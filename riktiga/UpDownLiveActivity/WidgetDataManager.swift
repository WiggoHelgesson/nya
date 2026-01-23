//
//  WidgetDataManager.swift
//  UpDownLiveActivity
//
//  Shared data manager for widgets to access streak and nutrition data
//

import Foundation
import WidgetKit

// MARK: - Widget Data Manager
struct WidgetDataManager {
    // App Group identifier - must match the one configured in Xcode
    static let appGroupIdentifier = "group.com.bylito.upanddown"
    
    static var sharedDefaults: UserDefaults? {
        UserDefaults(suiteName: appGroupIdentifier)
    }
    
    // MARK: - Streak Data
    static func getCurrentStreak() -> Int {
        // Try shared defaults first, fall back to standard
        if let shared = sharedDefaults {
            let streak = shared.integer(forKey: "widget_current_streak")
            if streak > 0 { return streak }
        }
        return UserDefaults.standard.integer(forKey: "current_streak")
    }
    
    static func hasCompletedToday() -> Bool {
        if let shared = sharedDefaults {
            if let completedDate = shared.object(forKey: "widget_completed_today") as? Date {
                return Calendar.current.isDateInToday(completedDate)
            }
        }
        // Fallback
        if let completedDate = UserDefaults.standard.object(forKey: "completed_today") as? Date {
            return Calendar.current.isDateInToday(completedDate)
        }
        return false
    }
    
    // MARK: - Nutrition Data
    static func getCaloriesGoal() -> Int {
        if let shared = sharedDefaults {
            let goal = shared.integer(forKey: "widget_calories_goal")
            if goal > 0 { return goal }
        }
        return 2000 // Default
    }
    
    static func getCaloriesConsumed() -> Int {
        if let shared = sharedDefaults {
            return shared.integer(forKey: "widget_calories_consumed")
        }
        return 0
    }
    
    static func getProteinGoal() -> Int {
        if let shared = sharedDefaults {
            let goal = shared.integer(forKey: "widget_protein_goal")
            if goal > 0 { return goal }
        }
        return 150 // Default
    }
    
    static func getProteinConsumed() -> Int {
        if let shared = sharedDefaults {
            return shared.integer(forKey: "widget_protein_consumed")
        }
        return 0
    }
    
    static func getCarbsGoal() -> Int {
        if let shared = sharedDefaults {
            let goal = shared.integer(forKey: "widget_carbs_goal")
            if goal > 0 { return goal }
        }
        return 250 // Default
    }
    
    static func getCarbsConsumed() -> Int {
        if let shared = sharedDefaults {
            return shared.integer(forKey: "widget_carbs_consumed")
        }
        return 0
    }
    
    static func getFatGoal() -> Int {
        if let shared = sharedDefaults {
            let goal = shared.integer(forKey: "widget_fat_goal")
            if goal > 0 { return goal }
        }
        return 70 // Default
    }
    
    static func getFatConsumed() -> Int {
        if let shared = sharedDefaults {
            return shared.integer(forKey: "widget_fat_consumed")
        }
        return 0
    }
    
    // MARK: - Calculated Values
    static func getCaloriesLeft() -> Int {
        return max(0, getCaloriesGoal() - getCaloriesConsumed())
    }
    
    static func getProteinLeft() -> Int {
        return max(0, getProteinGoal() - getProteinConsumed())
    }
    
    static func getCarbsLeft() -> Int {
        return max(0, getCarbsGoal() - getCarbsConsumed())
    }
    
    static func getFatLeft() -> Int {
        return max(0, getFatGoal() - getFatConsumed())
    }
    
    static func getCaloriesProgress() -> Double {
        let goal = Double(getCaloriesGoal())
        guard goal > 0 else { return 0 }
        return min(1.0, Double(getCaloriesConsumed()) / goal)
    }
}

// MARK: - Save Widget Data (call from main app)
extension WidgetDataManager {
    static func saveStreakData(currentStreak: Int, completedToday: Bool) {
        guard let shared = sharedDefaults else { return }
        shared.set(currentStreak, forKey: "widget_current_streak")
        if completedToday {
            shared.set(Date(), forKey: "widget_completed_today")
        }
        // Trigger widget refresh
        WidgetCenter.shared.reloadAllTimelines()
    }
    
    static func saveNutritionData(
        caloriesGoal: Int,
        caloriesConsumed: Int,
        proteinGoal: Int,
        proteinConsumed: Int,
        carbsGoal: Int,
        carbsConsumed: Int,
        fatGoal: Int,
        fatConsumed: Int
    ) {
        guard let shared = sharedDefaults else { return }
        shared.set(caloriesGoal, forKey: "widget_calories_goal")
        shared.set(caloriesConsumed, forKey: "widget_calories_consumed")
        shared.set(proteinGoal, forKey: "widget_protein_goal")
        shared.set(proteinConsumed, forKey: "widget_protein_consumed")
        shared.set(carbsGoal, forKey: "widget_carbs_goal")
        shared.set(carbsConsumed, forKey: "widget_carbs_consumed")
        shared.set(fatGoal, forKey: "widget_fat_goal")
        shared.set(fatConsumed, forKey: "widget_fat_consumed")
        // Trigger widget refresh
        WidgetCenter.shared.reloadAllTimelines()
    }
}
