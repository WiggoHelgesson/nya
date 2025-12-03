import SwiftUI
import Combine
import Supabase

struct ActivitiesView: View {
    @StateObject private var userPostsViewModel = SocialViewModel()
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var task: Task<Void, Never>?
    @State private var selectedPost: SocialWorkoutPost?
    
    // Alla belöningar i önskad ordning (PUMPLABS först, ZEN ENERGY som andra)
    let allRewards = [
        RewardCard(
            id: 1,
            brandName: "PUMPLABS",
            discount: "10% rabatt",
            points: "200 poäng",
            imageName: "12",
            category: "Gym",
            isBookmarked: false
        ),
        RewardCard(
            id: 2,
            brandName: "ZEN ENERGY",
            discount: "10% rabatt",
            points: "200 poäng",
            imageName: "13",
            category: "Gym",
            isBookmarked: false
        ),
        RewardCard(
            id: 3,
            brandName: "PLIKTGOLF",
            discount: "10% rabatt",
            points: "200 poäng",
            imageName: "4",
            category: "Golf",
            isBookmarked: false
        ),
        RewardCard(
            id: 4,
            brandName: "PEGMATE",
            discount: "5% rabatt",
            points: "200 poäng",
            imageName: "5",
            category: "Golf",
            isBookmarked: false
        ),
        RewardCard(
            id: 5,
            brandName: "LONEGOLF",
            discount: "10% rabatt",
            points: "200 poäng",
            imageName: "6",
            category: "Golf",
            isBookmarked: false
        ),
        RewardCard(
            id: 6,
            brandName: "WINWIZE",
            discount: "25% rabatt",
            points: "200 poäng",
            imageName: "7",
            category: "Golf",
            isBookmarked: false
        ),
        RewardCard(
            id: 7,
            brandName: "SCANDIGOLF",
            discount: "15% rabatt",
            points: "200 poäng",
            imageName: "8",
            category: "Golf",
            isBookmarked: false
        ),
        RewardCard(
            id: 8,
            brandName: "Exotic Golf",
            discount: "10% rabatt",
            points: "200 poäng",
            imageName: "9",
            category: "Golf",
            isBookmarked: false
        ),
        RewardCard(
            id: 9,
            brandName: "HAPPYALBA",
            discount: "10% rabatt",
            points: "200 poäng",
            imageName: "10",
            category: "Golf",
            isBookmarked: false
        ),
        RewardCard(
            id: 10,
            brandName: "RETROGOLF",
            discount: "10% rabatt",
            points: "200 poäng",
            imageName: "11",
            category: "Golf",
            isBookmarked: false
        ),
        RewardCard(
            id: 24,
            brandName: "CLYRO",
            discount: "20% rabatt",
            points: "200 poäng",
            imageName: "39",
            category: "Gym",
            isBookmarked: false
        ),
        RewardCard(
            id: 25,
            brandName: "CLYRO",
            discount: "20% rabatt",
            points: "200 poäng",
            imageName: "39",
            category: "Löpning",
            isBookmarked: false
        ),
        RewardCard(
            id: 26,
            brandName: "Fjällsyn UF",
            discount: "15% rabatt",
            points: "200 poäng",
            imageName: "38",
            category: "Skidåkning",
            isBookmarked: false
        ),
        RewardCard(
            id: 27,
            brandName: "Powerwell",
            discount: "15% rabatt",
            points: "200 poäng",
            imageName: "40",
            category: "Gym",
            isBookmarked: false
        )
    ]
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemBackground).ignoresSafeArea()
                
                if userPostsViewModel.isLoading && userPostsViewModel.posts.isEmpty {
                    VStack(spacing: 16) {
                        ProgressView()
                            .tint(AppColors.brandBlue)
                        Text("Hämtar dina inlägg...")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                } else if userPostsViewModel.posts.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "figure.run")
                            .font(.system(size: 48))
                            .foregroundColor(.gray)
                        Text("Inga träningspass än")
                            .font(.headline)
                        Text("Starta ett pass för att se det här")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                } else {
                    ScrollView {
                        VStack(spacing: 24) {
                            // MARK: - Alla belöningar sliderbar
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Alla belöningar")
                                    .font(.headline)
                                    .foregroundColor(.black)
                                    .padding(.horizontal, 16)
                                
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 12) {
                                        ForEach(allRewards, id: \.id) { reward in
                                            AllRewardsCard(reward: reward)
                                        }
                                    }
                                    .padding(.horizontal, 16)
                                }
                            }
                            
                            // MARK: - Aktiviteter
                            LazyVStack(spacing: 0) {
                                ForEach(userPostsViewModel.posts) { post in
                                    SocialPostCard(
                                        post: post,
                                        onOpenDetail: { tappedPost in selectedPost = tappedPost },
                                        viewModel: userPostsViewModel
                                    )
                                    Divider()
                                        .background(Color(.systemGray5))
                                }
                            }
                        }
                        .padding(.vertical, 16)
                    }
                }
            }
            .navigationTitle("Aktiviteter")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(item: $selectedPost) { post in
                WorkoutDetailView(post: post)
            }
            .task {
                // Cancel any previous task
                task?.cancel()
                
                guard let userId = authViewModel.currentUser?.id else { return }
                
                // Create new task
                task = Task {
                    await userPostsViewModel.loadPostsForUser(userId: userId, viewerId: userId)
                }
            }
            .onDisappear {
                task?.cancel()
            }
            .refreshable {
                if let userId = authViewModel.currentUser?.id {
                    await userPostsViewModel.refreshPostsForUser(userId: userId, viewerId: userId)
                }
            }
        }
    }
}

