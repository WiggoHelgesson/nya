import Foundation
import Supabase

class MonthlyStatsService {
    static let shared = MonthlyStatsService()
    private let supabase = SupabaseConfig.supabase
    
    private init() {}
    
    func fetchTopMonthlyUsers(limit: Int = 20) async throws -> [MonthlyUser] {
        do {
            print("🔄 Fetching top monthly users")
            
            // Get first and last day of current month
            let calendar = Calendar.current
            let now = Date()
            let components = calendar.dateComponents([.year, .month], from: now)
            
            guard let startOfMonth = calendar.date(from: components),
                  let endOfMonth = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: startOfMonth) else {
                throw NSError(domain: "MonthlyStatsService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to calculate month boundaries"])
            }
            
            print("📅 Fetching stats from \(startOfMonth) to \(endOfMonth)")
            
            // Get data from workout_posts table
            let workoutPosts: [WorkoutPost] = try await supabase
                .from("workout_posts")
                .select("id, user_id, activity_type, distance, created_at")
                .gte("created_at", value: startOfMonth.ISO8601Format())
                .lte("created_at", value: endOfMonth.ISO8601Format())
                .execute()
                .value
            
            print("📊 Found \(workoutPosts.count) workout posts this month")
            
            // Group by user and sum distances
            var userDistances: [String: Double] = [:]
            
            for post in workoutPosts {
                let userId = post.userId
                let distance = post.distance ?? 0.0
                // Convert km to meters (assuming distance is stored in km)
                userDistances[userId, default: 0.0] += distance * 1000.0
            }
            
            // Fetch user profiles and create MonthlyUser objects
            var users: [MonthlyUser] = []
            
            for (userId, distance) in userDistances {
                // Only include users who walked at least 100 meters
                if distance >= 100.0 {
                    if let profile = try? await ProfileService.shared.fetchUserProfile(userId: userId) {
                        let user = MonthlyUser(
                            id: userId,
                            username: profile.name,
                            avatarUrl: profile.avatarUrl,
                            distance: distance / 1000.0, // Convert meters to km
                            isPro: profile.isProMember
                        )
                        users.append(user)
                    }
                }
            }
            
            // Sort by distance descending and take top limit
            users.sort { $0.distance > $1.distance }
            let topUsers = Array(users.prefix(limit))
            
            print("✅ Fetched \(topUsers.count) top users")
            return topUsers
            
        } catch {
            print("❌ Error fetching top monthly users: \(error)")
            throw error
        }
    }
    
    func fetchLastMonthWinner() async throws -> MonthlyUser? {
        do {
            print("🔄 Fetching last month's winner")
            
            // Get first and last day of last month
            let calendar = Calendar.current
            let now = Date()
            let components = calendar.dateComponents([.year, .month], from: now)
            
            guard let currentMonth = calendar.date(from: components),
                  let lastMonth = calendar.date(byAdding: DateComponents(month: -1), to: currentMonth) else {
                throw NSError(domain: "MonthlyStatsService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to calculate last month boundaries"])
            }
            
            let lastMonthComponents = calendar.dateComponents([.year, .month], from: lastMonth)
            guard let startOfLastMonth = calendar.date(from: lastMonthComponents),
                  let endOfLastMonth = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: startOfLastMonth) else {
                throw NSError(domain: "MonthlyStatsService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to calculate last month boundaries"])
            }
            
            print("📅 Fetching last month stats from \(startOfLastMonth) to \(endOfLastMonth)")
            
            // Get data from workout_posts for last month
            let workoutPosts: [WorkoutPost] = try await supabase
                .from("workout_posts")
                .select("id, user_id, activity_type, distance, created_at")
                .gte("created_at", value: startOfLastMonth.ISO8601Format())
                .lte("created_at", value: endOfLastMonth.ISO8601Format())
                .execute()
                .value
            
            // Group by user and sum distances
            var userDistances: [String: Double] = [:]
            
            for post in workoutPosts {
                let userId = post.userId
                let distance = post.distance ?? 0.0
                // Convert km to meters (assuming distance is stored in km)
                userDistances[userId, default: 0.0] += distance * 1000.0
            }
            
            // Find the user with the highest distance
            if let winnerEntry = userDistances.max(by: { $0.value < $1.value }) {
                let userId = winnerEntry.key
                let distance = winnerEntry.value
                
                if let profile = try? await ProfileService.shared.fetchUserProfile(userId: userId) {
                    let winner = MonthlyUser(
                        id: userId,
                        username: profile.name,
                        avatarUrl: profile.avatarUrl,
                        distance: distance / 1000.0, // Convert meters to km
                        isPro: profile.isProMember
                    )
                    print("✅ Found last month winner: \(profile.name) with \(winner.distance) km")
                    return winner
                }
            }
            
            print("ℹ️ No winner found for last month")
            return nil
            
        } catch {
            print("❌ Error fetching last month winner: \(error)")
            return nil
        }
    }
}

