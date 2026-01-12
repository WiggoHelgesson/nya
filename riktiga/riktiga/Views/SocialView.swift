import SwiftUI
import Combine
import PhotosUI
import Supabase

// MARK: - Social Tab Selection
enum SocialTab: String, CaseIterable {
    case feed = "Flödet"
    case news = "Nyheter"
}

struct SocialView: View {
    @StateObject private var socialViewModel = SocialViewModel()
    @StateObject private var newsViewModel = NewsViewModel()
    @EnvironmentObject var authViewModel: AuthViewModel
    @Environment(\.scenePhase) private var scenePhase
    @State private var visiblePostCount = 5 // Start with 5 posts
    @State private var isLoadingMore = false
    @State private var selectedPost: SocialWorkoutPost?
    @State private var recommendedUsers: [UserSearchResult] = []
    @State private var recommendedFollowingStatus: [String: Bool] = [:]
    @State private var isLoadingRecommended = false
    @State private var showPaywall = false
    @State private var lastActiveTime: Date = Date()
    @State private var showInviteSheet = false
    @State private var showFindFriends = false
    @State private var selectedTab: SocialTab = .feed
    @State private var showCreateNews = false
    @State private var newsToEdit: NewsItem? = nil
    @State private var showNewsAvatarPicker = false
    @State private var newsAvatarItem: PhotosPickerItem? = nil
    @State private var newsAvatarUrl: String? = nil
    @State private var isUploadingAvatar = false
    @State private var pendingPostNavigation: String? = nil
    @State private var navigationPath = NavigationPath()
    @State private var featuredPosts: [SocialWorkoutPost] = []
    @State private var isLoadingFeatured = false
    @State private var carouselIndex = 0
    @State private var weeklyActivities: Int = 0
    @State private var weeklyTime: TimeInterval = 0
    @State private var weeklyDistance: Double = 0
    @State private var lastWeekActivities: Int = 0
    @State private var lastWeekTime: TimeInterval = 0
    @State private var lastWeekDistance: Double = 0
    private let brandLogos = BrandLogoItem.all
    private let sessionRefreshThreshold: TimeInterval = 120 // Refresh if inactive for 2+ minutes
    private let adminEmail = "info@bylito.se"
    
    // Only show users with profile pictures
    private var recommendedUsersWithPhoto: [UserSearchResult] {
        recommendedUsers.filter { $0.avatarUrl != nil && !$0.avatarUrl!.isEmpty }
    }
    
    // Check if current user is admin
    private var isAdmin: Bool {
        authViewModel.currentUser?.email.lowercased() == adminEmail.lowercased()
    }
    
