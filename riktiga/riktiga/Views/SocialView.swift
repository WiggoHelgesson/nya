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
        if socialViewModel.isLoading && socialViewModel.posts.isEmpty {
            loadingView
        } else if socialViewModel.posts.isEmpty {
            emptyStateView
        } else {
            scrollContent
        }
    }
    
    private var loadingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .tint(AppColors.brandBlue)
                .scaleEffect(1.5)
            Text("Laddar inlägg...")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.gray)
        }
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
    }
    
    private var scrollContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                HomeHeaderView()
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)
                
                tabSelector
                
                Divider()
                
                if selectedTab == .feed {
                    feedContent
                } else {
                    newsContent
                }
            }
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
                                    
                                    if index == 1, shouldShowRecommendedFriendsSection {
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
                VStack(spacing: 16) {
                    ProgressView()
                        .padding(.top, 40)
                    Text("Laddar nyheter...")
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                }
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
                    HStack {
                        Spacer()
                        ProgressView()
                            .padding()
                        Spacer()
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
    @State private var showComments = false
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

                Button(action: { showComments = true }) {
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
        .sheet(isPresented: $showComments) {
            CommentsView(postId: post.id, postOwnerId: post.userId) {
                commentCount += 1
                onCommentCountChanged(post.id, commentCount)
            }
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
                
                Text(formatDate(post.createdAt))
                    .font(.system(size: 13))
                    .foregroundColor(.gray)
                
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
        } else {
            // Swipeable images (route and user image)
            SwipeableImageView(routeImage: post.imageUrl, userImage: post.userImageUrl)
                .onTapGesture {
                    onOpenDetail(post)
                }
        }
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
                        statColumn(title: "Distans", value: String(format: "%.2f km", distance))
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
                        statColumn(title: "Tempo", value: pace)
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
            } else if calendar.isDateInYesterday(date) {
                return "Igår"
            } else {
                let dateFormatter = DateFormatter()
                dateFormatter.dateStyle = .short
                return dateFormatter.string(from: date)
            }
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
            
            Text("\(commentCount) kommentarer")
                .font(.system(size: 14))
                .foregroundColor(.gray)
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
    let postId: String
    let postOwnerId: String
    let onCommentAdded: (() -> Void)?
    @StateObject private var commentsViewModel = CommentsViewModel()
    @State private var newComment = ""
    @State private var replyTarget: PostComment?
    @State private var isSending = false
    @EnvironmentObject var authViewModel: AuthViewModel
    @Environment(\.dismiss) private var dismiss
    @Namespace private var bottomID
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Comments list
                ScrollViewReader { scrollProxy in
                    ScrollView {
                        LazyVStack(spacing: 16) {
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
                                                onReply: { replyTarget = thread.comment }
                                            )
                                            .environmentObject(authViewModel)
                                            ForEach(thread.replies) { reply in
                                                CommentRow(
                                                    comment: reply,
                                                    isReply: true,
                                                    onLike: { commentsViewModel.toggleLike(for: reply.id, currentUserId: authViewModel.currentUser?.id) },
                                                    onReply: { replyTarget = reply }
                                                )
                                                .environmentObject(authViewModel)
                                            }
                                        }
                                        
                                        Color.clear
                                            .frame(height: 1)
                                            .id(bottomID)
                                    }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                                .refreshable {
                                    await reloadComments()
                                }
                    }
                    .onChange(of: commentsViewModel.totalCommentCount) { _ in
                        withAnimation {
                            scrollProxy.scrollTo(bottomID, anchor: .bottom)
                        }
                    }
                }
                
                // Add comment section
                VStack(spacing: 12) {
                    Divider()
                    
                    if let replyTarget {
                        HStack {
                            Text("Svara på \(replyTarget.userName ?? "användare")")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.gray)
                            Spacer()
                            Button("Avbryt") {
                                self.replyTarget = nil
                            }
                            .font(.system(size: 13, weight: .semibold))
                        }
                        .padding(.horizontal, 16)
                    }
                    
                    HStack(spacing: 12) {
                        TextField("Skriv en kommentar...", text: $newComment)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                        
                        Button("Skicka") {
                            addComment()
                        }
                        .disabled(isSending || newComment.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                    .padding(16)
                }
                .background(Color(.systemBackground))
            }
            .navigationTitle("Kommentarer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Stäng") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                Task {
                    await reloadComments()
                }
            }
        }
    }
    
    private func addComment() {
        guard let userId = authViewModel.currentUser?.id,
              !newComment.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        let commentText = newComment.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Create optimistic comment for immediate display
        let optimisticComment = PostComment(
            postId: postId,
            userId: userId,
            content: commentText,
            userName: authViewModel.currentUser?.name,
            userAvatarUrl: authViewModel.currentUser?.avatarUrl,
            parentCommentId: replyTarget?.id
        )
        
        // Add to UI immediately
        commentsViewModel.appendComment(optimisticComment)
        newComment = ""
        
        isSending = true
        Task {
            do {
                try await SocialService.shared.addComment(
                    postId: postId,
                    userId: userId,
                    content: commentText,
                    parentCommentId: replyTarget?.id,
                    postOwnerId: postOwnerId
                )
                print("✅ Comment added successfully")
                
                await reloadComments()
                await MainActor.run {
                    onCommentAdded?()
                    replyTarget = nil
                }
            } catch {
                print("❌ Error adding comment: \(error)")
                // Remove optimistic comment on error
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
        print("🔄 Force reloading comments from database for post: \(postId)")
        await commentsViewModel.fetchCommentsAsync(postId: postId, currentUserId: authViewModel.currentUser?.id)
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
        .multilineTextAlignment(.center)
    }
}

struct CommentRow: View {
    let comment: PostComment
    let isReply: Bool
    let onLike: () -> Void
    let onReply: () -> Void
    @EnvironmentObject private var authViewModel: AuthViewModel
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            avatarView
            
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    NavigationLink {
                        UserProfileView(userId: comment.userId)
                            .environmentObject(authViewModel)
                    } label: {
                        Text(comment.userName ?? "Användare")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.primary)
                    }
                    .buttonStyle(PlainButtonStyle())
                    Text(relativeDate(comment.createdAt))
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                
                Text(comment.content)
                    .font(.system(size: 15))
                    .foregroundColor(.primary)
                
                HStack(spacing: 16) {
                    Button(action: onLike) {
                        HStack(spacing: 4) {
                            Image(systemName: comment.isLikedByCurrentUser ? "heart.fill" : "heart")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(comment.isLikedByCurrentUser ? .red : .secondary)
                            if comment.likeCount > 0 {
                                Text(comment.likeCount == 1 ? "1 like" : "\(comment.likeCount) likes")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(.secondary)
                            } else {
                                Text("Like")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    
                    Button(action: onReply) {
                        Text("Svara")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(14)
            .background(Color(.secondarySystemBackground))
            .cornerRadius(16)
            
            Spacer()
        }
        .padding(.leading, isReply ? 44 : 0)
    }
    
    private var avatarView: some View {
        NavigationLink {
            UserProfileView(userId: comment.userId)
                .environmentObject(authViewModel)
        } label: {
            Group {
                if let avatarUrl = comment.userAvatarUrl, !avatarUrl.isEmpty {
                    ProfileImage(url: avatarUrl, size: 36)
                } else {
                    Circle()
                        .fill(Color(.systemGray5))
                        .frame(width: 36, height: 36)
                        .overlay(
                            Image(systemName: "person.fill")
                                .foregroundColor(.gray)
                                .font(.system(size: 15))
                        )
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
        .padding(.top, 4)
    }
    
    private func relativeDate(_ isoString: String) -> String {
        let formatter = ISO8601DateFormatter()
        guard let date = formatter.date(from: isoString) else { return isoString }
        let elapsed = Int(Date().timeIntervalSince(date))
        if elapsed < 60 { return "Just nu" }
        let minutes = elapsed / 60
        if minutes < 60 { return "\(minutes)m sedan" }
        let hours = minutes / 60
        if hours < 24 { return "\(hours)h sedan" }
        let days = hours / 24
        return "\(days)d sedan"
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
                    .overlay(
                        LinearGradient(
                            colors: [Color.black.opacity(0.2), Color.black.opacity(0.05)],
                            startPoint: .bottom,
                            endPoint: .top
                        )
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
                    .clipped()
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
    
    var body: some View {
        Group {
            if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(height: height)
                    .clipped()
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
        .background(Color(.secondarySystemBackground))
        .cornerRadius(16)
    }
}

// MARK: - Invite Friends Sheet

struct InviteFriendsSheet: View {
    @Environment(\.dismiss) private var dismiss
    
    private let appStoreLink = "https://apps.apple.com/app/id6745013790" // App Store link
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

#Preview {
    SocialView()
        .environmentObject(AuthViewModel())
}
