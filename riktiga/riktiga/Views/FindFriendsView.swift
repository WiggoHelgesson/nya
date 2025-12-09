import SwiftUI
import Combine

struct FindFriendsView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @Environment(\.dismiss) private var dismiss
    @StateObject private var findFriendsViewModel = FindFriendsViewModel()
    @State private var searchText = ""
    @State private var recommendedUsers: [UserSearchResult] = []
    @State private var isLoadingRecommended = false
    @State private var recommendedFollowingStatus: [String: Bool] = [:]
    @State private var searchDebounceTask: Task<Void, Never>?
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search Bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.gray)
                    
                    TextField("Sök efter användare...", text: $searchText)
                        .textFieldStyle(PlainTextFieldStyle())
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .onChange(of: searchText) { _, newValue in
                            // Cancel previous search task
                            searchDebounceTask?.cancel()
                            
                            if newValue.count >= 2 {
                                // Debounce: wait 300ms before searching
                                searchDebounceTask = Task {
                                    try? await Task.sleep(nanoseconds: 300_000_000)
                                    if !Task.isCancelled {
                                        await MainActor.run {
                                            performSearch()
                                        }
                                    }
                                }
                            } else {
                                findFriendsViewModel.searchResults = []
                            }
                        }
                    
                    if !searchText.isEmpty {
                        Button {
                            searchText = ""
                            findFriendsViewModel.searchResults = []
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.gray)
                        }
                    }
                }
                .padding(12)
                .background(Color(.systemGray6))
                .cornerRadius(10)
                .padding(.horizontal, 16)
                .padding(.top, 16)
                
                // Results
                if !searchText.isEmpty {
                    // Show search results when searching
                    if findFriendsViewModel.isLoading && findFriendsViewModel.searchResults.isEmpty {
                        Spacer()
                        ProgressView("Söker...")
                            .foregroundColor(.gray)
                        Spacer()
                    } else if findFriendsViewModel.searchResults.isEmpty && !findFriendsViewModel.isLoading {
                        Spacer()
                        VStack(spacing: 16) {
                            Image(systemName: "person.crop.circle.badge.questionmark")
                                .font(.system(size: 48))
                                .foregroundColor(.gray)
                            Text("Inga användare hittades")
                                .font(.headline)
                            Text("Prova att söka efter ett annat namn")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        Spacer()
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 12) {
                                ForEach(findFriendsViewModel.searchResults) { user in
                                    NavigationLink(destination: UserProfileView(userId: user.id)) {
                                        UserSearchCard(
                                            user: user,
                                            isFollowing: findFriendsViewModel.followingStatus[user.id] ?? false,
                                            onFollowToggle: {
                                                toggleFollow(userId: user.id)
                                            }
                                        )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(16)
                        }
                    }
                } else {
                    // Show recommended users when search is empty
                    if isLoadingRecommended && recommendedUsers.isEmpty {
                        Spacer()
                        ProgressView("Laddar rekommendationer...")
                            .foregroundColor(.gray)
                        Spacer()
                    } else if recommendedUsers.isEmpty {
                        Spacer()
                        VStack(spacing: 16) {
                            Image(systemName: "person.2.fill")
                                .font(.system(size: 48))
                                .foregroundColor(.gray)
                            Text("Rekommenderade vänner")
                                .font(.headline)
                            Text("Vi laddar förslag baserat på gemensamma vänner...")
                                .font(.caption)
                                .foregroundColor(.gray)
                                .multilineTextAlignment(.center)
                        }
                        .padding(16)
                        Spacer()
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 12) {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Rekommenderade vänner")
                                        .font(.system(size: 18, weight: .bold))
                                        .foregroundColor(.black)
                                    
                                    Text("Baserat på gemensamma vänner")
                                        .font(.system(size: 14))
                                        .foregroundColor(.gray)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 16)
                                .padding(.top, 16)
                                .padding(.bottom, 8)
                                
                                ForEach(recommendedUsers) { user in
                                    NavigationLink(destination: UserProfileView(userId: user.id)) {
                                        UserSearchCard(
                                            user: user,
                                            isFollowing: recommendedFollowingStatus[user.id] ?? false,
                                            onFollowToggle: {
                                                toggleRecommendedFollow(userId: user.id)
                                            }
                                        )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.bottom, 16)
                        }
                    }
                }
            }
            .navigationTitle("Hitta vänner")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Stäng") {
                        dismiss()
                    }
                }
            }
            .task {
                await loadFollowingIds()
                loadRecommendedUsers()
            }
        }
    }
    
    private func loadFollowingIds() async {
        guard let userId = authViewModel.currentUser?.id else { return }
        await findFriendsViewModel.loadFollowingIds(userId: userId)
    }
    
    private func loadRecommendedUsers() {
        guard let userId = authViewModel.currentUser?.id else { return }
        
        isLoadingRecommended = true
        
        // Load from cache immediately
        if let cached = AppCacheManager.shared.getCachedRecommendedUsers(userId: userId) {
            self.recommendedUsers = cached
            // Update follow status from already loaded followingIds
            for user in cached {
                recommendedFollowingStatus[user.id] = findFriendsViewModel.followingIds.contains(user.id)
            }
            self.isLoadingRecommended = false
        }
        
        Task {
            do {
                let recommended = try await SocialService.shared.getRecommendedUsers(userId: userId, limit: 8)
                
                // Use already loaded followingIds for fast status check
                var followStatus: [String: Bool] = [:]
                for user in recommended {
                    followStatus[user.id] = findFriendsViewModel.followingIds.contains(user.id)
                }
                
                await MainActor.run {
                    self.recommendedUsers = recommended
                    self.recommendedFollowingStatus = followStatus
                    self.isLoadingRecommended = false
                }
                AppCacheManager.shared.saveRecommendedUsers(recommended, userId: userId)
            } catch {
                print("❌ Error loading recommended users: \(error)")
                await MainActor.run {
                    self.isLoadingRecommended = false
                }
            }
        }
    }
    
    private func performSearch() {
        print("🔍 FindFriendsView: performSearch called with text: '\(searchText)'")
        guard !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              let currentUserId = authViewModel.currentUser?.id else { 
            print("❌ FindFriendsView: Search text empty or no current user")
            return 
        }
        
        print("🔍 FindFriendsView: Calling searchUsers with query: '\(searchText)', userId: '\(currentUserId)'")
        findFriendsViewModel.searchUsers(query: searchText, currentUserId: currentUserId)
    }
    
    private func toggleFollow(userId: String) {
        guard let currentUserId = authViewModel.currentUser?.id else { return }
        
        findFriendsViewModel.toggleFollow(followerId: currentUserId, followingId: userId)
    }
    
    private func toggleRecommendedFollow(userId: String) {
        guard let currentUserId = authViewModel.currentUser?.id else { return }
        
        let isCurrentlyFollowing = recommendedFollowingStatus[userId] ?? false
        
        // Optimistic update
        recommendedFollowingStatus[userId] = !isCurrentlyFollowing
        findFriendsViewModel.followingStatus[userId] = !isCurrentlyFollowing
        if isCurrentlyFollowing {
            findFriendsViewModel.followingIds.remove(userId)
        } else {
            findFriendsViewModel.followingIds.insert(userId)
        }
        
        Task {
            do {
                if isCurrentlyFollowing {
                    try await SocialService.shared.unfollowUser(followerId: currentUserId, followingId: userId)
                } else {
                    try await SocialService.shared.followUser(followerId: currentUserId, followingId: userId)
                }
                NotificationCenter.default.post(name: .profileStatsUpdated, object: nil)
            } catch {
                // Revert on error
                await MainActor.run {
                    recommendedFollowingStatus[userId] = isCurrentlyFollowing
                    findFriendsViewModel.followingStatus[userId] = isCurrentlyFollowing
                    if isCurrentlyFollowing {
                        findFriendsViewModel.followingIds.insert(userId)
                    } else {
                        findFriendsViewModel.followingIds.remove(userId)
                    }
                }
                print("❌ Error toggling follow: \(error)")
            }
        }
    }
    
}

