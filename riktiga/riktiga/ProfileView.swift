import SwiftUI
import Combine
import PhotosUI
import Supabase

// MARK: - ProfileActivitiesView (Activities tab content)
struct ProfileActivitiesView: View {
    var onPublicProfileTapped: (() -> Void)? = nil
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var isPremium = RevenueCatManager.shared.isProMember
    @State private var showImagePicker = false
    @State private var bannerPickerItem: PhotosPickerItem?
    @State private var avatarPickerItem: PhotosPickerItem?
    @State private var bannerUrl: String?
    @State private var isUploadingBanner = false
    @State private var isUploadingAvatar = false
    @State private var profileImage: UIImage?
    @State private var showMyPurchases = false
    @State private var showFindFriends = false
    @State private var showFollowersList = false
    @State private var showFollowingList = false
    @State private var followersCount = 0
    @State private var followingCount = 0
    @State private var profileObserver: NSObjectProtocol?
    @State private var showEditProfile = false
    @State private var showPaywall = false
    @State private var activityCount: Int = 0
    @State private var lastStatsLoad: Date?
    @State private var isInitialLoad = true
    @StateObject private var myPostsViewModel = SocialViewModel()
    @State private var selectedPost: SocialWorkoutPost?
    @State private var navigationPath = NavigationPath()
    @State private var showRoutines = false
    @State private var showSharedRoutines = false
    @State private var myStories: [Story] = []
    @State private var showStoryViewer = false
    @State private var selectedUserStories: UserStories? = nil
    @State private var friendUsers: [UserSearchResult] = []
    @State private var selectedFriendUserId: String? = nil
    @State private var myEvents: [Event] = []
    @State private var showCreateEvent = false
    @State private var selectedEvent: Event? = nil
    private let statsLoadThrottle: TimeInterval = 60
    
    // Computed property to handle empty or nil name
    private var displayName: String {
        let name = authViewModel.currentUser?.name ?? ""
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Användare" : trimmed
    }
    
