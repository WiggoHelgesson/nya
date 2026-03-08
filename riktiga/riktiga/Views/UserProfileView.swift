import SwiftUI
import PhotosUI
import Supabase

struct UserProfileView: View {
    let userId: String
    
    @State private var username: String = ""
    @State private var avatarUrl: String? = nil
    @State private var bannerUrl: String? = nil
    
    @State private var avatarPickerItem: PhotosPickerItem?
    @State private var bannerPickerItem: PhotosPickerItem?
    @State private var isUploadingAvatar = false
    @State private var isUploadingBanner = false
    @State private var followersCount: Int = 0
    @State private var followingCount: Int = 0
    @State private var workoutsCount: Int = 0
    @State private var isLoading: Bool = true
    @State private var isFollowingUser: Bool = false
    @State private var followToggleInProgress: Bool = false
    @State private var isPro: Bool = false
    @State private var showPersonalRecords: Bool = false
    @State private var pinnedPostIds: [String] = []
    @State private var profileBio: String? = nil
    @State private var profileHomeGym: String? = nil
    @State private var profileTrainingGoal: String? = nil
    @State private var profileTrainingIdentity: String? = nil
    @State private var profileGymPbs: [GymPB] = []
    @State private var profilePb5km: Int? = nil
    @State private var profilePb10kmH: Int? = nil
    @State private var profilePb10kmM: Int? = nil
    @State private var profilePbMarathonH: Int? = nil
    @State private var profilePbMarathonM: Int? = nil
    @State private var profileCompletedRaces: [String] = []
    @StateObject private var profilePostsViewModel = SocialViewModel()
    @State private var selectedPost: SocialWorkoutPost?
    @State private var selectedLivePhotoPost: SocialWorkoutPost?
    @State private var weeklyHours: Double = 0
    @State private var dailyActivityData: [DailyActivity] = []
    @State private var showComparison: Bool = false
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var authViewModel: AuthViewModel
    
    // Animation states
    @State private var showHeader: Bool = false
    @State private var showStats: Bool = false
    @State private var showChart: Bool = false
    @State private var showPosts: Bool = false
    
    // Follow list states
    @State private var showFollowersList: Bool = false
    @State private var showFollowingList: Bool = false
    
    // Message states
    @State private var isCreatingConversation: Bool = false
    @State private var navigateToConversation: UUID? = nil
    
    // Mutual friends
    @State private var mutualFriends: [UserSearchResult] = []
    
    private var isOwnProfile: Bool {
        authViewModel.currentUser?.id == userId
    }
    
    // Filter posts with Up&Down Live photos
    private var livePhotoPosts: [SocialWorkoutPost] {
        profilePostsViewModel.posts.filter { post in
            if let userImageUrl = post.userImageUrl, !userImageUrl.isEmpty {
                return userImageUrl.contains("live_")
            }
            return false
        }
    }
    
    private var pinnedPosts: [SocialWorkoutPost] {
        guard !pinnedPostIds.isEmpty else { return [] }
        return pinnedPostIds.compactMap { id in
            profilePostsViewModel.posts.first(where: { $0.id == id })
        }
    }
    
    private var hasAboutData: Bool {
        (profileBio != nil && !(profileBio?.isEmpty ?? true)) ||
        (profileHomeGym != nil && !(profileHomeGym?.isEmpty ?? true)) ||
        (profileTrainingGoal != nil && !(profileTrainingGoal?.isEmpty ?? true)) ||
        (profileTrainingIdentity != nil && !(profileTrainingIdentity?.isEmpty ?? true)) ||
        !profileGymPbs.isEmpty ||
        profilePb5km != nil || profilePb10kmM != nil || profilePbMarathonM != nil ||
        !profileCompletedRaces.isEmpty
    }
    
    private var aboutSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(L.t(sv: "Om \(username)", nb: "Om \(username)"))
                .font(.system(size: 18, weight: .bold))
                .padding(.bottom, 2)
            
            Group {
                if let bio = profileBio, !bio.isEmpty {
                    aboutRow(icon: "text.quote", text: bio)
                }
                
                if let gym = profileHomeGym, !gym.isEmpty {
                    aboutRow(icon: "house.fill", label: L.t(sv: "Hemmagym", nb: "Hjemmegym"), text: gym)
                }
                
                if let goal = profileTrainingGoal, !goal.isEmpty {
                    aboutRow(icon: "target", label: L.t(sv: "Tränar inför", nb: "Trener mot"), text: goal)
                }
                
                if let identity = profileTrainingIdentity, !identity.isEmpty {
                    aboutRow(icon: "person.fill", label: L.t(sv: "Träningsidentitet", nb: "Treningsidentitet"), text: identity)
                }
            }
            