    var body: some View {
        NavigationStack(path: $navigationPath) {
            ZStack {
                Color(.systemBackground).ignoresSafeArea()
                mainContent
            }
            .navigationTitle("")
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("PopToRootSocialt"))) { _ in
                navigationPath = NavigationPath()
                selectedPost = nil
            }
            .navigationBarHidden(true)
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(item: $selectedPost) { post in
                WorkoutDetailView(post: post)
                    .onAppear { NavigationDepthTracker.shared.setAtRoot(false) }
                    .onDisappear { NavigationDepthTracker.shared.setAtRoot(true) }
            }
            .task(id: authViewModel.currentUser?.id) {
                await loadInitialData()
            }
            .refreshable {
                await refreshData()
            }
            .sheet(isPresented: $showPaywall) {
                PresentPaywallView()
            }
            .sheet(isPresented: $showCreateNews) {
                CreateNewsView(newsViewModel: newsViewModel)
            }
            .sheet(isPresented: $showFindFriends) {
                FindFriendsView()
                    .environmentObject(authViewModel)
            }
            .enableSwipeBack()
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("NavigateToNewsTab"))) { _ in
                withAnimation {
                    selectedTab = .news
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("NavigateToPost"))) { notification in
                if let userInfo = notification.userInfo,
                   let postId = userInfo["postId"] as? String {
                    // Switch to feed tab first
                    withAnimation {
                        selectedTab = .feed
                    }
                    // Try to find the post in existing posts
                    if let post = socialViewModel.posts.first(where: { $0.id == postId }) {
                        selectedPost = post
                    } else {
                        // Post not in current feed - save it and fetch when data loads
                        pendingPostNavigation = postId
                        // Try to fetch the post directly
                        Task {
                            await fetchAndNavigateToPost(postId: postId)
                        }
                    }
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("PostUpdated"))) { _ in
                Task {
                    await socialViewModel.refreshSocialFeed(userId: authViewModel.currentUser?.id ?? "")
                }
            }
            .onChange(of: scenePhase) { oldPhase, newPhase in
                handleScenePhaseChange(newPhase)
            }
        }
    }
    
    // MARK: - Extracted Views
    
    @ViewBuilder
    private var mainContent: some View {
        VStack(spacing: 0) {
            // Combined header with tabs (Strava-style)
            CombinedHeaderWithTabs(selectedTab: $selectedTab)
                .environmentObject(authViewModel)
                .zIndex(1)
            
            if socialViewModel.isLoading && socialViewModel.posts.isEmpty && featuredPosts.isEmpty {
                loadingView
            } else if socialViewModel.posts.isEmpty && !featuredPosts.isEmpty {
                // Show featured posts when user has no following
                featuredPostsContent
            } else if socialViewModel.posts.isEmpty {
                emptyStateView
            } else {
                scrollContent
            }
        }
    }
    
    private var loadingView: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Skeleton for carousel/header area
                HStack(spacing: 16) {
                    SkeletonRectangle(height: 120, cornerRadius: 16)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                
                // Skeleton posts
                SkeletonFeedView(postCount: 3)
            }
        }
        .scrollDisabled(true)
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 24) {
            Spacer()
            
            VStack(spacing: 16) {
                Image(systemName: "person.2.badge.plus")
                    .font(.system(size: 64))
                    .foregroundColor(.gray.opacity(0.6))
                
                Text("Inga inlägg än")
                    .font(.system(size: 24, weight: .bold))
                
                Text("Följ andra användare för att se deras inlägg i ditt flöde")
                    .font(.system(size: 15))
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                
                Button {
                    showFindFriends = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 16, weight: .semibold))
                        Text("Lägg till vänner")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 28)
                    .padding(.vertical, 14)
                    .background(Color.black)
                    .cornerRadius(25)
                }
                .padding(.top, 8)
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task {
            await loadFeaturedPosts()
        }
    }
    
    private var featuredPostsContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // Strava-style swipeable cards
                quickInsightsCarousel
                
                Divider()
                
                if selectedTab == .feed {
                    // Featured posts
                    LazyVStack(spacing: 0) {
                        ForEach(featuredPosts) { post in
                            SocialPostCard(
                                post: post,
                                onOpenDetail: { tappedPost in selectedPost = tappedPost },
                                onLikeChanged: { _, _, _ in },
                                onCommentCountChanged: { _, _ in },
                                onPostDeleted: { _ in }
                            )
                            Divider()
                                .background(Color(.systemGray5))
                        }
                    }
                } else {
                    newsContent
                }
            }
        }
    }
    
    private var scrollContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // Strava-style swipeable cards
                quickInsightsCarousel
                
                Divider()
                
                if selectedTab == .feed {
                    feedContent
                } else {
                    newsContent
                }
            }
        }
    }
    
    // MARK: - Quick Insights Carousel (Strava-style)
    private var quickInsightsCarousel: some View {
        VStack(spacing: 8) {
            TabView(selection: $carouselIndex.animation(.easeInOut(duration: 0.3))) {
                // Card 1: Weekly Snapshot
                weeklySnapshotCard
                    .tag(0)
                
                // Card 2: Progressive Overload
                progressiveOverloadCard
                    .tag(1)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(height: 120)
            
            // Custom page indicators
            HStack(spacing: 8) {
                ForEach(0..<2, id: \.self) { index in
                    Circle()
                        .fill(carouselIndex == index ? Color.primary : Color.gray.opacity(0.4))
                        .frame(width: 8, height: 8)
                        .scaleEffect(carouselIndex == index ? 1.0 : 0.85)
                        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: carouselIndex)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
    
    private var progressiveOverloadCard: some View {
        NavigationLink(destination: ProgressiveOverloadView()) {
            HStack(spacing: 16) {
                // Image
                Image("UTVECKLING")
                    .resizable()
                    .scaledToFill()
                    .frame(width: 70, height: 70)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                
                VStack(alignment: .leading, spacing: 6) {
                    Text("Se din utveckling")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.gray)
                        .textCase(.uppercase)
                    
                    Text("Progressive Overload")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.primary)
                    
                    Text("Följ din styrketräning och se hur du blir starkare över tid.")
                        .font(.system(size: 13))
                        .foregroundColor(.gray)
                        .lineLimit(2)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.gray)
            }
            .padding(16)
        }
        .buttonStyle(.plain)
    }
    
    private var weeklySnapshotCard: some View {
        NavigationLink(destination: StatisticsView()) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Din veckostatistik")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Text("Se mer")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.primary)
                }
                
                HStack(spacing: 0) {
                    // Activities
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Aktiviteter")
                            .font(.system(size: 11))
                            .foregroundColor(.gray)
                        Text("\(weeklyActivities)")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(.primary)
                        weeklyChangeLabel(current: Double(weeklyActivities), previous: Double(lastWeekActivities), suffix: "")
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    
                    // Time
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Tid")
                            .font(.system(size: 11))
                            .foregroundColor(.gray)
                        Text(formatDuration(weeklyTime))
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(.primary)
                        weeklyChangeLabel(current: weeklyTime / 60, previous: lastWeekTime / 60, suffix: "")
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    
                    // Distance
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Distans")
                            .font(.system(size: 11))
                            .foregroundColor(.gray)
                        Text(String(format: "%.2f km", weeklyDistance / 1000))
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(.primary)
                        weeklyChangeLabel(current: weeklyDistance, previous: lastWeekDistance, suffix: " km")
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(16)
        }
        .buttonStyle(.plain)
        .task {
            await loadWeeklyStats()
        }
    }
    
    @ViewBuilder
    private func weeklyChangeLabel(current: Double, previous: Double, suffix: String) -> some View {
        let diff = current - previous
        HStack(spacing: 2) {
            Image(systemName: diff >= 0 ? "arrow.up" : "arrow.down")
                .font(.system(size: 9, weight: .bold))
            if suffix == " km" {
                Text(String(format: "%.2f%@", abs(diff) / 1000, suffix))
                    .font(.system(size: 11, weight: .medium))
            } else {
                Text("\(Int(abs(diff)))\(suffix)")
                    .font(.system(size: 11, weight: .medium))
            }
        }
        .foregroundColor(.gray)
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(Color(.systemGray5))
        .cornerRadius(4)
    }
    
    private func formatDuration(_ seconds: TimeInterval) -> String {
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60
        return "\(hours)h \(minutes)m"
    }
    
    private func loadWeeklyStats() async {
        guard let userId = authViewModel.currentUser?.id else { return }
        
        do {
            // Current week stats
            let calendar = Calendar.current
            let now = Date()
            let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? now
            let startOfLastWeek = calendar.date(byAdding: .weekOfYear, value: -1, to: startOfWeek) ?? now
            
            // Fetch posts for current week
            let posts = try await WorkoutService.shared.fetchUserWorkoutPosts(userId: userId)
            
            // Filter this week's posts
            let thisWeekPosts = posts.filter { post in
                if let date = ISO8601DateFormatter().date(from: post.createdAt) {
                    return date >= startOfWeek
                }
                return false
            }
            
            // Filter last week's posts
            let lastWeekPosts = posts.filter { post in
                if let date = ISO8601DateFormatter().date(from: post.createdAt) {
                    return date >= startOfLastWeek && date < startOfWeek
                }
                return false
            }
            
            // Calculate stats
            let activities = thisWeekPosts.count
            let time = thisWeekPosts.reduce(0.0) { $0 + Double($1.duration ?? 0) }
            let distance = thisWeekPosts.reduce(0.0) { $0 + ($1.distance ?? 0.0) }
            
            let lastActivities = lastWeekPosts.count
            let lastTime = lastWeekPosts.reduce(0.0) { $0 + Double($1.duration ?? 0) }
            let lastDistance = lastWeekPosts.reduce(0.0) { $0 + ($1.distance ?? 0.0) }
            
            await MainActor.run {
                self.weeklyActivities = activities
                self.weeklyTime = time
                self.weeklyDistance = distance
                self.lastWeekActivities = lastActivities
                self.lastWeekTime = lastTime
                self.lastWeekDistance = lastDistance
            }
        } catch {
            print("❌ Error loading weekly stats: \(error)")
        }
    }
    
    private var tabSelector: some View {
        HStack(spacing: 0) {
            ForEach(SocialTab.allCases, id: \.self) { tab in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedTab = tab
                    }
                } label: {
                    VStack(spacing: 8) {
                        Text(tab.rawValue)
                            .font(.system(size: 15, weight: selectedTab == tab ? .bold : .medium))
                            .foregroundColor(selectedTab == tab ? .primary : .gray)
                        
                        Rectangle()
                            .fill(selectedTab == tab ? Color.primary : Color.clear)
                            .frame(height: 2)
                    }
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 12)
    }
    
    // MARK: - Helper Functions
    
    private func loadInitialData() async {
        guard let userId = authViewModel.currentUser?.id else { return }
        
        do {
            try await AuthSessionManager.shared.ensureValidSession()
        } catch {
            print("❌ Session invalid, cannot fetch feed")
            return
        }
        
        await socialViewModel.fetchSocialFeedAsync(userId: userId)
        await loadRecommendedUsers(for: userId)
        await newsViewModel.fetchNews()
        
        // Check if we have a pending post navigation
        if let postId = pendingPostNavigation {
            pendingPostNavigation = nil
            if let post = socialViewModel.posts.first(where: { $0.id == postId }) {
                await MainActor.run {
                    selectedPost = post
                }
            }
        }
        
        // Load featured posts if user has no posts in feed
        if socialViewModel.posts.isEmpty {
            await loadFeaturedPosts()
        }
    }
    
    private func loadFeaturedPosts() async {
        guard !isLoadingFeatured else { return }
        guard let userId = authViewModel.currentUser?.id else { return }
        
        isLoadingFeatured = true
        
        do {
            let posts = try await SocialService.shared.getFeaturedPosts(viewerId: userId, limit: 4)
            await MainActor.run {
                self.featuredPosts = posts
                self.isLoadingFeatured = false
            }
        } catch {
            print("❌ Error loading featured posts: \(error)")
            await MainActor.run {
                self.isLoadingFeatured = false
            }
        }
    }
    
    private func fetchAndNavigateToPost(postId: String) async {
        do {
            // Try to fetch this specific post
            let post: SocialWorkoutPost = try await SupabaseConfig.supabase
                .from("workout_posts")
                .select("""
                    *,
                    profiles!inner(username, avatar_url, is_pro_member),
                    workout_post_likes(count),
                    workout_post_comments(count)
                """)
                .eq("id", value: postId)
                .single()
                .execute()
                .value
            
            await MainActor.run {
                selectedPost = post
                pendingPostNavigation = nil
            }
        } catch {
            print("❌ Failed to fetch post \(postId): \(error)")
            // Post might not exist or user doesn't have access
            pendingPostNavigation = nil
        }
    }
    
    private func refreshData() async {
        guard let userId = authViewModel.currentUser?.id else { return }
        
        do {
            try await AuthSessionManager.shared.ensureValidSession()
        } catch {
            print("❌ Session invalid, cannot refresh")
            return
        }
        
        visiblePostCount = 5
        await socialViewModel.refreshSocialFeed(userId: userId)
        await loadRecommendedUsers(for: userId)
        await newsViewModel.fetchNews()
    }
    
    private func handleScenePhaseChange(_ newPhase: ScenePhase) {
        if newPhase == .active {
            let inactiveTime = Date().timeIntervalSince(lastActiveTime)
            if inactiveTime > sessionRefreshThreshold && !socialViewModel.posts.isEmpty {
                print("🔄 App became active after \(Int(inactiveTime))s - refreshing social feed")
                Task {
                    guard let userId = authViewModel.currentUser?.id else { return }
                    do {
                        try await AuthSessionManager.shared.ensureValidSession()
                        await socialViewModel.refreshSocialFeed(userId: userId)
                    } catch {
                        print("❌ Failed to refresh on scene change: \(error)")
                    }
                }
            }
            lastActiveTime = Date()
        } else if newPhase == .background || newPhase == .inactive {
            lastActiveTime = Date()
        }
    }
    
    // MARK: - Feed Content
    private var feedContent: some View {
        LazyVStack(spacing: 0, pinnedViews: []) {
                                ForEach(Array(postsToDisplay.enumerated()), id: \.element.id) { index, post in
                                    VStack(spacing: 0) {
                                        SocialPostCard(
                                            post: post,
                                            onOpenDetail: { tappedPost in selectedPost = tappedPost },
                                            onLikeChanged: { postId, isLiked, count in
                                                socialViewModel.updatePostLikeStatus(postId: postId, isLiked: isLiked, likeCount: count)
                                            },
                                            onCommentCountChanged: { postId, count in
                                                socialViewModel.updatePostCommentCount(postId: postId, commentCount: count)
                                            },
                                            onPostDeleted: { postId in
                                                socialViewModel.removePost(postId: postId)
                                            }
                                        )
                                        .id(post.id) // Stable identity for better SwiftUI diffing
                                        Divider()
                                            .background(Color(.systemGray5))
                                    }
                                    .onAppear {
                                        if let index = socialViewModel.posts.firstIndex(where: { $0.id == post.id }),
                                           index >= visiblePostCount - 2,
                                           visiblePostCount < socialViewModel.posts.count {
                                            loadMorePosts()
                                        }
                                    }
                                    
                                    if index == 0, shouldShowRecommendedFriendsSection {
                                        recommendedFriendsInlineSection
                                        Divider()
                                            .background(Color(.systemGray5))
                                    }
                                    
                                    if index == 4, shouldShowBrandSlider {
                                        brandSliderInlineSection
                                        Divider()
                                            .background(Color(.systemGray5))
                                    }
                                }
                                
                                if isLoadingMore {
                                    HStack {
                                        Spacer()
                                        ProgressView()
                                            .tint(AppColors.brandBlue)
                                        Spacer()
                                    }
                                    .padding()
                                }
                                
                                if visiblePostCount >= socialViewModel.posts.count {
                                    Text("Inga fler inlägg")
                                        .font(.system(size: 14))
                                        .foregroundColor(.gray)
                                        .padding()
                                }
        }
    }
    
    // MARK: - News Content
    private var newsContent: some View {
        VStack(spacing: 0) {
            // Admin controls
            if isAdmin {
                VStack(spacing: 12) {
                    // Avatar picker row
                    HStack(spacing: 12) {
                        // Current avatar
                        PhotosPicker(selection: $newsAvatarItem, matching: .images) {
                            ZStack {
                                if let avatarUrl = newsAvatarUrl, !avatarUrl.isEmpty {
                                    LocalAsyncImage(path: avatarUrl)
                                        .frame(width: 56, height: 56)
                                        .clipShape(Circle())
                                } else {
                                    Image("23")
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 56, height: 56)
                                        .clipShape(Circle())
                                }
                                
                                // Edit overlay
                                Circle()
                                    .fill(Color.black.opacity(0.4))
                                    .frame(width: 56, height: 56)
                                    .overlay(
                                        Image(systemName: "camera.fill")
                                            .font(.system(size: 18))
                                            .foregroundColor(.white)
                                    )
                                
                                if isUploadingAvatar {
                                    Circle()
                                        .fill(Color.black.opacity(0.6))
                                        .frame(width: 56, height: 56)
                                        .overlay(
                                            ProgressView()
                                                .tint(.white)
                                        )
                                }
                            }
                        }
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Nyhetsprofil")
                                .font(.system(size: 15, weight: .semibold))
                            Text("Tryck för att byta profilbild")
                                .font(.system(size: 13))
                                .foregroundColor(.gray)
                        }
                        
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    
                    // Create news button
                    Button(action: {
                        showCreateNews = true
                    }) {
                        HStack(spacing: 12) {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 20))
                            Text("Skapa nyhet")
                                .font(.system(size: 15, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.black)
                        .cornerRadius(25)
                    }
                    .padding(.horizontal, 16)
                }
                .padding(.vertical, 12)
                
                Divider()
            }
            
            if newsViewModel.isLoading {
                // Skeleton loading for news
                VStack(spacing: 12) {
                    ForEach(0..<3, id: \.self) { _ in
                        SkeletonListRow()
                    }
                }
                .padding(.top, 16)
            } else if newsViewModel.news.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "newspaper")
                        .font(.system(size: 48))
                        .foregroundColor(.gray.opacity(0.5))
                        .padding(.top, 60)
                    Text("Inga nyheter än")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.gray)
                    Text("Håll utkik för uppdateringar!")
                        .font(.system(size: 14))
                        .foregroundColor(.gray.opacity(0.8))
                }
                .frame(maxWidth: .infinity)
            } else {
                LazyVStack(spacing: 0) {
                    ForEach(newsViewModel.news) { newsItem in
                        NewsItemView(
                            news: newsItem,
                            isAdmin: isAdmin,
                            onEdit: { item in
                                newsToEdit = item
                            },
                            onDelete: { item in
                                Task {
                                    await newsViewModel.deleteNews(id: item.id)
                                }
                            },
                            onLike: { item, shouldLike in
                                Task {
                                    if shouldLike {
                                        await newsViewModel.likeNews(newsId: item.id)
                                    } else {
                                        await newsViewModel.unlikeNews(newsId: item.id)
                                    }
                                }
                            }
                        )
                        Divider()
                    }
                }
            }
        }
        .sheet(item: $newsToEdit) { news in
            EditNewsView(newsViewModel: newsViewModel, news: news)
        }
        .onChange(of: newsAvatarItem) { _, newValue in
            Task {
                await uploadNewsAvatar(item: newValue)
            }
        }
        .task {
            // Load saved news avatar URL
            await loadNewsAvatarUrl()
        }
    }
    
    // MARK: - News Avatar Functions
    private func loadNewsAvatarUrl() async {
        do {
            struct NewsSettings: Decodable {
                let avatar_url: String?
            }
            
            let settings: [NewsSettings] = try await SupabaseConfig.supabase
                .from("news_settings")
                .select("avatar_url")
                .limit(1)
                .execute()
                .value
            
            if let avatarUrl = settings.first?.avatar_url {
                newsAvatarUrl = avatarUrl
            }
        } catch {
            print("⚠️ Could not load news avatar: \(error)")
        }
    }
    
    private func uploadNewsAvatar(item: PhotosPickerItem?) async {
        guard let item = item else { return }
        
        isUploadingAvatar = true
        
        do {
            guard let data = try await item.loadTransferable(type: Data.self),
                  let image = UIImage(data: data),
                  let imageData = image.jpegData(compressionQuality: 0.7) else {
                isUploadingAvatar = false
                return
            }
            
            let fileName = "news_avatar_\(UUID().uuidString).jpg"
            
            _ = try await SupabaseConfig.supabase.storage
                .from("avatars")
                .upload(fileName, data: imageData, options: .init(contentType: "image/jpeg", upsert: true))
            
            // Create full public URL for the avatar
            let fullAvatarUrl = "https://xebatkodviqgkpsbyuiv.supabase.co/storage/v1/object/public/avatars/\(fileName)"
            
            // Save to news_settings table
            struct SettingsPayload: Encodable {
                let id: String
                let avatar_url: String
            }
            
            try await SupabaseConfig.supabase
                .from("news_settings")
                .upsert(SettingsPayload(id: "default", avatar_url: fullAvatarUrl))
                .execute()
            
            newsAvatarUrl = fullAvatarUrl
            
            // Update all news items to use new avatar
            await newsViewModel.updateAllNewsAvatars(avatarUrl: fullAvatarUrl)
            
            print("✅ News avatar updated successfully")
        } catch {
            print("❌ Failed to upload news avatar: \(error)")
        }
        
        isUploadingAvatar = false
    }
    
    private func loadMorePosts() {
        guard !isLoadingMore else { return }
        
        isLoadingMore = true
        
        // Load 5 more posts
        let newCount = min(visiblePostCount + 5, socialViewModel.posts.count)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            visiblePostCount = newCount
            isLoadingMore = false
        }
    }
    
    private var postsToDisplay: [SocialWorkoutPost] {
        Array(socialViewModel.posts.prefix(visiblePostCount))
    }
    
    private var shouldShowRecommendedFriendsSection: Bool {
        isLoadingRecommended || !recommendedUsersWithPhoto.isEmpty
    }
    
    private var shouldShowBrandSlider: Bool {
        postsToDisplay.count >= 5
    }
    
    @ViewBuilder
    private var recommendedFriendsInlineSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Rekommenderade vänner")
                    .font(.system(size: 18, weight: .bold))
                Spacer()
                if isLoadingRecommended && recommendedUsers.isEmpty {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }
            .padding(.horizontal, 16)
            
            if recommendedUsersWithPhoto.isEmpty {
                if isLoadingRecommended {
                    // Skeleton loading for recommended users
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(0..<4, id: \.self) { _ in
                                VStack(spacing: 8) {
                                    SkeletonCircle(size: 60)
                                    SkeletonLine(width: 60, height: 12)
                                    SkeletonLine(width: 50, height: 28)
                                }
                                .frame(width: 80)
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                } else {
                    Text("Vi hittar snart fler att följa.")
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 8)
                }
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(recommendedUsersWithPhoto) { user in
                            RecommendedFriendCard(
                                user: user,
                                isFollowing: recommendedFollowingStatus[user.id] ?? false,
                                onFollowToggle: {
                                    toggleRecommendedFollow(for: user.id)
                                }
                            )
                        }
                    }
                    .padding(.horizontal, 16)
                }
                .frame(maxHeight: 150)
            }
        }
        .padding(.vertical, 20)
        .background(Color(.systemGray6))
    }
    
    private var emptyStateRecommendedFriends: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Rekommenderade att följa")
                .font(.system(size: 20, weight: .bold))
                .padding(.horizontal, 16)
            
            if isLoadingRecommended && recommendedUsers.isEmpty {
                HStack {
                    Spacer()
                    ProgressView()
                        .padding(.vertical, 40)
                    Spacer()
                }
            } else if recommendedUsersWithPhoto.isEmpty {
                VStack(spacing: 16) {
                    VStack(spacing: 8) {
                        Text("Inga rekommendationer just nu")
                            .font(.system(size: 15))
                            .foregroundColor(.gray)
                        Text("Bjud in dina vänner för att träna tillsammans!")
                            .font(.system(size: 13))
                            .foregroundColor(.gray.opacity(0.8))
                    }
                    
                    // Invite friends button
                    Button {
                        showInviteSheet = true
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "person.badge.plus")
                                .font(.system(size: 16, weight: .semibold))
                            Text("Bjud in dina vänner")
                                .font(.system(size: 15, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(Color.black)
                        .cornerRadius(25)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            } else {
                // Grid layout for empty state (more prominent) - only users with photos
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 12) {
                    ForEach(recommendedUsersWithPhoto) { user in
                        EmptyStateUserCard(
                            user: user,
                            isFollowing: recommendedFollowingStatus[user.id] ?? false,
                            onFollowToggle: {
                                toggleRecommendedFollow(for: user.id)
                            }
                        )
                    }
                }
                .padding(.horizontal, 16)
                
                // Invite button below recommendations
                Button {
                    showInviteSheet = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "person.badge.plus")
                            .font(.system(size: 14, weight: .medium))
                        Text("Bjud in fler vänner")
                            .font(.system(size: 14, weight: .medium))
                    }
                    .foregroundColor(.primary)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(20)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 8)
            }
        }
        .padding(.vertical, 16)
        .onAppear {
            if recommendedUsers.isEmpty {
                Task {
                    await loadRecommendedUsers(for: authViewModel.currentUser?.id ?? "")
                }
            }
        }
        .sheet(isPresented: $showInviteSheet) {
            InviteFriendsSheet()
        }
    }
    
    private var brandSliderInlineSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Varumärken")
                .font(.system(size: 18, weight: .bold))
                .padding(.horizontal, 16)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(brandLogos) { brand in
                        Button(action: navigateToRewards) {
                            VStack(spacing: 8) {
                                Image(brand.imageName)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 60, height: 60)
                                    .clipShape(Circle())
                                    .overlay(
                                        Circle()
                                            .stroke(Color.black.opacity(0.08), lineWidth: 1)
                                    )
                                
                                Text(brand.name.capitalized)
                                    .font(.system(size: 12, weight: .semibold))
                                    .lineLimit(1)
                                    .foregroundColor(.primary)
                            }
                            .frame(width: 90)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 4)
            }
        }
        .padding(.vertical, 20)
        .background(Color(.systemBackground))
    }
    
    private func toggleRecommendedFollow(for userId: String) {
        guard let currentUserId = authViewModel.currentUser?.id else { return }
        let isCurrentlyFollowing = recommendedFollowingStatus[userId] ?? false
        
        Task {
            do {
                if isCurrentlyFollowing {
                    try await SocialService.shared.unfollowUser(followerId: currentUserId, followingId: userId)
                } else {
                    try await SocialService.shared.followUser(followerId: currentUserId, followingId: userId)
                }
                
                await MainActor.run {
                    recommendedFollowingStatus[userId] = !isCurrentlyFollowing
                }
            } catch {
                print("❌ Error toggling follow from SocialView: \(error)")
            }
        }
    }
    
    private func loadRecommendedUsers(for userId: String) async {
        await MainActor.run {
            if recommendedUsers.isEmpty {
                isLoadingRecommended = true
            }
        }
        
        if let cached = AppCacheManager.shared.getCachedRecommendedUsers(userId: userId) {
            await MainActor.run {
                self.recommendedUsers = cached
            }
        }
        
        do {
            let recommended = try await RetryHelper.shared.retry(maxRetries: 3, delay: 0.5) {
                return try await SocialService.shared.getRecommendedUsers(userId: userId, limit: 8)
            }
            
            var followStatus: [String: Bool] = [:]
            for user in recommended {
                let isFollowing = try await SocialService.shared.isFollowing(followerId: userId, followingId: user.id)
                followStatus[user.id] = isFollowing
            }
            
            await MainActor.run {
                self.recommendedUsers = recommended
                self.recommendedFollowingStatus = followStatus
                self.isLoadingRecommended = false
            }
            
            AppCacheManager.shared.saveRecommendedUsers(recommended, userId: userId)
        } catch {
            print("❌ Error loading recommended users in SocialView: \(error)")
            await MainActor.run {
                self.isLoadingRecommended = false
            }
        }
    }
    
    private func navigateToRewards() {
        NotificationCenter.default.post(name: NSNotification.Name("NavigateToRewards"), object: nil)
    }
}

