import Foundation
import SwiftUI
import Combine
import Supabase
import TerraiOS

// MARK: - Terra Device Provider
enum TerraProvider: String, CaseIterable, Identifiable {
    case apple = "APPLE"
    case garmin = "GARMIN"
    case fitbit = "FITBIT"
    case zwift = "ZWIFT"
    case oura = "OURA"
    case peloton = "PELOTON"
    case polar = "POLAR"
    case wahoo = "WAHOO"
    case suunto = "SUUNTO"
    case amazfit = "AMAZFIT"
    case coros = "COROS"
    case samsung = "SAMSUNG"
    case nike = "NIKE"
    case huawei = "HUAWEI"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .apple: return "Apple Watch"
        case .garmin: return "Garmin"
        case .fitbit: return "Fitbit"
        case .zwift: return "Zwift"
        case .oura: return "Oura"
        case .peloton: return "Peloton"
        case .polar: return "Polar"
        case .wahoo: return "Wahoo"
        case .suunto: return "Suunto"
        case .amazfit: return "Amazfit"
        case .coros: return "Coros"
        case .samsung: return "Samsung"
        case .nike: return "Nike"
        case .huawei: return "Huawei"
        }
    }
    
    var iconName: String {
        switch self {
        case .apple: return "applewatch"
        case .garmin: return "garmin"
        case .fitbit: return "fitbit"
        case .zwift: return "zwift"
        case .oura: return "oura"
        case .peloton: return "peloton"
        case .polar: return "polar"
        case .wahoo: return "wahoo"
        case .suunto: return "suunto"
        case .amazfit: return "amazfit"
        case .coros: return "coros"
        case .samsung: return "samsung"
        case .nike: return "nike"
        case .huawei: return "huawei"
        }
    }
    
    // Use SF Symbols as fallback
    var sfSymbol: String {
        switch self {
        case .apple: return "applewatch"
        case .garmin: return "figure.run"
        case .fitbit: return "heart.fill"
        case .zwift: return "bicycle"
        case .oura: return "circle.circle"
        case .peloton: return "figure.indoor.cycle"
        case .polar: return "waveform.path.ecg"
        case .wahoo: return "bicycle"
        case .suunto: return "location.north.fill"
        case .amazfit: return "applewatch"
        case .coros: return "figure.run"
        case .samsung: return "applewatch"
        case .nike: return "figure.run"
        case .huawei: return "applewatch"
        }
    }
    
    // Check if this provider requires the SDK (not web widget)
    var requiresSDK: Bool {
        self == .apple
    }
}

// MARK: - Terra Connection Model
struct TerraConnection: Codable, Identifiable {
    let id: String
    let userId: String
    let terraUserId: String
    let provider: String
    let connectedAt: Date
    let isActive: Bool
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case terraUserId = "terra_user_id"
        case provider
        case connectedAt = "connected_at"
        case isActive = "is_active"
    }
}

// MARK: - Terra Widget Response
struct TerraWidgetResponse: Codable {
    let sessionId: String
    let url: String
    
    enum CodingKeys: String, CodingKey {
        case sessionId = "session_id"
        case url
    }
}

// MARK: - Terra Auth Token Response
struct TerraAuthTokenResponse: Codable {
    let token: String
    let status: String
}

// MARK: - Terra Service
class TerraService: ObservableObject {
    static let shared = TerraService()
    
    private let apiKey = "a7yuczMGO6C_BRXrrB0FpGQ8lTtHmU39"
    private let devId = "updown-prod-B7LDZTFeIy"
    private let baseURL = "https://api.tryterra.co/v2"
    
    @Published var connectedProviders: [TerraConnection] = []
    @Published var isLoading = false
    @Published var error: String?
    @Published var isAppleHealthConnected = false
    @Published var appleHealthUserId: String?
    
    // Terra SDK manager for Apple Health
    private var terraManager: TerraManager?
    
    private init() {}
    
