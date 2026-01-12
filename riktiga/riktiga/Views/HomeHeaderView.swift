import SwiftUI

// MARK: - Strava-Style Navigation Header
struct StravaStyleHeaderView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    var isProfilePage: Bool = false
    var onSettingsTapped: (() -> Void)? = nil
    
    @State private var unreadNotifications = 0
    @State private var isFetchingUnread = false
    @State private var showMonthlyPrize = false
    @State private var showNonProAlert = false
    @State private var showPaywall = false
    @State private var showFindFriends = false
    @State private var showPublicProfile = false
    
    private var isPremium: Bool {
        authViewModel.currentUser?.isProMember ?? false
    }
    
    var body: some View {
        ZStack {
            // MARK: - Center: Månadens pris (verkligt centrerad)
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
            
            // MARK: - Left and Right sides
            HStack {
                // MARK: - Left side: Profile Picture
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
                
                Spacer()
                
                // MARK: - Right side: Different for Profile page vs other pages
                if isProfilePage {
                    // Settings icon for profile page
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
                    // Find Friends + Notifications for other pages
                    HStack(spacing: 12) {
                        // Find friends
                        Button {
                            showFindFriends = true
                        } label: {
                            Image(systemName: "person.badge.plus")
                                .font(.system(size: 22, weight: .regular))
                                .foregroundColor(.primary)
                                .frame(width: 36, height: 36)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        
                        // Notification bell - NavigationLink to separate page
                        NavigationLink(destination: NotificationsView(onDismiss: {
                            Task { await refreshUnreadCount() }
                        }).environmentObject(authViewModel)) {
                            ZStack(alignment: .topTrailing) {
                                Image(systemName: "bell")
                                    .font(.system(size: 22, weight: .regular))
                                    .foregroundColor(.primary)
                                
                                // Notification badge
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
        .padding(.vertical, 12)
        .background(Color(.systemBackground))
        .shadow(color: Color.black.opacity(0.15), radius: 8, x: 0, y: 4)
        .sheet(isPresented: $showMonthlyPrize) {
            MonthlyPrizeView()
                .environmentObject(authViewModel)
        }
        .sheet(isPresented: $showPaywall) {
            PresentPaywallView()
        }
        .sheet(isPresented: $showFindFriends) {
            FindFriendsView()
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
                    showPaywall = true
                }
            }
        } message: {
            Text("Uppgradera till Pro för att delta i månadens tävling och vinna häftiga priser!")
        }
        .task {
            await refreshUnreadCount()
        }
        .onAppear {
            Task { await refreshUnreadCount() }
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

// MARK: - Backwards compatibility - All headers now use same Strava-style
struct HomeHeaderView: View {
    var body: some View {
        StravaStyleHeaderView()
    }
}

struct RewardsHeaderView: View {
    var body: some View {
        StravaStyleHeaderView()
    }
}

struct ProfileHeaderView: View {
    var body: some View {
        StravaStyleHeaderView()
    }
}

#Preview {
    StravaStyleHeaderView()
        .environmentObject(AuthViewModel())
}
