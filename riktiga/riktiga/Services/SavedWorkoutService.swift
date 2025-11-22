import Foundation
import Supabase
import PostgREST

final class SavedWorkoutService {
    static let shared = SavedWorkoutService()
    private let supabase = SupabaseConfig.supabase
    private let isoFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
    private let isoFormatterNoMs: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()
    private init() {}
    
    func fetchSavedWorkouts(for userId: String) async throws -> [SavedGymWorkout] {
        try await AuthSessionManager.shared.ensureValidSession()
        struct SavedWorkoutRecord: Decodable {
            let id: String
            let userId: String
            let name: String
            let exercises: [GymExercisePost]?
            let createdAt: String
            
            enum CodingKeys: String, CodingKey {
                case id
                case userId = "user_id"
                case name
                case exercises = "exercises_data"
                case createdAt = "created_at"
            }
        }
        do {
            let records: [SavedWorkoutRecord] = try await supabase
                .from("saved_gym_workouts")
                .select("id, user_id, name, exercises_data, created_at")
                .eq("user_id", value: userId)
                .order("created_at", ascending: false)
                .execute()
                .value
            return records.compactMap { record in
                guard let exercises = record.exercises else { return nil }
                let date = isoFormatter.date(from: record.createdAt) ?? isoFormatterNoMs.date(from: record.createdAt) ?? Date()
                return SavedGymWorkout(id: record.id, userId: record.userId, name: record.name, exercises: exercises, createdAt: date)
            }
        } catch let error as PostgrestError where error.code == "42P01" {
            print("ℹ️ saved_gym_workouts table is missing. Create it before using saved gym passes.")
            return []
        }
    }
    
    func saveWorkoutTemplate(userId: String, name: String, exercises: [GymExercisePost]) async throws -> SavedGymWorkout {
        try await AuthSessionManager.shared.ensureValidSession()
        struct InsertPayload: Encodable {
            let id: String
            let userId: String
            let name: String
            let exercises: [GymExercisePost]
            
            enum CodingKeys: String, CodingKey {
                case id
                case userId = "user_id"
                case name
                case exercises = "exercises_data"
            }
        }
        let id = UUID().uuidString
        let payload = InsertPayload(id: id, userId: userId, name: name, exercises: exercises)
        do {
            _ = try await supabase
                .from("saved_gym_workouts")
                .insert(payload)
                .execute()
            return SavedGymWorkout(id: id, userId: userId, name: name, exercises: exercises, createdAt: Date())
        } catch let error as PostgrestError where error.code == "42P01" {
            print("ℹ️ saved_gym_workouts table is missing. Create it before saving gym passes.")
            throw error
        }
    }
    
    func deleteWorkoutTemplate(id: String, userId: String) async throws {
        try await AuthSessionManager.shared.ensureValidSession()
        do {
            _ = try await supabase
                .from("saved_gym_workouts")
                .delete()
                .eq("id", value: id)
                .eq("user_id", value: userId)
                .execute()
        } catch let error as PostgrestError where error.code == "42P01" {
            print("ℹ️ saved_gym_workouts table is missing. Nothing to delete.")
        }
    }
}
