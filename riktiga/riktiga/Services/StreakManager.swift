import Foundation

struct StreakInfo {
    let consecutiveDays: Int
    let completedDaysThisWeek: Int
    let lastWorkoutDate: Date?
    
    var streakTitle: String {
        if consecutiveDays == 1 {
            return "\(consecutiveDays) dag i rad"
        }
        return "\(consecutiveDays) dagar i rad"
    }
}

final class StreakManager {
    static let shared = StreakManager()
    
    private let defaults = UserDefaults.standard
    private let consecutiveDaysKey = "streakConsecutiveDays"
    private let lastWorkoutDateKey = "streakLastWorkoutDate"
    
    private init() {}
    
    func getCurrentStreak() -> StreakInfo {
        let consecutiveDays = defaults.integer(forKey: consecutiveDaysKey)
        let lastWorkoutDate = defaults.object(forKey: lastWorkoutDateKey) as? Date
        let completedDaysThisWeek = calculateCompletedDaysThisWeek()
        
        return StreakInfo(
            consecutiveDays: consecutiveDays,
            completedDaysThisWeek: completedDaysThisWeek,
            lastWorkoutDate: lastWorkoutDate
        )
    }
    
    func registerWorkoutCompletion() {
        let calendar = Calendar.current
        let now = Date()
        let today = calendar.startOfDay(for: now)
        
        // Get last workout date
        let lastWorkoutDate = defaults.object(forKey: lastWorkoutDateKey) as? Date
        let lastWorkoutDay = lastWorkoutDate != nil ? calendar.startOfDay(for: lastWorkoutDate!) : nil
        
        // Check if already worked out today
        if let lastDay = lastWorkoutDay, calendar.isDate(lastDay, inSameDayAs: today) {
            print("ℹ️ Already worked out today, streak unchanged")
            return
        }
        
        // Check if yesterday
        var currentStreak = defaults.integer(forKey: consecutiveDaysKey)
        
        if let lastDay = lastWorkoutDay {
            if let daysBetween = calendar.dateComponents([.day], from: lastDay, to: today).day {
                if daysBetween == 1 {
                    // Consecutive day - increment streak
                    currentStreak += 1
                    print("✅ Consecutive day! Streak: \(currentStreak)")
                } else if daysBetween > 1 {
                    // Streak broken - reset to 1
                    currentStreak = 1
                    print("💔 Streak broken, starting fresh: \(currentStreak)")
                }
            }
        } else {
            // First workout ever
            currentStreak = 1
            print("🎉 First workout! Streak: \(currentStreak)")
        }
        
        // Save new streak and date
        defaults.set(currentStreak, forKey: consecutiveDaysKey)
        defaults.set(today, forKey: lastWorkoutDateKey)
        
        print("✅ Streak updated: \(currentStreak) days")
    }
    
    private func calculateCompletedDaysThisWeek() -> Int {
        let calendar = Calendar.current
        let now = Date()
        
        guard let lastWorkoutDate = defaults.object(forKey: lastWorkoutDateKey) as? Date else {
            return 0
        }
        
        // Get start of current week (Monday)
        let weekday = calendar.component(.weekday, from: now)
        let daysFromMonday = (weekday + 5) % 7 // Convert Sunday=1 to Monday=0
        guard let weekStart = calendar.date(byAdding: .day, value: -daysFromMonday, to: calendar.startOfDay(for: now)) else {
            return 0
        }
        
        // Count days with workouts this week
        var count = 0
        let consecutiveDays = defaults.integer(forKey: consecutiveDaysKey)
        let lastWorkoutDay = calendar.startOfDay(for: lastWorkoutDate)
        
        // Go backwards from last workout date and count days in this week
        for i in 0..<consecutiveDays {
            if let checkDate = calendar.date(byAdding: .day, value: -i, to: lastWorkoutDay),
               checkDate >= weekStart {
                count += 1
            } else {
                break
            }
        }
        
        return count
    }
    
    func resetStreak() {
        defaults.removeObject(forKey: consecutiveDaysKey)
        defaults.removeObject(forKey: lastWorkoutDateKey)
        print("🔄 Streak reset")
    }
}
