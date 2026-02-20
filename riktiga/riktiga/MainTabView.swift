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
    @ObservedObject private var barcodeScanLimitManager = BarcodeScanLimitManager.shared
    @ObservedObject private var revenueCatManager = RevenueCatManager.shared
    @Environment(\.scenePhase) private var scenePhase
    @State private var hasActiveSession = SessionManager.shared.hasActiveSession
    @State private var showStartSession = false
    @State private var startActivityType: ActivityType? = .running
    @State private var showResumeSession = false
    @State private var selectedTab = 0  // 0=Hem, 1=Kalorier, (2=Coach om aktiv), 2/3=Belöningar, 3/4=Profil
    @State private var previousTab = 0
    @State private var autoPresentedActiveSession = false
    @State private var showDiscardConfirmation = false
    @State private var showAddMealSheet = false
    @State private var showFoodScanner = false
    @State private var initialScannerMode: FoodScanMode = .ai
    @State private var showAIScanPaywall = false
    @State private var showManualEntry = false
    @State private var showProWelcome = false
    @State private var showSessionAutoEndedAlert = false
    @State private var hasActiveCoach = false
    @State private var coachWorkoutToStart: SavedGymWorkout? = nil
    @State private var pendingCoachInvitation: CoachInvitation? = nil
    @State private var showCoachInvitationPopup = false
    @State private var hasCheckedInvitations = false
    @State private var hideFloatingButton = false
    @State private var popToRootTrigger: [Int: Int] = [0: 0, 1: 0, 2: 0, 3: 0, 4: 0]
    
    private let hapticGenerator = UIImpactFeedbackGenerator(style: .heavy)
    
    // Tab items data - dynamiskt baserat på om användaren har coach
    private var tabItems: [(icon: String, title: String, selectedIcon: String)] {
        if hasActiveCoach {
            return [
                ("house", "Hem", "house.fill"),
                ("fork.knife", "Kalorier", "fork.knife"),
                ("person.badge.shield.checkmark", "Coach", "person.badge.shield.checkmark.fill"),
                ("gift", "Belöningar", "gift.fill"),
                ("person", "Profil", "person.fill")
            ]
        } else {
            return [
                ("house", "Hem", "house.fill"),
                ("fork.knife", "Kalorier", "fork.knife"),
                ("gift", "Belöningar", "gift.fill"),
                ("person", "Profil", "person.fill")
            ]
        }
    }
    
    // Tab index mapping
    private var rewardsTabIndex: Int { hasActiveCoach ? 3 : 2 }
    private var profileTabIndex: Int { hasActiveCoach ? 4 : 3 }
    private var coachTabIndex: Int { 2 } // Endast om hasActiveCoach
    
    var body: some View {
        customTabView
            .modifier(FullScreenCoversModifier(
                showStartSession: $showStartSession,
                showResumeSession: $showResumeSession,
                showFoodScanner: $showFoodScanner,
                showManualEntry: $showManualEntry,
                showProWelcome: $showProWelcome,
                startActivityType: startActivityType,
                coachWorkoutToStart: coachWorkoutToStart,
                initialScannerMode: initialScannerMode,
                authViewModel: authViewModel
            ))
            .modifier(NavigationReceiversModifier(
                selectedTab: $selectedTab,
                showStartSession: $showStartSession,
                showResumeSession: $showResumeSession,
                startActivityType: $startActivityType,
                coachWorkoutToStart: $coachWorkoutToStart,
                initialScannerMode: $initialScannerMode,
                showFoodScanner: $showFoodScanner,
                hideFloatingButton: $hideFloatingButton,
                hasActiveCoach: hasActiveCoach,
                rewardsTabIndex: rewardsTabIndex,
                profileTabIndex: profileTabIndex,
                coachTabIndex: coachTabIndex
            ))
            .modifier(StateObserversModifier(
                selectedTab: $selectedTab,
                hasActiveSession: $hasActiveSession,
                autoPresentedActiveSession: $autoPresentedActiveSession,
                showStartSession: $showStartSession,
                showResumeSession: $showResumeSession,
                showProWelcome: $showProWelcome,
                showSessionAutoEndedAlert: $showSessionAutoEndedAlert,
                previousTab: $previousTab,
                hasActiveCoach: hasActiveCoach,
                notificationNav: notificationNav,
                coachTabIndex: coachTabIndex
            ))
            .sheet(isPresented: $authViewModel.showUsernameRequiredPopup) {
                UsernameRequiredView().environmentObject(authViewModel)
            }
            .sheet(isPresented: $authViewModel.showPaywallAfterSignup) {
                PaywallAfterSignupView().environmentObject(authViewModel)
            }
            .sheet(isPresented: $showCoachInvitationPopup) {
                coachInvitationSheet
            }
            .onAppear {
                if hasActiveSession && !showStartSession && !showResumeSession {
                    autoPresentedActiveSession = true
                    showResumeSession = true
                }
                hapticGenerator.prepare()
            }
            .task {
                await checkForActiveCoach()
                await checkForPendingInvitations()
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("CoachStatusChanged"))) { _ in
                Task { await checkForActiveCoach() }
            }
            .onChange(of: scenePhase) {
                handleScenePhaseChange()
            }
            .onReceive(Timer.publish(every: 600, on: .main, in: .common).autoconnect()) { _ in
                if scenePhase == .active {
                    Task { try? await AuthSessionManager.shared.ensureValidSession() }
                }
            }
            .alert("Passet avslutades", isPresented: $showSessionAutoEndedAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("Ditt gympass avslutades automatiskt eftersom det varit aktivt i mer än 10 timmar.")
            }
    }
    
    // MARK: - Coach Invitation Sheet
    private var coachInvitationSheet: some View {
        NavigationStack {
            if let invitation = pendingCoachInvitation {
                CoachInvitationView(
                    invitation: invitation,
                    onAccept: {
                        showCoachInvitationPopup = false
                        pendingCoachInvitation = nil
                        Task { await checkForActiveCoach() }
                        NotificationCenter.default.post(name: NSNotification.Name("CoachStatusChanged"), object: nil)
                    },
                    onDecline: {
                        showCoachInvitationPopup = false
                        pendingCoachInvitation = nil
                    }
                )
                .navigationTitle("Coach-inbjudan")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button {
                            showCoachInvitationPopup = false
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                    }
                }
            } else {
                Color.clear
                    .onAppear { showCoachInvitationPopup = false }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
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
                        addMealOption(icon: "dumbbell.fill", title: "Starta gympass") {
                            showAddMealSheet = false
                            startActivityType = .walking
                            showStartSession = true
                        }
                        .scaleEffect(showAddMealSheet ? 1 : 0.8)
                        
                        addMealOption(icon: "figure.run", title: "Starta löppass") {
                            showAddMealSheet = false
                            startActivityType = .running
                            showStartSession = true
                        }
                        .scaleEffect(showAddMealSheet ? 1 : 0.8)
                    }
                    
                    HStack(spacing: 12) {
                        // Barcode Scan - check if limit reached for non-pro users
                        if !revenueCatManager.isProMember && barcodeScanLimitManager.isAtLimit() {
                            barcodeScanLimitedOption()
                                .scaleEffect(showAddMealSheet ? 1 : 0.8)
                        } else {
                            addMealOption(icon: "barcode.viewfinder", title: "Scanna streckkod") {
                                showAddMealSheet = false
                                initialScannerMode = .barcode
                                showFoodScanner = true
                            }
                            .scaleEffect(showAddMealSheet ? 1 : 0.8)
                        }
                        
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
            VStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 24))
                    .foregroundColor(.primary)
                
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
            }
            .padding(.horizontal, 8)
            .frame(width: 150, height: 120)
            .background(mealOptionBackground)
        }
    }
    
    @ViewBuilder
    private var mealOptionBackground: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(Color(.systemBackground))
            .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 5)
    }
    
    // AI Scan option with logo
    private func aiScanOption(action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 12) {
                // App logo with rounded corners
                Image("23")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 36, height: 36)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                
                Text("Tracka kalorier med AI")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
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
            .fill(Color(.systemBackground))
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
            VStack(spacing: 12) {
                ZStack {
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
                
                Text("Tracka kalorier med AI")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.gray.opacity(0.5))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
                
                Text("0 kvar")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.orange)
            }
            .frame(width: 150, height: 120)
            .background(disabledMealOptionBackground)
        }
    }
    
    // Barcode Scan limited option (shows paywall when tapped)
    private func barcodeScanLimitedOption() -> some View {
        Button {
            withAnimation { showAddMealSheet = false }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                SuperwallService.shared.showPaywall()
            }
        } label: {
            VStack(spacing: 12) {
                ZStack {
                    Image(systemName: "barcode.viewfinder")
                        .font(.system(size: 24))
                        .foregroundColor(.gray.opacity(0.4))
                    
                    Image(systemName: "lock.fill")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                        .padding(5)
                        .background(Color.gray)
                        .clipShape(Circle())
                        .offset(x: 20, y: -8)
                }
                
                Text("Scanna streckkod")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.gray.opacity(0.5))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
                
                Text("PRO")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.orange)
            }
            .frame(width: 150, height: 120)
            .background(disabledMealOptionBackground)
        }
    }
    
    // MARK: - Custom Tab View (all iOS versions)
    private var customTabView: some View {
        VStack(spacing: 0) {
            // Content views based on selected tab
            ZStack {
                SocialContainerView(popToRootTrigger: popToRootTrigger[0] ?? 0)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .opacity(selectedTab == 0 ? 1 : 0)
                    .allowsHitTesting(selectedTab == 0 && !showAddMealSheet)
                
                HomeContainerView(popToRootTrigger: popToRootTrigger[1] ?? 0)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .opacity(selectedTab == 1 ? 1 : 0)
                    .allowsHitTesting(selectedTab == 1 && !showAddMealSheet)
                
                if hasActiveCoach {
                    CoachTabView(popToRootTrigger: popToRootTrigger[2] ?? 0)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .opacity(selectedTab == 2 ? 1 : 0)
                        .allowsHitTesting(selectedTab == 2 && !showAddMealSheet)
                }
                
                RewardsContainerView(popToRootTrigger: popToRootTrigger[rewardsTabIndex] ?? 0)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .opacity(selectedTab == rewardsTabIndex ? 1 : 0)
                    .allowsHitTesting(selectedTab == rewardsTabIndex && !showAddMealSheet)
                
                ProfileContainerView(popToRootTrigger: popToRootTrigger[profileTabIndex] ?? 0)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .opacity(selectedTab == profileTabIndex ? 1 : 0)
                    .allowsHitTesting(selectedTab == profileTabIndex && !showAddMealSheet)
                
                // Add Meal Overlay
                addMealOverlay
                    .opacity(showAddMealSheet ? 1 : 0)
                    .allowsHitTesting(showAddMealSheet)
                
                // Floating + button
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        if !showAddMealSheet && navigationTracker.isAtRootView && !hideFloatingButton {
                            floatingAddButton
                                .transition(.scale.combined(with: .opacity))
                        }
                    }
                    .padding(.trailing, 16)
                    .padding(.bottom, 12)
                }
                .animation(.spring(response: 0.3, dampingFraction: 0.8), value: navigationTracker.isAtRootView)
                
                // Floating active session banner
                if sessionManager.hasActiveSession && !showStartSession && !showResumeSession && !showAddMealSheet {
                    VStack {
                        Spacer()
                        activeSessionBanner
                            .padding(.bottom, 8)
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            
            // Custom Tab Bar - always at bottom, never overlaps content
            customTabBar
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: sessionManager.hasActiveSession)
        .animation(.easeOut(duration: 0.15), value: showAddMealSheet)
    }
    
    // MARK: - Tab Bar Background
    @ViewBuilder
    private var tabBarBackground: some View {
        Color(.systemBackground)
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
                floatingButtonBackground
                
                Image(systemName: showAddMealSheet ? "xmark" : "plus")
                    .font(.system(size: 22, weight: .medium))
                    .foregroundColor(.white)
                    .rotationEffect(.degrees(showAddMealSheet ? 0 : 0))
            }
        }
    }
    
    @ViewBuilder
    private var floatingButtonBackground: some View {
        // Always black background with shadow
        Circle()
            .fill(Color.black)
            .frame(width: 56, height: 56)
            .shadow(color: Color.black.opacity(0.25), radius: 10, x: 0, y: 4)
    }
    
    // MARK: - Custom Tab Bar
    private var customTabBar: some View {
        VStack(spacing: 0) {
            // Top border line
            Rectangle()
                .fill(Color.gray.opacity(0.2))
                .frame(height: 0.5)
            
            // Tab bar content
            HStack(spacing: 0) {
                ForEach(0..<tabItems.count, id: \.self) { index in
                    CustomTabBarItem(
                        icon: tabItems[index].icon,
                        selectedIcon: tabItems[index].selectedIcon,
                        title: tabItems[index].title,
                        isSelected: selectedTab == index,
                        action: {
                            if selectedTab == index {
                                // Increment trigger to pop to root
                                popToRootTrigger[index, default: 0] += 1
                            } else {
                                switchToTab(index)
                            }
                        }
                    )
                }
            }
            .padding(.top, 8)
            .padding(.bottom, 2)
        }
        .background(
            Color(.systemBackground)
                .ignoresSafeArea(edges: .bottom)
        )
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
        // Instant tab switch - no delay
        selectedTab = index
    }
    
    private func checkForActiveCoach() async {
        guard let userId = authViewModel.currentUser?.id else { return }
        
        do {
            let coachRelation = try await CoachService.shared.fetchMyCoach(for: userId)
            await MainActor.run {
                hasActiveCoach = coachRelation != nil
            }
        } catch {
            print("❌ Failed to check for active coach: \(error)")
        }
    }
    
    private func checkForPendingInvitations() async {
        guard let userId = authViewModel.currentUser?.id else { return }
        // Don't show if already showing an invitation or already have a coach
        guard !showCoachInvitationPopup else { return }
        
        do {
            let invitations = try await CoachService.shared.fetchPendingInvitations(for: userId)
            if let firstInvitation = invitations.first {
                await MainActor.run {
                    pendingCoachInvitation = firstInvitation
                    // Only show popup after data is fully loaded
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        // Double-check invitation is still set before showing
                        if pendingCoachInvitation != nil {
                            showCoachInvitationPopup = true
                        }
                    }
                }
            }
        } catch {
            print("❌ Failed to check pending invitations: \(error)")
        }
    }
    
    private func handleScenePhaseChange() {
        if scenePhase == .active {
            SessionManager.shared.checkAndAutoEndExpiredSession()
            AuthSessionManager.shared.resetFailureCounter()
            Task { await checkForPendingInvitations() }
            Task {
                do {
                    try await AuthSessionManager.shared.ensureValidSession()
                    print("✅ Auth session verified on app activation")
                } catch {
                    // NEVER log out from here. Session refresh failures can be caused by
                    // network issues, temporary server problems, etc.
                    // If the session is truly revoked server-side, the auth state listener
                    // (onAuthStateChange → .signedOut) will handle it.
                    print("⚠️ Session check failed on activation: \(error) — NOT logging out")
                    
                    // Try to recover in the background for next time
                    try? await AuthSessionManager.shared.forceRefresh()
                }
            }
        }
    }
    
    @ViewBuilder
    private var activeSessionBannerBackground: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(Color(.systemBackground))
            .shadow(color: Color.black.opacity(0.12), radius: 12, x: 0, y: 4)
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.gray.opacity(0.2), lineWidth: 0.5)
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

