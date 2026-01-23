import Foundation
import Supabase

class SocialService {
    static let shared = SocialService()
    private let supabase = SupabaseConfig.supabase
    
    // In-memory cache for post counts (likes and comments)
    private var postCountsCache: [String: (likeCount: Int, commentCount: Int)] = [:]
    // In-memory cache for top likers to prevent N+1 queries during scrolling
    private var topLikersCache: [String: [UserSearchResult]] = [:]
    
    private let cacheManager = AppCacheManager.shared
    private var hasLoggedFollowingCancelled = false
    private var hasLoggedSocialFeedCancelled = false
    private let isoFormatterWithMs: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()
    private let isoFormatterNoMs: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()
    private func parseDate(_ s: String) -> Date {
        if let d = isoFormatterWithMs.date(from: s) { return d }
        if let d = isoFormatterNoMs.date(from: s) { return d }
        return Date.distantPast
    }
    
    // MARK: - Follow Functions
    
    /// Safely follow a user - only adds if not already following
    func followUser(followerId: String, followingId: String) async throws {
        do {
            try await AuthSessionManager.shared.ensureValidSession()
            // Check if already following to avoid duplicates
            let existingFollows: [Follow] = try await supabase
                .from("user_follows")
                .select()
                .eq("follower_id", value: followerId)
                .eq("following_id", value: followingId)
                .execute()
                .value
            
            if existingFollows.isEmpty {
                let follow = Follow(followerId: followerId, followingId: followingId)
                _ = try await supabase
                    .from("user_follows")
                    .insert(follow)
                    .execute()
                print("✅ User followed successfully")
                hasLoggedFollowingCancelled = false
                
                // Create follow notification
                do {
                    let currentUser = try await supabase.auth.user()
                    let userProfile: [UserSearchResult] = try await supabase
                        .from("profiles")
                        .select("id, username, avatar_url")
                        .eq("id", value: currentUser.id.uuidString)
                        .execute()
                        .value
                    
                    if let profile = userProfile.first {
                        try await NotificationService.shared.createFollowNotification(
                            userId: followingId,
                            followedByUserId: followerId,
                            followedByUserName: profile.name,
                            followedByUserAvatar: profile.avatarUrl
                        )
                    }
                } catch {
                    print("⚠️ Could not create follow notification: \(error)")
                    // Don't fail the follow operation if notification fails
                }
            } else {
                print("✅ User already being followed")
            }
        } catch {
            print("❌ Error following user: \(error)")
            throw error
        }
    }
    
    /// Safely unfollow a user - only removes the specific follow relationship
    func unfollowUser(followerId: String, followingId: String) async throws {
        do {
            try await AuthSessionManager.shared.ensureValidSession()
            _ = try await supabase
                .from("user_follows")
                .delete()
                .eq("follower_id", value: followerId)
                .eq("following_id", value: followingId)
                .execute()
            print("✅ User unfollowed successfully")
        } catch {
            print("❌ Error unfollowing user: \(error)")
            throw error
        }
    }
    
    /// Get all users that the current user follows
    func getFollowing(userId: String) async throws -> [String] {
        do {
            try await AuthSessionManager.shared.ensureValidSession()
            let follows: [Follow] = try await supabase
                .from("user_follows")
                .select()
                .eq("follower_id", value: userId)
                .execute()
                .value
            
            let followingIds = follows.map { $0.followingId }
            print("🔍 getFollowing for user \(userId): found \(followingIds.count) following relationships")
            print("🔍 Following IDs: \(followingIds)")
            return followingIds
        } catch {
            // Don't log cancelled requests as errors
            if let urlError = error as? URLError, urlError.code == .cancelled {
                if !hasLoggedFollowingCancelled {
                    print("⚠️ Following request was cancelled")
                    hasLoggedFollowingCancelled = true
                }
                return []
            }
            print("❌ Error fetching following: \(error)")
            return []
        }
    }
    
    /// Get detailed user information for users that the current user follows
    func getFollowingUsers(userId: String) async throws -> [UserSearchResult] {
        do {
            try await AuthSessionManager.shared.ensureValidSession()
            print("🔍 Getting following users for user: \(userId)")
            
            // First get the following IDs
            let followingIds = try await getFollowing(userId: userId)
            print("🔍 Found \(followingIds.count) following IDs: \(followingIds)")
            
            if followingIds.isEmpty {
                print("✅ No following found")
                return []
            }
            
            // Then get user details for those IDs
            let users: [UserSearchResult] = try await supabase
                .from("profiles")
                .select("id, username, avatar_url")
                .in("id", values: followingIds)
                .not("username", operator: .is, value: "null")
                .execute()
                .value
            
            print("✅ Loaded \(users.count) following users")
            return users
        } catch {
            print("❌ Error fetching following users: \(error)")
            return []
        }
    }
    
    /// Get all users that follow the current user
    func getFollowers(userId: String) async throws -> [String] {
        do {
            try await AuthSessionManager.shared.ensureValidSession()
            let follows: [Follow] = try await supabase
                .from("user_follows")
                .select()
                .eq("following_id", value: userId)
                .execute()
                .value
            
            let followerIds = follows.map { $0.followerId }
            print("🔍 getFollowers for user \(userId): found \(followerIds.count) follower relationships")
            print("🔍 Follower IDs: \(followerIds)")
            return followerIds
        } catch {
            print("❌ Error fetching followers: \(error)")
            return []
        }
    }
    
