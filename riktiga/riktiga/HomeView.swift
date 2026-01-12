import SwiftUI
import Combine
import UIKit
import Supabase

// MARK: - Brand Logo Item (used by other views)
struct BrandLogoItem: Identifiable {
    let id = UUID()
    let name: String
    let imageName: String
    
    static let all: [BrandLogoItem] = [
        BrandLogoItem(name: "J.LINDEBERG", imageName: "37"),
        BrandLogoItem(name: "PLIKTGOLF", imageName: "15"),
        BrandLogoItem(name: "PEGMATE", imageName: "5"),
        BrandLogoItem(name: "LONEGOLF", imageName: "14"),
        BrandLogoItem(name: "WINWIZE", imageName: "17"),
        BrandLogoItem(name: "SCANDIGOLF", imageName: "18"),
        BrandLogoItem(name: "HAPPYALBA", imageName: "16"),
        BrandLogoItem(name: "RETROGOLF", imageName: "20"),
        BrandLogoItem(name: "PUMPLABS", imageName: "21"),
        BrandLogoItem(name: "ZEN ENERGY", imageName: "22"),
        BrandLogoItem(name: "PEAK", imageName: "33"),
        BrandLogoItem(name: "CAPSTONE", imageName: "34"),
        BrandLogoItem(name: "FUSE ENERGY", imageName: "46")
    ]
}

// MARK: - Popular Store Item
struct PopularStoreItem: Identifiable {
    let id = UUID()
    let name: String
    let imageName: String
    let reward: RewardCard?
    
    static let all: [PopularStoreItem] = [
        PopularStoreItem(name: "Pumplab", imageName: "21", reward: RewardCatalog.all.first { $0.brandName == "PUMPLABS" }),
        PopularStoreItem(name: "Lonegolf", imageName: "14", reward: RewardCatalog.all.first { $0.brandName == "LONEGOLF" }),
        PopularStoreItem(name: "Zen Energy", imageName: "22", reward: RewardCatalog.all.first { $0.brandName == "ZEN ENERGY" }),
        PopularStoreItem(name: "Fuse Energy", imageName: "46", reward: RewardCatalog.all.first { $0.brandName == "FUSE ENERGY" }),
        PopularStoreItem(name: "Pliktgolf", imageName: "15", reward: RewardCatalog.all.first { $0.brandName == "PLIKTGOLF" }),
        PopularStoreItem(name: "Clyro", imageName: "39", reward: RewardCatalog.all.first { $0.brandName == "CLYRO" }),
        PopularStoreItem(name: "Happyalba", imageName: "16", reward: RewardCatalog.all.first { $0.brandName == "HAPPYALBA" }),
        PopularStoreItem(name: "Winwize", imageName: "17", reward: RewardCatalog.all.first { $0.brandName == "WINWIZE" }),
        PopularStoreItem(name: "Capstone", imageName: "34", reward: RewardCatalog.all.first { $0.brandName == "CAPSTONE" })
    ]
}

