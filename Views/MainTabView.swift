import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var selectedTab = 0
    
    var body: some View {
        ZStack {
            TabView(selection: $selectedTab) {
                // Hem tab
                HomeView()
                    .tabItem {
                        Image(systemName: "house.fill")
                        Text("Hem")
                    }
                    .tag(0)
                
                // Aktiviteter tab
                ActivitiesView()
                    .tabItem {
                        Image(systemName: "figure.walk")
                        Text("Aktiviteter")
                    }
                    .tag(1)
                
                // Belöningar tab
                RewardsView()
                    .tabItem {
                        Image(systemName: "star.fill")
                        Text("Belöningar")
                    }
                    .tag(2)
                
                // Profil tab
                ProfileView()
                    .tabItem {
                        Image(systemName: "person.fill")
                        Text("Profil")
                    }
                    .tag(3)
            }
            
            // Starta pass button - floating action button
            VStack {
                HStack {
                    Spacer()
                    VStack(spacing: 8) {
                        NavigationLink(destination: StartSessionView()) {
                            VStack(spacing: 4) {
                                Image(systemName: "play.fill")
                                    .font(.headline)
                                Text("Starta pass")
                                    .font(.caption)
                            }
                            .frame(width: 60, height: 60)
                            .background(
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        Color(red: 0.1, green: 0.6, blue: 0.8),
                                        Color(red: 0.2, green: 0.4, blue: 0.9)
                                    ]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .foregroundColor(.white)
                            .clipShape(Circle())
                            .shadow(radius: 5)
                        }
                        Spacer()
                    }
                    .padding(20)
                }
            }
        }
    }
}

#Preview {
    MainTabView()
        .environmentObject(AuthViewModel())
}
