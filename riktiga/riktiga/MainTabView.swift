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
                
                // Starta Pass Button - Above Navigation
                VStack {
                    Spacer()
                    
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
                    .padding(.bottom, 100) // Position above navigation
                }
                
                // Custom Navigation Bar - Apple Liquid Glass
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
                        }
                        
                        // Socialt
                        Button(action: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                selectedTab = 1
                            }
                        }) {
                            VStack(spacing: 4) {
                                Image(systemName: "person.2.fill")
                                    .font(.title3)
                                    .scaleEffect(selectedTab == 1 ? 1.1 : 1.0)
                                Text("Socialt")
                                    .font(.caption)
                                    .fontWeight(selectedTab == 1 ? .bold : .regular)
                            }
                            .frame(maxWidth: .infinity)
                            .foregroundColor(selectedTab == 1 ? .blue : .secondary)
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
                        }
                    }
                    .frame(height: 80)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 28, style: .continuous)
                            .stroke(Color.white.opacity(0.25), lineWidth: 1)
                    )
                    .shadow(radius: 8)
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
