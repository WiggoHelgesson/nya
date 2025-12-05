import SwiftUI
import Combine

struct ProfileView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @ObservedObject private var revenueCatManager = RevenueCatManager.shared
    @State private var showImagePicker = false
    @State private var profileImage: UIImage?
    @State private var showSettings = false
    @State private var showStatistics = false
    @State private var showMyPurchases = false
    @State private var showFindFriends = false
    @State private var showFollowersList = false
    @State private var showFollowingList = false
    @State private var followersCount = 0
    @State private var followingCount = 0
    @State private var profileObserver: NSObjectProtocol?
    @State private var showEditProfile = false
    @State private var showPaywall = false
    @State private var showTrainerOnboarding = false
    @State private var weeklyActivityData: [WeeklyActivityData] = []
    @State private var activityCount: Int = 0
    @State private var personalBestInfo: PersonalBestInfo = PersonalBestInfo()
    @State private var lastActivityFetch: Date?
    @State private var isUsingCachedWeeklyData = false
    @State private var selectedPost: SocialWorkoutPost?
    
    private let cacheManager = AppCacheManager.shared
    private let weeklyDataThrottle: TimeInterval = 120
    
    private func updatePersonalBestInfo() {
        let fiveKm = authViewModel.currentUser?.pb5kmMinutes
        let tenKmMinutes: Int?
        if let minutes = authViewModel.currentUser?.pb10kmMinutes {
            let hours = authViewModel.currentUser?.pb10kmHours ?? 0
            tenKmMinutes = hours * 60 + minutes
        } else {
            tenKmMinutes = nil
        }
        personalBestInfo = PersonalBestInfo(fiveKmMinutes: fiveKm, tenKmMinutes: tenKmMinutes, benchMaxKg: personalBestInfo.benchMaxKg)
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // MARK: - Profile Header Card with Settings button in top right
                    HStack {
                        if !revenueCatManager.isPremium {
                            Button(action: {
                                showPaywall = true
                            }) {
                                Image("41")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 36, height: 36)
                                    .shadow(color: Color.black.opacity(0.15), radius: 6, x: 0, y: 3)
                            }
                        }
                        
                        Spacer()
                        
                        Button(action: {
                            showSettings = true
                        }) {
                            Image(systemName: "gearshape.fill")
                                .font(.title2)
                                .foregroundColor(.black)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 8)
                    
                    VStack(spacing: 16) {
                        HStack(spacing: 16) {
                            // Profilbild - Tappable
                            VStack(spacing: 4) {
                                Button(action: {
                                    showImagePicker = true
                                }) {
                                    ProfileImage(url: authViewModel.currentUser?.avatarUrl, size: 80)
                                }
                                
                                Text("Tryck på bilden ovan för att byta profilbild")
                                    .font(.caption2)
                                    .foregroundColor(.gray)
                                    .multilineTextAlignment(.center)
                                    .frame(width: 80)
                            }
                            
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Text(authViewModel.currentUser?.name ?? "User")
                                        .font(.system(size: 20, weight: .bold))
                                    
                                    Spacer()
                                    
                                    Button(action: {
                                        showEditProfile = true
                                    }) {
                                        Image(systemName: "pencil.circle.fill")
                                            .font(.title2)
                                            .foregroundColor(.black)
                                    }
                                }
                                
                                HStack(spacing: 20) {
                                    VStack(spacing: 4) {
                                        Text("\(formatNumber(activityCount))")
                                            .font(.system(size: 16, weight: .bold))
                                        Text("Träningspass")
                                            .font(.caption2)
                                            .foregroundColor(.gray)
                                    }
                                    
                                    Button(action: {
                                        showFollowersList = true
                                    }) {
                                        VStack(spacing: 4) {
                                            Text("\(followersCount)")
                                                .font(.system(size: 16, weight: .bold))
                                                .foregroundColor(.black)
                                            Text("Följare")
                                                .font(.caption2)
                                                .foregroundColor(.gray)
                                        }
                                    }
                                    
                                    Button(action: {
                                        showFollowingList = true
                                    }) {
                                        VStack(spacing: 4) {
                                            Text("\(followingCount)")
                                                .font(.system(size: 16, weight: .bold))
                                                .foregroundColor(.black)
                                            Text("Följer")
                                                .font(.caption2)
                                                .foregroundColor(.gray)
                                        }
                                    }
                                    
                                    Spacer()
                                }
                                
                            }
                        }
                    }
                    .padding(20)
                    .background(Color(.systemGray6))
                    .cornerRadius(16)

                    // MARK: - XP Box
                    HStack(spacing: 16) {
                        // Logo/Icon
                        Image("23")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 56, height: 56)
                            .cornerRadius(10)
                        
                        // XP Text
                        VStack(alignment: .leading, spacing: 4) {
                            Text("\(formatNumber(authViewModel.currentUser?.currentXP ?? 0)) Poäng")
                                .font(.system(size: 18, weight: .bold))
                        }
                        
                        Spacer()
                    }
                    .padding(16)
                    .background(Color.white)
                    .cornerRadius(12)
                    .border(Color.black, width: 2)
                    
                    // MARK: - Action Buttons (3x1)
                    HStack(spacing: 12) {
                        ActionButton(
                            icon: "cart.fill",
                            label: "Mina köp",
                            action: {
                                showMyPurchases = true
                            }
                        )
                        
                        ActionButton(
                            icon: "chart.bar.fill",
                            label: "Statistik",
                            action: {
                                showStatistics = true
                            }
                        )
                        
                        ActionButton(
                            icon: "person.badge.plus.fill",
                            label: "Hitta vänner",
                            action: {
                                showFindFriends = true
                            }
                        )
                    }
                    
                    // MARK: - Become Golf Trainer Button
                    Button {
                        showTrainerOnboarding = true
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "figure.golf")
                                .font(.title2)
                                .foregroundColor(.white)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Bli golftränare")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(.white)
                                
                                Text("Erbjud lektioner och tjäna pengar")
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.8))
                            }
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.white.opacity(0.7))
                        }
                        .padding(16)
                        .background(
                            LinearGradient(
                                colors: [Color.green, Color.green.opacity(0.8)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(12)
                    }
                    
                    Divider()
                        .background(Color(.systemGray4))
                    
                    // MARK: - Weekly Activity Chart
                    WeeklyActivityChart(weeklyData: weeklyActivityData)
                        .padding(.horizontal, 16)
                    
                    if isUsingCachedWeeklyData {
                        cachedStatsIndicator
                    }
                    
                    Divider()
                        .background(Color(.systemGray4))
                    
                    // MARK: - Trophy Case Section
                    TrophyCaseView(activityCount: activityCount, personalBests: personalBestInfo)
                        .equatable()
                    
                    Divider()
                        .background(Color(.systemGray4))
                    
                    // MARK: - Aktiviteter Section
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Aktiviteter")
                                .font(.system(size: 18, weight: .bold))
                            Spacer()
                        }
                        
                        if let userId = authViewModel.currentUser?.id {
                            UserActivitiesView(userId: userId) { post in
                                selectedPost = post
                            }
                        }
                    }
                    
                    Spacer()
                }
                .padding(16)
            }
            .navigationTitle("Inställningar")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(item: $selectedPost) { post in
                WorkoutDetailView(post: post)
            }
            .sheet(isPresented: $showImagePicker) {
                ImagePicker(image: $profileImage, authViewModel: authViewModel)
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
            .sheet(isPresented: $showPaywall) {
                PresentPaywallView()
            }
            .sheet(isPresented: $showStatistics) {
                StatisticsView()
            }
            .sheet(isPresented: $showMyPurchases) {
                MyPurchasesView()
            }
            .sheet(isPresented: $showFindFriends) {
                FindFriendsView()
            }
            .sheet(isPresented: $showFollowersList) {
                if let userId = authViewModel.currentUser?.id {
                    FollowListView(userId: userId, listType: .followers)
                }
            }
            .sheet(isPresented: $showFollowingList) {
                if let userId = authViewModel.currentUser?.id {
                    FollowListView(userId: userId, listType: .following)
                }
            }
            .sheet(isPresented: $showEditProfile) {
                EditProfileView()
            }
            .sheet(isPresented: $showTrainerOnboarding) {
                TrainerOnboardingView()
            }
            .onAppear {
                updatePersonalBestInfo()
                loadProfileStats()
                loadWeeklyActivityData()
            }
            .onReceive(NotificationCenter.default.publisher(for: .profileStatsUpdated)) { _ in
                loadProfileStats()
            }
            .onAppear {
                // Lyssna på profilbild uppdateringar
                profileObserver = NotificationCenter.default.addObserver(
                    forName: .profileImageUpdated,
                    object: nil,
                    queue: .main
                ) { notification in
                    if let newImageUrl = notification.object as? String {
                        print("🔄 Profile image updated in UI: \(newImageUrl)")
                        // Trigga UI-uppdatering genom att uppdatera authViewModel
                        authViewModel.objectWillChange.send()
                    }
                }
            }
            .onDisappear {
                if let observer = profileObserver {
                    NotificationCenter.default.removeObserver(observer)
                    profileObserver = nil
                }
            }
        }
    }
    
    private var cachedStatsIndicator: some View {
        HStack(spacing: 6) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 12, weight: .semibold))
            Text("Visar sparad statistik")
                .font(.system(size: 12, weight: .medium))
        }
        .foregroundColor(.black)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color.black.opacity(0.05))
        .cornerRadius(12)
    }
    
    private func loadProfileStats() {
        guard let currentUserId = authViewModel.currentUser?.id else { return }
        
        Task {
            do {
                let followers = try await SocialService.shared.getFollowers(userId: currentUserId)
                let following = try await SocialService.shared.getFollowing(userId: currentUserId)
                
                await MainActor.run {
                    self.followersCount = followers.count
                    self.followingCount = following.count
                }
            } catch {
                print("❌ Error loading profile stats: \(error)")
            }
        }
    }
    
    private func loadWeeklyActivityData(forceReload: Bool = false) {
        guard let userId = authViewModel.currentUser?.id else { return }
        
        let pbFive = authViewModel.currentUser?.pb5kmMinutes
        let pbTenCombined: Int? = {
            guard let minutes = authViewModel.currentUser?.pb10kmMinutes else { return nil }
            let hours = authViewModel.currentUser?.pb10kmHours ?? 0
            return hours * 60 + minutes
        }()
        
        if !forceReload,
           let cachedWorkouts = cacheManager.getCachedUserWorkouts(userId: userId, allowExpired: true),
           !cachedWorkouts.isEmpty {
            Task.detached(priority: .utility) {
                let metrics = ProfileView.computeMetrics(from: cachedWorkouts)
                await MainActor.run {
                    self.applyProfileMetrics(metrics,
                                             pbFive: pbFive,
                                             pbTen: pbTenCombined,
                                             usingCache: true)
                }
            }
        }
        
        if !forceReload,
           let lastFetch = lastActivityFetch,
           Date().timeIntervalSince(lastFetch) < weeklyDataThrottle,
           !weeklyActivityData.isEmpty {
            return
        }
        
        Task(priority: .userInitiated) {
            do {
                let activities = try await WorkoutService.shared.getUserWorkoutPosts(userId: userId)
                cacheManager.saveUserWorkouts(activities, userId: userId)
                
                let metrics = await Task.detached(priority: .utility) {
                    ProfileView.computeMetrics(from: activities)
                }.value
                
                await MainActor.run {
                    self.lastActivityFetch = Date()
                    self.applyProfileMetrics(metrics,
                                             pbFive: pbFive,
                                             pbTen: pbTenCombined,
                                             usingCache: false)
                }
            } catch {
                if Task.isCancelled { return }
                print("❌ Error loading weekly activity data: \(error)")
            }
        }
    }
    
    @MainActor
    private func applyProfileMetrics(_ metrics: ProfileMetrics,
                                     pbFive: Int?,
                                     pbTen: Int?,
                                     usingCache: Bool) {
        weeklyActivityData = metrics.weeklyData
        activityCount = metrics.activityCount
        personalBestInfo = PersonalBestInfo(
            fiveKmMinutes: pbFive,
            tenKmMinutes: pbTen,
            benchMaxKg: metrics.benchMaxKg
        )
        isUsingCachedWeeklyData = usingCache
    }
}

