import Foundation

struct WorkoutPost: Codable, Identifiable {
    let id: String
    let userId: String
    let activityType: String
    let title: String
    let description: String?
    let distance: Double?
    let duration: Int?
    let imageUrl: String? // Route image
    let userImageUrl: String? // User's own image
    let elevationGain: Double?
    let maxSpeed: Double?
    let createdAt: String
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case activityType = "activity_type"
        case title
        case description
        case distance
        case duration
        case imageUrl = "image_url"
        case userImageUrl = "user_image_url"
        case elevationGain = "elevation_gain"
        case maxSpeed = "max_speed"
        case createdAt = "created_at"
    }
    
    init(id: String = UUID().uuidString, userId: String, activityType: String, title: String, description: String? = nil, distance: Double? = nil, duration: Int? = nil, imageUrl: String? = nil, userImageUrl: String? = nil, elevationGain: Double? = nil, maxSpeed: Double? = nil) {
        self.id = id
        self.userId = userId
        self.activityType = activityType
        self.title = title
        self.description = description
        self.distance = distance
        self.duration = duration
        self.imageUrl = imageUrl
        self.userImageUrl = userImageUrl
        self.elevationGain = elevationGain
        self.maxSpeed = maxSpeed
        self.createdAt = ISO8601DateFormatter().string(from: Date())
    }
}
