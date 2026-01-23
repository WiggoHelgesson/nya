//
//  WidgetSyncService.swift
//  Up&Down
//
//  Service för att synka data till widgets via App Group
//

import Foundation
import WidgetKit

final class WidgetSyncService {
    static let shared = WidgetSyncService()
    
    // App Group identifier - måste matcha det i widget extension
    private let appGroupIdentifier = "group.com.bylito.upanddown"
    
    private var sharedDefaults: UserDefaults? {
        UserDefaults(suiteName: appGroupIdentifier)
    }
    
    private init() {}
    
    // MARK: - Streak Sync
    
    /// Synka streak data till widgets
    func syncStreakData() {
        guard let shared = sharedDefaults else {
            print("⚠️ Widget sync: Could not access App Group")
            return
        }
        
        let streakInfo = StreakManager.shared.getCurrentStreak()
        
        shared.set(streakInfo.currentStreak, forKey: "widget_current_streak")
        
        if streakInfo.completedToday {
            shared.set(Date(), forKey: "widget_completed_today")
        }
        
        print("📱 Widget sync: Streak = \(streakInfo.currentStreak)")
        
        // Trigger widget refresh
        WidgetCenter.shared.reloadTimelines(ofKind: "StreakWidget")
    }
    
    // MARK: - Nutrition Sync
    
    /// Synka nutrition data till widgets
    func syncNutritionData(
        caloriesGoal: Int,
        caloriesConsumed: Int,
        proteinGoal: Int,
        proteinConsumed: Int,
        carbsGoal: Int,
        carbsConsumed: Int,
        fatGoal: Int,
        fatConsumed: Int
    ) {
        guard let shared = sharedDefaults else {
            print("⚠️ Widget sync: Could not access App Group")
            return
        }
        
        shared.set(caloriesGoal, forKey: "widget_calories_goal")
        shared.set(caloriesConsumed, forKey: "widget_calories_consumed")
        shared.set(proteinGoal, forKey: "widget_protein_goal")
        shared.set(proteinConsumed, forKey: "widget_protein_consumed")
        shared.set(carbsGoal, forKey: "widget_carbs_goal")
        shared.set(carbsConsumed, forKey: "widget_carbs_consumed")
        shared.set(fatGoal, forKey: "widget_fat_goal")
        shared.set(fatConsumed, forKey: "widget_fat_consumed")
        
        print("📱 Widget sync: Calories = \(caloriesConsumed)/\(caloriesGoal)")
        
        // Trigger widget refresh
        WidgetCenter.shared.reloadTimelines(ofKind: "CaloriesWidget")
        WidgetCenter.shared.reloadTimelines(ofKind: "DetailedNutritionWidget")
    }
    
    /// Synka endast målen (utan konsumtion)
    func syncNutritionGoals(
        caloriesGoal: Int,
        proteinGoal: Int,
        carbsGoal: Int,
        fatGoal: Int
    ) {
        guard let shared = sharedDefaults else { return }
        
        shared.set(caloriesGoal, forKey: "widget_calories_goal")
        shared.set(proteinGoal, forKey: "widget_protein_goal")
        shared.set(carbsGoal, forKey: "widget_carbs_goal")
        shared.set(fatGoal, forKey: "widget_fat_goal")
        
        // Trigger widget refresh
        WidgetCenter.shared.reloadTimelines(ofKind: "CaloriesWidget")
        WidgetCenter.shared.reloadTimelines(ofKind: "DetailedNutritionWidget")
    }
    
    /// Synka endast konsumtion
    func syncNutritionConsumed(
        caloriesConsumed: Int,
        proteinConsumed: Int,
        carbsConsumed: Int,
        fatConsumed: Int
    ) {
        guard let shared = sharedDefaults else { return }
        
        shared.set(caloriesConsumed, forKey: "widget_calories_consumed")
        shared.set(proteinConsumed, forKey: "widget_protein_consumed")
        shared.set(carbsConsumed, forKey: "widget_carbs_consumed")
        shared.set(fatConsumed, forKey: "widget_fat_consumed")
        
        // Trigger widget refresh
        WidgetCenter.shared.reloadTimelines(ofKind: "CaloriesWidget")
        WidgetCenter.shared.reloadTimelines(ofKind: "DetailedNutritionWidget")
    }
    
    // MARK: - Refresh All Widgets
    
    /// Uppdatera alla widgets
    func refreshAllWidgets() {
        WidgetCenter.shared.reloadAllTimelines()
    }
}
