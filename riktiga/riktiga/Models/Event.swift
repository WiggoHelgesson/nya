import Foundation

// MARK: - Event Model
struct Event: Codable, Identifiable, Hashable {
    static func == (lhs: Event, rhs: Event) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    let id: String
    let userId: String
    let title: String
    let description: String
    let coverImageUrl: String
    let createdAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case title
        case description
        case coverImageUrl = "cover_image_url"
        case createdAt = "created_at"
    }
    
    init(id: String, userId: String, title: String, description: String, coverImageUrl: String, createdAt: Date = Date()) {
        self.id = id
        self.userId = userId
        self.title = title
        self.description = description
        self.coverImageUrl = coverImageUrl
        self.createdAt = createdAt
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        userId = try container.decode(String.self, forKey: .userId)
        title = try container.decode(String.self, forKey: .title)
        description = try container.decode(String.self, forKey: .description)
        coverImageUrl = try container.decode(String.self, forKey: .coverImageUrl)
        
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        if let dateString = try? container.decode(String.self, forKey: .createdAt) {
            createdAt = dateFormatter.date(from: dateString) ?? Date()
        } else {
            createdAt = Date()
        }
    }
}

// MARK: - Event Image Model
struct EventImage: Codable, Identifiable {
    let id: String
    let eventId: String
    let imageUrl: String
    let sortOrder: Int
    
    enum CodingKeys: String, CodingKey {
        case id
        case eventId = "event_id"
        case imageUrl = "image_url"
        case sortOrder = "sort_order"
    }
}

// MARK: - Insert Models
struct EventInsert: Encodable {
    let id: String
    let user_id: String
    let title: String
    let description: String
    let cover_image_url: String
}

struct EventImageInsert: Encodable {
    let id: String
    let event_id: String
    let image_url: String
    let sort_order: Int
}
