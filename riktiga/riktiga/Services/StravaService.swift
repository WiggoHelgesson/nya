import Foundation
import CoreLocation
import UIKit
import Combine

// MARK: - Strava Configuration
struct StravaConfig {
    static let clientId = "192603"
    static let clientSecret = "49b5e75e99bb41d90b82417e7c35c46496419ab3"
    // Custom URL scheme - bare minimum format
    static let redirectUri = "upanddown://upanddown"
    static let scope = "activity:write,activity:read_all"
    
    // Use MOBILE authorize endpoint
    static let authorizeUrl = "https://www.strava.com/oauth/mobile/authorize"
    static let tokenUrl = "https://www.strava.com/oauth/token"
    static let uploadUrl = "https://www.strava.com/api/v3/activities"
}

// MARK: - Strava Token Model
struct StravaToken: Codable {
    let accessToken: String
    let refreshToken: String
    let expiresAt: Int
    let athleteId: Int?
    
    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case expiresAt = "expires_at"
        case athleteId = "athlete_id"
    }
    
    var isExpired: Bool {
        return Date().timeIntervalSince1970 > Double(expiresAt)
    }
}

// MARK: - Strava Activity Types
enum StravaActivityType: String {
    case run = "Run"
    case ride = "Ride"
    case walk = "Walk"
    case hike = "Hike"
    case weightTraining = "WeightTraining"
    case workout = "Workout"
    case golf = "Golf"
    case nordicSki = "NordicSki"
    case alpineSki = "AlpineSki"
    
    static func from(appActivity: String) -> StravaActivityType {
        switch appActivity.lowercased() {
        case "löpning", "löppass", "running":
            return .run
        case "cykling", "cycling":
            return .ride
        case "promenad", "walking":
            return .walk
        case "vandring", "hiking", "bergsbestigning":
            return .hike
        case "gym", "gympass", "styrketräning":
            return .weightTraining
        case "golf", "golfrunda":
            return .golf
        case "skidor", "skidpass", "skiing":
            return .nordicSki
        default:
            return .workout
        }
    }
}

// MARK: - Strava Service
@MainActor
class StravaService: ObservableObject {
    static let shared = StravaService()
    
    @Published var isConnected: Bool = false
    @Published var isLoading: Bool = false
    @Published var athleteName: String?
    @Published var lastUploadStatus: String?
    
    private let tokenKey = "strava_token"
    private let athleteNameKey = "strava_athlete_name"
    private var currentToken: StravaToken?
    
    private init() {
        loadStoredToken()
    }
    
    // MARK: - Connection Status
    
    private func loadStoredToken() {
        if let data = UserDefaults.standard.data(forKey: tokenKey),
           let token = try? JSONDecoder().decode(StravaToken.self, from: data) {
            currentToken = token
            isConnected = true
            athleteName = UserDefaults.standard.string(forKey: athleteNameKey)
            print("🏃 Strava: Token loaded, connected")
        }
    }
    
    private func saveToken(_ token: StravaToken) {
        if let data = try? JSONEncoder().encode(token) {
            UserDefaults.standard.set(data, forKey: tokenKey)
            currentToken = token
            isConnected = true
            print("🏃 Strava: Token saved")
        }
    }
    
    func disconnect() {
        UserDefaults.standard.removeObject(forKey: tokenKey)
        UserDefaults.standard.removeObject(forKey: athleteNameKey)
        currentToken = nil
        isConnected = false
        athleteName = nil
        print("🏃 Strava: Disconnected")
    }
    
    // MARK: - OAuth Flow
    
    func startOAuthFlow() {
        // Build URL manually to ensure correct encoding
        let redirectEncoded = StravaConfig.redirectUri.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? StravaConfig.redirectUri
        
        let urlString = "\(StravaConfig.authorizeUrl)?client_id=\(StravaConfig.clientId)&redirect_uri=\(redirectEncoded)&response_type=code&approval_prompt=auto&scope=\(StravaConfig.scope)"
        
        guard let url = URL(string: urlString) else {
            print("❌ Strava: Failed to create URL")
            return
        }
        
        print("🏃 Strava: ========== OAUTH DEBUG ==========")
        print("🏃 Strava: Client ID: \(StravaConfig.clientId)")
        print("🏃 Strava: Redirect URI: \(StravaConfig.redirectUri)")
        print("🏃 Strava: Redirect Encoded: \(redirectEncoded)")
        print("🏃 Strava: Full URL: \(url.absoluteString)")
        print("🏃 Strava: ================================")
        
        UIApplication.shared.open(url)
    }
    
    func handleOAuthCallback(url: URL) async -> Bool {
        print("🏃 Strava: Handling callback URL: \(url)")
        
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let code = components.queryItems?.first(where: { $0.name == "code" })?.value else {
            print("❌ Strava: No code in callback")
            return false
        }
        
        // Check for errors
        if let error = components.queryItems?.first(where: { $0.name == "error" })?.value {
            print("❌ Strava: OAuth error: \(error)")
            return false
        }
        
        print("🏃 Strava: Got authorization code, exchanging for token")
        return await exchangeCodeForToken(code: code)
    }
    
