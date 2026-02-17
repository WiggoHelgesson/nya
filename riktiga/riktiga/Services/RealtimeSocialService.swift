import Foundation
import Supabase
import Combine

/// Service for real-time updates on social features (likes, comments)
@MainActor
class RealtimeSocialService: ObservableObject {
    static let shared = RealtimeSocialService()
    private let supabase = SupabaseConfig.supabase
    
    // Publishers for real-time events
    @Published var postLikeUpdated: (postId: String, delta: Int, userId: String)? = nil
    @Published var commentAdded: (postId: String, comment: PostComment)? = nil
    @Published var commentDeleted: (postId: String, commentId: String)? = nil
    @Published var commentLikeUpdated: (commentId: String, delta: Int, userId: String)? = nil
    
    private var postLikesChannel: RealtimeChannelV2?
    private var commentsChannel: RealtimeChannelV2?
    private var commentLikesChannel: RealtimeChannelV2?
    
    // Track whether we're already listening to prevent duplicate subscriptions
    private var isListening = false
    
    private init() {
        print("🔴 RealtimeSocialService initialized")
    }
    
    // MARK: - Start Listening
    
    /// Start listening to all social real-time updates
    func startListening() {
        // Prevent duplicate subscriptions
        guard !isListening else {
            print("🔴 Already listening - skipping duplicate startListening call")
            return
        }
        isListening = true
        print("🔴 Starting real-time social updates...")
        setupPostLikesChannel()
        setupCommentsChannel()
        setupCommentLikesChannel()
    }
    
    /// Stop all real-time channels
    func stopListening() {
        guard isListening else { return }
        isListening = false
        print("🔴 Stopping real-time social updates...")
        Task {
            if let channel = postLikesChannel {
                await supabase.removeChannel(channel)
                postLikesChannel = nil
            }
            if let channel = commentsChannel {
                await supabase.removeChannel(channel)
                commentsChannel = nil
            }
            if let channel = commentLikesChannel {
                await supabase.removeChannel(channel)
                commentLikesChannel = nil
            }
        }
    }
    
    // MARK: - Post Likes Channel
    
    private func setupPostLikesChannel() {
        // Remove existing channel first
        if let existing = postLikesChannel {
            Task { await supabase.removeChannel(existing) }
            postLikesChannel = nil
        }
        
        Task {
            do {
                let channel = await supabase.channel("post-likes-realtime")
                
                let insertChanges = await channel.postgresChange(
                    InsertAction.self,
                    schema: "public",
                    table: "workout_post_likes"
                )
                
                let deleteChanges = await channel.postgresChange(
                    DeleteAction.self,
                    schema: "public",
                    table: "workout_post_likes"
                )
                
                await channel.subscribe()
                
                postLikesChannel = channel
                print("✅ Post likes channel subscribed")
                
                // Listen for inserts (new likes)
                Task {
                    for await change in insertChanges {
                        guard let postId = extractString(from: change.record, key: "workout_post_id"),
                              let userId = extractString(from: change.record, key: "user_id") else {
                            print("⚠️ Could not parse like insert event")
                            continue
                        }
                        print("🔴 Real-time: Post \(postId) liked by \(userId)")
                        await MainActor.run {
                            self.postLikeUpdated = (postId: postId, delta: 1, userId: userId)
                        }
                    }
                }
                
                // Listen for deletes (unlikes)
                Task {
                    for await change in deleteChanges {
                        guard let postId = extractString(from: change.oldRecord, key: "workout_post_id"),
                              let userId = extractString(from: change.oldRecord, key: "user_id") else {
                            print("⚠️ Could not parse like delete event")
                            continue
                        }
                        print("🔴 Real-time: Post \(postId) unliked by \(userId)")
                        await MainActor.run {
                            self.postLikeUpdated = (postId: postId, delta: -1, userId: userId)
                        }
                    }
                }
                
            } catch {
                print("❌ Error setting up post likes channel: \(error)")
            }
        }
    }
    
    // MARK: - Comments Channel
    
