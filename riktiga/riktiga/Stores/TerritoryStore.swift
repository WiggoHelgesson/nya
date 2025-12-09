import SwiftUI
import MapKit
import CoreLocation
import Combine

final class TerritoryStore: ObservableObject {
    static let shared = TerritoryStore()
    
    @Published private(set) var territories: [Territory] = []
    @Published private(set) var activeSessionTerritories: [Territory] = []
    
    private let service = TerritoryService.shared
    private let eligibleActivities: Set<ActivityType> = [.running, .golf]
    private let localStorageKey = "LocalTerritories"
    
    // MARK: - Caching & Performance
    private var cachedTerritoryIds: Set<UUID> = []
    private var lastFetchBounds: (minLat: Double, maxLat: Double, minLon: Double, maxLon: Double)?
    private var lastFetchTime: Date = .distantPast
    private let cacheValidityDuration: TimeInterval = 60 // 1 minute cache
    private let boundsMargin: Double = 0.02 // Extra margin around viewport
    
    // Debounce
    private var debounceTask: Task<Void, Never>?
    private let debounceInterval: TimeInterval = 0.3 // 300ms debounce
    
    init() {
        loadLocalTerritories()
    }
    
    // MARK: - Viewport-based Loading with Debounce
    
    /// Refresh territories within the visible map bounds with debouncing
    func refreshForViewport(
        minLat: Double,
        maxLat: Double,
        minLon: Double,
        maxLon: Double
    ) {
        // Cancel any pending debounce
        debounceTask?.cancel()
        
        // Start new debounce task
        debounceTask = Task { @MainActor in
            // Wait for debounce interval
            try? await Task.sleep(nanoseconds: UInt64(debounceInterval * 1_000_000_000))
            
            guard !Task.isCancelled else { return }
            
            // Check if we need to fetch (bounds changed significantly or cache expired)
            let shouldFetch = shouldFetchForBounds(minLat: minLat, maxLat: maxLat, minLon: minLon, maxLon: maxLon)
            
            if shouldFetch {
                await performViewportFetch(minLat: minLat, maxLat: maxLat, minLon: minLon, maxLon: maxLon)
            }
        }
    }
    
    private func shouldFetchForBounds(minLat: Double, maxLat: Double, minLon: Double, maxLon: Double) -> Bool {
        // Always fetch if cache is old
        if Date().timeIntervalSince(lastFetchTime) > cacheValidityDuration {
            return true
        }
        
        // Check if bounds changed significantly
        guard let lastBounds = lastFetchBounds else {
            return true
        }
        
        // Calculate if new bounds are outside the cached bounds (with margin)
        let expandedMinLat = lastBounds.minLat - boundsMargin
        let expandedMaxLat = lastBounds.maxLat + boundsMargin
        let expandedMinLon = lastBounds.minLon - boundsMargin
        let expandedMaxLon = lastBounds.maxLon + boundsMargin
        
        // If new viewport is within expanded cached bounds, no need to fetch
        if minLat >= expandedMinLat && maxLat <= expandedMaxLat &&
           minLon >= expandedMinLon && maxLon <= expandedMaxLon {
            return false
        }
        
        return true
    }
    