    private func exchangeCodeForToken(code: String) async -> Bool {
        isLoading = true
        defer { isLoading = false }
        
        guard let url = URL(string: StravaConfig.tokenUrl) else { return false }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        let body = [
            "client_id": StravaConfig.clientId,
            "client_secret": StravaConfig.clientSecret,
            "code": code,
            "grant_type": "authorization_code"
        ]
        
        request.httpBody = body
            .map { "\($0.key)=\($0.value)" }
            .joined(separator: "&")
            .data(using: .utf8)
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                print("❌ Strava: Token exchange failed")
                if let responseString = String(data: data, encoding: .utf8) {
                    print("Response: \(responseString)")
                }
                return false
            }
            
            // Parse token response
            let decoder = JSONDecoder()
            let tokenResponse = try decoder.decode(StravaTokenResponse.self, from: data)
            
            let token = StravaToken(
                accessToken: tokenResponse.accessToken,
                refreshToken: tokenResponse.refreshToken,
                expiresAt: tokenResponse.expiresAt,
                athleteId: tokenResponse.athlete?.id
            )
            
            saveToken(token)
            
            // Save athlete name
            if let athlete = tokenResponse.athlete {
                let name = "\(athlete.firstname ?? "") \(athlete.lastname ?? "")".trimmingCharacters(in: .whitespaces)
                if !name.isEmpty {
                    athleteName = name
                    UserDefaults.standard.set(name, forKey: athleteNameKey)
                }
            }
            
            print("✅ Strava: Connected successfully")
            return true
            
        } catch {
            print("❌ Strava: Token exchange error: \(error)")
            return false
        }
    }
    
    // MARK: - Token Refresh
    
    private func refreshTokenIfNeeded() async -> String? {
        guard let token = currentToken else { return nil }
        
        // Check if token is still valid (with 5 min buffer)
        let expirationWithBuffer = Double(token.expiresAt) - 300
        if Date().timeIntervalSince1970 < expirationWithBuffer {
            return token.accessToken
        }
        
        print("🏃 Strava: Refreshing expired token")
        
        guard let url = URL(string: StravaConfig.tokenUrl) else { return nil }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        let body = [
            "client_id": StravaConfig.clientId,
            "client_secret": StravaConfig.clientSecret,
            "refresh_token": token.refreshToken,
            "grant_type": "refresh_token"
        ]
        
        request.httpBody = body
            .map { "\($0.key)=\($0.value)" }
            .joined(separator: "&")
            .data(using: .utf8)
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                print("❌ Strava: Token refresh failed")
                return nil
            }
            
            let decoder = JSONDecoder()
            let tokenResponse = try decoder.decode(StravaToken.self, from: data)
            saveToken(tokenResponse)
            
            print("✅ Strava: Token refreshed")
            return tokenResponse.accessToken
            
        } catch {
            print("❌ Strava: Token refresh error: \(error)")
            return nil
        }
    }
    
    // MARK: - Upload Activity
    
    func uploadActivity(
        title: String,
        description: String?,
        activityType: String,
        startDate: Date,
        duration: Int,
        distance: Double?,
        routeCoordinates: [CLLocationCoordinate2D]?
    ) async -> Bool {
        guard isConnected else {
            print("⚠️ Strava: Not connected")
            lastUploadStatus = "Inte ansluten till Strava"
            return false
        }
        
        guard let accessToken = await refreshTokenIfNeeded() else {
            print("❌ Strava: Could not get valid token")
            lastUploadStatus = "Kunde inte autentisera"
            return false
        }
        
        print("🏃 Strava: Uploading activity: \(title)")
        
        guard let url = URL(string: StravaConfig.uploadUrl) else { return false }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let stravaType = StravaActivityType.from(appActivity: activityType)
        
        // Create activity payload
        var payload: [String: Any] = [
            "name": title,
            "type": stravaType.rawValue,
            "start_date_local": ISO8601DateFormatter().string(from: startDate),
            "elapsed_time": duration
        ]
        
        if let desc = description, !desc.isEmpty {
            payload["description"] = desc + "\n\n📱 Registrerad med Up&Down"
        } else {
            payload["description"] = "📱 Registrerad med Up&Down"
        }
        
        if let dist = distance, dist > 0 {
            payload["distance"] = dist * 1000 // Convert km to meters
        }
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: payload)
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                lastUploadStatus = "Okänt fel"
                return false
            }
            
            if httpResponse.statusCode == 201 {
                print("✅ Strava: Activity uploaded successfully")
                lastUploadStatus = "Uppladdat till Strava!"
                return true
            } else {
                if let responseString = String(data: data, encoding: .utf8) {
                    print("❌ Strava: Upload failed (\(httpResponse.statusCode)): \(responseString)")
                }
                
                if httpResponse.statusCode == 401 {
                    lastUploadStatus = "Autentisering misslyckades"
                    // Token might be revoked, disconnect
                    disconnect()
                } else {
                    lastUploadStatus = "Uppladdning misslyckades"
                }
                return false
            }
            
        } catch {
            print("❌ Strava: Upload error: \(error)")
            lastUploadStatus = "Nätverksfel"
            return false
        }
    }
}

// MARK: - Token Response Models

private struct StravaTokenResponse: Codable {
    let accessToken: String
    let refreshToken: String
    let expiresAt: Int
    let athlete: StravaAthlete?
    
    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case expiresAt = "expires_at"
        case athlete
    }
}

private struct StravaAthlete: Codable {
    let id: Int
    let firstname: String?
    let lastname: String?
}


