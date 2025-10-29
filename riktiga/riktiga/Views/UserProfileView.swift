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
    @Environment(\.dismiss) private var dismiss
    
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
        }
    }
}