struct SocialPostCard: View {
    let post: SocialWorkoutPost
    let onOpenDetail: (SocialWorkoutPost) -> Void
    let onLikeChanged: (String, Bool, Int) -> Void
    let onCommentCountChanged: (String, Int) -> Void
    let onPostDeleted: (String) -> Void
    @State private var isLiked: Bool
    @State private var likeCount: Int
    @State private var commentCount: Int
    @State private var topLikers: [UserSearchResult] = []
    @State private var showMenu = false
    @State private var showDeleteAlert = false
    @State private var likeInProgress = false
    @State private var showShareSheet = false
    @State private var showLikesList = false
    @State private var showEditSheet = false
    @State private var editedTitle: String = ""
    @State private var editedDescription: String = ""
    @EnvironmentObject var authViewModel: AuthViewModel
    
    init(post: SocialWorkoutPost, onOpenDetail: @escaping (SocialWorkoutPost) -> Void, onLikeChanged: @escaping (String, Bool, Int) -> Void, onCommentCountChanged: @escaping (String, Int) -> Void, onPostDeleted: @escaping (String) -> Void) {
        self.post = post
        self.onOpenDetail = onOpenDetail
        self.onLikeChanged = onLikeChanged
        self.onCommentCountChanged = onCommentCountChanged
        self.onPostDeleted = onPostDeleted
        _isLiked = State(initialValue: post.isLikedByCurrentUser ?? false)
        _likeCount = State(initialValue: post.likeCount ?? 0)
        _commentCount = State(initialValue: post.commentCount ?? 0)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            headerSection
            statsSection
            contentSection
            
            likesPreview
            
            // Like, Comment, Share buttons - large, evenly spaced
            HStack(spacing: 0) {
                Button(action: toggleLike) {
                    Image(systemName: isLiked ? "heart.fill" : "heart")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(isLiked ? .red : .gray)
                        .animation(.none, value: isLiked)
                }
                .disabled(likeInProgress)
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())

                NavigationLink(destination: CommentsView(post: post) {
                    commentCount += 1
                    onCommentCountChanged(post.id, commentCount)
                }) {
                    Image(systemName: "bubble.right")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.gray)
                }
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())

                Button(action: { showShareSheet = true }) {
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
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemBackground))
        .task(id: post.id) {
            // Only fetch if we have likes and haven't loaded yet
            if likeCount > 0 && topLikers.isEmpty {
                await loadTopLikers()
            }
        }
        .onChange(of: post.likeCount) { newValue in
            likeCount = newValue ?? likeCount
        }
        .onChange(of: post.commentCount) { newValue in
            commentCount = newValue ?? commentCount
        }
        .onChange(of: post.isLikedByCurrentUser) { newValue in
            isLiked = newValue ?? isLiked
        }
        .confirmationDialog("Post Options", isPresented: $showMenu, titleVisibility: .hidden) {
            Button("Redigera") {
                showEditSheet = true
            }
            Button("Ta bort inlägg", role: .destructive) {
                showDeleteAlert = true
            }
            Button("Avbryt", role: .cancel) {}
        }
        .alert("Ta bort inlägg", isPresented: $showDeleteAlert) {
            Button("Avbryt", role: .cancel) {}
            Button("Ta bort", role: .destructive) {
                deletePost()
            }
        } message: {
            Text("Är du säker på att du vill ta bort detta inlägg? Denna åtgärd kan inte ångras.")
        }
        .sheet(isPresented: $showShareSheet) {
            ShareActivityView(post: post)
        }
        .sheet(isPresented: $showLikesList) {
            LikesListView(postId: post.id)
                .environmentObject(authViewModel)
        }
        .sheet(isPresented: $showEditSheet) {
            EditPostView(post: post) { newTitle, newDescription, newImage in
                Task {
                    await updatePost(title: newTitle, description: newDescription, image: newImage)
                }
            }
        }
    }
    
    private var headerSection: some View {
        HStack(spacing: 12) {
            NavigationLink(destination: UserProfileView(userId: post.userId)) {
                ProfileImage(url: post.userAvatarUrl, size: 40)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                NavigationLink(destination: UserProfileView(userId: post.userId)) {
                    HStack(spacing: 6) {
                        if let name = post.userName?.trimmingCharacters(in: .whitespacesAndNewlines),
                           !name.isEmpty {
                            Text(name)
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.primary)
                            
                            // Pro member verified badge
                            if post.userIsPro == true {
                                Image(systemName: "checkmark.seal.fill")
                                    .font(.system(size: 14))
                                    .foregroundColor(.blue)
                            }
                        } else {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color(.systemGray5))
                                .frame(width: 120, height: 14)
                                .shimmer()
                        }
                        
                        Image(systemName: getActivityIcon(post.activityType))
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(AppColors.brandBlue)
                    }
                }
                
                // Date and device info
                HStack(spacing: 4) {
                    Text(formatDate(post.createdAt))
                        .font(.system(size: 13))
                        .foregroundColor(.gray)
                    
                    // Show device name for external posts
                    if let deviceName = post.deviceName, !deviceName.isEmpty {
                        Text("•")
                            .font(.system(size: 13))
                            .foregroundColor(.gray)
                        Text(deviceName)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.gray)
                    }
                }
                
                if let location = post.location {
                    Text(location)
                        .font(.system(size: 13))
                        .foregroundColor(.gray)
                }
            }
            
            Spacer()
            
            if post.userId == authViewModel.currentUser?.id {
                Button(action: {
                    showMenu = true
                }) {
                    Image(systemName: "ellipsis")
                        .foregroundColor(.primary)
                        .font(.system(size: 16))
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }
    
    @ViewBuilder
    private var contentSection: some View {
        // Show exercises list for Gympass, otherwise show swipeable images
        if post.activityType == "Gympass", let exercises = post.exercises, !exercises.isEmpty {
            GymExercisesListView(exercises: exercises, userImage: post.userImageUrl)
                .onTapGesture {
                    onOpenDetail(post)
                }
        } else if post.isExternalPost || shouldShowCleanCard {
            // External posts or posts without images - show clean Strava-style card
            ExternalActivityCard(post: post)
                .onTapGesture {
                    onOpenDetail(post)
                }
        } else {
            // Swipeable images (route and user image)
            SwipeableImageView(routeImage: post.imageUrl, userImage: post.userImageUrl)
                .onTapGesture {
                    onOpenDetail(post)
                }
        }
    }
    
    // Show clean card if no images available (avoids gray placeholder)
    private var shouldShowCleanCard: Bool {
        let hasRouteImage = post.imageUrl != nil && !post.imageUrl!.isEmpty
        let hasUserImage = post.userImageUrl != nil && !post.userImageUrl!.isEmpty
        return !hasRouteImage && !hasUserImage
    }
    
    // Used in statsSection to avoid duplicate stats
    private var showsCleanCard: Bool {
        post.isExternalPost || shouldShowCleanCard
    }
    
    private var statsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Text(post.title)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.primary)
                
                if let isPro = post.userIsPro, isPro {
                    Image("41")
                        .resizable()
                        .renderingMode(.original)
                        .scaledToFit()
                        .frame(height: 16)
                        .padding(.leading, 4)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            
            if let description = trimmedDescription {
                Text(description)
                    .font(.system(size: 14))
                    .foregroundColor(.gray)
                    .padding(.horizontal, 16)
            }
            
            // PB Badge - show if this workout has a personal best
            if let pbExercise = post.pbExerciseName, let pbVal = post.pbValue,
               !pbExercise.isEmpty, !pbVal.isEmpty {
                HStack(spacing: 10) {
                    Image(systemName: "trophy.fill")
                        .font(.system(size: 18))
                        .foregroundColor(.yellow)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Nytt PB!")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.yellow)
                        Text("\(pbExercise): \(pbVal)")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.primary)
                    }
                    
                    Spacer()
                }
                .padding(12)
                .background(Color(.systemGray6))
                .cornerRadius(10)
                .padding(.horizontal, 16)
            }
            
            // Only show stats here for gym posts or posts with images
            // ExternalActivityCard handles stats for clean/external posts
            if !showsCleanCard {
                HStack(spacing: 0) {
                    if isGymPost {
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
                            // Show meters for swimming, km for others
                            if post.isSwimmingPost {
                                let meters = Int(distance * 1000)
                                statColumn(title: "Distans", value: "\(meters) m")
                            } else {
                                statColumn(title: "Distans", value: String(format: "%.2f km", distance))
                            }
                        }
                        
                        if let duration = post.duration {
                            if post.distance != nil {
                                Divider()
                                    .frame(height: 40)
                            }
                            statColumn(title: "Tid", value: formatDuration(duration))
                        }
                        
                        if let pace = averagePaceText {
                            if post.distance != nil || post.duration != nil {
                                Divider()
                                    .frame(height: 40)
                            }
                            // Show pace per 100m for swimming
                            if post.isSwimmingPost {
                                statColumn(title: "Tempo/100m", value: pace)
                            } else {
                                statColumn(title: "Tempo", value: pace)
                            }
                        }
                        
                        if let strokes = post.strokes {
                            if (post.distance != nil || post.duration != nil || averagePaceText != nil) {
                                Divider()
                                    .frame(height: 40)
                            }
                            statColumn(title: "Slag", value: "\(strokes)")
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
            }
        }
        .onTapGesture {
            onOpenDetail(post)
        }
    }
    
    private var averagePaceText: String? {
        guard let distance = post.distance, distance > 0,
              let duration = post.duration else { return nil }
        let paceSeconds = Double(duration) / distance
        let minutes = Int(paceSeconds) / 60
        let seconds = Int(paceSeconds) % 60
        return String(format: "%d:%02d /km", minutes, seconds)
    }
    
    private var trimmedDescription: String? {
        guard let text = post.description?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else {
            return nil
        }
        return text
    }
    
    private var isGymPost: Bool {
        post.activityType == "Gympass"
    }
    
    private var gymVolumeText: String? {
        guard isGymPost, let exercises = post.exercises else { return nil }
        let total = totalVolume(for: exercises)
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        let text = formatter.string(from: NSNumber(value: Int(round(total)))) ?? "0"
        return "\(text) kg"
    }
    
    private func totalVolume(for exercises: [GymExercisePost]) -> Double {
        exercises.reduce(0) { result, exercise in
            let setVolume = zip(exercise.kg, exercise.reps).reduce(0) { partial, pair in
                partial + (pair.0 * Double(pair.1))
            }
            return result + setVolume
        }
    }
    
    private func statColumn(title: String, value: String) -> some View {
        VStack(spacing: 6) {
            Text(title)
                .font(.system(size: 11))
                .foregroundColor(.gray)
            Text(value)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.primary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
    }
    
    private func deletePost() {
        Task {
            do {
                let userId = authViewModel.currentUser?.id
                try await WorkoutService.shared.deleteWorkoutPost(postId: post.id, userId: userId)
                print("✅ Post deleted successfully")
                // Remove post from the list immediately
                await MainActor.run {
                    onPostDeleted(post.id)
                }
            } catch {
                print("❌ Error deleting post: \(error)")
            }
        }
    }
    
    private func updatePost(title: String, description: String, image: UIImage?) async {
        do {
            var imageUrl: String? = nil
            
            // Upload new image if provided
            if let image = image {
                imageUrl = try await WorkoutService.shared.uploadWorkoutImage(image, postId: post.id)
            }
            
            // Update the post
            try await WorkoutService.shared.updateWorkoutPost(
                postId: post.id,
                title: title,
                description: description,
                userImageUrl: imageUrl
            )
            
            print("✅ Post updated successfully")
            
            await MainActor.run {
                showEditSheet = false
                // Notify that post was updated - trigger refresh
                NotificationCenter.default.post(name: NSNotification.Name("PostUpdated"), object: nil)
            }
        } catch {
            print("❌ Error updating post: \(error)")
            await MainActor.run {
                showEditSheet = false
            }
        }
    }
    
    private func toggleLike() {
        guard let userId = authViewModel.currentUser?.id else { return }
        guard !likeInProgress else { return }
        
        // Store previous state for rollback
        let previousLiked = isLiked
        let previousCount = likeCount
        let previousTopLikers = topLikers
        
        // Update UI immediately (optimistic update)
        likeInProgress = true
        isLiked.toggle()
        likeCount += isLiked ? 1 : -1
        if isLiked {
            if let currentUser = authViewModel.currentUser {
                let liker = UserSearchResult(id: currentUser.id, name: currentUser.name, avatarUrl: currentUser.avatarUrl)
                if !topLikers.contains(where: { $0.id == liker.id }) {
                    topLikers.insert(liker, at: 0)
                }
            }
        } else {
            topLikers.removeAll { $0.id == userId }
        }
        topLikers = Array(topLikers.prefix(3))
        
        Task {
            do {
                if isLiked {
                    // When liking, check if already liked first
                    let existingLikes = try await SocialService.shared.getPostLikes(postId: post.id)
                    let alreadyLiked = existingLikes.contains { $0.userId == userId }
                    
                    if !alreadyLiked {
                        // Pass post owner ID to trigger notification
                        try await SocialService.shared.likePost(
                            postId: post.id,
                            userId: userId,
                            postOwnerId: post.userId,
                            postTitle: post.activityType
                        )
                        print("✅ Post liked successfully")
                    } else {
                        print("⚠️ Already liked this post")
                    }
                } else {
                    try await SocialService.shared.unlikePost(postId: post.id, userId: userId)
                    print("✅ Post unliked successfully")
                }
                
                await MainActor.run {
                    likeInProgress = false
                    onLikeChanged(post.id, isLiked, likeCount)
                }
            } catch {
                print("❌ Error toggling like: \(error)")
                // Rollback on error
                await MainActor.run {
                    isLiked = previousLiked
                    likeCount = previousCount
                    topLikers = previousTopLikers
                    likeInProgress = false
                }
            }
            await loadTopLikers()
        }
    }
    
    func getActivityIcon(_ activity: String) -> String {
        switch activity {
        case "Löppass", "Löpning":
            return "figure.run"
        case "Golfrunda", "Golf":
            return "flag.fill"
        case "Gympass":
            return "figure.strengthtraining.traditional"
        case "Bestiga berg", "Vandring":
            return "mountain.2.fill"
        case "Skidåkning":
            return "snowflake"
        case "Simning":
            return "figure.pool.swim"
        case "Cykling":
            return "figure.outdoor.cycle"
        case "Promenad":
            return "figure.walk"
        case "Yoga":
            return "figure.yoga"
        case "Rodd":
            return "figure.rower"
        case "Cardio":
            return "heart.fill"
        default:
            return "figure.walk"
        }
    }
    
    func formatDate(_ dateString: String) -> String {
        // Try multiple date formats
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        var date: Date?
        
        // Try with fractional seconds first
        date = formatter.date(from: dateString)
        
        // Fall back to without fractional seconds
        if date == nil {
            formatter.formatOptions = [.withInternetDateTime]
            date = formatter.date(from: dateString)
        }
        
        // Fall back to basic ISO format
        if date == nil {
            let basicFormatter = DateFormatter()
            basicFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
            date = basicFormatter.date(from: dateString)
        }
        
        if date == nil {
            let basicFormatter = DateFormatter()
            basicFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
            date = basicFormatter.date(from: dateString)
        }
        
        guard let parsedDate = date else {
            return dateString
        }
        
        let calendar = Calendar.current
        if calendar.isDateInToday(parsedDate) {
            let timeFormatter = DateFormatter()
            timeFormatter.timeStyle = .short
            timeFormatter.locale = Locale(identifier: "sv_SE")
            return "Idag \(timeFormatter.string(from: parsedDate))"
        } else if calendar.isDateInYesterday(parsedDate) {
            return "Igår"
        } else {
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "d MMM"
            dateFormatter.locale = Locale(identifier: "sv_SE")
            return dateFormatter.string(from: parsedDate)
        }
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

    private func loadTopLikers() async {
        guard likeCount > 0 else {
            await MainActor.run {
                self.topLikers = []
            }
            return
        }
        do {
            let likers = try await SocialService.shared.getTopPostLikers(postId: post.id, limit: 3)
            await MainActor.run {
                self.topLikers = likers
            }
        } catch {
            print("⚠️ Could not fetch top likers: \(error)")
        }
    }
}

private extension SocialPostCard {
    var likesPreview: some View {
        HStack(spacing: 12) {
            if likeCount > 0 {
                Button(action: { showLikesList = true }) {
                    HStack(spacing: 12) {
                        OverlappingAvatarStack(users: Array(topLikers.prefix(3)))
                        Text(likeCountText)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.primary)
                    }
                    .padding(.vertical, 4)
                }
                .buttonStyle(.plain)
            } else {
                Text("Bli först att gilla")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            NavigationLink(destination: CommentsView(post: post) {
                commentCount += 1
                onCommentCountChanged(post.id, commentCount)
            }) {
                Text("\(commentCount) kommentarer")
                    .font(.system(size: 14))
                    .foregroundColor(.gray)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .padding(.bottom, 4)
    }
    
    var likeCountText: String {
        likeCount == 1 ? "1 like" : "\(likeCount) likes"
    }
}

private struct OverlappingAvatarStack: View {
    let users: [UserSearchResult]
    
    var body: some View {
        ZStack(alignment: .leading) {
            if users.isEmpty {
                Circle()
                    .fill(Color(.systemGray5))
                    .frame(width: 36, height: 36)
                    .overlay(
                        Image(systemName: "person.fill")
                            .foregroundColor(.gray)
                            .font(.system(size: 14))
                    )
            } else {
                ForEach(Array(users.enumerated()), id: \.element.id) { index, liker in
                    ProfileImage(url: liker.avatarUrl, size: 36)
                        .overlay(Circle().stroke(Color.white, lineWidth: 2))
                        .offset(x: CGFloat(index) * 20)
                }
            }
        }
        .frame(width: CGFloat(max(users.count, 1)) * 20 + 20, height: 40, alignment: .leading)
    }
}

// Add a destination for NavigationStack value routing
extension SocialView {
    @ViewBuilder
    var navigationDestination: some View {
        EmptyView()
    }
}

struct CommentsView: View {
    let post: SocialWorkoutPost
    let onCommentAdded: (() -> Void)?
    @StateObject private var commentsViewModel = CommentsViewModel()
    @State private var newComment = ""
    @State private var replyTarget: PostComment?
    @State private var isSending = false
    @State private var topLikers: [UserSearchResult] = []
    @EnvironmentObject var authViewModel: AuthViewModel
    @Environment(\.dismiss) private var dismiss
    @Namespace private var bottomID
    @FocusState private var isCommentFieldFocused: Bool
    
    private var isGymWorkout: Bool {
        post.activityType.lowercased() == "gym"
    }
    
    private var activityIcon: String {
        switch post.activityType.lowercased() {
        case "gym":
            return "dumbbell.fill"
        case "running", "löpning":
            return "figure.run"
        case "golf":
            return "figure.golf"
        case "skiing", "skidor":
            return "figure.skiing.downhill"
        default:
            return "figure.walk"
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { scrollProxy in
                ScrollView {
                    VStack(spacing: 0) {
                        // Post header section (like Strava)
                        postHeaderSection
                        
                        Divider()
                        
                        // Comments section
                        LazyVStack(spacing: 0) {
                            if commentsViewModel.isLoading && commentsViewModel.threads.isEmpty {
                                ProgressView()
                                    .padding(.top, 40)
                            } else if commentsViewModel.threads.isEmpty {
                                emptyStateView
                            } else {
                                ForEach(commentsViewModel.threads) { thread in
                                    CommentRow(
                                        comment: thread.comment,
                                        isReply: false,
                                        onLike: { commentsViewModel.toggleLike(for: thread.comment.id, currentUserId: authViewModel.currentUser?.id) },
                                        onReply: { startReplyTo(thread.comment) },
                                        onDelete: { deleteComment(thread.comment) }
                                    )
                                    .environmentObject(authViewModel)
                                    .transition(.asymmetric(
                                        insertion: .opacity.combined(with: .move(edge: .bottom)),
                                        removal: .opacity
                                    ))
                                    
                                    ForEach(thread.replies) { reply in
                                        CommentRow(
                                            comment: reply,
                                            isReply: true,
                                            onLike: { commentsViewModel.toggleLike(for: reply.id, currentUserId: authViewModel.currentUser?.id) },
                                            onReply: { startReplyTo(reply) },
                                            onDelete: { deleteComment(reply) }
                                        )
                                        .environmentObject(authViewModel)
                                        .transition(.asymmetric(
                                            insertion: .opacity.combined(with: .move(edge: .bottom)),
                                            removal: .opacity
                                        ))
                                    }
                                }
                                
                                Color.clear
                                    .frame(height: 1)
                                    .id(bottomID)
                            }
                        }
                        .padding(.top, 8)
                    }
                    .frame(maxWidth: .infinity)
                    .background(Color(.systemBackground))
                    .refreshable {
                        await reloadComments()
                    }
                }
                .onChange(of: commentsViewModel.totalCommentCount) { _ in
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        scrollProxy.scrollTo(bottomID, anchor: .bottom)
                    }
                }
            }
            
            // Add comment section
            commentInputSection
        }
        .background(Color(.systemBackground))
        .navigationTitle("Diskussion")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await reloadComments()
            await loadTopLikers()
        }
    }
    
    // MARK: - Post Header Section
    private var postHeaderSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Route image (only for non-gym workouts)
            if !isGymWorkout, let imageUrl = post.imageUrl, !imageUrl.isEmpty {
                AsyncImage(url: URL(string: imageUrl)) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(height: 180)
                            .clipped()
                    case .failure(_):
                        Color(.systemGray5)
                            .frame(height: 180)
                    case .empty:
                        Color(.systemGray5)
                            .frame(height: 180)
                            .overlay(ProgressView())
                    @unknown default:
                        EmptyView()
                    }
                }
            }
            
            VStack(alignment: .leading, spacing: 8) {
                // Title
                Text(post.title)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.primary)
                
                // User info and stats
                HStack(spacing: 4) {
                    Text(post.userName ?? "Användare")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                    
                    Text("·")
                        .foregroundColor(.secondary)
                    
                    Text(formatPostDate(post.createdAt))
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                    
                    Text("·")
                        .foregroundColor(.secondary)
                    
                    // Stats based on activity type
                    if isGymWorkout {
                        Image(systemName: "dumbbell.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                        Text(formatGymStats())
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    } else {
                        // Icon based on activity type
                        Image(systemName: activityIcon)
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                        if let distance = post.distance {
                            Text(String(format: "%.2f km", distance))
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                // Likes section
                HStack(spacing: 8) {
                    Image(systemName: "hand.thumbsup")
                        .font(.system(size: 16))
                        .foregroundColor(.secondary)
                    
                    Text("\(post.likeCount ?? 0)")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    // Profile pictures of likers (max 8)
                    if !topLikers.isEmpty {
                        HStack(spacing: -8) {
                            ForEach(Array(topLikers.prefix(8).enumerated()), id: \.element.id) { index, liker in
                                ProfileImage(url: liker.avatarUrl, size: 28)
                                    .overlay(Circle().stroke(Color(.systemBackground), lineWidth: 2))
                                    .zIndex(Double(8 - index))
                            }
                        }
                    }
                }
                .padding(.top, 4)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemBackground))
    }
    
    // MARK: - Comment Input Section
    private var commentInputSection: some View {
        VStack(spacing: 0) {
            Divider()
            
            if let replyTarget {
                HStack {
                    Text("Svara på \(replyTarget.userName ?? "användare")")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.gray)
                    Spacer()
                    Button("Avbryt") {
                        cancelReply()
                    }
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.black)
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .transition(.asymmetric(
                    insertion: .move(edge: .bottom).combined(with: .opacity),
                    removal: .opacity
                ))
            }
            
            HStack(spacing: 12) {
                TextField(replyTarget != nil ? "Svara \(replyTarget?.userName ?? "")..." : "Lägg till en kommentar", text: $newComment)
                    .font(.system(size: 15))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color(.systemGray6))
                    .cornerRadius(20)
                    .focused($isCommentFieldFocused)
                
                Button(action: {
                    addComment()
                }) {
                    if isSending {
                        ProgressView()
                            .tint(.primary)
                            .frame(width: 50)
                    } else {
                        Text("Skicka")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(newComment.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? .gray : .black)
                    }
                }
                .disabled(isSending || newComment.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .animation(.easeInOut, value: isSending)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(Color(.systemBackground))
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: replyTarget?.id)
    }
    
    // MARK: - Reply Functions
    private func startReplyTo(_ comment: PostComment) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            replyTarget = comment
            // Insert username in the text field
            if let userName = comment.userName, !userName.isEmpty {
                newComment = "\(userName) "
            }
        }
        // Focus the text field with a slight delay for better UX
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            isCommentFieldFocused = true
        }
    }
    
    private func cancelReply() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            replyTarget = nil
            newComment = ""
        }
    }
    
    private func deleteComment(_ comment: PostComment) {
        Task {
            do {
                // Delete from database
                try await SocialService.shared.deleteComment(commentId: comment.id)
                
                // Remove from local state with animation
                await MainActor.run {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        commentsViewModel.removeComment(withId: comment.id)
                    }
                    
                    // Haptic feedback for successful deletion
                    let generator = UINotificationFeedbackGenerator()
                    generator.notificationOccurred(.success)
                }
                
                print("✅ Comment deleted successfully")
            } catch {
                print("❌ Error deleting comment: \(error)")
                
                // Show error haptic
                await MainActor.run {
                    let generator = UINotificationFeedbackGenerator()
                    generator.notificationOccurred(.error)
                }
            }
        }
    }
    
    // MARK: - Helper Functions
    private func formatPostDate(_ dateString: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        guard let date = formatter.date(from: dateString) else {
            formatter.formatOptions = [.withInternetDateTime]
            guard let date = formatter.date(from: dateString) else {
                return dateString
            }
            return formatDate(date)
        }
        return formatDate(date)
    }
    
    private func formatDate(_ date: Date) -> String {
        let outputFormatter = DateFormatter()
        outputFormatter.dateFormat = "d MMM yyyy"
        outputFormatter.locale = Locale(identifier: "sv_SE")
        return outputFormatter.string(from: date)
    }
    
    private func formatGymStats() -> String {
        guard let exercises = post.exercises else { return "" }
        
        var totalSets = 0
        var totalVolume: Double = 0
        
        for exercise in exercises {
            totalSets += exercise.sets
            // Iterate through the arrays of reps and kg
            let setCount = min(exercise.reps.count, exercise.kg.count)
            for i in 0..<setCount {
                let reps = Double(exercise.reps[i])
                let kg = exercise.kg[i]
                totalVolume += reps * kg
            }
        }
        
        if totalVolume > 0 {
            return String(format: "%.0f kg", totalVolume)
        }
        return "\(totalSets) set"
    }
    
    private func addComment() {
        guard let userId = authViewModel.currentUser?.id,
              !newComment.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        let commentText = newComment.trimmingCharacters(in: .whitespacesAndNewlines)
        
        let optimisticComment = PostComment(
            postId: post.id,
            userId: userId,
            content: commentText,
            userName: authViewModel.currentUser?.name,
            userAvatarUrl: authViewModel.currentUser?.avatarUrl,
            parentCommentId: replyTarget?.id
        )
        
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            commentsViewModel.appendComment(optimisticComment)
        }
        newComment = ""
        
        isSending = true
        Task {
            do {
                try await SocialService.shared.addComment(
                    postId: post.id,
                    userId: userId,
                    content: commentText,
                    parentCommentId: replyTarget?.id,
                    postOwnerId: post.userId
                )
                print("✅ Comment added successfully")
                
                await reloadComments()
                await MainActor.run {
                    onCommentAdded?()
                    replyTarget = nil
                }
            } catch {
                print("❌ Error adding comment: \(error)")
                await MainActor.run {
                    commentsViewModel.removeComment(withId: optimisticComment.id)
                }
            }
            await MainActor.run {
                isSending = false
            }
        }
    }
    
    private func reloadComments() async {
        print("🔄 Force reloading comments from database for post: \(post.id)")
        await commentsViewModel.fetchCommentsAsync(postId: post.id, currentUserId: authViewModel.currentUser?.id)
    }
    
    private func loadTopLikers() async {
        do {
            let likers = try await SocialService.shared.getTopPostLikers(postId: post.id, limit: 8)
            await MainActor.run {
                self.topLikers = likers
            }
        } catch {
            print("⚠️ Could not fetch top likers: \(error)")
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 8) {
            Image(systemName: "bubble.left")
                .font(.system(size: 32))
                .foregroundColor(.gray)
            Text("Inga kommentarer än")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.gray)
            Text("Starta konversationen genom att lämna en kommentar.")
                .font(.system(size: 13))
                .foregroundColor(.gray)
        }
        .padding(.top, 60)
        .padding(.horizontal, 32)
        .multilineTextAlignment(.center)
    }
}

