import SwiftUI
import Combine

struct MainTabView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @ObservedObject private var sessionManager = SessionManager.shared
    @State private var showStartSession = false
    @State private var showResumeSession = false
    @State private var selectedTab = 0  // Track selected tab (0=Hem, 1=Socialt, 2=Belöningar, 3=Profil)
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Standard TabView with automatic Liquid Glass
                TabView(selection: $selectedTab) {
                    HomeView()
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
                    
                    ProfileView()
                        .tag(3)
                        .tabItem {
                            Image(systemName: "person.fill")
                            Text("Profil")
                        }
                }
                
                // Starta Pass Button - Floating above TabView
                VStack {
                    Spacer()
                    
                    // Only show button if there's an active session
                    let _ = print("🔍 MainTabView - hasActiveSession: \(sessionManager.hasActiveSession)")
                    if sessionManager.hasActiveSession {
                        let _ = print("▶️ Showing ÅTERVÄND TILL PASS button")
                        Button(action: {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                                showResumeSession = true
                            }
                        }) {
                            HStack {
                                Image(systemName: "play.circle.fill")
                                    .font(.system(size: 18))
                                Text("ÅTERVÄND TILL PASS")
                                    .font(.headline)
                                    .fontWeight(.bold)
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                LinearGradient(
                                    gradient: Gradient(colors: [Color.black, Color.gray.opacity(0.8)]),
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .cornerRadius(12)
                            .shadow(color: Color.black.opacity(0.3), radius: 8, x: 0, y: 4)
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 90)
                    } else {
                        let _ = print("▶️ Showing STARTA PASS button")
                        Button(action: {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                                showStartSession = true
                            }
                        }) {
                            Text("STARTA PASS")
                                .font(.headline)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(
                                    LinearGradient(
                                        gradient: Gradient(colors: [Color.black, Color.gray.opacity(0.8)]),
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                                .cornerRadius(12)
                                .shadow(color: Color.black.opacity(0.3), radius: 8, x: 0, y: 4)
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 90)
                    }
                }
                
                // Sheet presentation handled by .sheet modifier
            }
        }
        .sheet(isPresented: $showStartSession) {
            StartSessionView()
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(20)
        }
        .sheet(isPresented: $showResumeSession) {
            StartSessionView()
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(20)
        }
        .onChange(of: showStartSession) { oldValue, newValue in
            // Reset showResumeSession when start session is shown
            if newValue {
                showResumeSession = false
            }
        }
        .onChange(of: showResumeSession) { oldValue, newValue in
            // Reset showStartSession when resume session is shown
            if newValue {
                showStartSession = false
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("NavigateToSocial"))) { _ in
            print("📥 NavigateToSocial notification received")
            // Navigate to Social tab after saving workout
            selectedTab = 1
            // Wait a bit for onChange in StartSessionView to clear session first
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                // Close any open session sheets
                showStartSession = false
                showResumeSession = false
                print("✅ Closed session sheets")
            }
        }
        .sheet(isPresented: $authViewModel.showUsernameRequiredPopup) {
            UsernameRequiredView()
                .environmentObject(authViewModel)
        }
        .sheet(isPresented: $authViewModel.showPaywallAfterSignup) {
            PaywallAfterSignupView()
                .environmentObject(authViewModel)
                .onDisappear {
                    // Allow dismissal
                }
        }
    }
}

#Preview {
    MainTabView()
        .environmentObject(AuthViewModel())
}
