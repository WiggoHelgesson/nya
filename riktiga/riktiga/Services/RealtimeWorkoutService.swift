import Foundation
import Supabase
import Combine

// MARK: - Realtime Workout Service
// Handles real-time syncing of workout exercises and spectating functionality

class RealtimeWorkoutService: ObservableObject {
    static let shared = RealtimeWorkoutService()
    
    private let supabase = SupabaseConfig.supabase
    
    @Published var spectatorCount: Int = 0
    @Published var recentCheers: [WorkoutCheer] = []
    @Published var spectatedExercises: [SpectateExercise] = []
    @Published var isSpectating: Bool = false
    
    private var exerciseSyncTask: Task<Void, Never>?
    private var spectatorPingTimer: Timer?
    private var cheerCheckTimer: Timer?
    private var currentSessionId: String?
    private var spectatingSessionId: String?
    
    private init() {}
    
    // MARK: - Session Owner Functions
    
    /// Start syncing exercises for the current session
    func startSyncingExercises(sessionId: String, userId: String) {
        currentSessionId = sessionId
        
        // Start spectator count polling
        startSpectatorCountPolling()
        
        // Start cheer checking
        startCheerChecking()
        
        print("📡 Started real-time exercise syncing for session: \(sessionId)")
    }
    
    /// Sync a single exercise to the database
    func syncExercise(_ exercise: GymExercise, sessionId: String, userId: String, orderIndex: Int) async {
        do {
            let setsJson = try JSONEncoder().encode(exercise.sets)
            let setsString = String(data: setsJson, encoding: .utf8) ?? "[]"
            
            // Check if exercise already exists
            let existing: [ActiveSessionExercise] = try await supabase
                .from("active_session_exercises")
                .select()
                .eq("session_id", value: sessionId)
                .eq("exercise_id", value: exercise.id)
                .execute()
                .value
            
            if existing.isEmpty {
                // Insert new exercise
                try await supabase
                    .from("active_session_exercises")
                    .insert([
                        "session_id": sessionId,
                        "user_id": userId,
                        "exercise_name": exercise.name,
                        "exercise_id": exercise.id,
                        "muscle_group": exercise.category ?? "",
                        "sets": setsString,
                        "notes": exercise.notes ?? "",
                        "order_index": String(orderIndex)
                    ])
                    .execute()
            } else {
                // Update existing exercise
                try await supabase
                    .from("active_session_exercises")
                    .update([
                        "sets": setsString,
                        "notes": exercise.notes ?? "",
                        "updated_at": ISO8601DateFormatter().string(from: Date())
                    ])
                    .eq("session_id", value: sessionId)
                    .eq("exercise_id", value: exercise.id)
                    .execute()
            }
            
            print("✅ Synced exercise: \(exercise.name)")
        } catch {
            print("❌ Failed to sync exercise: \(error)")
        }
    }
    
    /// Sync all exercises at once
    func syncAllExercises(_ exercises: [GymExercise], sessionId: String, userId: String) async {
        for (index, exercise) in exercises.enumerated() {
            await syncExercise(exercise, sessionId: sessionId, userId: userId, orderIndex: index)
        }
    }
    
    /// Remove an exercise from the database
    func removeExercise(exerciseId: String, sessionId: String) async {
        do {
            try await supabase
                .from("active_session_exercises")
                .delete()
                .eq("session_id", value: sessionId)
                .eq("exercise_id", value: exerciseId)
                .execute()
            
            print("🗑️ Removed exercise from sync: \(exerciseId)")
        } catch {
            print("❌ Failed to remove exercise: \(error)")
        }
    }
    
    /// Clear all exercises when session ends
    func clearSessionExercises(sessionId: String) async {
        stopSyncing()
        
        do {
            try await supabase
                .from("active_session_exercises")
                .delete()
                .eq("session_id", value: sessionId)
                .execute()
            
            print("🧹 Cleared all exercises for session: \(sessionId)")
        } catch {
            print("❌ Failed to clear exercises: \(error)")
        }
    }
    
