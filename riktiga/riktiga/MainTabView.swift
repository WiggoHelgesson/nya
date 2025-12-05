import SwiftUI
import Combine
import UIKit
import MapKit
import CoreLocation

struct MainTabView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @ObservedObject private var sessionManager = SessionManager.shared
    @State private var showStartSession = false
    @State private var showResumeSession = false
    @State private var selectedTab = 0  // 0=Hem, 1=Zon krig, 2=Lektioner, 3=Belöningar, 4=Profil
    @State private var previousTab = 0
    @State private var autoPresentedActiveSession = false
    private let hapticGenerator = UIImpactFeedbackGenerator(style: .heavy)
    
    var body: some View {
        ZStack(alignment: .bottom) {
            NavigationStack {
                TabView(selection: $selectedTab) {
                    SocialView()
                        .tag(0)
                        .tabItem {
                            Image(systemName: "house.fill")
                            Text("Hem")
                        }
                    
                    ZoneWarView()
                        .tag(1)
                        .tabItem {
                            Image(systemName: "map.fill")
                            Text("Zon krig")
                        }
                    
                    LessonsView()
                        .tag(2)
                        .tabItem {
                            Image(systemName: "figure.golf")
                            Text("Lektioner")
                        }
                    
                    RewardsView()
                        .tag(3)
                        .tabItem {
                            Image(systemName: "gift.fill")
                            Text("Belöningar")
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
            
            // Floating Start Session Button
            floatingStartButton
        }
        .fullScreenCover(isPresented: $showStartSession) {
            GymSessionView()
                .ignoresSafeArea()
        }
        .fullScreenCover(isPresented: $showResumeSession) {
            StartSessionView()
                .ignoresSafeArea()
        }
        .onAppear {
            if sessionManager.hasActiveSession && !showStartSession && !showResumeSession {
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
            selectedTab = 0
            showStartSession = false
            showResumeSession = false
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("CloseStartSession"))) { _ in
            showStartSession = false
            showResumeSession = false
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("NavigateToRewards"))) { _ in
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
        .onChange(of: sessionManager.hasActiveSession) { _, newValue in
            if newValue {
                if !autoPresentedActiveSession && !showStartSession && !showResumeSession {
                    autoPresentedActiveSession = true
                    showResumeSession = true
                }
            } else {
                autoPresentedActiveSession = false
            }
        }
    }
    
    // MARK: - Floating Start Button
    
    private var floatingStartButton: some View {
        Button {
            triggerHeavyHaptic()
            Task {
                await TrackingPermissionManager.shared.requestPermissionIfNeeded()
                await MainActor.run {
                    if sessionManager.hasActiveSession {
                        showResumeSession = true
                    } else {
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

