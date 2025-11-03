import Foundation
import Supabase

class NotificationService {
    static let shared = NotificationService()
    private let supabase = SupabaseConfig.supabase
    
    private init() {}
    
    // MARK: - Fetch Notifications
    func getNotifications(userId: String) async throws -> [AppNotification] {
        do {
            let notifications: [AppNotification] = try await supabase
                .from("notifications")
                .select()
                .eq("user_id", value: userId)
                .order("created_at", ascending: false)
                .execute()
                .value
            
            print("✅ Fetched \(notifications.count) notifications for user \(userId)")
            return notifications
        } catch {
            print("❌ Error fetching notifications: \(error)")
            throw error
        }
    }
    
    // MARK: - Create Like Notification
    func createLikeNotification(
        userId: String,
        likedByUserId: String,
        likedByUserName: String,
        likedByUserAvatar: String?,
        postId: String,
        postTitle: String
    ) async throws {
        let notification = [
            "user_id": AnyEncodable(userId),
            "triggered_by_user_id": AnyEncodable(likedByUserId),
            "triggered_by_user_name": AnyEncodable(likedByUserName),
            "triggered_by_user_avatar": AnyEncodable(likedByUserAvatar),
            "actor_id": AnyEncodable(likedByUserId),
            "actor_username": AnyEncodable(likedByUserName),
            "type": AnyEncodable("like"),
            "post_id": AnyEncodable(postId),
            "created_at": AnyEncodable(ISO8601DateFormatter().string(from: Date())),
            "is_read": AnyEncodable(false)
        ]
        
        do {
            try await supabase
                .from("notifications")
                .insert(notification)
                .execute()
            print("✅ Like notification created")
            
            // Send push notification
            NotificationManager.shared.sendLikeNotification(fromUserName: likedByUserName, postTitle: postTitle)
        } catch {
            print("❌ Error creating like notification: \(error)")
            throw error
        }
    }
    
    // MARK: - Create Comment Notification
    func createCommentNotification(
        userId: String,
        commentedByUserId: String,
        commentedByUserName: String,
        commentedByUserAvatar: String?,
        postId: String,
        postTitle: String,
        commentText: String
    ) async throws {
        let notification = [
            "user_id": AnyEncodable(userId),
            "triggered_by_user_id": AnyEncodable(commentedByUserId),
            "triggered_by_user_name": AnyEncodable(commentedByUserName),
            "triggered_by_user_avatar": AnyEncodable(commentedByUserAvatar),
            "actor_id": AnyEncodable(commentedByUserId),
            "actor_username": AnyEncodable(commentedByUserName),
            "type": AnyEncodable("comment"),
            "post_id": AnyEncodable(postId),
            "created_at": AnyEncodable(ISO8601DateFormatter().string(from: Date())),
            "is_read": AnyEncodable(false)
        ]
        
        do {
            try await supabase
                .from("notifications")
                .insert(notification)
                .execute()
            print("✅ Comment notification created")
            
            // Send push notification
            NotificationManager.shared.sendCommentNotification(fromUserName: commentedByUserName, commentText: commentText)
        } catch {
            print("❌ Error creating comment notification: \(error)")
            throw error
        }
    }
    
    // MARK: - Create Follow Notification
    func createFollowNotification(
        userId: String,
        followedByUserId: String,
        followedByUserName: String,
        followedByUserAvatar: String?
    ) async throws {
        // Remove any existing follow notification from the same actor to prevent duplicates
        do {
            try await supabase
                .from("notifications")
                .delete()
                .eq("user_id", value: userId)
                .eq("actor_id", value: followedByUserId)
                .eq("type", value: "follow")
                .execute()
        } catch {
            print("⚠️ Failed to clear existing follow notification: \(error)")
        }
        
        let notification = [
            "user_id": AnyEncodable(userId),
            "triggered_by_user_id": AnyEncodable(followedByUserId),
            "triggered_by_user_name": AnyEncodable(followedByUserName),
            "triggered_by_user_avatar": AnyEncodable(followedByUserAvatar),
            "actor_id": AnyEncodable(followedByUserId),
            "actor_username": AnyEncodable(followedByUserName),
            "type": AnyEncodable("follow"),
            "post_id": AnyEncodable(NSNull()),
            "created_at": AnyEncodable(ISO8601DateFormatter().string(from: Date())),
            "is_read": AnyEncodable(false)
        ]
        
        do {
            try await supabase
                .from("notifications")
                .insert(notification)
                .execute()
            print("✅ Follow notification created")
            
            // Send push notification
            NotificationManager.shared.sendFollowNotification(fromUserName: followedByUserName)
        } catch {
            print("❌ Error creating follow notification: \(error)")
            throw error
        }
    }
    
    // MARK: - Mark as Read
    func markAsRead(notificationId: String) async throws {
        do {
            try await supabase
                .from("notifications")
                .update(["is_read": AnyEncodable(true)])
                .eq("id", value: notificationId)
                .execute()
            print("✅ Notification marked as read")
        } catch {
            print("❌ Error marking notification as read: \(error)")
            throw error
        }
    }
    
    // MARK: - Delete Notification
    func deleteNotification(notificationId: String) async throws {
        do {
            try await supabase
                .from("notifications")
                .delete()
                .eq("id", value: notificationId)
                .execute()
            print("✅ Notification deleted")
        } catch {
            print("❌ Error deleting notification: \(error)")
            throw error
        }
    }
    
    // MARK: - Unread Count
    func getUnreadCount(userId: String) async throws -> Int {
        do {
            let response = try await supabase
                .from("notifications")
                .select("id", count: .exact)
                .eq("user_id", value: userId)
                .eq("is_read", value: false)
                .execute()
            return response.count ?? 0
        } catch {
            print("❌ Error fetching unread notification count: \(error)")
            throw error
        }
    }
    
    func markAllAsRead(userId: String) async throws {
        do {
            try await supabase
                .from("notifications")
                .update(["is_read": AnyEncodable(true)])
                .eq("user_id", value: userId)
                .eq("is_read", value: false)
                .execute()
            print("✅ Marked all notifications as read for user \(userId)")
        } catch {
            print("❌ Error marking all notifications as read: \(error)")
            throw error
        }
    }
}
