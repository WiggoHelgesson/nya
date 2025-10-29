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
        
        if value is NSNull {
            try container.encodeNil()
            return
        }
        
        switch value {
        case let string as String:
            try container.encode(string)
        case let int as Int:
            try container.encode(int)
        case let double as Double:
            try container.encode(double)
        case let bool as Bool:
            try container.encode(bool)
        default:
            // For any other type, encode as string description
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
            
            // Create unique file name
            let fileName = "\(postId)_\(UUID().uuidString).jpg"
            
            print("📤 Uploading image to Supabase Storage: \(fileName)")
            print("📊 Image size: \(imageData.count) bytes")
            
            // Upload to Supabase Storage (allow overwrite if file exists)
            do {
                _ = try await supabase.storage
                    .from("workout-images")
                    .upload(fileName, data: imageData, options: FileOptions(upsert: true))
                
                print("✅ Image uploaded successfully to Supabase Storage: \(fileName)")
                
                // Try to get a signed URL (works for private buckets)
                do {
                    let signedURL = try await supabase.storage
                        .from("workout-images")
                        .createSignedURL(path: fileName, expiresIn: 31536000) // 1 year expiry
                    
                    print("✅ Image signed URL: \(signedURL)")
                    return signedURL.absoluteString
                } catch {
                    print("⚠️ Could not create signed URL, using public URL: \(error)")
                    // Fall back to public URL
                    let publicURL = try supabase.storage
                        .from("workout-images")
                        .getPublicURL(path: fileName)
                    
                    print("✅ Image public URL: \(publicURL)")
                    return publicURL.absoluteString
                }
                
            } catch {
                print("❌ Upload failed or couldn't get URL: \(error)")
                print("⚠️ Cannot save image - upload to Supabase failed")
                // Don't save locally as a fallback - throw error instead
                throw error
            }
            
        } catch {
            print("❌ Error uploading image to Supabase: \(error)")
            // Don't save locally - throw error instead
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
    
    func saveWorkoutPost(_ post: WorkoutPost, routeImage: UIImage? = nil, userImage: UIImage? = nil, earnedPoints: Int = 0) async throws {
        var postToSave = post
        var uploadedRouteImageUrl: String? = nil
        var uploadedUserImageUrl: String? = nil
        
        // Upload route image if provided
        if let routeImage = routeImage {
            do {
                uploadedRouteImageUrl = try await uploadWorkoutImage(routeImage, postId: post.id)
                print("✅ Route image uploaded successfully")
            } catch {
                print("⚠️ Route image upload failed: \(error)")
            }
        }
        
        // Upload user image if provided
        if let userImage = userImage {
            do {
                let userImageFileName = "\(post.id)_user_\(UUID().uuidString).jpg"
                guard let imageData = userImage.jpegData(compressionQuality: 0.8) else {
                    throw NSError(domain: "ImageConversionError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Could not convert image to JPEG"])
                }
                
                print("📤 Uploading user image to Supabase Storage: \(userImageFileName)")
                
                _ = try await supabase.storage
                    .from("workout-images")
                    .upload(userImageFileName, data: imageData, options: FileOptions(upsert: true))
                
                print("✅ User image uploaded successfully")
                
                // Get signed URL
                do {
                    let signedURL = try await supabase.storage
                        .from("workout-images")
                        .createSignedURL(path: userImageFileName, expiresIn: 31536000)
                    uploadedUserImageUrl = signedURL.absoluteString
                } catch {
                    print("⚠️ Could not create signed URL for user image, using public URL")
                    let publicURL = try supabase.storage
                        .from("workout-images")
                        .getPublicURL(path: userImageFileName)
                    uploadedUserImageUrl = publicURL.absoluteString
                }
            } catch {
                print("⚠️ User image upload failed: \(error)")
            }
        }
        
        // Create post with both image URLs
        postToSave = WorkoutPost(
            id: post.id,
            userId: post.userId,
            activityType: post.activityType,
            title: post.title,
            description: post.description,
            distance: post.distance,
            duration: post.duration,
            imageUrl: uploadedRouteImageUrl,
            userImageUrl: uploadedUserImageUrl,
            elevationGain: post.elevationGain,
            maxSpeed: post.maxSpeed
        )
        
        do {
            var minimalPost: [String: AnyEncodable] = [
                "id": AnyEncodable(postToSave.id),
                "user_id": AnyEncodable(postToSave.userId),
                "activity_type": AnyEncodable(postToSave.activityType),
                "title": AnyEncodable(postToSave.title),
                "created_at": AnyEncodable(postToSave.createdAt)
            ]
            
            if let description = postToSave.description, !description.isEmpty {
                minimalPost["description"] = AnyEncodable(description)
            }
            
            if let imageUrl = postToSave.imageUrl, !imageUrl.isEmpty {
                minimalPost["image_url"] = AnyEncodable(imageUrl)
                print("✅ Saving post with route image URL: \(imageUrl)")
            }
            
            if let userImageUrl = postToSave.userImageUrl, !userImageUrl.isEmpty {
                minimalPost["user_image_url"] = AnyEncodable(userImageUrl)
                print("✅ Saving post with user image URL: \(userImageUrl)")
            }
            
            if let distance = postToSave.distance {
                minimalPost["distance"] = AnyEncodable(distance)
            }
            
            if let duration = postToSave.duration {
                minimalPost["duration"] = AnyEncodable(duration)
            }
            
            if let elevationGain = postToSave.elevationGain {
                minimalPost["elevation_gain"] = AnyEncodable(elevationGain)
            }
            
            if let maxSpeed = postToSave.maxSpeed {
                minimalPost["max_speed"] = AnyEncodable(maxSpeed)
            }
            
            try await supabase
                .from("workout_posts")
                .insert(minimalPost)
                .execute()
            print("✅ Workout post saved: \(postToSave.id)")
            
            if earnedPoints > 0 {
                try await ProfileService.shared.updateUserPoints(userId: post.userId, pointsToAdd: earnedPoints)
                print("✅ XP updated: +\(earnedPoints)")
            }
        } catch {
            print("❌ Error saving workout post: \(error)")
            throw error
        }
    }
    
    // Backwards compatibility
    func saveWorkoutPost(_ post: WorkoutPost, image: UIImage? = nil, earnedPoints: Int = 0) async throws {
        try await saveWorkoutPost(post, routeImage: image, userImage: nil, earnedPoints: earnedPoints)
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
