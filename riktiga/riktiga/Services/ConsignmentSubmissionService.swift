import Foundation
import Supabase
import UIKit

enum ConsignmentSubmissionError: LocalizedError {
    case notSignedIn
    case uploadFailed

    var errorDescription: String? {
        switch self {
        case .notSignedIn: return "Du måste vara inloggad."
        case .uploadFailed: return "Uppladdning av bilder misslyckades."
        }
    }
}

final class ConsignmentSubmissionService {
    static let shared = ConsignmentSubmissionService()

    private let bucket = "consignment-photos"
    private var supabase: SupabaseClient { SupabaseConfig.supabase }

    private init() {}

    func submit(
        userId: String,
        images: [UIImage],
        category: String,
        analysis: SellAnalysisResult,
        userBrand: String,
        userCondition: String
    ) async throws -> UUID {
        let folderId = UUID()
        var imageUrls: [String] = []

        for (index, image) in images.enumerated() {
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

        let row = ConsignmentInsertRow(
            userId: userId,
            imageUrls: imageUrls,
            category: category,
            aiPayload: analysis,
            userBrand: userBrand.trimmingCharacters(in: .whitespacesAndNewlines),
            userCondition: userCondition.trimmingCharacters(in: .whitespacesAndNewlines)
        )

        try await supabase
            .from("consignment_submissions")
            .insert(row)
            .execute()

        return folderId
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
}

private struct ConsignmentInsertRow: Encodable {
    let userId: String
    let imageUrls: [String]
    let category: String
    let aiPayload: SellAnalysisResult
    let userBrand: String
    let userCondition: String

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case imageUrls = "image_urls"
        case category
        case aiPayload = "ai_payload"
        case userBrand = "user_brand"
        case userCondition = "user_condition"
    }
}
