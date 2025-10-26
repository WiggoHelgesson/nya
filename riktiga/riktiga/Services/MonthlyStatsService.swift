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
            
            // Query workout_posts for current month
            // We'll need to sum up distances and get user stats
            let posts: [WorkoutPost] = try await supabase
                .from("workout_posts")
                .select("user_id, activity_type, distance, created_at")
                .gte("created_at", value: startOfMonth.ISO8601Format())
                .lte("created_at", value: endOfMonth.ISO8601Format())
                .execute()
                .value
            
            print("📊 Found \(posts.count) workout posts this month")
            
            // Group by user and sum distances
            var userDistances: [String: Double] = [:]
            var userMap: [String: (username: String, avatarUrl: String?, isPro: Bool)] = [:]
            
            for post in posts {
                let userId = post.userId
                
                // Add distance (assuming distance is stored in the workout post)
                let distance = post.distance ?? 0.0
                userDistances[userId, default: 0.0] += distance
                
                // Fetch user info if we don't have it yet
                if userMap[userId] == nil {
                    if let user = try? await ProfileService.shared.fetchUserProfile(userId: userId) {
                        userMap[userId] = (
                            username: user.name,
                            avatarUrl: user.avatarUrl,
                            isPro: user.isProMember
                        )
                    } else {
                        userMap[userId] = (username: "Användare", avatarUrl: nil, isPro: false)
                    }
                }
            }
            
            // Convert to MonthlyUser array and sort by distance
            var users: [MonthlyUser] = []
            
            for (userId, distance) in userDistances {
                if let userInfo = userMap[userId] {
                    let user = MonthlyUser(
                        id: userId,
                        username: userInfo.username,
                        avatarUrl: userInfo.avatarUrl,
                        distance: distance,
                        isPro: userInfo.isPro
                    )
                    users.append(user)
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
            
            // Get top 1 user from last month
            let users = try await fetchTopMonthlyUsers(limit: 1, startDate: startOfLastMonth, endDate: endOfLastMonth)
            
            return users.first
            
        } catch {
            print("❌ Error fetching last month winner: \(error)")
            return nil
        }
    }
    
    private func fetchTopMonthlyUsers(limit: Int, startDate: Date, endDate: Date) async throws -> [MonthlyUser] {
        let posts: [WorkoutPost] = try await supabase
            .from("workout_posts")
            .select("user_id, activity_type, distance, created_at")
            .gte("created_at", value: startDate.ISO8601Format())
            .lte("created_at", value: endDate.ISO8601Format())
            .execute()
            .value
        
        // Group by user and sum distances
        var userDistances: [String: Double] = [:]
        var userMap: [String: (username: String, avatarUrl: String?, isPro: Bool)] = [:]
        
        for post in posts {
            let userId = post.userId
            let distance = post.distance ?? 0.0
            userDistances[userId, default: 0.0] += distance
            
            if userMap[userId] == nil {
                if let user = try? await ProfileService.shared.fetchUserProfile(userId: userId) {
                    userMap[userId] = (
                        username: user.name,
                        avatarUrl: user.avatarUrl,
                        isPro: user.isProMember
                    )
                } else {
                    userMap[userId] = (username: "Användare", avatarUrl: nil, isPro: false)
                }
            }
        }
        
        var users: [MonthlyUser] = []
        
        for (userId, distance) in userDistances {
            if let userInfo = userMap[userId] {
                let user = MonthlyUser(
                    id: userId,
                    username: userInfo.username,
                    avatarUrl: userInfo.avatarUrl,
                    distance: distance,
                    isPro: userInfo.isPro
                )
                users.append(user)
            }
        }
        
        users.sort { $0.distance > $1.distance }
        return Array(users.prefix(limit))
    }
}

