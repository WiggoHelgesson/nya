import Foundation

struct Reward: Codable, Identifiable {
    let id: String
    let title: String
    let description: String
    let pointsRequired: Int
    let unlocked: Bool
    
    enum CodingKeys: String, CodingKey {
        case id, title, description, pointsRequired, unlocked
    }
}
