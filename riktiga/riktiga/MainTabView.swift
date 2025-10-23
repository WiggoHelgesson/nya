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
                        VStack(spacing: 4) {
                            Image(systemName: "house.fill")
                            Text("Hem")
                        }
                    }
                    .tag(0)
                
                // Socialt tab
                VStack {
                    Text("Socialt")
                        .font(.title)
                    Spacer()
                }
                .tabItem {
                    VStack(spacing: 4) {
                        Image(systemName: "person.2.fill")
                        Text("Socialt")
                    }
                }
                .tag(1)
                
                // Starta Pass - Center button placeholder
                VStack {
                    Text("Starta Pass")
                }
                .tabItem {
                    VStack(spacing: 4) {
                        Image(systemName: "star.fill")
                        Text("Pass")
                    }
                }
                .tag(2)
                
                // Belöningar tab
                RewardsView()
                    .tabItem {
                        VStack(spacing: 4) {
                            Image(systemName: "star.fill")
                            Text("Belöningar")
                        }
                    }
                    .tag(3)
                
                // Profil tab
                ProfileView()
                    .tabItem {
                        VStack(spacing: 4) {
                            Image(systemName: "person.fill")
                            Text("Profil")
                        }
                    }
                    .tag(4)
            }
            .tint(.black)
            .onAppear {
                let appearance = UITabBarAppearance()
                
                // Liquid Glass Effect
                appearance.backgroundEffect = UIBlurEffect(style: .light)
                appearance.backgroundColor = UIColor.white.withAlphaComponent(0.7)
                
                // Tab bar styling
                appearance.stackedLayoutAppearance.normal.iconColor = UIColor.gray
                appearance.stackedLayoutAppearance.normal.titleTextAttributes = [NSAttributedString.Key.foregroundColor: UIColor.gray]
                
                appearance.stackedLayoutAppearance.selected.iconColor = UIColor.black
                appearance.stackedLayoutAppearance.selected.titleTextAttributes = [NSAttributedString.Key.foregroundColor: UIColor.black]
                
                UITabBar.appearance().standardAppearance = appearance
                UITabBar.appearance().scrollEdgeAppearance = appearance
            }
        }
    }
}

#Preview {
    MainTabView()
        .environmentObject(AuthViewModel())
}
