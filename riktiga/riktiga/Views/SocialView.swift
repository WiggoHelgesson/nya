import SwiftUI
import Combine

struct SocialView: View {
    @StateObject private var socialViewModel = SocialViewModel()
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var visiblePostCount = 5 // Start with 5 posts
    @State private var isLoadingMore = false
    @State private var task: Task<Void, Never>?
    @State private var selectedPost: SocialWorkoutPost?
    
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
                        VStack(alignment: .leading, spacing: 0) {
                            HomeHeaderView()
                                .padding(.horizontal, 16)
                                .padding(.bottom, 16)
                            
                            LazyVStack(spacing: 0) {
                                ForEach(postsToDisplay) { post in
                                    VStack(spacing: 0) {
                                        SocialPostCard(
                                            post: post,
                                            onOpenDetail: { tappedPost in selectedPost = tappedPost },
                                            viewModel: socialViewModel
                                        )
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
                    }
                }
            }
            .navigationTitle("")
            .navigationBarHidden(true)
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
            .enableSwipeBack()
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
    
    private var postsToDisplay: [SocialWorkoutPost] {
        Array(socialViewModel.posts.prefix(visiblePostCount))
    }
}

struct SocialPostCard: View {
    let post: SocialWorkoutPost
    let onOpenDetail: (SocialWorkoutPost) -> Void
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
    @EnvironmentObject var authViewModel: AuthViewModel
    @ObservedObject var viewModel: SocialViewModel
    
