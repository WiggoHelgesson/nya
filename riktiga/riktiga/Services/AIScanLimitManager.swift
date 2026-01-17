import Foundation
import Combine

// MARK: - AI Scan Limit Manager (User-Specific)
class AIScanLimitManager: ObservableObject {
    static let shared = AIScanLimitManager()
    
    private let freeScansPerWeek = 3
    private let baseKey = "ai_scan_usage"
    
    @Published var scansUsedThisWeek: Int = 0
    @Published var weekStartDate: Date = Date()
    
    private var currentUserId: String?
    
    private var userDefaultsKey: String {
        guard let userId = currentUserId else {
            return baseKey
        }
        return "\(baseKey)_\(userId)"
    }
    
    private init() {
        // Don't load here - wait for setCurrentUser to be called
    }
    
    // MARK: - Set current user (call this on login/signup)
    func setCurrentUser(userId: String?) {
        let previousUserId = currentUserId
        currentUserId = userId
        
        // Only reload if user changed
        if previousUserId != userId {
            print("👤 AIScanLimitManager: User changed to \(userId ?? "nil")")
            loadUsage()
        }
    }
    
    // MARK: - Check if user can scan for free
    var canScanForFree: Bool {
        return scansUsedThisWeek < freeScansPerWeek
    }
    
    var remainingFreeScans: Int {
        return max(0, freeScansPerWeek - scansUsedThisWeek)
    }
    
    // MARK: - Use a scan
    func useScan() {
        checkAndResetWeekIfNeeded()
        scansUsedThisWeek += 1
        saveUsage()
        print("📸 AI Scan used: \(scansUsedThisWeek)/\(freeScansPerWeek) for user: \(currentUserId ?? "unknown")")
    }
    
    // MARK: - Check if should show limit (4th scan)
    func shouldShowLimitOnNextScan() -> Bool {
        checkAndResetWeekIfNeeded()
        return scansUsedThisWeek >= freeScansPerWeek
    }
    
    // MARK: - Check if at the limit (for graying out button)
    func isAtLimit() -> Bool {
        checkAndResetWeekIfNeeded()
        return scansUsedThisWeek >= freeScansPerWeek
    }
    
    // MARK: - Private methods
    private func loadUsage() {
        guard currentUserId != nil else {
            // No user logged in, start fresh
            scansUsedThisWeek = 0
            weekStartDate = Date()
            print("📸 AIScanLimit: No user, starting with 0 scans used")
            return
        }
        
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey),
              let usage = try? JSONDecoder().decode(ScanUsage.self, from: data) else {
            // No saved data for this user, start fresh with 0 scans used
            print("📸 AIScanLimit: New user, starting with 0 scans used (3 free)")
            resetWeek()
            return
        }
        
        self.weekStartDate = usage.weekStartDate
        self.scansUsedThisWeek = usage.scansUsed
        
        print("📸 AIScanLimit: Loaded \(scansUsedThisWeek)/\(freeScansPerWeek) scans for user")
        
        // Check if we need to reset for a new week
        checkAndResetWeekIfNeeded()
    }
    
    private func saveUsage() {
        guard currentUserId != nil else { return }
        
        let usage = ScanUsage(weekStartDate: weekStartDate, scansUsed: scansUsedThisWeek)
        if let data = try? JSONEncoder().encode(usage) {
            UserDefaults.standard.set(data, forKey: userDefaultsKey)
        }
    }
    
    private func checkAndResetWeekIfNeeded() {
        let calendar = Calendar.current
        let now = Date()
        
        // Check if current week start is different from saved week start
        guard let currentWeekStart = calendar.dateInterval(of: .weekOfYear, for: now)?.start,
              let savedWeekStart = calendar.dateInterval(of: .weekOfYear, for: weekStartDate)?.start else {
            return
        }
        
        // If we're in a new week, reset the counter
        if currentWeekStart > savedWeekStart {
            print("📅 New week detected - resetting AI scan count for user: \(currentUserId ?? "unknown")")
            resetWeek()
        }
    }
    
    private func resetWeek() {
        let calendar = Calendar.current
        weekStartDate = calendar.dateInterval(of: .weekOfYear, for: Date())?.start ?? Date()
        scansUsedThisWeek = 0
        saveUsage()
    }
}

// MARK: - Scan Usage Model
private struct ScanUsage: Codable {
    let weekStartDate: Date
    let scansUsed: Int
}

