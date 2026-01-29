//
//  ExercisePRService.swift
//  riktiga
//
//  Service to calculate exercise Personal Records (PRs)
//

import Foundation

class ExercisePRService {
    static let shared = ExercisePRService()
    
    // Cache for user exercise history: [userId: [exerciseName: ExerciseBest]]
    private var userBestCache: [String: [String: ExerciseBest]] = [:]
    private var cacheTimestamps: [String: Date] = [:]
    private let cacheValidityMinutes: Double = 10
    
    private init() {}
    
    struct ExerciseBest {
        let maxWeight: Double       // Highest weight ever lifted in a single set
        let maxVolume: Double       // Highest total volume (weight × reps) in a single session
    }
    
    struct PRResult {
        let hasWeightPR: Bool
        let hasVolumePR: Bool
        let weightIncreasePercent: Double
        let volumeIncreasePercent: Double
        
        /// Returns the highest increase percentage, or nil if no PR
        var displayPercent: Double? {
            let maxPercent = max(weightIncreasePercent, volumeIncreasePercent)
            return maxPercent > 0 ? maxPercent : nil
        }
    }
    
    /// Calculate PR percentage for an exercise in a post
    /// - Parameters:
    ///   - exercise: The exercise to check
    ///   - userId: The user who did the exercise
    ///   - postDate: Date of the post (to only compare against OLDER workouts)
    /// - Returns: PRResult with percentage increase if it's a PR
    func calculatePR(
        for exercise: GymExercisePost,
        userId: String,
        postDate: Date
    ) async -> PRResult {
        // Get user's best records (from workouts BEFORE this post)
        let userBests = await getUserBests(userId: userId, beforeDate: postDate)
        
        guard let previousBest = userBests[exercise.name.lowercased()] else {
            // No previous record - this is their first time, not a PR to display
            return PRResult(hasWeightPR: false, hasVolumePR: false, weightIncreasePercent: 0, volumeIncreasePercent: 0)
        }
        
        // Calculate current workout stats
        let currentMaxWeight = exercise.kg.max() ?? 0
        let currentVolume = calculateVolume(kg: exercise.kg, reps: exercise.reps)
        
        // Calculate percentage increases
        var weightIncrease: Double = 0
        var volumeIncrease: Double = 0
        
        if previousBest.maxWeight > 0 && currentMaxWeight > previousBest.maxWeight {
            weightIncrease = ((currentMaxWeight - previousBest.maxWeight) / previousBest.maxWeight) * 100
        }
        
        if previousBest.maxVolume > 0 && currentVolume > previousBest.maxVolume {
            volumeIncrease = ((currentVolume - previousBest.maxVolume) / previousBest.maxVolume) * 100
        }
        
        return PRResult(
            hasWeightPR: weightIncrease > 0,
            hasVolumePR: volumeIncrease > 0,
            weightIncreasePercent: weightIncrease,
            volumeIncreasePercent: volumeIncrease
        )
    }
    
    /// Get all exercise bests for a user (from workouts before a given date)
    private func getUserBests(userId: String, beforeDate: Date) async -> [String: ExerciseBest] {
        // Check cache
        let cacheKey = "\(userId)_\(beforeDate.timeIntervalSince1970)"
        if let cached = userBestCache[cacheKey],
           let timestamp = cacheTimestamps[cacheKey],
           Date().timeIntervalSince(timestamp) < cacheValidityMinutes * 60 {
            return cached
        }
        
        // Fetch user's workout history
        do {
            let posts = try await WorkoutService.shared.getUserWorkoutPosts(userId: userId, forceRefresh: false)
            var bests: [String: ExerciseBest] = [:]
            
            let dateFormatter = ISO8601DateFormatter()
            
            for post in posts {
                // Only consider posts BEFORE the given date
                guard let postDateString = post.createdAt as String?,
                      let postDate = dateFormatter.date(from: postDateString),
                      postDate < beforeDate else { continue }
                
                guard post.activityType.lowercased().contains("gym"),
                      let exercises = post.exercises else { continue }
                
                for exercise in exercises {
                    let name = exercise.name.lowercased()
                    let maxWeight = exercise.kg.max() ?? 0
                    let volume = calculateVolume(kg: exercise.kg, reps: exercise.reps)
                    
                    if let existing = bests[name] {
                        bests[name] = ExerciseBest(
                            maxWeight: max(existing.maxWeight, maxWeight),
                            maxVolume: max(existing.maxVolume, volume)
                        )
                    } else {
                        bests[name] = ExerciseBest(maxWeight: maxWeight, maxVolume: volume)
                    }
                }
            }
            
            // Cache the result
            userBestCache[cacheKey] = bests
            cacheTimestamps[cacheKey] = Date()
            
            return bests
        } catch {
            print("⚠️ ExercisePRService: Failed to fetch workout history: \(error)")
            return [:]
        }
    }
    
    /// Calculate total volume (weight × reps) for all sets
    private func calculateVolume(kg: [Double], reps: [Int]) -> Double {
        zip(kg, reps).reduce(0) { total, pair in
            total + (pair.0 * Double(pair.1))
        }
    }
    
    /// Clear cache (call when user logs out or data changes significantly)
    func clearCache() {
        userBestCache.removeAll()
        cacheTimestamps.removeAll()
    }
}
