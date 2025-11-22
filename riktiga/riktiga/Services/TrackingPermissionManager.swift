import Foundation
import AppTrackingTransparency
import AdSupport

final class TrackingPermissionManager {
    static let shared = TrackingPermissionManager()
    private let defaultsKey = "hasRequestedATT"
    private init() {}
    
    func requestPermissionIfNeeded() async {
        guard #available(iOS 14, *) else { return }
        let status = ATTrackingManager.trackingAuthorizationStatus
        switch status {
        case .notDetermined:
            await withCheckedContinuation { continuation in
                ATTrackingManager.requestTrackingAuthorization { _ in
                    UserDefaults.standard.set(true, forKey: self.defaultsKey)
                    continuation.resume()
                }
            }
        default:
            if !UserDefaults.standard.bool(forKey: defaultsKey) {
                UserDefaults.standard.set(true, forKey: defaultsKey)
            }
        }
    }
}
