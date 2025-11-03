import Foundation
import Supabase
import Combine

struct WeeklyStats: Codable {
    let totalDistance: Double
    let dailyStats: [DailyStat]
    let goalProgress: Double
}

struct DailyStat: Codable {
    let day: String
    let distance: Double
    let isToday: Bool
}

class StatisticsService: ObservableObject {
    static let shared = StatisticsService()
    private let supabase = SupabaseConfig.supabase
    
    @Published var weeklyStats: WeeklyStats?
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private init() {}
    
    func fetchWeeklyStats(userId: String) async {
        DispatchQueue.main.async {
            self.isLoading = true
            self.errorMessage = nil
        }
        
        // Try to load from cache first
        if let cachedStats = AppCacheManager.shared.getCachedWeeklyStats(userId: userId) {
            await MainActor.run {
                self.weeklyStats = cachedStats
                self.isLoading = false
            }
            print("✅ Loaded weekly stats from cache")
        }
        
        do {
            // Hämta alla aktiviteter för användaren från denna vecka
            let calendar = Calendar.current
            let now = Date()
            let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? now
            let endOfWeek = calendar.dateInterval(of: .weekOfYear, for: now)?.end ?? now
            
            print("📊 Fetching stats from \(startOfWeek) to \(endOfWeek)")
            
            // Hämta workout posts från denna vecka
            let workoutPosts: [WorkoutPost] = try await supabase
                .from("workout_posts")
                .select("id, user_id, activity_type, title, distance, duration, created_at")
                .eq("user_id", value: userId)
                .gte("created_at", value: startOfWeek.ISO8601Format())
                .lte("created_at", value: endOfWeek.ISO8601Format())
                .execute()
                .value
            
            print("📊 Found \(workoutPosts.count) workout posts this week")
            
            // Beräkna total distans
            let totalDistance = workoutPosts.reduce(0) { $0 + ($1.distance ?? 0.0) }
            
            // Skapa daglig statistik
            var dailyStats: [DailyStat] = []
            let dayNames = ["Mån", "Tis", "Ons", "Tor", "Fre", "Lör", "Sön"]
            
            for i in 0..<7 {
                let dayDate = calendar.date(byAdding: .day, value: i, to: startOfWeek) ?? startOfWeek
                let dayDistance = workoutPosts
                    .filter { post in
                        if let postDate = ISO8601DateFormatter().date(from: post.createdAt) {
                            return calendar.isDate(postDate, inSameDayAs: dayDate)
                        }
                        return false
                    }
                    .reduce(0) { $0 + ($1.distance ?? 0.0) }
                
                let isToday = calendar.isDate(dayDate, inSameDayAs: now)
                
                dailyStats.append(DailyStat(
                    day: dayNames[i],
                    distance: dayDistance,
                    isToday: isToday
                ))
            }
            
            // Beräkna målprogression (20 km per vecka)
            let goalProgress = min(totalDistance / 20.0, 1.0)
            
            let stats = WeeklyStats(
                totalDistance: totalDistance,
                dailyStats: dailyStats,
                goalProgress: goalProgress
            )
            
            // Save to cache
            AppCacheManager.shared.saveWeeklyStats(stats, userId: userId)
            
            DispatchQueue.main.async {
                self.weeklyStats = stats
                self.isLoading = false
            }
            
        } catch {
            print("❌ Error fetching weekly stats: \(error)")
            DispatchQueue.main.async {
                self.errorMessage = "Kunde inte hämta statistik: \(error.localizedDescription)"
                self.isLoading = false
            }
        }
    }
    
    func fetchMonthlyStats(userId: String, completion: @escaping (MonthlyStats) -> Void) async {
        do {
            // Hämta alla aktiviteter för användaren från denna månad
            let calendar = Calendar.current
            let now = Date()
            let startOfMonth = calendar.dateInterval(of: .month, for: now)?.start ?? now
            let endOfMonth = calendar.dateInterval(of: .month, for: now)?.end ?? now
            
            print("📊 Fetching monthly stats from \(startOfMonth) to \(endOfMonth)")
            
            // Hämta workout posts från denna månad
            let workoutPosts: [WorkoutPost] = try await supabase
                .from("workout_posts")
                .select("id, user_id, activity_type, title, distance, duration, created_at")
                .eq("user_id", value: userId)
                .gte("created_at", value: startOfMonth.ISO8601Format())
                .lte("created_at", value: endOfMonth.ISO8601Format())
                .execute()
                .value
            
            print("📊 Found \(workoutPosts.count) workout posts this month")
            
            // Beräkna total distans
            let totalDistance = workoutPosts.reduce(0) { $0 + ($1.distance ?? 0.0) }
            
            // Dela upp i veckor
            var weeklyStats: [WeeklyStat] = []
            let weekRange = calendar.range(of: .weekOfMonth, in: .month, for: now) ?? (1..<2)
            
            for weekNum in weekRange {
                let weekStart = calendar.date(byAdding: .weekOfMonth, value: weekNum - 1, to: startOfMonth) ?? startOfMonth
                let weekEnd = calendar.date(byAdding: .day, value: 7, to: weekStart) ?? weekStart
                
                let weekDistance = workoutPosts
                    .filter { post in
                        if let postDate = ISO8601DateFormatter().date(from: post.createdAt) {
                            return postDate >= weekStart && postDate < weekEnd
                        }
                        return false
                    }
                    .reduce(0) { $0 + ($1.distance ?? 0.0) }
                
                weeklyStats.append(WeeklyStat(
                    week: "Vecka \(weekNum)",
                    distance: weekDistance
                ))
            }
            
            completion(MonthlyStats(totalDistance: totalDistance, weeklyStats: weeklyStats))
            
        } catch {
            print("❌ Error fetching monthly stats: \(error)")
            completion(MonthlyStats(totalDistance: 0.0, weeklyStats: []))
        }
    }
}

struct MonthlyStats {
    let totalDistance: Double
    let weeklyStats: [WeeklyStat]
}

struct WeeklyStat {
    let week: String
    let distance: Double
}