            if !profileGymPbs.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Image(systemName: "dumbbell.fill")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                            .frame(width: 22)
                        Text(L.t(sv: "PB Gym", nb: "PB Gym"))
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.secondary)
                    }
                    ForEach(Array(profileGymPbs.enumerated()), id: \.offset) { _, pb in
                        HStack(spacing: 4) {
                            Text(pb.name)
                                .font(.system(size: 14, weight: .medium))
                            Spacer()
                            Text("\(String(format: "%.0f", pb.kg)) kg × \(pb.reps) reps")
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                        }
                        .padding(.leading, 28)
                    }
                }
            }
            
            if profilePb5km != nil || profilePb10kmM != nil || profilePbMarathonM != nil {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Image(systemName: "figure.run")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                            .frame(width: 22)
                        Text(L.t(sv: "PB Löpning", nb: "PB Løping"))
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.secondary)
                    }
                    if let m = profilePb5km {
                        HStack {
                            Text("5 km")
                                .font(.system(size: 14, weight: .medium))
                            Spacer()
                            Text("\(m) min")
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                        }
                        .padding(.leading, 28)
                    }
                    if let h = profilePb10kmH, let m = profilePb10kmM {
                        HStack {
                            Text("10 km")
                                .font(.system(size: 14, weight: .medium))
                            Spacer()
                            Text("\(h)h \(m)min")
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                        }
                        .padding(.leading, 28)
                    }
                    if let h = profilePbMarathonH, let m = profilePbMarathonM {
                        HStack {
                            Text(L.t(sv: "Maraton", nb: "Maraton"))
                                .font(.system(size: 14, weight: .medium))
                            Spacer()
                            Text("\(h)h \(m)min")
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                        }
                        .padding(.leading, 28)
                    }
                }
            }
            
            if !profileCompletedRaces.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Image(systemName: "flag.fill")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                            .frame(width: 22)
                        Text(L.t(sv: "Genomförda lopp", nb: "Gjennomførte løp"))
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.secondary)
                    }
                    ForEach(profileCompletedRaces, id: \.self) { race in
                        Text(race)
                            .font(.system(size: 14))
                            .padding(.leading, 28)
                    }
                }
            }
        }
        .padding(16)
        .background(Color(.systemBackground))
        .cornerRadius(14)
        .shadow(color: .black.opacity(0.04), radius: 4, x: 0, y: 2)
    }
    
    private func aboutRow(icon: String, label: String? = nil, text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(.secondary)
                .frame(width: 22)
                .padding(.top, 2)
            
            VStack(alignment: .leading, spacing: 2) {
                if let label = label {
                    Text(label)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.secondary)
                }
                Text(text)
                    .font(.system(size: 14))
                    .foregroundColor(.primary)
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Fixed Header Section
            ScrollView {
                VStack(spacing: 0) {
                    // MARK: - Facebook-style Banner + Avatar
                    ZStack(alignment: .bottom) {
                        // Banner
                        ZStack(alignment: .bottomTrailing) {
                            if let bannerUrl = bannerUrl, !bannerUrl.isEmpty {
                                LocalAsyncImage(path: bannerUrl)
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: UIScreen.main.bounds.width, height: 200)
                                    .clipped()
                            } else {
                                Color(.systemGray4)
                                    .frame(width: UIScreen.main.bounds.width, height: 200)
                            }
                            
                            if isOwnProfile {
                                PhotosPicker(selection: $bannerPickerItem, matching: .images) {
                                    Image(systemName: "camera.fill")
                                        .font(.system(size: 14))
                                        .foregroundColor(.white)
                                        .frame(width: 32, height: 32)
                                        .background(Color.black.opacity(0.6))
                                        .clipShape(Circle())
                                }
                                .padding(12)
                            }
                        }
                        .frame(height: 200)
                        
                        // Avatar overlapping the banner
                        ZStack(alignment: .bottomTrailing) {
                            ProfileAvatarView(path: avatarUrl ?? "", size: 100)
                                .overlay(
                                    Circle()
                                        .stroke(Color(.systemBackground), lineWidth: 4)
                                )
                            
                            if isOwnProfile {
                                PhotosPicker(selection: $avatarPickerItem, matching: .images) {
                                    Image(systemName: "camera.fill")
                                        .font(.system(size: 12))
                                        .foregroundColor(.white)
                                        .frame(width: 28, height: 28)
                                        .background(Color.black.opacity(0.7))
                                        .clipShape(Circle())
                                        .overlay(Circle().stroke(Color(.systemBackground), lineWidth: 2))
                                }
                            }
                        }
                        .offset(y: 50)
                        .opacity(showHeader ? 1 : 0)
                    }
                    
                    // Spacer for the overlapping avatar
                    Spacer().frame(height: 56)
                    
                    // MARK: - Name + Stats (centered)
                    VStack(spacing: 10) {
                        // Username + Pro badge
                        HStack(spacing: 6) {
                            Text(username.isEmpty ? L.t(sv: "Användare", nb: "Bruker") : username)
                                .font(.system(size: 22, weight: .bold))
                                .foregroundColor(.primary)
                            
                            if isPro {
                                Image(systemName: "checkmark.seal.fill")
                                    .font(.system(size: 16))
                                    .foregroundColor(.blue)
                            }
                        }
                        .opacity(showHeader ? 1 : 0)
                        
                        // Stats row
                        HStack(spacing: 0) {
                            VStack(spacing: 2) {
                                Text("\(workoutsCount)")
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
                        .opacity(showStats ? 1 : 0)
                        
                        // Personal Records button
                        Button(action: { showPersonalRecords = true }) {
                            HStack(spacing: 4) {
                                Image(systemName: "trophy.fill")
                                    .font(.system(size: 12))
                                Text(L.t(sv: "Personliga rekord", nb: "Personlige rekorder"))
                                    .font(.system(size: 12, weight: .medium))
                            }
                            .foregroundColor(.primary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                        }
                        .opacity(showStats ? 1 : 0)
                        
                        // Follow + Message buttons (other users)
                        if let currentUser = authViewModel.currentUser, currentUser.id != userId {
                            HStack(spacing: 8) {
                                Button(action: toggleFollow) {
                                    HStack(spacing: 6) {
                                        if followToggleInProgress {
                                            ProgressView()
                                                .scaleEffect(0.8)
                                                .tint(.white)
                                        }
                                        Text(isFollowingUser ? L.t(sv: "Följer", nb: "Følger") : L.t(sv: "Följ", nb: "Følg"))
                                            .font(.system(size: 14, weight: .semibold))
                                    }
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 40)
                                    .background(isFollowingUser ? Color(.systemGray5) : Color.black)
                                    .foregroundColor(isFollowingUser ? .black : .white)
                                    .cornerRadius(10)
                                }
                                .disabled(followToggleInProgress)
                                
                                Button(action: openConversation) {
                                    HStack(spacing: 6) {
                                        if isCreatingConversation {
                                            ProgressView()
                                                .scaleEffect(0.8)
                                                .tint(.primary)
                                        } else {
                                            Image(systemName: "paperplane.fill")
                                                .font(.system(size: 13))
                                        }
                                        Text(L.t(sv: "Meddelande", nb: "Melding"))
                                            .font(.system(size: 14, weight: .semibold))
                                    }
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 40)
                                    .background(Color(.systemGray5))
                                    .foregroundColor(.primary)
                                    .cornerRadius(10)
                                }
                                .disabled(isCreatingConversation)
                            }
                            .opacity(showStats ? 1 : 0)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)
                    
                    // MARK: - Mutual Friends + Live Gallery + About/Chart/Compare
                    Group {
                        if !isOwnProfile && !mutualFriends.isEmpty {
                            HStack(spacing: 6) {
                                HStack(spacing: -8) {
                                    ForEach(Array(mutualFriends.prefix(3).enumerated()), id: \.offset) { _, friend in
                                        ProfileAvatarView(path: friend.avatarUrl ?? "", size: 28)
                                            .overlay(Circle().stroke(Color(.systemBackground), lineWidth: 2))
                                    }
                                }
                                
                                if mutualFriends.count == 1, let friend = mutualFriends.first {
                                    Text(L.t(
                                        sv: "Vän med \(friend.name)",
                                        nb: "Venn med \(friend.name)"
                                    ))
                                    .font(.system(size: 13))
                                    .foregroundColor(.secondary)
                                } else {
                                    Text(L.t(
                                        sv: "\(mutualFriends.count) gemensamma vänner",
                                        nb: "\(mutualFriends.count) felles venner"
                                    ))
                                    .font(.system(size: 13))
                                    .foregroundColor(.secondary)
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.bottom, 8)
                            .opacity(showStats ? 1 : 0)
                        }
                        
                        if !livePhotoPosts.isEmpty {
                            PublicProfileLiveGallery(
                                posts: livePhotoPosts,
                                selectedPost: $selectedLivePhotoPost
                            )
                            .opacity(showHeader ? 1 : 0)
                        }
                    }
                    
                    Group {
                        if hasAboutData {
                            aboutSection
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                                .opacity(showHeader ? 1 : 0)
                        }
                        
                        WeeklyHoursChart(
                            weeklyHours: weeklyHours,
                            dailyData: dailyActivityData
                        )
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .opacity(showChart ? 1 : 0)
                        
                        if let currentUser = authViewModel.currentUser, currentUser.id != userId {
                            CompareButton(
                                myAvatarUrl: currentUser.avatarUrl,
                                theirAvatarUrl: avatarUrl,
                                action: {
                                    showComparison = true
                                }
                            )
                            .padding(.horizontal, 16)
                            .padding(.bottom, 12)
                            .opacity(showChart ? 1 : 0)
                        }
                    }
                    
                    // MARK: - Pinned Posts Slider
                    if !pinnedPosts.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(spacing: 6) {
                                Image(systemName: "pin.fill")
                                    .font(.system(size: 13))
                                    .foregroundColor(.secondary)
                                Text(L.t(
                                    sv: "\(username) pinnade pass",
                                    nb: "\(username) festede økter"
                                ))
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.secondary)
                            }
                            .padding(.horizontal, 16)
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    ForEach(pinnedPosts) { post in
                                        PinnedPostCard(
                                            post: post,
                                            onTap: { selectedPost = post }
                                        )
                                        .frame(width: UIScreen.main.bounds.width * 0.85)
                                    }
                                }
                                .padding(.horizontal, 16)
                            }
                        }
                        .padding(.vertical, 12)
                        .opacity(showPosts ? 1 : 0)
                    }
                    
                    Divider()
                        .opacity(showPosts ? 1 : 0)
                
                    // Posts list
                    if isLoading {
                        VStack(spacing: 16) {
                            ProgressView().tint(AppColors.brandBlue)
                            Text(L.t(sv: "Laddar profil...", nb: "Laster profil..."))
                                .font(.system(size: 14))
                                .foregroundColor(.gray)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 40)
                    } else {
                        if profilePostsViewModel.isLoading && profilePostsViewModel.posts.isEmpty {
                            VStack(spacing: 12) {
                                ProgressView().tint(AppColors.brandBlue)
                                Text(L.t(sv: "Hämtar inlägg...", nb: "Henter innlegg..."))
                                    .font(.system(size: 14))
                                    .foregroundColor(.gray)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.top, 40)
                            .opacity(showPosts ? 1 : 0)
                        } else if profilePostsViewModel.posts.isEmpty {
                            VStack(spacing: 12) {
                                Image(systemName: "figure.run")
                                    .font(.system(size: 48))
                                    .foregroundColor(.gray)
                                Text(L.t(sv: "Inga inlägg än", nb: "Ingen innlegg ennå"))
                                    .font(.headline)
                                Text(L.t(sv: "När användaren sparar pass visas de här.", nb: "Når brukeren lagrer økter vises de her."))
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                            .padding(.top, 40)
                            .opacity(showPosts ? 1 : 0)
                        } else {
                            LazyVStack(spacing: 0) {
                                ForEach(Array(profilePostsViewModel.posts.enumerated()), id: \.element.id) { index, post in
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
                                    .opacity(showPosts ? 1 : 0)
                                    .animation(.smooth(duration: 0.4).delay(Double(index) * 0.05), value: showPosts)
                                    
                                    Divider()
                                        .background(Color(.systemGray5))
                                }
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle(L.t(sv: "Profil", nb: "Profil"))
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadData()
            triggerAnimations()
        }
        .onChange(of: avatarPickerItem) { _, newItem in
            guard let newItem else { return }
            Task {
                if let data = try? await newItem.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    await uploadAvatar(image)
                }
            }
        }
        .onChange(of: bannerPickerItem) { _, newItem in
            guard let newItem else { return }
            Task {
                if let data = try? await newItem.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    await uploadBanner(image)
                }
            }
        }
        .navigationDestination(item: $selectedPost) { post in
            WorkoutDetailView(post: post)
        }
        .navigationDestination(item: $navigateToConversation) { conversationId in
            DirectMessageView(
                conversationId: conversationId,
                otherUserId: userId,
                otherUsername: username.isEmpty ? L.t(sv: "Användare", nb: "Bruker") : username,
                otherAvatarUrl: avatarUrl
            )
            .environmentObject(authViewModel)
        }
        .sheet(isPresented: $showPersonalRecords) {
            PersonalRecordsView(userId: userId, username: username)
        }
        .sheet(item: $selectedLivePhotoPost) { post in
            LivePhotoDetailSheet(post: post)
        }
        .sheet(isPresented: $showComparison) {
            if let currentUser = authViewModel.currentUser {
                UserComparisonView(
                    myUserId: currentUser.id,
                    myUsername: currentUser.name,
                    myAvatarUrl: currentUser.avatarUrl,
                    theirUserId: userId,
                    theirUsername: username,
                    theirAvatarUrl: avatarUrl
                )
            }
        }
        .sheet(isPresented: $showFollowersList) {
            NavigationStack {
                FollowListView(userId: userId, listType: .followers)
                    .environmentObject(authViewModel)
            }
        }
        .sheet(isPresented: $showFollowingList) {
            NavigationStack {
                FollowListView(userId: userId, listType: .following)
                    .environmentObject(authViewModel)
            }
        }
        .onAppear { NavigationDepthTracker.shared.setAtRoot(false) }
        .onDisappear { NavigationDepthTracker.shared.setAtRoot(true) }
    }
    
    private enum ProfileLoadResult: Sendable {
        case profile(User?)
        case followers([String])
        case following([String])
    }
    
    private func loadData() async {
        isLoading = true
        
        let results = await withTaskGroup(of: ProfileLoadResult.self, returning: [ProfileLoadResult].self) { group in
            group.addTask {
                let p = try? await ProfileService.shared.fetchUserProfile(userId: self.userId)
                return .profile(p)
            }
            group.addTask {
                let ids = (try? await SocialService.shared.getFollowers(userId: self.userId)) ?? []
                return .followers(ids)
            }
            group.addTask {
                let ids = (try? await SocialService.shared.getFollowing(userId: self.userId)) ?? []
                return .following(ids)
            }
            var collected: [ProfileLoadResult] = []
            for await result in group { collected.append(result) }
            return collected
        }
        
        var profile: User? = nil
        var followersIds: [String] = []
        var followingIds: [String] = []
        for result in results {
            switch result {
            case .profile(let p): profile = p
            case .followers(let ids): followersIds = ids
            case .following(let ids): followingIds = ids
            }
        }
        
        await MainActor.run {
            if let profile = profile {
                self.username = profile.name
                self.avatarUrl = profile.avatarUrl
                self.bannerUrl = profile.bannerUrl
                self.isPro = profile.isProMember
                self.pinnedPostIds = profile.pinnedPostIds
                self.profileBio = profile.bio
                self.profileHomeGym = profile.homeGym
                self.profileTrainingGoal = profile.trainingGoal
                self.profileTrainingIdentity = profile.trainingIdentity
                self.profileGymPbs = profile.gymPbs
                self.profilePb5km = profile.pb5kmMinutes
                self.profilePb10kmH = profile.pb10kmHours
                self.profilePb10kmM = profile.pb10kmMinutes
                self.profilePbMarathonH = profile.pbMarathonHours
                self.profilePbMarathonM = profile.pbMarathonMinutes
                self.profileCompletedRaces = profile.completedRaces
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
        
        await MainActor.run {
            workoutsCount = profilePostsViewModel.posts.count
            calculateWeeklyActivity()
        }
        
        // Load mutual friends (only for other users' profiles)
        if let currentUserId = authViewModel.currentUser?.id, currentUserId != userId {
            do {
                let mutual = try await SocialService.shared.getMutualFriends(currentUserId: currentUserId, otherUserId: userId)
                await MainActor.run {
                    self.mutualFriends = mutual
                }
            } catch {
                print("⚠️ Failed to load mutual friends: \(error)")
            }
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
    
    private func openConversation() {
        guard !isCreatingConversation else { return }
        isCreatingConversation = true
        
        Task {
            do {
                let conversationId = try await DirectMessageService.shared.getOrCreateConversation(withUserId: userId)
                await MainActor.run {
                    isCreatingConversation = false
                    navigateToConversation = conversationId
                }
            } catch {
                print("❌ Failed to open conversation: \(error)")
                await MainActor.run {
                    isCreatingConversation = false
                }
            }
        }
    }
    
    private func uploadAvatar(_ image: UIImage) async {
        guard let imageData = image.jpegData(compressionQuality: 0.85) else { return }
        await MainActor.run { isUploadingAvatar = true }
        do {
            let url = try await ProfileService.shared.uploadAvatarImageData(imageData, userId: userId)
            try await SupabaseConfig.supabase
                .from("profiles")
                .update(["avatar_url": url])
                .eq("id", value: userId)
                .execute()
            await MainActor.run {
                avatarUrl = url
                authViewModel.currentUser?.avatarUrl = url
                isUploadingAvatar = false
            }
        } catch {
            print("❌ Failed to upload avatar: \(error)")
            await MainActor.run { isUploadingAvatar = false }
        }
    }
    
    private func uploadBanner(_ image: UIImage) async {
        guard let imageData = image.jpegData(compressionQuality: 0.85) else { return }
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
    
    private func triggerAnimations() {
        // Staggered animations for smooth loading appearance
        withAnimation(.smooth(duration: 0.4)) {
            showHeader = true
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(.smooth(duration: 0.4)) {
                showStats = true
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            withAnimation(.smooth(duration: 0.4)) {
                showChart = true
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation(.smooth(duration: 0.4)) {
                showPosts = true
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
            return weeklyHours == 1 ? L.t(sv: "timme", nb: "time") : L.t(sv: "timmar", nb: "timer")
        }
        return L.t(sv: "min", nb: "min")
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
                Text(L.t(sv: "denna vecka", nb: "denne uken"))
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

// MARK: - Pinned Post Card (compact card for horizontal slider)

struct PinnedPostCard: View {
    let post: SocialWorkoutPost
    let onTap: () -> Void
    
    private var activityIcon: String {
        switch post.activityType {
        case "Gym": return "dumbbell.fill"
        case "Löpning": return "figure.run"
        case "Golf": return "figure.golf"
        case "Skidor": return "figure.skiing.downhill"
        case "Simning": return "figure.pool.swim"
        case "Cykling": return "figure.outdoor.cycle"
        default: return "figure.walk"
        }
    }
    
    private var formattedDate: String {
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let isoNoMs = ISO8601DateFormatter()
        isoNoMs.formatOptions = [.withInternetDateTime]
        guard let date = iso.date(from: post.createdAt) ?? isoNoMs.date(from: post.createdAt) else { return "" }
        let df = DateFormatter()
        df.dateStyle = .medium
        df.timeStyle = .none
        df.locale = Locale(identifier: "sv_SE")
        return df.string(from: date)
    }
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 10) {
                // Top row: activity icon + title + date
                HStack(spacing: 10) {
                    Image(systemName: activityIcon)
                        .font(.system(size: 18))
                        .foregroundColor(.white)
                        .frame(width: 36, height: 36)
                        .background(Color.black)
                        .clipShape(Circle())
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(post.title)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.primary)
                            .lineLimit(1)
                        
                        Text(formattedDate)
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "pin.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.blue)
                }
                
                // Stats row
                HStack(spacing: 16) {
                    if let duration = post.duration, duration > 0 {
                        statPill(icon: "clock", value: formatDuration(duration))
                    }
                    if let distance = post.distance, distance > 0 {
                        statPill(icon: "location", value: String(format: "%.1f km", distance))
                    }
                    if let exercises = post.exercises, !exercises.isEmpty {
                        statPill(icon: "dumbbell", value: "\(exercises.count) \(L.t(sv: "övningar", nb: "øvelser"))")
                    }
                }
                
                // Gym exercises preview
                if let exercises = post.exercises, !exercises.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(exercises.prefix(3), id: \.name) { exercise in
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(Color(.systemGray4))
                                    .frame(width: 6, height: 6)
                                Text(exercise.name)
                                    .font(.system(size: 13))
                                    .foregroundColor(.primary)
                                    .lineLimit(1)
                                Spacer()
                                Text("\(exercise.sets)×\(exercise.reps.first ?? 0) • \(String(format: "%.0f", exercise.kg.max() ?? 0)) kg")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.secondary)
                            }
                        }
                        if exercises.count > 3 {
                            Text(L.t(sv: "+\(exercises.count - 3) övningar till", nb: "+\(exercises.count - 3) øvelser til"))
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .padding(14)
            .background(Color(.systemBackground))
            .cornerRadius(14)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color(.systemGray4), lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
    }
    
    private func statPill(icon: String, value: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
            Text(value)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color(.systemGray6))
        .cornerRadius(6)
    }
    
    private func formatDuration(_ seconds: Int) -> String {
        let h = seconds / 3600
        let m = (seconds % 3600) / 60
        if h > 0 { return "\(h)h \(m)m" }
        return "\(m) min"
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

// MARK: - Compare Button

struct CompareButton: View {
    let myAvatarUrl: String?
    let theirAvatarUrl: String?
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                // Profile pictures overlapping
                HStack(spacing: -12) {
                    ProfileAvatarView(path: myAvatarUrl ?? "", size: 36)
                        .overlay(Circle().stroke(Color.white, lineWidth: 2))
                        .zIndex(1)
                    
                    ProfileAvatarView(path: theirAvatarUrl ?? "", size: 36)
                        .overlay(Circle().stroke(Color.white, lineWidth: 2))
                }
                
                Text(L.t(sv: "Jämför", nb: "Sammenlign"))
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.primary)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.gray)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(.secondarySystemBackground))
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - User Comparison View

struct UserComparisonView: View {
    let myUserId: String
    let myUsername: String
    let myAvatarUrl: String?
    let theirUserId: String
    let theirUsername: String
    let theirAvatarUrl: String?
    
    @Environment(\.dismiss) var dismiss
    @State private var selectedPeriod: ComparisonPeriod = .last30Days
    @State private var myWorkoutCount: Int = 0
    @State private var theirWorkoutCount: Int = 0
    @State private var myTotalTime: Int = 0 // seconds
    @State private var theirTotalTime: Int = 0 // seconds
    @State private var myTotalVolume: Double = 0
    @State private var theirTotalVolume: Double = 0
    @State private var commonExercises: [CommonExercise] = []
    @State private var selectedExercise: CommonExercise? = nil
    @State private var isLoading: Bool = true
    
    enum ComparisonPeriod: String, CaseIterable {
        case last30Days = "Senaste 30 dagarna"
        case last90Days = "Senaste 90 dagarna"
        case thisYear = "Detta året"
        case allTime = "All time"
        
        var displayName: String {
            switch self {
            case .last30Days: return L.t(sv: "Senaste 30 dagarna", nb: "Siste 30 dagene")
            case .last90Days: return L.t(sv: "Senaste 90 dagarna", nb: "Siste 90 dagene")
            case .thisYear: return L.t(sv: "Detta året", nb: "Dette året")
            case .allTime: return L.t(sv: "All time", nb: "All time")
            }
        }
        
        var days: Int? {
            switch self {
            case .last30Days: return 30
            case .last90Days: return 90
            case .thisYear: return nil
            case .allTime: return nil
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Period selector
                    Menu {
                        ForEach(ComparisonPeriod.allCases, id: \.self) { period in
                            Button {
                                selectedPeriod = period
                                Task { await loadComparisonData() }
                            } label: {
                                HStack {
                                    Text(period.displayName)
                                    if period == selectedPeriod {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    } label: {
                        HStack {
                            Text(selectedPeriod.displayName)
                                .font(.system(size: 16, weight: .medium))
                            Image(systemName: "chevron.down")
                                .font(.system(size: 12))
                        }
                        .foregroundColor(.primary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(12)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    
                    // VS Header
                    HStack(spacing: 20) {
                        // My profile
                        VStack(spacing: 8) {
                            ProfileAvatarView(path: myAvatarUrl ?? "", size: 80)
                                .overlay(
                                    Circle()
                                        .stroke(Color.black, lineWidth: 3)
                                )
                            Text(myUsername)
                                .font(.system(size: 14, weight: .semibold))
                                .lineLimit(1)
                        }
                        .frame(maxWidth: .infinity)
                        
                        // VS badge
                        Text("VS")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                            .background(Color.black)
                            .clipShape(Circle())
                        
                        // Their profile
                        VStack(spacing: 8) {
                            ProfileAvatarView(path: theirAvatarUrl ?? "", size: 80)
                                .overlay(
                                    Circle()
                                        .stroke(Color(.systemGray4), lineWidth: 3)
                                )
                            Text(theirUsername)
                                .font(.system(size: 14, weight: .semibold))
                                .lineLimit(1)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    
                    if isLoading {
                        ProgressView()
                            .padding(.top, 40)
                    } else {
                        // Stats comparison
                        VStack(alignment: .leading, spacing: 20) {
                            Text("\(L.t(sv: "Stats", nb: "Stats")) - \(selectedPeriod.displayName)")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.gray)
                                .padding(.horizontal, 20)
                            
                            // Workout Count
                            ComparisonStatRow(
                                title: L.t(sv: "Antal pass", nb: "Antall økter"),
                                myValue: myWorkoutCount,
                                theirValue: theirWorkoutCount,
                                myAvatarUrl: myAvatarUrl,
                                theirAvatarUrl: theirAvatarUrl
                            )
                            
                            // Workout Time
                            ComparisonTimeRow(
                                title: L.t(sv: "Träningstid", nb: "Treningstid"),
                                mySeconds: myTotalTime,
                                theirSeconds: theirTotalTime,
                                myAvatarUrl: myAvatarUrl,
                                theirAvatarUrl: theirAvatarUrl
                            )
                            
                            // Total Volume
                            ComparisonVolumeRow(
                                title: L.t(sv: "Total volym", nb: "Total volum"),
                                myVolume: myTotalVolume,
                                theirVolume: theirTotalVolume,
                                myAvatarUrl: myAvatarUrl,
                                theirAvatarUrl: theirAvatarUrl
                            )
                        }
                        .padding(.top, 20)
                        
                        // Common exercises section
                        if !commonExercises.isEmpty {
                            VStack(alignment: .leading, spacing: 16) {
                                HStack(spacing: 8) {
                                    Text(L.t(sv: "Jämför övningar", nb: "Sammenlign øvelser"))
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(.gray)
                                    
                                    Image(systemName: "questionmark.circle")
                                        .font(.system(size: 14))
                                        .foregroundColor(.gray)
                                }
                                .padding(.horizontal, 20)
                                .padding(.top, 24)
                                
                                ForEach(commonExercises) { exercise in
                                    Button {
                                        selectedExercise = exercise
                                    } label: {
                                        CommonExerciseRow(exercise: exercise)
                                    }
                                    .buttonStyle(.plain)
                                    
                                    if exercise.id != commonExercises.last?.id {
                                        Divider()
                                            .padding(.horizontal, 20)
                                    }
                                }
                            }
                        }
                    }
                    
                    Spacer(minLength: 50)
                }
            }
            .navigationTitle(L.t(sv: "Jämförelse", nb: "Sammenligning"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.primary)
                    }
                }
            }
        }
        .task { await loadComparisonData() }
        .sheet(item: $selectedExercise) { exercise in
            ExerciseComparisonView(
                exercise: exercise,
                myUsername: myUsername,
                myAvatarUrl: myAvatarUrl,
                theirUsername: theirUsername,
                theirAvatarUrl: theirAvatarUrl
            )
        }
    }
    
    private func loadComparisonData() async {
        isLoading = true
        
        let calendar = Calendar.current
        let now = Date()
        
        var startDate: Date?
        switch selectedPeriod {
        case .last30Days:
            startDate = calendar.date(byAdding: .day, value: -30, to: now)
        case .last90Days:
            startDate = calendar.date(byAdding: .day, value: -90, to: now)
        case .thisYear:
            startDate = calendar.date(from: calendar.dateComponents([.year], from: now))
        case .allTime:
            startDate = nil
        }
        
        // Load both users' posts in parallel
        let myPosts: [SocialWorkoutPost]
        let theirPosts: [SocialWorkoutPost]
        do {
            let myTask = Task { try await WorkoutService.shared.getUserWorkoutPosts(userId: myUserId, forceRefresh: true) }
            let theirTask = Task { try await WorkoutService.shared.getUserWorkoutPosts(userId: theirUserId, forceRefresh: true) }
            myPosts = (try? await myTask.value) ?? []
            theirPosts = (try? await theirTask.value) ?? []
        }
        
        // Filter by date range
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let isoFormatterNoFrac = ISO8601DateFormatter()
        isoFormatterNoFrac.formatOptions = [.withInternetDateTime]
        
        func parseDate(_ dateString: String) -> Date? {
            return isoFormatter.date(from: dateString) ?? isoFormatterNoFrac.date(from: dateString)
        }
        
        let filteredMyPosts = myPosts.filter { post in
            guard let startDate = startDate else { return true }
            guard let createdAt = parseDate(post.createdAt) else { return false }
            return createdAt >= startDate
        }
        
        let filteredTheirPosts = theirPosts.filter { post in
            guard let startDate = startDate else { return true }
            guard let createdAt = parseDate(post.createdAt) else { return false }
            return createdAt >= startDate
        }
        
        // Calculate volume from gym exercises
        var myVolume: Double = 0
        var theirVolume: Double = 0
        var myExerciseStats: [String: ExerciseStats] = [:]
        var theirExerciseStats: [String: ExerciseStats] = [:]
        
        for post in filteredMyPosts {
            if let exercises = post.exercises {
                for exercise in exercises {
                    // Calculate volume from arrays
                    var exerciseVolume: Double = 0
                    for i in 0..<min(exercise.reps.count, exercise.kg.count) {
                        exerciseVolume += exercise.kg[i] * Double(exercise.reps[i])
                    }
                    myVolume += exerciseVolume
                    
                    // Track exercise stats
                    let name = exercise.name
                    var stats = myExerciseStats[name] ?? ExerciseStats(exerciseName: name, exerciseId: exercise.id)
                    
                    for i in 0..<min(exercise.reps.count, exercise.kg.count) {
                        let setKg = exercise.kg[i]
                        let setReps = exercise.reps[i]
                        let setVolume = setKg * Double(setReps)
                        let oneRepMax = setKg * (1 + Double(setReps) / 30.0) // Epley formula
                        
                        if setKg > stats.heaviestWeight {
                            stats.heaviestWeight = setKg
                        }
                        if oneRepMax > stats.oneRepMax {
                            stats.oneRepMax = oneRepMax
                        }
                        if setVolume > stats.bestSetVolume {
                            stats.bestSetVolume = setVolume
                        }
                    }
                    myExerciseStats[name] = stats
                }
            }
        }
        
        for post in filteredTheirPosts {
            if let exercises = post.exercises {
                for exercise in exercises {
                    // Calculate volume from arrays
                    var exerciseVolume: Double = 0
                    for i in 0..<min(exercise.reps.count, exercise.kg.count) {
                        exerciseVolume += exercise.kg[i] * Double(exercise.reps[i])
                    }
                    theirVolume += exerciseVolume
                    
                    // Track exercise stats
                    let name = exercise.name
                    var stats = theirExerciseStats[name] ?? ExerciseStats(exerciseName: name, exerciseId: exercise.id)
                    
                    for i in 0..<min(exercise.reps.count, exercise.kg.count) {
                        let setKg = exercise.kg[i]
                        let setReps = exercise.reps[i]
                        let setVolume = setKg * Double(setReps)
                        let oneRepMax = setKg * (1 + Double(setReps) / 30.0) // Epley formula
                        
                        if setKg > stats.heaviestWeight {
                            stats.heaviestWeight = setKg
                        }
                        if oneRepMax > stats.oneRepMax {
                            stats.oneRepMax = oneRepMax
                        }
                        if setVolume > stats.bestSetVolume {
                            stats.bestSetVolume = setVolume
                        }
                    }
                    theirExerciseStats[name] = stats
                }
            }
        }
        
        // Find common exercises
        let myExerciseNames = Set(myExerciseStats.keys)
        let theirExerciseNames = Set(theirExerciseStats.keys)
        let commonNames = myExerciseNames.intersection(theirExerciseNames)
        
        var common: [CommonExercise] = []
        for name in commonNames {
            if let myStats = myExerciseStats[name], let theirStats = theirExerciseStats[name] {
                common.append(CommonExercise(
                    name: name,
                    exerciseId: myStats.exerciseId,
                    myStats: myStats,
                    theirStats: theirStats
                ))
            }
        }
        
        await MainActor.run {
            myWorkoutCount = filteredMyPosts.count
            theirWorkoutCount = filteredTheirPosts.count
            myTotalTime = filteredMyPosts.reduce(0) { $0 + ($1.duration ?? 0) }
            theirTotalTime = filteredTheirPosts.reduce(0) { $0 + ($1.duration ?? 0) }
            myTotalVolume = myVolume
            theirTotalVolume = theirVolume
            commonExercises = common.sorted { $0.name < $1.name }
            isLoading = false
        }
    }
}

// MARK: - Exercise Stats Helper
struct ExerciseStats {
    let exerciseName: String
    let exerciseId: String?
    var oneRepMax: Double = 0
    var heaviestWeight: Double = 0
    var bestSetVolume: Double = 0
}

// MARK: - Common Exercise
struct CommonExercise: Identifiable {
    let id = UUID()
    let name: String
    let exerciseId: String?
    let myStats: ExerciseStats
    let theirStats: ExerciseStats
}

// MARK: - Comparison Stat Row

struct ComparisonStatRow: View {
    let title: String
    let myValue: Int
    let theirValue: Int
    let myAvatarUrl: String?
    let theirAvatarUrl: String?
    
    private var maxValue: Int {
        max(myValue, theirValue, 1)
    }
    
    private var myProgress: CGFloat {
        CGFloat(myValue) / CGFloat(maxValue)
    }
    
    private var theirProgress: CGFloat {
        CGFloat(theirValue) / CGFloat(maxValue)
    }
    
    private var percentageDiff: Int {
        guard theirValue > 0 else { return myValue > 0 ? 100 : 0 }
        return Int(((Double(myValue) - Double(theirValue)) / Double(theirValue)) * 100)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                
                if percentageDiff != 0 {
                    HStack(spacing: 2) {
                        Image(systemName: percentageDiff > 0 ? "arrow.up" : "arrow.down")
                            .font(.system(size: 12, weight: .bold))
                        Text("\(abs(percentageDiff))%")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundColor(percentageDiff > 0 ? .green : .red)
                }
            }
            .padding(.horizontal, 20)
            
            // My bar
            HStack(spacing: 12) {
                ProfileAvatarView(path: myAvatarUrl ?? "", size: 28)
                
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color(.systemGray5))
                            .frame(height: 12)
                        
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.black)
                            .frame(width: geometry.size.width * myProgress, height: 12)
                    }
                }
                .frame(height: 12)
                
                Text("\(myValue)")
                    .font(.system(size: 14, weight: .semibold))
                    .frame(width: 40, alignment: .trailing)
            }
            .padding(.horizontal, 20)
            
            // Their bar
            HStack(spacing: 12) {
                ProfileAvatarView(path: theirAvatarUrl ?? "", size: 28)
                
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color(.systemGray5))
                            .frame(height: 12)
                        
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color(.systemGray3))
                            .frame(width: geometry.size.width * theirProgress, height: 12)
                    }
                }
                .frame(height: 12)
                
                Text("\(theirValue)")
                    .font(.system(size: 14, weight: .semibold))
                    .frame(width: 40, alignment: .trailing)
            }
            .padding(.horizontal, 20)
        }
    }
}

