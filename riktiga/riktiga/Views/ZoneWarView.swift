import SwiftUI
import MapKit
import CoreLocation
import Supabase

struct ZoneWarView: View {
    @ObservedObject private var territoryStore = TerritoryStore.shared
    @State private var isLoading = false
    @State private var selectedTerritory: Territory?
    @State private var showTerritoryDetail = false
    @State private var showLeaderboard = false
    
    // Area tracking
    @State private var currentAreaName: String = "Området"
    @State private var areaLeader: TerritoryLeader?
    @State private var allLeaders: [TerritoryLeader] = []
    @State private var visibleMapRect: MKMapRect = MKMapRect.world
    
    // Cache for profiles
    private static var cachedLeaders: [TerritoryLeader] = []
    private static var lastCacheTime: Date = .distantPast
    private static let cacheValidityDuration: TimeInterval = 300 // 5 minutes
    
    var body: some View {
        NavigationStack {
            ZStack {
                ZoneWarMapView(
                    territories: territoryStore.territories,
                    onTerritoryTapped: { territory in
                        selectedTerritory = territory
                        showTerritoryDetail = true
                    },
                    onRegionChanged: { region, mapRect in
                        visibleMapRect = mapRect
                        updateAreaName(for: region.center)
                        updateLeaderForVisibleArea(mapRect: mapRect)
                    }
                )
                // Don't use ignoresSafeArea to keep tab bar visible
                
                if isLoading {
                    ProgressView()
                        .scaleEffect(1.5)
                        .padding()
                        .background(.ultraThinMaterial)
                        .cornerRadius(10)
                }
            }
            .task {
                // Show cached data immediately if available
                if !Self.cachedLeaders.isEmpty {
                    allLeaders = Self.cachedLeaders
                    if let first = Self.cachedLeaders.first {
                        areaLeader = first
                    }
                }
                
                isLoading = Self.cachedLeaders.isEmpty
                
                // First sync any local territories to backend
                await territoryStore.syncLocalTerritoriesToBackend()
                
                // Then refresh to get all territories
                await territoryStore.refresh()
                await loadAllLeaders()
                isLoading = false
            }
            .refreshable {
                // Sync local territories first, then refresh
                await territoryStore.syncLocalTerritoriesToBackend()
                await territoryStore.refresh()
                await loadAllLeaders()
            }
            .overlay(alignment: .top) {
                kingOfAreaHeader
            }
            .sheet(isPresented: $showTerritoryDetail) {
                if let territory = selectedTerritory {
                    TerritoryDetailView(territory: territory)
                        .presentationDetents([.medium, .large])
                }
            }
            .sheet(isPresented: $showLeaderboard) {
                NavigationStack {
                    ZoneWarLeaderboardView(areaName: currentAreaName, leaders: allLeaders)
                        .toolbar {
                            ToolbarItem(placement: .topBarTrailing) {
                                Button("Stäng") {
                                    showLeaderboard = false
                                }
                                .foregroundColor(.white)
                            }
                        }
                        .toolbarBackground(Color(red: 0.4, green: 0.35, blue: 0.2), for: .navigationBar)
                        .toolbarBackground(.visible, for: .navigationBar)
                }
                .presentationDetents([.large])
            }
        }
    }
    
    // MARK: - King of Area Header
    
