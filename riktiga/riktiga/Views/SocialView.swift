import SwiftUI
import Combine

struct SocialView: View {
    @StateObject private var socialViewModel = SocialViewModel()
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var visiblePostCount = 5 // Start with 5 posts
    @State private var isLoadingMore = false
    @State private var task: Task<Void, Never>?
    
    var body: some View {
            NavigationStack {
            ZStack {
                Color(.systemBackground).ignoresSafeArea()
                
                if socialViewModel.isLoading && socialViewModel.posts.isEmpty {
                    VStack(spacing: 20) {
                        ProgressView()
                            .tint(AppColors.brandBlue)
                            .scaleEffect(1.5)
                        Text("Laddar inlägg...")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.gray)
                    }
                } else if socialViewModel.posts.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "person.2.badge.plus")
                            .font(.system(size: 64))
                            .foregroundColor(.gray)
                        Text("Inga inlägg än")
                            .font(.system(size: 20, weight: .semibold))
                        Text("Skapa ett pass i Aktiviteter-tabben eller följ andra användare för att se deras inlägg")
                            .font(.system(size: 16))
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                        
                        // Debug info
                        VStack(spacing: 4) {
                            Text("Tips:")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.gray)
                            Text("• Följ andra användare")
                                .font(.system(size: 12))
                                .foregroundColor(.gray)
                            Text("• Eller skapa ett eget pass")
                                .font(.system(size: 12))
                                .foregroundColor(.gray)
                        }
                        .padding(12)
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                    }
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            HomeHeaderView()
                        }
                        
                        LazyVStack(spacing: 16) {
                            // Show posts dynamically based on visiblePostCount
                            ForEach(Array(socialViewModel.posts.prefix(visiblePostCount))) { post in
                                SocialPostCard(post: post, viewModel: socialViewModel)
                                    .onAppear {
                                        // Load more posts when user scrolls near the end
                                        if let index = socialViewModel.posts.firstIndex(where: { $0.id == post.id }),
                                           index >= visiblePostCount - 2,
                                           visiblePostCount < socialViewModel.posts.count {
                                            loadMorePosts()
                                        }
                                    }
                            }
                            
                            // Loading indicator at the bottom when loading more
                            if isLoadingMore {
                                HStack {
                                    Spacer()
                                    ProgressView()
                                        .tint(AppColors.brandBlue)
                                    Spacer()
                                }
                                .padding()
                            }
                            
                            // End of list message
                            if visiblePostCount >= socialViewModel.posts.count {
                                Text("Inga fler inlägg")
                                    .font(.system(size: 14))
                                    .foregroundColor(.gray)
                                    .padding()
                            }
                        }
                        .padding(16)
                    }
                }
            }
            .navigationTitle("")
            .navigationBarHidden(true)
            .navigationBarTitleDisplayMode(.inline)
            .task {
                // Cancel any previous task
                task?.cancel()
                
                guard let userId = authViewModel.currentUser?.id else { return }
                
                // Create new task
                task = Task {
                    await socialViewModel.fetchSocialFeedAsync(userId: userId)
                }
            }
            .onDisappear {
                task?.cancel()
            }
            .refreshable {
                if let userId = authViewModel.currentUser?.id {
                    visiblePostCount = 5 // Reset to 5 posts when refreshing
                    await socialViewModel.refreshSocialFeed(userId: userId)
                }
            }
        }
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
}

