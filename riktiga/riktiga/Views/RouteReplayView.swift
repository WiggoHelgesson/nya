import SwiftUI
import MapKit

// MARK: - RouteReplayView

struct RouteReplayView: View {
    let post: SocialWorkoutPost
    @Environment(\.dismiss) private var dismiss

    @State private var coordinates: [CLLocationCoordinate2D] = []
    @State private var progress: Double = 0.0
    @State private var isPlaying = false
    @State private var playbackSpeed: Double = 10.0
    @State private var timer: Timer?
    @State private var hasStarted = false

    private let speedOptions: [Double] = [10, 20, 50, 100]
    private let speedLabels: [Double: String] = [10: "1x", 20: "2x", 50: "5x", 100: "10x"]

    private var totalDuration: Double {
        Double(post.duration ?? 0)
    }

    private var totalDistance: Double {
        post.distance ?? 0.0
    }

    private var currentDistance: String {
        let d = progress * totalDistance
        return String(format: "%.1f", d)
    }

    private var currentElevation: String {
        let e = post.elevationGain ?? 0
        return "\(Int(progress * e))"
    }

    private var currentElapsedTime: String {
        let elapsed = progress * totalDuration
        let minutes = Int(elapsed) / 60
        let seconds = Int(elapsed) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    private var currentPace: String {
        let elapsed = progress * totalDuration
        let dist = progress * totalDistance
        guard dist > 0.05 else { return "0:00" }
        let paceSeconds = elapsed / dist
        if paceSeconds > 1800 { return "0:00" }
        let m = Int(paceSeconds) / 60
        let s = Int(paceSeconds) % 60
        return String(format: "%d:%02d", m, s)
    }

    var body: some View {
        ZStack {
            if coordinates.count >= 2 {
                RouteReplayMapView(
                    coordinates: coordinates,
                    progress: progress
                )
                .ignoresSafeArea()
                .allowsHitTesting(false)
            } else {
                Color.black.ignoresSafeArea()
                ProgressView()
                    .tint(.white)
            }

            VStack(spacing: 0) {
                topStatsBar
                Spacer()
                bottomControls
            }
        }
        .statusBarHidden()
        .onAppear {
            coordinates = parseRouteData(post.routeData)
        }
        .onDisappear {
            stopPlayback()
        }
    }

    // MARK: - Top Stats

    private var topStatsBar: some View {
        VStack(spacing: 12) {
            HStack {
                Button {
                    stopPlayback()
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 40, height: 40)
                        .background(Circle().fill(Color.black.opacity(0.5)))
                }
                Spacer()
            }
            .padding(.horizontal, 16)
            
            HStack(spacing: 0) {
                statColumn(value: currentPace, unit: "/km", label: "Pace")
                statColumn(value: currentElevation, unit: "m", label: "Elevation")
                statColumn(value: currentDistance, unit: "km", label: "Distance")
            }
            .padding(.horizontal, 8)
        }
        .padding(.top, 56)
        .padding(.bottom, 16)
        .background(
            LinearGradient(
                colors: [Color.black.opacity(0.7), Color.black.opacity(0.0)],
                startPoint: .top,
                endPoint: .bottom
            )
            .allowsHitTesting(false)
        )
    }

