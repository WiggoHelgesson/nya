import Foundation
import Combine

// MARK: - AI Scan Limit Manager (User-Specific)
// Non-Pro users get 3 FREE AI scans TOTAL (not per week)
class AIScanLimitManager: ObservableObject {
    static let shared = AIScanLimitManager()
    
    private let freeScansTotal = 3
    private let baseKey = "ai_scan_usage_total"
    
    @Published var scansUsedTotal: Int = 0
    
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
        return scansUsedTotal < freeScansTotal
    }
    
    var remainingFreeScans: Int {
        return max(0, freeScansTotal - scansUsedTotal)
    }
    
    // For backwards compatibility with existing code
    var scansUsedThisWeek: Int {
        return scansUsedTotal
    }
    
    // MARK: - Use a scan
    func useScan() {
        scansUsedTotal += 1
        saveUsage()
        print("📸 AI Scan used: \(scansUsedTotal)/\(freeScansTotal) TOTAL for user: \(currentUserId ?? "unknown")")
    }
    
    // MARK: - Check if should show limit (4th scan)
    func shouldShowLimitOnNextScan() -> Bool {
        return scansUsedTotal >= freeScansTotal
    }
    
    // MARK: - Check if at the limit (for graying out button)
    func isAtLimit() -> Bool {
        return scansUsedTotal >= freeScansTotal
    }
    
    // MARK: - Private methods
    private func loadUsage() {
        guard currentUserId != nil else {
            // No user logged in, start fresh
            scansUsedTotal = 0
            print("📸 AIScanLimit: No user, starting with 0 scans used")
            return
        }
        
        // Try to load total usage (new format)
        if let totalScans = UserDefaults.standard.object(forKey: userDefaultsKey) as? Int {
            scansUsedTotal = totalScans
            print("📸 AIScanLimit: Loaded \(scansUsedTotal)/\(freeScansTotal) TOTAL scans for user")
            return
        }
        
        // Try to migrate from old weekly format
        let oldKey = "ai_scan_usage_\(currentUserId ?? "")"
        if let data = UserDefaults.standard.data(forKey: oldKey),
           let oldUsage = try? JSONDecoder().decode(OldScanUsage.self, from: data) {
            // Migrate: keep the scans they've already used
            scansUsedTotal = oldUsage.scansUsed
            saveUsage()
            // Remove old key
            UserDefaults.standard.removeObject(forKey: oldKey)
            print("📸 AIScanLimit: Migrated from weekly to total. Used: \(scansUsedTotal)/\(freeScansTotal)")
            return
        }
        
        // New user, start with 0 scans used (3 free)
        scansUsedTotal = 0
        print("📸 AIScanLimit: New user, starting with 0 scans used (\(freeScansTotal) free TOTAL)")
    }
    
    private func saveUsage() {
        guard currentUserId != nil else { return }
        UserDefaults.standard.set(scansUsedTotal, forKey: userDefaultsKey)
    }
}

// MARK: - Old Scan Usage Model (for migration)
private struct OldScanUsage: Codable {
    let weekStartDate: Date
    let scansUsed: Int
}