struct UserSearchCard: View {
    let user: UserSearchResult
    let isFollowing: Bool
    let onFollowToggle: () -> Void
    @State private var isProcessing = false
    
    var body: some View {
        HStack(spacing: 12) {
            // User Avatar
            ProfileImage(url: user.avatarUrl, size: 50)
            
            // User Info
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(user.name)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.black)
                        .lineLimit(1)
                    
                    // Chevron to indicate tappable
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.gray.opacity(0.6))
                }
                
                Text("@\(user.name.lowercased().replacingOccurrences(of: " ", with: ""))")
                    .font(.system(size: 13))
                    .foregroundColor(.gray)
                    .lineLimit(1)
            }
            
            Spacer()
            
            // Follow Button - prevent navigation when tapping
            Button(action: {
                guard !isProcessing else { return }
                isProcessing = true
                onFollowToggle()
                
                // Reset processing state after a short delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    isProcessing = false
                }
            }) {
                HStack(spacing: 4) {
                    if isProcessing {
                        ProgressView()
                            .scaleEffect(0.7)
                            .progressViewStyle(CircularProgressViewStyle(tint: isFollowing ? .gray : .white))
                    }
                    
                    Text(isFollowing ? "Följer" : "Följ")
                        .font(.system(size: 14, weight: .semibold))
                }
                .foregroundColor(isFollowing ? .gray : .white)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(isFollowing ? Color(.systemGray5) : Color.black)
                )
            }
            .buttonStyle(.borderless) // Prevents NavigationLink from triggering
            .disabled(isProcessing)
        }
        .padding(14)
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.08), radius: 3, x: 0, y: 1)
    }
}

