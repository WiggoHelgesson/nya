import AppIntents
import ActivityKit

struct CompleteSetIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Klart set"
    static var description = LocalizedStringResource("Markerar nuvarande set som klart och går till nästa.")

    func perform() async throws -> some IntentResult {
        // Här skickar vi en notis till appen att markera setet som klart
        NotificationCenter.default.post(name: NSNotification.Name("LiveActivityCompleteSet"), object: nil)
        return .result()
    }
}











