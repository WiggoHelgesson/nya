import SwiftUI
import MapKit
import CoreLocation
import Combine

final class TerritoryStore: ObservableObject {
    static let shared = TerritoryStore()
    
    @Published private(set) var territories: [Territory] = []
    @Published private(set) var activeSessionTerritories: [Territory] = []
    @Published private(set) var tiles: [Tile] = []
    @Published var pendingCelebrationTerritory: Territory?
    
    private let service = TerritoryService.shared
    private let eligibleActivities: Set<ActivityType> = [.running, .golf]
    private let localStorageKey = "LocalTerritories"
    
    // MARK: - Caching & Performance
    private var cachedTerritoryIds: Set<UUID> = []
    private var lastFetchBounds: (minLat: Double, maxLat: Double, minLon: Double, maxLon: Double)?
    private var lastFetchTime: Date = .distantPast
    private let cacheValidityDuration: TimeInterval = 15 // 15 seconds cache for faster sync
    private let boundsMargin: Double = 0.2 // Extra margin around viewport (increased to show more tiles)
    
    // Tiles cache - use dictionary for O(1) lookups and stable updates
    private var tileCache: [Int64: Tile] = [:] // Dictionary by tile ID
    private var lastTileFetchTime: Date = .distantPast
    private var lastTileBounds: (minLat: Double, maxLat: Double, minLon: Double, maxLon: Double)?
    private let tileCacheValidity: TimeInterval = 30 // 30 seconds - faster refresh for new tiles
    private var isFetchingTiles: Bool = false // Prevent concurrent fetches
    private let maxCachedTiles: Int = 10000 // Support large areas - only visible viewport is fetched anyway
    
    // Track if we need force refresh (set after completing a workout)
    @Published var needsForceRefresh: Bool = false
    
    // Debounce
    private var debounceTask: Task<Void, Never>?
    private let debounceInterval: TimeInterval = 0.8 // 800ms debounce (increased for smoother map)
    
    init() {
        // We do NOT load local territories anymore. Server is truth.
        // loadLocalTerritories() 
    }
    
    /// Approximate area per tile (25m x 25m = 625m²)
    let tileAreaApprox: Double = 625.0
    
    /// Force clear all caches and refetch territories
    func forceRefresh() {
        lastFetchTime = .distantPast
        lastFetchBounds = nil
        lastTileFetchTime = .distantPast
        lastTileBounds = nil
        cachedTerritoryIds.removeAll()
        territories.removeAll()
        tileCache.removeAll()
        tiles.removeAll()
        
        // Clear local storage (cleanup)
        UserDefaults.standard.removeObject(forKey: localStorageKey)
        
        print("🔄 Territory cache forcefully cleared")
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
                
                // We do NOT add local territories anymore. Grid is truth.
                
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
        lastTileFetchTime = .distantPast // Also invalidate tiles
        lastTileBounds = nil
    }
    
    func refresh() async {
        do {
            let remote = try await service.fetchTerritories()
            let mapped = remote.compactMap { $0.asTerritory() }
            
            await MainActor.run {
                // Strictly server authoritative
                self.territories = mapped
            }
        } catch {
            print("❌ Territory refresh failed: \(error)")
            // No fallback to local anymore
        }
    }

