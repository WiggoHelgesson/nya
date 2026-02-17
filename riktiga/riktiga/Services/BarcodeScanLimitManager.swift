import Foundation
import Combine

// MARK: - Barcode Scan Limit Manager (User-Specific)
// Non-Pro users get 1 FREE barcode health scan TOTAL
class BarcodeScanLimitManager: ObservableObject {
    static let shared = BarcodeScanLimitManager()
    
    private let freeScansTotal = 1
    private let baseKey = "barcode_scan_usage_total"
    
    @Published var scansUsedTotal: Int = 0
    
    private var currentUserId: String?
    
    private var userDefaultsKey: String {
        guard let userId = currentUserId else {
            return baseKey
        }
        return "\(baseKey)_\(userId)"
    }
    
    private init() {}
    
    // MARK: - Set current user (call this on login/signup)
    func setCurrentUser(userId: String?) {
        let previousUserId = currentUserId
        currentUserId = userId
        
        if previousUserId != userId {
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
    
    // MARK: - Use a scan
    func useScan() {
        scansUsedTotal += 1
        saveUsage()
        print("📊 Barcode Scan used: \(scansUsedTotal)/\(freeScansTotal) TOTAL for user: \(currentUserId ?? "unknown")")
    }
    
    // MARK: - Check if at the limit
    func isAtLimit() -> Bool {
        return scansUsedTotal >= freeScansTotal
    }
    
    // MARK: - Private methods
    private func loadUsage() {
        guard currentUserId != nil else {
            scansUsedTotal = 0
            return
        }
        
        if let totalScans = UserDefaults.standard.object(forKey: userDefaultsKey) as? Int {
            scansUsedTotal = totalScans
            print("📊 BarcodeScanLimit: Loaded \(scansUsedTotal)/\(freeScansTotal) TOTAL scans for user")
            return
        }
        
        scansUsedTotal = 0
        print("📊 BarcodeScanLimit: New user, starting with 0 scans used (\(freeScansTotal) free TOTAL)")
    }
    
    private func saveUsage() {
        guard currentUserId != nil else { return }
        UserDefaults.standard.set(scansUsedTotal, forKey: userDefaultsKey)
    }
}
