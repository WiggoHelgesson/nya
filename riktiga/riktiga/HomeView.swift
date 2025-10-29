import SwiftUI
import Combine

struct HomeView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @ObservedObject private var statisticsService = StatisticsService.shared
    private let healthKitManager = HealthKitManager.shared
    @State private var showMonthlyPrize = false
    @State private var weeklySteps: [DailySteps] = []
    @State private var isLoadingSteps = false
    @State private var observers: [NSObjectProtocol] = []
    @State private var recommendedUsers: [UserSearchResult] = []
    @State private var isLoadingRecommended = false
    @State private var followingStatus: [String: Bool] = [:]
    
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
                            
                            Text((authViewModel.currentUser?.name ?? "ANVÄNDARE").uppercased())
                                .font(.system(size: 36, weight: .bold))
                                .foregroundColor(.black)
                                .padding(.horizontal, 20)
                                .padding(.top, 12)
                                .rotationEffect(.degrees(-2))
                                .shadow(color: Color.black.opacity(0.2), radius: 4, x: 0, y: 2)
                        }
                        .padding(.top, 20)
                        
                        // MARK: - Weekly Distance Section
                        VStack(spacing: 16) {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Denna vecka")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(.gray)
                                    
                                    if statisticsService.isLoading {
                                        Text("Laddar...")
                                            .font(.system(size: 36, weight: .black))
                                            .foregroundColor(.gray)
                                    } else {
                                        Text(String(format: "%.1f km", statisticsService.weeklyStats?.totalDistance ?? 0.0))
                                            .font(.system(size: 36, weight: .black))
                                            .foregroundColor(.black)
                                    }
                                }
                                
                                Spacer()
                                
                                VStack(alignment: .trailing, spacing: 4) {
                                    Text("Mål: 20 km")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(.gray)
                                    
                                    if statisticsService.isLoading {
                                        Text("0%")
                                            .font(.system(size: 20, weight: .bold))
                                            .foregroundColor(.gray)
                                    } else {
                                        Text("\(Int((statisticsService.weeklyStats?.goalProgress ?? 0.0) * 100))%")
                                            .font(.system(size: 20, weight: .bold))
                                            .foregroundColor(.black)
                                    }
                                }
                            }
                            
                            // Progress bar
                            GeometryReader { geometry in
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color(.systemGray6))
                                        .frame(height: 12)
                                    
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color.black)
                                        .frame(width: geometry.size.width * (statisticsService.weeklyStats?.goalProgress ?? 0.0), height: 12)
                                }
                            }
                            .frame(height: 12)
                        }
                        .padding(20)
                        .background(Color.white)
                        .cornerRadius(16)
                        .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 2)
                        .padding(.horizontal, 20)
                        
                        // MARK: - Action Button
                        VStack(spacing: 12) {
                            // Månadens Pris Button
                            Button(action: {
                                showMonthlyPrize = true
                            }) {
                                HStack(spacing: 12) {
                                    Image(systemName: "trophy.fill")
                                        .font(.system(size: 18, weight: .medium))
                                    
                                    Text("MÅNADENS PRIS")
                                        .font(.system(size: 16, weight: .semibold))
                                    
                                    Spacer()
                                    
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 14, weight: .medium))
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(16)
                                .background(Color(.systemGray5))
                                .foregroundColor(.primary)
                                .cornerRadius(12)
                            }
                        }
                        .padding(.horizontal, 20)
                        
                        // MARK: - Weekly Statistics Section
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Veckoöversikt")
                                .font(.system(size: 20, weight: .black))
                                .foregroundColor(.black)
                                .padding(.horizontal, 20)
                            
                            VStack(spacing: 12) {
                                if statisticsService.isLoading {
                                    ForEach(0..<7) { _ in
                                        WeeklyStatRow(day: "---", distance: 0.0, isToday: false)
                                    }
                                } else {
                                    let dailyStats = statisticsService.weeklyStats?.dailyStats ?? []
                                    if dailyStats.isEmpty {
                                        // Show empty week if no data
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
                        
                        // MARK: - Weekly Steps Section
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
                            
                            VStack(spacing: 12) {
                                if isLoadingSteps {
                                    ForEach(0..<7) { _ in
                                        WeeklyStatRow(day: "---", distance: 0.0, isToday: false)
                                    }
                                } else if weeklySteps.isEmpty {
                                    // Show empty week for steps
                                    let days = ["Mån", "Tis", "Ons", "Tor", "Fre", "Lör", "Sön"]
                                    ForEach(Array(days.enumerated()), id: \.offset) { index, day in
                                        WeeklyStepsRow(date: Date(), steps: 0, dayName: day) // Use dummy date and provide day name
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
                        
                        Spacer(minLength: 50)
                    }
                    .padding(.vertical, 12)
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
        }
        .sheet(isPresented: $showMonthlyPrize) {
            MonthlyPrizeView()
        }
        .onAppear {
            if let userId = authViewModel.currentUser?.id {
                Task {
                    await statisticsService.fetchWeeklyStats(userId: userId)
                }
            }
            
            // Hämta stegdata från Apple Health
            isLoadingSteps = true
            healthKitManager.getWeeklySteps { steps in
                weeklySteps = steps
                isLoadingSteps = false
                
                // Kontrollera om användaren nått 10k steg idag och ge poäng
                checkAndAwardDailyStepsReward(steps: steps)
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
                print("🔄 Workout saved, refreshing weekly stats...")
                if let userId = authViewModel.currentUser?.id {
                    Task {
                        await statisticsService.fetchWeeklyStats(userId: userId)
                    }
                }
            }
            
            observers.append(contentsOf: [profileObserver, workoutObserver])
            
            // Load recommended users
            loadRecommendedUsers()
        }
        .onDisappear {
            // Remove all observers
            for observer in observers {
                NotificationCenter.default.removeObserver(observer)
            }
            observers.removeAll()
        }
    }
    
    private func loadRecommendedUsers() {
        guard let userId = authViewModel.currentUser?.id else { return }
        
        isLoadingRecommended = true
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
                    
                    print("✅ Awarded 10 points for reaching 10k steps")
                } catch {
                    print("❌ Error awarding steps points: \(error)")
                }
            }
        }
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
                        .frame(width: steps > 0 ? min(geometry.size.width * (CGFloat(steps) / 20000.0), geometry.size.width) : 0, height: 8)
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

#Preview {
    HomeView()
        .environmentObject(AuthViewModel())
}