    private func performViewportFetch(minLat: Double, maxLat: Double, minLon: Double, maxLon: Double) async {
        #if DEBUG
        // print("🗺️ Viewport fetch")
        #endif
        
        // Add margin to fetch area (so we have data for nearby scrolling)
        let fetchMinLat = minLat - boundsMargin
        let fetchMaxLat = maxLat + boundsMargin
        let fetchMinLon = minLon - boundsMargin
        let fetchMaxLon = maxLon + boundsMargin
        
        do {
            let remote = try await service.fetchTerritoriesInBounds(
                minLat: fetchMinLat,
                maxLat: fetchMaxLat,
                minLon: fetchMinLon,
                maxLon: fetchMaxLon
            )
            
            let mapped = remote.compactMap { $0.asTerritory() }
            
            await MainActor.run {
                // Merge with existing territories (keep territories outside viewport)
                let newIds = Set(mapped.map { $0.id })
                
                // Keep territories that are outside the new fetch area or in the new fetch
                var updatedTerritories = self.territories.filter { territory in
                    // Keep if not in the fetch area OR if it's in the new fetch
                    if newIds.contains(territory.id) {
                        return false // Will be replaced by new version
                    }
                    return true
                }
                
                // Add newly fetched territories
                updatedTerritories.append(contentsOf: mapped)
                
                // Add any pending local territories
                let localTerritories = self.loadLocalTerritoriesSync()
                let allIds = Set(updatedTerritories.map { $0.id })
                let pendingLocal = localTerritories.filter { !allIds.contains($0.id) }
                updatedTerritories.append(contentsOf: pendingLocal)
                
                self.territories = updatedTerritories
                self.cachedTerritoryIds = Set(updatedTerritories.map { $0.id })
                self.lastFetchBounds = (fetchMinLat, fetchMaxLat, fetchMinLon, fetchMaxLon)
                self.lastFetchTime = Date()
                
                // Viewport loaded silently for performance
            }
        } catch {
            print("❌ Viewport fetch failed: \(error)")
        }
    }
    
    /// Force invalidate cache (call when new territory is claimed)
    func invalidateCache() {
        lastFetchTime = .distantPast
        lastFetchBounds = nil
    }
    
    func refresh() async {
        do {
            let remote = try await service.fetchTerritories()
            let mapped = remote.compactMap { $0.asTerritory() }
            
            await MainActor.run {
                var allTerritories = mapped
                
                // Merge with local pending territories
                let localTerritories = loadLocalTerritoriesSync()
                let remoteIds = Set(mapped.map { $0.id })
                let pendingLocal = localTerritories.filter { !remoteIds.contains($0.id) }
                
                if !pendingLocal.isEmpty {
                    allTerritories.append(contentsOf: pendingLocal)
                }
                
                self.territories = allTerritories
            }
        } catch {
            // Fallback to local territories on error
            await MainActor.run {
                let localTerritories = loadLocalTerritoriesSync()
                if !localTerritories.isEmpty && self.territories.isEmpty {
                    self.territories = localTerritories
                }
            }
        }
    }
    
    func resetSession() {
        activeSessionTerritories = []
    }
    
    func finalizeTerritoryCapture(
        activity: ActivityType,
        routeCoordinates: [CLLocationCoordinate2D],
        userId: String,
        sessionDistance: Double? = nil,
        sessionDuration: Int? = nil,
        sessionPace: String? = nil
    ) {
        guard eligibleActivities.contains(activity) else { return }
        guard routeCoordinates.count >= 3 else { return }
        
        // Close the polygon properly
        let closed = ensureClosedLoop(routeCoordinates)
        
        // Simplify to reduce self-intersections
        let simplified = simplifyPolygon(closed, tolerance: 0.00005)
        
        // Use convex hull for very complex routes
        let finalCoordinates: [CLLocationCoordinate2D]
        if simplified.count > 500 {
            finalCoordinates = convexHull(simplified)
        } else {
            finalCoordinates = simplified
        }
        
        // Ensure polygon is closed
        let validPolygon = ensureClosedLoop(finalCoordinates)
        let area = calculateArea(coordinates: validPolygon)
        
        let pendingTerritory = Territory(
            id: UUID(),
            ownerId: userId,
            activity: activity,
            area: area,
            polygons: [validPolygon],
            sessionDistance: sessionDistance,
            sessionDuration: sessionDuration,
            sessionPace: sessionPace,
            createdAt: Date()
        )
        
        // Save locally
        saveLocalTerritory(pendingTerritory)
        
        DispatchQueue.main.async {
            self.activeSessionTerritories = [pendingTerritory]
            if !self.territories.contains(where: { $0.id == pendingTerritory.id }) {
                self.territories.append(pendingTerritory)
            }
        }
        
        // Save to backend (non-blocking)
        Task {
            do {
                let feature = try await service.claimTerritory(
                    ownerId: userId,
                    activity: activity,
                    coordinates: validPolygon,
                    distance: sessionDistance,
                    duration: sessionDuration,
                    pace: sessionPace
                )
                
                if let territory = feature.asTerritory() {
                    var updatedTerritory = territory
                    updatedTerritory.sessionDistance = sessionDistance
                    updatedTerritory.sessionDuration = sessionDuration
                    updatedTerritory.sessionPace = sessionPace
                    
                    removeLocalTerritory(id: pendingTerritory.id)
                    saveLocalTerritory(updatedTerritory)
                    
                    await MainActor.run {
                        self.activeSessionTerritories = [updatedTerritory]
                        self.territories.removeAll { $0.id == pendingTerritory.id }
                        if !self.territories.contains(where: { $0.id == updatedTerritory.id }) {
                            self.territories.append(updatedTerritory)
                        }
                    }
                    await self.refresh()
                }
            } catch {
                // Territory kept locally as fallback
            }
        }
    }
    
