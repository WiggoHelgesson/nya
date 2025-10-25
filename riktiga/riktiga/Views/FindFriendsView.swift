import SwiftUI
import Combine

struct FindFriendsView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @Environment(\.dismiss) private var dismiss
    @StateObject private var findFriendsViewModel = FindFriendsViewModel()
    @State private var searchText = ""
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search Bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.gray)
                    
                    TextField("Sök efter användare...", text: $searchText)
                        .textFieldStyle(PlainTextFieldStyle())
                        .onChange(of: searchText) { _, newValue in
                            if newValue.count >= 3 {
                                performSearch()
                            } else {
                                findFriendsViewModel.searchResults = []
                            }
                        }
                }
                .padding(12)
                .background(Color(.systemGray6))
                .cornerRadius(10)
                .padding(.horizontal, 16)
                .padding(.top, 16)
                
                // Results
                if findFriendsViewModel.isLoading {
                    Spacer()
                    ProgressView("Söker...")
                        .foregroundColor(.gray)
                    Spacer()
                } else if findFriendsViewModel.searchResults.isEmpty && !searchText.isEmpty {
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
                } else if findFriendsViewModel.searchResults.isEmpty {
                    Spacer()
                    VStack(spacing: 16) {
                        Image(systemName: "person.2.fill")
                            .font(.system(size: 48))
                            .foregroundColor(.gray)
                        Text("Hitta dina vänner")
                            .font(.headline)
                        Text("Sök efter namn för att hitta användare att följa")
                            .font(.caption)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                    }
                    Spacer()
                } else {
                    // Show cache indicator if using cached data
                    if findFriendsViewModel.isUsingCache {
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
                    
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(findFriendsViewModel.searchResults) { user in
                                UserSearchCard(
                                    user: user,
                                    isFollowing: findFriendsViewModel.followingStatus[user.id] ?? false,
                                    onFollowToggle: {
                                        toggleFollow(userId: user.id)
                                    }
                                )
                            }
                        }
                        .padding(16)
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
                Text(user.name)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.black)
                
                Text("Användare")
                    .font(.system(size: 14))
                    .foregroundColor(.gray)
                    .lineLimit(1)
            }
            
            Spacer()
            
            // Follow Button
            Button(action: {
                guard !isProcessing else { return }
                isProcessing = true
                onFollowToggle()
                
                // Reset processing state after a short delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    isProcessing = false
                }
            }) {
                HStack(spacing: 6) {
                    if isProcessing {
                        ProgressView()
                            .scaleEffect(0.8)
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Image(systemName: isFollowing ? "person.badge.minus" : "person.badge.plus")
                            .font(.system(size: 14, weight: .medium))
                    }
                    
                    Text(isFollowing ? "Avfölj" : "Följ")
                        .font(.system(size: 14, weight: .medium))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(isFollowing ? Color(.systemGray4) : AppColors.brandBlue)
                )
            }
            .disabled(isProcessing)
        }
        .padding(16)
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
}

class FindFriendsViewModel: ObservableObject {
    @Published var searchResults: [UserSearchResult] = []
    @Published var isLoading = false
    @Published var followingStatus: [String: Bool] = [:]
    @Published var isUsingCache = false
    
    private let cacheManager = AppCacheManager.shared
    
    func searchUsers(query: String, currentUserId: String) {
        print("🔍 FindFriendsViewModel: Starting search for '\(query)' with userId '\(currentUserId)'")
        isLoading = true
        
        // First, try to load from cache for instant display
        if let cachedUsers = cacheManager.getCachedAllUsers() {
            let filteredUsers = cachedUsers.filter { user in
                user.name.lowercased().contains(query.lowercased())
            }
            
            if !filteredUsers.isEmpty {
                DispatchQueue.main.async {
                    self.searchResults = filteredUsers
                    self.isLoading = false
                    self.isUsingCache = true
                    print("✅ Loaded \(filteredUsers.count) users from cache")
                    
                    // Check follow status for each user
                    self.checkFollowStatus(for: filteredUsers, currentUserId: currentUserId)
                }
            }
        }
        
        // Then fetch fresh data in background
        Task {
            do {
                let results = try await SocialService.shared.searchUsers(query: query, currentUserId: currentUserId)
                
                await MainActor.run {
                    print("🔍 FindFriendsViewModel: Got \(results.count) results")
                    // Only update if we got new data or cache was empty
                    if self.searchResults.isEmpty || !self.isUsingCache {
                        self.searchResults = results
                    }
                    self.isLoading = false
                    self.isUsingCache = false
                    
                    // Check follow status for each user
                    self.checkFollowStatus(for: results, currentUserId: currentUserId)
                    
                    // Save all users to cache for future searches
                    self.cacheManager.saveAllUsers(results)
                }
            } catch {
                await MainActor.run {
                    print("❌ FindFriendsViewModel: Error occurred, clearing results")
                    if !self.isUsingCache {
                        self.searchResults = []
                    }
                    self.isLoading = false
                    self.isUsingCache = false
                }
                print("❌ FindFriendsViewModel: Error searching users: \(error)")
            }
        }
    }
    
    private func checkFollowStatus(for users: [UserSearchResult], currentUserId: String) {
        Task {
            for user in users {
                do {
                    let isFollowing = try await SocialService.shared.isFollowing(
                        followerId: currentUserId,
                        followingId: user.id
                    )
                    
                    await MainActor.run {
                        self.followingStatus[user.id] = isFollowing
                    }
                } catch {
                    print("Error checking follow status for user \(user.id): \(error)")
                }
            }
        }
    }
    
    func toggleFollow(followerId: String, followingId: String) {
        let isCurrentlyFollowing = followingStatus[followingId] ?? false
        
        Task {
            do {
                if isCurrentlyFollowing {
                    try await SocialService.shared.unfollowUser(followerId: followerId, followingId: followingId)
                    print("✅ Unfollowed user \(followingId)")
                } else {
                    try await SocialService.shared.followUser(followerId: followerId, followingId: followingId)
                    print("✅ Followed user \(followingId)")
                }
                
                await MainActor.run {
                    self.followingStatus[followingId] = !isCurrentlyFollowing
                    
                    // Notify that profile stats should be updated
                    NotificationCenter.default.post(name: .profileStatsUpdated, object: nil)
                }
            } catch {
                print("❌ Error toggling follow: \(error)")
            }
        }
    }
}

#Preview {
    FindFriendsView()
        .environmentObject(AuthViewModel())
}
