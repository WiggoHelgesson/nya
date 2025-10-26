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
        
        struct LocationCoordinate: Codable {
            let latitude: Double
            let longitude: Double
            let timestamp: Date
        }
    }
    
    @Published var hasActiveSession: Bool = false
    @Published var activeSession: ActiveSession?
    
    private init() {
        loadActiveSession()
    }
    
    func saveActiveSession(activityType: String, startTime: Date, isPaused: Bool, duration: Int, distance: Double, routeCoordinates: [CLLocationCoordinate2D]) {
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
            }
        )
        
        // Save to UserDefaults
        if let encoded = try? JSONEncoder().encode(session) {
            UserDefaults.standard.set(encoded, forKey: "activeSession")
            UserDefaults.standard.set(true, forKey: "hasActiveSession")
            
            DispatchQueue.main.async {
                self.hasActiveSession = true
                self.activeSession = session
            }
        }
    }
    
    func loadActiveSession() {
        if let data = UserDefaults.standard.data(forKey: "activeSession"),
           let session = try? JSONDecoder().decode(ActiveSession.self, from: data) {
            DispatchQueue.main.async {
                self.hasActiveSession = true
                self.activeSession = session
            }
        } else {
            DispatchQueue.main.async {
                self.hasActiveSession = false
                self.activeSession = nil
            }
        }
    }
    
    func clearActiveSession() {
        UserDefaults.standard.removeObject(forKey: "activeSession")
        UserDefaults.standard.set(false, forKey: "hasActiveSession")
        
        DispatchQueue.main.async {
            self.hasActiveSession = false
            self.activeSession = nil
        }
    }
}

