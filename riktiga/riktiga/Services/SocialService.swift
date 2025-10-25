import Foundation
import Supabase

class SocialService {
    static let shared = SocialService()
    private let supabase = SupabaseConfig.supabase
    
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
    
    func likePost(postId: String, userId: String) async throws {
        do {
            let like = PostLike(postId: postId, userId: userId)
            _ = try await supabase
                .from("workout_post_likes")
                .insert(like)
                .execute()
            print("✅ Post liked successfully")
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
                .eq("post_id", value: postId)
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
                .eq("post_id", value: postId)
                .execute()
                .value
            
            return likes
        } catch {
            print("❌ Error fetching post likes: \(error)")
            return []
        }
    }
    
    // MARK: - Comment Functions
    
    func addComment(postId: String, userId: String, content: String) async throws {
        do {
            let comment = PostComment(postId: postId, userId: userId, content: content)
            _ = try await supabase
                .from("workout_post_comments")
                .insert(comment)
                .execute()
            print("✅ Comment added successfully")
        } catch {
            print("❌ Error adding comment: \(error)")
            throw error
        }
    }
    
    func getPostComments(postId: String) async throws -> [PostComment] {
        do {
            let comments: [PostComment] = try await supabase
                .from("workout_post_comments")
                .select()
                .eq("post_id", value: postId)
                .order("created_at", ascending: true)
                .execute()
                .value
            
            return comments
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
            // First get the users that the current user follows
            let following = try await getFollowing(userId: userId)
            
            // Include current user's ID in the list of users to fetch posts from
            var userIdsToFetch = following
            do {
                let currentUser = try await supabase.auth.user()
                userIdsToFetch.append(currentUser.id.uuidString)
            } catch {
                print("⚠️ Could not get current user: \(error)")
            }
            
            // If user doesn't follow anyone yet, still show their own posts
            if userIdsToFetch.isEmpty {
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
            
            print("✅ Fetched \(posts.count) social feed posts")
            return posts
        } catch {
            print("❌ Error fetching social feed: \(error)")
            return []
        }
    }
}
