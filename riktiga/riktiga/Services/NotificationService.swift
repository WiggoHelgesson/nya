import Foundation
import Supabase

@MainActor
final class NotificationService {
    static let shared = NotificationService()
    private let supabase = SupabaseConfig.supabase
    
    private init() {}
    
    /// Fetch notifications for the current user
    func fetchNotifications(userId: String) async throws -> [AppNotification] {
        print("🔔 Fetching notifications for user: \(userId)")
        
        // Ensure valid session for RLS
        try await AuthSessionManager.shared.ensureValidSession()
        
        let notifications: [AppNotification] = try await supabase
            .from("notifications")
            .select("*")
            .eq("user_id", value: userId)
            .order("created_at", ascending: false)
            .limit(50)
            .execute()
            .value
        
        print("✅ Fetched \(notifications.count) notifications")
        
        return notifications
    }
    
    /// Get count of unread notifications
    func fetchUnreadCount(userId: String) async throws -> Int {
        // Ensure valid session for RLS
        try await AuthSessionManager.shared.ensureValidSession()
        
        struct CountResponse: Decodable {
            let count: Int
        }
        
        let response: PostgrestResponse<[AppNotification]> = try await supabase
            .from("notifications")
            .select("*", count: .exact)
            .eq("user_id", value: userId)
            .eq("is_read", value: false)
            .execute()
        
        let count = response.count ?? 0
        print("🔔 Unread notifications: \(count)")
        
        return count
    }
    
    /// Mark a notification as read
    func markAsRead(notificationId: String) async throws {
        // Ensure valid session for RLS
        try await AuthSessionManager.shared.ensureValidSession()
        
        try await supabase
            .from("notifications")
            .update(["is_read": true])
            .eq("id", value: notificationId)
            .execute()
        
        print("✅ Marked notification as read: \(notificationId)")
    }
    
    /// Mark all notifications as read
    func markAllAsRead(userId: String) async throws {
        // Ensure valid session for RLS
        try await AuthSessionManager.shared.ensureValidSession()
        
        try await supabase
            .from("notifications")
            .update(["is_read": true])
            .eq("user_id", value: userId)
            .eq("is_read", value: false)
            .execute()
        
        print("✅ Marked all notifications as read")
    }
    
    /// Create a like notification
    func createLikeNotification(
        userId: String,
        likedByUserId: String,
        likedByUserName: String,
        likedByUserAvatar: String?,
        postId: String,
        postTitle: String
    ) async throws {
        struct Payload: Encodable {
            let user_id: String
            let actor_id: String
            let actor_username: String
            let actor_avatar_url: String?
            let type: String
            let post_id: String
        }
        
        let payload = Payload(
            user_id: userId,
            actor_id: likedByUserId,
            actor_username: likedByUserName,
            actor_avatar_url: likedByUserAvatar,
            type: "like",
            post_id: postId
        )
        
        try await supabase
            .from("notifications")
            .insert(payload)
            .execute()
        
        print("✅ Created like notification")
        
        // Send push notification
        await PushNotificationService.shared.sendRealPushNotification(
            toUserId: userId,
            title: "Ny like",
            body: "\(likedByUserName) gillade ditt inlägg",
            data: ["type": "like", "post_id": postId, "actor_id": likedByUserId]
        )
    }
    
    /// Create a comment notification
    func createCommentNotification(
        userId: String,
        commentedByUserId: String,
        commentedByUserName: String,
        commentedByUserAvatar: String?,
        postId: String,
        postTitle: String,
        commentText: String
    ) async throws {
        struct Payload: Encodable {
            let user_id: String
            let actor_id: String
            let actor_username: String
            let actor_avatar_url: String?
            let type: String
            let post_id: String
        }
        
        let payload = Payload(
            user_id: userId,
            actor_id: commentedByUserId,
            actor_username: commentedByUserName,
            actor_avatar_url: commentedByUserAvatar,
            type: "comment",
            post_id: postId
        )
        
        try await supabase
            .from("notifications")
            .insert(payload)
            .execute()
        
        print("✅ Created comment notification")
        
        // Send push notification
        await PushNotificationService.shared.sendRealPushNotification(
            toUserId: userId,
            title: "Ny kommentar",
            body: "\(commentedByUserName) kommenterade ditt inlägg",
            data: ["type": "comment", "post_id": postId, "actor_id": commentedByUserId]
        )
    }
    
    /// Create a follow notification
    func createFollowNotification(
        userId: String,
        followedByUserId: String,
        followedByUserName: String,
        followedByUserAvatar: String?
    ) async throws {
        struct Payload: Encodable {
            let user_id: String
            let actor_id: String
            let actor_username: String
            let actor_avatar_url: String?
            let type: String
        }
        
        let payload = Payload(
            user_id: userId,
            actor_id: followedByUserId,
            actor_username: followedByUserName,
            actor_avatar_url: followedByUserAvatar,
            type: "follow"
        )
        
        try await supabase
            .from("notifications")
            .insert(payload)
            .execute()
        
        print("✅ Created follow notification")
        
        // Send push notification
        await PushNotificationService.shared.sendRealPushNotification(
            toUserId: userId,
            title: "Ny följare",
            body: "\(followedByUserName) började följa dig",
            data: ["type": "follow", "actor_id": followedByUserId]
        )
    }
}


extension Notification.Name {
    static let profileStatsUpdated = Notification.Name("profileStatsUpdated")
    static let profileImageUpdated = Notification.Name("profileImageUpdated")
    static let savedGymWorkoutCreated = Notification.Name("SavedGymWorkoutCreated")
}
