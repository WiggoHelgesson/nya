import SwiftUI
import Combine

struct MainTabView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @StateObject private var sessionManager = SessionManager.shared
    @State private var showStartSession = false
    @State private var showResumeSession = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Standard TabView with automatic Liquid Glass
                TabView {
                    HomeView()
                        .tabItem {
                            Image(systemName: "house.fill")
                            Text("Hem")
                        }
                    
                    SocialView()
                        .tabItem {
                            Image(systemName: "person.2.fill")
                            Text("Socialt")
                        }
                    
                    RewardsView()
                        .tabItem {
                            Image(systemName: "gift.fill")
                            Text("Belöningar")
                        }
                    
                    ProfileView()
                        .tabItem {
                            Image(systemName: "person.fill")
                            Text("Profil")
                        }
                }
                
                // Starta Pass Button - Floating above TabView
                VStack {
                    Spacer()
                    
                    Button(action: {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                            if sessionManager.hasActiveSession {
                                showResumeSession = true
                            } else {
                                showStartSession = true
                            }
                        }
                    }) {
                        HStack {
                            if sessionManager.hasActiveSession {
                                Image(systemName: "play.circle.fill")
                                    .font(.system(size: 18))
                            }
                            Text(sessionManager.hasActiveSession ? "ÅTERUPPTA SESSION" : "STARTA PASS")
                                .font(.headline)
                                .fontWeight(.bold)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            LinearGradient(
                                gradient: Gradient(colors: sessionManager.hasActiveSession ? [Color.green, Color.green.opacity(0.8)] : [Color.black, Color.gray.opacity(0.8)]),
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .cornerRadius(12)
                        .shadow(color: Color.black.opacity(0.3), radius: 8, x: 0, y: 4)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 90) // Position just above TabView without touching
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
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("NavigateToActivities"))) { _ in
            // TabView will handle navigation automatically
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
