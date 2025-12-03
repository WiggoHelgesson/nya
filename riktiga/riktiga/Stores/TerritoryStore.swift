import SwiftUI
import MapKit
import CoreLocation
import Combine

final class TerritoryStore: ObservableObject {
    static let shared = TerritoryStore()
    
    @Published private(set) var territories: [Territory] = []
    @Published private(set) var activeSessionTerritories: [Territory] = [] // Captured during current session
    
    private let service = TerritoryService.shared
    private let eligibleActivities: Set<ActivityType> = [.running, .golf, .hiking, .skiing]
    
    // Loop detection state
    private var lastCheckedIndex = 0
    private var lastCaptureTime: Date = .distantPast
    
    func refresh() async {
        do {
            let remote = try await service.fetchTerritories()
            let mapped = remote.compactMap { $0.asTerritory() }
            await MainActor.run {
                self.territories = mapped
            }
        } catch {
            print("⚠️ Failed to load territories: \(error)")
        }
    }
    
    // MARK: - Real-time Loop Detection
    
    func resetSession() {
        activeSessionTerritories = []
        lastCheckedIndex = 0
        lastCaptureTime = .distantPast
    }
    
    func checkRouteForLoops(coordinates: [CLLocationCoordinate2D], activity: ActivityType, userId: String) {
        guard eligibleActivities.contains(activity) else { return }
        guard coordinates.count > 20 else { return }
        
        // Debounce captures (e.g. wait 10 seconds between captures)
        guard Date().timeIntervalSince(lastCaptureTime) > 10 else { return }
        
        // Only check new points
        // We want to check if the *latest* point closes a loop with *any* previous point
        // But we need a buffer to avoid immediate self-intersection (standing still)
        let currentIndex = coordinates.count - 1
        let current = coordinates[currentIndex]
        let currentLoc = CLLocation(latitude: current.latitude, longitude: current.longitude)
        
        // Look back from (current - buffer) to 0
        // Buffer: ignore last ~15 points (assuming GPS updates every second -> 15 seconds) or ~30 meters
        let buffer = 15
        let searchEndIndex = currentIndex - buffer
        
        guard searchEndIndex > lastCheckedIndex else { return }
        
        // Optimization: iterate backwards to find the *smallest* closed loop first (most recent intersection)
        // Or iterate forwards to find the *largest*?
        // User scenario: "korsade min egen linje". Usually implies the most recent loop.
        
        var foundLoopStart: Int? = nil
        
        for i in stride(from: searchEndIndex, through: lastCheckedIndex, by: -1) {
            let coord = coordinates[i]
            let loc = CLLocation(latitude: coord.latitude, longitude: coord.longitude)
            
            // Distance threshold: 15 meters
            if loc.distance(from: currentLoc) < 15 {
                foundLoopStart = i
                break
            }
        }
        
        if let start = foundLoopStart {
            // Found a loop!
            let loopCoordinates = Array(coordinates[start...currentIndex])
            
            // Basic validation: must have enough points and cover some distance
            if isValidLoop(loopCoordinates) {
                captureLoop(coordinates: loopCoordinates, activity: activity, userId: userId)
                
                // Update state to avoid re-capturing the same loop immediately
                // We set lastCheckedIndex to current, so we only look for *new* loops starting after this point?
                // No, we might form another loop that includes points *before* this loop.
                // But to prevent spamming the same intersection, we should advance.
                lastCheckedIndex = currentIndex
                lastCaptureTime = Date()
            }
        }
    }
    
    private func isValidLoop(_ coordinates: [CLLocationCoordinate2D]) -> Bool {
        guard coordinates.count >= 10 else { return false }
        
        // Calculate perimeter length to ensure it's not just noise
        var perimeter: Double = 0
        for i in 0..<coordinates.count - 1 {
            let c1 = coordinates[i]
            let c2 = coordinates[i+1]
            perimeter += CLLocation(latitude: c1.latitude, longitude: c1.longitude).distance(from: CLLocation(latitude: c2.latitude, longitude: c2.longitude))
        }
        
        return perimeter > 50 // Minimum 50m perimeter
    }
    