    /// Get detailed user information for users that follow the current user
    func getFollowerUsers(userId: String) async throws -> [UserSearchResult] {
        do {
            try await AuthSessionManager.shared.ensureValidSession()
            print("🔍 Getting follower users for user: \(userId)")
            
            // First get the follower IDs
            let followerIds = try await getFollowers(userId: userId)
            print("🔍 Found \(followerIds.count) follower IDs: \(followerIds)")
            
            if followerIds.isEmpty {
                print("✅ No followers found")
                return []
            }
            
            // Then get user details for those IDs
            let users: [UserSearchResult] = try await supabase
                .from("profiles")
                .select("id, username, avatar_url")
                .in("id", values: followerIds)
                .not("username", operator: .is, value: "null")
                .execute()
                .value
            
            print("✅ Loaded \(users.count) follower users")
            return users
        } catch {
            print("❌ Error fetching follower users: \(error)")
            return []
        }
    }
    
    /// Check if one user is following another
    func isFollowing(followerId: String, followingId: String) async throws -> Bool {
        do {
            try await AuthSessionManager.shared.ensureValidSession()
            let follows: [Follow] = try await supabase
                .from("user_follows")
                .select()
                .eq("follower_id", value: followerId)
                .eq("following_id", value: followingId)
                .limit(1)
                .execute()
                .value
            
            return !follows.isEmpty
        } catch {
            print("❌ Error checking follow status: \(error)")
            return false
        }
    }
    
    /// Get detailed follow information for debugging
    func getFollowStats(userId: String) async throws -> (following: Int, followers: Int) {
        do {
            let following = try await getFollowing(userId: userId)
            let followers = try await getFollowers(userId: userId)
            
            print("📊 Follow stats for user \(userId): Following: \(following.count), Followers: \(followers.count)")
            return (following: following.count, followers: followers.count)
        } catch {
            print("❌ Error getting follow stats: \(error)")
            return (following: 0, followers: 0)
        }
    }
    
    func likePost(postId: String, userId: String, postOwnerId: String? = nil, postTitle: String = "") async throws {
        do {
            try await AuthSessionManager.shared.ensureValidSession()
            let like = PostLike(postId: postId, userId: userId)
            _ = try await supabase
                .from("workout_post_likes")
                .insert(like)
                .execute()
            print("✅ Post liked successfully")
            
            // Invalidate top likers cache so next fetch gets fresh data
            topLikersCache.removeValue(forKey: postId)
            
            // Create notification if we have post owner info
            if let postOwnerId = postOwnerId, postOwnerId != userId {
                do {
                    // Fetch current user info
                    let currentUser = try await supabase.auth.user()
                    
                    struct ProfileInfo: Codable {
                        let username: String?
                        let avatar_url: String?
                    }
                    
                    let userProfile: [ProfileInfo] = try await supabase
                        .from("profiles")
                        .select("username, avatar_url")
                        .eq("id", value: currentUser.id.uuidString)
                        .execute()
                        .value
                    
                    if let profile = userProfile.first {
                        try await NotificationService.shared.createLikeNotification(
                            userId: postOwnerId,
                            likedByUserId: userId,
                            likedByUserName: profile.username ?? "Användare",
                            likedByUserAvatar: profile.avatar_url,
                            postId: postId,
                            postTitle: postTitle
                        )
                    }
                } catch {
                    print("⚠️ Could not create notification: \(error)")
                    // Don't fail the like operation if notification fails
                }
            }
        } catch {
            print("❌ Error liking post: \(error)")
            throw error
        }
    }
    
    func unlikePost(postId: String, userId: String) async throws {
        do {
            try await AuthSessionManager.shared.ensureValidSession()
            _ = try await supabase
                .from("workout_post_likes")
                .delete()
                .eq("workout_post_id", value: postId)
                .eq("user_id", value: userId)
                .execute()
            print("✅ Post unliked successfully")
            
            // Invalidate top likers cache
            topLikersCache.removeValue(forKey: postId)
        } catch {
            print("❌ Error unliking post: \(error)")
            throw error
        }
    }
    
    func getPostLikes(postId: String) async throws -> [PostLike] {
        do {
            try await AuthSessionManager.shared.ensureValidSession()
            let likes: [PostLike] = try await supabase
                .from("workout_post_likes")
                .select()
                .eq("workout_post_id", value: postId)
                .execute()
                .value
            
            return likes
        } catch {
            print("❌ Error fetching post likes: \(error)")
            return []
        }
    }
    
