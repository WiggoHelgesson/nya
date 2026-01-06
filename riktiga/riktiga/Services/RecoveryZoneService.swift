import Foundation

// MARK: - Muscle Recovery Data
struct MuscleRecoveryStatus: Identifiable {
    let id = UUID()
    let muscleGroup: String
    let lastTrainedDate: Date
    let recoveryHours: Int // Total recovery time needed
    
    var hoursRemaining: Int {
        let hoursSinceTrained = Int(Date().timeIntervalSince(lastTrainedDate) / 3600)
        return max(0, recoveryHours - hoursSinceTrained)
    }
    
    var isRecovered: Bool {
        hoursRemaining == 0
    }
    
    var timeRemainingText: String {
        let hours = hoursRemaining
        if hours == 0 {
            return "Redo"
        } else if hours < 24 {
            return "\(hours)h kvar"
        } else {
            let days = hours / 24
            let remainingHours = hours % 24
            if remainingHours > 0 {
                return "\(days)d \(remainingHours)h kvar"
            } else {
                return "\(days)d kvar"
            }
        }
    }
    
    var recoveryProgress: Double {
        let hoursSinceTrained = Date().timeIntervalSince(lastTrainedDate) / 3600
        return min(1.0, hoursSinceTrained / Double(recoveryHours))
    }
}

// MARK: - Recovery Zone Service
class RecoveryZoneService {
    static let shared = RecoveryZoneService()
    
    private init() {}
    
    // Recovery time in hours - same for all muscle groups
    private let recoveryHoursForAllMuscles: Int = 30
    
    // All muscle groups we track (Swedish names matching the app)
    let allMuscleGroups = [
        "Övre rygg",
        "Nedre rygg",
        "Bröst",
        "Mage",
        "Triceps",
        "Biceps",
        "Underarmar",
        "Lår",
        "Hamstrings",
        "Rumpa",
        "Vader",
        "Axlar"
    ]
    
    // Map categories from workout posts to our tracked muscle groups
    // These categories come from ExerciseDBExercise.swedishBodyPart:
    // "Rygg", "Cardio", "Bröst", "Underarmar", "Underben", "Nacke", "Axlar", "Överarmar", "Lår", "Midja"
    private func mapCategoryToMuscleGroups(_ category: String) -> [String] {
        let lower = category.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Direct Swedish mappings from ExerciseDBExercise.swedishBodyPart
        if lower == "bröst" || lower.contains("bröst") {
            return ["Bröst"]
        }
        if lower == "rygg" || lower.contains("rygg") {
            return ["Övre rygg", "Nedre rygg"]
        }
        if lower == "axlar" || lower.contains("axl") {
            return ["Axlar"]
        }
        if lower == "överarmar" || lower.contains("överarm") {
            return ["Biceps", "Triceps"]
        }
        if lower == "underarmar" || lower.contains("underarm") {
            return ["Underarmar"]
        }
        if lower == "lår" || lower.contains("lår") {
            return ["Lår", "Hamstrings"]
        }
        if lower == "underben" || lower.contains("underben") {
            return ["Vader"]
        }
        if lower == "midja" || lower.contains("midja") || lower.contains("mage") {
            return ["Mage"]
        }
        
        // Fallback pattern matching for English names or variations
        if lower.contains("chest") || lower.contains("pectorals") {
            return ["Bröst"]
        }
        if lower.contains("back") || lower.contains("lats") {
            return ["Övre rygg", "Nedre rygg"]
        }
        if lower.contains("shoulder") || lower.contains("delt") {
            return ["Axlar"]
        }
        if lower.contains("bicep") {
            return ["Biceps"]
        }
        if lower.contains("tricep") {
            return ["Triceps"]
        }
        if lower.contains("upper arm") {
            return ["Biceps", "Triceps"]
        }
        if lower.contains("forearm") || lower.contains("lower arm") {
            return ["Underarmar"]
        }
        if lower.contains("quad") {
            return ["Lår"]
        }
        if lower.contains("hamstring") {
            return ["Hamstrings"]
        }
        if lower.contains("leg") || lower.contains("upper leg") {
            return ["Lår", "Hamstrings"]
        }
        if lower.contains("lower leg") || lower.contains("calve") || lower.contains("calf") {
            return ["Vader"]
        }
        if lower.contains("glute") || lower.contains("hip") {
            return ["Rumpa"]
        }
        if lower.contains("abs") || lower.contains("core") || lower.contains("waist") {
            return ["Mage"]
        }
        
        print("⚠️ RecoveryZone: Unknown category '\(category)' - not mapped to any muscle group")
        return []
    }
    
