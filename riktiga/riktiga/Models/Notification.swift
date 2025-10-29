import Foundation

struct AppNotification: Codable, Identifiable {
    let id: String
    let userId: String // Recipient user ID
    let triggeredByUserId: String // User who performed the action
    let triggeredByUserName: String
    let triggeredByUserAvatar: String?
    let type: NotificationType
    let postId: String? // For likes and comments
    let description: String
    let createdAt: String
    let isRead: Bool
    
    enum NotificationType: String, Codable {
        case like = "like"
        case comment = "comment"
        case follow = "follow"
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case triggeredByUserId = "triggered_by_user_id"
        case triggeredByUserName = "triggered_by_user_name"
        case triggeredByUserAvatar = "triggered_by_user_avatar"
        case type
        case postId = "post_id"
        case description
        case createdAt = "created_at"
        case isRead = "is_read"
    }
    
    // Custom decoder to handle missing fields
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        id = try container.decodeIfPresent(String.self, forKey: .id) ?? UUID().uuidString
        userId = try container.decodeIfPresent(String.self, forKey: .userId) ?? ""
        triggeredByUserId = try container.decodeIfPresent(String.self, forKey: .triggeredByUserId) ?? ""
        triggeredByUserName = try container.decodeIfPresent(String.self, forKey: .triggeredByUserName) ?? "Unknown User"
        triggeredByUserAvatar = try container.decodeIfPresent(String.self, forKey: .triggeredByUserAvatar)
        type = try container.decodeIfPresent(NotificationType.self, forKey: .type) ?? .like
        postId = try container.decodeIfPresent(String.self, forKey: .postId)
        description = try container.decodeIfPresent(String.self, forKey: .description) ?? ""
        createdAt = try container.decodeIfPresent(String.self, forKey: .createdAt) ?? ISO8601DateFormatter().string(from: Date())
        isRead = try container.decodeIfPresent(Bool.self, forKey: .isRead) ?? false
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(userId, forKey: .userId)
        try container.encode(triggeredByUserId, forKey: .triggeredByUserId)
        try container.encode(triggeredByUserName, forKey: .triggeredByUserName)
        try container.encodeIfPresent(triggeredByUserAvatar, forKey: .triggeredByUserAvatar)
        try container.encode(type, forKey: .type)
        try container.encodeIfPresent(postId, forKey: .postId)
        try container.encode(description, forKey: .description)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(isRead, forKey: .isRead)
    }
}