    func getTopPostLikers(postId: String, limit: Int = 3) async throws -> [UserSearchResult] {
        // Check memory cache first
        if let cached = topLikersCache[postId] {
            return cached
        }
        
        do {
            try await AuthSessionManager.shared.ensureValidSession()
            // Fetch likes ordered by most recent
            let likes: [PostLike] = try await supabase
                .from("workout_post_likes")
                .select()
                .eq("workout_post_id", value: postId)
                .order("created_at", ascending: false)
                .limit(limit)
                .execute()
                .value
            let likerIds = likes.map { $0.userId }
            guard !likerIds.isEmpty else { 
                topLikersCache[postId] = []
                return [] 
            }
            
            // Check if we have these users in some other cache?
            // For now, just fetch them.
            
            let users: [UserSearchResult] = try await supabase
                .from("profiles")
                .select("id, username, avatar_url")
                .in("id", values: likerIds)
                .execute()
                .value
            // Preserve order matching likes array
            let userMap = Dictionary(uniqueKeysWithValues: users.map { ($0.id, $0) })
            let result = likerIds.compactMap { userMap[$0] }
            ImageCacheManager.shared.prefetch(urls: result.compactMap { $0.avatarUrl })
            
            // Update cache
            topLikersCache[postId] = result
            return result
        } catch {
            print("❌ Error fetching top likers: \(error)")
            return []
        }
    }
    
    func getAllPostLikers(postId: String) async throws -> [UserSearchResult] {
        do {
            try await AuthSessionManager.shared.ensureValidSession()
            let likes: [PostLike] = try await supabase
                .from("workout_post_likes")
                .select()
                .eq("workout_post_id", value: postId)
                .order("created_at", ascending: false)
                .execute()
                .value
            
            let likerIds = likes.map { $0.userId }
            guard !likerIds.isEmpty else { return [] }
            
            let users: [UserSearchResult] = try await supabase
                .from("profiles")
                .select("id, username, avatar_url")
                .in("id", values: likerIds)
                .execute()
                .value
            
            let userMap = Dictionary(uniqueKeysWithValues: users.map { ($0.id, $0) })
            let result = likerIds.compactMap { userMap[$0] }
            ImageCacheManager.shared.prefetch(urls: result.compactMap { $0.avatarUrl })
            return result
        } catch {
            print("❌ Error fetching likers list: \(error)")
            return []
        }
    }
    
    // MARK: - Comment Functions
    
    func addComment(postId: String,
                    userId: String,
                    content: String,
                    parentCommentId: String? = nil,
                    postOwnerId: String? = nil,
                    postTitle: String = "") async throws {
        do {
            try await AuthSessionManager.shared.ensureValidSession()
            let comment = PostComment(postId: postId,
                                      userId: userId,
                                      content: content,
                                      parentCommentId: parentCommentId)
            
            struct InsertPayload: Encodable {
                let id: String
                let workout_post_id: String
                let user_id: String
                let content: String
                let parent_comment_id: String?
                let created_at: String
            }
            
            let payload = InsertPayload(
                id: comment.id,
                workout_post_id: postId,
                user_id: userId,
                content: content,
                parent_comment_id: parentCommentId,
                created_at: comment.createdAt
            )

            _ = try await supabase
                .from("workout_post_comments")
                .insert(payload)
                .execute()
            print("✅ Comment added successfully")
            
            // Fetch current user info for notifications
            do {
                let currentUser = try await supabase.auth.user()
                
                struct ProfileInfo: Codable {
                    let username: String?
                    let avatar_url: String?
                }
                
                let userProfile: [ProfileInfo] = try await supabase
                    .from("profiles")
                    .select("username, avatar_url")
                    .eq("id", value: currentUser.id.uuidString)
                    .execute()
                    .value
                
                guard let profile = userProfile.first else { return }
                
                // If this is a reply to another comment, notify the parent comment author
                if let parentCommentId = parentCommentId {
                    // Fetch parent comment author
                    struct ParentComment: Codable {
                        let user_id: String
                    }
                    
                    let parentComments: [ParentComment] = try await supabase
                        .from("workout_post_comments")
                        .select("user_id")
                        .eq("id", value: parentCommentId)
                        .limit(1)
                        .execute()
                        .value
                    
                    if let parentComment = parentComments.first, parentComment.user_id != userId {
                        // Send reply notification to parent comment author
                        try await NotificationService.shared.createReplyNotification(
                            userId: parentComment.user_id,
                            repliedByUserId: userId,
                            repliedByUserName: profile.username ?? "Användare",
                            repliedByUserAvatar: profile.avatar_url,
                            postId: postId,
                            postTitle: postTitle
                        )
                    }
                }
                
                // Also notify post owner if it's a new comment (not a reply to yourself)
                if let postOwnerId = postOwnerId, postOwnerId != userId {
                    // Don't notify post owner if they're already being notified as parent comment author
                    let shouldNotifyPostOwner: Bool
                    if let parentCommentId = parentCommentId {
                        struct ParentComment: Codable {
                            let user_id: String
                        }
                        let parentComments: [ParentComment] = try await supabase
                            .from("workout_post_comments")
                            .select("user_id")
                            .eq("id", value: parentCommentId)
                            .limit(1)
                            .execute()
                            .value
                        shouldNotifyPostOwner = parentComments.first?.user_id != postOwnerId
                    } else {
                        shouldNotifyPostOwner = true
                    }
                    
                    if shouldNotifyPostOwner {
                        try await NotificationService.shared.createCommentNotification(
                            userId: postOwnerId,
                            commentedByUserId: userId,
                            commentedByUserName: profile.username ?? "Användare",
                            commentedByUserAvatar: profile.avatar_url,
                            postId: postId,
                            postTitle: postTitle,
                            commentText: content
                        )
                    }
                }
            } catch {
                print("⚠️ Could not create notification: \(error)")
                // Don't fail the comment operation if notification fails
            }
        } catch {
            print("❌ Error adding comment: \(error)")
            throw error
        }
    }
    
