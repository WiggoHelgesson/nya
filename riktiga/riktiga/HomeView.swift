import SwiftUI
import Combine
import UIKit

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

struct HomeView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var isLoadingStats = StatisticsService.shared.isLoading
    @State private var weeklyStats: WeeklyStats? = StatisticsService.shared.weeklyStats
    private let healthKitManager = HealthKitManager.shared
    @State private var showMonthlyPrize = false
    @State private var showStatistics = false
    @State private var weeklySteps: [DailySteps] = []
    @State private var isLoadingSteps = false
    @State private var weeklyFlights: [DailyFlights] = []
    @State private var isLoadingFlights = false
    @State private var observers: [NSObjectProtocol] = []
    @State private var recommendedUsers: [UserSearchResult] = []
    @State private var isLoadingRecommended = false
    @State private var followingStatus: [String: Bool] = [:]
    @State private var currentInsightIndex: Int = 0
    @State private var uppyInsight: String = "Laddar... //UPPY"
    @State private var isLoadingInsight = false
    @State private var pendingRewardCelebration: RewardCelebration?
    @State private var streakInfo = StreakManager.shared.getCurrentStreak()
    private let brandLogos = BrandLogoItem.all
    @State private var monthlyWorkoutDays: Set<Int> = []
    @State private var monthReferenceDate = Date()
    @State private var isLoadingMonthlyCalendar = true
    @State private var selectedReward: RewardCard? = nil
    
    private let isoFormatterWithMs: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
    
    private let isoFormatterNoMs: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Bakgrund
                AppColors.white
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        // MARK: - Top Header with Notifications and Search
                        HomeHeaderView()
                        
                        // MARK: - Welcome Section
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 16) {
                                // Profile Picture Circle
                                AsyncImage(url: URL(string: authViewModel.currentUser?.avatarUrl ?? "")) { image in
                                    image
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                } placeholder: {
                                    Image(systemName: "person.circle.fill")
                                        .font(.system(size: 40))
                                        .foregroundColor(.white)
                                }
                                .frame(width: 50, height: 50)
                                .clipShape(Circle())
                                .overlay(
                                    Circle()
                                        .stroke(Color.white, lineWidth: 2)
                                )
                                
                                Text("VÄLKOMMEN")
                                    .font(.system(size: 32, weight: .black))
                                    .foregroundColor(.white)
                                
                                Spacer()
                            }
                            .padding(.horizontal, 24)
                            .padding(.vertical, 16)
                            .background(Color.black)
                            .cornerRadius(16)
                            .rotationEffect(.degrees(-2))
                            .shadow(color: Color.black.opacity(0.3), radius: 8, x: 0, y: 4)
                        }
                        .padding(.top, 20)
                        
                        motivationBanner
                            .padding(.horizontal, 20)
                        
                        // MARK: - Activity Insights (Steps / Sleep / Distance)
                        TabView(selection: $currentInsightIndex) {
                            monthlyCalendarCard
                                .tag(0)
                            stepsCard
                                .tag(1)
                            weeklyDistanceCard
                                .tag(2)
                        }
                        .frame(height: 320)
                        .tabViewStyle(.page(indexDisplayMode: .automatic))
                        .padding(.top, 8)
                        
                        HStack(spacing: 6) {
                            ForEach(0..<3) { index in
                                Circle()
                                    .fill(index == currentInsightIndex ? Color.black : Color.gray.opacity(0.3))
                                    .frame(width: 8, height: 8)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.bottom, 8)
                        
                        brandLogoSlider
                            .padding(.horizontal, 20)
                        
                        streakSection
                            .padding(.horizontal, 20)
                        
                        // MARK: - Recommended Friends Section
                        if !recommendedUsers.isEmpty || isLoadingRecommended {
                            VStack(alignment: .leading, spacing: 16) {
                                Text("Rekommenderade vänner")
                                    .font(.system(size: 20, weight: .black))
                                    .foregroundColor(.black)
                                    .padding(.horizontal, 20)
                                
                                if isLoadingRecommended {
                                    HStack {
                                        ProgressView()
                                        Spacer()
                                    }
                                    .padding(20)
                                    .background(Color.white)
                                    .cornerRadius(16)
                                    .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 2)
                                    .padding(.horizontal, 20)
                                } else {
                                    ScrollView(.horizontal, showsIndicators: false) {
                                        HStack(spacing: 12) {
                                            ForEach(recommendedUsers) { user in
                                                RecommendedFriendCard(
                                                    user: user,
                                                    isFollowing: followingStatus[user.id] ?? false,
                                                    onFollowToggle: {
                                                        toggleFollow(userId: user.id)
                                                    }
                                                )
                                            }
                                        }
                                        .padding(.horizontal, 20)
                                    }
                                }
                            }
                        }
                        
                        HealthDataDisclosureView(
                            title: "Apple Health-data",
                            description: "Up&Down hämtar distans- och steginformation från Apple Health för att hålla dina mål och listor uppdaterade.",
                            showsManageButton: true,
                            manageAction: openHealthSettings
                        )
                        .padding(.horizontal, 20)

                        Spacer(minLength: 50)
                    }
                    .padding(.vertical, 12)
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
        }
        .enableSwipeBack()
        .sheet(isPresented: $showStatistics) {
            StatisticsView()
        }
        .sheet(isPresented: $showMonthlyPrize) {
            MonthlyPrizeView()
        }
        .sheet(item: $selectedReward) { reward in
            RewardDetailView(reward: reward)
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
            if let userId = authViewModel.currentUser?.id {
                Task {
                    await StatisticsService.shared.fetchWeeklyStats(userId: userId)
                }
            }
            
            // Refresh streak info
            streakInfo = StreakManager.shared.getCurrentStreak()
            
            // Load AI-generated insight
            loadUppyInsight()
            loadMonthlyCalendarData()
            
            // Hämta stegdata från Apple Health
            isLoadingSteps = true
            healthKitManager.getWeeklySteps { steps in
                weeklySteps = steps
                isLoadingSteps = false
                
                // Kontrollera om användaren nått 10k steg idag och ge poäng
                awardStepsPointsIfNeeded(steps: steps.first(where: { Calendar.current.isDateInToday($0.date) })?.steps ?? 0)
            }
            
            // Hämta sömndata
            isLoadingFlights = true
            healthKitManager.getWeeklyFlightsClimbed { flightEntries in
                weeklyFlights = flightEntries
                isLoadingFlights = false
                if let todayFlights = flightEntries.first(where: { $0.isToday }) {
                    awardFlightsPointsIfNeeded(flights: todayFlights.count)
                }
            }
            
            // Lyssna på profilbild uppdateringar
            let profileObserver = NotificationCenter.default.addObserver(
                forName: .profileImageUpdated,
                object: nil,
                queue: .main
            ) { notification in
                if let newImageUrl = notification.object as? String {
                    print("🔄 Profile image updated in HomeView: \(newImageUrl)")
                    authViewModel.objectWillChange.send()
                }
            }
            
            // Lyssna på uppdateringar efter att en workout har sparats
            let workoutObserver = NotificationCenter.default.addObserver(
                forName: NSNotification.Name("WorkoutSaved"),
                object: nil,
                queue: .main
            ) { _ in
                print("🔄 Workout saved, refreshing weekly stats and streak...")
                // Refresh streak info
                streakInfo = StreakManager.shared.getCurrentStreak()
                if let userId = authViewModel.currentUser?.id {
                    Task {
                        await StatisticsService.shared.fetchWeeklyStats(userId: userId)
                    }
                }
                loadMonthlyCalendarData(force: true)
            }
            
            observers.append(contentsOf: [profileObserver, workoutObserver])
            
            // Load recommended users
            loadRecommendedUsers()
            
            presentNextRewardIfAvailable()
        }
        .onDisappear {
            // Remove all observers
            for observer in observers {
                NotificationCenter.default.removeObserver(observer)
            }
            observers.removeAll()
        }
        .onReceive(StatisticsService.shared.$isLoading) { newValue in
            isLoadingStats = newValue
        }
        .onReceive(StatisticsService.shared.$weeklyStats) { newValue in
            weeklyStats = newValue
        }
        .onReceive(NotificationCenter.default.publisher(for: .rewardCelebrationQueued)) { _ in
            presentNextRewardIfAvailable()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            presentNextRewardIfAvailable()
        }
    }
    
    private var calendar: Calendar {
        var cal = Calendar(identifier: .iso8601)
        cal.locale = Locale(identifier: "sv_SE")
        cal.firstWeekday = 2
        return cal
    }
    
    private func loadRecommendedUsers() {
        guard let userId = authViewModel.currentUser?.id else { return }
        
        isLoadingRecommended = true
        // Try cache first for instant UI
        if let cached = AppCacheManager.shared.getCachedRecommendedUsers(userId: userId) {
            self.recommendedUsers = cached
            self.isLoadingRecommended = false
        }
        Task {
            do {
                // Use retry helper for better network resilience
                let recommended = try await RetryHelper.shared.retry(maxRetries: 3, delay: 0.5) {
                    return try await SocialService.shared.getRecommendedUsers(userId: userId, limit: 10)
                }
                
                // Check follow status for each recommended user
                var followStatus: [String: Bool] = [:]
                for user in recommended {
                    let isFollowing = try await SocialService.shared.isFollowing(followerId: userId, followingId: user.id)
                    followStatus[user.id] = isFollowing
                }
                
                await MainActor.run {
                    self.recommendedUsers = recommended
                    self.followingStatus = followStatus
                    self.isLoadingRecommended = false
                }
                AppCacheManager.shared.saveRecommendedUsers(recommended, userId: userId)
            } catch {
                print("❌ Error loading recommended users after retries: \(error)")
                await MainActor.run {
                    self.isLoadingRecommended = false
                }
            }
        }
    }
    
    private func toggleFollow(userId: String) {
        guard let currentUserId = authViewModel.currentUser?.id else { return }
        
        let isCurrentlyFollowing = followingStatus[userId] ?? false
        
        Task {
            do {
                if isCurrentlyFollowing {
                    try await SocialService.shared.unfollowUser(followerId: currentUserId, followingId: userId)
                } else {
                    try await SocialService.shared.followUser(followerId: currentUserId, followingId: userId)
                }
                
                await MainActor.run {
                    followingStatus[userId] = !isCurrentlyFollowing
                }
            } catch {
                print("❌ Error toggling follow: \(error)")
            }
        }
    }

    private var motivationBanner: some View {
        NavigationLink {
            UppyChatView()
        } label: {
            HStack(alignment: .center, spacing: 14) {
                Image("31")
                    .resizable()
                    .scaledToFill()
                    .frame(width: 64, height: 64)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .shadow(color: Color.black.opacity(0.12), radius: 6, x: 0, y: 4)
                
                if isLoadingInsight {
                    HStack(spacing: 8) {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("Analyserar...")
                            .font(.system(size: 13))
                            .foregroundColor(.gray)
                    }
                } else {
                    Text(uppyInsight)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.black)
                        .multilineTextAlignment(.leading)
                }
                
                Spacer()
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 18)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color.white)
                    .shadow(color: Color.black.opacity(0.06), radius: 12, x: 0, y: 6)
            )
        }
        .buttonStyle(.plain)
    }
    
    private var brandLogoSlider: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Varumärken")
                .font(.system(size: 20, weight: .black))
                .foregroundColor(.black)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 18) {
                    ForEach(brandLogos) { brand in
                        Button {
                            handleBrandTap(brand.name)
                        } label: {
                            VStack(spacing: 8) {
                                Image(brand.imageName)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 68, height: 68)
                                    .background(Color(.systemGray6))
                                    .clipShape(Circle())
                                    .overlay(
                                        Circle()
                                            .stroke(Color.black.opacity(0.08), lineWidth: 1)
                                    )
                                    .shadow(color: Color.black.opacity(0.08), radius: 6, x: 0, y: 3)
                                
                                Text(brand.name.capitalized)
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(.black)
                                    .lineLimit(1)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.white)
                .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 6)
        )
    }
    
    private func handleBrandTap(_ brandName: String) {
        if let reward = rewardForBrand(brandName) {
            selectedReward = reward
        } else {
            openBrandWebsite(brandName)
        }
    }
    
    private func rewardForBrand(_ brandName: String) -> RewardCard? {
        RewardCatalog.all.first { $0.brandName.caseInsensitiveCompare(brandName) == .orderedSame }
    }
    
    private func openBrandWebsite(_ brandName: String) {
        let urlString: String
        switch brandName.uppercased() {
        case "J.LINDEBERG":
            urlString = "https://jlindeberg.com/"
        case "PUMPLABS":
            urlString = "https://pumplab.se/"
        case "EXOTIC GOLF":
            urlString = "https://exoticagolf.se/"
        case "ZEN ENERGY":
            urlString = "https://zenenergydrinks.com/?srsltid=AfmBOoo0XewnkvbPLeH1CbuslALX3C-hEOOaf_jJuHh3XMGlHm-rB2Pb"
        case "HAPPYALBA":
            urlString = "https://www.happyalba.com/"
        case "LONEGOLF":
            urlString = "https://lonegolf.se"
        case "PEGMATE":
            urlString = "https://pegmate.se/en/"
        case "PLIKTGOLF":
            urlString = "https://pliktgolf.se"
        case "PEAK":
            urlString = "https://peaksummit.se"
        case "CAPSTONE":
            urlString = "https://capstone.nu/"
        case "FUSE ENERGY":
            urlString = "https://fuseenergy.se"
        case "RETROGOLF":
            urlString = "https://retrogolfacademy.se/"
        case "SCANDIGOLF":
            urlString = "https://www.scandigolf.se/"
        case "WINWIZE":
            urlString = "https://winwize.com/?srsltid=AfmBOootwFRqBXLHIeZW7SD8Em9h3_XydIfKOpTSt_uB01nndveoqM0J"
        default:
            urlString = "https://google.com"
        }
        
        if let url = URL(string: urlString) {
            UIApplication.shared.open(url)
        }
    }
    
    private var streakSection: some View {
        VStack(spacing: 16) {
            HStack(spacing: 16) {
                // Flame icon with gradient
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.orange.opacity(0.2), Color.orange.opacity(0.05)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: 70, height: 70)
                    
                    Image(systemName: "flame.fill")
                        .font(.system(size: 36))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color.orange, Color.red],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                }
                
                VStack(alignment: .leading, spacing: 6) {
                    Text("Din streak")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.black)
                    
                    HStack(spacing: 8) {
                        Text("\(streakInfo.consecutiveDays)")
                            .font(.system(size: 28, weight: .black))
                            .foregroundColor(.black)
                        Text(streakInfo.consecutiveDays == 1 ? "dag i rad" : "dagar i rad")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.gray)
                    }
                    
                    Text("\(streakInfo.completedDaysThisWeek)/7 dagar denna vecka")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.gray)
                }
                
                Spacer()
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color.white)
                    .shadow(color: Color.black.opacity(0.06), radius: 12, x: 0, y: 6)
            )
            
            // Week calendar
            HStack(spacing: 8) {
                ForEach(0..<7) { index in
                    let symbols = Calendar.current.shortWeekdaySymbols
                    let symbol = symbols[index]
                    let isCompleted = streakInfo.completedDaysThisWeek > index
                    
                    VStack(spacing: 6) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(isCompleted ?
                                      LinearGradient(colors: [Color.orange, Color.orange.opacity(0.8)], startPoint: .top, endPoint: .bottom) :
                                      LinearGradient(colors: [Color(.systemGray6), Color(.systemGray6)], startPoint: .top, endPoint: .bottom))
                                .frame(height: 48)
                            
                            if isCompleted {
                                Image(systemName: "flame.fill")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(.white)
                            } else {
                                Circle()
                                    .fill(Color.white.opacity(0.5))
                                    .frame(width: 6, height: 6)
                            }
                        }
                        
                        Text(String(symbol.prefix(2)))
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.gray)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.white)
                    .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 4)
            )
        }
    }
    
    private func checkAndAwardDailyStepsReward(steps: [DailySteps]) {
        // Hitta dagens steg
        guard let todaySteps = steps.first(where: { Calendar.current.isDateInToday($0.date) }),
              todaySteps.steps >= 10000 else {
            return
        }
        
        // Kontrollera om användaren redan fått poäng idag
        let today = Calendar.current.startOfDay(for: Date())
        let lastRewardDate = UserDefaults.standard.object(forKey: "lastStepsRewardDate") as? Date ?? Date.distantPast
        let lastRewardDay = Calendar.current.startOfDay(for: lastRewardDate)
        
        // Om användaren inte har fått poäng idag, ge 10 poäng
        if today > lastRewardDay {
            Task {
                guard let userId = authViewModel.currentUser?.id else { return }
                
                do {
                    // Ge 10 poäng
                    try await ProfileService.shared.updateUserPoints(userId: userId, pointsToAdd: 10)
                    
                    // Spara att vi har gett poäng idag
                    UserDefaults.standard.set(Date(), forKey: "lastStepsRewardDate")
                    
                    // Reload user profile to update XP
                    if let updatedProfile = try await ProfileService.shared.fetchUserProfile(userId: userId) {
                        await MainActor.run {
                            authViewModel.currentUser = updatedProfile
                        }
                    }
                    
                    RewardCelebrationManager.shared.enqueueReward(points: 10, reason: "10 000 steg avklarade i dag!")
                    print("✅ Awarded 10 points for reaching 10k steps")
                } catch {
                    print("❌ Error awarding steps points: \(error)")
                }
            }
        }
    }

    private func openHealthSettings() {
        HealthKitManager.shared.handleManageAuthorizationButton()
    }

    private func refreshUserProfile() async {
        guard let userId = authViewModel.currentUser?.id else { return }
        do {
            if let updatedProfile = try await ProfileService.shared.fetchUserProfile(userId: userId) {
                await MainActor.run {
                    authViewModel.currentUser = updatedProfile
                }
            }
        } catch {
            print("❌ Error refreshing user profile: \(error)")
        }
    }
    
    private func loadUppyInsight() {
        // Check cache first (valid for 24 hours)
        let cacheKey = "uppyInsight_\(Calendar.current.startOfDay(for: Date()).timeIntervalSince1970)"
        if let cached = UserDefaults.standard.string(forKey: cacheKey) {
            uppyInsight = cached
            return
        }
        
        isLoadingInsight = true
        Task {
            let insight = await UppyInsightBuilder.shared.generateDailyInsight(for: authViewModel.currentUser)
            await MainActor.run {
                self.uppyInsight = insight
                self.isLoadingInsight = false
                // Cache for 24h
                UserDefaults.standard.set(insight, forKey: cacheKey)
            }
        }
    }
    
    private func presentNextRewardIfAvailable() {
        guard pendingRewardCelebration == nil else { return }
        if let reward = RewardCelebrationManager.shared.consumeNextReward() {
            pendingRewardCelebration = reward
        }
    }
}

