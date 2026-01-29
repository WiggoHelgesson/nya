import SwiftUI

struct HomeContainerView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
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
                .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("PopToRootKalorier"))) { _ in
                    navigationPath = NavigationPath()
                    showAddMealView = false
                }
        }
    }
}

// MARK: - Simple App Header (No Tabs - for Home page)
struct SimpleAppHeader: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    
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
        VStack(spacing: 0) {
            // MARK: - Top Row (Profile, Title, Actions)
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
                    // Profile picture
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
                    
                    // Right side actions
                    HStack(spacing: 12) {
                        // Notifications - NavigationLink to separate page
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
                        
                        // Find friends last (rightmost)
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
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 16)
        }
        .background(Color(.systemBackground))
        .shadow(color: Color.black.opacity(0.15), radius: 8, x: 0, y: 4)
        .sheet(isPresented: $showMonthlyPrize) {
            MonthlyPrizeView()
                .environmentObject(authViewModel)
        }
        .navigationDestination(isPresented: $showFindFriends) {
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
                    SuperwallService.shared.showPaywall()
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

// MARK: - Combined Header with Tabs (Strava-style)
struct CombinedHeaderWithTabs<Tab: RawRepresentable & CaseIterable & Hashable>: View where Tab.RawValue == String, Tab.AllCases: RandomAccessCollection {
    @EnvironmentObject var authViewModel: AuthViewModel
    @Binding var selectedTab: Tab
    
    @State private var unreadNotifications = 0
    @State private var isFetchingUnread = false
    @State private var showMonthlyPrize = false
    @State private var showNonProAlert = false
    @State private var showPaywall = false
    @State private var showFindFriends = false
    @State private var showPublicProfile = false
    
    var isProfilePage: Bool = false
    var onSettingsTapped: (() -> Void)? = nil
    
    private var isPremium: Bool {
        authViewModel.currentUser?.isProMember ?? false
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // MARK: - Top Row (Profile, Title, Actions)
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
                    // Profile picture
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
                        HStack(spacing: 12) {
                            // Notifications - NavigationLink to separate page
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
                            
                            // Find friends last (rightmost)
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
                                Text(tab.rawValue)
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
        .sheet(isPresented: $showMonthlyPrize) {
            MonthlyPrizeView()
                .environmentObject(authViewModel)
        }
        .navigationDestination(isPresented: $showFindFriends) {
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
                    SuperwallService.shared.showPaywall()
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

#Preview {
    HomeContainerView()
        .environmentObject(AuthViewModel())
}