class FindFriendsViewModel: ObservableObject {
    @Published var searchResults: [UserSearchResult] = []
    @Published var isLoading = false
    @Published var followingStatus: [String: Bool] = [:]
    @Published var followingIds: Set<String> = []
    
    private let cacheManager = AppCacheManager.shared
    
    // Load all following IDs once for fast status checks
    func loadFollowingIds(userId: String) async {
        do {
            let ids = try await SocialService.shared.getFollowing(userId: userId)
            await MainActor.run {
                self.followingIds = Set(ids)
                print("✅ Loaded \(ids.count) following IDs")
            }
        } catch {
            print("❌ Error loading following IDs: \(error)")
        }
    }
    
    func searchUsers(query: String, currentUserId: String) {
        print("🔍 FindFriendsViewModel: Starting search for '\(query)'")
        isLoading = true
        
        let lowercasedQuery = query.lowercased()
        
        // First, try to load from cache for instant display
        if let cachedUsers = cacheManager.getCachedAllUsers() {
            let filteredUsers = cachedUsers.filter { user in
                user.name.lowercased().contains(lowercasedQuery)
            }
            
            if !filteredUsers.isEmpty {
                self.searchResults = filteredUsers
                // Use pre-loaded followingIds for instant status
                for user in filteredUsers {
                    self.followingStatus[user.id] = self.followingIds.contains(user.id)
                }
                self.isLoading = false
                print("✅ Loaded \(filteredUsers.count) users from cache")
            }
        }
        
        // Then fetch fresh data in background
        Task {
            do {
                let results = try await SocialService.shared.searchUsers(query: query, currentUserId: currentUserId)
                
                await MainActor.run {
                    print("🔍 FindFriendsViewModel: Got \(results.count) results")
                    self.searchResults = results
                    
                    // Use pre-loaded followingIds for instant status
                    for user in results {
                        self.followingStatus[user.id] = self.followingIds.contains(user.id)
                    }
                    
                    self.isLoading = false
                    
                    // Save all users to cache for future searches
                    self.cacheManager.saveAllUsers(results)
                }
            } catch {
                await MainActor.run {
                    print("❌ FindFriendsViewModel: Error: \(error)")
                    self.isLoading = false
                }
            }
        }
    }
    
    func toggleFollow(followerId: String, followingId: String) {
        let isCurrentlyFollowing = followingStatus[followingId] ?? false
        
        // Optimistic update
        followingStatus[followingId] = !isCurrentlyFollowing
        if isCurrentlyFollowing {
            followingIds.remove(followingId)
        } else {
            followingIds.insert(followingId)
        }
        
        Task {
            do {
                if isCurrentlyFollowing {
                    try await SocialService.shared.unfollowUser(followerId: followerId, followingId: followingId)
                    print("✅ Unfollowed user \(followingId)")
                } else {
                    try await SocialService.shared.followUser(followerId: followerId, followingId: followingId)
                    print("✅ Followed user \(followingId)")
                }
                
                // Notify that profile stats should be updated
                NotificationCenter.default.post(name: .profileStatsUpdated, object: nil)
            } catch {
                // Revert on error
                await MainActor.run {
                    self.followingStatus[followingId] = isCurrentlyFollowing
                    if isCurrentlyFollowing {
                        self.followingIds.insert(followingId)
                    } else {
                        self.followingIds.remove(followingId)
                    }
                }
                print("❌ Error toggling follow: \(error)")
            }
        }
    }
}

#Preview {
    FindFriendsView()
        .environmentObject(AuthViewModel())
}
