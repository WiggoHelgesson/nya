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
                        .frame(width: 40, height: 40)
                        .clipShape(Circle())
                } placeholder: {
                    Circle()
                        .fill(Color(.systemGray5))
                        .frame(width: 40, height: 40)
                        .overlay(
                            Image(systemName: "person.fill")
                                .foregroundColor(.gray)
                        )
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(post.userName ?? "Okänd användare")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.black)
                    
                    Text(formatDate(post.createdAt))
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                // Activity type icon
                Image(systemName: getActivityIcon(post.activityType))
                    .font(.system(size: 18))
                    .foregroundColor(AppColors.brandBlue)
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            
            // Post content
            VStack(alignment: .leading, spacing: 12) {
                // Title
                Text(post.title)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.black)
                    .padding(.horizontal, 16)
                
                // Stats row
                HStack(spacing: 24) {
                    if let distance = post.distance {
                        HStack(spacing: 6) {
                            Image(systemName: "location.fill")
                                .font(.system(size: 14))
                                .foregroundColor(AppColors.brandGreen)
                            Text(String(format: "%.2f km", distance))
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.black)
                        }
                    }
                    
                    if let duration = post.duration {
                        HStack(spacing: 6) {
                            Image(systemName: "clock.fill")
                                .font(.system(size: 14))
                                .foregroundColor(AppColors.brandBlue)
                            Text(formatDuration(duration))
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.black)
                        }
                    }
                    
                    Spacer()
                }
                .padding(.horizontal, 16)
                
                // Description
                if let description = post.description, !description.isEmpty {
                    Text(description)
                        .font(.system(size: 15))
                        .foregroundColor(.black)
                        .lineLimit(nil)
                        .padding(.horizontal, 16)
                }
                
                // Image if available
                if let imageUrl = post.imageUrl, !imageUrl.isEmpty {
                    AsyncImage(url: URL(string: imageUrl)) { image in
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(maxHeight: 300)
                            .clipped()
                    } placeholder: {
                        Rectangle()
                            .fill(Color(.systemGray5))
                            .frame(height: 200)
                            .overlay(
                                Image(systemName: "photo")
                                    .foregroundColor(.gray)
                                    .font(.system(size: 24))
                            )
                    }
                    .padding(.horizontal, 16)
                }
            }
            
            // Action buttons
            HStack(spacing: 24) {
                // Like button
                Button(action: {
                    toggleLike()
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: isLiked ? "heart.fill" : "heart")
                            .font(.system(size: 16))
                            .foregroundColor(isLiked ? .red : .gray)
                        
                        Text("\(likeCount)")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.gray)
                    }
                }
                
                // Comment button
                Button(action: {
                    showComments = true
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "bubble.left")
                            .font(.system(size: 16))
                            .foregroundColor(.gray)
                        
                        Text("\(commentCount)")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.gray)
                    }
                }
                
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(Color.white)
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
