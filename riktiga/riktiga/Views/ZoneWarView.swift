import SwiftUI
import MapKit
import CoreLocation
import Supabase

// MARK: - Territory Event Models

// Params struct moved to nonisolated context
nonisolated(unsafe) struct TakeoverEventParams: Encodable {
    let p_user_id: String
    let p_limit: Int
}

struct TerritoryEventRow: Decodable {
    let id: UUID
    let territory_id: UUID
    let actor_id: String
    let event_type: String
    let metadata: [String: AnyCodable]?  // JSON object, not string
    let created_at: Date?
}

// Helper for decoding arbitrary JSON values
struct AnyCodable: Decodable {
    let value: Any
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let string = try? container.decode(String.self) {
            value = string
        } else if let int = try? container.decode(Int.self) {
            value = int
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else if let bool = try? container.decode(Bool.self) {
            value = bool
        } else {
            value = ""
        }
    }
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
    @State private var regionDebounceTask: DispatchWorkItem?
    @State private var localStatsDebounceTask: Task<Void, Never>?
    
    // Area tracking
    @State private var currentAreaName: String = "Området"
    @State private var areaLeader: TerritoryLeader?
    @State private var allLeaders: [TerritoryLeader] = []
    @State private var localLeaders: [TerritoryLeader] = [] // Calculated from visible tiles
    @State private var visibleMapRect: MKMapRect = MKMapRect.world
    
    // Bottom menu
    @State private var showBottomMenu = false
    @State private var selectedMenuTab: Int = 0 // 0 = Topplista, 1 = Events
    @State private var territoryEvents: [TerritoryEvent] = []
    
    // Prize list
    @State private var isPrizeListExpanded = false
    
    // Pro membership
    @State private var isPremium = RevenueCatManager.shared.isPremium
    @State private var showPaywall = false
    
    // New territory celebration
    @State private var showNewTerritoryCelebration = false
    @State private var celebrationTerritory: Territory?
    @State private var targetMapRegion: MKCoordinateRegion?
    
    // Lottery stats
    @State private var myLotteryTickets: Int = 0
    @State private var totalLotteryTickets: Int = 0
    @State private var isLotteryExpanded: Bool = false
    @State private var showLotteryInfoPopup: Bool = false
    @EnvironmentObject private var authViewModel: AuthViewModel
    
    // Cache for profiles
    private static var cachedLeaders: [TerritoryLeader] = []
    private static var lastCacheTime: Date = .distantPast
    private static let cacheValidityDuration: TimeInterval = 300 // 5 minutes
    
    // Cache for events
    private static var cachedEvents: [TerritoryEvent] = []
    private static var lastEventsCacheTime: Date = .distantPast
    
    // Geocoding throttle
    @State private var lastGeocodingTime: Date = .distantPast
    private let geocodingThrottle: TimeInterval = 2.0
    
