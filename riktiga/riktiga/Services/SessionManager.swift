import Foundation
import CoreLocation
import Combine

class SessionManager: ObservableObject {
    static let shared = SessionManager()
    
    // Keys for UserDefaults
    private let sessionKey = "activeSession"
    private let backupSessionKey = "activeSessionBackup"
    private let hasSessionKey = "hasActiveSession"
    private let lastSaveTimeKey = "lastSessionSaveTime"
    
    struct ActiveSession: Codable {
        let activityType: String
        let startTime: Date
        let isPaused: Bool
        let accumulatedDuration: Int
        let accumulatedDistance: Double
        let routeCoordinates: [LocationCoordinate]
        var completedSplits: [WorkoutSplit] = []
        let elevationGain: Double?
        let maxSpeed: Double?
        let gymExercises: [GymExercise]?
        let savedAt: Date // Track when this was saved
        
        struct LocationCoordinate: Codable {
            let latitude: Double
            let longitude: Double
            let timestamp: Date
        }
        
        private enum CodingKeys: String, CodingKey {
            case activityType, startTime, isPaused, accumulatedDuration, accumulatedDistance
            case routeCoordinates, completedSplits, elevationGain, maxSpeed, gymExercises, savedAt
        }
        
        init(activityType: String,
             startTime: Date,
             isPaused: Bool,
             accumulatedDuration: Int,
             accumulatedDistance: Double,
             routeCoordinates: [LocationCoordinate],
             completedSplits: [WorkoutSplit] = [],
             elevationGain: Double? = nil,
             maxSpeed: Double? = nil,
             gymExercises: [GymExercise]? = nil,
             savedAt: Date = Date()) {
            self.activityType = activityType
            self.startTime = startTime
            self.isPaused = isPaused
            self.accumulatedDuration = accumulatedDuration
            self.accumulatedDistance = accumulatedDistance
            self.routeCoordinates = routeCoordinates
            self.completedSplits = completedSplits
            self.elevationGain = elevationGain
            self.maxSpeed = maxSpeed
            self.gymExercises = gymExercises
            self.savedAt = savedAt
        }
        
