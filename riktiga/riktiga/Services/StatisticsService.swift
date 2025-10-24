import Foundation
import Supabase

struct WeeklyStats {
    let totalDistance: Double
    let dailyStats: [DailyStat]
    let goalProgress: Double
}

struct DailyStat {
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
                .select("id, distance, created_at")
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
}
