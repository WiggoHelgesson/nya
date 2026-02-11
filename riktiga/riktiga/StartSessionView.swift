import SwiftUI
import MapKit
import CoreLocation
import Combine
import UIKit

// MARK: - XP Celebration Data Wrapper
struct XpCelebrationData: Identifiable {
    let id = UUID()
    let points: Int
}

struct StartSessionView: View {
    private let initialActivity: ActivityType?
    private let coachWorkout: SavedGymWorkout?
    @State private var showActivitySelection: Bool
    @State private var selectedActivityType: ActivityType?
    @State private var carouselSelection: ActivityType = .walking
    @ObservedObject private var sessionManager = SessionManager.shared
    @ObservedObject private var locationManager = LocationManager.shared
    @State private var forceNewSession = false
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var authViewModel: AuthViewModel
    
    init(initialActivity: ActivityType? = nil, coachWorkout: SavedGymWorkout? = nil) {
        self.initialActivity = initialActivity
        self.coachWorkout = coachWorkout
        
        // Gym sessions (.walking) and coach workouts skip activity selection and auto-start
        // Running sessions show the session map but don't auto-start (user presses start)
        let isGymOrCoach = initialActivity == .walking || coachWorkout != nil
        _showActivitySelection = State(initialValue: initialActivity == nil && coachWorkout == nil)
        _selectedActivityType = State(initialValue: initialActivity ?? (coachWorkout != nil ? .walking : nil))
        _forceNewSession = State(initialValue: isGymOrCoach)
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
                    GymSessionView(initialCoachWorkout: coachWorkout)
                } else {
                    SessionMapView(activity: activity, isPresented: $showActivitySelection, resumeSession: false, forceNewSession: $forceNewSession, autoStart: forceNewSession)
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
                // Vi ska INTE starta tracking här, det görs när passet faktiskt startas
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
    
    private let activities: [ActivityType] = [.walking, .running, .hiking]
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
                    .background(isSelected ? Color.primary : Color.primary.opacity(0.08))
                    .foregroundColor(isSelected ? Color(.systemBackground) : .primary)
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
                        .background(Color(.secondarySystemBackground))
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
            Color(.systemBackground).ignoresSafeArea()
            
            VStack(spacing: 32) {
            Spacer()
            
                VStack(spacing: 12) {
                    Text(title)
                        .font(.system(size: 28, weight: .black))
                        .foregroundColor(.primary)
                    
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
                        .foregroundColor(.primary)
                }
                
                Text(badgeText.uppercased())
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.primary)
                
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
            Color(.systemBackground).ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 32) {
                    Spacer().frame(height: 40)
                    
                    // Title
                    VStack(spacing: 8) {
                        Text("Din streak lever!")
                            .font(.system(size: 32, weight: .black))
                    .foregroundColor(.primary)
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
                .foregroundColor(.primary)
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
        // Check if this weekday index is in the completed days array (index+1 because Calendar weekdays are 1-based)
        let isCompleted = streakInfo.completedDaysThisWeek.contains(index + 1)
        
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
    var autoStart: Bool = false
    @ObservedObject private var locationManager = LocationManager.shared
    @State private var isPremium = RevenueCatManager.shared.isProMember
    @ObservedObject private var sessionManager = SessionManager.shared
    @ObservedObject private var territoryStore = TerritoryStore.shared
    @EnvironmentObject private var authViewModel: AuthViewModel
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
    @State private var showTerritoryAnimation = false
    @State private var territoryAnimationCoordinates: [CLLocationCoordinate2D] = []
    @State private var showSessionComplete = false
    @State private var showTakeoverSummary = false
    @State private var takeoverUsers: [TileTakeoverRow] = []
    @State private var isLoadingTakeovers = false
    @State private var isSessionEnding = false  // Flag to prevent saves during session end
    @State private var earnedPoints: Int = 0
    @State private var routeImage: UIImage?
    @State private var completedSplits: [WorkoutSplit] = []
    @State private var lastRegionUpdate: Date = .distantPast
    @State private var routeCoordinatesSnapshot: [CLLocationCoordinate2D] = []
    @State private var lastPointsUpdate: Date = Date()
    @State private var lastSnapshotSourceCount: Int = 0
    @State private var liveTerritoryArea: Double = 0 // New state for live area
    private let maxRouteSnapshotPoints = 400 // Balance between detail and performance
    @State private var lastRouteUpdateTime: Date = .distantPast
    private let routeUpdateInterval: TimeInterval = 0.2 // Update route every 0.2s for smooth real-time
    @State private var lastAreaUpdateTime: Date = .distantPast
    private let areaUpdateInterval: TimeInterval = 1.0 // Update area every 1s
    
    // Speed detection for anti-cheat
    @State private var highSpeedStartTime: Date? = nil
    @State private var hasShownSpeedWarning = false
    @State private var showVehicleDetectedAlert = false
    @State private var trackingStoppedDueToSpeed = false
    private let maxSpeedRunning: Double = 25.0 // km/h
    private let maxSpeedGolf: Double = 12.0 // km/h
    private let highSpeedDurationThreshold: TimeInterval = 15.0 // seconds
    
    // Live photo during session
    @State private var sessionLivePhoto: UIImage? = nil
    @State private var showLivePhotoCapture = false
    @State private var livePhotoTaken = false
    
    // Expandable stats panel
    @State private var isStatsExpanded = false
    
    // Territory closure warning
    @State private var showTerritoryWarning = false
    @State private var pendingEndSession = false
    private let maxDistanceFromStartForTerritory: Double = 500.0 // meters (increased for GPS accuracy on real devices)
    
    @Environment(\.dismiss) var dismiss
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ZStack {
            // MARK: - Map Background with route
            Map(coordinateRegion: $region, showsUserLocation: true)
                .ignoresSafeArea()
                .overlay(routeCanvasOverlay)
                .onChange(of: locationManager.routeCoordinates.count) { oldCount, newCount in
                    // Only trigger on actual changes
                    guard oldCount != newCount else { return }
                    
                    print("📍 Route coordinates changed: \(oldCount) -> \(newCount)")
                    
                    if newCount == 0 {
                        routeCoordinatesSnapshot = []
                        lastSnapshotSourceCount = 0
                        liveTerritoryArea = 0
                    } else {
                        // Force immediate update for first points to show route instantly
                        // Also serves as backup if snapshot was somehow empty
                        if newCount <= 20 || routeCoordinatesSnapshot.isEmpty {
                            routeCoordinatesSnapshot = locationManager.routeCoordinates
                            lastSnapshotSourceCount = newCount
                            print("📍 Snapshot updated directly: \(routeCoordinatesSnapshot.count) points")
                        } else {
                            // After initial points, use throttled updates
                            refreshRouteSnapshotIfNeeded(force: newCount % 5 == 0)
                        }
                        updateLiveTerritoryArea()
                        
                        // Save session every 10 coordinate updates for bulletproof persistence
                        if newCount % 10 == 0 {
                            saveSessionState()
                        }
                    }
                }
                .onAppear {
                    // Request location permission but DON'T start tracking yet
                    locationManager.requestLocationPermission()
                    centerMapOnUser(animated: false)
                    if !resumeSession {
                        territoryStore.resetSession()
                    }
                    
                    // Auto-start if coming from activity switch (e.g., from gym session)
                    if autoStart && !resumeSession && !isRunning {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            Task { @MainActor in
                                sessionManager.beginSession()
                                locationManager.startNewTracking(activityType: activity.rawValue)
                                startTimer()
                                isRunning = true
                                print("🏃 Auto-started \(activity.rawValue) session")
                                
                                // Notify followers about session start
                                if let userId = authViewModel.currentUser?.id {
                                    let userName = authViewModel.currentUser?.name ?? "Användare"
                                    Task {
                                        let currentLocation = locationManager.userLocation.map { CLLocation(latitude: $0.latitude, longitude: $0.longitude) }
                                        try? await ActiveSessionService.shared.startSession(
                                            userId: userId,
                                            activityType: activity.rawValue,
                                            location: currentLocation,
                                            userName: userName
                                        )
                                        await ActiveSessionService.shared.notifyFollowers(
                                            userId: userId,
                                            userName: userName,
                                            activityType: activity.rawValue
                                        )
                                    }
                                }
                            }
                        }
                    }
                    
                    if resumeSession, let session = sessionManager.activeSession {
                        Task { @MainActor in
                            print("🔄 [RESUME] Starting session restoration...")
                            print("🔄 [RESUME] Duration: \(session.accumulatedDuration)s")
                            print("🔄 [RESUME] Distance: \(String(format: "%.3f", session.accumulatedDistance)) km")
                            print("🔄 [RESUME] Coords: \(session.routeCoordinates.count)")
                            print("🔄 [RESUME] Paused: \(session.isPaused)")
                            
                            sessionDuration = session.accumulatedDuration
                            sessionStartTime = session.startTime
                            isPaused = session.isPaused
                            isRunning = !session.isPaused

                            // Restore distance properly (both totalDistance and distance)
                            locationManager.restoreDistance(session.accumulatedDistance)
                            completedSplits = session.completedSplits

                            // Restore skiing metrics if available
                            if let elevationGain = session.elevationGain {
                                locationManager.elevationGain = elevationGain
                                print("🔄 [RESUME] Restored elevationGain: \(elevationGain)m")
                            }
                            if let maxSpeed = session.maxSpeed {
                                locationManager.maxSpeed = maxSpeed
                                print("🔄 [RESUME] Restored maxSpeed: \(maxSpeed)m/s")
                            }

                            // Set activity type for location manager
                            locationManager.setActivityType(session.activityType)

                            // Load route coordinates if available - BEFORE starting tracking
                            if !session.routeCoordinates.isEmpty {
                                let restoredCoords = session.routeCoordinates.map { coord in
                                    CLLocationCoordinate2D(latitude: coord.latitude, longitude: coord.longitude)
                                }
                                locationManager.restoreRouteCoordinates(restoredCoords)
                                routeCoordinatesSnapshot = restoredCoords
                                lastSnapshotSourceCount = restoredCoords.count
                                print("🔄 [RESUME] Restored \(restoredCoords.count) route coordinates")
                            }

                            // Calculate earned points for the current distance
                            updateEarnedPoints()

                            // Resume tracking if session was running (preserve existing data)
                            if !session.isPaused {
                                sessionManager.beginSession()
                                locationManager.startTracking(preserveData: true, activityType: session.activityType)
                                startTimer()
                                print("🔄 [RESUME] Timer started, tracking resumed")
                            } else {
                                // Even if paused, enable saves so state can be updated
                                sessionManager.beginSession()
                                print("🔄 [RESUME] Session paused, but saves enabled")
                            }

                            // Ensure we are in resume mode
                            forceNewSession = false
                            
                            // Refresh route display
                            refreshRouteSnapshot(force: true)
                            
                            // Final verification
                            locationManager.debugPrintState()
                            sessionManager.debugPrintState()
                            print("🔄 [RESUME] Session restoration complete ✅")
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
                .onReceive(locationManager.$currentSpeedKmh) { speed in
                    // Only check speed for running and golf during active session
                    guard isRunning && !trackingStoppedDueToSpeed else { return }
                    checkSpeedForCheating(currentSpeed: speed)
                }
                .overlay(alignment: .bottom) {
                    // Only show territory capture overlay for running and golf (not skiing)
                    if isRunning && (activity == .running || activity == .golf) {
                        VStack {
                            Text("Live Territory Capture")
                                .font(.caption)
                                .foregroundColor(.white)
                            Text(String(format: "%.0f m²", liveTerritoryArea))
                                .font(.headline)
                                .foregroundColor(.white)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.green.opacity(0.8))
                        .cornerRadius(10)
                        .offset(y: -200) // Position above controls
                    }
                }

            // Back button removed

            // MARK: - Bottom Stats and Controls
            VStack {
                Spacer()

                VStack(spacing: 16) {
                    // Only show detailed stats when session is running or paused
                    if isRunning || isPaused {
                        // GPS Status - Always visible when running
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

                        // Main Distance Display - Always visible when running
                        VStack(spacing: 4) {
                            Text(String(format: "%.2f", locationManager.distance))
                                .font(.system(size: 36, weight: .black))
                                .foregroundColor(.primary)
                            Text("km")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.primary)
                        }
                        
                        // EXPANDABLE SECTION - Hidden by default when running
                        if isStatsExpanded || isPaused {
                            // Status Text
                            Text("Inspelning pågår")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.primary)

                            // Three Column Stats
                            HStack(spacing: 20) {
                                VStack(spacing: 4) {
                                    Text("\(earnedPoints)")
                                        .font(.system(size: 20, weight: .black))
                                        .foregroundColor(.primary)
                                    Text("Poäng")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundColor(.gray)
                                }
                                .frame(maxWidth: .infinity)
                                
                                VStack(spacing: 4) {
                                    Text(formattedTime(sessionDuration))
                                        .font(.system(size: 20, weight: .black))
                                        .foregroundColor(.primary)
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
                                            .foregroundColor(.primary)
                                        Text("Höjdmeter")
                                            .font(.system(size: 12, weight: .semibold))
                                            .foregroundColor(.gray)
                                    }
                                    .frame(maxWidth: .infinity)
                                } else {
                                    VStack(spacing: 4) {
                                        Text(currentPace)
                                            .font(.system(size: 20, weight: .black))
                                            .foregroundColor(.primary)
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
                                            .foregroundColor(.primary)
                                        Text("Topphastighet")
                                            .font(.system(size: 12, weight: .semibold))
                                            .foregroundColor(.gray)
                                    }
                                    .frame(maxWidth: .infinity)
                                }
                            }
                            .padding(.horizontal, 16)
                            
                            // Show area capture card (only for running and golf, not skiing)
                            if locationManager.distance > 0.01 && (activity == .running || activity == .golf) {
                                VStack(spacing: 2) {
                                    Image(systemName: "wifi")
                                        .font(.system(size: 12))
                                        .foregroundColor(.red)
                                    Text(formatArea(estimatePolygonArea(routeCoordinatesSnapshot)))
                                        .font(.system(size: 28, weight: .black))
                                        .foregroundColor(.primary)
                                    Text("Ditt område")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(.gray)
                                }
                                .padding(.vertical, 12)
                                .padding(.horizontal, 24)
                                .background(
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .fill(Color(.secondarySystemBackground))
                                        .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 2)
                                )
                                .padding(.bottom, 8)
                            }
                        }
                        
                        // Expand/Collapse handle - Only show when running (not paused)
                        if isRunning && !isPaused {
                            Button(action: {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    isStatsExpanded.toggle()
                                }
                            }) {
                                HStack(spacing: 4) {
                                    Image(systemName: isStatsExpanded ? "chevron.down" : "chevron.up")
                                        .font(.system(size: 12, weight: .bold))
                                    Text(isStatsExpanded ? "Dölj statistik" : "Visa statistik")
                                        .font(.system(size: 12, weight: .semibold))
                                }
                                .foregroundColor(.gray)
                                .padding(.vertical, 8)
                            }
                        }
                    } // End of isRunning || isPaused condition for stats

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
                                    checkAndEndSession()
                                }
                            )
                        }
                        .padding(.horizontal, 16)
                    } else {
                        // Running state - Show Start/Pause button
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
                                            
                                            // Notify followers about session start
                                            if let userId = authViewModel.currentUser?.id {
                                                let userName = authViewModel.currentUser?.name ?? "Användare"
                                                Task {
                                                    let currentLocation = locationManager.userLocation.map { CLLocation(latitude: $0.latitude, longitude: $0.longitude) }
                                                    try? await ActiveSessionService.shared.startSession(
                                                        userId: userId,
                                                        activityType: activity.rawValue,
                                                        location: currentLocation,
                                                        userName: userName
                                                    )
                                                    await ActiveSessionService.shared.notifyFollowers(
                                                        userId: userId,
                                                        userName: userName,
                                                        activityType: activity.rawValue
                                                    )
                                                }
                                            }
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
                        
                        // Live photo button - only show when running
                        if isRunning {
                            Button(action: {
                                if !livePhotoTaken {
                                    showLivePhotoCapture = true
                                }
                            }) {
                                HStack(spacing: 8) {
                                    Image(systemName: livePhotoTaken ? "checkmark.circle.fill" : "camera.fill")
                                        .font(.system(size: 14, weight: .semibold))
                                    Text(livePhotoTaken ? "Bild tagen ✓" : "Ta en live bild")
                                        .font(.system(size: 14, weight: .semibold))
                                }
                                .frame(maxWidth: .infinity)
                                .padding(12)
                                .background(livePhotoTaken ? Color.green : Color.white)
                                .foregroundColor(livePhotoTaken ? .white : .black)
                                .cornerRadius(10)
                            }
                            .disabled(livePhotoTaken)
                            .padding(.horizontal, 16)
                            .padding(.top, 8)
                        }
                        
                        // Other activities section - only show when not running
                        if !isRunning {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("Välj annan aktivitet")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(.gray)
                                    .padding(.horizontal, 16)
                                    .padding(.top, 8)
                                
                                HStack(spacing: 12) {
                                    OtherActivityButton(
                                        icon: "figure.walk",
                                        title: "Promenad",
                                        action: {
                                            NotificationCenter.default.post(
                                                name: NSNotification.Name("SwitchActivity"),
                                                object: nil,
                                                userInfo: ["activity": ActivityType.hiking.rawValue]
                                            )
                                        }
                                    )
                                    
                                    OtherActivityButton(
                                        icon: "figure.golf",
                                        title: "Golf",
                                        action: {
                                            NotificationCenter.default.post(
                                                name: NSNotification.Name("SwitchActivity"),
                                                object: nil,
                                                userInfo: ["activity": ActivityType.golf.rawValue]
                                            )
                                        }
                                    )
                                    
                                    OtherActivityButton(
                                        icon: "snowflake",
                                        title: "Skidor",
                                        action: {
                                            NotificationCenter.default.post(
                                                name: NSNotification.Name("SwitchActivity"),
                                                object: nil,
                                                userInfo: ["activity": ActivityType.skiing.rawValue]
                                            )
                                        }
                                    )
                                }
                                .padding(.horizontal, 16)
                            }
                        }
                    }
                }
                .padding(20)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color(.secondarySystemBackground).opacity(0.98))
                        .shadow(radius: 10)
                )
                .padding(16)
            }
            
            // X button to cancel before starting (only show when not running and not paused)
            if !isRunning && !isPaused && !resumeSession {
                VStack {
                    HStack {
                        Button {
                            NotificationCenter.default.post(name: NSNotification.Name("CloseStartSession"), object: nil)
                            dismiss()
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 32, weight: .bold))
                                .foregroundStyle(.black, Color(.systemGray5))
                        }
                        Spacer()
                    }
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.top, 60)
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
        .alert("Fordon detekterat", isPresented: $showVehicleDetectedAlert) {
            Button("OK") {
                // User acknowledges - session is paused but NOT dismissed
                // They can resume when they slow down
                showVehicleDetectedAlert = false
            }
        } message: {
            Text("Tracking pausas. Du verkar färdas med ett fordon. Passet sparas och du kan fortsätta när du saktar ner.")
        }
        .alert("Området kan inte sparas", isPresented: $showTerritoryWarning) {
            Button("Avbryt", role: .cancel) {
                showTerritoryWarning = false
                pendingEndSession = false
            }
            Button("Spara ändå") {
                showTerritoryWarning = false
                endSession(skipTerritoryCapture: true)
            }
        } message: {
            Text("Du är mer än 500 meter från startpunkten. Området kommer inte att sparas på Zonkriget, men du kan spara passet ändå.")
        }
        .onDisappear {
            // Save session state when view disappears, but DON'T stop timer
            // Timer continues in background
            print("📱 [SESSION] SessionMapView disappearing - force saving")
            saveSessionState(force: true)
        }
        .onReceive(RevenueCatManager.shared.$isProMember) { newValue in
            isPremium = newValue
        }
        .fullScreenCover(isPresented: $showTerritoryAnimation) {
            TerritoryCaptureAnimationView(
                routeCoordinates: territoryAnimationCoordinates,
                activityType: activity.rawValue,
                earnedXP: earnedPoints,
                onComplete: {
                    showTerritoryAnimation = false
                    showSessionComplete = true
                }
            )
        }
        .sheet(isPresented: $showSessionComplete) {
            SessionCompleteView(
                activity: activity,
                distance: locationManager.distance,
                duration: sessionDuration,
                earnedPoints: earnedPoints,
                routeImage: routeImage,
                routeCoordinates: territoryAnimationCoordinates.isEmpty ? locationManager.routeCoordinates : territoryAnimationCoordinates,  // Use preserved coordinates
                elevationGain: activity == .skiing && locationManager.elevationGain > 0 ? locationManager.elevationGain : nil,
                maxSpeed: activity == .skiing && locationManager.maxSpeed > 0 ? locationManager.maxSpeed : nil,
                completedSplits: completedSplits,
                gymExercises: nil,  // No gym exercises for regular workouts
                sessionLivePhoto: sessionLivePhoto,  // Pass the live photo taken during session
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
        .sheet(isPresented: $showTakeoverSummary) {
            TakeoverSummaryView(
                users: takeoverUsers,
                isLoading: isLoadingTakeovers,
                onCreatePost: {
                    showTakeoverSummary = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        showSessionComplete = true
                    }
                }
            )
        }
        .sheet(isPresented: $showLivePhotoCapture) {
            LivePhotoCaptureView(
                capturedImage: $sessionLivePhoto,
                onCapture: {
                    livePhotoTaken = true
                }
            )
        }
        // No onChange needed - session is cleared in endSession()
        .onChange(of: scenePhase) { _, newPhase in
            print("📱 [SESSION] ScenePhase changed to \(newPhase)")
            guard sessionStartTime != nil else {
                print("📱 [SESSION] No sessionStartTime - skipping state save")
                return
            }
            if newPhase == .background || newPhase == .inactive {
                print("📥 [SESSION] App going to background/inactive - FORCE saving session state")
                saveSessionState(force: true)
                // Also force save through SessionManager as backup
                SessionManager.shared.forceSaveCurrentSession()
            } else if newPhase == .active {
                print("📱 [SESSION] App became active - session still running: \(isRunning)")
                // Verify session state is intact
                SessionManager.shared.debugPrintState()
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
            
            // Force route snapshot update every 2 seconds for reliability
            if Int(sessionDuration) % 2 == 0 && !locationManager.routeCoordinates.isEmpty {
                let coords = locationManager.routeCoordinates
                if coords.count != routeCoordinatesSnapshot.count {
                    routeCoordinatesSnapshot = coords
                    lastSnapshotSourceCount = coords.count
                    print("⏱️ Timer route update: \(coords.count) points")
                }
            }
            
            // Auto-save session state every 5 seconds to prevent data loss
            if Int(sessionDuration) % 5 == 0 {
                saveSessionState()
            }
            
            // Ping the active session every 2 minutes to keep it alive
            if Int(sessionDuration) % 120 == 0, let userId = authViewModel.currentUser?.id {
                Task {
                    try? await ActiveSessionService.shared.pingSession(userId: userId)
                }
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
        if isPremium {
            earnedPoints = Int(Double(basePoints) * 1.5)
        } else {
            earnedPoints = basePoints
        }
    }
    
    // MARK: - Speed Detection for Anti-Cheat
    
    private func checkSpeedForCheating(currentSpeed: Double) {
        // Only check for running and golf (not skiing or other activities)
        guard activity == .running || activity == .golf else { return }
        
        // Get the appropriate speed limit for the activity
        let maxSpeed = activity == .running ? maxSpeedRunning : maxSpeedGolf
        
        if currentSpeed > maxSpeed {
            // Speed is above threshold
            if highSpeedStartTime == nil {
                // Start tracking high speed duration
                highSpeedStartTime = Date()
                print("⚠️ High speed detected: \(String(format: "%.1f", currentSpeed)) km/h (limit: \(maxSpeed) km/h)")
            } else if let startTime = highSpeedStartTime {
                // Check how long we've been at high speed
                let duration = Date().timeIntervalSince(startTime)
                
                if duration >= highSpeedDurationThreshold {
                    if !hasShownSpeedWarning {
                        // Show warning first
                        hasShownSpeedWarning = true
                        print("⚠️ Speed warning shown after \(duration) seconds")
                        // Give them a chance to slow down
                    } else {
                        // Already warned, now stop tracking
                        print("🚗 Vehicle detected after sustained high speed - stopping tracking")
                        stopTrackingDueToVehicle()
                    }
                }
            }
        } else {
            // Speed is acceptable, reset the timer
            if highSpeedStartTime != nil {
                print("✅ Speed returned to normal: \(String(format: "%.1f", currentSpeed)) km/h")
            }
            highSpeedStartTime = nil
            // Don't reset hasShownSpeedWarning - if they speed up again, we go straight to stop
        }
    }
    
    private func stopTrackingDueToVehicle() {
        trackingStoppedDueToSpeed = true
        showVehicleDetectedAlert = true
        
        // Stop the session
        if isRunning {
            stopTimer()
            locationManager.stopTracking()
            isRunning = false
            isPaused = true
        }
    }
    
    private func refreshRouteSnapshotIfNeeded(force: Bool = false) {
        let sourceCount = locationManager.routeCoordinates.count
        let now = Date()
        
        // Force update bypasses throttling
        if force {
            lastRouteUpdateTime = now
            refreshRouteSnapshot(force: true)
            return
        }
        
        guard sourceCount > 0 else {
            routeCoordinatesSnapshot = []
            lastSnapshotSourceCount = 0
            return
        }
        
        // Throttle updates to prevent lag
        let timeSinceLastUpdate = now.timeIntervalSince(lastRouteUpdateTime)
        guard timeSinceLastUpdate >= routeUpdateInterval else { return }
        
        // Only refresh if points changed
        if sourceCount != lastSnapshotSourceCount {
            lastRouteUpdateTime = now
            refreshRouteSnapshot(force: false)
        }
    }

    private func updateLiveTerritoryArea() {
        let now = Date()
        
        // Throttle area calculations - expensive operation
        guard now.timeIntervalSince(lastAreaUpdateTime) >= areaUpdateInterval else { return }
        
        guard locationManager.routeCoordinates.count > 2 else {
            liveTerritoryArea = 0
            return
        }
        
        lastAreaUpdateTime = now
        
        // Calculate area in background to avoid blocking UI
        let coords = locationManager.routeCoordinates
        Task.detached(priority: .utility) {
            var closedCoords = coords
            if let first = closedCoords.first {
                closedCoords.append(first) // Close the loop
            }
            
            let area = TerritoryStore.shared.calculateArea(coordinates: closedCoords)
            await MainActor.run {
                self.liveTerritoryArea = area
            }
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
        
        // Directly update snapshot for real-time responsiveness
        // Only simplify if we have many points
        if coordinates.count <= maxRouteSnapshotPoints {
            routeCoordinatesSnapshot = coordinates
        } else {
            // Simplify synchronously but efficiently - avoid async overhead for small simplifications
            let simplified = simplifyRoute(coordinates, targetCount: maxRouteSnapshotPoints)
            routeCoordinatesSnapshot = simplified
        }
    }
    
    private func simplifyRoute(_ coordinates: [CLLocationCoordinate2D], targetCount: Int) -> [CLLocationCoordinate2D] {
        guard coordinates.count > targetCount, targetCount > 0 else {
            return coordinates
        }
        
        // More aggressive simplification for better performance
        let step = coordinates.count / targetCount
        var simplified: [CLLocationCoordinate2D] = []
        simplified.reserveCapacity(targetCount + 2)
        
        // Always include first point
        if let first = coordinates.first {
            simplified.append(first)
        }
        
        // Sample every nth point
        var lastIndex = 0
        for index in stride(from: step, to: coordinates.count - 1, by: step) {
            simplified.append(coordinates[index])
            lastIndex = index
        }
        
        // Always include last point
        if let last = coordinates.last, lastIndex < coordinates.count - 1 {
            simplified.append(last)
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
    
    func saveSessionState(force: Bool = false) {
        guard let startTime = sessionStartTime else {
            print("⚠️ No startTime, not saving")
            return
        }
        
        print("🔍 saveSessionState - isSessionEnding: \(isSessionEnding), force: \(force)")
        
        // Don't save if we're in the process of ending the session (unless forced)
        if isSessionEnding && !force {
            print("🛑 Not saving session state - session is ending (isSessionEnding = true)")
            return
        }

        // Auto-cancel sessions that have been running in the background for more than 2 hours
        if UIApplication.shared.applicationState != .active && !force {
            let elapsed = Date().timeIntervalSince(startTime)
            if elapsed >= 2 * 3600 {
                print("⏰ Session auto-cancelled after 2h in background")
                cancelBackgroundTimedOutSession()
                return
            }
        }
        
        // Get route coordinates from location manager
        let coords = locationManager.routeCoordinates
        let currentDistance = locationManager.distance
        
        print("💾 Saving session state: duration=\(sessionDuration)s, distance=\(String(format: "%.2f", currentDistance))km, coords=\(coords.count)")
        
        // Save to SessionManager
        sessionManager.saveActiveSession(
            activityType: activity.rawValue,
            startTime: startTime,
            isPaused: isPaused,
            duration: sessionDuration,
            distance: currentDistance,
            routeCoordinates: coords,
            completedSplits: completedSplits,
            elevationGain: locationManager.elevationGain > 0 ? locationManager.elevationGain : nil,
            maxSpeed: locationManager.maxSpeed > 0 ? locationManager.maxSpeed : nil,
            force: force
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
        showTerritoryAnimation = false
        territoryAnimationCoordinates = []
        forceNewSession = true
    }

    func stopTimer() {
        isRunning = false
        timer?.invalidate()
        timer = nil
    }
    
    /// Check if user is close enough to start point before ending session
    func checkAndEndSession() {
        // Only check for running and golf (territory-capturing activities)
        guard activity == .running || activity == .golf else {
            endSession(skipTerritoryCapture: false)
            return
        }
        
        // Check if we have enough route coordinates and a start point
        guard let startCoord = locationManager.routeCoordinates.first,
              let currentLocation = locationManager.userLocation else {
            // No start point or current location - just end session normally
            endSession(skipTerritoryCapture: false)
            return
        }
        
        // Calculate distance from current location to start point
        let startLocation = CLLocation(latitude: startCoord.latitude, longitude: startCoord.longitude)
        let currentLoc = CLLocation(latitude: currentLocation.latitude, longitude: currentLocation.longitude)
        let distanceFromStart = currentLoc.distance(from: startLocation)
        
        print("📏 Distance from start: \(distanceFromStart)m (max: \(maxDistanceFromStartForTerritory)m)")
        
        if distanceFromStart > maxDistanceFromStartForTerritory {
            // Too far from start - show warning
            showTerritoryWarning = true
            pendingEndSession = true
        } else {
            // Close enough - end session normally with territory capture
            endSession(skipTerritoryCapture: false)
        }
    }
    
    func endSession(skipTerritoryCapture: Bool = false) {
        print("🏁 Ending session... (skipTerritoryCapture: \(skipTerritoryCapture))")
        print("📍 BEFORE STOP - routeCoordinates.count: \(locationManager.routeCoordinates.count)")
        
        // Cancel any active session reminder notifications
        NotificationManager.shared.cancelActiveSessionReminders()
        
        // Get user ID early to ensure we can save territory
        guard let userId = authViewModel.currentUser?.id else {
            print("⚠️ No user ID found in endSession, cannot claim territory")
            return
        }
        
        // End active session for friends map
        Task {
            try? await ActiveSessionService.shared.endSession(userId: userId)
        }
        print("✅ User ID found: \(userId)")
        
        // IMPORTANT: Capture coordinates BEFORE stopping tracking
        let finalRouteCoordinates = locationManager.routeCoordinates
        let finalUserLocation = locationManager.userLocation
        print("📍 CAPTURED finalRouteCoordinates.count: \(finalRouteCoordinates.count)")
        
        // NOW stop timer and tracking
        isSessionEnding = true
        stopTimer()
        locationManager.stopTracking()
        print("🛑 Timer stopped, isSessionEnding = true")
        
        // Save session data before showing completion
        print("💾 Distance: \(locationManager.distance) km")
        print("💾 Duration: \(sessionDuration) seconds")
        print("💾 Route points (final): \(finalRouteCoordinates.count)")
        
        // Generate route snapshot
        MapSnapshotService.shared.generateRouteSnapshot(
            routeCoordinates: finalRouteCoordinates,
            userLocation: finalUserLocation,
            activity: activity
        ) { snapshotImage in
            print("🗺️ Route snapshot generation completed")
            if let snapshotImage = snapshotImage {
                print("✅ Route snapshot generated successfully")
                DispatchQueue.main.async {
                    self.routeImage = snapshotImage
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
        if isPremium {
            earnedPoints = Int(Double(basePoints) * 1.5)
        } else {
            earnedPoints = basePoints
        }
        
        // Update streak
        StreakManager.shared.registerActivityCompletion()
        
        // Capture territory - only if not skipped
        if !skipTerritoryCapture {
            // Only running and golf can take over tiles
            if activity == .running || activity == .golf {
                isLoadingTakeovers = true
                Task { @MainActor in
                    let store = TerritoryStore.shared
                    
                    let takeovers = await store.finalizeTerritoryCaptureAndReturnTakeovers(
                        activity: activity,
                        routeCoordinates: finalRouteCoordinates,
                        userId: userId,
                        sessionDistance: locationManager.distance,
                        sessionDuration: sessionDuration,
                        sessionPace: currentPace
                    )
                    
                    if !takeovers.isEmpty {
                        print("🎯 Captured territory with \(takeovers.count) takeovers")
                    } else {
                        print("🎯 Captured territory (no takeovers)")
                    }
                    
                    // Wait briefly before showing session complete
                    try? await Task.sleep(nanoseconds: 500_000_000)
                    self.isLoadingTakeovers = false
                    
                    // Show session complete
                    self.updateEarnedPoints()
                    print("🎉 Earned points: \(self.earnedPoints), Distance: \(self.locationManager.distance)")
                    self.showSessionComplete = true
                }
                
                // Preserve coordinates for animation or post saving
                self.territoryAnimationCoordinates = finalRouteCoordinates
                
            } else {
                // For other activities (biking, etc.), just show session complete
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    self.updateEarnedPoints()
                    print("🎉 Earned points: \(self.earnedPoints), Distance: \(self.locationManager.distance)")
                    self.showSessionComplete = true
                }
            }
        } else {
            print("⏭️ Skipping territory capture (user chose to save without territory)")
            self.territoryAnimationCoordinates = [] // No animation if skipped
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                self.updateEarnedPoints()
                print("🎉 Earned points: \(self.earnedPoints), Distance: \(self.locationManager.distance)")
                self.showSessionComplete = true
            }
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
    
    func estimatePolygonArea(_ coordinates: [CLLocationCoordinate2D]) -> Double {
        guard coordinates.count > 2 else { return 0 }
        // Use shoelace formula on projected meters (Mercator projection roughly)
        // Approximate meters per degree
        let metersPerLat = 111132.954 - 559.822 * cos(2 * coordinates[0].latitude * .pi / 180) + 1.175 * cos(4 * coordinates[0].latitude * .pi / 180)
        let metersPerLon = 111132.954 * cos(coordinates[0].latitude * .pi / 180)
        
        var area: Double = 0.0
        let j = coordinates.count - 1
        
        var prev = coordinates[j]
        for curr in coordinates {
            area += (prev.longitude + curr.longitude) * (prev.latitude - curr.latitude)
            prev = curr
        }
        
        // Correct shoelace with conversion
        return abs(area / 2.0) * metersPerLat * metersPerLon
    }
    
    func formatArea(_ area: Double) -> String {
        if area > 1_000_000 {
            let km2 = area / 1_000_000
            return String(format: "%.2f km²", km2)
        }
        return String(format: "%.0f m²", area)
    }
    
    // MARK: - Route Canvas View
    @ViewBuilder
    private var routeCanvasOverlay: some View {
        GeometryReader { geometry in
            Canvas { context, size in
                drawRouteCanvas(context: context, size: size)
            }
            .id("canvas-\(routeCoordinatesSnapshot.count)")
            .allowsHitTesting(false)
        }
        .allowsHitTesting(false)
    }
    
    private func drawRouteCanvas(context: GraphicsContext, size: CGSize) {
        let currentSnapshot = routeCoordinatesSnapshot
        let localRoutePoints = currentSnapshot.map { convertToMapPoint($0, in: size) }
        
        // 1. Previously captured active territories
        for territory in territoryStore.activeSessionTerritories {
            for polygon in territory.polygons {
                guard polygon.count > 2 else { continue }
                let points = polygon.map { convertToMapPoint($0, in: size) }
                var path = Path()
                if let first = points.first {
                    path.move(to: first)
                    for point in points.dropFirst() {
                        path.addLine(to: point)
                    }
                    path.closeSubpath()
                }
                context.fill(path, with: .color(territory.color.opacity(0.4)))
                context.stroke(path, with: .color(territory.color), lineWidth: 2)
            }
        }
        
        // 2. Live territory fill (running/golf only)
        if localRoutePoints.count >= 2 && (activity == .running || activity == .golf) {
            var fillPath = Path()
            if let first = localRoutePoints.first {
                fillPath.move(to: first)
                for point in localRoutePoints.dropFirst() {
                    fillPath.addLine(to: point)
                }
                fillPath.closeSubpath()
            }
            context.fill(fillPath, with: .color(.green.opacity(0.3)))
            
            // Dashed closing line
            if let first = localRoutePoints.first, let last = localRoutePoints.last {
                var dashPath = Path()
                dashPath.move(to: last)
                dashPath.addLine(to: first)
                context.stroke(dashPath, with: .color(.black), style: StrokeStyle(lineWidth: 2, dash: [5, 5]))
            }
        }
        
        // 3. Route line
        if localRoutePoints.count > 1 {
            var routePath = Path()
            routePath.move(to: localRoutePoints[0])
            for point in localRoutePoints.dropFirst() {
                routePath.addLine(to: point)
            }
            context.stroke(routePath, with: .color(.black), lineWidth: 4)
        }
        
        // 4. Start marker
        if let first = localRoutePoints.first {
            let markerSize: CGFloat = 14
            let markerRect = CGRect(x: first.x - markerSize/2, y: first.y - markerSize/2, width: markerSize, height: markerSize)
            context.fill(Circle().path(in: markerRect), with: .color(.green))
            context.stroke(Circle().path(in: markerRect), with: .color(.white), lineWidth: 2)
        }
    }
}

// MARK: - Takeover Summary View
struct TakeoverSummaryView: View {
    let users: [TileTakeoverRow]
    let isLoading: Bool
    let onCreatePost: () -> Void
    @Environment(\.dismiss) private var dismiss
    
    private var peopleCountText: String {
        users.count == 1 ? "1 person" : "\(users.count) personer"
    }
    
    private var titleText: String {
        users.count == 1 ? "Du tog över \(peopleCountText)s område" : "Du tog över \(peopleCountText)s områden"
    }
    
    private var totalTilesTaken: Int {
        users.reduce(0) { $0 + $1.tilesTaken }
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // Hero
                    VStack(spacing: 12) {
                        HStack(alignment: .top, spacing: 12) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(.ultraThinMaterial)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                                            .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                                    )
                                Image(systemName: "crown.fill")
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundColor(.yellow)
                            }
                            .frame(width: 46, height: 46)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(titleText)
                                    .font(.system(size: 24, weight: .black))
                                    .foregroundColor(.primary)
                                    .fixedSize(horizontal: false, vertical: true)
                                
                                Text("Bra jobbat! Här är alla du tog över ifrån.")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                        }
                        
                        // Stats chips
                        HStack(spacing: 10) {
                            statChip(title: "Personer", value: "\(users.count)")
                            statChip(title: "Rutor", value: "\(totalTilesTaken)")
                            Spacer()
                        }
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(Color(.secondarySystemBackground))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(Color.primary.opacity(0.06), lineWidth: 1)
                    )
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    
                    // List card
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Övertagna spelare")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.primary)
                            Spacer()
                            if isLoading {
                                ProgressView().tint(.secondary)
                            }
                        }
                        
                        if isLoading {
                            VStack(spacing: 12) {
                                ProgressView()
                                    .tint(.primary)
                                Text("Räknar övertaganden…")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                        } else if users.isEmpty {
                            Text("Inga övertaganden den här rundan.")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.vertical, 8)
                        } else {
                            VStack(spacing: 0) {
                                ForEach(Array(users.enumerated()), id: \.element.id) { index, user in
                                    HStack(spacing: 12) {
                                        OptimizedAsyncImage(
                                            url: user.avatarUrl,
                                            width: 46,
                                            height: 46,
                                            cornerRadius: 23
                                        )
                                        
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(user.username ?? "Användare")
                                                .font(.system(size: 16, weight: .bold))
                                                .foregroundColor(.primary)
                                            Text("\(user.tilesTaken) rutor")
                                                .font(.system(size: 13, weight: .semibold))
                                                .foregroundColor(.secondary)
                                        }
                                        
                                        Spacer()
                                        
                                        Text("\(user.tilesTaken)")
                                            .font(.system(size: 14, weight: .bold))
                                            .foregroundColor(.primary)
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 6)
                                            .background(Color.primary.opacity(0.06))
                                            .clipShape(Capsule())
                                    }
                                    .padding(.vertical, 10)
                                    
                                    if index != users.count - 1 {
                                        Divider()
                                            .opacity(0.5)
                                    }
                                }
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(Color(.systemBackground))
                            )
                        }
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(Color(.secondarySystemBackground))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(Color.primary.opacity(0.06), lineWidth: 1)
                    )
                    .padding(.horizontal, 16)
                    
                    // Extra filler card so screen doesn't feel empty for 1 person
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Tips")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.primary)
                        Text("Skapa ett inlägg och visa upp ditt övertagande så dina vänner kan supporta.")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(Color(.secondarySystemBackground))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(Color.primary.opacity(0.06), lineWidth: 1)
                    )
                    .padding(.horizontal, 16)
                    .padding(.bottom, 90) // space for sticky button
                }
                .padding(.top, 8)
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundStyle(.gray, Color(.systemGray5))
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 0) {
                    Divider().opacity(0.3)
                    Button {
                        onCreatePost()
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "square.and.pencil")
                                .font(.system(size: 16, weight: .semibold))
                            Text("Skapa inlägg")
                                .font(.system(size: 16, weight: .black))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.black)
                        .cornerRadius(16)
                    }
                    .disabled(isLoading || users.isEmpty)
                    .opacity((isLoading || users.isEmpty) ? 0.6 : 1.0)
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 12)
                    .background(.ultraThinMaterial)
                }
            }
        }
    }
    
    private func statChip(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title.uppercased())
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.secondary)
            Text(value)
                .font(.system(size: 18, weight: .black))
                .foregroundColor(.primary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.primary.opacity(0.06), lineWidth: 1)
        )
    }
}

// MARK: - Other Activity Button
struct OtherActivityButton: View {
    let icon: String
    let title: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(.primary)
                Text(title)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.primary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.gray.opacity(0.12))
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    StartSessionView()
        .environmentObject(AuthViewModel())
}