// MARK: - Comparison Time Row

struct ComparisonTimeRow: View {
    let title: String
    let mySeconds: Int
    let theirSeconds: Int
    let myAvatarUrl: String?
    let theirAvatarUrl: String?
    
    private var maxSeconds: Int {
        max(mySeconds, theirSeconds, 1)
    }
    
    private var myProgress: CGFloat {
        CGFloat(mySeconds) / CGFloat(maxSeconds)
    }
    
    private var theirProgress: CGFloat {
        CGFloat(theirSeconds) / CGFloat(maxSeconds)
    }
    
    private var percentageDiff: Int {
        guard theirSeconds > 0 else { return mySeconds > 0 ? 100 : 0 }
        return Int(((Double(mySeconds) - Double(theirSeconds)) / Double(theirSeconds)) * 100)
    }
    
    private func formatTime(_ seconds: Int) -> String {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        if hours > 0 {
            return "\(hours)h"
        }
        return "\(minutes)m"
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                
                if percentageDiff != 0 {
                    HStack(spacing: 2) {
                        Image(systemName: percentageDiff > 0 ? "arrow.up" : "arrow.down")
                            .font(.system(size: 12, weight: .bold))
                        Text("\(abs(percentageDiff))%")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundColor(percentageDiff > 0 ? .green : .red)
                }
            }
            .padding(.horizontal, 20)
            
            // My bar
            HStack(spacing: 12) {
                ProfileAvatarView(path: myAvatarUrl ?? "", size: 28)
                
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color(.systemGray5))
                            .frame(height: 12)
                        
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.black)
                            .frame(width: geometry.size.width * myProgress, height: 12)
                    }
                }
                .frame(height: 12)
                
                Text(formatTime(mySeconds))
                    .font(.system(size: 14, weight: .semibold))
                    .frame(width: 50, alignment: .trailing)
            }
            .padding(.horizontal, 20)
            
            // Their bar
            HStack(spacing: 12) {
                ProfileAvatarView(path: theirAvatarUrl ?? "", size: 28)
                
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color(.systemGray5))
                            .frame(height: 12)
                        
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color(.systemGray3))
                            .frame(width: geometry.size.width * theirProgress, height: 12)
                    }
                }
                .frame(height: 12)
                
                Text(formatTime(theirSeconds))
                    .font(.system(size: 14, weight: .semibold))
                    .frame(width: 50, alignment: .trailing)
            }
            .padding(.horizontal, 20)
        }
    }
}

