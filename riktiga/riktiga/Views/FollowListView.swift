import SwiftUI
import Combine

struct FollowListView: View {
    let userId: String
    let listType: FollowListType
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = FollowListViewModel()
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var selectedTab: FollowListType
    
    init(userId: String, listType: FollowListType) {
        self.userId = userId
        self.listType = listType
        self._selectedTab = State(initialValue: listType)
    }
    
    enum FollowListType {
        case followers
        case following
        
        var title: String {
            switch self {
            case .followers:
                return "Följare"
            case .following:
                return "Följer"
            }
        }
        
        var sectionHeader: String {
            switch self {
            case .followers:
                return "PERSONER SOM FÖLJER DIG"
            case .following:
                return "PERSONER DU FÖLJER"
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Tab selector
            HStack(spacing: 0) {
                // Following tab
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedTab = .following
                    }
                    Task {
                        await viewModel.loadUsers(userId: userId, listType: .following)
                    }
                } label: {
                    VStack(spacing: 8) {
                        Text("Följer")
                            .font(.system(size: 16, weight: selectedTab == .following ? .semibold : .regular))
                            .foregroundColor(selectedTab == .following ? .black : .gray)
                        
                        Rectangle()
                            .fill(selectedTab == .following ? Color.black : Color.clear)
                            .frame(height: 2)
                    }
                }
                .frame(maxWidth: .infinity)
                
                // Followers tab
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedTab = .followers
                    }
                    Task {
                        await viewModel.loadUsers(userId: userId, listType: .followers)
                    }
                } label: {
                    VStack(spacing: 8) {
                        Text("Följare")
                            .font(.system(size: 16, weight: selectedTab == .followers ? .semibold : .regular))
                            .foregroundColor(selectedTab == .followers ? .black : .gray)
                        
                        Rectangle()
                            .fill(selectedTab == .followers ? Color.black : Color.clear)
                            .frame(height: 2)
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.top, 8)
            
            Divider()
            
            // Content
            if viewModel.isLoading && viewModel.users.isEmpty {
                Spacer()
                ProgressView("Laddar...")
                    .foregroundColor(.gray)
                Spacer()
            } else if viewModel.users.isEmpty {
                Spacer()
                VStack(spacing: 16) {
                    Image(systemName: selectedTab == .followers ? "person.2" : "person.2.fill")
                        .font(.system(size: 50))
                        .foregroundColor(.gray)
                    
                    Text(selectedTab == .followers ? "Inga följare än" : "Följer ingen än")
                        .font(.title2)
                        .fontWeight(.medium)
                        .foregroundColor(.gray)
                    
                    Text(selectedTab == .followers ? "När någon följer dig kommer de att visas här" : "När du börjar följa någon kommer de att visas här")
                        .font(.body)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
                Spacer()
            } else {
                // Section header
                HStack {
                    Text(selectedTab.sectionHeader)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.gray)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color(.systemGray6))
                
                // Users list
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(viewModel.users, id: \.id) { user in
                            NavigationLink(destination: UserProfileView(userId: user.id)) {
                                UserFollowRow(
                                    user: user,
                                    currentUserId: authViewModel.currentUser?.id ?? "",
                                    onFollowToggle: { userId, isFollowing in
                                        Task {
                                            await viewModel.toggleFollow(followerId: authViewModel.currentUser?.id ?? "", followingId: userId, isFollowing: isFollowing)
                                        }
                                    }
                                )
                            }
                            .buttonStyle(.plain)
                            
                            Divider()
                                .padding(.leading, 78)
                        }
                    }
                }
            }
        }
        .navigationTitle("Anslutningar")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: {
                    dismiss()
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .semibold))
                        Text("Tillbaka")
                            .font(.system(size: 17))
                    }
                    .foregroundColor(.black)
                }
            }
        }
        .onAppear {
            NavigationDepthTracker.shared.pushView()
            Task {
                await viewModel.loadUsers(userId: userId, listType: selectedTab)
            }
        }
        .onDisappear {
            NavigationDepthTracker.shared.popView()
        }
    }
}

struct UserFollowRow: View {
    let user: UserSearchResult
    let currentUserId: String
    let onFollowToggle: (String, Bool) -> Void
    @State private var isFollowing = false
    @State private var isLoading = false
    @State private var showUnfollowConfirmation = false
    
