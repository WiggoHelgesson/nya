import SwiftUI
import MapKit
import CoreLocation
import Combine
import UIKit

struct StartSessionView: View {
    private let initialActivity: ActivityType?
    @State private var showActivitySelection: Bool
    @State private var selectedActivityType: ActivityType?
    @State private var carouselSelection: ActivityType = .walking
    @ObservedObject private var sessionManager = SessionManager.shared
    @ObservedObject private var locationManager = LocationManager.shared
    @State private var forceNewSession = false
    @Environment(\.dismiss) private var dismiss
    
    init(initialActivity: ActivityType? = nil) {
        self.initialActivity = initialActivity
        _showActivitySelection = State(initialValue: initialActivity == nil)
        _selectedActivityType = State(initialValue: initialActivity)
        _forceNewSession = State(initialValue: initialActivity != nil)
    }
    
    var body: some View {
        Group {
            if sessionManager.hasActiveSession && !forceNewSession, let session = sessionManager.activeSession {
                // Resume active session
                if let activity = ActivityType(rawValue: session.activityType) {
                    if activity == .walking {
                        // Show GymSessionView for gym sessions
                        GymSessionView()
                    } else {
                        SessionMapView(activity: activity, isPresented: $showActivitySelection, resumeSession: true, forceNewSession: $forceNewSession)
                    }
                } else {
                    activitySelectionCard {
                        selectedActivityType = carouselSelection
                        showActivitySelection = false
                    }
                }
            } else if showActivitySelection {
                activitySelectionCard {
                    selectedActivityType = carouselSelection
                    showActivitySelection = false
                }
            } else if let activity = selectedActivityType {
                // Check if gym session
                if activity == .walking {
                    GymSessionView()
                } else {
                    SessionMapView(activity: activity, isPresented: $showActivitySelection, resumeSession: false, forceNewSession: $forceNewSession)
                }
            } else {
                // Empty view as fallback
                EmptyView()
            }
        }
        .overlay(alignment: .topTrailing) {
            if !sessionManager.hasActiveSession && showActivitySelection {
                Button {
                    NotificationCenter.default.post(name: NSNotification.Name("CloseStartSession"), object: nil)
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.black.opacity(0.8))
                        .padding(16)
                }
            }
        }
        .task {
            // Ensure session manager is loaded
            print("🔍 StartSessionView.task - activeSession: \(sessionManager.activeSession != nil), hasActiveSession: \(sessionManager.hasActiveSession)")
            Task { @MainActor in
                locationManager.requestLocationPermission()
                locationManager.startTracking(activityType: carouselSelection.rawValue)
            }
        }
        .onAppear {
            carouselSelection = .walking
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("SessionFinalized"))) { _ in
            // Reset view state when a session is finalized anywhere
            forceNewSession = false
            selectedActivityType = nil
            showActivitySelection = true
            carouselSelection = .walking
        }
        .interactiveDismissDisabled(sessionManager.hasActiveSession || selectedActivityType != nil)
    }
    
    @ViewBuilder
    private func activitySelectionCard(onStart: @escaping () -> Void) -> some View {
        ActivityCarouselSelectionView(currentSelection: $carouselSelection, onStart: onStart)
            .padding(.horizontal, 20)
            .padding(.vertical, 20)
            .background(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(Color(.systemGroupedBackground))
                    .shadow(color: Color.black.opacity(0.25), radius: 30, x: 0, y: 16)
            )
            .padding(.horizontal, 16)
    }
}

enum ActivityType: String, CaseIterable, Identifiable {
    case running = "Löppass"
    case golf = "Golfrunda"
    case walking = "Gympass"
    case hiking = "Bestiga berg"
    case skiing = "Skidåkning"
    
    static let carouselOrder: [ActivityType] = [.walking, .running, .golf, .hiking, .skiing]
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .running: return "figure.run"
        case .golf: return "figure.golf"
        case .walking: return "figure.strengthtraining.traditional"
        case .hiking: return "mountain.2.fill"
        case .skiing: return "snowflake"
        }
    }
    
    var buttonText: String {
        switch self {
        case .running: return "Starta löppass"
        case .golf: return "Starta golfrunda"
        case .walking: return "Starta gympass"
        case .hiking: return "Starta bergsbestigning"
        case .skiing: return "Starta skidpass"
        }
    }
    
    var headline: String {
        switch self {
        case .walking: return "Bygg styrka"
        case .running: return "Jaga farten"
        case .golf: return "Perfekt sving"
        case .hiking: return "Upp på toppen"
        case .skiing: return "Följ spåren"
        }
    }
    
    var description: String {
        switch self {
        case .walking: return "Logga gympass, set och vikter med precision."
        case .running: return "Spela in distans, tempo och PB på dina löppass."
        case .golf: return "Håll koll på rundor, slag och distans på banan."
        case .hiking: return "Kapa nya toppar och spara höjdmetrarna."
        case .skiing: return "Följ dina åk och lutning i backen."
        }
    }
}

