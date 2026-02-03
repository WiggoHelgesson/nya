import Foundation

struct StreakInfo {
    let currentStreak: Int
    let longestStreak: Int
    let lastActivityDate: Date?
    let completedToday: Bool
    let completedDaysThisWeek: [Int] // Array of weekday indices (1=Sunday, 2=Monday, etc.)
    
    // Backwards compatibility aliases
    var consecutiveDays: Int { currentStreak }
    
    var streakTitle: String {
        if currentStreak == 1 {
            return "\(currentStreak) dag i rad"
        }
        return "\(currentStreak) dagar i rad"
    }
}

final class StreakManager {
    static let shared = StreakManager()
    
    private let defaults = UserDefaults.standard
    
    // Base keys - user ID will be appended
    private let currentStreakKeyBase = "current_streak"
    private let longestStreakKeyBase = "longest_streak"
    private let lastActivityDateKeyBase = "last_activity_date"
    private let completedTodayKeyBase = "completed_today"
    private let lastCheckedDateKeyBase = "last_checked_date"
    private let completedDatesKeyBase = "completed_dates" // Store all completed dates for week view
    private let lostStreakKeyBase = "lost_streak" // Track when streak was just lost
    private let lostStreakDaysKeyBase = "lost_streak_days" // How many days the lost streak was
    
    // Current user ID - must be set before using
    private var currentUserId: String?
    
    // User-specific keys
    private var currentStreakKey: String { "\(currentStreakKeyBase)_\(currentUserId ?? "unknown")" }
    private var longestStreakKey: String { "\(longestStreakKeyBase)_\(currentUserId ?? "unknown")" }
    private var lastActivityDateKey: String { "\(lastActivityDateKeyBase)_\(currentUserId ?? "unknown")" }
    private var completedTodayKey: String { "\(completedTodayKeyBase)_\(currentUserId ?? "unknown")" }
    private var lastCheckedDateKey: String { "\(lastCheckedDateKeyBase)_\(currentUserId ?? "unknown")" }
    private var completedDatesKey: String { "\(completedDatesKeyBase)_\(currentUserId ?? "unknown")" }
    private var lostStreakKey: String { "\(lostStreakKeyBase)_\(currentUserId ?? "unknown")" }
    private var lostStreakDaysKey: String { "\(lostStreakDaysKeyBase)_\(currentUserId ?? "unknown")" }
    
    private init() {}
    
    /// Set current user ID - call this when user logs in
    func setUser(userId: String) {
        let previousUserId = currentUserId
        currentUserId = userId
        
        // Only check streak if user changed
        if previousUserId != userId {
            checkAndUpdateStreak()
            WidgetSyncService.shared.syncStreakData()
        }
    }
    
    /// Clear user data on logout
    func clearUser() {
        currentUserId = nil
    }
    
    // MARK: - Public Properties
    
    /// Quick access to current streak count
    var currentStreak: Int {
        defaults.integer(forKey: currentStreakKey)
    }
    
    /// Check if streak was just lost (to show StreakLostView)
    var hasJustLostStreak: Bool {
        defaults.bool(forKey: lostStreakKey)
    }
    
    /// Get how many days the lost streak was
    var lostStreakDays: Int {
        defaults.integer(forKey: lostStreakDaysKey)
    }
    
    /// Clear the lost streak flag (after showing StreakLostView)
    func clearLostStreakFlag() {
        defaults.set(false, forKey: lostStreakKey)
        defaults.removeObject(forKey: lostStreakDaysKey)
    }
    
    // MARK: - Public Methods
    
    /// Get current streak info
    func getCurrentStreak() -> StreakInfo {
        let currentStreak = defaults.integer(forKey: currentStreakKey)
        let longestStreak = defaults.integer(forKey: longestStreakKey)
        let lastActivityDate = defaults.object(forKey: lastActivityDateKey) as? Date
        let completedToday = hasCompletedToday()
        let completedDaysThisWeek = getCompletedWeekdays()
        
        return StreakInfo(
            currentStreak: currentStreak,
            longestStreak: longestStreak,
            lastActivityDate: lastActivityDate,
            completedToday: completedToday,
            completedDaysThisWeek: completedDaysThisWeek
        )
    }
    
