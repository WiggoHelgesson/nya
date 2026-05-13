import Foundation
import Supabase
import UIKit

enum ConsignmentSubmissionError: LocalizedError {
    case notSignedIn
    case uploadFailed
    case invalidInput

    var errorDescription: String? {
        switch self {
        case .notSignedIn: return "Du måste vara inloggad."
        case .uploadFailed: return "Uppladdning av bilder misslyckades."
        case .invalidInput: return "Alla fält måste fyllas i."
        }
    }
}

final class ConsignmentSubmissionService {
    static let shared = ConsignmentSubmissionService()

    private let bucket = "consignment-photos"
    private var supabase: SupabaseClient { SupabaseConfig.supabase }

    private init() {}

    /// Result of submitting a new listing. `autoApproved` is `true` when our
    /// AI photo-check has confirmed the images contain a product and the row
    /// was inserted with `admin_status = "accepted"` (visible in the
    /// marketplace feed immediately). When `false`, the row was inserted as
    /// `pending` and is routed to manual admin review.
    struct SubmitOutcome {
        let id: UUID
        let autoApproved: Bool
    }

    func submit(userId: String, model: SellFlowModel) async throws -> SubmitOutcome {
        guard model.isReadyToSubmit,
              let priceSEK = model.priceSEK
        else {
            throw ConsignmentSubmissionError.invalidInput
        }

        // 1) Lightweight AI check on the *original* images before we upload
        //    anything. We keep the bar very low — only clearly off-topic
        //    photos (memes, random selfies, pure landscapes) get routed to
        //    manual review. On any network / API failure we also fall back
        //    to manual review so we never auto-publish junk.
        let verification = await ListingImageVerificationService.shared.verify(images: model.images)
        let autoApprove = verification.isProduct

        let folderId = UUID()
        var imageUrls: [String] = []

        for (index, image) in model.images.enumerated() {
            guard let data = SellImagePrep.jpegData(from: image, maxDimension: 2000, quality: 0.82) else {
                continue
            }
            let path = "\(userId)/\(folderId.uuidString)/\(index).jpg"
            do {
                try await supabase.storage
                    .from(bucket)
                    .upload(path: path, file: data, options: FileOptions(contentType: "image/jpeg", upsert: true))

                let publicURL = try supabase.storage
                    .from(bucket)
                    .getPublicURL(path: path)

                imageUrls.append(SupabaseConfig.rewriteURL(publicURL.absoluteString))
            } catch {
                print("Consignment upload error: \(error)")
                throw ConsignmentSubmissionError.uploadFailed
            }
        }

        guard !imageUrls.isEmpty else { throw ConsignmentSubmissionError.uploadFailed }

        let trimmedMaterial = model.material.trimmingCharacters(in: .whitespacesAndNewlines)

        let adminStatus = autoApprove ? "accepted" : "pending"
        let aiNotes: String = {
            let prefix = autoApprove ? "auto_approved" : "needs_review"
            let conf = String(format: "%.2f", verification.confidence)
            let reason = verification.reason.isEmpty ? "-" : verification.reason
            return "\(prefix) (conf \(conf)): \(reason)"
        }()

        let row = ConsignmentInsertRow(
            userId: userId,
            imageUrls: imageUrls,
            category: model.selectedCategory,
            title: model.title.trimmingCharacters(in: .whitespacesAndNewlines),
            description: model.listingDescription.trimmingCharacters(in: .whitespacesAndNewlines),
            priceSEK: priceSEK,
            colors: model.colors,
            material: trimmedMaterial.isEmpty ? nil : trimmedMaterial,
            packageSize: model.packageSize,
            userBrand: model.brand.trimmingCharacters(in: .whitespacesAndNewlines),
            userCondition: model.condition,
            adminStatus: adminStatus,
            adminNotes: aiNotes
        )

        try await supabase
            .from("consignment_submissions")
            .insert(row)
            .execute()

        return SubmitOutcome(id: folderId, autoApproved: autoApprove)
    }

    func fetchMine(userId: String, limit: Int = 80) async throws -> [ConsignmentSubmissionRow] {
        try await AuthSessionManager.shared.ensureValidSession()
        return try await supabase
            .from("consignment_submissions")
            .select()
            .eq("user_id", value: userId)
            .order("created_at", ascending: false)
            .limit(limit)
            .execute()
            .value
    }

