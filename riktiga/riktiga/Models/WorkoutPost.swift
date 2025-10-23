import Foundation

struct WorkoutPost: Codable, Identifiable {
    let id: String
    let userId: String
    let activityType: String
    let title: String
    let description: String
    let imageData: String?
    let createdAt: String
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case activityType = "activity_type"
        case title
        case description
        case imageData = "image_data"
        case createdAt = "created_at"
    }
    
    init(id: String = UUID().uuidString, userId: String, activityType: String, title: String, description: String, imageData: String? = nil) {
        self.id = id
        self.userId = userId
        self.activityType = activityType
        self.title = title
        self.description = description
        self.imageData = imageData
        self.createdAt = ISO8601DateFormatter().string(from: Date())
    }
}