private struct ProfileMetrics {
    let weeklyData: [WeeklyActivityData]
    let activityCount: Int
    let benchMaxKg: Double?
}

private extension ProfileView {
    static func computeMetrics(from activities: [WorkoutPost]) -> ProfileMetrics {
        let calendar = Calendar.current
        let now = Date()
        let currentWeekStart = calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? now
        let isoFormatter = ISO8601DateFormatter()
        var activitiesWithDates: [(WorkoutPost, Date)] = []
        activitiesWithDates.reserveCapacity(activities.count)
        var benchBestKg: Double = 0.0
        
        for activity in activities {
            guard let date = isoFormatter.date(from: activity.createdAt) else { continue }
            activitiesWithDates.append((activity, date))
            
            if activity.activityType.lowercased().contains("gym"),
               let exercises = activity.exercises {
                for exercise in exercises {
                    let normalizedName = exercise.name.lowercased()
                    if normalizedName.contains("bänk") || normalizedName.contains("bench"),
                       let maxKg = exercise.kg.max() {
                        benchBestKg = max(benchBestKg, maxKg)
                    }
                }
            }
        }
        
        struct WeekKey: Hashable {
            let year: Int
            let week: Int
        }
        
        var buckets: [WeekKey: [WorkoutPost]] = [:]
        for (activity, date) in activitiesWithDates {
            let comps = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
            guard let year = comps.yearForWeekOfYear,
                  let week = comps.weekOfYear else { continue }
            let key = WeekKey(year: year, week: week)
            buckets[key, default: []].append(activity)
        }
        
        let labelFormatter = DateFormatter()
        labelFormatter.locale = Locale(identifier: "sv_SE")
        labelFormatter.dateFormat = "MMM d"
        
        var weeks: [WeeklyActivityData] = []
        for offset in stride(from: 9, through: 0, by: -1) {
            guard let weekStart = calendar.date(byAdding: .weekOfYear, value: -offset, to: currentWeekStart),
                  let weekEnd = calendar.date(byAdding: .day, value: 7, to: weekStart) else { continue }
            
            let comps = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: weekStart)
            guard let year = comps.yearForWeekOfYear,
                  let week = comps.weekOfYear else { continue }
            
            let key = WeekKey(year: year, week: week)
            let weeklyActivities = buckets[key] ?? []
            
            var runDistance = 0.0, runTime = 0.0, runElevation = 0.0
            var golfDistance = 0.0, golfTime = 0.0, golfElevation = 0.0
            var climbingDistance = 0.0, climbingTime = 0.0, climbingElevation = 0.0
            var skiingDistance = 0.0, skiingTime = 0.0, skiingElevation = 0.0
            var gymVolume = 0.0, gymTime = 0.0
            
            for activity in weeklyActivities {
                let distance = activity.distance ?? 0
                let time = Double(activity.duration ?? 0)
                let elevation = activity.elevationGain ?? 0
                let type = activity.activityType.lowercased()
                
                switch type {
                case "run", "running", "löpning":
                    runDistance += distance
                    runTime += time
                    runElevation += elevation
                case "golf":
                    golfDistance += distance
                    golfTime += time
                    golfElevation += elevation
                case "climbing", "klättring", "bergsklättring":
                    climbingDistance += distance
                    climbingTime += time
                    climbingElevation += elevation
                case "skiing", "skidåkning":
                    skiingDistance += distance
                    skiingTime += time
                    skiingElevation += elevation
                case "gym", "gympass":
                    gymTime += time
                    if let exercises = activity.exercises {
                        for exercise in exercises {
                            let volume = zip(exercise.kg, exercise.reps).reduce(0.0) { partial, pair in
                                partial + (pair.0 * Double(pair.1))
                            }
                            gymVolume += volume
                        }
                    }
                default:
                    runDistance += distance
                    runTime += time
                    runElevation += elevation
                }
            }
            
            weeks.append(
                WeeklyActivityData(
                    weekLabel: labelFormatter.string(from: weekStart),
                    runDistance: runDistance,
                    runTime: runTime,
                    runElevation: runElevation,
                    golfDistance: golfDistance,
                    golfTime: golfTime,
                    golfElevation: golfElevation,
                    climbingDistance: climbingDistance,
                    climbingTime: climbingTime,
                    climbingElevation: climbingElevation,
                    skiingDistance: skiingDistance,
                    skiingTime: skiingTime,
                    skiingElevation: skiingElevation,
                    gymVolume: gymVolume,
                    gymTime: gymTime,
                    startDate: weekStart,
                    endDate: weekEnd
                )
            )
        }
        
