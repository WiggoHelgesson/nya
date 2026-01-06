import Foundation
import ActivityKit

struct WorkoutActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var currentExercise: String?
        var currentSet: Int?
        var totalSets: Int?
        var completedSets: Int? // Antal set markerade som klara
        var currentReps: Int?
        var currentWeight: Double?
        var previousWeight: String? // Info om förra gången (t.ex. "80 kg x 2")
        var isAllSetsDone: Bool = false
        
        var distance: Double? 
        var pace: String?     
        var totalVolume: Double? 
        var elapsedSeconds: Int
    }

    // Fast data som inte ändras (t.ex. typ av pass)
    var workoutType: String // "Gympass" eller "Löppass"
}

