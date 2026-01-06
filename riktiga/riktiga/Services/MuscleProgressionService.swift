import Foundation
import Supabase

// MARK: - Models

struct MuscleLevel: Codable {
    let muscleGroup: String
    var currentXP: Double
    var currentLevel: Int
    var lastTrainedDate: Date
    
    var nextLevelXP: Double {
        return xpRequiredForLevel(currentLevel + 1)
    }
    
    var progressToNextLevel: Double {
        let currentLevelXP = xpRequiredForLevel(currentLevel)
        let nextLevelXP = xpRequiredForLevel(currentLevel + 1)
        let xpInCurrentLevel = currentXP - currentLevelXP
        let xpNeededForLevel = nextLevelXP - currentLevelXP
        return xpInCurrentLevel / xpNeededForLevel
    }
    
    var color: (red: Double, green: Double, blue: Double) {
        return colorForLevel(currentLevel)
    }
    
    private func xpRequiredForLevel(_ level: Int) -> Double {
        return 10.0 * pow(Double(level), 1.5)
    }
    
    private func colorForLevel(_ level: Int) -> (red: Double, green: Double, blue: Double) {
        switch level {
        case 0...20:
            // Ljusgrå → Ljusröd
            let progress = Double(level) / 20.0
            return (
                0.7 + (0.9 - 0.7) * progress,
                0.7 - (0.7 - 0.4) * progress,
                0.7 - (0.7 - 0.3) * progress
            )
        case 21...40:
            // Ljusröd → Röd
            let progress = Double(level - 20) / 20.0
            return (
                0.9,
                0.4 - (0.4 - 0.2) * progress,
                0.3 - (0.3 - 0.2) * progress
            )
        case 41...60:
            // Röd → Orange
            let progress = Double(level - 40) / 20.0
            return (
                0.9,
                0.2 + (0.5 - 0.2) * progress,
                0.2
            )
        case 61...80:
            // Orange → Mörkorange
            let progress = Double(level - 60) / 20.0
            return (
                0.9 + (1.0 - 0.9) * progress,
                0.5 + (0.4 - 0.5) * progress,
                0.2 - (0.2 - 0.0) * progress
            )
        case 81...95:
            // Mörkorange → Guld
            let progress = Double(level - 80) / 15.0
            return (
                1.0,
                0.4 + (0.84 - 0.4) * progress,
                0.0 + (0.0 - 0.0) * progress
            )
        case 96...100:
            // GULD ✨
            return (1.0, 0.84, 0.0)
        default:
            return (0.7, 0.7, 0.7)
        }
    }
}

struct ExerciseXPGain {
    let muscleGroups: [String]
    let xpGained: Double
    let bonuses: [String]
}

// MARK: - Service

class MuscleProgressionService {
    static let shared = MuscleProgressionService()
    private init() {}
    
    private let userDefaults = UserDefaults.standard
    private let muscleProgressKey = "muscle_progression_data"
    
    // All tracked muscle groups
    let allMuscleGroups = [
        "Bröst", "Rygg", "Axlar", "Biceps", "Triceps",
        "Mage", "Ben", "Vader", "Rumpa"
    ]
    
    // MARK: - Load/Save
    
    func loadMuscleProgress(userId: String) -> [MuscleLevel] {
        let key = "\(muscleProgressKey)_\(userId)"
        
        if let data = userDefaults.data(forKey: key),
           let decoded = try? JSONDecoder().decode([MuscleLevel].self, from: data) {
            return applyDecay(to: decoded)
        }
        
        // Initialize new user with level 0
        return allMuscleGroups.map { muscle in
            MuscleLevel(
                muscleGroup: muscle,
                currentXP: 0,
                currentLevel: 0,
                lastTrainedDate: Date.distantPast
            )
        }
    }
    
    func saveMuscleProgress(userId: String, progress: [MuscleLevel]) {
        let key = "\(muscleProgressKey)_\(userId)"
        
        if let encoded = try? JSONEncoder().encode(progress) {
            userDefaults.set(encoded, forKey: key)
        }
    }
    
    // MARK: - XP Calculation
    
    func processGymSession(
        userId: String,
        exercises: [GymExercisePost],
        sessionDate: Date = Date()
    ) -> [ExerciseXPGain] {
        var progress = loadMuscleProgress(userId: userId)
        var xpGains: [ExerciseXPGain] = []
        
        for exercise in exercises {
            let gain = calculateXPForExercise(
                exercise: exercise,
                currentProgress: progress,
                sessionDate: sessionDate
            )
            
            // Apply XP to muscles
            for muscle in gain.muscleGroups {
                if let index = progress.firstIndex(where: { $0.muscleGroup == muscle }) {
                    var muscleLevel = progress[index]
                    muscleLevel.currentXP += gain.xpGained
                    muscleLevel.lastTrainedDate = sessionDate
                    
                    // Level up if needed
                    while muscleLevel.currentXP >= xpRequiredForLevel(muscleLevel.currentLevel + 1) {
                        muscleLevel.currentLevel += 1
                        if muscleLevel.currentLevel >= 100 {
                            muscleLevel.currentLevel = 100
                            break
                        }
                    }
                    
                    progress[index] = muscleLevel
                }
            }
            
            xpGains.append(gain)
        }
        
        saveMuscleProgress(userId: userId, progress: progress)
        return xpGains
    }
    