    var body: some View {
        ZStack {
            Color.white
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 16) {
                    VStack(spacing: 16) {
                    VStack(spacing: 0) {
                        // MARK: - Facebook-style Banner + Avatar
                        ZStack(alignment: .bottom) {
                            // Banner
                            ZStack(alignment: .bottomTrailing) {
                                if let bannerUrl = bannerUrl, !bannerUrl.isEmpty {
                                    LocalAsyncImage(path: bannerUrl)
                                        .aspectRatio(contentMode: .fill)
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 180)
                                        .clipped()
                                } else {
                                    Color(.systemGray4)
                                        .frame(height: 180)
                                }
                                
                                PhotosPicker(selection: $bannerPickerItem, matching: .images) {
                                    Image(systemName: "camera.fill")
                                        .font(.system(size: 13))
                                        .foregroundColor(.white)
                                        .frame(width: 30, height: 30)
                                        .background(Color.black.opacity(0.6))
                                        .clipShape(Circle())
                                }
                                .padding(10)
                            }
                            .frame(height: 180)
                            
                            // Avatar overlapping banner
                            ZStack(alignment: .bottomTrailing) {
                                Button(action: {
                                    if !myStories.isEmpty {
                                        let myUserStories = UserStories(
                                            id: authViewModel.currentUser?.id ?? "",
                                            userId: authViewModel.currentUser?.id ?? "",
                                            username: displayName,
                                            avatarUrl: authViewModel.currentUser?.avatarUrl,
                                            isProMember: authViewModel.currentUser?.isProMember ?? false,
                                            stories: myStories,
                                            hasUnviewedStories: false
                                        )
                                        selectedUserStories = myUserStories
                                    }
                                }) {
                                    ZStack {
                                        if !myStories.isEmpty {
                                            if isPremium {
                                                RoundedRectangle(cornerRadius: 128 * 0.3)
                                                    .stroke(
                                                        LinearGradient(
                                                            colors: [Color.white, Color.black, Color.gray],
                                                            startPoint: .topLeading,
                                                            endPoint: .bottomTrailing
                                                        ),
                                                        lineWidth: 3
                                                    )
                                                    .frame(width: 133, height: 133)
                                            } else {
                                                Circle()
                                                    .stroke(
                                                        LinearGradient(
                                                            colors: [Color.white, Color.black, Color.gray],
                                                            startPoint: .topLeading,
                                                            endPoint: .bottomTrailing
                                                        ),
                                                        lineWidth: 3
                                                    )
                                                    .frame(width: 128, height: 128)
                                            }
                                        }
                                        
                                        ProfileImage(url: authViewModel.currentUser?.avatarUrl, size: 120, isPro: isPremium)
                                            .overlay(
                                                Group {
                                                    if isPremium {
                                                        RoundedRectangle(cornerRadius: 120 * 0.3)
                                                            .stroke(Color(.systemBackground), lineWidth: 4)
                                                    } else {
                                                        Circle()
                                                            .stroke(Color(.systemBackground), lineWidth: 4)
                                                    }
                                                }
                                            )
                                    }
                                }
                                .buttonStyle(.plain)
                                
                                PhotosPicker(selection: $avatarPickerItem, matching: .images) {
                                    Image(systemName: "camera.fill")
                                        .font(.system(size: 11))
                                        .foregroundColor(.white)
                                        .frame(width: 28, height: 28)
                                        .background(Color.black.opacity(0.7))
                                        .clipShape(Circle())
                                        .overlay(Circle().stroke(Color(.systemBackground), lineWidth: 2))
                                }
                            }
                            .offset(y: 60)
                        }
                        
                        Spacer().frame(height: 66)
                        
                        Text(displayName)
                            .font(.system(size: 22, weight: .bold))
                        
                        if let user = authViewModel.currentUser,
                           let name = SchoolService.institutionName(for: user.verifiedSchoolEmail ?? user.email) {
                            Text(name)
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer().frame(height: 6)
                        
                        // Stats row
                        HStack(spacing: 0) {
                            VStack(spacing: 2) {
                                Text("\(formatNumber(activityCount))")
                                    .font(.system(size: 16, weight: .bold))
                                    .contentTransition(.numericText())
                                Text(L.t(sv: "Pass", nb: "Økter"))
                                    .font(.system(size: 11))
                                    .foregroundColor(.gray)
                            }
                            .frame(maxWidth: .infinity)
                            
                            Button { showFollowersList = true } label: {
                                VStack(spacing: 2) {
                                    Text("\(followersCount)")
                                        .font(.system(size: 16, weight: .bold))
                                        .contentTransition(.numericText())
                                    Text(L.t(sv: "Följare", nb: "Følgere"))
                                        .font(.system(size: 11))
                                        .foregroundColor(.gray)
                                }
                                .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.plain)
                            
                            Button { showFollowingList = true } label: {
                                VStack(spacing: 2) {
                                    Text("\(followingCount)")
                                        .font(.system(size: 16, weight: .bold))
                                        .contentTransition(.numericText())
                                    Text(L.t(sv: "Följer", nb: "Følger"))
                                        .font(.system(size: 11))
                                        .foregroundColor(.gray)
                                }
                                .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.bottom, 12)
                    }
                    .background(Color(.systemBackground))
                    .cornerRadius(16)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    
                    // MARK: - Profile Buttons
                    HStack(spacing: 8) {
                        Button(action: { onPublicProfileTapped?() }) {
                            HStack(spacing: 6) {
                                Image(systemName: "person.crop.circle")
                                    .font(.system(size: 14, weight: .medium))
                                Text(L.t(sv: "Publik profil", nb: "Offentlig profil"))
                                    .font(.system(size: 14, weight: .medium))
                            }
                            .foregroundColor(.primary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 11)
                            .background(Color(.systemGray5))
                            .cornerRadius(10)
                        }
                        
                        Button(action: { showEditProfile = true }) {
                            HStack(spacing: 6) {
                                Image(systemName: "pencil")
                                    .font(.system(size: 14, weight: .medium))
                                Text(L.t(sv: "Redigera profil", nb: "Rediger profil"))
                                    .font(.system(size: 14, weight: .medium))
                            }
                            .foregroundColor(.primary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 11)
                            .background(Color(.systemGray5))
                            .cornerRadius(10)
                        }
                    }
                    
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
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.primary, lineWidth: 2)
                    )
                    
                    // MARK: - Up&Down Live Gallery
                    UpAndDownLiveGallery(posts: myPostsViewModel.posts)
                    
                    // MARK: - Friends Grid
                    if !friendUsers.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Text(L.t(sv: "Vänner", nb: "Venner"))
                                    .font(.system(size: 18, weight: .bold))
                                Spacer()
                                Button {
                                    showFollowingList = true
                                } label: {
                                    Text(L.t(sv: "Visa alla", nb: "Vis alle"))
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(.primary)
                                }
                            }
                            
                            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 4), spacing: 10) {
                                ForEach(friendUsers.prefix(4)) { friend in
                                    Button {
                                        selectedFriendUserId = friend.id
                                    } label: {
                                        VStack(spacing: 6) {
                                            ProfileAvatarView(path: friend.avatarUrl ?? "", size: 70)
                                            
                                            Text(friend.name.components(separatedBy: " ").first ?? friend.name)
                                                .font(.system(size: 12, weight: .medium))
                                                .foregroundColor(.primary)
                                                .lineLimit(1)
                                        }
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                        .padding(.top, 4)
                    }
                    
                    // MARK: - Action Buttons (2 rows of 2)
                    VStack(spacing: 10) {
                        // Row 1: Mina köp & Hitta vänner
                        HStack(spacing: 10) {
                            ProfileCardButton(
                                icon: "cart.fill",
                                label: "Mina köp",
                                action: { showMyPurchases = true }
                            )
                            
                            ProfileCardButton(
                                icon: "person.badge.plus.fill",
                                label: "Hitta vänner",
                                action: { showFindFriends = true }
                            )
                        }
                        
                        // Row 2: Gym rutiner & Dela pass med vänner
                        HStack(spacing: 10) {
                            ProfileCardButton(
                                icon: "figure.strengthtraining.traditional",
                                label: "Gym rutiner",
                                action: { showRoutines = true }
                            )
                            
                            ProfileCardButton(
                                icon: "paperplane.fill",
                                label: "Dela pass med vänner",
                                action: { showSharedRoutines = true }
                            )
                        }
                    }
                    
                    // MARK: - Händelser (Events)
                    EventsSliderView(
                        events: myEvents,
                        isOwnProfile: true,
                        onCreateTapped: { showCreateEvent = true },
                        onEventTapped: { event in selectedEvent = event }
                    )
                    
                    // MARK: - Recovery Zone
                    if let userId = authViewModel.currentUser?.id {
                        RecoveryZoneView(userId: userId)
                            .padding(.top, 20)
                    }
                    
                    Divider()
                        .background(Color(.systemGray4))
                        .padding(.top, 24)
                    }
                    .padding(.horizontal, 16)
                    
                    // MARK: - My Posts Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Mina aktiviteter")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.primary)
                            .padding(.horizontal, 20)
                        
                        if myPostsViewModel.isLoading && myPostsViewModel.posts.isEmpty {
                            VStack(spacing: 12) {
                                ProgressView().tint(AppColors.brandBlue)
                                Text("Hämtar inlägg...")
                                    .font(.system(size: 14))
                                    .foregroundColor(.gray)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 40)
                        } else if myPostsViewModel.posts.isEmpty {
                            VStack(spacing: 12) {
                                Image(systemName: "figure.run")
                                    .font(.system(size: 48))
                                    .foregroundColor(.gray)
                                Text("Inga aktiviteter än")
                                    .font(.headline)
                                Text("Dina gym rutiner kommer visas här.")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 40)
                        } else {
                            LazyVStack(spacing: 0) {
                                ForEach(myPostsViewModel.posts) { post in
                                    SocialPostCard(
                                        post: post,
                                        onOpenDetail: { tappedPost in selectedPost = tappedPost },
                                        onLikeChanged: { postId, isLiked, count in
                                            myPostsViewModel.updatePostLikeStatus(postId: postId, isLiked: isLiked, likeCount: count)
                                        },
                                        onCommentCountChanged: { postId, count in
                                            myPostsViewModel.updatePostCommentCount(postId: postId, commentCount: count)
                                        },
                                        onPostDeleted: { postId in
                                            myPostsViewModel.removePost(postId: postId)
                                        }
                                    )
                                    .id(post.id) // Stable identity for better diffing
                                    Divider()
                                        .background(Color(.systemGray5))
                                }
                            }
                        }
                    }
                    
                    Spacer()
                    }
                .padding(.top, 16)
                }
            }
        } // ZStack
            .navigationDestination(item: $selectedPost) { post in
                WorkoutDetailView(post: post)
            }
            .sheet(isPresented: $showImagePicker) {
                ImagePicker(image: $profileImage, authViewModel: authViewModel)
            }
            .fullScreenCover(item: $selectedUserStories) { userStories in
                StoryViewerOverlay(
                    userStories: userStories,
                    currentUserId: authViewModel.currentUser?.id ?? "",
                    onStoryViewed: { _ in },
                    onDismiss: {
                        selectedUserStories = nil
                    }
                )
                .environmentObject(authViewModel)
                .background(Color.black)
                .ignoresSafeArea()
            }
            .sheet(isPresented: $showMyPurchases) {
                MyPurchasesView()
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
            .navigationDestination(isPresented: $showFollowingList) {
                if let userId = authViewModel.currentUser?.id {
                    FollowListView(userId: userId, listType: .following)
                        .environmentObject(authViewModel)
                }
            }
            .sheet(isPresented: $showEditProfile) {
                EditProfileView()
            }
            .sheet(isPresented: $showRoutines) {
                NavigationStack {
                    RoutinesView()
                        .environmentObject(authViewModel)
                }
            }
            .sheet(isPresented: $showSharedRoutines) {
                NavigationStack {
                    SharedRoutinesView()
                        .environmentObject(authViewModel)
                }
            }
            
            .sheet(isPresented: Binding(
                get: { selectedFriendUserId != nil },
                set: { if !$0 { selectedFriendUserId = nil } }
            )) {
                if let friendId = selectedFriendUserId {
                    NavigationStack {
                        UserProfileView(userId: friendId)
                            .toolbar {
                                ToolbarItem(placement: .navigationBarLeading) {
                                    Button(L.t(sv: "Stäng", nb: "Lukk")) {
                                        selectedFriendUserId = nil
                                    }
                                }
                            }
                    }
                }
            }
            .sheet(isPresented: $showCreateEvent) {
                if let userId = authViewModel.currentUser?.id {
                    CreateEventView(userId: userId) { newEvent in
                        myEvents.insert(newEvent, at: 0)
                    }
                }
            }
            .sheet(item: $selectedEvent) { event in
                NavigationStack {
                    EventDetailView(
                        event: event,
                        isOwnEvent: true,
                        onDeleted: {
                            myEvents.removeAll { $0.id == event.id }
                            selectedEvent = nil
                        }
                    )
                    .toolbar {
                        ToolbarItem(placement: .navigationBarLeading) {
                            Button(L.t(sv: "Stäng", nb: "Lukk")) {
                                selectedEvent = nil
                            }
                        }
                    }
                }
            }
            .onChange(of: bannerPickerItem) { _, newItem in
                guard let newItem else { return }
                Task { await uploadBanner(newItem) }
            }
            .onChange(of: avatarPickerItem) { _, newItem in
                guard let newItem else { return }
                Task { await uploadAvatar(newItem) }
            }
            .task {
                // Load banner URL
                bannerUrl = authViewModel.currentUser?.bannerUrl
                
                // Update premium status
                isPremium = RevenueCatManager.shared.isProMember
                
                // Load profile observer first (non-async)
                profileObserver = NotificationCenter.default.addObserver(
                    forName: .profileImageUpdated,
                    object: nil,
                    queue: .main
                ) { notification in
                    if let newImageUrl = notification.object as? String {
                        print("🔄 Profile image updated in UI: \(newImageUrl)")
                        authViewModel.objectWillChange.send()
                    }
                }
                
                // Ensure session is valid before loading data
                do {
                    try await AuthSessionManager.shared.ensureValidSession()
                } catch {
                    print("❌ Session invalid")
                }
                
                // Load data in parallel for faster loading
                await withTaskGroup(of: Void.self) { group in
                    group.addTask { @MainActor in
                        self.loadProfileStats()
                    }
                    group.addTask {
                        // Load user's own posts
                        if let userId = await self.authViewModel.currentUser?.id {
                            await self.myPostsViewModel.loadPostsForUser(userId: userId, viewerId: userId)
                            // Update activity count with loaded posts
                            await MainActor.run {
                                withAnimation(.smooth(duration: 0.4)) {
                                    self.activityCount = self.myPostsViewModel.posts.count
                                }
                            }
                            // Prefetch post images for faster display
                            await self.prefetchPostImages()
                        }
                    }
                    group.addTask {
                        // Load user's stories
                        await self.loadMyStories()
                    }
                    group.addTask {
                        if let userId = await self.authViewModel.currentUser?.id {
                            await self.loadMyEvents(userId: userId)
                        }
                    }
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("RefreshStories"))) { _ in
                Task {
                    await loadMyStories()
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("NavigateToSharedWorkouts"))) { _ in
                showSharedRoutines = true
            }
            .onReceive(RevenueCatManager.shared.$isProMember) { newValue in
                isPremium = newValue
            }
            .onReceive(NotificationCenter.default.publisher(for: .profileStatsUpdated)) { _ in
                loadProfileStats(force: true)
            }
            .onChange(of: myPostsViewModel.posts.count) { _, newCount in
                withAnimation(.smooth(duration: 0.4)) {
                    activityCount = newCount
                }
            }
            .onDisappear {
                if let observer = profileObserver {
                    NotificationCenter.default.removeObserver(observer)
                    profileObserver = nil
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("PopToRootProfil"))) { _ in
                navigationPath = NavigationPath()
            }
    }
    
    private func loadProfileStats(force: Bool = false) {
        guard let currentUserId = authViewModel.currentUser?.id else { return }
        
        // Throttle stats loading
        if !force,
           let lastLoad = lastStatsLoad,
           Date().timeIntervalSince(lastLoad) < statsLoadThrottle {
            return
        }
        
        Task {
            do {
                try await AuthSessionManager.shared.ensureValidSession()
                
                async let followersTask = SocialService.shared.getFollowers(userId: currentUserId)
                async let followingTask = SocialService.shared.getFollowing(userId: currentUserId)
                async let followingUsersTask = SocialService.shared.getFollowingUsers(userId: currentUserId)
                
                let (followers, following, followingUsers) = try await (followersTask, followingTask, followingUsersTask)
                
                await MainActor.run {
                    withAnimation(.smooth(duration: 0.4)) {
                        self.followersCount = followers.count
                        self.followingCount = following.count
                        self.friendUsers = followingUsers
                    }
                    self.lastStatsLoad = Date()
                }
            } catch {
                print("Error loading profile stats: \(error)")
            }
        }
    }
    
    /// Prefetch images for posts to speed up display
    private func prefetchPostImages() async {
        let imagesToPrefetch = myPostsViewModel.posts.prefix(5).compactMap { post -> [String] in
            var urls: [String] = []
            if let imageUrl = post.imageUrl, !imageUrl.isEmpty { urls.append(imageUrl) }
            if let userImageUrl = post.userImageUrl, !userImageUrl.isEmpty { urls.append(userImageUrl) }
            return urls
        }.flatMap { $0 }
        
        ImageCacheManager.shared.prefetch(urls: imagesToPrefetch)
    }
    
    /// Load user's own stories
    @MainActor
    private func loadMyStories() async {
        guard let userId = authViewModel.currentUser?.id else { return }
        
        do {
            let stories = try await StoryService.shared.fetchMyStories(userId: userId)
            self.myStories = stories
            print("📖 Profile: Loaded \(stories.count) stories")
        } catch {
            print("❌ Profile: Error loading stories: \(error)")
        }
    }
    
    private func loadMyEvents(userId: String) async {
        do {
            let events = try await EventService.shared.fetchEvents(userId: userId)
            await MainActor.run {
                self.myEvents = events
            }
        } catch {
            print("❌ Profile: Error loading events: \(error)")
        }
    }
    
    private func uploadAvatar(_ item: PhotosPickerItem) async {
        guard let data = try? await item.loadTransferable(type: Data.self),
              let image = UIImage(data: data),
              let imageData = image.jpegData(compressionQuality: 0.85),
              let userId = authViewModel.currentUser?.id else { return }
        await MainActor.run { isUploadingAvatar = true }
        do {
            let url = try await ProfileService.shared.uploadAvatarImageData(imageData, userId: userId)
            try await SupabaseConfig.supabase
                .from("profiles")
                .update(["avatar_url": url])
                .eq("id", value: userId)
                .execute()
            await MainActor.run {
                authViewModel.currentUser?.avatarUrl = url
                isUploadingAvatar = false
            }
        } catch {
            print("❌ Failed to upload avatar: \(error)")
            await MainActor.run { isUploadingAvatar = false }
        }
    }
    
    private func uploadBanner(_ item: PhotosPickerItem) async {
        guard let data = try? await item.loadTransferable(type: Data.self),
              let image = UIImage(data: data),
              let imageData = image.jpegData(compressionQuality: 0.85),
              let userId = authViewModel.currentUser?.id else { return }
        await MainActor.run { isUploadingBanner = true }
        do {
            let timestamp = Int(Date().timeIntervalSince1970)
            let fileName = "\(userId)_banner_\(timestamp).jpg"
            try await SupabaseConfig.supabase.storage
                .from("avatars")
                .upload(fileName, data: imageData, options: .init(contentType: "image/jpeg", upsert: true))
            let publicURL = try SupabaseConfig.supabase.storage
                .from("avatars")
                .getPublicURL(path: fileName)
            let urlString = publicURL.absoluteString
            try await SupabaseConfig.supabase
                .from("profiles")
                .update(["banner_url": urlString])
                .eq("id", value: userId)
                .execute()
            await MainActor.run {
                bannerUrl = urlString
                authViewModel.currentUser?.bannerUrl = urlString
                isUploadingBanner = false
            }
        } catch {
            print("❌ Failed to upload banner: \(error)")
            await MainActor.run { isUploadingBanner = false }
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
                    .foregroundColor(.primary)
                
                Text(label)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.primary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(16)
            .background(Color(.secondarySystemBackground))
            .cornerRadius(12)
        }
    }
}

