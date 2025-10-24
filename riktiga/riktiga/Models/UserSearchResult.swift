import Foundation

struct UserSearchResult: Codable, Identifiable {
    let id: String
    let name: String
    let email: String
    let avatarUrl: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case email
        case avatarUrl = "avatar_url"
    }
}
