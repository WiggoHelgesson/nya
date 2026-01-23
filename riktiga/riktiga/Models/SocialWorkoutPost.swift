import Foundation

// Helper struct for JOIN results
struct SocialWorkoutPostRaw: Codable {
    let id: String
    let userId: String
    let activityType: String
    let title: String
    let description: String?
    let distance: Double?
    let duration: Int?
    let elevationGain: Double?
    let imageUrl: String?
    let userImageUrl: String?
    let createdAt: String
    let splits: [WorkoutSplit]?
    let exercises: [GymExercisePost]?
    let pbExerciseName: String?
    let pbValue: String?
    let streakCount: Int?
    let source: String?
    let deviceName: String?
    
    // JOIN data
    let profiles: ProfileData?
    let workoutPostLikes: [LikeCountData]?
    let workoutPostComments: [CommentCountData]?
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case activityType = "activity_type"
        case title
        case description
        case distance
        case duration
        case elevationGain = "elevation_gain"
        case imageUrl = "image_url"
        case userImageUrl = "user_image_url"
        case createdAt = "created_at"
        case splits = "split_data"
        case exercises = "exercises_data"
        case pbExerciseName = "pb_exercise_name"
        case pbValue = "pb_value"
        case streakCount = "streak_count"
        case source
        case deviceName = "device_name"
        case profiles
        case workoutPostLikes = "workout_post_likes"
        case workoutPostComments = "workout_post_comments"
    }
}

struct ProfileData: Codable {
    let username: String?
    let avatarUrl: String?
    let isProMember: Bool?
    
    enum CodingKeys: String, CodingKey {
        case username
        case avatarUrl = "avatar_url"
        case isProMember = "is_pro_member"
    }
}

struct LikeCountData: Codable {
    let count: Int
}

struct CommentCountData: Codable {
    let count: Int
}

struct SocialWorkoutPost: Codable, Identifiable {
    let id: String
    let userId: String
    let activityType: String
    let title: String
    let description: String?
    let distance: Double?
    let duration: Int?
    let elevationGain: Double?
    let imageUrl: String? // Route image
    let userImageUrl: String? // User's own image
    let createdAt: String
    
    // Social data
    let userName: String?
    let userAvatarUrl: String?
    let userIsPro: Bool?
    let location: String?
    let strokes: Int?
    let likeCount: Int?
    let commentCount: Int?
    let isLikedByCurrentUser: Bool?
    let splits: [WorkoutSplit]?
    let exercises: [GymExercisePost]?  // For gym sessions
    
    // Personal Best data
    let pbExerciseName: String?
    let pbValue: String?
    
    // Streak data for achievement banners
    let streakCount: Int?
    
    // External tracking data
    let source: String?
    let deviceName: String?
    
    // Computed property to check if it's an external post
    var isExternalPost: Bool {
        source != nil && source != "app"
    }
    
    // Computed property for swimming (show meters)
    var isSwimmingPost: Bool {
        activityType == "Simning"
    }
    
    // Computed property for cycling
    var isCyclingPost: Bool {
        activityType == "Cykling"
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case activityType = "activity_type"
        case title
        case description
        case distance
        case duration
        case elevationGain = "elevation_gain"
        case imageUrl = "image_url"
        case userImageUrl = "user_image_url"
        case createdAt = "created_at"
        case userName = "user_name"
        case userAvatarUrl = "user_avatar_url"
        case userIsPro = "user_is_pro"
        case location
        case strokes
        case likeCount = "like_count"
        case commentCount = "comment_count"
        case isLikedByCurrentUser = "is_liked_by_current_user"
        case splits = "split_data"
        case exercises = "exercises_data"
        case pbExerciseName = "pb_exercise_name"
        case pbValue = "pb_value"
        case streakCount = "streak_count"
        case source
        case deviceName = "device_name"
    }
    
