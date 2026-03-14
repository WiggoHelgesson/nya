import SwiftUI

enum HomeTab: String, CaseIterable {
    case hem = "Hem"
    case hittaTranare = "Hitta tränare"

    var displayName: String {
        switch self {
        case .hem: return L.t(sv: "Hem", nb: "Hjem")
        case .hittaTranare: return L.t(sv: "Hitta tränare", nb: "Finn trener")
        }
    }
}

struct SocialContainerView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @ObservedObject private var notificationNav = NotificationNavigationManager.shared
    let popToRootTrigger: Int
    @State private var selectedTab: HomeTab = .hem
    @State private var showFindFriends = false
    @State private var unreadNotifications = 0
    @State private var isFetchingUnread = false
    @State private var unreadMessages = 0
    @State private var dmNavigationPath = NavigationPath()
    @State private var lastUnreadFetch: Date = .distantPast
    @StateObject private var dmService = DirectMessageService.shared
    
    private let fetchThrottleInterval: TimeInterval = 30
    
    @State private var showEditProfile = false
    
    private var isPremium: Bool {
        authViewModel.currentUser?.isProMember ?? false
    }
    
    private var profileCompletedSteps: Int {
        guard let user = authViewModel.currentUser else { return 0 }
        var count = 0
        if !user.pinnedPostIds.isEmpty { count += 1 }
        if let bio = user.bio, !bio.isEmpty { count += 1 }
        if !user.gymPbs.isEmpty || user.pb5kmMinutes != nil || user.pb10kmMinutes != nil || user.pbMarathonMinutes != nil { count += 1 }
        if !user.completedRaces.isEmpty { count += 1 }
        if let gym = user.homeGym, !gym.isEmpty { count += 1 }
        if let goal = user.trainingGoal, !goal.isEmpty { count += 1 }
        if let identity = user.trainingIdentity, !identity.isEmpty { count += 1 }
        return min(count, 3)
    }
    
    var body: some View {
        NavigationStack(path: $dmNavigationPath) {
            VStack(spacing: 0) {
                // MARK: - Header (samma som Rewards)
                VStack(spacing: 0) {
                    ZStack {
                        // Center: Page title
                        Text(L.t(sv: "Socialt", nb: "Sosialt"))
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.primary)
                        
                        // Left and Right sides
                        HStack {
                            // Left: Profile picture + Search
                            HStack(spacing: 10) {
                                NavigationLink(destination: UserProfileView(userId: authViewModel.currentUser?.id ?? "").environmentObject(authViewModel)) {
                                    ProfileImage(url: authViewModel.currentUser?.avatarUrl, size: 36, isPro: authViewModel.currentUser?.isProMember ?? false)
                                        .overlay(
                                            Circle()
                                                .stroke(Color.black.opacity(0.1), lineWidth: 1)
                                        )
                                }
                                .buttonStyle(.plain)
                                
                                NavigationLink(destination: FindFriendsView().environmentObject(authViewModel)) {
                                    Image(systemName: "magnifyingglass")
                                        .font(.system(size: 20, weight: .regular))
                                        .foregroundColor(.primary)
                                        .frame(width: 32, height: 32)
                                        .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                            }
                            
                            Spacer()
                            
                            // Right: Messages + Notifications
                            HStack(spacing: 12) {
                                // Direct messages
                                NavigationLink(destination: MessagesListView().environmentObject(authViewModel)) {
                                    ZStack(alignment: .topTrailing) {
                                        Image(systemName: "bubble.left.and.bubble.right")
                                            .font(.system(size: 20, weight: .regular))
                                            .foregroundColor(.primary)
                                        
                                        if unreadMessages > 0 {
                                            Circle()
                                                .fill(Color.black)
                                                .frame(width: 18, height: 18)
                                                .overlay(
                                                    Text("\(min(unreadMessages, 99))")
                                                        .font(.system(size: 10, weight: .bold))
                                                        .foregroundColor(.white)
                                                )
                                                .offset(x: 8, y: -6)
                                        }
                                    }
                                    .frame(width: 36, height: 36)
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                
                                // Notification bell
                                NavigationLink(destination: NotificationsView(onDismiss: {
                                    Task { await refreshUnreadCount() }
                                }).environmentObject(authViewModel)) {
                                    ZStack(alignment: .topTrailing) {
                                        Image(systemName: "bell")
                                            .font(.system(size: 22, weight: .regular))
                                            .foregroundColor(.primary)
                                        
                                        if unreadNotifications > 0 {
                                            Circle()
                                                .fill(Color.black)
                                                .frame(width: 18, height: 18)
                                                .overlay(
                                                    Text("\(min(unreadNotifications, 99))")
                                                        .font(.system(size: 10, weight: .bold))
                                                        .foregroundColor(.white)
                                                )
                                                .offset(x: 8, y: -6)
                                        }
                                    }
                                    .frame(width: 36, height: 36)
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 16)
                    
                    // Bottom separator
                    Rectangle()
                        .fill(Color.primary)
                        .frame(height: 0.5)
                        .opacity(0.1)
                }
                .background(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.15), radius: 8, x: 0, y: 4)
                .zIndex(2)
                
                if profileCompletedSteps < 3 {
                    Button {
                        showEditProfile = true
                    } label: {
                        HStack {
                            Text(L.t(
                                sv: "Sätt upp din publika profil \(profileCompletedSteps)/3",
                                nb: "Sett opp din offentlige profil \(profileCompletedSteps)/3"
                            ))
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.white)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(Color.black)
                    }
                    .buttonStyle(.plain)
                }
                
                SocialView()
                    .environmentObject(authViewModel)
            }
            .navigationBarHidden(true)
            .navigationDestination(for: String.self) { conversationId in
                DMNavigationWrapper(conversationId: conversationId)
                    .environmentObject(authViewModel)
            }
        }
        .id(popToRootTrigger)
        .sheet(isPresented: $showEditProfile) {
            NavigationStack {
                EditProfileView()
                    .environmentObject(authViewModel)
            }
        }
        .task {
            await throttledRefresh()
        }
        .onChange(of: popToRootTrigger) { _, _ in
            dmNavigationPath = NavigationPath()
            selectedTab = .hem
            NotificationCenter.default.post(name: NSNotification.Name("PopToRootHem"), object: nil)
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("RefreshUnreadMessages"))) { _ in
            Task { await refreshUnreadMessages() }
        }
        .onChange(of: notificationNav.shouldNavigateToDirectMessage) { _, conversationId in
            if let conversationId = conversationId {
                dmNavigationPath = NavigationPath()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    dmNavigationPath.append(conversationId)
                }
                notificationNav.shouldNavigateToDirectMessage = nil
            }
        }
    }
    
    private func throttledRefresh() async {
        guard Date().timeIntervalSince(lastUnreadFetch) >= fetchThrottleInterval else { return }
        lastUnreadFetch = Date()
        await refreshUnreadCount()
        await refreshUnreadMessages()
    }
    
    private func refreshUnreadCount() async {
        guard !isFetchingUnread else { return }
        guard let userId = authViewModel.currentUser?.id else {
            await MainActor.run { unreadNotifications = 0 }
            return
        }
        isFetchingUnread = true
        do {
            let count = try await NotificationService.shared.fetchUnreadCount(userId: userId)
            await MainActor.run {
                unreadNotifications = count
            }
        } catch {
            print("⚠️ Failed to fetch unread notifications: \(error)")
        }
        isFetchingUnread = false
    }
    
    private func refreshUnreadMessages() async {
        await dmService.fetchTotalUnreadCount()
        await MainActor.run {
            unreadMessages = dmService.totalUnreadCount
        }
    }
}

