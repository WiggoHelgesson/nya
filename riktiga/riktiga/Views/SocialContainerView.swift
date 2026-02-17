import SwiftUI

enum HomeTab: String, CaseIterable {
    case hem = "Hem"
    case hittaTranare = "Hitta tränare"
}

struct SocialContainerView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @ObservedObject private var notificationNav = NotificationNavigationManager.shared
    let popToRootTrigger: Int
    @State private var selectedTab: HomeTab = .hem
    @State private var showMonthlyPrize = false
    @State private var showNonProAlert = false
    @State private var showFindFriends = false
    @State private var showPublicProfile = false
    @State private var unreadNotifications = 0
    @State private var isFetchingUnread = false
    @State private var unreadMessages = 0
    @State private var dmNavigationPath = NavigationPath()
    @State private var lastUnreadFetch: Date = .distantPast
    @StateObject private var dmService = DirectMessageService.shared
    
    private let fetchThrottleInterval: TimeInterval = 30
    
    private var isPremium: Bool {
        authViewModel.currentUser?.isProMember ?? false
    }
    
    var body: some View {
        NavigationStack(path: $dmNavigationPath) {
            VStack(spacing: 0) {
                // MARK: - Header (samma som Rewards)
                VStack(spacing: 0) {
                    // Top Row: Profile pic | Månadens pris | Find friends + Bell
                    ZStack {
                        // Center: Månadens pris
                        Button {
                            if isPremium {
                                showMonthlyPrize = true
                            } else {
                                showNonProAlert = true
                            }
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "trophy.fill")
                                    .font(.system(size: 13, weight: .semibold))
                                Text("Månadens pris")
                                    .font(.system(size: 13, weight: .semibold))
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 9)
                            .background(Color.black)
                            .cornerRadius(20)
                        }
                        .buttonStyle(.plain)
                        
                        // Left and Right sides
                        HStack {
                            // Left: Profile picture + Search
                            HStack(spacing: 10) {
                                Button {
                                    showPublicProfile = true
                                } label: {
                                    ProfileImage(url: authViewModel.currentUser?.avatarUrl, size: 36)
                                        .overlay(
                                            Circle()
                                                .stroke(Color.black.opacity(0.1), lineWidth: 1)
                                        )
                                }
                                .buttonStyle(.plain)
                                
                                // Search / Find friends
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
                    
                    // MARK: - Tab Selector (Strava-style underline)
                    HStack(spacing: 0) {
                        ForEach(HomeTab.allCases, id: \.self) { tab in
                            Button {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    selectedTab = tab
                                }
                            } label: {
                                VStack(spacing: 10) {
                                    Text(tab.rawValue)
                                        .font(.system(size: 16, weight: selectedTab == tab ? .bold : .medium))
                                        .foregroundColor(selectedTab == tab ? .primary : .gray)
                                    
                                    // Black underline indicator
                                    Rectangle()
                                        .fill(selectedTab == tab ? Color.primary : Color.clear)
                                        .frame(height: 3)
                                }
                                .frame(maxWidth: .infinity)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .background(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.15), radius: 8, x: 0, y: 4)
                .zIndex(2)
                
                // Swipeable content
                TabView(selection: $selectedTab) {
                    SocialView()
                        .environmentObject(authViewModel)
                        .tag(HomeTab.hem)
                    
                    FindTrainerView()
                        .environmentObject(authViewModel)
                        .tag(HomeTab.hittaTranare)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
            }
            .navigationBarHidden(true)
            .navigationDestination(for: String.self) { conversationId in
                DMNavigationWrapper(conversationId: conversationId)
                    .environmentObject(authViewModel)
            }
        }
        .sheet(isPresented: $showMonthlyPrize) {
            MonthlyPrizeView()
                .environmentObject(authViewModel)
        }
        .sheet(isPresented: $showPublicProfile) {
            if let userId = authViewModel.currentUser?.id {
                NavigationStack {
                    UserProfileView(userId: userId)
                        .environmentObject(authViewModel)
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
        .alert("Enbart för pro medlemmar", isPresented: $showNonProAlert) {
            Button("Stäng", role: .cancel) { }
            Button("Bli Pro") {
                showNonProAlert = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    SuperwallService.shared.showPaywall()
                }
            }
        } message: {
            Text("Uppgradera till Pro för att delta i månadens tävling och vinna häftiga priser!")
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
                        otherUsername: "Chatt",
                        otherAvatarUrl: nil
                    )
                    .environmentObject(authViewModel)
                } else {
                    Text("Kunde inte öppna konversationen")
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
