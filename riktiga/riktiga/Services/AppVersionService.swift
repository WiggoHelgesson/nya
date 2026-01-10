import Foundation
import SwiftUI
import Supabase
import Combine

// MARK: - App Config Model
struct AppConfig: Codable {
    let id: String? // UUID as string
    let minVersion: String?
    let recommendedVersion: String?
    let updateMessageSv: String?
    let updateMessageEn: String?
    let forceUpdate: Bool?
    let appStoreUrl: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case minVersion = "min_version"
        case recommendedVersion = "recommended_version"
        case updateMessageSv = "update_message_sv"
        case updateMessageEn = "update_message_en"
        case forceUpdate = "force_update"
        case appStoreUrl = "app_store_url"
    }
}

// MARK: - Version Check Result
enum VersionCheckResult {
    case upToDate
    case updateAvailable(message: String, appStoreUrl: String)
    case forceUpdateRequired(message: String, appStoreUrl: String)
    case error(String)
}

// MARK: - App Version Service
class AppVersionService: ObservableObject {
    static let shared = AppVersionService()
    
    @Published var checkResult: VersionCheckResult = .upToDate
    @Published var isChecking = false
    
    private let supabase = SupabaseConfig.supabase
    
    private init() {}
    
    /// Get current app version from bundle
    var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }
    
    /// Check if app needs update
    @MainActor
    func checkVersion() async {
        isChecking = true
        
        do {
            // Fetch the first (and only) config row
            let configs: [AppConfig] = try await supabase
                .from("app_config")
                .select()
                .limit(1)
                .execute()
                .value
            
            guard let config = configs.first else {
                print("⚠️ No app_config found, allowing app")
                checkResult = .upToDate
                isChecking = false
                return
            }
            
            let minVersion = config.minVersion ?? "1.0"
            let forceUpdate = config.forceUpdate ?? false
            
            let result = compareVersions(
                current: currentVersion,
                minimum: minVersion,
                forceUpdate: forceUpdate,
                message: config.updateMessageSv ?? "En uppdatering krävs.",
                appStoreUrl: config.appStoreUrl ?? "https://apps.apple.com/se/app/up-down/id6749190145?l=en-GB"
            )
            
            checkResult = result
            isChecking = false
            
            print("📱 Version check: current=\(currentVersion), min=\(minVersion), force=\(forceUpdate)")
            
        } catch {
            print("❌ Version check failed: \(error)")
            // Don't block app if check fails
            checkResult = .upToDate
            isChecking = false
        }
    }
    
    /// Compare version strings
    private func compareVersions(current: String, minimum: String, forceUpdate: Bool, message: String, appStoreUrl: String) -> VersionCheckResult {
        let currentComponents = current.split(separator: ".").compactMap { Int($0) }
        let minimumComponents = minimum.split(separator: ".").compactMap { Int($0) }
        
        // Pad arrays to same length
        let maxLength = max(currentComponents.count, minimumComponents.count)
        var currentPadded = currentComponents
        var minimumPadded = minimumComponents
        
        while currentPadded.count < maxLength { currentPadded.append(0) }
        while minimumPadded.count < maxLength { minimumPadded.append(0) }
        
        // Compare version components
        for i in 0..<maxLength {
            if currentPadded[i] < minimumPadded[i] {
                // Current version is older than minimum
                if forceUpdate {
                    return .forceUpdateRequired(message: message, appStoreUrl: appStoreUrl)
                } else {
                    return .updateAvailable(message: message, appStoreUrl: appStoreUrl)
                }
            } else if currentPadded[i] > minimumPadded[i] {
                // Current version is newer
                return .upToDate
            }
        }
        
        // Versions are equal
        return .upToDate
    }
    
    /// Open App Store
    func openAppStore(url: String) {
        guard let appStoreURL = URL(string: url) else { return }
        UIApplication.shared.open(appStoreURL)
    }
}