    /// Stop syncing
    func stopSyncing() {
        spectatorPingTimer?.invalidate()
        spectatorPingTimer = nil
        cheerCheckTimer?.invalidate()
        cheerCheckTimer = nil
        currentSessionId = nil
        
        Task { @MainActor in
            spectatorCount = 0
            recentCheers = []
        }
        
        print("⏹️ Stopped real-time syncing")
    }
    
    // MARK: - Spectator Count Polling
    
    private func startSpectatorCountPolling() {
        spectatorPingTimer?.invalidate()
        spectatorPingTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            guard let self = self, let sessionId = self.currentSessionId else { return }
            Task {
                await self.fetchSpectatorCount(sessionId: sessionId)
            }
        }
        
        // Initial fetch
        if let sessionId = currentSessionId {
            Task {
                await fetchSpectatorCount(sessionId: sessionId)
            }
        }
    }
    
    private func fetchSpectatorCount(sessionId: String) async {
        do {
            let count: Int = try await supabase
                .rpc("get_spectator_count", params: ["p_session_id": sessionId])
                .execute()
                .value
            
            await MainActor.run {
                self.spectatorCount = count
            }
        } catch {
            print("❌ Failed to fetch spectator count: \(error)")
        }
    }
    
    // MARK: - Cheer Checking
    
    private func startCheerChecking() {
        cheerCheckTimer?.invalidate()
        cheerCheckTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { [weak self] _ in
            guard let self = self, let sessionId = self.currentSessionId else { return }
            Task {
                await self.fetchRecentCheers(sessionId: sessionId)
            }
        }
    }
    
    private func fetchRecentCheers(sessionId: String) async {
        do {
            let cheers: [WorkoutCheerResponse] = try await supabase
                .rpc("get_recent_cheers", params: ["p_session_id": sessionId])
                .execute()
                .value
            
            let newCheers = cheers.map { response in
                WorkoutCheer(
                    id: response.id,
                    emoji: response.emoji,
                    fromUsername: response.from_username,
                    fromAvatarUrl: response.from_avatar_url,
                    createdAt: ISO8601DateFormatter().date(from: response.created_at) ?? Date()
                )
            }
            
            await MainActor.run {
                // Only add cheers we haven't seen yet
                let existingIds = Set(self.recentCheers.map { $0.id })
                let brandNewCheers = newCheers.filter { !existingIds.contains($0.id) }
                
                if !brandNewCheers.isEmpty {
                    self.recentCheers.append(contentsOf: brandNewCheers)
                    
                    // Trigger haptic and notification for new cheers
                    for cheer in brandNewCheers {
                        NotificationCenter.default.post(
                            name: NSNotification.Name("NewWorkoutCheer"),
                            object: nil,
                            userInfo: ["cheer": cheer]
                        )
                    }
                }
                
                // Keep only last 20 cheers
                if self.recentCheers.count > 20 {
                    self.recentCheers = Array(self.recentCheers.suffix(20))
                }
            }
        } catch {
            print("❌ Failed to fetch cheers: \(error)")
        }
    }
    
    // MARK: - Spectator Functions
    
    /// Start spectating a friend's workout
    func startSpectating(sessionId: String, spectatorId: String) async {
        spectatingSessionId = sessionId
        
        do {
            // Add ourselves as a spectator
            try await supabase
                .from("session_spectators")
                .upsert([
                    "session_id": sessionId,
                    "spectator_id": spectatorId,
                    "last_ping_at": ISO8601DateFormatter().string(from: Date())
                ])
                .execute()
            
            await MainActor.run {
                self.isSpectating = true
            }
            
            // Start polling for exercises
            startExercisePolling(sessionId: sessionId)
            
            // Start ping timer to keep spectator status alive
            startSpectatorPing(sessionId: sessionId, spectatorId: spectatorId)
            
            print("👀 Started spectating session: \(sessionId)")
        } catch {
            print("❌ Failed to start spectating: \(error)")
        }
    }
    
    /// Stop spectating
    func stopSpectating(spectatorId: String) async {
        guard let sessionId = spectatingSessionId else { return }
        
        exerciseSyncTask?.cancel()
        spectatorPingTimer?.invalidate()
        spectatorPingTimer = nil
        spectatingSessionId = nil
        
        do {
            try await supabase
                .from("session_spectators")
                .delete()
                .eq("session_id", value: sessionId)
                .eq("spectator_id", value: spectatorId)
                .execute()
            
            await MainActor.run {
                self.isSpectating = false
                self.spectatedExercises = []
            }
            
            print("👋 Stopped spectating")
        } catch {
            print("❌ Failed to stop spectating: \(error)")
        }
    }
    
    private func startExercisePolling(sessionId: String) {
        exerciseSyncTask?.cancel()
        exerciseSyncTask = Task {
            while !Task.isCancelled {
                await fetchSpectatedExercises(sessionId: sessionId)
                try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
            }
        }
    }
    
    private func fetchSpectatedExercises(sessionId: String) async {
        do {
            let exercises: [ActiveSessionExercise] = try await supabase
                .from("active_session_exercises")
                .select()
                .eq("session_id", value: sessionId)
                .order("order_index")
                .execute()
                .value
            
            let spectateExercises = exercises.map { exercise -> SpectateExercise in
                let sets: [ExerciseSet] = {
                    guard let setsData = exercise.sets.data(using: .utf8) else { return [] }
                    return (try? JSONDecoder().decode([ExerciseSet].self, from: setsData)) ?? []
                }()
                
                return SpectateExercise(
                    id: exercise.id,
                    exerciseId: exercise.exercise_id ?? exercise.id,
                    name: exercise.exercise_name,
                    muscleGroup: exercise.muscle_group,
                    sets: sets,
                    notes: exercise.notes,
                    orderIndex: exercise.order_index
                )
            }
            
            await MainActor.run {
                self.spectatedExercises = spectateExercises
            }
        } catch {
            print("❌ Failed to fetch spectated exercises: \(error)")
        }
    }
    
    private func startSpectatorPing(sessionId: String, spectatorId: String) {
        spectatorPingTimer?.invalidate()
        spectatorPingTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
            Task {
                do {
                    try await self?.supabase
                        .from("session_spectators")
                        .update(["last_ping_at": ISO8601DateFormatter().string(from: Date())])
                        .eq("session_id", value: sessionId)
                        .eq("spectator_id", value: spectatorId)
                        .execute()
                } catch {
                    print("❌ Failed to ping spectator status: \(error)")
                }
            }
        }
    }
    
    // MARK: - Send Cheer
    
    /// Send a cheer emoji to motivate a friend
    func sendCheer(sessionId: String, fromUserId: String, toUserId: String, emoji: String) async -> Bool {
        do {
            try await supabase
                .from("workout_cheers")
                .insert([
                    "session_id": sessionId,
                    "from_user_id": fromUserId,
                    "to_user_id": toUserId,
                    "emoji": emoji
                ])
                .execute()
            
            print("🎉 Sent cheer: \(emoji)")
            return true
        } catch {
            print("❌ Failed to send cheer: \(error)")
            return false
        }
    }
}

// MARK: - Models

struct ActiveSessionExercise: Codable {
    let id: String
    let session_id: String
    let user_id: String
    let exercise_name: String
    let exercise_id: String?
    let muscle_group: String?
    let sets: String // JSON string
    let notes: String?
    let order_index: Int
    let created_at: String?
    let updated_at: String?
}

struct SpectateExercise: Identifiable {
    let id: String
    let exerciseId: String
    let name: String
    let muscleGroup: String?
    let sets: [ExerciseSet]
    let notes: String?
    let orderIndex: Int
}

struct WorkoutCheer: Identifiable {
    let id: String
    let emoji: String
    let fromUsername: String
    let fromAvatarUrl: String?
    let createdAt: Date
}

struct WorkoutCheerResponse: Codable {
    let id: String
    let emoji: String
    let from_username: String
    let from_avatar_url: String?
    let created_at: String
}