// MARK: - Comparison Volume Row

struct ComparisonVolumeRow: View {
    let title: String
    let myVolume: Double
    let theirVolume: Double
    let myAvatarUrl: String?
    let theirAvatarUrl: String?
    
    private var maxVolume: Double {
        max(myVolume, theirVolume, 1)
    }
    
    private var myProgress: CGFloat {
        CGFloat(myVolume / maxVolume)
    }
    
    private var theirProgress: CGFloat {
        CGFloat(theirVolume / maxVolume)
    }
    
    private var percentageDiff: Int {
        guard theirVolume > 0 else { return myVolume > 0 ? 100 : 0 }
        return Int(((myVolume - theirVolume) / theirVolume) * 100)
    }
    
    private func formatVolume(_ volume: Double) -> String {
        if volume >= 1000 {
            return String(format: "%.0f kg", volume)
        }
        return String(format: "%.0f kg", volume)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                
                if percentageDiff != 0 {
                    HStack(spacing: 2) {
                        Image(systemName: percentageDiff > 0 ? "arrow.up" : "arrow.down")
                            .font(.system(size: 12, weight: .bold))
                        Text("\(abs(percentageDiff))%")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundColor(percentageDiff > 0 ? .green : .red)
                }
            }
            .padding(.horizontal, 20)
            
            // My bar
            HStack(spacing: 12) {
                ProfileAvatarView(path: myAvatarUrl ?? "", size: 28)
                
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color(.systemGray5))
                            .frame(height: 12)
                        
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.black)
                            .frame(width: geometry.size.width * myProgress, height: 12)
                    }
                }
                .frame(height: 12)
                
                Text(formatVolume(myVolume))
                    .font(.system(size: 14, weight: .semibold))
                    .frame(width: 70, alignment: .trailing)
            }
            .padding(.horizontal, 20)
            
            // Their bar
            HStack(spacing: 12) {
                ProfileAvatarView(path: theirAvatarUrl ?? "", size: 28)
                
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color(.systemGray5))
                            .frame(height: 12)
                        
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color(.systemGray3))
                            .frame(width: geometry.size.width * theirProgress, height: 12)
                    }
                }
                .frame(height: 12)
                
                Text(formatVolume(theirVolume))
                    .font(.system(size: 14, weight: .semibold))
                    .frame(width: 70, alignment: .trailing)
            }
            .padding(.horizontal, 20)
        }
    }
}

