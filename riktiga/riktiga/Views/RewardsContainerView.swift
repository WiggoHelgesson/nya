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
    
    @State private var selectedTab = 0
    @ObservedObject private var cartManager = CartManager.shared
    @State private var showCart = false
    @State private var marketSubTab = 0
    
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
                        if isPremium {
                            Text(selectedTab == 0
                                 ? L.t(sv: "Belöningar", nb: "Belønninger")
                                 : "Up&Down Market")
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
                    
                    // MARK: - Tab Picker (Belöningar / Up&Down Market)
                    rewardsTabPicker
                }
                .background(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.15), radius: 8, x: 0, y: 4)
                .zIndex(2)
                
                // MARK: - Content
                if selectedTab == 0 {
                    RewardsView()
                        .environmentObject(authViewModel)
                } else {
                    VStack(spacing: 0) {
                        marketSubTabPicker
                        
                        if marketSubTab == 0 {
                            ProductGridView(showCart: $showCart)
                                .environmentObject(authViewModel)
                        } else {
                            sellPlaceholderView
                        }
                    }
                }
            }
            .navigationBarHidden(true)
            .navigationDestination(for: ShopifyProduct.self) { product in
                ProductDetailView(product: product, showCart: $showCart)
                    .environmentObject(authViewModel)
            }
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
        .sheet(isPresented: $showCart) {
            CartView()
                .environmentObject(authViewModel)
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
            selectedTab = 0
            marketSubTab = 0
            NotificationCenter.default.post(name: NSNotification.Name("PopToRootBeloningar"), object: nil)
        }
    }
    
    // MARK: - Rewards / Market Tab Picker
    
    private var rewardsTabPicker: some View {
        HStack(spacing: 0) {
            rewardsTabButton(L.t(sv: "Belöningar", nb: "Belønninger"), index: 0)
            rewardsTabButton("Up&Down Market", index: 1)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 8)
    }
    
    private func rewardsTabButton(_ title: String, index: Int) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) { selectedTab = index }
        } label: {
            Text(title)
                .font(.system(size: 14, weight: selectedTab == index ? .bold : .medium))
                .foregroundColor(selectedTab == index ? .primary : .secondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(
                    selectedTab == index
                        ? RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color(.systemGray5))
                        : nil
                )
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Market Sub-Tab Picker (Köp / Sälj)
    
    private var marketSubTabPicker: some View {
        HStack(spacing: 0) {
            marketSubTabButton(L.t(sv: "Köp", nb: "Kjøp"), index: 0)
            marketSubTabButton(L.t(sv: "Sälj", nb: "Selg"), index: 1)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
    }
    
    private func marketSubTabButton(_ title: String, index: Int) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) { marketSubTab = index }
        } label: {
            Text(title)
                .font(.system(size: 13, weight: marketSubTab == index ? .bold : .medium))
                .foregroundColor(marketSubTab == index ? .primary : .secondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
                .background(
                    marketSubTab == index
                        ? RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color(.systemGray5))
                        : nil
                )
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Sell Placeholder
    
    private var sellPlaceholderView: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "tag")
                .font(.system(size: 40))
                .foregroundColor(.gray.opacity(0.5))
            Text(L.t(sv: "Sälj - Kommer snart", nb: "Selg - Kommer snart"))
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - Network
    
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