    /// Get completed weekdays for current week (1=Sunday, 2=Monday, etc.)
    private func getCompletedWeekdays() -> [Int] {
        guard let completedDatesData = defaults.data(forKey: completedDatesKey),
              let completedDates = try? JSONDecoder().decode([Date].self, from: completedDatesData) else {
            return []
        }
        
        let calendar = Calendar.current
        let today = Date()
        
        // Get start of current week (Monday)
        let weekday = calendar.component(.weekday, from: today)
        let daysFromMonday = (weekday + 5) % 7
        guard let weekStart = calendar.date(byAdding: .day, value: -daysFromMonday, to: calendar.startOfDay(for: today)) else {
            return []
        }
        
        // Get end of week (Sunday)
        guard let weekEnd = calendar.date(byAdding: .day, value: 7, to: weekStart) else {
            return []
        }
        
        // Filter dates within this week and get weekday indices
        var weekdays: [Int] = []
        for date in completedDates {
            let dayStart = calendar.startOfDay(for: date)
            if dayStart >= weekStart && dayStart < weekEnd {
                let wd = calendar.component(.weekday, from: date)
                if !weekdays.contains(wd) {
                    weekdays.append(wd)
                }
            }
        }
        
        return weekdays
    }
    
    /// Register activity completion (workout OR meal logged)
    /// Call this when user completes a workout or logs a meal with AI
    func registerActivityCompletion() {
        guard currentUserId != nil else {
            print("⚠️ No user ID set for streak tracking")
            return
        }
        
        let calendar = Calendar.current
        let now = Date()
        let today = calendar.startOfDay(for: now)
        
        // Check if already completed today
        if hasCompletedToday() {
            print("ℹ️ Already completed activity today, streak unchanged")
            return
        }
        
        // Get last activity date
        let lastActivityDate = defaults.object(forKey: lastActivityDateKey) as? Date
        let lastActivityDay = lastActivityDate != nil ? calendar.startOfDay(for: lastActivityDate!) : nil
        
        var currentStreak = defaults.integer(forKey: currentStreakKey)
        
        if let lastDay = lastActivityDay {
            if let daysBetween = calendar.dateComponents([.day], from: lastDay, to: today).day {
                if daysBetween == 0 {
                    // Same day - should have been caught above
                    return
                } else if daysBetween == 1 {
                    // Consecutive day - increment streak
                    currentStreak += 1
                    print("🔥 Consecutive day! Streak: \(currentStreak)")
                } else {
                    // Missed one or more days - streak broken, start fresh
                    currentStreak = 1
                    print("💔 Streak broken (missed \(daysBetween - 1) days), starting fresh")
                }
            }
        } else {
            // First activity ever
            currentStreak = 1
            print("🎉 First activity! Streak: \(currentStreak)")
        }
        
        // Update longest streak if needed
        var longestStreak = defaults.integer(forKey: longestStreakKey)
        if currentStreak > longestStreak {
            longestStreak = currentStreak
            defaults.set(longestStreak, forKey: longestStreakKey)
            print("🏆 New longest streak: \(longestStreak)")
        }
        
        // Save current streak and date
        defaults.set(currentStreak, forKey: currentStreakKey)
        defaults.set(today, forKey: lastActivityDateKey)
        defaults.set(today, forKey: completedTodayKey)
        
        // Save completed date to list for week view
        saveCompletedDate(today)
        
        print("✅ Streak updated: \(currentStreak) days (longest: \(longestStreak))")
        
        // Check streak achievements
        checkStreakAchievements(streak: currentStreak)
        
        // Sync to widgets
        WidgetSyncService.shared.syncStreakData()
        
        // Post notification for UI updates
        NotificationCenter.default.post(name: .streakUpdated, object: nil)
    }
    
    /// Save a completed date to the list
    private func saveCompletedDate(_ date: Date) {
        var completedDates: [Date] = []
        
        if let data = defaults.data(forKey: completedDatesKey),
           let decoded = try? JSONDecoder().decode([Date].self, from: data) {
            completedDates = decoded
        }
        
        // Add today if not already present
        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: date)
        if !completedDates.contains(where: { calendar.isDate($0, inSameDayAs: dayStart) }) {
            completedDates.append(dayStart)
        }
        