struct HomeView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @Environment(\.colorScheme) var colorScheme
    @State private var selectedReward: RewardCard? = nil
    @State private var pendingRewardCelebration: RewardCelebration?
    @State private var selectedStep: Int = 1
    @State private var showSearchView = false
    
    // Animation states
    @State private var showSearch = false
    @State private var showWelcome = false
    @State private var showStores = false
    @State private var showHowItWorks = false
    @State private var showButtons = false
    
    // Welcome/Onboarding task states
    @State private var hasFirstActivity = false
    @State private var followingCount = 0
    @State private var hasProfilePicture = false
    @State private var hasConnectedDevice = false
    @State private var showFindFriends = false
    @State private var showEditProfile = false
    @State private var showConnectDevice = false
    @State private var welcomeTasksDismissed = false
    
    // Key for storing per-user welcome dismissed state
    private var welcomeDismissedKey: String {
        guard let userId = authViewModel.currentUser?.id else { return "welcomeTasksDismissed_unknown" }
        return "welcomeTasksDismissed_\(userId)"
    }
    
    private var allWelcomeTasksCompleted: Bool {
        hasFirstActivity && followingCount >= 3 && hasProfilePicture && hasConnectedDevice
    }
    
    private var completedTasksCount: Int {
        var count = 0
        if hasFirstActivity { count += 1 }
        if followingCount >= 3 { count += 1 }
        if hasProfilePicture { count += 1 }
        if hasConnectedDevice { count += 1 }
        return count
    }
    
    private let popularStores = PopularStoreItem.all
    
    // Adaptive gradient colors for background
    private var gradientColors: [Color] {
        if colorScheme == .dark {
            return [
                Color.black,
                Color(red: 0.05, green: 0.05, blue: 0.05),
                Color(red: 0.08, green: 0.08, blue: 0.08)
            ]
        } else {
            return [
        Color(red: 1.0, green: 1.0, blue: 1.0),
        Color(red: 0.98, green: 0.98, blue: 0.99),
        Color(red: 0.96, green: 0.96, blue: 0.97)
    ]
        }
    }
    
    // Adaptive colors
    private var cardBackground: Color {
        colorScheme == .dark ? Color(red: 0.12, green: 0.12, blue: 0.12) : Color.white
    }
    
    private var primaryTextColor: Color {
        colorScheme == .dark ? Color.white : Color.black
    }
    
    private var secondaryTextColor: Color {
        colorScheme == .dark ? Color.gray : Color.gray
    }
    
    // Step data
    private let stepData: [(title: String, description: String)] = [
        ("Tracka dina pass", "Genom att tracka dina gympass, löppass eller golfrundor samlar du på dig poäng som samlas i appen."),
        ("Dela med vänner", "Efter varje pass får du skapa ett inlägg som sedan delas med alla dina vänner."),
        ("Använd din rabattkod!", "Genom att träna har du nu blivit belönad med en rabattkod som du kan använda när som helst!")
    ]
    
    var body: some View {
            ZStack {
            // Dark gradient background
            LinearGradient(
                colors: gradientColors,
                startPoint: .top,
                endPoint: .bottom
            )
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // MARK: - Welcome Section (Onboarding Tasks)
                        if !welcomeTasksDismissed && !allWelcomeTasksCompleted {
                            welcomeSection
                                .padding(.top, 8)
                                .opacity(showWelcome ? 1 : 0)
                                .offset(y: showWelcome ? 0 : 15)
                        }
                        
                        // MARK: - Search Bar
                        searchBar
                            .padding(.horizontal, 20)
                            .opacity(showSearch ? 1 : 0)
                            .offset(y: showSearch ? 0 : 10)
                        
                    // MARK: - Popular Stores Section
                    popularStoresSection
                            .padding(.horizontal, 20)
                            .opacity(showStores ? 1 : 0)
                            .offset(y: showStores ? 0 : 15)
                        
                    // MARK: - How It Works Section
                    howItWorksSection
                                    .padding(.horizontal, 20)
                            .opacity(showHowItWorks ? 1 : 0)
                            .offset(y: showHowItWorks ? 0 : 15)
                    
                    // MARK: - Action Buttons
                    actionButtons
                        .padding(.horizontal, 20)
                        .opacity(showButtons ? 1 : 0)
                        .offset(y: showButtons ? 0 : 15)

                    Spacer(minLength: 100)
                    }
                }
            }
        .onAppear {
            animateHomeContent()
        }
        .task {
            await loadWelcomeTasks()
            }
        .sheet(item: $selectedReward) { reward in
            RewardDetailView(reward: reward)
        }
        .sheet(isPresented: $showSearchView) {
            SearchRewardsView(allRewards: RewardCatalog.all)
        }
        .sheet(isPresented: $showFindFriends) {
            NavigationStack {
                FindFriendsView()
            }
        }
        .sheet(isPresented: $showEditProfile) {
            NavigationStack {
                EditProfileView()
            }
        }
        .sheet(isPresented: $showConnectDevice) {
            ConnectDeviceView()
                .environmentObject(authViewModel)
                .onDisappear {
                    // Refresh device connection status when sheet closes
                    checkDeviceConnection()
                }
        }
        .sheet(item: $pendingRewardCelebration, onDismiss: {
            presentNextRewardIfAvailable()
        }) { reward in
            XpCelebrationView(
                points: reward.points,
                title: "Belöning upplåst! 🎯",
                subtitle: reward.reason,
                buttonTitle: "Fortsätt"
            ) {
                pendingRewardCelebration = nil
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    presentNextRewardIfAvailable()
                }
            }
        }
        .onAppear {
            presentNextRewardIfAvailable()
        }
        .onReceive(NotificationCenter.default.publisher(for: .rewardCelebrationQueued)) { _ in
            presentNextRewardIfAvailable()
        }
    }
    
    // MARK: - Search Bar
    private var searchBar: some View {
        Button {
            showSearchView = true
        } label: {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(secondaryTextColor)
                    .font(.system(size: 16))
                
                Text("Sök efter butik")
                    .font(.system(size: 16))
                    .foregroundColor(secondaryTextColor)
                
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(cardBackground)
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.3 : 0.06), radius: 4, x: 0, y: 2)
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Welcome Section (Onboarding Tasks)
    private var welcomeSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Decorative curved element at top
            HStack {
                // Black curved accent
                ZStack(alignment: .topLeading) {
                    Circle()
                        .fill(Color.black)
                        .frame(width: 120, height: 120)
                        .offset(x: -60, y: -60)
                }
                .frame(width: 60, height: 60)
                .clipped()
                
                Spacer()
            }
            
            // Header text
            VStack(alignment: .leading, spacing: 6) {
                Text("Välkommen till gemenskapen!")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.black)
                
                Text("Så här kommer du igång med Up&Down:")
                    .font(.system(size: 15))
                    .foregroundColor(.gray)
            }
            .padding(.horizontal, 20)
            .padding(.top, 4)
            
            // Segmented progress bar
            HStack(spacing: 6) {
                ForEach(0..<4, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 3)
                        .fill(index < completedTasksCount ? Color.black : Color(.systemGray4))
                        .frame(height: 5)
                        .animation(.spring(response: 0.4), value: completedTasksCount)
                }
                
                Text("\(completedTasksCount)/4")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.gray)
                    .frame(width: 30)
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 20)
            
            // Task cards - each in its own gray box
            VStack(spacing: 12) {
                // Task 1: First Activity
                WelcomeTaskCard(
                    icon: "figure.run",
                    title: "Ladda upp din första aktivitet",
                    subtitle: "Du kan spela in det direkt i appen.",
                    isCompleted: hasFirstActivity,
                    action: {
                        // Start a new session (same as "Starta pass" tab)
                        NotificationCenter.default.post(
                            name: NSNotification.Name("SwitchActivity"),
                            object: nil,
                            userInfo: ["activity": "running"]
                        )
                    }
                )
                
                // Task 2: Follow three people
                WelcomeTaskCard(
                    icon: "person.2.fill",
                    title: "Följ tre personer (\(min(followingCount, 3))/3)",
                    subtitle: "Hitta vänner och favoriter att följa.",
                    isCompleted: followingCount >= 3,
                    action: {
                        showFindFriends = true
                    }
                )
                
                // Task 3: Add profile picture
                WelcomeTaskCard(
                    icon: "person.crop.circle",
                    title: "Lägg till en profilbild",
                    subtitle: "Det hjälper andra att känna igen dig.",
                    isCompleted: hasProfilePicture,
                    action: {
                        showEditProfile = true
                    }
                )
                
                // Task 4: Connect a device
                WelcomeTaskCard(
                    icon: "applewatch",
                    title: "Anslut en enhet",
                    subtitle: "Synka med Garmin, Apple Watch och fler.",
                    isCompleted: hasConnectedDevice,
                    action: {
                        showConnectDevice = true
                    }
                )
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 20)
        }
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 0))
    }
    
    // MARK: - Popular Stores Section
    private var popularStoresSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Populära butiker")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(primaryTextColor)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(popularStores) { store in
                        Button {
                            if let reward = store.reward {
                                selectedReward = reward
                            }
                        } label: {
                            VStack(spacing: 8) {
                                // Store logo in circle
                                ZStack {
                                    Circle()
                                        .fill(cardBackground)
                                        .frame(width: 70, height: 70)
                                        .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.3 : 0.1), radius: 4, x: 0, y: 2)
                                    
                                    Image(store.imageName)
                                    .resizable()
                                        .scaledToFit()
                                        .frame(width: 50, height: 50)
                                    .clipShape(Circle())
                                }
                                
                                Text(store.name)
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(primaryTextColor.opacity(0.8))
                                    .lineLimit(1)
                            }
                            .frame(width: 80)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
    
    // MARK: - How It Works Section
    private var howItWorksSection: some View {
        VStack(spacing: 28) {
            Text("Så här funkar det")
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(primaryTextColor)
            
            // Step indicators - interactive
            HStack(spacing: 0) {
                ForEach(1...3, id: \.self) { step in
                    HStack(spacing: 0) {
                        // Step circle - tappable
                        Button {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                                selectedStep = step
                            }
                        } label: {
                            ZStack {
                                Circle()
                                    .fill(selectedStep == step ? primaryTextColor : Color.gray.opacity(0.15))
                                    .frame(width: 48, height: 48)
                                    .shadow(color: selectedStep == step ? primaryTextColor.opacity(0.2) : Color.clear, radius: 8, x: 0, y: 0)
                                
                                Text("\(step)")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(selectedStep == step ? (colorScheme == .dark ? .black : .white) : .gray)
                            }
                            .scaleEffect(selectedStep == step ? 1.1 : 1.0)
                        }
                        .buttonStyle(.plain)
                        
                        // Connecting line (except for last step)
                        if step < 3 {
                            Rectangle()
                        .fill(
                            LinearGradient(
                                        colors: [
                                            step < selectedStep ? primaryTextColor.opacity(0.4) : Color.gray.opacity(0.2),
                                            step < selectedStep ? primaryTextColor.opacity(0.4) : Color.gray.opacity(0.2)
                                        ],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(height: 2)
                                .frame(maxWidth: .infinity)
                        }
                    }
                }
            }
            .padding(.horizontal, 30)
            
            // Step content with animation
            VStack(spacing: 16) {
                Text(stepData[selectedStep - 1].title)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(primaryTextColor)
                    .multilineTextAlignment(.center)
                    .id("title-\(selectedStep)")
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)
                    ))
                
                Text(stepData[selectedStep - 1].description)
                    .font(.system(size: 15))
                    .foregroundColor(secondaryTextColor)
                    .multilineTextAlignment(.center)
                    .lineLimit(4)
                    .padding(.horizontal, 20)
                    .id("desc-\(selectedStep)")
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)
                    ))
            }
            .frame(height: 120)
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: selectedStep)
        }
        .padding(.vertical, 32)
        .padding(.horizontal, 16)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(cardBackground)
                .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.3 : 0.06), radius: 12, x: 0, y: 4)
        )
    }
    
    
    // MARK: - Action Buttons
    private var actionButtons: some View {
        VStack(spacing: 12) {
            // Progressive Overload Button
            NavigationLink(destination: ProgressiveOverloadView()) {
                HStack {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.system(size: 18, weight: .semibold))
                    
                    Text("Progressive overload")
                        .font(.system(size: 16, weight: .semibold))
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(secondaryTextColor)
                    }
                .foregroundColor(primaryTextColor)
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            .background(
                    RoundedRectangle(cornerRadius: 14)
                    .fill(cardBackground)
                        .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.3 : 0.06), radius: 6, x: 0, y: 2)
                )
            }
            .buttonStyle(.plain)
            
            // See Profile Button
            if let userId = authViewModel.currentUser?.id {
                NavigationLink(destination: UserProfileView(userId: userId)) {
                    HStack {
                        Image(systemName: "person.circle")
                            .font(.system(size: 18, weight: .semibold))
                        
                        Text("Se din profil")
                            .font(.system(size: 16, weight: .semibold))
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(secondaryTextColor)
                    }
                    .foregroundColor(primaryTextColor)
            .padding(.horizontal, 20)
                    .padding(.vertical, 16)
            .background(
                        RoundedRectangle(cornerRadius: 14)
                    .fill(cardBackground)
                            .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.3 : 0.06), radius: 6, x: 0, y: 2)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }
    
    // MARK: - Animation
    private func animateHomeContent() {
        withAnimation(.easeOut(duration: 0.4)) {
            showSearch = true
        }
        withAnimation(.easeOut(duration: 0.4).delay(0.08)) {
            showWelcome = true
        }
        withAnimation(.easeOut(duration: 0.4).delay(0.16)) {
            showStores = true
        }
        withAnimation(.easeOut(duration: 0.4).delay(0.24)) {
            showHowItWorks = true
        }
        withAnimation(.easeOut(duration: 0.4).delay(0.32)) {
            showButtons = true
        }
    }
    
    // MARK: - Helper Functions
    private func presentNextRewardIfAvailable() {
        guard pendingRewardCelebration == nil else { return }
        if let reward = RewardCelebrationManager.shared.consumeNextReward() {
            pendingRewardCelebration = reward
        }
    }
    
    // MARK: - Load Welcome Tasks
    private func loadWelcomeTasks() async {
        guard let userId = authViewModel.currentUser?.id else { 
            print("⚠️ Welcome tasks: No user ID found")
            return 
        }
        
        // Load per-user dismissed state
        await MainActor.run {
            welcomeTasksDismissed = UserDefaults.standard.bool(forKey: welcomeDismissedKey)
        }
        
        print("📊 Loading welcome tasks for user: \(userId) (dismissed: \(welcomeTasksDismissed))")
        
        do {
            // Check if user has any activities/posts
            let postsResponse: [WelcomePostRecord] = try await SupabaseConfig.supabase
                .from("workout_posts")
                .select("id")
                .eq("user_id", value: userId)
                .limit(1)
                .execute()
                .value
            
            await MainActor.run {
                hasFirstActivity = !postsResponse.isEmpty
                print("✅ Has first activity: \(hasFirstActivity) (found \(postsResponse.count) posts)")
            }
            
            // Check following count - use correct table name "user_follows"
            let followingResponse: [Follow] = try await SupabaseConfig.supabase
                .from("user_follows")
                .select("id, follower_id, following_id, created_at")
                .eq("follower_id", value: userId)
                .execute()
                .value
            
            await MainActor.run {
                followingCount = followingResponse.count
                print("✅ Following count: \(followingCount)")
            }
            
            // Check if user has profile picture - use profiles table
            let profileResponse: [UserAvatarRecord] = try await SupabaseConfig.supabase
                .from("profiles")
                .select("avatar_url")
                .eq("id", value: userId)
                .limit(1)
                .execute()
                .value
            
            await MainActor.run {
                if let profile = profileResponse.first {
                    hasProfilePicture = profile.avatarUrl != nil && !profile.avatarUrl!.isEmpty
                    print("✅ Has profile picture: \(hasProfilePicture) (url: \(profile.avatarUrl ?? "nil"))")
                } else {
                    hasProfilePicture = false
                    print("⚠️ No profile record found for avatar check")
                }
            }
            
            // Check if user has connected a device (via Terra)
            let deviceResponse: [TerraConnectionRecord] = try await SupabaseConfig.supabase
                .from("terra_connections")
                .select("id")
                .eq("user_id", value: userId)
                .eq("is_active", value: true)
                .limit(1)
                .execute()
                .value
            
            await MainActor.run {
                hasConnectedDevice = !deviceResponse.isEmpty
                print("✅ Has connected device: \(hasConnectedDevice)")
            }
            
            // Auto-dismiss if all tasks completed
            await MainActor.run {
                print("📊 Completed tasks: \(completedTasksCount)/4 - Activity: \(hasFirstActivity), Following: \(followingCount >= 3), Picture: \(hasProfilePicture), Device: \(hasConnectedDevice)")
                if allWelcomeTasksCompleted {
                    withAnimation(.easeOut(duration: 0.3)) {
                        welcomeTasksDismissed = true
                        UserDefaults.standard.set(true, forKey: welcomeDismissedKey)
                    }
                }
            }
        } catch {
            print("❌ Error loading welcome tasks: \(error)")
        }
    }
    
    private func checkDeviceConnection() {
        guard let userId = authViewModel.currentUser?.id else { return }
        
        Task {
            do {
                let deviceResponse: [TerraConnectionRecord] = try await SupabaseConfig.supabase
                    .from("terra_connections")
                    .select("id")
                    .eq("user_id", value: userId)
                    .eq("is_active", value: true)
                    .limit(1)
                    .execute()
                    .value
                
                await MainActor.run {
                    hasConnectedDevice = !deviceResponse.isEmpty
                }
            } catch {
                print("❌ Error checking device connection: \(error)")
            }
        }
    }
}