// MARK: - Profile Card Button (VOI style top row)
struct ProfileCardButton: View {
    let icon: String
    let label: String
    let action: () -> Void
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 24))
                    .foregroundColor(.primary)
                
                Text(label)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.primary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 90)
            .background(Color.white)
            .cornerRadius(16)
            .shadow(color: .black.opacity(0.08), radius: 12, x: 0, y: 4)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.primary.opacity(0.1), lineWidth: 1)
            )
            .drawingGroup() // GPU-accelerated rendering
        }
    }
}

// MARK: - Profile List Row (VOI style list item)
struct ProfileListRow: View {
    let icon: String
    let title: String
    let subtitle: String
    var badgeCount: Int = 0
    
    var body: some View {
        HStack(spacing: 14) {
            // Icon
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(.primary)
                .frame(width: 40, height: 40)
            
            // Text
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.primary)
                
                Text(subtitle)
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Badge or chevron
            if badgeCount > 0 {
                Text("\(badgeCount)")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.red)
                    .cornerRadius(10)
            }
            
            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.gray)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
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
    ProfileActivitiesView()
        .environmentObject(AuthViewModel())
}

// MARK: - Up&Down Live Gallery
// MARK: - Up&Down Live Gallery (compact entry widget)
struct UpAndDownLiveGallery: View {
    let posts: [SocialWorkoutPost]
    @State private var showCalendar = false

