import Foundation

struct PostComment: Codable, Identifiable {
    let id: String
    let postId: String
    let userId: String
    let content: String
    let createdAt: String
    
    enum CodingKeys: String, CodingKey {
        case id
        case postId = "post_id"
        case userId = "user_id"
        case content
        case createdAt = "created_at"
    }
    
    init(id: String = UUID().uuidString, postId: String, userId: String, content: String) {
        self.id = id
        self.postId = postId
        self.userId = userId
        self.content = content
        self.createdAt = ISO8601DateFormatter().string(from: Date())
    }
}
