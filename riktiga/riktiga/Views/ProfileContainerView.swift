import SwiftUI

enum ProfileTab: String, CaseIterable {
    case statistik = "Statistik"
    case minaAnnonser = "Mina annonser"
    case aktiviteter = "Aktiviteter"

    var displayName: String {
        switch self {
        case .statistik: return L.t(sv: "Statistik", nb: "Statistikk")
        case .minaAnnonser: return L.t(sv: "Mina annonser", nb: "Mine annonser")
        case .aktiviteter: return L.t(sv: "Aktiviteter", nb: "Aktiviteter")
        }
    }
}

struct ProfileContainerView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    let popToRootTrigger: Int
    @Namespace private var heroNS
    @State private var selectedTab: ProfileTab = .aktiviteter
    @State private var showSettings = false
    @State private var navigationPath = NavigationPath()
    @State private var showPublicProfile = false

    var body: some View {
        NavigationStack(path: $navigationPath) {
            VStack(spacing: 0) {
                ProfileHeaderWithTabs(selectedTab: $selectedTab, onSettingsTapped: {
                    showSettings = true
                }, onPublicProfileTapped: {
                    showPublicProfile = true
                })
                    .environmentObject(authViewModel)
                    .zIndex(2)
                
                TabView(selection: $selectedTab) {
                    StatisticsView()
                        .environmentObject(authViewModel)
                        .tag(ProfileTab.statistik)

                    // MARKET HIDDEN: Mina annonser-sidan döljs helt i TabView
                    // (utöver att fliken är gömd i headern), så att horisontell
                    // page-swipe inte når den. Vyn finns kvar i kodbasen och
                    // återaktiveras genom att ta bort `#if false`.
                    #if false
                    MyListingsView()
                        .environmentObject(authViewModel)
                        .environment(\.marketplaceHeroNamespace, heroNS)
                        .tag(ProfileTab.minaAnnonser)
                    #endif

                    ProfileActivitiesView(onPublicProfileTapped: {
                        showPublicProfile = true
                    })
                        .environmentObject(authViewModel)
                        .tag(ProfileTab.aktiviteter)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut(duration: 0.25), value: selectedTab)
            }
            .navigationBarHidden(true)
            .marketplaceDestinations()
            .navigationDestination(isPresented: $showPublicProfile) {
                if let userId = authViewModel.currentUser?.id {
                    UserProfileView(userId: userId, forcePublicView: true)
                        .environmentObject(authViewModel)
                }
            }
        }
        .id(popToRootTrigger)
        .onChange(of: popToRootTrigger) { _, _ in
            navigationPath = NavigationPath()
            showSettings = false
            showPublicProfile = false
            NotificationCenter.default.post(name: NSNotification.Name("PopToRootProfil"), object: nil)
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("NavigateToStatistics"))) { _ in
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedTab = .statistik
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("OpenMyPurchases"))) { _ in
            NavigationDepthTracker.shared.hideTabBar = false
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedTab = .aktiviteter
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("NavigateToMyListings"))) { _ in
            // MARKET HIDDEN: fliken Mina annonser döljs i headern tills marketplace lanseras.
            // Push-notiser som tidigare landade här blir no-op men kraschar inte.
            /* hidden for now */
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
    }
}

// MARK: - Profile Skeleton View
private struct ProfileSkeletonView: View {
    var body: some View {
        VStack(spacing: 0) {
            // Header skeleton
            VStack(spacing: 0) {
                HStack {
                    Circle()
                        .fill(Color(.systemGray5))
                        .frame(width: 36, height: 36)
                    
                    Spacer()
                    
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color(.systemGray5))
                        .frame(width: 120, height: 36)
                    
                    Spacer()
                    
                    Circle()
                        .fill(Color(.systemGray5))
                        .frame(width: 36, height: 36)
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 16)
                
                // Tab skeleton
                HStack(spacing: 0) {
                    ForEach(0..<3, id: \.self) { _ in
                        VStack(spacing: 10) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color(.systemGray5))
                                .frame(width: 70, height: 16)
                            
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color(.systemGray5))
                                .frame(height: 3)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            }
            .background(Color(.systemBackground))
            
            // Content skeleton
            ScrollView {
                VStack(spacing: 16) {
                    // Stats cards
                    HStack(spacing: 12) {
                        ForEach(0..<2, id: \.self) { _ in
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color(.systemGray5))
                                .frame(height: 90)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    
                    // More cards
                    ForEach(0..<4, id: \.self) { _ in
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color(.systemGray5))
                            .frame(height: 80)
                            .padding(.horizontal, 16)
                    }
                }
            }
        }
        .shimmer()
    }
}

