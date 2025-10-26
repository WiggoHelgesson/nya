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
            
            let startOfMonthStr = startOfMonth.ISO8601Format()
            let endOfMonthStr = endOfMonth.ISO8601Format()
            
            print("📅 Current month is: \(calendar.component(.month, from: now)), year: \(calendar.component(.year, from: now))")
            print("📅 Fetching stats from \(startOfMonthStr) to \(endOfMonthStr)")
            
            // Get data from golf_rounds
            struct GolfRound: Decodable {
                let userId: String
                let distanceWalkedMeters: Double?
                
                enum CodingKeys: String, CodingKey {
                    case userId = "user_id"
                    case distanceWalkedMeters = "distance_walked_meters"
                }
            }
            
            let golfRounds: [GolfRound] = try await supabase
                .from("golf_rounds")
                .select("user_id, distance_walked_meters")
                .gte("created_at", value: startOfMonth.ISO8601Format())
                .lte("created_at", value: endOfMonth.ISO8601Format())
                .execute()
                .value
            
            print("📊 Found \(golfRounds.count) golf rounds this month")
            
            // Also fetch all users' data from workout_posts as fallback
            let workoutPosts: [WorkoutPost] = try await supabase
                .from("workout_posts")
                .select("id, user_id, activity_type, title, distance, created_at")
                .gte("created_at", value: startOfMonthStr)
                .lte("created_at", value: endOfMonthStr)
                .execute()
                .value
            
            print("📊 Found \(workoutPosts.count) workout posts this month")
            
            // Group by user and sum distances (convert meters to km)
            var userDistances: [String: Double] = [:]
            
            // Add workout posts data to user distances
            for post in workoutPosts {
                let userId = post.userId
                let distance = post.distance ?? 0.0
                userDistances[userId, default: 0.0] += distance
            }
            
            // Get data from completed_training_sessions
            struct TrainingSession: Decodable {
                let userId: String
                let distanceWalkedMeters: Double?
                
                enum CodingKeys: String, CodingKey {
                    case userId = "user_id"
                    case distanceWalkedMeters = "distance_walked_meters"
                }
            }
            
            let trainingSessions: [TrainingSession] = try await supabase
                .from("completed_training_sessions")
                .select("user_id, distance_walked_meters")
                .gte("created_at", value: startOfMonth.ISO8601Format())
                .lte("created_at", value: endOfMonth.ISO8601Format())
                .execute()
                .value
            
            print("📊 Found \(trainingSessions.count) training sessions this month")
            
            for round in golfRounds {
                let userId = round.userId
                let distance = round.distanceWalkedMeters ?? 0.0
                userDistances[userId, default: 0.0] += distance / 1000.0 // Convert meters to km
            }
            
            for session in trainingSessions {
                let userId = session.userId
                let distance = session.distanceWalkedMeters ?? 0.0
                userDistances[userId, default: 0.0] += distance / 1000.0 // Convert meters to km
            }
            
            // Fetch user profiles and create MonthlyUser objects
            var users: [MonthlyUser] = []
            
            print("📊 Processing \(userDistances.count) unique users...")
            
            for (index, (userId, distance)) in userDistances.enumerated() {
                print("📊 Processing user \(index + 1)/\(userDistances.count): userId=\(userId), distance=\(distance) km")
                
                // Only include users who walked at least 0.1 km (100 meters)
                if distance >= 0.1 {
                    print("📊 Fetching profile \(index + 1)/\(userDistances.count) for userId: \(userId)")
                    if let profile = try? await ProfileService.shared.fetchUserProfile(userId: userId) {
                        let user = MonthlyUser(
                            id: userId,
                            username: profile.name,
                            avatarUrl: profile.avatarUrl,
                            distance: distance,
                            isPro: profile.isProMember
                        )
                        users.append(user)
                        print("✅ Added user: \(profile.name) with \(distance) km")
                    } else {
                        print("❌ Failed to fetch profile for userId: \(userId)")
                    }
                } else {
                    print("⏭️ Skipping user \(userId) - distance too low: \(distance) km < 0.1 km")
                }
            }
            
            // Sort by distance descending and take top limit
            users.sort { $0.distance > $1.distance }
            let topUsers = Array(users.prefix(limit))
            
            print("✅ Fetched \(topUsers.count) top users")
            print("📊 Total unique users with distance data: \(userDistances.count)")
            
            // Debug print top 20
            for (index, user) in topUsers.enumerated() {
                print("\(index + 1). \(user.username): \(user.distance) km")
            }
            
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
            
            // Get data from golf_rounds for last month
            struct GolfRound: Decodable {
                let userId: String
                let distanceWalkedMeters: Double?
                
                enum CodingKeys: String, CodingKey {
                    case userId = "user_id"
                    case distanceWalkedMeters = "distance_walked_meters"
                }
            }
            
            let golfRounds: [GolfRound] = try await supabase
                .from("golf_rounds")
                .select("user_id, distance_walked_meters")
                .gte("created_at", value: startOfLastMonth.ISO8601Format())
                .lte("created_at", value: endOfLastMonth.ISO8601Format())
                .execute()
                .value
            
            // Get data from completed_training_sessions for last month
            struct TrainingSession: Decodable {
                let userId: String
                let distanceWalkedMeters: Double?
                
                enum CodingKeys: String, CodingKey {
                    case userId = "user_id"
                    case distanceWalkedMeters = "distance_walked_meters"
                }
            }
            
            let trainingSessions: [TrainingSession] = try await supabase
                .from("completed_training_sessions")
                .select("user_id, distance_walked_meters")
                .gte("created_at", value: startOfLastMonth.ISO8601Format())
                .lte("created_at", value: endOfLastMonth.ISO8601Format())
                .execute()
                .value
            
            // Group by user and sum distances (convert meters to km)
            var userDistances: [String: Double] = [:]
            
            for round in golfRounds {
                let userId = round.userId
                let distance = round.distanceWalkedMeters ?? 0.0
                userDistances[userId, default: 0.0] += distance / 1000.0 // Convert meters to km
            }
            
            for session in trainingSessions {
                let userId = session.userId
                let distance = session.distanceWalkedMeters ?? 0.0
                userDistances[userId, default: 0.0] += distance / 1000.0 // Convert meters to km
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
                        distance: distance,
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

