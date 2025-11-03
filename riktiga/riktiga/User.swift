import Foundation

struct User: Codable, Identifiable {
    let id: String
    var name: String
    var email: String
    var currentXP: Int = 0
    var currentLevel: Int = 0
    var isProMember: Bool = false
    var avatarUrl: String? = nil
    var pb5kmMinutes: Int? = nil
    var pb10kmHours: Int? = nil
    var pb10kmMinutes: Int? = nil
    var pbMarathonHours: Int? = nil
    var pbMarathonMinutes: Int? = nil
    
    enum CodingKeys: String, CodingKey {
        case id
        case name = "username"
        case email
        case currentXP = "current_xp"
        case currentLevel = "current_level"
        case isProMember = "is_pro_member"
        case avatarUrl = "avatar_url"
        case pb5kmMinutes = "pb_5km_minutes"
        case pb10kmHours = "pb_10km_hours"
        case pb10kmMinutes = "pb_10km_minutes"
        case pbMarathonHours = "pb_marathon_hours"
        case pbMarathonMinutes = "pb_marathon_minutes"
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
        avatarUrl = try container.decodeIfPresent(String.self, forKey: .avatarUrl)
        pb5kmMinutes = try container.decodeIfPresent(Int.self, forKey: .pb5kmMinutes)
        pb10kmHours = try container.decodeIfPresent(Int.self, forKey: .pb10kmHours)
        pb10kmMinutes = try container.decodeIfPresent(Int.self, forKey: .pb10kmMinutes)
        pbMarathonHours = try container.decodeIfPresent(Int.self, forKey: .pbMarathonHours)
        pbMarathonMinutes = try container.decodeIfPresent(Int.self, forKey: .pbMarathonMinutes)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(email, forKey: .email)
        try container.encode(currentXP, forKey: .currentXP)
        try container.encode(currentLevel, forKey: .currentLevel)
        try container.encode(isProMember, forKey: .isProMember)
        try container.encodeIfPresent(avatarUrl, forKey: .avatarUrl)
        try container.encodeIfPresent(pb5kmMinutes, forKey: .pb5kmMinutes)
        try container.encodeIfPresent(pb10kmHours, forKey: .pb10kmHours)
        try container.encodeIfPresent(pb10kmMinutes, forKey: .pb10kmMinutes)
        try container.encodeIfPresent(pbMarathonHours, forKey: .pbMarathonHours)
        try container.encodeIfPresent(pbMarathonMinutes, forKey: .pbMarathonMinutes)
    }
    
    init(id: String, name: String, email: String, currentXP: Int = 0, currentLevel: Int = 0, isProMember: Bool = false, avatarUrl: String? = nil, pb5kmMinutes: Int? = nil, pb10kmHours: Int? = nil, pb10kmMinutes: Int? = nil, pbMarathonHours: Int? = nil, pbMarathonMinutes: Int? = nil) {
        self.id = id
        self.name = name
        self.email = email
        self.currentXP = currentXP
        self.currentLevel = currentLevel
        self.isProMember = isProMember
        self.avatarUrl = avatarUrl
        self.pb5kmMinutes = pb5kmMinutes
        self.pb10kmHours = pb10kmHours
        self.pb10kmMinutes = pb10kmMinutes
        self.pbMarathonHours = pbMarathonHours
        self.pbMarathonMinutes = pbMarathonMinutes
    }
}
