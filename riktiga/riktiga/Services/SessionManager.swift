import Foundation
import CoreLocation
import Combine

class SessionManager: ObservableObject {
    static let shared = SessionManager()
    
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
        
        struct LocationCoordinate: Codable {
            let latitude: Double
            let longitude: Double
            let timestamp: Date
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
             gymExercises: [GymExercise]? = nil) {
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
        if let data = UserDefaults.standard.data(forKey: "activeSession"),
           let session = try? JSONDecoder().decode(ActiveSession.self, from: data) {
            self.hasActiveSession = true
            self.activeSession = session
            self.acceptsSaves = true
            print("✅ [SessionManager] Restored active session: \(session.activityType), duration: \(session.accumulatedDuration)s, distance: \(String(format: "%.2f", session.accumulatedDistance))km")
        } else {
            self.hasActiveSession = false
            self.activeSession = nil
            self.acceptsSaves = false
            print("ℹ️ [SessionManager] No saved session found on init")
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
                           gymExercises: [GymExercise]? = nil) {
        // Ignore saves if session is finalized
        guard acceptsSaves else {
            print("⏭️ saveActiveSession ignored (acceptsSaves=false)")
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
            gymExercises: gymExercises
        )
        
        // Save to UserDefaults SYNCHRONOUSLY to ensure it's persisted before app is suspended
        if let encoded = try? JSONEncoder().encode(session) {
            UserDefaults.standard.set(encoded, forKey: "activeSession")
            UserDefaults.standard.set(true, forKey: "hasActiveSession")
            // Force immediate write to disk - critical for backgrounded apps
            UserDefaults.standard.synchronize()
            
            print("💾 Session saved: duration=\(duration)s, distance=\(String(format: "%.2f", distance))km, coords=\(routeCoordinates.count)")
            
            // Update in-memory state on main thread
            DispatchQueue.main.async { [weak self] in
                self?.hasActiveSession = true
                self?.activeSession = session
            }
        } else {
            print("❌ Failed to encode session for saving")
        }
    }
    
    func loadActiveSession() async {
        await MainActor.run {
            if let data = UserDefaults.standard.data(forKey: "activeSession"),
               let session = try? JSONDecoder().decode(ActiveSession.self, from: data) {
                self.hasActiveSession = true
                self.activeSession = session
                self.acceptsSaves = true
                print("✅ Loaded active session: \(session.activityType)")
            } else {
                self.hasActiveSession = false
                self.activeSession = nil
                self.acceptsSaves = false
                print("ℹ️ No active session found")
            }
        }
    }
    
    /// Atomically and synchronously clear the active session.
    /// This is the single source of truth for resetting session state.
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
            print("🗑️ Session duration was: \(duration) seconds (\(duration / 60) minutes)")
        }

        // Clear persisted state first so nothing can be reloaded
        UserDefaults.standard.removeObject(forKey: "activeSession")
        UserDefaults.standard.set(false, forKey: "hasActiveSession")

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
    }
}

