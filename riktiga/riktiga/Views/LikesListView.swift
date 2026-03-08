import SwiftUI

struct LikesListView: View {
    let postId: String
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var likers: [UserSearchResult] = []
    @State private var followingIds: Set<String> = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView(L.t(sv: "Laddar gillningar...", nb: "Laster likerklikk..."))
                        .tint(.gray)
                } else if let errorMessage {
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 44))
                            .foregroundColor(.orange)
                        Text(errorMessage)
                            .font(.system(size: 16, weight: .medium))
                            .multilineTextAlignment(.center)
                            .foregroundColor(.gray)
                        Button(L.t(sv: "Försök igen", nb: "Prøv igjen")) {
                            Task { await loadData() }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding()
                } else if likers.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "hand.thumbsup")
                            .font(.system(size: 48))
                            .foregroundColor(.gray)
                        Text(L.t(sv: "Inga gillningar ännu", nb: "Ingen likerklikk ennå"))
                            .font(.title3)
                            .fontWeight(.semibold)
                        Text(L.t(sv: "När någon gillar det här passet visas de här.", nb: "Når noen liker denne økten, vises de her."))
                            .font(.body)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }
                } else {
                    List {
                        Section {
                            ForEach(likers) { liker in
                                LikeUserRow(
                                    user: liker,
                                    isFollowing: followingIds.contains(liker.id),
                                    isCurrentUser: liker.id == authViewModel.currentUser?.id,
                                    onFollowToggle: {
                                        Task {
                                            await toggleFollow(for: liker.id)
                                        }
                                    }
                                )
                            }
                        } header: {
                            Text(L.t(sv: "ANDRA ATLETER", nb: "ANDRE UTØVERE"))
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.secondary)
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .padding(.top, isLoading || likers.isEmpty ? 40 : 0)
            .navigationTitle(L.t(sv: "Gillningar", nb: "Likerklikk"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "chevron.left")
                            .foregroundColor(.primary)
                            .frame(width: 32, height: 32)
                            .background(Color(.systemGray5))
                            .clipShape(Circle())
                    }
                }
            }
            .task {
                await loadData()
            }
        }
    }
    
    private func loadData() async {
        guard let currentUserId = authViewModel.currentUser?.id else {
            await MainActor.run {
                errorMessage = L.t(sv: "Du behöver vara inloggad för att se gillningar.", nb: "Du må være innlogget for å se likerklikk.")
                isLoading = false
            }
            return
        }
        
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }
        
        do {
            async let likersTask = SocialService.shared.getAllPostLikers(postId: postId)
            async let followingTask = SocialService.shared.getFollowing(userId: currentUserId)
            
            let likers = try await likersTask
            let followingIds = try await followingTask
            
            await MainActor.run {
                self.likers = likers
                self.followingIds = Set(followingIds)
                self.isLoading = false
                ImageCacheManager.shared.prefetch(urls: likers.compactMap { $0.avatarUrl })
            }
        } catch {
            await MainActor.run {
                self.errorMessage = L.t(sv: "Kunde inte hämta listan just nu.", nb: "Kunne ikke hente listen akkurat nå.")
                self.isLoading = false
            }
        }
    }
    
    private func toggleFollow(for userId: String) async {
        guard let currentUserId = authViewModel.currentUser?.id else { return }
        let isCurrentlyFollowing = followingIds.contains(userId)
        
        do {
            if isCurrentlyFollowing {
                try await SocialService.shared.unfollowUser(followerId: currentUserId, followingId: userId)
            } else {
                try await SocialService.shared.followUser(followerId: currentUserId, followingId: userId)
            }
            
            await MainActor.run {
                if isCurrentlyFollowing {
                    followingIds.remove(userId)
                } else {
                    followingIds.insert(userId)
                }
            }
        } catch {
            await MainActor.run {
                self.errorMessage = L.t(sv: "Kunde inte uppdatera följ-status. Försök igen.", nb: "Kunne ikke oppdatere følgestatus. Prøv igjen.")
            }
        }
    }
}

private struct LikeUserRow: View {
    let user: UserSearchResult
    let isFollowing: Bool
    let isCurrentUser: Bool
    let onFollowToggle: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            NavigationLink(destination: UserProfileView(userId: user.id)) {
                HStack(spacing: 12) {
                    ProfileImage(url: user.avatarUrl, size: 48)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(user.name)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.primary)
                        Text("@\(user.name.lowercased())")
                            .font(.system(size: 13))
                            .foregroundColor(.gray)
                    }
                }
            }
            
            Spacer()
            
            if !isCurrentUser {
                Button(action: onFollowToggle) {
                    Text(isFollowing ? L.t(sv: "Avfölj", nb: "Slutt å følge") : L.t(sv: "Följ", nb: "Følg"))
                        .font(.system(size: 14, weight: .semibold))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            Capsule()
                                .stroke(isFollowing ? Color.red : Color.clear, lineWidth: isFollowing ? 1 : 0)
                        )
                        .background(
                            Capsule()
                                .fill(isFollowing ? Color(.systemGray6) : Color.black)
                        )
                        .foregroundColor(isFollowing ? .red : .white)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 6)
    }
}

#Preview {
    LikesListView(postId: "preview")
        .environmentObject(AuthViewModel())
}