    private func calculateXPForExercise(
        exercise: GymExercisePost,
        currentProgress: [MuscleLevel],
        sessionDate: Date
    ) -> ExerciseXPGain {
        let muscles = mapCategoryToMuscles(exercise.category ?? "")
        guard !muscles.isEmpty else {
            return ExerciseXPGain(muscleGroups: [], xpGained: 0, bonuses: [])
        }
        
        // Base XP = (Sets × Avg Reps × Compound Multiplier) / 10
        let totalReps = exercise.reps.reduce(0, +)
        let avgReps = Double(totalReps) / Double(exercise.sets)
        let compoundMultiplier = isCompoundLift(exercise.category ?? "") ? 1.5 : 1.0
        
        var baseXP = (Double(exercise.sets) * avgReps * compoundMultiplier) / 10.0
        var bonuses: [String] = []
        
        // Bonus 1: Recovery Window (30-72h since last trained)
        for muscle in muscles {
            if let muscleLevel = currentProgress.first(where: { $0.muscleGroup == muscle }) {
                let hoursSinceLastTrain = sessionDate.timeIntervalSince(muscleLevel.lastTrainedDate) / 3600
                if hoursSinceLastTrain >= 30 && hoursSinceLastTrain <= 72 {
                    baseXP *= 1.1
                    bonuses.append("Recovery Window")
                    break // Only apply once
                }
            }
        }
        
        // Bonus 2: Weak Point Training (lowest level muscle)
        if let lowestLevel = currentProgress.min(by: { $0.currentLevel < $1.currentLevel }),
           muscles.contains(lowestLevel.muscleGroup) {
            baseXP *= 1.2
            bonuses.append("Weak Point")
        }
        
        return ExerciseXPGain(
            muscleGroups: muscles,
            xpGained: baseXP,
            bonuses: bonuses
        )
    }
    
    // MARK: - Decay System
    
    private func applyDecay(to progress: [MuscleLevel]) -> [MuscleLevel] {
        let now = Date()
        
        return progress.map { muscle in
            var updated = muscle
            let daysSinceLastTrain = now.timeIntervalSince(muscle.lastTrainedDate) / (24 * 3600)
            
            // No decay for first 14 days
            guard daysSinceLastTrain > 14 else { return updated }
            
            // -2% per week after 14 days
            let weeksOfDecay = (daysSinceLastTrain - 14) / 7
            let decayMultiplier = pow(0.98, weeksOfDecay)
            
            // Calculate decayed XP
            let minXP = xpRequiredForLevel(muscle.currentLevel / 2) // Can't go below 50% of current level
            let decayedXP = max(minXP, muscle.currentXP * decayMultiplier)
            
            updated.currentXP = decayedXP
            
            // Recalculate level based on decayed XP
            while updated.currentLevel > 0 && decayedXP < xpRequiredForLevel(updated.currentLevel) {
                updated.currentLevel -= 1
            }
            
            return updated
        }
    }
    
    // MARK: - Helpers
    
    private func xpRequiredForLevel(_ level: Int) -> Double {
        return 10.0 * pow(Double(level), 1.5)
    }
    
    private func isCompoundLift(_ category: String) -> Bool {
        let lower = category.lowercased()
        let compoundCategories = ["bröst", "rygg", "ben", "lår", "chest", "back", "legs", "quad"]
        return compoundCategories.contains { lower.contains($0) }
    }
    
    private func mapCategoryToMuscles(_ category: String) -> [String] {
        let lower = category.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        
        if lower == "bröst" || lower.contains("bröst") || lower.contains("chest") {
            return ["Bröst"]
        }
        if lower == "rygg" || lower.contains("rygg") || lower.contains("back") {
            return ["Rygg"]
        }
        if lower == "axlar" || lower.contains("axl") || lower.contains("shoulder") {
            return ["Axlar"]
        }
        if lower == "överarmar" || lower.contains("överarm") {
            return ["Biceps", "Triceps"]
        }
        if lower.contains("bicep") {
            return ["Biceps"]
        }
        if lower.contains("tricep") {
            return ["Triceps"]
        }
        if lower == "midja" || lower.contains("midja") || lower.contains("mage") || lower.contains("abs") {
            return ["Mage"]
        }
        if lower == "lår" || lower.contains("lår") || lower.contains("quad") || lower == "ben" {
            return ["Ben"]
        }
        if lower == "underben" || lower.contains("underben") || lower.contains("vader") || lower.contains("calv") {
            return ["Vader"]
        }
        if lower.contains("rumpa") || lower.contains("glute") || lower.contains("sits") {
            return ["Rumpa"]
        }
        
        return []
    }
    
    // MARK: - Overall Score
    
