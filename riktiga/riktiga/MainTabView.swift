import SwiftUI
import Combine
import UIKit
import MapKit
import CoreLocation
import Supabase

// MARK: - Navigation Depth Tracker
class NavigationDepthTracker: ObservableObject {
    static let shared = NavigationDepthTracker()
    @Published var isAtRootView = true
    private var navigationDepth = 0
    
    func pushView() {
        navigationDepth += 1
        isAtRootView = false
    }
    
    func popView() {
        navigationDepth = max(0, navigationDepth - 1)
        isAtRootView = navigationDepth == 0
    }
    
    func setAtRoot(_ atRoot: Bool) {
        if atRoot {
            popView()
        } else {
            pushView()
        }
    }
    
    func resetToRoot() {
        navigationDepth = 0
        isAtRootView = true
    }
}

// MARK: - View Modifier for tracking navigation
struct NavigationTrackingModifier: ViewModifier {
    let isRoot: Bool
    
    func body(content: Content) -> some View {
        content
            .onAppear {
                NavigationDepthTracker.shared.setAtRoot(isRoot)
            }
    }
}

extension View {
    func trackNavigation(isRoot: Bool) -> some View {
        modifier(NavigationTrackingModifier(isRoot: isRoot))
    }
}

struct MainTabView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @ObservedObject private var navigationTracker = NavigationDepthTracker.shared
    @ObservedObject private var notificationNav = NotificationNavigationManager.shared
    @ObservedObject private var sessionManager = SessionManager.shared
    @ObservedObject private var scanLimitManager = AIScanLimitManager.shared
    @ObservedObject private var revenueCatManager = RevenueCatManager.shared
    @Environment(\.scenePhase) private var scenePhase
    @State private var hasActiveSession = SessionManager.shared.hasActiveSession
    @State private var showStartSession = false
    @State private var startActivityType: ActivityType? = .running
    @State private var showResumeSession = false
    @State private var selectedTab = 0  // 0=Hem (Social), 1=Kalorier (Home), 2=Belöningar, 3=Profil
    @State private var previousTab = 0
    @State private var autoPresentedActiveSession = false
    @State private var showDiscardConfirmation = false
    @State private var showAddMealSheet = false
    @State private var showFoodScanner = false
    @State private var initialScannerMode: FoodScanMode = .ai
    @State private var showAIScanPaywall = false
    @State private var showManualEntry = false
    @State private var showProWelcome = false
    
    private let hapticGenerator = UIImpactFeedbackGenerator(style: .heavy)
    
    // Check if iOS 26+ for Liquid Glass
    private var supportsLiquidGlass: Bool {
        if #available(iOS 26.0, *) {
            return true
        }
        return false
    }
    
    // Tab items data - 4 tabs now (removed Starta pass)
    private let tabItems: [(icon: String, title: String)] = [
        ("house.fill", "Hem"),
        ("fork.knife", "Kalorier"),
        ("gift.fill", "Belöningar"),
        ("person.fill", "Profil")
    ]
    
    var body: some View {
        Group {
            // Use the same custom tab bar with Tracka button for all iOS versions
            legacyTabView
        }
        .fullScreenCover(isPresented: $showStartSession) {
            StartSessionView(initialActivity: startActivityType ?? .running)
                .id(startActivityType ?? .running)
                .ignoresSafeArea()
        }
        .fullScreenCover(isPresented: $showResumeSession) {
            StartSessionView()
                .ignoresSafeArea()
        }
        .fullScreenCover(isPresented: $showFoodScanner) {
            FoodScannerView(initialMode: initialScannerMode)
        }
        .fullScreenCover(isPresented: $showManualEntry) {
            ManualFoodEntryView()
                .environmentObject(authViewModel)
        }
        .fullScreenCover(isPresented: $showProWelcome) {
            ProWelcomeView(onDismiss: {
                showProWelcome = false
            })
        }
        .onReceive(NotificationCenter.default.publisher(for: .userBecamePro)) { _ in
            // Small delay to let the paywall dismiss first
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                showProWelcome = true
            }
        }
        .onAppear {
            if hasActiveSession && !showStartSession && !showResumeSession {
                autoPresentedActiveSession = true
                showResumeSession = true
            }
            hapticGenerator.prepare()
        }
        .onChange(of: showStartSession) { _, newValue in
            if newValue {
                showResumeSession = false
            }
        }
        .onChange(of: showResumeSession) { _, newValue in
            if newValue {
                showStartSession = false
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("NavigateToSocial"))) { _ in
            selectedTab = 1
            showStartSession = false
            showResumeSession = false
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("SwitchActivity"))) { note in
            // Check userInfo first, then object for backwards compatibility
            if let userInfo = note.userInfo,
               let name = userInfo["activity"] as? String,
               let activity = ActivityType(rawValue: name) {
                startActivityType = activity
            } else if let name = note.object as? String, let activity = ActivityType(rawValue: name) {
                startActivityType = activity
            } else {
                startActivityType = .running
            }
            showResumeSession = false
            showStartSession = true
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("CloseStartSession"))) { _ in
            showStartSession = false
            showResumeSession = false
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("NavigateToRewards"))) { _ in
            selectedTab = 2  // Belöningar is now at index 2
            showStartSession = false
            showResumeSession = false
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("NavigateToSocial"))) { _ in
            selectedTab = 1  // Socialt tab
            showStartSession = false
            showResumeSession = false
        }
        .onChange(of: notificationNav.shouldNavigateToNews) { _, shouldNavigate in
            if shouldNavigate {
                selectedTab = 1  // Switch to Socialt tab
                // Post notification to SocialView to switch to News tab
                NotificationCenter.default.post(name: NSNotification.Name("NavigateToNewsTab"), object: nil)
                notificationNav.resetNavigation()
            }
        }
        .onChange(of: notificationNav.shouldNavigateToPost) { _, postId in
            if let postId = postId {
                selectedTab = 1  // Switch to Socialt tab
                // Post notification to SocialView to open the specific post
                NotificationCenter.default.post(
                    name: NSNotification.Name("NavigateToPost"),
                    object: nil,
                    userInfo: ["postId": postId]
                )
                notificationNav.resetNavigation()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("SessionFinalized"))) { _ in
            showStartSession = false
            showResumeSession = false
            autoPresentedActiveSession = false
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("OpenAIFoodScanner"))) { _ in
            // Open the AI food scanner (for adding story from story circle)
            initialScannerMode = .ai
            showFoodScanner = true
        }
        .sheet(isPresented: $authViewModel.showUsernameRequiredPopup) {
            UsernameRequiredView().environmentObject(authViewModel)
        }
        .sheet(isPresented: $authViewModel.showPaywallAfterSignup) {
            PaywallAfterSignupView().environmentObject(authViewModel)
        }
        .onReceive(SessionManager.shared.$hasActiveSession) { newValue in
            hasActiveSession = newValue
        }
        .onChange(of: hasActiveSession) { _, newValue in
            if newValue {
                if !autoPresentedActiveSession && !showStartSession && !showResumeSession {
                    autoPresentedActiveSession = true
                    showResumeSession = true
                }
            } else {
                autoPresentedActiveSession = false
            }
        }
        .onChange(of: selectedTab) { oldTab, newTab in
            // Haptic feedback when switching tabs
            if oldTab != newTab {
                triggerTabSwitchHaptic()
            }
            
            // Reset to root view when switching tabs
            navigationTracker.resetToRoot()
            
            // Smart memory cleanup based on which tabs are involved
            Task.detached(priority: .utility) {
                // Light cleanup when leaving map-heavy views
                if oldTab == 0 { // Leaving Home/ZoneWar
                    await MainActor.run {
                        ImageCacheManager.shared.trimCache()
                    }
                }
                
                if oldTab == 1 { // Leaving Social
                    await MainActor.run {
                        SocialViewModel.invalidateCache()
                    }
                }
            }
            
            // Store previous tab
            previousTab = oldTab
        }
        .onChange(of: scenePhase) {
            if scenePhase == .active {
                // Reset failure counter and refresh auth session when app becomes active
                AuthSessionManager.shared.resetFailureCounter()
                
                Task {
                    do {
                        try await AuthSessionManager.shared.ensureValidSession()
                        print("✅ Auth session verified on app activation")
                    } catch let authError as AuthError {
                        // NEVER logout if there's an active workout session!
                        if SessionManager.shared.hasActiveSession {
                            print("⚠️ Auth error but ACTIVE SESSION exists - NOT logging out to protect workout")
                            return
                        }
                        
                        // Only logout on true auth errors (session missing), not network issues
                        if case .sessionMissing = authError {
                            print("❌ Session truly missing - logging out")
                            authViewModel.logout()
                        } else {
                            print("⚠️ Auth error but not logging out: \(authError)")
                        }
                    } catch {
                        // Network/other errors - don't logout, just log
                        print("⚠️ Session check failed (network?): \(error) - NOT logging out")
                    }
                }
            }
        }
        .onReceive(Timer.publish(every: 600, on: .main, in: .common).autoconnect()) { _ in
            // Periodic session refresh every 10 minutes while app is active
            if scenePhase == .active {
                Task {
                    do {
                        try await AuthSessionManager.shared.ensureValidSession()
                        print("✅ Periodic session refresh successful")
                    } catch {
                        print("⚠️ Periodic session refresh failed: \(error)")
                    }
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didReceiveMemoryWarningNotification)) { _ in
            // System is low on memory - clear caches aggressively
            print("⚠️ Memory warning received - clearing caches")
            ImageCacheManager.shared.clearCache()
            TerritoryStore.shared.invalidateCache()
            SocialViewModel.invalidateCache()
        }
    }
    
    // MARK: - iOS 26+ Liquid Glass Tab View
    @available(iOS 26.0, *)
    private var liquidGlassTabView: some View {
        ZStack(alignment: .bottom) {
            // Native TabView with built-in Liquid Glass effect
            TabView(selection: $selectedTab) {
                Tab("Hem", systemImage: "house.fill", value: 0) {
                    SocialView()
                }
                
                Tab("Kalorier", systemImage: "fork.knife", value: 1) {
                    HomeContainerView()
                }
                
                Tab("Belöningar", systemImage: "gift.fill", value: 2) {
                    RewardsView()
                }
                
                Tab("Profil", systemImage: "person.fill", value: 3) {
                    ProfileContainerView()
                }
            }
            .allowsHitTesting(!showAddMealSheet)
            
            // Add Meal Overlay - always rendered but hidden for smooth transitions
            addMealOverlay
                .opacity(showAddMealSheet ? 1 : 0)
                .allowsHitTesting(showAddMealSheet)
            
            // Floating active session banner
            if sessionManager.hasActiveSession && !showStartSession && !showResumeSession && !showAddMealSheet {
                activeSessionBanner
                    .padding(.bottom, 100)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: sessionManager.hasActiveSession)
        .animation(.easeOut(duration: 0.15), value: showAddMealSheet)
    }
    
    // MARK: - Add Meal Overlay
    private var addMealOverlay: some View {
        ZStack {
            // Semi-transparent background that closes the menu when tapped
            Color.black.opacity(showAddMealSheet ? 0.3 : 0)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation(.easeOut(duration: 0.15)) {
                        showAddMealSheet = false
                    }
                }
            
            VStack {
                Spacer()
                
                VStack(spacing: 12) {
                    HStack(spacing: 12) {
                        addMealOption(icon: "dumbbell.fill", title: "Starta pass") {
                            showAddMealSheet = false
                            startActivityType = .walking
                            showStartSession = true
                        }
                        .scaleEffect(showAddMealSheet ? 1 : 0.8)
                        
                        addMealOption(icon: "barcode.viewfinder", title: "Scanna streckkod") {
                            showAddMealSheet = false
                            initialScannerMode = .barcode
                            showFoodScanner = true
                        }
                        .scaleEffect(showAddMealSheet ? 1 : 0.8)
                    }
                    
                    HStack(spacing: 12) {
                        addMealOption(icon: "pencil.line", title: "Regga manuellt") {
                            showAddMealSheet = false
                            showManualEntry = true
                        }
                        .scaleEffect(showAddMealSheet ? 1 : 0.8)
                        
                        // AI Scan - check if limit reached for non-pro users
                        if !revenueCatManager.isProMember && scanLimitManager.isAtLimit() {
                            aiScanLimitedOption()
                                .scaleEffect(showAddMealSheet ? 1 : 0.8)
                        } else {
                            aiScanOption {
                                showAddMealSheet = false
                                initialScannerMode = .ai
                                showFoodScanner = true
                            }
                            .scaleEffect(showAddMealSheet ? 1 : 0.8)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }
        }
    }
    
    private func addMealOption(icon: String, title: String, action: @escaping () -> Void) -> some View {
        Button(action: {
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.impactOccurred()
            action()
        }) {
            VStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 24))
                    .foregroundColor(.primary)
                
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.primary)
            }
            .frame(width: 150, height: 120)
            .background(mealOptionBackground)
        }
    }
    
    @ViewBuilder
    private var mealOptionBackground: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(.regularMaterial)
            .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 5)
    }
    
    // AI Scan option with logo and stars
    private func aiScanOption(action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 8) {
                ZStack {
                    // Stars around the logo
                    Image(systemName: "sparkles")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.primary)
                        .offset(x: -20, y: -12)
                    
                    Image(systemName: "sparkle")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.primary)
                        .offset(x: 18, y: -14)
                    
                    Image(systemName: "sparkle")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(.primary.opacity(0.6))
                        .offset(x: 22, y: 2)
                    
                    // App logo with rounded corners
                    Image("23")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 36, height: 36)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .frame(height: 44)
                
                Text("Ta bild med AI")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.primary)
            }
            .frame(width: 150, height: 120)
            .background(mealOptionBackground)
        }
    }
    
    private func disabledMealOption(icon: String, title: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(.gray.opacity(0.5))
            
            Text(title)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.gray.opacity(0.5))
        }
        .frame(width: 150, height: 120)
        .background(disabledMealOptionBackground)
    }
    
    @ViewBuilder
    private var disabledMealOptionBackground: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(.regularMaterial)
            .opacity(0.7)
            .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 4)
    }
    
    // AI Scan limited option (shows paywall when tapped)
    private func aiScanLimitedOption() -> some View {
        Button {
            withAnimation { showAddMealSheet = false }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                SuperwallService.shared.showPaywall()
            }
        } label: {
            VStack(spacing: 8) {
                ZStack {
                    // Stars around the logo (grayed)
                    Image(systemName: "sparkles")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.gray.opacity(0.3))
                        .offset(x: -20, y: -12)
                    
                    Image(systemName: "sparkle")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.gray.opacity(0.3))
                        .offset(x: 18, y: -14)
                    
                    // App logo (grayed) with rounded corners
                    Image("23")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 36, height: 36)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .opacity(0.4)
                    
                    // Lock badge
                    Image(systemName: "lock.fill")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                        .padding(5)
                        .background(Color.gray)
                        .clipShape(Circle())
                        .offset(x: 20, y: -8)
                }
                .frame(height: 44)
                
                Text("Ta bild med AI")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.gray.opacity(0.5))
                
                Text("0 kvar")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.orange)
            }
            .frame(width: 150, height: 120)
            .background(disabledMealOptionBackground)
        }
    }
    
    // MARK: - Legacy Tab View (iOS 25 and earlier)
    private var legacyTabView: some View {
        ZStack(alignment: .bottom) {
            // Content views based on selected tab - instant switch
            Group {
                switch selectedTab {
                case 0:
                    SocialView()
                case 1:
                    HomeContainerView()
                case 2:
                    RewardsView()
                case 3:
                    ProfileContainerView()
                default:
                    Color.clear
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .allowsHitTesting(!showAddMealSheet)
            
            // Add Meal Overlay - always rendered but hidden for smooth transitions
            addMealOverlay
                .opacity(showAddMealSheet ? 1 : 0)
                .allowsHitTesting(showAddMealSheet)
            
            // Floating active session banner
            if sessionManager.hasActiveSession && !showStartSession && !showResumeSession && !showAddMealSheet {
                activeSessionBanner
                    .padding(.bottom, 100) // Above tab bar
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            
            // Custom Tab Bar with + button - hide when navigating to subpages
            if !showAddMealSheet && navigationTracker.isAtRootView {
                legacyCustomTabBar
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: sessionManager.hasActiveSession)
        .animation(.easeOut(duration: 0.15), value: showAddMealSheet)
        .animation(.easeOut(duration: 0.25), value: navigationTracker.isAtRootView)
    }
    
    // MARK: - Legacy Custom Tab Bar (Golf GameBook style)
    private var legacyCustomTabBar: some View {
        VStack(spacing: 0) {
            // Top border line
            Rectangle()
                .fill(Color(.systemGray4))
                .frame(height: 0.5)
            
            // Tab bar content - all 5 items in one row
            HStack(spacing: 0) {
                // Tab 0: Hem
                FixedTabBarItem(
                    icon: tabItems[0].icon,
                    title: tabItems[0].title,
                    isSelected: selectedTab == 0,
                    action: {
                        // Always pop to root and reset navigation tracker
                        NotificationCenter.default.post(name: NSNotification.Name("PopToRootHem"), object: nil)
                        NavigationDepthTracker.shared.resetToRoot()
                        if selectedTab != 0 {
                            switchToTab(0)
                        }
                    }
                )
                
                // Tab 1: Kalorier
                FixedTabBarItem(
                    icon: tabItems[1].icon,
                    title: tabItems[1].title,
                    isSelected: selectedTab == 1,
                    action: {
                        // Always pop to root and reset navigation tracker
                        NotificationCenter.default.post(name: NSNotification.Name("PopToRootKalorier"), object: nil)
                        NavigationDepthTracker.shared.resetToRoot()
                        if selectedTab != 1 {
                            switchToTab(1)
                        }
                    }
                )
                
                // Center: Tracka button (sticks up)
                centerTrackaButton
                
                // Tab 2: Belöningar
                FixedTabBarItem(
                    icon: tabItems[2].icon,
                    title: tabItems[2].title,
                    isSelected: selectedTab == 2,
                    action: {
                        // Always pop to root and reset navigation tracker
                        NotificationCenter.default.post(name: NSNotification.Name("PopToRootBeloningar"), object: nil)
                        NavigationDepthTracker.shared.resetToRoot()
                        if selectedTab != 2 {
                            switchToTab(2)
                        }
                    }
                )
                
                // Tab 3: Profil
                FixedTabBarItem(
                    icon: tabItems[3].icon,
                    title: tabItems[3].title,
                    isSelected: selectedTab == 3,
                    action: {
                        // Always pop to root and reset navigation tracker
                        NotificationCenter.default.post(name: NSNotification.Name("PopToRootProfil"), object: nil)
                        NavigationDepthTracker.shared.resetToRoot()
                        if selectedTab != 3 {
                            switchToTab(3)
                        }
                    }
                )
            }
            .padding(.top, 6)
            .padding(.bottom, 28)
            .padding(.horizontal, 4)
        }
        .background(Color(.systemBackground))
    }
    
    // MARK: - Center Tracka Button (circular, sticks up above tab bar)
    private var centerTrackaButton: some View {
        Button {
            triggerHeavyHaptic()
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                showAddMealSheet.toggle()
            }
        } label: {
            VStack(spacing: 4) {
                ZStack {
                    // Outer dark rim for 3D depth effect
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(white: 0.25),
                                    Color.black,
                                    Color(white: 0.15),
                                    Color.black
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 72, height: 72)
                        .shadow(color: Color.black.opacity(0.5), radius: 12, x: 0, y: 6)
                    
                    // Main button body with gradient
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(white: 0.45),      // Silver highlight at top
                                    Color(white: 0.3),       // Silver mid
                                    Color(white: 0.15),      // Dark mid
                                    Color.black,             // Black bottom
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: 64, height: 64)
                    
                    // Inner highlight ring at top for 3D pop
                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.4),
                                    Color.white.opacity(0.2),
                                    Color.clear,
                                    Color.clear,
                                    Color.black.opacity(0.3)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            lineWidth: 2
                        )
                        .frame(width: 62, height: 62)
                    
                    // Subtle inner shadow/bevel
                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color.black.opacity(0.4),
                                    Color.clear,
                                    Color.clear,
                                    Color(white: 0.4).opacity(0.3)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                        .frame(width: 58, height: 58)
                    
                    // Text inside button - bolder and larger
                    Text("Tracka")
                        .font(.system(size: 14, weight: .heavy))
                        .foregroundColor(.white)
                        .shadow(color: .black.opacity(0.6), radius: 2, x: 0, y: 1)
                }
                .offset(y: -16) // Stick up more above other tabs
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }
    
    private func triggerHeavyHaptic() {
        // Double haptic for more noticeable feedback on + button
        hapticGenerator.prepare()
        hapticGenerator.impactOccurred(intensity: 1.0)
        
        // Second lighter tap after a tiny delay for "click" feel
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            let lightHaptic = UIImpactFeedbackGenerator(style: .light)
            lightHaptic.impactOccurred(intensity: 0.6)
        }
    }
    
    private func triggerTabSwitchHaptic() {
        // Medium haptic for tab switching - noticeable but not too strong
        let tabHaptic = UIImpactFeedbackGenerator(style: .medium)
        tabHaptic.prepare()
        tabHaptic.impactOccurred(intensity: 0.7)
    }
    
    private func switchToTab(_ index: Int) {
        // Instant tab switch - each view handles its own loading state
        selectedTab = index
    }
    
    @ViewBuilder
    private var activeSessionBannerBackground: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(.regularMaterial)
            .shadow(color: Color.black.opacity(0.12), radius: 12, x: 0, y: 4)
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.white.opacity(0.3), lineWidth: 0.5)
            )
    }
    
    // MARK: - Active Session Banner
    private var activeSessionBanner: some View {
        VStack(spacing: 0) {
            // Main banner content
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Pågående pass")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.primary)
                }
                
                Spacer()
                
                // Resume button
                Button {
                    showResumeSession = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "play.fill")
                            .font(.system(size: 10))
                        Text("Återuppta")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .foregroundColor(.green)
                }
                
                Text("•")
                    .foregroundColor(.gray)
                    .padding(.horizontal, 8)
                
                // Discard button
                Button {
                    showDiscardConfirmation = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "xmark")
                            .font(.system(size: 10, weight: .semibold))
                        Text("Avsluta")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .foregroundColor(.red)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(activeSessionBannerBackground)
        }
        .padding(.horizontal, 16)
        .alert("Avsluta pass?", isPresented: $showDiscardConfirmation) {
            Button("Fortsätt träna", role: .cancel) { }
            Button("Avsluta", role: .destructive) {
                // End Live Activity first, then finalize session
                LiveActivityManager.shared.endLiveActivity()
                SessionManager.shared.finalizeSession()
            }
        } message: {
            Text("Ditt pågående pass kommer att förkastas och inte sparas.")
        }
    }
}

