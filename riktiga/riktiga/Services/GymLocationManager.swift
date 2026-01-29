import Foundation
import CoreLocation
import UserNotifications
import Combine

/// Manages gym location detection and notifications
/// Saves locations where users have gym sessions and notifies them when they return
final class GymLocationManager: NSObject, ObservableObject {
    static let shared = GymLocationManager()
    
    private let locationManager = CLLocationManager()
    private let defaults = UserDefaults.standard
    
    // Keys for UserDefaults
    private let savedGymLocationsKey = "savedGymLocations"
    private let lastNotificationTimeKey = "lastGymNotificationTime"
    private let geofenceRadiusMeters: Double = 100 // 100 meter radius
    private let maxSavedGyms = 5 // Maximum number of gym locations to track
    private let notificationCooldownSeconds: TimeInterval = 3600 // 1 hour cooldown between notifications
    
    @Published var savedGymLocations: [GymLocation] = []
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    
    private var currentUserId: String?
    private var isGymSessionActive = false
    private var pendingSessionLocation: CLLocation? // Store location during session
    private var lastNotificationTime: Date? // Track when last notification was sent
    
    override private init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.allowsBackgroundLocationUpdates = false
        loadSavedGymLocations()
        loadLastNotificationTime()
    }
    
    // MARK: - Public Methods
    
    /// Set the current user ID for location tracking
    func setUser(userId: String) {
        currentUserId = userId
        loadSavedGymLocations()
        loadLastNotificationTime()
        setupGeofencesForSavedGyms()
    }
    
    /// Clear user data on logout
    func clearUser() {
        currentUserId = nil
        stopAllGeofencing()
        savedGymLocations = []
    }
    
    /// Request location permissions
    func requestPermissions() {
        locationManager.requestWhenInUseAuthorization()
    }
    
    /// Request always authorization for background geofencing
    func requestAlwaysAuthorization() {
        locationManager.requestAlwaysAuthorization()
    }
    
    /// Called when user starts a gym session - capture location for potential saving
    func gymSessionStarted() {
        isGymSessionActive = true
        pendingSessionLocation = nil
        
        // Request current location to store (will be saved only if session is completed)
        locationManager.requestLocation()
    }
    
    /// Called when user ends a gym session without saving
    func gymSessionEnded() {
        isGymSessionActive = false
        pendingSessionLocation = nil // Discard the location if not saved
    }
    
    /// Called when user SAVES a gym session - only then save the gym location
    func gymSessionSaved() {
        isGymSessionActive = false
        
        // Only save location if we have a pending location from the session
        if let location = pendingSessionLocation {
            addGymLocation(location)
            print("📍 Gym location saved after session completion")
        } else {
            // Try to get current location as fallback
            locationManager.requestLocation()
        }
        
        pendingSessionLocation = nil
    }
    
    /// Check if user is currently at a saved gym location
    func isAtSavedGym() -> Bool {
        guard let currentLocation = locationManager.location else { return false }
        
        for gym in savedGymLocations {
            let gymLocation = CLLocation(latitude: gym.latitude, longitude: gym.longitude)
            let distance = currentLocation.distance(from: gymLocation)
            if distance <= geofenceRadiusMeters {
                return true
            }
        }
        return false
    }
    
    // MARK: - Private Methods
    
    private func userDefaultsKey() -> String {
        guard let userId = currentUserId else { return savedGymLocationsKey }
        return "\(savedGymLocationsKey)_\(userId)"
    }
    
    private func loadSavedGymLocations() {
        guard let data = defaults.data(forKey: userDefaultsKey()),
              let locations = try? JSONDecoder().decode([GymLocation].self, from: data) else {
            savedGymLocations = []
            return
        }
        savedGymLocations = locations
        print("📍 Loaded \(locations.count) saved gym locations")
    }
    
    private func savGymLocations() {
        guard let data = try? JSONEncoder().encode(savedGymLocations) else { return }
        defaults.set(data, forKey: userDefaultsKey())
    }
    
    private func addGymLocation(_ location: CLLocation) {
        // Check if we already have a gym near this location
        for gym in savedGymLocations {
            let gymLocation = CLLocation(latitude: gym.latitude, longitude: gym.longitude)
            if location.distance(from: gymLocation) < geofenceRadiusMeters {
                // Already have this gym saved, just update visit count
                if let index = savedGymLocations.firstIndex(where: { $0.id == gym.id }) {
                    savedGymLocations[index].visitCount += 1
                    savedGymLocations[index].lastVisited = Date()
                    savGymLocations()
                    print("📍 Updated existing gym location: \(gym.name ?? "Gym")")
                }
                return
            }
        }
        
        // New gym location
        let newGym = GymLocation(
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude,
            name: nil, // Could reverse geocode to get name
            visitCount: 1,
            lastVisited: Date()
        )
        
        // Add to list, keeping only the most visited gyms
        savedGymLocations.append(newGym)
        if savedGymLocations.count > maxSavedGyms {
            // Remove least visited gym
            savedGymLocations.sort { $0.visitCount > $1.visitCount }
            savedGymLocations = Array(savedGymLocations.prefix(maxSavedGyms))
        }
        
        savGymLocations()
        setupGeofence(for: newGym)
        
        // Reverse geocode to get a name
        reverseGeocodeLocation(location) { [weak self] name in
            if let name = name, let index = self?.savedGymLocations.firstIndex(where: { $0.id == newGym.id }) {
                self?.savedGymLocations[index].name = name
                self?.savGymLocations()
            }
        }
        
        print("📍 Saved new gym location")
    }
    
    private func reverseGeocodeLocation(_ location: CLLocation, completion: @escaping (String?) -> Void) {
        let geocoder = CLGeocoder()
        geocoder.reverseGeocodeLocation(location) { placemarks, error in
            guard let placemark = placemarks?.first else {
                completion(nil)
                return
            }
            
            // Try to get a meaningful name
            let name = placemark.name ?? placemark.thoroughfare ?? placemark.locality
            completion(name)
        }
    }
    
    // MARK: - Geofencing
    
    private func setupGeofencesForSavedGyms() {
        // Only setup geofences if we have always authorization
        guard CLLocationManager.authorizationStatus() == .authorizedAlways else {
            print("⚠️ Need 'Always' location permission for gym geofencing")
            return
        }
        
        // Clear existing geofences
        stopAllGeofencing()
        
        // Setup geofence for each saved gym
        for gym in savedGymLocations {
            setupGeofence(for: gym)
        }
    }
    
    private func setupGeofence(for gym: GymLocation) {
        guard CLLocationManager.authorizationStatus() == .authorizedAlways else { return }
        guard CLLocationManager.isMonitoringAvailable(for: CLCircularRegion.self) else {
            print("⚠️ Geofencing not available on this device")
            return
        }
        
        let coordinate = CLLocationCoordinate2D(latitude: gym.latitude, longitude: gym.longitude)
        let region = CLCircularRegion(
            center: coordinate,
            radius: geofenceRadiusMeters,
            identifier: gym.id
        )
        region.notifyOnEntry = true
        region.notifyOnExit = false
        
        locationManager.startMonitoring(for: region)
        print("📍 Started monitoring geofence for gym: \(gym.name ?? gym.id)")
    }
    
    private func stopAllGeofencing() {
        for region in locationManager.monitoredRegions {
            locationManager.stopMonitoring(for: region)
        }
    }
    
    // MARK: - Notifications
    
    private func loadLastNotificationTime() {
        guard let userId = currentUserId else { return }
        let key = "\(lastNotificationTimeKey)_\(userId)"
        lastNotificationTime = defaults.object(forKey: key) as? Date
    }
    
    private func saveLastNotificationTime() {
        guard let userId = currentUserId else { return }
        let key = "\(lastNotificationTimeKey)_\(userId)"
        lastNotificationTime = Date()
        defaults.set(lastNotificationTime, forKey: key)
    }
    
    private func sendGymReminderNotification(gymName: String?) {
        // Don't send if gym session is already active
        guard !isGymSessionActive else {
            print("⏳ Skipping gym notification - session already active")
            return
        }
        
        // Check if SessionManager has an active session
        if SessionManager.shared.activeSession != nil {
            print("⏳ Skipping gym notification - SessionManager has active session")
            return
        }
        
        let content = UNMutableNotificationContent()
        content.title = "Dags för gym? 💪"
        content.body = "Glöm inte tracka passet 🏋️"
        content.sound = .default
        content.userInfo = ["type": "gym_reminder"]
        
        // Use a fixed identifier to prevent duplicate notifications
        let request = UNNotificationRequest(
            identifier: "gym-location-reminder",
            content: content,
            trigger: nil // Send immediately
        )
        
        UNUserNotificationCenter.current().add(request) { [weak self] error in
            if let error = error {
                print("❌ Failed to send gym reminder notification: \(error)")
            } else {
                print("✅ Sent gym reminder notification")
                // Save the time to prevent rapid duplicate notifications
                DispatchQueue.main.async {
                    self?.saveLastNotificationTime()
                }
            }
        }
    }
}