// MARK: - DM Navigation Wrapper (loads conversation data from ID)
struct DMNavigationWrapper: View {
    let conversationId: String
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var conversation: DirectConversation? = nil
    @State private var isLoading = true
    
    var body: some View {
        Group {
            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let conv = conversation {
                DirectMessageView(
                    conversationId: conv.id,
                    otherUserId: conv.otherUserId ?? "",
                    otherUsername: conv.displayName,
                    otherAvatarUrl: conv.otherAvatarUrl,
                    isGroup: conv.isGroup ?? false,
                    memberCount: conv.memberCount ?? 2
                )
                .environmentObject(authViewModel)
            } else {
                // Fallback: open with just the ID
                if let uuid = UUID(uuidString: conversationId) {
                    DirectMessageView(
                        conversationId: uuid,
                        otherUserId: "",
                        otherUsername: L.t(sv: "Chatt", nb: "Chat"),
                        otherAvatarUrl: nil
                    )
                    .environmentObject(authViewModel)
                } else {
                    Text(L.t(sv: "Kunde inte öppna konversationen", nb: "Kunne ikke åpne samtalen"))
                        .foregroundColor(.secondary)
                }
            }
        }
        .task {
            await loadConversation()
        }
    }
    
    private func loadConversation() async {
        guard let uuid = UUID(uuidString: conversationId) else {
            isLoading = false
            return
        }
        
        let service = DirectMessageService.shared
        
        // First try from already-loaded conversations
        if let existing = service.conversations.first(where: { $0.id == uuid }) {
            await MainActor.run {
                conversation = existing
                isLoading = false
            }
            return
        }
        
        // Otherwise fetch fresh conversations
        do {
            let conversations = try await service.fetchConversations()
            if let found = conversations.first(where: { $0.id == uuid }) {
                await MainActor.run {
                    conversation = found
                    isLoading = false
                }
                return
            }
        } catch {
            print("⚠️ Failed to fetch conversations for navigation: \(error)")
        }
        
        await MainActor.run {
            isLoading = false
        }
    }
}

#Preview {
    SocialContainerView(popToRootTrigger: 0)
        .environmentObject(AuthViewModel())
}
