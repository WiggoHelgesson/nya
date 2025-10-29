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
        let elevationGain: Double?
        let maxSpeed: Double?
        
        struct LocationCoordinate: Codable {
            let latitude: Double
            let longitude: Double
            let timestamp: Date
        }
        
        init(activityType: String, startTime: Date, isPaused: Bool, accumulatedDuration: Int, accumulatedDistance: Double, routeCoordinates: [LocationCoordinate], elevationGain: Double? = nil, maxSpeed: Double? = nil) {
            self.activityType = activityType
            self.startTime = startTime
            self.isPaused = isPaused
            self.accumulatedDuration = accumulatedDuration
            self.accumulatedDistance = accumulatedDistance
            self.routeCoordinates = routeCoordinates
            self.elevationGain = elevationGain
            self.maxSpeed = maxSpeed
        }
    }
    
    @Published var hasActiveSession: Bool = false {
        didSet {
            print("🔄 hasActiveSession changed: \(oldValue) -> \(hasActiveSession)")
        }
    }
    @Published var activeSession: ActiveSession?
    
    private init() {
        // Load session synchronously to avoid init issues
        if let data = UserDefaults.standard.data(forKey: "activeSession"),
           let session = try? JSONDecoder().decode(ActiveSession.self, from: data) {
            self.hasActiveSession = true
            self.activeSession = session
        } else {
            self.hasActiveSession = false
            self.activeSession = nil
        }
    }
    
    func saveActiveSession(activityType: String, startTime: Date, isPaused: Bool, duration: Int, distance: Double, routeCoordinates: [CLLocationCoordinate2D], elevationGain: Double? = nil, maxSpeed: Double? = nil) {
        Task {
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
                elevationGain: elevationGain,
                maxSpeed: maxSpeed
            )
            
            // Save to UserDefaults
            if let encoded = try? JSONEncoder().encode(session) {
                UserDefaults.standard.set(encoded, forKey: "activeSession")
                UserDefaults.standard.set(true, forKey: "hasActiveSession")
                
                await MainActor.run {
                    self.hasActiveSession = true
                    self.activeSession = session
                }
            }
        }
    }
    
    func loadActiveSession() async {
        await MainActor.run {
            if let data = UserDefaults.standard.data(forKey: "activeSession"),
               let session = try? JSONDecoder().decode(ActiveSession.self, from: data) {
                self.hasActiveSession = true
                self.activeSession = session
                print("✅ Loaded active session: \(session.activityType)")
            } else {
                self.hasActiveSession = false
                self.activeSession = nil
                print("ℹ️ No active session found")
            }
        }
    }
    
    func clearActiveSession() {
        print("🗑️ clearActiveSession() called")
        print("🗑️ Before: hasActiveSession = \(self.hasActiveSession)")
        
        // Clear UserDefaults FIRST to prevent reload
        UserDefaults.standard.removeObject(forKey: "activeSession")
        UserDefaults.standard.set(false, forKey: "hasActiveSession")
        print("🗑️ UserDefaults cleared immediately")
        
        // Update UI state
        self.hasActiveSession = false
        self.activeSession = nil
        
        print("🗑️ After: hasActiveSession = \(self.hasActiveSession)")
    }
}

