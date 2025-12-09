import SwiftUI
import MapKit
import Supabase

// Cache for territory owner profiles
private actor TerritoryProfileCache {
    static let shared = TerritoryProfileCache()
    private var cache: [String: TerritoryOwnerProfile] = [:]
    
    func get(_ id: String) -> TerritoryOwnerProfile? {
        return cache[id]
    }
    
    func set(_ profile: TerritoryOwnerProfile, for id: String) {
        cache[id] = profile
    }
}

struct TerritoryDetailView: View {
    let territory: Territory
    @Environment(\.dismiss) private var dismiss
    
    @State private var ownerProfile: TerritoryOwnerProfile?
    @State private var isLoadingProfile = true
    @State private var showUserProfile = false
    @State private var locationName: String = "Sverige"
    @State private var isInitialLoading = true
    
    var body: some View {
        ZStack {
            // Background color - prevents white flash
            Color.black.ignoresSafeArea()
            
            if isInitialLoading {
                // Loading state
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.2)
                        .tint(.white)
                    
                    Text("Laddar...")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                }
            } else {
                // Main content
                NavigationStack {
                    VStack(spacing: 0) {
                        // Close button at top
                        HStack {
                            Spacer()
                            Button {
                                dismiss()
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.title)
                                    .foregroundStyle(.white.opacity(0.8), .black.opacity(0.3))
                            }
                            .padding(.trailing, 16)
                            .padding(.top, 16)
                        }
                        .zIndex(1)
                        
                        // Map showing territory
                        TerritoryMapPreview(territory: territory)
                            .frame(height: UIScreen.main.bounds.height * 0.4)
                            .offset(y: -40)
                        
                        // Info card at bottom
                        infoCard
                            .offset(y: -40)
                    }
                    .background(Color.black)
                    .navigationBarHidden(true)
                    .navigationDestination(isPresented: $showUserProfile) {
                        if let profile = ownerProfile {
                            UserProfileView(userId: profile.id)
                        }
                    }
                }
            }
        }
        .task {
            // Load data immediately
            async let profileTask: () = loadOwnerProfile()
            async let locationTask: () = loadLocationName()
            _ = await (profileTask, locationTask)
            
            await MainActor.run {
                withAnimation(.easeOut(duration: 0.15)) {
                    isInitialLoading = false
                }
            }
        }
    }
    
    // MARK: - Info Card
    
    private var infoCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header with profile, name, date
            HStack(alignment: .top) {
                Button {
                    if ownerProfile != nil {
                        showUserProfile = true
                    }
                } label: {
                    HStack(spacing: 12) {
                        // Profile image with loading state
                        ZStack {
                            Circle()
                                .fill(Color.gray.opacity(0.3))
                                .frame(width: 50, height: 50)
                            
                            if isLoadingProfile {
                                ProgressView()
                                    .scaleEffect(0.7)
                                    .tint(.white)
                            } else {
                                ProfileImage(url: ownerProfile?.avatarUrl, size: 50)
                            }
                        }
                        
                        // Name and date
                        VStack(alignment: .leading, spacing: 4) {
                            if isLoadingProfile {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color.gray.opacity(0.3))
                                    .frame(width: 100, height: 18)
                            } else {
                                Text(ownerProfile?.name ?? "Okänd")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(.white)
                            }
                            
                            if let createdAt = territory.createdAt {
                                Text(formattedDate(createdAt))
                                    .font(.system(size: 14))
                                    .foregroundColor(.gray)
                            } else {
                                Text("Nyligen")
                                    .font(.system(size: 14))
                                    .foregroundColor(.gray)
                            }
                            
                            Text(locationName)
                                .font(.system(size: 14))
                                .foregroundColor(.gray)
                        }
                    }
                }
                .buttonStyle(.plain)
                .disabled(isLoadingProfile)
                
                Spacer()
                
                // Menu button
                Button {
                    // TODO: Show menu options
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.title2)
                        .foregroundColor(.white)
                        .padding(8)
                }
            }
            
            // Activity type
            Text(activityName)
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(.white)
                .italic()
            
            // Stats row - always visible with actual data
            HStack(spacing: 0) {
                // Distance
                StatItem(
                    value: formatDistance(territory.sessionDistance),
                    label: "Km",
                    color: .white
                )
                
                // Duration
                StatItem(
                    value: formatDuration(territory.sessionDuration),
                    label: "Tid",
                    color: .white
                )
                
                // Pace
                StatItem(
                    value: formatPace(territory.sessionPace),
                    label: "Min/km",
                    color: .white
                )
                
                // Territory area - always has data
                StatItem(
                    value: formatArea(territory.area),
                    label: "Km²",
                    color: .green
                )
            }
            .padding(.top, 8)
            
            Spacer(minLength: 20)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color(red: 0.12, green: 0.12, blue: 0.14))
        )
        .padding(.horizontal, 12)
        .padding(.bottom, 12)
        .offset(y: -20)
    }
    
    // MARK: - Helpers
    
    private var activityName: String {
        switch territory.activity {
        case .running: return "Löppass"
        case .golf: return "Golfrunda"
        case .skiing: return "Skidpass"
        case .hiking: return "Vandring"
        default: return "Aktivitet"
        }
    }
    
    private func formatDistance(_ distance: Double?) -> String {
        guard let distance = distance, distance > 0 else { return "--" }
        return String(format: "%.2f", distance)
    }
    
    private func formatDuration(_ seconds: Int?) -> String {
        guard let seconds = seconds, seconds > 0 else { return "--" }
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        let secs = seconds % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        } else {
            return String(format: "%d:%02d", minutes, secs)
        }
    }
    
    private func formatPace(_ pace: String?) -> String {
        guard let pace = pace, pace != "0:00", !pace.isEmpty else { return "--" }
        return pace
    }
    
    private func formatArea(_ area: Double) -> String {
        let km2 = area / 1_000_000
        if km2 >= 1 {
            return String(format: "%.2f", km2)
        } else if km2 >= 0.1 {
            return String(format: "%.2f", km2)
        } else {
            return String(format: "%.4f", km2)
        }
    }
    
    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE d MMMM HH:mm"
        formatter.locale = Locale(identifier: "sv_SE")
        return formatter.string(from: date)
    }
    
    private func loadOwnerProfile() async {
        // Check cache first
        if let cached = await TerritoryProfileCache.shared.get(territory.ownerId) {
            await MainActor.run {
                self.ownerProfile = cached
                self.isLoadingProfile = false
            }
            return
        }
        
        do {
            let profile: TerritoryOwnerProfile = try await SupabaseConfig.supabase.database
                .from("profiles")
                .select("id, username, avatar_url, is_pro")
                .eq("id", value: territory.ownerId)
                .single()
                .execute()
                .value
            
            // Cache the profile
            await TerritoryProfileCache.shared.set(profile, for: territory.ownerId)
            
            // Prefetch avatar image
            if let avatarUrl = profile.avatarUrl {
                ImageCacheManager.shared.prefetch(urls: [avatarUrl])
            }
            
            await MainActor.run {
                self.ownerProfile = profile
                self.isLoadingProfile = false
            }
        } catch {
            print("Failed to load owner profile: \(error)")
            await MainActor.run {
                self.isLoadingProfile = false
            }
        }
    }
    
    private func loadLocationName() async {
        // Get center of the territory for reverse geocoding
        guard let firstPolygon = territory.polygons.first, !firstPolygon.isEmpty else { return }
        
        // Calculate center
        let latSum = firstPolygon.reduce(0.0) { $0 + $1.latitude }
        let lonSum = firstPolygon.reduce(0.0) { $0 + $1.longitude }
        let center = CLLocation(
            latitude: latSum / Double(firstPolygon.count),
            longitude: lonSum / Double(firstPolygon.count)
        )
        
        let geocoder = CLGeocoder()
        do {
            let placemarks = try await geocoder.reverseGeocodeLocation(center)
            if let placemark = placemarks.first {
                let name = placemark.locality ?? placemark.subAdministrativeArea ?? placemark.administrativeArea ?? "Sverige"
                await MainActor.run {
                    self.locationName = "\(name), Sverige"
                }
            }
        } catch {
            print("Reverse geocoding failed: \(error)")
        }
    }
}