struct CommentRow: View {
    let comment: PostComment
    let isReply: Bool
    let onLike: () -> Void
    let onReply: () -> Void
    let onDelete: () -> Void
    @EnvironmentObject private var authViewModel: AuthViewModel
    
    // Swipe state
    @State private var swipeOffset: CGFloat = 0
    @State private var isDragging = false
    @GestureState private var dragOffset: CGFloat = 0
    @State private var showDeleteConfirmation = false
    
    private let actionThreshold: CGFloat = -100
    private let maxSwipe: CGFloat = -150
    
    // Check if current user owns this comment
    private var isOwnComment: Bool {
        guard let currentUserId = authViewModel.currentUser?.id else { return false }
        return comment.userId == currentUserId
    }
    
    private var currentOffset: CGFloat {
        let total = swipeOffset + dragOffset
        // Limit swipe to left only and with resistance
        if total > 0 { return 0 }
        if total < maxSwipe {
            // Add rubber band effect past maxSwipe
            let overflow = total - maxSwipe
            return maxSwipe + overflow * 0.3
        }
        return total
    }
    
    private var showAction: Bool {
        currentOffset < actionThreshold / 2
    }
    
    private var actionOpacity: Double {
        let progress = min(1.0, abs(currentOffset) / abs(actionThreshold))
        return progress
    }
    
