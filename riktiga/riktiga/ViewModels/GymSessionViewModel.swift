import Foundation
import SwiftUI
import Combine

// MARK: - Gym XP Daily Tracker
// Tracks gym XP per day to enforce daily limit of 30 points

class GymXPTracker {
    static let shared = GymXPTracker()
    
    private let dailyXPKey = "GymDailyXP"
    private let dateKey = "GymDailyXPDate"
    
    private init() {}
    
    /// Get today's accumulated gym XP
    func getTodayGymXP() -> Int {
        let storedDate = UserDefaults.standard.string(forKey: dateKey) ?? ""
        let todayString = dateString(for: Date())
        
        // Reset if it's a new day
        if storedDate != todayString {
            UserDefaults.standard.set(0, forKey: dailyXPKey)
            UserDefaults.standard.set(todayString, forKey: dateKey)
            return 0
        }
        
        return UserDefaults.standard.integer(forKey: dailyXPKey)
    }
    
    /// Add XP to today's total
    func addGymXP(_ xp: Int) {
        let todayString = dateString(for: Date())
        let storedDate = UserDefaults.standard.string(forKey: dateKey) ?? ""
        
        // Reset if it's a new day
        if storedDate != todayString {
            UserDefaults.standard.set(xp, forKey: dailyXPKey)
            UserDefaults.standard.set(todayString, forKey: dateKey)
        } else {
            let current = UserDefaults.standard.integer(forKey: dailyXPKey)
            UserDefaults.standard.set(current + xp, forKey: dailyXPKey)
        }
    }
    
    private func dateString(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}

struct PreviousExerciseSet: Equatable {
    let kg: Double
    let reps: Int
}

struct ExerciseHistorySnapshot {
    let sets: [PreviousExerciseSet]
}

class GymSessionViewModel: ObservableObject {
    @Published var exercises: [GymExercise] = []
    @Published var formattedDuration: String = "00:00"
    @Published var sessionData: GymSessionData?
    @Published private(set) var elapsedSeconds: Int = 0
    @Published var savedWorkouts: [SavedGymWorkout] = []
    @Published var isLoadingSavedWorkouts = false
    @Published private(set) var exerciseHistory: [String: ExerciseHistorySnapshot] = [:]
    
    var totalVolume: Double {
        exercises.reduce(0) { result, exercise in
            result + exerciseVolume(exercise)
        }
    }
    
    var formattedVolume: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        let volumeValue = Int(round(totalVolume))
        let number = NSNumber(value: volumeValue)
        let text = formatter.string(from: number) ?? "0"
        return "\(text) kg"
    }
    
    private var startTime: Date?
    private var timer: Timer?
    private let historyLimit = 60
    
    var sessionStartTime: Date? {
        startTime
    }

