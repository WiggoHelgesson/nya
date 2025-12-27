import SwiftUI

struct UserProfileView: View {
    let userId: String
    
    @State private var username: String = ""
    @State private var avatarUrl: String? = nil
    @State private var followersCount: Int = 0
    @State private var followingCount: Int = 0
    @State private var workoutsCount: Int = 0
    @State private var isLoading: Bool = true
    @State private var isFollowingUser: Bool = false
    @State private var followToggleInProgress: Bool = false
    @State private var isPro: Bool = false
    @State private var showPersonalRecords: Bool = false
    @StateObject private var profilePostsViewModel = SocialViewModel()
    @State private var selectedPost: SocialWorkoutPost?
    @State private var selectedLivePhotoPost: SocialWorkoutPost?
    @State private var weeklyHours: Double = 0
    @State private var dailyActivityData: [DailyActivity] = []
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var authViewModel: AuthViewModel
    
    // Filter posts with Up&Down Live photos
    private var livePhotoPosts: [SocialWorkoutPost] {
        profilePostsViewModel.posts.filter { post in
            if let userImageUrl = post.userImageUrl, !userImageUrl.isEmpty {
                return userImageUrl.contains("live_")
            }
            return false
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Fixed Header Section
            ScrollView {
                VStack(spacing: 0) {
                    // MARK: - Up&Down Live Gallery Slider (only if has live photos)
                    if !livePhotoPosts.isEmpty {
                        PublicProfileLiveGallery(
                            posts: livePhotoPosts,
                            selectedPost: $selectedLivePhotoPost
                        )
                    }
                    
                    // Header
                    VStack(spacing: 12) {
                        HStack(spacing: 12) {
                            ProfileAvatarView(path: avatarUrl ?? "", size: 72)
                                .overlay(Circle().stroke(Color(.systemGray5), lineWidth: 1))
                            
                            VStack(alignment: .leading, spacing: 6) {
                                HStack(spacing: 6) {
                                    Text(username.isEmpty ? "Användare" : username)
                                        .font(.system(size: 20, weight: .semibold))
                                        .foregroundColor(.primary)
                                    
                                    if isPro {
                                        Image(systemName: "checkmark.seal.fill")
                                            .font(.system(size: 16))
                                            .foregroundColor(.blue)
                                    }
                                    
                                    Spacer()
                                }
                                
                                HStack(spacing: 0) {
                                    VStack(spacing: 2) {
                                        Text("\(workoutsCount)")
                                            .font(.system(size: 16, weight: .bold))
                                        Text("Pass")
                                            .font(.system(size: 11))
                                            .foregroundColor(.gray)
                                    }
                                    .frame(maxWidth: .infinity)
                                    
                                    VStack(spacing: 2) {
                                        Text("\(followersCount)")
                                            .font(.system(size: 16, weight: .bold))
                                        Text("Följare")
                                            .font(.system(size: 11))
                                            .foregroundColor(.gray)
                                    }
                                    .frame(maxWidth: .infinity)
                                    
                                    VStack(spacing: 2) {
                                        Text("\(followingCount)")
                                            .font(.system(size: 16, weight: .bold))
                                        Text("Följer")
                                            .font(.system(size: 11))
                                            .foregroundColor(.gray)
                                    }
                                    .frame(maxWidth: .infinity)
                                }
                                .frame(maxWidth: .infinity)
                                
                                // Personal Records button
                                HStack {
                                    Spacer()
                                    Button(action: {
                                        showPersonalRecords = true
                                    }) {
                                        HStack(spacing: 4) {
                                            Image(systemName: "trophy.fill")
                                                .font(.system(size: 12))
                                            Text("Personliga rekord")
                                                .font(.system(size: 12, weight: .medium))
                                        }
                                        .foregroundColor(.primary)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(Color(.systemGray6))
                                        .cornerRadius(8)
                                    }
                                    Spacer()
                                }
                                .padding(.top, 4)
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                        
                        // Follow button on its own row
                        if let currentUser = authViewModel.currentUser, currentUser.id != userId {
                            Button(action: toggleFollow) {
                                HStack(spacing: 6) {
                                    if followToggleInProgress {
                                        ProgressView()
                                            .scaleEffect(0.8)
                                            .tint(.white)
                                    }
                                    Text(isFollowingUser ? "Följer" : "Följ")
                                        .font(.system(size: 14, weight: .semibold))
                                }
                                .frame(maxWidth: .infinity)
                                .frame(height: 40)
                                .background(isFollowingUser ? Color(.systemGray5) : Color.black)
                                .foregroundColor(isFollowingUser ? .black : .white)
                                .cornerRadius(10)
                            }
                            .disabled(followToggleInProgress)
                            .padding(.horizontal, 16)
                        }
                    }
                    .padding(.bottom, 12)
                    .background(Color(.secondarySystemBackground))
                    
                    // MARK: - Weekly Activity Chart
                    WeeklyHoursChart(
                        weeklyHours: weeklyHours,
                        dailyData: dailyActivityData
                    )
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    
                    Divider()
                
                    // Posts list
                    if isLoading {
                        VStack(spacing: 16) {
                            ProgressView().tint(AppColors.brandBlue)
                            Text("Laddar profil...")
                                .font(.system(size: 14))
                                .foregroundColor(.gray)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 40)
                    } else {
                        if profilePostsViewModel.isLoading && profilePostsViewModel.posts.isEmpty {
                            VStack(spacing: 12) {
                                ProgressView().tint(AppColors.brandBlue)
                                Text("Hämtar inlägg...")
                                    .font(.system(size: 14))
                                    .foregroundColor(.gray)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.top, 40)
                        } else if profilePostsViewModel.posts.isEmpty {
                            VStack(spacing: 12) {
                                Image(systemName: "figure.run")
                                    .font(.system(size: 48))
                                    .foregroundColor(.gray)
                                Text("Inga inlägg än")
                                    .font(.headline)
                                Text("När användaren sparar pass visas de här.")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                            .padding(.top, 40)
                        } else {
                            LazyVStack(spacing: 0) {
                                ForEach(profilePostsViewModel.posts) { post in
                                    SocialPostCard(
                                        post: post,
                                        onOpenDetail: { tappedPost in selectedPost = tappedPost },
                                        onLikeChanged: { postId, isLiked, count in
                                            profilePostsViewModel.updatePostLikeStatus(postId: postId, isLiked: isLiked, likeCount: count)
                                        },
                                        onCommentCountChanged: { postId, count in
                                            profilePostsViewModel.updatePostCommentCount(postId: postId, commentCount: count)
                                        },
                                        onPostDeleted: { postId in
                                            profilePostsViewModel.removePost(postId: postId)
                                        }
                                    )
                                    Divider()
                                        .background(Color(.systemGray5))
                                }
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Profil")
        .navigationBarTitleDisplayMode(.inline)
        .task { await loadData() }
        .navigationDestination(item: $selectedPost) { post in
            WorkoutDetailView(post: post)
        }
        .sheet(isPresented: $showPersonalRecords) {
            PersonalRecordsView(userId: userId, username: username)
        }
        .sheet(item: $selectedLivePhotoPost) { post in
            LivePhotoDetailSheet(post: post)
        }
        .onAppear { NavigationDepthTracker.shared.setAtRoot(false) }
        .onDisappear { NavigationDepthTracker.shared.setAtRoot(true) }
    }
    
    private func loadData() async {
        isLoading = true
        
        // Load all data in parallel
        async let profileTask = ProfileService.shared.fetchUserProfile(userId: userId)
        async let followersIdsTask = SocialService.shared.getFollowers(userId: userId)
        async let followingIdsTask = SocialService.shared.getFollowing(userId: userId)
        
        // Wait for all results
        let profile = try? await profileTask
        let followersIds = (try? await followersIdsTask) ?? []
        let followingIds = (try? await followingIdsTask) ?? []
        
        // Update UI once with all data
        await MainActor.run {
            if let profile = profile {
                self.username = profile.name
                self.avatarUrl = profile.avatarUrl
                self.isPro = profile.isProMember
            }
            
            self.followersCount = followersIds.count
            self.followingCount = followingIds.count
            self.isLoading = false
            
            if let currentUserId = authViewModel.currentUser?.id, currentUserId != userId {
                self.isFollowingUser = followersIds.contains(currentUserId)
            } else {
                self.isFollowingUser = false
            }
        }
        
        if let viewerId = authViewModel.currentUser?.id {
            await profilePostsViewModel.loadPostsForUser(userId: userId, viewerId: viewerId)
        } else {
            await profilePostsViewModel.loadPostsForUser(userId: userId, viewerId: userId)
        }
        
        // Calculate weekly hours and daily data from posts
        await MainActor.run {
            workoutsCount = profilePostsViewModel.posts.count
            calculateWeeklyActivity()
        }
    }
    
    private func calculateWeeklyActivity() {
        let calendar = Calendar.current
        let now = Date()
        
        // Date formatter for parsing ISO8601 strings
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        // Fallback formatter without fractional seconds
        let isoFormatterNoFrac = ISO8601DateFormatter()
        isoFormatterNoFrac.formatOptions = [.withInternetDateTime]
        
        func parseDate(_ dateString: String) -> Date? {
            return isoFormatter.date(from: dateString) ?? isoFormatterNoFrac.date(from: dateString)
        }
        
        // Get start and end of current week
        let startOfWeek = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)) ?? now
        
        // Calculate last 3 months of data for the chart
        let threeMonthsAgo = calendar.date(byAdding: .month, value: -3, to: now) ?? now
        
        // Filter posts from this week for weekly hours
        let thisWeekPosts = profilePostsViewModel.posts.filter { post in
            guard let createdAt = parseDate(post.createdAt) else { return false }
            return createdAt >= startOfWeek
        }
        
        // Sum up duration in hours
        let totalSeconds = thisWeekPosts.reduce(0) { sum, post in
            sum + (post.duration ?? 0)
        }
        weeklyHours = Double(totalSeconds) / 3600.0
        
        // Group posts by date for the chart (last 3 months)
        var dailyTotals: [Date: Int] = [:]
        
        for post in profilePostsViewModel.posts {
            guard let createdAt = parseDate(post.createdAt), createdAt >= threeMonthsAgo else { continue }
            let dayStart = calendar.startOfDay(for: createdAt)
            let duration = post.duration ?? 0
            dailyTotals[dayStart, default: 0] += duration
        }
        
        // Create daily activity data for chart
        var data: [DailyActivity] = []
        var currentDate = threeMonthsAgo
        while currentDate <= now {
            let dayStart = calendar.startOfDay(for: currentDate)
            let seconds = dailyTotals[dayStart] ?? 0
            data.append(DailyActivity(date: dayStart, seconds: seconds))
            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? now
        }
        
        dailyActivityData = data
    }
    
    private func toggleFollow() {
        guard let currentUser = authViewModel.currentUser else { return }
        guard !followToggleInProgress else { return }
        followToggleInProgress = true
        Task {
            do {
                if isFollowingUser {
                    try await SocialService.shared.unfollowUser(followerId: currentUser.id, followingId: userId)
                    await MainActor.run {
                        self.isFollowingUser = false
                        self.followersCount = max(0, self.followersCount - 1)
                    }
                } else {
                    try await SocialService.shared.followUser(followerId: currentUser.id, followingId: userId)
                    await MainActor.run {
                        self.isFollowingUser = true
                        self.followersCount += 1
                    }
                }
            } catch {
                print("❌ Error toggling follow: \(error)")
            }
            await MainActor.run {
                self.followToggleInProgress = false
            }
        }
    }
}

// MARK: - Supporting Types

struct DailyActivity: Identifiable {
    let id = UUID()
    let date: Date
    let seconds: Int
    
    var hours: Double {
        Double(seconds) / 3600.0
    }
}

// MARK: - Weekly Hours Chart

struct WeeklyHoursChart: View {
    let weeklyHours: Double
    let dailyData: [DailyActivity]
    
    private var hoursText: String {
        if weeklyHours >= 1 {
            return String(format: "%.0f", weeklyHours)
        } else {
            let minutes = Int(weeklyHours * 60)
            return minutes > 0 ? "\(minutes)" : "0"
        }
    }
    
    private var hoursUnit: String {
        if weeklyHours >= 1 {
            return weeklyHours == 1 ? "timme" : "timmar"
        }
        return "min"
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with bold hours
            HStack(spacing: 4) {
                Text(hoursText)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.primary)
                Text(hoursUnit)
                    .font(.system(size: 20, weight: .regular))
                    .foregroundColor(.primary)
                Text("denna vecka")
                    .font(.system(size: 20, weight: .regular))
                    .foregroundColor(.primary)
            }
            
            // Activity Chart
            if !dailyData.isEmpty {
                ActivityBarChart(data: dailyData)
                    .frame(height: 100)
            }
        }
        .padding(16)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
}

// MARK: - Activity Bar Chart (3 months view)

struct ActivityBarChart: View {
    let data: [DailyActivity]
    
    private var maxHours: Double {
        max(data.map { $0.hours }.max() ?? 1, 1)
    }
    
    private var dateLabels: [String] {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        
        // Show labels for first day of each month
        var labels: [String] = []
        var lastMonth = -1
        
        for activity in data {
            let month = Calendar.current.component(.month, from: activity.date)
            if month != lastMonth {
                labels.append(formatter.string(from: activity.date))
                lastMonth = month
            }
        }
        
        return labels
    }
    
    var body: some View {
        VStack(spacing: 4) {
            // Y-axis labels and chart
            HStack(alignment: .bottom, spacing: 0) {
                // Y-axis
                VStack(alignment: .trailing, spacing: 0) {
                    Text(formatHours(maxHours))
                        .font(.system(size: 10))
                        .foregroundColor(.gray)
                    Spacer()
                    Text("0 hrs")
                        .font(.system(size: 10))
                        .foregroundColor(.gray)
                }
                .frame(width: 40)
                .padding(.bottom, 16)
                
                // Chart bars
                GeometryReader { geometry in
                    let barWidth = max(1, (geometry.size.width / CGFloat(data.count)) - 0.5)
                    
                    HStack(alignment: .bottom, spacing: 0.5) {
                        ForEach(data) { activity in
                            let heightRatio = maxHours > 0 ? CGFloat(activity.hours / maxHours) : 0
                            
                            Rectangle()
                                .fill(activity.hours > 0 ? Color.blue : Color.clear)
                                .frame(width: barWidth, height: max(0, (geometry.size.height - 16) * heightRatio))
                        }
                    }
                }
            }
            
            // X-axis labels
            HStack {
                ForEach(dateLabels, id: \.self) { label in
                    Text(label)
                        .font(.system(size: 10))
                        .foregroundColor(.gray)
                    if label != dateLabels.last {
                        Spacer()
                    }
                }
            }
            .padding(.leading, 40)
        }
    }
    
    private func formatHours(_ hours: Double) -> String {
        if hours >= 1 {
            return "\(Int(hours)) hrs"
        } else {
            return "\(Int(hours * 60)) min"
        }
    }
}

// MARK: - Public Profile Live Gallery

struct PublicProfileLiveGallery: View {
    let posts: [SocialWorkoutPost]
    @Binding var selectedPost: SocialWorkoutPost?
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(posts) { post in
                    if let userImageUrl = post.userImageUrl {
                        Button {
                            selectedPost = post
                        } label: {
                            LivePhotoGridImage(path: userImageUrl)
                                .frame(width: 100, height: 100)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(Color(.systemGray6))
    }
}

// MARK: - Live Photo Detail Sheet

struct LivePhotoDetailSheet: View {
    let post: SocialWorkoutPost
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                
                if let userImageUrl = post.userImageUrl {
                    LocalAsyncImage(path: userImageUrl)
                        .scaledToFit()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.white.opacity(0.8))
                    }
                }
            }
        }
    }
}

