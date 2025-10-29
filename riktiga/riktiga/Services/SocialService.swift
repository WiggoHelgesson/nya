import Foundation
import Supabase

class SocialService {
    static let shared = SocialService()
    private let supabase = SupabaseConfig.supabase
    
    // In-memory cache for post counts (likes and comments)
    private var postCountsCache: [String: (likeCount: Int, commentCount: Int)] = [:]
    
    // MARK: - Follow Functions
    
    /// Safely follow a user - only adds if not already following
    func followUser(followerId: String, followingId: String) async throws {
        do {
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
                
                // Create follow notification
                do {
                    let currentUser = try await supabase.auth.user()
                    let userProfile: [UserSearchResult] = try await supabase
                        .from("profiles")
                        .select("username, avatar_url")
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
                print("⚠️ Following request was cancelled")
                return []
            }
            print("❌ Error fetching following: \(error)")
            return []
        }
    }
    
    /// Get detailed user information for users that the current user follows
    func getFollowingUsers(userId: String) async throws -> [UserSearchResult] {
        do {
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
            let like = PostLike(postId: postId, userId: userId)
            _ = try await supabase
                .from("workout_post_likes")
                .insert(like)
                .execute()
            print("✅ Post liked successfully")
            
            // Create notification if we have post owner info
            if let postOwnerId = postOwnerId, postOwnerId != userId {
                do {
                    // Fetch current user info
                    let currentUser = try await supabase.auth.user()
                    let userProfile: [UserSearchResult] = try await supabase
                        .from("profiles")
                        .select("username, avatar_url")
                        .eq("id", value: currentUser.id.uuidString)
                        .execute()
                        .value
                    
                    if let profile = userProfile.first {
                        try await NotificationService.shared.createLikeNotification(
                            userId: postOwnerId,
                            likedByUserId: userId,
                            likedByUserName: profile.name,
                            likedByUserAvatar: profile.avatarUrl,
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
            _ = try await supabase
                .from("workout_post_likes")
                .delete()
                .eq("workout_post_id", value: postId)
                .eq("user_id", value: userId)
                .execute()
            print("✅ Post unliked successfully")
        } catch {
            print("❌ Error unliking post: \(error)")
            throw error
        }
    }
    
    func getPostLikes(postId: String) async throws -> [PostLike] {
        do {
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
    
    // MARK: - Comment Functions
    
    func addComment(postId: String, userId: String, content: String, postOwnerId: String? = nil, postTitle: String = "") async throws {
        do {
            let comment = PostComment(postId: postId, userId: userId, content: content)
            _ = try await supabase
                .from("workout_post_comments")
                .insert(comment)
                .execute()
            print("✅ Comment added successfully")
            
            // Create notification if we have post owner info
            if let postOwnerId = postOwnerId, postOwnerId != userId {
                do {
                    // Fetch current user info
                    let currentUser = try await supabase.auth.user()
                    let userProfile: [UserSearchResult] = try await supabase
                        .from("profiles")
                        .select("username, avatar_url")
                        .eq("id", value: currentUser.id.uuidString)
                        .execute()
                        .value
                    
                    if let profile = userProfile.first {
                        try await NotificationService.shared.createCommentNotification(
                            userId: postOwnerId,
                            commentedByUserId: userId,
                            commentedByUserName: profile.name,
                            commentedByUserAvatar: profile.avatarUrl,
                            postId: postId,
                            postTitle: postTitle,
                            commentText: content
                        )
                    }
                } catch {
                    print("⚠️ Could not create notification: \(error)")
                    // Don't fail the comment operation if notification fails
                }
            }
        } catch {
            print("❌ Error adding comment: \(error)")
            throw error
        }
    }
    
    func getPostComments(postId: String) async throws -> [PostComment] {
        do {
            // Fetch comments
            let comments: [PostComment] = try await supabase
                .from("workout_post_comments")
                .select()
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
                    userAvatarUrl: user?.avatarUrl
                )
            }
            
            return enrichedComments
        } catch {
            print("❌ Error fetching post comments: \(error)")
            return []
        }
    }
    
    // MARK: - User Search Functions
    
    func getAllUsers() async throws -> [UserSearchResult] {
        do {
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
    
    func searchUsers(query: String, currentUserId: String) async throws -> [UserSearchResult] {
        do {
            print("🔍 Searching for users with query: '\(query)', currentUserId: '\(currentUserId)'")
            
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
    
    // MARK: - Social Feed Functions
    
    func getSocialFeed(userId: String) async throws -> [SocialWorkoutPost] {
        do {
            // Get the users that the current user follows
            let following = try await getFollowing(userId: userId)
            
            // Include current user's ID in the list of users to fetch posts from
            var userIdsToFetch = following
            do {
                let currentUser = try await supabase.auth.user()
                userIdsToFetch.append(currentUser.id.uuidString)
            } catch let userError as URLError {
                if userError.code == .cancelled {
                    print("⚠️ Current user request was cancelled")
                    // If cancelled, still try to fetch with just following IDs
                } else {
                    print("⚠️ Could not get current user: \(userError)")
                }
            } catch {
                print("⚠️ Could not get current user: \(error)")
            }
            
            // If user doesn't follow anyone yet, still show their own posts
            if userIdsToFetch.isEmpty {
                print("⚠️ No users to fetch posts from")
                return []
            }
            
            // Get posts from followed users AND current user with social data
            let posts: [SocialWorkoutPost] = try await supabase
                .from("workout_posts")
                .select("""
                    *,
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
            
            print("✅ Fetched \(posts.count) social feed posts from \(userIdsToFetch.count) users")
            
            return posts
        } catch let urlError as URLError where urlError.code == .cancelled {
            // Don't throw error for cancelled requests
            print("⚠️ Social feed request was cancelled (likely due to refresh)")
            throw CancellationError()
        } catch {
            print("❌ Error fetching social feed: \(error)")
            throw error
        }
    }
}
