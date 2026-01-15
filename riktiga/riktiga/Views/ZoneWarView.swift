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
    @State private var navigationPath = NavigationPath()
    
    // Track if initial load has happened (persists across view recreations)
    private static var hasInitiallyLoaded = false
    
    // Area tracking
    @State private var currentAreaName: String = "Området"
    @State private var areaLeader: TerritoryLeader?
    @State private var allLeaders: [TerritoryLeader] = []
    @State private var localLeaders: [TerritoryLeader] = [] // Calculated from city bounds, not just visible tiles
    @State private var visibleMapRect: MKMapRect = MKMapRect.world
    
    // Bottom menu
    @State private var showBottomMenu = false
    @State private var showLotteryLeaderboard = false
    @State private var selectedMenuTab: Int = 0 // 0 = Topplista, 1 = Events
    @State private var territoryEvents: [TerritoryEvent] = []
    
    // Prize list
    @State private var isPrizeListExpanded = false
    
    // Pro membership
    @State private var isPremium = RevenueCatManager.shared.isProMember
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
    
    // Geocoding throttle - 1 second for more responsive area name updates
    @State private var lastGeocodingTime: Date = .distantPast
    private let geocodingThrottle: TimeInterval = 1.0
    
    // City bounds cache for local leaderboard
    @State private var cachedCityName: String = ""
    @State private var cachedCityBounds: (minLat: Double, maxLat: Double, minLon: Double, maxLon: Double)?
    private let cityBoundsGeocoder = CLGeocoder()
    
    var body: some View {
        NavigationStack(path: $navigationPath) {
            ZStack {
                ZoneWarMapView(
                    territories: territoryStore.territories, // Owner polygons (one overlay per owner)
                    tiles: [], // No tile rendering (avoid caps + lag)
                    onTerritoryTapped: { territory in
                        selectedTerritory = territory
                    },
                    onRegionChanged: { region, mapRect in
                        visibleMapRect = mapRect
                        updateAreaName(for: region.center)
                        // updateLeaderForVisibleArea(mapRect: mapRect) // Replaced by calculateLocalStats
                        
                        // IMPORTANT:
                        // Do NOT debounce here. The TerritoryStore already debounces + caches viewport fetches.
                        // Double-debouncing caused situations where users had to press refresh to see polygons.
                        let center = region.center
                        let span = region.span
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
                        
                        // Update local king when map region changes (throttled inside calculateLocalStats)
                        calculateLocalStats()
                    },
                    targetRegion: $targetMapRegion
                )
                // Ta bort ignoresSafeArea så kartan inte går under tab-selectorn
                
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
                // Clear city bounds cache to ensure fresh calculation with correct radius
                cachedCityName = ""
                cachedCityBounds = nil
                
                // Check for pending territory celebration OR needsForceRefresh flag
                let hasPendingTerritory = territoryStore.pendingCelebrationTerritory != nil
                let needsRefresh = territoryStore.needsForceRefresh
                
                if hasPendingTerritory || needsRefresh {
                    print("🔄 Force refreshing tiles (pending: \(hasPendingTerritory), needsRefresh: \(needsRefresh))")
                    // Force clear cache so new tiles are loaded
                    territoryStore.invalidateCache()
                }
                
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
                
                // Capture visibleMapRect before task group (can't access @State inside addTask)
                let currentMapRect = visibleMapRect
                
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
                    // No tile loading in owner-polygon mode
                }
                isLoading = false
            }
            .refreshable {
                // Force clear cache and refetch everything
                cachedCityName = ""
                cachedCityBounds = nil
                territoryStore.forceRefresh()
                await territoryStore.syncLocalTerritoriesToBackend()
                await territoryStore.refresh()
                await loadAllLeaders()
                await loadTerritoryEvents()
                calculateLocalStats() // Recalculate with cleared city cache
            }
            .onAppear {
                // On subsequent appearances (returning to tab), force refresh territories
                if Self.hasInitiallyLoaded {
                    // Small delay to let the map view stabilize
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        let mapRect = visibleMapRect
                        
                        // Only refresh if we have valid bounds (not the entire world)
                        // Check if it's not the world rect by comparing size (world rect has huge size)
                        let isValidViewport = mapRect.size.width > 0 && mapRect.size.width < MKMapRect.world.size.width * 0.5
                        if isValidViewport {
                            let region = MKCoordinateRegion(mapRect)
                            let minLat = region.center.latitude - region.span.latitudeDelta / 2
                            let maxLat = region.center.latitude + region.span.latitudeDelta / 2
                            let minLon = region.center.longitude - region.span.longitudeDelta / 2
                            let maxLon = region.center.longitude + region.span.longitudeDelta / 2
                            
                            // Force invalidate cache and refresh for current viewport
                            territoryStore.invalidateCache()
                            territoryStore.refreshForViewport(
                                minLat: minLat,
                                maxLat: maxLat,
                                minLon: minLon,
                                maxLon: maxLon
                            )
                        } else {
                            // Fallback: general refresh
                            Task {
                                territoryStore.forceRefresh()
                                await territoryStore.refresh()
                            }
                        }
                    }
                } else {
                    // First appearance - mark flag (task handles initial load)
                    Self.hasInitiallyLoaded = true
                }
            }
            // Listen for workout saved notifications to refresh zones
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("WorkoutSaved"))) { _ in
                print("🗺️ ZoneWar: Received WorkoutSaved notification - refreshing zones")
                Task {
                    // FORCE refresh immediately - clear everything and fetch fresh
                    territoryStore.forceRefresh()
                    
                    // Wait a tiny bit for DB to settle
                    try? await Task.sleep(nanoseconds: 500_000_000) // 0.5s
                    
                    // Fetch fresh data
                    await territoryStore.refresh()
                    
                    // Also reload tiles for current viewport
                    let region = MKCoordinateRegion(visibleMapRect)
                    let minLat = region.center.latitude - region.span.latitudeDelta / 2
                    let maxLat = region.center.latitude + region.span.latitudeDelta / 2
                    let minLon = region.center.longitude - region.span.longitudeDelta / 2
                    let maxLon = region.center.longitude + region.span.longitudeDelta / 2
                    
                    await territoryStore.loadTilesInBounds(
                        minLat: minLat,
                        maxLat: maxLat,
                        minLon: minLon,
                        maxLon: maxLon,
                        forceRefresh: true
                    )
                    
                    await loadAllLeaders()
                    print("✅ ZoneWar: Zones refreshed after workout")
                }
            }
            // Recalculate local stats whenever territories update (debounced)
            .onChange(of: territoryStore.territories.count) { oldCount, newCount in
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
                .presentationDragIndicator(.visible) // Allow swipe-down to dismiss
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
                .presentationDragIndicator(.visible) // Allow swipe-down to dismiss
            }
            .sheet(isPresented: $showLotteryLeaderboard) {
                ZoneWarMenuView(
                    selectedTab: $selectedMenuTab,
                    leaders: localLeaders,
                    events: territoryEvents,
                    areaName: currentAreaName,
                    onRefresh: {
                        territoryStore.forceRefresh()
                        await territoryStore.refresh()
                        await loadAllLeaders()
                        await loadTerritoryEvents()
                    },
                    initialLeaderboardTab: 2 // Open directly to lottery tab
                )
                .presentationDetents([.large])
                .presentationDragIndicator(.visible) // Allow swipe-down to dismiss
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("PopToRootHem"))) { _ in
                navigationPath = NavigationPath()
                showLeaderboard = false
                showBottomMenu = false
                showLotteryLeaderboard = false
                selectedTerritory = nil
            }
        }
    }
    
    // MARK: - King of Area Header
    
    private var kingOfAreaHeader: some View {
        Button {
            showLeaderboard = true
        } label: {
            VStack(spacing: 0) {
                VStack(spacing: 4) {
                    // Leader info
                    if let leader = areaLeader {
                        HStack(spacing: 10) {
                            ProfileImage(url: leader.avatarUrl, size: 36)
                                .id("king-avatar-\(leader.id)") // Unique ID per leader
                            
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
                            
                            // Total tiles
                            Text(formatTileCount(leader.tileCount))
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
            }
            .padding(.horizontal, 16)
        }
        .buttonStyle(.plain)
        .onReceive(RevenueCatManager.shared.$isProMember) { newValue in
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
                let isPro = RevenueCatManager.shared.isProMember
                let multiplier = isPro ? 2.0 : 1.0
                
                // Calculate from owner territories (area_m2 from server)
                let myAreaM2 = territoryStore.territories.first(where: { $0.ownerId == userId })?.area ?? 0
                let totalAreaM2 = territoryStore.territories.reduce(0) { $0 + $1.area }
                let myAreaKm2 = myAreaM2 / 1_000_000.0
                let totalAreaKm2 = totalAreaM2 / 1_000_000.0
                
                myLotteryTickets = Int(myAreaKm2 * multiplier)
                totalLotteryTickets = max(Int(totalAreaKm2), myLotteryTickets)
            }
        }
    }
    
    // Prize data model
    private var prizes: [(logoImage: String, text: String)] {
        [
            ("46", "FUSE ENERGY 1500kr"),
            ("14", "Lonegolf 1000kr"),
            ("15", "Pliktgolf 500kr"),
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
            // Use get_my_takeover_events to get only events where someone took OUR tiles
            struct TakeoverEvent: Decodable {
                let event_id: UUID
                let actor_id: UUID
                let actor_name: String
                let actor_avatar: String?
                let event_type: String
                let tile_count: Int
                let created_at: Date?
            }
            
            let params = TakeoverEventParams(p_user_id: currentUserId, p_limit: 50)
            
            let response: [TakeoverEvent] = try await SupabaseConfig.supabase
                .rpc("get_my_takeover_events", params: params)
                .execute()
                .value
            
            var events: [TerritoryEvent] = []
            
            for item in response {
                // Calculate area from tile count (each tile is ~625 m² = 25m x 25m)
                let areaKm2 = Double(item.tile_count) * 625.0 / 1_000_000
                let areaDescription = String(format: "%.3f km² (%d tiles)", areaKm2, item.tile_count)
                
                events.append(TerritoryEvent(
                    id: item.event_id,
                    type: .takeover,
                    actorId: item.actor_id.uuidString,
                    actorName: item.actor_name,
                    actorAvatarUrl: item.actor_avatar,
                    territoryId: UUID(),
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
            
            print("📢 Loaded \(events.count) takeover events (where others took my tiles)")
        } catch {
            print("⚠️ Takeover events not available: \(error.localizedDescription)")
            // Don't spam logs - just use empty events
            await MainActor.run {
                if Self.cachedEvents.isEmpty {
                    self.territoryEvents = []
                }
            }
        }
    }
    
    // MARK: - Helper Functions
    
    // Profile cache for local lookups - ensures consistent ID-to-profile mapping
    @State private var profileCache: [String: TerritoryOwnerProfile] = [:]
    
    // Throttle for local stats - prevent excessive database calls
    @State private var lastLocalStatsTime: Date = .distantPast
    private let localStatsThrottle: TimeInterval = 1.5 // Update every 1.5 seconds for responsive local king
    
    private func calculateLocalStats() {
        // Throttle database calls
        let now = Date()
        guard now.timeIntervalSince(lastLocalStatsTime) >= localStatsThrottle else { return }
        lastLocalStatsTime = now
        
        // Trigger async fetch from database based on CURRENT CITY/LOCALITY
        Task {
            await loadLeadersForCurrentCity()
        }
    }
    
    private func loadLeadersForCurrentCity() async {
        // Get leaderboard for the ENTIRE city/locality, not just visible area
        // This ensures you see all of Danderyd's leaders when in Danderyd
        
        let cityName = currentAreaName
        
        // Skip if no valid city name
        guard !cityName.isEmpty && cityName != "Området" else {
            return
        }
        
        // Check if we already have cached bounds for this city
        if cityName == cachedCityName, let bounds = cachedCityBounds {
            await fetchLeadersForBounds(minLat: bounds.minLat, maxLat: bounds.maxLat, minLon: bounds.minLon, maxLon: bounds.maxLon)
            return
        }
        
        // Geocode the city name to get its bounds
        do {
            let placemarks = try await cityBoundsGeocoder.geocodeAddressString("\(cityName), Sverige")
            
            if let placemark = placemarks.first {
                let centerLat: Double
                let centerLon: Double
                var radiusMeters: Double
                
                // Get center from region or location
                if let region = placemark.region as? CLCircularRegion {
                    centerLat = region.center.latitude
                    centerLon = region.center.longitude
                    // Use the geocoded radius, but cap it to avoid overlapping with neighbors
                    // Most Swedish municipalities are 5-20km across
                    radiusMeters = min(region.radius, 10000) // Max 10km radius
                    radiusMeters = max(radiusMeters, 3000)   // Min 3km radius
                } else if let location = placemark.location {
                    centerLat = location.coordinate.latitude
                    centerLon = location.coordinate.longitude
                    radiusMeters = 5000 // Default 5km radius for smaller areas
                } else {
                    return
                }
                
                // Convert radius to degrees (approximately)
                // 1 degree latitude ≈ 111km
                let radiusInDegrees = radiusMeters / 111000
                
                // Create bounding box centered on the city
                let latSpan = radiusInDegrees
                let lonSpan = radiusInDegrees / cos(centerLat * .pi / 180) // Adjust for longitude
                
                let minLat = centerLat - latSpan
                let maxLat = centerLat + latSpan
                let minLon = centerLon - lonSpan
                let maxLon = centerLon + lonSpan
                
                // Cache the city bounds
                await MainActor.run {
                    self.cachedCityName = cityName
                    self.cachedCityBounds = (minLat: minLat, maxLat: maxLat, minLon: minLon, maxLon: maxLon)
                }
                
                #if DEBUG
                print("📍 City bounds for \(cityName): center(\(centerLat), \(centerLon)) radius=\(Int(radiusMeters))m")
                #endif
                
                await fetchLeadersForBounds(minLat: minLat, maxLat: maxLat, minLon: minLon, maxLon: maxLon)
            }
        } catch {
            print("⚠️ Geocoding failed for \(cityName): \(error)")
        }
    }
    
    // Legacy functions for backwards compatibility
    private func loadLocalLeadersFromDatabase() async {
        await loadLeadersForCurrentCity()
    }
    
    private func fetchLeadersForVisibleBounds() async {
        await loadLeadersForCurrentCity()
    }
    
    private func fetchLeadersForBounds(minLat: Double, maxLat: Double, minLon: Double, maxLon: Double) async {
        do {
            try await AuthSessionManager.shared.ensureValidSession()
            
            struct LocalLeaderRow: Decodable {
                let owner_id: UUID
                let area_m2: Double
                let tile_count: Int
                let username: String?
                let avatar_url: String?
                let is_pro: Bool?
            }
            
            let results: [LocalLeaderRow] = try await SupabaseConfig.supabase
                .rpc("get_leaderboard_in_bounds", params: [
                    "min_lat": minLat,
                    "min_lon": minLon,
                    "max_lat": maxLat,
                    "max_lon": maxLon,
                    "limit_count": 20
                ])
                .execute()
                .value
            
            // Create leaders with UNIQUE IDs and properly mapped data
            // Use a dictionary to ensure no duplicate owner IDs
            var leaderDict: [String: TerritoryLeader] = [:]
            
            for row in results {
                let odwnerId = row.owner_id.uuidString.lowercased()
                
                // Only add if we haven't seen this owner before (shouldn't happen, but safety check)
                if leaderDict[odwnerId] == nil {
                    leaderDict[odwnerId] = TerritoryLeader(
                        id: odwnerId,
                        name: row.username ?? "Användare",
                        avatarUrl: row.avatar_url,
                        totalArea: row.area_m2,
                        tileCount: row.tile_count,
                        isPro: row.is_pro ?? false
                    )
                }
            }
            
            // Sort by tile count descending
            let leaders = leaderDict.values.sorted { $0.tileCount > $1.tileCount }
            
            // Prefetch avatar images for top leaders to ensure they're cached
            let avatarUrls = leaders.prefix(5).compactMap { $0.avatarUrl }
            if !avatarUrls.isEmpty {
                ImageCacheManager.shared.prefetch(urls: avatarUrls)
            }
            
            await MainActor.run {
                self.localLeaders = leaders
                
                // Update Area Leader (King of the visible area)
                if let first = leaders.first {
                    self.areaLeader = first
                    #if DEBUG
                    print("👑 King of \(currentAreaName): \(first.name) with \(first.tileCount) tiles (avatar: \(first.avatarUrl ?? "none"))")
                    #endif
                } else {
                    self.areaLeader = nil
                }
                
                #if DEBUG
                print("📊 Local leaderboard: \(leaders.count) leaders in visible area (\(currentAreaName))")
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
    
    private func formatTileCount(_ count: Int) -> String {
        if count >= 1000 {
            return "\(count / 1000)k rutor"
        } else {
            return "\(count) rutor"
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
                // Build area name - prefer specific neighborhood/suburb, then city
                // Priority: subLocality (neighborhood) > locality (city) > subAdministrativeArea > administrativeArea
                var areaName: String
                
                if let subLocality = placemark.subLocality, !subLocality.isEmpty {
                    // Use neighborhood/suburb if available (e.g., "Vasastan", "Södermalm")
                    areaName = subLocality
                } else if let locality = placemark.locality, !locality.isEmpty {
                    // Fall back to city/town (e.g., "Stockholm", "Danderyd")
                    areaName = locality
                } else if let subAdmin = placemark.subAdministrativeArea, !subAdmin.isEmpty {
                    // Fall back to sub-administrative area
                    areaName = subAdmin
                } else if let admin = placemark.administrativeArea, !admin.isEmpty {
                    // Fall back to administrative area (county)
                    areaName = admin
                } else {
                    areaName = "Området"
                }
                
                DispatchQueue.main.async {
                    let previousAreaName = self.currentAreaName
                    self.currentAreaName = areaName
                    
                    // If the area changed, refresh leaderboard immediately
                    if previousAreaName != areaName {
                        self.cachedCityName = ""
                        self.cachedCityBounds = nil
                        // Immediate refresh for responsive king updates
                        self.calculateLocalStats()
                        
                        #if DEBUG
                        print("📍 Area changed: \(previousAreaName) → \(areaName)")
                        #endif
                    }
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
            // Calculate tile count from area (each tile is ~625 m²)
            let tileCount = Int(area / 625.0)
            
            if let profile = profilesMap[ownerId] {
                leaders.append(TerritoryLeader(
                    id: profile.id,
                    name: profile.name,
                    avatarUrl: profile.avatarUrl,
                    totalArea: area,
                    tileCount: tileCount,
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
                    tileCount: tileCount,
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
        UIColor(red: 0.20, green: 0.60, blue: 0.90, alpha: 1), // Blue
        UIColor(red: 0.90, green: 0.30, blue: 0.30, alpha: 1), // Red
        UIColor(red: 0.30, green: 0.80, blue: 0.40, alpha: 1), // Green
        UIColor(red: 0.95, green: 0.60, blue: 0.10, alpha: 1), // Orange
        UIColor(red: 0.60, green: 0.30, blue: 0.80, alpha: 1), // Purple
        UIColor(red: 0.10, green: 0.70, blue: 0.70, alpha: 1), // Teal
        UIColor(red: 0.95, green: 0.35, blue: 0.65, alpha: 1), // Pink
        UIColor(red: 0.85, green: 0.75, blue: 0.15, alpha: 1), // Yellow/Gold
        UIColor(red: 0.25, green: 0.35, blue: 0.95, alpha: 1), // Indigo
        UIColor(red: 0.55, green: 0.45, blue: 0.25, alpha: 1), // Brown
        UIColor(red: 0.15, green: 0.85, blue: 0.45, alpha: 1), // Mint
        UIColor(red: 0.65, green: 0.65, blue: 0.75, alpha: 1), // Slate
    ]
    
    static func colorForUser(_ ownerId: String) -> UIColor {
        // Generate consistent color based on owner ID hash
        let hash = abs(ownerId.hashValue)
        let index = hash % colors.count
        return colors[index]
    }
}

// MARK: - Fast Tile Rendering (single overlay)
/// A single overlay that holds many grid tiles to render efficiently.
final class TileGridOverlay: NSObject, MKOverlay {
    struct RenderTile: Sendable {
        let id: Int64
        let ownerId: String?
        let mapRect: MKMapRect
    }
    
    // MKOverlay
    let coordinate: CLLocationCoordinate2D
    let boundingMapRect: MKMapRect
    
    // Render data
    var tiles: [RenderTile] = []
    
    override init() {
        self.boundingMapRect = MKMapRect.world
        self.coordinate = CLLocationCoordinate2D(latitude: 0, longitude: 0)
        super.init()
    }
}

/// Renderer that draws all tiles in one pass (much faster than thousands of MKPolygons).
final class TileGridRenderer: MKOverlayRenderer {
    // Cache colors by owner for fewer allocations
    private var colorCache: [String: UIColor] = [:]
    
    override func draw(_ mapRect: MKMapRect, zoomScale: MKZoomScale, in context: CGContext) {
        guard let grid = overlay as? TileGridOverlay else { return }
        
        // Performance knobs
        // IMPORTANT: No strokes at any zoom level to keep tiles visually "tight" with no gaps/seams.
        let shouldStroke = false
        let zoomedOut = zoomScale < 0.02
        
        context.saveGState()
        context.setAllowsAntialiasing(false)
        context.setShouldAntialias(false)
        
        // Filter to what is actually visible
        var visible = grid.tiles.filter { $0.mapRect.intersects(mapRect) }
        
        if zoomedOut || visible.count > 6000 {
            // IMPORTANT: When zoomed out, we must NOT drop tiles (it creates gaps).
            // Instead, aggregate into larger "super-tiles" in screen-space so coverage stays solid and fast.
            
            // Target bucket size in screen points (bigger when more zoomed out)
            let bucketScreenPts: Double = zoomScale < 0.008 ? 14 : 10
            let bucketMapPts = bucketScreenPts / Double(zoomScale) // screenPts = mapPts * zoomScale
            
            struct BucketKey: Hashable {
                let x: Int
                let y: Int
            }
            
            // Count owners per bucket, pick majority owner
            var buckets: [BucketKey: (rect: MKMapRect, counts: [String: Int], empty: Int)] = [:]
            buckets.reserveCapacity(min(visible.count, 8000))
            
            for t in visible {
                let bx = Int(floor(t.mapRect.midX / bucketMapPts))
                let by = Int(floor(t.mapRect.midY / bucketMapPts))
                let key = BucketKey(x: bx, y: by)
                
                let originX = Double(bx) * bucketMapPts
                let originY = Double(by) * bucketMapPts
                let bucketRect = MKMapRect(x: originX, y: originY, width: bucketMapPts, height: bucketMapPts)
                
                if buckets[key] == nil {
                    buckets[key] = (bucketRect, [:], 0)
                }
                
                if let owner = t.ownerId, !owner.isEmpty {
                    buckets[key]!.counts[owner, default: 0] += 1
                } else {
                    buckets[key]!.empty += 1
                }
            }
            
            for (_, bucket) in buckets {
                // Choose majority owner (or empty if no owner)
                let owner: String? = bucket.counts.max(by: { $0.value < $1.value })?.key
                
                // Inflate to avoid hairline seams due to pixel rounding
                let rect = self.rect(for: bucket.rect).insetBy(dx: -1.2, dy: -1.2)
                
                if let owner, !owner.isEmpty {
                    let fill: UIColor = colorCache[owner] ?? {
                        let c = TerritoryColors.colorForUser(owner)
                        colorCache[owner] = c
                        return c
                    }()
                    context.setFillColor(fill.withAlphaComponent(0.6).cgColor)
                } else {
                    context.setFillColor(UIColor.gray.withAlphaComponent(0.14).cgColor)
                }
                context.fill(rect)
                
                // No strokes when zoomed out (strokes create visible grid lines)
            }
        } else {
            // Zoomed in: draw actual tiles (no gaps), with subtle stroke
            for tile in visible {
                // Inflate slightly to avoid hairline seams due to pixel rounding
                let rect = self.rect(for: tile.mapRect).insetBy(dx: -1.2, dy: -1.2)
                
                if let owner = tile.ownerId, !owner.isEmpty {
                    let fill: UIColor = colorCache[owner] ?? {
                        let c = TerritoryColors.colorForUser(owner)
                        colorCache[owner] = c
                        return c
                    }()
                    context.setFillColor(fill.withAlphaComponent(0.6).cgColor)
                } else {
                    context.setFillColor(UIColor.gray.withAlphaComponent(0.18).cgColor)
                }
                context.fill(rect)
                
                if shouldStroke {
                    context.setLineWidth(max(0.35, 0.7 / zoomScale))
                    if let owner = tile.ownerId, !owner.isEmpty {
                        let stroke = (colorCache[owner] ?? TerritoryColors.colorForUser(owner)).withAlphaComponent(0.35)
                        context.setStrokeColor(stroke.cgColor)
                    } else {
                        context.setStrokeColor(UIColor.gray.withAlphaComponent(0.15).cgColor)
                    }
                    context.stroke(rect)
                }
            }
        }
        
        context.restoreGState()
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
        
        // Also check if map has no overlays but we have territories to show (happens when view is recreated)
        let mapNeedsInitialOverlays = uiView.overlays.isEmpty && !territories.isEmpty
        
        if tilesChanged || territoriesChanged || mapNeedsInitialOverlays {
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
        private var didFallbackCenter = false
        private var currentTileSignature: Set<String> = []
        
        // Single overlay + renderer for fast drawing (tile mode)
        private let tileOverlay = TileGridOverlay()
        private var tileRenderer: TileGridRenderer?
        
        // Bounds index for fast-ish tap hit testing
        private var tileBounds: [(tile: Tile, minLat: Double, maxLat: Double, minLon: Double, maxLon: Double)] = []
        
        // Owner polygon mode
        private var polygonToTerritory: [MKPolygon: Territory] = [:]
        private var territoryPolygons: [MKPolygon] = []
        private var ownerColorMap: [String: UIColor] = [:]
        
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

            // If we're in territory-polygon mode, hit-test the polygon overlays
            if !territoryPolygons.isEmpty {
                for polygon in territoryPolygons {
                    let renderer = MKPolygonRenderer(polygon: polygon)
                    let mapPoint = MKMapPoint(tapCoordinate)
                    let polygonViewPoint = renderer.point(for: mapPoint)
                    if renderer.path?.contains(polygonViewPoint) == true,
                       let territory = polygonToTerritory[polygon] {
                        onTerritoryTapped(territory)
                        return
                    }
                }
                return
            }
            
            // Otherwise, tile mode hit test against tile bounds (fast enough for a few thousand tiles)
            let lat = tapCoordinate.latitude
            let lon = tapCoordinate.longitude
            guard let tapped = tileBounds.first(where: { lat >= $0.minLat && lat <= $0.maxLat && lon >= $0.minLon && lon <= $0.maxLon })?.tile,
                  let ownerId = tapped.ownerId else { return }
            
            // Find all tiles from same activity_id (same workout) for the detail sheet
            let connectedTiles: [Tile]
            if let activityId = tapped.activityId, !activityId.isEmpty {
                connectedTiles = tiles.filter { $0.activityId == activityId }
            } else {
                connectedTiles = [tapped]
            }
            
            let totalArea = Double(connectedTiles.count) * 625.0
            let allPolygons = connectedTiles.map { $0.coordinates }
            
            var aggregatedTerritory = Territory(
                id: UUID(),
                ownerId: ownerId,
                activity: nil,
                area: totalArea,
                polygons: allPolygons,
                tileCount: connectedTiles.count
            )
            aggregatedTerritory.sessionDistance = tapped.distanceKm
            aggregatedTerritory.sessionDuration = tapped.durationSec
            aggregatedTerritory.sessionPace = tapped.pace
            
            onTerritoryTapped(aggregatedTerritory)
        }
        
        func updateMap(_ mapView: MKMapView, territories: [Territory], tiles: [Tile]) {
            // TERRITORY (owner polygon) mode
            if !territories.isEmpty && tiles.isEmpty {
                // Clear tile overlay if present
                if mapView.overlays.contains(where: { $0 === tileOverlay }) {
                    mapView.removeOverlay(tileOverlay)
                }
                
                // Build polygons
                polygonToTerritory.removeAll(keepingCapacity: true)
                territoryPolygons.removeAll(keepingCapacity: true)
                ownerColorMap.removeAll(keepingCapacity: true)
                
                var polys: [MKPolygon] = []
                polys.reserveCapacity(territories.count * 2)
                
                for territory in territories {
                    for ring in territory.polygons {
                        guard ring.count >= 3 else { continue }
                        var coords = ring
                        if let first = coords.first, let last = coords.last,
                           (first.latitude != last.latitude || first.longitude != last.longitude) {
                            coords.append(first)
                        }
                        let poly = MKPolygon(coordinates: coords, count: coords.count)
                        poly.title = territory.ownerId
                        polygonToTerritory[poly] = territory
                        polys.append(poly)
                    }
                }

                // Compute a better local color assignment so adjacent owners don't share colors.
                ownerColorMap = Self.computeNonAdjacentOwnerColors(
                    territories: territories,
                    polygons: polys
                )
                
                // BULLETPROOF: Smart overlay update - avoid flicker
                // Only update if there are actual changes
                let newOwnerIds = Set(polys.compactMap { $0.title })
                let oldOwnerIds = Set(territoryPolygons.compactMap { $0.title })
                
                // Check if we need to update
                let needsUpdate = newOwnerIds != oldOwnerIds || 
                                 polys.count != territoryPolygons.count
                
                if needsUpdate {
                    // Remove overlays that are no longer needed
                    let overlaysToRemove = mapView.overlays.filter { overlay in
                        if let poly = overlay as? MKPolygon {
                            return !newOwnerIds.contains(poly.title ?? "")
                        }
                        return overlay === tileOverlay // Don't remove tile overlay here
                    }
                    
                    if !overlaysToRemove.isEmpty {
                        mapView.removeOverlays(overlaysToRemove)
                    }
                    
                    // Add only new polygons
                    let existingOwners = Set(mapView.overlays.compactMap { ($0 as? MKPolygon)?.title })
                    let newPolys = polys.filter { !existingOwners.contains($0.title ?? "") }
                    
                    if !newPolys.isEmpty {
                        mapView.addOverlays(newPolys, level: .aboveRoads)
                    }
                } else {
                    print("📍 No overlay changes detected - keeping existing overlays")
                }
                
                territoryPolygons = polys
                tileBounds.removeAll(keepingCapacity: true)
                
                return
            }
            
            // TILE mode (fallback)
            territoryPolygons.removeAll(keepingCapacity: true)
            polygonToTerritory.removeAll(keepingCapacity: true)
            
            // Tiles are already viewport-filtered + sampled in TerritoryStore.
            let tilesToRender = tiles
            let newSig = Set(tilesToRender.map { "\($0.id)_\($0.ownerId ?? "")" })
            if newSig == currentTileSignature, !currentTileSignature.isEmpty {
                return
            }
            currentTileSignature = newSig
            
            // Build render tiles (precompute map rects)
            var renderTiles: [TileGridOverlay.RenderTile] = []
            renderTiles.reserveCapacity(tilesToRender.count)
            var boundsIndex: [(Tile, Double, Double, Double, Double)] = []
            boundsIndex.reserveCapacity(tilesToRender.count)
            
            for t in tilesToRender {
                guard t.coordinates.count >= 4 else { continue }
                let lats = t.coordinates.map { $0.latitude }
                let lons = t.coordinates.map { $0.longitude }
                guard let minLat = lats.min(),
                      let maxLat = lats.max(),
                      let minLon = lons.min(),
                      let maxLon = lons.max()
                else { continue }
                
                let nw = MKMapPoint(CLLocationCoordinate2D(latitude: maxLat, longitude: minLon))
                let se = MKMapPoint(CLLocationCoordinate2D(latitude: minLat, longitude: maxLon))
                let rect = MKMapRect(
                    x: min(nw.x, se.x),
                    y: min(nw.y, se.y),
                    width: abs(se.x - nw.x),
                    height: abs(se.y - nw.y)
                )
                
                renderTiles.append(.init(id: t.id, ownerId: t.ownerId, mapRect: rect))
                boundsIndex.append((t, minLat, maxLat, minLon, maxLon))
            }
            
            tileOverlay.tiles = renderTiles
            tileBounds = boundsIndex.map { (tile: $0.0, minLat: $0.1, maxLat: $0.2, minLon: $0.3, maxLon: $0.4) }
            
            // Ensure overlay is added once
            if !mapView.overlays.contains(where: { $0 === tileOverlay }) {
                // Remove old overlays (from older versions)
                if !mapView.overlays.isEmpty {
                    mapView.removeOverlays(mapView.overlays)
                }
                mapView.addOverlay(tileOverlay, level: .aboveRoads)
            } else {
                // Redraw only visible area
                tileRenderer?.setNeedsDisplay(mapView.visibleMapRect)
            }
            
            if !hasCentered {
                // Centering strategy:
                // - Prefer real GPS. Don't "lock in" fallback before userLocation is ready.
                // - If location permission is denied / never comes, do ONE fallback.
                let defaultSpan = MKCoordinateSpan(latitudeDelta: 0.03, longitudeDelta: 0.03) // ~3km, closer to "see my area"
                
                if let userLocation = mapView.userLocation.location {
                    let userRegion = MKCoordinateRegion(center: userLocation.coordinate, span: defaultSpan)
                    mapView.setRegion(userRegion, animated: false)
                    hasCentered = true
                } else if !didFallbackCenter {
                    // Temporary fallback (only once). If GPS arrives later, didUpdate will re-center.
                    didFallbackCenter = true
                    let stockholm = MKCoordinateRegion(
                        center: CLLocationCoordinate2D(latitude: 59.3293, longitude: 18.0686),
                        span: MKCoordinateSpan(latitudeDelta: 0.12, longitudeDelta: 0.12)
                    )
                    mapView.setRegion(stockholm, animated: false)
                    // NOTE: do NOT set hasCentered here, so we can still auto-center when GPS appears.
                }
                
                // Trigger initial region callback
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self, weak mapView] in
                    guard let self = self, let mapView = mapView else { return }
                    self.onRegionChanged(mapView.region, mapView.visibleMapRect)
                }
            }
        }

        func mapView(_ mapView: MKMapView, didUpdate userLocation: MKUserLocation) {
            // As soon as we have a real GPS coordinate, auto-center once.
            guard !hasCentered, let loc = userLocation.location else { return }
            let span = MKCoordinateSpan(latitudeDelta: 0.03, longitudeDelta: 0.03)
            mapView.setRegion(MKCoordinateRegion(center: loc.coordinate, span: span), animated: true)
            hasCentered = true
            
            // Kick region callback so we fetch data around the user immediately
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self, weak mapView] in
                guard let self = self, let mapView = mapView else { return }
                self.onRegionChanged(mapView.region, mapView.visibleMapRect)
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
        
        private var rendererCallCount = 0
        
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if overlay === tileOverlay {
                if let cached = tileRenderer { return cached }
                let r = TileGridRenderer(overlay: overlay)
                tileRenderer = r
                return r
            }
            
            if let polygon = overlay as? MKPolygon {
                let renderer = MKPolygonRenderer(polygon: polygon)
                let ownerId = polygon.title ?? ""
                let color = ownerColorMap[ownerId] ?? TerritoryColors.colorForUser(ownerId)
                renderer.fillColor = color.withAlphaComponent(0.55)
                renderer.strokeColor = UIColor.clear // seamless
                renderer.lineWidth = 0
                return renderer
            }
            return MKOverlayRenderer(overlay: overlay)
        }
    }
}

// MARK: - Owner color assignment (avoid same color touching)
extension ZoneWarMapView.Coordinator {
    /// Greedy graph coloring on owner bounding boxes (viewport-local).
    /// This greatly reduces the chance that two neighboring owners look identical.
    fileprivate static func computeNonAdjacentOwnerColors(
        territories: [Territory],
        polygons: [MKPolygon]
    ) -> [String: UIColor] {
        // Build one bounding rect per owner (union of all polygon bounds for that owner)
        var ownerRects: [String: MKMapRect] = [:]
        ownerRects.reserveCapacity(territories.count)
        
        for poly in polygons {
            let ownerId = poly.title ?? ""
            guard !ownerId.isEmpty else { continue }
            let r = poly.boundingMapRect
            if let existing = ownerRects[ownerId] {
                ownerRects[ownerId] = existing.union(r)
            } else {
                ownerRects[ownerId] = r
            }
        }
        
        // Build adjacency using expanded rect intersection (cheap + good enough visually)
        let ownerIds = Array(ownerRects.keys)
        var neighbors: [String: Set<String>] = Dictionary(uniqueKeysWithValues: ownerIds.map { ($0, []) })
        
        // Pick padding ~40m in map points at mid-latitude of viewport
        let avgLat: Double = {
            let lats = territories.compactMap { $0.polygons.first?.first?.latitude }
            return lats.reduce(0, +) / Double(max(lats.count, 1))
        }()
        let padMapPoints = MKMapPointsPerMeterAtLatitude(avgLat) * 40.0
        
        func expanded(_ rect: MKMapRect) -> MKMapRect {
            rect.insetBy(dx: -padMapPoints, dy: -padMapPoints)
        }
        
        for i in 0..<ownerIds.count {
            let a = ownerIds[i]
            guard let ra = ownerRects[a] else { continue }
            let ea = expanded(ra)
            for j in (i + 1)..<ownerIds.count {
                let b = ownerIds[j]
                guard let rb = ownerRects[b] else { continue }
                if ea.intersects(expanded(rb)) {
                    neighbors[a, default: []].insert(b)
                    neighbors[b, default: []].insert(a)
                }
            }
        }
        
        // Order: larger areas first (harder to color later)
        let territoryAreaByOwner: [String: Double] = Dictionary(
            territories.map { ($0.ownerId, $0.area) },
            uniquingKeysWith: { max($0, $1) }
        )
        let ordered = ownerIds.sorted {
            (territoryAreaByOwner[$0] ?? 0) > (territoryAreaByOwner[$1] ?? 0)
        }
        
        // Greedy assignment from palette
        let palette = TerritoryColors.colors
        var assigned: [String: UIColor] = [:]
        assigned.reserveCapacity(ownerIds.count)
        
        for owner in ordered {
            let usedByNeighbors: Set<UIColor> = Set(neighbors[owner, default: []].compactMap { assigned[$0] })
            if let color = palette.first(where: { !usedByNeighbors.contains($0) }) {
                assigned[owner] = color
            } else {
                // Fallback if palette exhausted (rare)
                assigned[owner] = TerritoryColors.colorForUser(owner)
            }
        }
        
        return assigned
    }
}

// MARK: - Zone War Menu View (Full Page)

struct ZoneWarMenuView: View {
    @Binding var selectedTab: Int
    let leaders: [TerritoryLeader]
    let events: [TerritoryEvent]
    let areaName: String
    var onRefresh: (() async -> Void)? = nil // Callback for pull-to-refresh
    var initialLeaderboardTab: Int? = nil // Optional: open directly to specific tab (0=Local, 1=Sweden, 2=Lottery)
    @Environment(\.dismiss) private var dismiss
    
    // Pro membership
    @State private var isPremium = RevenueCatManager.shared.isProMember
    @State private var showPaywall = false
    
    // Leaderboard type toggle - 0 = Local, 1 = Sweden, 2 = Lotter
    @State private var leaderboardTab: Int = RevenueCatManager.shared.isProMember ? 0 : 1
    @State private var hasSetInitialTab = false
    @State private var swedenLeaders: [TerritoryLeader] = []
    @State private var isLoadingSwedenLeaders = false
    @State private var lotteryLeaders: [LotteryLeader] = []
    @State private var isLoadingLotteryLeaders = false
    
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
                    ForEach(["Topplista", "Övertaganden"], id: \.self) { tab in
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
                                            .foregroundColor(.primary)
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
                    Text(selectedTab == 0 ? "Topplista" : "Övertaganden")
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
            .onReceive(RevenueCatManager.shared.$isProMember) { newValue in
                isPremium = newValue
            }
            .task {
                // Load Sweden leaders immediately for non-Pro users (always refresh)
                if !isPremium {
                    loadSwedenLeaders()
                }
            }
            .onAppear {
                // Set initial leaderboard tab if specified
                if !hasSetInitialTab, let initialTab = initialLeaderboardTab {
                    leaderboardTab = initialTab
                    hasSetInitialTab = true
                    if initialTab == 2 {
                        loadLotteryLeaders()
                    }
                }
            }
        }
    }
    
    // MARK: - Leaderboard View
    
    private var leaderboardView: some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(spacing: 0) {
                // Area toggle picker with 3 tabs
                HStack(spacing: 0) {
                    // Local area button
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            leaderboardTab = 0
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "mappin.circle.fill")
                                .font(.system(size: 12))
                            Text(areaName)
                                .font(.system(size: 12, weight: .semibold))
                                .lineLimit(1)
                        }
                        .foregroundColor(leaderboardTab == 0 ? .black : .gray)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(leaderboardTab == 0 ? Color.yellow : Color.clear)
                        .cornerRadius(16)
                    }
                    
                    // Sweden button
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            leaderboardTab = 1
                        }
                        loadSwedenLeaders()
                    } label: {
                        HStack(spacing: 4) {
                            Text("🇸🇪")
                                .font(.system(size: 12))
                            Text("Sverige")
                                .font(.system(size: 12, weight: .semibold))
                        }
                        .foregroundColor(leaderboardTab == 1 ? .black : .gray)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(leaderboardTab == 1 ? Color.yellow : Color.clear)
                        .cornerRadius(16)
                    }
                    
                    // Lottery button
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            leaderboardTab = 2
                        }
                        loadLotteryLeaders()
                    } label: {
                        HStack(spacing: 4) {
                            Text("🎰")
                                .font(.system(size: 12))
                            Text("Lotter")
                                .font(.system(size: 12, weight: .semibold))
                        }
                        .foregroundColor(leaderboardTab == 2 ? .black : .gray)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(leaderboardTab == 2 ? Color.yellow : Color.clear)
                        .cornerRadius(16)
                    }
                }
                .padding(4)
                .background(Color(red: 0.2, green: 0.2, blue: 0.22))
                .cornerRadius(24)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                
                // Leaderboard content based on tab
                if leaderboardTab == 2 {
                    // Lottery leaderboard
                    lotteryLeaderboardContent
                } else {
                    // Territory leaderboard (local or sweden)
                    territoryLeaderboardContent
                }
            }
            .padding(.top, 8)
            .frame(maxWidth: .infinity)
        }
        .scrollBounceBehavior(.basedOnSize)
        .refreshable {
            if leaderboardTab == 2 {
                loadLotteryLeaders()
            } else {
                loadSwedenLeaders()
            }
            await onRefresh?()
        }
    }
    
    // MARK: - Territory Leaderboard Content
    
    private var territoryLeaderboardContent: some View {
        let isSweden = leaderboardTab == 1
        let displayLeaders = isSweden ? swedenLeaders : leaders.sorted { $0.tileCount > $1.tileCount }
        let maxCount = isSweden ? 20 : displayLeaders.count
        
        return Group {
            if isLoadingSwedenLeaders && isSweden {
                ProgressView()
                    .scaleEffect(1.2)
                    .padding(.top, 40)
            } else {
                LazyVStack(spacing: 0) {
                    ForEach(Array(displayLeaders.prefix(maxCount).enumerated()), id: \.element.id) { index, leader in
                        Button {
                            selectedUserId = leader.id
                            showUserProfile = true
                        } label: {
                            leaderboardRow(index: index, leader: leader)
                        }
                        .buttonStyle(.plain)
                        
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
    }
    
    // MARK: - Lottery Leaderboard Content
    
    private var lotteryLeaderboardContent: some View {
        Group {
            if isLoadingLotteryLeaders {
                ProgressView()
                    .scaleEffect(1.2)
                    .padding(.top, 40)
            } else if lotteryLeaders.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "ticket")
                        .font(.system(size: 48))
                        .foregroundColor(.gray)
                    Text("Ingen lottlista än")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                    Text("Samla lotter genom att erövra områden!")
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                }
                .padding(.top, 60)
            } else {
                LazyVStack(spacing: 0) {
                    ForEach(Array(lotteryLeaders.enumerated()), id: \.element.id) { index, leader in
                        Button {
                            selectedUserId = leader.id
                            showUserProfile = true
                        } label: {
                            lotteryLeaderboardRow(index: index, leader: leader)
                        }
                        .buttonStyle(.plain)
                        
                        if index < lotteryLeaders.count - 1 {
                            Divider()
                                .background(Color.gray.opacity(0.2))
                                .padding(.leading, 66)
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Lottery Leaderboard Row
    
    @ViewBuilder
    private func lotteryLeaderboardRow(index: Int, leader: LotteryLeader) -> some View {
        HStack(spacing: 14) {
            // Rank badge
            ZStack {
                Circle()
                    .fill(rankColor(for: index + 1))
                    .frame(width: 36, height: 36)
                Text("\(index + 1)")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
            }
            
            // Avatar
            if let avatarUrl = leader.avatarUrl, !avatarUrl.isEmpty {
                OptimizedAsyncImage(url: avatarUrl, width: 44, height: 44, cornerRadius: 22)
            } else {
                Circle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 44, height: 44)
                    .overlay(
                        Image(systemName: "person.fill")
                            .foregroundColor(.gray)
                    )
            }
            
            // Name and PRO badge
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(leader.name)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    
                    if leader.isPro {
                        Image("41")
                            .resizable()
                            .renderingMode(.original)
                            .scaledToFit()
                            .frame(height: 16)
                    }
                }
                
                // Crown for #1
                if index == 0 {
                    Text("LOTTMÄSTARE")
                        .font(.system(size: 10, weight: .black))
                        .foregroundColor(.yellow)
                }
            }
            
            Spacer()
            
            // Ticket count
            HStack(spacing: 4) {
                Text("🎫")
                    .font(.system(size: 14))
                Text("\(leader.ticketCount)")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.yellow)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
    
    // MARK: - Load Lottery Leaders
    
    private func loadLotteryLeaders() {
        guard !isLoadingLotteryLeaders else { return }
        
        isLoadingLotteryLeaders = true
        
        Task {
            do {
                struct LotteryLeaderResponse: Decodable {
                    let user_id: String
                    let name: String
                    let avatar_url: String?
                    let ticket_count: Int
                    let is_pro: Bool
                }
                
                let result: [LotteryLeaderResponse] = try await SupabaseConfig.supabase.database
                    .rpc("get_lottery_leaderboard", params: ["limit_count": 20])
                    .execute()
                    .value
                
                let leaders = result.map { entry in
                    LotteryLeader(
                        id: entry.user_id,
                        name: entry.name,
                        avatarUrl: entry.avatar_url,
                        ticketCount: entry.ticket_count,
                        isPro: entry.is_pro
                    )
                }
                
                await MainActor.run {
                    self.lotteryLeaders = leaders
                    self.isLoadingLotteryLeaders = false
                }
                
                print("🎫 Loaded \(leaders.count) lottery leaders")
            } catch {
                print("❌ Failed to load lottery leaderboard: \(error)")
                await MainActor.run {
                    self.isLoadingLotteryLeaders = false
                }
            }
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
                        Text(leaderboardTab == 1 ? "KUNG AV SVERIGE" : "KUNG AV OMRÅDET")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.yellow)
                    }
                }
            }
            
            Spacer()
            
            // Tile count
            Text(formatTileCount(leader.tileCount))
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(.gray)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(index == 0 ? Color.yellow.opacity(0.1) : Color.clear)
    }
    
    private func formatTileCount(_ count: Int) -> String {
        if count >= 1000 {
            return "\(count / 1000)k rutor"
        } else {
            return "\(count) rutor"
        }
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
                    let tile_count: Int
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
                            tileCount: entry.tile_count,
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
                        tileCount: entry.tile_count,
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
                                    .foregroundColor(.primary)
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
            ("Fuse Energy", "46"),
            ("Lonegolf", "14"),
            ("Pliktgolf", "15"),
            ("Zen Energy", "22")
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