    // MARK: - Tiles
    func loadTilesInBounds(minLat: Double, maxLat: Double, minLon: Double, maxLon: Double, forceRefresh: Bool = false) async {
        // Prevent concurrent fetches that cause flickering
        guard !isFetchingTiles else {
            print("⏳ [TILES] Skipping fetch - already fetching")
            return
        }
        
        let now = Date()
        
        // Check if we need force refresh (after completing a workout)
        let shouldForce = forceRefresh || needsForceRefresh
        
        // Skip cache check if force refresh
        if !shouldForce {
            // Throttle tile fetches - only fetch if cache expired OR bounds are outside cached area
            let cacheValid = now.timeIntervalSince(lastTileFetchTime) < tileCacheValidity
            let boundsWithinCache: Bool = {
                guard let last = lastTileBounds else { return false }
                return minLat >= last.minLat - boundsMargin &&
                       maxLat <= last.maxLat + boundsMargin &&
                       minLon >= last.minLon - boundsMargin &&
                       maxLon <= last.maxLon + boundsMargin
            }()
            
            if cacheValid && boundsWithinCache {
                print("💾 [TILES] Using cached tiles (count: \(tiles.count))")
                return // Use existing cached tiles
            }
        }
        
        // Clear the force refresh flag
        if needsForceRefresh {
            await MainActor.run { needsForceRefresh = false }
        }
        
        print("🔄 [TILES] Fetching tiles for bounds: \(minLat)-\(maxLat), \(minLon)-\(maxLon) (force: \(shouldForce))")
        
        await MainActor.run { isFetchingTiles = true }
        defer { Task { @MainActor in isFetchingTiles = false } }
        
        // Expand fetch bounds significantly for smoother scrolling
        let expandedMinLat = minLat - boundsMargin * 2
        let expandedMaxLat = maxLat + boundsMargin * 2
        let expandedMinLon = minLon - boundsMargin * 2
        let expandedMaxLon = maxLon + boundsMargin * 2

        do {
            let result = try await service.fetchTilesInBounds(
                minLat: expandedMinLat,
                maxLat: expandedMaxLat,
                minLon: expandedMinLon,
                maxLon: expandedMaxLon
            )
            
            await MainActor.run {
                // MERGE tiles instead of replacing - prevents flickering
                var updatedCache = self.tileCache
                
                for feature in result {
                    let ring = feature.geom.coordinates.first ?? []
                    let coords = ring.compactMap { pair -> CLLocationCoordinate2D? in
                        guard pair.count == 2 else { return nil }
                        return CLLocationCoordinate2D(latitude: pair[1], longitude: pair[0])
                    }
                    
                    let tile = Tile(
                        id: feature.tile_id,
                        ownerId: feature.owner_id,
                        activityId: feature.activity_id,
                        distanceKm: feature.distance_km,
                        durationSec: feature.duration_sec,
                        pace: feature.pace,
                        coordinates: coords,
                        lastUpdatedAt: feature.last_updated_at
                    )
                    
                    // Update or insert tile
                    updatedCache[feature.tile_id] = tile
                }
                
                // Limit cache size to prevent memory issues
                if updatedCache.count > self.maxCachedTiles {
                    // Keep only the most recent tiles (by string comparison - ISO dates sort correctly)
                    let sortedTiles = updatedCache.values.sorted { 
                        ($0.lastUpdatedAt ?? "") > ($1.lastUpdatedAt ?? "")
                    }
                    let tilesToKeep = Array(sortedTiles.prefix(self.maxCachedTiles))
                    updatedCache = Dictionary(uniqueKeysWithValues: tilesToKeep.map { ($0.id, $0) })
                }
                
                // Only update published array if there are actual changes
                let newTiles = Array(updatedCache.values)
                if newTiles.count != self.tiles.count || 
                   Set(newTiles.map { $0.id }) != Set(self.tiles.map { $0.id }) ||
                   self.tilesHaveOwnershipChanges(old: self.tiles, new: newTiles) {
                    self.tileCache = updatedCache
                    self.tiles = newTiles
                }
                
                self.lastTileFetchTime = now
                self.lastTileBounds = (expandedMinLat, expandedMaxLat, expandedMinLon, expandedMaxLon)
                
                print("✅ [TILES] Loaded \(result.count) tiles from server, total cached: \(self.tiles.count)")
            }
        } catch {
            print("❌ [TILES] Failed to load tiles in bounds: \(error)")
            // Don't clear tiles on error - keep showing cached
        }
    }
    
