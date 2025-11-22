import Foundation
import Supabase

/// Builds context about user's workout data for UPPY AI to analyze
class UppyInsightBuilder {
    static let shared = UppyInsightBuilder()
    private init() {}
    
    /// Generates a personalized insight based on user statistics
    func generateDailyInsight(for user: User?) async -> String {
        guard let user = user else {
            return "Välkommen till Up&Down! //UPPY"
        }
        
        // Gather user statistics
        let xp = user.currentXP
        let level = user.currentLevel
        
        // Calculate XP to next level (assuming 1000 XP per level)
        let xpForNextLevel = (level + 1) * 1000
        let xpRemaining = xpForNextLevel - xp
        
        // Fetch recent workout data (last 60 days for accurate streak)
        let recentWorkouts = await fetchRecentWorkouts(userId: user.id)
        let weeklyDistance = await fetchWeeklyDistance(userId: user.id)
        let monthlySteps = await MonthlyStatsService.shared.fetchMonthlySteps(for: user.id)
        
        // Calculate streak (consecutive days with workouts, going back from today)
        let streak = calculateStreak(from: recentWorkouts)
        
        // Count this week's workouts
        let calendar = Calendar.current
        let now = Date()
        let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? now
        let thisWeekWorkouts = recentWorkouts.filter { workout in
            if let date = ISO8601DateFormatter().date(from: workout.createdAt) {
                return date >= startOfWeek
            }
            return false
        }
        
        // Build context for AI
        let context = buildInsightContext(
            xp: xp,
            level: level,
            xpRemaining: xpRemaining,
            streak: streak,
            weeklyDistance: weeklyDistance,
            monthlySteps: monthlySteps,
            recentWorkoutCount: thisWeekWorkouts.count
        )
        
        // Generate insight using OpenAI
        do {
            let insight = try await UppyChatService.shared.generateInsight(context: context)
            return insight
        } catch {
            print("❌ Failed to generate AI insight: \(error)")
            // Fallback to rule-based insight
            return generateFallbackInsight(
                streak: streak,
                xpRemaining: xpRemaining,
                weeklyDistance: weeklyDistance
            )
        }
    }
    
    private func buildInsightContext(
        xp: Int,
        level: Int,
        xpRemaining: Int,
        streak: Int,
        weeklyDistance: Double,
        monthlySteps: Int,
        recentWorkoutCount: Int
    ) -> String {
        """
        Användarstatistik:
        - Nuvarande XP: \(xp)
        - Nuvarande nivå: \(level)
        - XP kvar till nästa nivå: \(xpRemaining)
        - Nuvarande streak: \(streak) dagar
        - Veckans distans: \(String(format: "%.1f", weeklyDistance)) km
        - Månadens steg: \(monthlySteps)
        - Antal träningspass senaste veckan: \(recentWorkoutCount)
        
        Skapa EN kort, personlig och uppmuntrande mening (max 12 ord) baserat på statistiken.
        Avsluta ALLTID med "//UPPY".
        Exempel:
        - "Du är \(streak) dagar i streak, fortsätt så! //UPPY"
        - "Bara \(xpRemaining) XP kvar till nästa nivå! //UPPY"
        - "Du sprang \(String(format: "%.1f", weeklyDistance)) km denna vecka, grym insats! //UPPY"
        """
    }
    
    private func generateFallbackInsight(streak: Int, xpRemaining: Int, weeklyDistance: Double) -> String {
        let insights = [
            "Du är \(streak) dagar i streak, fortsätt! //UPPY",
            "Bara \(xpRemaining) XP kvar till nästa nivå! //UPPY",
            "Du har tränat bra denna vecka! //UPPY",
            "Keep going, du gör det bra! //UPPY",
            "Stor respekt för ditt engagemang! //UPPY"
        ]
        
        if streak > 0 {
            return "Du är \(streak) dagar i streak, fortsätt! //UPPY"
        } else if xpRemaining < 500 {
            return "Bara \(xpRemaining) XP kvar till nästa nivå! //UPPY"
        } else if weeklyDistance > 10 {
            return "Du sprang \(String(format: "%.1f", weeklyDistance)) km denna vecka! //UPPY"
        }
        
        return insights.randomElement() ?? "Stort lycka till idag! //UPPY"
    }
    
    private func fetchRecentWorkouts(userId: String) async -> [WorkoutPost] {
        do {
            let calendar = Calendar.current
            let now = Date()
            // Fetch last 60 days to calculate accurate streak
            let startDate = calendar.date(byAdding: .day, value: -60, to: now) ?? now
            
            let workouts: [WorkoutPost] = try await SupabaseConfig.supabase
                .from("workout_posts")
                .select("id, user_id, created_at, distance, activity_type")
                .eq("user_id", value: userId)
                .gte("created_at", value: startDate.ISO8601Format())
                .order("created_at", ascending: false)
                .execute()
                .value
            
            return workouts
        } catch {
            print("❌ Error fetching recent workouts: \(error)")
            return []
        }
    }
    
    private func fetchWeeklyDistance(userId: String) async -> Double {
        let workouts = await fetchRecentWorkouts(userId: userId)
        let calendar = Calendar.current
        let now = Date()
        let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? now
        
        // Filter only this week's workouts for distance calculation
        let thisWeekWorkouts = workouts.filter { workout in
            if let date = ISO8601DateFormatter().date(from: workout.createdAt) {
                return date >= startOfWeek
            }
            return false
        }
        
        return thisWeekWorkouts.reduce(0) { $0 + ($1.distance ?? 0) }
    }
    
    private func calculateStreak(from workouts: [WorkoutPost]) -> Int {
        guard !workouts.isEmpty else { return 0 }
        
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        // Group workouts by day
        var daysWithWorkouts = Set<Date>()
        for workout in workouts {
            if let date = ISO8601DateFormatter().date(from: workout.createdAt) {
                let dayStart = calendar.startOfDay(for: date)
                daysWithWorkouts.insert(dayStart)
            }
        }
        
        // Count consecutive days backwards from today
        var streak = 0
        var currentDay = today
        
        while daysWithWorkouts.contains(currentDay) && streak < 365 {
            streak += 1
            currentDay = calendar.date(byAdding: .day, value: -1, to: currentDay) ?? currentDay
        }
        
        return streak
    }
}