// MARK: - Subviews for HomeView activity insights
extension HomeView {
    private var stepsCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Steg denna vecka")
                    .font(.system(size: 20, weight: .black))
                    .foregroundColor(.black)
                Text("Gå 10k steg och få 10 poäng varje dag")
                    .font(.system(size: 14))
                    .foregroundColor(.gray)
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            
            VStack(spacing: 12) {
                if isLoadingSteps {
                    ForEach(0..<7) { _ in
                        WeeklyStatRow(day: "---", distance: 0.0, isToday: false)
                    }
                } else if weeklySteps.isEmpty {
                    let days = ["Mån", "Tis", "Ons", "Tor", "Fre", "Lör", "Sön"]
                    ForEach(Array(days.enumerated()), id: \.offset) { index, day in
                        WeeklyStepsRow(date: Date(), steps: 0, dayName: day)
                    }
                } else {
                    ForEach(weeklySteps) { dailySteps in
                        WeeklyStepsRow(date: dailySteps.date, steps: dailySteps.steps)
                    }
                }
            }
            .padding(20)
            .background(Color.white)
            .cornerRadius(16)
            .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 2)
        }
        .padding(.horizontal, 20)
    }
    
    private var monthlyCalendarCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Träningspass denna månaden")
                    .font(.system(size: 20, weight: .black))
                    .foregroundColor(.black)
            }
            .padding(.horizontal, 20)
            .padding(.top, 32)
            
            VStack(spacing: 16) {
                if isLoadingMonthlyCalendar {
                    ProgressView("Hämtar kalender…")
                        .padding()
                } else {
                    MonthMiniGrid(referenceDate: monthReferenceDate,
                                  workoutDays: monthlyWorkoutDays,
                                  calendar: calendar)
                }
            }
            .padding(20)
            .background(Color.white)
            .cornerRadius(16)
            .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 2)
        }
        .padding(.horizontal, 20)
    }
    
    private func awardFlightsPointsIfNeeded(flights: Int) {
        guard flights >= 10 else { return }
        let today = Calendar.current.startOfDay(for: Date())
        let lastRewardDate = UserDefaults.standard.object(forKey: "lastFlightsRewardDate") as? Date ?? Date.distantPast
        if Calendar.current.startOfDay(for: lastRewardDate) == today { return }
        Task {
            guard let userId = authViewModel.currentUser?.id else { return }
            do {
                try await ProfileService.shared.updateUserPoints(userId: userId, pointsToAdd: 5)
                UserDefaults.standard.set(Date(), forKey: "lastFlightsRewardDate")
                await refreshUserProfile()
                RewardCelebrationManager.shared.enqueueReward(points: 5, reason: "Du tog 10 trappor i dag!")
            } catch {
                print("⚠️ Could not award flights points: \(error)")
            }
        }
    }
    
    private func awardStepsPointsIfNeeded(steps: Int) {
        guard steps >= 10_000 else { return }
        let today = Calendar.current.startOfDay(for: Date())
        let lastRewardDate = UserDefaults.standard.object(forKey: "lastStepsRewardDate") as? Date ?? Date.distantPast
        if Calendar.current.startOfDay(for: lastRewardDate) == today { return }
        Task {
            guard let userId = authViewModel.currentUser?.id else { return }
            do {
                try await ProfileService.shared.updateUserPoints(userId: userId, pointsToAdd: 10)
                UserDefaults.standard.set(Date(), forKey: "lastStepsRewardDate")
                await refreshUserProfile()
                RewardCelebrationManager.shared.enqueueReward(points: 10, reason: "10 000 steg avklarade i dag!")
            } catch {
                print("⚠️ Error awarding steps points: \(error)")
            }
        }
    }
    
    private func loadMonthlyCalendarData(force: Bool = false) {
        guard let userId = authViewModel.currentUser?.id else { return }
        Task {
            do {
                let posts = try await WorkoutService.shared.getUserWorkoutPosts(userId: userId, forceRefresh: force)
                let cal = calendar
                let startOfMonth = cal.date(from: cal.dateComponents([.year, .month], from: Date())) ?? Date()
                let endOfMonth = cal.date(byAdding: .month, value: 1, to: startOfMonth) ?? Date()
                let days = posts.compactMap { post -> Int? in
                    guard let date = parseISODate(post.createdAt) else { return nil }
                    guard date >= startOfMonth && date < endOfMonth else { return nil }
                    return cal.component(.day, from: date)
                }
                await MainActor.run {
                    monthReferenceDate = startOfMonth
                    monthlyWorkoutDays = Set(days)
                    isLoadingMonthlyCalendar = false
                }
            } catch {
                await MainActor.run {
                    isLoadingMonthlyCalendar = false
                }
            }
        }
    }
    
    private func parseISODate(_ string: String) -> Date? {
        if let date = isoFormatterWithMs.date(from: string) {
            return date
        }
        return isoFormatterNoMs.date(from: string)
    }
    
    private var weeklyDistanceCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Veckoöversikt")
                .font(.system(size: 20, weight: .black))
                .foregroundColor(.black)
                .padding(.horizontal, 20)
            
            VStack(spacing: 12) {
                if isLoadingStats {
                    ForEach(0..<7) { _ in
                        WeeklyStatRow(day: "---", distance: 0.0, isToday: false)
                    }
                } else {
                    let dailyStats = weeklyStats?.dailyStats ?? []
                    if dailyStats.isEmpty {
                        let days = ["Mån", "Tis", "Ons", "Tor", "Fre", "Lör", "Sön"]
                        ForEach(days, id: \.self) { day in
                            WeeklyStatRow(day: day, distance: 0.0, isToday: false)
                        }
                    } else {
                        ForEach(dailyStats, id: \.day) { dailyStat in
                            WeeklyStatRow(day: dailyStat.day, distance: dailyStat.distance, isToday: dailyStat.isToday)
                        }
                    }
                }
            }
            .padding(20)
            .background(Color.white)
            .cornerRadius(16)
            .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 2)
        }
        .padding(.horizontal, 20)
    }
}

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

