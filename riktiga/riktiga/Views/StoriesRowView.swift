import SwiftUI

// MARK: - Stories Row View (Instagram-style)
struct StoriesRowView: View {
    let userStories: [UserStories]
    let currentUserId: String
    let myStories: [Story]
    let onStoryTap: (UserStories, Int) -> Void
    let onAddStoryTap: () -> Void
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 16) {
                // My story (add new or view existing)
                MyStoryCircle(
                    myStories: myStories,
                    onTap: {
                        if myStories.isEmpty {
                            onAddStoryTap()
                        } else {
                            // View own stories
                            let myUserStories = UserStories(
                                id: currentUserId,
                                userId: currentUserId,
                                username: "Din händelse",
                                avatarUrl: nil, // Will be loaded from profile
                                isProMember: false,
                                stories: myStories,
                                hasUnviewedStories: false
                            )
                            onStoryTap(myUserStories, 0)
                        }
                    }
                )
                
                // Friends' stories
                ForEach(userStories) { userStory in
                    StoryCircle(
                        userStory: userStory,
                        onTap: {
                            onStoryTap(userStory, 0)
                        }
                    )
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
        .background(Color.white)
    }
}

// MARK: - My Story Circle
struct MyStoryCircle: View {
    let myStories: [Story]
    let onTap: () -> Void
    
