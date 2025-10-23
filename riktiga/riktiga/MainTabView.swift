import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var selectedTab = 0
    
    var body: some View {
        ZStack {
            // Tab Content
            Group {
                if selectedTab == 0 {
                    HomeView()
                } else if selectedTab == 1 {
                    VStack {
                        Text("Aktiviteter")
                            .font(.title)
                        Spacer()
                    }
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
                        .foregroundColor(selectedTab == 0 ? .black : .gray)
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
                        .foregroundColor(selectedTab == 1 ? .black : .gray)
                    }
                    
                    // Starta Pass - Center Button
                    NavigationLink(destination: StartSessionView()) {
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
                        .background(Color(red: 0.15, green: 0.2, blue: 0.35))
                        .cornerRadius(8)
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
                        .foregroundColor(selectedTab == 2 ? .black : .gray)
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
                        .foregroundColor(selectedTab == 3 ? .black : .gray)
                    }
                }
                .frame(height: 70)
                .background(
                    ZStack {
                        Color.white.opacity(0.7)
                        .background(.ultraThinMaterial)
                    }
                )
                .cornerRadius(20)
                .padding(12)
            }
        }
    }
}

#Preview {
    MainTabView()
        .environmentObject(AuthViewModel())
}