struct WeeklyStepsRow: View {
    let date: Date
    let steps: Int
    let dayNameOverride: String?
    
    init(date: Date, steps: Int, dayName: String? = nil) {
        self.date = date
        self.steps = steps
        self.dayNameOverride = dayName
    }
    
    private var isToday: Bool {
        Calendar.current.isDateInToday(date)
    }
    
    private var dayName: String {
        if let override = dayNameOverride {
            return override
        }
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter.string(from: date)
    }
    
    private var reachedGoal: Bool {
        steps >= 10000
    }
    
    var body: some View {
        HStack(spacing: 12) {
            Text(dayName)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(isToday ? .black : .gray)
                .frame(width: 30, alignment: .leading)
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(.systemGray6))
                        .frame(height: 8)
                    
                    RoundedRectangle(cornerRadius: 4)
                        .fill(reachedGoal ? Color.green : Color.red)
                        .frame(width: steps > 0 ? min(geometry.size.width * (CGFloat(steps) / 10000.0), geometry.size.width) : 0, height: 8)
                }
            }
            .frame(height: 8)
            
            Text("\(steps)")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(isToday ? .black : .gray)
                .frame(width: 55, alignment: .trailing)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

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
                .foregroundColor(.black)
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

struct WeeklyFlightsRow: View {
    let day: String
    let flights: Int
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
                        .fill(flights >= 10 ? Color.green : Color.orange)
                        .frame(width: min(geometry.size.width * (CGFloat(flights) / 10.0), geometry.size.width), height: 8)
                }
            }
            .frame(height: 8)
            
            Text("\(flights)")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(isToday ? .black : .gray)
                .frame(width: 55, alignment: .trailing)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct MonthMiniGrid: View {
    let referenceDate: Date
    let workoutDays: Set<Int>
    let calendar: Calendar
    
    private var monthLabel: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "LLLL yyyy"
        formatter.locale = Locale(identifier: "sv_SE")
        return formatter.string(from: referenceDate).capitalized
    }
    
    private var daysInMonth: [Int] {
        guard let range = calendar.range(of: .day, in: .month, for: referenceDate) else { return [] }
        return Array(range)
    }
    
    private var firstWeekdayOffset: Int {
        let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: referenceDate)) ?? referenceDate
        let weekday = calendar.component(.weekday, from: monthStart)
        return (weekday - calendar.firstWeekday + 7) % 7
    }
    
    private var weekdaySymbols: [String] {
        ["Mån", "Tis", "Ons", "Tor", "Fre", "Lör", "Sön"]
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(monthLabel)
                .font(.system(size: 18, weight: .semibold))
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 7), spacing: 10) {
                ForEach(weekdaySymbols, id: \.self) { symbol in
                    Text(symbol)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.gray)
                        .frame(maxWidth: .infinity)
                }
                
                ForEach(0..<firstWeekdayOffset, id: \.self) { _ in
                    Text("")
                        .frame(height: 30)
                }
                
                ForEach(daysInMonth, id: \.self) { day in
                    let hasWorkout = workoutDays.contains(day)
                    Text("\(day)")
                        .font(.system(size: 14, weight: .semibold))
                        .frame(width: 32, height: 32)
                        .background(
                            Circle()
                                .fill(hasWorkout ? Color.black : Color.clear)
                                .overlay(
                                    Circle()
                                        .stroke(Color.black.opacity(0.08), lineWidth: hasWorkout ? 0 : 1)
                                )
                        )
                        .foregroundColor(hasWorkout ? .white : .primary)
                }
            }
        }
    }
}

#Preview {
    HomeView()
        .environmentObject(AuthViewModel())
}