// MARK: - Full Screen Covers Modifier
private struct FullScreenCoversModifier: ViewModifier {
    @Binding var showStartSession: Bool
    @Binding var showResumeSession: Bool
    @Binding var showFoodScanner: Bool
    @Binding var showManualEntry: Bool
    @Binding var showProWelcome: Bool
    let startActivityType: ActivityType?
    let coachWorkoutToStart: SavedGymWorkout?
    let initialScannerMode: FoodScanMode
    let authViewModel: AuthViewModel
    
    func body(content: Content) -> some View {
        content
            .fullScreenCover(isPresented: $showStartSession) {
                StartSessionView(initialActivity: startActivityType ?? .running, coachWorkout: coachWorkoutToStart)
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
    }
}

// MARK: - Navigation Receivers Modifier
private struct NavigationReceiversModifier: ViewModifier {
    @Binding var selectedTab: Int
    @Binding var showStartSession: Bool
    @Binding var showResumeSession: Bool
    @Binding var startActivityType: ActivityType?
    @Binding var coachWorkoutToStart: SavedGymWorkout?
    @Binding var initialScannerMode: FoodScanMode
    @Binding var showFoodScanner: Bool
    @Binding var hideFloatingButton: Bool
    let hasActiveCoach: Bool
    let rewardsTabIndex: Int
    let profileTabIndex: Int
    let coachTabIndex: Int
    
