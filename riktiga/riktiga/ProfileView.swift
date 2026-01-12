import SwiftUI
import Combine

struct ProfileView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var isPremium = RevenueCatManager.shared.isProMember
    @State private var showImagePicker = false
    @State private var profileImage: UIImage?
    @State private var showSettings = false
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
    @State private var showPublicProfile = false
    @State private var navigationPath = NavigationPath()
    @State private var showRoutines = false
    
    private let statsLoadThrottle: TimeInterval = 60
    
    
    var body: some View {
        NavigationStack(path: $navigationPath) {
            VStack(spacing: 0) {
                // MARK: - Fixed Strava-Style Navigation Header (with settings icon)
                StravaStyleHeaderView(isProfilePage: true, onSettingsTapped: {
                    showSettings = true
                })
                    .environmentObject(authViewModel)
                    .zIndex(1)
                
                ScrollView {
                    LazyVStack(spacing: 16) {
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
                                            .foregroundColor(.primary)
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
                                                .foregroundColor(.primary)
                                            Text("Följare")
                                                .font(.caption2)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                    
                                    Button(action: {
                                        showFollowingList = true
                                    }) {
                                        VStack(spacing: 4) {
                                            Text("\(followingCount)")
                                                .font(.system(size: 16, weight: .bold))
                                                .foregroundColor(.primary)
                                            Text("Följer")
                                                .font(.caption2)
                                                .foregroundColor(.secondary)
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
                    
                    // MARK: - Public Profile Button
                    Button(action: {
                        showPublicProfile = true
                    }) {
                        HStack {
                            Image(systemName: "person.crop.circle")
                                .font(.system(size: 16, weight: .medium))
                            Text("Se din publika profil")
                                .font(.system(size: 15, weight: .medium))
                        }
                        .foregroundColor(.primary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
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
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.primary, lineWidth: 2)
                    )
                    
                    // MARK: - Action Buttons (2x2 grid)
                    VStack(spacing: 10) {
                        // First row
                        HStack(spacing: 10) {
                            ProfileCardButton(
                                icon: "cart.fill",
                                label: "Mina köp",
                                action: { showMyPurchases = true }
                            )
                            
                            NavigationLink(destination: StatisticsView()) {
                                VStack(spacing: 10) {
                                    Image(systemName: "chart.bar.fill")
                                        .font(.system(size: 24))
                                        .foregroundColor(.primary)
                                    
                                    Text("Statistik")
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundColor(.primary)
                                        .lineLimit(1)
                                }
                                .frame(maxWidth: .infinity)
                                .frame(height: 90)
                                .background(Color(.secondarySystemBackground))
                                .cornerRadius(16)
                                .shadow(color: .black.opacity(0.08), radius: 12, x: 0, y: 4)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                        
                        // Second row
                        HStack(spacing: 10) {
                            ProfileCardButton(
                                icon: "person.badge.plus.fill",
                                label: "Hitta vänner",
                                action: { showFindFriends = true }
                            )
                            
                            ProfileCardButton(
                                icon: "bookmark.fill",
                                label: "Sparade pass",
                                action: { showRoutines = true }
                            )
                        }
                    }
                    
                    
                    // MARK: - Up&Down Live Gallery
                    UpAndDownLiveGallery(posts: myPostsViewModel.posts)
                    
                    // MARK: - Recovery Zone
                    if let userId = authViewModel.currentUser?.id {
                        RecoveryZoneView(userId: userId)
                            .padding(.top, 20)
                    }
                    
                    Divider()
                        .background(Color(.systemGray4))
                        .padding(.top, 24)
                    
                    // MARK: - My Posts Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Mina aktiviteter")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.primary)
                            .padding(.horizontal, 4)
                        
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
                                Text("Dina sparade pass kommer visas här.")
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
                .padding(16)
                }
            }
            .navigationBarHidden(true)
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
            .sheet(isPresented: $showRoutines) {
                NavigationStack {
                    RoutinesView()
                        .environmentObject(authViewModel)
                }
            }
            .sheet(isPresented: $showPublicProfile) {
                if let userId = authViewModel.currentUser?.id {
                    NavigationStack {
                        UserProfileView(userId: userId)
                            .toolbar {
                                ToolbarItem(placement: .navigationBarLeading) {
                                    Button("Stäng") {
                                        showPublicProfile = false
                                    }
                                }
                            }
                    }
                    }
            }
            .task {
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
                                self.activityCount = self.myPostsViewModel.posts.count
                            }
                            // Prefetch post images for faster display
                            await self.prefetchPostImages()
                        }
                    }
                }
            }
            .onReceive(RevenueCatManager.shared.$isProMember) { newValue in
                isPremium = newValue
            }
            .onReceive(NotificationCenter.default.publisher(for: .profileStatsUpdated)) { _ in
                loadProfileStats(force: true)
            }
            .onChange(of: myPostsViewModel.posts.count) { _, newCount in
                activityCount = newCount
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
                
                // Load in parallel for better performance
                async let followersTask = SocialService.shared.getFollowers(userId: currentUserId)
                async let followingTask = SocialService.shared.getFollowing(userId: currentUserId)
                
                let (followers, following) = try await (followersTask, followingTask)
                
                await MainActor.run {
                    self.followersCount = followers.count
                    self.followingCount = following.count
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
            .background(Color(.secondarySystemBackground))
            .cornerRadius(16)
            .shadow(color: colorScheme == .dark ? .clear : .black.opacity(0.08), radius: 12, x: 0, y: 4)
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
    ProfileView()
        .environmentObject(AuthViewModel())
}

// MARK: - Up&Down Live Gallery
struct UpAndDownLiveGallery: View {
    let posts: [SocialWorkoutPost]
    
    // Filter posts that have Up&Down Live photos (filename contains "live_")
    private var postsWithImages: [SocialWorkoutPost] {
        posts.filter { post in
            // Check for live photos in userImageUrl (has "live_" prefix in filename)
            if let userImageUrl = post.userImageUrl, !userImageUrl.isEmpty {
                return userImageUrl.contains("live_")
            }
            return false
        }
    }
    
    // Create rows of 3 images
    private var imageRows: [[SocialWorkoutPost]] {
        var rows: [[SocialWorkoutPost]] = []
        var currentRow: [SocialWorkoutPost] = []
        
        for post in postsWithImages {
            currentRow.append(post)
            if currentRow.count == 3 {
                rows.append(currentRow)
                currentRow = []
            }
        }
        
        // Add remaining items
        if !currentRow.isEmpty {
            rows.append(currentRow)
        }
        
        return rows
    }
    
    // Subtle gray that blends with background
    private let sectionBackground = Color(.systemGray6)
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Image("23")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 28, height: 28)
                    .cornerRadius(6)
                
                Text("Up&Down Live")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.primary)
                
                Spacer()
                
                Text("\(postsWithImages.count)")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.gray)
            }
            .padding(.horizontal, 8)
            .padding(.top, 8)
            
            if postsWithImages.isEmpty {
                // Empty state
                VStack(spacing: 12) {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.gray.opacity(0.5))
                    
                    Text("Inga Up&Down Live bilder än")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.gray)
                    
                    Text("Ta en bild med Up&Down Live efter ditt nästa pass!")
                        .font(.system(size: 13))
                        .foregroundColor(.gray.opacity(0.7))
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            } else {
                // Photo grid - 3 columns
                VStack(spacing: 8) {
                    ForEach(Array(imageRows.enumerated()), id: \.offset) { rowIndex, row in
                        HStack(spacing: 8) {
                            ForEach(row) { post in
                                LivePhotoCell(post: post)
                            }
                            
                            // Fill empty spots in last row
                            if row.count < 3 {
                                ForEach(0..<(3 - row.count), id: \.self) { _ in
                                    Rectangle()
                                        .fill(Color.clear)
                                        .aspectRatio(1, contentMode: .fit)
                                }
                            }
                        }
                    }
                }
                .padding(8)
            }
        }
        .padding(8)
        .background(sectionBackground)
        .cornerRadius(16)
    }
}