struct ActivityCarouselSelectionView: View {
    @Binding var currentSelection: ActivityType
    let onStart: () -> Void
    
    private let activities: [ActivityType] = [.walking, .running, .golf, .skiing]
    private let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]
    private let maxHeight = UIScreen.main.bounds.height * 0.55
    
    var body: some View {
        VStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Välj aktivitet")
                    .font(.system(size: 26, weight: .bold))
                Text("Tryck på en ruta för att välja och starta.")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }
                    .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 18)
            .padding(.top, 12)
            
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(activities) { activity in
                    Button {
                        currentSelection = activity
                    } label: {
                        ActivityGridCard(activity: activity, isSelected: currentSelection == activity)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 18)
            
            Button(action: onStart) {
                Text(currentSelection.buttonText.uppercased())
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            .background(Color.black)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            }
            .padding(.horizontal, 18)
            
            Spacer(minLength: 0)
        }
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
        .frame(height: maxHeight, alignment: .top)
    }
    
    private struct ActivityGridCard: View {
        let activity: ActivityType
        let isSelected: Bool
        
        var body: some View {
            VStack(alignment: .leading, spacing: 8) {
                            Image(systemName: activity.icon)
                    .font(.system(size: 30, weight: .bold))
                    .padding(12)
                    .background(isSelected ? Color.black : Color.black.opacity(0.08))
                    .foregroundColor(isSelected ? .white : .black)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(activity.rawValue)
                        .font(.system(size: 16, weight: .semibold))
                }
                .frame(maxWidth: .infinity)
                .multilineTextAlignment(.center)
                        }
                        .padding(16)
            .frame(maxWidth: .infinity)
                        .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                        .overlay(
                RoundedRectangle(cornerRadius: 24)
                    .stroke(isSelected ? Color.black : Color.clear, lineWidth: 2)
            )
            .shadow(color: Color.black.opacity(0.06), radius: 10, x: 0, y: 4)
        }
    }
}

struct XpCelebrationView: View {
    let points: Int
    let title: String
    let subtitle: String
    let badgeText: String
    let buttonTitle: String
    let onButtonTap: () -> Void
    
    @State private var animatedPoints: Double = 0
    @State private var pulse = false
    
    init(
        points: Int,
        title: String = "Grymt jobbat! 💥",
        subtitle: String = "Du har precis tjänat in",
        badgeText: String = "XP",
        buttonTitle: String = "Fortsätt",
        onButtonTap: @escaping () -> Void
    ) {
        self.points = points
        self.title = title
        self.subtitle = subtitle
        self.badgeText = badgeText
        self.buttonTitle = buttonTitle
        self.onButtonTap = onButtonTap
    }
    
    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()
            
            VStack(spacing: 32) {
            Spacer()
            
                VStack(spacing: 12) {
                    Text(title)
                        .font(.system(size: 28, weight: .black))
                        .foregroundColor(.black)
                    
                    Text(subtitle)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                }
                
                ZStack {
                    Circle()
                        .fill(Color.black.opacity(0.06))
                        .frame(width: 220, height: 220)
                        .scaleEffect(pulse ? 1.08 : 0.95)
                        .animation(.easeInOut(duration: 1).repeatForever(autoreverses: true), value: pulse)
                    
                    Circle()
                        .stroke(Color.black.opacity(0.15), lineWidth: 2)
                        .frame(width: 260, height: 260)
                        .opacity(pulse ? 0.4 : 0.15)
                        .animation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true), value: pulse)
                    
                    AnimatedNumberText(value: animatedPoints)
                        .font(.system(size: 56, weight: .black))
                        .foregroundColor(.black)
                }
                
                Text(badgeText.uppercased())
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.black)
                
                Button(action: onButtonTap) {
                    Text(buttonTitle.uppercased())
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.black)
                        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                        .shadow(color: Color.black.opacity(0.25), radius: 10, x: 0, y: 4)
                }
                .padding(.horizontal, 32)
                
                Spacer()
            }
            .padding(.vertical, 40)
        }
        .onAppear {
            animatedPoints = 0
            pulse = true
            withAnimation(.interpolatingSpring(mass: 0.7, stiffness: 70, damping: 9).delay(0.1)) {
                animatedPoints = Double(points)
            }
        }
    }
}

private struct AnimatedNumberText: Animatable, View {
    var value: Double
    
    var animatableData: Double {
        get { value }
        set { value = newValue }
    }
    
    var body: some View {
        Text("\(Int(value))")
    }
}