    func calculateTotalStrengthScore(userId: String) -> Int {
        let progress = loadMuscleProgress(userId: userId)
        let totalLevels = progress.reduce(0) { $0 + $1.currentLevel }
        let maxPossible = allMuscleGroups.count * 100
        return Int((Double(totalLevels) / Double(maxPossible)) * 100)
    }
    
    // MARK: - Migration (process historical data)
    
    func migrateHistoricalData(userId: String) async {
        // Check if migration already done
        let migrationKey = "muscle_progression_migrated_\(userId)"
        if UserDefaults.standard.bool(forKey: migrationKey) {
            print("💪 Migration already completed for user \(userId)")
            return
        }
        
        print("🔄 Starting historical data migration...")
        print("💪 Loading user posts from database...")
        
        // Load posts directly from Supabase
        let supabase = SupabaseConfig.supabase
        
        do {
            print("💪 Fetching from workout_posts for user: \(userId)")
            
            // Use wildcard to get all columns (exercises might be named differently)
            let response: [SocialWorkoutPost] = try await supabase
                .from("workout_posts")
                .select("*")
                .eq("user_id", value: userId)
                .order("created_at", ascending: true)
                .execute()
                .value
            
            print("💪 Received \(response.count) total posts from database")
            
            // Get all gym posts sorted by date (oldest first)
            let gymPosts = response.filter { post in
                let activityType = post.activityType.lowercased()
                let isGym = activityType.contains("gym") || activityType.contains("gympass")
                if isGym {
                    print("   - Found gym post: \(post.title) (\(post.activityType))")
                    if post.exercises != nil {
                        print("     ✅ Has exercises")
                    } else {
                        print("     ❌ No exercises")
                    }
                }
                return isGym
            }
            
            print("💪 Found \(gymPosts.count) historical gym sessions")
            
            let gymPostsWithExercises = gymPosts.filter { $0.exercises != nil }
            print("💪 Of which \(gymPostsWithExercises.count) have exercise data")
            
            // Process each post chronologically
            for (index, post) in gymPosts.enumerated() {
                guard let exercises = post.exercises else { continue }
                let postDate = parseDate(post.createdAt)
                
                let xpGains = processGymSession(
                    userId: userId,
                    exercises: exercises,
                    sessionDate: postDate
                )
                
                if (index + 1) % 10 == 0 {
                    print("💪 Processed \(index + 1)/\(gymPosts.count) sessions...")
                }
            }
            
            // Mark migration as complete
            UserDefaults.standard.set(true, forKey: migrationKey)
            print("✅ Migration complete! Processed \(gymPosts.count) gym sessions")
            
            // Log final progress
            let finalProgress = loadMuscleProgress(userId: userId)
            for muscle in finalProgress {
                print("   \(muscle.muscleGroup): Level \(muscle.currentLevel) (\(Int(muscle.currentXP)) XP)")
            }
            
        } catch {
            print("❌ Migration failed: \(error)")
            print("   Error type: \(type(of: error))")
            
            // Try alternative approach: fetch raw data and parse manually
            print("🔄 Trying alternative approach with raw JSON...")
            
            do {
                // Get raw JSON response
                struct WorkoutPostMinimal: Codable {
                    let id: String
                    let user_id: String
                    let activity_type: String
                    let title: String
                    let created_at: String
                    // No exercises field - we'll check if posts exist at all
                }
                
                let minimalPosts: [WorkoutPostMinimal] = try await supabase
                    .from("workout_posts")
                    .select("id, user_id, activity_type, title, created_at")
                    .eq("user_id", value: userId)
                    .execute()
                    .value
                
                print("💪 Found \(minimalPosts.count) total posts (minimal fetch)")
                
                let gymPostsMinimal = minimalPosts.filter { post in
                    let activityType = post.activity_type.lowercased()
                    return activityType.contains("gym") || activityType.contains("gympass")
                }
                
                print("💪 Of which \(gymPostsMinimal.count) are gym posts")
                print("❌ Cannot migrate without exercises data")
                print("   The 'exercises' column does not exist in workout_posts table")
                print("   Gym workouts need to be saved with exercise data for Strength Score to work")
                
            } catch let alternativeError {
                print("❌ Alternative fetch also failed: \(alternativeError)")
            }
        }
    }
    
    private func parseDate(_ dateString: String) -> Date {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: dateString) {
            return date
        }
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: dateString) ?? Date.distantPast
    }
    
    // MARK: - Debug/Reset
    
    func resetMigration(userId: String) {
        let migrationKey = "muscle_progression_migrated_\(userId)"
        UserDefaults.standard.removeObject(forKey: migrationKey)
        print("🔄 Migration reset for user \(userId)")
    }
    
    func resetAllProgress(userId: String) {
        let progressKey = "muscle_progression_data_\(userId)"
        let migrationKey = "muscle_progression_migrated_\(userId)"
        UserDefaults.standard.removeObject(forKey: progressKey)
        UserDefaults.standard.removeObject(forKey: migrationKey)
        print("🔄 All progress reset for user \(userId)")
    }
}