// MARK: - CLLocationManagerDelegate
extension GymLocationManager: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        
        // If gym session is active, store location for potential saving later
        if isGymSessionActive {
            pendingSessionLocation = location
            print("📍 Stored pending gym location during active session")
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("❌ Location error: \(error.localizedDescription)")
    }
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
        
        switch manager.authorizationStatus {
        case .authorizedAlways:
            print("✅ Location: Always authorized - geofencing enabled")
            setupGeofencesForSavedGyms()
        case .authorizedWhenInUse:
            print("✅ Location: When in use authorized")
        case .denied, .restricted:
            print("❌ Location: Denied or restricted")
        case .notDetermined:
            print("⏳ Location: Not determined")
        @unknown default:
            break
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        guard let circularRegion = region as? CLCircularRegion else { return }
        
        print("📍 Entered gym region: \(circularRegion.identifier)")
        
        // Check notification cooldown to avoid multiple notifications
        if let lastTime = lastNotificationTime,
           Date().timeIntervalSince(lastTime) < notificationCooldownSeconds {
            print("⏳ Skipping gym notification - cooldown active (last sent \(Int(Date().timeIntervalSince(lastTime)))s ago)")
            return
        }
        
        // Find the gym - only send notification for gyms with at least 1 saved session
        guard let gym = savedGymLocations.first(where: { $0.id == circularRegion.identifier }),
              gym.visitCount >= 1 else {
            print("⏳ Skipping notification - gym not found or no saved sessions")
            return
        }
        
        sendGymReminderNotification(gymName: gym.name)
    }
}

// MARK: - Gym Location Model
struct GymLocation: Codable, Identifiable {
    var id: String = UUID().uuidString
    let latitude: Double
    let longitude: Double
    var name: String?
    var visitCount: Int
    var lastVisited: Date
}
