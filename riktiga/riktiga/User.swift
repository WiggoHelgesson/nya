import Foundation

struct User: Codable, Identifiable {
    let id: String
    var name: String
    var email: String
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
    
    // Custom decode för att hantera att email inte finns i profiles
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        email = try container.decodeIfPresent(String.self, forKey: .email) ?? ""
        currentXP = try container.decodeIfPresent(Int.self, forKey: .currentXP) ?? 0
        currentLevel = try container.decodeIfPresent(Int.self, forKey: .currentLevel) ?? 0
        isProMember = try container.decodeIfPresent(Bool.self, forKey: .isProMember) ?? false
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(email, forKey: .email)
        try container.encode(currentXP, forKey: .currentXP)
        try container.encode(currentLevel, forKey: .currentLevel)
        try container.encode(isProMember, forKey: .isProMember)
    }
    
    init(id: String, name: String, email: String, currentXP: Int = 0, currentLevel: Int = 0, isProMember: Bool = false) {
        self.id = id
        self.name = name
        self.email = email
        self.currentXP = currentXP
        self.currentLevel = currentLevel
        self.isProMember = isProMember
    }
}
