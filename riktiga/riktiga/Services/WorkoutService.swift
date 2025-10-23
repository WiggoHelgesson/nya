import Foundation
import Supabase
import PostgREST

class WorkoutService {
    static let shared = WorkoutService()
    private let supabase = SupabaseConfig.supabase
    
    func saveWorkoutPost(_ post: WorkoutPost) async throws {
        do {
            _ = try await supabase
                .from("workout_posts")
                .insert(post)
                .execute()
            print("✅ Workout post saved: \(post.id)")
        } catch {
            print("❌ Error saving workout post: \(error)")
            throw error
        }
    }
    
    func fetchUserWorkoutPosts(userId: String) async throws -> [WorkoutPost] {
        do {
            let posts: [WorkoutPost] = try await supabase
                .from("workout_posts")
                .select()
                .eq("user_id", value: userId)
                .order("created_at", ascending: false)
                .execute()
                .value
            
            print("✅ Fetched \(posts.count) workout posts")
            return posts
        } catch {
            print("❌ Error fetching workout posts: \(error)")
            return []
        }
    }
    
    func fetchAllWorkoutPosts() async throws -> [WorkoutPost] {
        do {
            let posts: [WorkoutPost] = try await supabase
                .from("workout_posts")
                .select()
                .order("created_at", ascending: false)
                .execute()
                .value
            
            print("✅ Fetched \(posts.count) total workout posts")
            return posts
        } catch {
            print("❌ Error fetching all workout posts: \(error)")
            return []
        }
    }
}
