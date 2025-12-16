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
    
    func setAtRoot(_ atRoot: Bool) {
        DispatchQueue.main.async {
            self.isAtRootView = atRoot
        }
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
    @Environment(\.scenePhase) private var scenePhase
    @State private var hasActiveSession = SessionManager.shared.hasActiveSession
    @State private var showStartSession = false
    @State private var startActivityType: ActivityType? = .running
    @State private var showResumeSession = false
    @State private var selectedTab = 0  // 0=Hem(Zonkriget), 1=Socialt, 2=Belöningar, 3=Lektioner, 4=Profil
    @State private var previousTab = 0
    @State private var autoPresentedActiveSession = false
    
    private let hapticGenerator = UIImpactFeedbackGenerator(style: .heavy)
    
    var body: some View {
        ZStack(alignment: .bottom) {
            NavigationStack {
                TabView(selection: $selectedTab) {
                    ZoneWarView()
                        .tag(0)
                        .tabItem {
                            Image(systemName: "house.fill")
                            Text("Hem")
                        }
                    
                    SocialView()
                        .tag(1)
                        .tabItem {
                            Image(systemName: "person.2.fill")
                            Text("Socialt")
                        }
                    
                    RewardsView()
                        .tag(2)
                        .tabItem {
                            Image(systemName: "gift.fill")
                            Text("Belöningar")
                        }
                    
                    LessonsView()
                        .tag(3)
                        .tabItem {
                            Image(systemName: "figure.golf")
                            Text("Lektioner")
                        }
                    
                    ProfileView()
                        .tag(4)
                        .tabItem {
                            Image(systemName: "person.fill")
                            Text("Profil")
                        }
                }
                .accentColor(.black)
                .ignoresSafeArea(.keyboard, edges: .bottom)
            }
            .enableSwipeBack()
            
            // Floating Start Session Button (now also on Hem (0) och Lektioner (3))
            if (selectedTab == 0 || selectedTab == 1 || selectedTab == 2 || selectedTab == 3 || selectedTab == 4)
                && navigationTracker.isAtRootView {
                floatingStartButton
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
            selectedTab = 2
            showStartSession = false
            showResumeSession = false
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("NavigateToLessons"))) { _ in
            selectedTab = 3
            showStartSession = false
            showResumeSession = false
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
            navigationTracker.setAtRoot(true)
            
            // Smart memory cleanup based on which tabs are involved
            Task.detached(priority: .utility) {
                // Light cleanup when leaving map-heavy views
                if oldTab == 0 { // Leaving ZoneWar
                    await MainActor.run {
                        ImageCacheManager.shared.trimCache()
                    }
                    // Give map time to release resources
                    try? await Task.sleep(nanoseconds: 100_000_000)
                    await MainActor.run {
                        TerritoryStore.shared.invalidateCache()
                    }
                }
                
                if oldTab == 3 { // Leaving Lessons
                    await MainActor.run {
                        ImageCacheManager.shared.trimCache()
                        LessonsViewModel.invalidateCache()
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
            LessonsViewModel.invalidateCache()
            SocialViewModel.invalidateCache()
        }
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