    // MARK: - Polygon Processing
    
    private func ensureClosedLoop(_ coordinates: [CLLocationCoordinate2D]) -> [CLLocationCoordinate2D] {
        guard coordinates.count >= 3 else { return coordinates }
        guard let first = coordinates.first, let last = coordinates.last else { return coordinates }
        
        var result = coordinates
        
        // Check if already closed (exact match)
        if first.latitude == last.latitude && first.longitude == last.longitude {
            return result
        }
        
        // Check if close enough (within 10 meters)
        let start = CLLocation(latitude: first.latitude, longitude: first.longitude)
        let end = CLLocation(latitude: last.latitude, longitude: last.longitude)
        
        if start.distance(from: end) <= 10 {
            // Replace last with first to ensure exact closure
            result[result.count - 1] = first
        } else {
            // Append first point to close
            result.append(first)
        }
        
        return result
    }
    
    private func simplifyPolygon(_ coordinates: [CLLocationCoordinate2D], tolerance: Double) -> [CLLocationCoordinate2D] {
        guard coordinates.count > 10 else { return coordinates }
        
        // Douglas-Peucker simplification
        var result: [CLLocationCoordinate2D] = []
        var stack: [(Int, Int)] = [(0, coordinates.count - 1)]
        var keep = Set<Int>([0, coordinates.count - 1])
        
        while !stack.isEmpty {
            let (start, end) = stack.removeLast()
            
            var maxDist: Double = 0
            var maxIndex = start
            
            for i in (start + 1)..<end {
                let dist = perpendicularDistance(
                    point: coordinates[i],
                    lineStart: coordinates[start],
                    lineEnd: coordinates[end]
                )
                if dist > maxDist {
                    maxDist = dist
                    maxIndex = i
                }
            }
            
            if maxDist > tolerance {
                keep.insert(maxIndex)
                stack.append((start, maxIndex))
                stack.append((maxIndex, end))
            }
        }
        
        for i in 0..<coordinates.count {
            if keep.contains(i) {
                result.append(coordinates[i])
            }
        }
        
        return result.count >= 3 ? result : coordinates
    }
    
    private func perpendicularDistance(point: CLLocationCoordinate2D, lineStart: CLLocationCoordinate2D, lineEnd: CLLocationCoordinate2D) -> Double {
        let dx = lineEnd.longitude - lineStart.longitude
        let dy = lineEnd.latitude - lineStart.latitude
        
        let lengthSquared = dx * dx + dy * dy
        if lengthSquared == 0 {
            return sqrt(pow(point.longitude - lineStart.longitude, 2) + pow(point.latitude - lineStart.latitude, 2))
        }
        
        var t = ((point.longitude - lineStart.longitude) * dx + (point.latitude - lineStart.latitude) * dy) / lengthSquared
        t = max(0, min(1, t))
        
        let nearestX = lineStart.longitude + t * dx
        let nearestY = lineStart.latitude + t * dy
        
        return sqrt(pow(point.longitude - nearestX, 2) + pow(point.latitude - nearestY, 2))
    }
    