// MARK: - Common Exercise Row

struct CommonExerciseRow: View {
    let exercise: CommonExercise
    
    var body: some View {
        HStack(spacing: 16) {
            // Exercise image
            if let exerciseId = exercise.exerciseId {
                ExerciseGIFView(exerciseId: exerciseId, gifUrl: nil)
                    .frame(width: 60, height: 60)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
            } else {
                Image(systemName: "dumbbell.fill")
                    .font(.system(size: 24))
                    .foregroundColor(.gray)
                    .frame(width: 60, height: 60)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(exercise.name)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
                Text(L.t(sv: "Tryck för att jämföra", nb: "Trykk for å sammenligne"))
                    .font(.system(size: 13))
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.gray)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }
}

// MARK: - Exercise Comparison View

struct ExerciseComparisonView: View {
    let exercise: CommonExercise
    let myUsername: String
    let myAvatarUrl: String?
    let theirUsername: String
    let theirAvatarUrl: String?
    
    @Environment(\.dismiss) var dismiss
    
    // Determine who is stronger (wins more categories)
    private var amIStronger: Bool {
        var myWins = 0
        var theirWins = 0
        
        if exercise.myStats.oneRepMax > exercise.theirStats.oneRepMax { myWins += 1 } else if exercise.theirStats.oneRepMax > exercise.myStats.oneRepMax { theirWins += 1 }
        if exercise.myStats.heaviestWeight > exercise.theirStats.heaviestWeight { myWins += 1 } else if exercise.theirStats.heaviestWeight > exercise.myStats.heaviestWeight { theirWins += 1 }
        if exercise.myStats.bestSetVolume > exercise.theirStats.bestSetVolume { myWins += 1 } else if exercise.theirStats.bestSetVolume > exercise.myStats.bestSetVolume { theirWins += 1 }
        
        return myWins > theirWins
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // VS Header
                    HStack(spacing: 20) {
                        // My profile
                        VStack(spacing: 8) {
                            ProfileAvatarView(path: myAvatarUrl ?? "", size: 80)
                                .overlay(
                                    Circle()
                                        .stroke(Color.black, lineWidth: 3)
                                )
                            Text(myUsername)
                                .font(.system(size: 14, weight: .semibold))
                                .lineLimit(1)
                            
                            if amIStronger {
                                Text(L.t(sv: "STARKARE", nb: "STERKERE"))
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 4)
                                    .background(Color.green)
                                    .cornerRadius(12)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        
                        // VS badge
                        Text("VS")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                            .background(Color.black)
                            .clipShape(Circle())
                        
                        // Their profile
                        VStack(spacing: 8) {
                            ProfileAvatarView(path: theirAvatarUrl ?? "", size: 80)
                                .overlay(
                                    Circle()
                                        .stroke(Color(.systemGray4), lineWidth: 3)
                                )
                            Text(theirUsername)
                                .font(.system(size: 14, weight: .semibold))
                                .lineLimit(1)
                            
                            if !amIStronger {
                                Text(L.t(sv: "STARKARE", nb: "STERKERE"))
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 4)
                                    .background(Color.green)
                                    .cornerRadius(12)
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    
                    // Exercise info
                    VStack(alignment: .leading, spacing: 8) {
                        Text(L.t(sv: "Övning", nb: "Øvelse"))
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.gray)
                        
                        HStack(spacing: 12) {
                            if let exerciseId = exercise.exerciseId {
                                ExerciseGIFView(exerciseId: exerciseId, gifUrl: nil)
                                    .frame(width: 60, height: 60)
                                    .background(Color(.systemGray6))
                                    .cornerRadius(8)
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(exercise.name)
                                    .font(.system(size: 16, weight: .semibold))
                            }
                            
                            Spacer()
                        }
                    }
                    .padding(.horizontal, 20)
                    
                    // Comparison stats
                    VStack(alignment: .leading, spacing: 8) {
                        Text(L.t(sv: "Jämförelse", nb: "Sammenligning"))
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.gray)
                            .padding(.horizontal, 20)
                        
                        VStack(spacing: 20) {
                            // One Rep Max
                            ExerciseStatCompareRow(
                                title: "One Rep Max",
                                myValue: exercise.myStats.oneRepMax,
                                theirValue: exercise.theirStats.oneRepMax,
                                unit: "kg",
                                myAvatarUrl: myAvatarUrl,
                                theirAvatarUrl: theirAvatarUrl
                            )
                            
                            // Heaviest Weight
                            ExerciseStatCompareRow(
                                title: L.t(sv: "Tyngsta vikt", nb: "Tyngste vekt"),
                                myValue: exercise.myStats.heaviestWeight,
                                theirValue: exercise.theirStats.heaviestWeight,
                                unit: "kg",
                                myAvatarUrl: myAvatarUrl,
                                theirAvatarUrl: theirAvatarUrl
                            )
                            
                            // Best Set Volume
                            ExerciseStatCompareRow(
                                title: L.t(sv: "Bästa set (volym)", nb: "Beste sett (volum)"),
                                myValue: exercise.myStats.bestSetVolume,
                                theirValue: exercise.theirStats.bestSetVolume,
                                unit: "kg",
                                myAvatarUrl: myAvatarUrl,
                                theirAvatarUrl: theirAvatarUrl
                            )
                        }
                    }
                    .padding(.top, 8)
                    
                    Spacer(minLength: 50)
                }
            }
            .navigationTitle(L.t(sv: "Jämförelse", nb: "Sammenligning"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.primary)
                    }
                }
            }
        }
    }
}

