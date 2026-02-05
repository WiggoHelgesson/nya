import Foundation
import SwiftUI
import UIKit
import Combine

// MARK: - Achievement Manager
class AchievementManager: ObservableObject {
    static let shared = AchievementManager()
    
    @Published var unlockedAchievements: [Achievement] = []
    @Published var currentlyShowingAchievement: Achievement? = nil
    @Published var showAchievementPopup = false
    
    private let userDefaultsKey = "unlocked_achievements"
    private var currentUserId: String?
    
    private init() {
        loadUnlockedAchievements()
    }
    
    // MARK: - Set Current User
    func setUser(_ userId: String) {
        currentUserId = userId
        loadUnlockedAchievements()
    }
    
    // MARK: - Load/Save Achievements
    private func loadUnlockedAchievements() {
        guard let userId = currentUserId else { return }
        let key = "\(userDefaultsKey)_\(userId)"
        
        if let data = UserDefaults.standard.data(forKey: key),
           let achievements = try? JSONDecoder().decode([Achievement].self, from: data) {
            unlockedAchievements = achievements
            print("📦 Loaded \(achievements.count) unlocked achievements for user \(userId)")
        }
    }
    
    private func saveUnlockedAchievements() {
        guard let userId = currentUserId else { return }
        let key = "\(userDefaultsKey)_\(userId)"
        
        if let data = try? JSONEncoder().encode(unlockedAchievements) {
            UserDefaults.standard.set(data, forKey: key)
            print("💾 Saved \(unlockedAchievements.count) achievements")
        }
    }
    
    // MARK: - Check if Achievement is Unlocked
    func isUnlocked(_ achievementId: String) -> Bool {
        unlockedAchievements.contains { $0.id == achievementId }
    }
    
    // MARK: - Unlock Achievement
    func unlock(_ achievementId: String) {
        // DISABLED: Achievements are turned off
        return
        
        // Check if already unlocked
        // guard !isUnlocked(achievementId) else {
        //     print("⚠️ Achievement \(achievementId) already unlocked")
        //     return
        // }
        // 
        // // Find the achievement
        // guard var achievement = Achievement.getAchievement(id: achievementId) else {
        //     print("❌ Achievement \(achievementId) not found")
        //     return
        // }
        // 
        // // Set unlock date
        // achievement.unlockedAt = Date()
        // 
        // // Add to unlocked list
        // unlockedAchievements.append(achievement)
        // saveUnlockedAchievements()
        // 
        // print("🏆 Achievement unlocked: \(achievement.name)")
        // 
        // // Show the achievement popup
        // DispatchQueue.main.async {
        //     self.showAchievement(achievement)
        // }
    }
    
    // MARK: - Show Achievement Popup
    func showAchievement(_ achievement: Achievement) {
        // DISABLED: Achievement popups are turned off
        return
        
        // Trigger strong haptic feedback
        // triggerAchievementHaptic()
        
        // withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
        //     currentlyShowingAchievement = achievement
        //     showAchievementPopup = true
        // }
    }
    
    // MARK: - Dismiss Achievement Popup
    func dismissAchievement() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            showAchievementPopup = false
        }
        
        // Clear after animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.currentlyShowingAchievement = nil
        }
    }
    
    // MARK: - Haptic Feedback
    private func triggerAchievementHaptic() {
        let heavy = UIImpactFeedbackGenerator(style: .heavy)
        let notification = UINotificationFeedbackGenerator()
        
        heavy.prepare()
        notification.prepare()
        
        // BAM - 3 hårda slag
        heavy.impactOccurred(intensity: 1.0)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            heavy.impactOccurred(intensity: 1.0)
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            heavy.impactOccurred(intensity: 1.0)
            notification.notificationOccurred(.success)
        }
    }
    
    // MARK: - Check Progress and Unlock
    
    /// Check and unlock meal/scan achievements based on count
    func checkMealAchievements(mealCount: Int) {
        // 🍽️ Matloggning med AI
        if mealCount >= 1 && !isUnlocked("first_scan") {
            unlock("first_scan")
        }
        if mealCount >= 3 && !isUnlocked("scans_3") {
            unlock("scans_3")
        }
        if mealCount >= 10 && !isUnlocked("scans_10") {
            unlock("scans_10")
        }
        if mealCount >= 20 && !isUnlocked("scans_20") {
            unlock("scans_20")
        }
        if mealCount >= 30 && !isUnlocked("scans_30") {
            unlock("scans_30")
        }
        if mealCount >= 50 && !isUnlocked("scans_50") {
            unlock("scans_50")
        }
        if mealCount >= 100 && !isUnlocked("scans_100") {
            unlock("scans_100")
        }
    }
    
    /// Check and unlock workout achievements based on count
    func checkWorkoutAchievements(workoutCount: Int) {
        // 🏋️ Träningspass
        if workoutCount >= 1 && !isUnlocked("first_workout") {
            unlock("first_workout")
        }
        if workoutCount >= 3 && !isUnlocked("workouts_3") {
            unlock("workouts_3")
        }
        if workoutCount >= 10 && !isUnlocked("workouts_10") {
            unlock("workouts_10")
        }
        if workoutCount >= 25 && !isUnlocked("workouts_25") {
            unlock("workouts_25")
        }
        if workoutCount >= 50 && !isUnlocked("workouts_50") {
            unlock("workouts_50")
        }
        if workoutCount >= 100 && !isUnlocked("workouts_100") {
            unlock("workouts_100")
        }
    }
    
    /// Check story achievement
    func checkStoryAchievement() {
        if !isUnlocked("first_story") {
            unlock("first_story")
        }
    }
    
    /// Check follower achievement
    func checkFollowerAchievement(followerCount: Int) {
        if followerCount >= 1 && !isUnlocked("first_follower") {
            unlock("first_follower")
        }
    }
    
    // MARK: - Get All Achievements with Status
    func getAllAchievementsWithStatus() -> [Achievement] {
        return Achievement.allAchievements.map { achievement in
            if let unlocked = unlockedAchievements.first(where: { $0.id == achievement.id }) {
                return unlocked
            }
            return achievement
        }
    }
    
    // MARK: - Reset (for testing)
    func resetAllAchievements() {
        guard let userId = currentUserId else { return }
        let key = "\(userDefaultsKey)_\(userId)"
        UserDefaults.standard.removeObject(forKey: key)
        unlockedAchievements = []
        print("🗑️ All achievements reset")
    }
}