    private var kingOfAreaHeader: some View {
        Button {
            showLeaderboard = true
        } label: {
            VStack(spacing: 4) {
                // Leader info
                if let leader = areaLeader {
                    HStack(spacing: 10) {
                        // Profile image
                        ProfileImage(url: leader.avatarUrl, size: 36)
                        
                        // Name and area
                        VStack(alignment: .leading, spacing: 2) {
                            Text(leader.name)
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                            
                            HStack(spacing: 4) {
                                Text("👑")
                                    .font(.caption)
                                Text("KING OF THE AREA")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(.yellow)
                                Text("👑")
                                    .font(.caption)
                            }
                        }
                        
                        Spacer()
                        
                        // Total area
                        Text(formatArea(leader.totalArea))
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(.white)
                    }
                } else {
                    // No leader yet
                    HStack {
                        Image(systemName: "crown.fill")
                            .foregroundColor(.yellow)
                        Text("Ingen kung än")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white)
                        Spacer()
                    }
                }
                
                // Area name subtitle
                Text("Kungen av \(currentAreaName)")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.8))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.black.opacity(0.85))
            )
            .padding(.horizontal, 16)
            .padding(.top, 8)
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Helper Functions
    
    private func formatArea(_ area: Double) -> String {
        let km2 = area / 1_000_000
        if km2 >= 10 {
            return String(format: "%.1fkm²", km2)
        } else if km2 >= 0.01 {
            return String(format: "%.2fkm²", km2)
        } else {
            return String(format: "%.0fm²", area)
        }
    }
    
    private func updateAreaName(for coordinate: CLLocationCoordinate2D) {
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        let geocoder = CLGeocoder()
        
        geocoder.reverseGeocodeLocation(location) { placemarks, error in
            if let placemark = placemarks?.first {
                // Try to get the most specific area name
                let areaName = placemark.subLocality 
                    ?? placemark.locality 
                    ?? placemark.subAdministrativeArea
                    ?? placemark.administrativeArea
                    ?? "Området"
                
                DispatchQueue.main.async {
                    self.currentAreaName = areaName
                }
            }
        }
    }
    
    private func updateLeaderForVisibleArea(mapRect: MKMapRect) {
        // Calculate which territories are visible and sum up area per owner
        var ownerVisibleAreas: [String: Double] = [:]
        
        for territory in territoryStore.territories {
            // Check if territory intersects with visible rect
            for polygon in territory.polygons {
                guard polygon.count >= 3 else { continue }
                
                let mkPolygon = MKPolygon(coordinates: polygon, count: polygon.count)
                if mapRect.intersects(mkPolygon.boundingMapRect) {
                    ownerVisibleAreas[territory.ownerId, default: 0] += territory.area
                    break // Count each territory only once per owner
                }
            }
        }
        
        // Find the leader (most visible area)
        if let topOwner = ownerVisibleAreas.max(by: { $0.value < $1.value }) {
            // Find the leader in our cached list and use their TOTAL area (not just visible)
            if let leader = allLeaders.first(where: { $0.id == topOwner.key }) {
                DispatchQueue.main.async {
                    // Use the leader's total area from allLeaders, not just visible area
                    self.areaLeader = leader
                }
            }
        }
    }
    
    private func loadAllLeaders() async {
        // Check cache first
        let now = Date()
        if !Self.cachedLeaders.isEmpty && now.timeIntervalSince(Self.lastCacheTime) < Self.cacheValidityDuration {
            await MainActor.run {
                self.allLeaders = Self.cachedLeaders
                if let first = Self.cachedLeaders.first {
                    self.areaLeader = first
                }
            }
            return
        }
        
        // Group territories by owner and calculate total area
        var ownerAreas: [String: Double] = [:]
        
        for territory in territoryStore.territories {
            ownerAreas[territory.ownerId, default: 0] += territory.area
        }
        
        // Sort by area descending
        let sortedOwners = ownerAreas.sorted { $0.value > $1.value }
        
        // Fetch profile info for each owner
        var leaders: [TerritoryLeader] = []
        var avatarUrls: [URL] = []
        
        for (ownerId, area) in sortedOwners {
            do {
                let profile: TerritoryOwnerProfile = try await SupabaseConfig.supabase.database
                    .from("profiles")
                    .select("id, username, avatar_url, is_pro")
                    .eq("id", value: ownerId)
                    .single()
                    .execute()
                    .value
                
                leaders.append(TerritoryLeader(
                    id: profile.id,
                    name: profile.name,
                    avatarUrl: profile.avatarUrl,
                    totalArea: area,
                    isPro: profile.isPro ?? false
                ))
                
                // Collect avatar URLs for prefetching
                if let avatarUrl = profile.avatarUrl, let url = URL(string: avatarUrl) {
                    avatarUrls.append(url)
                }
            } catch {
                // Add with placeholder name if profile fetch fails
                leaders.append(TerritoryLeader(
                    id: ownerId,
                    name: "Okänd",
                    avatarUrl: nil,
                    totalArea: area,
                    isPro: false
                ))
            }
        }
        
        // Prefetch all avatar images
        ImageCacheManager.shared.prefetch(urls: avatarUrls.map { $0.absoluteString })
        
        // Update cache
        Self.cachedLeaders = leaders
        Self.lastCacheTime = now
        
        await MainActor.run {
            self.allLeaders = leaders
            // Set initial leader
            if let first = leaders.first {
                self.areaLeader = first
            }
        }
    }
}

// Profile model for territory owner
struct TerritoryOwnerProfile: Decodable {
    let id: String
    let username: String?
    let avatarUrl: String?
    let isPro: Bool?
    
    enum CodingKeys: String, CodingKey {
        case id
        case username
        case avatarUrl = "avatar_url"
        case isPro = "is_pro"
    }
    
    var name: String {
        username ?? "Okänd användare"
    }
}

struct ZoneWarMapView: UIViewRepresentable {
    let territories: [Territory]
    let onTerritoryTapped: (Territory) -> Void
    let onRegionChanged: (MKCoordinateRegion, MKMapRect) -> Void
    
    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.showsUserLocation = true
        mapView.pointOfInterestFilter = .excludingAll
        mapView.mapType = .mutedStandard
        
