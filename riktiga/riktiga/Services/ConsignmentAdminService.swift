import Foundation
import Supabase

enum ConsignmentAdminError: LocalizedError {
    case notAuthenticated

    var errorDescription: String? {
        switch self {
        case .notAuthenticated: return "Inte inloggad."
        }
    }
}

final class ConsignmentAdminService {
    static let shared = ConsignmentAdminService()

    private var supabase: SupabaseClient { SupabaseConfig.supabase }

    private init() {}

    func fetchSubmissions(status: String? = nil, limit: Int = 80) async throws -> [ConsignmentSubmissionRow] {
        try await AuthSessionManager.shared.ensureValidSession()

        if let status {
            return try await supabase
                .from("consignment_submissions")
                .select()
                .eq("admin_status", value: status)
                .order("created_at", ascending: false)
                .limit(limit)
                .execute()
                .value
        }
        return try await supabase
            .from("consignment_submissions")
            .select()
            .order("created_at", ascending: false)
            .limit(limit)
            .execute()
            .value
    }

    func updateSubmission(
        id: UUID,
        adminStatus: String,
        finalPriceRange: String?,
        adminNotes: String?
    ) async throws {
        try await AuthSessionManager.shared.ensureValidSession()

        let payload = AdminUpdatePayload(
            adminStatus: adminStatus,
            finalPriceRange: finalPriceRange,
            adminNotes: adminNotes,
            updatedAt: ISO8601DateFormatter().string(from: Date())
        )

        try await supabase
            .from("consignment_submissions")
            .update(payload)
            .eq("id", value: id.uuidString)
            .execute()
    }
}

private struct AdminUpdatePayload: Encodable {
    let adminStatus: String
    let finalPriceRange: String?
    let adminNotes: String?
    let updatedAt: String

    enum CodingKeys: String, CodingKey {
        case adminStatus = "admin_status"
        case finalPriceRange = "final_price_range"
        case adminNotes = "admin_notes"
        case updatedAt = "updated_at"
    }
}