    var body: some View {
        NavigationStack {
            ZStack {
                ZoneWarMapView(
                    territories: [], // Only use tiles for grid-based system
                    tiles: territoryStore.tiles,
                    onTerritoryTapped: { territory in
                        selectedTerritory = territory
                    },
                    onRegionChanged: { region, mapRect in
                        visibleMapRect = mapRect
                        updateAreaName(for: region.center)
                        // updateLeaderForVisibleArea(mapRect: mapRect) // Replaced by calculateLocalStats
                        
                        // Viewport-based loading with debounce to reduce churn on map moves
                        regionDebounceTask?.cancel()
                        let work = DispatchWorkItem { [center = region.center, span = region.span, mapRect] in
                            let minLat = center.latitude - span.latitudeDelta / 2
                            let maxLat = center.latitude + span.latitudeDelta / 2
                            let minLon = center.longitude - span.longitudeDelta / 2
                            let maxLon = center.longitude + span.longitudeDelta / 2
                            
                            territoryStore.refreshForViewport(
                                minLat: minLat,
                                maxLat: maxLat,
                                minLon: minLon,
                                maxLon: maxLon
                            )
                            
                            // Load tiles for current viewport (separate throttle inside)
                            let topLeft = MKMapPoint(x: mapRect.origin.x, y: mapRect.origin.y)
                            let bottomRight = MKMapPoint(x: mapRect.maxX, y: mapRect.maxY)
                            let minLonTiles = min(topLeft.coordinate.longitude, bottomRight.coordinate.longitude)
                            let maxLonTiles = max(topLeft.coordinate.longitude, bottomRight.coordinate.longitude)
                            let minLatTiles = min(topLeft.coordinate.latitude, bottomRight.coordinate.latitude)
                            let maxLatTiles = max(topLeft.coordinate.latitude, bottomRight.coordinate.latitude)
                            Task {
                                await territoryStore.loadTilesInBounds(
                                    minLat: minLatTiles,
                                    maxLat: maxLatTiles,
                                    minLon: minLonTiles,
                                    maxLon: maxLonTiles
                                )
                            }
                        }
                        regionDebounceTask = work
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8, execute: work) // Increased debounce to reduce flicker
                    },
                    targetRegion: $targetMapRegion
                )
                .ignoresSafeArea(edges: .top) // Map covers full screen including top
                
                if isLoading {
                    ProgressView()
                        .scaleEffect(1.5)
                        .padding()
                        .background(.ultraThinMaterial)
                        .cornerRadius(10)
                }
                
                // New territory celebration overlay
                if showNewTerritoryCelebration, let territory = celebrationTerritory {
                    NewTerritoryCelebrationView(
                        territory: territory,
                        onComplete: {
                            showNewTerritoryCelebration = false
                            celebrationTerritory = nil
                            territoryStore.pendingCelebrationTerritory = nil
                        },
                        onFocusMap: { region in
                            targetMapRegion = region
                        }
                    )
                    .transition(.opacity)
                    .zIndex(100)
                }
                
            }
            .task {
                // Check for pending territory celebration
                if let pendingTerritory = territoryStore.pendingCelebrationTerritory {
                    celebrationTerritory = pendingTerritory
                    // Slight delay to let the view appear first
                    try? await Task.sleep(nanoseconds: 300_000_000) // 0.3s
                    withAnimation {
                        showNewTerritoryCelebration = true
                    }
                }
                
                // Show cached data immediately if available (instant UI)
                if !Self.cachedLeaders.isEmpty {
                    allLeaders = Self.cachedLeaders
                }
                if !Self.cachedEvents.isEmpty {
                    territoryEvents = Self.cachedEvents
                }
                
                isLoading = Self.cachedLeaders.isEmpty
                
                // First sync any local territories to backend
                await territoryStore.syncLocalTerritoriesToBackend()
                
                // Then refresh and load data in parallel for faster loading
                await withTaskGroup(of: Void.self) { group in
                    group.addTask {
                        await self.territoryStore.refresh()
                    }
                    group.addTask {
                        await self.loadLotteryStats()
                    }
                    group.addTask {
                        await self.loadAllLeaders()
                    }
                    group.addTask {
                        await self.loadTerritoryEvents()
                    }
                }
                isLoading = false
            }
            .refreshable {
                // Force clear cache and refetch everything
                territoryStore.forceRefresh()
                await territoryStore.syncLocalTerritoriesToBackend()
                await territoryStore.refresh()
                await loadAllLeaders()
                await loadTerritoryEvents()
            }
            // Recalculate local stats whenever tiles update (heavily debounced to prevent lag)
            .onChange(of: territoryStore.tiles.count) { oldCount, newCount in
                // Only trigger if count changed significantly (more than 10%)
                let threshold = max(10, oldCount / 10)
                guard abs(newCount - oldCount) >= threshold || oldCount == 0 else { return }
                
                localStatsDebounceTask?.cancel()
                localStatsDebounceTask = Task {
                    try? await Task.sleep(nanoseconds: 800_000_000) // 800ms debounce
                    guard !Task.isCancelled else { return }
                    await MainActor.run { calculateLocalStats() }
                }
            }
            // Recalculate local stats whenever global leaders update (debounced)
            .onChange(of: allLeaders.count) { oldCount, newCount in
                // Only trigger if leader count changed
                guard oldCount != newCount else { return }
                localStatsDebounceTask?.cancel()
                localStatsDebounceTask = Task {
                    try? await Task.sleep(nanoseconds: 300_000_000) // 300ms debounce
                    guard !Task.isCancelled else { return }
                    await MainActor.run { calculateLocalStats() }
                }
            }
            // Floating refresh button that clears cache and reloads - bottom right
            .overlay(alignment: .bottomTrailing) {
                Button {
                    Task {
                        territoryStore.forceRefresh()
                        await territoryStore.refresh()
                        await loadAllLeaders()
                        await loadTerritoryEvents()
                        await loadLotteryStats()
                    }
                } label: {
                    Image(systemName: "arrow.clockwise.circle.fill")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)
                    .padding(12)
                    .background(Color.black.opacity(0.7))
                    .clipShape(Circle())
                    .shadow(radius: 6)
                }
                .padding(.trailing, 16)
                .padding(.bottom, 140) // Above tab bar and bottom menu
                .accessibilityLabel("Uppdatera kartan")
            }
            .overlay(alignment: .top) {
                VStack(spacing: 0) {
                    kingOfAreaHeader
                    
                    // Prizes box and Lottery - below king of area, aligned right
                    HStack {
                        Spacer()
                        VStack(spacing: 8) {
                            prizeListBox
                            
                            // Info button
                            Button {
                                showLotteryInfoPopup = true
                            } label: {
                                HStack(spacing: 6) {
                                    Text("Hur får jag lotter?")
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundColor(.white)
                                    Image(systemName: "questionmark.circle.fill")
                                        .font(.system(size: 12))
                                        .foregroundColor(.yellow)
                                }
                                .frame(width: 195)
                                .padding(.vertical, 8)
                                .background(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .fill(Color.black.opacity(0.85))
                                )
                            }
                            .buttonStyle(.plain)
                            
                            lotteryCard
                        }
                        .padding(.trailing, 12)
                    }
                    .padding(.top, 4)
                }
                .padding(.top, 4)
            }
            .overlay(alignment: .bottom) {
                bottomMenuBar
                    .padding(.bottom, 8)
            }
            .alert("Så får du lotter 🎰", isPresented: $showLotteryInfoPopup) {
                Button("Förstått!", role: .cancel) { }
            } message: {
                Text("• 1 km² = 1 lott\n• Gympass med 5000kg+ = 1 lott\n• Boka en lektion = 5 lotter\n• Bli PRO-medlem för 2x lotter\n\nDet mest effektiva sättet är att ta över områden via Zonkriget!\n\n— Så funkar det —\n\nGenom att utföra olika handlingar i Up&Down får du lotter som ökar dina chanser att vinna priserna som visas på Zonkriget-sidan. Vill du ha större chans att vinna? Skaffa så mycket lotter du bara kan!")
            }
            .sheet(item: $selectedTerritory) { territory in
                TerritoryDetailView(territory: territory)
                    .presentationDetents([.medium, .large])
            }
            .sheet(isPresented: $showLeaderboard) {
                ZoneWarMenuView(
                    selectedTab: $selectedMenuTab,
                    leaders: localLeaders,
                    events: territoryEvents,
                    areaName: currentAreaName,
                    onRefresh: {
                        // Refresh all data
                        territoryStore.forceRefresh()
                        await territoryStore.refresh()
                        await loadAllLeaders()
                        await loadTerritoryEvents()
                    }
                )
                .presentationDetents([.large])
                .presentationDragIndicator(.hidden) // Hide drag indicator
                .interactiveDismissDisabled() // Disable swipe to dismiss
                .onAppear {
                    selectedMenuTab = 0
                }
            }
            .sheet(isPresented: $showBottomMenu) {
                ZoneWarMenuView(
                    selectedTab: $selectedMenuTab,
                    leaders: localLeaders,
                    events: territoryEvents,
                    areaName: currentAreaName,
                    onRefresh: {
                        // Refresh all data
                        territoryStore.forceRefresh()
                        await territoryStore.refresh()
                        await loadAllLeaders()
                        await loadTerritoryEvents()
                    }
                )
                .presentationDetents([.large])
                .presentationDragIndicator(.hidden) // Hide drag indicator
                .interactiveDismissDisabled() // Disable swipe to dismiss
            }
        }
    }
    
    // MARK: - King of Area Header
    
    private var kingOfAreaHeader: some View {
        Button {
            if isPremium {
                showLeaderboard = true
            } else {
                showPaywall = true
            }
        } label: {
            VStack(spacing: 0) {
                // Main blurred content
                ZStack {
                    VStack(spacing: 4) {
                        // Leader info
                        if let leader = areaLeader {
                            HStack(spacing: 10) {
                                // Profile image with PRO badge for non-premium
                                ZStack(alignment: .bottomTrailing) {
                                    ProfileImage(url: leader.avatarUrl, size: 36)
                                    
                                    if !isPremium {
                                        Text("PRO")
                                            .font(.system(size: 8, weight: .black))
                                            .foregroundColor(.yellow)
                                            .padding(.horizontal, 4)
                                            .padding(.vertical, 2)
                                            .background(
                                                Capsule()
                                                    .fill(Color.black.opacity(0.9))
                                            )
                                            .offset(x: 4, y: 4)
                                    }
                                }
                                
                                // Name and area
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(leader.name)
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(.white)
                                    
                                    // This row shows different content based on premium
                                    if isPremium {
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
                        
                        // Area name subtitle - only for premium
                        if isPremium {
                            Text("Kungen av \(currentAreaName)")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.white.opacity(0.8))
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .blur(radius: isPremium ? 0 : 6)
                    
                    // PRO text for non-premium
                    if !isPremium {
                        Text("PRO")
                            .font(.system(size: 14, weight: .black))
                            .foregroundColor(.yellow)
                    }
                }
                .background(
                    UnevenRoundedRectangle(
                        topLeadingRadius: 16,
                        bottomLeadingRadius: isPremium ? 16 : 0,
                        bottomTrailingRadius: isPremium ? 16 : 0,
                        topTrailingRadius: 16,
                        style: .continuous
                    )
                    .fill(Color.black.opacity(0.85))
                )
                
                // Bottom section with unlock text for non-premium
                if !isPremium {
                    HStack(spacing: 6) {
                        Text("👑")
                            .font(.system(size: 14))
                        Text("KING OF THE AREA")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.white)
                        Text("👑")
                            .font(.system(size: 14))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        UnevenRoundedRectangle(
                            topLeadingRadius: 0,
                            bottomLeadingRadius: 16,
                            bottomTrailingRadius: 16,
                            topTrailingRadius: 0,
                            style: .continuous
                        )
                        .fill(Color.black.opacity(0.75))
                    )
                }
            }
            .padding(.horizontal, 16)
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showPaywall) {
            PresentPaywallView()
        }
        .onReceive(RevenueCatManager.shared.$isPremium) { newValue in
            isPremium = newValue
        }
    }
    
    // MARK: - Prize List Box
    
    private var prizeListBox: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header - tappable to expand
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    isPrizeListExpanded.toggle()
                }
            } label: {
                HStack(spacing: 8) {
                    Text("🏆 PRISER")
                        .font(.system(size: 11, weight: .black))
                        .foregroundColor(.yellow)
                    
                    Image(systemName: isPrizeListExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.yellow.opacity(0.7))
                }
            }
            .buttonStyle(.plain)
            
            // Prize list - show 3 or all 5
            let displayedPrizes = isPrizeListExpanded ? prizes : Array(prizes.prefix(3))
            
            ForEach(displayedPrizes.indices, id: \.self) { index in
                HStack(spacing: 8) {
                    // Company logo in circle with black border
                    Image(displayedPrizes[index].logoImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 24, height: 24)
                        .clipShape(Circle())
                        .overlay(
                            Circle()
                                .stroke(Color.black, lineWidth: 2)
                        )
                    
                    // Rank number
                    Text("\(index + 1).")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 16, alignment: .leading)
                    
                    // Company name and prize
                    Text(displayedPrizes[index].text)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.white)
                        .fixedSize(horizontal: true, vertical: false)
                }
            }
            
            // "Show more" hint when collapsed
            if !isPrizeListExpanded {
                Text("Tryck för att se alla")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(.gray)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(width: 195) // Fixed width to fit longer text
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.black.opacity(0.85))
        )
        .onTapGesture {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                isPrizeListExpanded.toggle()
            }
        }
    }
    
    // MARK: - Lottery Card
    
    private var lotteryCard: some View {
        LotteryTicketCard(
            myTickets: myLotteryTickets,
            totalTickets: totalLotteryTickets,
            drawDate: "1 april",
            isExpanded: $isLotteryExpanded
        )
        .frame(width: 195)
    }
    
    private func loadLotteryStats() async {
        guard let userId = authViewModel.currentUser?.id else { return }
        
        do {
            try await AuthSessionManager.shared.ensureValidSession()
            
            // Struct matching the SQL function return type
            struct LotteryStats: Decodable {
                let my_tickets: Int
                let total_tickets: Int
                let my_percentage: Double
                let territory_tickets: Int
                let gym_tickets: Int
                let booking_tickets: Int
            }
            
            let stats: [LotteryStats] = try await SupabaseConfig.supabase
                .rpc("get_lottery_stats", params: ["p_user_id": userId])
                .execute()
                .value
            
            if let stat = stats.first {
                await MainActor.run {
                    myLotteryTickets = stat.my_tickets
                    totalLotteryTickets = stat.total_tickets
                    print("🎫 Lottery stats loaded:")
                    print("   - My tickets: \(stat.my_tickets) (Territory: \(stat.territory_tickets), Gym: \(stat.gym_tickets), Bookings: \(stat.booking_tickets))")
                    print("   - Total tickets: \(stat.total_tickets)")
                    print("   - My percentage: \(String(format: "%.1f", stat.my_percentage))%")
                }
            }
        } catch {
            print("❌ Failed to load lottery stats: \(error)")
            // Fallback: Calculate from tiles (PRO multiplier applied locally)
            await MainActor.run {
                let isPro = authViewModel.currentUser?.isProMember ?? false
                let multiplier = isPro ? 2.0 : 1.0
                
                // Calculate from tiles
                let myTiles = territoryStore.tiles.filter { $0.ownerId == userId }
                // Each tile is ~625 m² (25m x 25m), 1600 tiles = 1 km²
                let myAreaKm2 = Double(myTiles.count) * 625.0 / 1_000_000.0
                let totalAreaKm2 = Double(territoryStore.tiles.count) * 625.0 / 1_000_000.0
                
                myLotteryTickets = Int(myAreaKm2 * multiplier)
                totalLotteryTickets = max(Int(totalAreaKm2), myLotteryTickets)
            }
        }
    }
    
    // Prize data model
    private var prizes: [(logoImage: String, text: String)] {
        [
            ("35", "FUSE ENERGY 1500kr"),
            ("14", "Lonegolf 1000kr"),
            ("22", "Zen Energy 1 flak")
        ]
    }
    
    // MARK: - Bottom Menu Bar
    
    private var bottomMenuBar: some View {
        HStack(spacing: 0) {
            Button {
                selectedMenuTab = 0
                showBottomMenu = true
            } label: {
                Text("TOPPLISTA")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 28)
                    .padding(.vertical, 12)
            }
        }
        .background(
            Capsule()
                .fill(
                    LinearGradient(
                        colors: [
                            Color.black.opacity(0.9),
                            Color.gray.opacity(0.55)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
        )
        .padding(.horizontal, 90)
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
        
        // Check cache first
        let now = Date()
        if !Self.cachedEvents.isEmpty && now.timeIntervalSince(Self.lastEventsCacheTime) < Self.cacheValidityDuration {
            await MainActor.run {
                self.territoryEvents = Self.cachedEvents
            }
            return
        }
        
        do {
            // Use the RPC function to get takeover events for current user
            struct TakeoverEventRow: Decodable {
                let event_id: UUID
                let actor_id: UUID
                let actor_name: String
                let actor_avatar: String?
                let event_type: String
                let tile_count: Int
                let created_at: Date?
            }
            
            let response: [TakeoverEventRow] = try await SupabaseConfig.supabase
                .rpc("get_my_takeover_events", params: TakeoverEventParams(
                    p_user_id: currentUserId,
                    p_limit: 50
                ))
                .execute()
                .value
            
            var events: [TerritoryEvent] = []
            
            for item in response {
                // Create area description based on tile count
                let tileCount = item.tile_count
                let areaDescription = tileCount > 1 ? "\(tileCount) rutor" : "1 ruta"
                
                events.append(TerritoryEvent(
                    id: item.event_id,
                    type: .takeover,
                    actorId: item.actor_id.uuidString,
                    actorName: item.actor_name,
                    actorAvatarUrl: item.actor_avatar,
                    territoryId: item.event_id, // Use event_id as placeholder
                    areaName: areaDescription,
                    timestamp: item.created_at ?? Date()
                ))
            }
            
            // Cache and update
            Self.cachedEvents = events
            Self.lastEventsCacheTime = Date()
            
            await MainActor.run {
                self.territoryEvents = events
            }
            
            print("📢 Loaded \(events.count) takeover events")
        } catch {
            print("❌ Error loading territory events: \(error)")
            
            // Fallback: Try direct table query if RPC doesn't exist yet
            do {
                let response: [TerritoryEventRow] = try await SupabaseConfig.supabase
                    .from("territory_events")
                    .select("id, territory_id, actor_id, event_type, metadata, created_at")
                    .eq("victim_id", value: currentUserId)
                    .eq("event_type", value: "takeover")
                    .order("created_at", ascending: false)
                    .limit(50)
                    .execute()
                    .value
                
                var events: [TerritoryEvent] = []
                let actorIds = Array(Set(response.map { $0.actor_id }))
                var profilesMap: [String: (name: String, avatarUrl: String?)] = [:]
                
                if !actorIds.isEmpty {
                    if let profiles: [ProfileInfo] = try? await SupabaseConfig.supabase
                        .from("profiles")
                        .select("id, username, avatar_url")
                        .in("id", values: actorIds)
                        .execute()
                        .value {
                        for profile in profiles {
                            profilesMap[profile.id] = (profile.username ?? "Okänd", profile.avatar_url)
                        }
                    }
                }
                
                for item in response {
                    let profile = profilesMap[item.actor_id]
                    let tileCount = (item.metadata?["tile_count"]?.value as? Int) ?? 1
                    
                    events.append(TerritoryEvent(
                        id: item.id,
                        type: .takeover,
                        actorId: item.actor_id,
                        actorName: profile?.name ?? "Okänd",
                        actorAvatarUrl: profile?.avatarUrl,
                        territoryId: item.territory_id,
                        areaName: tileCount > 1 ? "\(tileCount) rutor" : "1 ruta",
                        timestamp: item.created_at ?? Date()
                    ))
                }
                
                Self.cachedEvents = events
                Self.lastEventsCacheTime = Date()
                
                await MainActor.run {
                    self.territoryEvents = events
                }
            } catch {
                print("❌ Fallback event loading also failed: \(error)")
            }
        }
    }
    
    // MARK: - Helper Functions
    
    // Profile cache for local lookups - ensures consistent ID-to-profile mapping
    @State private var profileCache: [String: TerritoryOwnerProfile] = [:]
    
    // Throttle for local stats - prevent excessive database calls
    @State private var lastLocalStatsTime: Date = .distantPast
    private let localStatsThrottle: TimeInterval = 5.0 // Only update every 5 seconds
    
    private func calculateLocalStats() {
        // Throttle database calls
        let now = Date()
        guard now.timeIntervalSince(lastLocalStatsTime) >= localStatsThrottle else { return }
        lastLocalStatsTime = now
        
        // Trigger async fetch from database instead of counting local tiles
        Task {
            await loadLocalLeadersFromDatabase()
        }
    }
    
    private func loadLocalLeadersFromDatabase() async {
        // Get bounding box from visible map rect
        let topLeft = MKMapPoint(x: visibleMapRect.origin.x, y: visibleMapRect.origin.y)
        let bottomRight = MKMapPoint(x: visibleMapRect.maxX, y: visibleMapRect.maxY)
        
        let minLat = min(topLeft.coordinate.latitude, bottomRight.coordinate.latitude)
        let maxLat = max(topLeft.coordinate.latitude, bottomRight.coordinate.latitude)
        let minLon = min(topLeft.coordinate.longitude, bottomRight.coordinate.longitude)
        let maxLon = max(topLeft.coordinate.longitude, bottomRight.coordinate.longitude)
        
        // Add margin to capture more area
        let margin = 0.01 // ~1km margin
        let expandedMinLat = minLat - margin
        let expandedMaxLat = maxLat + margin
        let expandedMinLon = minLon - margin
        let expandedMaxLon = maxLon + margin
        
        do {
            try await AuthSessionManager.shared.ensureValidSession()
            
            struct LocalLeaderRow: Decodable {
                let owner_id: UUID
                let area_m2: Double
                let username: String?
                let avatar_url: String?
                let is_pro: Bool?
            }
            
            let results: [LocalLeaderRow] = try await SupabaseConfig.supabase
                .rpc("get_leaderboard_in_bounds", params: [
                    "min_lat": expandedMinLat,
                    "min_lon": expandedMinLon,
                    "max_lat": expandedMaxLat,
                    "max_lon": expandedMaxLon,
                    "limit_count": 20
                ])
                .execute()
                .value
            
            await MainActor.run {
                let leaders = results.map { row in
                    TerritoryLeader(
                        id: row.owner_id.uuidString.lowercased(),
                        name: row.username ?? "Användare",
                        avatarUrl: row.avatar_url,
                        totalArea: row.area_m2,
                        isPro: row.is_pro ?? false
                    )
                }
                
                self.localLeaders = leaders
                
                // Update Area Leader (King of the visible area)
                if let first = leaders.first {
                    self.areaLeader = first
                } else {
                    self.areaLeader = nil
                }
                
                #if DEBUG
                print("📊 Local leaderboard from DB: \(leaders.count) leaders in bounds")
                #endif
            }
        } catch {
            print("❌ Failed to load local leaderboard: \(error)")
        }
    }
    
    private func fetchMissingProfiles(ownerIds: [String]) async {
        guard !ownerIds.isEmpty else { return }
        
        do {
            try await AuthSessionManager.shared.ensureValidSession()
            
            // Fetch profiles for the missing IDs
            let profiles: [TerritoryOwnerProfile] = try await SupabaseConfig.supabase
                .from("profiles")
                .select("id, username, avatar_url, is_pro")
                .in("id", values: ownerIds)
                .execute()
                .value
            
            // Update cache and trigger recalculation
            await MainActor.run {
                for profile in profiles {
                    self.profileCache[profile.id.lowercased()] = profile
                }
                
                // Prefetch avatar images
                let avatarUrls = profiles.compactMap { $0.avatarUrl }
                ImageCacheManager.shared.prefetch(urls: avatarUrls)
                
                // Recalculate with new profile data
                if !profiles.isEmpty {
                    self.calculateLocalStats()
                }
            }
            
            print("✅ Fetched \(profiles.count) missing profiles for local leaderboard")
        } catch {
            print("❌ Failed to fetch missing profiles: \(error)")
        }
    }
    
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
        // Throttle geocoding to reduce API calls
        let now = Date()
        guard now.timeIntervalSince(lastGeocodingTime) >= geocodingThrottle else { return }
        lastGeocodingTime = now
        
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
    
    private func loadAllLeaders() async {
        // Check cache first - but only if cache has valid profiles (not all "Okänd")
        let now = Date()
        let cacheHasValidProfiles = Self.cachedLeaders.contains { $0.name != "Okänd" }
        
        if !Self.cachedLeaders.isEmpty && 
           cacheHasValidProfiles &&
           now.timeIntervalSince(Self.lastCacheTime) < Self.cacheValidityDuration {
            await MainActor.run {
                self.allLeaders = Self.cachedLeaders
                // Note: areaLeader is calculated from localLeaders only, not Sweden-wide
            }
            return
        }
        
        // Ensure valid session first - MUST succeed before fetching profiles
        do {
            try await AuthSessionManager.shared.ensureValidSession()
        } catch {
            print("❌ Failed to ensure valid session for leaders: \(error)")
            // If session fails, use existing cache even if stale
            if !Self.cachedLeaders.isEmpty && cacheHasValidProfiles {
                await MainActor.run {
                    self.allLeaders = Self.cachedLeaders
                    // Note: areaLeader is calculated from localLeaders only
                }
            }
            return
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
        
        // Try up to 3 times to fetch profiles
        for attempt in 1...3 {
            do {
                // Re-ensure session is valid on retry
                if attempt > 1 {
                    try await AuthSessionManager.shared.ensureValidSession()
                }
                
                let profiles: [TerritoryOwnerProfile] = try await SupabaseConfig.supabase
                    .from("profiles")
                    .select("id, username, avatar_url, is_pro")
                    .in("id", values: ownerIds)
                    .execute()
                    .value
                
                print("✅ Fetched \(profiles.count) profiles for \(ownerIds.count) owners (attempt \(attempt))")
                
                for profile in profiles {
                    profilesMap[profile.id] = profile
                    // Also add to local profile cache for consistent lookups
                    self.profileCache[profile.id.lowercased()] = profile
                }
                break // Success, exit retry loop
            } catch {
                print("❌ Failed to fetch profiles (attempt \(attempt)): \(error)")
                if attempt < 3 {
                    try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 second delay before retry
                }
            }
        }
        
        // Fallback: fetch any missing profiles in smaller chunks
        let missingIds = ownerIds.filter { profilesMap[$0] == nil }
        if !missingIds.isEmpty {
            print("⚠️ Missing \(missingIds.count) profiles, fetching in chunks...")
            for chunk in missingIds.chunked(into: 10) {
                do {
                    let extra: [TerritoryOwnerProfile] = try await SupabaseConfig.supabase
                        .from("profiles")
                        .select("id, username, avatar_url, is_pro")
                        .in("id", values: chunk)
                        .execute()
                        .value
                    for profile in extra {
                        profilesMap[profile.id] = profile
                        self.profileCache[profile.id.lowercased()] = profile
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
        
        // Only update cache if we got valid profiles
        let newCacheHasValidProfiles = leaders.contains { $0.name != "Okänd" }
        if newCacheHasValidProfiles || Self.cachedLeaders.isEmpty {
            Self.cachedLeaders = leaders
            Self.lastCacheTime = now
        }
        
        await MainActor.run {
            // Use new leaders only if we got valid profiles, otherwise keep old
            if newCacheHasValidProfiles || self.allLeaders.isEmpty {
                self.allLeaders = leaders
                
                // Trigger local recalculation now that we have profiles
                calculateLocalStats()
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
    let tiles: [Tile]
    let onTerritoryTapped: (Territory) -> Void
    let onRegionChanged: (MKCoordinateRegion, MKMapRect) -> Void
    var targetRegion: Binding<MKCoordinateRegion?>?
    
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
        // Only update coordinator data (lightweight)
        context.coordinator.onTerritoryTapped = onTerritoryTapped
        context.coordinator.onRegionChanged = onRegionChanged
        
        // Check if data actually changed before triggering expensive map update
        let tilesChanged = tiles.count != context.coordinator.tiles.count ||
                          Set(tiles.map { $0.id }) != Set(context.coordinator.tiles.map { $0.id }) ||
                          tilesHaveOwnershipChanges(old: context.coordinator.tiles, new: tiles)
        let territoriesChanged = territories.count != context.coordinator.territories.count ||
                                Set(territories.map { $0.id }) != Set(context.coordinator.territories.map { $0.id })
        
        if tilesChanged || territoriesChanged {
            context.coordinator.territories = territories
            context.coordinator.tiles = tiles
            
            // Debounce map updates to prevent rapid redraws
            context.coordinator.pendingMapUpdate?.cancel()
            
            // Capture coordinator weakly to prevent crashes if view deallocated
            let coordinator = context.coordinator
            let workItem = DispatchWorkItem { [weak coordinator, tiles, territories] in
                guard let coordinator = coordinator else { return }
                coordinator.updateMap(uiView, territories: territories, tiles: tiles)
            }
            context.coordinator.pendingMapUpdate = workItem
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15, execute: workItem)
        }
        
        // Animate to target region if set
        if let targetRegion = targetRegion?.wrappedValue {
            DispatchQueue.main.async {
                uiView.setRegion(targetRegion, animated: true)
                // Clear the target after animating
                self.targetRegion?.wrappedValue = nil
            }
        }
    }
    
    private func tilesHaveOwnershipChanges(old: [Tile], new: [Tile]) -> Bool {
        let oldMap = Dictionary(uniqueKeysWithValues: old.map { ($0.id, $0.ownerId) })
        for tile in new {
            if oldMap[tile.id] != tile.ownerId {
                return true
            }
        }
        return false
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
        var tiles: [Tile] = []
        var onTerritoryTapped: (Territory) -> Void
        var onTileTapped: ((Tile) -> Void)?
        var onRegionChanged: (MKCoordinateRegion, MKMapRect) -> Void
        private var hasCentered = false
        private var currentTerritoryIds: Set<UUID> = []
        private var currentTileIds: Set<Int64> = []
        private var polygonToTerritory: [MKPolygon: Territory] = [:]
        private var polygonToTile: [MKPolygon: Tile] = [:]
        private var polygonIsTile: Set<MKPolygon> = []
        
        // Throttling for region changes
        private var lastRegionChangeTime: Date = .distantPast
        private let regionChangeThrottleInterval: TimeInterval = 1.0 // 1s throttle (increased to reduce flickering)
        private var pendingRegionChange: DispatchWorkItem?
        var pendingMapUpdate: DispatchWorkItem?
        
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
                    // Check if it's a territory
                    if let territory = polygonToTerritory[polygon] {
                        onTerritoryTapped(territory)
                        return
                    }
                    // Check if it's a tile - create a temporary Territory for display
                    if let tile = polygonToTile[polygon], let ownerId = tile.ownerId {
                        let tempTerritory = Territory(
                            id: UUID(),
                            ownerId: ownerId,
                            activity: nil,
                            area: 625, // ~25m x 25m tile
                            polygons: [tile.coordinates]
                        )
                        onTerritoryTapped(tempTerritory)
                        return
                    }
                }
            }
        }
        
        func updateMap(_ mapView: MKMapView, territories: [Territory], tiles: [Tile]) {
            // No arbitrary limit - render all tiles in the current viewport
            // The TerritoryStore already limits fetching to visible viewport
            let tilesToRender = tiles
            
            // Create signatures for comparison
            let newTerritoryIds = Set(territories.map { $0.id })
            let newTileSignatures = Set(tilesToRender.map { "\($0.id)_\($0.ownerId ?? "")" })
            let currentTileSignatures = Set(currentTileIds.map { id -> String in
                if let tile = polygonToTile.values.first(where: { $0.id == id }) {
                    return "\(tile.id)_\(tile.ownerId ?? "")"
                }
                return "\(id)_"
            })
            
            // Skip if nothing changed
            if newTerritoryIds == currentTerritoryIds && newTileSignatures == currentTileSignatures && !currentTileIds.isEmpty {
                return
            }
            
            // INCREMENTAL UPDATE: Only add/remove changed tiles
            let tilesToAdd = tilesToRender.filter { tile in
                !currentTileIds.contains(tile.id) || 
                polygonToTile.values.first(where: { $0.id == tile.id })?.ownerId != tile.ownerId
            }
            let tileIdsToRemove = currentTileIds.subtracting(Set(tilesToRender.map { $0.id }))
            
            // If small change, do incremental update (much faster)
            let isSmallChange = tilesToAdd.count < 50 && tileIdsToRemove.count < 50
            
            if isSmallChange && !currentTileIds.isEmpty {
                // Remove old overlays for tiles being removed/updated
                let overlaysToRemove = mapView.overlays.filter { overlay in
                    guard let polygon = overlay as? MKPolygon, polygonIsTile.contains(polygon) else { return false }
                    if let tile = polygonToTile[polygon] {
                        return tileIdsToRemove.contains(tile.id) || tilesToAdd.contains(where: { $0.id == tile.id })
                    }
                    return false
                }
                mapView.removeOverlays(overlaysToRemove)
                
                // Add new tiles
                var newPolygons: [MKPolygon] = []
                for tile in tilesToAdd {
                    guard tile.coordinates.count >= 3 else { continue }
                    var coords = tile.coordinates
                    if let first = coords.first, let last = coords.last, (first.latitude != last.latitude || first.longitude != last.longitude) {
                        coords.append(first)
                    }
                    let poly = MKPolygon(coordinates: coords, count: coords.count)
                    poly.title = tile.ownerId ?? ""
                    polygonIsTile.insert(poly)
                    polygonToTile[poly] = tile
                    newPolygons.append(poly)
                }
                mapView.addOverlays(newPolygons)
                
                currentTileIds = Set(tilesToRender.map { $0.id })
                return
            }
            
            // FULL REBUILD (only when necessary)
            currentTerritoryIds = newTerritoryIds
            currentTileIds = Set(tilesToRender.map { $0.id })
            
            let existingOverlays = mapView.overlays
            
            polygonToTerritory.removeAll(keepingCapacity: true)
            polygonToTile.removeAll(keepingCapacity: true)
            polygonIsTile.removeAll(keepingCapacity: true)
            
            var allPolygons: [MKPolygon] = []
            allPolygons.reserveCapacity(territories.count * 2 + tilesToRender.count)
            
            // Tiles first
            for tile in tilesToRender {
                guard tile.coordinates.count >= 3 else { continue }
                var coords = tile.coordinates
                if let first = coords.first, let last = coords.last, (first.latitude != last.latitude || first.longitude != last.longitude) {
                    coords.append(first)
                }
                let poly = MKPolygon(coordinates: coords, count: coords.count)
                poly.title = tile.ownerId ?? ""
                polygonIsTile.insert(poly)
                polygonToTile[poly] = tile
                allPolygons.append(poly)
            }
            
            // Territories
            for territory in territories {
                for (ringIndex, ring) in territory.polygons.enumerated() {
                    guard ring.count >= 3 else { continue }
                    
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
            
            // Batch update
            if !allPolygons.isEmpty {
                mapView.addOverlays(allPolygons)
            }
            if !existingOverlays.isEmpty {
                mapView.removeOverlays(existingOverlays)
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
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self, weak mapView] in
                    guard let self = self, let mapView = mapView else { return }
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
                let workItem = DispatchWorkItem { [weak self, weak mapView] in
                    guard let self = self, let mapView = mapView else { return }
                    self.lastRegionChangeTime = Date()
                    self.onRegionChanged(mapView.region, mapView.visibleMapRect)
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
            
            // Tile vs Territory styling
            let isTile = polygonIsTile.contains(polygon)
            let ownerId = polygon.title ?? ""
            
            if isTile {
                // Neutral tile = grå; owned tile = färg
                if ownerId.isEmpty {
                    renderer.fillColor = UIColor.gray.withAlphaComponent(0.12)
                    renderer.strokeColor = UIColor.gray.withAlphaComponent(0.25)
                    renderer.lineWidth = 0.5
                } else {
                    let color = TerritoryColors.colorForUser(ownerId)
                    renderer.fillColor = color.withAlphaComponent(0.18)
                    renderer.strokeColor = color.withAlphaComponent(0.5)
                    renderer.lineWidth = 1.0
                }
            } else {
                // Territories (union per ägare)
                let color = TerritoryColors.colorForUser(ownerId)
                renderer.fillColor = color.withAlphaComponent(0.35)
                renderer.strokeColor = color
                renderer.lineWidth = 2.5
            }
            
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
    var onRefresh: (() async -> Void)? = nil // Callback for pull-to-refresh
    @Environment(\.dismiss) private var dismiss
    
    // Pro membership
    @State private var isPremium = RevenueCatManager.shared.isPremium
    @State private var showPaywall = false
    
    // Leaderboard type toggle - Non-Pro users default to Sweden, Pro users default to local
    @State private var isShowingSwedenLeaderboard = !RevenueCatManager.shared.isPremium
    @State private var swedenLeaders: [TerritoryLeader] = []
    @State private var isLoadingSwedenLeaders = false
    
    // Navigation state
    @State private var selectedUserId: String?
    @State private var showUserProfile = false
    
    // Refresh state
    @State private var isRefreshing = false
    
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
                
                // Sponsors section
                sponsorsSection
            }
            .background(Color(red: 0.12, green: 0.12, blue: 0.14))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text(selectedTab == 0 ? "Topplista" : "Events")
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
            .navigationDestination(isPresented: $showUserProfile) {
                if let userId = selectedUserId {
                    UserProfileView(userId: userId)
                }
            }
            .sheet(isPresented: $showPaywall) {
                PresentPaywallView()
            }
            .onReceive(RevenueCatManager.shared.$isPremium) { newValue in
                isPremium = newValue
            }
            .task {
                // Load Sweden leaders immediately for non-Pro users (always refresh)
                if !isPremium {
                    loadSwedenLeaders()
                }
            }
        }
    }
    
    // MARK: - Leaderboard View
    
    private var leaderboardView: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Area toggle picker
                HStack(spacing: 0) {
                    // Local area button
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isShowingSwedenLeaderboard = false
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "mappin.circle.fill")
                                .font(.system(size: 14))
                            Text(areaName)
                                .font(.system(size: 14, weight: .semibold))
                                .lineLimit(1)
                        }
                        .foregroundColor(!isShowingSwedenLeaderboard ? .black : .gray)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(!isShowingSwedenLeaderboard ? Color.yellow : Color.clear)
                        .cornerRadius(20)
                    }
                    
                    // Sweden button
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isShowingSwedenLeaderboard = true
                        }
                        // Always reload Sweden leaders to get fresh data
                        loadSwedenLeaders()
                    } label: {
                        HStack(spacing: 6) {
                            Text("🇸🇪")
                                .font(.system(size: 14))
                            Text("Hela Sverige")
                                .font(.system(size: 14, weight: .semibold))
                        }
                        .foregroundColor(isShowingSwedenLeaderboard ? .black : .gray)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(isShowingSwedenLeaderboard ? Color.yellow : Color.clear)
                        .cornerRadius(20)
                    }
                }
                .padding(4)
                .background(Color(red: 0.2, green: 0.2, blue: 0.22))
                .cornerRadius(24)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                
                // Leaderboard content
                let displayLeaders = isShowingSwedenLeaderboard ? swedenLeaders : leaders.sorted { $0.totalArea > $1.totalArea }
                let maxCount = isShowingSwedenLeaderboard ? 20 : displayLeaders.count
                
                if isLoadingSwedenLeaders && isShowingSwedenLeaderboard {
                    ProgressView()
                        .scaleEffect(1.2)
                        .padding(.top, 40)
                } else {
                    // Check if local leaderboard should be blurred (non-Pro viewing local)
                    let shouldBlurLocal = !isPremium && !isShowingSwedenLeaderboard
                    
                    LazyVStack(spacing: 0) {
                        ForEach(Array(displayLeaders.prefix(maxCount).enumerated()), id: \.element.id) { index, leader in
                            if shouldBlurLocal {
                                // Blurred row for non-Pro users on local leaderboard
                                Button {
                                    showPaywall = true
                                } label: {
                                    leaderboardRow(index: index, leader: leader)
                                        .blur(radius: 6)
                                        .overlay(
                                            HStack(spacing: 6) {
                                                Image(systemName: "lock.fill")
                                                    .font(.system(size: 14, weight: .bold))
                                                Text("PRO")
                                                    .font(.system(size: 14, weight: .black))
                                            }
                                            .foregroundColor(.yellow)
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 6)
                                            .background(
                                                Capsule()
                                                    .fill(Color.black.opacity(0.8))
                                            )
                                        )
                                }
                                .buttonStyle(.plain)
                            } else {
                                // Normal row for Pro users or Sweden leaderboard
                                Button {
                                    selectedUserId = leader.id
                                    showUserProfile = true
                                } label: {
                                    leaderboardRow(index: index, leader: leader)
                                }
                                .buttonStyle(.plain)
                            }
                            
                            if index < min(maxCount, displayLeaders.count) - 1 {
                                Divider()
                                    .background(Color.gray.opacity(0.2))
                                    .padding(.leading, 66)
                            }
                        }
                        
                        if displayLeaders.isEmpty {
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
                }
            }
            .padding(.top, 8)
        }
        .refreshable {
            // Pull to refresh - reload Sweden leaders
            loadSwedenLeaders()
            // Call parent refresh callback
            await onRefresh?()
        }
    }
    
    // Helper view for leaderboard row
    @ViewBuilder
    private func leaderboardRow(index: Int, leader: TerritoryLeader) -> some View {
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
                HStack(spacing: 6) {
                    Text(leader.name)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.gray.opacity(0.6))
                }
                
                if index == 0 {
                    HStack(spacing: 4) {
                        Text("👑")
                            .font(.system(size: 10))
                        Text(isShowingSwedenLeaderboard ? "KUNG AV SVERIGE" : "KUNG AV OMRÅDET")
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
    }
    
    private func loadSwedenLeaders() {
        isLoadingSwedenLeaders = true
        
        Task {
            await MainActor.run {
                isLoadingSwedenLeaders = true
            }
            
            // Ensure session is valid before fetching
            do {
                try await AuthSessionManager.shared.ensureValidSession()
            } catch {
                print("⚠️ Session check failed before loading Sweden leaders: \(error)")
            }
            
            do {
                // Use the RPC function that aggregates from territory_tiles
                struct LeaderboardEntry: Decodable {
                    let owner_id: UUID
                    let area_m2: Double
                    let username: String?
                    let avatar_url: String?
                    let is_pro: Bool?
                }
                
                print("📊 Fetching Sweden leaderboard via RPC...")
                
                let result: [LeaderboardEntry] = try await SupabaseConfig.supabase.database
                    .rpc("get_leaderboard", params: ["limit_count": 20])
                    .execute()
                    .value
                
                print("📊 Fetched \(result.count) leaders from RPC")
                
                // Check if all names are null - might indicate session issue
                let allNullNames = result.allSatisfy { $0.username == nil }
                if allNullNames && !result.isEmpty {
                    print("⚠️ All usernames are null - possible session/RLS issue. Retrying...")
                    await AuthSessionManager.shared.recoverSession()
                    
                    // Retry once
                    let retryResult: [LeaderboardEntry] = try await SupabaseConfig.supabase.database
                        .rpc("get_leaderboard", params: ["limit_count": 20])
                        .execute()
                        .value
                    
                    let retryLeaders = retryResult.map { entry in
                        TerritoryLeader(
                            id: entry.owner_id.uuidString.lowercased(),
                            name: entry.username ?? "Användare",
                            avatarUrl: entry.avatar_url,
                            totalArea: entry.area_m2,
                            isPro: entry.is_pro ?? false
                        )
                    }
                    
                    await MainActor.run {
                        self.swedenLeaders = retryLeaders
                        self.isLoadingSwedenLeaders = false
                    }
                    return
                }
                
                let newLeaders = result.map { entry in
                    TerritoryLeader(
                        id: entry.owner_id.uuidString.lowercased(),
                        name: entry.username ?? "Användare", // Better fallback than "Okänd"
                        avatarUrl: entry.avatar_url,
                        totalArea: entry.area_m2,
                        isPro: entry.is_pro ?? false
                    )
                }
                
                await MainActor.run {
                    self.swedenLeaders = newLeaders
                    self.isLoadingSwedenLeaders = false
                }
            } catch {
                print("❌ Failed to load Sweden leaders: \(error)")
                // Try to recover session for next time
                await AuthSessionManager.shared.recoverSession()
                
                await MainActor.run {
                    // Keep existing data if we have it
                    if self.swedenLeaders.isEmpty {
                        self.swedenLeaders = []
                    }
                    self.isLoadingSwedenLeaders = false
                }
            }
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
        .refreshable {
            // Pull to refresh events
            await onRefresh?()
        }
    }
    
    // MARK: - Sponsors Section
    
    private var sponsorsSection: some View {
        VStack(spacing: 16) {
            Text("Zonkriget sponsras av")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.gray)
            
            HStack(spacing: 16) {
                ForEach(sponsors, id: \.name) { sponsor in
                    VStack(spacing: 6) {
                        Image(sponsor.imageName)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 50, height: 50)
                            .clipShape(Circle())
                            .overlay(
                                Circle()
                                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                            )
                        
                        Text(sponsor.name)
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(.gray)
                            .lineLimit(1)
                    }
                }
            }
        }
        .padding(.vertical, 20)
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity)
        .background(Color(red: 0.08, green: 0.08, blue: 0.1))
    }
    
    private var sponsors: [(name: String, imageName: String)] {
        [
            ("Fuse Energy", "35"),
            ("Lonegolf", "14")
        ]
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