    var body: some View {
        ZStack(alignment: .trailing) {
            // Background action (Reply or Delete)
            HStack {
                Spacer()
                
                ZStack {
                    // Red for delete, Black for reply
                    isOwnComment ? Color.red : Color.black
                    
                    Text(isOwnComment ? "Radera" : "Svara")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                        .opacity(actionOpacity)
                        .scaleEffect(showAction ? 1.0 : 0.8)
                        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: showAction)
                }
                .frame(width: max(0, -currentOffset))
            }
            
            // Main comment content
            commentContent
                .offset(x: currentOffset)
                .gesture(
                    DragGesture(minimumDistance: 10)
                        .updating($dragOffset) { value, state, _ in
                            // Only allow horizontal swipes that are primarily leftward
                            if abs(value.translation.width) > abs(value.translation.height) {
                                state = value.translation.width
                            }
                        }
                        .onChanged { _ in
                            isDragging = true
                        }
                        .onEnded { value in
                            isDragging = false
                            let finalOffset = swipeOffset + value.translation.width
                            
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                                // If swiped past threshold, trigger action
                                if finalOffset < actionThreshold {
                                    // Haptic feedback
                                    let generator = UIImpactFeedbackGenerator(style: .medium)
                                    generator.impactOccurred()
                                    
                                    if isOwnComment {
                                        // Show delete confirmation
                                        showDeleteConfirmation = true
                                    } else {
                                        // Trigger reply action
                                        onReply()
                                    }
                                }
                                
                                // Always snap back to original position
                                swipeOffset = 0
                            }
                        }
                )
        }
        .clipped()
        .alert("Vill du radera?", isPresented: $showDeleteConfirmation) {
            Button("Avbryt", role: .cancel) { }
            Button("Radera", role: .destructive) {
                onDelete()
            }
        } message: {
            Text("Den här kommentaren kommer att tas bort permanent.")
        }
    }
    
    private var commentContent: some View {
        HStack(alignment: .top, spacing: 12) {
            avatarView
            
            VStack(alignment: .leading, spacing: 6) {
                // Name · Time
                HStack(spacing: 4) {
                    NavigationLink {
                        UserProfileView(userId: comment.userId)
                            .environmentObject(authViewModel)
                    } label: {
                        Text(comment.userName ?? "Användare")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.primary)
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    Text("·")
                        .foregroundColor(.secondary)
                    
                    Text(relativeDate(comment.createdAt))
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
                
                // Comment text with bold username if it's a reply
                commentTextView
                
                // Like button with count
                HStack(spacing: 4) {
                    Button(action: onLike) {
                        Image(systemName: comment.isLikedByCurrentUser ? "heart.fill" : "heart")
                            .font(.system(size: 14))
                            .foregroundColor(comment.isLikedByCurrentUser ? .red : .secondary)
                    }
                    
                    if comment.likeCount > 0 {
                        Text(comment.likeCount == 1 ? "1 like" : "\(comment.likeCount) likes")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.top, 2)
            }
            
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(.systemBackground))
    }
    
    private var commentTextView: some View {
        // Check if the comment starts with a username (reply pattern)
        let content = comment.content
        
        // Try to find username at the start of the comment
        if let spaceIndex = content.firstIndex(of: " "),
           content.first?.isLetter == true || content.first?.isNumber == true {
            let potentialUsername = String(content[..<spaceIndex])
            let restOfComment = String(content[content.index(after: spaceIndex)...])
            
            // Check if it looks like a username (no special chars except underscore/dot)
            let isUsername = potentialUsername.allSatisfy { 
                $0.isLetter || $0.isNumber || $0 == "_" || $0 == "." || $0 == "-"
            } && potentialUsername.count > 1
            
            if isUsername {
                return AnyView(
                    HStack(spacing: 0) {
                        Text(potentialUsername)
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(.primary)
                        Text(" " + restOfComment)
                            .font(.system(size: 15))
                            .foregroundColor(.primary)
                    }
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                )
            }
        }
        
        // Regular comment without username prefix
        return AnyView(
            Text(content)
                .font(.system(size: 15))
                .foregroundColor(.primary)
                .fixedSize(horizontal: false, vertical: true)
        )
    }
    
    private var avatarView: some View {
        NavigationLink {
            UserProfileView(userId: comment.userId)
                .environmentObject(authViewModel)
        } label: {
            Group {
                if let avatarUrl = comment.userAvatarUrl, !avatarUrl.isEmpty {
                    ProfileImage(url: avatarUrl, size: 40)
                } else {
                    Circle()
                        .fill(Color(.systemGray5))
                        .frame(width: 40, height: 40)
                        .overlay(
                            Image(systemName: "person.fill")
                                .foregroundColor(.gray)
                                .font(.system(size: 16))
                        )
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func relativeDate(_ isoString: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        var date = formatter.date(from: isoString)
        if date == nil {
            formatter.formatOptions = [.withInternetDateTime]
            date = formatter.date(from: isoString)
        }
        
        guard let parsedDate = date else { return isoString }
        
        let elapsed = Int(Date().timeIntervalSince(parsedDate))
        if elapsed < 60 { return "just nu" }
        let minutes = elapsed / 60
        if minutes < 60 { return "\(minutes) min sedan" }
        let hours = minutes / 60
        if hours < 24 { return "\(hours) timmar sedan" }
        let days = hours / 24
        if days < 7 { return "\(days) dagar sedan" }
        let weeks = days / 7
        if weeks < 4 { return "\(weeks) veckor sedan" }
        let months = days / 30
        return "\(months) månader sedan"
    }
}

@MainActor
class SocialViewModel: ObservableObject {
    // Shared instance for cache management
    static let shared = SocialViewModel()
    
    @Published var posts: [SocialWorkoutPost] = []
    @Published var isLoading: Bool = false
    private var isFetching = false
    private var currentUserId: String?
    private var hasLoggedFetchCancelled = false
    private var lastSuccessfulFetch: Date?
    private let refetchThreshold: TimeInterval = 30 // Don't refetch within 30 seconds
    
    // CRITICAL: Store the "known good" counts that should never be replaced with 0
    private var knownGoodCounts: [String: (likeCount: Int, commentCount: Int)] = [:]
    
    /// Invalidate cache to force fresh data on next fetch
    static func invalidateCache() {
        shared.lastSuccessfulFetch = nil
    }
    
    private struct AuthorMetadata {
        let name: String?
        let avatarUrl: String?
        let isPro: Bool?
    }
    private var authorMetadataCache: [String: AuthorMetadata] = [:]
    private var isFetchingAuthorMetadata = false

    private let isoFormatterWithMs: ISO8601DateFormatter = {
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
        if let d = isoFormatterWithMs.date(from: s) { return d }
        if let d = isoFormatterNoMs.date(from: s) { return d }
        return Date.distantPast
    }

    private func sortedByDateDesc(_ items: [SocialWorkoutPost]) -> [SocialWorkoutPost] {
        return items.sorted { lhs, rhs in
            let ld = parseDate(lhs.createdAt)
            let rd = parseDate(rhs.createdAt)
            return ld > rd
        }
    }
    
    func fetchSocialFeed(userId: String) {
        isLoading = true
        Task {
            do {
                let fetchedPosts = try await SocialService.shared.getSocialFeed(userId: userId)
                await MainActor.run {
                    self.posts = fetchedPosts
                    self.isLoading = false
                    self.prefetchAvatars(for: fetchedPosts)
                }
            } catch {
                print("Error fetching social feed: \(error)")
                await MainActor.run {
                    self.isLoading = false
                }
            }
        }
    }
    
    func fetchSocialFeedAsync(userId: String) async {
        currentUserId = userId
        
        // CRITICAL: Don't refetch if we just fetched recently (within 30 seconds)
        // This prevents data from being replaced when navigating back
        if let lastFetch = lastSuccessfulFetch, 
           Date().timeIntervalSince(lastFetch) < refetchThreshold,
           !posts.isEmpty {
            print("📱 Skipping refetch - fetched \(Int(Date().timeIntervalSince(lastFetch)))s ago")
            return
        }
        
        // Prevent duplicate fetches
        if isFetching { return }
        
        isFetching = true
        
        // STEP 1: Load from cache IMMEDIATELY and show it
        let cachedPosts = AppCacheManager.shared.getCachedSocialFeed(userId: userId, allowExpired: true)
        
        // Store known good counts from cache AND current posts
        if let cached = cachedPosts {
            for post in cached {
                let likeCount = post.likeCount ?? 0
                let commentCount = post.commentCount ?? 0
                // Only store if counts are non-zero
                if likeCount > 0 || commentCount > 0 {
                    knownGoodCounts[post.id] = (likeCount: likeCount, commentCount: commentCount)
                }
            }
        }
        // Also preserve current posts' counts
        for post in posts {
            let likeCount = post.likeCount ?? 0
            let commentCount = post.commentCount ?? 0
            if likeCount > 0 || commentCount > 0 {
                // Keep the higher value
                if let existing = knownGoodCounts[post.id] {
                    knownGoodCounts[post.id] = (
                        likeCount: max(existing.likeCount, likeCount),
                        commentCount: max(existing.commentCount, commentCount)
                    )
                } else {
                    knownGoodCounts[post.id] = (likeCount: likeCount, commentCount: commentCount)
                }
            }
        }
        
        // Show cached posts immediately if we have them
        if let cached = cachedPosts, !cached.isEmpty {
            // Apply known good counts to cached posts before showing
            let enhancedCached = applyKnownGoodCounts(to: cached)
            let sortedPosts = sortedByDateDesc(enhancedCached)
            
            // Prefetch first avatar URLs with HIGH priority and WAIT for completion
            let firstAvatarUrls = sortedPosts.prefix(3).compactMap { $0.userAvatarUrl }.filter { !$0.isEmpty }
            if !firstAvatarUrls.isEmpty {
                await ImageCacheManager.shared.prefetchHighPriority(urls: firstAvatarUrls)
            }
            
            // Now show posts - first avatars should be in cache
            posts = sortedPosts
            
            // Prefetch rest in background (non-blocking)
            Task.detached(priority: .background) {
                await ImageCacheManager.shared.prefetchHighPriority(urls: sortedPosts.dropFirst(3).prefix(7).compactMap { $0.userAvatarUrl }.filter { !$0.isEmpty })
            }
            
            isLoading = false
            Task { await self.enrichAuthorMetadataIfNeeded() }
        } else {
            isLoading = true
        }
        
        // STEP 2: Fetch from network in background
        do {
            var fetchedPosts = try await SocialService.shared.getReliableSocialFeed(userId: userId)
            
            // CRITICAL: Apply known good counts - NEVER show 0 if we know better
            fetchedPosts = applyKnownGoodCounts(to: fetchedPosts)
            
            // Update known good counts with any new non-zero values
            for post in fetchedPosts {
                let likeCount = post.likeCount ?? 0
                let commentCount = post.commentCount ?? 0
                if likeCount > 0 || commentCount > 0 {
                    if let existing = knownGoodCounts[post.id] {
                        knownGoodCounts[post.id] = (
                            likeCount: max(existing.likeCount, likeCount),
                            commentCount: max(existing.commentCount, commentCount)
                        )
                    } else {
                        knownGoodCounts[post.id] = (likeCount: likeCount, commentCount: commentCount)
                    }
                }
            }
            
            let sortedPosts = sortedByDateDesc(fetchedPosts)
            
            // Prefetch first avatar URLs with HIGH priority and WAIT for completion
            let firstAvatarUrls = sortedPosts.prefix(3).compactMap { $0.userAvatarUrl }.filter { !$0.isEmpty }
            if !firstAvatarUrls.isEmpty {
                await ImageCacheManager.shared.prefetchHighPriority(urls: firstAvatarUrls)
            }
            
            // Now show posts - first avatars should be in cache
            posts = sortedPosts
            
            // Prefetch rest in background (non-blocking)
            Task.detached(priority: .background) {
                await ImageCacheManager.shared.prefetchHighPriority(urls: sortedPosts.dropFirst(3).prefix(7).compactMap { $0.userAvatarUrl }.filter { !$0.isEmpty })
            }
            
            isLoading = false
            isFetching = false
            lastSuccessfulFetch = Date()
            
            // Persist to cache
            AppCacheManager.shared.saveSocialFeed(posts, userId: userId)
            Task { await self.enrichAuthorMetadataIfNeeded() }
            
        } catch is CancellationError {
            // Request was cancelled (user navigated away) - just keep current posts
            if !hasLoggedFetchCancelled {
                print("⚠️ Fetch was cancelled - keeping current posts")
                hasLoggedFetchCancelled = true
            }
            isLoading = false
            isFetching = false
            // Don't clear posts on cancellation!
            
        } catch {
            print("❌ Error fetching social feed: \(error)")
            // On error, keep existing posts
            isLoading = false
            isFetching = false
        }
    }
    
    /// Apply known good counts to posts - never let counts go to 0 if we know they should be higher
    private func applyKnownGoodCounts(to posts: [SocialWorkoutPost]) -> [SocialWorkoutPost] {
        return posts.map { post in
            let knownCounts = knownGoodCounts[post.id]
            let currentLikeCount = post.likeCount ?? 0
            let currentCommentCount = post.commentCount ?? 0
            
            // Use the higher of: current value OR known good value
            let finalLikeCount = max(currentLikeCount, knownCounts?.likeCount ?? 0)
            let finalCommentCount = max(currentCommentCount, knownCounts?.commentCount ?? 0)
            
            // Only create new post if we need to update counts
            if finalLikeCount != currentLikeCount || finalCommentCount != currentCommentCount {
                return SocialWorkoutPost(
                    id: post.id,
                    userId: post.userId,
                    activityType: post.activityType,
                    title: post.title,
                    description: post.description,
                    distance: post.distance,
                    duration: post.duration,
                    imageUrl: post.imageUrl,
                    userImageUrl: post.userImageUrl,
                    createdAt: post.createdAt,
                    userName: post.userName,
                    userAvatarUrl: post.userAvatarUrl,
                    userIsPro: post.userIsPro,
                    location: post.location,
                    strokes: post.strokes,
                    likeCount: finalLikeCount,
                    commentCount: finalCommentCount,
                    isLikedByCurrentUser: post.isLikedByCurrentUser,
                    splits: post.splits,
                    exercises: post.exercises,
                    pbExerciseName: post.pbExerciseName,
                    pbValue: post.pbValue
                )
            }
            return post
        }
    }
    
    func refreshSocialFeed(userId: String) async {
        // Preserve current posts' counts in known good counts
        for post in posts {
            let likeCount = post.likeCount ?? 0
            let commentCount = post.commentCount ?? 0
            if likeCount > 0 || commentCount > 0 {
                if let existing = knownGoodCounts[post.id] {
                    knownGoodCounts[post.id] = (
                        likeCount: max(existing.likeCount, likeCount),
                        commentCount: max(existing.commentCount, commentCount)
                    )
                } else {
                    knownGoodCounts[post.id] = (likeCount: likeCount, commentCount: commentCount)
                }
            }
        }
        
        do {
            var fetchedPosts = try await RetryHelper.shared.retry(maxRetries: 3, delay: 0.5) {
                return try await SocialService.shared.getReliableSocialFeed(userId: userId)
            }
            
            if !fetchedPosts.isEmpty {
                // Apply known good counts - NEVER let counts go to 0
                fetchedPosts = applyKnownGoodCounts(to: fetchedPosts)
                
                // Update known good counts with new non-zero values
                for post in fetchedPosts {
                    let likeCount = post.likeCount ?? 0
                    let commentCount = post.commentCount ?? 0
                    if likeCount > 0 || commentCount > 0 {
                        if let existing = knownGoodCounts[post.id] {
                            knownGoodCounts[post.id] = (
                                likeCount: max(existing.likeCount, likeCount),
                                commentCount: max(existing.commentCount, commentCount)
                            )
                        } else {
                            knownGoodCounts[post.id] = (likeCount: likeCount, commentCount: commentCount)
                        }
                    }
                }
                
                let sorted = sortedByDateDesc(fetchedPosts)
                
                // Prefetch first 5 avatars with HIGH priority BEFORE showing posts
                let firstAvatarUrls = sorted.prefix(5).compactMap { $0.userAvatarUrl }.filter { !$0.isEmpty }
                await ImageCacheManager.shared.prefetchHighPriority(urls: firstAvatarUrls)
                
                posts = sorted
                prefetchAvatars(for: posts) // Prefetch rest in background
                lastSuccessfulFetch = Date()
                AppCacheManager.shared.saveSocialFeed(sorted, userId: userId)
                Task { await self.enrichAuthorMetadataIfNeeded() }
            } else {
                print("⚠️ Refresh returned empty array, keeping existing posts")
            }
        } catch is CancellationError {
            print("⚠️ Refresh was cancelled - keeping current posts")
            // Don't modify posts on cancellation
        } catch {
            print("❌ Error refreshing social feed: \(error)")
            // On error, keep existing posts with their counts intact
        }
    }

    private var lastUserPostsLoad: Date?
    private var lastUserPostsUserId: String?
    private let userPostsThrottle: TimeInterval = 30
    
    func loadPostsForUser(userId targetUserId: String, viewerId: String, force: Bool = false) async {
        currentUserId = viewerId
        
        // Use cached data if recent and same user
        if !force,
           let lastLoad = lastUserPostsLoad,
           let lastUserId = lastUserPostsUserId,
           lastUserId == targetUserId,
           Date().timeIntervalSince(lastLoad) < userPostsThrottle,
           !posts.isEmpty {
            return
        }
        
        // Only show loading if we have no data
        if posts.isEmpty {
            isLoading = true
        }
        
        do {
            let fetchedPosts = try await SocialService.shared.getPostsForUser(targetUserId: targetUserId, viewerId: viewerId)
            
            // Prefetch first 5 avatars with HIGH priority BEFORE showing posts
            let firstAvatarUrls = fetchedPosts.prefix(5).compactMap { $0.userAvatarUrl }.filter { !$0.isEmpty }
            await ImageCacheManager.shared.prefetchHighPriority(urls: firstAvatarUrls)
            
            await MainActor.run {
                self.posts = fetchedPosts
                self.isLoading = false
                self.lastUserPostsLoad = Date()
                self.lastUserPostsUserId = targetUserId
                self.prefetchAvatars(for: fetchedPosts)
            }
        } catch is CancellationError {
            await MainActor.run { self.isLoading = false }
        } catch {
            print("❌ Error loading posts for user \(targetUserId): \(error)")
            await MainActor.run { self.isLoading = false }
        }
    }
    
    func refreshPostsForUser(userId targetUserId: String, viewerId: String) async {
        await loadPostsForUser(userId: targetUserId, viewerId: viewerId, force: true)
    }
    
    private func enrichAuthorMetadataIfNeeded() async {
        if isFetchingAuthorMetadata { return }
        
        let missingAuthorIds = Set(posts.compactMap { post -> String? in
            let hasName = !(post.userName?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
            let hasAvatar = !(post.userAvatarUrl?.isEmpty ?? true)
            let hasProFlag = post.userIsPro != nil
            return (hasName && hasAvatar && hasProFlag) ? nil : post.userId
        })
        
        guard !missingAuthorIds.isEmpty else { return }
        
        isFetchingAuthorMetadata = true
        defer { isFetchingAuthorMetadata = false }
        
        var fetchedMetadata: [String: AuthorMetadata] = [:]
        
        for userId in missingAuthorIds {
            if let cached = authorMetadataCache[userId] {
                fetchedMetadata[userId] = cached
                continue
            }
            
            if let profile = try? await ProfileService.shared.fetchUserProfile(userId: userId) {
                let metadata = AuthorMetadata(
                    name: profile.name,
                    avatarUrl: profile.avatarUrl,
                    isPro: profile.isProMember
                )
                authorMetadataCache[userId] = metadata
                fetchedMetadata[userId] = metadata
            }
        }
        
        guard !fetchedMetadata.isEmpty else { return }
        
        for index in posts.indices {
            let post = posts[index]
            guard let metadata = fetchedMetadata[post.userId] else { continue }
            
            posts[index] = SocialWorkoutPost(
                id: post.id,
                userId: post.userId,
                activityType: post.activityType,
                title: post.title,
                description: post.description,
                distance: post.distance,
                duration: post.duration,
                imageUrl: post.imageUrl,
                userImageUrl: post.userImageUrl,
                createdAt: post.createdAt,
                userName: metadata.name ?? post.userName,
                userAvatarUrl: metadata.avatarUrl ?? post.userAvatarUrl,
                userIsPro: post.userIsPro ?? metadata.isPro,
                location: post.location,
                strokes: post.strokes,
                likeCount: post.likeCount,
                commentCount: post.commentCount,
                isLikedByCurrentUser: post.isLikedByCurrentUser,
                splits: post.splits,
                exercises: post.exercises,
                pbExerciseName: post.pbExerciseName,
                pbValue: post.pbValue
            )
        }
        
        posts = sortedByDateDesc(posts)
        if let uid = currentUserId {
            AppCacheManager.shared.saveSocialFeed(posts, userId: uid)
        }
    }
    
    private func prefetchAvatars(for posts: [SocialWorkoutPost]) {
        guard !posts.isEmpty else { return }
        let urls = posts.compactMap { $0.userAvatarUrl }.filter { !$0.isEmpty }
        guard !urls.isEmpty else { return }
        
        // Prefetch first 5 with high priority, rest with normal priority
        Task {
            await ImageCacheManager.shared.prefetchHighPriority(urls: Array(urls.prefix(5)))
        }
        
        // Prefetch the rest with normal priority
        if urls.count > 5 {
            ImageCacheManager.shared.prefetch(urls: Array(urls.dropFirst(5)))
        }
    }
    
    func updatePostLikeStatus(postId: String, isLiked: Bool, likeCount: Int) {
        // ALWAYS update known good counts when user explicitly likes/unlikes
        if likeCount > 0 {
            if let existing = knownGoodCounts[postId] {
                knownGoodCounts[postId] = (likeCount: likeCount, commentCount: existing.commentCount)
            } else {
                knownGoodCounts[postId] = (likeCount: likeCount, commentCount: 0)
            }
        }
        
        if let index = posts.firstIndex(where: { $0.id == postId }) {
            var updatedPost = posts[index]
            updatedPost = SocialWorkoutPost(
                id: updatedPost.id,
                userId: updatedPost.userId,
                activityType: updatedPost.activityType,
                title: updatedPost.title,
                description: updatedPost.description,
                distance: updatedPost.distance,
                duration: updatedPost.duration,
                imageUrl: updatedPost.imageUrl,
                userImageUrl: updatedPost.userImageUrl,
                createdAt: updatedPost.createdAt,
                userName: updatedPost.userName,
                userAvatarUrl: updatedPost.userAvatarUrl,
                userIsPro: updatedPost.userIsPro,
                location: updatedPost.location,
                strokes: updatedPost.strokes,
                likeCount: likeCount,
                commentCount: updatedPost.commentCount,
                isLikedByCurrentUser: isLiked,
                splits: updatedPost.splits,
                exercises: updatedPost.exercises,
                pbExerciseName: updatedPost.pbExerciseName,
                pbValue: updatedPost.pbValue
            )
            posts[index] = updatedPost
            if let uid = currentUserId {
                AppCacheManager.shared.saveSocialFeed(posts, userId: uid)
            }
        }
    }
    
    func updatePostCommentCount(postId: String, commentCount: Int) {
        // ALWAYS update known good counts when comment is added
        if commentCount > 0 {
            if let existing = knownGoodCounts[postId] {
                knownGoodCounts[postId] = (likeCount: existing.likeCount, commentCount: commentCount)
            } else {
                knownGoodCounts[postId] = (likeCount: 0, commentCount: commentCount)
            }
        }
        
        if let index = posts.firstIndex(where: { $0.id == postId }) {
            var updatedPost = posts[index]
            updatedPost = SocialWorkoutPost(
                id: updatedPost.id,
                userId: updatedPost.userId,
                activityType: updatedPost.activityType,
                title: updatedPost.title,
                description: updatedPost.description,
                distance: updatedPost.distance,
                duration: updatedPost.duration,
                imageUrl: updatedPost.imageUrl,
                userImageUrl: updatedPost.userImageUrl,
                createdAt: updatedPost.createdAt,
                userName: updatedPost.userName,
                userAvatarUrl: updatedPost.userAvatarUrl,
                userIsPro: updatedPost.userIsPro,
                location: updatedPost.location,
                strokes: updatedPost.strokes,
                likeCount: updatedPost.likeCount,
                commentCount: commentCount,
                isLikedByCurrentUser: updatedPost.isLikedByCurrentUser,
                splits: updatedPost.splits,
                exercises: updatedPost.exercises,
                pbExerciseName: updatedPost.pbExerciseName,
                pbValue: updatedPost.pbValue
            )
            posts[index] = updatedPost
            if let uid = currentUserId {
                AppCacheManager.shared.saveSocialFeed(posts, userId: uid)
            }
        }
    }
    
    func removePost(postId: String) {
        posts.removeAll { $0.id == postId }
        if let uid = currentUserId {
            AppCacheManager.shared.saveSocialFeed(posts, userId: uid)
        }
    }
}

struct CommentThread: Identifiable {
    let id: String
    var comment: PostComment
    var replies: [PostComment]
}

class CommentsViewModel: ObservableObject {
    @Published private(set) var threads: [CommentThread] = []
    @Published private(set) var isLoading = false
    private var postId: String = ""
    
    var totalCommentCount: Int {
        threads.reduce(0) { $0 + 1 + $1.replies.count }
    }
    
    func fetchComments(postId: String, currentUserId: String?) {
        Task {
            await fetchCommentsAsync(postId: postId, currentUserId: currentUserId)
        }
    }
    
    func fetchCommentsAsync(postId: String, currentUserId: String?) async {
        await MainActor.run {
            if self.postId != postId {
                self.threads = []
            }
            self.isLoading = true
        }
        do {
            let fetchedComments = try await SocialService.shared.getPostComments(postId: postId, currentUserId: currentUserId)
            await MainActor.run {
                self.postId = postId
                self.threads = Self.buildThreads(from: fetchedComments)
                self.isLoading = false
            }
        } catch {
            print("Error fetching comments: \(error)")
            await MainActor.run {
                self.isLoading = false
            }
        }
    }
    
    func appendComment(_ comment: PostComment) {
        if comment.parentCommentId == nil {
            threads.append(CommentThread(id: comment.id, comment: comment, replies: []))
        } else {
            insertReply(comment)
        }
    }
    
    func removeComment(withId id: String) {
        if let index = threads.firstIndex(where: { $0.id == id }) {
            threads.remove(at: index)
            return
        }
        for idx in threads.indices {
            if let replyIndex = threads[idx].replies.firstIndex(where: { $0.id == id }) {
                threads[idx].replies.remove(at: replyIndex)
                return
            }
        }
    }
    
    func toggleLike(for commentId: String, currentUserId: String?) {
        guard let userId = currentUserId else { return }
        guard var target = findComment(by: commentId) else { return }
        let willLike = !target.isLikedByCurrentUser
        
        updateComment(id: commentId) { comment in
            comment.isLikedByCurrentUser.toggle()
            comment.likeCount = max(0, comment.likeCount + (comment.isLikedByCurrentUser ? 1 : -1))
        }
        
        Task {
            do {
                if willLike {
                    try await SocialService.shared.likeComment(commentId: commentId, userId: userId)
                } else {
                    try await SocialService.shared.unlikeComment(commentId: commentId, userId: userId)
                }
            } catch {
                print("Error toggling comment like: \(error)")
                await MainActor.run {
                    self.updateComment(id: commentId) { comment in
                        comment.isLikedByCurrentUser.toggle()
                        comment.likeCount = max(0, comment.likeCount + (comment.isLikedByCurrentUser ? 1 : -1))
                    }
                }
            }
        }
    }
    
    private func insertReply(_ reply: PostComment) {
        if let parentIndex = threads.firstIndex(where: { $0.id == reply.parentCommentId }) {
            threads[parentIndex].replies.append(reply)
            threads[parentIndex].replies.sort { $0.createdAt < $1.createdAt }
            return
        }
        for idx in threads.indices {
            if threads[idx].replies.contains(where: { $0.id == reply.parentCommentId }) {
                threads[idx].replies.append(reply)
                threads[idx].replies.sort { $0.createdAt < $1.createdAt }
                return
            }
        }
        threads.append(CommentThread(id: reply.id, comment: reply, replies: []))
    }
    
    private func findComment(by id: String) -> PostComment? {
        if let thread = threads.first(where: { $0.id == id }) {
            return thread.comment
        }
        for thread in threads {
            if let reply = thread.replies.first(where: { $0.id == id }) {
                return reply
            }
        }
        return nil
    }
    
    private func updateComment(id: String, mutate: (inout PostComment) -> Void) {
        if let index = threads.firstIndex(where: { $0.id == id }) {
            mutate(&threads[index].comment)
            return
        }
        for idx in threads.indices {
            if let replyIndex = threads[idx].replies.firstIndex(where: { $0.id == id }) {
                mutate(&threads[idx].replies[replyIndex])
                return
            }
        }
    }
    
    private static func buildThreads(from comments: [PostComment]) -> [CommentThread] {
        let groupedReplies = Dictionary(grouping: comments.filter { $0.parentCommentId != nil }) { $0.parentCommentId! }
        let roots = comments.filter { $0.parentCommentId == nil }
        return roots.map { root in
            let replies = (groupedReplies[root.id] ?? []).sorted { $0.createdAt < $1.createdAt }
            return CommentThread(id: root.id, comment: root, replies: replies)
        }
    }
}

// MARK: - Gym Exercises List View
struct GymExercisesListView: View {
    let exercises: [GymExercisePost]
    let userImage: String?
    @State private var currentPage = 0
    
    private var hasUserImage: Bool {
        if let userImage, !userImage.isEmpty { return true }
        return false
    }
    
    var body: some View {
        RoundedRectangle(cornerRadius: 20, style: .continuous)
            .fill(Color(.systemBackground))
            .shadow(color: Color.black.opacity(0.08), radius: 12, x: 0, y: 6)
            .overlay(
                TabView(selection: $currentPage) {
                    if hasUserImage {
                        userImagePage
                            .tag(0)
                        exercisesListPage
                            .tag(1)
                    } else {
                        exercisesListPage
                            .tag(0)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: hasUserImage ? .automatic : .never))
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            )
            .frame(height: hasUserImage ? 420 : 380)
            .padding(.horizontal, 16)
    }

    private var exercisesListPage: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(Array(exercises.enumerated()), id: \.offset) { index, exercise in
                    exerciseCard(exercise: exercise, isLast: index == exercises.count - 1)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
    }
    
    private func exerciseCard(exercise: GymExercisePost, isLast: Bool) -> some View {
        HStack(alignment: .top, spacing: 12) {
            // Exercise GIF/Image
            if let exerciseId = exercise.id {
                ExerciseGIFView(exerciseId: exerciseId, gifUrl: nil)
                    .frame(width: 80, height: 80)
                    .cornerRadius(8)
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(.systemGray5))
                    .frame(width: 80, height: 80)
                    .overlay(
                        Image(systemName: "dumbbell.fill")
                            .foregroundColor(.gray)
                    )
            }
            
            // Exercise details
            VStack(alignment: .leading, spacing: 6) {
                Text(exercise.name)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)
                    .lineLimit(2)
                
                Text("\(exercise.sets) sets")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                
                // Show all sets in a compact format
                ForEach(0..<exercise.sets, id: \.self) { setIndex in
                    if setIndex < exercise.kg.count && setIndex < exercise.reps.count {
                        HStack(spacing: 4) {
                            Text("\(setIndex + 1).")
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                                .frame(width: 20, alignment: .leading)
                            
                            Text("\(Int(exercise.kg[setIndex])) kg")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.primary)
                            
                            Text("×")
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                            
                            Text("\(exercise.reps[setIndex]) reps")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.primary)
                        }
                    }
                }
                
                // Show notes if available
                if let notes = exercise.notes, !notes.isEmpty {
                    Text(notes)
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                        .italic()
                        .padding(.top, 4)
                }
            }
            
            Spacer()
        }
        .padding(12)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
    
    @ViewBuilder
    private var userImagePage: some View {
        GeometryReader { geometry in
            if let userImage {
                FullFrameAsyncImage(path: userImage, height: geometry.size.height)
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .overlay(
                        LinearGradient(
                            colors: [Color.black.opacity(0.2), Color.black.opacity(0.05)],
                            startPoint: .bottom,
                            endPoint: .top
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    )
                    .overlay(
                        Text(userImage.contains("live_") ? "Up&Down Live" : "Din bild")
                            .font(.system(size: 14, weight: .semibold))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.black.opacity(0.5))
                            .foregroundColor(.white)
                            .cornerRadius(8)
                            .padding(16),
                        alignment: .bottomLeading
                    )
            }
        }
    }
}

// MARK: - Full Frame Async Image (for gym post images)
struct FullFrameAsyncImage: View {
    let path: String
    let height: CGFloat
    @State private var image: UIImage?
    @State private var isLoading = true
    @State private var loadFailed = false
    
    // Check if this is a live photo (has selfie overlay on left side)
    private var isLivePhoto: Bool {
        path.contains("live_")
    }
    
    var body: some View {
        Group {
            if let image = image {
                GeometryReader { geometry in
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: geometry.size.width, height: height)
                        // For live photos, align to leading edge so selfie is visible
                        .frame(width: geometry.size.width, height: height, alignment: isLivePhoto ? .leading : .center)
                        .clipped()
                }
                .frame(height: height)
            } else if isLoading {
                Rectangle()
                    .fill(Color(.systemGray5))
                    .frame(height: height)
                    .overlay(ProgressView().scaleEffect(0.8))
            } else if loadFailed {
                Rectangle()
                    .fill(Color(.systemGray6))
                    .frame(height: height)
                    .overlay(
                        VStack(spacing: 8) {
                            Image(systemName: "photo")
                                .foregroundColor(.gray)
                                .font(.system(size: 28))
                        }
                    )
            } else {
                Rectangle()
                    .fill(Color(.systemGray6))
                    .frame(height: height)
            }
        }
        .task {
            await loadImage()
        }
    }
    
    private func loadImage() async {
        guard !path.isEmpty else {
            loadFailed = true
            isLoading = false
            return
        }
        
        // Check cache first
        if let cached = ImageCacheManager.shared.getImage(for: path) {
            image = cached
            isLoading = false
            return
        }
        
        // Try to load from URL
        if let url = URL(string: path) {
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                if let downloadedImage = UIImage(data: data) {
                    ImageCacheManager.shared.setImage(downloadedImage, for: path)
                    await MainActor.run {
                        self.image = downloadedImage
                        self.isLoading = false
                    }
                    return
                }
            } catch {
                print("❌ Failed to load image: \(error)")
            }
        }
        
        // Try Supabase storage
        do {
            let filename = path.contains("/") ? String(path.split(separator: "/").last ?? "") : path
            let signedURL = try await SupabaseConfig.supabase.storage
                .from("workout-images")
                .createSignedURL(path: filename, expiresIn: 3600)
            
            let (data, _) = try await URLSession.shared.data(from: signedURL)
            if let downloadedImage = UIImage(data: data) {
                ImageCacheManager.shared.setImage(downloadedImage, for: path)
                await MainActor.run {
                    self.image = downloadedImage
                    self.isLoading = false
                }
                return
            }
        } catch {
            print("❌ Supabase image load failed: \(error)")
        }
        
        await MainActor.run {
            loadFailed = true
            isLoading = false
        }
    }
}

// MARK: - Empty State User Card

struct EmptyStateUserCard: View {
    let user: UserSearchResult
    let isFollowing: Bool
    let onFollowToggle: () -> Void
    @State private var isProcessing = false
    
    var body: some View {
        VStack(spacing: 12) {
            NavigationLink(destination: UserProfileView(userId: user.id)) {
                ProfileImage(url: user.avatarUrl, size: 70)
            }
            
            Text(user.name)
                .font(.system(size: 15, weight: .semibold))
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
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(isFollowing ? .secondary : .white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(isFollowing ? Color(.systemGray5) : Color.primary)
                    .cornerRadius(10)
            }
            .disabled(isProcessing)
        }
        .padding(16)
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.08), radius: 4, x: 0, y: 2)
    }
}

