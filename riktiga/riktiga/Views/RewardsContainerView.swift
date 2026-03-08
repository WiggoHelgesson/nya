import SwiftUI

struct RewardsContainerView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    let popToRootTrigger: Int
    @State private var showPublicProfile = false
    @State private var unreadNotifications = 0
    @State private var unreadMessages = 0
    @State private var isFetchingUnread = false
    @State private var navigationPath = NavigationPath()
    @State private var lastUnreadFetch: Date = .distantPast
    @StateObject private var dmService = DirectMessageService.shared
    
    private let fetchThrottleInterval: TimeInterval = 30
    
    private var isPremium: Bool {
        authViewModel.currentUser?.isProMember ?? false
    }
    
    var body: some View {
        NavigationStack(path: $navigationPath) {
            VStack(spacing: 0) {
                // MARK: - Header
                VStack(spacing: 0) {
                    ZStack {
                        // Center: Page title or Pro CTA
                        if isPremium {
                            Text(L.t(sv: "Belöningar", nb: "Belønninger"))
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.primary)
                        } else {
                            Button {
                                SuperwallService.shared.showPaywall()
                            } label: {
                                Text(L.t(sv: "Bli pro medlem", nb: "Bli pro-medlem"))
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 9)
                                    .background(
                                        LinearGradient(colors: [.black, Color(white: 0.55)],
                                                       startPoint: .leading, endPoint: .trailing)
                                    )
                                    .cornerRadius(20)
                            }
                            .buttonStyle(.plain)
                        }
                        
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
                }
                .background(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.15), radius: 8, x: 0, y: 4)
                .zIndex(2)
                
                // Content (no tabs needed)
                RewardsView()
                    .environmentObject(authViewModel)
            }
            .navigationBarHidden(true)
        }
        .sheet(isPresented: $showPublicProfile) {
            if let userId = authViewModel.currentUser?.id {
                NavigationStack {
                    UserProfileView(userId: userId)
                        .environmentObject(authViewModel)
                        .toolbar {
                            ToolbarItem(placement: .navigationBarLeading) {
                                Button(L.t(sv: "Stäng", nb: "Lukk")) {
                                    showPublicProfile = false
                                }
                            }
                        }
                }
            }
        }
        .task {
            await throttledRefresh()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("RefreshUnreadMessages"))) { _ in
            Task { await refreshUnreadMessages() }
        }
        .id(popToRootTrigger)
        .onChange(of: popToRootTrigger) { _, _ in
            navigationPath = NavigationPath()
            NotificationCenter.default.post(name: NSNotification.Name("PopToRootBeloningar"), object: nil)
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
    RewardsContainerView(popToRootTrigger: 0)
        .environmentObject(AuthViewModel())
}
