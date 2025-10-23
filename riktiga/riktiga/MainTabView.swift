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
                        ActivitiesView()
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
                        Button(action: { selectedTab = 0 }) {
                            VStack(spacing: 4) {
                                Image(systemName: "house.fill")
                                    .font(.title3)
                                Text("Hem")
                                    .font(.caption)
                            }
                            .frame(maxWidth: .infinity)
                            .foregroundColor(selectedTab == 0 ? .black : .gray.opacity(0.6))
                        }
                        
                        // Aktiviteter
                        Button(action: { selectedTab = 1 }) {
                            VStack(spacing: 4) {
                                Image(systemName: "figure.walk")
                                    .font(.title3)
                                Text("Aktiviteter")
                                    .font(.caption)
                            }
                            .frame(maxWidth: .infinity)
                            .foregroundColor(selectedTab == 1 ? .black : .gray.opacity(0.6))
                        }
                        
                        // Starta Pass - Center Button
                        Button(action: { showStartSession = true }) {
                            VStack(spacing: 4) {
                                Text("STARTA\nPASS")
                                    .font(.system(size: 11, weight: .bold))
                                    .lineLimit(2)
                                    .multilineTextAlignment(.center)
                            }
                            .frame(maxWidth: .infinity)
                            .font(.caption)
                            .foregroundColor(.white)
                            .padding(12)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
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
                                    .shadow(color: Color.black.opacity(0.3), radius: 4, x: 0, y: 2)
                            )
                        }
                        
                        // Belöningar
                        Button(action: { selectedTab = 2 }) {
                            VStack(spacing: 4) {
                                Image(systemName: "star.fill")
                                    .font(.title3)
                                Text("Belöningar")
                                    .font(.caption)
                            }
                            .frame(maxWidth: .infinity)
                            .foregroundColor(selectedTab == 2 ? .black : .gray.opacity(0.6))
                        }
                        
                        // Profil
                        Button(action: { selectedTab = 3 }) {
                            VStack(spacing: 4) {
                                Image(systemName: "person.fill")
                                    .font(.title3)
                                Text("Profil")
                                    .font(.caption)
                            }
                            .frame(maxWidth: .infinity)
                            .foregroundColor(selectedTab == 3 ? .black : .gray.opacity(0.6))
                        }
                    }
                    .frame(height: 70)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(
                        // Liquid Glass Background with strong blur
                        ZStack {
                            // Blur layer
                            RoundedRectangle(cornerRadius: 24)
                                .fill(.ultraThinMaterial)
                            
                            // Glass overlay
                            RoundedRectangle(cornerRadius: 24)
                                .fill(
                                    LinearGradient(
                                        gradient: Gradient(colors: [
                                            Color.white.opacity(0.25),
                                            Color.white.opacity(0.1)
                                        ]),
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                            
                            // Border for glass effect
                            RoundedRectangle(cornerRadius: 24)
                                .stroke(
                                    LinearGradient(
                                        gradient: Gradient(colors: [
                                            Color.white.opacity(0.4),
                                            Color.white.opacity(0.1)
                                        ]),
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 1.5
                                )
                        }
                        .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 4)
                        .shadow(color: Color.white.opacity(0.5), radius: 6, x: 0, y: -2)
                    )
                    .padding(.horizontal, 12)
                    .padding(.bottom, 12)
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
