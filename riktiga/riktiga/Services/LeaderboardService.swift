import Foundation
import Supabase

struct LeaderboardEntry: Identifiable, Decodable {
    let user_id: String
    let username: String?
    let avatar_url: String?
    let is_pro_member: Bool?

    var id: String { user_id }

    let workout_count: Int?
    let total_distance: Double?
    let total_volume: Double?

    var displayValue: String {
        if let count = workout_count {
            return "\(count) pass"
        } else if let dist = total_distance {
            return String(format: "%.1f km", dist)
        } else if let vol = total_volume {
            if vol >= 1000 {
                return String(format: "%.0f kg", vol)
            }
            return String(format: "%.0f kg", vol)
        }
        return "-"
    }
}

enum LeaderboardCategory: String, CaseIterable, Identifiable, Hashable {
    case workouts
    case gymVolume

    var id: String { rawValue }

    var title: String {
        switch self {
        case .workouts: return L.t(sv: "Flest pass denna månaden", nb: "Flest økter denne måneden")
        case .gymVolume: return L.t(sv: "Lyft tyngst denna månaden", nb: "Løftet tyngst denne måneden")
        }
    }

    var imageName: String {
        switch self {
        case .workouts: return "91"
        case .gymVolume: return "81"
        }
    }

    var valueHeader: String {
        switch self {
        case .workouts: return L.t(sv: "PASS", nb: "ØKTER")
        case .gymVolume: return L.t(sv: "VOLYM", nb: "VOLUM")
        }
    }
}

class LeaderboardService {
    static let shared = LeaderboardService()
    private let supabase = SupabaseConfig.supabase

    private init() {}

    private var currentMonth: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"
        return formatter.string(from: Date())
    }

    func fetchWorkoutCountLeaderboard(userIds: [String]? = nil) async throws -> [LeaderboardEntry] {
        var params: [String: AnyJSON] = ["p_month": .string(currentMonth)]
        if let ids = userIds {
            params["p_user_ids"] = .array(ids.map { .string($0) })
        }
        let entries: [LeaderboardEntry] = try await supabase
            .rpc("get_monthly_workout_count_leaderboard", params: params)
            .execute()
            .value
        return entries
    }

    func fetchRunningDistanceLeaderboard(userIds: [String]? = nil) async throws -> [LeaderboardEntry] {
        var params: [String: AnyJSON] = ["p_month": .string(currentMonth)]
        if let ids = userIds {
            params["p_user_ids"] = .array(ids.map { .string($0) })
        }
        let entries: [LeaderboardEntry] = try await supabase
            .rpc("get_monthly_running_distance_leaderboard", params: params)
            .execute()
            .value
        return entries
    }

    func fetchGymVolumeLeaderboard(userIds: [String]? = nil) async throws -> [LeaderboardEntry] {
        var params: [String: AnyJSON] = ["p_month": .string(currentMonth)]
        if let ids = userIds {
            params["p_user_ids"] = .array(ids.map { .string($0) })
        }
        let entries: [LeaderboardEntry] = try await supabase
            .rpc("get_monthly_gym_volume_leaderboard", params: params)
            .execute()
            .value
        return entries
    }

    func fetchLeaderboard(category: LeaderboardCategory, userIds: [String]? = nil) async throws -> [LeaderboardEntry] {
        switch category {
        case .workouts: return try await fetchWorkoutCountLeaderboard(userIds: userIds)
        case .gymVolume: return try await fetchGymVolumeLeaderboard(userIds: userIds)
        }
    }

    func fetchSchoolUserIds() async throws -> [String] {
        struct UserIdRow: Decodable {
            let user_id: String
        }
        let rows: [UserIdRow] = try await supabase
            .rpc("get_danderyd_user_ids")
            .execute()
            .value
        return rows.map { $0.user_id }
    }
}
