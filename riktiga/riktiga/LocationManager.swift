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
        
        // Enable background location updates
        if #available(iOS 9.0, *) {
            locationManager.allowsBackgroundLocationUpdates = true
        }
        
        // Kontrollera initial authorization status
        authorizationStatus = locationManager.authorizationStatus
    }
    
    func requestLocationPermission() {
        // Request always authorization for background tracking
        locationManager.requestAlwaysAuthorization()
    }
    
    func requestBackgroundLocationPermission() {
        // Request always authorization
        locationManager.requestAlwaysAuthorization()
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
        
        // Ensure background location is enabled
        if #available(iOS 9.0, *) {
            locationManager.allowsBackgroundLocationUpdates = true
        }
        
        locationManager.startUpdatingLocation()
        
        print("✅ Location tracking started with background updates")
        
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
        
        // Accept location if accuracy is reasonable (more lenient to avoid stopping tracking)
        guard location.horizontalAccuracy > 0 && location.horizontalAccuracy <= 100 else {
            print("⚠️ Poor GPS accuracy: \(location.horizontalAccuracy)m, skipping but NOT stopping tracking")
            // Don't update location but keep tracking active
            return
        }
        
        print("📍 GPS Update: accuracy=\(location.horizontalAccuracy)m")
        
        // Update user location on main thread
        DispatchQueue.main.async {
            self.userLocation = location.coordinate
        }
        
        if startLocation == nil {
            // First location
            startLocation = location
            lastLocation = location
            
            // Add first point to route
            DispatchQueue.main.async {
                self.routeCoordinates.append(location.coordinate)
            }
            print("🚀 Tracking started at: \(location.coordinate)")
        } else if let lastLoc = lastLocation {
            // Calculate distance from last location
            let newDistance = location.distance(from: lastLoc)
            
            // Accept reasonable distances (up to 100m jumps)
            if newDistance > 0 && newDistance < 100 {
                totalDistance += newDistance
                
                DispatchQueue.main.async {
                    self.distance = self.totalDistance / 1000.0
                    // Add point to route for visualization
                    self.routeCoordinates.append(location.coordinate)
                    print("📏 Distance updated: \(self.distance) km")
                }
                
                lastLocation = location
            } else {
                print("⚠️ Skipped GPS jump: \(newDistance)m")
            }
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
        case .authorizedWhenInUse:
            print("✅ Location access granted (when in use)")
            DispatchQueue.main.async {
                self.locationError = nil
            }
        case .authorizedAlways:
            print("✅ Location access granted (always - background tracking enabled)")
            // Enable background updates when always authorization is granted
            if #available(iOS 9.0, *) {
                locationManager.allowsBackgroundLocationUpdates = true
            }
            DispatchQueue.main.async {
                self.locationError = nil
            }
        @unknown default:
            print("⚠️ Unknown location authorization status")
            break
        }
    }
}