    /// Updates an existing listing owned by `userId`. Re-uploads every
    /// current `model.images` entry to a fresh folder to keep the logic
    /// simple (no partial image tracking) and best-effort removes the old
    /// image objects from storage after the row update succeeds.
    func update(
        userId: String,
        rowId: UUID,
        model: SellFlowModel,
        previousImageUrls: [String]
    ) async throws {
        guard model.isReadyToSubmit,
              let priceSEK = model.priceSEK
        else {
            throw ConsignmentSubmissionError.invalidInput
        }

        let folderId = UUID()
        var imageUrls: [String] = []
        for (index, image) in model.images.enumerated() {
            guard let data = SellImagePrep.jpegData(from: image, maxDimension: 2000, quality: 0.82) else {
                continue
            }
            let path = "\(userId)/\(folderId.uuidString)/\(index).jpg"
            do {
                try await supabase.storage
                    .from(bucket)
                    .upload(path: path, file: data, options: FileOptions(contentType: "image/jpeg", upsert: true))

                let publicURL = try supabase.storage
                    .from(bucket)
                    .getPublicURL(path: path)

                imageUrls.append(SupabaseConfig.rewriteURL(publicURL.absoluteString))
            } catch {
                print("Consignment update upload error: \(error)")
                throw ConsignmentSubmissionError.uploadFailed
            }
        }

        guard !imageUrls.isEmpty else { throw ConsignmentSubmissionError.uploadFailed }

        let trimmedMaterial = model.material.trimmingCharacters(in: .whitespacesAndNewlines)

        let update = ConsignmentUpdateRow(
            imageUrls: imageUrls,
            category: model.selectedCategory,
            title: model.title.trimmingCharacters(in: .whitespacesAndNewlines),
            description: model.listingDescription.trimmingCharacters(in: .whitespacesAndNewlines),
            priceSEK: priceSEK,
            colors: model.colors,
            material: trimmedMaterial.isEmpty ? nil : trimmedMaterial,
            packageSize: model.packageSize,
            userBrand: model.brand.trimmingCharacters(in: .whitespacesAndNewlines),
            userCondition: model.condition
        )

        try await supabase
            .from("consignment_submissions")
            .update(update)
            .eq("id", value: rowId)
            .eq("user_id", value: userId)
            .execute()

        await removeStorageObjects(for: previousImageUrls)
    }

    /// Deletes a row owned by `userId` and best-effort removes its image
    /// objects from storage. RLS enforces ownership at the DB level.
    ///
    /// Pass `asAdmin: true` to skip the `user_id` filter so an admin (as
    /// defined by `public.is_admin()` in the database) can remove another
    /// user's listing. RLS still gates whether the delete is permitted.
    func delete(
        userId: String,
        rowId: UUID,
        imageUrls: [String],
        asAdmin: Bool = false
    ) async throws {
        let deleted: [ConsignmentSubmissionRow]
        if asAdmin {
            deleted = try await supabase
                .from("consignment_submissions")
                .delete()
                .eq("id", value: rowId)
                .select()
                .execute()
                .value
        } else {
            deleted = try await supabase
                .from("consignment_submissions")
                .delete()
                .eq("id", value: rowId)
                .eq("user_id", value: userId)
                .select()
                .execute()
                .value
        }

        guard !deleted.isEmpty else {
            throw NSError(
                domain: "ConsignmentSubmissionService",
                code: 403,
                userInfo: [NSLocalizedDescriptionKey: L.t(
                    sv: "Kunde inte radera annonsen. Saknar behörighet – kör RLS-policyn i Supabase.",
                    nb: "Kunne ikke slette annonsen. Mangler tilgang – kjør RLS-policyen i Supabase."
                )]
            )
        }

        await removeStorageObjects(for: imageUrls)
    }

    private func removeStorageObjects(for urls: [String]) async {
        let paths = urls.compactMap { storagePath(from: $0) }
        guard !paths.isEmpty else { return }
        do {
            _ = try await supabase.storage.from(bucket).remove(paths: paths)
        } catch {
            print("Consignment storage cleanup failed: \(error)")
        }
    }

    private func storagePath(from urlString: String) -> String? {
        let marker = "/\(bucket)/"
        guard let range = urlString.range(of: marker) else { return nil }
        let path = String(urlString[range.upperBound...])
        return path.isEmpty ? nil : path
    }
}

private struct ConsignmentUpdateRow: Encodable {
    let imageUrls: [String]
    let category: String
    let title: String
    let description: String
    let priceSEK: Int
    let colors: [String]
    let material: String?
    let packageSize: String
    let userBrand: String
    let userCondition: String

    enum CodingKeys: String, CodingKey {
        case imageUrls = "image_urls"
        case category
        case title
        case description
        case priceSEK = "price_sek"
        case colors
        case material
        case packageSize = "package_size"
        case userBrand = "user_brand"
        case userCondition = "user_condition"
    }
}

private struct ConsignmentInsertRow: Encodable {
    let userId: String
    let imageUrls: [String]
    let category: String
    let title: String
    let description: String
    let priceSEK: Int
    let colors: [String]
    let material: String?
    let packageSize: String
    let userBrand: String
    let userCondition: String
    let adminStatus: String
    let adminNotes: String?

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case imageUrls = "image_urls"
        case category
        case title
        case description
        case priceSEK = "price_sek"
        case colors
        case material
        case packageSize = "package_size"
        case userBrand = "user_brand"
        case userCondition = "user_condition"
        case adminStatus = "admin_status"
        case adminNotes = "admin_notes"
    }
}
