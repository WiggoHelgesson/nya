import Foundation

struct WorkoutSplit: Codable, Identifiable, Hashable {
    let id: String
    let kilometerIndex: Int
    let distanceKm: Double
    let durationSeconds: Double
    let paceSecondsPerKm: Double
    
    init(id: String = UUID().uuidString,
         kilometerIndex: Int,
         distanceKm: Double,
         durationSeconds: Double) {
        self.id = id
        self.kilometerIndex = kilometerIndex
        self.distanceKm = distanceKm
        self.durationSeconds = durationSeconds
        let safeDistance = max(distanceKm, 0.0001)
        self.paceSecondsPerKm = durationSeconds / safeDistance
    }
}



