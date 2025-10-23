import Foundation

struct Activity: Codable, Identifiable {
    let id: String
    let title: String
    let description: String
    let duration: Int // minuter
    let caloriesBurned: Int
    let date: Date
    
    enum CodingKeys: String, CodingKey {
        case id, title, description, duration, caloriesBurned, date
    }
}