// MARK: - Welcome Task Helper Records
private struct WelcomePostRecord: Codable {
    let id: String
}

private struct UserAvatarRecord: Codable {
    let avatarUrl: String?
    
    enum CodingKeys: String, CodingKey {
        case avatarUrl = "avatar_url"
    }
}

private struct TerraConnectionRecord: Codable {
    let id: String
}

// MARK: - Welcome Task Row
struct WelcomeTaskCard: View {
    let icon: String
    let title: String
    let subtitle: String
    let isCompleted: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                // Checkbox circle on the left
                ZStack {
                    Circle()
                        .stroke(isCompleted ? Color.black : Color(.systemGray3), lineWidth: 1.5)
                        .frame(width: 22, height: 22)
                    
                    if isCompleted {
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.black)
                    }
                }
                
                // Icon in rounded square
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.systemGray5))
                        .frame(width: 48, height: 48)
                    
                    Image(systemName: icon)
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(.black)
                }
                
                // Text content
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.black)
                    
                    Text(subtitle)
                        .font(.system(size: 13))
                        .foregroundColor(.gray)
                        .lineLimit(2)
                }
                
                Spacer()
                
                // Chevron
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Color(.systemGray3))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 14)
            .background(Color(.systemGray6))
            .cornerRadius(16)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Follow Record for Query
