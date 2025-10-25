import SwiftUI
import Combine

struct MainTabView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var selectedTab = 0
    @State private var showStartSession = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Tab Content
                Group {
                    if selectedTab == 0 {
                        HomeView()
                    } else if selectedTab == 1 {
                        SocialView() // This will show leaderboards/social content
                    } else if selectedTab == 2 {
                        RewardsView()
                    } else if selectedTab == 3 {
                        ProfileView()
                    }
                }
                
                // Custom Navigation Bar - Liquid Glass
                VStack {
                    Spacer()
                    
                    HStack(spacing: 0) {
                        // Hem
                        Button(action: { 
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                selectedTab = 0 
                            }
                        }) {
                            VStack(spacing: 4) {
                                Image(systemName: "house.fill")
                                    .font(.title3)
                                    .scaleEffect(selectedTab == 0 ? 1.1 : 1.0)
                                Text("Hem")
                                    .font(.caption)
                                    .fontWeight(selectedTab == 0 ? .bold : .regular)
                            }
                            .frame(maxWidth: .infinity)
                            .foregroundColor(selectedTab == 0 ? .blue : .secondary)
                            .background(
                                selectedTab == 0 ? 
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(.thinMaterial)
                                : nil
                            )
                        }
                        
                        // Topplistor (Leaderboards)
                        Button(action: { 
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                selectedTab = 1 
                            }
                        }) {
                            VStack(spacing: 4) {
                                Image(systemName: "trophy.fill")
                                    .font(.title3)
                                    .scaleEffect(selectedTab == 1 ? 1.1 : 1.0)
                                Text("Topplistor")
                                    .font(.caption)
                                    .fontWeight(selectedTab == 1 ? .bold : .regular)
                            }
                            .frame(maxWidth: .infinity)
                            .foregroundColor(selectedTab == 1 ? .blue : .secondary)
                            .background(
                                selectedTab == 1 ? 
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(.thinMaterial)
                                : nil
                            )
                        }
                        
                        // Starta Pass - Round Center Button
                        Button(action: { 
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                                showStartSession = true 
                            }
                        }) {
                            VStack(spacing: 2) {
                                Text("STARTA")
                                    .font(.system(size: 10, weight: .black))
                                Text("PASS")
                                    .font(.system(size: 10, weight: .black))
                            }
                            .foregroundColor(.white)
                            .frame(width: 60, height: 60)
                            .background(
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            gradient: Gradient(colors: [
                                                Color(red: 0.2, green: 0.25, blue: 0.4),
                                                Color(red: 0.15, green: 0.2, blue: 0.35)
                                            ]),
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .shadow(color: Color.black.opacity(0.3), radius: 8, x: 0, y: 4)
                                    .shadow(color: Color.white.opacity(0.2), radius: 4, x: 0, y: -2)
                            )
                        }
                        
                        // Belöningar
                        Button(action: { 
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                selectedTab = 2 
                            }
                        }) {
                            VStack(spacing: 4) {
                                Image(systemName: "gift.fill")
                                    .font(.title3)
                                    .scaleEffect(selectedTab == 2 ? 1.1 : 1.0)
                                Text("Belöningar")
                                    .font(.caption)
                                    .fontWeight(selectedTab == 2 ? .bold : .regular)
                            }
                            .frame(maxWidth: .infinity)
                            .foregroundColor(selectedTab == 2 ? .blue : .secondary)
                            .background(
                                selectedTab == 2 ? 
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(.thinMaterial)
                                : nil
                            )
                        }
                        
                        // Profil
                        Button(action: { 
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                selectedTab = 3 
                            }
                        }) {
                            VStack(spacing: 4) {
                                Image(systemName: "person.fill")
                                    .font(.title3)
                                    .scaleEffect(selectedTab == 3 ? 1.1 : 1.0)
                                Text("Profil")
                                    .font(.caption)
                                    .fontWeight(selectedTab == 3 ? .bold : .regular)
                            }
                            .frame(maxWidth: .infinity)
                            .foregroundColor(selectedTab == 3 ? .blue : .secondary)
                            .background(
                                selectedTab == 3 ? 
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(.thinMaterial)
                                : nil
                            )
                        }
                    }
                    .frame(height: 80)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 28)
                            .fill(.ultraThinMaterial)
                            .overlay(
                                RoundedRectangle(cornerRadius: 28)
                                    .stroke(Color.white.opacity(0.2), lineWidth: 0.5)
                            )
                            .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 5)
                    )
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
                }
                
                NavigationLink(isActive: $showStartSession) {
                    StartSessionView()
                } label: {
                    EmptyView()
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("NavigateToActivities"))) { _ in
            selectedTab = 1 // Switch to Activities tab
        }
    }
}

#Preview {
    MainTabView()
        .environmentObject(AuthViewModel())
}
