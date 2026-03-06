import Foundation
import Combine

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

class PinnedRoutineStore: ObservableObject {
    static let shared = PinnedRoutineStore()
    private let key = "pinned_routines"
    
    @Published var pinnedIds: Set<String>
    
    private init() {
        pinnedIds = Set(UserDefaults.standard.stringArray(forKey: key) ?? [])
    }
    
    func toggle(_ id: String) {
        if pinnedIds.contains(id) { pinnedIds.remove(id) } else { pinnedIds.insert(id) }
        UserDefaults.standard.set(Array(pinnedIds), forKey: key)
    }
    
    func isPinned(_ id: String) -> Bool { pinnedIds.contains(id) }
}