    func body(content: Content) -> some View {
        content
            .onChange(of: showStartSession) { _, isShowing in
                if !isShowing { coachWorkoutToStart = nil }
                if isShowing { showResumeSession = false }
            }
            .onChange(of: showResumeSession) { _, newValue in
                if newValue { showStartSession = false }
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("NavigateToSocial"))) { _ in
                selectedTab = 0
                showStartSession = false
                showResumeSession = false
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("SwitchActivity"))) { note in
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
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("StartCoachWorkout"))) { note in
                if let workout = note.object as? SavedGymWorkout {
                    coachWorkoutToStart = workout
                    startActivityType = .walking
                    showResumeSession = false
                    showStartSession = true
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("CloseStartSession"))) { _ in
                showStartSession = false
                showResumeSession = false
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("NavigateToRewards"))) { _ in
                selectedTab = rewardsTabIndex
                showStartSession = false
                showResumeSession = false
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("NavigateToKalorier"))) { _ in
                selectedTab = 1
                showStartSession = false
                showResumeSession = false
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("NavigateToProfile"))) { _ in
                selectedTab = profileTabIndex
                showStartSession = false
                showResumeSession = false
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("NavigateToStatistics"))) { _ in
                selectedTab = profileTabIndex
                showStartSession = false
                showResumeSession = false
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("NavigateToCoach"))) { _ in
                if hasActiveCoach {
                    selectedTab = coachTabIndex
                    showStartSession = false
                    showResumeSession = false
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("SessionFinalized"))) { _ in
                showStartSession = false
                showResumeSession = false
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("OpenAIFoodScanner"))) { _ in
                initialScannerMode = .ai
                showFoodScanner = true
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("HideFloatingButton"))) { _ in
                withAnimation { hideFloatingButton = true }
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ShowFloatingButton"))) { _ in
                withAnimation { hideFloatingButton = false }
            }
    }
}

