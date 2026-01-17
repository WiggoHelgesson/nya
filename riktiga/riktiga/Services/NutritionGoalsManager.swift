import Foundation

// MARK: - Nutrition Goals Manager
// Handles user-specific nutrition goals storage in UserDefaults

class NutritionGoalsManager {
    static let shared = NutritionGoalsManager()
    
    private init() {}
    
    // MARK: - Key Generation
    private func key(for goal: String, userId: String) -> String {
        // Always use lowercase userId to ensure consistency
        return "\(goal)_\(userId.lowercased())"
    }
    
    // MARK: - Save Goals
    func saveGoals(
        calories: Int,
        protein: Int,
        carbs: Int,
        fat: Int,
        userId: String
    ) {
        UserDefaults.standard.set(calories, forKey: key(for: "dailyCaloriesGoal", userId: userId))
        UserDefaults.standard.set(protein, forKey: key(for: "dailyProteinGoal", userId: userId))
        UserDefaults.standard.set(carbs, forKey: key(for: "dailyCarbsGoal", userId: userId))
        UserDefaults.standard.set(fat, forKey: key(for: "dailyFatGoal", userId: userId))
        
        // Also save the userId to track the current user
        UserDefaults.standard.set(userId, forKey: "currentNutritionUserId")
        
        print("✅ Nutrition goals saved for user: \(userId)")
    }
    
    // MARK: - Load Goals
    func loadGoals(userId: String) -> (calories: Int, protein: Int, carbs: Int, fat: Int)? {
        let caloriesKey = key(for: "dailyCaloriesGoal", userId: userId)
        
        // Check if goals exist for this user
        guard UserDefaults.standard.object(forKey: caloriesKey) != nil else {
            return nil
        }
        
        let calories = UserDefaults.standard.integer(forKey: key(for: "dailyCaloriesGoal", userId: userId))
        let protein = UserDefaults.standard.integer(forKey: key(for: "dailyProteinGoal", userId: userId))
        let carbs = UserDefaults.standard.integer(forKey: key(for: "dailyCarbsGoal", userId: userId))
        let fat = UserDefaults.standard.integer(forKey: key(for: "dailyFatGoal", userId: userId))
        
        return (calories, protein, carbs, fat)
    }
    
    // MARK: - Check if onboarding completed
    func hasCompletedOnboarding(userId: String) -> Bool {
        let caloriesKey = key(for: "dailyCaloriesGoal", userId: userId)
        if let value = UserDefaults.standard.object(forKey: caloriesKey) as? Int {
            return value > 0
        }
        return false
    }
    
    // MARK: - Clear Goals (for logout)
    func clearCurrentUserGoals() {
        UserDefaults.standard.removeObject(forKey: "currentNutritionUserId")
    }
    
    // MARK: - Get individual goals
    func getCaloriesGoal(userId: String) -> Int {
        return UserDefaults.standard.integer(forKey: key(for: "dailyCaloriesGoal", userId: userId))
    }
    
    func getProteinGoal(userId: String) -> Int {
        return UserDefaults.standard.integer(forKey: key(for: "dailyProteinGoal", userId: userId))
    }
    
    func getCarbsGoal(userId: String) -> Int {
        return UserDefaults.standard.integer(forKey: key(for: "dailyCarbsGoal", userId: userId))
    }
    
    func getFatGoal(userId: String) -> Int {
        return UserDefaults.standard.integer(forKey: key(for: "dailyFatGoal", userId: userId))
    }
}


