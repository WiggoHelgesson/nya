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
        if value is NSNull {
            var container = encoder.singleValueContainer()
            try container.encodeNil()
            return
        }
        
        if let dict = value as? [String: Any] {
            var container = encoder.container(keyedBy: DynamicCodingKeys.self)
            for (key, nestedValue) in dict {
                if let codingKey = DynamicCodingKeys(stringValue: key) {
                    try container.encode(AnyEncodable(nestedValue), forKey: codingKey)
                }
            }
            return
        }
        
        if let array = value as? [Any] {
            var container = encoder.unkeyedContainer()
            for element in array {
                try container.encode(AnyEncodable(element))
            }
            return
        }
        
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
        case let date as Date:
            try container.encode(date.iso8601String)
        case let encodable as Encodable:
            try encodable.encode(to: encoder)
        default:
            try container.encode(String(describing: value))
        }
    }
    
    private struct DynamicCodingKeys: CodingKey {
        var stringValue: String
        var intValue: Int?
        init?(stringValue: String) { self.stringValue = stringValue; self.intValue = nil }
        init?(intValue: Int) { self.stringValue = "\(intValue)"; self.intValue = intValue }
    }
}

private extension Date {
    var iso8601String: String {
        ISO8601DateFormatter().string(from: self)
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
        try await AuthSessionManager.shared.ensureValidSession()
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
            maxSpeed: post.maxSpeed,
            splits: post.splits
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
            if let splits = postToSave.splits, let splitPayload = encodeSplits(splits) {
                minimalPost["split_data"] = AnyEncodable(splitPayload)
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
        try await AuthSessionManager.shared.ensureValidSession()
        let posts: [WorkoutPost] = try await supabase
            .from("workout_posts")
            .select()
            .eq("user_id", value: userId)
            .order("created_at", ascending: false)
            .execute()
            .value
        print("✅ Fetched \(posts.count) workout posts")
        return posts
    }
    
    func fetchAllWorkoutPosts() async throws -> [WorkoutPost] {
        try await AuthSessionManager.shared.ensureValidSession()
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
    
    func deleteWorkoutPost(postId: String, userId: String) async throws {
        try await AuthSessionManager.shared.ensureValidSession()
        print("🗑️ Deleting workout post: \(postId)")
        
        // First, get the post to find image URLs
        let response: [WorkoutPost] = try await supabase
            .from("workout_posts")
            .select()
            .eq("id", value: postId)
            .eq("user_id", value: userId)
            .execute()
            .value
        
        guard let post = response.first else {
            print("⚠️ Post not found or user doesn't own it")
            return
        }
        
        // Delete images from storage if they exist
        if let imageUrl = post.imageUrl, !imageUrl.isEmpty {
            // Extract filename from URL
            if let filename = imageUrl.components(separatedBy: "/").last {
                do {
                    try await supabase.storage
                        .from("workout-images")
                        .remove(paths: [filename])
                    print("✅ Deleted route image: \(filename)")
                } catch {
                    print("⚠️ Could not delete route image: \(error)")
                }
            }
        }
        
        if let userImageUrl = post.userImageUrl, !userImageUrl.isEmpty {
            // Extract filename from URL
            if let filename = userImageUrl.components(separatedBy: "/").last {
                do {
                    try await supabase.storage
                        .from("workout-images")
                        .remove(paths: [filename])
                    print("✅ Deleted user image: \(filename)")
                } catch {
                    print("⚠️ Could not delete user image: \(error)")
                }
            }
        }
        
        // Delete all likes for this post
        try await supabase
            .from("workout_post_likes")
            .delete()
            .eq("workout_post_id", value: postId)
            .execute()
        print("✅ Deleted all likes for post")
        
        // Delete all comments for this post
        try await supabase
            .from("workout_post_comments")
            .delete()
            .eq("workout_post_id", value: postId)
            .execute()
        print("✅ Deleted all comments for post")
        
        // Delete the post itself
        try await supabase
            .from("workout_posts")
            .delete()
            .eq("id", value: postId)
            .eq("user_id", value: userId)
            .execute()
        print("✅ Deleted workout post from database")
        
        // TODO: Should also subtract points from user's XP
    }
}

private func encodeSplits(_ splits: [WorkoutSplit]) -> [[String: Any]]? {
    let encoder = JSONEncoder()
    guard let data = try? encoder.encode(splits),
          let json = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
        return nil
    }
    return json
}