// MARK: - Fixed Tab Bar Item Component (Golf GameBook style)
private struct FixedTabBarItem: View {
    let icon: String
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    private let selectionHaptic = UIImpactFeedbackGenerator(style: .medium)
    
    // Selected color (black)
    private var selectedColor: Color {
        Color.black
    }
    
    var body: some View {
        Button {
            selectionHaptic.prepare()
            selectionHaptic.impactOccurred(intensity: 0.8)
            action()
        } label: {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 24, weight: isSelected ? .bold : .regular))
                    .foregroundColor(isSelected ? selectedColor : .gray)
                
                Text(title)
                    .font(.system(size: 11, weight: isSelected ? .bold : .medium))
                    .foregroundColor(isSelected ? selectedColor : .gray)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Tab Skeleton View
private struct TabSkeletonView: View {
    @State private var isAnimating = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header skeleton
            VStack(spacing: 12) {
                // Title bar skeleton
                HStack {
                    SkeletonBox(width: 120, height: 28)
                    Spacer()
                    SkeletonBox(width: 40, height: 40, cornerRadius: 20)
                }
                .padding(.horizontal, 20)
                .padding(.top, 60)
                
                // Banner/hero skeleton
                SkeletonBox(width: UIScreen.main.bounds.width - 32, height: 180, cornerRadius: 16)
                    .padding(.horizontal, 16)
            }
            
            // Content cards skeleton
            VStack(spacing: 16) {
                ForEach(0..<3, id: \.self) { index in
                    HStack(spacing: 12) {
                        SkeletonBox(width: 50, height: 50, cornerRadius: 25)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            SkeletonBox(width: 140, height: 16)
                            SkeletonBox(width: 200, height: 12)
                        }
                        
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                }
            }
            .padding(.top, 24)
            
            Spacer()
        }
        .background(Color(.systemBackground))
        .onAppear {
            withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                isAnimating = true
            }
        }
    }
}

// MARK: - Skeleton Box Component
private struct SkeletonBox: View {
    let width: CGFloat
    let height: CGFloat
    var cornerRadius: CGFloat = 8
    
    @State private var isAnimating = false
    
    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(
                LinearGradient(
                    colors: [
                        Color(.systemGray5),
                        Color(.systemGray4),
                        Color(.systemGray5)
                    ],
                    startPoint: isAnimating ? .leading : .trailing,
                    endPoint: isAnimating ? .trailing : .leading
                )
            )
            .frame(width: width, height: height)
            .onAppear {
                withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                    isAnimating = true
                }
            }
    }
}
