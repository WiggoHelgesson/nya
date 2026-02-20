import SwiftUI
import Combine
import PhotosUI
import Supabase
import MapKit
import ConfettiSwiftUI

// MARK: - Social Tab Selection
enum SocialTab: String, CaseIterable {
    case feed = "Flödet"
    // Active Friends tab temporarily hidden
    // case activeFriends = "Aktiva vänner"
}

struct SocialView: View {
    @StateObject private var socialViewModel = SocialViewModel.shared
    @StateObject private var newsViewModel = NewsViewModel()
    @StateObject private var celebrationManager = CelebrationManager.shared
    @ObservedObject private var uploadManager = PostUploadManager.shared
    @ObservedObject private var adService = AdService.shared
    @EnvironmentObject var authViewModel: AuthViewModel
    @Environment(\.scenePhase) private var scenePhase
    @State private var visiblePostCount = 5 // Start with 5 posts
    @State private var isLoadingMore = false
    @State private var hasInitiallyLoaded = false // Track if first load is complete
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
    @State private var weeklyWeight: Double = 0
    @State private var lastWeekActivities: Int = 0
    @State private var lastWeekTime: TimeInterval = 0
    @State private var lastWeekWeight: Double = 0
    
    // Animation states - default true for instant navigation
    @State private var showHeader = true
    @State private var showCarousel = true
    @State private var showPosts = true
    
    // Stories state
    @State private var friendsStories: [UserStories] = []
    @State private var myStories: [Story] = []
    @State private var isLoadingStories = false
    @State private var selectedUserStories: UserStories? = nil
    
    // Notification navigation state - scroll to post instead of opening detail
    @State private var highlightedPostId: String? = nil
    
    // Friends at gym state
    @State private var activeFriends: [ActiveFriendSession] = []
    @State private var isLoadingActiveFriends = false
    
    // Banner image picker
    @State private var showBannerPicker = false
    @State private var bannerPickerItem: PhotosPickerItem? = nil
    @State private var isUploadingBanner = false
    
    @State private var streakCount: Int = 0
    @State private var friendCount: Int = 0
    @State private var friendAvatars: [String?] = []
    @State private var showNotifications = false
    
    // Navigation states
    @State private var showFollowersList = false
    @State private var showOwnProfile = false
    
    // Timer for active friends refresh
    @State private var activeFriendsRefreshTimer: Timer?
    
