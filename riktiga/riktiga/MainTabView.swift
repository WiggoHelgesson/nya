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
    @State private var selectedTab = 0  // 0=Hem, 1=Socialt, 2=Belöningar, 3=Profil
    @State private var previousTab = 0
    @State private var autoPresentedActiveSession = false
    @State private var showDiscardConfirmation = false
    @State private var showAddMealSheet = false
    @State private var showFoodScanner = false
    @State private var initialScannerMode: FoodScanMode = .ai
    @State private var showAIScanPaywall = false
    @State private var showManualEntry = false
    
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
        ("person.2.fill", "Socialt"),
        ("gift.fill", "Belöningar"),
        ("person.fill", "Profil")
    ]
    
    var body: some View {
        Group {
            if #available(iOS 26.0, *) {
                // iOS 26+ : Native Liquid Glass TabView
                liquidGlassTabView
            } else {
                // iOS 25 and earlier: Custom Tab Bar
                legacyTabView
            }
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
        .sheet(isPresented: $showAIScanPaywall) {
            PresentPaywallView()
        }
        .fullScreenCover(isPresented: $showManualEntry) {
            ManualFoodEntryView()
                .environmentObject(authViewModel)
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
                    HomeContainerView()
                }
                
                Tab("Socialt", systemImage: "person.2.fill", value: 1) {
                    SocialView()
                }
                
                Tab("Belöningar", systemImage: "gift.fill", value: 2) {
                    RewardsView()
                }
                
                Tab("Profil", systemImage: "person.fill", value: 3) {
                    ProfileContainerView()
                }
            }
            .tint(.primary)
            .opacity(showAddMealSheet ? 0.3 : 1.0)
            .blur(radius: showAddMealSheet ? 10 : 0)
            
            // Add Meal Overlay
            if showAddMealSheet {
                addMealOverlay
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }
            
            // Floating + button container - hide when navigating to sub-pages
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    if !showAddMealSheet && navigationTracker.isAtRootView {
                        floatingAddButton
                            .transition(.scale.combined(with: .opacity))
                    }
                }
                .padding(.trailing, 16)
                .padding(.bottom, 90) // Above the tab bar
            }
            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: navigationTracker.isAtRootView)
            
            // Floating active session banner
            if sessionManager.hasActiveSession && !showStartSession && !showResumeSession && !showAddMealSheet {
                activeSessionBanner
                    .padding(.bottom, 100)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: sessionManager.hasActiveSession)
        .animation(.spring(response: 0.4, dampingFraction: 0.75), value: showAddMealSheet)
    }
    
    // MARK: - Add Meal Overlay
    private var addMealOverlay: some View {
        ZStack {
            // Semi-transparent background that closes the menu when tapped
            Color.black.opacity(0.15) // Slightly darker for better contrast
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        showAddMealSheet = false
                    }
                }
            
            VStack {
                Spacer()
                
                VStack(spacing: 12) {
                    HStack(spacing: 12) {
                        addMealOption(icon: "dumbbell.fill", title: "Starta pass") {
                            withAnimation { showAddMealSheet = false }
                            showStartSession = true
                        }
                        addMealOption(icon: "barcode.viewfinder", title: "Scanna streckkod") {
                            withAnimation { showAddMealSheet = false }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                initialScannerMode = .barcode
                                showFoodScanner = true
                            }
                        }
                    }
                    
                    HStack(spacing: 12) {
                        // Regga manuellt
                        addMealOption(icon: "pencil.line", title: "Regga manuellt") {
                            withAnimation { showAddMealSheet = false }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                showManualEntry = true
                            }
                        }
                        
                        // AI Scan - check if limit reached for non-pro users
                        if !revenueCatManager.isProMember && scanLimitManager.isAtLimit() {
                            // Grayed out AI scan button
                            aiScanLimitedOption()
                        } else {
                            aiScanOption {
                                withAnimation { showAddMealSheet = false }
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                    initialScannerMode = .ai
                                    showFoodScanner = true
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 40) // Bottom part of the screen
            }
        }
    }
    
    private func addMealOption(icon: String, title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 24))
                    .foregroundColor(.black)
                
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.black)
            }
            .frame(width: 150, height: 120)
            .background(Color.white)
            .cornerRadius(16)
            .shadow(color: Color.black.opacity(0.15), radius: 15, x: 0, y: 10)
        }
    }
    
    // AI Scan option with logo and stars
    private func aiScanOption(action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 8) {
                ZStack {
                    // Stars around the logo
                    Image(systemName: "sparkles")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.black)
                        .offset(x: -20, y: -12)
                    
                    Image(systemName: "sparkle")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.black)
                        .offset(x: 18, y: -14)
                    
                    Image(systemName: "sparkle")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(.black.opacity(0.6))
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
                    .foregroundColor(.black)
            }
            .frame(width: 150, height: 120)
            .background(Color.white)
            .cornerRadius(16)
            .shadow(color: Color.black.opacity(0.15), radius: 15, x: 0, y: 10)
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
        .background(Color.white.opacity(0.7))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.08), radius: 10, x: 0, y: 5)
    }
    
    // AI Scan limited option (shows paywall when tapped)
    private func aiScanLimitedOption() -> some View {
        Button {
            withAnimation { showAddMealSheet = false }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                showAIScanPaywall = true
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
            .background(Color.white.opacity(0.7))
            .cornerRadius(16)
            .shadow(color: Color.black.opacity(0.08), radius: 10, x: 0, y: 5)
        }
    }
    
    // MARK: - Legacy Tab View (iOS 25 and earlier)
    private var legacyTabView: some View {
        ZStack(alignment: .bottom) {
            // Content views based on selected tab
            Group {
                switch selectedTab {
                case 0:
                    HomeContainerView()
                case 1:
                    SocialView()
                case 2:
                    RewardsView()
                case 3:
                    ProfileContainerView()
                default:
                    Color.clear
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .opacity(showAddMealSheet ? 0.3 : 1.0)
            .blur(radius: showAddMealSheet ? 10 : 0)
            
            // Add Meal Overlay
            if showAddMealSheet {
                addMealOverlay
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }
            
            // Floating active session banner
            if sessionManager.hasActiveSession && !showStartSession && !showResumeSession && !showAddMealSheet {
                activeSessionBanner
                    .padding(.bottom, 100) // Above tab bar
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            
            // Custom Tab Bar with + button - hide + when navigating
            if !showAddMealSheet {
                legacyCustomTabBar
                    .animation(.spring(response: 0.3, dampingFraction: 0.8), value: navigationTracker.isAtRootView)
            }
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: sessionManager.hasActiveSession)
        .animation(.spring(response: 0.4, dampingFraction: 0.75), value: showAddMealSheet)
    }
    
    // MARK: - Floating Add Button
    private var floatingAddButton: some View {
        Button {
            triggerHeavyHaptic()
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                showAddMealSheet.toggle()
            }
        } label: {
            ZStack {
                Circle()
                    .fill(Color(red: 0.15, green: 0.15, blue: 0.17))
                    .frame(width: 56, height: 56)
                    .shadow(color: Color.black.opacity(0.25), radius: 10, x: 0, y: 4)
                
                Image(systemName: showAddMealSheet ? "xmark" : "plus")
                    .font(.system(size: 22, weight: .medium))
                    .foregroundColor(.white)
                    .rotationEffect(.degrees(showAddMealSheet ? 0 : 0))
            }
        }
    }
    
    // MARK: - Legacy Custom Tab Bar
    private var legacyCustomTabBar: some View {
        HStack(alignment: .center, spacing: 12) {
            // Tab items container with glass style background
            HStack(spacing: 0) {
                ForEach(0..<tabItems.count, id: \.self) { index in
                    LegacyTabBarItem(
                        icon: tabItems[index].icon,
                        title: tabItems[index].title,
                        isSelected: selectedTab == index,
                        action: {
                            if selectedTab == index {
                                // Same tab tapped - pop to root
                                let notificationName: String
                                switch index {
                                case 0: notificationName = "PopToRootHem"
                                case 1: notificationName = "PopToRootSocialt"
                                case 2: notificationName = "PopToRootBeloningar"
                                case 3: notificationName = "PopToRootProfil"
                                default: notificationName = ""
                                }
                                if !notificationName.isEmpty {
                                    NotificationCenter.default.post(name: NSNotification.Name(notificationName), object: nil)
                                }
                            } else {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    selectedTab = index
                                }
                            }
                        }
                    )
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
            .background(
                ZStack {
                    // Glass effect layers
                    RoundedRectangle(cornerRadius: 32, style: .continuous)
                        .fill(.ultraThinMaterial)
                    
                    RoundedRectangle(cornerRadius: 32, style: .continuous)
                        .fill(Color.white.opacity(0.7))
                    
                    RoundedRectangle(cornerRadius: 32, style: .continuous)
                        .stroke(Color.white.opacity(0.5), lineWidth: 1)
                }
                .shadow(color: Color.black.opacity(0.08), radius: 20, x: 0, y: 8)
            )
            
            // + button on the right - hide when navigating to sub-pages
            if navigationTracker.isAtRootView {
                floatingAddButton
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 28)
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
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(.systemBackground))
                    .shadow(color: Color.black.opacity(0.15), radius: 12, x: 0, y: 4)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
            )
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

// MARK: - Legacy Tab Bar Item Component
private struct LegacyTabBarItem: View {
    let icon: String
    let title: String
    let isSelected: Bool
    let action: () -> Void
    @Environment(\.colorScheme) private var colorScheme
    
    private let selectionHaptic = UIImpactFeedbackGenerator(style: .medium)
    
    var body: some View {
        Button {
            // Strong haptic feedback on tab selection
            selectionHaptic.prepare()
            selectionHaptic.impactOccurred(intensity: 0.8)
            action()
        } label: {
            VStack(spacing: 4) {
                ZStack {
                    if isSelected {
                        // Selected background pill
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color.gray.opacity(0.15))
                            .frame(width: 56, height: 32)
                    }
                    
                    Image(systemName: icon)
                        .font(.system(size: isSelected ? 20 : 18, weight: isSelected ? .bold : .regular))
                        .foregroundColor(isSelected ? .primary : .gray)
                }
                .frame(height: 32)
                
                Text(title)
                    .font(.system(size: 10, weight: isSelected ? .semibold : .medium))
                    .foregroundColor(isSelected ? .primary : .gray)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }
}

