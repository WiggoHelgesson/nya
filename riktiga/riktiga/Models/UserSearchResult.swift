import Foundation

struct UserSearchResult: Codable, Identifiable {
    let id: String
    let name: String
    let avatarUrl: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case name = "username"
        case avatarUrl = "avatar_url"
        case followerId = "follower_id"
        case followingId = "following_id"
    }
    
    // Custom decoder to handle null username values and JOIN results
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // Handle different possible field names from JOIN queries
        if let followerId = try? container.decode(String.self, forKey: .followerId) {
            id = followerId
        } else if let followingId = try? container.decode(String.self, forKey: .followingId) {
            id = followingId
        } else {
            id = try container.decode(String.self, forKey: .id)
        }
        
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? "Unknown User"
        avatarUrl = try container.decodeIfPresent(String.self, forKey: .avatarUrl)
    }
    
    // Custom encoder to handle encoding
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encodeIfPresent(avatarUrl, forKey: .avatarUrl)
    }
}