    var body: some View {
        HStack(spacing: 12) {
            // Profile picture
            ProfileImage(url: user.avatarUrl, size: 50)
            
            // User info
            VStack(alignment: .leading, spacing: 4) {
                Text(user.name)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.black)
                
                Text("@\(user.name.lowercased().replacingOccurrences(of: " ", with: ""))")
                    .font(.system(size: 14))
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            // Follow/Following button
            if user.id != currentUserId {
                Button(action: {
                    if isFollowing {
                        // Show confirmation popup
                        showUnfollowConfirmation = true
                    } else {
                        // Follow directly
                        performFollowToggle()
                    }
                }) {
                    if isLoading {
                        ProgressView()
                            .scaleEffect(0.8)
                            .frame(width: 90, height: 36)
                    } else {
                        Text(isFollowing ? "Följer" : "Följ")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(isFollowing ? .black : .white)
                            .frame(width: 90, height: 36)
                            .background(isFollowing ? Color.white : Color.black)
                            .cornerRadius(18)
                            .overlay(
                                RoundedRectangle(cornerRadius: 18)
                                    .stroke(Color.gray.opacity(0.3), lineWidth: isFollowing ? 1 : 0)
                            )
                    }
                }
                .disabled(isLoading)
                .alert("Är du säker?", isPresented: $showUnfollowConfirmation) {
                    Button("Avbryt", role: .cancel) { }
                    Button("Avfölj", role: .destructive) {
                        performFollowToggle()
                    }
                } message: {
                    Text("Du kommer att sluta följa \(user.name)")
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .onAppear {
            Task {
                await checkFollowStatus()
            }
        }
    }
    
    private func performFollowToggle() {
        Task {
            isLoading = true
            onFollowToggle(user.id, isFollowing)
            // Toggle state after action
            await MainActor.run {
                isFollowing.toggle()
                isLoading = false
            }
        }
    }
    
    private func checkFollowStatus() async {
        do {
            isFollowing = try await SocialService.shared.isFollowing(followerId: currentUserId, followingId: user.id)
        } catch {
            print("Error checking follow status: \(error)")
        }
    }
}

@MainActor
class FollowListViewModel: ObservableObject {
    @Published var users: [UserSearchResult] = []
    @Published var isLoading = false
    @Published var isUsingCache = false
    
    private let cacheManager = AppCacheManager.shared
    
    func loadUsers(userId: String, listType: FollowListView.FollowListType) async {
        isLoading = true
        users = [] // Clear for new tab
        
        // First, try to load from cache for instant display
        if listType == .followers {
            if let cachedFollowers = cacheManager.getCachedFollowers(userId: userId) {
                self.users = cachedFollowers
                self.isLoading = false
                self.isUsingCache = true
                print("✅ Loaded \(cachedFollowers.count) followers from cache")
            }
        } else {
            if let cachedFollowing = cacheManager.getCachedFollowing(userId: userId) {
                self.users = cachedFollowing
                self.isLoading = false
                self.isUsingCache = true
                print("✅ Loaded \(cachedFollowing.count) following from cache")
            }
        }
        
        // Then fetch fresh data in background
        do {
            if listType == .followers {
                let fetchedUsers = try await SocialService.shared.getFollowerUsers(userId: userId)
                self.users = fetchedUsers
                self.isLoading = false
                self.isUsingCache = false
                
                // Save to cache for next time
                self.cacheManager.saveFollowers(fetchedUsers, userId: userId)
                print("✅ Loaded \(fetchedUsers.count) follower users")
            } else {
                let fetchedUsers = try await SocialService.shared.getFollowingUsers(userId: userId)
                self.users = fetchedUsers
                self.isLoading = false
                self.isUsingCache = false
                
                // Save to cache for next time
                self.cacheManager.saveFollowing(fetchedUsers, userId: userId)
                print("✅ Loaded \(fetchedUsers.count) following users")
            }
        } catch {
            print("Error loading users: \(error)")
            self.users = []
            self.isLoading = false
            self.isUsingCache = false
        }
    }
    
    func toggleFollow(followerId: String, followingId: String, isFollowing: Bool) async {
        do {
            if isFollowing {
                try await SocialService.shared.unfollowUser(followerId: followerId, followingId: followingId)
            } else {
                try await SocialService.shared.followUser(followerId: followerId, followingId: followingId)
            }
            
            // Post notification to update profile stats
            NotificationCenter.default.post(name: .profileStatsUpdated, object: nil)
        } catch {
            print("Error toggling follow: \(error)")
        }
    }
}

#Preview {
    FollowListView(userId: "test-user-id", listType: .followers)
        .environmentObject(AuthViewModel())
}