// MARK: - State Observers Modifier
private struct StateObserversModifier: ViewModifier {
    @Binding var selectedTab: Int
    @Binding var hasActiveSession: Bool
    @Binding var autoPresentedActiveSession: Bool
    @Binding var showStartSession: Bool
    @Binding var showResumeSession: Bool
    @Binding var showProWelcome: Bool
    @Binding var showSessionAutoEndedAlert: Bool
    @Binding var previousTab: Int
    let hasActiveCoach: Bool
    let notificationNav: NotificationNavigationManager
    let coachTabIndex: Int
    
    func body(content: Content) -> some View {
        content
            .onReceive(NotificationCenter.default.publisher(for: .userBecamePro)) { _ in
                let key = "hasSeenProWelcome"
                guard !UserDefaults.standard.bool(forKey: key) else { return }
                UserDefaults.standard.set(true, forKey: key)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    showProWelcome = true
                }
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
            .onChange(of: notificationNav.shouldNavigateToNews) { _, shouldNavigate in
                if shouldNavigate {
                    selectedTab = 0
                    NotificationCenter.default.post(name: NSNotification.Name("NavigateToNewsTab"), object: nil)
                    notificationNav.resetNavigation()
                }
            }
            .onChange(of: notificationNav.shouldNavigateToPost) { _, postId in
                if let postId = postId {
                    selectedTab = 0
                    NotificationCenter.default.post(name: NSNotification.Name("NavigateToPost"), object: nil, userInfo: ["postId": postId])
                    notificationNav.resetNavigation()
                }
            }
            .onChange(of: notificationNav.shouldNavigateToCoachChat) { _, shouldNavigate in
                if shouldNavigate && hasActiveCoach {
                    selectedTab = coachTabIndex
                    notificationNav.shouldNavigateToCoachChat = false
                }
            }
            .onChange(of: selectedTab) { oldTab, newTab in
                if oldTab != newTab {
                    let tabHaptic = UIImpactFeedbackGenerator(style: .medium)
                    tabHaptic.prepare()
                    tabHaptic.impactOccurred(intensity: 0.7)
                }
                NavigationDepthTracker.shared.resetToRoot()
                previousTab = oldTab
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.didReceiveMemoryWarningNotification)) { _ in
                ImageCacheManager.shared.clearCache()
                TerritoryStore.shared.invalidateCache()
                SocialViewModel.invalidateCache()
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("SessionAutoEnded"))) { _ in
                showSessionAutoEndedAlert = true
            }
    }
}

// MARK: - Custom Tab Bar Item Component
private struct CustomTabBarItem: View {
    let icon: String
    let selectedIcon: String
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
            VStack(spacing: 5) {
                Image(systemName: isSelected ? selectedIcon : icon)
                    .font(.system(size: 24, weight: isSelected ? .medium : .regular))
                    .foregroundColor(isSelected ? .primary : .gray)
                    .frame(height: 28)
                
                Text(title)
                    .font(.system(size: 11, weight: isSelected ? .medium : .regular))
                    .foregroundColor(isSelected ? .primary : .gray)
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

