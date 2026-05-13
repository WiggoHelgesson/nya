import Foundation
import Supabase

// MARK: - Errors

enum ShippingLabelError: LocalizedError {
    case manualRequired
    case notImplemented
    case notAuthenticated
    case invalidAddress
    case missingLabel

    var errorDescription: String? {
        switch self {
        case .manualRequired:
            return "Fraktsedeln laddas upp manuellt av admin."
        case .notImplemented:
            return "Fraktleverantörens API är inte aktiverad än."
        case .notAuthenticated:
            return "Inte inloggad."
        case .invalidAddress:
            return "Adressen är ofullständig."
        case .missingLabel:
            return "Ingen fraktsedel hittades."
        }
    }
}

// MARK: - Provider protocol

protocol ShippingLabelProviding {
    /// Generate a shipping label for the given submission and seller address.
    /// Returns a URL to the stored PDF. Implementations that rely on manual upload
    /// should throw `ShippingLabelError.manualRequired`.
    func generateLabel(
        for submission: ConsignmentSubmissionRow,
        address: ShippingAddress
    ) async throws -> URL
}

struct ManualUploadShippingLabelProvider: ShippingLabelProviding {
    func generateLabel(
        for submission: ConsignmentSubmissionRow,
        address: ShippingAddress
    ) async throws -> URL {
        throw ShippingLabelError.manualRequired
    }
}

/// Stub for future automatic generation. Kept here so the surface is in place.
struct PostNordShippingLabelProvider: ShippingLabelProviding {
    func generateLabel(
        for submission: ConsignmentSubmissionRow,
        address: ShippingAddress
    ) async throws -> URL {
        throw ShippingLabelError.notImplemented
    }
}

// MARK: - Service

@MainActor
final class ShippingLabelService {
    static let shared = ShippingLabelService()

    private let provider: ShippingLabelProviding
    private var supabase: SupabaseClient { SupabaseConfig.supabase }

    private let bucket = "shipping-labels"

    private init(provider: ShippingLabelProviding = ManualUploadShippingLabelProvider()) {
        self.provider = provider
    }

    // MARK: Seller

    /// Persist the seller's shipping address and move status forward.
    func saveAddress(submissionId: UUID, address: ShippingAddress) async throws {
        try await AuthSessionManager.shared.ensureValidSession()

        guard !address.fullName.isEmpty,
              !address.street.isEmpty,
              !address.postalCode.isEmpty,
              !address.city.isEmpty else {
            throw ShippingLabelError.invalidAddress
        }

        struct Payload: Encodable {
            let shipping_address: ShippingAddress
            let shipping_status: String
            let updated_at: String
        }

        let payload = Payload(
            shipping_address: address,
            shipping_status: ShippingStatus.awaitingLabel,
            updated_at: ISO8601DateFormatter().string(from: Date())
        )

        try await supabase
            .from("consignment_submissions")
            .update(payload)
            .eq("id", value: submissionId.uuidString)
            .execute()
    }

    /// Seller confirms the package has been posted.
    func markShipped(submissionId: UUID) async throws {
        try await AuthSessionManager.shared.ensureValidSession()

        struct Payload: Encodable {
            let shipping_status: String
            let shipped_at: String
            let updated_at: String
        }

        let now = ISO8601DateFormatter().string(from: Date())
        let payload = Payload(
            shipping_status: ShippingStatus.shipped,
            shipped_at: now,
            updated_at: now
        )

        try await supabase
            .from("consignment_submissions")
            .update(payload)
            .eq("id", value: submissionId.uuidString)
            .execute()
    }

    /// Returns a short-lived signed URL for the seller's shipping label PDF.
    func signedUrlForLabel(submissionId: UUID, userId: UUID) async throws -> URL {
        try await AuthSessionManager.shared.ensureValidSession()
        let path = Self.labelPath(submissionId: submissionId, userId: userId)
        return try await supabase.storage
            .from(bucket)
            .createSignedURL(path: path, expiresIn: 3600)
    }

