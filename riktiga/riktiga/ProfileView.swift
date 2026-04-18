import SwiftUI
import Combine
import Supabase

// MARK: - ProfileActivitiesView (Activities tab content)
struct ProfileActivitiesView: View {
    var onPublicProfileTapped: (() -> Void)? = nil
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var showMyPurchases = false
    @State private var showMySubmissions = false
    @StateObject private var myPostsViewModel = SocialViewModel()
    @State private var selectedPost: SocialWorkoutPost?
    @State private var navigationPath = NavigationPath()
    @State private var showRoutines = false
    @State private var showSharedRoutines = false

    var body: some View {
        ZStack {
            Color.white
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 16) {
                    VStack(spacing: 16) {
                    // MARK: - Profile Menu
                    VStack(spacing: 8) {
                        ProfileMenuSectionHeader(title: L.t(sv: "Mina annonser & betalningar", nb: "Mine annonser og betalinger"))
                        VStack(spacing: 0) {
                            ProfileMenuRow(
                                icon: "shippingbox",
                                title: L.t(sv: "Mina inskickade produkter", nb: "Mine innsendte produkter")
                            ) {
                                showMySubmissions = true
                            }
                            Divider()
                            ProfileMenuRow(
                                icon: "cart",
                                title: L.t(sv: "Mina köp", nb: "Mine kjøp")
                            ) {
                                showMyPurchases = true
                            }
                        }
                        .background(Color(.systemBackground))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        
                        ProfileMenuSectionHeader(title: L.t(sv: "Gym", nb: "Gym"))
                            .padding(.top, 8)
                        VStack(spacing: 0) {
                            ProfileMenuRow(
                                icon: "figure.strengthtraining.traditional",
                                title: L.t(sv: "Gym rutiner", nb: "Gymrutiner")
                            ) {
                                showRoutines = true
                            }
                            Divider()
                            ProfileMenuRow(
                                icon: "paperplane",
                                title: L.t(sv: "Dela pass med vänner", nb: "Del økt med venner")
                            ) {
                                showSharedRoutines = true
                            }
                        }
                        .background(Color(.systemBackground))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    
                    // MARK: - Up&Down Live Gallery
                    UpAndDownLiveGallery(posts: myPostsViewModel.posts)
                    
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
            .sheet(isPresented: $showMyPurchases) {
                MyPurchasesView()
            }
            .sheet(isPresented: $showMySubmissions) {
                MyConsignmentSubmissionsView()
                    .environmentObject(authViewModel)
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
            .task {
                do {
                    try await AuthSessionManager.shared.ensureValidSession()
                } catch {
                    print("❌ Session invalid")
                }

                if let userId = authViewModel.currentUser?.id {
                    await myPostsViewModel.loadPostsForUser(userId: userId, viewerId: userId)
                    await prefetchPostImages()
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("NavigateToSharedWorkouts"))) { _ in
                showSharedRoutines = true
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("PopToRootProfil"))) { _ in
                navigationPath = NavigationPath()
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

// MARK: - Profile Menu Section Header
struct ProfileMenuSectionHeader: View {
    let title: String
    var body: some View {
        Text(title)
            .font(.system(size: 13, weight: .semibold))
            .foregroundColor(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 4)
            .padding(.top, 4)
    }
}

// MARK: - Profile Menu Row
struct ProfileMenuRow: View {
    let icon: String
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(.primary)
                    .frame(width: 28)
                Text(title)
                    .font(.system(size: 16))
                    .foregroundColor(.primary)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.gray)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
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
