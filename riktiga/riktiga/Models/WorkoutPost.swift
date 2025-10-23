import Foundation

struct WorkoutPost: Codable, Identifiable {
    let id: String
    let userId: String
    let activityType: String
    let title: String
    let description: String
    let distance: Double
    let duration: Int
    let imageData: String?
    let createdAt: String
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case activityType = "activity_type"
        case title
        case description
        case distance
        case duration
        case imageData = "image_data"
        case createdAt = "created_at"
    }
    
    init(id: String = UUID().uuidString, userId: String, activityType: String, title: String, description: String, distance: Double, duration: Int, imageData: String? = nil) {
        self.id = id
        self.userId = userId
        self.activityType = activityType
        self.title = title
        self.description = description
        self.distance = distance
        self.duration = duration
        self.imageData = imageData
        self.createdAt = ISO8601DateFormatter().string(from: Date())
    }
}
