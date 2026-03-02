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
    @Published var currentSpeedKmh: Double = 0.0 // Current speed in km/h for UI
    
    private let locationManager = CLLocationManager()
    private var startLocation: CLLocation?
    private var totalDistance: Double = 0.0
    private var lastLocation: CLLocation?
    private var isResumingFromPause: Bool = false
    
    /// Restore distance when resuming a session (prevents distance from resetting to 0)
    func restoreDistance(_ distanceInKm: Double) {
        guard distanceInKm >= 0 else {
            print("⚠️ Invalid distance to restore: \(distanceInKm) km")
            return
        }
        totalDistance = distanceInKm * 1000.0 // Convert km back to meters
        distance = distanceInKm
        print("📍 [RESTORE] totalDistance: \(totalDistance)m (\(String(format: "%.3f", distanceInKm)) km)")
    }
    
    /// Restore route coordinates when resuming a session
    func restoreRouteCoordinates(_ coordinates: [CLLocationCoordinate2D]) {
        guard !coordinates.isEmpty else {
            print("⚠️ No coordinates to restore")
            return
        }
        routeCoordinates = coordinates
        if let firstCoord = coordinates.first {
            startLocation = CLLocation(latitude: firstCoord.latitude, longitude: firstCoord.longitude)
        }
        if let lastCoord = coordinates.last {
            lastLocation = CLLocation(latitude: lastCoord.latitude, longitude: lastCoord.longitude)
            print("📍 [RESTORE] Restored \(coordinates.count) coordinates, startLocation and lastLocation set")
        }
    }
    
    /// Debug print current state
    func debugPrintState() {
        print("📊 [LocationManager] State:")
        print("  - distance: \(String(format: "%.3f", distance)) km")
        print("  - totalDistance: \(String(format: "%.1f", totalDistance)) m")
        print("  - routeCoordinates: \(routeCoordinates.count)")
        print("  - isTracking: \(isTracking)")
        print("  - userLocation: \(userLocation != nil ? "set" : "nil")")
    }
    
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
    
    private var lastLiveActivityUpdate: Date = .distantPast
    private var activityStartTime: Date?
    
    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = 5 // Update every 5 meters for better performance
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
        guard authorizationStatus == .authorizedAlways || authorizationStatus == .authorizedWhenInUse else { 
            print("⚠️ Cannot enable background location - not authorized")
            return 
        }
        
        locationManager.allowsBackgroundLocationUpdates = true
        locationManager.showsBackgroundLocationIndicator = true
        print("✅ Background location updates enabled (status: \(authorizationStatus == .authorizedAlways ? "Always" : "WhenInUse"))")
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
            isResumingFromPause = true
            print("🚀 Resuming location tracking with preserved data...")
        } else {
            print("🚀 Starting location tracking...")
        }
        
        // Enable background updates if authorized
        enableBackgroundLocationIfAuthorized()
        
        locationManager.startUpdatingLocation()
        
        // Start Live Activity
        if !preserveData {
            let type = activityType ?? currentActivityType ?? "Löppass"
            
            // Starta endast Live Activity för löpning/golf/skidåkning etc.
            // Gympass sköter sin egen Live Activity
            if type != "Gympass" {
                activityStartTime = Date()
                let initialState = WorkoutActivityAttributes.ContentState(
                    distance: 0.0,
                    pace: "0:00",
                    elapsedSeconds: 0
                )
                LiveActivityManager.shared.startLiveActivity(workoutType: type, initialContent: initialState)
            }
        }
        
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
        activityStartTime = nil
        LiveActivityManager.shared.endLiveActivity()
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard !locations.isEmpty else { return }
        
        var latestLocation: CLLocation = locations.last!
        var batchedRoutePoints: [CLLocationCoordinate2D] = []
        var latestDistance: Double? = nil
        var latestMaxSpeed: Double? = nil
        var latestElevationGain: Double? = nil
        var latestVehicleDetected: Bool? = nil
        var latestSpeedKmh: Double? = nil
        
        for location in locations {
            guard location.horizontalAccuracy > 0 && location.horizontalAccuracy <= 65 else {
                continue
            }
            
            let locationAge = abs(location.timestamp.timeIntervalSinceNow)
            guard locationAge < 120 else {
                continue
            }
            
            latestLocation = location
            
            if startLocation == nil {
                startLocation = location
                lastLocation = location
                batchedRoutePoints.append(location.coordinate)
                print("📍 FIRST route point added: \(location.coordinate)")
            } else if isResumingFromPause {
                lastLocation = location
                isResumingFromPause = false
                batchedRoutePoints.append(location.coordinate)
                print("📍 Resumed from pause — lastLocation reset to \(location.coordinate)")
            } else if let lastLoc = lastLocation {
                let distanceFromLast = location.distance(from: lastLoc)
                
                let timeDiff = location.timestamp.timeIntervalSince(lastLoc.timestamp)
                let speed = timeDiff > 0 ? distanceFromLast / timeDiff : 0.0
                
                latestSpeedKmh = speed * 3.6
                
                recentSpeeds.append(speed)
                if recentSpeeds.count > maxRecentSpeeds {
                    recentSpeeds.removeFirst()
                }
                
                let isInVehicle = detectVehicleMovement(speed)
                if currentActivityType != "Skidåkning" && isInVehicle {
                    latestVehicleDetected = true
                    lastLocation = location
                    continue
                } else {
                    latestVehicleDetected = false
                }
                
                let maxReasonableDistance = 50.0 * max(timeDiff, 1.0)
                let isValidDistance = distanceFromLast <= maxReasonableDistance && distanceFromLast < 200
                
                if timeDiff > 0 && isValidDistance {
                    totalDistance += distanceFromLast
                    latestDistance = totalDistance / 1000.0
                    
                    if currentActivityType == "Skidåkning" {
                        updateSpeedHistory(speed)
                        let avgSpeed = speedHistory.isEmpty ? 0 : speedHistory.reduce(0, +) / Double(speedHistory.count)
                        let speedVariance = speedHistory.isEmpty ? 0 : speedHistory.map { pow($0 - avgSpeed, 2) }.reduce(0, +) / Double(speedHistory.count)
                        
                        isOnLift = avgSpeed > 10.0 && speedVariance < 5.0 && speedHistory.count >= 5
                        
                        if !isOnLift {
                            if let lastAlt = lastValidAltitude, location.altitude > 0 {
                                let altitudeDiff = location.altitude - lastAlt
                                if altitudeDiff > 0 {
                                    elevationGain += altitudeDiff
                                    latestElevationGain = elevationGain
                                }
                                lastValidAltitude = location.altitude
                            } else if location.altitude > 0 {
                                lastValidAltitude = location.altitude
                            }
                            
                            if speed > maxSpeed {
                                maxSpeed = speed
                                latestMaxSpeed = speed
                            }
                        }
                    } else {
                        if speed > maxSpeed {
                            maxSpeed = speed
                            latestMaxSpeed = speed
                        }
                    }
                    
                    if let lastRoutePoint = batchedRoutePoints.last ?? routeCoordinates.last {
                        let lastRouteLocation = CLLocation(latitude: lastRoutePoint.latitude, longitude: lastRoutePoint.longitude)
                        let distanceFromLastRoute = location.distance(from: lastRouteLocation)
                        
                        let minDistance = 2.0
                        let maxDistance = 80.0
                        let goodAccuracy = location.horizontalAccuracy <= 30
                        let isReasonableJump = distanceFromLastRoute >= minDistance && distanceFromLastRoute <= maxDistance
                        let highAccuracyOverride = location.horizontalAccuracy < 15 && distanceFromLastRoute <= 150
                        
                        if (isReasonableJump && goodAccuracy) || highAccuracyOverride {
                            batchedRoutePoints.append(location.coordinate)
                            print("📍 Route point added (#\(routeCoordinates.count + batchedRoutePoints.count)): dist=\(String(format: "%.1f", distanceFromLastRoute))m, acc=\(String(format: "%.1f", location.horizontalAccuracy))m")
                        }
                    } else {
                        batchedRoutePoints.append(location.coordinate)
                        print("📍 Second route point added")
                    }
                    
                    lastLocation = location
                } else if timeDiff > 30 {
                    lastLocation = location
                    batchedRoutePoints.append(location.coordinate)
                    print("📍 Large time gap (\(String(format: "%.0f", timeDiff))s) — resetting lastLocation")
                }
            }
        }
        
        Task { @MainActor in
            self.userLocation = latestLocation.coordinate
            if let speed = latestSpeedKmh { self.currentSpeedKmh = speed }
            if let vehicle = latestVehicleDetected { self.vehicleDetected = vehicle }
            if let dist = latestDistance { self.distance = dist }
            if let maxSpd = latestMaxSpeed { self.maxSpeed = maxSpd }
            if let elev = latestElevationGain { self.elevationGain = elev }
            if !batchedRoutePoints.isEmpty {
                self.routeCoordinates.append(contentsOf: batchedRoutePoints)
            }
            
            if self.isTracking && abs(self.lastLiveActivityUpdate.timeIntervalSinceNow) > 10 {
                self.lastLiveActivityUpdate = Date()
                let elapsed = self.activityStartTime.map { Int(Date().timeIntervalSince($0)) } ?? 0
                let pace: String = {
                    let speed = self.currentSpeedKmh
                    guard speed > 0.5 else { return "0:00" }
                    let minutesPerKm = 60.0 / speed
                    if minutesPerKm > 30 { return "0:00" }
                    let m = Int(minutesPerKm)
                    let s = Int((minutesPerKm - Double(m)) * 60)
                    return String(format: "%d:%02d", m, s)
                }()
                
                let state = WorkoutActivityAttributes.ContentState(
                    distance: self.distance,
                    pace: pace,
                    elapsedSeconds: elapsed
                )
                LiveActivityManager.shared.updateLiveActivity(with: state)
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