// MARK: - Featured User Model
struct FeaturedUser: Identifiable {
    let id: String
    let username: String
    let avatarUrl: String?
}

// MARK: - Featured User Card
struct FeaturedUserCard: View {
    let user: FeaturedUser
    let isFollowing: Bool
    let onFollowToggle: () -> Void
    @State private var isProcessing = false
    
    var body: some View {
            VStack(spacing: 12) {
            NavigationLink(destination: UserProfileView(userId: user.id)) {
                ProfileAvatarView(path: user.avatarUrl ?? "", size: 60)
            }
            
            Text(user.username)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.primary)
                .lineLimit(1)
            
            Button(action: {
                guard !isProcessing else { return }
                isProcessing = true
                onFollowToggle()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    isProcessing = false
                }
            }) {
                Text(isFollowing ? "Följer" : "Följ")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(isFollowing ? .gray : .white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
                    .background(isFollowing ? Color(.systemGray5) : Color.black)
                    .cornerRadius(8)
            }
            .disabled(isProcessing)
        }
        .frame(width: 100)
        .padding(12)
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.08), radius: 4, x: 0, y: 2)
    }
}

// MARK: - Recommended Friend Card (used by multiple views)
struct RecommendedFriendCard: View {
    let user: UserSearchResult
    let isFollowing: Bool
    let onFollowToggle: () -> Void
    @State private var isProcessing = false
    
