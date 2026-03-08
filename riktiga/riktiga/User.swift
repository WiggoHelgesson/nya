import Foundation

struct User: Codable, Identifiable {
    let id: String
    var name: String
    var email: String
    var currentXP: Int = 0
    var currentLevel: Int = 0
    var isProMember: Bool = false
    var avatarUrl: String? = nil
    var bannerUrl: String? = nil
    var pb5kmMinutes: Int? = nil
    var pb10kmHours: Int? = nil
    var pb10kmMinutes: Int? = nil
    var pbMarathonHours: Int? = nil
    var pbMarathonMinutes: Int? = nil
    var climbedMountains: [String] = []
    var completedRaces: [String] = []
    var onboardingCompleted: Bool = false
    var bio: String? = nil
    var pinnedPostIds: [String] = []
    var gymPbs: [GymPB] = []
    var homeGym: String? = nil
    var trainingGoal: String? = nil
    var trainingIdentity: String? = nil
    
    enum CodingKeys: String, CodingKey {
        case id
        case name = "username"
        case email
        case currentXP = "current_xp"
        case currentLevel = "current_level"
        case isProMember = "is_pro_member"
        case avatarUrl = "avatar_url"
        case bannerUrl = "banner_url"
        case pb5kmMinutes = "pb_5km_minutes"
        case pb10kmHours = "pb_10km_hours"
        case pb10kmMinutes = "pb_10km_minutes"
        case pbMarathonHours = "pb_marathon_hours"
        case pbMarathonMinutes = "pb_marathon_minutes"
        case climbedMountains = "climbed_mountains"
        case completedRaces = "completed_races"
        case onboardingCompleted = "onboarding_completed"
        case bio
        case pinnedPostIds = "pinned_post_ids"
        case gymPbs = "gym_pbs"
        case homeGym = "home_gym"
        case trainingGoal = "training_goal"
        case trainingIdentity = "training_identity"
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
        bannerUrl = try container.decodeIfPresent(String.self, forKey: .bannerUrl)
        pb5kmMinutes = try container.decodeIfPresent(Int.self, forKey: .pb5kmMinutes)
        pb10kmHours = try container.decodeIfPresent(Int.self, forKey: .pb10kmHours)
        pb10kmMinutes = try container.decodeIfPresent(Int.self, forKey: .pb10kmMinutes)
        pbMarathonHours = try container.decodeIfPresent(Int.self, forKey: .pbMarathonHours)
        pbMarathonMinutes = try container.decodeIfPresent(Int.self, forKey: .pbMarathonMinutes)
        climbedMountains = try container.decodeIfPresent([String].self, forKey: .climbedMountains) ?? []
        completedRaces = try container.decodeIfPresent([String].self, forKey: .completedRaces) ?? []
        onboardingCompleted = try container.decodeIfPresent(Bool.self, forKey: .onboardingCompleted) ?? false
        bio = try container.decodeIfPresent(String.self, forKey: .bio)
        pinnedPostIds = try container.decodeIfPresent([String].self, forKey: .pinnedPostIds) ?? []
        gymPbs = try container.decodeIfPresent([GymPB].self, forKey: .gymPbs) ?? []
        homeGym = try container.decodeIfPresent(String.self, forKey: .homeGym)
        trainingGoal = try container.decodeIfPresent(String.self, forKey: .trainingGoal)
        trainingIdentity = try container.decodeIfPresent(String.self, forKey: .trainingIdentity)
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
        try container.encodeIfPresent(bannerUrl, forKey: .bannerUrl)
        try container.encodeIfPresent(pb5kmMinutes, forKey: .pb5kmMinutes)
        try container.encodeIfPresent(pb10kmHours, forKey: .pb10kmHours)
        try container.encodeIfPresent(pb10kmMinutes, forKey: .pb10kmMinutes)
        try container.encodeIfPresent(pbMarathonHours, forKey: .pbMarathonHours)
        try container.encodeIfPresent(pbMarathonMinutes, forKey: .pbMarathonMinutes)
        try container.encode(climbedMountains, forKey: .climbedMountains)
        try container.encode(completedRaces, forKey: .completedRaces)
        try container.encode(onboardingCompleted, forKey: .onboardingCompleted)
        try container.encodeIfPresent(bio, forKey: .bio)
        try container.encode(pinnedPostIds, forKey: .pinnedPostIds)
        try container.encode(gymPbs, forKey: .gymPbs)
        try container.encodeIfPresent(homeGym, forKey: .homeGym)
        try container.encodeIfPresent(trainingGoal, forKey: .trainingGoal)
        try container.encodeIfPresent(trainingIdentity, forKey: .trainingIdentity)
    }
    
    init(id: String, name: String, email: String, currentXP: Int = 0, currentLevel: Int = 0, isProMember: Bool = false, avatarUrl: String? = nil, bannerUrl: String? = nil, pb5kmMinutes: Int? = nil, pb10kmHours: Int? = nil, pb10kmMinutes: Int? = nil, pbMarathonHours: Int? = nil, pbMarathonMinutes: Int? = nil, climbedMountains: [String] = [], completedRaces: [String] = [], onboardingCompleted: Bool = false, bio: String? = nil, pinnedPostIds: [String] = [], gymPbs: [GymPB] = [], homeGym: String? = nil, trainingGoal: String? = nil, trainingIdentity: String? = nil) {
        self.id = id
        self.name = name
        self.email = email
        self.currentXP = currentXP
        self.currentLevel = currentLevel
        self.isProMember = isProMember
        self.avatarUrl = avatarUrl
        self.bannerUrl = bannerUrl
        self.pb5kmMinutes = pb5kmMinutes
        self.pb10kmHours = pb10kmHours
        self.pb10kmMinutes = pb10kmMinutes
        self.pbMarathonHours = pbMarathonHours
        self.pbMarathonMinutes = pbMarathonMinutes
        self.climbedMountains = climbedMountains
        self.completedRaces = completedRaces
        self.onboardingCompleted = onboardingCompleted
        self.bio = bio
        self.pinnedPostIds = pinnedPostIds
        self.gymPbs = gymPbs
        self.homeGym = homeGym
        self.trainingGoal = trainingGoal
        self.trainingIdentity = trainingIdentity
    }
}

struct GymPB: Codable, Identifiable {
    var id: String { name }
    var name: String
    var kg: Double
    var reps: Int
}

struct Mountain: Identifiable {
    let id: String
    let name: String
    let imageName: String
}

extension Mountain {
    static let all: [Mountain] = [
        Mountain(id: "kebnekaise", name: "Kebnekaise", imageName: "25")
    ]
}

struct Race: Identifiable {
    let id: String
    let name: String
    let imageName: String
}

extension Race {
    static let all: [Race] = [
        Race(id: "ironman", name: "Iron Man", imageName: "26")
    ]
}