    private func convexHull(_ points: [CLLocationCoordinate2D]) -> [CLLocationCoordinate2D] {
        guard points.count >= 3 else { return points }
        
        // Sort by x, then y
        let sorted = points.sorted { a, b in
            if a.longitude != b.longitude {
                return a.longitude < b.longitude
            }
            return a.latitude < b.latitude
        }
        
        // Build lower hull
        var lower: [CLLocationCoordinate2D] = []
        for p in sorted {
            while lower.count >= 2 && cross(lower[lower.count - 2], lower[lower.count - 1], p) <= 0 {
                lower.removeLast()
            }
            lower.append(p)
        }
        
        // Build upper hull
        var upper: [CLLocationCoordinate2D] = []
        for p in sorted.reversed() {
            while upper.count >= 2 && cross(upper[upper.count - 2], upper[upper.count - 1], p) <= 0 {
                upper.removeLast()
            }
            upper.append(p)
        }
        
        // Remove last point of each half because it's repeated
        lower.removeLast()
        upper.removeLast()
        
        return lower + upper
    }
    
    private func cross(_ o: CLLocationCoordinate2D, _ a: CLLocationCoordinate2D, _ b: CLLocationCoordinate2D) -> Double {
        return (a.longitude - o.longitude) * (b.latitude - o.latitude) - (a.latitude - o.latitude) * (b.longitude - o.longitude)
    }
    
    func calculateArea(coordinates: [CLLocationCoordinate2D]) -> Double {
        guard coordinates.count >= 3 else { return 0 }
        
        var area: Double = 0
        let earthRadius = 6371000.0
        
        for i in 0..<coordinates.count {
            let p1 = coordinates[i]
            let p2 = coordinates[(i + 1) % coordinates.count]
            
            let lat1Rad = p1.latitude * .pi / 180
            let lon1Rad = p1.longitude * .pi / 180
            let lat2Rad = p2.latitude * .pi / 180
            let lon2Rad = p2.longitude * .pi / 180
            
            area += (lon2Rad - lon1Rad) * (2 + sin(lat1Rad) + sin(lat2Rad))
        }
        
        return abs(area * earthRadius * earthRadius / 2.0)
    }
    
    // MARK: - Local Storage
    
    private func loadLocalTerritories() {
        territories = loadLocalTerritoriesSync()
        print("🌍 TerritoryStore: Loaded \(territories.count) territories from local storage")
    }
    
    private func loadLocalTerritoriesSync() -> [Territory] {
        guard let data = UserDefaults.standard.data(forKey: localStorageKey),
              let stored = try? JSONDecoder().decode([StoredTerritory].self, from: data) else {
            return []
        }
        return stored.map { $0.toTerritory() }
    }
    
    private func saveLocalTerritory(_ territory: Territory) {
        var stored = loadLocalTerritoriesSync().map { StoredTerritory(from: $0) }
        if !stored.contains(where: { $0.id == territory.id.uuidString }) {
            stored.append(StoredTerritory(from: territory))
        }
        if let data = try? JSONEncoder().encode(stored) {
            UserDefaults.standard.set(data, forKey: localStorageKey)
            print("💾 Saved territory. Total local: \(stored.count)")
        }
    }
    
    private func removeLocalTerritory(id: UUID) {
        var stored = loadLocalTerritoriesSync().map { StoredTerritory(from: $0) }
        stored.removeAll { $0.id == id.uuidString }
        if let data = try? JSONEncoder().encode(stored) {
            UserDefaults.standard.set(data, forKey: localStorageKey)
        }
    }
    