// MARK: - Profile Header with Tabs
struct ProfileHeaderWithTabs: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @Binding var selectedTab: ProfileTab
    
    var onSettingsTapped: (() -> Void)? = nil
    var onPublicProfileTapped: (() -> Void)? = nil
    
    private var isPremium: Bool {
        authViewModel.currentUser?.isProMember ?? false
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // MARK: - Top Row (Profile, Title, Actions)
            ZStack {
                // Center: Points badge
                PointsBadge(points: authViewModel.currentUser?.currentXP ?? 0)
                
                // Left and Right sides
                HStack {
                    // Profile picture
                    Button {
                        onPublicProfileTapped?()
                    } label: {
                        ProfileImage(url: authViewModel.currentUser?.avatarUrl, size: 36, isPro: authViewModel.currentUser?.isProMember ?? false)
                            .overlay(
                                Circle()
                                    .stroke(Color.black.opacity(0.1), lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                    
                    Spacer()
                    
                    // Settings button
                    Button {
                        onSettingsTapped?()
                    } label: {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 22, weight: .regular))
                            .foregroundColor(.primary)
                            .frame(width: 36, height: 36)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 16)
            
            // MARK: - Tab Selector (Strava-style)
            // MARKET HIDDEN: Fliken `.minaAnnonser` är gömd tills marketplace lanseras.
            // Enumcasen finns kvar i `ProfileTab` så att TabView nedan kan fortsätta
            // tagga vyn — den blir bara aldrig vald.
            HStack(spacing: 0) {
                ForEach([ProfileTab.statistik, .aktiviteter], id: \.self) { tab in
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedTab = tab
                        }
                    } label: {
                        VStack(spacing: 10) {
                            Text(tab.displayName)
                                .font(.system(size: 16, weight: selectedTab == tab ? .bold : .medium))
                                .foregroundColor(selectedTab == tab ? .primary : .gray)
                            
                            // Black underline indicator
                            Rectangle()
                                .fill(selectedTab == tab ? Color.primary : Color.clear)
                                .frame(height: 3)
                        }
                        .frame(maxWidth: .infinity)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.bottom, 0)
        }
        .background(Color(.systemBackground))
        .shadow(color: Color.black.opacity(0.15), radius: 8, x: 0, y: 4)
    }
}

// MARK: - Pro Banner View
private struct ProBannerView: View {
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            ZStack {
                // Background gradient (Black to Silver)
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color(red: 0.1, green: 0.1, blue: 0.1),
                        Color(red: 0.3, green: 0.3, blue: 0.3),
                        Color(red: 0.5, green: 0.5, blue: 0.5),
                        Color(red: 0.3, green: 0.3, blue: 0.3),
                        Color(red: 0.1, green: 0.1, blue: 0.1)
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                
                // Content
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(L.t(sv: "Skaffa Up&Down Pro och lås upp alla förmåner", nb: "Skaff Up&Down Pro og lås opp alle fordeler"))
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                        
                        // CTA Button (White)
                        HStack(spacing: 4) {
                            Text(L.t(sv: "Prenumerera nu", nb: "Abonner nå"))
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.black)
                            
                            Image(systemName: "arrow.right")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.black)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 6)
                        .background(Color.white)
                        .cornerRadius(20)
                    }
                    
                    Spacer()
                    
                    // App Logo
                    Image("23")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 50, height: 50)
                        .cornerRadius(10)
                        .shadow(color: .black.opacity(0.3), radius: 5, x: 0, y: 2)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .frame(height: 70)
            .overlay(
                RoundedRectangle(cornerRadius: 0)
                    .stroke(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color.white.opacity(0.2),
                                Color.white.opacity(0.1)
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.5
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    ProfileContainerView(popToRootTrigger: 0)
        .environmentObject(AuthViewModel())
}