// MARK: - Invite Friends Sheet

struct InviteFriendsSheet: View {
    @Environment(\.dismiss) private var dismiss
    
    private let appStoreLink = "https://apps.apple.com/se/app/up-down/id6749190145?l=en-GB" // App Store link
    private let inviteMessage = "Utmana mig i Zonkriget (:"
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 12) {
                    Image(systemName: "person.2.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.primary)
                    
                    Text("Bjud in dina vänner")
                        .font(.system(size: 24, weight: .bold))
                    
                    Text("Träna tillsammans med dina vänner och tävla om territorier i Zonkriget!")
                        .font(.system(size: 15))
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
                .padding(.top, 40)
                
                Spacer()
                
                // Share options
                VStack(spacing: 16) {
                    // Share via Messages/SMS
                    ShareLink(
                        item: URL(string: appStoreLink)!,
                        subject: Text("Träna med mig!"),
                        message: Text(inviteMessage)
                    ) {
                        HStack(spacing: 12) {
                            Image(systemName: "message.fill")
                                .font(.system(size: 20))
                            Text("Dela via meddelande")
                                .font(.system(size: 16, weight: .semibold))
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                        .foregroundColor(.primary)
                        .padding(16)
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(12)
                    }
                    
                    // Copy link
                    Button {
                        UIPasteboard.general.string = appStoreLink
                        // Visual feedback could be added here
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "link")
                                .font(.system(size: 20))
                            Text("Kopiera länk")
                                .font(.system(size: 16, weight: .semibold))
                            Spacer()
                            Image(systemName: "doc.on.doc")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                        .foregroundColor(.primary)
                        .padding(16)
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(12)
                    }
                    
                    // Share via other apps
                    ShareLink(item: URL(string: appStoreLink)!) {
                        HStack(spacing: 12) {
                            Image(systemName: "square.and.arrow.up")
                                .font(.system(size: 20))
                            Text("Dela via andra appar")
                                .font(.system(size: 16, weight: .semibold))
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                        .foregroundColor(.primary)
                        .padding(16)
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(12)
                    }
                }
                .padding(.horizontal, 20)
                
                Spacer()
                
                // Info text
                Text("Ju fler vänner, desto roligare träning! 🎉")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                    .padding(.bottom, 20)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Stäng") {
                        dismiss()
                    }
                    .foregroundColor(.primary)
                }
            }
        }
    }
}

