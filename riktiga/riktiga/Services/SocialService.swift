import Foundation
import Supabase

class SocialService {
    static let shared = SocialService()
    private let supabase = SupabaseConfig.supabase
    
    // MARK: - Follow Functions
    
    func followUser(followerId: String, followingId: String) async throws {
        do {
            let follow = Follow(followerId: followerId, followingId: followingId)
            _ = try await supabase
                .from("follows")
                .insert(follow)
                .execute()
            print("✅ User followed successfully")
        } catch {
            print("❌ Error following user: \(error)")
            throw error
        }
    }
    
    func unfollowUser(followerId: String, followingId: String) async throws {
        do {
            _ = try await supabase
                .from("follows")
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
    
    func getFollowing(userId: String) async throws -> [String] {
        do {
            let follows: [Follow] = try await supabase
                .from("follows")
                .select()
                .eq("follower_id", value: userId)
                .execute()
                .value
            
            return follows.map { $0.followingId }
        } catch {
            print("❌ Error fetching following: \(error)")
            return []
        }
    }
    
    func getFollowers(userId: String) async throws -> [String] {
        do {
            let follows: [Follow] = try await supabase
                .from("follows")
                .select()
                .eq("following_id", value: userId)
                .execute()
                .value
            
            return follows.map { $0.followerId }
        } catch {
            print("❌ Error fetching followers: \(error)")
            return []
        }
    }
    
    // MARK: - Like Functions
    
    func likePost(postId: String, userId: String) async throws {
        do {
            let like = PostLike(postId: postId, userId: userId)
            _ = try await supabase
                .from("post_likes")
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
                .from("post_likes")
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
                .from("post_likes")
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
                .from("post_comments")
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
                .from("post_comments")
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
    
    func searchUsers(query: String, currentUserId: String) async throws -> [UserSearchResult] {
        do {
            let users: [UserSearchResult] = try await supabase
                .from("profiles")
                .select("id, username, avatar_url")
                .ilike("username", pattern: "%\(query)%")
                .neq("id", value: currentUserId)
                .limit(20)
                .execute()
                .value
            
            print("✅ Found \(users.count) users matching '\(query)'")
            return users
        } catch {
            print("❌ Error searching users: \(error)")
            return []
        }
    }
    
    func isFollowing(followerId: String, followingId: String) async throws -> Bool {
        do {
            let follows: [Follow] = try await supabase
                .from("follows")
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
    
    // MARK: - Social Feed Functions
    
    func getSocialFeed(userId: String) async throws -> [SocialWorkoutPost] {
        do {
            // First get the users that the current user follows
            let following = try await getFollowing(userId: userId)
            
            if following.isEmpty {
                return []
            }
            
            // Get posts from followed users with social data
            let posts: [SocialWorkoutPost] = try await supabase
                .from("workout_posts")
                .select("""
                    *,
                    profiles!workout_posts_user_id_fkey(name, avatar_url),
                    post_likes(count),
                    post_comments(count)
                """)
                .in("user_id", values: following)
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