    func deleteComment(commentId: String) async throws {
        do {
            try await AuthSessionManager.shared.ensureValidSession()
            
            // Delete the comment
            try await supabase
                .from("workout_post_comments")
                .delete()
                .eq("id", value: commentId)
                .execute()
            
            print("✅ Comment deleted successfully")
        } catch {
            print("❌ Error deleting comment: \(error)")
            throw error
        }
    }
    
    func getPostComments(postId: String, currentUserId: String?) async throws -> [PostComment] {
        do {
            try await AuthSessionManager.shared.ensureValidSession()
            // Fetch comments
            let comments: [PostComment] = try await supabase
                .from("workout_post_comments")
                .select("""
                    id,
                    workout_post_id,
                    user_id,
                    content,
                    created_at,
                    parent_comment_id
                """)
                .eq("workout_post_id", value: postId)
                .order("created_at", ascending: true)
                .execute()
                .value
            
            // Get unique user IDs from comments
            let userIds = Array(Set(comments.map { $0.userId }))
            
            if userIds.isEmpty {
                return comments
            }
            
            // Fetch user data for all comment authors
            let users: [UserSearchResult] = try await supabase
                .from("profiles")
                .select("id, username, avatar_url")
                .in("id", values: userIds)
                .execute()
                .value
            
            // Create a map of userId to user data for quick lookup
            let userMap = Dictionary(uniqueKeysWithValues: users.map { ($0.id, $0) })
            
            // Combine comments with user data
            let enrichedComments = comments.map { comment in
                let user = userMap[comment.userId]
                return PostComment(
                    id: comment.id,
                    postId: comment.postId,
                    userId: comment.userId,
                    content: comment.content,
                    createdAt: comment.createdAt,
                    userName: user?.name,
                    userAvatarUrl: user?.avatarUrl,
                    parentCommentId: comment.parentCommentId
                )
            }
            
            let commentIds = enrichedComments.map { $0.id }
            if commentIds.isEmpty { return enrichedComments }
            
            struct CommentLike: Decodable {
                let comment_id: String
                let user_id: String
            }
            
            let likes: [CommentLike] = try await supabase
                .from("comment_likes")
                .select("comment_id, user_id")
                .in("comment_id", values: commentIds)
                .execute()
                .value
            
            var likeMap: [String: Int] = [:]
            var likedByUser = Set<String>()
            for like in likes {
                likeMap[like.comment_id, default: 0] += 1
                if let currentUserId, like.user_id == currentUserId {
                    likedByUser.insert(like.comment_id)
                }
            }
            
            return enrichedComments.map { comment in
                var updated = comment
                updated.likeCount = likeMap[comment.id] ?? 0
                updated.isLikedByCurrentUser = likedByUser.contains(comment.id)
                return updated
            }
        } catch {
            print("❌ Error fetching post comments: \(error)")
            return []
        }
    }
    
    func likeComment(commentId: String, userId: String) async throws {
        struct Payload: Encodable { let comment_id: String; let user_id: String }
        do {
            try await AuthSessionManager.shared.ensureValidSession()
            try await supabase
                .from("comment_likes")
                .insert(Payload(comment_id: commentId, user_id: userId))
                .execute()
            print("✅ Comment liked")
        } catch {
            print("❌ Error liking comment: \(error)")
            throw error
        }
    }
    
    func unlikeComment(commentId: String, userId: String) async throws {
        do {
            try await AuthSessionManager.shared.ensureValidSession()
            try await supabase
                .from("comment_likes")
                .delete()
                .eq("comment_id", value: commentId)
                .eq("user_id", value: userId)
                .execute()
            print("✅ Comment unliked")
        } catch {
            print("❌ Error unliking comment: \(error)")
            throw error
        }
    }
    
    // MARK: - User Search Functions
    
    func getAllUsers() async throws -> [UserSearchResult] {
        do {
            try await AuthSessionManager.shared.ensureValidSession()
            print("🔍 Getting all users from profiles table")
            
            let users: [UserSearchResult] = try await supabase
                .from("profiles")
                .select("id, username, avatar_url")
                .not("username", operator: .is, value: "null")
                .limit(50)
                .execute()
                .value
            
            print("✅ Found \(users.count) total users in database: \(users.map { $0.name })")
            return users
        } catch {
            print("❌ Error getting all users: \(error)")
            print("❌ Error details: \(error.localizedDescription)")
            return []
        }
    }
    
