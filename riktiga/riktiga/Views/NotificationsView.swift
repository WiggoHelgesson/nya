import SwiftUI

struct NotificationsView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    private let notificationService = NotificationService.shared
    @State private var isLoading = false
    @State private var notifications: [AppNotification] = []
    @State private var selectedNotification: AppNotification?
    @State private var selectedProfileId: String?
    @State private var selectedPostForComments: SocialWorkoutPost?
    @State private var errorMessage: String?
    @State private var hasMarkedAsRead = false
    var onDismiss: (() -> Void)? = nil
    
    var body: some View {
        ZStack {
            Color(UIColor.systemGroupedBackground)
                .ignoresSafeArea()
            
            if isLoading && notifications.isEmpty {
                // Skeleton loading for notifications
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(0..<6, id: \.self) { _ in
                            SkeletonNotificationRow()
                            Divider()
                                .padding(.leading, 72)
                        }
                    }
                }
                .scrollDisabled(true)
            } else if let error = errorMessage {
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 50))
                        .foregroundColor(.orange)
                    
                    Text("Kunde inte ladda notiser")
                        .font(.system(size: 18, weight: .bold))
                    
                    Text(error)
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    
                    Button("Försök igen") {
                        Task { await loadNotifications() }
                    }
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color.black)
                    .cornerRadius(20)
                }
            } else if notifications.isEmpty {
                emptyStateView
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(notifications) { notification in
                            NotificationRowStrava(notification: notification) {
                                handleNotificationTap(notification)
                            }
                            
                            Divider()
                                .padding(.leading, 76)
                        }
                    }
                    .background(Color(.systemBackground))
                }
            }
        }
        .navigationTitle("Notiser")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable {
            await loadNotifications()
        }
        .task {
            await loadNotifications()
            // Mark all as read when entering the page
            await markAllAsReadOnEntry()
        }
        .onAppear {
            NavigationDepthTracker.shared.setAtRoot(false)
        }
        .onDisappear {
            NavigationDepthTracker.shared.setAtRoot(true)
            onDismiss?()
        }
        .navigationDestination(isPresented: Binding(
            get: { selectedProfileId != nil },
            set: { if !$0 { selectedProfileId = nil } }
        )) {
            if let userId = selectedProfileId {
                UserProfileView(userId: userId)
            }
        }
        .navigationDestination(isPresented: Binding(
            get: { selectedPostForComments != nil },
            set: { if !$0 { selectedPostForComments = nil } }
        )) {
            if let post = selectedPostForComments {
                CommentsView(post: post, onCommentAdded: nil)
                    .environmentObject(authViewModel)
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "bell.slash")
                .font(.system(size: 50))
                .foregroundColor(.gray)
            
            Text("Inga notiser ännu")
                .font(.system(size: 18, weight: .bold))
            
            Text("När någon gillar, kommenterar eller följer dig kommer det att visas här.")
                .font(.system(size: 14))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
    }
    
    private func loadNotifications() async {
        guard let userId = authViewModel.currentUser?.id else { return }
        
        // Only show loading indicator on first load
        if notifications.isEmpty {
            await MainActor.run {
                isLoading = true
                errorMessage = nil
            }
        }
        
        do {
            let fetched = try await notificationService.fetchNotifications(userId: userId)
            
            // Prefetch all avatar images for faster loading
            let avatarUrls = fetched.compactMap { $0.actorAvatarUrl }.filter { !$0.isEmpty }
            ImageCacheManager.shared.prefetch(urls: avatarUrls)
            
            await MainActor.run {
                notifications = fetched
                isLoading = false
                errorMessage = nil
            }
        } catch let error as NSError {
            // Ignore cancelled errors (happens during pull-to-refresh)
            if error.code == NSURLErrorCancelled {
                print("⚠️ Notification fetch cancelled (normal during refresh)")
                return
            }
            
            print("❌ Error loading notifications: \(error)")
            await MainActor.run {
                isLoading = false
                // Only show error if we don't have any notifications yet
                if notifications.isEmpty {
                    errorMessage = error.localizedDescription
                }
            }
        } catch {
            print("❌ Error loading notifications: \(error)")
            await MainActor.run {
                isLoading = false
                if notifications.isEmpty {
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    private func markAllAsReadOnEntry() async {
        guard !hasMarkedAsRead else { return }
        guard let userId = authViewModel.currentUser?.id else { return }
        
        hasMarkedAsRead = true
        
        do {
            try await notificationService.markAllAsRead(userId: userId)
            await MainActor.run {
                notifications = notifications.map { item in
                    var updated = item
                    updated.isRead = true
                    return updated
                }
            }
        } catch {
            print("⚠️ Could not mark notifications as read: \(error)")
        }
    }
    
    private func handleNotificationTap(_ notification: AppNotification) {
        Task {
            // For comment, reply, and like notifications, navigate to the post's comments
            switch notification.type {
            case .comment, .reply, .like:
                if let postId = notification.postId, !postId.isEmpty {
                    do {
                        // Fetch the post
                        let post = try await SocialService.shared.getPost(postId: postId)
                        await MainActor.run {
                            selectedPostForComments = post
                        }
                    } catch {
                        print("❌ Error fetching post for notification: \(error)")
                        // Fallback to profile navigation
                        await MainActor.run {
                            if !notification.actorId.isEmpty {
                                selectedProfileId = notification.actorId
                            }
                        }
                    }
                } else {
                    // No post ID, go to profile
                    await MainActor.run {
                        if !notification.actorId.isEmpty {
                            selectedProfileId = notification.actorId
                        }
                    }
                }
                
            case .follow:
                // For follow notifications, go to the user's profile
                await MainActor.run {
                    if !notification.actorId.isEmpty {
                        selectedProfileId = notification.actorId
                    }
                }
                
            default:
                // Default: go to profile
                await MainActor.run {
                    if !notification.actorId.isEmpty {
                        selectedProfileId = notification.actorId
                    }
                }
            }
        }
    }
}

// MARK: - Strava-style Notification Row
struct NotificationRowStrava: View {
    let notification: AppNotification
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .top, spacing: 12) {
                // Profile picture (cached)
                ProfileImage(url: notification.actorAvatarUrl, size: 52)
                
                // Content
                VStack(alignment: .leading, spacing: 4) {
                    // Title (bold)
                    Text(notificationTitle)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    // Description
                    Text(notificationDescription)
                        .font(.system(size: 14))
                        .foregroundColor(.primary)
                        .lineLimit(2)
                    
                    // Timestamp
                    Text(formatDate(notification.createdAt))
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                        .padding(.top, 2)
                }
                
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(Color(.systemBackground))
        }
        .buttonStyle(.plain)
    }
    
    private var notificationTitle: String {
        switch notification.type {
        case .like:
            return "Ny gilla-markering"
        case .comment:
            return "Ny kommentar"
        case .follow:
            return "Ny följare"
        case .reply:
            return "Svar på din kommentar"
        case .newWorkout:
            return "Nytt träningspass"
        case .unknown:
            return "Notis"
        }
    }
    
    private var notificationDescription: String {
        let name = notification.actorUsername ?? "Någon"
        
        switch notification.type {
        case .like:
            return "\(name) gillade ditt inlägg"
        case .comment:
            if let text = notification.commentText, !text.isEmpty {
                return "\(name) kommenterade: \"\(text)\""
            }
            return "\(name) kommenterade på ditt inlägg"
        case .follow:
            return "\(name) började följa dig"
        case .reply:
            if let text = notification.commentText, !text.isEmpty {
                return "\(name) svarade: \"\(text)\""
            }
            return "\(name) svarade på din kommentar"
        case .newWorkout:
            return "\(name) har avslutat ett träningspass!"
        case .unknown:
            return "\(name) skickade en notis"
        }
    }
    
    private func formatDate(_ isoString: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        var date = formatter.date(from: isoString)
        if date == nil {
            formatter.formatOptions = [.withInternetDateTime]
            date = formatter.date(from: isoString)
        }
        
        guard let parsedDate = date else { return isoString }
        
        let now = Date()
        let diff = now.timeIntervalSince(parsedDate)
        
        // If today, show time
        let calendar = Calendar.current
        if calendar.isDateInToday(parsedDate) {
            let timeFormatter = DateFormatter()
            timeFormatter.dateFormat = "HH:mm"
            timeFormatter.locale = Locale(identifier: "sv_SE")
            return "Idag kl \(timeFormatter.string(from: parsedDate))"
        }
        
        // If yesterday
        if calendar.isDateInYesterday(parsedDate) {
            let timeFormatter = DateFormatter()
            timeFormatter.dateFormat = "HH:mm"
            timeFormatter.locale = Locale(identifier: "sv_SE")
            return "Igår kl \(timeFormatter.string(from: parsedDate))"
        }
        
        // If within last 7 days
        if diff < 604800 {
            let days = Int(diff / 86400)
            return "\(days) dagar sedan"
        }
        
        // Otherwise show full date
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "d MMM yyyy 'kl' HH:mm"
        dateFormatter.locale = Locale(identifier: "sv_SE")
        return dateFormatter.string(from: parsedDate)
    }
}

#Preview {
    NavigationStack {
        NotificationsView()
            .environmentObject(AuthViewModel())
    }
}
