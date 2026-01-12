import Foundation

struct OnboardingData {
    var username: String = ""
    var firstName: String = ""
    var lastName: String = ""
    var selectedSports: [String] = []
    var fitnessLevel: String = ""
    var goals: [String] = []
    var locationAuthorized: Bool = false
    var appleHealthAuthorized: Bool = true
    var golfHcp: Int?
    var pb5kmMinutes: Int?
    var pb10kmHours: Int?
    var pb10kmMinutes: Int?
    var pbMarathonHours: Int?
    var pbMarathonMinutes: Int?
    var notificationsAuthorized: Bool = false
    var healthAuthorized: Bool = true
    var profileImageData: Data? = nil
    
    var trimmedUsername: String {
        username.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    var hasRunningPB: Bool {
        pb5kmMinutes != nil || pb10kmHours != nil || pb10kmMinutes != nil || pbMarathonHours != nil || pbMarathonMinutes != nil
    }
}
