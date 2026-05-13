import Foundation
import Combine

extension Notification.Name {
    /// Efter ny/uppdaterad annons – trigga omhämtning av Produkter-feeden.
    static let communityListingsNeedRefresh = Notification.Name("communityListingsNeedRefresh")
}

/// Delar den aktuella listan av community-annonser mellan feed-vyn och
/// marknadsplatsens söksida, så att sök kan filtrera samma rader som visas i
/// feeden utan att behöva göra en egen hämtning.
final class CommunityListingsCache: ObservableObject {
    static let shared = CommunityListingsCache()

    @Published var listings: [ConsignmentSubmissionRow] = []

    /// Undvik upprepade nätverksanrop vid snabba flikbyten.
    private var lastSuccessfulRefreshAt: Date?
    private let minRefreshInterval: TimeInterval = 3

    private init() {}

    /// - Parameter force: `true` vid pull-to-refresh, notiser och första laddning — kringgår throttle.
    @MainActor
    func refresh(force: Bool = false) async {
        if !force,
           let last = lastSuccessfulRefreshAt,
           Date().timeIntervalSince(last) < minRefreshInterval {
            return
        }
        do {
            let rows = try await CommunityListingsService.shared.fetchAcceptedListings(limit: 60)
            self.listings = rows
            lastSuccessfulRefreshAt = Date()
        } catch {
            print("⚠️ CommunityListingsCache refresh failed: \(error)")
        }
    }
}