    private var postsWithImages: [SocialWorkoutPost] {
        posts.filter { post in
            if let url = post.userImageUrl, !url.isEmpty {
                return url.contains("live_")
            }
            return false
        }
    }

    private var latestPost: SocialWorkoutPost? {
        postsWithImages.first
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header
            HStack(spacing: 8) {
                Image("23")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 22, height: 22)
                    .cornerRadius(5)
                Text("Up&Down LIVE")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(.primary)
                Spacer()
                if !postsWithImages.isEmpty {
                    Text("\(postsWithImages.count)")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.secondary)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.secondary)
                }
            }

            if postsWithImages.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 36))
                        .foregroundColor(.gray.opacity(0.4))
                    Text(L.t(sv: "Inga Up&Down Live bilder än", nb: "Ingen Up&Down Live-bilder ennå"))
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.gray)
                    Text(L.t(sv: "Ta en bild med Up&Down Live efter ditt nästa pass!", nb: "Ta et bilde med Up&Down Live etter din neste økt!"))
                        .font(.system(size: 12))
                        .foregroundColor(.gray.opacity(0.7))
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 32)
            } else if let latest = latestPost, let imageUrl = latest.userImageUrl {
                Button { showCalendar = true } label: {
                    Color.clear
                        .aspectRatio(1, contentMode: .fit)
                        .overlay(
                            LivePhotoGridImage(path: imageUrl)
                                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(Color.black.opacity(0.35))
                        )
                        .overlay(
                            VStack(spacing: 8) {
                                Image("23")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 44, height: 44)
                                    .cornerRadius(10)
                                Text("Up&Down Live")
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundColor(.white)
                            }
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(14)
        .background(Color(.systemGray6))
        .cornerRadius(16)
        .task {
            guard let url = latestPost?.userImageUrl,
                  ImageCacheManager.shared.getImage(for: url) == nil,
                  let imageUrl = URL(string: url) else { return }
            if let (data, _) = try? await SupabaseConfig.urlSession.data(from: imageUrl),
               let img = UIImage(data: data) {
                ImageCacheManager.shared.setImage(img, for: url)
            }
        }
        .sheet(isPresented: $showCalendar) {
            LiveCalendarView(posts: postsWithImages)
        }
    }
}