    private func getRecoveryHours(for muscleGroup: String) -> Int {
        return recoveryHoursForAllMuscles
    }
    
    /// Parse ISO8601 date string with multiple format support
    private func parseDate(_ dateString: String) -> Date? {
        // Try with fractional seconds first
        let formatterWithFraction = ISO8601DateFormatter()
        formatterWithFraction.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatterWithFraction.date(from: dateString) {
            return date
        }
        
        // Try without fractional seconds
        let formatterWithoutFraction = ISO8601DateFormatter()
        formatterWithoutFraction.formatOptions = [.withInternetDateTime]
        if let date = formatterWithoutFraction.date(from: dateString) {
            return date
        }
        
        // Try basic format
        let basicFormatter = DateFormatter()
        basicFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        basicFormatter.timeZone = TimeZone(identifier: "UTC")
        return basicFormatter.date(from: dateString)
    }
    
    /// Analyze workout posts and return recovery status for each muscle group
    func analyzeRecoveryStatus(from posts: [WorkoutPost]) -> (needsRecovery: [MuscleRecoveryStatus], readyToTrain: [String]) {
        // Get only gym workouts from the last 7 days
        let sevenDaysAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        
        // Filter for gym posts - check both "gym" and "Gympass"
        let recentGymPosts = posts.filter { post in
            let activityLower = post.activityType.lowercased()
            let isGym = activityLower.contains("gym") || activityLower == "gympass"
            let postDate = parseDate(post.createdAt) ?? Date.distantPast
            let isRecent = postDate > sevenDaysAgo
            return isGym && isRecent
        }
        
        print("🏋️ RecoveryZone: Found \(recentGymPosts.count) recent gym posts")
        
        // Track the latest training date for each muscle group
        var muscleLastTrained: [String: Date] = [:]
        
        for post in recentGymPosts {
            guard let exercises = post.exercises else { 
                print("⚠️ RecoveryZone: Post has no exercises")
                continue 
            }
            let postDate = parseDate(post.createdAt) ?? Date()
            
            print("🏋️ RecoveryZone: Processing post with \(exercises.count) exercises from \(post.createdAt)")
            
            for exercise in exercises {
                let category = exercise.category ?? ""
                print("   - Exercise: \(exercise.name), Category: '\(category)'")
                
                let muscleGroups = mapCategoryToMuscleGroups(category)
                print("   - Mapped to muscles: \(muscleGroups)")
                
                for muscle in muscleGroups {
                    if let existingDate = muscleLastTrained[muscle] {
                        // Keep the most recent training date
                        if postDate > existingDate {
                            muscleLastTrained[muscle] = postDate
                        }
                    } else {
                        muscleLastTrained[muscle] = postDate
                    }
                }
            }
        }
        
        print("🏋️ RecoveryZone: Muscles trained: \(muscleLastTrained.keys.sorted())")
        
        // Build recovery status
        var needsRecovery: [MuscleRecoveryStatus] = []
        var readyToTrain: [String] = []
        
        for muscleGroup in allMuscleGroups {
            if let lastTrained = muscleLastTrained[muscleGroup] {
                let recoveryHours = getRecoveryHours(for: muscleGroup)
                let status = MuscleRecoveryStatus(
                    muscleGroup: muscleGroup,
                    lastTrainedDate: lastTrained,
                    recoveryHours: recoveryHours
                )
                
                if status.isRecovered {
                    readyToTrain.append(muscleGroup)
                } else {
                    needsRecovery.append(status)
                }
            } else {
                // Never trained recently = ready to train
                readyToTrain.append(muscleGroup)
            }
        }
        
        // Sort needsRecovery by time remaining (least time first)
        needsRecovery.sort { $0.hoursRemaining < $1.hoursRemaining }
        
        print("🏋️ RecoveryZone: \(needsRecovery.count) need recovery, \(readyToTrain.count) ready to train")
        
        return (needsRecovery, readyToTrain)
    }
    
    /// Get overall recovery status
    func getOverallStatus(needsRecoveryCount: Int, totalMuscles: Int) -> (status: String, message: String) {
        let readyCount = totalMuscles - needsRecoveryCount
        let readyPercentage = Double(readyCount) / Double(totalMuscles)
        
        if readyPercentage >= 0.9 {
            return ("Redo", "Du är utvilad och redo för ett intensivt pass!")
        } else if readyPercentage >= 0.7 {
            return ("Nästan redo", "De flesta muskelgrupper är redo för träning.")
        } else if readyPercentage >= 0.5 {
            return ("Delvis vilad", "Ungefär hälften av muskelgrupperna behöver mer vila.")
        } else {
            return ("Vila", "Många muskelgrupper behöver fortfarande återhämtning.")
        }
    }
}

