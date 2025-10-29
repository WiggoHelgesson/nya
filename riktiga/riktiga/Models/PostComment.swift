import Foundation

struct PostComment: Codable, Identifiable {
    let id: String
    let postId: String
    let userId: String
    let content: String
    let createdAt: String
    let userName: String?
    let userAvatarUrl: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case postId = "workout_post_id"
        case userId = "user_id"
        case content
        case createdAt = "created_at"
        case userName = "profiles.username"
        case userAvatarUrl = "profiles.avatar_url"
    }
    
    init(id: String = UUID().uuidString, postId: String, userId: String, content: String, userName: String? = nil, userAvatarUrl: String? = nil) {
        self.id = id
        self.postId = postId
        self.userId = userId
        self.content = content
        self.createdAt = ISO8601DateFormatter().string(from: Date())
        self.userName = userName
        self.userAvatarUrl = userAvatarUrl
    }
    
    init(id: String, postId: String, userId: String, content: String, createdAt: String, userName: String? = nil, userAvatarUrl: String? = nil) {
        self.id = id
        self.postId = postId
        self.userId = userId
        self.content = content
        self.createdAt = createdAt
        self.userName = userName
        self.userAvatarUrl = userAvatarUrl
    }
}
