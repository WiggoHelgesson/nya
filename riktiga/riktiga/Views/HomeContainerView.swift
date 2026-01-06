import SwiftUI

enum HomeTab: String, CaseIterable {
    case home = "Hem"
    case zoneWar = "Zonkriget"
}

struct HomeContainerView: View {
    @State private var selectedTab: HomeTab = .home
    
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                // FAST tab selector - scrollar INTE med innehållet
                HomeTabSelector(selectedTab: $selectedTab)
                
                // Innehållet under - detta är det enda som scrollar
                if selectedTab == .home {
                    HomeContentView()
                } else {
                    ZoneWarView()
                }
            }
        }
        .ignoresSafeArea(edges: .bottom)
    }
}

// MARK: - Tab Selector (FAST position - scrollar inte)
struct HomeTabSelector: View {
    @Binding var selectedTab: HomeTab
    
    var body: some View {
        VStack(spacing: 0) {
            // Tab buttons
            HStack(spacing: 0) {
                ForEach(HomeTab.allCases, id: \.self) { tab in
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedTab = tab
                        }
                    } label: {
                        VStack(spacing: 6) {
                            Text(tab.rawValue)
                                .font(.system(size: 16, weight: selectedTab == tab ? .bold : .medium))
                                .foregroundColor(selectedTab == tab ? .black : .gray)
                            
                            // Underline indicator
                            Rectangle()
                                .fill(selectedTab == tab ? Color.black : Color.clear)
                                .frame(height: 3)
                                .cornerRadius(1.5)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 40)
            
            // Separator line
            Rectangle()
                .fill(Color(.systemGray5))
                .frame(height: 1)
        }
        .background(Color(.systemBackground))
    }
}

// MARK: - Home Content (utan NavigationStack wrapper)
struct HomeContentView: View {
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
                AppColors.white
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        // MARK: - Top Header with Notifications and Search
                        HomeHeaderView()
                        
