import Foundation
import Supabase

/// Ensures the Supabase auth session stays alive so RLS-protected queries keep returning data.
actor AuthSessionManager {
    static let shared = AuthSessionManager()
    private let supabase = SupabaseConfig.supabase
    private var refreshTask: Task<Void, Error>?
    private init() {}
    
    /// Makes sure there is an active, non-expired session before performing database queries.
    /// Throws `AuthError.sessionMissing` if the user must re-authenticate.
    func ensureValidSession(leeway seconds: TimeInterval = 60) async throws {
        do {
            let session = try await supabase.auth.session
            let expirationDate = Date(timeIntervalSince1970: session.expiresAt)
            if expirationDate.timeIntervalSinceNow < seconds {
                try await refreshSession()
            }
        } catch let authError as AuthError {
            switch authError {
            case .sessionMissing:
                print("❌ Supabase session missing – user needs to log in again")
                throw authError
            default:
                print("⚠️ Supabase session error: \(authError). Trying refresh…")
                try await refreshSession()
            }
        } catch {
            print("⚠️ Unexpected error reading session: \(error). Trying refresh…")
            try await refreshSession()
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
}

