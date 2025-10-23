import Foundation
import CoreLocation
import Combine

class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var userLocation: CLLocationCoordinate2D?
    @Published var distance: Double = 0.0
    @Published var isTracking = false
    
    private let locationManager = CLLocationManager()
    private var startLocation: CLLocation?
    private var totalDistance: Double = 0.0
    private var lastLocation: CLLocation?
    
    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = 10
        
        // VIKTIGT: Inte pausera uppdateringar automatiskt
        if #available(iOS 11.0, *) {
            locationManager.pausesLocationUpdatesAutomatically = false
        }
    }
    
    func requestLocationPermission() {
        locationManager.requestWhenInUseAuthorization()
    }
    
    func requestBackgroundLocationPermission() {
        // Bara requestera whenInUse för simulator
        locationManager.requestWhenInUseAuthorization()
    }
    
    func startTracking() {
        isTracking = true
        startLocation = nil
        totalDistance = 0.0
        lastLocation = nil
        distance = 0.0
        
        // Starta endast cuando quando användaren är i appen
        locationManager.startUpdatingLocation()
    }
    
    func stopTracking() {
        isTracking = false
        locationManager.stopUpdatingLocation()
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        
        DispatchQueue.main.async {
            self.userLocation = location.coordinate
        }
        
        if startLocation == nil {
            startLocation = location
            lastLocation = location
        } else if let lastLoc = lastLocation {
            let newDistance = location.distance(from: lastLoc)
            if newDistance < 100 && newDistance > 0 {
                totalDistance += newDistance
                DispatchQueue.main.async {
                    self.distance = self.totalDistance / 1000.0
                }
            }
            lastLocation = location
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location error: \(error.localizedDescription)")
    }
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        switch status {
        case .notDetermined:
            requestLocationPermission()
        case .restricted, .denied:
            print("Location access denied")
        case .authorizedWhenInUse, .authorizedAlways:
            print("Location access granted")
        @unknown default:
            break
        }
    }
}