                        // MARK: - Welcome Section
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 16) {
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
                        
                        // MARK: - Uppy Motivation Banner
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
                                        .foregroundColor(.primary)
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
                        .padding(.horizontal, 20)
                        
                        // MARK: - Activity Insights
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
                        
                        // MARK: - Streak Section
                        streakSection
                            .padding(.horizontal, 20)
                        
                        // MARK: - Recommended Friends
                        if !recommendedUsers.isEmpty || isLoadingRecommended {
                            recommendedFriendsSection
                        }
                        
                        // MARK: - Health Data Disclosure
                        HealthDataDisclosureView(
                            title: "Apple Health-data",
                            description: "Up&Down hämtar distans- och steginformation från Apple Health för att hålla dina mål och listor uppdaterade.",
                            showsManageButton: true,
                            manageAction: { HealthKitManager.shared.handleManageAuthorizationButton() }
                        )
                        .padding(.horizontal, 20)

                        Spacer(minLength: 100)
                    }
                    .padding(.vertical, 12)
                }
            }
            .navigationTitle("")
            .navigationBarHidden(true)
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
            }
        }
        .onAppear {
            loadData()
        }
        .onDisappear {
            for observer in observers {
                NotificationCenter.default.removeObserver(observer)
            }
            observers.removeAll()
        }
        .onReceive(StatisticsService.shared.$isLoading) { isLoadingStats = $0 }
        .onReceive(StatisticsService.shared.$weeklyStats) { weeklyStats = $0 }
    }
    
    // MARK: - Subviews
    
    private var streakSection: some View {
        VStack(spacing: 16) {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(LinearGradient(colors: [Color.orange.opacity(0.2), Color.orange.opacity(0.05)], startPoint: .top, endPoint: .bottom))
                        .frame(width: 70, height: 70)
                    
                    Image(systemName: "flame.fill")
                        .font(.system(size: 36))
                        .foregroundStyle(LinearGradient(colors: [Color.orange, Color.red], startPoint: .top, endPoint: .bottom))
                }
                
                VStack(alignment: .leading, spacing: 6) {
                    Text("Din streak")
                        .font(.system(size: 18, weight: .bold))
                    
                    HStack(spacing: 8) {
                        Text("\(streakInfo.consecutiveDays)")
                            .font(.system(size: 28, weight: .black))
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
        }
    }
    
    private var recommendedFriendsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Rekommenderade vänner")
                .font(.system(size: 20, weight: .black))
                .padding(.horizontal, 20)
            
            if isLoadingRecommended {
                HStack {
                    ProgressView()
                    Spacer()
                }
                .padding(20)
                .background(Color(.secondarySystemBackground))
                .cornerRadius(16)
                .padding(.horizontal, 20)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(recommendedUsers) { user in
                            RecommendedFriendCard(
                                user: user,
                                isFollowing: followingStatus[user.id] ?? false,
                                onFollowToggle: { toggleFollow(userId: user.id) }
                            )
                        }
                    }
                    .padding(.horizontal, 20)
                }
            }
        }
    }
    
    private var stepsCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Steg denna vecka")
                    .font(.system(size: 20, weight: .black))
                Text("Gå 10k steg och få 10 poäng varje dag")
                    .font(.system(size: 14))
                    .foregroundColor(.gray)
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            
            VStack(spacing: 12) {
                if weeklySteps.isEmpty {
                    let days = ["Mån", "Tis", "Ons", "Tor", "Fre", "Lör", "Sön"]
                    ForEach(days, id: \.self) { day in
                        WeeklyStepsRow(date: Date(), steps: 0, dayName: day)
                    }
                } else {
                    ForEach(weeklySteps) { dailySteps in
                        WeeklyStepsRow(date: dailySteps.date, steps: dailySteps.steps)
                    }
                }
            }
            .padding(20)
            .background(Color(.secondarySystemBackground))
            .cornerRadius(16)
        }
        .padding(.horizontal, 20)
    }
    
    private var monthlyCalendarCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Träningspass denna månaden")
                .font(.system(size: 20, weight: .black))
                .padding(.horizontal, 20)
                .padding(.top, 32)
            
            VStack(spacing: 16) {
                if isLoadingMonthlyCalendar {
                    ProgressView("Hämtar kalender…")
                        .padding()
                } else {
                    MonthMiniGridSimple(referenceDate: monthReferenceDate, workoutDays: monthlyWorkoutDays)
                }
            }
            .padding(20)
            .background(Color(.secondarySystemBackground))
            .cornerRadius(16)
        }
        .padding(.horizontal, 20)
    }
    
    private var weeklyDistanceCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Veckoöversikt")
                .font(.system(size: 20, weight: .black))
                .padding(.horizontal, 20)
            
            VStack(spacing: 12) {
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
            .padding(20)
            .background(Color(.secondarySystemBackground))
            .cornerRadius(16)
        }
        .padding(.horizontal, 20)
    }
    
    // MARK: - Functions
    
    private func loadData() {
        if let userId = authViewModel.currentUser?.id {
            Task {
                await StatisticsService.shared.fetchWeeklyStats(userId: userId)
            }
        }
        
        streakInfo = StreakManager.shared.getCurrentStreak()
        loadUppyInsight()
        loadMonthlyCalendarData()
        
        isLoadingSteps = true
        healthKitManager.getWeeklySteps { steps in
            weeklySteps = steps
            isLoadingSteps = false
        }
        
        loadRecommendedUsers()
        presentNextRewardIfAvailable()
    }
    
    private func loadRecommendedUsers() {
        guard let userId = authViewModel.currentUser?.id else { return }
        isLoadingRecommended = true
        
        Task {
            do {
                let recommended = try await SocialService.shared.getRecommendedUsers(userId: userId, limit: 10)
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
            } catch {
                await MainActor.run { self.isLoadingRecommended = false }
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
    
    private func loadUppyInsight() {
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
                UserDefaults.standard.set(insight, forKey: cacheKey)
            }
        }
    }
    
    private func loadMonthlyCalendarData() {
        guard let userId = authViewModel.currentUser?.id else { return }
        Task {
            do {
                let posts = try await WorkoutService.shared.getUserWorkoutPosts(userId: userId, forceRefresh: false)
                var cal = Calendar(identifier: .iso8601)
                cal.locale = Locale(identifier: "sv_SE")
                cal.firstWeekday = 2
                
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
                await MainActor.run { isLoadingMonthlyCalendar = false }
            }
        }
    }
    
    private func parseISODate(_ string: String) -> Date? {
        if let date = isoFormatterWithMs.date(from: string) { return date }
        return isoFormatterNoMs.date(from: string)
    }
    
    private func presentNextRewardIfAvailable() {
        guard pendingRewardCelebration == nil else { return }
        if let reward = RewardCelebrationManager.shared.consumeNextReward() {
            pendingRewardCelebration = reward
        }
    }
}

// MARK: - Simple Month Grid
private struct MonthMiniGridSimple: View {
    let referenceDate: Date
    let workoutDays: Set<Int>
    
    private var calendar: Calendar {
        var cal = Calendar(identifier: .iso8601)
        cal.locale = Locale(identifier: "sv_SE")
        cal.firstWeekday = 2
        return cal
    }
    
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
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(monthLabel)
                .font(.system(size: 18, weight: .semibold))
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 7), spacing: 10) {
                ForEach(["Mån", "Tis", "Ons", "Tor", "Fre", "Lör", "Sön"], id: \.self) { symbol in
                    Text(symbol)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.gray)
                }
                
                ForEach(0..<firstWeekdayOffset, id: \.self) { _ in
                    Text("").frame(height: 30)
                }
                
                ForEach(daysInMonth, id: \.self) { day in
                    let hasWorkout = workoutDays.contains(day)
                    Text("\(day)")
                        .font(.system(size: 14, weight: .semibold))
                        .frame(width: 32, height: 32)
                        .background(
                            Circle()
                                .fill(hasWorkout ? Color.black : Color.clear)
                                .overlay(Circle().stroke(Color.black.opacity(0.08), lineWidth: hasWorkout ? 0 : 1))
                        )
                        .foregroundColor(hasWorkout ? .white : .primary)
                }
            }
        }
    }
}

#Preview {
    HomeContainerView()
        .environmentObject(AuthViewModel())
}
