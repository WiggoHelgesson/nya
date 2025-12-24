import SwiftUI

// MARK: - News Item View (Twitter-like design)
struct NewsItemView: View {
    let news: NewsItem
    var isAdmin: Bool = false
    var onEdit: ((NewsItem) -> Void)? = nil
    var onDelete: ((NewsItem) -> Void)? = nil
    var onLike: ((NewsItem, Bool) -> Void)? = nil
    
    @State private var showDeleteConfirmation = false
    @State private var showOptionsMenu = false
    @State private var isLiked: Bool = false
    @State private var likeCount: Int = 0
    @State private var likeInProgress = false
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Avatar
            if let avatarUrl = news.authorAvatarUrl, !avatarUrl.isEmpty {
                LocalAsyncImage(path: avatarUrl)
                    .frame(width: 48, height: 48)
                    .clipShape(Circle())
            } else {
                // Default Up&Down logo/avatar
                Image("23")
                    .resizable()
                    .scaledToFill()
                    .frame(width: 48, height: 48)
                    .clipShape(Circle())
            }
            
            VStack(alignment: .leading, spacing: 4) {
                // Header with name and time
                HStack(spacing: 4) {
                    Text(news.authorName)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.primary)
                    
                    // Verified badge for official account
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.blue)
                    
                    Text("@upanddown")
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                    
                    Text("·")
                        .foregroundColor(.gray)
                    
                    Text(news.formattedDate)
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                    
                    Spacer()
                    
                    // Admin menu button
                    if isAdmin {
                        Menu {
                            Button(action: {
                                onEdit?(news)
                            }) {
                                Label("Redigera", systemImage: "pencil")
                            }
                            
                            Button(role: .destructive, action: {
                                showDeleteConfirmation = true
                            }) {
                                Label("Radera", systemImage: "trash")
                            }
                        } label: {
                            Image(systemName: "ellipsis")
                                .font(.system(size: 16))
                                .foregroundColor(.gray)
                                .padding(8)
                        }
                    }
                }
                
                // Content
                Text(news.content)
                    .font(.system(size: 15))
                    .foregroundColor(.primary)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
                
                // Optional image
                if let imageUrl = news.imageUrl, !imageUrl.isEmpty {
                    LocalAsyncImage(path: imageUrl)
                        .frame(maxWidth: .infinity)
                        .frame(height: 200)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .padding(.top, 8)
                }
                
                // Like button row (Twitter-style)
                HStack(spacing: 20) {
                    // Like button
                    Button(action: toggleLike) {
                        HStack(spacing: 6) {
                            Image(systemName: isLiked ? "heart.fill" : "heart")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(isLiked ? .red : .gray)
                            
                            if likeCount > 0 {
                                Text("\(likeCount)")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                    .disabled(likeInProgress)
                    
                    Spacer()
                }
                .padding(.top, 12)
            }
            
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(.systemBackground))
        .onAppear {
            isLiked = news.isLikedByCurrentUser ?? false
            likeCount = news.likeCount ?? 0
        }
        .onChange(of: news.isLikedByCurrentUser) { newValue in
            isLiked = newValue ?? false
        }
        .onChange(of: news.likeCount) { newValue in
            likeCount = newValue ?? 0
        }
        .alert("Radera nyhet", isPresented: $showDeleteConfirmation) {
            Button("Avbryt", role: .cancel) { }
            Button("Radera", role: .destructive) {
                onDelete?(news)
            }
        } message: {
            Text("Är du säker på att du vill radera denna nyhet?")
        }
    }
    
    private func toggleLike() {
        guard !likeInProgress else { return }
        likeInProgress = true
        
        // Optimistic update
        let newLikedState = !isLiked
        isLiked = newLikedState
        likeCount += newLikedState ? 1 : -1
        likeCount = max(0, likeCount)
        
        // Notify parent to handle the actual like/unlike
        onLike?(news, newLikedState)
        
        // Reset progress after a short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            likeInProgress = false
        }
    }
}

// MARK: - Preview
#Preview {
    VStack(spacing: 0) {
        NewsItemView(news: NewsItem(
            id: "1",
            content: "🎉 Ny uppdatering! Nu kan du se dina vänners träningspass i realtid och tävla om territorier på kartan. Ladda ner senaste versionen nu!",
            authorId: "admin",
            authorName: "Up&Down",
            authorAvatarUrl: nil,
            createdAt: ISO8601DateFormatter().string(from: Date()),
            imageUrl: nil,
            likeCount: 42,
            isLikedByCurrentUser: false
        ))
        
        Divider()
        
        NewsItemView(news: NewsItem(
            id: "2",
            content: "💪 Grattis till alla som deltog i veckans utmaning! Över 500 användare sprang sammanlagt 2000 km. Ni är fantastiska!",
            authorId: "admin",
            authorName: "Up&Down",
            authorAvatarUrl: nil,
            createdAt: ISO8601DateFormatter().string(from: Date().addingTimeInterval(-3600)),
            imageUrl: nil,
            likeCount: 128,
            isLikedByCurrentUser: true
        ))
    }
}