        // Add tap gesture recognizer
        let tapGesture = UITapGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleTap(_:))
        )
        mapView.addGestureRecognizer(tapGesture)
        
        return mapView
    }
    
    func updateUIView(_ uiView: MKMapView, context: Context) {
        context.coordinator.territories = territories
        context.coordinator.onTerritoryTapped = onTerritoryTapped
        context.coordinator.onRegionChanged = onRegionChanged
        
        DispatchQueue.main.async {
            context.coordinator.updateMap(uiView, with: self.territories)
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(
            territories: territories,
            onTerritoryTapped: onTerritoryTapped,
            onRegionChanged: onRegionChanged
        )
    }
    
    final class Coordinator: NSObject, MKMapViewDelegate {
        var territories: [Territory]
        var onTerritoryTapped: (Territory) -> Void
        var onRegionChanged: (MKCoordinateRegion, MKMapRect) -> Void
        private var hasCentered = false
        private var currentTerritoryIds: Set<UUID> = []
        private var polygonToTerritory: [MKPolygon: Territory] = [:]
        
        init(
            territories: [Territory],
            onTerritoryTapped: @escaping (Territory) -> Void,
            onRegionChanged: @escaping (MKCoordinateRegion, MKMapRect) -> Void
        ) {
            self.territories = territories
            self.onTerritoryTapped = onTerritoryTapped
            self.onRegionChanged = onRegionChanged
        }
        
        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            guard let mapView = gesture.view as? MKMapView else { return }
            
            let tapPoint = gesture.location(in: mapView)
            let tapCoordinate = mapView.convert(tapPoint, toCoordinateFrom: mapView)
            
            for overlay in mapView.overlays {
                guard let polygon = overlay as? MKPolygon else { continue }
                
                let renderer = MKPolygonRenderer(polygon: polygon)
                let mapPoint = MKMapPoint(tapCoordinate)
                let polygonViewPoint = renderer.point(for: mapPoint)
                
                if renderer.path?.contains(polygonViewPoint) == true {
                    if let territory = polygonToTerritory[polygon] {
                        onTerritoryTapped(territory)
                        return
                    }
                }
            }
        }
        
        func updateMap(_ mapView: MKMapView, with territories: [Territory]) {
            print("🗺️ ========== MAP UPDATE ==========")
            print("🗺️ updateMap called with \(territories.count) territories")
            
            let newIds = Set(territories.map { $0.id })
            if newIds == currentTerritoryIds {
                print("🗺️ Territory IDs unchanged, skipping update")
                return
            }
            
            print("🗺️ Updating map with new territories...")
            currentTerritoryIds = newIds
            
            mapView.removeOverlays(mapView.overlays)
            polygonToTerritory.removeAll()
            
            var allPolygons: [MKPolygon] = []
            
            for (index, territory) in territories.enumerated() {
                print("🗺️ Territory \(index + 1): owner=\(territory.ownerId.prefix(8))..., polygons=\(territory.polygons.count)")
                
                for (ringIndex, ring) in territory.polygons.enumerated() {
                    guard ring.count >= 3 else {
                        print("⚠️   Ring \(ringIndex) has only \(ring.count) coords, skipping")
                        continue
                    }
                    
                    var coordinates = ring
                    if let first = coordinates.first, let last = coordinates.last {
                        if first.latitude != last.latitude || first.longitude != last.longitude {
                            coordinates.append(first)
                        }
                    }
                    
                    let polygon = MKPolygon(coordinates: coordinates, count: coordinates.count)
                    polygon.title = territory.activity?.rawValue
                    polygonToTerritory[polygon] = territory
                    allPolygons.append(polygon)
                    print("✅   Created polygon with \(coordinates.count) points for owner \(territory.ownerId.prefix(8))...")
                }
            }
            
            print("🗺️ Adding \(allPolygons.count) total polygons to map")
            mapView.addOverlays(allPolygons)
            print("🗺️ ========== MAP UPDATE COMPLETE ==========")
            
            if !hasCentered {
                if let firstPolygon = allPolygons.first {
                    let rect = firstPolygon.boundingMapRect
                    let expandedRect = rect.insetBy(dx: -rect.size.width * 0.5, dy: -rect.size.height * 0.5)
                    mapView.setVisibleMapRect(
                        expandedRect,
                        edgePadding: UIEdgeInsets(top: 120, left: 60, bottom: 120, right: 60),
                        animated: true
                    )
                } else {
                    let stockholm = MKCoordinateRegion(
                        center: CLLocationCoordinate2D(latitude: 59.3293, longitude: 18.0686),
                        span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
                    )
                    mapView.setRegion(stockholm, animated: false)
                }
                hasCentered = true
                
                // Trigger initial region callback
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self.onRegionChanged(mapView.region, mapView.visibleMapRect)
                }
            }
        }
        
        func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
            onRegionChanged(mapView.region, mapView.visibleMapRect)
        }
        
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            guard let polygon = overlay as? MKPolygon else {
                return MKOverlayRenderer(overlay: overlay)
            }
            
            let renderer = MKPolygonRenderer(polygon: polygon)
            let color = polygon.activityColor
            
            renderer.fillColor = color.withAlphaComponent(0.35)
            renderer.strokeColor = color
            renderer.lineWidth = 2
            
            return renderer
        }
    }
}
