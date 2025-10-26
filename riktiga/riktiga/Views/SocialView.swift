import SwiftUI
import Combine

struct SocialView: View {
    @StateObject private var socialViewModel = SocialViewModel()
    @EnvironmentObject var authViewModel: AuthViewModel
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemBackground).ignoresSafeArea()
                
                if socialViewModel.posts.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "person.2.fill")
                            .font(.system(size: 48))
                            .foregroundColor(.gray)
                        Text("Inga inlägg från dina vänner")
                            .font(.headline)
                        Text("Följ några vänner för att se deras träningspass")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                } else {
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            ForEach(socialViewModel.posts) { post in
                                SocialPostCard(post: post)
                            }
                        }
                        .padding(16)
                    }
                }
            }
            .navigationTitle("Socialt")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                if let userId = authViewModel.currentUser?.id {
                    socialViewModel.fetchSocialFeed(userId: userId)
                }
            }
            .refreshable {
                if let userId = authViewModel.currentUser?.id {
                    await socialViewModel.refreshSocialFeed(userId: userId)
                }
            }
        }
    }
}

struct SocialPostCard: View {
    let post: SocialWorkoutPost
    @State private var showComments = false
    @State private var isLiked = false
    @State private var likeCount = 0
    @State private var commentCount = 0
    @EnvironmentObject var authViewModel: AuthViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header with user info
            HStack(spacing: 12) {
                // User avatar
                AsyncImage(url: URL(string: post.userAvatarUrl ?? "")) { image in
                    image
                        .resizable()
                        .scaledToFill()
                } placeholder: {
                    Image(systemName: "person.circle.fill")
                        .foregroundColor(.gray)
                }
                .frame(width: 40, height: 40)
                .clipShape(Circle())
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(post.userName ?? "Okänd användare")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.black)
                    
                    Text(formatDate(post.createdAt))
                        .font(.system(size: 13))
                        .foregroundColor(.gray)
                    
                    if let location = post.location {
                        Text(location)
                            .font(.system(size: 13))
                            .foregroundColor(.gray)
                    }
                }
                
                Spacer()
                
                Button(action: {}) {
                    Image(systemName: "ellipsis")
                        .foregroundColor(.black)
                        .font(.system(size: 16))
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 8)
            
            // Large image
            if let imageUrl = post.imageUrl, !imageUrl.isEmpty {
                AsyncImage(url: URL(string: imageUrl)) { image in
                    image
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: .infinity, maxHeight: 400)
                        .clipped()
                } placeholder: {
                    Rectangle()
                        .fill(Color(.systemGray5))
                        .frame(height: 300)
                        .overlay(
                            ProgressView()
                        )
                }
            }
            
            // Content below image
            VStack(alignment: .leading, spacing: 12) {
                // Title with PRO badge
                HStack(spacing: 8) {
                    Text(post.title)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.black)
                    
                    if let isPro = post.userIsPro, isPro {
                        Text("PRO")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.black)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(Color.yellow)
                            .cornerRadius(4)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                
                // Stats row with white background
                HStack(spacing: 0) {
                    if let distance = post.distance {
                        VStack(spacing: 6) {
                            Text("Distans")
                                .font(.system(size: 11))
                                .foregroundColor(.gray)
                            Text(String(format: "%.2f km", distance))
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.black)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                    }
                    
                    if let duration = post.duration {
                        if post.distance != nil {
                            Divider()
                                .frame(height: 40)
                        }
                        
                        VStack(spacing: 6) {
                            Text("Tid")
                                .font(.system(size: 11))
                                .foregroundColor(.gray)
                            Text(formatDuration(duration))
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.black)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                    }
                    
                    if let strokes = post.strokes {
                        if post.distance != nil || post.duration != nil {
                            Divider()
                                .frame(height: 40)
                        }
                        
                        VStack(spacing: 6) {
                            Text("Slag")
                                .font(.system(size: 11))
                                .foregroundColor(.gray)
                            Text("\(strokes)")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.black)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                    }
                }
                .background(Color.white)
                .cornerRadius(12)
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }
        }
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
        .onAppear {
            isLiked = post.isLikedByCurrentUser ?? false
            likeCount = post.likeCount ?? 0
            commentCount = post.commentCount ?? 0
        }
        .sheet(isPresented: $showComments) {
            CommentsView(postId: post.id)
        }
    }
    
    private func toggleLike() {
        guard let userId = authViewModel.currentUser?.id else { return }
        
        Task {
            do {
                if isLiked {
                    try await SocialService.shared.unlikePost(postId: post.id, userId: userId)
                    await MainActor.run {
                        isLiked = false
                        likeCount = max(0, likeCount - 1)
                    }
                } else {
                    try await SocialService.shared.likePost(postId: post.id, userId: userId)
                    await MainActor.run {
                        isLiked = true
                        likeCount += 1
                    }
                }
            } catch {
                print("Error toggling like: \(error)")
            }
        }
    }
    
    func getActivityIcon(_ activity: String) -> String {
        switch activity {
        case "Löppass":
            return "figure.run"
        case "Golfrunda":
            return "flag.fill"
        case "Promenad":
            return "figure.walk"
        case "Bestiga berg":
            return "mountain.2.fill"
        default:
            return "figure.walk"
        }
    }
    
    func formatDate(_ dateString: String) -> String {
        let formatter = ISO8601DateFormatter()
        if let date = formatter.date(from: dateString) {
            let calendar = Calendar.current
            if calendar.isDateInToday(date) {
                let timeFormatter = DateFormatter()
                timeFormatter.timeStyle = .short
                return timeFormatter.string(from: date)
            } else if calendar.isDateInYesterday(date) {
                return "Igår"
            } else {
                let dateFormatter = DateFormatter()
                dateFormatter.dateStyle = .short
                return dateFormatter.string(from: date)
            }
        }
        return dateString
    }
    
    func formatDuration(_ seconds: Int) -> String {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        let secs = seconds % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        } else {
            return String(format: "%02d:%02d", minutes, secs)
        }
    }
}