struct StreakCelebrationView: View {
    let onDismiss: () -> Void
    @State private var streakInfo = StreakManager.shared.getCurrentStreak()
    @State private var showContent = false
    @State private var flameScale: CGFloat = 0
    @State private var flameRotation: Double = -20
    
    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 32) {
                    Spacer().frame(height: 40)
                    
                    // Title
                    VStack(spacing: 8) {
                        Text("Din streak lever!")
                            .font(.system(size: 32, weight: .black))
                    .foregroundColor(.black)
                            .opacity(showContent ? 1 : 0)
                            .offset(y: showContent ? 0 : 20)
                        
                        Text(streakInfo.streakTitle)
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.gray)
                            .opacity(showContent ? 1 : 0)
                            .offset(y: showContent ? 0 : 20)
                    }
                    
                    // Flame icon
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [Color.orange.opacity(0.3), Color.orange.opacity(0.1)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .frame(width: 200, height: 200)
                            .blur(radius: 20)
                            .opacity(showContent ? 1 : 0)
                        
                        Image(systemName: "flame.fill")
                            .font(.system(size: 100))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [Color.orange, Color.red],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .scaleEffect(flameScale)
                            .rotationEffect(.degrees(flameRotation))
                    }
                    .frame(height: 200)
                    
                    // Stats cards
                    HStack(spacing: 16) {
                        statCard(
                            value: "\(streakInfo.consecutiveDays)",
                            label: "DAGAR I RAD"
                        )
                        
                        statCard(
                            value: "\(streakInfo.completedDaysThisWeek)/7",
                            label: "DENNA VECKA"
                        )
                    }
                    .padding(.horizontal, 32)
                    .opacity(showContent ? 1 : 0)
                    .offset(y: showContent ? 0 : 30)
                    
                    // Week calendar
                    VStack(spacing: 16) {
                        Text("VECKA \(Calendar.current.component(.weekOfYear, from: Date()))")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.gray)
                        
                        HStack(spacing: 12) {
                            ForEach(0..<7) { index in
                                weekdayCircle(index: index)
                            }
                        }
                    }
                    .opacity(showContent ? 1 : 0)
                    .offset(y: showContent ? 0 : 30)
                    
                    Text("Fortsätt logga pass för att hålla streaken vid liv!")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                        .opacity(showContent ? 1 : 0)
                    
                    // Button
                    Button(action: onDismiss) {
                        Text("SKAPA INLÄGG")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                            .background(Color.black)
                            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                            .shadow(color: Color.black.opacity(0.25), radius: 10, x: 0, y: 4)
                    }
                    .padding(.horizontal, 32)
                    .opacity(showContent ? 1 : 0)
                    .offset(y: showContent ? 0 : 30)
                    
                    Spacer().frame(height: 40)
                }
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.2)) {
                showContent = true
            }
            withAnimation(.spring(response: 0.8, dampingFraction: 0.6).delay(0.3)) {
                flameScale = 1.0
                flameRotation = 0
            }
            withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true).delay(0.8)) {
                flameScale = 1.1
            }
        }
    }
    
    private func statCard(value: String, label: String) -> some View {
        VStack(spacing: 8) {
            Text(value)
                .font(.system(size: 36, weight: .black))
                .foregroundColor(.black)
            Text(label)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
    
    private func weekdayCircle(index: Int) -> some View {
        let symbols = Calendar.current.shortWeekdaySymbols
        let symbol = symbols[index]
        let isCompleted = streakInfo.completedDaysThisWeek > index
        
        return VStack(spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(isCompleted ? 
                          LinearGradient(colors: [Color.orange, Color.orange.opacity(0.8)], startPoint: .top, endPoint: .bottom) : 
                          LinearGradient(colors: [Color(.systemGray6), Color(.systemGray6)], startPoint: .top, endPoint: .bottom))
                    .frame(width: 44, height: 44)
                
                if isCompleted {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)
                } else {
                    Circle()
                        .fill(Color.white.opacity(0.5))
                        .frame(width: 8, height: 8)
                }
            }
            
            Text(symbol)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.gray)
        }
    }
}

private struct HoldToConfirmButton: View {
    let title: String
    let duration: Double
    let onComplete: () -> Void
    
    @State private var progress: CGFloat = 0
    @State private var isHolding = false
    @State private var holdCompleted = false
    