// MARK: - Territory Map Preview

struct TerritoryMapPreview: UIViewRepresentable {
    let territory: Territory
    
    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.isUserInteractionEnabled = true
        mapView.isScrollEnabled = true
        mapView.isZoomEnabled = true
        mapView.pointOfInterestFilter = .excludingAll
        mapView.mapType = .standard
        
        // Add overlays immediately
        addOverlays(to: mapView)
        
        return mapView
    }
    
    func updateUIView(_ mapView: MKMapView, context: Context) {
        // Only update if needed
        if mapView.overlays.isEmpty {
            addOverlays(to: mapView)
        }
    }
    
    private func addOverlays(to mapView: MKMapView) {
        mapView.removeOverlays(mapView.overlays)
        
        for ring in territory.polygons {
            guard ring.count >= 3 else { continue }
            
            var coordinates = ring
            if let first = coordinates.first, let last = coordinates.last {
                if first.latitude != last.latitude || first.longitude != last.longitude {
                    coordinates.append(first)
                }
            }
            
            let polygon = MKPolygon(coordinates: coordinates, count: coordinates.count)
            polygon.title = territory.activity?.rawValue
            mapView.addOverlay(polygon)
            
            // Center on polygon
            let rect = polygon.boundingMapRect
            let expandedRect = rect.insetBy(dx: -rect.size.width * 0.3, dy: -rect.size.height * 0.3)
            mapView.setVisibleMapRect(expandedRect, animated: false)
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    class Coordinator: NSObject, MKMapViewDelegate {
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            guard let polygon = overlay as? MKPolygon else {
                return MKOverlayRenderer(overlay: overlay)
            }
            
            let renderer = MKPolygonRenderer(polygon: polygon)
            let color = polygon.activityColor
            
            renderer.fillColor = color.withAlphaComponent(0.4)
            renderer.strokeColor = color
            renderer.lineWidth = 3
            
            return renderer
        }
    }
}

// MARK: - Stat Item

private struct StatItem: View {
    let value: String
    let label: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(color)
            
            Text(label)
                .font(.system(size: 12))
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity)
    }
}