    private func setupCommentsChannel() {
        // Remove existing channel first
        if let existing = commentsChannel {
            Task { await supabase.removeChannel(existing) }
            commentsChannel = nil
        }
        
        Task {
            do {
                let channel = await supabase.channel("comments-realtime")
                
                let insertChanges = await channel.postgresChange(
                    InsertAction.self,
                    schema: "public",
                    table: "workout_post_comments"
                )
                
                let deleteChanges = await channel.postgresChange(
                    DeleteAction.self,
                    schema: "public",
                    table: "workout_post_comments"
                )
                
                await channel.subscribe()
                
                commentsChannel = channel
                print("✅ Comments channel subscribed")
                
                // Listen for inserts (new comments)
                Task {
                    for await change in insertChanges {
                        guard let commentId = extractString(from: change.record, key: "id"),
                              let postId = extractString(from: change.record, key: "workout_post_id"),
                              let userId = extractString(from: change.record, key: "user_id"),
                              let content = extractString(from: change.record, key: "content"),
                              let createdAt = extractString(from: change.record, key: "created_at") else {
                            print("⚠️ Could not parse comment insert event")
                            continue
                        }
                        
                        let parentCommentId = extractString(from: change.record, key: "parent_comment_id")
                        
                        print("🔴 Real-time: New comment on post \(postId)")
                        
                        // Fetch user profile for the comment - with fallback if it fails
                        var userName: String? = nil
                        var userAvatarUrl: String? = nil
                        
                        do {
                            struct UserProfile: Decodable {
                                let username: String?
                                let avatar_url: String?
                            }
                            
                            let profiles: [UserProfile] = try await supabase
                                .from("profiles")
                                .select("username, avatar_url")
                                .eq("id", value: userId)
                                .execute()
                                .value
                            
                            userName = profiles.first?.username
                            userAvatarUrl = profiles.first?.avatar_url
                        } catch {
                            print("⚠️ Failed to fetch user profile for comment - using fallback: \(error)")
                            // Continue without profile info - the comment will still be displayed
                        }
                        
                        let comment = PostComment(
                            id: commentId,
                            postId: postId,
                            userId: userId,
                            content: content,
                            createdAt: createdAt,
                            userName: userName,
                            userAvatarUrl: userAvatarUrl,
                            parentCommentId: parentCommentId,
                            likeCount: 0,
                            isLikedByCurrentUser: false
                        )
                        
                        await MainActor.run {
                            self.commentAdded = (postId: postId, comment: comment)
                        }
                    }
                }
                
                // Listen for deletes (removed comments)
                Task {
                    for await change in deleteChanges {
                        guard let commentId = extractString(from: change.oldRecord, key: "id"),
                              let postId = extractString(from: change.oldRecord, key: "workout_post_id") else {
                            print("⚠️ Could not parse comment delete event")
                            continue
                        }
                        print("🔴 Real-time: Comment \(commentId) deleted from post \(postId)")
                        await MainActor.run {
                            self.commentDeleted = (postId: postId, commentId: commentId)
                        }
                    }
                }
                
            } catch {
                print("❌ Error setting up comments channel: \(error)")
            }
        }
    }
    
    // MARK: - Comment Likes Channel
    
    private func setupCommentLikesChannel() {
        // Remove existing channel first
        if let existing = commentLikesChannel {
            Task { await supabase.removeChannel(existing) }
            commentLikesChannel = nil
        }
        
        Task {
            do {
                let channel = await supabase.channel("comment-likes-realtime")
                
                let insertChanges = await channel.postgresChange(
                    InsertAction.self,
                    schema: "public",
                    table: "comment_likes"
                )
                
                let deleteChanges = await channel.postgresChange(
                    DeleteAction.self,
                    schema: "public",
                    table: "comment_likes"
                )
                
                await channel.subscribe()
                
                commentLikesChannel = channel
                print("✅ Comment likes channel subscribed")
                
                // Listen for inserts (new comment likes)
                Task {
                    for await change in insertChanges {
                        guard let commentId = extractString(from: change.record, key: "comment_id"),
                              let userId = extractString(from: change.record, key: "user_id") else {
                            print("⚠️ Could not parse comment like insert event")
                            continue
                        }
                        print("🔴 Real-time: Comment \(commentId) liked by \(userId)")
                        await MainActor.run {
                            self.commentLikeUpdated = (commentId: commentId, delta: 1, userId: userId)
                        }
                    }
                }
                
                // Listen for deletes (comment unlikes)
                Task {
                    for await change in deleteChanges {
                        guard let commentId = extractString(from: change.oldRecord, key: "comment_id"),
                              let userId = extractString(from: change.oldRecord, key: "user_id") else {
                            print("⚠️ Could not parse comment like delete event")
                            continue
                        }
                        print("🔴 Real-time: Comment \(commentId) unliked by \(userId)")
                        await MainActor.run {
                            self.commentLikeUpdated = (commentId: commentId, delta: -1, userId: userId)
                        }
                    }
                }
                
            } catch {
                print("❌ Error setting up comment likes channel: \(error)")
            }
        }
    }
    
    // MARK: - Helpers
    
    /// Safely extract a string value from a record dictionary, handling AnyJSON, NSNull, etc.
    private func extractString(from record: [String: Any], key: String) -> String? {
        guard let value = record[key] else { return nil }
        if value is NSNull { return nil }
        if let str = value as? String { return str }
        // Handle AnyJSON or other wrapped types
        return "\(value)" == "<null>" ? nil : "\(value)"
    }
}