    func startTimer(startTime: Date? = nil) {
        if let startTime = startTime {
            self.startTime = startTime
        } else if self.startTime == nil {
            self.startTime = Date()
        }

        timer?.invalidate()

        updateDuration()

        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateDuration()
        }
    }
    
    func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
    
    func resetSession() {
        stopTimer()
        exercises = []
        startTime = nil
        elapsedSeconds = 0
        formattedDuration = "00:00"
        sessionData = nil
    }

    private func updateDuration() {
        guard let startTime else {
            elapsedSeconds = 0
            formattedDuration = "00:00"
            return
        }

        let elapsed = max(0, Int(Date().timeIntervalSince(startTime)))
        elapsedSeconds = elapsed
        let minutes = elapsed / 60
        let seconds = elapsed % 60
        formattedDuration = String(format: "%02d:%02d", minutes, seconds)
    }

    func restoreSession(exercises: [GymExercise], startTime: Date) {
        self.exercises = exercises
        self.startTime = startTime
        updateDuration()
    }
    
    func loadSavedWorkouts(userId: String) async {
        if isLoadingSavedWorkouts { return }
        await MainActor.run { isLoadingSavedWorkouts = true }
        do {
            let workouts = try await SavedWorkoutService.shared.fetchSavedWorkouts(for: userId)
            await MainActor.run {
                self.savedWorkouts = workouts
                self.isLoadingSavedWorkouts = false
            }
        } catch {
            print("⚠️ Failed to load saved gym workouts: \(error)")
            await MainActor.run {
                self.isLoadingSavedWorkouts = false
            }
        }
    }
    
    func applySavedWorkout(_ workout: SavedGymWorkout) {
        let convertedExercises = workout.exercises.map { post -> GymExercise in
            let combined = zip(post.kg, post.reps)
            var sets = combined.map { pair in
                ExerciseSet(kg: pair.0, reps: pair.1, isCompleted: false)
            }
            if post.sets > sets.count {
                for _ in sets.count..<post.sets {
                    sets.append(ExerciseSet(kg: 0, reps: 0, isCompleted: false))
                }
            }
            return GymExercise(
                id: post.id ?? UUID().uuidString,
                name: post.name,
                category: post.category,
                sets: sets
            )
        }
        exercises = convertedExercises
    }
    
    func addExercise(_ template: ExerciseTemplate) {
        let newExercise = GymExercise(
            id: template.id,  // Keep the original exercise ID from the API
            name: template.name,
            category: template.category,
            sets: []
        )
        exercises.append(newExercise)
    }
    
    func previousSets(for exerciseName: String) -> [PreviousExerciseSet] {
        exerciseHistory[exerciseName]?.sets ?? []
    }
    
    func removeExercise(_ id: String) {
        exercises.removeAll { $0.id == id }
    }
    
    func addSet(to exerciseId: String) {
        guard let index = exercises.firstIndex(where: { $0.id == exerciseId }) else { return }
        
        // Get previous set values for convenience
        let previousSet = exercises[index].sets.last
        let newSet = ExerciseSet(
            kg: previousSet?.kg ?? 0,
            reps: previousSet?.reps ?? 0,
            isCompleted: false
        )
        
        exercises[index].sets.append(newSet)
    }
    
    func updateSet(exerciseId: String, setIndex: Int, kg: Double, reps: Int) {
        guard let exerciseIndex = exercises.firstIndex(where: { $0.id == exerciseId }),
              setIndex < exercises[exerciseIndex].sets.count else { return }
        
        exercises[exerciseIndex].sets[setIndex].kg = kg
        exercises[exerciseIndex].sets[setIndex].reps = reps
        exercises[exerciseIndex].sets[setIndex].isCompleted = kg > 0 && reps > 0
    }
    
    func deleteSet(exerciseId: String, setIndex: Int) {
        guard let exerciseIndex = exercises.firstIndex(where: { $0.id == exerciseId }),
              setIndex < exercises[exerciseIndex].sets.count else { return }
        
        exercises[exerciseIndex].sets.remove(at: setIndex)
    }
    
    func toggleSetCompletion(exerciseId: String, setIndex: Int) {
        guard let exerciseIndex = exercises.firstIndex(where: { $0.id == exerciseId }),
              setIndex < exercises[exerciseIndex].sets.count else { return }
        
        exercises[exerciseIndex].sets[setIndex].isCompleted.toggle()
    }
    
    func appendGeneratedExercises(_ generated: [GeneratedWorkoutEntry]) {
        guard !generated.isEmpty else { return }
        
        let mapped = generated.map { entry in
            let setCount = max(entry.sets, 1)
            let repsValue = max(entry.targetReps, 1)
            let exerciseSets = (0..<setCount).map { _ in
                ExerciseSet(kg: 0, reps: repsValue, isCompleted: false)
            }
            return GymExercise(
                id: entry.exerciseId,
                name: entry.name,
                category: entry.category,
                sets: exerciseSets
            )
        }
        
        exercises.append(contentsOf: mapped)
    }
    
    func completeSession(duration: Int, isPro: Bool) {
        let totalSets = exercises.reduce(0) { $0 + $1.sets.count }
        let completedSets = exercises.reduce(0) { total, exercise in
            total + exercise.sets.filter { $0.isCompleted }.count
        }
        
        let volume = totalVolume
        let pointsFromVolume = Int(volume / 160.0)
        
        // Max 30 points per gym session
        var earnedXP = min(30, pointsFromVolume)
        
        // Check daily limit (max 30 points per day from gym)
        let todayGymXP = GymXPTracker.shared.getTodayGymXP()
        let remainingDailyAllowance = max(0, 30 - todayGymXP)
        earnedXP = min(earnedXP, remainingDailyAllowance)
        
        if isPro {
            earnedXP = Int(Double(earnedXP) * 1.5)
        }
        
        // Track the earned XP for daily limit
        if earnedXP > 0 {
            GymXPTracker.shared.addGymXP(earnedXP)
        }
        
        sessionData = GymSessionData(
            duration: duration,
            exercises: exercises,
            totalSets: totalSets,
            completedSets: completedSets,
            earnedXP: earnedXP,
            totalVolume: volume
        )
    }
    
    private func exerciseVolume(_ exercise: GymExercise) -> Double {
        exercise.sets.reduce(0) { partial, set in
            partial + (set.kg * Double(set.reps))
        }
    }
    
    func loadExerciseHistory(userId: String) async {
        do {
            let posts = try await WorkoutService.shared.getUserWorkoutPosts(userId: userId, forceRefresh: false)
            var latest: [String: ExerciseHistorySnapshot] = [:]
            for post in posts where post.activityType.lowercased().contains("gym") {
                guard let exercises = post.exercises else { continue }
                for exercise in exercises {
                    guard latest[exercise.name] == nil else { continue }
                    let zipped = zip(exercise.kg, exercise.reps)
                        .map { PreviousExerciseSet(kg: $0.0, reps: $0.1) }
                        .filter { $0.kg > 0 || $0.reps > 0 }
                    guard !zipped.isEmpty else { continue }
                    latest[exercise.name] = ExerciseHistorySnapshot(sets: zipped)
                }
                if latest.count >= historyLimit {
                    break
                }
            }
            await MainActor.run {
                self.exerciseHistory = latest
            }
        } catch {
            print("⚠️ Failed to load exercise history: \(error)")
        }
    }
}

// MARK: - Models
struct GymExercise: Identifiable, Codable {
    let id: String
    let name: String
    let category: String?
    var sets: [ExerciseSet]
}

struct ExerciseSet: Codable {
    var kg: Double
    var reps: Int
    var isCompleted: Bool
}

struct ExerciseTemplate: Identifiable {
    let id: String
    let name: String
    let category: String?
}

struct GeneratedWorkoutEntry {
    let exerciseId: String
    let name: String
    let category: String?
    let sets: Int
    let targetReps: Int
}

struct GymSessionData {
    let duration: Int
    let exercises: [GymExercise]
    let totalSets: Int
    let completedSets: Int
    let earnedXP: Int
    let totalVolume: Double
}