    private let startFeedback = UIImpactFeedbackGenerator(style: .medium)
    private let completionFeedback = UINotificationFeedbackGenerator()
    private let idleIndicatorFraction: CGFloat = 0.07
    
    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let minFillWidth = width * idleIndicatorFraction
            let fillWidth = max(width * progress, minFillWidth)
            
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.black.opacity(0.15))
                
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.black)
                    .frame(width: min(fillWidth, width))
                
                Text(title.uppercased())
                    .font(.system(size: 16, weight: .black))
                    .foregroundColor(.white)
                    .frame(width: width, height: 48)
            }
            .frame(height: 48)
            .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .onLongPressGesture(
                minimumDuration: duration,
                maximumDistance: 50,
                pressing: { pressing in
                    if pressing {
                        startHold()
                    } else if !holdCompleted {
                        cancelHold(animated: true)
                    }
                },
                perform: {
                    finishHold()
                }
            )
        }
        .frame(height: 48)
        .onDisappear {
            progress = 0
            isHolding = false
            holdCompleted = false
        }
    }
    
    private func startHold() {
        guard !isHolding else { return }
        isHolding = true
        holdCompleted = false
        startFeedback.prepare()
        completionFeedback.prepare()
        startFeedback.impactOccurred(intensity: 0.8)
        withAnimation(.linear(duration: duration)) {
            progress = 1
        }
    }
    
    private func cancelHold(animated: Bool) {
        guard isHolding else { return }
        isHolding = false
        holdCompleted = false
        let reset = {
            progress = 0
        }
        if animated {
            withAnimation(.easeOut(duration: 0.25)) {
                reset()
            }
        } else {
            reset()
        }
    }
    
    private func finishHold() {
        guard isHolding else { return }
        holdCompleted = true
        isHolding = false
        progress = 1
        completionFeedback.notificationOccurred(.success)
        onComplete()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            holdCompleted = false
            withAnimation(.easeOut(duration: 0.25)) {
                progress = 0
            }
        }
    }
}