    /// Get recommended users based on mutual friends (users that follow people you also follow)
    func getRecommendedUsers(userId: String, limit: Int = 15) async throws -> [UserSearchResult] {
        do {
            try await AuthSessionManager.shared.ensureValidSession()
            print("🔍 Getting recommended users for user: \(userId)")
            
            // Get all users that the current user follows
            let followingIds = try await getFollowing(userId: userId)
            
            if followingIds.isEmpty {
                // If user is not following anyone, return random users
                let allUsers: [UserSearchResult] = try await supabase
                    .from("profiles")
                    .select("id, username, avatar_url")
                    .neq("id", value: userId)
                    .not("username", operator: .is, value: "null")
                    .limit(limit)
                    .execute()
                    .value
                
                // Exclude users already being followed
                let alreadyFollowing = try await getFollowing(userId: userId)
                let recommended = allUsers.filter { !alreadyFollowing.contains($0.id) }
                
                print("✅ Found \(recommended.count) recommended users (random)")
                return Array(recommended.prefix(limit))
            }
            
            // Get all users that follow the same people as the current user
            // This is done by finding users whose following list overlaps with the current user's following list
            let followingSet = Set(followingIds)
            
            // Get all follows where the following_id is someone the current user follows
            let mutualFollows: [Follow] = try await supabase
                .from("user_follows")
                .select()
                .in("following_id", values: Array(followingSet))
                .neq("follower_id", value: userId)
                .execute()
                .value
            
            // Count how many mutual follows each user has
            var mutualCounts: [String: Int] = [:]
            for follow in mutualFollows {
                if !followingSet.contains(follow.followerId) { // Don't count if already following them
                    mutualCounts[follow.followerId, default: 0] += 1
                }
            }
            
            // Sort by number of mutual follows (descending)
            let sortedUserIds = mutualCounts.sorted { $0.value > $1.value }.map { $0.key }
            
            // Get user details for top recommendations
            let userIdsToFetch = Array(sortedUserIds.prefix(limit))
            
            if userIdsToFetch.isEmpty {
                // Fallback: get random users if no mutual friends found
                let allUsers: [UserSearchResult] = try await supabase
                    .from("profiles")
                    .select("id, username, avatar_url")
                    .neq("id", value: userId)
                    .not("username", operator: .is, value: "null")
                    .limit(limit)
                    .execute()
                    .value
                
                let alreadyFollowing = try await getFollowing(userId: userId)
                let recommended = allUsers.filter { !alreadyFollowing.contains($0.id) }
                
                print("✅ Found \(recommended.count) recommended users (fallback)")
                return Array(recommended.prefix(limit))
            }
            
            let recommendedUsers: [UserSearchResult] = try await supabase
                .from("profiles")
                .select("id, username, avatar_url")
                .in("id", values: userIdsToFetch)
                .not("username", operator: .is, value: "null")
                .execute()
                .value
            
            // Sort to maintain order from mutualCounts
            let sortedUsers = recommendedUsers.sorted { user1, user2 in
                let index1 = userIdsToFetch.firstIndex(of: user1.id) ?? Int.max
                let index2 = userIdsToFetch.firstIndex(of: user2.id) ?? Int.max
                return index1 < index2
            }
            
            print("✅ Found \(sortedUsers.count) recommended users with mutual friends")
            return sortedUsers
        } catch {
            print("❌ Error getting recommended users: \(error)")
            return []
        }
    }
    
    /// Get mutual friends count between the current user and a list of other users
    /// Returns a dictionary mapping user IDs to their mutual friend count
    func getMutualFriendsCount(currentUserId: String, otherUserIds: [String]) async throws -> [String: Int] {
        guard !otherUserIds.isEmpty else { return [:] }
        
        do {
            // Get who the current user follows
            let myFollowing = try await getFollowing(userId: currentUserId)
            let myFollowingSet = Set(myFollowing)
            
            if myFollowingSet.isEmpty {
                // If current user doesn't follow anyone, no mutual friends possible
                return [:]
            }
            
            var mutualCounts: [String: Int] = [:]
            
            // For each other user, get who they follow and count overlap
            for otherUserId in otherUserIds {
                let theirFollowing = try await getFollowing(userId: otherUserId)
                let theirFollowingSet = Set(theirFollowing)
                
                // Mutual friends = intersection of who we both follow
                let mutualCount = myFollowingSet.intersection(theirFollowingSet).count
                if mutualCount > 0 {
                    mutualCounts[otherUserId] = mutualCount
                }
            }
            
            return mutualCounts
        } catch {
            print("❌ Error getting mutual friends count: \(error)")
            return [:]
        }
    }
    
    func searchUsers(query: String, currentUserId: String) async throws -> [UserSearchResult] {
        do {
            try await AuthSessionManager.shared.ensureValidSession()
            print("🔍 Searching for users with query: '\(query)'")
            
            let users: [UserSearchResult] = try await supabase
                .from("profiles")
                .select("id, username, avatar_url")
                .ilike("username", pattern: "%\(query)%")
                .not("username", operator: .is, value: "null")
                .neq("id", value: currentUserId)
                .limit(20)
                .execute()
                .value
            
            print("✅ Found \(users.count) users matching '\(query)': \(users.map { $0.name })")
            return users
        } catch {
            print("❌ Error searching users: \(error)")
            print("❌ Error details: \(error.localizedDescription)")
            return []
        }
    }
    