    private func statColumn(value: String, unit: String, label: String) -> some View {
        VStack(spacing: 2) {
            HStack(alignment: .lastTextBaseline, spacing: 2) {
                Text(value)
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                Text(unit)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
            }
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.white.opacity(0.5))
                .textCase(.uppercase)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Bottom Controls

    @GestureState private var isDraggingSlider = false

    private var elapsedTimeLabel: String {
        let elapsed = progress * totalDuration
        let m = Int(elapsed) / 60
        let s = Int(elapsed) % 60
        return String(format: "%d:%02d", m, s)
    }

    private var totalTimeLabel: String {
        let m = Int(totalDuration) / 60
        let s = Int(totalDuration) % 60
        return String(format: "%d:%02d", m, s)
    }

    private var bottomControls: some View {
        VStack(spacing: 10) {
            // Timeline scrubber
            VStack(spacing: 6) {
                GeometryReader { geo in
                    let width = geo.size.width
                    let thumbX = progress * width

                    ZStack(alignment: .leading) {
                        // Track background
                        Capsule()
                            .fill(Color.white.opacity(0.25))
                            .frame(height: 6)

                        // Filled track
                        Capsule()
                            .fill(Color.white)
                            .frame(width: max(0, thumbX), height: 6)

                        // Thumb
                        Circle()
                            .fill(Color.white)
                            .frame(width: isDraggingSlider ? 22 : 16, height: isDraggingSlider ? 22 : 16)
                            .shadow(color: .black.opacity(0.4), radius: 4, x: 0, y: 2)
                            .offset(x: max(0, min(thumbX - (isDraggingSlider ? 11 : 8), width - (isDraggingSlider ? 22 : 16))))
                    }
                    .contentShape(Rectangle().inset(by: -20))
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .updating($isDraggingSlider) { _, state, _ in
                                state = true
                            }
                            .onChanged { value in
                                if isPlaying { pausePlayback() }
                                let newProgress = max(0, min(1, value.location.x / width))
                                progress = newProgress
                            }
                    )
                }
                .frame(height: 22)

                // Time labels
                HStack {
                    Text(elapsedTimeLabel)
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundColor(.white.opacity(0.7))
                    Spacer()
                    Text(totalTimeLabel)
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundColor(.white.opacity(0.5))
                }
            }
            .padding(.horizontal, 20)

            // Play/Pause + Speed
            HStack {
                Button {
                    if isPlaying {
                        pausePlayback()
                    } else {
                        startPlayback()
                    }
                } label: {
                    Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 22))
                        .foregroundColor(.white)
                        .frame(width: 50, height: 50)
                        .background(Circle().fill(Color.white.opacity(0.15)))
                }

                Spacer()

                Button {
                    cycleSpeed()
                } label: {
                    Text(speedLabels[playbackSpeed] ?? "\(Int(playbackSpeed))x")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .frame(minWidth: 48, minHeight: 40)
                        .padding(.horizontal, 8)
                        .background(Capsule().fill(Color.white.opacity(0.2)))
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 36)
        }
        .padding(.top, 16)
        .background(
            LinearGradient(
                colors: [Color.black.opacity(0.0), Color.black.opacity(0.7)],
                startPoint: .top,
                endPoint: .bottom
            )
            .allowsHitTesting(false)
        )
    }

    // MARK: - Playback

    private func startPlayback() {
        guard coordinates.count >= 2, totalDuration > 0 else { return }
        if progress >= 0.999 { progress = 0 }
        isPlaying = true
        hasStarted = true

        let tickInterval: TimeInterval = 1.0 / 30.0
        let progressPerTick = (playbackSpeed * tickInterval) / max(totalDuration, 1)

        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: tickInterval, repeats: true) { _ in
            DispatchQueue.main.async {
                progress += progressPerTick
                if progress >= 1.0 {
                    progress = 1.0
                    pausePlayback()
                }
            }
        }
    }

    private func pausePlayback() {
        isPlaying = false
        timer?.invalidate()
        timer = nil
    }

    private func stopPlayback() {
        pausePlayback()
        progress = 0
    }

    private func cycleSpeed() {
        if let idx = speedOptions.firstIndex(of: playbackSpeed) {
            playbackSpeed = speedOptions[(idx + 1) % speedOptions.count]
        } else {
            playbackSpeed = 1
        }
        if isPlaying {
            pausePlayback()
            startPlayback()
        }
    }

    // MARK: - Route Parsing

    private func parseRouteData(_ json: String?) -> [CLLocationCoordinate2D] {
        guard let json = json, let data = json.data(using: .utf8) else { return [] }
        guard let arr = try? JSONSerialization.jsonObject(with: data) as? [[String: Double]] else { return [] }
        return arr.compactMap { dict in
            guard let lat = dict["lat"], let lon = dict["lon"] else { return nil }
            return CLLocationCoordinate2D(latitude: lat, longitude: lon)
        }
    }
}

// MARK: - RouteReplayMapView (UIViewRepresentable)

struct RouteReplayMapView: UIViewRepresentable {
    let coordinates: [CLLocationCoordinate2D]
    let progress: Double

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.mapType = .hybridFlyover
        mapView.isZoomEnabled = false
        mapView.isScrollEnabled = false
        mapView.isRotateEnabled = false
        mapView.isPitchEnabled = false
        mapView.showsCompass = false
        mapView.showsUserLocation = false
        mapView.pointOfInterestFilter = .excludingAll

        // Full route (dim)
        if coordinates.count >= 2 {
            let fullPolyline = MKPolyline(coordinates: coordinates, count: coordinates.count)
            fullPolyline.title = "full"
            mapView.addOverlay(fullPolyline, level: .aboveRoads)
        }

        // Start annotation
        if let first = coordinates.first {
            let ann = MKPointAnnotation()
            ann.coordinate = first
            ann.title = "start"
            mapView.addAnnotation(ann)
        }

        // Moving dot annotation
        let dot = MKPointAnnotation()
        dot.title = "current"
        dot.coordinate = coordinates.first ?? CLLocationCoordinate2D()
        mapView.addAnnotation(dot)
        context.coordinator.movingDot = dot

        // Initial camera
        if let first = coordinates.first {
            let heading = coordinates.count > 1 ? Self.heading(from: first, to: coordinates[1]) : 0
            let camera = MKMapCamera(
                lookingAtCenter: first,
                fromDistance: 800,
                pitch: 65,
                heading: heading
            )
            mapView.setCamera(camera, animated: false)
        }

        context.coordinator.mapView = mapView
        context.coordinator.allCoordinates = coordinates
        return mapView
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        let coord = context.coordinator
        let clamped = min(max(progress, 0), 1)
        let count = coordinates.count
        guard count >= 2 else { return }

