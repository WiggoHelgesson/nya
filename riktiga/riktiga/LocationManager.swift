import Foundation
import CoreLocation
import Combine
import UIKit

class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    static let shared = LocationManager()
    
    @Published var userLocation: CLLocationCoordinate2D?
    @Published var distance: Double = 0.0
    @Published var isTracking = false
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var locationError: String?
    @Published var routeCoordinates: [CLLocationCoordinate2D] = []
    @Published var showLocationDeniedAlert = false
    
    // Skiing-specific metrics
    @Published var elevationGain: Double = 0.0 // meters
    @Published var maxSpeed: Double = 0.0 // m/s
    
    private let locationManager = CLLocationManager()
    private var startLocation: CLLocation?
    private var totalDistance: Double = 0.0
    private var lastLocation: CLLocation?
    
    // For lift detection (skiing)
    private var speedHistory: [Double] = [] // Last 10 speed readings
    private var isOnLift: Bool = false
    private var lastValidAltitude: Double? // Last altitude not on lift
    private var currentActivityType: String? // Track current activity type

    // Vehicle detection
    @Published var vehicleDetected: Bool = false
    private var speedThresholdForVehicle: Double = 15.0 // m/s (54 km/h) - speeds above this likely indicate vehicle
    private var recentSpeeds: [Double] = [] // Track last 5 speed readings
    private let maxRecentSpeeds = 5
    
    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = kCLDistanceFilterNone
        locationManager.activityType = .fitness
        
        // VIKTIGT: Inte pausera uppdateringar automatiskt
        if #available(iOS 11.0, *) {
            locationManager.pausesLocationUpdatesAutomatically = false
        }
        
        // Kontrollera initial authorization status
        authorizationStatus = locationManager.authorizationStatus
    }
    
    func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
    
    // Helper to safely enable background location
    private func enableBackgroundLocationIfAuthorized() {
        guard authorizationStatus == .authorizedAlways else { 
            print("⚠️ Cannot enable background location - not authorized")
            return 
        }
        
        // Enable background location updates only when we have Always permission
        if #available(iOS 9.0, *) {
            locationManager.allowsBackgroundLocationUpdates = true
            print("✅ Background location updates enabled")
        }
    }
    
    private var shouldRequestAlwaysAfterWhenInUse = false
    
    func requestLocationPermission() {
        switch authorizationStatus {
        case .authorizedAlways:
            Task { @MainActor in self.locationError = nil }
        case .authorizedWhenInUse:
            locationManager.requestAlwaysAuthorization()
        case .denied, .restricted:
            openSettings()
        case .notDetermined:
            shouldRequestAlwaysAfterWhenInUse = true
            locationManager.requestWhenInUseAuthorization()
        @unknown default:
            locationManager.requestWhenInUseAuthorization()
        }
    }
    
    func requestBackgroundLocationPermission() {
        shouldRequestAlwaysAfterWhenInUse = true
        switch authorizationStatus {
        case .authorizedAlways:
            break
        case .authorizedWhenInUse:
            locationManager.requestAlwaysAuthorization()
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        case .denied, .restricted:
            openSettings()
        @unknown default:
            locationManager.requestAlwaysAuthorization()
        }
    }
    
    func setActivityType(_ activityType: String?) {
        currentActivityType = activityType
    }
    
    func startTracking(preserveData: Bool = false, activityType: String? = nil) {
        if let activityType = activityType {
            currentActivityType = activityType
        }
        // Kontrollera permissions först
        guard authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways else {
            print("❌ Location permission not granted. Current status: \(authorizationStatus.rawValue)")
            Task { @MainActor in
                self.locationError = "Platstillstånd krävs för att spåra din aktivitet"
            }
            return
        }
        
        // Only reset if not preserving data and not already tracking
        if !preserveData && !isTracking {
            // Only reset location data when starting a new session
            if startLocation == nil {
                // Reset everything for a new session
                startLocation = nil
                totalDistance = 0.0
                lastLocation = nil
                distance = 0.0
                locationError = nil
                routeCoordinates = []
                elevationGain = 0.0
                maxSpeed = 0.0
                speedHistory = []
                isOnLift = false
                lastValidAltitude = nil
                recentSpeeds = []
                Task { @MainActor in
                    self.vehicleDetected = false
                }
            }
        }
        
        isTracking = true
        
        if preserveData {
            print("🚀 Resuming location tracking with preserved data...")
        } else {
            print("🚀 Starting location tracking...")
        }
        
        // Enable background updates if authorized
        enableBackgroundLocationIfAuthorized()
        
        locationManager.startUpdatingLocation()
        
        print("✅ Location tracking started")
        
        // Fallback för simulator
        #if targetEnvironment(simulator)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            if self.userLocation == nil {
                print("📍 Setting simulator location to Stockholm")
                self.userLocation = CLLocationCoordinate2D(latitude: 59.3293, longitude: 18.0686) // Stockholm
            }
        }
        #endif
    }
    
    // Function to start a fresh tracking session (resets everything)
    func startNewTracking(activityType: String? = nil) {
        // Reset everything for a new session
        startLocation = nil
        totalDistance = 0.0
        lastLocation = nil
        distance = 0.0
        locationError = nil
        routeCoordinates = []
        elevationGain = 0.0
        maxSpeed = 0.0
        speedHistory = []
        isOnLift = false
        lastValidAltitude = nil
        recentSpeeds = []
        Task { @MainActor in
            self.vehicleDetected = false
        }
        if let activityType = activityType {
            currentActivityType = activityType
        }
        
        startTracking(activityType: activityType)
    }
    
    func stopTracking() {
        isTracking = false
        locationManager.stopUpdatingLocation()
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        
        // Accept location if accuracy is reasonable (more lenient to avoid stopping tracking)
        guard location.horizontalAccuracy > 0 && location.horizontalAccuracy <= 100 else {
            print("⚠️ Poor GPS accuracy: \(location.horizontalAccuracy)m, skipping but NOT stopping tracking")
            // Don't update location but keep tracking active
            return
        }
        
        print("📍 GPS Update: accuracy=\(location.horizontalAccuracy)m")
        
        // Update user location on main thread using Task for async
        Task { @MainActor in
            self.userLocation = location.coordinate
        }
        
        if startLocation == nil {
            // First location
            startLocation = location
            lastLocation = location
            
            // Add first point to route
            Task { @MainActor in
                self.routeCoordinates.append(location.coordinate)
            }
            print("🚀 Tracking started at: \(location.coordinate)")
        } else if let lastLoc = lastLocation {
            // Calculate distance from last location
            let newDistance = location.distance(from: lastLoc)
            
            // Calculate speed (m/s)
            let timeDiff = location.timestamp.timeIntervalSince(lastLoc.timestamp)
            let speed = timeDiff > 0 ? newDistance / timeDiff : 0.0
            
            // Track recent speeds for vehicle detection
            recentSpeeds.append(speed)
            if recentSpeeds.count > maxRecentSpeeds {
                recentSpeeds.removeFirst()
            }
            
            // Check if moving in vehicle (only for non-skiing activities)
            let isInVehicle = detectVehicleMovement(speed)
            if currentActivityType != "Skidåkning" && isInVehicle {
                Task { @MainActor in
                    self.vehicleDetected = true
                }
                print("🚗 Vehicle movement detected - speed: \(String(format: "%.1f", speed)) m/s (\(String(format: "%.1f", speed * 3.6)) km/h)")
                // Skip this distance update
                lastLocation = location
                Task { @MainActor in
                    self.userLocation = location.coordinate
                }
                return
            } else {
                Task { @MainActor in
                    self.vehicleDetected = false
                }
            }
            
            // Accept reasonable distances (up to 100m jumps) and add to route if distance or time moved
            if timeDiff > 0 {
                totalDistance += newDistance
                
                // Handle skiing-specific metrics
                if currentActivityType == "Skidåkning" {
                    // Detect if on lift: speed > 10 m/s (36 km/h) and relatively constant
                    updateSpeedHistory(speed)
                    let avgSpeed = speedHistory.isEmpty ? 0 : speedHistory.reduce(0, +) / Double(speedHistory.count)
                    let speedVariance = speedHistory.isEmpty ? 0 : speedHistory.map { pow($0 - avgSpeed, 2) }.reduce(0, +) / Double(speedHistory.count)
                    
                    // On lift if: average speed > 10 m/s and variance is low (< 5 m²/s² means fairly constant speed)
                    let wasOnLift = isOnLift
                    isOnLift = avgSpeed > 10.0 && speedVariance < 5.0 && speedHistory.count >= 5
                    
                    if !isOnLift {
                        // Not on lift - count elevation gain
                        if let lastAlt = lastValidAltitude, location.altitude > 0 {
                            let altitudeDiff = location.altitude - lastAlt
                            if altitudeDiff > 0 {
                                // Only count positive elevation gain (going uphill while not on lift)
                                Task { @MainActor in
                                    self.elevationGain += altitudeDiff
                                }
                                print("⛰️ Elevation gain: +\(altitudeDiff)m (Total: \(self.elevationGain)m)")
                            }
                            lastValidAltitude = location.altitude
                        } else if location.altitude > 0 {
                            lastValidAltitude = location.altitude
                        }
                        
                        // Update max speed (only when not on lift)
                        if speed > 0 {
                            Task { @MainActor in
                                if speed > self.maxSpeed {
                                    self.maxSpeed = speed
                                    print("🏔️ New max speed: \(String(format: "%.1f", speed)) m/s (\(String(format: "%.1f", speed * 3.6)) km/h)")
                                }
                            }
                        }
                    } else if !wasOnLift {
                        // Just entered lift
                        print("🚡 Entered lift (speed: \(String(format: "%.1f", avgSpeed)) m/s)")
                    }
                } else {
                    // For other activities, track max speed
                    if speed > 0 {
                        Task { @MainActor in
                            if speed > self.maxSpeed {
                                self.maxSpeed = speed
                            }
                        }
                    }
                }
                
                Task { @MainActor in
                    self.distance = self.totalDistance / 1000.0
                    
                    // Add point to route for visualization only if significant distance from last point
                    // This reduces UI updates and improves performance
                    let shouldAddPoint: Bool
                    if let lastRoutePoint = self.routeCoordinates.last {
                        let lastRouteLocation = CLLocation(latitude: lastRoutePoint.latitude, longitude: lastRoutePoint.longitude)
                        let distanceFromLastPoint = location.distance(from: lastRouteLocation)
                        shouldAddPoint = distanceFromLastPoint >= 5.0
                    } else {
                        shouldAddPoint = true
                    }
                    
                    if shouldAddPoint {
                        self.routeCoordinates.append(location.coordinate)
                    }
                    
                    print("📏 Distance updated: \(self.distance) km")
                }
                
                lastLocation = location
            } else {
                print("⚠️ Skipped GPS jump: \(newDistance)m")
            }
        }
    }
    
    private func updateSpeedHistory(_ speed: Double) {
        speedHistory.append(speed)
        // Keep only last 10 readings (about 10 seconds if GPS updates every second)
        if speedHistory.count > 10 {
            speedHistory.removeFirst()
        }
    }
    
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location error: \(error.localizedDescription)")
        
        // Hantera simulator-problem
        if let clError = error as? CLError {
            switch clError.code {
            case .locationUnknown:
                print("⚠️ Location unknown - common in simulator")
                // Simulera en position för simulator
                #if targetEnvironment(simulator)
                Task { @MainActor in
                    self.userLocation = CLLocationCoordinate2D(latitude: 59.3293, longitude: 18.0686) // Stockholm
                }
                #endif
            case .denied:
                print("❌ Location access denied")
            case .network:
                print("❌ Network error")
            default:
                print("❌ Other location error: \(clError.localizedDescription)")
            }
        }
    }
    
    private func detectVehicleMovement(_ currentSpeed: Double) -> Bool {
        // If speed is above 15 m/s (54 km/h), likely in vehicle
        if currentSpeed > speedThresholdForVehicle {
            return true
        }
        
        // Check if recent speeds show consistent high velocity (moving in vehicle)
        if recentSpeeds.count >= 3 {
            let avgSpeed = recentSpeeds.reduce(0, +) / Double(recentSpeeds.count)
            // If average of recent speeds is high, likely in vehicle
            if avgSpeed > 10.0 { // 36 km/h average
                // Check for low variance (consistent speed = vehicle)
                let variance = recentSpeeds.map { pow($0 - avgSpeed, 2) }.reduce(0, +) / Double(recentSpeeds.count)
                if variance < 5.0 {
                    return true
                }
            }
        }
        
        return false
    }
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        Task { @MainActor in
            self.authorizationStatus = status
        }
        
        switch status {
        case .notDetermined:
            print("📍 Location permission not determined, awaiting user choice...")
            Task { @MainActor in
                self.locationError = nil
            }
            
        case .authorizedAlways:
            print("✅ Location access granted (always)")
            enableBackgroundLocationIfAuthorized()
            Task { @MainActor in
                self.locationError = nil
            }
            
        case .authorizedWhenInUse:
            print("ℹ️ Location access granted only when in use")
            if shouldRequestAlwaysAfterWhenInUse {
                shouldRequestAlwaysAfterWhenInUse = false
                locationManager.requestAlwaysAuthorization()
            }
            Task { @MainActor in
                self.locationError = "Välj 'Tillåt alltid' för att appen ska fungera i bakgrunden."
                self.showLocationDeniedAlert = true
            }
            
        case .restricted, .denied:
            print("⚠️ Location permission insufficient - showing warning")
            Task { @MainActor in
                self.locationError = "Platsåtkomst i bakgrunden krävs för att spåra din rutt när appen är stängd. Välj 'Tillåt alltid' i Inställningar."
                self.showLocationDeniedAlert = true
            }
            
        @unknown default:
            print("⚠️ Unknown location authorization status")
            break
        }
    }
}