    /// Find users that match contact names from the device
    func findUsersByNames(names: [String]) async throws -> [UserSearchResult] {
        guard !names.isEmpty else { return [] }
        
        do {
            try await AuthSessionManager.shared.ensureValidSession()
            print("📇 Searching for users matching \(names.count) contact names")
            
            // Get current user to exclude from results
            let currentUser = try await supabase.auth.user()
            let currentUserId = currentUser.id.uuidString
            
            // Search for users whose names match contact names (case insensitive)
            // We'll fetch all users and filter locally for better matching
            let allUsers: [UserSearchResult] = try await supabase
                .from("profiles")
                .select("id, username, avatar_url")
                .not("username", operator: .is, value: "null")
                .neq("id", value: currentUserId)
                .limit(500) // Get a good sample
                .execute()
                .value
            
            // Create a set of normalized contact names for EXACT matching
            // Normalize by lowercasing and trimming whitespace
            let normalizedContactNames = Set(names.map { 
                $0.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) 
            })
            
            // Filter users whose names EXACTLY match a contact name (case insensitive)
            let matchedUsers = allUsers.filter { user in
                let normalizedUserName = user.name.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
                // Only exact match - the username must be exactly the same as a contact name
                return normalizedContactNames.contains(normalizedUserName)
            }
            
            print("✅ Found \(matchedUsers.count) users with EXACT contact name match")
            return matchedUsers
        } catch {
            print("❌ Error finding users by names: \(error)")
            return []
        }
    }
    
    // MARK: - Featured Users Helper
    
    /// Get user IDs for featured usernames (shown when user doesn't follow anyone)
    private func getFeaturedUserIds() async throws -> [String] {
        struct ProfileUsername: Decodable {
            let id: String
        }
        
        do {
            let profiles: [ProfileUsername] = try await supabase
                .from("profiles")
                .select("id")
                .in("username", values: Self.featuredUsernames)
                .execute()
                .value
            
            return profiles.map { $0.id }
        } catch {
            print("⚠️ Could not fetch featured user IDs: \(error)")
            return []
        }
    }
    
    // MARK: - Social Feed Functions
    
    // Featured usernames to show when user doesn't follow anyone
    private static let featuredUsernames = ["Wiggolito", "Linus.Lanneborn", "Podden"]
    
    func getSocialFeed(userId: String) async throws -> [SocialWorkoutPost] {
        do {
            try await AuthSessionManager.shared.ensureValidSession()
            // Always include the provided userId (avoid auth.user() cancellation problems)
            var userIdsToFetch: [String] = [userId]
            var followingCount = 0
            
            // Try to add following users; if request is cancelled, just continue with current user
            do {
                let following = try await getFollowing(userId: userId)
                followingCount = following.count
                userIdsToFetch.append(contentsOf: following)
            } catch let urlError as URLError where urlError.code == .cancelled {
                if !hasLoggedFollowingCancelled {
                    print("⚠️ Following request was cancelled - proceeding with current user's posts only")
                    hasLoggedFollowingCancelled = true
                }
            } catch {
                print("⚠️ Could not fetch following list: \(error) - proceeding with current user's posts only")
            }
            
            // If user doesn't follow anyone, show posts from featured users instead
            if followingCount == 0 {
                let featuredUserIds = try await getFeaturedUserIds()
                userIdsToFetch.append(contentsOf: featuredUserIds)
                print("📱 User follows no one - showing featured users: \(Self.featuredUsernames)")
            }
            
            // Get posts from followed users AND current user with social data
            let posts: [SocialWorkoutPost] = try await supabase
                .from("workout_posts")
                .select("""
                    id,
                    user_id,
                    activity_type,
                    title,
                    description,
                    distance,
                    duration,
                    image_url,
                    user_image_url,
                    elevation_gain,
                    max_speed,
                    created_at,
                    split_data,
                    exercises_data,
                    pb_exercise_name,
                    pb_value,
                    streak_count,
                    source,
                    device_name,
                    profiles!workout_posts_user_id_fkey(username, avatar_url),
                    workout_post_likes(count),
                    workout_post_comments(count)
                """)
                .in("user_id", values: userIdsToFetch)
                .order("created_at", ascending: false)
                .execute()
                .value
            
            // Cache the counts for later use
            for post in posts {
                postCountsCache[post.id] = (likeCount: post.likeCount ?? 0, commentCount: post.commentCount ?? 0)
            }
            
            hasLoggedSocialFeedCancelled = false
            print("✅ Fetched \(posts.count) social feed posts from \(userIdsToFetch.count) users")
            let enriched = await markLikedPosts(posts, userId: userId)
            return enriched
        } catch let urlError as URLError where urlError.code == .cancelled {
            // Don't throw error for cancelled requests
            if !hasLoggedSocialFeedCancelled {
                print("⚠️ Social feed request was cancelled (likely due to refresh)")
                hasLoggedSocialFeedCancelled = true
            }
            throw CancellationError()
        } catch {
            print("❌ Error fetching social feed: \(error)")
            throw error
        }
    }

    /// Fetch social feed with guaranteed fallback so the user always sees their own and followed posts
    func getReliableSocialFeed(userId: String) async throws -> [SocialWorkoutPost] {
        do {
            try await AuthSessionManager.shared.ensureValidSession()
            let primary = try await getSocialFeed(userId: userId)
            if !primary.isEmpty {
                return primary
            }
            print("⚠️ Primary social feed returned 0 posts. Building fallback feed.")
        } catch let error as CancellationError {
            throw error
        } catch {
            print("❌ Primary social feed failed: \(error). Building fallback feed.")
        }
        let fallback = await buildFallbackFeed(userId: userId)
        let enrichedFallback = await markLikedPosts(fallback, userId: userId)
        if fallback.isEmpty {
            print("⚠️ Fallback feed empty as well.")
        }
        return enrichedFallback
    }

    func getPostsForUser(targetUserId: String, viewerId: String) async throws -> [SocialWorkoutPost] {
        do {
            try await AuthSessionManager.shared.ensureValidSession()
            let posts: [SocialWorkoutPost] = try await supabase
                .from("workout_posts")
                .select("""
                    id,
                    user_id,
                    activity_type,
                    title,
                    description,
                    distance,
                    duration,
                    image_url,
                    user_image_url,
                    elevation_gain,
                    max_speed,
                    created_at,
                    split_data,
                    exercises_data,
                    pb_exercise_name,
                    pb_value,
                    streak_count,
                    source,
                    device_name,
                    profiles!workout_posts_user_id_fkey(username, avatar_url, is_pro_member),
                    workout_post_likes(count),
                    workout_post_comments(count)
                """)
                .eq("user_id", value: targetUserId)
                .order("created_at", ascending: false)
                .execute()
                .value
            
            for post in posts {
                postCountsCache[post.id] = (likeCount: post.likeCount ?? 0, commentCount: post.commentCount ?? 0)
            }
            
            return await markLikedPosts(posts, userId: viewerId)
        } catch let error as URLError where error.code == .cancelled {
            throw CancellationError()
        } catch {
            print("❌ Error fetching posts for user \(targetUserId): \(error)")
            throw error
        }
    }
    
    /// Fetch a single post by ID
    func getPost(postId: String) async throws -> SocialWorkoutPost {
        do {
            try await AuthSessionManager.shared.ensureValidSession()
            let posts: [SocialWorkoutPost] = try await supabase
                .from("workout_posts")
                .select("""
                    id,
                    user_id,
                    activity_type,
                    title,
                    description,
                    distance,
                    duration,
                    image_url,
                    user_image_url,
                    elevation_gain,
                    max_speed,
                    created_at,
                    split_data,
                    exercises_data,
                    pb_exercise_name,
                    pb_value,
                    streak_count,
                    source,
                    device_name,
                    profiles!workout_posts_user_id_fkey(username, avatar_url, is_pro_member),
                    workout_post_likes(count),
                    workout_post_comments(count)
                """)
                .eq("id", value: postId)
                .limit(1)
                .execute()
                .value
            
            guard let post = posts.first else {
                throw NSError(domain: "SocialService", code: 404, userInfo: [NSLocalizedDescriptionKey: "Post not found"])
            }
            
            print("✅ Fetched post: \(post.title)")
            return post
        } catch {
            print("❌ Error fetching post \(postId): \(error)")
            throw error
        }
    }
    
    private func buildFallbackFeed(userId: String) async -> [SocialWorkoutPost] {
        var userIdSet: Set<String> = [userId]
        if let following = try? await getFollowing(userId: userId) {
            userIdSet.formUnion(following)
        }
        let ids = Array(userIdSet)
        if ids.isEmpty {
            return []
        }
        var collected: [SocialWorkoutPost] = []
        await withTaskGroup(of: [SocialWorkoutPost].self) { group in
            for targetId in ids {
                group.addTask { [weak self] in
                    guard let self else { return [] }
                    var workouts: [WorkoutPost] = []
                    do {
                        workouts = try await RetryHelper.shared.retry(maxRetries: 3, delay: 0.4) {
                            return try await WorkoutService.shared.fetchUserWorkoutPosts(userId: targetId)
                        }
                    } catch {
                        if let cached = self.cacheManager.getCachedUserWorkouts(userId: targetId, allowExpired: true) {
                            workouts = cached
                        } else {
                            print("⚠️ Could not fetch workouts for user \(targetId): \(error)")
                            return []
                        }
                    }
                    guard !workouts.isEmpty else { return [] }
                    let profile = try? await ProfileService.shared.fetchUserProfile(userId: targetId)
                    
                    // Fetch actual counts from database instead of relying on stale cache
                    let postIds = workouts.map { $0.id }
                    var countsMap: [String: (likeCount: Int, commentCount: Int)] = [:]
                    
                    do {
                        try await AuthSessionManager.shared.ensureValidSession()
                        
                        // Fetch like counts
                        struct LikeCountRow: Decodable {
                            let workout_post_id: String
                            let count: Int
                        }
                        
                        // Use a simpler approach - fetch counts for each post
                        for postId in postIds {
                            // Get like count
                            let likes: [[String: String]] = try await self.supabase
                                .from("workout_post_likes")
                                .select("workout_post_id")
                                .eq("workout_post_id", value: postId)
                                .execute()
                                .value
                            
                            // Get comment count
                            let comments: [[String: String]] = try await self.supabase
                                .from("workout_post_comments")
                                .select("workout_post_id")
                                .eq("workout_post_id", value: postId)
                                .execute()
                                .value
                            
                            countsMap[postId] = (likeCount: likes.count, commentCount: comments.count)
                            
                            // Update cache with fresh counts
                            self.postCountsCache[postId] = countsMap[postId]
                        }
                    } catch {
                        print("⚠️ Could not fetch fresh counts in fallback feed: \(error)")
                        // Fall back to cache if fresh fetch fails
                        for postId in postIds {
                            countsMap[postId] = self.postCountsCache[postId] ?? (likeCount: 0, commentCount: 0)
                        }
                    }
                    
                    let mapped = workouts.map { post -> SocialWorkoutPost in
                        let counts = countsMap[post.id] ?? (likeCount: 0, commentCount: 0)
                        return SocialWorkoutPost(
                            id: post.id,
                            userId: post.userId,
                            activityType: post.activityType,
                            title: post.title,
                            description: post.description,
                            distance: post.distance,
                            duration: post.duration,
                            imageUrl: post.imageUrl,
                            userImageUrl: post.userImageUrl,
                            createdAt: post.createdAt,
                            userName: profile?.name,
                            userAvatarUrl: profile?.avatarUrl,
                            userIsPro: profile?.isProMember,
                            location: nil,
                            strokes: nil,
                            likeCount: counts.likeCount,
                            commentCount: counts.commentCount,
                            isLikedByCurrentUser: false,
                            splits: post.splits,
                            exercises: post.exercises
                        )
                    }
                    return mapped
                }
            }
            for await userPosts in group {
                collected.append(contentsOf: userPosts)
            }
        }
        // Deduplicate by id and sort by createdAt desc
        var seenIds: Set<String> = []
        let deduped = collected.filter { post in
            if seenIds.contains(post.id) {
                return false
            }
            seenIds.insert(post.id)
            return true
        }
        return deduped.sorted { parseDate($0.createdAt) > parseDate($1.createdAt) }
    }
    
    private func markLikedPosts(_ posts: [SocialWorkoutPost], userId: String) async -> [SocialWorkoutPost] {
        guard !posts.isEmpty else { return posts }
        struct LikeRow: Decodable { let postId: String; enum CodingKeys: String, CodingKey { case postId = "workout_post_id" } }
        do {
            try await AuthSessionManager.shared.ensureValidSession()
            let postIds = posts.map { $0.id }
            let likes: [LikeRow] = try await supabase
                .from("workout_post_likes")
                .select("workout_post_id")
                .eq("user_id", value: userId)
                .in("workout_post_id", values: postIds)
                .execute()
                .value
            let likedSet = Set(likes.map { $0.postId })
            return posts.map { post in
                SocialWorkoutPost(
                    id: post.id,
                    userId: post.userId,
                    activityType: post.activityType,
                    title: post.title,
                    description: post.description,
                    distance: post.distance,
                    duration: post.duration,
                    imageUrl: post.imageUrl,
                    userImageUrl: post.userImageUrl,
                    createdAt: post.createdAt,
                    userName: post.userName,
                    userAvatarUrl: post.userAvatarUrl,
                    userIsPro: post.userIsPro,
                    location: post.location,
                    strokes: post.strokes,
                    likeCount: post.likeCount,
                    commentCount: post.commentCount,
                    isLikedByCurrentUser: likedSet.contains(post.id),
                    splits: post.splits,
                    exercises: post.exercises
                )
            }
        } catch {
            print("⚠️ Could not mark liked posts: \(error)")
            return posts
        }
    }
    
    // MARK: - Featured Posts (for empty feed - shows recent posts from all users)
    func getFeaturedPosts(viewerId: String, limit: Int = 7) async throws -> [SocialWorkoutPost] {
        do {
            try await AuthSessionManager.shared.ensureValidSession()
            
            // Fetch the most recent posts from ALL users (excluding the viewer's own posts)
            let posts: [SocialWorkoutPost] = try await supabase
                .from("workout_posts")
                .select("""
                    id,
                    user_id,
                    activity_type,
                    title,
                    description,
                    distance,
                    duration,
                    image_url,
                    user_image_url,
                    elevation_gain,
                    max_speed,
                    created_at,
                    split_data,
                    exercises_data,
                    pb_exercise_name,
                    pb_value,
                    streak_count,
                    source,
                    device_name,
                    profiles!workout_posts_user_id_fkey(username, avatar_url, is_pro_member),
                    workout_post_likes(count),
                    workout_post_comments(count)
                """)
                .neq("user_id", value: viewerId) // Exclude own posts
                .order("created_at", ascending: false)
                .limit(limit)
                .execute()
                .value
            
            print("✅ Loaded \(posts.count) recent posts for empty feed")
            return await markLikedPosts(posts, userId: viewerId)
        } catch {
            print("❌ Error fetching recent posts: \(error)")
            throw error
        }
    }
}