        let exactIndex = clamped * Double(count - 1)
        let lowerIndex = Int(exactIndex)
        let upperIndex = min(lowerIndex + 1, count - 1)
        let fraction = exactIndex - Double(lowerIndex)

        let from = coordinates[lowerIndex]
        let to = coordinates[upperIndex]
        let currentLat = from.latitude + (to.latitude - from.latitude) * fraction
        let currentLon = from.longitude + (to.longitude - from.longitude) * fraction
        let currentCoord = CLLocationCoordinate2D(latitude: currentLat, longitude: currentLon)

        // Update moving dot
        coord.movingDot?.coordinate = currentCoord

        // Update progress polyline
        let progressCount = upperIndex + 1
        if progressCount >= 2 {
            var progressCoords = Array(coordinates.prefix(progressCount))
            progressCoords[progressCoords.count - 1] = currentCoord

            if let existing = coord.progressOverlay {
                mapView.removeOverlay(existing)
            }
            let progressLine = MKPolyline(coordinates: progressCoords, count: progressCoords.count)
            progressLine.title = "progress"
            mapView.addOverlay(progressLine, level: .aboveRoads)
            coord.progressOverlay = progressLine
        }

        // Camera: look from slightly behind current position toward next points
        let lookAheadIndex = min(upperIndex + 3, count - 1)
        let lookAhead = coordinates[lookAheadIndex]
        let heading = Self.heading(from: currentCoord, to: lookAhead)

        let camera = MKMapCamera(
            lookingAtCenter: currentCoord,
            fromDistance: 800,
            pitch: 65,
            heading: heading
        )
        UIView.animate(withDuration: 0.15, delay: 0, options: [.curveLinear]) {
            mapView.camera = camera
        }
    }

    // MARK: - Heading calculation

    static func heading(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> CLLocationDirection {
        let lat1 = from.latitude * .pi / 180
        let lat2 = to.latitude * .pi / 180
        let dLon = (to.longitude - from.longitude) * .pi / 180
        let y = sin(dLon) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon)
        var bearing = atan2(y, x) * 180 / .pi
        if bearing < 0 { bearing += 360 }
        return bearing
    }

    // MARK: - Coordinator

    class Coordinator: NSObject, MKMapViewDelegate {
        var mapView: MKMapView?
        var movingDot: MKPointAnnotation?
        var progressOverlay: MKPolyline?
        var allCoordinates: [CLLocationCoordinate2D] = []

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let polyline = overlay as? MKPolyline {
                let renderer = MKPolylineRenderer(polyline: polyline)
                if polyline.title == "full" {
                    renderer.strokeColor = UIColor.white.withAlphaComponent(0.3)
                    renderer.lineWidth = 4
                    renderer.lineCap = .round
                    renderer.lineJoin = .round
                } else {
                    renderer.strokeColor = UIColor.black
                    renderer.lineWidth = 5
                    renderer.lineCap = .round
                    renderer.lineJoin = .round
                }
                return renderer
            }
            return MKOverlayRenderer(overlay: overlay)
        }

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            if annotation is MKUserLocation { return nil }
            guard let point = annotation as? MKPointAnnotation else { return nil }

            if point.title == "start" {
                let id = "start"
                let view = mapView.dequeueReusableAnnotationView(withIdentifier: id) ?? MKAnnotationView(annotation: annotation, reuseIdentifier: id)
                view.annotation = annotation
                view.canShowCallout = false
                let size: CGFloat = 14
                let renderer = UIGraphicsImageRenderer(size: CGSize(width: size, height: size))
                view.image = renderer.image { ctx in
                    UIColor.systemGreen.setFill()
                    ctx.cgContext.fillEllipse(in: CGRect(x: 0, y: 0, width: size, height: size))
                    UIColor.white.setStroke()
                    ctx.cgContext.setLineWidth(2)
                    ctx.cgContext.strokeEllipse(in: CGRect(x: 1, y: 1, width: size - 2, height: size - 2))
                }
                view.centerOffset = CGPoint(x: 0, y: 0)
                return view
            }

            if point.title == "current" {
                let id = "current"
                let view = mapView.dequeueReusableAnnotationView(withIdentifier: id) ?? MKAnnotationView(annotation: annotation, reuseIdentifier: id)
                view.annotation = annotation
                view.canShowCallout = false
                let size: CGFloat = 18
                let renderer = UIGraphicsImageRenderer(size: CGSize(width: size, height: size))
                view.image = renderer.image { ctx in
                    UIColor.black.setFill()
                    ctx.cgContext.fillEllipse(in: CGRect(x: 0, y: 0, width: size, height: size))
                    UIColor.white.setStroke()
                    ctx.cgContext.setLineWidth(2.5)
                    ctx.cgContext.strokeEllipse(in: CGRect(x: 1.25, y: 1.25, width: size - 2.5, height: size - 2.5))
                }
                view.centerOffset = CGPoint(x: 0, y: 0)
                view.layer.zPosition = 100
                return view
            }

            return nil
        }
    }
}