// MARK: - Live Photo Grid Image (fills cell properly)
struct LivePhotoGridImage: View {
    let path: String
    var contentMode: ContentMode = .fill
    @State private var image: UIImage?
    @State private var isLoading = true

    var body: some View {
        ZStack {
            Color.black
            if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
            } else if isLoading {
                ProgressView().tint(.white)
            }
        }
        .task { await loadImage() }
    }

    private func loadImage() async {
        if let cached = ImageCacheManager.shared.getImage(for: path) {
            await MainActor.run { self.image = cached; self.isLoading = false }
            return
        }
        guard let url = URL(string: path) else { await MainActor.run { isLoading = false }; return }
        do {
            let (data, _) = try await SupabaseConfig.urlSession.data(from: url)
            if let loaded = UIImage(data: data) {
                ImageCacheManager.shared.setImage(loaded, for: path)
                await MainActor.run { self.image = loaded; self.isLoading = false }
            }
        } catch {
            await MainActor.run { self.isLoading = false }
        }
    }
}

// MARK: - Live Calendar View
private struct YearMonth: Hashable {
    let year: Int
    let month: Int
}

struct LiveCalendarView: View {
    let posts: [SocialWorkoutPost]
    @Environment(\.dismiss) private var dismiss
    @State private var selectedPost: SocialWorkoutPost? = nil
    @State private var months: [YearMonth] = []
    @State private var postsByDay: [String: SocialWorkoutPost] = [:]

