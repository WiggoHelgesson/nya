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
        // Check for existing notification to prevent duplicates
        struct ExistingNotification: Decodable {
            let id: String
        }
        
        let existing: [ExistingNotification] = try await supabase
            .from("notifications")
            .select("id")
            .eq("user_id", value: userId)
            .eq("actor_id", value: likedByUserId)
            .eq("post_id", value: postId)
            .eq("type", value: "like")
            .limit(1)
            .execute()
            .value
        
        if !existing.isEmpty {
            print("⚠️ Like notification already exists, skipping duplicate")
            return
        }
        
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
        
        // Send push notification with post title
        let displayTitle = postTitle.isEmpty ? "ditt inlägg" : postTitle
        await PushNotificationService.shared.sendRealPushNotification(
            toUserId: userId,
            title: "Ny like",
            body: "\(likedByUserName) gav dig en like på \(displayTitle)",
            data: ["type": "like", "post_id": postId, "actor_id": likedByUserId, "actor_avatar": likedByUserAvatar ?? ""]
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
        
        // Send push notification with post title
        let displayTitle = postTitle.isEmpty ? "ditt inlägg" : postTitle
        await PushNotificationService.shared.sendRealPushNotification(
            toUserId: userId,
            title: "Ny kommentar",
            body: "\(commentedByUserName) kommenterade på \(displayTitle)",
            data: ["type": "comment", "post_id": postId, "actor_id": commentedByUserId, "actor_avatar": commentedByUserAvatar ?? ""]
        )
    }
    
    /// Create a reply notification (when someone replies to your comment)
    func createReplyNotification(
        userId: String,
        repliedByUserId: String,
        repliedByUserName: String,
        repliedByUserAvatar: String?,
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
            actor_id: repliedByUserId,
            actor_username: repliedByUserName,
            actor_avatar_url: repliedByUserAvatar,
            type: "reply",
            post_id: postId
        )
        
        try await supabase
            .from("notifications")
            .insert(payload)
            .execute()
        
        print("✅ Created reply notification")
        
        // Send push notification
        let displayTitle = postTitle.isEmpty ? "ett inlägg" : postTitle
        await PushNotificationService.shared.sendRealPushNotification(
            toUserId: userId,
            title: "Nytt svar",
            body: "\(repliedByUserName) svarade på din kommentar på \(displayTitle)",
            data: ["type": "reply", "post_id": postId, "actor_id": repliedByUserId, "actor_avatar": repliedByUserAvatar ?? ""]
        )
    }
    
    /// Create a follow notification
    func createFollowNotification(
        userId: String,
        followedByUserId: String,
        followedByUserName: String,
        followedByUserAvatar: String?
    ) async throws {
        // Check for existing notification to prevent duplicates
        struct ExistingNotification: Decodable {
            let id: String
        }
        
        let existing: [ExistingNotification] = try await supabase
            .from("notifications")
            .select("id")
            .eq("user_id", value: userId)
            .eq("actor_id", value: followedByUserId)
            .eq("type", value: "follow")
            .limit(1)
            .execute()
            .value
        
        if !existing.isEmpty {
            print("⚠️ Follow notification already exists, skipping duplicate")
            return
        }
        
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
        
        // Send push notification with avatar
        await PushNotificationService.shared.sendRealPushNotification(
            toUserId: userId,
            title: "Ny följare",
            body: "\(followedByUserName) började följa dig",
            data: ["type": "follow", "actor_id": followedByUserId, "actor_avatar": followedByUserAvatar ?? ""]
        )
    }
    
    // MARK: - Uppy Notification
    
    /// Send an Uppy notification when someone sends motivation during workout
    func sendUppyNotification(
        toUserId: String,
        fromUserName: String,
        uppyCount: Int
    ) async throws {
        let title = "\(fromUserName) skickade en Uppy 💪"
        let body: String
        
        if uppyCount >= 3 {
            body = "Du fick din 3:e Uppy! +10 poäng 🎉"
        } else {
            body = "Du har nu \(uppyCount) av 3 Uppys!"
        }
        
        // Send push notification
        await PushNotificationService.shared.sendRealPushNotification(
            toUserId: toUserId,
            title: title,
            body: body,
            data: ["type": "uppy", "uppy_count": String(uppyCount)]
        )
        
        print("✅ Sent Uppy push notification to user \(toUserId)")
    }
}


extension Notification.Name {
    static let profileStatsUpdated = Notification.Name("profileStatsUpdated")
    static let profileImageUpdated = Notification.Name("profileImageUpdated")
    static let savedGymWorkoutCreated = Notification.Name("SavedGymWorkoutCreated")
    static let uppyReceived = Notification.Name("uppyReceived")
}