struct WorkoutPostCard: View {
    let post: WorkoutPost
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Content header ABOVE image
            VStack(alignment: .leading, spacing: 12) {
                // Title
                Text(post.title)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.black)
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                
                if let description = trimmedDescription {
                    Text(description)
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                        .padding(.horizontal, 16)
                }
                
                // Stats row
                HStack(spacing: 0) {
                    if post.activityType == "Gympass" {
                        if let duration = post.duration {
                            statColumn(title: "Tid", value: formatDuration(duration))
                        }
                        if let volume = gymVolumeText {
                            if post.duration != nil {
                                Divider()
                                    .frame(height: 40)
                            }
                            statColumn(title: "Volym", value: volume)
                        }
                    } else {
                        if let distance = post.distance {
                            statColumn(title: "Distans", value: String(format: "%.2f km", distance))
                        }
                        
                        if let duration = post.duration {
                            if post.distance != nil {
                                Divider()
                                    .frame(height: 40)
                            }
                            statColumn(title: "Tid", value: formatDuration(duration))
                        }
                        // Show elevation for skiing and hiking
                        if (post.activityType == "Skidåkning" || post.activityType == "Bestiga berg"),
                           let elevationGain = post.elevationGain, elevationGain > 0 {
                            if post.distance != nil || post.duration != nil {
                                Divider()
                                    .frame(height: 40)
                            }
                            statColumn(title: "Höjdmeter", value: String(format: "%.0f m", elevationGain))
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
            }
            
            // Show exercises list for Gympass, otherwise show swipeable images
            if post.activityType == "Gympass", let exercises = post.exercises, !exercises.isEmpty {
                GymExercisesListView(exercises: exercises, userImage: post.userImageUrl)
            } else {
                // Swipeable images (route and user image)
                SwipeableImageView(routeImage: post.imageUrl, userImage: post.userImageUrl)
            }
            
            // Like, Comment, Share buttons - large, evenly spaced
            HStack(spacing: 0) {
                Button(action: {}) {
                    Image(systemName: "heart")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.gray)
                }
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
                
                Button(action: {}) {
                    Image(systemName: "bubble.right")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.gray)
                }
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
                
                Button(action: {}) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.gray)
                }
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 14)
        }
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 4)
    }
    
    private func statColumn(title: String, value: String) -> some View {
        VStack(spacing: 6) {
            Text(title.uppercased())
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.gray)
            Text(value)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.black)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
    }
    
    private var gymVolumeText: String? {
        guard post.activityType == "Gympass", let exercises = post.exercises else { return nil }
        let total = totalVolume(for: exercises)
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        let text = formatter.string(from: NSNumber(value: Int(round(total)))) ?? "0"
        return "\(text) kg"
    }
    
    private func totalVolume(for exercises: [GymExercisePost]) -> Double {
        exercises.reduce(0) { result, exercise in
            let exerciseVolume = zip(exercise.kg, exercise.reps).reduce(0) { partial, pair in
                partial + (pair.0 * Double(pair.1))
            }
            return result + exerciseVolume
        }
    }
    
    private var trimmedDescription: String? {
        guard let text = post.description?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else {
            return nil
        }
        return text
    }
    
    func getActivityIcon(_ activity: String) -> String {
        switch activity {
        case "Löppass":
            return "figure.run"
        case "Golfrunda":
            return "flag.fill"
        case "Gympass":
            return "figure.strengthtraining.traditional"
        case "Bestiga berg":
            return "mountain.2.fill"
        case "Skidåkning":
            return "snowflake"
        default:
            return "figure.walk"
        }
    }
    
    func formatDate(_ dateString: String) -> String {
        let formatter = ISO8601DateFormatter()
        if let date = formatter.date(from: dateString) {
            let calendar = Calendar.current
            if calendar.isDateInToday(date) {
                let timeFormatter = DateFormatter()
                timeFormatter.timeStyle = .short
                return timeFormatter.string(from: date)
            }
            let dateFormatter = DateFormatter()
            dateFormatter.dateStyle = .short
            return dateFormatter.string(from: date)
        }
        return dateString
    }
    
    func formatDuration(_ seconds: Int) -> String {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        let secs = seconds % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        } else {
            return String(format: "%02d:%02d", minutes, secs)
        }
    }
}

