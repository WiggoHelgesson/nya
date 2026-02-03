import Foundation

// MARK: - Shared Workout Model
struct SharedWorkout: Identifiable, Codable {
    let id: String
    let senderId: String
    let receiverId: String
    let workoutName: String
    let exercises: [GymExercisePost]
    let message: String?
    let createdAt: Date
    let isRead: Bool
    
    // Sender profile info (populated when fetching)
    var senderUsername: String?
    var senderAvatarUrl: String?
    
    init(
        id: String,
        senderId: String,
        receiverId: String,
        workoutName: String,
        exercises: [GymExercisePost],
        message: String? = nil,
        createdAt: Date,
        isRead: Bool = false,
        senderUsername: String? = nil,
        senderAvatarUrl: String? = nil
    ) {
        self.id = id
        self.senderId = senderId
        self.receiverId = receiverId
        self.workoutName = workoutName
        self.exercises = exercises
        self.message = message
        self.createdAt = createdAt
        self.isRead = isRead
        self.senderUsername = senderUsername
        self.senderAvatarUrl = senderAvatarUrl
    }
}

// MARK: - Friend for sharing
struct FriendForSharing: Identifiable {
    let id: String
    let username: String
    let avatarUrl: String?
}
