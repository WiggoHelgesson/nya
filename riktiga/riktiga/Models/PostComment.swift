import Foundation

struct PostComment: Codable, Identifiable {
    let id: String
    let postId: String
    let userId: String
    let content: String
    let createdAt: String
    let userName: String?
    let userAvatarUrl: String?
    let parentCommentId: String?
    var likeCount: Int
    var isLikedByCurrentUser: Bool
    
    private enum AdditionalKeys: String, CodingKey {
        case likeCount
        case isLikedByCurrentUser
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case postId = "workout_post_id"
        case userId = "user_id"
        case content
        case createdAt = "created_at"
        case profiles // This matches the JSON key "profiles"
        case userName = "username" // These might not be needed if we decode manually
        case userAvatarUrl = "avatar_url"
        case parentCommentId = "parent_comment_id"
    }
    
    init(id: String = UUID().uuidString,
         postId: String,
         userId: String,
         content: String,
         createdAt: String = ISO8601DateFormatter().string(from: Date()),
         userName: String? = nil,
         userAvatarUrl: String? = nil,
         parentCommentId: String? = nil,
         likeCount: Int = 0,
         isLikedByCurrentUser: Bool = false) {
        self.id = id
        self.postId = postId
        self.userId = userId
        self.content = content
        self.createdAt = createdAt
        self.userName = userName
        self.userAvatarUrl = userAvatarUrl
        self.parentCommentId = parentCommentId
        self.likeCount = likeCount
        self.isLikedByCurrentUser = isLikedByCurrentUser
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        self.id = try container.decode(String.self, forKey: .id)
        self.postId = try container.decode(String.self, forKey: .postId)
        self.userId = try container.decode(String.self, forKey: .userId)
        self.content = try container.decode(String.self, forKey: .content)
        self.createdAt = try container.decode(String.self, forKey: .createdAt)
        self.parentCommentId = try container.decodeIfPresent(String.self, forKey: .parentCommentId)
        
        // Handle nested profiles data
        struct ProfileData: Decodable {
            let username: String?
            let avatar_url: String?
        }
        
        // Check if "profiles" key exists and decode it
        if let profiles = try? container.decodeIfPresent(ProfileData.self, forKey: .profiles) {
             self.userName = profiles.username
             self.userAvatarUrl = profiles.avatar_url
        } else {
             self.userName = nil
             self.userAvatarUrl = nil
        }

        // Handle additional keys safely
        if let additional = try? decoder.container(keyedBy: AdditionalKeys.self) {
            self.likeCount = try additional.decodeIfPresent(Int.self, forKey: .likeCount) ?? 0
            self.isLikedByCurrentUser = try additional.decodeIfPresent(Bool.self, forKey: .isLikedByCurrentUser) ?? false
        } else {
            self.likeCount = 0
            self.isLikedByCurrentUser = false
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(postId, forKey: .postId)
        try container.encode(userId, forKey: .userId)
        try container.encode(content, forKey: .content)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encodeIfPresent(userName, forKey: .userName)
        try container.encodeIfPresent(userAvatarUrl, forKey: .userAvatarUrl)
        try container.encodeIfPresent(parentCommentId, forKey: .parentCommentId)
        
        var additional = encoder.container(keyedBy: AdditionalKeys.self)
        try additional.encode(likeCount, forKey: .likeCount)
        try additional.encode(isLikedByCurrentUser, forKey: .isLikedByCurrentUser)
    }
}
