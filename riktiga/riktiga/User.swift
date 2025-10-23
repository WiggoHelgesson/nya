import Foundation

struct User: Codable, Identifiable {
    let id: String
    let name: String
    let email: String
    var currentXP: Int = 0
    var currentLevel: Int = 0
    var isProMember: Bool = false
    
    enum CodingKeys: String, CodingKey {
        case id
        case name = "username"
        case email
        case currentXP = "current_xp"
        case currentLevel = "current_level"
        case isProMember = "is_pro_member"
    }
}