    // Friend location map state
    @State private var showFriendsMap = false
    
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
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("PopToRootHem"))) { _ in
                navigationPath = NavigationPath()
                selectedPost = nil
                showFindFriends = false
                showFollowersList = false
                showOwnProfile = false
                showNotifications = false
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
                // Setup real-time listeners
                await MainActor.run {
                    socialViewModel.setupRealtimeListeners()
                    RealtimeSocialService.shared.startListening()
                }
            }
            .onDisappear {
                // Stop real-time updates when view disappears
                RealtimeSocialService.shared.stopListening()
            }
            .sheet(isPresented: $showCreateNews) {
                CreateNewsView(newsViewModel: newsViewModel)
            }
            .navigationDestination(isPresented: $showFriendsMap) {
                FriendsLocationMapView(friends: activeFriends)
                    .environmentObject(authViewModel)
            }
            .navigationDestination(isPresented: $showFindFriends) {
                FindFriendsView()
                    .environmentObject(authViewModel)
            }
            .navigationDestination(isPresented: $showFollowersList) {
                if let userId = authViewModel.currentUser?.id {
                    FollowListView(userId: userId, listType: .followers)
                        .environmentObject(authViewModel)
                }
            }
            .navigationDestination(isPresented: $showOwnProfile) {
                if let userId = authViewModel.currentUser?.id {
                    UserProfileView(userId: userId)
                        .environmentObject(authViewModel)
                }
            }
            .fullScreenCover(item: $selectedUserStories) { userStories in
                StoryViewerOverlay(
                    userStories: userStories,
                    currentUserId: authViewModel.currentUser?.id ?? "",
                    onStoryViewed: { storyId in
                        markStoryAsViewed(storyId: storyId)
                    },
                    onDismiss: {
                        selectedUserStories = nil
                    }
                )
                .environmentObject(authViewModel)
                .background(Color.black)
                .ignoresSafeArea()
            }
            .enableSwipeBack()
            // Active Friends navigation temporarily disabled
            // .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("NavigateToActiveFriendsTab"))) { _ in
            //     withAnimation {
            //         selectedTab = .activeFriends
            //     }
            // }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("OpenNotifications"))) { _ in
                // Open notifications view
                showNotifications = true
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("NavigateToPost"))) { notification in
                if let userInfo = notification.userInfo,
                   let postId = userInfo["postId"] as? String {
                    // Switch to feed tab first
                    withAnimation {
                        selectedTab = .feed
                    }
                    // Set highlighted post to scroll to and highlight it
                    highlightedPostId = postId
                    
                    // If post not in feed, fetch it first
                    if !socialViewModel.posts.contains(where: { $0.id == postId }) {
                        pendingPostNavigation = postId
                        Task {
                            await fetchPostForHighlight(postId: postId)
                        }
                    }
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("PostUpdated"))) { _ in
                Task {
                    await socialViewModel.refreshSocialFeed(userId: authViewModel.currentUser?.id ?? "")
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("RefreshStories"))) { _ in
                Task {
                    if let userId = authViewModel.currentUser?.id {
                        await loadStories(userId: userId)
                    }
                }
            }
            .onChange(of: scenePhase) { oldPhase, newPhase in
                handleScenePhaseChange(newPhase)
            }
            .confettiCannon(
                counter: $celebrationManager.confettiCounter,
                num: celebrationManager.confettiCount,
                colors: celebrationManager.confettiColors,
                confettiSize: celebrationManager.confettiSize,
                rainHeight: celebrationManager.rainHeight,
                radius: celebrationManager.radius,
                repetitions: celebrationManager.repetitions,
                repetitionInterval: celebrationManager.repetitionInterval
            )
        }
    }
    
    // MARK: - Extracted Views
    
    @ViewBuilder
    private var mainContent: some View {
        GeometryReader { geometry in
            let topInset = geometry.safeAreaInsets.top
            
            ScrollView {
                VStack(spacing: 0) {
                    // Hero Banner Section - extends behind status bar via negative padding
                    heroBannerSection
                        .padding(.top, -topInset)
                        .zIndex(2)
                        .pageEntrance()
                    
                    // Overlapping Friends & Stats section
                    friendsAndStatsSection
                        .offset(y: -40)
                        .zIndex(3)
                        .pageEntrance(delay: 0.05)
                    
                    VStack(spacing: 0) {
                        // Show skeleton while initially loading (before first successful load)
                        if !hasInitiallyLoaded || (socialViewModel.isLoading && socialViewModel.posts.isEmpty) {
                            loadingView
                        } else if socialViewModel.posts.isEmpty && !featuredPosts.isEmpty {
                            // Show featured posts when user has no following
                            featuredPostsContent
                        } else if socialViewModel.posts.isEmpty && hasInitiallyLoaded {
                            emptyStateView
                        } else {
                            // Feed content directly here instead of scrollContent to avoid nested scrolls
                            VStack(alignment: .leading, spacing: 0) {
                                // MARK: - Friends at gym section
                                friendsAtGymSection
                                
                                // MARK: - Upload progress indicator
                                if uploadManager.uploadingPost != nil {
                                    uploadProgressCard
                                }
                                
                                // Separator line between friends section and posts
                                Divider()
                                    .background(Color(.systemGray5))
                                
                                // Always show feed content
                                feedContent
                            }
                        }
                    }
                    .padding(.top, -30) // Adjust for the overlapping section
                }
            }
            .scrollClipDisabled()
            .refreshable {
                await refreshData()
            }
            .navigationDestination(isPresented: $showNotifications) {
                NotificationsView(onDismiss: {
                    showNotifications = false
                })
                .environmentObject(authViewModel)
            }
            .onChange(of: showPaywall) { _, newValue in
                if newValue {
                    SuperwallService.shared.showPaywall()
                    showPaywall = false
                }
            }
            .onAppear {
                animateContentIn()
                loadStats()
                Task { await adService.fetchFeedAds() }
            }
        }
    }

    // MARK: - Load Stats
    private func loadStats() {
        guard let userId = authViewModel.currentUser?.id else { return }
        
        // Load streak
        streakCount = StreakManager.shared.getCurrentStreak().currentStreak
        
        // Load friend count and avatars
        Task {
            do {
                // Fetch follower users directly to get their avatars
                let followerUsers = try await SocialService.shared.getFollowerUsers(userId: userId)
                
                await MainActor.run {
                    self.friendCount = followerUsers.count
                    // Take up to 3 avatars from actual followers
                    self.friendAvatars = followerUsers.prefix(3).map { $0.avatarUrl }
                }
            } catch {
                print("⚠️ Error loading friend stats: \(error)")
            }
        }
    }

    // MARK: - Friends & Stats Section (Overlapping)
    private var friendsAndStatsSection: some View {
        HStack(spacing: 10) {
            // Friends Card - tappable to show followers list
            Button {
                showFollowersList = true
            } label: {
                HStack(spacing: 0) {
                    // Three profile pictures (Actual Friends)
                    HStack(spacing: -14) {
                        ForEach(0..<friendAvatars.count, id: \.self) { index in
                            ProfileImage(url: friendAvatars[index], size: 36)
                                .overlay(Circle().stroke(Color.white, lineWidth: 2.5))
                        }
                        
                        if friendAvatars.isEmpty {
                            Circle()
                                .fill(Color.gray.opacity(0.1))
                                .frame(width: 36, height: 36)
                                .overlay(
                                    Image(systemName: "person.fill")
                                        .font(.system(size: 16))
                                        .foregroundColor(.gray)
                                )
                                .overlay(Circle().stroke(Color.white, lineWidth: 2.5))
                        }
                    }
                    
                    Spacer()
                    
                    HStack(spacing: 6) {
                        Text("\(friendCount)")
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundColor(.black)
                        
                        Text("Vänner")
                            .font(.system(size: 17, weight: .medium, design: .rounded))
                            .foregroundColor(.black)
                    }
                }
                .padding(.leading, 14)
                .padding(.trailing, 20)
                .padding(.vertical, 16)
                .frame(maxWidth: .infinity)
                .background(Color(.systemBackground))
                .cornerRadius(28)
                .shadow(color: Color.black.opacity(0.1), radius: 15, x: 0, y: 8)
            }
            .buttonStyle(.plain)
            
            // Streak Card
            HStack(spacing: 6) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.orange)
                
                Text("\(streakCount)")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundColor(.black)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
            .background(Color(.systemBackground))
            .cornerRadius(28)
            .shadow(color: Color.black.opacity(0.1), radius: 15, x: 0, y: 8)
        }
        .padding(.horizontal, 12)
    }

    // MARK: - Hero Banner Section
    private var heroBannerSection: some View {
        ZStack(alignment: .top) {
            // Background banner image or gray placeholder
            ZStack(alignment: .bottom) {
                if let bannerUrl = authViewModel.currentUser?.bannerUrl, !bannerUrl.isEmpty {
                    LocalAsyncImage(path: bannerUrl)
                        .aspectRatio(contentMode: .fill)
                        .frame(width: UIScreen.main.bounds.width, height: 420)
                        .clipped()
                } else {
                    // Default banner image (77) for users without custom banner
                    Image("77")
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: UIScreen.main.bounds.width, height: 420)
                        .clipped()
                }
                
                // Bottom shadow gradient
                LinearGradient(
                    colors: [Color.clear, Color.black.opacity(0.5)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 150)
            }
            
            // Top Navigation Overlay
            HStack {
                // Left side - Upgrade to PRO (only show if not already Pro)
                if !RevenueCatManager.shared.isProMember {
                    Button {
                        SuperwallService.shared.showPaywall()
                    } label: {
                        Text("Uppgradera till PRO")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                            .shadow(color: .black.opacity(0.3), radius: 4)
                    }
                    .padding(.leading, 24)
                }
                
                Spacer()
            }
            .padding(.top, 60)
            
            // Profile and Name Overlay - Tappable to show own profile
            Button {
                showOwnProfile = true
            } label: {
                VStack(alignment: .leading, spacing: 20) {
                    Spacer()
                    
                    // Profile picture with black/silver gradient ring
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.black,
                                        Color(white: 0.7),
                                        Color.white.opacity(0.8),
                                        Color(white: 0.7),
                                        Color.black
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 115, height: 115)
                            .shadow(color: .black.opacity(0.3), radius: 12)
                        
                        ProfileImage(url: authViewModel.currentUser?.avatarUrl, size: 105)
                            .clipShape(Circle())
                    }
                    .padding(.leading, 24)
                    
                    // Greeting text
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Kör hårt,")
                            .font(.system(size: 32, weight: .medium, design: .rounded))
                            .foregroundColor(.white)
                            .shadow(color: .black.opacity(0.4), radius: 5)
                        
                        Text(authViewModel.currentUser?.name ?? "")
                            .font(.system(size: 38, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .shadow(color: .black.opacity(0.4), radius: 5)
                            .lineLimit(2)
                            .minimumScaleFactor(0.6)
                    }
                    .padding(.leading, 24)
                    .padding(.trailing, 160) // Leave space for icons on the right
                    .padding(.bottom, 90) // Moved down by increasing banner height
                }
                .frame(width: UIScreen.main.bounds.width, height: 420, alignment: .leading)
            }
            .buttonStyle(.plain)
            
            // Edit Banner Button
            VStack {
                Spacer()
                HStack(spacing: 12) {
                    Spacer()
                    Button {
                        showBannerPicker = true
                    } label: {
                        Image(systemName: "photo.on.rectangle.angled")
                            .font(.system(size: 24))
                            .foregroundColor(.black)
                            .frame(width: 60, height: 60)
                            .background(Color.white)
                            .clipShape(RoundedRectangle(cornerRadius: 18))
                            .shadow(color: .black.opacity(0.2), radius: 12, x: 0, y: 6)
                    }
                }
                .padding(.trailing, 28)
                .padding(.bottom, 110)
            }
        }
        .frame(width: UIScreen.main.bounds.width, height: 420)
        .overlay(
            // Edit banner button (hidden but accessible)
            Button {
                showBannerPicker = true
            } label: {
                Color.clear
                    .frame(width: 80, height: 80)
            },
            alignment: .topLeading
        )
        .photosPicker(isPresented: $showBannerPicker, selection: $bannerPickerItem, matching: .images)
        .onChange(of: bannerPickerItem) { _, newItem in
            Task {
                await uploadBannerImage(item: newItem)
            }
        }
    }
    
    // MARK: - Upload Banner Image
    private func uploadBannerImage(item: PhotosPickerItem?) async {
        guard let item = item else { return }
        guard let userId = authViewModel.currentUser?.id else { return }
        
        await MainActor.run {
            isUploadingBanner = true
        }
        
        do {
            guard let data = try await item.loadTransferable(type: Data.self),
                  let image = UIImage(data: data) else {
                await MainActor.run { isUploadingBanner = false }
                return
            }
            
            // Resize image for banner (max 1200px width)
            let resizedImage = resizeBannerImage(image, targetWidth: 1200)
            guard let jpegData = resizedImage.jpegData(compressionQuality: 0.8) else {
                await MainActor.run { isUploadingBanner = false }
                return
            }
            
            let filename = "banner_\(userId)_\(Int(Date().timeIntervalSince1970)).jpg"
            let path = "banners/\(filename)"
            
            // Upload to Supabase Storage
            try await SupabaseConfig.supabase.storage
                .from("avatars")
                .upload(path: path, file: jpegData, options: .init(contentType: "image/jpeg", upsert: true))
            
            // Update profile with new banner URL
            let updateResponse = try await SupabaseConfig.supabase
                .from("profiles")
                .update(["banner_url": path])
                .eq("id", value: userId)
                .execute()
            
            print("📡 Supabase update response: \(updateResponse.status)")
            
            // Force refresh user data in AuthViewModel
            await authViewModel.loadUserProfile()
            
            await MainActor.run {
                isUploadingBanner = false
                bannerPickerItem = nil
            }
            
            print("✅ Banner uploaded successfully: \(path)")
            
        } catch {
            print("❌ Failed to upload banner: \(error)")
            await MainActor.run {
                isUploadingBanner = false
                bannerPickerItem = nil
            }
        }
    }
    
    // Helper function to resize image for banner
    private func resizeBannerImage(_ image: UIImage, targetWidth: CGFloat) -> UIImage {
        let size = image.size
        let widthRatio = targetWidth / size.width
        
        if widthRatio >= 1.0 {
            return image // Don't upscale
        }
        
        let newSize = CGSize(width: targetWidth, height: size.height * widthRatio)
        
        UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
        image.draw(in: CGRect(origin: .zero, size: newSize))
        let resizedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return resizedImage ?? image
    }
    
    private func animateContentIn() {
        // Show everything instantly for fast navigation
        showHeader = true
        showCarousel = true
        showPosts = true
    }
    
    private var loadingView: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Skeleton for "Vänner som tränar" section
            VStack(alignment: .leading, spacing: 12) {
                SkeletonLine(width: 160, height: 20)
                
                HStack(spacing: 12) {
                    SkeletonCircle(size: 48)
                    VStack(alignment: .leading, spacing: 6) {
                        SkeletonLine(width: 200, height: 14)
                        SkeletonLine(width: 140, height: 12)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            
            Divider()
                .background(Color(.systemGray5))
            
            // Skeleton posts
            SkeletonFeedView(postCount: 4)
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 0) {
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
                // Posts from all users (always show feed)
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
            }
        }
    }
    
    private var scrollContent: some View {
        ScrollViewReader { scrollProxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // MARK: - Friends at gym section
                    friendsAtGymSection
                    
                    // Always show feed content
                    feedContent
                        .opacity(showPosts ? 1 : 0)
                        .offset(y: showPosts ? 0 : 30)
                }
            }
            .onChange(of: highlightedPostId) { _, postId in
                if let postId = postId {
                    // Scroll to the highlighted post with animation
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                        scrollProxy.scrollTo(postId, anchor: .center)
                    }
                    // Remove highlight after 3 seconds
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                        withAnimation(.easeOut(duration: 0.5)) {
                            highlightedPostId = nil
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Friends at Gym Section
    private var friendsAtGymSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Vänner som tränar")
                    .font(.system(size: 20, weight: .bold))
                
                Text("Tryck på dina vänner för att se exakt vart de tränar")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 16)
            
            // Horizontal scroll with app logo + active friends
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    // App logo first (always visible) - tap to open map
                    friendAtGymCard(
                        imageContent: AnyView(
                            Image("23")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 60, height: 60)
                                .clipShape(Circle())
                        ),
                        name: "Up&Down",
                        duration: nil,
                        onTap: {
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            showFriendsMap = true
                        }
                    )
                    
                    // Active friends or placeholders
                    if activeFriends.isEmpty && !isLoadingActiveFriends {
                        // Show text when no friends are active
                        Text("Inga av dina vänner tränar just nu")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.secondary)
                            .padding(.leading, 8)
                            .frame(height: 60)
                    } else {
                        ForEach(activeFriends) { friend in
                            friendAtGymCard(
                                imageContent: AnyView(
                                    AsyncImage(url: URL(string: friend.avatarUrl ?? "")) { phase in
                                        switch phase {
                                        case .success(let image):
                                            image
                                                .resizable()
                                                .scaledToFill()
                                        case .failure(_), .empty:
                                            Circle()
                                                .fill(Color.gray.opacity(0.3))
                                                .overlay(
                                                    Image(systemName: "person.fill")
                                                        .font(.system(size: 24))
                                                        .foregroundColor(.gray)
                                                )
                                        @unknown default:
                                            Circle()
                                                .fill(Color.gray.opacity(0.3))
                                        }
                                    }
                                    .frame(width: 60, height: 60)
                                    .clipShape(Circle())
                                ),
                                name: friend.userName.components(separatedBy: " ").first ?? friend.userName,
                                duration: friend.formattedDuration,
                                onTap: {
                                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                    showFriendsMap = true
                                }
                            )
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 4)
            }
            .animation(.easeInOut(duration: 0.3), value: activeFriends.count)
        }
        .padding(.vertical, 8)
        .task {
            await loadActiveFriendsData()
        }
        .onAppear {
            startActiveFriendsTimer()
        }
        .onDisappear {
            stopActiveFriendsTimer()
        }
    }
    
    // Helper view for friend at gym card
    private func friendAtGymCard(imageContent: AnyView, name: String, duration: String?, onTap: (() -> Void)?) -> some View {
        VStack(spacing: 8) {
            // Profile picture with black/silver gradient ring
            ZStack {
                Circle()
                    .stroke(
                        LinearGradient(
                            colors: [.black, Color(white: 0.7), .black],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 3
                    )
                    .frame(width: 70, height: 70)
                
                imageContent
            }
            
            // Name
            Text(name)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.black)
                .lineLimit(1)
            
            // Duration (if available)
            if let duration = duration {
                Text(duration)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.black)
            } else {
                Text(" ")
                    .font(.system(size: 11, weight: .semibold))
            }
        }
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
        .onTapGesture {
            onTap?()
        }
    }
    
    // MARK: - Active Friends Timer
    private func startActiveFriendsTimer() {
        // Invalidate existing timer if any
        activeFriendsRefreshTimer?.invalidate()
        
        // Create new timer that fires every 30 seconds
        activeFriendsRefreshTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { _ in
            Task {
                await loadActiveFriendsData()
            }
        }
    }
    
    private func stopActiveFriendsTimer() {
        activeFriendsRefreshTimer?.invalidate()
        activeFriendsRefreshTimer = nil
    }
    
    private func activityIconForFriend(_ activityType: String) -> String {
        switch activityType.lowercased() {
        case "running", "löpning", "löppass": return "figure.run"
        case "gym", "strength", "walking", "gympass": return "dumbbell.fill"
        case "cycling", "cykling": return "bicycle"
        case "promenad", "bestiga berg", "hiking": return "figure.walk"
        case "swimming", "simning": return "figure.pool.swim"
        case "yoga": return "figure.yoga"
        case "golf", "golfrunda": return "figure.golf"
        case "skidåkning", "skiing": return "figure.skiing.downhill"
        default: return "flame.fill"
        }
    }
    
    private func activityLabelForFriend(_ activityType: String) -> String {
        switch activityType.lowercased() {
        case "running", "löpning", "löppass": return "Löppass"
        case "gym", "strength", "walking", "gympass": return "Gympass"
        case "cycling", "cykling": return "Cykling"
        case "promenad", "bestiga berg", "hiking": return "Promenad"
        case "swimming", "simning": return "Simning"
        case "yoga": return "Yoga"
        case "golf", "golfrunda": return "Golfrunda"
        case "skidåkning", "skiing": return "Skidpass"
        default: return "Tränar"
        }
    }
    
    private func isGymSession(_ activityType: String) -> Bool {
        let lower = activityType.lowercased()
        return lower == "gym" || lower == "walking" || lower == "gympass" || lower == "strength"
    }
    
    private func loadActiveFriendsData() async {
        guard let userId = authViewModel.currentUser?.id else { return }
        
        // Only show loading indicator on first load (when we have no data yet)
        let isFirstLoad = activeFriends.isEmpty && !isLoadingActiveFriends
        if isFirstLoad {
            await MainActor.run {
                isLoadingActiveFriends = true
            }
            
            // Cleanup stale sessions on first load
            try? await ActiveSessionService.shared.cleanupStaleSessions()
        }
        
        do {
            // Fetch active friends (now filters out stale sessions)
            let active = try await ActiveSessionService.shared.fetchActiveFriends(userId: userId)
            await MainActor.run {
                // Use animation to smoothly update the list
                withAnimation(.easeInOut(duration: 0.3)) {
                    activeFriends = active
                    isLoadingActiveFriends = false
                }
            }
        } catch {
            print("⚠️ Failed to load friends data: \(error)")
            await MainActor.run {
                withAnimation(.easeInOut(duration: 0.3)) {
                    isLoadingActiveFriends = false
                }
            }
        }
    }
    
    // MARK: - Quick Insights Carousel (Strava-style) - KEPT FOR REFERENCE
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
        NavigationLink(destination: AllExercisesListView()) {
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
                    
                    // Weight (Kg)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Kg")
                            .font(.system(size: 11))
                            .foregroundColor(.gray)
                        Text(formatWeight(weeklyWeight))
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(.primary)
                        weeklyChangeLabel(current: weeklyWeight, previous: lastWeekWeight, suffix: " kg")
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
    
    private func formatWeight(_ kg: Double) -> String {
        if kg >= 1000 {
            return String(format: "%.1fk", kg / 1000)
        }
        return String(format: "%.0f", kg)
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
            
            // Calculate total weight lifted from gym exercises
            let weight = thisWeekPosts.reduce(0.0) { total, post in
                guard let exercises = post.exercises else { return total }
                return total + exercises.reduce(0.0) { exerciseTotal, exercise in
                    let setCount = min(exercise.reps.count, exercise.kg.count)
                    return exerciseTotal + (0..<setCount).reduce(0.0) { setTotal, i in
                        return setTotal + (Double(exercise.reps[i]) * exercise.kg[i])
                    }
                }
            }
            
            let lastActivities = lastWeekPosts.count
            let lastTime = lastWeekPosts.reduce(0.0) { $0 + Double($1.duration ?? 0) }
            let lastWeight = lastWeekPosts.reduce(0.0) { total, post in
                guard let exercises = post.exercises else { return total }
                return total + exercises.reduce(0.0) { exerciseTotal, exercise in
                    let setCount = min(exercise.reps.count, exercise.kg.count)
                    return exerciseTotal + (0..<setCount).reduce(0.0) { setTotal, i in
                        return setTotal + (Double(exercise.reps[i]) * exercise.kg[i])
                    }
                }
            }
            
            await MainActor.run {
                self.weeklyActivities = activities
                self.weeklyTime = time
                self.weeklyWeight = weight
                self.lastWeekActivities = lastActivities
                self.lastWeekTime = lastTime
                self.lastWeekWeight = lastWeight
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
        
        // Load stories from friends
        await loadStories(userId: userId)
        
        // Load active friends at gym
        await loadActiveFriendsData()
        
        await socialViewModel.fetchSocialFeedAsync(userId: userId)
        
        // Mark initial load as complete with smooth animation
        await MainActor.run {
            withAnimation(.easeOut(duration: 0.3)) {
                hasInitiallyLoaded = true
            }
        }
        
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
    
    // MARK: - Load Stories
    private func loadStories(userId: String) async {
        isLoadingStories = true
        
        // Load my stories (always try this)
        do {
            let mine = try await StoryService.shared.fetchMyStories(userId: userId)
            await MainActor.run {
                self.myStories = mine
            }
        } catch {
            print("❌ Error loading my stories: \(error)")
        }
        
        // Load friends stories (separate try so my stories still work)
        do {
            let friends = try await StoryService.shared.fetchFriendsStories(userId: userId)
            await MainActor.run {
                self.friendsStories = friends
            }
        } catch {
            print("❌ Error loading friends stories: \(error)")
            // This is OK - user might not follow anyone
        }
        
        await MainActor.run {
            self.isLoadingStories = false
        }
    }
    
    // MARK: - Mark Story as Viewed
    private func markStoryAsViewed(storyId: String) {
        guard let userId = authViewModel.currentUser?.id else { return }
        
        Task {
            do {
                try await StoryService.shared.markStoryAsViewed(storyId: storyId, viewerId: userId)
                
                // Update local state
                await MainActor.run {
                    for index in friendsStories.indices {
                        if let storyIndex = friendsStories[index].stories.firstIndex(where: { $0.id == storyId }) {
                            friendsStories[index].stories[storyIndex].hasViewed = true
                        }
                        // Update hasUnviewedStories
                        friendsStories[index].hasUnviewedStories = friendsStories[index].stories.contains { !$0.hasViewed }
                    }
                }
            } catch {
                print("❌ Error marking story as viewed: \(error)")
            }
        }
    }
    
    private func loadFeaturedPosts() async {
        guard !isLoadingFeatured else { return }
        guard let userId = authViewModel.currentUser?.id else { return }
        
        isLoadingFeatured = true
        
        do {
            // Load 7 most recent posts from all users for users without friends
            let posts = try await SocialService.shared.getFeaturedPosts(viewerId: userId, limit: 7)
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
    
    // Fetch post for highlight (from notification) - doesn't open detail, just scrolls and highlights
    private func fetchPostForHighlight(postId: String) async {
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
                // Add the post to the feed if it's not already there
                if !socialViewModel.posts.contains(where: { $0.id == postId }) {
                    // Insert at the beginning of the posts array
                    socialViewModel.posts.insert(post, at: 0)
                }
                pendingPostNavigation = nil
                // The highlightedPostId is already set, ScrollViewReader will scroll to it
            }
        } catch {
            print("❌ Failed to fetch post for highlight \(postId): \(error)")
            pendingPostNavigation = nil
            highlightedPostId = nil
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
        
        // Refresh stories first
        await loadStories(userId: userId)
        
        // Refresh active friends
        await loadActiveFriendsData()
        
        await socialViewModel.refreshSocialFeed(userId: userId)
        await loadRecommendedUsers(for: userId)
        await newsViewModel.fetchNews()
    }
    
    private func handleScenePhaseChange(_ newPhase: ScenePhase) {
        if newPhase == .active {
            let inactiveTime = Date().timeIntervalSince(lastActiveTime)
            
            // Restart the active friends timer when app becomes active
            startActiveFriendsTimer()
            
            // Always refresh active friends when app becomes active (they change frequently)
            Task {
                await loadActiveFriendsData()
            }
            
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
            // Stop the timer when app goes to background to save battery
            stopActiveFriendsTimer()
            lastActiveTime = Date()
        }
    }
    
    // MARK: - Upload Progress Card
    private var uploadProgressCard: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color(.systemGray5))
                    .frame(width: 44, height: 44)
                
                if uploadManager.uploadFailed {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 18))
                        .foregroundColor(.red)
                } else {
                    ProgressView()
                        .scaleEffect(0.9)
                }
            }
            
            VStack(alignment: .leading, spacing: 3) {
                Text(uploadManager.uploadingPost?.title ?? "Träningspass")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
                if uploadManager.uploadFailed {
                    Text("Uppladdning misslyckades")
                        .font(.system(size: 13))
                        .foregroundColor(.red)
                } else {
                    Text("Laddar upp...")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            if uploadManager.uploadFailed {
                Button {
                    uploadManager.dismissFailure()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(Color(.systemBackground))
        .transition(.asymmetric(
            insertion: .move(edge: .top).combined(with: .opacity),
            removal: .opacity
        ))
        .animation(.easeInOut(duration: 0.3), value: uploadManager.uploadingPost?.id)
    }
    
    // MARK: - Feed Content
    private var feedContent: some View {
        LazyVStack(spacing: 0, pinnedViews: []) {
            ForEach(Array(postsToDisplay.enumerated()), id: \.element.id) { index, post in
                let isHighlighted = highlightedPostId == post.id
                
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
                    .overlay(
                        // Highlight overlay when navigating from notification
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.blue, lineWidth: isHighlighted ? 3 : 0)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.blue.opacity(isHighlighted ? 0.08 : 0))
                            )
                            .padding(4)
                            .animation(.easeInOut(duration: 0.3), value: isHighlighted)
                    )
                    .scaleEffect(isHighlighted ? 1.01 : 1.0)
                    .animation(.spring(response: 0.4, dampingFraction: 0.7), value: isHighlighted)
                    
                    Divider()
                        .background(Color(.systemGray5))
                }
                .opacity(showPosts ? 1 : 0)
                .offset(y: showPosts ? 0 : 20)
                .animation(
                    .spring(response: 0.5, dampingFraction: 0.8)
                    .delay(Double(min(index, 5)) * 0.05),
                    value: showPosts
                )
                .onAppear {
                    if let index = socialViewModel.posts.firstIndex(where: { $0.id == post.id }),
                       index >= visiblePostCount - 2,
                       visiblePostCount < socialViewModel.posts.count {
                        loadMorePosts()
                    }
                }
                
                // Pro upgrade banner after 8th post
                // Only show for non-Pro members
                if index == 7, !(authViewModel.currentUser?.isProMember ?? false) {
                    ProUpgradeBanner(onTap: {
                        showPaywall = true
                    })
                    .opacity(showPosts ? 1 : 0)
                    .offset(y: showPosts ? 0 : 15)
                    .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.2), value: showPosts)
                    Divider()
                        .background(Color(.systemGray5))
                }
                
                // Dynamic ad or fallback sponsored post after 4th post
                if index == 3 {
                    if let feedAd = adService.feedAds.first {
                        FeedAdCard(ad: feedAd)
                            .opacity(showPosts ? 1 : 0)
                            .offset(y: showPosts ? 0 : 15)
                            .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.25), value: showPosts)
                    } else {
                        SponsoredPostCard()
                            .opacity(showPosts ? 1 : 0)
                            .offset(y: showPosts ? 0 : 15)
                            .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.25), value: showPosts)
                    }
                    Divider()
                        .background(Color(.systemGray5))
                }
                
                // Removed recommended friends section
                
                // Become a trainer promo after 10th post
                if index == 9 {
                    BecomeTrainerPromoCard()
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .opacity(showPosts ? 1 : 0)
                        .offset(y: showPosts ? 0 : 15)
                        .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.25), value: showPosts)
                    Divider()
                        .background(Color(.systemGray5))
                }
                
                // Visa varumärkesslider efter andra inlägget
                if index == 1, shouldShowBrandSlider {
                    brandSliderInlineSection
                        .opacity(showPosts ? 1 : 0)
                        .offset(y: showPosts ? 0 : 15)
                        .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.25), value: showPosts)
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
    
    // MARK: - Active Friends Content
    private var activeFriendsContent: some View {
        ActiveFriendsMapView()
            .environmentObject(authViewModel)
    }
    
    // MARK: - News Content (Deprecated)
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
            VStack(alignment: .leading, spacing: 4) {
                Text("Varumärken")
                    .font(.system(size: 18, weight: .bold))
                
                Text("Få rabatter hos dessa varumärken genom att samla poäng genom dina gympass")
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
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
    @State private var likeAnimationScale: CGFloat = 1.0
    @State private var showLikeParticles = false
    @State private var showSaveRoutineAlert = false
    @State private var isSavingRoutine = false
    @State private var routineSavedSuccess = false
    @EnvironmentObject var authViewModel: AuthViewModel
    
    private let likeHaptic = UIImpactFeedbackGenerator(style: .medium)
    
    // Check if this is the current user's post
    private var isOwnPost: Bool {
        post.userId == authViewModel.currentUser?.id
    }
    
    // Check if this is a gym post with exercises that can be saved as routine
    private var canSaveAsRoutine: Bool {
        post.activityType == "Gympass" && (post.exercises?.isEmpty == false)
    }
    
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
            // Share only shown for own posts, otherwise 50/50 for like/comment
            HStack(spacing: 0) {
                Button(action: toggleLike) {
                    ZStack {
                        // Particle burst effect when liking
                        if showLikeParticles {
                            ForEach(0..<6, id: \.self) { index in
                                Image(systemName: "heart.fill")
                                    .font(.system(size: 8))
                                    .foregroundColor(.red.opacity(0.8))
                                    .offset(
                                        x: cos(Double(index) * .pi / 3) * 20,
                                        y: sin(Double(index) * .pi / 3) * 20
                                    )
                                    .opacity(showLikeParticles ? 0 : 1)
                                    .scaleEffect(showLikeParticles ? 1.5 : 0.5)
                            }
                        }
                        
                        // Main heart icon
                        Image(systemName: isLiked ? "heart.fill" : "heart")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(isLiked ? .red : .gray)
                            .scaleEffect(likeAnimationScale)
                    }
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(likeInProgress)

                NavigationLink(destination: CommentsView(post: post) {
                    commentCount += 1
                    onCommentCountChanged(post.id, commentCount)
                }
                .onAppear { NavigationDepthTracker.shared.setAtRoot(false) }
                .onDisappear { NavigationDepthTracker.shared.setAtRoot(true) }
                ) {
                    Image(systemName: "bubble.right")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.gray)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                // Only show share button for own posts
                if isOwnPost {
                    Button(action: { showShareSheet = true }) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.gray)
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 14)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemBackground))
        .task(id: post.id) {
            // Always verify actual like count from server (catches stale cache / wrong counts)
            await verifyLikeCount()
            
            // Fetch top likers if we have likes
            if likeCount > 0 && topLikers.isEmpty {
                await loadTopLikers()
            }
        }
        .onChange(of: post.likeCount) { newValue in
            let newCount = newValue ?? likeCount
            let countChanged = newCount != likeCount
            likeCount = newCount
            // Re-fetch top likers when count changes from real-time (not from own like action)
            if countChanged && !likeInProgress {
                Task { await loadTopLikers() }
            }
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
            if canSaveAsRoutine {
                Button("Gör till en rutin") {
                    Task {
                        await saveAsRoutine()
                    }
                }
            }
            Button("Ta bort inlägg", role: .destructive) {
                showDeleteAlert = true
            }
            Button("Avbryt", role: .cancel) {}
        }
        .alert("Rutin sparad!", isPresented: $routineSavedSuccess) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Gympasset har sparats som en rutin. Du hittar den under \"Gym rutiner\" när du startar ett nytt gympass.")
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
                VStack(alignment: .leading, spacing: 2) {
                    Text(formatStravaDate(post.createdAt))
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                    
                    if let location = post.location {
                        HStack(spacing: 4) {
                            Image(systemName: "mappin.and.ellipse")
                                .font(.system(size: 10))
                            Text(location)
                        }
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                    }
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
                        .padding(8)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }
    
    @ViewBuilder
    private var contentSection: some View {
        // Show exercises list for Gympass, otherwise show swipeable images
        // Note: Tap gesture is handled inside GymExercisesListView/SwipeableImageView
        // to only trigger on the center image area, not on buttons
        if post.activityType == "Gympass", let exercises = post.exercises, !exercises.isEmpty {
            GymExercisesListView(
                exercises: exercises,
                userImage: post.userImageUrl,
                userId: post.userId,
                postDate: ISO8601DateFormatter().date(from: post.createdAt),
                onTapImage: {
                    onOpenDetail(post)
                }
            )
        } else if shouldShowCleanCard, let routeData = post.routeData, !routeData.isEmpty {
            // Post has GPS data but map image upload failed - regenerate map from stored coordinates
            RouteMapFallbackView(routeData: routeData, activityType: post.activityType)
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
            SwipeableImageView(routeImage: post.imageUrl, userImage: post.userImageUrl, onTapImage: {
                onOpenDetail(post)
            })
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
    
    private var hasTrainedWith: Bool {
        if let tw = post.trainedWith, !tw.isEmpty { return true }
        return false
    }
    
    private var statsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Trained with friends — above the title
            if let trainedWith = post.trainedWith, !trainedWith.isEmpty {
                HStack(spacing: 6) {
                    Text("Tränade med")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.secondary)
                    
                    HStack(spacing: -6) {
                        ForEach(Array(trainedWith.enumerated()), id: \.element.id) { index, friend in
                            NavigationLink(destination: UserProfileView(userId: friend.id)) {
                                ProfileImage(url: friend.avatarUrl, size: 26)
                                    .overlay(
                                        Circle()
                                            .stroke(Color(.systemBackground), lineWidth: 1.5)
                                    )
                            }
                            .zIndex(Double(trainedWith.count - index))
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
            }
            
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
            .padding(.top, hasTrainedWith ? 4 : 12)
            
            if let description = trimmedDescription {
                Text(description)
                    .font(.system(size: 14))
                    .foregroundColor(.gray)
                    .padding(.horizontal, 16)
            }
            
            // Gym Achievement Banner
            if isGymPost {
                GymAchievementBanner(post: post)
                    .padding(.horizontal, 16)
            }
            
            if isGymPost || !showsCleanCard {
                HStack(alignment: .top, spacing: 20) {
                    if isGymPost {
                        if let volume = gymVolumeText {
                            statColumn(title: "Volym", value: volume)
                        }
                        
                        if let sets = gymSetsCount {
                            statColumn(title: "Sets", value: "\(sets)")
                        }
                        
                        if let duration = post.duration {
                            statColumn(title: "Tid", value: formatDuration(duration))
                        }
                        
                        if let achievements = getAchievementCount(), achievements > 0 {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Prestationer")
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                                HStack(spacing: 4) {
                                    Image(systemName: "medal.fill")
                                        .font(.system(size: 18))
                                        .foregroundColor(.yellow)
                                    Text("\(achievements)")
                                        .font(.system(size: 18, weight: .bold))
                                        .foregroundColor(.primary)
                                }
                            }
                            .frame(alignment: .leading)
                            .padding(.vertical, 8)
                        }
                    } else {
                        if let distance = post.distance {
                            if post.isSwimmingPost {
                                let meters = Int(distance * 1000)
                                statColumn(title: "Distans", value: "\(meters) m")
                            } else {
                                statColumn(title: "Distans", value: String(format: "%.2f km", distance))
                            }
                        }
                        
                        if let duration = post.duration {
                            statColumn(title: "Tid", value: formatDuration(duration))
                        }
                        
                        if let pace = averagePaceText {
                            if post.isSwimmingPost {
                                statColumn(title: "Tempo/100m", value: pace)
                            } else {
                                statColumn(title: "Tempo", value: pace)
                            }
                        }
                        
                        if let strokes = post.strokes {
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
    
    private var gymSetsCount: Int? {
        guard isGymPost, let exercises = post.exercises else { return nil }
        return exercises.reduce(0) { $0 + $1.sets }
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
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
            Text(value)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.primary)
        }
        .frame(alignment: .leading)
        .padding(.vertical, 8)
    }
    
    private func getAchievementCount() -> Int? {
        guard isGymPost else { return nil }
        var count = 0
        
        // 1. New heaviest lift (PB)
        if post.pbExerciseName != nil {
            count += 1
        }
        
        // 2. Longest workout (placeholder for now, could be checked against history)
        // 3. Heaviest workout (placeholder for now, could be checked against history)
        
        // Check if this post is marked as a new record in the title or description
        // (In a real app, we would check the database for historical records)
        let titleLower = post.title.lowercased()
        if titleLower.contains("rekord") || titleLower.contains("longest") || titleLower.contains("heaviest") {
            count += 1
        }
        
        if let descLower = post.description?.lowercased(), descLower.contains("rekord") || descLower.contains("longest") || descLower.contains("heaviest") {
            count += 1
        }
        
        return count > 0 ? count : nil
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
    
    private func saveAsRoutine() async {
        guard let userId = authViewModel.currentUser?.id,
              let exercises = post.exercises,
              !exercises.isEmpty else {
            return
        }
        
        await MainActor.run {
            isSavingRoutine = true
        }
        
        do {
            // Use the post title as the routine name
            let routineName = post.title.isEmpty ? "Mitt gympass" : post.title
            
            // Save as a workout template
            _ = try await SavedWorkoutService.shared.saveWorkoutTemplate(
                userId: userId,
                name: routineName,
                exercises: exercises
            )
            
            await MainActor.run {
                isSavingRoutine = false
                routineSavedSuccess = true
                
                // Haptic feedback for success
                let successHaptic = UINotificationFeedbackGenerator()
                successHaptic.notificationOccurred(.success)
            }
            
            print("✅ Workout saved as routine: \(routineName)")
        } catch {
            print("❌ Error saving workout as routine: \(error)")
            await MainActor.run {
                isSavingRoutine = false
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
        
        // Haptic feedback
        likeHaptic.impactOccurred()
        
        // Update UI immediately (optimistic update)
        likeInProgress = true
        isLiked.toggle()
        likeCount += isLiked ? 1 : -1
        
        // Trigger like animation when liking
        if isLiked {
            // Scale animation
            withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                likeAnimationScale = 1.3
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) {
                    likeAnimationScale = 1.0
                }
            }
            
            // Particle burst animation
            withAnimation(.easeOut(duration: 0.4)) {
                showLikeParticles = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                showLikeParticles = false
            }
            
            // Confetti celebration (same as adding an exercise)
            CelebrationManager.shared.celebrateExerciseAdded()
            
            if let currentUser = authViewModel.currentUser {
                let liker = UserSearchResult(id: currentUser.id, name: currentUser.name, avatarUrl: currentUser.avatarUrl)
                if !topLikers.contains(where: { $0.id == liker.id }) {
                    topLikers.insert(liker, at: 0)
                }
            }
        } else {
            // Small bounce animation when unliking
            withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) {
                likeAnimationScale = 0.8
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) {
                    likeAnimationScale = 1.0
                }
            }
            topLikers.removeAll { $0.id == userId }
        }
        topLikers = Array(topLikers.prefix(3))
        
        Task {
            do {
                // Fetch actual like count and check current like status from server
                let existingLikes = try await SocialService.shared.getPostLikes(postId: post.id)
                let alreadyLiked = existingLikes.contains { $0.userId == userId }
                let actualLikeCount = existingLikes.count
                
                if isLiked {
                    // User wants to like
                    if !alreadyLiked {
                        // Pass post owner ID to trigger notification
                        try await SocialService.shared.likePost(
                            postId: post.id,
                            userId: userId,
                            postOwnerId: post.userId,
                            postTitle: post.title
                        )
                        print("✅ Post liked successfully")
                        
                        // Update with correct count from server + 1
                        await MainActor.run {
                            likeCount = actualLikeCount + 1
                            likeInProgress = false
                            onLikeChanged(post.id, true, likeCount)
                        }
                    } else {
                        // Was already liked - sync state correctly
                        print("⚠️ Already liked this post - syncing state")
                        await MainActor.run {
                            isLiked = true // Make sure it shows as liked
                            likeCount = actualLikeCount // Correct the count
                            likeInProgress = false
                            onLikeChanged(post.id, true, likeCount)
                        }
                    }
                } else {
                    // User wants to unlike
                    if alreadyLiked {
                        try await SocialService.shared.unlikePost(postId: post.id, userId: userId)
                        print("✅ Post unliked successfully")
                        
                        // Update with correct count from server - 1
                        await MainActor.run {
                            likeCount = max(0, actualLikeCount - 1)
                            likeInProgress = false
                            onLikeChanged(post.id, false, likeCount)
                        }
                    } else {
                        // Wasn't liked - sync state correctly
                        print("⚠️ Post wasn't liked - syncing state")
                        await MainActor.run {
                            isLiked = false // Make sure it shows as not liked
                            likeCount = actualLikeCount // Correct the count
                            likeInProgress = false
                            onLikeChanged(post.id, false, likeCount)
                        }
                    }
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
    
    private func formatStravaDate(_ dateString: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        var date: Date? = formatter.date(from: dateString)
        if date == nil {
            formatter.formatOptions = [.withInternetDateTime]
            date = formatter.date(from: dateString)
        }
        
        guard let parsedDate = date else { return dateString }
        
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "sv_SE")
        dateFormatter.dateFormat = "d MMMM, yyyy 'klockan' HH:mm"
        
        let datePart = dateFormatter.string(from: parsedDate)
        
        let sourcePart: String
        if let source = post.source?.lowercased() {
            if source == "app" {
                sourcePart = "Reggat med Up&Down"
            } else if source == "strava" {
                sourcePart = "Strava App"
            } else if source == "garmin" {
                sourcePart = "Garmin"
            } else if source == "apple_watch" || source == "healthkit" {
                sourcePart = "Apple Watch"
            } else {
                sourcePart = source.capitalized
            }
        } else {
            sourcePart = "Reggat med Up&Down"
        }
        
        return "\(datePart) • \(sourcePart)"
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

    /// Verify the like count and liked status from the server to catch stale cache
    private func verifyLikeCount() async {
        guard let userId = authViewModel.currentUser?.id else { return }
        // Skip verification while the user's own like action is in progress
        guard !likeInProgress else { return }
        do {
            let status = try await SocialService.shared.getPostLikeStatus(postId: post.id, userId: userId)
            await MainActor.run {
                if status.count != likeCount {
                    likeCount = status.count
                    onLikeChanged(post.id, isLiked, likeCount)
                }
                if status.isLiked != isLiked {
                    isLiked = status.isLiked
                }
            }
        } catch {
            // Keep current values if verification fails (e.g. cancelled request)
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
            // Invalidate cache first to ensure fresh data
            SocialService.shared.invalidateTopLikersCache(forPostId: post.id)
            let likers = try await SocialService.shared.getTopPostLikers(postId: post.id, limit: 3)
            // Deduplicate by ID to prevent rendering issues
            var seen = Set<String>()
            let uniqueLikers = likers.filter { seen.insert($0.id).inserted }
            await MainActor.run {
                self.topLikers = uniqueLikers
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
                            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: topLikers.map(\.id))
                        Text(likeCountText)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.primary)
                            .contentTransition(.numericText())
                            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: likeCount)
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
            }
            .onAppear { NavigationDepthTracker.shared.setAtRoot(false) }
            .onDisappear { NavigationDepthTracker.shared.setAtRoot(true) }
            ) {
                Text("\(commentCount) kommentarer")
                    .font(.system(size: 14))
                    .foregroundColor(.gray)
                    .contentTransition(.numericText())
                    .animation(.spring(response: 0.3, dampingFraction: 0.8), value: commentCount)
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
    
    // Deduplicate users by ID to prevent rendering issues
    private var uniqueUsers: [UserSearchResult] {
        var seen = Set<String>()
        return users.filter { seen.insert($0.id).inserted }
    }
    
    var body: some View {
        let displayUsers = Array(uniqueUsers.prefix(3))
        let avatarSize: CGFloat = 36
        let overlap: CGFloat = 20
        let totalWidth = displayUsers.isEmpty
            ? avatarSize
            : avatarSize + CGFloat(displayUsers.count - 1) * overlap
        
        ZStack(alignment: .leading) {
            if displayUsers.isEmpty {
                Circle()
                    .fill(Color(.systemGray5))
                    .frame(width: avatarSize, height: avatarSize)
                    .overlay(
                        Image(systemName: "person.fill")
                            .foregroundColor(.gray)
                            .font(.system(size: 14))
                    )
            } else {
                ForEach(Array(displayUsers.enumerated()), id: \.offset) { index, liker in
                    Group {
                        if let url = liker.avatarUrl, !url.isEmpty {
                            ProfileImage(url: url, size: avatarSize)
                        } else {
                            // Bulletproof fallback for missing avatar
                            Circle()
                                .fill(Color(.systemGray4))
                                .frame(width: avatarSize, height: avatarSize)
                                .overlay(
                                    Text(String(liker.name.prefix(1)).uppercased())
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundColor(.white)
                                )
                        }
                    }
                    .overlay(Circle().stroke(Color(.systemBackground), lineWidth: 2))
                    .offset(x: CGFloat(index) * overlap)
                    .zIndex(Double(displayUsers.count - index))
                }
            }
        }
        .frame(width: totalWidth + 4, height: avatarSize + 4, alignment: .leading)
        .clipped()
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
    
    // Animation states - default true for instant navigation
    @State private var headerAppeared = true
    @State private var commentsAppeared = true
    @State private var inputAppeared = true
    
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
                            .opacity(headerAppeared ? 1 : 0)
                            .offset(y: headerAppeared ? 0 : -10)
                        
                        Divider()
                            .opacity(headerAppeared ? 1 : 0)
                        
                        // Comments section
                        LazyVStack(spacing: 0) {
                            if commentsViewModel.isLoading && commentsViewModel.threads.isEmpty {
                                ProgressView()
                                    .padding(.top, 40)
                            } else if commentsViewModel.threads.isEmpty {
                                emptyStateView
                                    .opacity(commentsAppeared ? 1 : 0)
                                    .offset(y: commentsAppeared ? 0 : 15)
                            } else {
                                ForEach(Array(commentsViewModel.threads.enumerated()), id: \.element.id) { index, thread in
                                    CommentRow(
                                        comment: thread.comment,
                                        isReply: false,
                                        canSwipeToReply: true, // Main comments can always be replied to
                                        onLike: { commentsViewModel.toggleLike(for: thread.comment.id, currentUserId: authViewModel.currentUser?.id) },
                                        onReply: { startReplyTo(thread.comment) },
                                        onDelete: { deleteComment(thread.comment) }
                                    )
                                    .environmentObject(authViewModel)
                                    .opacity(commentsAppeared ? 1 : 0)
                                    .offset(y: commentsAppeared ? 0 : 20)
                                    .animation(
                                        .spring(response: 0.5, dampingFraction: 0.8)
                                        .delay(Double(index) * 0.05),
                                        value: commentsAppeared
                                    )
                                    
                                    ForEach(thread.replies) { reply in
                                        // Level 2 replies (direct replies to main comment) can be replied to
                                        // Level 3 replies (replies to replies) cannot be replied to
                                        let isLevel2Reply = reply.parentCommentId == thread.id
                                        
                                        CommentRow(
                                            comment: reply,
                                            isReply: true,
                                            canSwipeToReply: isLevel2Reply, // Only level 2 replies can be replied to
                                            onLike: { commentsViewModel.toggleLike(for: reply.id, currentUserId: authViewModel.currentUser?.id) },
                                            onReply: { startReplyTo(reply) },
                                            onDelete: { deleteComment(reply) }
                                        )
                                        .environmentObject(authViewModel)
                                        .opacity(commentsAppeared ? 1 : 0)
                                        .offset(y: commentsAppeared ? 0 : 20)
                                    }
                                }
                                
                                Color.clear
                                    .frame(height: 1)
                                    .id(bottomID)
                            }
                        }
                        .padding(.top, 8)
                        .padding(.bottom, 20) // Extra space at bottom for scrolling
                    }
                    .frame(maxWidth: .infinity)
                    .background(Color(.systemBackground))
                    .refreshable {
                        await reloadComments()
                    }
                }
                .scrollBounceBehavior(.always) // Allow bounce scrolling
                .onChange(of: commentsViewModel.totalCommentCount) { _ in
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        scrollProxy.scrollTo(bottomID, anchor: .bottom)
                    }
                }
            }
            
            // Add comment section
            commentInputSection
                .opacity(inputAppeared ? 1 : 0)
                .offset(y: inputAppeared ? 0 : 30)
        }
        .background(Color(.systemBackground))
        .navigationTitle("Diskussion")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await reloadComments()
            await loadTopLikers()
        }
        .onReceive(RealtimeSocialService.shared.$postLikeUpdated.compactMap { $0 }) { update in
            // Re-fetch top likers when a like event fires for this post
            if update.postId == post.id {
                SocialService.shared.invalidateTopLikersCache(forPostId: post.id)
                Task { await loadTopLikers() }
            }
        }
        .onAppear {
            // Track navigation depth to hide tab bar
            NavigationDepthTracker.shared.setAtRoot(false)
            
            // Setup real-time listeners for comment likes and new/deleted comments
            commentsViewModel.setupRealtimeListeners(currentUserId: authViewModel.currentUser?.id)
        }
        .onDisappear {
            NavigationDepthTracker.shared.setAtRoot(true)
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
            // Insert @username: in the text field (colon marks end of mention)
            if let userName = comment.userName, !userName.isEmpty {
                newComment = "@\(userName): "
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
    let canSwipeToReply: Bool // Whether this comment can be swiped to reply (false for 3rd level comments)
    let onLike: () -> Void
    let onReply: () -> Void
    let onDelete: () -> Void
    @EnvironmentObject private var authViewModel: AuthViewModel
    
    // Swipe state
    @State private var swipeOffset: CGFloat = 0
    @State private var isDragging = false
    @GestureState private var dragOffset: CGFloat = 0
    @State private var showDeleteConfirmation = false
    
    // Like animation state
    @State private var likeScale: CGFloat = 1.0
    
    private let actionThreshold: CGFloat = -100
    private let maxSwipe: CGFloat = -150
    
    // Check if current user owns this comment
    private var isOwnComment: Bool {
        guard let currentUserId = authViewModel.currentUser?.id else { return false }
        return comment.userId == currentUserId
    }
    
    // Can swipe if: own comment (delete) OR can reply to this comment
    private var canSwipe: Bool {
        isOwnComment || canSwipeToReply
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
                .offset(x: canSwipe ? currentOffset : 0)
                .contentShape(Rectangle()) // Ensure the entire area is tappable/draggable
                .highPriorityGesture(
                    DragGesture(minimumDistance: 8, coordinateSpace: .local)
                        .updating($dragOffset) { value, state, _ in
                            // Only allow swipe if canSwipe is true
                            guard canSwipe else { return }
                            
                            // Only capture horizontal swipes (left swipe primarily)
                            let horizontalAmount = abs(value.translation.width)
                            let verticalAmount = abs(value.translation.height)
                            
                            // Must be more horizontal than vertical and moving left
                            if horizontalAmount > verticalAmount * 1.5 && value.translation.width < 0 {
                                state = value.translation.width
                            }
                        }
                        .onChanged { value in
                            guard canSwipe else { return }
                            let horizontalAmount = abs(value.translation.width)
                            let verticalAmount = abs(value.translation.height)
                            if horizontalAmount > verticalAmount * 1.5 && value.translation.width < 0 {
                                isDragging = true
                            }
                        }
                        .onEnded { value in
                            guard canSwipe else { return }
                            isDragging = false
                            
                            // Only process if it was a horizontal swipe
                            let horizontalAmount = abs(value.translation.width)
                            let verticalAmount = abs(value.translation.height)
                            guard horizontalAmount > verticalAmount else {
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                                    swipeOffset = 0
                                }
                                return
                            }
                            
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
                    Button {
                        // Haptic feedback
                        let haptic = UIImpactFeedbackGenerator(style: .light)
                        haptic.impactOccurred()
                        
                        // Animation
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.5)) {
                            likeScale = 1.4
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                            withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) {
                                likeScale = 1.0
                            }
                        }
                        
                        onLike()
                    } label: {
                        Image(systemName: comment.isLikedByCurrentUser ? "heart.fill" : "heart")
                            .font(.system(size: 14))
                            .foregroundColor(comment.isLikedByCurrentUser ? .red : .secondary)
                            .scaleEffect(likeScale)
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
        // Check if the comment starts with @username: (reply pattern)
        let content = comment.content
        
        // Look for @username: pattern at the start (colon marks end of mention)
        if content.hasPrefix("@") {
            // Find the colon that ends the @mention
            if let colonIndex = content.firstIndex(of: ":") {
                let mention = String(content[...colonIndex]) // includes @ and :
                let afterColon = content.index(after: colonIndex)
                let restOfComment = afterColon < content.endIndex ? String(content[afterColon...]).trimmingCharacters(in: .whitespaces) : ""
                
                return AnyView(
                    (Text(mention)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.primary)
                    + Text(" " + restOfComment)
                        .font(.system(size: 15))
                        .foregroundColor(.primary))
                    .fixedSize(horizontal: false, vertical: true)
                )
            }
        }
        
        // Regular comment without @mention prefix
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
    
    // Real-time updates
    private let realtimeService = RealtimeSocialService.shared
    private var cancellables = Set<AnyCancellable>()
    
    /// Invalidate cache to force fresh data on next fetch
    static func invalidateCache() {
        shared.lastSuccessfulFetch = nil
    }
    
    func insertPostAtTop(_ post: SocialWorkoutPost) {
        guard !posts.contains(where: { $0.id == post.id }) else { return }
        withAnimation(.easeOut(duration: 0.3)) {
            posts.insert(post, at: 0)
        }
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
    
    // MARK: - Real-time Updates
    
    func setupRealtimeListeners() {
        // Listen for post like updates
        realtimeService.$postLikeUpdated
            .compactMap { $0 }
            .sink { [weak self] update in
                self?.handlePostLikeUpdate(postId: update.postId, delta: update.delta, userId: update.userId)
            }
            .store(in: &cancellables)
        
        // Listen for new comments
        realtimeService.$commentAdded
            .compactMap { $0 }
            .sink { [weak self] update in
                self?.handleCommentAdded(postId: update.postId, comment: update.comment)
            }
            .store(in: &cancellables)
        
        // Listen for deleted comments
        realtimeService.$commentDeleted
            .compactMap { $0 }
            .sink { [weak self] update in
                self?.handleCommentDeleted(postId: update.postId, commentId: update.commentId)
            }
            .store(in: &cancellables)
        
        // Listen for comment like updates
        realtimeService.$commentLikeUpdated
            .compactMap { $0 }
            .sink { [weak self] update in
                self?.handleCommentLikeUpdate(commentId: update.commentId, delta: update.delta, userId: update.userId)
            }
            .store(in: &cancellables)
    }
    
    private func handlePostLikeUpdate(postId: String, delta: Int, userId: String) {
        guard let index = posts.firstIndex(where: { $0.id == postId }) else { return }
        
        // Invalidate top likers cache so fresh data is fetched
        SocialService.shared.invalidateTopLikersCache(forPostId: postId)
        
        let oldPost = posts[index]
        let newCount = max(0, (oldPost.likeCount ?? 0) + delta)
        let newIsLiked = userId == currentUserId ? (delta > 0) : oldPost.isLikedByCurrentUser
        
        // Create new post with updated values
        let updatedPost = SocialWorkoutPost(
            id: oldPost.id,
            userId: oldPost.userId,
            activityType: oldPost.activityType,
            title: oldPost.title,
            description: oldPost.description,
            distance: oldPost.distance,
            duration: oldPost.duration,
            elevationGain: oldPost.elevationGain,
            imageUrl: oldPost.imageUrl,
            userImageUrl: oldPost.userImageUrl,
            createdAt: oldPost.createdAt,
            userName: oldPost.userName,
            userAvatarUrl: oldPost.userAvatarUrl,
            userIsPro: oldPost.userIsPro,
            location: oldPost.location,
            strokes: oldPost.strokes,
            likeCount: newCount,
            commentCount: oldPost.commentCount,
            isLikedByCurrentUser: newIsLiked,
            splits: oldPost.splits,
            exercises: oldPost.exercises,
            trainedWith: oldPost.trainedWith,
            pbExerciseName: oldPost.pbExerciseName,
            pbValue: oldPost.pbValue,
            streakCount: oldPost.streakCount,
            source: oldPost.source,
            deviceName: oldPost.deviceName,
            routeData: oldPost.routeData
        )
        
        posts[index] = updatedPost
        
        // Update known good counts
        if newCount > 0 {
            knownGoodCounts[postId] = (likeCount: newCount, commentCount: updatedPost.commentCount ?? 0)
        }
        
        print("✅ Real-time: Updated post \(postId) likes: \(newCount)")
    }
    
    private func handleCommentAdded(postId: String, comment: PostComment) {
        guard let index = posts.firstIndex(where: { $0.id == postId }) else { return }
        
        let oldPost = posts[index]
        let newCount = (oldPost.commentCount ?? 0) + 1
        
        // Create new post with updated values
        let updatedPost = SocialWorkoutPost(
            id: oldPost.id,
            userId: oldPost.userId,
            activityType: oldPost.activityType,
            title: oldPost.title,
            description: oldPost.description,
            distance: oldPost.distance,
            duration: oldPost.duration,
            elevationGain: oldPost.elevationGain,
            imageUrl: oldPost.imageUrl,
            userImageUrl: oldPost.userImageUrl,
            createdAt: oldPost.createdAt,
            userName: oldPost.userName,
            userAvatarUrl: oldPost.userAvatarUrl,
            userIsPro: oldPost.userIsPro,
            location: oldPost.location,
            strokes: oldPost.strokes,
            likeCount: oldPost.likeCount,
            commentCount: newCount,
            isLikedByCurrentUser: oldPost.isLikedByCurrentUser,
            splits: oldPost.splits,
            exercises: oldPost.exercises,
            trainedWith: oldPost.trainedWith,
            pbExerciseName: oldPost.pbExerciseName,
            pbValue: oldPost.pbValue,
            streakCount: oldPost.streakCount,
            source: oldPost.source,
            deviceName: oldPost.deviceName,
            routeData: oldPost.routeData
        )
        
        posts[index] = updatedPost
        
        // Update known good counts
        knownGoodCounts[postId] = (likeCount: updatedPost.likeCount ?? 0, commentCount: newCount)
        
        print("✅ Updated post \(postId) comments: \(newCount)")
    }
    
    private func handleCommentDeleted(postId: String, commentId: String) {
        guard let index = posts.firstIndex(where: { $0.id == postId }) else { return }
        
        let oldPost = posts[index]
        let newCount = max(0, (oldPost.commentCount ?? 0) - 1)
        
        // Create new post with updated values
        let updatedPost = SocialWorkoutPost(
            id: oldPost.id,
            userId: oldPost.userId,
            activityType: oldPost.activityType,
            title: oldPost.title,
            description: oldPost.description,
            distance: oldPost.distance,
            duration: oldPost.duration,
            elevationGain: oldPost.elevationGain,
            imageUrl: oldPost.imageUrl,
            userImageUrl: oldPost.userImageUrl,
            createdAt: oldPost.createdAt,
            userName: oldPost.userName,
            userAvatarUrl: oldPost.userAvatarUrl,
            userIsPro: oldPost.userIsPro,
            location: oldPost.location,
            strokes: oldPost.strokes,
            likeCount: oldPost.likeCount,
            commentCount: newCount,
            isLikedByCurrentUser: oldPost.isLikedByCurrentUser,
            splits: oldPost.splits,
            exercises: oldPost.exercises,
            trainedWith: oldPost.trainedWith,
            pbExerciseName: oldPost.pbExerciseName,
            pbValue: oldPost.pbValue,
            streakCount: oldPost.streakCount,
            source: oldPost.source,
            deviceName: oldPost.deviceName,
            routeData: oldPost.routeData
        )
        
        posts[index] = updatedPost
        
        // Update known good counts
        if newCount > 0 {
            knownGoodCounts[postId] = (likeCount: updatedPost.likeCount ?? 0, commentCount: newCount)
        }
        
        print("✅ Updated post \(postId) comments after deletion: \(newCount)")
    }
    
    private func handleCommentLikeUpdate(commentId: String, delta: Int, userId: String) {
        // This will be used in comment detail views
        print("✅ Comment \(commentId) like updated: delta \(delta)")
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
                    elevationGain: post.elevationGain,
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
                    trainedWith: post.trainedWith,
                    pbExerciseName: post.pbExerciseName,
                    pbValue: post.pbValue,
                    streakCount: post.streakCount,
                    source: post.source,
                    deviceName: post.deviceName,
                    routeData: post.routeData
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
                elevationGain: post.elevationGain,
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
                trainedWith: post.trainedWith,
                pbExerciseName: post.pbExerciseName,
                pbValue: post.pbValue,
                streakCount: post.streakCount,
                source: post.source,
                deviceName: post.deviceName,
                routeData: post.routeData
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
                elevationGain: updatedPost.elevationGain,
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
                pbValue: updatedPost.pbValue,
                streakCount: updatedPost.streakCount,
                source: updatedPost.source,
                deviceName: updatedPost.deviceName
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
                elevationGain: updatedPost.elevationGain,
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
                pbValue: updatedPost.pbValue,
                streakCount: updatedPost.streakCount,
                source: updatedPost.source,
                deviceName: updatedPost.deviceName
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
    private let realtimeService = RealtimeSocialService.shared
    private var cancellables = Set<AnyCancellable>()
    
    var totalCommentCount: Int {
        threads.reduce(0) { $0 + 1 + $1.replies.count }
    }
    
    func setupRealtimeListeners(currentUserId: String?) {
        // Clear previous subscriptions to avoid duplicates
        cancellables.removeAll()
        
        // Listen for comment like updates
        realtimeService.$commentLikeUpdated
            .compactMap { $0 }
            .sink { [weak self] update in
                self?.handleCommentLikeUpdate(commentId: update.commentId, delta: update.delta, userId: update.userId, currentUserId: currentUserId)
            }
            .store(in: &cancellables)
        
        // Listen for new comments in real-time
        realtimeService.$commentAdded
            .compactMap { $0 }
            .sink { [weak self] update in
                self?.handleRealtimeCommentAdded(postId: update.postId, comment: update.comment, currentUserId: currentUserId)
            }
            .store(in: &cancellables)
        
        // Listen for deleted comments in real-time
        realtimeService.$commentDeleted
            .compactMap { $0 }
            .sink { [weak self] update in
                self?.handleRealtimeCommentDeleted(postId: update.postId, commentId: update.commentId)
            }
            .store(in: &cancellables)
    }
    
    private func handleRealtimeCommentAdded(postId: String, comment: PostComment, currentUserId: String?) {
        // Only handle comments for the current post
        guard postId == self.postId else { return }
        // Avoid duplicates - check if we already have this comment (e.g. from optimistic insert)
        if findComment(by: comment.id) != nil { return }
        
        appendComment(comment)
        print("✅ Real-time: Added comment to thread for post \(postId)")
    }
    
    private func handleRealtimeCommentDeleted(postId: String, commentId: String) {
        // Only handle comments for the current post
        guard postId == self.postId else { return }
        
        removeComment(withId: commentId)
        print("✅ Real-time: Removed comment \(commentId) from thread")
    }
    
    private func handleCommentLikeUpdate(commentId: String, delta: Int, userId: String, currentUserId: String?) {
        // Find and update the comment in threads
        for (threadIndex, thread) in threads.enumerated() {
            // Check if it's the main comment
            if thread.comment.id == commentId {
                var updatedComment = thread.comment
                updatedComment.likeCount = max(0, updatedComment.likeCount + delta)
                if userId == currentUserId {
                    updatedComment.isLikedByCurrentUser = delta > 0
                }
                threads[threadIndex].comment = updatedComment
                return
            }
            
            // Check if it's a reply
            for (replyIndex, reply) in thread.replies.enumerated() {
                if reply.id == commentId {
                    var updatedReply = reply
                    updatedReply.likeCount = max(0, updatedReply.likeCount + delta)
                    if userId == currentUserId {
                        updatedReply.isLikedByCurrentUser = delta > 0
                    }
                    threads[threadIndex].replies[replyIndex] = updatedReply
                    return
                }
            }
        }
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

// MARK: - Gym Achievement Banner
struct GymAchievementBanner: View {
    let post: SocialWorkoutPost
    
    // Get the user's first name
    private var firstName: String {
        guard let name = post.userName?.trimmingCharacters(in: .whitespacesAndNewlines),
              !name.isEmpty else { return "Användaren" }
        return name.components(separatedBy: " ").first ?? name
    }
    
    // Determine which achievement to show (if any)
    private var achievement: GymAchievement? {
        // 1. If user hit their heaviest lift in any exercise
        if let pbExercise = post.pbExerciseName, !pbExercise.isEmpty {
            return .heaviestLift(exercise: pbExercise)
        }
        
        // 2. If user has a streak over 3 days
        if let streakCount = post.streakCount, streakCount > 3 {
            return .streak(days: streakCount)
        }
        
        // No achievement to show
        return nil
    }
    
    // Only show the banner if there's a qualifying achievement
    var shouldShow: Bool {
        return achievement != nil
    }
    
    var body: some View {
        if let achievement = achievement {
            HStack(spacing: 12) {
                // Achievement icon - gray/black theme
                ZStack {
                    Circle()
                        .fill(Color(.systemGray5))
                        .frame(width: 36, height: 36)
                    
                    Image(systemName: achievement.iconName)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Color(.systemGray))
                }
                
                // Achievement text
                Text(achievement.message(firstName: firstName))
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.primary)
                    .lineLimit(2)
                
                Spacer()
            }
            .padding(12)
            .background(Color(.systemGray6).opacity(0.8))
            .cornerRadius(10)
        }
    }
}

// MARK: - Gym Achievement Types (Simplified)
enum GymAchievement {
    case heaviestLift(exercise: String)
    case streak(days: Int)
    
    var iconName: String {
        switch self {
        case .heaviestLift: return "trophy.fill"
        case .streak: return "flame.fill"
        }
    }
    
    func message(firstName: String) -> String {
        switch self {
        case .heaviestLift(let exercise):
            return "\(firstName) tog sitt tyngsta lyft i \(exercise)"
        case .streak(let days):
            return "\(firstName) har en streak på \(days) dagar"
        }
    }
}

// MARK: - Gym Exercises List View
struct GymExercisesListView: View {
    let exercises: [GymExercisePost]
    let userImage: String?
    let userId: String?
    let postDate: Date?
    var onTapImage: (() -> Void)? = nil
    @State private var currentPage = 0
    @State private var prResults: [String: Double] = [:] // exerciseName: percentage
    
    init(exercises: [GymExercisePost], userImage: String?, userId: String? = nil, postDate: Date? = nil, onTapImage: (() -> Void)? = nil) {
        self.exercises = exercises
        self.userImage = userImage
        self.userId = userId
        self.postDate = postDate
        self.onTapImage = onTapImage
    }
    
    private var hasUserImage: Bool {
        if let userImage, !userImage.isEmpty { return true }
        return false
    }
    
    var body: some View {
        ZStack(alignment: .bottom) {
            if hasUserImage {
                // Swipeable pages using TabView
                TabView(selection: $currentPage) {
                    userImagePage
                        .tag(0)
                    
                    exercisesListPage
                        .tag(1)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(Color(.systemBackground))
                        .shadow(color: Color.black.opacity(0.08), radius: 12, x: 0, y: 6)
                )
            } else {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color(.systemBackground))
                    .shadow(color: Color.black.opacity(0.08), radius: 12, x: 0, y: 6)
                    .overlay(
                        exercisesListPage
                            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    )
            }
            
            // Page indicators at bottom (only if has user image)
            if hasUserImage {
                HStack(spacing: 8) {
                    ForEach(0..<2, id: \.self) { index in
                        Circle()
                            .fill(currentPage == index ? Color.primary : Color.gray.opacity(0.4))
                            .frame(width: 8, height: 8)
                    }
                }
                .padding(.bottom, 12)
            }
        }
        .frame(height: hasUserImage ? 420 : 380)
        .padding(.horizontal, 16)
        .task {
            await loadPRs()
        }
    }
    
    private func loadPRs() async {
        guard let userId = userId, let postDate = postDate else { return }
        
        var results: [String: Double] = [:]
        for exercise in exercises {
            let pr = await ExercisePRService.shared.calculatePR(
                for: exercise,
                userId: userId,
                postDate: postDate
            )
            if let percent = pr.displayPercent, percent > 0 {
                results[exercise.name] = percent
            }
        }
        
        await MainActor.run {
            self.prResults = results
        }
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
                
                // Show PR percentage if available
                if let prPercent = prResults[exercise.name], prPercent > 0 {
                    Text("+\(String(format: "%.0f", prPercent))% ökning!")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.green)
                }
                
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
                    // Tap gesture only on the center area of the image
                    .overlay(
                        Color.clear
                            .contentShape(Rectangle())
                            .onTapGesture {
                                onTapImage?()
                            }
                            .padding(.horizontal, 60) // Leave edges untappable for buttons
                            .padding(.vertical, 60)
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
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(maxWidth: .infinity, alignment: isLivePhoto ? .leading : .center)
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

// MARK: - Route Map Fallback View
// Generates a map snapshot from stored route_data when the original image upload failed
struct RouteMapFallbackView: View {
    let routeData: String
    let activityType: String
    
    @State private var mapImage: UIImage? = nil
    @State private var isLoading = true
    
    var body: some View {
        Group {
            if let mapImage = mapImage {
                Image(uiImage: mapImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(height: 300)
                    .clipped()
            } else if isLoading {
                RoundedRectangle(cornerRadius: 0)
                    .fill(Color(.systemGray6))
                    .frame(height: 300)
                    .overlay(
                        ProgressView()
                            .scaleEffect(1.2)
                    )
            } else {
                // Could not generate map - show nothing
                EmptyView()
            }
        }
        .task {
            await generateMap()
        }
    }
    
    private func generateMap() async {
        guard let coordinates = parseRouteData(routeData), coordinates.count > 1 else {
            await MainActor.run { isLoading = false }
            return
        }
        
        let activity = ActivityType(rawValue: activityType)
        
        await withCheckedContinuation { continuation in
            MapSnapshotService.shared.generateRouteSnapshot(
                routeCoordinates: coordinates,
                userLocation: coordinates.first,
                activity: activity
            ) { image in
                DispatchQueue.main.async {
                    self.mapImage = image
                    self.isLoading = false
                }
                continuation.resume()
            }
        }
    }
    
    private func parseRouteData(_ json: String) -> [CLLocationCoordinate2D]? {
        guard let data = json.data(using: .utf8) else { return nil }
        
        guard let coordsArray = try? JSONSerialization.jsonObject(with: data) as? [[String: Double]] else {
            return nil
        }
        
        let coordinates = coordsArray.compactMap { dict -> CLLocationCoordinate2D? in
            guard let lat = dict["lat"], let lon = dict["lon"] else { return nil }
            return CLLocationCoordinate2D(latitude: lat, longitude: lon)
        }
        
        return coordinates.count > 1 ? coordinates : nil
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

// MARK: - Dynamic Feed Ad Card
private struct FeedAdCard: View {
    let ad: AdCampaign
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 12) {
                if let imageURL = ad.imageURL {
                    AsyncImage(url: imageURL) { image in
                        image.resizable().scaledToFill()
                    } placeholder: {
                        Color.gray.opacity(0.3)
                    }
                    .frame(width: 40, height: 40)
                    .clipShape(Circle())
                } else {
                    Circle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 40, height: 40)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(ad.title)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.primary)
                            .lineLimit(1)
                        
                        Text("Sponsrad")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Capsule().fill(Color.gray))
                    }
                    
                    Text("Annons")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            
            if let imageURL = ad.imageURL {
                Button(action: openAd) {
                    AsyncImage(url: imageURL) { image in
                        image.resizable().aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Rectangle()
                            .fill(Color.gray.opacity(0.15))
                            .overlay(ProgressView())
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 400)
                    .clipped()
                }
                .buttonStyle(.plain)
            }
            
            if let description = ad.description, !description.isEmpty {
                Text(description)
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                    .padding(.horizontal, 16)
                    .padding(.top, 10)
            }
            
            Button(action: openAd) {
                HStack {
                    Text(ad.title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    Spacer()
                    
                    Text(ad.ctaLabel)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 8)
                        .background(Color.primary)
                        .cornerRadius(8)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .buttonStyle(.plain)
        }
        .background(Color(.systemBackground))
    }
    
    private func openAd() {
        AdService.shared.trackClick(campaignId: ad.id)
        if let url = ad.ctaURL {
            UIApplication.shared.open(url)
        }
    }
}

// MARK: - Sponsored Post Card (Up&DownCoach)
private struct SponsoredPostCard: View {
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack(spacing: 12) {
                // Profile picture - Up&DownCoach logo
                Image("logga")
                    .resizable()
                    .scaledToFill()
                    .frame(width: 40, height: 40)
                    .clipShape(Circle())
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text("Up&DownCoach")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.primary)
                        
                        Text("Sponsrad")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(
                                Capsule()
                                    .fill(Color.gray)
                            )
                    }
                    
                    Text("Annons")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            
            // Post image
            Button(action: {
                if let url = URL(string: "https://upanddowncoach.com") {
                    UIApplication.shared.open(url)
                }
            }) {
                Image("80")
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(maxWidth: .infinity)
                    .frame(height: 400)
                    .clipped()
            }
            .buttonStyle(.plain)
            
            // Bottom CTA
            Button(action: {
                if let url = URL(string: "https://upanddowncoach.com") {
                    UIApplication.shared.open(url)
                }
            }) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Up&DownCoach")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.primary)
                        Text("upanddowncoach.com")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Text("Besök")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 8)
                        .background(Color.primary)
                        .cornerRadius(8)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .buttonStyle(.plain)
        }
        .background(Color(.systemBackground))
    }
}

// MARK: - Pro Upgrade Banner
private struct ProUpgradeBanner: View {
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
                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("UPPGRADERA TILL")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.white.opacity(0.8))
                            .tracking(1.2)
                        
                        Text("PRO MEDLEMSKAP")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(.white)
                        
                        // CTA Button (White)
                        HStack(spacing: 6) {
                            Text("LÄS MER")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.black)
                            
                            Image(systemName: "arrow.right")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.black)
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(Color.white)
                        .cornerRadius(25)
                    }
                    
                    Spacer()
                    
                    // App Logo
                    Image("23")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 100, height: 100)
                        .cornerRadius(20)
                        .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 5)
                }
                .padding(24)
            }
            .frame(height: 160)
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color.white.opacity(0.3),
                                Color.white.opacity(0.1)
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .shadow(color: .black.opacity(0.4), radius: 15, x: 0, y: 8)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

