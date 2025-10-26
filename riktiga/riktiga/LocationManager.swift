import Foundation
import CoreLocation
import Combine

class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var userLocation: CLLocationCoordinate2D?
    @Published var distance: Double = 0.0
    @Published var isTracking = false
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var locationError: String?
    @Published var routeCoordinates: [CLLocationCoordinate2D] = []
    
    private let locationManager = CLLocationManager()
    private var startLocation: CLLocation?
    private var totalDistance: Double = 0.0
    private var lastLocation: CLLocation?
    private var filteredLocation: CLLocation?
    private var locationBuffer: [CLLocation] = []
    private let maxBufferSize = 5
    
    override init() {
        super.init()
        locationManager.delegate = self
        // Use kCLLocationAccuracyHundredMeters for better battery life
        locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        locationManager.distanceFilter = 5 // Small filter for smoother tracking
        locationManager.activityType = .fitness // Optimize for workout tracking
        
        // VIKTIGT: Inte pausera uppdateringar automatiskt
        if #available(iOS 11.0, *) {
            locationManager.pausesLocationUpdatesAutomatically = false
        }
        
        // Enable deferred location updates for battery optimization
        if #available(iOS 6.0, *) {
            locationManager.allowsBackgroundLocationUpdates = false // For better battery life
        }
        
        // Kontrollera initial authorization status
        authorizationStatus = locationManager.authorizationStatus
    }
    
    func requestLocationPermission() {
        locationManager.requestWhenInUseAuthorization()
    }
    
    func requestBackgroundLocationPermission() {
        // Bara requestera whenInUse för simulator
        locationManager.requestWhenInUseAuthorization()
    }
    
    func startTracking() {
        // Kontrollera permissions först
        guard authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways else {
            print("❌ Location permission not granted. Current status: \(authorizationStatus.rawValue)")
            locationError = "Platstillstånd krävs för att spåra din aktivitet"
            return
        }
        
        isTracking = true
        startLocation = nil
        totalDistance = 0.0
        lastLocation = nil
        distance = 0.0
        locationError = nil
        routeCoordinates = []
        
        print("🚀 Starting location tracking...")
        locationManager.startUpdatingLocation()
        
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
    
    func stopTracking() {
        isTracking = false
        locationManager.stopUpdatingLocation()
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        
        // Kalman-style filtering for better accuracy
        let filtered = filterLocation(location)
        
        // Update user location
        DispatchQueue.main.async {
            self.userLocation = filtered.coordinate
        }
        
        if startLocation == nil {
            startLocation = filtered
            lastLocation = filtered
            filteredLocation = filtered
            // Lägg till första punkten i rutten
            DispatchQueue.main.async {
                self.routeCoordinates.append(filtered.coordinate)
            }
        } else if let lastLoc = lastLocation {
            let newDistance = filtered.distance(from: lastLoc)
            
            // Adaptive filtering based on speed and accuracy
            let maxJump = calculateMaxJump(from: lastLoc, to: filtered)
            
            if newDistance <= maxJump && newDistance > 0.5 {
                totalDistance += newDistance
                DispatchQueue.main.async {
                    self.distance = self.totalDistance / 1000.0
                    // Lägg till nya punkten i rutten för smidigare linje
                    self.routeCoordinates.append(filtered.coordinate)
                }
                lastLocation = filtered
                filteredLocation = filtered
            } else {
                print("⚠️ Skipped GPS reading - jump too large: \(newDistance)m (max: \(maxJump)m)")
            }
        }
    }
    
    // Kalman-style filtering
    private func filterLocation(_ location: CLLocation) -> CLLocation {
        // Filter out bad accuracy readings
        guard location.horizontalAccuracy > 0 && location.horizontalAccuracy <= 65 else {
            // Return last known good location if accuracy is too poor
            return filteredLocation ?? location
        }
        
        // If no previous location, just return this one
        guard filteredLocation != nil else {
            locationBuffer.append(location)
            return location
        }
        
        // Add to buffer for averaging
        locationBuffer.append(location)
        if locationBuffer.count > maxBufferSize {
            locationBuffer.removeFirst()
        }
        
        // Calculate weighted average of recent locations
        let filteredLat = weightedAverage(for: locationBuffer.map { $0.coordinate.latitude })
        let filteredLon = weightedAverage(for: locationBuffer.map { $0.coordinate.longitude })
        
        // Create filtered location with better accuracy
        let filtered = CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: filteredLat, longitude: filteredLon),
            altitude: location.altitude,
            horizontalAccuracy: location.horizontalAccuracy,
            verticalAccuracy: location.verticalAccuracy,
            timestamp: location.timestamp
        )
        
        return filtered
    }
    
    // Weighted average gives more weight to recent locations
    private func weightedAverage(for values: [Double]) -> Double {
        guard !values.isEmpty else { return 0.0 }
        
        let count = Double(values.count)
        var weightedSum: Double = 0.0
        var weightSum: Double = 0.0
        
        for (index, value) in values.enumerated() {
            let weight = Double(index + 1) / count // More recent = more weight
            weightedSum += value * weight
            weightSum += weight
        }
        
        return weightedSum / weightSum
    }
    
    // Calculate max allowed jump based on speed and accuracy
    private func calculateMaxJump(from: CLLocation, to: CLLocation) -> Double {
        let timeDiff = to.timestamp.timeIntervalSince(from.timestamp)
        
        // Calculate speed (for potential future use)
        let _ = timeDiff > 0 ? to.distance(from: from) / timeDiff : 0
        
        // Estimate max realistic jump based on speed
        // For running: ~10 m/s, for walking: ~1.4 m/s
        let maxSpeed: Double = 12.0 // m/s (faster than Usain Bolt)
        let estimatedMaxDistance = maxSpeed * timeDiff + 50 // Add 50m buffer
        
        // Also consider accuracy
        let accuracyBuffer = min(to.horizontalAccuracy, from.horizontalAccuracy)
        
        return min(estimatedMaxDistance, accuracyBuffer * 2) + 50
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
                DispatchQueue.main.async {
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
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        DispatchQueue.main.async {
            self.authorizationStatus = status
        }
        
        switch status {
        case .notDetermined:
            print("📍 Location permission not determined, requesting...")
            requestLocationPermission()
        case .restricted, .denied:
            print("❌ Location access denied")
            DispatchQueue.main.async {
                self.locationError = "Platstillstånd nekades. Gå till Inställningar för att aktivera platsåtkomst."
            }
        case .authorizedWhenInUse, .authorizedAlways:
            print("✅ Location access granted")
            DispatchQueue.main.async {
                self.locationError = nil
            }
        @unknown default:
            print("⚠️ Unknown location authorization status")
            break
        }
    }
}