// MARK: - Exercise Stat Compare Row

struct ExerciseStatCompareRow: View {
    let title: String
    let myValue: Double
    let theirValue: Double
    let unit: String
    let myAvatarUrl: String?
    let theirAvatarUrl: String?
    
    private var maxValue: Double {
        max(myValue, theirValue, 1)
    }
    
    private var myProgress: CGFloat {
        CGFloat(myValue / maxValue)
    }
    
    private var theirProgress: CGFloat {
        CGFloat(theirValue / maxValue)
    }
    
    private var percentageDiff: Int {
        guard theirValue > 0 else { return myValue > 0 ? 100 : 0 }
        return Int(((myValue - theirValue) / theirValue) * 100)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                
                if percentageDiff != 0 {
                    HStack(spacing: 2) {
                        Image(systemName: percentageDiff > 0 ? "arrow.up" : "arrow.down")
                            .font(.system(size: 12, weight: .bold))
                        Text("\(abs(percentageDiff))%")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundColor(percentageDiff > 0 ? .green : .red)
                }
            }
            .padding(.horizontal, 20)
            
            // My bar
            HStack(spacing: 12) {
                ProfileAvatarView(path: myAvatarUrl ?? "", size: 28)
                
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color(.systemGray5))
                            .frame(height: 12)
                        
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.black)
                            .frame(width: geometry.size.width * myProgress, height: 12)
                    }
                }
                .frame(height: 12)
                
                Text("\(Int(myValue))\(unit)")
                    .font(.system(size: 14, weight: .semibold))
                    .frame(width: 60, alignment: .trailing)
            }
            .padding(.horizontal, 20)
            
            // Their bar
            HStack(spacing: 12) {
                ProfileAvatarView(path: theirAvatarUrl ?? "", size: 28)
                
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color(.systemGray5))
                            .frame(height: 12)
                        
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color(.systemGray3))
                            .frame(width: geometry.size.width * theirProgress, height: 12)
                    }
                }
                .frame(height: 12)
                
                Text("\(Int(theirValue))\(unit)")
                    .font(.system(size: 14, weight: .semibold))
                    .frame(width: 60, alignment: .trailing)
            }
            .padding(.horizontal, 20)
        }
    }
}