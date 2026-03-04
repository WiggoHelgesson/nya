import Foundation
import ActivityKit

class LiveActivityManager {
    static let shared = LiveActivityManager()
    
    private var currentActivity: ActivityKit.Activity<WorkoutActivityAttributes>?
    
    private init() {}
    
    // MARK: - Start Activity
    func startLiveActivity(workoutType: String, initialContent: WorkoutActivityAttributes.ContentState) {
        // 1. Kontrollera behörighet
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { 
            print("⚠️ Live Activities är avstängt i systeminställningarna")
            return 
        }
        
        // 2. Avsluta ALLA gamla aktiviteter först för att undvika krockar och felaktiga typer
        endLiveActivity()
        
        // Ge systemet en liten chans att stänga ner innan vi startar ny (valfritt men säkrare)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            let attributes = WorkoutActivityAttributes(workoutType: workoutType)
            let content = ActivityContent(state: initialContent, staleDate: nil)
            
            do {
                self.currentActivity = try ActivityKit.Activity.request(attributes: attributes, content: content)
                print("✅ Live Activity startad med ID: \(self.currentActivity?.id ?? "okänd") för \(workoutType)")
            } catch {
                print("❌ MISSFAIL: Kunde inte starta Live Activity. Fel: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Update Activity
    func updateLiveActivity(with newState: WorkoutActivityAttributes.ContentState) {
        Task {
            // Uppdatera alla aktiva (för att vara säker)
            for activity in ActivityKit.Activity<WorkoutActivityAttributes>.activities {
                let content = ActivityContent(state: newState, staleDate: nil)
                await activity.update(content)
                print("🔄 Live Activity \(activity.id) uppdaterad")
            }
        }
    }
    
    // MARK: - End Activity
    func endLiveActivity() {
        print("🛑 Attempting to end all Live Activities...")
        
        let activities = ActivityKit.Activity<WorkoutActivityAttributes>.activities
        print("🛑 Found \(activities.count) active Live Activities to end")
        
        for activity in activities {
            Task {
                await activity.end(nil, dismissalPolicy: .immediate)
                print("🛑 Live Activity \(activity.id) avslutad")
            }
        }
        currentActivity = nil
    }
    
    /// End any orphaned Live Activities that persist without an active session.
    /// Call on app launch.
    func cleanupOrphanedActivities() {
        guard !SessionManager.shared.hasActiveSession else { return }
        let activities = ActivityKit.Activity<WorkoutActivityAttributes>.activities
        guard !activities.isEmpty else { return }
        print("🧹 Found \(activities.count) orphaned Live Activities - cleaning up")
        for activity in activities {
            Task {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
        }
        currentActivity = nil
    }
}