    private func captureLoop(coordinates: [CLLocationCoordinate2D], activity: ActivityType, userId: String) {
        print("🎯 Loop detected! Capturing territory...")
        // Ensure the coordinates form a valid closed loop first
        let simplified = ensureClosedLoop(simplify(coordinates))
        
        // Optimistic update: Create a local temporary territory
        let tempId = UUID()
        let tempTerritory = Territory(
            id: tempId,
            ownerId: userId,
            activity: activity,
            area: 0, // We don't compute area locally yet
            polygons: [simplified]
        )
        
        // Update UI immediately on main thread
        DispatchQueue.main.async {
            self.activeSessionTerritories.append(tempTerritory)
            // Also add to main list for Zone War view if not already there
            if !self.territories.contains(where: { $0.id == tempId }) {
                self.territories.append(tempTerritory)
            }
        }
        
        // Send to backend
        Task {
            do {
                let feature = try await service.claimTerritory(ownerId: userId, activity: activity, coordinates: simplified)
                if let territory = feature.asTerritory() {
                    await MainActor.run {
                        // Remove temp territory
                        self.activeSessionTerritories.removeAll { $0.id == tempId }
                        self.territories.removeAll { $0.id == tempId }
                        
                        // Add real territory
                        self.activeSessionTerritories.append(territory)
                        // Prevent duplicates in main list
                        if !self.territories.contains(where: { $0.id == territory.id }) {
                            self.territories.append(territory)
                        }
                    }
                    print("✅ Territory captured and saved!")
                }
            } catch {
                print("⚠️ Failed to claim territory: \(error)")
                // Keep the temp one? Or remove it? Let's keep it as "pending" or remove on failure.
                // For now, removing on failure to avoid desync.
                await MainActor.run {
                    self.activeSessionTerritories.removeAll { $0.id == tempId }
                    self.territories.removeAll { $0.id == tempId }
                }
            }
        }
    }
    
    // Existing end-of-session check (kept for backup)
    func captureTerritoryIfNeeded(activity: ActivityType, routeCoordinates: [CLLocationCoordinate2D], userId: String) {
        guard eligibleActivities.contains(activity) else { return }
        guard routeCoordinates.count >= 4 else { return }
        
        if isClosedLoop(routeCoordinates) {
             // Force capture even if detected before, to be safe at end of session?
             // No, captureLoop handles backend calls.
             captureLoop(coordinates: routeCoordinates, activity: activity, userId: userId)
        }
    }
}

extension TerritoryStore {
    private func isClosedLoop(_ coordinates: [CLLocationCoordinate2D]) -> Bool {
        guard let first = coordinates.first, let last = coordinates.last else { return false }
        let start = CLLocation(latitude: first.latitude, longitude: first.longitude)
        let end = CLLocation(latitude: last.latitude, longitude: last.longitude)
        return start.distance(from: end) <= 25 // Tighter threshold for end-of-session
    }
    
    private func simplify(_ coordinates: [CLLocationCoordinate2D]) -> [CLLocationCoordinate2D] {
        let step = max(1, coordinates.count / 200) // Higher resolution
        guard step > 1 else { return coordinates }
        var simplified: [CLLocationCoordinate2D] = []
        for (index, coordinate) in coordinates.enumerated() where index % step == 0 {
            simplified.append(coordinate)
        }
        // Always include last point
        if let last = coordinates.last {
            simplified.append(last)
        }
        return simplified.count < 3 ? coordinates : simplified
    }

    private func ensureClosedLoop(_ coordinates: [CLLocationCoordinate2D]) -> [CLLocationCoordinate2D] {
        guard coordinates.count >= 3, let first = coordinates.first, let last = coordinates.last else { return coordinates }
        let start = CLLocation(latitude: first.latitude, longitude: first.longitude)
        let end = CLLocation(latitude: last.latitude, longitude: last.longitude)
        if start.distance(from: end) <= 5 {
            var closed = coordinates
            closed[closed.count - 1] = first
            return closed
        } else {
            var closed = coordinates
            closed.append(first)
            return closed
        }
    }
}

struct Territory: Identifiable {
    let id: UUID
    let ownerId: String
    let activity: ActivityType?
    let area: Double
    let polygons: [[CLLocationCoordinate2D]]
}

extension MKPolygon {
    var activityColor: UIColor {
        guard let title = title, let activity = ActivityType(rawValue: title) else {
            return UIColor.systemGreen
        }
        switch activity {
        case .running:
            return UIColor.systemOrange
        case .golf:
            return UIColor.systemBlue
        case .skiing:
            return UIColor.systemTeal
        case .hiking:
            return UIColor.systemBrown
        default:
            return UIColor.systemGreen
        }
    }
}

// Helper for color in SwiftUI
extension Territory {
    var color: Color {
        switch activity {
        case .running: return .orange
        case .golf: return .blue
        case .skiing: return .teal
        case .hiking: return .brown
        default: return .green
        }
    }
}

