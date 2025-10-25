import SwiftUI
import Combine

struct FollowListView: View {
    let userId: String
    let listType: FollowListType
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = FollowListViewModel()
    @EnvironmentObject var authViewModel: AuthViewModel
    
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
    }
    
    var body: some View {
        NavigationStack {
            VStack {
                if viewModel.isLoading {
                    Spacer()
                    ProgressView("Laddar...")
                        .foregroundColor(.gray)
                    Spacer()
                } else if viewModel.users.isEmpty {
                    Spacer()
                    VStack(spacing: 16) {
                        Image(systemName: listType == .followers ? "person.2" : "person.2.fill")
                            .font(.system(size: 50))
                            .foregroundColor(.gray)
                        
                        Text(listType == .followers ? "Inga följare än" : "Följer ingen än")
                            .font(.title2)
                            .fontWeight(.medium)
                            .foregroundColor(.gray)
                        
                        Text(listType == .followers ? "När någon följer dig kommer de att visas här" : "När du börjar följa någon kommer de att visas här")
                            .font(.body)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }
                    Spacer()
                } else {
                    // Show cache indicator if using cached data
                    if viewModel.isUsingCache {
                        HStack {
                            Image(systemName: "clock.arrow.circlepath")
                                .foregroundColor(.blue)
                            Text("Visar sparad data")
                                .font(.caption)
                                .foregroundColor(.blue)
                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                    }
                    
                    List {
                        ForEach(viewModel.users, id: \.id) { user in
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
                    }
                    .listStyle(PlainListStyle())
                }
            }
            .navigationTitle(listType.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        dismiss()
                    }) {
                        Image(systemName: "chevron.left")
                            .foregroundColor(.black)
                            .frame(width: 32, height: 32)
                            .background(Color(.systemGray5))
                            .cornerRadius(16)
                    }
                }
            }
            .onAppear {
                Task {
                    await viewModel.loadUsers(userId: userId, listType: listType)
                }
            }
        }
    }
}

struct UserFollowRow: View {
    let user: UserSearchResult
    let currentUserId: String
    let onFollowToggle: (String, Bool) -> Void
    @State private var isFollowing = false
    @State private var isLoading = false
    
    var body: some View {
        HStack(spacing: 12) {
            // Profile picture
            ProfileImage(url: user.avatarUrl, size: 50)
            
            // User info
            VStack(alignment: .leading, spacing: 4) {
                Text(user.name)
                    .font(.headline)
                    .foregroundColor(.black)
                
                Text("@\(user.name.lowercased())")
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            // Follow/Unfollow button
            if user.id != currentUserId {
                Button(action: {
                    Task {
                        isLoading = true
                        onFollowToggle(user.id, isFollowing)
                        isLoading = false
                    }
                }) {
                    if isLoading {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else {
                        Text(isFollowing ? "Avfölj" : "Följ")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(isFollowing ? .red : .white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(isFollowing ? Color(.systemGray6) : Color.black)
                            .cornerRadius(20)
                    }
                }
                .disabled(isLoading)
            }
        }
        .padding(.vertical, 8)
        .onAppear {
            Task {
                await checkFollowStatus()
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
        
        // First, try to load from cache for instant display
        if listType == .followers {
            if let cachedFollowers = cacheManager.getCachedFollowers(userId: userId) {
                DispatchQueue.main.async {
                    self.users = cachedFollowers
                    self.isLoading = false
                    self.isUsingCache = true
                    print("✅ Loaded \(cachedFollowers.count) followers from cache")
                }
            }
        } else {
            if let cachedFollowing = cacheManager.getCachedFollowing(userId: userId) {
                DispatchQueue.main.async {
                    self.users = cachedFollowing
                    self.isLoading = false
                    self.isUsingCache = true
                    print("✅ Loaded \(cachedFollowing.count) following from cache")
                }
            }
        }
        
        // Then fetch fresh data in background
        do {
            if listType == .followers {
                let fetchedUsers = try await SocialService.shared.getFollowerUsers(userId: userId)
                await MainActor.run {
                    // Only update if we got new data or cache was empty
                    if self.users.isEmpty || !self.isUsingCache {
                        self.users = fetchedUsers
                    }
                    self.isLoading = false
                    self.isUsingCache = false
                    
                    // Save to cache for next time
                    self.cacheManager.saveFollowers(fetchedUsers, userId: userId)
                }
                print("✅ Loaded \(fetchedUsers.count) follower users directly with JOIN")
            } else {
                let fetchedUsers = try await SocialService.shared.getFollowingUsers(userId: userId)
                await MainActor.run {
                    // Only update if we got new data or cache was empty
                    if self.users.isEmpty || !self.isUsingCache {
                        self.users = fetchedUsers
                    }
                    self.isLoading = false
                    self.isUsingCache = false
                    
                    // Save to cache for next time
                    self.cacheManager.saveFollowing(fetchedUsers, userId: userId)
                }
                print("✅ Loaded \(fetchedUsers.count) following users directly with JOIN")
            }
        } catch {
            print("Error loading users: \(error)")
            await MainActor.run {
                self.users = []
                self.isLoading = false
                self.isUsingCache = false
            }
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
