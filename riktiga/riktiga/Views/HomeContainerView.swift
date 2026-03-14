import SwiftUI

struct HomeContainerView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    let popToRootTrigger: Int
    @State private var showAddMealView = false
    @State private var navigationPath = NavigationPath()
    
    var body: some View {
        NavigationStack(path: $navigationPath) {
            HomeView()
                .environmentObject(authViewModel)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar(.hidden, for: .navigationBar)
                .fullScreenCover(isPresented: $showAddMealView) {
                    AddMealView()
                }
                .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("OpenAddMealView"))) { _ in
                    showAddMealView = true
                }
        }
        .id(popToRootTrigger)
        .onChange(of: popToRootTrigger) { _, _ in
            navigationPath = NavigationPath()
            showAddMealView = false
        }
    }
}

// MARK: - Simple App Header (No Tabs - for Home page)
struct SimpleAppHeader: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    
    @State private var unreadNotifications = 0
    @State private var unreadMessages = 0
    @State private var isFetchingUnread = false
    @State private var showFindFriends = false
    @State private var lastUnreadFetch: Date = .distantPast
    @StateObject private var dmService = DirectMessageService.shared
    
    private let fetchThrottleInterval: TimeInterval = 30
    
    private var isPremium: Bool {
        authViewModel.currentUser?.isProMember ?? false
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // MARK: - Top Row (Profile, Title, Actions)
            ZStack {
                // Center: Page title
                Text(L.t(sv: "Hem", nb: "Hjem"))
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
        }
        .background(Color(.systemBackground))
        .shadow(color: Color.black.opacity(0.15), radius: 8, x: 0, y: 4)
        .task {
            await throttledRefresh()
        }
        .onAppear {
            Task { await throttledRefresh() }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("RefreshUnreadMessages"))) { _ in
            Task { await refreshUnreadMessages() }
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

// MARK: - Combined Header with Tabs (Strava-style)
struct CombinedHeaderWithTabs<Tab: RawRepresentable & CaseIterable & Hashable>: View where Tab.RawValue == String, Tab.AllCases: RandomAccessCollection {
    @EnvironmentObject var authViewModel: AuthViewModel
    @Binding var selectedTab: Tab
    var tabDisplayName: ((Tab) -> String)? = nil
    
    @State private var unreadNotifications = 0
    @State private var unreadMessages = 0
    @State private var isFetchingUnread = false
    @State private var lastUnreadFetch: Date = .distantPast
    @StateObject private var dmService = DirectMessageService.shared
    
    var isProfilePage: Bool = false
    var onSettingsTapped: (() -> Void)? = nil
    
    private let fetchThrottleInterval: TimeInterval = 30
    
    private var isPremium: Bool {
        authViewModel.currentUser?.isProMember ?? false
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // MARK: - Top Row (Profile, Title, Actions)
            ZStack {
                // Center: Page title
                Text(tabDisplayName?(selectedTab) ?? selectedTab.rawValue)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.primary)
                
                // Left and Right sides
                HStack {
                    if isProfilePage {
                        NavigationLink(destination: UserProfileView(userId: authViewModel.currentUser?.id ?? "").environmentObject(authViewModel)) {
                            ProfileImage(url: authViewModel.currentUser?.avatarUrl, size: 36, isPro: authViewModel.currentUser?.isProMember ?? false)
                                .overlay(
                                    Circle()
                                        .stroke(Color.black.opacity(0.1), lineWidth: 1)
                                )
                        }
                        .buttonStyle(.plain)
                    } else {
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
                    }
                    
                    Spacer()
                    
                    // Right side actions
                    if isProfilePage {
                        Button {
                            onSettingsTapped?()
                        } label: {
                            Image(systemName: "gearshape.fill")
                                .font(.system(size: 22, weight: .regular))
                                .foregroundColor(.primary)
                                .frame(width: 36, height: 36)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    } else {
                        // Messages + Notifications
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
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 16)
            
            // MARK: - Tab Selector (Strava-style) - Only show if more than 1 tab
            if Array(Tab.allCases).count > 1 {
                HStack(spacing: 0) {
                    ForEach(Array(Tab.allCases), id: \.self) { tab in
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                selectedTab = tab
                            }
                        } label: {
                            VStack(spacing: 10) {
                                Text(tabDisplayName?(tab) ?? tab.rawValue)
                                    .font(.system(size: 16, weight: selectedTab == tab ? .bold : .medium))
                                    .foregroundColor(selectedTab == tab ? .primary : .gray)
                                
                                // Black underline indicator (50% width)
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
                .padding(.bottom, 0)
            }
        }
        .background(Color(.systemBackground))
        .shadow(color: Color.black.opacity(0.15), radius: 8, x: 0, y: 4)
        .task {
            await throttledRefresh()
        }
        .onAppear {
            Task { await throttledRefresh() }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("RefreshUnreadMessages"))) { _ in
            Task { await refreshUnreadMessages() }
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

#Preview {
    HomeContainerView(popToRootTrigger: 0)
        .environmentObject(AuthViewModel())
}