    init(post: SocialWorkoutPost, onOpenDetail: @escaping (SocialWorkoutPost) -> Void, viewModel: SocialViewModel) {
        self.post = post
        self.onOpenDetail = onOpenDetail
        self.viewModel = viewModel
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
        .background(Color.white)
        .onAppear {
            Task {
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
        .sheet(isPresented: $showLikesList) {
            LikesListView(postId: post.id)
                .environmentObject(authViewModel)
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
                                .foregroundColor(.black)
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
                        .foregroundColor(.black)
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
            
            if let description = trimmedDescription {
                Text(description)
                    .font(.system(size: 14))
                    .foregroundColor(.gray)
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
                .foregroundColor(.black)
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
                            .foregroundColor(.black)
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
                    parentCommentId: replyTarget?.id
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
    @Published var posts: [SocialWorkoutPost] = []
    @Published var isLoading: Bool = false
    private var isFetching = false
    private var currentUserId: String?
    private var hasLoggedFetchCancelled = false
    
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
        // Prevent duplicate fetches
        if isFetching { return }
        
        isFetching = true
        isLoading = true
        
        // Try to load from cache first (ensure stable order); keep loading state until network finishes
        if let cachedPosts = AppCacheManager.shared.getCachedSocialFeed(userId: userId, allowExpired: true) {
            posts = sortedByDateDesc(cachedPosts)
            Task { await self.enrichAuthorMetadataIfNeeded() }
        }
        
        do {
            let fetchedPosts = try await SocialService.shared.getReliableSocialFeed(userId: userId)
            
            // Debug: Show all posts with their exercises status
            print("📋 Fetched posts:")
            for post in fetchedPosts {
                print("  - \(post.id): \(post.activityType) | exercises: \(post.exercises?.count ?? 0)")
            }
            
            posts = sortedByDateDesc(fetchedPosts)
            isLoading = false
            isFetching = false
            
            // Debug: Show posts after assignment
            print("✨ Posts in ViewModel after assignment:")
            for post in posts {
                print("  - \(post.id): \(post.activityType) | exercises: \(post.exercises?.count ?? 0)")
            }
            
            // Persist to cache for offline use (sorted to keep order consistent)
            AppCacheManager.shared.saveSocialFeed(posts, userId: userId)
            Task { await self.enrichAuthorMetadataIfNeeded() }
        } catch is CancellationError {
            if !hasLoggedFetchCancelled {
                print("⚠️ Fetch was cancelled")
                hasLoggedFetchCancelled = true
            }
            
            if posts.isEmpty,
               let cached = AppCacheManager.shared.getCachedSocialFeed(userId: userId, allowExpired: true) {
                posts = sortedByDateDesc(cached)
            }
            isLoading = false
            isFetching = false
        } catch {
            print("Error fetching social feed: \(error)")
            isLoading = false
            isFetching = false
        }
    }
    
    func refreshSocialFeed(userId: String) async {
        do {
            // Use retry helper for better network resilience
            let fetchedPosts = try await RetryHelper.shared.retry(maxRetries: 3, delay: 0.5) {
                return try await SocialService.shared.getReliableSocialFeed(userId: userId)
            }
            
            // Only update posts if we got new data, don't replace with empty array
            if !fetchedPosts.isEmpty {
                let sorted = sortedByDateDesc(fetchedPosts)
                posts = sorted
                AppCacheManager.shared.saveSocialFeed(sorted, userId: userId)
                Task { await self.enrichAuthorMetadataIfNeeded() }
            } else {
                print("⚠️ Refresh returned empty array, keeping existing posts")
            }
        } catch is CancellationError {
            // Cancelled refresh - don't update posts or log as error
            print("⚠️ Refresh was cancelled")
        } catch {
            print("❌ Error refreshing social feed after retries: \(error)")
            if let cached = AppCacheManager.shared.getCachedSocialFeed(userId: userId, allowExpired: true),
               posts.isEmpty {
                posts = sortedByDateDesc(cached)
                Task { await self.enrichAuthorMetadataIfNeeded() }
            }
        }
    }

    func loadPostsForUser(userId targetUserId: String, viewerId: String) async {
        currentUserId = viewerId
        isLoading = true
        do {
            let posts = try await SocialService.shared.getPostsForUser(targetUserId: targetUserId, viewerId: viewerId)
            await MainActor.run {
                self.posts = posts
                self.isLoading = false
            }
        } catch is CancellationError {
            await MainActor.run { self.isLoading = false }
        } catch {
            print("❌ Error loading posts for user \(targetUserId): \(error)")
            await MainActor.run { self.isLoading = false }
        }
    }
    
    func refreshPostsForUser(userId targetUserId: String, viewerId: String) async {
        currentUserId = viewerId
        do {
            let posts = try await SocialService.shared.getPostsForUser(targetUserId: targetUserId, viewerId: viewerId)
            await MainActor.run {
                self.posts = posts
            }
        } catch {
            print("⚠️ Could not refresh posts for user \(targetUserId): \(error)")
        }
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
                exercises: post.exercises
            )
        }
        
        posts = sortedByDateDesc(posts)
        if let uid = currentUserId {
            AppCacheManager.shared.saveSocialFeed(posts, userId: uid)
        }
    }
    
    func updatePostLikeStatus(postId: String, isLiked: Bool, likeCount: Int) {
        if let index = posts.firstIndex(where: { $0.id == postId }) {
            var updatedPost = posts[index]
            // Only change like-related fields; keep all media fields intact
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
                exercises: updatedPost.exercises
            )
            posts[index] = updatedPost
            if let uid = currentUserId {
                AppCacheManager.shared.saveSocialFeed(posts, userId: uid)
            }
        }
    }
    
    func updatePostCommentCount(postId: String, commentCount: Int) {
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
                exercises: updatedPost.exercises
            )
            posts[index] = updatedPost
            if let uid = currentUserId {
                AppCacheManager.shared.saveSocialFeed(posts, userId: uid)
            }
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
                    .foregroundColor(.black)
                    .lineLimit(2)
                
                Text("\(exercise.sets) sets")
                    .font(.system(size: 13))
                    .foregroundColor(.gray)
                
                // Show all sets in a compact format
                ForEach(0..<exercise.sets, id: \.self) { setIndex in
                    if setIndex < exercise.kg.count && setIndex < exercise.reps.count {
                        HStack(spacing: 4) {
                            Text("\(setIndex + 1).")
                                .font(.system(size: 13))
                                .foregroundColor(.gray)
                                .frame(width: 20, alignment: .leading)
                            
                            Text("\(Int(exercise.kg[setIndex])) kg")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.black)
                            
                            Text("×")
                                .font(.system(size: 13))
                                .foregroundColor(.gray)
                            
                            Text("\(exercise.reps[setIndex]) reps")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.black)
                        }
                    }
                }
            }
            
            Spacer()
        }
        .padding(12)
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
    
    @ViewBuilder
    private var userImagePage: some View {
        if let userImage {
            LocalAsyncImage(path: userImage)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .overlay(
                    LinearGradient(
                        colors: [Color.black.opacity(0.2), Color.black.opacity(0.05)],
                        startPoint: .bottom,
                        endPoint: .top
                    )
                )
                .overlay(
                    Text("Din bild")
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

#Preview {
    SocialView()
        .environmentObject(AuthViewModel())
}