    /// Check if any tiles have ownership changes
    private func tilesHaveOwnershipChanges(old: [Tile], new: [Tile]) -> Bool {
        let oldMap = Dictionary(uniqueKeysWithValues: old.map { ($0.id, $0.ownerId) })
        for tile in new {
            if oldMap[tile.id] != tile.ownerId {
                return true
            }
        }
        return false
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
        print("🎯 [TERRITORY] finalizeTerritoryCapture called")
        print("🎯 [TERRITORY] Activity: \(activity.rawValue)")
        print("🎯 [TERRITORY] Input coordinates count: \(routeCoordinates.count)")
        
        guard eligibleActivities.contains(activity) else {
            print("❌ [TERRITORY] Activity not eligible: \(activity.rawValue)")
            return
        }
        guard routeCoordinates.count >= 3 else {
            print("❌ [TERRITORY] Not enough coordinates: \(routeCoordinates.count)")
            return
        }
        
        // Close the polygon properly
        let closed = ensureClosedLoop(routeCoordinates)
        print("🎯 [TERRITORY] After closing loop: \(closed.count) points")
        
        // Less aggressive simplification - keep more detail
        let simplified = simplifyPolygon(closed, tolerance: 0.00002)
        print("🎯 [TERRITORY] After simplification: \(simplified.count) points")
        
        // Use convex hull only for VERY complex routes to avoid self-intersection issues
        let finalCoordinates: [CLLocationCoordinate2D]
        if simplified.count > 1000 {
            finalCoordinates = convexHull(simplified)
            print("🎯 [TERRITORY] Used convex hull: \(finalCoordinates.count) points")
        } else {
            finalCoordinates = simplified
        }
        
        // Ensure polygon is closed
        let validPolygon = ensureClosedLoop(finalCoordinates)
        print("🎯 [TERRITORY] Final polygon: \(validPolygon.count) points")
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
        
        // Spara lokalt och visa i session-UI tills servern svarar
        // Vi sparar INTE till 'territories' för att undvika overlap i kartan. Grid är sanningen.
        // saveLocalTerritory(pendingTerritory)
        
        DispatchQueue.main.async {
            // Endast för session-feedback, sparas ej permanent
            self.activeSessionTerritories = [pendingTerritory]
            // Vi lägger INTE till i main 'territories' längre
            self.pendingCelebrationTerritory = pendingTerritory
        }
        
        // Save to backend (non-blocking) using tile-based claim
        Task {
            do {
                print("🎯 [TERRITORY] Starting tile claim for user: \(userId)")
                print("🎯 [TERRITORY] Polygon points: \(validPolygon.count)")
                print("🎯 [TERRITORY] Area: \(area) m²")
                print("🎯 [TERRITORY] Distance: \(sessionDistance ?? 0) km, Duration: \(sessionDuration ?? 0) sec")
                print("🎯 [TERRITORY] First coord: \(validPolygon.first?.latitude ?? 0), \(validPolygon.first?.longitude ?? 0)")
                print("🎯 [TERRITORY] Last coord: \(validPolygon.last?.latitude ?? 0), \(validPolygon.last?.longitude ?? 0)")
                
                // Use a generated activityId to tag the claim (not critical)
                let activityId = UUID()
                try await service.claimTiles(
                    ownerId: userId,
                    activityId: activityId,
                    coordinates: validPolygon,
                    distanceKm: sessionDistance,
                    durationSec: sessionDuration,
                    pace: sessionPace
                )
                
                print("✅ [TERRITORY] Tile claim RPC completed successfully!")
                
                // Set flag to force refresh tiles on next load
                await MainActor.run {
                    self.needsForceRefresh = true
                }
                
                // Save bounds BEFORE invalidating cache
                let savedBounds = self.lastTileBounds
                
                // Calculate fallback bounds from the claimed polygon
                let fallbackBounds: (minLat: Double, maxLat: Double, minLon: Double, maxLon: Double)? = {
                    guard !validPolygon.isEmpty else { return nil }
                    let lats = validPolygon.map { $0.latitude }
                    let lons = validPolygon.map { $0.longitude }
                    guard let minLat = lats.min(), let maxLat = lats.max(),
                          let minLon = lons.min(), let maxLon = lons.max() else { return nil }
                    // Expand by 0.05 degrees (~5km) to ensure ALL claimed tiles are loaded
                    return (minLat - 0.05, maxLat + 0.05, minLon - 0.05, maxLon + 0.05)
                }()
                
                // After successful claim, refresh from backend union view
                // Vi tar bort lokala placeholders
                await MainActor.run {
                    self.activeSessionTerritories.removeAll()
                    // pendingCelebrationTerritory rensas i UI när modalen stängs
                    self.invalidateCache()
                }
                
                print("🔄 Refreshing territories from server...")
                await self.refresh()
                print("   Territories count after refresh: \(self.territories.count)")
                
                // Also force refresh tiles to update local stats immediately
                // Use fallbackBounds from the claimed polygon (more accurate than savedBounds)
                let boundsToUse = fallbackBounds ?? savedBounds
                if let bounds = boundsToUse {
                    print("🔄 Refreshing tiles in bounds: \(bounds)...")
                    // Force refresh to bypass any caching
                    await self.loadTilesInBounds(
                        minLat: bounds.minLat,
                        maxLat: bounds.maxLat,
                        minLon: bounds.minLon,
                        maxLon: bounds.maxLon,
                        forceRefresh: true
                    )
                    print("   Tiles count after refresh: \(self.tiles.count)")
                } else {
                    print("⚠️ No bounds available for tile refresh")
                }
                
                print("🎉 Territory capture complete!")
                
            } catch {
                print("❌ [TERRITORY] Tile claim failed: \(error)")
                print("❌ [TERRITORY] Error details: \(String(describing: error))")
                // Keep local territory as fallback? No, grid is truth.
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
        // Disabling local loading to enforce server-side truth
        // territories = loadLocalTerritoriesSync()
        // print("🌍 TerritoryStore: Loaded \(territories.count) territories from local storage")
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
    var tileCount: Int? // Number of tiles in this territory
}

struct Tile: Identifiable, Equatable {
    let id: Int64
    let ownerId: String?
    let activityId: String?
    let distanceKm: Double?
    let durationSec: Int?
    let pace: String?
    let coordinates: [CLLocationCoordinate2D]
    let lastUpdatedAt: String?
    
    static func == (lhs: Tile, rhs: Tile) -> Bool {
        return lhs.id == rhs.id &&
               lhs.ownerId == rhs.ownerId &&
               lhs.activityId == rhs.activityId &&
               lhs.lastUpdatedAt == rhs.lastUpdatedAt
    }
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