// MARK: - Friends Location Map View
struct FriendsLocationMapView: View {
    let friends: [ActiveFriendSession]
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var region: MKCoordinateRegion
    @State private var selectedFriend: ActiveFriendSession?
    @State private var showUppyConfirmation = false
    @State private var isSendingUppy = false
    
    init(friends: [ActiveFriendSession]) {
        self.friends = friends
        
        // Calculate region to fit all friends
        let friendsWithLocation = friends.compactMap { $0.coordinate }
        
        if !friendsWithLocation.isEmpty {
            // Calculate center and span to include all friends
            let latitudes = friendsWithLocation.map { $0.latitude }
            let longitudes = friendsWithLocation.map { $0.longitude }
            
            let minLat = latitudes.min() ?? 59.3293
            let maxLat = latitudes.max() ?? 59.3293
            let minLon = longitudes.min() ?? 18.0686
            let maxLon = longitudes.max() ?? 18.0686
            
            let centerLat = (minLat + maxLat) / 2
            let centerLon = (minLon + maxLon) / 2
            
            let spanLat = max(abs(maxLat - minLat) * 1.5, 0.01) // Add 50% padding
            let spanLon = max(abs(maxLon - minLon) * 1.5, 0.01)
            
            _region = State(initialValue: MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: centerLat, longitude: centerLon),
                span: MKCoordinateSpan(latitudeDelta: spanLat, longitudeDelta: spanLon)
            ))
        } else {
            // Default to Stockholm if no locations
            _region = State(initialValue: MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 59.3293, longitude: 18.0686),
                span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
            ))
        }
    }
    
    var body: some View {
        ZStack {
            // Always show map
            let friendsWithLocation = friends.filter { $0.coordinate != nil }
            
            Map(coordinateRegion: $region, annotationItems: friendsWithLocation) { friend in
                        MapAnnotation(coordinate: friend.coordinate!) {
                            Button {
                                if isGymSession(friend.activityType) {
                                    selectedFriend = friend
                                    showUppyConfirmation = true
                                }
                            } label: {
                                VStack(spacing: 4) {
                                    // Friend avatar
                                    AsyncImage(url: URL(string: friend.avatarUrl ?? "")) { phase in
                                        switch phase {
                                        case .success(let image):
                                            image
                                                .resizable()
                                                .scaledToFill()
                                                .frame(width: 50, height: 50)
                                                .clipShape(Circle())
                                                .overlay(
                                                    Circle()
                                                        .stroke(Color.white, lineWidth: 3)
                                                )
                                                .shadow(radius: 5)
                                        case .failure(_), .empty:
                                            Circle()
                                                .fill(Color.gray.opacity(0.3))
                                                .frame(width: 50, height: 50)
                                                .overlay(
                                                    Image(systemName: "person.fill")
                                                        .font(.system(size: 24))
                                                        .foregroundColor(.gray)
                                                )
                                                .overlay(
                                                    Circle()
                                                        .stroke(Color.white, lineWidth: 3)
                                                )
                                                .shadow(radius: 5)
                                        @unknown default:
                                            EmptyView()
                                        }
                                    }
                                    
                                    // Name and duration
                                    VStack(spacing: 2) {
                                        Text(friend.userName.components(separatedBy: " ").first ?? friend.userName)
                                            .font(.system(size: 12, weight: .bold))
                                            .foregroundColor(.white)
                                        
                                        // Live duration timer
                                        TimelineView(.periodic(from: .now, by: 1.0)) { timeline in
                                            let currentDuration = timeline.date.timeIntervalSince(friend.startedAt)
                                            Text(formatDuration(currentDuration))
                                                .font(.system(size: 10, weight: .medium))
                                                .foregroundColor(.white.opacity(0.8))
                                        }
                                    }
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.black.opacity(0.7))
                                    .cornerRadius(8)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .mapControls {
                        // Hide all map controls (zoom buttons etc.)
                    }
                    .ignoresSafeArea()
            
            // Overlays
            VStack {
                    Spacer()
                    
                    // Bottom text overlay
                    if friendsWithLocation.isEmpty {
                        // Simple text when no active friends
                        Text("Dina vänner tränar inte just nu")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(
                                Capsule()
                                    .fill(Color(.systemBackground).opacity(0.9))
                            )
                            .padding(.bottom, 100)
                    } else {
                        // Friends count card
                        HStack(spacing: 12) {
                            Image("upanddownlog")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 40, height: 40)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("\(friendsWithLocation.count) vänner tränar")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.primary)
                                
                                Text("Aktiva pass just nu")
                                    .font(.system(size: 14))
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color(.systemBackground))
                                .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 4)
                        )
                        .padding(.horizontal)
                        .padding(.bottom, 100)
                    }
                }
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle("Vänner som tränar")
        .alert("Skicka en Uppy till \(selectedFriend?.userName ?? "")", isPresented: $showUppyConfirmation) {
            Button("Avbryt", role: .cancel) {
                selectedFriend = nil
            }
            Button("Skicka 💪") {
                if let friend = selectedFriend {
                    sendUppy(to: friend)
                }
            }
        } message: {
            Text("Heja på din vän under deras gympass!")
        }
        .onAppear {
            // Hide the floating add button when map is shown
            NotificationCenter.default.post(name: NSNotification.Name("HideFloatingButton"), object: nil)
        }
        .onDisappear {
            // Show the floating add button again when leaving map
            NotificationCenter.default.post(name: NSNotification.Name("ShowFloatingButton"), object: nil)
        }
    }
    
    private func isGymSession(_ activityType: String) -> Bool {
        let lower = activityType.lowercased()
        return lower == "gym" || lower == "walking" || lower == "gympass" || lower == "strength"
    }
    
    private func sendUppy(to friend: ActiveFriendSession) {
        guard let senderId = authViewModel.currentUser?.id,
              let senderName = authViewModel.currentUser?.name,
              !isSendingUppy else { return }
        
        isSendingUppy = true
        
        Task {
            do {
                try await UppyService.shared.sendUppy(
                    sessionId: friend.id,
                    fromUserId: senderId,
                    fromUserName: senderName,
                    fromUserAvatar: authViewModel.currentUser?.avatarUrl,
                    toUserId: friend.userId,
                    toUserName: friend.userName
                )
                
                await MainActor.run {
                    isSendingUppy = false
                    selectedFriend = nil
                    UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                    
                    // Post notification for real-time update
                    NotificationCenter.default.post(name: .uppyReceived, object: nil)
                }
                
                print("✅ Uppy sent successfully")
            } catch UppyError.alreadySent {
                await MainActor.run {
                    isSendingUppy = false
                    selectedFriend = nil
                }
                print("⚠️ Already sent Uppy to this session")
            } catch {
                print("❌ Failed to send Uppy: \(error)")
                await MainActor.run {
                    isSendingUppy = false
                }
            }
        }
    }
    
    // MARK: - Helper Functions
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        let seconds = Int(duration) % 60
        
        if hours > 0 {
            return String(format: "%dh %02dm", hours, minutes)
        } else if minutes > 0 {
            return String(format: "%dm %02ds", minutes, seconds)
        } else {
            return String(format: "%ds", seconds)
        }
    }
}

#Preview {
    SocialView()
        .environmentObject(AuthViewModel())
}
