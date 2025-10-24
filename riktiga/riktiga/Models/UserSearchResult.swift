import Foundation

struct UserSearchResult: Codable, Identifiable {
    let id: String
    let name: String
    let avatarUrl: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case name = "username"
        case avatarUrl = "avatar_url"
    }
}