// MARK: - Live Photo Cell
struct LivePhotoCell: View {
    let post: SocialWorkoutPost
    @State private var showDetail = false
    
    var body: some View {
        Button(action: {
            showDetail = true
        }) {
            GeometryReader { geo in
                // Use userImageUrl for Up&Down Live photos
                if let userImageUrl = post.userImageUrl, userImageUrl.contains("live_") {
                    LivePhotoGridImage(path: userImageUrl)
                        .frame(width: geo.size.width, height: geo.size.width)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                } else {
                    Rectangle()
                        .fill(Color(.systemGray5))
                        .frame(width: geo.size.width, height: geo.size.width)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
            .aspectRatio(1, contentMode: .fit)
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showDetail) {
            LivePhotoDetailView(post: post)
        }
    }
}

// MARK: - Live Photo Grid Image (fills cell properly)
struct LivePhotoGridImage: View {
    let path: String
    @State private var image: UIImage?
    @State private var isLoading = true
    
    var body: some View {
        ZStack {
            Color.black
            
            if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else if isLoading {
                ProgressView()
                    .tint(.white)
            }
        }
        .task {
            await loadImage()
        }
    }
    
    private func loadImage() async {
        // Check cache first
        if let cached = ImageCacheManager.shared.getImage(for: path) {
            await MainActor.run {
                self.image = cached
                self.isLoading = false
            }
            return
        }
        
        // Load from URL
        guard let url = URL(string: path) else {
            isLoading = false
            return
        }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            if let loadedImage = UIImage(data: data) {
                ImageCacheManager.shared.setImage(loadedImage, for: path)
                await MainActor.run {
                    self.image = loadedImage
                    self.isLoading = false
                }
            }
        } catch {
            await MainActor.run {
                self.isLoading = false
            }
        }
    }
}

// MARK: - Live Photo Detail View
struct LivePhotoDetailView: View {
    let post: SocialWorkoutPost
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack {
                // Close button
                HStack {
                    Spacer()
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.white)
                            .padding(12)
                            .background(Color.white.opacity(0.2))
                            .clipShape(Circle())
                    }
                    .padding(.trailing, 16)
                    .padding(.top, 50)
                }
                
