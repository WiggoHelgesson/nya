import SwiftUI
import MapKit
import CoreLocation

struct TerritoryCaptureAnimationView: View {
    let routeCoordinates: [CLLocationCoordinate2D]
    let activityType: String
    let earnedXP: Int
    let onComplete: () -> Void
    
    @State private var routeProgress: CGFloat = 0
    @State private var fillOpacity: CGFloat = 0
    @State private var showXP: Bool = false
    @State private var mapRegion: MKCoordinateRegion
    @State private var animationComplete = false
    
    // Pre-calculated for performance
    private let simplifiedCoordinates: [CLLocationCoordinate2D]
    private let pathPoints: [CGPoint]
    private let bounds: (minLat: Double, maxLat: Double, minLon: Double, maxLon: Double)
    private let hasValidRoute: Bool
    
    init(routeCoordinates: [CLLocationCoordinate2D], activityType: String, earnedXP: Int, onComplete: @escaping () -> Void) {
        self.routeCoordinates = routeCoordinates
        self.activityType = activityType
        self.earnedXP = earnedXP
        self.onComplete = onComplete
        
        // Check if we have valid coordinates
        self.hasValidRoute = routeCoordinates.count >= 3
        
        // Simplify coordinates for smooth animation (max 120 points)
        let simplified = Self.simplifyCoordinates(routeCoordinates, targetCount: 120)
        self.simplifiedCoordinates = simplified
        
        // Calculate bounds
        let lats = simplified.map { $0.latitude }
        let lons = simplified.map { $0.longitude }
        let minLat = lats.min() ?? 59.33
        let maxLat = lats.max() ?? 59.34
        let minLon = lons.min() ?? 18.06
        let maxLon = lons.max() ?? 18.07
        self.bounds = (minLat, maxLat, minLon, maxLon)
        
        // Calculate map region with padding
        let centerLat = (minLat + maxLat) / 2
        let centerLon = (minLon + maxLon) / 2
        let spanLat = max((maxLat - minLat) * 1.4, 0.003)
        let spanLon = max((maxLon - minLon) * 1.4, 0.003)
        let span = max(spanLat, spanLon, 0.005)
        
        self._mapRegion = State(initialValue: MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: centerLat, longitude: centerLon),
            span: MKCoordinateSpan(latitudeDelta: span, longitudeDelta: span)
        ))
        
        // Pre-calculate path points (will be set properly in body based on geometry)
        self.pathPoints = []
    }
    
    private var activityColor: Color {
        switch activityType.lowercased() {
        case "running", "löpning": return Color.orange
        case "golf": return Color.green
        case "skiing", "skidåkning": return Color.blue
        default: return Color.purple
        }
    }
    
    private var activityIcon: String {
        switch activityType.lowercased() {
        case "running", "löpning": return "figure.run"
        case "golf": return "figure.golf"
        case "skiing", "skidåkning": return "figure.skiing.downhill"
        default: return "mappin.circle.fill"
        }
    }
    
    var body: some View {
        ZStack {
            // White background
            Color.white
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                HStack(spacing: 10) {
                    Image(systemName: activityIcon)
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.primary)
                    
                    Text("Nytt territorium!")
                        .font(.system(size: 28, weight: .black))
                        .foregroundColor(.primary)
                }
                .padding(.top, 60)
                .opacity(showXP ? 1 : 0)
                .animation(.easeOut(duration: 0.4), value: showXP)
                
                Spacer()
                
                // Map animation container
                GeometryReader { geometry in
                    let size = min(geometry.size.width - 40, geometry.size.height - 100)
                    
                    ZStack {
                        // Static map snapshot background
                        MapSnapshotView(region: mapRegion, size: CGSize(width: size, height: size))
                            .frame(width: size, height: size)
                            .clipShape(RoundedRectangle(cornerRadius: 20))
                            .overlay(
                                RoundedRectangle(cornerRadius: 20)
                                    .stroke(Color(.systemGray4), lineWidth: 1)
                            )
                            .shadow(color: .black.opacity(0.1), radius: 10, y: 5)
                        
                        // Animated path overlay
                        Canvas { context, canvasSize in
                            let points = convertToCanvasPoints(
                                coordinates: simplifiedCoordinates,
                                canvasSize: canvasSize
                            )
                            
                            guard points.count >= 3 else { return }
                            
                            // Draw filled area
                            if fillOpacity > 0 {
                                var fillPath = Path()
                                fillPath.move(to: points[0])
                                for point in points.dropFirst() {
                                    fillPath.addLine(to: point)
                                }
                                fillPath.closeSubpath()
                                
                                context.opacity = fillOpacity * 0.35
                                context.fill(fillPath, with: .color(activityColor))
                            }
                            
                            // Draw route line
                            if routeProgress > 0 {
                                var routePath = Path()
                                routePath.move(to: points[0])
                                
                                for point in points.dropFirst() {
                                    routePath.addLine(to: point)
                                }
                                routePath.closeSubpath()
                                
                                // Draw the route stroke
                                context.opacity = 1
                                context.stroke(
                                    routePath,
                                    with: .color(activityColor),
                                    style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round)
                                )
                            }
                            
                            // Draw start point
                            if routeProgress > 0, let first = points.first {
                                let startCircle = Path(ellipseIn: CGRect(
                                    x: first.x - 6,
                                    y: first.y - 6,
                                    width: 12,
                                    height: 12
                                ))
                                context.opacity = 1
                                context.fill(startCircle, with: .color(.green))
                                context.stroke(startCircle, with: .color(.white), lineWidth: 2)
                            }
                            
                            // Draw end point
                            if routeProgress >= 1, let last = points.last {
                                let endCircle = Path(ellipseIn: CGRect(
                                    x: last.x - 6,
                                    y: last.y - 6,
                                    width: 12,
                                    height: 12
                                ))
                                context.opacity = 1
                                context.fill(endCircle, with: .color(.red))
                                context.stroke(endCircle, with: .color(.white), lineWidth: 2)
                            }
                        }
                        .frame(width: size, height: size)
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                        .drawingGroup() // GPU acceleration
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .padding(.horizontal, 20)
                
                Spacer()
                
                // Create post button
                Button(action: onComplete) {
                    HStack(spacing: 12) {
                        Image(systemName: "square.and.pencil")
                            .font(.system(size: 20, weight: .bold))
                        
                        Text("Skapa inlägg")
                            .font(.system(size: 18, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(Color.black)
                    .cornerRadius(16)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 50)
                .opacity(showXP ? 1 : 0)
                .animation(.easeOut(duration: 0.4).delay(0.3), value: showXP)
            }
        }
        .onAppear {
            startAnimation()
        }
    }
    
    private func startAnimation() {
        // Show everything smoothly and quickly
        withAnimation(.easeOut(duration: 0.5)) {
            routeProgress = 1.0
            fillOpacity = 1.0
            showXP = true
            animationComplete = true
        }
    }
    
    private func skipToEnd() {
        // Instantly complete all animations
        withAnimation(.easeOut(duration: 0.2)) {
            routeProgress = 1.0
            fillOpacity = 1.0
            showXP = true
            animationComplete = true
        }
    }
    
    private func convertToCanvasPoints(coordinates: [CLLocationCoordinate2D], canvasSize: CGSize) -> [CGPoint] {
        guard !coordinates.isEmpty else { return [] }
        
        let padding: CGFloat = 30
        let drawableWidth = canvasSize.width - (padding * 2)
        let drawableHeight = canvasSize.height - (padding * 2)
        
        let latRange = bounds.maxLat - bounds.minLat
        let lonRange = bounds.maxLon - bounds.minLon
        
        guard latRange > 0, lonRange > 0 else { return [] }
        
        return coordinates.map { coord in
            let x = padding + ((coord.longitude - bounds.minLon) / lonRange) * drawableWidth
            let y = padding + ((bounds.maxLat - coord.latitude) / latRange) * drawableHeight
            return CGPoint(x: x, y: y)
        }
    }
    
    private static func simplifyCoordinates(_ coordinates: [CLLocationCoordinate2D], targetCount: Int) -> [CLLocationCoordinate2D] {
        guard coordinates.count > targetCount else { return coordinates }
        
        let step = Double(coordinates.count) / Double(targetCount)
        var result: [CLLocationCoordinate2D] = []
        
        for i in 0..<targetCount {
            let index = Int(Double(i) * step)
            if index < coordinates.count {
                result.append(coordinates[index])
            }
        }
        
        // Always include the last point if not already there
        if let last = coordinates.last {
            if let resultLast = result.last {
                // Check if coordinates are different
                if resultLast.latitude != last.latitude || resultLast.longitude != last.longitude {
                    result.append(last)
                }
            } else {
                result.append(last)
            }
        }
        
        return result
    }
}

// MARK: - Static Map Snapshot
struct MapSnapshotView: View {
    let region: MKCoordinateRegion
    let size: CGSize
    
    @State private var snapshot: UIImage?
    
    var body: some View {
        Group {
            if let snapshot = snapshot {
                Image(uiImage: snapshot)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                Rectangle()
                    .fill(Color(.systemGray6))
                    .overlay(
                        ProgressView()
                            .tint(.gray)
                    )
            }
        }
        .task {
            await generateSnapshot()
        }
    }
    
    private func generateSnapshot() async {
        let options = MKMapSnapshotter.Options()
        options.region = region
        options.size = size
        options.scale = UIScreen.main.scale
        options.mapType = .standard
        
        let snapshotter = MKMapSnapshotter(options: options)
        
        do {
            let result = try await snapshotter.start()
            await MainActor.run {
                self.snapshot = result.image
            }
        } catch {
            print("Failed to generate map snapshot: \(error)")
        }
    }
}

// MARK: - Preview
#Preview {
    TerritoryCaptureAnimationView(
        routeCoordinates: [
            CLLocationCoordinate2D(latitude: 59.3293, longitude: 18.0686),
            CLLocationCoordinate2D(latitude: 59.3310, longitude: 18.0700),
            CLLocationCoordinate2D(latitude: 59.3320, longitude: 18.0720),
            CLLocationCoordinate2D(latitude: 59.3300, longitude: 18.0740),
            CLLocationCoordinate2D(latitude: 59.3280, longitude: 18.0700),
            CLLocationCoordinate2D(latitude: 59.3293, longitude: 18.0686)
        ],
        activityType: "Running",
        earnedXP: 150,
        onComplete: {}
    )
}