    // MARK: - Initialize Terra SDK (call on app start)
    func initializeSDK(userId: String, completion: @escaping (Bool) -> Void) {
        print("🔄 Initializing Terra SDK for user: \(userId)")
        
        Terra.instance(devId: devId, referenceId: userId) { [weak self] manager, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("❌ Terra SDK init error: \(error)")
                    completion(false)
                    return
                }
                
                guard let manager = manager else {
                    print("❌ Terra SDK: No manager returned")
                    completion(false)
                    return
                }
                
                self?.terraManager = manager
                print("✅ Terra SDK initialized successfully")
                
                // Check if Apple Health is already connected from UserDefaults
                if UserDefaults.standard.bool(forKey: "terra_apple_health_connected") {
                    self?.isAppleHealthConnected = true
                    self?.appleHealthUserId = UserDefaults.standard.string(forKey: "terra_apple_health_user_id")
                    print("✅ Apple Health already connected (from cache)")
                }
                
                completion(true)
            }
        }
    }
    
    // MARK: - Connect Apple Health (SDK-based)
    func connectAppleHealth(userId: String, completion: @escaping (Bool, String?) -> Void) {
        print("🔄 Connecting Apple Health...")
        
        // First, generate auth token
        Task {
            do {
                let token = try await generateAuthToken()
                
                // Ensure SDK is initialized
                if terraManager == nil {
                    initializeSDK(userId: userId) { [weak self] success in
                        if success {
                            self?.performAppleHealthConnection(token: token, completion: completion)
                        } else {
                            completion(false, "Kunde inte initialisera Terra SDK")
                        }
                    }
                } else {
                    performAppleHealthConnection(token: token, completion: completion)
                }
            } catch {
                DispatchQueue.main.async {
                    completion(false, error.localizedDescription)
                }
            }
        }
    }
    
    private func performAppleHealthConnection(token: String, completion: @escaping (Bool, String?) -> Void) {
        guard let manager = terraManager else {
            completion(false, "Terra SDK inte initialiserad")
            return
        }
        
        manager.initConnection(
            type: .APPLE_HEALTH,
            token: token,
            customReadTypes: Set(), // Empty = request all permissions
            schedulerOn: true // Enable background delivery
        ) { [weak self] success, error in
            DispatchQueue.main.async {
                if success {
                    self?.isAppleHealthConnected = true
                    // Save connection state
                    UserDefaults.standard.set(true, forKey: "terra_apple_health_connected")
                    print("✅ Apple Health connected!")
                    completion(true, nil)
                } else {
                    let errorMsg = error?.localizedDescription ?? "Okänt fel"
                    print("❌ Apple Health connection failed: \(errorMsg)")
                    completion(false, errorMsg)
                }
            }
        }
    }
    
    // MARK: - Generate Auth Token (for SDK)
    private func generateAuthToken() async throws -> String {
        let endpoint = "\(baseURL)/auth/generateAuthToken"
        
        guard let url = URL(string: endpoint) else {
            throw TerraError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue(devId, forHTTPHeaderField: "dev-id")
        request.addValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw TerraError.apiError(statusCode: (response as? HTTPURLResponse)?.statusCode ?? 0, message: errorBody)
        }
        
        // Parse token from response
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let token = json["token"] as? String {
            print("✅ Auth token generated")
            return token
        }
        
        throw TerraError.invalidResponse
    }
    
    // MARK: - Generate Widget Session (for web-based providers)
    func generateWidgetSession(for provider: TerraProvider, userId: String) async throws -> URL {
        // Apple Health uses SDK, not widget
        if provider.requiresSDK {
            throw TerraError.apiError(statusCode: 0, message: "Apple Health kräver SDK-anslutning, inte widget")
        }
        
        let endpoint = "\(baseURL)/auth/generateWidgetSession"
        
        guard let url = URL(string: endpoint) else {
            throw TerraError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue(devId, forHTTPHeaderField: "dev-id")
        request.addValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "reference_id": userId,
            "providers": provider.rawValue,
            "language": "sv",
            "auth_success_redirect_url": "updown://terra-callback?success=true",
            "auth_failure_redirect_url": "updown://terra-callback?success=false"
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw TerraError.invalidResponse
        }
        
        // Log response for debugging
        let responseBody = String(data: data, encoding: .utf8) ?? "No body"
        print("📡 Terra API response (\(httpResponse.statusCode)): \(responseBody)")
        
        // Accept any 2xx status code
        guard (200...299).contains(httpResponse.statusCode) else {
            print("❌ Terra API error: \(responseBody)")
            throw TerraError.apiError(statusCode: httpResponse.statusCode, message: responseBody)
        }
        
        // Parse the response
        do {
            let widgetResponse = try JSONDecoder().decode(TerraWidgetResponse.self, from: data)
            
            guard let widgetURL = URL(string: widgetResponse.url) else {
                throw TerraError.invalidURL
            }
            
            print("✅ Terra widget URL: \(widgetURL)")
            return widgetURL
        } catch {
            // Fallback: extract URL directly from JSON
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let urlString = json["url"] as? String,
               let widgetURL = URL(string: urlString) {
                print("✅ Terra widget URL (fallback): \(widgetURL)")
                return widgetURL
            }
            throw error
        }
    }
    
    // MARK: - Fetch Connected Providers
    func fetchConnectedProviders(userId: String) async {
        await MainActor.run { isLoading = true }
        
        do {
            let connections: [TerraConnection] = try await SupabaseConfig.supabase
                .from("terra_connections")
                .select()
                .eq("user_id", value: userId)
                .eq("is_active", value: true)
                .execute()
                .value
            
            await MainActor.run {
                self.connectedProviders = connections
                self.isLoading = false
            }
        } catch {
            print("❌ Error fetching Terra connections: \(error)")
            await MainActor.run {
                self.connectedProviders = []
                self.isLoading = false
            }
        }
    }
    
    // MARK: - Disconnect Provider
    func disconnectProvider(connectionId: String) async throws {
        try await SupabaseConfig.supabase
            .from("terra_connections")
            .update(["is_active": false])
            .eq("id", value: connectionId)
            .execute()
    }
    
    // MARK: - Check if Provider is Connected
    func isProviderConnected(_ provider: TerraProvider) -> Bool {
        if provider == .apple {
            return isAppleHealthConnected
        }
        return connectedProviders.contains { $0.provider.uppercased() == provider.rawValue && $0.isActive }
    }
    
    func getConnection(for provider: TerraProvider) -> TerraConnection? {
        connectedProviders.first { $0.provider.uppercased() == provider.rawValue && $0.isActive }
    }
    
    // MARK: - Get Apple Health Data (manual fetch)
    func getAppleHealthData(type: TerraDataType, startDate: Date, endDate: Date, completion: @escaping (Bool) -> Void) {
        guard let manager = terraManager else {
            print("❌ Terra SDK not initialized")
            completion(false)
            return
        }
        
        switch type {
        case .activity:
            manager.getActivity(type: .APPLE_HEALTH, startDate: startDate, endDate: endDate) { success, data, error in
                if success {
                    print("✅ Got activity data")
                }
                completion(success)
            }
        case .daily:
            manager.getDaily(type: .APPLE_HEALTH, startDate: startDate, endDate: endDate) { success, data, error in
                if success {
                    print("✅ Got daily data")
                }
                completion(success)
            }
        case .sleep:
            manager.getSleep(type: .APPLE_HEALTH, startDate: startDate, endDate: endDate) { success, data, error in
                if success {
                    print("✅ Got sleep data")
                }
                completion(success)
            }
        case .body:
            manager.getBody(type: .APPLE_HEALTH, startDate: startDate, endDate: endDate) { success, data, error in
                if success {
                    print("✅ Got body data")
                }
                completion(success)
            }
        }
    }
}

// MARK: - Terra Data Types
enum TerraDataType {
    case activity
    case daily
    case sleep
    case body
}

// MARK: - Terra Errors
enum TerraError: LocalizedError {
    case invalidURL
    case invalidResponse
    case apiError(statusCode: Int, message: String)
    case notConnected
    case sdkNotInitialized
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Ogiltig URL"
        case .invalidResponse:
            return "Ogiltigt svar från servern"
        case .apiError(let code, let message):
            return "API-fel (\(code)): \(message)"
        case .notConnected:
            return "Inte ansluten"
        case .sdkNotInitialized:
            return "Terra SDK inte initialiserat"
        }
    }
}
