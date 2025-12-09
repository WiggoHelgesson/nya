import SwiftUI
import MapKit
import CoreLocation
import Supabase

// MARK: - Territory Event Models

struct TerritoryEventRow: Decodable {
    let id: UUID
    let territory_id: UUID
    let actor_id: String
    let event_type: String
    let metadata: String?
    let created_at: Date?
}

struct ProfileInfo: Decodable {
    let id: String
    let username: String?
    let avatar_url: String?
}

struct TerritoryEvent: Identifiable {
    let id: UUID
    let type: TerritoryEventType
    let actorId: String
    let actorName: String
    let actorAvatarUrl: String?
    let territoryId: UUID
    let areaName: String
    let timestamp: Date
    
    enum TerritoryEventType {
        case takeover
        case newClaim
    }
}

struct ZoneWarView: View {
    @ObservedObject private var territoryStore = TerritoryStore.shared
    @State private var isLoading = false
    @State private var selectedTerritory: Territory?
    @State private var showLeaderboard = false
    
    // Area tracking
    @State private var currentAreaName: String = "Området"
    @State private var areaLeader: TerritoryLeader?
    @State private var allLeaders: [TerritoryLeader] = []
    @State private var visibleMapRect: MKMapRect = MKMapRect.world
    
    // Bottom menu
    @State private var showBottomMenu = false
    @State private var selectedMenuTab: Int = 0 // 0 = Topplista, 1 = Events
    @State private var territoryEvents: [TerritoryEvent] = []
    
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
                    },
                    onRegionChanged: { region, mapRect in
                        visibleMapRect = mapRect
                        updateAreaName(for: region.center)
                        updateLeaderForVisibleArea(mapRect: mapRect)
                        
                        // Viewport-based loading with debounce
                        let minLat = region.center.latitude - region.span.latitudeDelta / 2
                        let maxLat = region.center.latitude + region.span.latitudeDelta / 2
                        let minLon = region.center.longitude - region.span.longitudeDelta / 2
                        let maxLon = region.center.longitude + region.span.longitudeDelta / 2
                        
                        territoryStore.refreshForViewport(
                            minLat: minLat,
                            maxLat: maxLat,
                            minLon: minLon,
                            maxLon: maxLon
                        )
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
                
                // Bottom menu bar
                VStack {
                    Spacer()
                    bottomMenuBar
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
                await loadTerritoryEvents()
                isLoading = false
            }
            .refreshable {
                // Sync local territories first, then refresh
                await territoryStore.syncLocalTerritoriesToBackend()
                await territoryStore.refresh()
                await loadAllLeaders()
                await loadTerritoryEvents()
            }
            .overlay(alignment: .top) {
                kingOfAreaHeader
            }
            .sheet(item: $selectedTerritory) { territory in
                TerritoryDetailView(territory: territory)
                    .presentationDetents([.medium, .large])
            }
            .sheet(isPresented: $showLeaderboard) {
                ZoneWarMenuView(
                    selectedTab: $selectedMenuTab,
                    leaders: allLeaders,
                    events: territoryEvents,
                    areaName: currentAreaName
                )
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .onAppear {
                    selectedMenuTab = 0 // Start on leaderboard when opening from header
                }
            }
            .sheet(isPresented: $showBottomMenu) {
                ZoneWarMenuView(
                    selectedTab: $selectedMenuTab,
                    leaders: allLeaders,
                    events: territoryEvents,
                    areaName: currentAreaName
                )
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
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
    
    // MARK: - Bottom Menu Bar
    
    private var bottomMenuBar: some View {
        HStack(spacing: 16) {
            // Topplista button
            Button {
                selectedMenuTab = 0
                showBottomMenu = true
            } label: {
                Text("Topplista")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(selectedMenuTab == 0 ? .white : .gray)
            }
            
            // Events button
            Button {
                selectedMenuTab = 1
                showBottomMenu = true
            } label: {
                HStack(spacing: 4) {
                    Text("Events")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(selectedMenuTab == 1 ? .white : .gray)
                    
                    // Show badge if there are events
                    if !territoryEvents.isEmpty {
                        Text("\(territoryEvents.count)")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.black)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(Color.red)
                            .clipShape(Capsule())
                    }
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(
            Capsule()
                .fill(Color(red: 0.15, green: 0.15, blue: 0.17))
        )
        .padding(.horizontal, 100)
        .padding(.bottom, 60) // Above tab bar
    }
    
    private func rankColor(for rank: Int) -> Color {
        switch rank {
        case 1: return Color.yellow
        case 2: return Color.gray.opacity(0.8)
        case 3: return Color(red: 0.8, green: 0.5, blue: 0.2)
        default: return Color.gray.opacity(0.3)
        }
    }
    
    private func timeAgo(from date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        
        if interval < 60 {
            return "Just nu"
        } else if interval < 3600 {
            let minutes = Int(interval / 60)
            return "\(minutes) min sedan"
        } else if interval < 86400 {
            let hours = Int(interval / 3600)
            return "\(hours) tim sedan"
        } else {
            let days = Int(interval / 86400)
            return "\(days) dagar sedan"
        }
    }
    
    private func loadTerritoryEvents() async {
        guard let currentUserId = AuthViewModel.shared.currentUser?.id else { return }
        
        do {
            // Fetch territory events where the current user's territory was taken over
            let response: [TerritoryEventRow] = try await SupabaseConfig.supabase
                .from("territory_events")
                .select("id, territory_id, actor_id, event_type, metadata, created_at")
                .eq("event_type", value: "claim")
                .order("created_at", ascending: false)
                .limit(50)
                .execute()
                .value
            
            var events: [TerritoryEvent] = []
            
            // Get unique actor IDs to fetch profiles
            let actorIds = Set(response.map { $0.actor_id })
            var profilesMap: [String: (name: String, avatarUrl: String?)] = [:]
            
            // Fetch profiles for all actors
            for actorId in actorIds {
                if let profile: ProfileInfo = try? await SupabaseConfig.supabase
                    .from("profiles")
                    .select("id, username, avatar_url")
                    .eq("id", value: actorId)
                    .limit(1)
                    .single()
                    .execute()
                    .value {
                    profilesMap[actorId] = (profile.username ?? "Okänd", profile.avatar_url)
                }
            }
            
            for item in response {
                // Parse metadata JSON
                var areaName = "Okänt område"
                var previousOwnerId: String? = nil
                
                if let metadataData = item.metadata?.data(using: .utf8),
                   let metadata = try? JSONSerialization.jsonObject(with: metadataData) as? [String: Any] {
                    areaName = metadata["area_name"] as? String ?? "Okänt område"
                    previousOwnerId = metadata["previous_owner_id"] as? String
                }
                
                // Check if this was a takeover of current user's territory
                let isMyTerritoryTakeover = previousOwnerId == currentUserId && item.actor_id != currentUserId
                
                if isMyTerritoryTakeover {
                    let profile = profilesMap[item.actor_id]
                    events.append(TerritoryEvent(
                        id: item.id,
                        type: .takeover,
                        actorId: item.actor_id,
                        actorName: profile?.name ?? "Okänd",
                        actorAvatarUrl: profile?.avatarUrl,
                        territoryId: item.territory_id,
                        areaName: areaName,
                        timestamp: item.created_at ?? Date()
                    ))
                }
            }
            
            await MainActor.run {
                self.territoryEvents = events
            }
        } catch {
            print("❌ Error loading territory events: \(error)")
        }
    }
    
    // MARK: - Helper Functions
    
    private func formatArea(_ area: Double) -> String {
        // Always display in km² for consistency
        let km2 = area / 1_000_000
        
        if km2 >= 100 {
            return String(format: "%.0f km²", km2)
        } else if km2 >= 10 {
            return String(format: "%.1f km²", km2)
        } else if km2 >= 1 {
            return String(format: "%.2f km²", km2)
        } else if km2 >= 0.001 {
            return String(format: "%.4f km²", km2)
        } else {
            return String(format: "%.6f km²", km2)
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
        
        // Ensure valid session first
        do {
            try await AuthSessionManager.shared.ensureValidSession()
        } catch {
            print("❌ Failed to ensure valid session for leaders: \(error)")
        }
        
        // Group territories by owner and calculate total area
        var ownerAreas: [String: Double] = [:]
        
        for territory in territoryStore.territories {
            ownerAreas[territory.ownerId, default: 0] += territory.area
        }
        
        print("👑 Loading leaders for \(ownerAreas.count) unique owners")
        
        // Sort by area descending
        let sortedOwners = ownerAreas.sorted { $0.value > $1.value }
        
        // Fetch ALL profiles in one query for better performance
        let ownerIds = sortedOwners.map { $0.key }
        var profilesMap: [String: TerritoryOwnerProfile] = [:]
        
        do {
            let profiles: [TerritoryOwnerProfile] = try await SupabaseConfig.supabase
                .from("profiles")
                .select("id, username, avatar_url, is_pro")
                .in("id", values: ownerIds)
                .execute()
                .value
            
            print("Fetched \(profiles.count) profiles for \(ownerIds.count) owners")
            
            for profile in profiles {
                profilesMap[profile.id] = profile
            }
        } catch {
            print("Failed to fetch profiles in batch: \(error)")
        }
        
        // Fallback: fetch any missing profiles in smaller chunks to avoid showing \"Okänd\"
        let missingIds = ownerIds.filter { profilesMap[$0] == nil }
        if !missingIds.isEmpty {
            for chunk in missingIds.chunked(into: 25) {
                do {
                    let extra: [TerritoryOwnerProfile] = try await SupabaseConfig.supabase
                        .from("profiles")
                        .select("id, username, avatar_url, is_pro")
                        .in("id", values: chunk)
                        .execute()
                        .value
                    for profile in extra {
                        profilesMap[profile.id] = profile
                    }
                } catch {
                    print("Fallback profile fetch failed for chunk \(chunk.count): \(error)")
                }
            }
        }
        
        // Build leaders list
        var leaders: [TerritoryLeader] = []
        var avatarUrls: [URL] = []
        
        for (ownerId, area) in sortedOwners {
            if let profile = profilesMap[ownerId] {
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
            } else {
                print("⚠️ No profile found for owner: \(ownerId)")
                // Add with placeholder name if profile not found
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
        
        print("👑 Leaders loaded: \(leaders.count) total, \(leaders.filter { $0.name != "Okänd" }.count) with profiles")
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

// MARK: - Territory Colors
enum TerritoryColors {
    static let colors: [UIColor] = [
        UIColor(red: 0.2, green: 0.6, blue: 0.9, alpha: 1),   // Blue
        UIColor(red: 0.9, green: 0.3, blue: 0.3, alpha: 1),   // Red
        UIColor(red: 0.3, green: 0.8, blue: 0.4, alpha: 1),   // Green
        UIColor(red: 0.95, green: 0.6, blue: 0.1, alpha: 1),  // Orange
        UIColor(red: 0.6, green: 0.3, blue: 0.8, alpha: 1),   // Purple
    ]
    
    static func colorForUser(_ ownerId: String) -> UIColor {
        // Generate consistent color based on owner ID hash
        let hash = abs(ownerId.hashValue)
        let index = hash % colors.count
        return colors[index]
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
        
        // Throttling for region changes
        private var lastRegionChangeTime: Date = .distantPast
        private let regionChangeThrottleInterval: TimeInterval = 0.5 // 500ms throttle
        private var pendingRegionChange: DispatchWorkItem?
        
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
            // Quick check to avoid unnecessary updates
            let newIds = Set(territories.map { $0.id })
            if newIds == currentTerritoryIds {
                return
            }
            
            currentTerritoryIds = newIds
            
            // Remove old overlays efficiently
            let existingOverlays = mapView.overlays
            if !existingOverlays.isEmpty {
                mapView.removeOverlays(existingOverlays)
            }
            polygonToTerritory.removeAll(keepingCapacity: true)
            
            // Pre-allocate array
            var allPolygons: [MKPolygon] = []
            allPolygons.reserveCapacity(territories.count * 2)
            
            for territory in territories {
                
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
                    polygon.title = territory.ownerId
                    polygonToTerritory[polygon] = territory
                    allPolygons.append(polygon)
                }
            }
            
            // Add all overlays at once for better performance
            if !allPolygons.isEmpty {
                mapView.addOverlays(allPolygons)
            }
            
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
            // Throttle region change callbacks to reduce lag
            pendingRegionChange?.cancel()
            
            let now = Date()
            let timeSinceLastChange = now.timeIntervalSince(lastRegionChangeTime)
            
            if timeSinceLastChange >= regionChangeThrottleInterval {
                // Enough time has passed, call immediately
                lastRegionChangeTime = now
                onRegionChanged(mapView.region, mapView.visibleMapRect)
            } else {
                // Schedule for later
                let workItem = DispatchWorkItem { [weak self] in
                    self?.lastRegionChangeTime = Date()
                    self?.onRegionChanged(mapView.region, mapView.visibleMapRect)
                }
                pendingRegionChange = workItem
                DispatchQueue.main.asyncAfter(
                    deadline: .now() + (regionChangeThrottleInterval - timeSinceLastChange),
                    execute: workItem
                )
            }
        }
        
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            guard let polygon = overlay as? MKPolygon else {
                return MKOverlayRenderer(overlay: overlay)
            }
            
            let renderer = MKPolygonRenderer(polygon: polygon)
            
            // Get color based on owner ID stored in title
            let ownerId = polygon.title ?? ""
            let color = TerritoryColors.colorForUser(ownerId)
            
            renderer.fillColor = color.withAlphaComponent(0.4)
            renderer.strokeColor = color
            renderer.lineWidth = 2.5
            
            return renderer
        }
    }
}

// MARK: - Zone War Menu View (Full Page)

struct ZoneWarMenuView: View {
    @Binding var selectedTab: Int
    let leaders: [TerritoryLeader]
    let events: [TerritoryEvent]
    let areaName: String
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Tab selector
                HStack(spacing: 0) {
                    ForEach(["Topplista", "Events"], id: \.self) { tab in
                        let index = tab == "Topplista" ? 0 : 1
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                selectedTab = index
                            }
                        } label: {
                            VStack(spacing: 8) {
                                HStack(spacing: 6) {
                                    Image(systemName: index == 0 ? "trophy.fill" : "bell.fill")
                                        .font(.system(size: 14))
                                    Text(tab)
                                        .font(.system(size: 16, weight: .semibold))
                                    
                                    // Badge for events
                                    if index == 1 && !events.isEmpty {
                                        Text("\(events.count)")
                                            .font(.system(size: 11, weight: .bold))
                                            .foregroundColor(.black)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(Color.yellow)
                                            .clipShape(Capsule())
                                    }
                                }
                                .foregroundColor(selectedTab == index ? .white : .gray)
                                
                                // Underline
                                Rectangle()
                                    .fill(selectedTab == index ? Color.yellow : Color.clear)
                                    .frame(height: 3)
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .padding(.top, 8)
                .background(Color(red: 0.12, green: 0.12, blue: 0.14))
                
                // Content
                if selectedTab == 0 {
                    leaderboardView
                } else {
                    eventsView
                }
            }
            .background(Color(red: 0.12, green: 0.12, blue: 0.14))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text(selectedTab == 0 ? "Topplista - \(areaName)" : "Events")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundStyle(.gray, Color(red: 0.2, green: 0.2, blue: 0.22))
                    }
                }
            }
            .toolbarBackground(Color(red: 0.12, green: 0.12, blue: 0.14), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
    }
    
    // MARK: - Leaderboard View
    
    private var leaderboardView: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(Array(leaders.sorted { $0.totalArea > $1.totalArea }.enumerated()), id: \.element.id) { index, leader in
                    HStack(spacing: 14) {
                        // Rank badge
                        ZStack {
                            Circle()
                                .fill(rankColor(for: index + 1))
                                .frame(width: 36, height: 36)
                            Text("\(index + 1)")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(index < 3 ? .black : .white)
                        }
                        
                        // Profile image
                        ProfileImage(url: leader.avatarUrl, size: 48)
                        
                        // Name
                        VStack(alignment: .leading, spacing: 2) {
                            Text(leader.name)
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                                .lineLimit(1)
                            
                            if index == 0 {
                                HStack(spacing: 4) {
                                    Text("👑")
                                        .font(.system(size: 10))
                                    Text("KUNG AV OMRÅDET")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundColor(.yellow)
                                }
                            }
                        }
                        
                        Spacer()
                        
                        // Area
                        Text(formatArea(leader.totalArea))
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(.gray)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .background(index == 0 ? Color.yellow.opacity(0.1) : Color.clear)
                    
                    if index < leaders.count - 1 {
                        Divider()
                            .background(Color.gray.opacity(0.2))
                            .padding(.leading, 66)
                    }
                }
                
                if leaders.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "trophy")
                            .font(.system(size: 48))
                            .foregroundColor(.gray)
                        Text("Ingen topplista än")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                        Text("Var först med att erövra ett område!")
                            .font(.system(size: 14))
                            .foregroundColor(.gray)
                    }
                    .padding(.top, 60)
                }
            }
            .padding(.top, 8)
        }
    }
    
    // MARK: - Events View
    
    private var eventsView: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                if events.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "bell.slash.fill")
                            .font(.system(size: 48))
                            .foregroundColor(.gray)
                        Text("Inga händelser än")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                        Text("Här ser du när någon tar över dina områden")
                            .font(.system(size: 14))
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                    }
                    .padding(.top, 60)
                } else {
                    ForEach(events) { event in
                        HStack(spacing: 14) {
                            // Profile image with red overlay for takeover
                            ZStack(alignment: .bottomTrailing) {
                                ProfileImage(url: event.actorAvatarUrl, size: 48)
                                
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.system(size: 14))
                                    .foregroundColor(.red)
                                    .background(
                                        Circle()
                                            .fill(Color(red: 0.12, green: 0.12, blue: 0.14))
                                            .frame(width: 18, height: 18)
                                    )
                                    .offset(x: 4, y: 4)
                            }
                            
                            // Event info
                            VStack(alignment: .leading, spacing: 4) {
                                HStack(spacing: 4) {
                                    Text(event.actorName)
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundColor(.white)
                                    
                                    Text("tog över ditt område!")
                                        .font(.system(size: 15))
                                        .foregroundColor(.gray)
                                }
                                
                                HStack(spacing: 6) {
                                    Image(systemName: "mappin.circle.fill")
                                        .font(.system(size: 13))
                                        .foregroundColor(.red)
                                    Text(event.areaName)
                                        .font(.system(size: 13))
                                        .foregroundColor(.gray)
                                    
                                    Text("•")
                                        .foregroundColor(.gray.opacity(0.5))
                                    
                                    Text(timeAgo(from: event.timestamp))
                                        .font(.system(size: 13))
                                        .foregroundColor(.gray)
                                }
                            }
                            
                            Spacer()
                            
                            // Action button
                            Button {
                                // Could navigate to the territory
                            } label: {
                                Text("Visa")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(.black)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 8)
                                    .background(Color.yellow)
                                    .cornerRadius(16)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                        
                        Divider()
                            .background(Color.gray.opacity(0.2))
                            .padding(.leading, 78)
                    }
                }
            }
            .padding(.top, 8)
        }
    }
    
    // MARK: - Helpers
    
    private func rankColor(for rank: Int) -> Color {
        switch rank {
        case 1: return Color.yellow
        case 2: return Color(white: 0.75)
        case 3: return Color(red: 0.8, green: 0.5, blue: 0.2)
        default: return Color.gray.opacity(0.3)
        }
    }
    
    private func formatArea(_ area: Double) -> String {
        let km2 = area / 1_000_000
        if km2 >= 100 {
            return String(format: "%.0f km²", km2)
        } else if km2 >= 10 {
            return String(format: "%.1f km²", km2)
        } else if km2 >= 1 {
            return String(format: "%.2f km²", km2)
        } else if km2 >= 0.001 {
            return String(format: "%.4f km²", km2)
        } else {
            return String(format: "%.6f km²", km2)
        }
    }
    
    private func timeAgo(from date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        
        if interval < 60 {
            return "Just nu"
        } else if interval < 3600 {
            let minutes = Int(interval / 60)
            return "\(minutes) min sedan"
        } else if interval < 86400 {
            let hours = Int(interval / 3600)
            return "\(hours) tim sedan"
        } else {
            let days = Int(interval / 86400)
            return "\(days) dagar sedan"
        }
    }
}

// MARK: - Corner Radius Extension

extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners
    
    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}

// MARK: - Helpers
extension Array {
    /// Split an array into fixed-size chunks.
    func chunked(into size: Int) -> [[Element]] {
        guard size > 0 else { return [] }
        var result: [[Element]] = []
        var index = startIndex
        while index < endIndex {
            let nextIndex = self.index(index, offsetBy: size, limitedBy: endIndex) ?? endIndex
            result.append(Array(self[index..<nextIndex]))
            index = nextIndex
        }
        return result
    }
}
