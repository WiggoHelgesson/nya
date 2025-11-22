import Foundation

struct AppNotification: Identifiable, Codable {
    let id: String
    let userId: String // Mottagare
    let actorId: String // Den som utförde handlingen
    let actorUsername: String?
    let actorAvatarUrl: String?
    let type: NotificationType
    let postId: String?
    let commentText: String?
    let createdAt: String
    var isRead: Bool
    
    enum NotificationType: String, Codable {
        case like = "like"
        case comment = "comment"
        case follow = "follow"
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case actorId = "actor_id"
        case actorUsername = "actor_username"
        case actorAvatarUrl = "actor_avatar_url"
        case type
        case postId = "post_id"
        case commentText = "comment_text"
        case createdAt = "created_at"
        case isRead = "is_read"
    }
    
    var displayText: String {
        switch type {
        case .like:
            return "\(actorUsername ?? "Någon") gillade ditt inlägg"
        case .comment:
            if let text = commentText, !text.isEmpty {
                return "\(actorUsername ?? "Någon") kommenterade: \"\(text)\""
            }
            return "\(actorUsername ?? "Någon") kommenterade på ditt inlägg"
        case .follow:
            return "\(actorUsername ?? "Någon") började följa dig"
        }
    }
    
    var icon: String {
        switch type {
        case .like:
            return "heart.fill"
        case .comment:
            return "bubble.right.fill"
        case .follow:
            return "person.fill.badge.plus"
        }
    }
    
    var iconColor: String {
        switch type {
        case .like:
            return "red"
        case .comment:
            return "blue"
        case .follow:
            return "green"
        }
    }
}