    private let calendar = Calendar(identifier: .gregorian)
    private let weekdaySymbols = ["MÅN", "TIS", "ONS", "TORS", "FRE", "LÖR", "SÖN"]

    private let monthFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "sv_SE")
        f.dateFormat = "MMMM yyyy"
        return f
    }()

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                // Navigation bar
                HStack {
                    Button { dismiss() } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(10)
                    }
                    Spacer()
                    Text("Minnen")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                    Spacer()
                    Color.clear.frame(width: 44, height: 44)
                }
                .padding(.horizontal, 8)
                .padding(.top, 8)

                // Weekday header
                HStack(spacing: 0) {
                    ForEach(weekdaySymbols, id: \.self) { day in
                        Text(day)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.gray)
                            .frame(maxWidth: .infinity)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)

                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 32) {
                            ForEach(months, id: \.self) { yearMonth in
                                monthSection(year: yearMonth.year, month: yearMonth.month)
                                    .id("\(yearMonth.year)-\(yearMonth.month)")
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 16)
                    }
                    .onChange(of: months) { _ in
                        let now = Date()
                        let comps = calendar.dateComponents([.year, .month], from: now)
                        if let y = comps.year, let m = comps.month {
                            proxy.scrollTo("\(y)-\(m)", anchor: .top)
                        }
                    }
                }
            }
        }
        .task {
            await buildCalendarData()
        }
        .sheet(item: $selectedPost) { post in
            LivePhotoFullscreenView(post: post)
        }
    }

    private func buildCalendarData() async {
        let cal = Calendar(identifier: .gregorian)
        let postsSnapshot = posts

        let computedMonths: [YearMonth] = await Task.detached(priority: .userInitiated) {
            guard let first = postsSnapshot.last else { return [] }
            guard let firstDate = Self.parseDateStatic(first.createdAt) else { return [] }
            let now = Date()
            var result: [YearMonth] = []
            var comps = cal.dateComponents([.year, .month], from: firstDate)
            let nowComps = cal.dateComponents([.year, .month], from: now)
            while true {
                guard let y = comps.year, let m = comps.month else { break }
                result.append(YearMonth(year: y, month: m))
                if y == nowComps.year && m == nowComps.month { break }
                comps.month = m + 1
                if comps.month! > 12 { comps.month = 1; comps.year = y + 1 }
            }
            return result
        }.value

        let computedPostsByDay: [String: SocialWorkoutPost] = await Task.detached(priority: .userInitiated) {
            var map: [String: SocialWorkoutPost] = [:]
            let fmt = DateFormatter()
            fmt.dateFormat = "yyyy-MM-dd"
            for post in postsSnapshot {
                if let date = Self.parseDateStatic(post.createdAt) {
                    let key = fmt.string(from: date)
                    if map[key] == nil { map[key] = post }
                }
            }
            return map
        }.value

        await MainActor.run {
            self.months = computedMonths
            self.postsByDay = computedPostsByDay
        }
    }

    private static func parseDateStatic(_ isoString: String) -> Date? {
        let f1 = ISO8601DateFormatter()
        f1.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = f1.date(from: isoString) { return d }
        let f2 = ISO8601DateFormatter()
        f2.formatOptions = [.withInternetDateTime]
        return f2.date(from: isoString)
    }

    @ViewBuilder
    private func monthSection(year: Int, month: Int) -> some View {
        let dateForMonth = calendar.date(from: DateComponents(year: year, month: month, day: 1)) ?? Date()
        let title = monthFormatter.string(from: dateForMonth).capitalized

        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.white)

            let days = daysInMonth(year: year, month: month)
            let firstWeekday = firstWeekdayOffset(year: year, month: month)
            let totalCells = firstWeekday + days
            let rows = Int(ceil(Double(totalCells) / 7.0))

            VStack(spacing: 4) {
                ForEach(0..<rows, id: \.self) { row in
                    HStack(spacing: 4) {
                        ForEach(0..<7, id: \.self) { col in
                            let cellIndex = row * 7 + col
                            let day = cellIndex - firstWeekday + 1
                            if day < 1 || day > days {
                                Color.clear.frame(maxWidth: .infinity).aspectRatio(3/4, contentMode: .fit)
                            } else {
                                dayCellView(year: year, month: month, day: day)
                            }
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func dayCellView(year: Int, month: Int, day: Int) -> some View {
        let key = String(format: "%04d-%02d-%02d", year, month, day)
        if let post = postsByDay[key], let imageUrl = post.userImageUrl {
            Button {
                selectedPost = post
            } label: {
                GeometryReader { geo in
                    ZStack(alignment: .bottom) {
                        LivePhotoGridImage(path: imageUrl)
                            .frame(width: geo.size.width, height: geo.size.width * 4 / 3)
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        // Day number overlay
                        Text("\(day)")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.white)
                            .shadow(color: .black.opacity(0.6), radius: 2, x: 0, y: 1)
                            .padding(.bottom, 4)
                    }
                }
                .aspectRatio(3/4, contentMode: .fit)
            }
            .buttonStyle(.plain)
        } else {
            GeometryReader { geo in
                Text("\(day)")
                    .font(.system(size: 13))
                    .foregroundColor(.gray)
                    .frame(width: geo.size.width, height: geo.size.width * 4 / 3, alignment: .center)
            }
            .aspectRatio(3/4, contentMode: .fit)
        }
    }

    private func daysInMonth(year: Int, month: Int) -> Int {
        let comps = DateComponents(year: year, month: month)
        guard let date = calendar.date(from: comps),
              let range = calendar.range(of: .day, in: .month, for: date) else { return 30 }
        return range.count
    }

    // Returns 0-based offset from Monday (Monday = 0)
    private func firstWeekdayOffset(year: Int, month: Int) -> Int {
        let comps = DateComponents(year: year, month: month, day: 1)
        guard let date = calendar.date(from: comps) else { return 0 }
        // Calendar.weekday: 1=Sun, 2=Mon, …, 7=Sat
        let raw = calendar.component(.weekday, from: date)
        return (raw + 5) % 7 // convert to Mon=0
    }

}

// MARK: - Live Photo Fullscreen View
struct LivePhotoFullscreenView: View {
    let post: SocialWorkoutPost
    @Environment(\.dismiss) private var dismiss
    @State private var likers: [UserSearchResult] = []
    @State private var isLoadingLikers = true

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                // Top bar
                HStack {
                    Button { dismiss() } label: {
                        Image(systemName: "chevron.down")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(10)
                    }

                    Spacer()

                    VStack(spacing: 2) {
                        Text(formattedWeekday(post.createdAt))
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.white)
                        Text(formattedTime(post.createdAt))
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.6))
                    }

                    Spacer()

                    Color.clear.frame(width: 44, height: 44)
                }
                .padding(.horizontal, 4)
                .padding(.top, 8)

                // Photo (fit to screen width, natural aspect ratio)
                if let imageUrl = post.userImageUrl {
                    LivePhotoGridImage(path: imageUrl, contentMode: .fit)
                        .frame(maxWidth: .infinity)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .overlay(
                            LinearGradient(
                                colors: [.clear, Color.black.opacity(0.25)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        )
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                }

                // RealMojis / Likers section
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 6) {
                        Text("Up&Down")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                        Text("\(post.likeCount ?? 0)")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 20)

                    if isLoadingLikers {
                        HStack {
                            ProgressView().tint(.white).padding(.horizontal, 20)
                            Spacer()
                        }
                    } else if likers.isEmpty {
                        Text(L.t(sv: "Inga gillningar än", nb: "Ingen likes ennå"))
                            .font(.system(size: 13))
                            .foregroundColor(.white.opacity(0.5))
                            .padding(.horizontal, 20)
                    } else {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 16) {
                                ForEach(likers) { liker in
                                    VStack(spacing: 6) {
                                        ProfileAvatarView(
                                            path: liker.avatarUrl ?? "",
                                            size: 52
                                        )
                                        Text(liker.name.components(separatedBy: " ").first ?? liker.name)
                                            .font(.system(size: 11, weight: .medium))
                                            .foregroundColor(.white.opacity(0.85))
                                            .lineLimit(1)
                                    }
                                }
                            }
                            .padding(.horizontal, 20)
                        }
                    }
                }
                .padding(.top, 16)

                Spacer()
            }
        }
        .task {
            do {
                likers = try await SocialService.shared.getTopPostLikers(postId: post.id, limit: 20)
            } catch {
                print("⚠️ Failed to load likers: \(error)")
            }
            isLoadingLikers = false
        }
    }

    private func formattedWeekday(_ iso: String) -> String {
        guard let date = parseDate(iso) else { return "" }
        let f = DateFormatter()
        f.locale = Locale(identifier: "sv_SE")
        f.dateFormat = "EEEE d MMM. yyyy"
        return f.string(from: date).capitalized
    }

    private func formattedTime(_ iso: String) -> String {
        guard let date = parseDate(iso) else { return "" }
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f.string(from: date)
    }

    private func parseDate(_ isoString: String) -> Date? {
        let formatters: [ISO8601DateFormatter] = [
            { let f = ISO8601DateFormatter(); f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]; return f }(),
            { let f = ISO8601DateFormatter(); f.formatOptions = [.withInternetDateTime]; return f }(),
        ]
        for f in formatters { if let d = f.date(from: isoString) { return d } }
        return nil
    }
}

// MARK: - Live Photo Detail View (legacy alias)
typealias LivePhotoDetailView = LivePhotoFullscreenView

// MARK: - Helper Functions
func formatNumber(_ number: Int) -> String {
    let formatter = NumberFormatter()
    formatter.numberStyle = .decimal
    formatter.groupingSeparator = ","
    return formatter.string(from: NSNumber(value: number)) ?? "\(number)"
}
