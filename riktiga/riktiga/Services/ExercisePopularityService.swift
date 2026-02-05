import Foundation
import Supabase

// MARK: - Exercise Popularity Service
// Tracks and fetches global exercise popularity data

class ExercisePopularityService {
    static let shared = ExercisePopularityService()
    
    private let supabase = SupabaseConfig.supabase
    
    // Cache for popularity data (refreshed periodically)
    private var popularityCache: [String: [PopularExercise]] = [:] // bodyPart -> exercises
    private var lastCacheUpdate: Date?
    private let cacheValidityMinutes: Double = 30
    
    private init() {}
    
    // MARK: - Increment Usage
    
    /// Record that an exercise was used (call when user adds exercise to workout)
    func recordExerciseUsage(exerciseId: String, exerciseName: String, bodyPart: String) async {
        do {
            try await supabase
                .rpc("increment_exercise_usage", params: [
                    "p_exercise_id": exerciseId,
                    "p_exercise_name": exerciseName,
                    "p_body_part": bodyPart.lowercased()
                ])
                .execute()
            
            print("📊 Recorded exercise usage: \(exerciseName)")
        } catch {
            print("❌ Failed to record exercise usage: \(error)")
        }
    }
    
    /// Record multiple exercises at once
    func recordExercisesBatch(_ exercises: [(id: String, name: String, bodyPart: String)]) async {
        guard !exercises.isEmpty else { return }
        
        do {
            let exercisesJson = exercises.map { exercise in
                [
                    "exercise_id": exercise.id,
                    "exercise_name": exercise.name,
                    "body_part": exercise.bodyPart.lowercased()
                ]
            }
            
            let jsonData = try JSONSerialization.data(withJSONObject: exercisesJson)
            let jsonString = String(data: jsonData, encoding: .utf8) ?? "[]"
            
            try await supabase
                .rpc("increment_exercises_batch", params: ["p_exercises": jsonString])
                .execute()
            
            print("📊 Recorded \(exercises.count) exercise usages")
        } catch {
            print("❌ Failed to record batch exercise usage: \(error)")
        }
    }
    
    // MARK: - Fetch Popularity
    
    /// Get popular exercises, optionally filtered by body part
    func getPopularExercises(bodyPart: String? = nil, limit: Int = 50) async -> [PopularExercise] {
        // Check cache first
        let cacheKey = bodyPart ?? "all"
        if let cached = getCachedPopularity(for: cacheKey) {
            return cached
        }
        
        do {
            let exercises: [PopularExerciseResponse] = try await supabase
                .rpc("get_popular_exercises", params: [
                    "p_body_part": AnyJSON.string(bodyPart ?? "all"),
                    "p_limit": AnyJSON.integer(limit)
                ])
                .execute()
                .value
            
            let result = exercises.map { response in
                PopularExercise(
                    exerciseId: response.exercise_id,
                    exerciseName: response.exercise_name,
                    bodyPart: response.body_part,
                    usageCount: response.usage_count
                )
            }
            
            // Update cache
            updateCache(for: cacheKey, with: result)
            
            return result
        } catch {
            print("❌ Failed to fetch popular exercises: \(error)")
            return []
        }
    }
    
    /// Get a set of popular exercise IDs for quick lookup (for sorting)
    func getPopularExerciseIds(bodyPart: String? = nil) async -> [String: Int] {
        let popular = await getPopularExercises(bodyPart: bodyPart)
        var result: [String: Int] = [:]
        for (index, exercise) in popular.enumerated() {
            result[exercise.exerciseId] = index // Lower index = more popular
        }
        return result
    }
    
    // MARK: - Cache Management
    
    private func getCachedPopularity(for key: String) -> [PopularExercise]? {
        guard let lastUpdate = lastCacheUpdate,
              Date().timeIntervalSince(lastUpdate) < cacheValidityMinutes * 60,
              let cached = popularityCache[key] else {
            return nil
        }
        return cached
    }
    
    private func updateCache(for key: String, with exercises: [PopularExercise]) {
        popularityCache[key] = exercises
        lastCacheUpdate = Date()
    }
    
    /// Clear the cache (useful after recording new usages)
    func clearCache() {
        popularityCache.removeAll()
        lastCacheUpdate = nil
    }
}

// MARK: - Models

struct PopularExercise {
    let exerciseId: String
    let exerciseName: String
    let bodyPart: String
    let usageCount: Int
}

struct PopularExerciseResponse: Codable {
    let exercise_id: String
    let exercise_name: String
    let body_part: String
    let usage_count: Int
}

