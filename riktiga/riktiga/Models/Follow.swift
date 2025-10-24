import Foundation

struct Follow: Codable, Identifiable {
    let id: String
    let followerId: String
    let followingId: String
    let createdAt: String
    
    enum CodingKeys: String, CodingKey {
        case id
        case followerId = "follower_id"
        case followingId = "following_id"
        case createdAt = "created_at"
    }
    
    init(id: String = UUID().uuidString, followerId: String, followingId: String) {
        self.id = id
        self.followerId = followerId
        self.followingId = followingId
        self.createdAt = ISO8601DateFormatter().string(from: Date())
    }
}