    /// Signed URL for a marketplace-order shipping label. The
    /// `book-marketplace-shipping` edge function stores PDFs at
    /// `{sellerId}/{orderId}.pdf` in the `shipping-labels` bucket.
    /// If `storedPath` is provided (e.g. read from
    /// `marketplace_orders.shipping_label_url` when it points at the
    /// bucket), we sign that path instead.
    func signedUrlForMarketplaceOrderLabel(
        orderId: UUID,
        sellerId: UUID,
        storedPath: String? = nil
    ) async throws -> URL {
        try await AuthSessionManager.shared.ensureValidSession()
        let path: String
        if let storedPath, !storedPath.isEmpty,
           !storedPath.hasPrefix("http") {
            path = storedPath
        } else {
            path = "\(sellerId.uuidString)/\(orderId.uuidString).pdf"
        }
        return try await supabase.storage
            .from(bucket)
            .createSignedURL(path: path, expiresIn: 3600)
    }

    // MARK: Admin

    /// Upload a PDF shipping label. Caller must be admin. Sets label URL + status.
    @discardableResult
    func uploadLabelPDF(
        submissionId: UUID,
        userId: UUID,
        data: Data,
        carrier: String? = nil,
        trackingNumber: String? = nil
    ) async throws -> String {
        try await AuthSessionManager.shared.ensureValidSession()

        let path = Self.labelPath(submissionId: submissionId, userId: userId)
        try await supabase.storage
            .from(bucket)
            .upload(
                path: path,
                file: data,
                options: FileOptions(contentType: "application/pdf", upsert: true)
            )

        struct Payload: Encodable {
            let shipping_label_url: String
            let shipping_status: String
            let shipping_carrier: String?
            let shipping_tracking_number: String?
            let updated_at: String
        }

        let payload = Payload(
            shipping_label_url: path,
            shipping_status: ShippingStatus.labelReady,
            shipping_carrier: carrier,
            shipping_tracking_number: trackingNumber,
            updated_at: ISO8601DateFormatter().string(from: Date())
        )

        try await supabase
            .from("consignment_submissions")
            .update(payload)
            .eq("id", value: submissionId.uuidString)
            .execute()

        return path
    }

    /// Admin: uploads a PDF shipping label for a marketplace order whose
    /// Automated booking failed (`shipping_status='manual'`). Stores at
    /// `{sellerId}/{orderId}.pdf` in the same bucket as API-booked
    /// labels and flips `shipping_status='label_ready'` so the seller
    /// sees the standard PDF link in the chat.
    @discardableResult
    func uploadMarketplaceOrderLabelPDF(
        orderId: UUID,
        sellerId: UUID,
        data: Data,
        carrier: String? = nil,
        trackingNumber: String? = nil,
        trackingUrl: String? = nil
    ) async throws -> String {
        try await AuthSessionManager.shared.ensureValidSession()

        let path = "\(sellerId.uuidString)/\(orderId.uuidString).pdf"
        try await supabase.storage
            .from(bucket)
            .upload(
                path: path,
                file: data,
                options: FileOptions(contentType: "application/pdf", upsert: true)
            )

        struct Payload: Encodable {
            let shipping_label_url: String
            let shipping_status: String
            let shipping_carrier: String?
            let shipping_tracking_number: String?
            let shipping_tracking_url: String?
            let shipping_booked_at: String
        }

        let payload = Payload(
            shipping_label_url: path,
            shipping_status: "label_ready",
            shipping_carrier: carrier,
            shipping_tracking_number: trackingNumber,
            shipping_tracking_url: trackingUrl,
            shipping_booked_at: ISO8601DateFormatter().string(from: Date())
        )

        try await supabase
            .from("marketplace_orders")
            .update(payload)
            .eq("id", value: orderId.uuidString)
            .execute()

        return path
    }

    /// Admin marks the package as received at warehouse.
    func markReceived(submissionId: UUID) async throws {
        try await AuthSessionManager.shared.ensureValidSession()

        struct Payload: Encodable {
            let shipping_status: String
            let received_at: String
            let updated_at: String
        }

        let now = ISO8601DateFormatter().string(from: Date())
        let payload = Payload(
            shipping_status: ShippingStatus.received,
            received_at: now,
            updated_at: now
        )

        try await supabase
            .from("consignment_submissions")
            .update(payload)
            .eq("id", value: submissionId.uuidString)
            .execute()
    }

    // MARK: Helpers

    static func labelPath(submissionId: UUID, userId: UUID) -> String {
        "\(userId.uuidString)/\(submissionId.uuidString).pdf"
    }
}
