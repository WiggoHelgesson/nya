import Foundation

struct WorkoutPost: Codable, Identifiable {
    let id: String
    let userId: String
    let activityType: String
    let title: String
    let description: String?
    let distance: Double?
    let duration: Int?
    let imageUrl: String? // Route image
    let userImageUrl: String? // User's own image
    let elevationGain: Double?
    let maxSpeed: Double?
    let createdAt: String
    let splits: [WorkoutSplit]?
    let exercises: [GymExercisePost]?  // For gym sessions
    let routeData: String?  // JSON string of route coordinates for Zone War
    let pbExerciseName: String?  // Personal Best exercise name
    let pbValue: String?  // Personal Best value (e.g., "67.0 kg x 6 reps")
    let streakCount: Int?  // User's streak when post was created
    let source: String?  // "app", "garmin", "fitbit", etc.
    let deviceName: String?  // "Garmin Forerunner 265", etc.
    let location: String?  // Gym name or location (e.g., "Nordic Wellness Lund")
    let trainedWith: [TrainedWithPerson]?  // Friends who trained together
    let isPublic: Bool
    let moderationStatus: String?  // 'approved' or 'pending_review'
    
    struct TrainedWithPerson: Codable, Identifiable, Hashable {
        let id: String
        let username: String
        let avatarUrl: String?
        
        enum CodingKeys: String, CodingKey {
            case id
            case username
            case avatarUrl = "avatarUrl"
        }
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case activityType = "activity_type"
        case title
        case description
        case distance
        case duration
        case imageUrl = "image_url"
        case userImageUrl = "user_image_url"
        case elevationGain = "elevation_gain"
        case maxSpeed = "max_speed"
        case createdAt = "created_at"
        case splits = "split_data"
        case exercises = "exercises_data"
        case routeData = "route_data"
        case pbExerciseName = "pb_exercise_name"
        case pbValue = "pb_value"
        case streakCount = "streak_count"
        case source
        case deviceName = "device_name"
        case location
        case trainedWith = "trained_with"
        case isPublic = "is_public"
        case moderationStatus = "moderation_status"
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        userId = try container.decode(String.self, forKey: .userId)
        activityType = try container.decode(String.self, forKey: .activityType)
        title = try container.decode(String.self, forKey: .title)
        description = try container.decodeIfPresent(String.self, forKey: .description)
        distance = try container.decodeIfPresent(Double.self, forKey: .distance)
        duration = try container.decodeIfPresent(Int.self, forKey: .duration)
        imageUrl = try container.decodeIfPresent(String.self, forKey: .imageUrl)
        userImageUrl = try container.decodeIfPresent(String.self, forKey: .userImageUrl)
        elevationGain = try container.decodeIfPresent(Double.self, forKey: .elevationGain)
        maxSpeed = try container.decodeIfPresent(Double.self, forKey: .maxSpeed)
        createdAt = try container.decode(String.self, forKey: .createdAt)
        splits = try container.decodeIfPresent([WorkoutSplit].self, forKey: .splits)
        exercises = try container.decodeIfPresent([GymExercisePost].self, forKey: .exercises)
        routeData = try container.decodeIfPresent(String.self, forKey: .routeData)
        pbExerciseName = try container.decodeIfPresent(String.self, forKey: .pbExerciseName)
        pbValue = try container.decodeIfPresent(String.self, forKey: .pbValue)
        streakCount = try container.decodeIfPresent(Int.self, forKey: .streakCount)
        source = try container.decodeIfPresent(String.self, forKey: .source)
        deviceName = try container.decodeIfPresent(String.self, forKey: .deviceName)
        location = try container.decodeIfPresent(String.self, forKey: .location)
        trainedWith = try container.decodeIfPresent([TrainedWithPerson].self, forKey: .trainedWith)
        isPublic = try container.decodeIfPresent(Bool.self, forKey: .isPublic) ?? true
        moderationStatus = try container.decodeIfPresent(String.self, forKey: .moderationStatus)
    }
    