struct SocialPostCard: View {
    let post: SocialWorkoutPost
    @State private var showComments = false
    @State private var isLiked = false
    @State private var likeCount = 0
    @State private var commentCount = 0
    @State private var showMenu = false
    @State private var showDeleteAlert = false
    @State private var likeInProgress = false
    @State private var showShareSheet = false
    @EnvironmentObject var authViewModel: AuthViewModel
    @ObservedObject var viewModel: SocialViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header with user info
            HStack(spacing: 12) {
                // User avatar -> navigate to profile
                NavigationLink(destination: UserProfileView(userId: post.userId)) {
                    AsyncImage(url: URL(string: post.userAvatarUrl ?? "")) { image in
                        image
                            .resizable()
                            .scaledToFill()
                    } placeholder: {
                        Image(systemName: "person.circle.fill")
                            .foregroundColor(.gray)
                    }
                    .frame(width: 40, height: 40)
                    .clipShape(Circle())
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    // Username with Activity Icon -> navigate to profile
                    NavigationLink(destination: UserProfileView(userId: post.userId)) {
                        HStack(spacing: 6) {
                            Text(post.userName ?? "Okänd användare")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.black)
                            
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
                
                // Only show menu button for posts by current user
                if post.userId == authViewModel.currentUser?.id {
                    Button(action: {
                        showMenu = true
                    }) {
                        Image(systemName: "ellipsis")
                            .foregroundColor(.black)
                            .font(.system(size: 16))
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 8)
            
            // Swipeable images (route and user image)
            SwipeableImageView(routeImage: post.imageUrl, userImage: post.userImageUrl)
            
            // Content below image
            VStack(alignment: .leading, spacing: 12) {
                // Title with PRO badge
                HStack(spacing: 8) {
                    Text(post.title)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.black)
                    
                    if let isPro = post.userIsPro, isPro {
                        Text("PRO")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.black)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(Color.yellow)
                            .cornerRadius(4)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                
                // Stats row with white background
                HStack(spacing: 0) {
                    if let distance = post.distance {
                        VStack(spacing: 6) {
                            Text("Distans")
                                .font(.system(size: 11))
                                .foregroundColor(.gray)
                            Text(String(format: "%.2f km", distance))
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.black)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                    }
                    
                    if let duration = post.duration {
                        if post.distance != nil {
                            Divider()
                                .frame(height: 40)
                        }
                        
                        VStack(spacing: 6) {
                            Text("Tid")
                                .font(.system(size: 11))
                                .foregroundColor(.gray)
                            Text(formatDuration(duration))
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.black)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                    }
                    
                    if let strokes = post.strokes {
                        if post.distance != nil || post.duration != nil {
                            Divider()
                                .frame(height: 40)
                        }
                        
                        VStack(spacing: 6) {
                            Text("Slag")
                                .font(.system(size: 11))
                                .foregroundColor(.gray)
                            Text("\(strokes)")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.black)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                    }
                }
                .background(Color.white)
                .cornerRadius(12)
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }
            
            // Like, Comment, Share buttons
            HStack(spacing: 16) {
                Button(action: toggleLike) {
                    HStack(spacing: 6) {
                        Image(systemName: isLiked ? "heart.fill" : "heart")
                            .foregroundColor(isLiked ? .red : .gray)
                            .scaleEffect(isLiked ? 1.2 : 1.0)
                            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isLiked)
                        Text("\(likeCount)")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.gray)
                            .animation(.easeInOut(duration: 0.2), value: likeCount)
                    }
                }
                .disabled(likeInProgress)
                
                Button(action: { showComments = true }) {
                    HStack(spacing: 6) {
                        Image(systemName: "bubble.right")
                            .foregroundColor(.gray)
                        Text("\(commentCount)")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.gray)
                    }
                }
                
                Button(action: { showShareSheet = true }) {
                    HStack(spacing: 6) {
                        Image(systemName: "square.and.arrow.up")
                            .foregroundColor(.gray)
                    }
                }
                
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
        }
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
        .onAppear {
            isLiked = post.isLikedByCurrentUser ?? false
            likeCount = post.likeCount ?? 0
            commentCount = post.commentCount ?? 0
        }
        .sheet(isPresented: $showComments) {
            CommentsView(postId: post.id) {
                commentCount += 1
                viewModel.updatePostCommentCount(postId: post.id, commentCount: commentCount)
            }
        }
        .confirmationDialog("Post Options", isPresented: $showMenu, titleVisibility: .hidden) {
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
    }
    
    private func deletePost() {
        Task {
            do {
                try await WorkoutService.shared.deleteWorkoutPost(postId: post.id)
                print("✅ Post deleted successfully")
                // Remove post from the list immediately
                await MainActor.run {
                    viewModel.posts.removeAll { $0.id == post.id }
                }
            } catch {
                print("❌ Error deleting post: \(error)")
            }
        }
    }
    
    private func toggleLike() {
        guard let userId = authViewModel.currentUser?.id else { return }
        guard !likeInProgress else { return }
        
        // Store previous state for rollback
        let previousLiked = isLiked
        let previousCount = likeCount
        
        // Update UI immediately (optimistic update)
        likeInProgress = true
        isLiked.toggle()
        likeCount += isLiked ? 1 : -1
        
        Task {
            do {
                if isLiked {
                    // When liking, check if already liked first
                    let existingLikes = try await SocialService.shared.getPostLikes(postId: post.id)
                    let alreadyLiked = existingLikes.contains { $0.userId == userId }
                    
                    if !alreadyLiked {
                        try await SocialService.shared.likePost(postId: post.id, userId: userId)
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
                }
                viewModel.updatePostLikeStatus(postId: post.id, isLiked: isLiked, likeCount: likeCount)
            } catch {
                print("❌ Error toggling like: \(error)")
                // Rollback on error
                await MainActor.run {
                    isLiked = previousLiked
                    likeCount = previousCount
                    likeInProgress = false
                }
            }
        }
    }
    
    func getActivityIcon(_ activity: String) -> String {
        switch activity {
        case "Löppass":
            return "figure.run"
        case "Golfrunda":
            return "flag.fill"
        case "Promenad":
            return "figure.walk"
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
    let onCommentAdded: (() -> Void)?
    @StateObject private var commentsViewModel = CommentsViewModel()
    @State private var newComment = ""
    @EnvironmentObject var authViewModel: AuthViewModel
    @Environment(\.dismiss) private var dismiss
    @Namespace private var bottomID
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Comments list
                ScrollViewReader { scrollProxy in
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(commentsViewModel.comments) { comment in
                                CommentRow(comment: comment)
                            }
                            
                            // Anchor for scrolling to bottom
                            Color.clear
                                .frame(height: 0)
                                .id(bottomID)
                        }
                        .padding(16)
                    }
                    .onChange(of: commentsViewModel.comments.count) { _ in
                        withAnimation {
                            scrollProxy.scrollTo(bottomID, anchor: .bottom)
                        }
                    }
                }
                
                // Add comment section
                VStack(spacing: 12) {
                    Divider()
                    
                    HStack(spacing: 12) {
                        TextField("Skriv en kommentar...", text: $newComment)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                        
                        Button("Skicka") {
                            addComment()
                        }
                        .disabled(newComment.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
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
            .task {
                await commentsViewModel.fetchCommentsAsync(postId: postId)
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
            userAvatarUrl: authViewModel.currentUser?.avatarUrl
        )
        
        // Add to UI immediately
        commentsViewModel.comments.append(optimisticComment)
        newComment = ""
        
        Task {
            do {
                try await SocialService.shared.addComment(
                    postId: postId,
                    userId: userId,
                    content: commentText
                )
                print("✅ Comment added successfully")
                
                await MainActor.run {
                    onCommentAdded?()
                }
            } catch {
                print("❌ Error adding comment: \(error)")
                // Remove optimistic comment on error
                await MainActor.run {
                    commentsViewModel.comments.removeAll { $0.id == optimisticComment.id }
                }
            }
        }
    }
}

struct CommentRow: View {
    let comment: PostComment
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // User avatar
            if let avatarUrl = comment.userAvatarUrl, !avatarUrl.isEmpty {
                ProfileImage(url: avatarUrl, size: 32)
            } else {
                Circle()
                    .fill(Color(.systemGray5))
                    .frame(width: 32, height: 32)
                    .overlay(
                        Image(systemName: "person.fill")
                            .foregroundColor(.gray)
                            .font(.system(size: 14))
                    )
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(comment.userName ?? "Användare")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.black)
                
                Text(comment.content)
                    .font(.system(size: 14))
                    .foregroundColor(.black)
                    .lineLimit(nil)
                
                Text(formatDate(comment.createdAt))
                    .font(.system(size: 12))
                    .foregroundColor(.gray)
            }
            
            Spacer()
        }
    }
    
    func formatDate(_ dateString: String) -> String {
        let formatter = ISO8601DateFormatter()
        if let date = formatter.date(from: dateString) {
            let timeFormatter = DateFormatter()
            timeFormatter.timeStyle = .short
            return timeFormatter.string(from: date)
        }
        return dateString
    }
}

class SocialViewModel: ObservableObject {
    @Published var posts: [SocialWorkoutPost] = []
    @Published var isLoading: Bool = false
    private var isFetching = false
    