// MARK: - External Activity Card
// A clean, Strava-style card for activities tracked with external devices
struct ExternalActivityCard: View {
    let post: SocialWorkoutPost
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Title section
            Text(post.title)
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(.primary)
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 12)
            
            // Stats row - Strava style (3 columns)
            HStack(spacing: 0) {
                // Distance
                if let distance = post.distance, distance > 0 {
                    statItem(
                        title: "Distans",
                        value: post.isSwimmingPost ? "\(Int(distance * 1000)) m" : String(format: "%.2f km", distance)
                    )
                }
                
                // Elevation Gain
                if let elevation = post.elevationGain, elevation > 0 {
                    statItem(title: "Höjdmeter", value: "\(Int(elevation)) m")
                }
                
                // Time
                if let duration = post.duration, duration > 0 {
                    statItem(title: "Tid", value: formatTimeStrava(duration))
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
            
            // Map image if available
            if let imageUrl = post.imageUrl, !imageUrl.isEmpty {
                AsyncImage(url: URL(string: imageUrl)) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(height: 220)
                            .clipped()
                            .cornerRadius(12)
                    case .failure:
                        // Show activity-specific placeholder
                        activityPlaceholder
                    case .empty:
                        ProgressView()
                            .frame(height: 220)
                    @unknown default:
                        activityPlaceholder
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            } else {
                // Show a nice activity-specific placeholder
                activityPlaceholder
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
            }
        }
    }
    
    private var activityPlaceholder: some View {
        ZStack {
            // Gradient background based on activity
            LinearGradient(
                colors: [activityColor.opacity(0.3), activityColor.opacity(0.1)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            VStack(spacing: 12) {
                Image(systemName: activityIcon)
                    .font(.system(size: 50, weight: .light))
                    .foregroundColor(activityColor)
                
                if let deviceName = post.deviceName, !deviceName.isEmpty {
                    HStack(spacing: 6) {
                        Image(systemName: deviceIcon)
                            .font(.system(size: 14))
                        Text(deviceName)
                            .font(.system(size: 15, weight: .medium))
                    }
                    .foregroundColor(activityColor.opacity(0.8))
                }
            }
        }
        .frame(height: 160)
        .cornerRadius(12)
    }
    
    private var deviceIcon: String {
        guard let source = post.source?.lowercased() else { return "applewatch" }
        switch source {
        case "zwift": return "laptopcomputer"
        case "garmin": return "applewatch"
        case "apple": return "applewatch"
        case "fitbit": return "applewatch"
        case "polar": return "applewatch"
        case "wahoo": return "bicycle"
        default: return "applewatch"
        }
    }
    
    private var activityIcon: String {
        switch post.activityType {
        case "Löpning", "Löppass": return "figure.run"
        case "Simning", "Simpass": return "figure.pool.swim"
        case "Cykling", "Cykelpass": return "figure.outdoor.cycle"
        case "Gympass": return "figure.strengthtraining.traditional"
        case "Promenad": return "figure.walk"
        case "Vandring": return "mountain.2.fill"
        case "Yoga", "Yogapass": return "figure.yoga"
        case "Rodd", "Roddpass": return "figure.rower"
        case "Golf", "Golfrunda": return "flag.fill"
        case "Skidåkning", "Skidpass": return "snowflake"
        case "Cardio", "Cardiopass": return "heart.fill"
        default: return "figure.walk"
        }
    }
    
    private var activityColor: Color {
        switch post.activityType {
        case "Löpning", "Löppass": return .orange
        case "Simning", "Simpass": return .blue
        case "Cykling", "Cykelpass": return .green
        case "Gympass": return .purple
        case "Promenad": return .teal
        case "Vandring": return .brown
        case "Yoga", "Yogapass": return .pink
        case "Rodd", "Roddpass": return .cyan
        case "Golf", "Golfrunda": return .green
        case "Skidåkning", "Skidpass": return .blue
        case "Cardio", "Cardiopass": return .red
        default: return .gray
        }
    }
    
    private func statItem(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 13))
                .foregroundColor(.secondary)
            Text(value)
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private func formatTimeStrava(_ seconds: Int) -> String {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        let secs = seconds % 60
        
        if hours > 0 {
            return String(format: "%dh %02dm", hours, minutes)
        } else if minutes > 0 {
            return String(format: "%dm %02ds", minutes, secs)
        } else {
            return String(format: "%ds", secs)
        }
    }
}

#Preview {
    SocialView()
        .environmentObject(AuthViewModel())
}
