import Foundation

/// Enkel minnes-cache per `userId` så att `UserProfileView` kan rita upp
/// stommen (avatar, namn, stats, veckotimmar, annonser) instant vid
/// re-open medan nätverks-refreshen körs i bakgrunden.
///
/// Används endast som UI-snapshot — ingen persistence, rensas när appen
/// avslutas.
@MainActor
final class UserProfileCache {
    static let shared = UserProfileCache()

    struct Snapshot {
        var username: String
        var avatarUrl: String?
        var bannerUrl: String?
        var isPro: Bool
        var followersCount: Int
        var followingCount: Int
        var workoutsCount: Int
        var weeklyHours: Double
        var listings: [ConsignmentSubmissionRow]
        var capturedAt: Date
    }

    private var map: [String: Snapshot] = [:]

    private init() {}

    func snapshot(for userId: String) -> Snapshot? {
        map[userId]
    }

    func store(_ snapshot: Snapshot, for userId: String) {
        map[userId] = snapshot
    }

    /// Uppdaterar bara delar av snapshoten (merge) så att en core-refresh
    /// inte skriver över listings som redan hämtats, och vice versa.
    func update(userId: String, mutate: (inout Snapshot) -> Void) {
        var snap = map[userId] ?? Snapshot(
            username: "",
            avatarUrl: nil,
            bannerUrl: nil,
            isPro: false,
            followersCount: 0,
            followingCount: 0,
            workoutsCount: 0,
            weeklyHours: 0,
            listings: [],
            capturedAt: Date()
        )
        mutate(&snap)
        snap.capturedAt = Date()
        map[userId] = snap
    }
}
