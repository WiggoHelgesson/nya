import Foundation

struct SavedGymWorkout: Identifiable, Codable {
    let id: String
    let userId: String
    let name: String
    let exercises: [GymExercisePost]
    let createdAt: Date
    
    init(id: String, userId: String, name: String, exercises: [GymExercisePost], createdAt: Date) {
        self.id = id
        self.userId = userId
        self.name = name
        self.exercises = exercises
        self.createdAt = createdAt
    }
}

