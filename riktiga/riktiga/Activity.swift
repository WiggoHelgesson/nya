import Foundation

struct Activity: Codable, Identifiable {
    let id: String
    let userId: String
    let title: String
    let description: String
    let duration: Int // minuter
    let distance: Double // km
    let caloriesBurned: Int
    let createdAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case title, description, duration, distance, caloriesBurned
        case createdAt = "created_at"
    }
}
