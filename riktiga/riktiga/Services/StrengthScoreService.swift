import Foundation

struct StrengthScore {
    let totalScore: Int // 0-100
    let level: StrengthLevel
    let pointsToNextLevel: Int
    let muscleProgress: [MuscleLevel]
    let focusMuscle: String?
    let totalXP: Double
    let achievements: [String]
}

enum StrengthLevel: String {
    case beginner = "Nybörjare"
    case novice = "Grundnivå"
    case intermediate = "Medel"
    case advanced = "Avancerad"
    case expert = "Expert"
    
    var range: ClosedRange<Int> {
        switch self {
        case .beginner: return 0...15
        case .novice: return 16...35
        case .intermediate: return 36...60
        case .advanced: return 61...85
        case .expert: return 86...100
        }
    }
    
    var color: (red: Double, green: Double, blue: Double) {
        switch self {
        case .beginner: return (0.9, 0.4, 0.3)
        case .novice: return (0.9, 0.6, 0.3)
        case .intermediate: return (0.9, 0.8, 0.3)
        case .advanced: return (0.6, 0.8, 0.4)
        case .expert: return (1.0, 0.84, 0.0) // Gold
        }
    }
}

class StrengthScoreService {
    static let shared = StrengthScoreService()
    private init() {}
    
    private let progressionService = MuscleProgressionService.shared
    
    func calculateStrengthScore(userId: String, from posts: [SocialWorkoutPost]) async -> StrengthScore {
        // Migrate historical data if needed (only runs once)
        await progressionService.migrateHistoricalData(userId: userId)
        
        // Load current muscle progression
        let muscleProgress = progressionService.loadMuscleProgress(userId: userId)
        
        // Calculate total score from muscle levels
        let totalLevels = muscleProgress.reduce(0) { $0 + $1.currentLevel }
        let maxPossible = progressionService.allMuscleGroups.count * 100
        let totalScore = Int((Double(totalLevels) / Double(maxPossible)) * 100)
        
        // Calculate total XP
        let totalXP = muscleProgress.reduce(0.0) { $0 + $1.currentXP }
        
        // Determine level
        let level: StrengthLevel
        switch totalScore {
        case 0...15: level = .beginner
        case 16...35: level = .novice
        case 36...60: level = .intermediate
        case 61...85: level = .advanced
        default: level = .expert
        }
        
        // Calculate points to next level
        let pointsToNext: Int
        switch level {
        case .beginner: pointsToNext = 16 - totalScore
        case .novice: pointsToNext = 36 - totalScore
        case .intermediate: pointsToNext = 61 - totalScore
        case .advanced: pointsToNext = 86 - totalScore
        case .expert: pointsToNext = 0
        }
        
        // Find focus muscle (lowest level)
        let focusMuscle = muscleProgress
            .sorted { $0.currentLevel < $1.currentLevel }
            .first?.muscleGroup
        
        // Calculate achievements
        let achievements = calculateAchievements(muscleProgress: muscleProgress, totalScore: totalScore)
        
        return StrengthScore(
            totalScore: totalScore,
            level: level,
            pointsToNextLevel: pointsToNext,
            muscleProgress: muscleProgress,
            focusMuscle: focusMuscle,
            totalXP: totalXP,
            achievements: achievements
        )
    }
    
    private func calculateAchievements(muscleProgress: [MuscleLevel], totalScore: Int) -> [String] {
        var achievements: [String] = []
        
        // First Steps - All muscles level 10+
        if muscleProgress.allSatisfy({ $0.currentLevel >= 10 }) {
            achievements.append("🏆 First Steps")
        }
        
        // Balanced Warrior - All muscles within 15 levels
        if let minLevel = muscleProgress.map({ $0.currentLevel }).min(),
           let maxLevel = muscleProgress.map({ $0.currentLevel }).max(),
           (maxLevel - minLevel) <= 15 {
            achievements.append("💪 Balanced Warrior")
        }
        
        // Power Lifter - Chest/Back/Legs all 80+
        let powerMuscles = muscleProgress.filter { ["Bröst", "Rygg", "Ben"].contains($0.muscleGroup) }
        if powerMuscles.allSatisfy({ $0.currentLevel >= 80 }) {
            achievements.append("⚡ Power Lifter")
        }
        
        // Master - At least one muscle level 100
        if muscleProgress.contains(where: { $0.currentLevel >= 100 }) {
            achievements.append("👑 Master")
        }
        
        // Expert Status - Total score 86+
        if totalScore >= 86 {
            achievements.append("✨ Expert Status")
        }
        
        return achievements
    }
}