    var body: some View {
            VStack(spacing: 12) {
            NavigationLink(destination: UserProfileView(userId: user.id)) {
                ProfileImage(url: user.avatarUrl, size: 60)
            }
            
            Text(user.name)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.primary)
                .lineLimit(1)
            
            Button(action: {
                guard !isProcessing else { return }
                isProcessing = true
                onFollowToggle()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    isProcessing = false
                }
            }) {
                Text(isFollowing ? "Följer" : "Följ")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(isFollowing ? .gray : .white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
                    .background(isFollowing ? Color(.systemGray5) : Color.black)
                    .cornerRadius(8)
            }
            .disabled(isProcessing)
        }
        .frame(width: 100)
        .padding(12)
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.08), radius: 4, x: 0, y: 2)
    }
}

// MARK: - Weekly Stat Row (used by multiple views)
struct WeeklyStatRow: View {
    let day: String
    let distance: Double
    let isToday: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            Text(day)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(isToday ? .black : .gray)
                .frame(width: 30, alignment: .leading)
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(.systemGray6))
                        .frame(height: 8)
                    
                    RoundedRectangle(cornerRadius: 4)
                        .fill(isToday ? .black : Color.gray)
                        .frame(width: min(geometry.size.width * (distance / 10.0), geometry.size.width), height: 8)
                }
            }
            .frame(height: 8)
            
            Text(String(format: "%.1f km", distance))
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(isToday ? .black : .gray)
                .frame(width: 55, alignment: .trailing)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview {
    HomeView()
        .environmentObject(AuthViewModel())
}