    // Custom decoder to handle JOIN results
    init(from decoder: Decoder) throws {
        let raw = try SocialWorkoutPostRaw(from: decoder)
        
        // Map basic fields
        id = raw.id
        userId = raw.userId
        activityType = raw.activityType
        title = raw.title
        description = raw.description
        distance = raw.distance
        duration = raw.duration
        elevationGain = raw.elevationGain
        imageUrl = raw.imageUrl
        userImageUrl = raw.userImageUrl
        createdAt = raw.createdAt
        
        // Map social data from JOIN results
        userName = raw.profiles?.username
        userAvatarUrl = raw.profiles?.avatarUrl
        userIsPro = raw.profiles?.isProMember
        location = nil // Will be set if available
        strokes = nil // Will be set if available
        
        // Map like and comment counts
        likeCount = raw.workoutPostLikes?.first?.count ?? 0
        commentCount = raw.workoutPostComments?.first?.count ?? 0
        
        isLikedByCurrentUser = false // Will be set separately
        splits = raw.splits
        exercises = raw.exercises
        
        // Map PB data
        pbExerciseName = raw.pbExerciseName
        pbValue = raw.pbValue
        
        // Map streak data
        streakCount = raw.streakCount
        
        // Map external tracking data
        source = raw.source
        deviceName = raw.deviceName
    }
    
    init(from post: WorkoutPost, userName: String? = nil, userAvatarUrl: String? = nil, userIsPro: Bool? = nil, location: String? = nil, strokes: Int? = nil, likeCount: Int = 0, commentCount: Int = 0, isLikedByCurrentUser: Bool = false, source: String? = nil, deviceName: String? = nil, streakCount: Int? = nil) {
        self.id = post.id
        self.userId = post.userId
        self.activityType = post.activityType
        self.title = post.title
        self.description = post.description
        self.distance = post.distance
        self.duration = post.duration
        self.elevationGain = post.elevationGain
        self.imageUrl = post.imageUrl
        self.userImageUrl = post.userImageUrl
        self.createdAt = post.createdAt
        self.userName = userName
        self.userAvatarUrl = userAvatarUrl
        self.userIsPro = userIsPro
        self.location = location
        self.strokes = strokes
        self.likeCount = likeCount
        self.commentCount = commentCount
        self.isLikedByCurrentUser = isLikedByCurrentUser
        self.splits = post.splits
        self.exercises = post.exercises
        self.pbExerciseName = post.pbExerciseName
        self.pbValue = post.pbValue
        self.streakCount = streakCount ?? post.streakCount
        self.source = source ?? post.source
        self.deviceName = deviceName ?? post.deviceName
    }

    // Memberwise convenience initializer to allow updating selective fields
    init(
        id: String,
        userId: String,
        activityType: String,
        title: String,
        description: String?,
        distance: Double?,
        duration: Int?,
        elevationGain: Double? = nil,
        imageUrl: String?,
        userImageUrl: String?,
        createdAt: String,
        userName: String?,
        userAvatarUrl: String?,
        userIsPro: Bool?,
        location: String?,
        strokes: Int?,
        likeCount: Int?,
        commentCount: Int?,
        isLikedByCurrentUser: Bool?,
        splits: [WorkoutSplit]?,
        exercises: [GymExercisePost]? = nil,
        pbExerciseName: String? = nil,
        pbValue: String? = nil,
        streakCount: Int? = nil,
        source: String? = nil,
        deviceName: String? = nil
    ) {
        self.id = id
        self.userId = userId
        self.activityType = activityType
        self.title = title
        self.description = description
        self.distance = distance
        self.duration = duration
        self.elevationGain = elevationGain
        self.imageUrl = imageUrl
        self.userImageUrl = userImageUrl
        self.createdAt = createdAt
        self.userName = userName
        self.userAvatarUrl = userAvatarUrl
        self.userIsPro = userIsPro
        self.location = location
        self.strokes = strokes
        self.likeCount = likeCount
        self.commentCount = commentCount
        self.isLikedByCurrentUser = isLikedByCurrentUser
        self.splits = splits
        self.exercises = exercises
        self.pbExerciseName = pbExerciseName
        self.pbValue = pbValue
        self.streakCount = streakCount
        self.source = source
        self.deviceName = deviceName
    }
}

extension SocialWorkoutPost: Hashable {
    static func == (lhs: SocialWorkoutPost, rhs: SocialWorkoutPost) -> Bool {
        lhs.id == rhs.id
    }
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
