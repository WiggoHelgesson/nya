import SwiftUI

struct RewardsContainerView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    let popToRootTrigger: Int
    @State private var showPublicProfile = false
    @State private var unreadNotifications = 0
    @State private var isFetchingUnread = false
    @State private var navigationPath = NavigationPath()
    @State private var lastUnreadFetch: Date = .distantPast

    private let fetchThrottleInterval: TimeInterval = 30

    var body: some View {
        NavigationStack(path: $navigationPath) {
            VStack(spacing: 0) {
                VStack(spacing: 0) {
                    ZStack {
                        PointsBadge(points: authViewModel.currentUser?.currentXP ?? 0)

                        HStack {
                            HStack(spacing: 10) {
                                Button {
                                    showPublicProfile = true
                                } label: {
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

                            HStack(spacing: 12) {
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
                    .padding(.bottom, 12)

                    Rectangle()
                        .fill(Color.primary)
                        .frame(height: 0.5)
                        .opacity(0.1)
                }
                .background(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.15), radius: 8, x: 0, y: 4)
                .zIndex(2)

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
            print("Failed to fetch unread notifications: \(error)")
        }
        isFetchingUnread = false
    }

}

#Preview {
    RewardsContainerView(popToRootTrigger: 0)
        .environmentObject(AuthViewModel())
}