    init(id: String = UUID().uuidString,
         userId: String,
         activityType: String,
         title: String,
         description: String? = nil,
         distance: Double? = nil,
         duration: Int? = nil,
         imageUrl: String? = nil,
         userImageUrl: String? = nil,
         elevationGain: Double? = nil,
         maxSpeed: Double? = nil,
         splits: [WorkoutSplit]? = nil,
         exercises: [GymExercisePost]? = nil,
         routeData: String? = nil,
         pbExerciseName: String? = nil,
         pbValue: String? = nil,
         streakCount: Int? = nil,
         source: String? = "app",
         deviceName: String? = nil,
         location: String? = nil,
         trainedWith: [TrainedWithPerson]? = nil,
         isPublic: Bool = true,
         moderationStatus: String? = nil) {
        self.id = id
        self.userId = userId
        self.activityType = activityType
        self.title = title
        self.description = description
        self.distance = distance
        self.duration = duration
        self.imageUrl = imageUrl
        self.userImageUrl = userImageUrl
        self.elevationGain = elevationGain
        self.maxSpeed = maxSpeed
        self.createdAt = ISO8601DateFormatter().string(from: Date())
        self.splits = splits
        self.exercises = exercises
        self.routeData = routeData
        self.pbExerciseName = pbExerciseName
        self.pbValue = pbValue
        self.streakCount = streakCount
        self.source = source
        self.deviceName = deviceName
        self.location = location
        self.trainedWith = trainedWith
        self.isPublic = isPublic
        self.moderationStatus = moderationStatus
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(userId, forKey: .userId)
        try container.encode(activityType, forKey: .activityType)
        try container.encode(title, forKey: .title)
        try container.encodeIfPresent(description, forKey: .description)
        try container.encodeIfPresent(distance, forKey: .distance)
        try container.encodeIfPresent(duration, forKey: .duration)
        try container.encodeIfPresent(imageUrl, forKey: .imageUrl)
        try container.encodeIfPresent(userImageUrl, forKey: .userImageUrl)
        try container.encodeIfPresent(elevationGain, forKey: .elevationGain)
        try container.encodeIfPresent(maxSpeed, forKey: .maxSpeed)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encodeIfPresent(splits, forKey: .splits)
        try container.encodeIfPresent(exercises, forKey: .exercises)
        try container.encodeIfPresent(routeData, forKey: .routeData)
        try container.encodeIfPresent(pbExerciseName, forKey: .pbExerciseName)
        try container.encodeIfPresent(pbValue, forKey: .pbValue)
        try container.encodeIfPresent(streakCount, forKey: .streakCount)
        try container.encodeIfPresent(source, forKey: .source)
        try container.encodeIfPresent(deviceName, forKey: .deviceName)
        try container.encodeIfPresent(location, forKey: .location)
        try container.encodeIfPresent(trainedWith, forKey: .trainedWith)
        try container.encode(isPublic, forKey: .isPublic)
        try container.encodeIfPresent(moderationStatus, forKey: .moderationStatus)
    }
}

// MARK: - Gym Exercise Post Model
struct GymExercisePost: Codable {
    let id: String?
    let name: String
    let category: String?
    let sets: Int
    let reps: [Int]
    let kg: [Double]
    let notes: String?
    var isCardio: Bool?
    var cardioSeconds: Int?
    
    enum CodingKeys: String, CodingKey {
        case id, name, category, sets, reps, kg, notes
        case isCardio = "is_cardio"
        case cardioSeconds = "cardio_seconds"
    }
    
    init(id: String?, name: String, category: String?, sets: Int, reps: [Int], kg: [Double], notes: String?, isCardio: Bool? = nil, cardioSeconds: Int? = nil) {
        self.id = id
        self.name = name
        self.category = category
        self.sets = sets
        self.reps = reps
        self.kg = kg
        self.notes = notes
        self.isCardio = isCardio
        self.cardioSeconds = cardioSeconds
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        category = try container.decodeIfPresent(String.self, forKey: .category)
        sets = try container.decodeIfPresent(Int.self, forKey: .sets) ?? 0
        reps = try container.decodeIfPresent([Int].self, forKey: .reps) ?? []
        kg = try container.decodeIfPresent([Double].self, forKey: .kg) ?? []
        notes = try container.decodeIfPresent(String.self, forKey: .notes)
        cardioSeconds = try container.decodeIfPresent(Int.self, forKey: .cardioSeconds)
        
        if let boolVal = try? container.decodeIfPresent(Bool.self, forKey: .isCardio) {
            isCardio = boolVal
        } else if let intVal = try? container.decodeIfPresent(Int.self, forKey: .isCardio) {
            isCardio = intVal != 0
        } else {
            isCardio = nil
        }
    }
}
