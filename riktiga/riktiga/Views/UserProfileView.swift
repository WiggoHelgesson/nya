import SwiftUI

struct UserProfileView: View {
    let userId: String
    
    @State private var username: String = ""
    @State private var avatarUrl: String? = nil
    @State private var followersCount: Int = 0
    @State private var followingCount: Int = 0
    @State private var posts: [WorkoutPost] = []
    @State private var isLoading: Bool = true
    @State private var pb5km: String? = nil
    @State private var pb10km: String? = nil
    @State private var pbMarathon: String? = nil
    @State private var isFollowingUser: Bool = false
    @State private var followToggleInProgress: Bool = false
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var authViewModel: AuthViewModel
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 12) {
                HStack(spacing: 12) {
                    LocalAsyncImage(path: avatarUrl ?? "")
                        .frame(width: 72, height: 72)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color(.systemGray5), lineWidth: 1))
                        .opacity((avatarUrl ?? "").isEmpty ? 0 : 1)
                        .overlay(
                            Group {
                                if (avatarUrl ?? "").isEmpty {
                                    Image(systemName: "person.circle.fill")
                                        .resizable()
                                        .scaledToFill()
                                        .foregroundColor(.gray)
                                        .frame(width: 72, height: 72)
                                }
                            }
                        )
                    
                    VStack(alignment: .leading, spacing: 6) {
                        Text(username.isEmpty ? "Användare" : username)
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.black)
                        HStack(spacing: 16) {
                            HStack(spacing: 4) {
                                Text("Följare")
                                    .font(.system(size: 12))
                                    .foregroundColor(.gray)
                                Text("\(followersCount)")
                                    .font(.system(size: 14, weight: .semibold))
                            }
                            HStack(spacing: 4) {
                                Text("Följer")
                                    .font(.system(size: 12))
                                    .foregroundColor(.gray)
                                Text("\(followingCount)")
                                    .font(.system(size: 14, weight: .semibold))
                            }
                        }
                    }
                    Spacer()

                    if let currentUser = authViewModel.currentUser, currentUser.id != userId {
                        Button(action: toggleFollow) {
                            HStack(spacing: 6) {
                                if followToggleInProgress {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                        .tint(.white)
                                }
                                Text(isFollowingUser ? "Följer" : "Följ")
                                    .font(.system(size: 14, weight: .semibold))
                            }
                            .frame(width: 96, height: 36)
                            .background(isFollowingUser ? Color(.systemGray5) : AppColors.brandBlue)
                            .foregroundColor(isFollowingUser ? .black : .white)
                            .cornerRadius(10)
                        }
                        .disabled(followToggleInProgress)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 12)
                .background(Color.white)
                Divider()
                
                // Personal Bests Section
                if (pb5km ?? "").isEmpty && (pb10km ?? "").isEmpty && (pbMarathon ?? "").isEmpty {
                    EmptyView()
                } else {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Personliga rekord")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.black)
                            .padding(.horizontal, 16)
                            .padding(.top, 12)
                        
                        HStack(spacing: 12) {
                            if let pb5km = pb5km, !pb5km.isEmpty {
                                VStack(alignment: .center, spacing: 4) {
                                    Label("5K", systemImage: "figure.run")
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundColor(.gray)
                                    Text(pb5km)
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(.black)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(8)
                                .background(Color(.systemGray6))
                                .cornerRadius(8)
                            }
                            
                            if let pb10km = pb10km, !pb10km.isEmpty {
                                VStack(alignment: .center, spacing: 4) {
                                    Label("10K", systemImage: "figure.run")
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundColor(.gray)
                                    Text(pb10km)
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(.black)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(8)
                                .background(Color(.systemGray6))
                                .cornerRadius(8)
                            }
                            
                            if let pbMarathon = pbMarathon, !pbMarathon.isEmpty {
                                VStack(alignment: .center, spacing: 4) {
                                    Label("Marathon", systemImage: "figure.run")
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundColor(.gray)
                                    Text(pbMarathon)
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundColor(.black)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(8)
                                .background(Color(.systemGray6))
                                .cornerRadius(8)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 12)
                    }
                    .background(Color.white)
                    Divider()
                }
            }
            
            // Posts list
            if isLoading {
                VStack(spacing: 16) {
                    ProgressView().tint(AppColors.brandBlue)
                    Text("Laddar profil...")
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 16) {
                        ForEach(posts) { post in
                            WorkoutPostCard(post: post)
                        }
                    }
                    .padding(16)
                }
            }
        }
        .navigationTitle("Profil")
        .navigationBarTitleDisplayMode(.inline)
        .task { await loadData() }
    }
    
    private func loadData() async {
        isLoading = true
        // Profile
        if let profile = try? await ProfileService.shared.fetchUserProfile(userId: userId) {
            await MainActor.run {
                self.username = profile.name
                self.avatarUrl = profile.avatarUrl
                self.pb5km = formattedFiveKm(from: profile)
                self.pb10km = formattedDistance(hours: profile.pb10kmHours, minutes: profile.pb10kmMinutes)
                self.pbMarathon = formattedDistance(hours: profile.pbMarathonHours, minutes: profile.pbMarathonMinutes)
            }
        }
        
        // Followers/following counts
        async let followersIdsTask = SocialService.shared.getFollowers(userId: userId)
        async let followingIdsTask = SocialService.shared.getFollowing(userId: userId)
        // Posts
        async let postsTask = WorkoutService.shared.fetchUserWorkoutPosts(userId: userId)
        
        let followersIds = (try? await followersIdsTask) ?? []
        let followingIds = (try? await followingIdsTask) ?? []
        let fetchedPosts = (try? await postsTask) ?? []
        
        await MainActor.run {
            self.followersCount = followersIds.count
            self.followingCount = followingIds.count
            self.posts = fetchedPosts
            self.isLoading = false
            if let currentUserId = authViewModel.currentUser?.id, currentUserId != userId {
                self.isFollowingUser = followersIds.contains(currentUserId)
            } else {
                self.isFollowingUser = false
            }
        }
    }
    
    private func toggleFollow() {
        guard let currentUser = authViewModel.currentUser else { return }
        guard !followToggleInProgress else { return }
        followToggleInProgress = true
        Task {
            do {
                if isFollowingUser {
                    try await SocialService.shared.unfollowUser(followerId: currentUser.id, followingId: userId)
                    await MainActor.run {
                        self.isFollowingUser = false
                        self.followersCount = max(0, self.followersCount - 1)
                    }
                } else {
                    try await SocialService.shared.followUser(followerId: currentUser.id, followingId: userId)
                    await MainActor.run {
                        self.isFollowingUser = true
                        self.followersCount += 1
                    }
                }
            } catch {
                print("❌ Error toggling follow: \(error)")
            }
            await MainActor.run {
                self.followToggleInProgress = false
            }
        }
    }
}

private extension UserProfileView {
    func formattedFiveKm(from user: User) -> String? {
        guard let minutes = user.pb5kmMinutes else { return nil }
        return "\(minutes) min"
    }
    
    func formattedDistance(hours: Int?, minutes: Int?) -> String? {
        guard let minutes = minutes else { return nil }
        let safeHours = hours ?? 0
        if safeHours == 0 {
            return "\(minutes) min"
        } else {
            return "\(safeHours) h \(minutes) min"
        }
    }
}