        // Keep only last 60 days to avoid unlimited growth
        let cutoffDate = calendar.date(byAdding: .day, value: -60, to: Date()) ?? Date()
        completedDates = completedDates.filter { $0 >= cutoffDate }
        
        // Save
        if let encoded = try? JSONEncoder().encode(completedDates) {
            defaults.set(encoded, forKey: completedDatesKey)
        }
    }
    
    /// Check if user has completed an activity today
    func hasCompletedToday() -> Bool {
        guard currentUserId != nil else { return false }
        guard let completedDate = defaults.object(forKey: completedTodayKey) as? Date else {
            return false
        }
        return Calendar.current.isDateInToday(completedDate)
    }
    
    /// Check streak status on app launch - break streak if yesterday was missed
    func checkAndUpdateStreak() {
        guard currentUserId != nil else {
            return // No user logged in
        }
        
        let calendar = Calendar.current
        let now = Date()
        let today = calendar.startOfDay(for: now)
        
        // Check if we already checked today
        if let lastChecked = defaults.object(forKey: lastCheckedDateKey) as? Date,
           calendar.isDateInToday(lastChecked) {
            return // Already checked today
        }
        
        // Mark that we checked today
        defaults.set(now, forKey: lastCheckedDateKey)
        
        // Get last activity date
        guard let lastActivityDate = defaults.object(forKey: lastActivityDateKey) as? Date else {
            return // No previous activity
        }
        
        let lastActivityDay = calendar.startOfDay(for: lastActivityDate)
        
        // Calculate days since last activity
        if let daysSinceActivity = calendar.dateComponents([.day], from: lastActivityDay, to: today).day {
            if daysSinceActivity > 1 {
                // Missed one or more days - streak is broken
                let oldStreak = defaults.integer(forKey: currentStreakKey)
                defaults.set(0, forKey: currentStreakKey)
                print("💔 Streak broken on app launch (missed \(daysSinceActivity - 1) days). Was: \(oldStreak)")
                
                // Set lost streak flag to show StreakLostView (only if they had a meaningful streak)
                if oldStreak >= 2 {
                    defaults.set(true, forKey: lostStreakKey)
                    defaults.set(oldStreak, forKey: lostStreakDaysKey)
                    print("📢 Lost streak flag set: \(oldStreak) days")
                    
                    // Post notification for UI to show StreakLostView
                    NotificationCenter.default.post(name: .streakLost, object: nil, userInfo: ["lostDays": oldStreak])
                }
                
                // Send push notification about broken streak (only if they had a streak)
                if oldStreak > 0 {
                    NotificationManager.shared.sendStreakBrokenNotification()
                }
                
                // Sync to widgets
                WidgetSyncService.shared.syncStreakData()
                
                // Post notification
                NotificationCenter.default.post(name: .streakUpdated, object: nil)
            }
        }
    }
    
    /// Reset streak completely (for testing)
    func resetStreak() {
        guard currentUserId != nil else { return }
        defaults.removeObject(forKey: currentStreakKey)
        defaults.removeObject(forKey: longestStreakKey)
        defaults.removeObject(forKey: lastActivityDateKey)
        defaults.removeObject(forKey: completedTodayKey)
        defaults.removeObject(forKey: lastCheckedDateKey)
        defaults.removeObject(forKey: completedDatesKey)
        print("🔄 Streak completely reset for user \(currentUserId ?? "unknown")")
        
        // Sync to widgets
        WidgetSyncService.shared.syncStreakData()
        
        NotificationCenter.default.post(name: .streakUpdated, object: nil)
    }
    
    /// Check and unlock streak achievements
    private func checkStreakAchievements(streak: Int) {
        if streak >= 7 {
            AchievementManager.shared.unlock("streak_7")
        }
        if streak >= 30 {
            AchievementManager.shared.unlock("streak_30")
        }
    }
}

// MARK: - Notification Names
extension Notification.Name {
    static let streakUpdated = Notification.Name("streakUpdated")
    static let streakLost = Notification.Name("streakLost")
    static let userBecamePro = Notification.Name("userBecamePro")
}
