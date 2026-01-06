import Foundation
import Supabase

class MonthlyStatsService {
    static let shared = MonthlyStatsService()
    private let supabase = SupabaseConfig.supabase
    private let cache = AppCacheManager.shared
    private let stepsCache = NSCache<NSString, NSNumber>()
    
    private init() {}
    
    // Upload this device's current month steps to Supabase so it can appear in the leaderboard
    func syncCurrentUserMonthlySteps() async {
        await withCheckedContinuation { continuation in
            HealthKitManager.shared.getCurrentMonthStepsTotal { steps in
                Task {
                    do {
                        let session = try await SupabaseConfig.supabase.auth.session
                        let userId = session.user.id.uuidString
                        let monthKey = Self.currentMonthKey()
                        struct Row: Encodable { let user_id: String; let month: String; let steps: Int }
                        try await self.supabase
                            .from("monthly_steps")
                            .upsert(Row(user_id: userId, month: monthKey, steps: steps), onConflict: "user_id,month")
                            .execute()
                        print("✅ Synced monthly steps: \(steps) for \(userId) month=\(monthKey)")
                    } catch {
                        print("❌ Failed to sync monthly steps: \(error)")
                    }
                    continuation.resume()
                }
            }
        }
    }

    func fetchTopMonthlyUsers(limit: Int = 20, forceRemote: Bool = false) async throws -> [MonthlyUser] {
        do {
            print("🔄 Fetching top monthly users by steps")
            let monthKey = Self.currentMonthKey()
            if !forceRemote, let cached = cache.getCachedMonthlyLeaderboard(monthKey: monthKey) {
                // Filter cached data to only Pro members
                let proMembers = cached.filter { $0.isPro }
                print("✅ Using cached monthly leaderboard (\(proMembers.count) Pro members)")
                return Array(proMembers.prefix(limit))
            }
            struct StepRow: Decodable { let userId: String; let steps: Int; enum CodingKeys: String, CodingKey { case userId = "user_id"; case steps } }
            // Fetch more users initially since we'll filter for Pro members only
            let fetchLimit = limit * 5 // Fetch 5x more to ensure we get enough Pro members
            let rows: [StepRow] = try await supabase
                .from("monthly_steps")
                .select("user_id, steps")
                .eq("month", value: monthKey)
                .order("steps", ascending: false)
                .limit(fetchLimit)
                .execute()
                .value

            var users: [MonthlyUser] = []
            for row in rows {
                if let profile = try? await ProfileService.shared.fetchUserProfile(userId: row.userId) {
                    // Only include Pro members on the leaderboard
                    if profile.isProMember {
                        users.append(MonthlyUser(id: row.userId, username: profile.name, avatarUrl: profile.avatarUrl, steps: row.steps, isPro: profile.isProMember))
                        // Stop once we have enough Pro members
                        if users.count >= limit {
                            break
                        }
                    }
                }
            }
            cache.saveMonthlyLeaderboard(users, monthKey: monthKey)
            print("✅ Filtered to \(users.count) Pro members for monthly leaderboard")
            return users
            
        } catch {
            print("❌ Error fetching top monthly users: \(error)")
            // fallback to cache if available
            let monthKey = Self.currentMonthKey()
            if let cached = cache.getCachedMonthlyLeaderboard(monthKey: monthKey) {
                // Filter cached data to only Pro members
                let proMembers = cached.filter { $0.isPro }
                print("⚠️ Returning cached leaderboard due to error (\(proMembers.count) Pro members)")
                return Array(proMembers.prefix(limit))
            }
            throw error
        }
    }
    
    func fetchMonthlySteps(for userId: String) async -> Int {
        let monthKey = Self.currentMonthKey()
        let cacheKey = "\(userId)_\(monthKey)" as NSString
        if let cached = stepsCache.object(forKey: cacheKey) {
            return cached.intValue
        }
        
        struct Row: Decodable { let steps: Int }
        do {
            let rows: [Row] = try await supabase
                .from("monthly_steps")
                .select("steps")
                .eq("user_id", value: userId)
                .eq("month", value: monthKey)
                .limit(1)
                .execute()
                .value
            let steps = rows.first?.steps ?? 0
            stepsCache.setObject(NSNumber(value: steps), forKey: cacheKey)
            return steps
        } catch {
            print("❌ Error fetching monthly steps for \(userId): \(error)")
            return 0
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
                let distanceKm = winnerEntry.value
                let stepsEstimate = Int(distanceKm * 1300.0) // approx 1300 steps per km
                
                if let profile = try? await ProfileService.shared.fetchUserProfile(userId: userId) {
                    let winner = MonthlyUser(
                        id: userId,
                        username: profile.name,
                        avatarUrl: profile.avatarUrl,
                        steps: stepsEstimate,
                        isPro: profile.isProMember
                    )
                    print("✅ Found last month winner: \(profile.name) with ~\(stepsEstimate) steps")
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

extension MonthlyStatsService {
    static func currentMonthKey() -> String {
        let now = Date()
        let comps = Calendar.current.dateComponents([.year, .month], from: now)
        let y = comps.year ?? 0
        let m = comps.month ?? 0
        return String(format: "%04d-%02d", y, m)
    }
}