    func fetchSocialFeed(userId: String) {
        isLoading = true
        Task {
            do {
                let fetchedPosts = try await SocialService.shared.getSocialFeed(userId: userId)
                await MainActor.run {
                    self.posts = fetchedPosts
                    self.isLoading = false
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
        // Prevent duplicate fetches
        if isFetching { return }
        
        isFetching = true
        isLoading = true
        
        // Try to load from cache first
        if let cachedPosts = AppCacheManager.shared.getCachedSocialFeed(userId: userId) {
            await MainActor.run {
                self.posts = cachedPosts
                self.isLoading = false
            }
                    }
        
        do {
            let fetchedPosts = try await SocialService.shared.getSocialFeed(userId: userId)
            
            // Save to cache
            AppCacheManager.shared.saveSocialFeed(fetchedPosts, userId: userId)
            
            await MainActor.run {
                self.posts = fetchedPosts
                self.isLoading = false
                self.isFetching = false
            }
        } catch is CancellationError {
            print("⚠️ Fetch was cancelled")
            await MainActor.run {
                self.isLoading = false
                self.isFetching = false
            }
        } catch {
            print("Error fetching social feed: \(error)")
            await MainActor.run {
                self.isLoading = false
            }
        }
    }
    
    func refreshSocialFeed(userId: String) async {
        do {
            // Use retry helper for better network resilience
            let fetchedPosts = try await RetryHelper.shared.retry(maxRetries: 3, delay: 0.5) {
                return try await SocialService.shared.getSocialFeed(userId: userId)
            }
            
            // Only update posts if we got new data, don't replace with empty array
            if !fetchedPosts.isEmpty {
                await MainActor.run {
                    self.posts = fetchedPosts
                }
            } else {
                print("⚠️ Refresh returned empty array, keeping existing posts")
            }
        } catch is CancellationError {
            // Cancelled refresh - don't update posts or log as error
            print("⚠️ Refresh was cancelled")
        } catch {
            print("❌ Error refreshing social feed after retries: \(error)")
        }
    }
    
    func updatePostLikeStatus(postId: String, isLiked: Bool, likeCount: Int) {
        if let index = posts.firstIndex(where: { $0.id == postId }) {
            var updatedPost = posts[index]
            updatedPost = SocialWorkoutPost(
                from: WorkoutPost(
                    id: updatedPost.id,
                    userId: updatedPost.userId,
                    activityType: updatedPost.activityType,
                    title: updatedPost.title,
                    description: updatedPost.description,
                    distance: updatedPost.distance,
                    duration: updatedPost.duration,
                    imageUrl: updatedPost.imageUrl,
                    elevationGain: nil,
                    maxSpeed: nil
                ),
                userName: updatedPost.userName,
                userAvatarUrl: updatedPost.userAvatarUrl,
                userIsPro: updatedPost.userIsPro,
                location: updatedPost.location,
                strokes: updatedPost.strokes,
                likeCount: likeCount,
                commentCount: updatedPost.commentCount ?? 0,
                isLikedByCurrentUser: isLiked
            )
            posts[index] = updatedPost
        }
    }
    
    func updatePostCommentCount(postId: String, commentCount: Int) {
        if let index = posts.firstIndex(where: { $0.id == postId }) {
            var updatedPost = posts[index]
            updatedPost = SocialWorkoutPost(
                from: WorkoutPost(
                    id: updatedPost.id,
                    userId: updatedPost.userId,
                    activityType: updatedPost.activityType,
                    title: updatedPost.title,
                    description: updatedPost.description,
                    distance: updatedPost.distance,
                    duration: updatedPost.duration,
                    imageUrl: updatedPost.imageUrl,
                    elevationGain: nil,
                    maxSpeed: nil
                ),
                userName: updatedPost.userName,
                userAvatarUrl: updatedPost.userAvatarUrl,
                userIsPro: updatedPost.userIsPro,
                location: updatedPost.location,
                strokes: updatedPost.strokes,
                likeCount: updatedPost.likeCount ?? 0,
                commentCount: commentCount,
                isLikedByCurrentUser: updatedPost.isLikedByCurrentUser ?? false
            )
            posts[index] = updatedPost
        }
    }
}

class CommentsViewModel: ObservableObject {
    @Published var comments: [PostComment] = []
    
    func fetchComments(postId: String) {
        Task {
            do {
                let fetchedComments = try await SocialService.shared.getPostComments(postId: postId)
                await MainActor.run {
                    self.comments = fetchedComments
                }
            } catch {
                print("Error fetching comments: \(error)")
            }
        }
    }
    
    func fetchCommentsAsync(postId: String) async {
        do {
            let fetchedComments = try await SocialService.shared.getPostComments(postId: postId)
            await MainActor.run {
                self.comments = fetchedComments
            }
        } catch {
            print("Error fetching comments: \(error)")
        }
    }
}

#Preview {
    SocialView()
        .environmentObject(AuthViewModel())
}