    @EnvironmentObject var authViewModel: AuthViewModel
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 8) {
                ZStack(alignment: .bottomTrailing) {
                    // Profile image with gradient ring if has stories
                    ZStack {
                        if myStories.isEmpty {
                            // No stories - show dashed circle
                            Circle()
                                .stroke(style: StrokeStyle(lineWidth: 2, dash: [4, 3]))
                                .foregroundColor(Color.gray.opacity(0.3))
                                .frame(width: 80, height: 80)
                        } else {
                            // Has stories - show gradient ring (white, black, gray)
                            Circle()
                                .stroke(
                                    LinearGradient(
                                        colors: [
                                            Color.white,
                                            Color.black,
                                            Color.gray
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 3
                                )
                                .frame(width: 80, height: 80)
                        }
                        
                        // Profile image
                        if let avatarUrl = authViewModel.currentUser?.avatarUrl,
                           !avatarUrl.isEmpty,
                           let url = URL(string: avatarUrl) {
                            AsyncImage(url: url) { image in
                                image
                                    .resizable()
                                    .scaledToFill()
                            } placeholder: {
                                Circle()
                                    .fill(Color.gray.opacity(0.2))
                            }
                            .frame(width: 72, height: 72)
                            .clipShape(Circle())
                        } else {
                            Circle()
                                .fill(Color.gray.opacity(0.15))
                                .frame(width: 72, height: 72)
                                .overlay(
                                    Image(systemName: "person.fill")
                                        .font(.system(size: 28))
                                        .foregroundColor(.gray)
                                )
                        }
                    }
                    
                    // Add button (only if no stories)
                    if myStories.isEmpty {
                        Circle()
                            .fill(Color.black)
                            .frame(width: 24, height: 24)
                            .overlay(
                                Image(systemName: "plus")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundColor(.white)
                            )
                            .overlay(
                                Circle()
                                    .stroke(Color.white, lineWidth: 2)
                            )
                            .offset(x: 2, y: 2)
                    }
                }
                
                Text("Din händelse")
                    .font(.system(size: 12))
                    .foregroundColor(.black)
                    .lineLimit(1)
                    .frame(width: 82)
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Story Circle (Friend's Story)
struct StoryCircle: View {
    let userStory: UserStories
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 8) {
                ZStack {
                    // Gradient ring - white/black/gray if unviewed, light gray if viewed
                    Circle()
                        .stroke(
                            userStory.hasUnviewedStories ?
                            LinearGradient(
                                colors: [
                                    Color.white,
                                    Color.black,
                                    Color.gray
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ) :
                            LinearGradient(
                                colors: [Color.gray.opacity(0.3), Color.gray.opacity(0.3)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 3
                        )
                        .frame(width: 80, height: 80)
                    
                    // Profile image
                    if let avatarUrl = userStory.avatarUrl,
                       !avatarUrl.isEmpty,
                       let url = URL(string: avatarUrl) {
                        AsyncImage(url: url) { image in
                            image
                                .resizable()
                                .scaledToFill()
                        } placeholder: {
                            Circle()
                                .fill(Color.gray.opacity(0.2))
                        }
                        .frame(width: 72, height: 72)
                        .clipShape(Circle())
                    } else {
                        Circle()
                            .fill(Color.gray.opacity(0.15))
                            .frame(width: 72, height: 72)
                            .overlay(
                                Text(String(userStory.username.prefix(1)).uppercased())
                                    .font(.system(size: 26, weight: .semibold))
                                    .foregroundColor(.gray)
                            )
                    }
                }
                
                Text(userStory.username)
                    .font(.system(size: 12))
                    .foregroundColor(.black)
                    .lineLimit(1)
                    .frame(width: 82)
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Story Viewer Overlay
struct StoryViewerOverlay: View {
    let userStories: UserStories
    @State private var currentIndex: Int = 0
    @State private var progress: CGFloat = 0
    @State private var timer: Timer?
    @State private var imageLoaded: Bool = false
    @State private var hasStarted: Bool = false
    @State private var preloadedImages: [Int: Image] = [:] // Cache for preloaded images
    @State private var storyViewers: [StoryViewer] = []
    @State private var viewerCount: Int = 0
    @State private var showViewersList = false
    @State private var showDeleteConfirmation = false
    @State private var isLiked = false
    @Environment(\.dismiss) private var dismiss
    
    let currentUserId: String
    let onStoryViewed: (String) -> Void
    let onDismiss: () -> Void
    
    private let storyDuration: Double = 5.0
    
    private var isOwnStory: Bool {
        userStories.userId.lowercased() == currentUserId.lowercased()
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background
                Color.black.ignoresSafeArea()
                
                // Story image
                if userStories.stories.isEmpty {
                    // No stories - show message and close
                    VStack(spacing: 16) {
                        Text("Inga stories")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                        
                        Button("Stäng") {
                            closeViewer()
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(Color.white.opacity(0.2))
                        .cornerRadius(20)
                    }
                    .onAppear {
                        print("📖 StoryViewer: No stories to show")
                    }
                } else if currentIndex < userStories.stories.count {
                    let story = userStories.stories[currentIndex]
                    
                    VStack(spacing: 0) {
                        // Safe area spacer for iOS status bar
                        Color.clear
                            .frame(height: 60) // Fixed height for status bar area
                        
                        // Progress bars
                        HStack(spacing: 4) {
                            ForEach(0..<userStories.stories.count, id: \.self) { index in
                                GeometryReader { geo in
                                    ZStack(alignment: .leading) {
                                        // Background
                                        Rectangle()
                                            .fill(Color.white.opacity(0.3))
                                        
                                        // Progress
                                        Rectangle()
                                            .fill(Color.white)
                                            .frame(width: index < currentIndex ? geo.size.width : (index == currentIndex ? geo.size.width * progress : 0))
                                    }
                                }
                                .frame(height: 3)
                                .cornerRadius(1.5)
                            }
                        }
                        .padding(.horizontal, 12)
                        
                        // Header
                        HStack(spacing: 12) {
                            // Avatar
                            if let avatarUrl = userStories.avatarUrl,
                               let url = URL(string: avatarUrl) {
                                AsyncImage(url: url) { image in
                                    image
                                        .resizable()
                                        .scaledToFill()
                                } placeholder: {
                                    Circle()
                                        .fill(Color.white.opacity(0.3))
                                }
                                .frame(width: 40, height: 40)
                                .clipShape(Circle())
                            } else {
                                Circle()
                                    .fill(Color.white.opacity(0.3))
                                    .frame(width: 40, height: 40)
                                    .overlay(
                                        Text(String(userStories.username.prefix(1)).uppercased())
                                            .font(.system(size: 16, weight: .semibold))
                                            .foregroundColor(.white)
                                    )
                            }
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(userStories.username)
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(.white)
                                
                                Text(story.timeAgo)
                                    .font(.system(size: 13))
                                    .foregroundColor(.white.opacity(0.7))
                            }
                            
                            Spacer()
                            
                            // Close button
                            Button {
                                closeViewer()
                            } label: {
                                Image(systemName: "xmark")
                                    .font(.system(size: 20, weight: .semibold))
                                    .foregroundColor(.white)
                                    .frame(width: 44, height: 44)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                        
                        Spacer()
                        
                        // Story image (square aspect ratio) - optimized for fast loading
                        Group {
                            if let preloadedImage = preloadedImages[currentIndex] {
                                // Use preloaded image for instant display
                                preloadedImage
                                    .resizable()
                                    .scaledToFit()
                                    .frame(maxWidth: geometry.size.width)
                                    .cornerRadius(12)
                                    .onAppear {
                                        if !imageLoaded {
                                            imageLoaded = true
                                            startTimerIfNeeded()
                                        }
                                    }
                            } else {
                                // Load image
                                AsyncImage(url: URL(string: story.imageUrl)) { phase in
                                    switch phase {
                                    case .success(let image):
                                        image
                                            .resizable()
                                            .scaledToFit()
                                            .frame(maxWidth: geometry.size.width)
                                            .cornerRadius(12)
                                            .onAppear {
                                                // Cache this image
                                                preloadedImages[currentIndex] = image
                                                if !imageLoaded {
                                                    imageLoaded = true
                                                    startTimerIfNeeded()
                                                }
                                                // Preload next image
                                                preloadNextImage()
                                            }
                                    case .failure(_):
                                        Rectangle()
                                            .fill(Color.gray.opacity(0.3))
                                            .frame(width: geometry.size.width, height: geometry.size.width)
                                            .overlay(
                                                VStack(spacing: 8) {
                                                    Image(systemName: "photo")
                                                        .font(.system(size: 40))
                                                        .foregroundColor(.white.opacity(0.5))
                                                    Text("Kunde inte ladda bild")
                                                        .font(.system(size: 14))
                                                        .foregroundColor(.white.opacity(0.5))
                                                }
                                            )
                                            .onAppear {
                                                imageLoaded = true
                                                startTimerIfNeeded()
                                            }
                                    case .empty:
                                        VStack(spacing: 16) {
                                            ProgressView()
                                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                                .scaleEffect(1.2)
                                            Text("Laddar...")
                                                .font(.system(size: 14))
                                                .foregroundColor(.white.opacity(0.7))
                                        }
                                        .frame(width: geometry.size.width, height: geometry.size.width * 0.8)
                                    @unknown default:
                                        EmptyView()
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 8)
                        .transition(.opacity.animation(.easeInOut(duration: 0.15)))
                        
                        Spacer()
                        
                        // Bottom navbar
                        storyBottomNavbar
                            .padding(.bottom, 30)
                    }
                    
                    // Tap zones for navigation
                    HStack(spacing: 0) {
                        // Left - previous
                        Rectangle()
                            .fill(Color.clear)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                goToPrevious()
                            }
                        
                        // Right - next
                        Rectangle()
                            .fill(Color.clear)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                goToNext()
                            }
                    }
                }
            }
        }
        .onAppear {
            print("📖 StoryViewer opened - User: \(userStories.username), Stories count: \(userStories.stories.count)")
            if !userStories.stories.isEmpty {
                print("📖 First story URL: \(userStories.stories[0].imageUrl)")
                // Preload all images immediately for instant transitions
                preloadAllImages()
                // Load viewers if own story
                if isOwnStory {
                    loadViewers()
                }
            }
            markCurrentAsViewed()
        }
        .sheet(isPresented: $showViewersList) {
            StoryViewersListView(viewers: storyViewers, viewerCount: viewerCount)
                .presentationDetents([.medium, .large])
        }
        .alert("Radera story?", isPresented: $showDeleteConfirmation) {
            Button("Avbryt", role: .cancel) { }
            Button("Radera", role: .destructive) {
                deleteCurrentStory()
            }
        } message: {
            Text("Denna story kommer att tas bort permanent.")
        }
        .onDisappear {
            stopTimer()
            hasStarted = false
        }
        .gesture(
            DragGesture(minimumDistance: 50)
                .onEnded { value in
                    if value.translation.height > 100 {
                        closeViewer()
                    }
                }
        )
    }
    
    // MARK: - Bottom Navbar
    private var storyBottomNavbar: some View {
        HStack(spacing: 16) {
            if isOwnStory {
                // Own story - show viewers activity
                Button {
                    stopTimer()
                    showViewersList = true
                } label: {
                    HStack(spacing: 8) {
                        // Viewer avatars (max 3)
                        HStack(spacing: -8) {
                            ForEach(storyViewers.prefix(3)) { viewer in
                                if let avatarUrl = viewer.avatarUrl, let url = URL(string: avatarUrl) {
                                    AsyncImage(url: url) { image in
                                        image
                                            .resizable()
                                            .scaledToFill()
                                    } placeholder: {
                                        Circle().fill(Color.gray.opacity(0.3))
                                    }
                                    .frame(width: 28, height: 28)
                                    .clipShape(Circle())
                                    .overlay(Circle().stroke(Color.black, lineWidth: 2))
                                } else {
                                    Circle()
                                        .fill(Color.gray.opacity(0.5))
                                        .frame(width: 28, height: 28)
                                        .overlay(
                                            Text(String(viewer.username.prefix(1)).uppercased())
                                                .font(.system(size: 12, weight: .semibold))
                                                .foregroundColor(.white)
                                        )
                                        .overlay(Circle().stroke(Color.black, lineWidth: 2))
                                }
                            }
                        }
                        
                        // Viewer icon and count
                        Image(systemName: "person.2.fill")
                            .font(.system(size: 16))
                            .foregroundColor(.white)
                        
                        Text("\(viewerCount)")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color.white.opacity(0.15))
                    .cornerRadius(24)
                }
                
                Spacer()
                
                // Delete button (three dots)
                Button {
                    stopTimer()
                    showDeleteConfirmation = true
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 44, height: 44)
                        .background(Color.white.opacity(0.15))
                        .clipShape(Circle())
                }
            } else {
                // Other's story - show like button
                Spacer()
                
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                        isLiked.toggle()
                    }
                    // Haptic feedback
                    let generator = UIImpactFeedbackGenerator(style: .medium)
                    generator.impactOccurred()
                } label: {
                    Image(systemName: isLiked ? "heart.fill" : "heart")
                        .font(.system(size: 28))
                        .foregroundColor(isLiked ? .red : .white)
                        .scaleEffect(isLiked ? 1.1 : 1.0)
                }
                .frame(width: 56, height: 56)
                .background(Color.white.opacity(0.15))
                .clipShape(Circle())
                
                Spacer()
            }
        }
        .padding(.horizontal, 20)
    }
    
    // MARK: - Load Viewers
    private func loadViewers() {
        Task {
            do {
                let storyIds = userStories.stories.map { $0.id }
                async let viewersTask = StoryService.shared.getAllViewersForStories(storyIds: storyIds)
                async let countTask = StoryService.shared.getViewCount(storyIds: storyIds)
                
                let (viewers, count) = try await (viewersTask, countTask)
                
                await MainActor.run {
                    self.storyViewers = viewers
                    self.viewerCount = count
                }
            } catch {
                print("❌ Error loading viewers: \(error)")
            }
        }
    }
    
    // MARK: - Delete Story
    private func deleteCurrentStory() {
        guard currentIndex < userStories.stories.count else { return }
        let story = userStories.stories[currentIndex]
        
        Task {
            do {
                try await StoryService.shared.deleteStory(storyId: story.id)
                await MainActor.run {
                    // If last story, close viewer
                    if userStories.stories.count <= 1 {
                        closeViewer()
                    } else {
                        // Go to next story or previous if at end
                        if currentIndex >= userStories.stories.count - 1 {
                            goToPrevious()
                        } else {
                            // Force refresh - close for now
                            closeViewer()
                        }
                    }
                    // Notify to refresh stories
                    NotificationCenter.default.post(name: NSNotification.Name("RefreshStories"), object: nil)
                }
            } catch {
                print("❌ Error deleting story: \(error)")
            }
        }
    }
    
    private func startTimerIfNeeded() {
        guard !hasStarted else { return }
        hasStarted = true
        startTimer()
    }
    
    private func startTimer() {
        progress = 0
        timer?.invalidate()
        
        let interval: Double = 0.03 // Smoother animation (was 0.05)
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { _ in
            withAnimation(.linear(duration: interval)) {
                progress += CGFloat(interval / storyDuration)
            }
            
            if progress >= 1 {
                goToNext()
            }
        }
    }
    
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
    
    /// Preload all story images for instant transitions
    private func preloadAllImages() {
        for (index, story) in userStories.stories.enumerated() {
            guard let url = URL(string: story.imageUrl) else { continue }
            
            Task {
                do {
                    let (data, _) = try await URLSession.shared.data(from: url)
                    if let uiImage = UIImage(data: data) {
                        await MainActor.run {
                            preloadedImages[index] = Image(uiImage: uiImage)
                            print("📖 Preloaded image \(index)")
                        }
                    }
                } catch {
                    print("❌ Failed to preload image \(index): \(error)")
                }
            }
        }
    }
    
    /// Preload just the next image
    private func preloadNextImage() {
        let nextIndex = currentIndex + 1
        guard nextIndex < userStories.stories.count,
              preloadedImages[nextIndex] == nil else { return }
        
        let story = userStories.stories[nextIndex]
        guard let url = URL(string: story.imageUrl) else { return }
        
        Task {
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                if let uiImage = UIImage(data: data) {
                    await MainActor.run {
                        preloadedImages[nextIndex] = Image(uiImage: uiImage)
                    }
                }
            } catch {
                print("❌ Failed to preload next image: \(error)")
            }
        }
    }
    
    private func goToNext() {
        if currentIndex < userStories.stories.count - 1 {
            withAnimation(.easeInOut(duration: 0.15)) {
                currentIndex += 1
            }
            progress = 0
            // If image is preloaded, continue immediately
            if preloadedImages[currentIndex] != nil {
                imageLoaded = true
            } else {
                imageLoaded = false
            }
            markCurrentAsViewed()
        } else {
            closeViewer()
        }
    }
    
    private func goToPrevious() {
        if currentIndex > 0 {
            withAnimation(.easeInOut(duration: 0.15)) {
                currentIndex -= 1
            }
            progress = 0
            // If image is preloaded, continue immediately
            if preloadedImages[currentIndex] != nil {
                imageLoaded = true
            } else {
                imageLoaded = false
            }
        }
    }
    
    private func closeViewer() {
        print("📖 Closing story viewer")
        stopTimer()
        imageLoaded = false
        dismiss()
        onDismiss()
    }
    
    private func markCurrentAsViewed() {
        guard currentIndex < userStories.stories.count else { return }
        let story = userStories.stories[currentIndex]
        
        // Only mark as viewed if it's not our own story
        if story.userId != currentUserId {
            onStoryViewed(story.id)
        }
    }
}

// MARK: - Post to Story Popup
struct PostToStoryPopup: View {
    @Binding var isPresented: Bool
    let image: UIImage
    let onConfirm: () -> Void
    let onCancel: () -> Void
    
    @State private var isPosting = false
    
    var body: some View {
        ZStack {
            // Dimmed background
            Color.black.opacity(0.5)
                .ignoresSafeArea()
                .onTapGesture {
                    if !isPosting {
                        onCancel()
                    }
                }
            
            // Popup card
            VStack(spacing: 20) {
                // Preview image
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(height: 200)
                    .cornerRadius(16)
                
                // Title
                Text("Dela till din story?")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.black)
                
                Text("Din bild kommer vara synlig för dina följare i 24 timmar")
                    .font(.system(size: 14))
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                // Buttons
                HStack(spacing: 12) {
                    Button {
                        onCancel()
                    } label: {
                        Text("Nej tack")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.gray.opacity(0.15))
                            .cornerRadius(25)
                    }
                    .disabled(isPosting)
                    
                    Button {
                        isPosting = true
                        onConfirm()
                    } label: {
                        HStack(spacing: 8) {
                            if isPosting {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.8)
                            }
                            Text(isPosting ? "Postar..." : "Dela")
                                .font(.system(size: 16, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.98, green: 0.35, blue: 0.13),
                                    Color(red: 0.89, green: 0.22, blue: 0.42)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(25)
                    }
                    .disabled(isPosting)
                }
            }
            .padding(24)
            .background(Color.white)
            .cornerRadius(24)
            .shadow(color: Color.black.opacity(0.2), radius: 20, x: 0, y: 10)
            .padding(.horizontal, 32)
        }
    }
}

// MARK: - Story Viewers List View
struct StoryViewersListView: View {
    let viewers: [StoryViewer]
    let viewerCount: Int
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header
                HStack {
                    Image(systemName: "person.2.fill")
                        .font(.system(size: 18))
                        .foregroundColor(.black)
                    
                    Text("\(viewerCount)")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.black)
                    
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .background(Color(.systemGray6))
                
                if viewers.isEmpty {
                    Spacer()
                    VStack(spacing: 16) {
                        Image(systemName: "eye.slash")
                            .font(.system(size: 48))
                            .foregroundColor(.gray)
                        Text("Ingen har sett din story än")
                            .font(.headline)
                            .foregroundColor(.gray)
                    }
                    Spacer()
                } else {
                    // Viewers list header
                    HStack {
                        Text("Vem som har sett händelsen")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.black)
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    .padding(.bottom, 12)
                    
                    // Viewers list
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(viewers) { viewer in
                                HStack(spacing: 12) {
                                    // Avatar
                                    if let avatarUrl = viewer.avatarUrl, let url = URL(string: avatarUrl) {
                                        AsyncImage(url: url) { image in
                                            image
                                                .resizable()
                                                .scaledToFill()
                                        } placeholder: {
                                            Circle().fill(Color.gray.opacity(0.3))
                                        }
                                        .frame(width: 50, height: 50)
                                        .clipShape(Circle())
                                    } else {
                                        Circle()
                                            .fill(Color.gray.opacity(0.3))
                                            .frame(width: 50, height: 50)
                                            .overlay(
                                                Text(String(viewer.username.prefix(1)).uppercased())
                                                    .font(.system(size: 18, weight: .semibold))
                                                    .foregroundColor(.gray)
                                            )
                                    }
                                    
                                    // Username
                                    Text(viewer.username)
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(.black)
                                    
                                    Spacer()
                                    
                                    // Options button
                                    Button {
                                        // Could add options like block, message etc.
                                    } label: {
                                        Image(systemName: "ellipsis")
                                            .font(.system(size: 18))
                                            .foregroundColor(.gray)
                                    }
                                    
                                    // Reply button
                                    Button {
                                        // Could add reply functionality
                                    } label: {
                                        Image(systemName: "arrowshape.turn.up.left")
                                            .font(.system(size: 18))
                                            .foregroundColor(.gray)
                                    }
                                }
                                .padding(.horizontal, 20)
                                .padding(.vertical, 12)
                                
                                Divider()
                                    .padding(.leading, 82)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Aktivitet")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.black)
                    }
                }
            }
        }
    }
}

#Preview {
    StoriesRowView(
        userStories: [],
        currentUserId: "test",
        myStories: [],
        onStoryTap: { _, _ in },
        onAddStoryTap: {}
    )
}