    // Debug: Clear all local territories
    func clearLocalTerritories() {
        UserDefaults.standard.removeObject(forKey: localStorageKey)
        territories = []
        print("🗑 Cleared all local territories")
    }
    
    // Sync local territories to backend
    func syncLocalTerritoriesToBackend() async {
        let localTerritories = loadLocalTerritoriesSync()
        print("🔄 Syncing \(localTerritories.count) local territories to backend...")
        
        for territory in localTerritories {
            guard let firstPolygon = territory.polygons.first, firstPolygon.count >= 3 else {
                print("⚠️ Skipping territory \(territory.id) - invalid polygon")
                continue
            }
            
            guard let activity = territory.activity else {
                print("⚠️ Skipping territory \(territory.id) - no activity type")
                continue
            }
            
            do {
                print("🔄 Syncing territory \(territory.id)...")
                let feature = try await service.claimTerritory(
                    ownerId: territory.ownerId,
                    activity: activity,
                    coordinates: firstPolygon
                )
                print("✅ Synced territory \(territory.id) -> backend ID: \(feature.id)")
                
                // Remove local and save with backend ID
                removeLocalTerritory(id: territory.id)
                if let newTerritory = feature.asTerritory() {
                    saveLocalTerritory(newTerritory)
                }
            } catch {
                print("❌ Failed to sync territory \(territory.id): \(error)")
            }
        }
        
        print("🔄 Sync complete. Refreshing from backend...")
        await refresh()
    }
}

// MARK: - Codable Storage

private struct StoredTerritory: Codable {
    let id: String
    let ownerId: String
    let activityRaw: String?
    let area: Double
    let polygons: [[[Double]]] // [[lat, lon]]
    let sessionDistance: Double?
    let sessionDuration: Int?
    let sessionPace: String?
    let createdAt: Date?
    
    init(from territory: Territory) {
        self.id = territory.id.uuidString
        self.ownerId = territory.ownerId
        self.activityRaw = territory.activity?.rawValue
        self.area = territory.area
        self.polygons = territory.polygons.map { ring in
            ring.map { [$0.latitude, $0.longitude] }
        }
        self.sessionDistance = territory.sessionDistance
        self.sessionDuration = territory.sessionDuration
        self.sessionPace = territory.sessionPace
        self.createdAt = territory.createdAt
    }
    
    func toTerritory() -> Territory {
        Territory(
            id: UUID(uuidString: id) ?? UUID(),
            ownerId: ownerId,
            activity: activityRaw.flatMap { ActivityType(rawValue: $0) },
            area: area,
            polygons: polygons.map { ring in
                ring.compactMap { pair -> CLLocationCoordinate2D? in
                    guard pair.count == 2 else { return nil }
                    return CLLocationCoordinate2D(latitude: pair[0], longitude: pair[1])
                }
            },
            sessionDistance: sessionDistance,
            sessionDuration: sessionDuration,
            sessionPace: sessionPace,
            createdAt: createdAt
        )
    }
}

// MARK: - Models

struct Territory: Identifiable {
    let id: UUID
    let ownerId: String
    let activity: ActivityType?
    let area: Double
    let polygons: [[CLLocationCoordinate2D]]
    
    // Session data (optional - for display purposes)
    var sessionDistance: Double? // in km
    var sessionDuration: Int? // in seconds
    var sessionPace: String? // formatted pace string
    var createdAt: Date?
}

extension MKPolygon {
    var activityColor: UIColor {
        guard let title = title, let activity = ActivityType(rawValue: title) else {
            return UIColor.systemGreen
        }
        switch activity {
        case .running: return UIColor.systemOrange
        case .golf: return UIColor.systemBlue
        case .skiing: return UIColor.systemTeal
        case .hiking: return UIColor.systemBrown
        default: return UIColor.systemGreen
        }
    }
}

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