struct CommentsView: View {
    let postId: String
    @StateObject private var commentsViewModel = CommentsViewModel()
    @State private var newComment = ""
    @EnvironmentObject var authViewModel: AuthViewModel
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Comments list
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(commentsViewModel.comments) { comment in
                            CommentRow(comment: comment)
                        }
                    }
                    .padding(16)
                }
                
                // Add comment section
                VStack(spacing: 12) {
                    Divider()
                    
                    HStack(spacing: 12) {
                        TextField("Skriv en kommentar...", text: $newComment)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                        
                        Button("Skicka") {
                            addComment()
                        }
                        .disabled(newComment.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                    .padding(16)
                }
                .background(Color(.systemBackground))
            }
            .navigationTitle("Kommentarer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Stäng") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                commentsViewModel.fetchComments(postId: postId)
            }
        }
    }
    
    private func addComment() {
        guard let userId = authViewModel.currentUser?.id,
              !newComment.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        Task {
            do {
                try await SocialService.shared.addComment(
                    postId: postId,
                    userId: userId,
                    content: newComment.trimmingCharacters(in: .whitespacesAndNewlines)
                )
                await MainActor.run {
                    newComment = ""
                    commentsViewModel.fetchComments(postId: postId)
                }
            } catch {
                print("Error adding comment: \(error)")
            }
        }
    }
}

struct CommentRow: View {
    let comment: PostComment
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // User avatar placeholder
            Circle()
                .fill(Color(.systemGray5))
                .frame(width: 32, height: 32)
                .overlay(
                    Image(systemName: "person.fill")
                        .foregroundColor(.gray)
                        .font(.system(size: 14))
                )
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Användare") // TODO: Get actual username
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.black)
                
                Text(comment.content)
                    .font(.system(size: 14))
                    .foregroundColor(.black)
                    .lineLimit(nil)
                
                Text(formatDate(comment.createdAt))
                    .font(.system(size: 12))
                    .foregroundColor(.gray)
            }
            
            Spacer()
        }
    }
    
    func formatDate(_ dateString: String) -> String {
        let formatter = ISO8601DateFormatter()
        if let date = formatter.date(from: dateString) {
            let timeFormatter = DateFormatter()
            timeFormatter.timeStyle = .short
            return timeFormatter.string(from: date)
        }
        return dateString
    }
}

class SocialViewModel: ObservableObject {
    @Published var posts: [SocialWorkoutPost] = []
    
    func fetchSocialFeed(userId: String) {
        Task {
            do {
                let fetchedPosts = try await SocialService.shared.getSocialFeed(userId: userId)
                await MainActor.run {
                    self.posts = fetchedPosts
                }
            } catch {
                print("Error fetching social feed: \(error)")
            }
        }
    }
    
    func refreshSocialFeed(userId: String) async {
        do {
            let fetchedPosts = try await SocialService.shared.getSocialFeed(userId: userId)
            await MainActor.run {
                self.posts = fetchedPosts
            }
        } catch {
            print("Error refreshing social feed: \(error)")
        }
    }
}

class CommentsViewModel: ObservableObject {
    @Published var comments: [PostComment] = []
    
    func fetchComments(postId: String) {
        Task {
            do {
                let fetchedComments = try await SocialService.shared.getPostComments(postId: postId)
                await MainActor.run {
                    self.comments = fetchedComments
                }
            } catch {
                print("Error fetching comments: \(error)")
            }
        }
    }
}

#Preview {
    SocialView()
        .environmentObject(AuthViewModel())
}
