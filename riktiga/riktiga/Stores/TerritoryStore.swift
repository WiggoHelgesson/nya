import SwiftUI
import MapKit
import CoreLocation
import Combine

final class TerritoryStore: ObservableObject {
    static let shared = TerritoryStore()
    
    @Published private(set) var territories: [Territory] = []
    @Published private(set) var activeSessionTerritories: [Territory] = []
    
    private let service = TerritoryService.shared
    private let eligibleActivities: Set<ActivityType> = [.running, .golf, .hiking, .skiing]
    private let localStorageKey = "LocalTerritories"
    
    init() {
        loadLocalTerritories()
    }
    
    func refresh() async {
        print("🌍 ========== TERRITORY REFRESH START ==========")
        print("🌍 TerritoryStore: Refreshing ALL territories from all users...")
        
        do {
            let remote = try await service.fetchTerritories()
            print("🌍 TerritoryStore: Fetched \(remote.count) territories from backend")
            
            // Debug: Print each territory
            for (index, feature) in remote.enumerated() {
                print("🔍 Territory \(index + 1): ID=\(feature.id), Owner=\(feature.owner_id.prefix(8))..., Activity=\(feature.activity_type), Area=\(Int(feature.area_m2))m²")
            }
            
            let mapped = remote.compactMap { $0.asTerritory() }
            print("🌍 TerritoryStore: Mapped to \(mapped.count) Territory objects")
            
            if mapped.count != remote.count {
                print("⚠️ WARNING: \(remote.count - mapped.count) territories failed to map!")
            }
            
            // Log unique owners
            let uniqueOwners = Set(mapped.map { $0.ownerId })
            print("🌍 TerritoryStore: Territories from \(uniqueOwners.count) different users")
            for owner in uniqueOwners {
                let count = mapped.filter { $0.ownerId == owner }.count
                print("   👤 Owner \(owner.prefix(8))...: \(count) territories")
            }
            
            await MainActor.run {
                var allTerritories = mapped
                
                let localTerritories = loadLocalTerritoriesSync()
                print("🌍 TerritoryStore: Local territories: \(localTerritories.count)")
                
                let remoteIds = Set(mapped.map { $0.id })
                let pendingLocal = localTerritories.filter { !remoteIds.contains($0.id) }
                
                if !pendingLocal.isEmpty {
                    print("🌍 TerritoryStore: Adding \(pendingLocal.count) pending local territories")
                    allTerritories.append(contentsOf: pendingLocal)
                }
                
                self.territories = allTerritories
                print("🌍 ✅ FINAL: \(self.territories.count) territories to display")
                print("🌍 ========== TERRITORY REFRESH END ==========")
            }
        } catch {
            print("❌ ========== TERRITORY REFRESH FAILED ==========")
            print("❌ Error: \(error)")
            print("❌ Error type: \(type(of: error))")
            
            await MainActor.run {
                let localTerritories = loadLocalTerritoriesSync()
                if !localTerritories.isEmpty && self.territories.isEmpty {
                    self.territories = localTerritories
                    print("🌍 Using \(localTerritories.count) local territories as fallback")
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
        print("🏁 TerritoryStore: finalizeTerritoryCapture")
        print("   - Activity: \(activity.rawValue)")
        print("   - Raw coordinates: \(routeCoordinates.count)")
        print("   - UserId: \(userId)")
        
        guard eligibleActivities.contains(activity) else {
            print("❌ Activity not eligible")
            return
        }
        guard routeCoordinates.count >= 3 else {
            print("❌ Not enough points: \(routeCoordinates.count)")
            return
        }
        
        // Step 1: Close the polygon properly
        var closed = ensureClosedLoop(routeCoordinates)
        print("   - After closing: \(closed.count) points")
        
        // Step 2: Simplify to reduce self-intersections
        let simplified = simplifyPolygon(closed, tolerance: 0.00005)
        print("   - After simplify: \(simplified.count) points")
        
        // Step 3: If still too complex, use convex hull as fallback
        let finalCoordinates: [CLLocationCoordinate2D]
        if simplified.count > 500 {
            finalCoordinates = convexHull(simplified)
            print("   - Used convex hull: \(finalCoordinates.count) points")
        } else {
            finalCoordinates = simplified
        }
        
        // Step 4: Ensure it's still closed after all operations
        let validPolygon = ensureClosedLoop(finalCoordinates)
        print("   - Final polygon: \(validPolygon.count) points")
        
        // Log first and last point to verify closure
        if let first = validPolygon.first, let last = validPolygon.last {
            print("   - First: (\(first.latitude), \(first.longitude))")
            print("   - Last: (\(last.latitude), \(last.longitude))")
            print("   - Closed: \(first.latitude == last.latitude && first.longitude == last.longitude)")
        }
        
        let area = calculateArea(coordinates: validPolygon)
        print("   - Calculated area: \(area) m²")
        
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
        
        // Save locally IMMEDIATELY
        saveLocalTerritory(pendingTerritory)
        print("💾 Saved territory locally")
        
        DispatchQueue.main.async {
            self.activeSessionTerritories = [pendingTerritory]
            if !self.territories.contains(where: { $0.id == pendingTerritory.id }) {
                self.territories.append(pendingTerritory)
            }
            print("✅ Added to territories array. Total: \(self.territories.count)")
        }
        
        // Try to save to backend (non-blocking)
        Task {
            do {
                print("🚀 ========== SENDING TO SUPABASE ==========")
                print("🚀 UserId: \(userId)")
                print("🚀 Activity: \(activity.rawValue)")
                print("🚀 Coordinates: \(validPolygon.count) points")
                print("🚀 First coord: \(validPolygon.first?.latitude ?? 0), \(validPolygon.first?.longitude ?? 0)")
                print("🚀 Last coord: \(validPolygon.last?.latitude ?? 0), \(validPolygon.last?.longitude ?? 0)")
                
                let feature = try await service.claimTerritory(
                    ownerId: userId,
                    activity: activity,
                    coordinates: validPolygon
                )
                print("✅ ========== BACKEND SAVE SUCCESS ==========")
                print("✅ Territory ID: \(feature.id)")
                print("✅ Area: \(feature.area_m2) m²")
                
                if let territory = feature.asTerritory() {
                    // Add session data to the territory from backend
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
                print("❌ ========== BACKEND SAVE FAILED ==========")
                print("❌ Error: \(error)")
                print("❌ Error type: \(type(of: error))")
                print("❌ Localized: \(error.localizedDescription)")
                if let nsError = error as NSError? {
                    print("❌ NSError domain: \(nsError.domain)")
                    print("❌ NSError code: \(nsError.code)")
                    print("❌ NSError userInfo: \(nsError.userInfo)")
                }
                print("⚠️ Territory kept locally only - will NOT be visible to other users!")
                print("❌ ==========================================")
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

