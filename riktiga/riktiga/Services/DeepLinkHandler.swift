import Foundation
import SwiftUI
import Combine
import Supabase

/// Handles deep links for the app (password reset, etc.)
final class DeepLinkHandler: ObservableObject {
    static let shared = DeepLinkHandler()
    
    @Published var showResetPassword = false
    @Published var pendingAccessToken: String?
    @Published var pendingRefreshToken: String?
    
    private init() {}
    
    /// Handle incoming URL
    /// Returns true if the URL was handled
    @MainActor
    func handle(url: URL) -> Bool {
        print("📱 DeepLinkHandler received URL: \(url)")
        
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: true) else {
            print("❌ Could not parse URL components")
            return false
        }
        
        // Handle different URL schemes
        // Supabase sends: upanddown://reset-password#access_token=...&refresh_token=...&type=recovery
        // or: upanddown://callback#access_token=...&refresh_token=...&type=recovery
        
        let host = components.host ?? ""
        let path = components.path
        
        print("📱 Host: \(host), Path: \(path)")
        
        // Check for password reset
        // The tokens are in the fragment (after #), not query params
        if let fragment = url.fragment {
            print("📱 Fragment: \(fragment)")
            
            // Parse fragment as query items
            let fragmentParams = parseFragment(fragment)
            
            if let type = fragmentParams["type"], type == "recovery" {
                print("✅ Password recovery deep link detected")
                
                if let accessToken = fragmentParams["access_token"],
                   let refreshToken = fragmentParams["refresh_token"] {
                    
                    // Set the session with these tokens
                    Task {
                        await setSessionFromTokens(accessToken: accessToken, refreshToken: refreshToken)
                    }
                    
                    // Show reset password view
                    showResetPassword = true
                    return true
                }
            }
        }
        
        // Handle Stripe return URLs
        if host == "stripe-return" || path.contains("stripe") {
            print("✅ Stripe return deep link detected")
            // Just return true, the app will handle refreshing the status
            return true
        }
        
        print("⚠️ Unhandled deep link: \(url)")
        return false
    }
    
    /// Parse URL fragment into dictionary
    private func parseFragment(_ fragment: String) -> [String: String] {
        var params: [String: String] = [:]
        let pairs = fragment.split(separator: "&")
        
        for pair in pairs {
            let keyValue = pair.split(separator: "=", maxSplits: 1)
            if keyValue.count == 2 {
                let key = String(keyValue[0])
                let value = String(keyValue[1]).removingPercentEncoding ?? String(keyValue[1])
                params[key] = value
            }
        }
        
        return params
    }
    
    /// Set Supabase session from recovery tokens
    private func setSessionFromTokens(accessToken: String, refreshToken: String) async {
        do {
            // Use the session to authenticate the user for password update
            try await SupabaseConfig.supabase.auth.setSession(accessToken: accessToken, refreshToken: refreshToken)
            print("✅ Session set from recovery tokens")
        } catch {
            print("❌ Failed to set session from tokens: \(error)")
        }
    }
}