        // Custom decoder to handle backward compatibility (old sessions without savedAt)
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            activityType = try container.decode(String.self, forKey: .activityType)
            startTime = try container.decode(Date.self, forKey: .startTime)
            isPaused = try container.decode(Bool.self, forKey: .isPaused)
            accumulatedDuration = try container.decode(Int.self, forKey: .accumulatedDuration)
            accumulatedDistance = try container.decode(Double.self, forKey: .accumulatedDistance)
            routeCoordinates = try container.decode([LocationCoordinate].self, forKey: .routeCoordinates)
            completedSplits = try container.decodeIfPresent([WorkoutSplit].self, forKey: .completedSplits) ?? []
            elevationGain = try container.decodeIfPresent(Double.self, forKey: .elevationGain)
            maxSpeed = try container.decodeIfPresent(Double.self, forKey: .maxSpeed)
            gymExercises = try container.decodeIfPresent([GymExercise].self, forKey: .gymExercises)
            // Default to current time if savedAt is missing (backward compatibility)
            savedAt = try container.decodeIfPresent(Date.self, forKey: .savedAt) ?? Date()
        }
    }
    
    @Published var hasActiveSession: Bool = false {
        didSet {
            print("🔄 hasActiveSession changed: \(oldValue) -> \(hasActiveSession)")
        }
    }
    @Published var activeSession: ActiveSession?
    // When false, all saveActiveSession calls are ignored. Set to true when starting/resuming a session.
    private var acceptsSaves: Bool = false
    
    private init() {
        // Load session synchronously to avoid init issues
        // Try primary storage first, then backup
        if let session = loadSessionFromStorage(key: sessionKey) ?? loadSessionFromStorage(key: backupSessionKey) {
            self.hasActiveSession = true
            self.activeSession = session
            self.acceptsSaves = true
            print("✅ [SessionManager] Restored active session: \(session.activityType), duration: \(session.accumulatedDuration)s, distance: \(String(format: "%.2f", session.accumulatedDistance))km, coords: \(session.routeCoordinates.count)")
        } else {
            self.hasActiveSession = false
            self.activeSession = nil
            self.acceptsSaves = false
            print("ℹ️ [SessionManager] No saved session found on init")
        }
    }
    
    private func loadSessionFromStorage(key: String) -> ActiveSession? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        do {
            let session = try JSONDecoder().decode(ActiveSession.self, from: data)
            // Validate session - must have been saved within last 24 hours
            if Date().timeIntervalSince(session.savedAt) < 24 * 3600 {
                return session
            } else {
                print("⚠️ [SessionManager] Session from \(key) is too old, ignoring")
                return nil
            }
        } catch {
            print("❌ [SessionManager] Failed to decode session from \(key): \(error)")
            return nil
        }
    }
    
    func saveActiveSession(activityType: String,
                           startTime: Date,
                           isPaused: Bool,
                           duration: Int,
                           distance: Double,
                           routeCoordinates: [CLLocationCoordinate2D],
                           completedSplits: [WorkoutSplit],
                           elevationGain: Double? = nil,
                           maxSpeed: Double? = nil,
                           gymExercises: [GymExercise]? = nil,
                           force: Bool = false) {
        // Ignore saves if session is finalized (unless forced)
        guard acceptsSaves || force else {
            print("⏭️ saveActiveSession ignored (acceptsSaves=false, force=false)")
            return
        }
        
        // Validate we have meaningful data to save
        guard duration > 0 || !routeCoordinates.isEmpty || distance > 0 else {
            print("⏭️ saveActiveSession ignored - no meaningful data to save")
            return
        }
        
        let session = ActiveSession(
            activityType: activityType,
            startTime: startTime,
            isPaused: isPaused,
            accumulatedDuration: duration,
            accumulatedDistance: distance,
            routeCoordinates: routeCoordinates.map { coord in
                ActiveSession.LocationCoordinate(
                    latitude: coord.latitude,
                    longitude: coord.longitude,
                    timestamp: Date()
                )
            },
            completedSplits: completedSplits,
            elevationGain: elevationGain,
            maxSpeed: maxSpeed,
            gymExercises: gymExercises,
            savedAt: Date()
        )
        
        // Save to UserDefaults SYNCHRONOUSLY to ensure it's persisted before app is suspended
        do {
            let encoded = try JSONEncoder().encode(session)
            
            // Save to primary storage
            UserDefaults.standard.set(encoded, forKey: sessionKey)
            UserDefaults.standard.set(true, forKey: hasSessionKey)
            UserDefaults.standard.set(Date(), forKey: lastSaveTimeKey)
            
            // Also save to backup storage (every 5 saves to reduce writes)
            if duration % 5 == 0 || routeCoordinates.count % 10 == 0 {
                UserDefaults.standard.set(encoded, forKey: backupSessionKey)
            }
            
            // Force immediate write to disk - critical for backgrounded apps
            UserDefaults.standard.synchronize()
            
            print("💾 Session saved: duration=\(duration)s, distance=\(String(format: "%.2f", distance))km, coords=\(routeCoordinates.count)")
            
            // Update in-memory state on main thread
            DispatchQueue.main.async { [weak self] in
                self?.hasActiveSession = true
                self?.activeSession = session
            }
        } catch {
            print("❌ Failed to encode session for saving: \(error)")
        }
    }
    
    /// Force save the current in-memory session (useful for emergency saves)
    func forceSaveCurrentSession() {
        guard let session = activeSession else {
            print("⚠️ No active session to force save")
            return
        }
        
        do {
            let encoded = try JSONEncoder().encode(session)
            UserDefaults.standard.set(encoded, forKey: sessionKey)
            UserDefaults.standard.set(encoded, forKey: backupSessionKey)
            UserDefaults.standard.set(true, forKey: hasSessionKey)
            UserDefaults.standard.synchronize()
            print("💾 Force saved current session")
        } catch {
            print("❌ Failed to force save: \(error)")
        }
    }
    
    func loadActiveSession() async {
        await MainActor.run {
            // Try primary first, then backup
            if let session = loadSessionFromStorage(key: sessionKey) ?? loadSessionFromStorage(key: backupSessionKey) {
                self.hasActiveSession = true
                self.activeSession = session
                self.acceptsSaves = true
                print("✅ Loaded active session: \(session.activityType), duration: \(session.accumulatedDuration)s, distance: \(String(format: "%.2f", session.accumulatedDistance))km, coords: \(session.routeCoordinates.count)")
            } else {
                self.hasActiveSession = false
                self.activeSession = nil
                self.acceptsSaves = false
                print("ℹ️ No active session found")
            }
        }
    }
    
    /// Check if there's a recoverable session (call this on app launch)
    func checkForRecoverableSession() -> Bool {
        return loadSessionFromStorage(key: sessionKey) != nil || loadSessionFromStorage(key: backupSessionKey) != nil
    }
    
    /// Atomically and synchronously clear the active session.
    /// This is the single source of truth for resetting session state.
    /// ONLY call this when user explicitly ends/completes/cancels a session!
    func finalizeSession() {
        if !Thread.isMainThread {
            DispatchQueue.main.sync { [weak self] in
                self?.finalizeSession()
            }
            return
        }

        // Log the call stack to help debug unexpected session closures
        let callStack = Thread.callStackSymbols.prefix(10).joined(separator: "\n")
        print("🗑️ finalizeSession() called from:\n\(callStack)")
        print("🗑️ Before: hasActiveSession = \(self.hasActiveSession)")
        
        if let session = activeSession {
            let duration = Int(Date().timeIntervalSince(session.startTime))
            let distance = session.accumulatedDistance
            let coords = session.routeCoordinates.count
            print("🗑️ Session being finalized: duration=\(duration)s (\(duration / 60) min), distance=\(String(format: "%.2f", distance))km, coords=\(coords)")
        }

        // Clear persisted state first so nothing can be reloaded
        // Clear BOTH primary and backup storage
        UserDefaults.standard.removeObject(forKey: sessionKey)
        UserDefaults.standard.removeObject(forKey: backupSessionKey)
        UserDefaults.standard.set(false, forKey: hasSessionKey)
        UserDefaults.standard.removeObject(forKey: lastSaveTimeKey)
        UserDefaults.standard.synchronize()

        // Clear in-memory state
        self.activeSession = nil
        self.hasActiveSession = false
        self.acceptsSaves = false

        // Broadcast that session has been finalized so UI can react
        NotificationCenter.default.post(name: NSNotification.Name("SessionFinalized"), object: nil)

        print("🗑️ After: hasActiveSession = \(self.hasActiveSession)")
    }

    /// Backwards-compatible alias
    func clearActiveSession() {
        finalizeSession()
    }

    /// Call when starting or resuming a session to allow saves again
    func beginSession() {
        acceptsSaves = true
        print("✅ [SessionManager] beginSession() - acceptsSaves = true")
    }
    
    /// Debug: Print current session state
    func debugPrintState() {
        print("📊 [SessionManager] State:")
        print("  - hasActiveSession: \(hasActiveSession)")
        print("  - acceptsSaves: \(acceptsSaves)")
        if let session = activeSession {
            print("  - activityType: \(session.activityType)")
            print("  - duration: \(session.accumulatedDuration)s")
            print("  - distance: \(String(format: "%.2f", session.accumulatedDistance))km")
            print("  - coords: \(session.routeCoordinates.count)")
            print("  - savedAt: \(session.savedAt)")
        } else {
            print("  - activeSession: nil")
        }
    }
}

