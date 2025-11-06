import Foundation

struct RaceMemory: Codable, Identifiable {
    let id: String
    let userId: String
    let raceId: String
    let imageUrl: String
    let createdAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case raceId = "race_id"
        case imageUrl = "image_url"
        case createdAt = "created_at"
    }
    
    init(id: String, userId: String, raceId: String, imageUrl: String, createdAt: Date) {
        self.id = id
        self.userId = userId
        self.raceId = raceId
        self.imageUrl = imageUrl
        self.createdAt = createdAt
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        userId = try container.decode(String.self, forKey: .userId)
        raceId = try container.decode(String.self, forKey: .raceId)
        imageUrl = try container.decode(String.self, forKey: .imageUrl)
        
        // Decode date string to Date
        let dateString = try container.decode(String.self, forKey: .createdAt)
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: dateString) {
            createdAt = date
        } else {
            // Fallback without fractional seconds
            formatter.formatOptions = [.withInternetDateTime]
            createdAt = formatter.date(from: dateString) ?? Date()
        }
    }
}


