import Foundation
import Supabase

/// Ensures the Supabase auth session stays alive so RLS-protected queries keep returning data.
actor AuthSessionManager {
    static let shared = AuthSessionManager()
    private let supabase = SupabaseConfig.supabase
    private var refreshTask: Task<Void, Error>?
    private var lastRefreshTime: Date = .distantPast
    private let minRefreshInterval: TimeInterval = 120 // 2 minutes between refreshes (more aggressive)
    private var consecutiveFailures: Int = 0
    private let maxRetries: Int = 5 // More retries
    private var isHealthy: Bool = true
    private var lastHealthCheck: Date = .distantPast
    
    private init() {}
    
    /// Makes sure there is an active, non-expired session before performing database queries.
    /// More resilient - won't throw on temporary network issues, only on true auth failures.
    func ensureValidSession(leeway seconds: TimeInterval = 180) async throws {
        // Always try to get current session first
        do {
            let session = try await supabase.auth.session
            let expirationDate = Date(timeIntervalSince1970: session.expiresAt)
            let timeUntilExpiry = expirationDate.timeIntervalSinceNow
            
            // Be more aggressive about refreshing:
            // - Refresh if expiring within 3 minutes (leeway)
            // - Refresh if we haven't refreshed in 2 minutes
            // - Refresh if we previously had failures
            let shouldRefresh = timeUntilExpiry < seconds || 
                                Date().timeIntervalSince(lastRefreshTime) > minRefreshInterval ||
                                !isHealthy
            
            if shouldRefresh {
                try await refreshSessionWithRetry()
            }
            
            // Mark as healthy and reset failure count
            isHealthy = true
            consecutiveFailures = 0
            lastHealthCheck = Date()
            
        } catch let authError as AuthError {
            isHealthy = false
            switch authError {
            case .sessionMissing:
                print("❌ Supabase session missing – user needs to log in again")
                throw authError
            default:
                print("⚠️ Supabase session error: \(authError). Trying refresh with retry…")
                try await refreshSessionWithRetry()
                isHealthy = true
            }
        } catch {
            // For network errors, be more lenient - don't fail immediately
            isHealthy = false
            print("⚠️ Session check error (possibly network): \(error)")
            
            consecutiveFailures += 1
            
            // Try to refresh anyway - might recover the session
            do {
                try await refreshSessionWithRetry()
                consecutiveFailures = 0
                isHealthy = true
                return // Success!
            } catch {
                print("⚠️ Refresh failed (attempt \(consecutiveFailures)/\(maxRetries))")
            }
            
            // Only throw after many consecutive failures
            if consecutiveFailures >= maxRetries {
                print("❌ Too many consecutive session failures (\(consecutiveFailures))")
                throw error
            }
            
            // Don't throw - let the operation proceed and potentially fail gracefully
            print("⚠️ Session uncertain but allowing operation to proceed")
        }
    }
    
    /// Check if the session is currently healthy (can be called synchronously to check state)
    var sessionIsHealthy: Bool {
        get { isHealthy }
    }
    
    /// Perform a quick health check - useful before batch operations
    func quickHealthCheck() async -> Bool {
        // If we checked recently and was healthy, skip
        if isHealthy && Date().timeIntervalSince(lastHealthCheck) < 30 {
            return true
        }
        
        do {
            try await ensureValidSession(leeway: 60)
            return true
        } catch {
            return false
        }
    }
    
    /// Refresh with retry logic for network resilience
    private func refreshSessionWithRetry() async throws {
        var lastError: Error?
        
        for attempt in 1...maxRetries {
            do {
                try await refreshSession()
                lastRefreshTime = Date()
                isHealthy = true
                print("✅ Session refreshed on attempt \(attempt)")
                return
            } catch {
                lastError = error
                print("⚠️ Refresh attempt \(attempt)/\(maxRetries) failed: \(error.localizedDescription)")
                
                // Wait before retrying (exponential backoff with jitter)
                if attempt < maxRetries {
                    // 0.5s, 1s, 2s, 4s base delays with random jitter
                    let baseDelay = pow(2.0, Double(attempt - 1)) * 0.5
                    let jitter = Double.random(in: 0...0.3)
                    let totalDelay = baseDelay + jitter
                    try? await Task.sleep(nanoseconds: UInt64(totalDelay * 1_000_000_000))
                }
            }
        }
        
        isHealthy = false
        if let error = lastError {
            throw error
        }
    }
    
    private func refreshSession() async throws {
        if let ongoing = refreshTask {
            try await ongoing.value
            return
        }
        let task = Task {
            do {
                _ = try await supabase.auth.refreshSession()
                print("✅ Supabase session refreshed")
            } catch {
                print("❌ Failed to refresh Supabase session: \(error)")
                throw error
            }
        }
        refreshTask = task
        do {
            try await task.value
        } catch {
            refreshTask = nil
            throw error
        }
        refreshTask = nil
    }
    
    /// Force a refresh regardless of timing (use when recovering from errors)
    func forceRefresh() async throws {
        lastRefreshTime = .distantPast
        consecutiveFailures = 0
        isHealthy = false // Mark as unhealthy to force full refresh
        try await refreshSessionWithRetry()
    }
    
    /// Reset failure counter (call when app becomes active)
    func resetFailureCounter() {
        Task {
            await _resetFailureCounter()
        }
    }
    
    private func _resetFailureCounter() {
        consecutiveFailures = 0
    }
    
    /// Recover from a bad state - call this when you detect data issues
    func recoverSession() async {
        print("🔄 Attempting session recovery...")
        isHealthy = false
        consecutiveFailures = 0
        lastRefreshTime = .distantPast
        
        do {
            try await refreshSessionWithRetry()
            print("✅ Session recovered successfully")
        } catch {
            print("❌ Session recovery failed: \(error.localizedDescription)")
        }
    }
    
    /// Call this when app becomes active to proactively refresh
    func onAppBecameActive() async {
        let timeSinceLastRefresh = Date().timeIntervalSince(lastRefreshTime)
        
        // If we haven't refreshed in 5+ minutes, do it now
        if timeSinceLastRefresh > 300 {
            print("🔄 App became active - proactively refreshing session...")
            do {
                try await ensureValidSession()
            } catch {
                print("⚠️ Proactive refresh failed: \(error.localizedDescription)")
            }
        }
    }
}

