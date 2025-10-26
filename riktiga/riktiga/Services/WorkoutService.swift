import Foundation
import Supabase
import PostgREST
import UIKit

// Helper struct to make Any values encodable
struct AnyEncodable: Encodable {
    let value: Any
    
    init(_ value: Any) {
        self.value = value
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        
        switch value {
        case let string as String:
            try container.encode(string)
        case let int as Int:
            try container.encode(int)
        case let double as Double:
            try container.encode(double)
        case let bool as Bool:
            try container.encode(bool)
        case is NSNull:
            try container.encodeNil()
        default:
            try container.encode(String(describing: value))
        }
    }
}

class WorkoutService {
    static let shared = WorkoutService()
    private let supabase = SupabaseConfig.supabase
    
    func uploadWorkoutImage(_ image: UIImage, postId: String) async throws -> String {
        do {
            // Convert image to JPEG data
            guard let imageData = image.jpegData(compressionQuality: 0.8) else {
                throw NSError(domain: "ImageConversionError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Could not convert image to JPEG"])
            }
            
            // Save image locally to Documents directory
            let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            let imagesDirectory = documentsPath.appendingPathComponent("WorkoutImages")
            
            // Create directory if it doesn't exist
            try FileManager.default.createDirectory(at: imagesDirectory, withIntermediateDirectories: true)
            
            // Create file name
            let fileName = "\(postId)_\(UUID().uuidString).jpg"
            let fileURL = imagesDirectory.appendingPathComponent(fileName)
            
            // Save image to local file
            try imageData.write(to: fileURL)
            
            print("✅ Image saved locally: \(fileURL.path)")
            
            // Return local file path as "URL"
            return fileURL.path
            
        } catch {
            print("❌ Error saving image locally: \(error)")
            throw error
        }
    }
    
    func getUserWorkoutPosts(userId: String) async throws -> [WorkoutPost] {
        do {
            let response: [WorkoutPost] = try await supabase
                .from("workout_posts")
                .select("*")
                .eq("user_id", value: userId)
                .order("created_at", ascending: false)
                .execute()
                .value
            
            print("✅ Fetched \(response.count) workout posts for user \(userId)")
            return response
            
        } catch {
            print("❌ Error fetching user workout posts: \(error)")
            throw error
        }
    }
    
    func deleteWorkoutPost(postId: String) async throws {
        do {
            try await supabase
                .from("workout_posts")
                .delete()
                .eq("id", value: postId)
                .execute()
            
            print("✅ Successfully deleted workout post: \(postId)")
            
        } catch {
            print("❌ Error deleting workout post: \(error)")
            throw error
        }
    }
    
    func saveWorkoutPost(_ post: WorkoutPost, image: UIImage? = nil, earnedPoints: Int = 0) async throws {
        do {
            var postToSave = post
            
            // Try to upload image if provided
            if let image = image {
                do {
                    let imageUrl = try await uploadWorkoutImage(image, postId: post.id)
                    postToSave = WorkoutPost(
                        id: post.id,
                        userId: post.userId,
                        activityType: post.activityType,
                        title: post.title,
                        description: post.description,
                        distance: post.distance,
                        duration: post.duration,
                        imageUrl: imageUrl
                    )
                    print("✅ Image uploaded successfully, saving post with image URL")
                } catch {
                    print("⚠️ Image upload failed, saving post without image: \(error)")
                    // Continue with the original post (without image) if upload fails
                }
            }
            
            // Create a minimal post object with only the columns that exist in the database
            let minimalPost: [String: AnyEncodable] = [
                "id": AnyEncodable(postToSave.id),
                "user_id": AnyEncodable(postToSave.userId),
                "activity_type": AnyEncodable(postToSave.activityType),
                "title": AnyEncodable(postToSave.title),
                "description": AnyEncodable(postToSave.description ?? NSNull()),
                "created_at": AnyEncodable(postToSave.createdAt)
            ]
            
            _ = try await supabase
                .from("workout_posts")
                .insert(minimalPost)
                .execute()
            print("✅ Workout post saved: \(postToSave.id)")
            
            // Update user's XP in database
            if earnedPoints > 0 {
                try await ProfileService.shared.updateUserPoints(userId: post.userId, pointsToAdd: earnedPoints)
                print("✅ XP updated: +\(earnedPoints)")
            }
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
