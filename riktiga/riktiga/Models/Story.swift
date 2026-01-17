import Foundation

// MARK: - Story Model
struct Story: Identifiable, Codable, Equatable {
    let id: String
    let userId: String
    let imageUrl: String
    let createdAt: Date
    let expiresAt: Date
    
    // Joined profile data
    var username: String?
    var avatarUrl: String?
    var isProMember: Bool?
    
    // View tracking
    var hasViewed: Bool = false
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case imageUrl = "image_url"
        case createdAt = "created_at"
        case expiresAt = "expires_at"
        case profiles
    }
    
    struct ProfileData: Codable {
        let username: String?
        let avatar_url: String?
        let is_pro_member: Bool?
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        id = try container.decode(String.self, forKey: .id)
        userId = try container.decode(String.self, forKey: .userId)
        imageUrl = try container.decode(String.self, forKey: .imageUrl)
        
        // Parse dates
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        if let createdAtString = try? container.decode(String.self, forKey: .createdAt) {
            createdAt = dateFormatter.date(from: createdAtString) ?? Date()
        } else {
            createdAt = Date()
        }
        
        if let expiresAtString = try? container.decode(String.self, forKey: .expiresAt) {
            expiresAt = dateFormatter.date(from: expiresAtString) ?? Date().addingTimeInterval(24 * 60 * 60)
        } else {
            expiresAt = Date().addingTimeInterval(24 * 60 * 60)
        }
        
        // Parse joined profile data
        if let profileData = try? container.decode(ProfileData.self, forKey: .profiles) {
            username = profileData.username
            avatarUrl = profileData.avatar_url
            isProMember = profileData.is_pro_member
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(userId, forKey: .userId)
        try container.encode(imageUrl, forKey: .imageUrl)
    }
    
    // Manual init for creating new stories
    init(id: String, userId: String, imageUrl: String, createdAt: Date = Date(), expiresAt: Date? = nil, username: String? = nil, avatarUrl: String? = nil, isProMember: Bool? = nil) {
        self.id = id
        self.userId = userId
        self.imageUrl = imageUrl
        self.createdAt = createdAt
        self.expiresAt = expiresAt ?? createdAt.addingTimeInterval(24 * 60 * 60) // 24 hours
        self.username = username
        self.avatarUrl = avatarUrl
        self.isProMember = isProMember
    }
    
    var isExpired: Bool {
        return Date() > expiresAt
    }
    
    var timeAgo: String {
        let interval = Date().timeIntervalSince(createdAt)
        let hours = Int(interval / 3600)
        let minutes = Int((interval.truncatingRemainder(dividingBy: 3600)) / 60)
        
        if hours > 0 {
            return "\(hours)h"
        } else if minutes > 0 {
            return "\(minutes)m"
        } else {
            return "Nu"
        }
    }
}

// MARK: - User Stories (grouped by user)
struct UserStories: Identifiable, Equatable {
    let id: String // user_id
    let userId: String
    let username: String
    let avatarUrl: String?
    let isProMember: Bool
    var stories: [Story]
    var hasUnviewedStories: Bool
    
    var latestStory: Story? {
        stories.sorted { $0.createdAt > $1.createdAt }.first
    }
}

// MARK: - Story Insert Model
struct StoryInsert: Encodable {
    let id: String
    let user_id: String
    let image_url: String
    let created_at: String
    let expires_at: String
}

// MARK: - Story View Model (for tracking views)
struct StoryViewInsert: Encodable {
    let story_id: String
    let viewer_id: String
    let viewed_at: String
}