                Spacer()
                
                // Image - use userImageUrl for Up&Down Live photos
                if let userImageUrl = post.userImageUrl, userImageUrl.contains("live_") {
                    LocalAsyncImage(path: userImageUrl)
                        .scaledToFit()
                        .cornerRadius(16)
                        .padding(.horizontal, 16)
                }
                
                Spacer()
                
                // Info
                VStack(spacing: 8) {
                    Text(post.title ?? "Träningspass")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                    
                    HStack(spacing: 16) {
                        if let distance = post.distance, distance > 0 {
                            Label(String(format: "%.2f km", distance), systemImage: "figure.run")
                                .foregroundColor(.white.opacity(0.8))
                        }
                        
                        if let duration = post.duration, duration > 0 {
                            Label(formatDuration(duration), systemImage: "clock")
                                .foregroundColor(.white.opacity(0.8))
                        }
                    }
                    .font(.system(size: 14))
                    
                    Text(formatDate(post.createdAt))
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.6))
                }
                .padding(.bottom, 50)
            }
        }
    }
    
    private func formatDuration(_ seconds: Int) -> String {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        let secs = seconds % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        } else {
            return String(format: "%d:%02d", minutes, secs)
        }
    }
    
    private func formatDate(_ isoString: String) -> String {
        let isoFormatter = ISO8601DateFormatter()
        guard let date = isoFormatter.date(from: isoString) else { return "" }
        
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "sv_SE")
        formatter.dateFormat = "d MMM yyyy"
        return formatter.string(from: date)
    }
}

// MARK: - Helper Functions
func formatNumber(_ number: Int) -> String {
    let formatter = NumberFormatter()
    formatter.numberStyle = .decimal
    formatter.groupingSeparator = ","
    return formatter.string(from: NSNumber(value: number)) ?? "\(number)"
}
