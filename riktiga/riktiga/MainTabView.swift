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
    @Environment(\.scenePhase) private var scenePhase
    @State private var hasActiveSession = SessionManager.shared.hasActiveSession
    @State private var showStartSession = false
    @State private var startActivityType: ActivityType? = .running
    @State private var showResumeSession = false
    @State private var selectedTab = 0  // 0=Hem(Zonkriget), 1=Socialt, 2=Starta pass (intercepted), 3=Belöningar, 4=Profil
    @State private var previousTab = 0
    @State private var autoPresentedActiveSession = false
    
    private let hapticGenerator = UIImpactFeedbackGenerator(style: .heavy)
    
    // Tab items data
    private let tabItems: [(icon: String, title: String)] = [
        ("house.fill", "Hem"),
        ("person.2.fill", "Socialt"),
        ("figure.run", "Starta pass"),
        ("gift.fill", "Belöningar"),
        ("person.fill", "Profil")
    ]
    
    var body: some View {
        ZStack(alignment: .bottom) {
            // Content views based on selected tab
            Group {
                switch selectedTab {
                case 0:
                    HomeContainerView()
                case 1:
                    SocialView()
                case 3:
                    RewardsView()
                case 4:
                    ProfileView()
                default:
                    Color.clear
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            // Custom Tab Bar
            customTabBar
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .fullScreenCover(isPresented: $showStartSession) {
            StartSessionView(initialActivity: startActivityType ?? .running)
                .id(startActivityType ?? .running)
                .ignoresSafeArea()
        }
        .fullScreenCover(isPresented: $showResumeSession) {
            StartSessionView()
                .ignoresSafeArea()
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
            selectedTab = 3  // Belöningar is now at index 3
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
            // Reset to root view when switching tabs
            navigationTracker.resetToRoot()
            
            // Smart memory cleanup based on which tabs are involved
            Task.detached(priority: .utility) {
                // Light cleanup when leaving map-heavy views
                if oldTab == 0 { // Leaving ZoneWar
                    await MainActor.run {
                        ImageCacheManager.shared.trimCache()
                    }
                    // Don't invalidate territory cache - it causes zones to disappear when returning
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
    
    // MARK: - Custom Tab Bar
    
    private var customTabBar: some View {
        HStack(spacing: 0) {
            ForEach(0..<tabItems.count, id: \.self) { index in
                TabBarItem(
                    icon: tabItems[index].icon,
                    title: tabItems[index].title,
                    isSelected: selectedTab == index,
                    action: {
                        if index == 2 {
                            // Starta pass - special handling
                            triggerHeavyHaptic()
                            Task {
                                await TrackingPermissionManager.shared.requestPermissionIfNeeded()
                                await MainActor.run {
                                    if hasActiveSession {
                                        showResumeSession = true
                                    } else {
                                        startActivityType = .running
                                        showStartSession = true
                                    }
                                }
                            }
                        } else if selectedTab == index {
                            // Same tab tapped - pop to root
                            let notificationName: String
                            switch index {
                            case 0: notificationName = "PopToRootHem"
                            case 1: notificationName = "PopToRootSocialt"
                            case 3: notificationName = "PopToRootBeloningar"
                            case 4: notificationName = "PopToRootProfil"
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
        .padding(.horizontal, 8)
        .padding(.top, 4)
        .padding(.bottom, 16)
        .background(
            Rectangle()
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.08), radius: 6, x: 0, y: -2)
                .ignoresSafeArea(edges: .bottom)
        )
    }
    
    // MARK: - Floating Start Button
    
    private var floatingStartButton: some View {
        Button {
            triggerHeavyHaptic()
            Task {
                await TrackingPermissionManager.shared.requestPermissionIfNeeded()
                await MainActor.run {
                    if hasActiveSession {
                        showResumeSession = true
                    } else {
                        startActivityType = .running
                        showStartSession = true
                    }
                }
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "play.fill")
                    .font(.system(size: 16, weight: .bold))
                Text("Starta pass")
                    .font(.system(size: 16, weight: .bold))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 24)
            .padding(.vertical, 14)
            .background(
                Capsule()
                    .fill(Color.black)
                    .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
            )
        }
        .padding(.bottom, 60) // Position above tab bar
    }
    
    private func triggerHeavyHaptic() {
        hapticGenerator.prepare()
        hapticGenerator.impactOccurred(intensity: 1.0)
    }
}

// MARK: - Tab Bar Item Component
private struct TabBarItem: View {
    let icon: String
    let title: String
    let isSelected: Bool
    let action: () -> Void
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 3) {
                // Icon with gradient when selected
                if isSelected {
                    Image(systemName: icon)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [
                                    colorScheme == .dark ? Color.white : Color.black,
                                    colorScheme == .dark ? Color.gray.opacity(0.8) : Color.gray.opacity(0.6)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(height: 28)
                } else {
                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .regular))
                        .foregroundColor(.gray)
                        .frame(height: 28)
                }
                
                Text(title)
                    .font(.system(size: 11, weight: isSelected ? .bold : .medium))
                    .foregroundColor(isSelected ? .primary : .gray)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }
}