struct SessionMapView: View {
    let activity: ActivityType
    @Binding var isPresented: Bool
    let resumeSession: Bool
    @Binding var forceNewSession: Bool
    @ObservedObject private var locationManager = LocationManager.shared
    @ObservedObject private var revenueCatManager = RevenueCatManager.shared
    @ObservedObject private var sessionManager = SessionManager.shared
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 59.3293, longitude: 18.0686),
        span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
    )
    @State private var isRunning = false
    @State private var isPaused = false
    @State private var sessionDuration: Int = 0
    @State private var sessionStartTime: Date?
    @State private var currentPace: String = "0:00"
    @State private var timer: Timer?
    @State private var showXpCelebration = false
    @State private var xpCelebrationPoints = 0
    @State private var showStreakCelebration = false
    @State private var showSessionComplete = false
    @State private var isSessionEnding = false  // Flag to prevent saves during session end
    @State private var earnedPoints: Int = 0
    @State private var routeImage: UIImage?
    @State private var completedSplits: [WorkoutSplit] = []
    @State private var lastRegionUpdate: Date = .distantPast
    @State private var routeCoordinatesSnapshot: [CLLocationCoordinate2D] = []
    @State private var lastPointsUpdate: Date = Date()
    @State private var lastSnapshotSourceCount: Int = 0
    private let maxRouteSnapshotPoints = 1500
    @Environment(\.dismiss) var dismiss
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ZStack {
            // MARK: - Map Background with route
            Map(coordinateRegion: $region, showsUserLocation: true)
                .ignoresSafeArea()
                .overlay(
                    // Route visualization - optimized with snapshot
                    GeometryReader { geometry in
                        Path { path in
                            guard routeCoordinatesSnapshot.count > 1 else { return }
                            
                            for (index, coordinate) in routeCoordinatesSnapshot.enumerated() {
                                let point = convertToMapPoint(coordinate, in: geometry.size)
                                if index == 0 {
                                    path.move(to: point)
                                } else {
                                    path.addLine(to: point)
                                }
                            }
                        }
                        .stroke(.black, lineWidth: 4)
                    }
                )
                .onChange(of: locationManager.routeCoordinates.count) { _ in
                    refreshRouteSnapshotIfNeeded()
                }
                .onReceive(locationManager.$routeCoordinates) { coords in
                    if coords.isEmpty {
                        routeCoordinatesSnapshot = []
                        lastSnapshotSourceCount = 0
                    } else if routeCoordinatesSnapshot.isEmpty {
                        refreshRouteSnapshot(force: true)
                    }
                }
                .onAppear {
                    // Request location permission but DON'T start tracking yet
                    locationManager.requestLocationPermission()
                    centerMapOnUser(animated: false)
                    if resumeSession, let session = sessionManager.activeSession {
                        Task { @MainActor in
                            print("🔄 Resuming session with duration: \(session.accumulatedDuration)s, distance: \(session.accumulatedDistance) km")
                            sessionDuration = session.accumulatedDuration
                            sessionStartTime = session.startTime
                            isPaused = session.isPaused
                            isRunning = !session.isPaused

                            // Set distance from saved session
                            locationManager.distance = session.accumulatedDistance
                            completedSplits = session.completedSplits

                            // Restore skiing metrics if available
                            if let elevationGain = session.elevationGain {
                                locationManager.elevationGain = elevationGain
                            }
                            if let maxSpeed = session.maxSpeed {
                                locationManager.maxSpeed = maxSpeed
                            }

                            // Set activity type for location manager
                            locationManager.setActivityType(session.activityType)

                            // Calculate earned points for the current distance
                            updateEarnedPoints()

                            // Resume tracking if session was running (preserve existing data)
                            if !session.isPaused {
                                sessionManager.beginSession()
                                locationManager.startTracking(preserveData: true, activityType: session.activityType)
                                startTimer()
                            }

                            // Ensure we are in resume mode
                            forceNewSession = false

                            // Load route coordinates if available
                            if !session.routeCoordinates.isEmpty {
                                locationManager.routeCoordinates = session.routeCoordinates.map { coord in
                                    CLLocationCoordinate2D(latitude: coord.latitude, longitude: coord.longitude)
                                }
                                refreshRouteSnapshot(force: true)
                            }
                        }
                    } else {
                        // Initialize snapshot for new sessions
                        refreshRouteSnapshot(force: true)
                    }
                }
                .onReceive(locationManager.$userLocation) { newLocation in
                    guard let location = newLocation else { return }
                        let now = Date()
                    if !isRunning || now.timeIntervalSince(lastRegionUpdate) >= 2.0 {
                        centerMap(on: location, animated: true)
                    }
                }

            // Back button removed

            // MARK: - Bottom Stats and Controls
            VStack {
                Spacer()

                VStack(spacing: 16) {
                    // GPS Status
                    HStack(spacing: 8) {
                        Image(systemName: locationManager.userLocation != nil ? "location.fill" : "location.slash")
                            .font(.system(size: 14))
                            .foregroundColor(locationManager.authorizationStatus == .authorizedAlways ? .black : .red)
                        Text(locationManager.userLocation != nil ? "GPS" : (locationManager.authorizationStatus == .authorizedAlways ? "GPS" : "GPS Ej tillgänglig"))
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(locationManager.userLocation != nil ? .black : (locationManager.authorizationStatus == .authorizedAlways ? .black : .red))
                    }
                    
                    // Location Error Display
                    if let error = locationManager.locationError {
                        VStack(spacing: 12) {
                            Text(error)
                                .font(.system(size: 12))
                                .foregroundColor(.red)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 16)
                            
                            Button(action: {
                                locationManager.openSettings()
                            }) {
                                Text("Öppna Inställningar")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 8)
                                    .background(AppColors.brandBlue)
                                    .cornerRadius(8)
                            }
                        }
                    }

                    // Main Distance Display (Längst upp i fetstil)
                    VStack(spacing: 4) {
                        Text(String(format: "%.2f", locationManager.distance))
                            .font(.system(size: 36, weight: .black))
                            .foregroundColor(.black)
                        Text("km")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.black)
                    }

                    // Status Text
                    Text("Inspelning pågår")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.black)

                    // Three Column Stats
                    HStack(spacing: 20) {
                        VStack(spacing: 4) {
                            Text("\(earnedPoints)")
                                .font(.system(size: 20, weight: .black))
                                .foregroundColor(.black)
                            Text("Poäng")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.gray)
                        }
                        .frame(maxWidth: .infinity)
                        
                        VStack(spacing: 4) {
                            Text(formattedTime(sessionDuration))
                                .font(.system(size: 20, weight: .black))
                                .foregroundColor(.black)
                            Text("Tid")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.gray)
                        }
                        .frame(maxWidth: .infinity)
                        
                        // Show elevation for skiing, pace for others
                        if activity == .skiing || activity == .hiking {
                            VStack(spacing: 4) {
                                Text(String(format: "%.0f m", locationManager.elevationGain))
                                    .font(.system(size: 20, weight: .black))
                                    .foregroundColor(.black)
                                Text("Höjdmeter")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(.gray)
                            }
                            .frame(maxWidth: .infinity)
                        } else {
                            VStack(spacing: 4) {
                                Text(currentPace)
                                    .font(.system(size: 20, weight: .black))
                                    .foregroundColor(.black)
                                Text("Tempo")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(.gray)
                            }
                            .frame(maxWidth: .infinity)
                        }
                        
                        if activity == .skiing {
                            VStack(spacing: 4) {
                                Text(formatTopSpeed(locationManager.maxSpeed))
                                    .font(.system(size: 20, weight: .black))
                                    .foregroundColor(.black)
                                Text("Topphastighet")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(.gray)
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                    .padding(.horizontal, 16)

                    // Start/Pause/Continue/End Buttons
                    if isPaused {
                        // Paused state - show Continue and End buttons
                        VStack(spacing: 12) {
                            Button(action: {
                                let generator = UIImpactFeedbackGenerator(style: .heavy)
                                generator.prepare()
                                generator.impactOccurred(intensity: 1.0)
                                Task {
                                    await TrackingPermissionManager.shared.requestPermissionIfNeeded()
                                    await MainActor.run {
                                        isSessionEnding = false
                                        print("✅ Resuming session - isSessionEnding = false")
                                        sessionManager.beginSession()
                                        locationManager.startTracking(preserveData: true, activityType: activity.rawValue)
                                        startTimer()
                                        isPaused = false
                                        isRunning = true
                                    }
                                }
                            }) {
                                Text("Fortsätt")
                                    .font(.system(size: 16, weight: .black))
                                    .frame(maxWidth: .infinity)
                                    .padding(14)
                                    .background(Color.black)
                                    .foregroundColor(.white)
                                    .cornerRadius(12)
                            }
                            
                            HoldToConfirmButton(
                                title: "Avsluta",
                                duration: 1.5,
                                onComplete: {
                                endSession()
                                }
                            )
                        }
                        .padding(.horizontal, 16)
                    } else {
                        // Running or stopped state - show Start/Pause button
                        Button(action: {
                            if isRunning {
                                stopTimer()
                                locationManager.stopTracking()
                                isRunning = false
                                isPaused = true
                            } else {
                                let generator = UIImpactFeedbackGenerator(style: .heavy)
                                generator.prepare()
                                generator.impactOccurred(intensity: 1.0)
                                Task {
                                    await TrackingPermissionManager.shared.requestPermissionIfNeeded()
                                    await MainActor.run {
                                        if !isRunning {
                                            isSessionEnding = false
                                            print("✅ Starting new session - isSessionEnding = false")
                                            sessionManager.beginSession()
                                            sessionDuration = 0
                                            sessionStartTime = nil
                                            currentPace = "0:00"
                                            completedSplits = []
                                            earnedPoints = 0
                                            isPaused = false
                                            locationManager.distance = 0
                                            locationManager.elevationGain = 0
                                            locationManager.maxSpeed = 0
                                            locationManager.routeCoordinates = []
                                            locationManager.startNewTracking(activityType: activity.rawValue)
                                            forceNewSession = true
                                            startTimer()
                                            isRunning = true
                                        }
                                    }
                                }
                            }
                        }) {
                            Text(isRunning ? "Pausa" : activity.buttonText)
                                .font(.system(size: 16, weight: .black))
                                .frame(maxWidth: .infinity)
                                .padding(14)
                                .background(.black)
                                .foregroundColor(.white)
                                .cornerRadius(12)
                        }
                        .padding(.horizontal, 16)
                    }
                }
                .padding(20)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color.white.opacity(0.95))
                        .shadow(radius: 10)
                )
                .padding(16)
            }
            
        }
        .navigationBarHidden(true)
        .alert("Platsåtkomst i bakgrunden krävs", isPresented: $locationManager.showLocationDeniedAlert) {
            Button("Avbryt", role: .cancel) {}
            Button("Öppna Inställningar") {
                locationManager.openSettings()
            }
        } message: {
            Text("För att spåra din rutt när appen är stängd måste du välja 'Tillåt alltid' för platsåtkomst i Inställningar.")
        }
        .onDisappear {
            // Save session state when view disappears, but DON'T stop timer
            // Timer continues in background
            saveSessionState()
        }
        .sheet(isPresented: $showXpCelebration) {
            XpCelebrationView(
                points: xpCelebrationPoints,
                buttonTitle: "Fortsätt"
            ) {
                showXpCelebration = false
                showStreakCelebration = true
            }
        }
        .sheet(isPresented: $showStreakCelebration) {
            StreakCelebrationView(onDismiss: {
                showStreakCelebration = false
                showSessionComplete = true
            })
        }
        .sheet(isPresented: $showSessionComplete) {
            SessionCompleteView(
                activity: activity,
                distance: locationManager.distance,
                duration: sessionDuration,
                earnedPoints: earnedPoints,
                routeImage: routeImage,
                elevationGain: activity == .skiing && locationManager.elevationGain > 0 ? locationManager.elevationGain : nil,
                maxSpeed: activity == .skiing && locationManager.maxSpeed > 0 ? locationManager.maxSpeed : nil,
                completedSplits: completedSplits,
                gymExercises: nil,  // No gym exercises for regular workouts
                isPresented: $showSessionComplete,
                onComplete: {
                    print("💾 Workout saved - finalizing session now")
                    // Finalize session once saving is complete
                    sessionManager.finalizeSession()
                    // Navigate to Social tab after saving
                    NotificationCenter.default.post(name: NSNotification.Name("NavigateToSocial"), object: nil)
                },
                onDelete: {
                    print("🗑️ Workout deleted - finalizing session now")
                    // Finalize session when deleting
                    sessionManager.finalizeSession()
                    // Ask MainTabView to close the StartSession sheet
                    NotificationCenter.default.post(name: NSNotification.Name("CloseStartSession"), object: nil)
                }
            )
        }
        // No onChange needed - session is cleared in endSession()
        .onChange(of: scenePhase) { _, newPhase in
            guard sessionStartTime != nil else { return }
            if newPhase == .background || newPhase == .inactive {
                print("📥 ScenePhase changed to \(newPhase) - saving session state")
                saveSessionState()
            }
        }
    }

    func startTimer() {
        isRunning = true
        if sessionStartTime == nil {
            sessionStartTime = Date()
        }
        
        // Don't create a new timer if one already exists (to prevent duplicates)
        if timer != nil {
            return
        }
        
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [self] _ in
            sessionDuration += 1
            updatePace()
            
            // Update points less frequently (every 5 seconds)
            let now = Date()
            if now.timeIntervalSince(lastPointsUpdate) >= 5.0 {
                updateEarnedPoints()
                lastPointsUpdate = now
            }
            
            updateSplitsIfNeeded()
        }
    }
    
    private func centerMapOnUser(animated: Bool) {
        guard let coordinate = locationManager.userLocation else { return }
        centerMap(on: coordinate, animated: animated)
    }
    
    private func centerMap(on coordinate: CLLocationCoordinate2D, animated: Bool) {
        let update = {
            region.center = coordinate
        }
        
        if animated {
            withAnimation(.easeInOut(duration: 0.35)) {
                update()
            }
        } else {
            update()
        }
        
        lastRegionUpdate = Date()
    }
    
    func updateEarnedPoints() {
        let basePoints = Int((locationManager.distance * distancePointMultiplier()).rounded())
        
        // PRO-medlemmar får 1.5x poäng
        if revenueCatManager.isPremium {
            earnedPoints = Int(Double(basePoints) * 1.5)
        } else {
            earnedPoints = basePoints
        }
    }
    
    private func refreshRouteSnapshotIfNeeded(force: Bool = false) {
        let sourceCount = locationManager.routeCoordinates.count
        if force {
            refreshRouteSnapshot(force: true)
            return
        }
        
        guard sourceCount > 0 else {
            routeCoordinatesSnapshot = []
            lastSnapshotSourceCount = 0
            return
        }
        
        // Refresh when new points were added or removed
        if sourceCount - lastSnapshotSourceCount >= 10 || sourceCount < lastSnapshotSourceCount {
            refreshRouteSnapshot(force: true)
        }
    }
    
    private func refreshRouteSnapshot(force: Bool) {
        let coordinates = locationManager.routeCoordinates
        
        guard !coordinates.isEmpty else {
            routeCoordinatesSnapshot = []
            lastSnapshotSourceCount = 0
            return
        }
        
        let sourceCount = coordinates.count
        lastSnapshotSourceCount = sourceCount
        
        Task.detached(priority: .userInitiated) {
            let simplified = simplifyRoute(coordinates, targetCount: maxRouteSnapshotPoints)
            await MainActor.run {
                if lastSnapshotSourceCount == sourceCount {
                    routeCoordinatesSnapshot = simplified
                }
            }
        }
    }
    
    private func simplifyRoute(_ coordinates: [CLLocationCoordinate2D], targetCount: Int) -> [CLLocationCoordinate2D] {
        guard coordinates.count > targetCount, targetCount > 0 else {
            return coordinates
        }
        
        let step = max(1, coordinates.count / targetCount)
        var simplified: [CLLocationCoordinate2D] = []
        simplified.reserveCapacity(min(coordinates.count, targetCount + 2))
        
        for (index, coordinate) in coordinates.enumerated() where index % step == 0 {
            simplified.append(coordinate)
        }
        
        if let last = coordinates.last {
            if let currentLast = simplified.last {
                if currentLast.latitude != last.latitude || currentLast.longitude != last.longitude {
                    simplified.append(last)
                }
            } else {
                simplified.append(last)
            }
        }
        
        return simplified
    }
    
    func updateSplitsIfNeeded() {
        guard locationManager.distance > 0 else { return }
        var accumulatedDuration = completedSplits.reduce(0.0) { $0 + $1.durationSeconds }
        while locationManager.distance >= Double(completedSplits.count + 1) {
            let nextIndex = completedSplits.count + 1
            let splitDuration = Double(sessionDuration) - accumulatedDuration
            guard splitDuration > 0 else { break }
            let split = WorkoutSplit(kilometerIndex: nextIndex,
                                     distanceKm: 1.0,
                                     durationSeconds: splitDuration)
            completedSplits.append(split)
            accumulatedDuration += splitDuration
        }
    }
    
    func saveSessionState() {
        guard let startTime = sessionStartTime else {
            print("⚠️ No startTime, not saving")
            return
        }
        
        print("🔍 saveSessionState - isSessionEnding: \(isSessionEnding)")
        
        // Don't save if we're in the process of ending the session
        if isSessionEnding {
            print("🛑 Not saving session state - session is ending (isSessionEnding = true)")
            return
        }

        // Auto-cancel sessions that have been running in the background for more than 2 hours
        if UIApplication.shared.applicationState != .active {
            let elapsed = Date().timeIntervalSince(startTime)
            if elapsed >= 2 * 3600 {
                print("⏰ Session auto-cancelled after 2h in background")
                cancelBackgroundTimedOutSession()
                return
            }
        }
        
        // Get route coordinates from location manager
        let coords = locationManager.routeCoordinates
        
        print("💾 Saving session state... (isSessionEnding is FALSE)")
        // Save to SessionManager
        sessionManager.saveActiveSession(
            activityType: activity.rawValue,
            startTime: startTime,
            isPaused: isPaused,
            duration: sessionDuration,
            distance: locationManager.distance,
            routeCoordinates: coords,
            completedSplits: completedSplits,
            elevationGain: locationManager.elevationGain > 0 ? locationManager.elevationGain : nil,
            maxSpeed: locationManager.maxSpeed > 0 ? locationManager.maxSpeed : nil
        )
    }

    private func cancelBackgroundTimedOutSession() {
        isSessionEnding = true
        stopTimer()
        locationManager.stopTracking()
        sessionManager.finalizeSession()
        locationManager.routeCoordinates = []
        locationManager.distance = 0
        locationManager.elevationGain = 0
        locationManager.maxSpeed = 0
        showSessionComplete = false
        showXpCelebration = false
        showStreakCelebration = false
        forceNewSession = true
    }

    func stopTimer() {
        isRunning = false
        timer?.invalidate()
        timer = nil
    }
    
    func endSession() {
        print("🏁 Ending session...")
        
        // STOP timer and tracking, but DON'T clear session yet (need data for SessionCompleteView)
        isSessionEnding = true
        stopTimer()
        locationManager.stopTracking()
        print("🛑 Timer stopped, isSessionEnding = true")
        
        // Save session data before showing completion
        print("💾 Distance: \(locationManager.distance) km")
        print("💾 Duration: \(sessionDuration) seconds")
        print("💾 Route points: \(locationManager.routeCoordinates.count)")
        print("📍 Route coordinates: \(locationManager.routeCoordinates)")
        
        // Generate route snapshot and wait for it
        MapSnapshotService.shared.generateRouteSnapshot(
            routeCoordinates: locationManager.routeCoordinates,
            userLocation: locationManager.userLocation
        ) { snapshotImage in
            print("🗺️ Route snapshot generation completed")
            if let snapshotImage = snapshotImage {
                print("✅ Route snapshot generated successfully")
                // Save route image to SessionManager for use in SessionCompleteView
                DispatchQueue.main.async {
                    // Store route image temporarily
                    self.routeImage = snapshotImage
                    print("📸 Route image stored in view")
                }
            } else {
                print("⚠️ Could not generate route snapshot - using nil")
                DispatchQueue.main.async {
                    self.routeImage = nil
                }
            }
        }
        
        let basePoints = Int((locationManager.distance * distancePointMultiplier()).rounded())
        
        // PRO-medlemmar får 1.5x poäng
        if revenueCatManager.isPremium {
            earnedPoints = Int(Double(basePoints) * 1.5)
        } else {
            earnedPoints = basePoints
        }
        
        // Update streak
        StreakManager.shared.registerWorkoutCompletion()
        
        // Add small delay to ensure route image is generated before showing celebration
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            print("✅ Showing XP celebration...")
            self.xpCelebrationPoints = self.earnedPoints
            self.showXpCelebration = true
        }
    }
    
    private func distancePointMultiplier() -> Double {
        switch activity {
        case .running, .golf, .hiking, .skiing:
            return 2.5 // 0.25 XP per 100 m
        default:
            return 15.0 // kvar för andra aktiviteter om de använder distanspoäng
        }
    }

    func updatePace() {
        // Om vi inte har kört tillräckligt långt eller om distans är 0, visa "0:00"
        if locationManager.distance < 0.05 {
            currentPace = "0:00"
            return
        }
        
        // Beräkna tempo (sekunder per km)
        let paceSeconds = (Double(sessionDuration) / locationManager.distance)
        
        // Om tempot är för långsamt (över 25 min/km - står still), visa "0:00"
        if paceSeconds > 1500 {
            currentPace = "0:00"
            return
        }
        
        let minutes = Int(paceSeconds / 60)
        let seconds = Int(paceSeconds.truncatingRemainder(dividingBy: 60))
        currentPace = String(format: "%d:%02d", minutes, seconds)
    }

    func formattedTime(_ seconds: Int) -> String {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        let secs = seconds % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        } else {
            return String(format: "%02d:%02d", minutes, secs)
        }
    }

    private func formatTopSpeed(_ speed: Double) -> String {
        let kmh = max(speed, 0) * 3.6
        return String(format: "%.1f km/h", kmh)
    }
    
    // Convert coordinate to map point for path drawing
    func convertToMapPoint(_ coordinate: CLLocationCoordinate2D, in size: CGSize) -> CGPoint {
        let centerLat = region.center.latitude
        let centerLon = region.center.longitude
        
        // Calculate delta in meters
        let latDelta = region.span.latitudeDelta
        let lonDelta = region.span.longitudeDelta
        
        // Convert to pixels
        let pixelsPerDegreeLat = size.height / latDelta
        let pixelsPerDegreeLon = size.width / lonDelta
        
        let x = (coordinate.longitude - centerLon) * pixelsPerDegreeLon + size.width / 2
        let y = (centerLat - coordinate.latitude) * pixelsPerDegreeLat + size.height / 2
        
        return CGPoint(x: x, y: y)
    }
}

#Preview {
    StartSessionView()
}