class WorkoutPostsViewModel: ObservableObject {
    @Published var posts: [WorkoutPost] = []
    private let cacheManager = AppCacheManager.shared
    private let isoFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()
    private let isoFormatterNoMs: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()
    private func parseDate(_ s: String) -> Date {
        if let d = isoFormatter.date(from: s) { return d }
        if let d = isoFormatterNoMs.date(from: s) { return d }
        return Date.distantPast
    }
    private func sorted(_ items: [WorkoutPost]) -> [WorkoutPost] {
        items.sorted { lhs, rhs in
            parseDate(lhs.createdAt) > parseDate(rhs.createdAt)
        }
    }
    
    func fetchUserPosts(userId: String) {
        Task {
            do {
                let fetchedPosts = try await WorkoutService.shared.fetchUserWorkoutPosts(userId: userId)
                DispatchQueue.main.async {
                    self.posts = fetchedPosts
                }
            } catch {
                print("Error fetching user posts: \(error)")
            }
        }
    }
    
    func fetchUserPostsAsync(userId: String) async {
        // Show cached posts immediately if available
        if let cached = cacheManager.getCachedUserWorkouts(userId: userId, allowExpired: true) {
            await MainActor.run {
                self.posts = sorted(cached)
            }
        }
        do {
            let fetchedPosts = try await RetryHelper.shared.retry(maxRetries: 3, delay: 0.5) {
                return try await WorkoutService.shared.fetchUserWorkoutPosts(userId: userId)
            }
            let ordered = sorted(fetchedPosts)
            var shouldCache = false
            await MainActor.run {
                let hadPostsAlready = !self.posts.isEmpty
                if !ordered.isEmpty || !hadPostsAlready {
                    self.posts = ordered
                    shouldCache = true
                } else {
                    print("⚠️ Received empty workout list, keeping existing posts")
                }
            }
            if shouldCache {
                cacheManager.saveUserWorkouts(ordered, userId: userId)
            }
        } catch is CancellationError {
            print("⚠️ Fetch was cancelled")
        } catch {
            print("❌ Error fetching user posts after retries: \(error)")
            if let cached = cacheManager.getCachedUserWorkouts(userId: userId, allowExpired: true) {
                await MainActor.run {
                    if self.posts.isEmpty {
                        self.posts = sorted(cached)
                    }
                }
            }
        }
    }
    
    func refreshUserPosts(userId: String) async {
        do {
            // Use retry helper for better network resilience
            let fetchedPosts = try await RetryHelper.shared.retry(maxRetries: 3, delay: 0.5) {
                return try await WorkoutService.shared.fetchUserWorkoutPosts(userId: userId)
            }
            let ordered = sorted(fetchedPosts)
            var shouldCache = false
            await MainActor.run {
                let hadPostsAlready = !self.posts.isEmpty
                if !ordered.isEmpty || !hadPostsAlready {
                    self.posts = ordered
                    shouldCache = true
                } else {
                    print("⚠️ Refresh returned empty workout list, keeping existing posts")
                }
            }
            if shouldCache {
                cacheManager.saveUserWorkouts(ordered, userId: userId)
            }
        } catch {
            print("❌ Error refreshing user posts after retries: \(error)")
            if let cached = cacheManager.getCachedUserWorkouts(userId: userId, allowExpired: true) {
                await MainActor.run {
                    if self.posts.isEmpty {
                        self.posts = sorted(cached)
                    }
                }
            }
        }
    }
}


#Preview {
    ActivitiesView()
        .environmentObject(AuthViewModel())
}

