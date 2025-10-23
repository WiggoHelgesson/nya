import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var selectedTab = 0
    
    var body: some View {
        ZStack {
            TabView(selection: $selectedTab) {
                // Hem tab
                HomeView()
                    .tag(0)
                
                // Socialt tab
                VStack {
                    Text("Socialt")
                        .font(.title)
                    Spacer()
                }
                .tag(1)
                
                // Belöningar tab
                RewardsView()
                    .tag(3)
                
                // Profil tab
                ProfileView()
                    .tag(4)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            
            // Custom Tab Bar - Liquid Glass
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
                    
                    // Socialt
                    Button(action: { selectedTab = 1 }) {
                        VStack(spacing: 4) {
                            Image(systemName: "person.2.fill")
                                .font(.title3)
                            Text("Socialt")
                                .font(.caption)
                        }
                        .frame(maxWidth: .infinity)
                        .foregroundColor(selectedTab == 1 ? .black : .gray)
                    }
                    
                    // Starta Pass - Center Button
                    NavigationLink(destination: StartSessionView()) {
                        VStack(spacing: 4) {
                            Text("STARTA\nPASS")
                                .font(.system(size: 12, weight: .bold))
                                .lineLimit(2)
                                .multilineTextAlignment(.center)
                        }
                        .frame(width: 70, height: 70)
                        .background(Color(red: 0.1, green: 0.15, blue: 0.25))
                        .foregroundColor(.white)
                        .clipShape(Circle())
                        .shadow(radius: 5)
                    }
                    
                    // Belöningar
                    Button(action: { selectedTab = 3 }) {
                        VStack(spacing: 4) {
                            Image(systemName: "star.fill")
                                .font(.title3)
                            Text("Belöningar")
                                .font(.caption)
                        }
                        .frame(maxWidth: .infinity)
                        .foregroundColor(selectedTab == 3 ? .black : .gray)
                    }
                    
                    // Profil
                    Button(action: { selectedTab = 4 }) {
                        VStack(spacing: 4) {
                            Image(systemName: "person.fill")
                                .font(.title3)
                            Text("Profil")
                                .font(.caption)
                        }
                        .frame(maxWidth: .infinity)
                        .foregroundColor(selectedTab == 4 ? .black : .gray)
                    }
                }
                .frame(height: 80)
                .background(
                    ZStack {
                        // Liquid Glass Effect Background
                        Color.white.opacity(0.7)
                        
                        // Blur effect
                        .background(.ultraThinMaterial)
                    }
                )
                .backdrop()
                .cornerRadius(20)
                .padding(12)
            }
        }
    }
}

// Glass morphism backdrop modifier
struct GlassBackdrop: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(.white.opacity(0.1))
                    .background(.ultraThinMaterial)
            )
            .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 2)
    }
}

extension View {
    func backdrop() -> some View {
        modifier(GlassBackdrop())
    }
}

#Preview {
    MainTabView()
        .environmentObject(AuthViewModel())
}