        let benchValue = benchBestKg > 0 ? benchBestKg : nil
        return ProfileMetrics(
            weeklyData: weeks,
            activityCount: activities.count,
            benchMaxKg: benchValue
        )
    }
}

struct UserActivitiesView: View {
    let userId: String
    var onSelectPost: (SocialWorkoutPost) -> Void
    
    @StateObject private var postsViewModel = SocialViewModel()
    
    var body: some View {
        VStack(spacing: 12) {
            if postsViewModel.isLoading && postsViewModel.posts.isEmpty {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Laddar aktiviteter...")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            } else if postsViewModel.posts.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "figure.run")
                        .font(.title2)
                        .foregroundColor(.gray)
                    Text("Inga aktiviteter än")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            } else {
                LazyVStack(spacing: 0) {
                    ForEach(postsViewModel.posts) { post in
                        SocialPostCard(
                            post: post,
                            onOpenDetail: { onSelectPost($0) },
                            viewModel: postsViewModel
                        )
                        Divider()
                            .background(Color(.systemGray5))
                    }
                }
            }
        }
        .task {
            await postsViewModel.loadPostsForUser(userId: userId, viewerId: userId)
        }
        .refreshable {
            await postsViewModel.refreshPostsForUser(userId: userId, viewerId: userId)
        }
    }
}

struct ActionButton: View {
    let icon: String
    let label: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(.black)
                
                Text(label)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.black)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(16)
            .background(Color(.systemGray6))
            .cornerRadius(10)
        }
    }
}

struct ImagePicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    let authViewModel: AuthViewModel
    @Environment(\.presentationMode) var presentationMode
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = .photoLibrary
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePicker
        
        init(_ parent: ImagePicker) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let uiImage = info[.originalImage] as? UIImage {
                parent.image = uiImage
                // Spara profilbilden via AuthViewModel
                parent.authViewModel.updateProfileImage(image: uiImage)
                
                // Visa en bekräftelse att bilden sparas
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    print("🔄 Profile image update initiated")
                }
            }
            parent.presentationMode.wrappedValue.dismiss()
        }
    }
}

#Preview {
    ProfileView()
        .environmentObject(AuthViewModel())
}

// MARK: - Helper Functions
func formatNumber(_ number: Int) -> String {
    let formatter = NumberFormatter()
    formatter.numberStyle = .decimal
    formatter.groupingSeparator = ","
    return formatter.string(from: NSNumber(value: number)) ?? "\(number)"
}
