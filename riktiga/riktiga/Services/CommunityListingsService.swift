import Foundation
import Supabase

/// Loads community-submitted second-hand listings that our AI image-check has
/// auto-approved (or an admin has accepted). These show up as a "Begagnat från
/// communityn"-section on the products page alongside Shopify products.
final class CommunityListingsService {
    static let shared = CommunityListingsService()

    private var supabase: SupabaseClient { SupabaseConfig.supabase }

    private init() {}

    /// Fetches the newest accepted listings.
    func fetchAcceptedListings(limit: Int = 40) async throws -> [ConsignmentSubmissionRow] {
        try await AuthSessionManager.shared.ensureValidSession()
        let rows: [ConsignmentSubmissionRow] = try await supabase
            .from("community_listings_feed")
            .select()
            .order("created_at", ascending: false)
            .limit(limit)
            .execute()
            .value
        return rows
    }

    /// Fetches a specific user's accepted, unsold listings. Used by
    /// `UserProfileView` to render the user's own "Annonser"-sektion under
    /// the weekly-hours-widget.
    func fetchAcceptedListings(forUserId userId: UUID, limit: Int = 40) async throws -> [ConsignmentSubmissionRow] {
        try await AuthSessionManager.shared.ensureValidSession()
        return try await supabase
            .from("community_listings_feed")
            .select()
            .eq("user_id", value: userId.uuidString)
            .order("created_at", ascending: false)
            .limit(limit)
            .execute()
            .value
    }

    /// Fetches a single listing by id. Used by the marketplace chat header to
    /// show the listing card (image/title/price) above the conversation.
    func fetchListing(id: UUID) async throws -> ConsignmentSubmissionRow? {
        try await AuthSessionManager.shared.ensureValidSession()
        let rows: [ConsignmentSubmissionRow] = try await supabase
            .from("consignment_submissions")
            .select()
            .eq("id", value: id.uuidString)
            .limit(1)
            .execute()
            .value
        return rows.first
    }
}
