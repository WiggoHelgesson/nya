import SwiftUI
import Combine

struct MainTabView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var selectedTab = 0
    @State private var showStartSession = false
    @State private var shimmerOffset: CGFloat = -200
    
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
                            .foregroundColor(selectedTab == 0 ? .black : .gray.opacity(0.6))
                        }
                        
                        // Aktiviteter
                        Button(action: { 
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                selectedTab = 1 
                            }
                        }) {
                            VStack(spacing: 4) {
                                Image(systemName: "figure.walk")
                                    .font(.title3)
                                    .scaleEffect(selectedTab == 1 ? 1.1 : 1.0)
                                Text("Aktiviteter")
                                    .font(.caption)
                                    .fontWeight(selectedTab == 1 ? .bold : .regular)
                            }
                            .frame(maxWidth: .infinity)
                            .foregroundColor(selectedTab == 1 ? .black : .gray.opacity(0.6))
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
                                Image(systemName: "shippingbox.fill")
                                    .font(.title3)
                                    .scaleEffect(selectedTab == 2 ? 1.1 : 1.0)
                                Text("Belöningar")
                                    .font(.caption)
                                    .fontWeight(selectedTab == 2 ? .bold : .regular)
                            }
                            .frame(maxWidth: .infinity)
                            .foregroundColor(selectedTab == 2 ? .black : .gray.opacity(0.6))
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
                            .foregroundColor(selectedTab == 3 ? .black : .gray.opacity(0.6))
                        }
                    }
                    .frame(height: 80)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(
                        // Real Liquid Glass Background
                        ZStack {
                            // Base blur layer with stronger blur
                            RoundedRectangle(cornerRadius: 28)
                                .fill(.ultraThinMaterial)
                                .blur(radius: 1)
                            
                            // Glass overlay with stronger gradient
                            RoundedRectangle(cornerRadius: 28)
                                .fill(
                                    LinearGradient(
                                        gradient: Gradient(colors: [
                                            Color.white.opacity(0.4),
                                            Color.white.opacity(0.2),
                                            Color.white.opacity(0.1),
                                            Color.white.opacity(0.05)
                                        ]),
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                            
                            // Animated liquid shimmer effect
                            RoundedRectangle(cornerRadius: 28)
                                .fill(
                                    LinearGradient(
                                        gradient: Gradient(stops: [
                                            .init(color: Color.clear, location: 0),
                                            .init(color: Color.clear, location: 0.3),
                                            .init(color: Color.white.opacity(0.3), location: 0.5),
                                            .init(color: Color.clear, location: 0.7),
                                            .init(color: Color.clear, location: 1)
                                        ]),
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .offset(x: shimmerOffset)
                                .clipped()
                            
                            // Secondary shimmer layer
                            RoundedRectangle(cornerRadius: 28)
                                .fill(
                                    LinearGradient(
                                        gradient: Gradient(stops: [
                                            .init(color: Color.clear, location: 0),
                                            .init(color: Color.white.opacity(0.1), location: 0.4),
                                            .init(color: Color.white.opacity(0.2), location: 0.5),
                                            .init(color: Color.white.opacity(0.1), location: 0.6),
                                            .init(color: Color.clear, location: 1)
                                        ]),
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .rotationEffect(.degrees(30))
                                .offset(x: shimmerOffset * 0.7)
                                .clipped()
                            
                            // Enhanced border with gradient
                            RoundedRectangle(cornerRadius: 28)
                                .stroke(
                                    LinearGradient(
                                        gradient: Gradient(colors: [
                                            Color.white.opacity(0.6),
                                            Color.white.opacity(0.3),
                                            Color.white.opacity(0.1),
                                            Color.white.opacity(0.3),
                                            Color.white.opacity(0.6)
                                        ]),
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 2
                                )
                        }
                        .shadow(color: Color.black.opacity(0.2), radius: 20, x: 0, y: 10)
                        .shadow(color: Color.white.opacity(0.8), radius: 10, x: 0, y: -5)
                        .onAppear {
                            withAnimation(.linear(duration: 3).repeatForever(autoreverses: false)) {
                                shimmerOffset = 200
                            }
                        }
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
