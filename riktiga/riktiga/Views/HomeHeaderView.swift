import SwiftUI

struct HomeHeaderView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var showNotifications = false
    @State private var unreadNotifications = 0
    @State private var isFetchingUnread = false
    @State private var showMonthlyPrize = false
    @State private var showNonProAlert = false
    @State private var showPaywall = false
    
    private var isPremium: Bool {
        authViewModel.currentUser?.isProMember ?? false
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // Notifications Button on the left
            Button {
                showNotifications = true
            } label: {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: "bell.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    // Notification badge
                    if unreadNotifications > 0 {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 20, height: 20)
                            .overlay(
                                Text("\(unreadNotifications)")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(.white)
                            )
                            .offset(x: 8, y: -8)
                    }
                }
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            
            Spacer()
            
            // Månadens pris button (centrerad)
            Button {
                if isPremium {
                    showMonthlyPrize = true
                } else {
                    showNonProAlert = true
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "trophy.fill")
                        .font(.system(size: 14, weight: .semibold))
                    Text("Månadens pris")
                        .font(.system(size: 14, weight: .semibold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Color.black)
                .cornerRadius(20)
            }
            .buttonStyle(.plain)
            
            Spacer()
            
            // Search icon on the right
            NavigationLink(destination: FindFriendsView()) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.primary)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .sheet(isPresented: $showNotifications) {
            NotificationsView(onDismiss: {
                Task { await refreshUnreadCount() }
            })
            .environmentObject(authViewModel)
        }
        .sheet(isPresented: $showMonthlyPrize) {
            MonthlyPrizeView()
                .environmentObject(authViewModel)
        }
        .sheet(isPresented: $showPaywall) {
            PresentPaywallView()
        }
        .alert("Enbart för pro medlemmar", isPresented: $showNonProAlert) {
            Button("Stäng", role: .cancel) { }
            Button("Bli Pro") {
                showNonProAlert = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    showPaywall = true
                }
            }
        } message: {
            Text("Uppgradera till Pro för att delta i månadens tävling och vinna häftiga priser!")
        }
        .task {
            await refreshUnreadCount()
        }
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
}

// MARK: - Rewards Header
struct RewardsHeaderView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var showNotifications = false
    @State private var unreadNotifications = 0
    @State private var isFetchingUnread = false
    @State private var showMonthlyPrize = false
    @State private var showNonProAlert = false
    @State private var showPaywall = false
    
    private var isPremium: Bool {
        authViewModel.currentUser?.isProMember ?? false
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // Notifications Button on the left
            Button {
                showNotifications = true
            } label: {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: "bell.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    // Notification badge
                    if unreadNotifications > 0 {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 20, height: 20)
                            .overlay(
                                Text("\(unreadNotifications)")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(.white)
                            )
                            .offset(x: 8, y: -8)
                    }
                }
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            
            Spacer()
            
            // Månadens pris button (centrerad)
            Button {
                if isPremium {
                    showMonthlyPrize = true
                } else {
                    showNonProAlert = true
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "trophy.fill")
                        .font(.system(size: 14, weight: .semibold))
                    Text("Månadens pris")
                        .font(.system(size: 14, weight: .semibold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Color.black)
                .cornerRadius(20)
            }
            .buttonStyle(.plain)
            
            Spacer()
            
            // Search icon on the right
            NavigationLink(destination: FindFriendsView()) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.primary)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .padding(.horizontal, 16)
        .sheet(isPresented: $showNotifications) {
            NotificationsView(onDismiss: {
                Task { await refreshUnreadCount() }
            })
            .environmentObject(authViewModel)
        }
        .sheet(isPresented: $showMonthlyPrize) {
            MonthlyPrizeView()
                .environmentObject(authViewModel)
        }
        .sheet(isPresented: $showPaywall) {
            PresentPaywallView()
        }
        .alert("Enbart för pro medlemmar", isPresented: $showNonProAlert) {
            Button("Stäng", role: .cancel) { }
            Button("Bli Pro") {
                showNonProAlert = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    showPaywall = true
                }
            }
        } message: {
            Text("Uppgradera till Pro för att delta i månadens tävling och vinna häftiga priser!")
        }
        .task {
            await refreshUnreadCount()
        }
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
}

// MARK: - Profile Header
struct ProfileHeaderView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var showNotifications = false
    @State private var unreadNotifications = 0
    @State private var isFetchingUnread = false
    @State private var showMonthlyPrize = false
    @State private var showNonProAlert = false
    @State private var showPaywall = false
    
    private var isPremium: Bool {
        authViewModel.currentUser?.isProMember ?? false
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // Notifications Button on the left
            Button {
                showNotifications = true
            } label: {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: "bell.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    // Notification badge
                    if unreadNotifications > 0 {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 20, height: 20)
                            .overlay(
                                Text("\(unreadNotifications)")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(.white)
                            )
                            .offset(x: 8, y: -8)
                    }
                }
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            
            Spacer()
            
            // Månadens pris button (centrerad)
            Button {
                if isPremium {
                    showMonthlyPrize = true
                } else {
                    showNonProAlert = true
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "trophy.fill")
                        .font(.system(size: 14, weight: .semibold))
                    Text("Månadens pris")
                        .font(.system(size: 14, weight: .semibold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Color.black)
                .cornerRadius(20)
            }
            .buttonStyle(.plain)
            
            Spacer()
            
            // Search icon on the right
            NavigationLink(destination: FindFriendsView()) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.primary)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .padding(.horizontal, 16)
        .sheet(isPresented: $showNotifications) {
            NotificationsView(onDismiss: {
                Task { await refreshUnreadCount() }
            })
            .environmentObject(authViewModel)
        }
        .sheet(isPresented: $showMonthlyPrize) {
            MonthlyPrizeView()
                .environmentObject(authViewModel)
        }
        .sheet(isPresented: $showPaywall) {
            PresentPaywallView()
        }
        .alert("Enbart för pro medlemmar", isPresented: $showNonProAlert) {
            Button("Stäng", role: .cancel) { }
            Button("Bli Pro") {
                showNonProAlert = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    showPaywall = true
                }
            }
        } message: {
            Text("Uppgradera till Pro för att delta i månadens tävling och vinna häftiga priser!")
        }
        .task {
            await refreshUnreadCount()
        }
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
}

#Preview {
    HomeHeaderView()
}
