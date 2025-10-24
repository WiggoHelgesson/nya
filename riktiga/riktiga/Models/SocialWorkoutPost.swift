import Foundation

struct SocialWorkoutPost: Codable, Identifiable {
    let id: String
    let userId: String
    let activityType: String
    let title: String
    let description: String?
    let distance: Double?
    let duration: Int?
    let imageUrl: String?
    let createdAt: String
    
    // Social data
    let userName: String?
    let userAvatarUrl: String?
    let likeCount: Int?
    let commentCount: Int?
    let isLikedByCurrentUser: Bool?
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case activityType = "activity_type"
        case title
        case description
        case distance
        case duration
        case imageUrl = "image_url"
        case createdAt = "created_at"
        case userName = "user_name"
        case userAvatarUrl = "user_avatar_url"
        case likeCount = "like_count"
        case commentCount = "comment_count"
        case isLikedByCurrentUser = "is_liked_by_current_user"
    }
    
    init(from post: WorkoutPost, userName: String? = nil, userAvatarUrl: String? = nil, likeCount: Int = 0, commentCount: Int = 0, isLikedByCurrentUser: Bool = false) {
        self.id = post.id
        self.userId = post.userId
        self.activityType = post.activityType
        self.title = post.title
        self.description = post.description
        self.distance = post.distance
        self.duration = post.duration
        self.imageUrl = post.imageUrl
        self.createdAt = post.createdAt
        self.userName = userName
        self.userAvatarUrl = userAvatarUrl
        self.likeCount = likeCount
        self.commentCount = commentCount
        self.isLikedByCurrentUser = isLikedByCurrentUser
    }
}
