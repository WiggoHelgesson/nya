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
    
    private init() {
        print("🔴 RealtimeSocialService initialized")
    }
    
    // MARK: - Start Listening
    
    /// Start listening to all social real-time updates
    func startListening() {
        print("🔴 Starting real-time social updates...")
        setupPostLikesChannel()
        setupCommentsChannel()
        setupCommentLikesChannel()
    }
    
    /// Stop all real-time channels
    func stopListening() {
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
                        if let postId = change.record["workout_post_id"] as? String,
                           let userId = change.record["user_id"] as? String {
                            print("🔴 Real-time: Post \(postId) liked by \(userId)")
                            await MainActor.run {
                                self.postLikeUpdated = (postId: postId, delta: 1, userId: userId)
                            }
                        }
                    }
                }
                
                // Listen for deletes (unlikes)
                Task {
                    for await change in deleteChanges {
                        if let postId = change.oldRecord["workout_post_id"] as? String,
                           let userId = change.oldRecord["user_id"] as? String {
                            print("🔴 Real-time: Post \(postId) unliked by \(userId)")
                            await MainActor.run {
                                self.postLikeUpdated = (postId: postId, delta: -1, userId: userId)
                            }
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
                        if let commentId = change.record["id"] as? String,
                           let postId = change.record["workout_post_id"] as? String,
                           let userId = change.record["user_id"] as? String,
                           let content = change.record["content"] as? String,
                           let createdAt = change.record["created_at"] as? String {
                            
                            print("🔴 Real-time: New comment on post \(postId)")
                            
                            // Fetch user profile for the comment
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
                                
                                let profile = profiles.first
                                
                                let comment = PostComment(
                                    id: commentId,
                                    postId: postId,
                                    userId: userId,
                                    content: content,
                                    createdAt: createdAt,
                                    userName: profile?.username,
                                    userAvatarUrl: profile?.avatar_url,
                                    parentCommentId: change.record["parent_comment_id"] as? String,
                                    likeCount: 0,
                                    isLikedByCurrentUser: false
                                )
                                
                                await MainActor.run {
                                    self.commentAdded = (postId: postId, comment: comment)
                                }
                            } catch {
                                print("⚠️ Failed to fetch user profile for comment: \(error)")
                            }
                        }
                    }
                }
                
                // Listen for deletes (removed comments)
                Task {
                    for await change in deleteChanges {
                        if let commentId = change.oldRecord["id"] as? String,
                           let postId = change.oldRecord["workout_post_id"] as? String {
                            print("🔴 Real-time: Comment \(commentId) deleted from post \(postId)")
                            await MainActor.run {
                                self.commentDeleted = (postId: postId, commentId: commentId)
                            }
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
                        if let commentId = change.record["comment_id"] as? String,
                           let userId = change.record["user_id"] as? String {
                            print("🔴 Real-time: Comment \(commentId) liked by \(userId)")
                            await MainActor.run {
                                self.commentLikeUpdated = (commentId: commentId, delta: 1, userId: userId)
                            }
                        }
                    }
                }
                
                // Listen for deletes (comment unlikes)
                Task {
                    for await change in deleteChanges {
                        if let commentId = change.oldRecord["comment_id"] as? String,
                           let userId = change.oldRecord["user_id"] as? String {
                            print("🔴 Real-time: Comment \(commentId) unliked by \(userId)")
                            await MainActor.run {
                                self.commentLikeUpdated = (commentId: commentId, delta: -1, userId: userId)
                            }
                        }
                    }
                }
                
            } catch {
                print("❌ Error setting up comment likes channel: \(error)")
            }
        }
    }
}
