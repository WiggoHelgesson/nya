import Foundation

class QuickTrackXPTracker {
    static let shared = QuickTrackXPTracker()
    
    private let dailyKey = "QuickTrackDailyXP"
    private let dateKey = "QuickTrackDailyXPDate"
    
    private init() {}
    
    func hasAwardedToday() -> Bool {
        let storedDate = UserDefaults.standard.string(forKey: dateKey) ?? ""
        return storedDate == todayString()
    }
    
    func markAwarded() {
        UserDefaults.standard.set(true, forKey: dailyKey)
        UserDefaults.standard.set(todayString(), forKey: dateKey)
    }
    
    func pointsToAward() -> Int {
        return hasAwardedToday() ? 0 : 20
    }
    
    private func todayString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }
}
