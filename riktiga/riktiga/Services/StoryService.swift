import Foundation
import Supabase
import UIKit
import Combine

// MARK: - Story Service
class StoryService: ObservableObject {
    static let shared = StoryService()
    
    @Published var friendsStories: [UserStories] = []
    @Published var myStories: [Story] = []
    @Published var isLoading = false
    
    private let supabase = SupabaseConfig.supabase
    
    private init() {}
    
    // MARK: - Fetch Stories from Friends
    func fetchFriendsStories(userId: String) async throws -> [UserStories] {
        print("📖 Fetching stories for user: \(userId)")
        
        // First get list of people the user follows (using user_follows table like SocialService)
        let follows: [UserFollowRecord] = try await supabase
            .from("user_follows")
            .select("following_id")
            .eq("follower_id", value: userId)
            .execute()
            .value
        
        let followingIds = follows.map { $0.following_id }
        print("📖 User follows \(followingIds.count) people: \(followingIds)")
        
        guard !followingIds.isEmpty else {
            print("📖 User doesn't follow anyone, no stories to show")
            return []
        }
        
        // Fetch non-expired stories from followed users
        let now = ISO8601DateFormatter().string(from: Date())
        print("📖 Checking for stories newer than: \(now)")
        
        let stories: [Story] = try await supabase
            .from("stories")
            .select("""
                id,
                user_id,
                image_url,
                created_at,
                expires_at,
                profiles!stories_user_id_fkey(username, avatar_url, is_pro_member)
            """)
            .in("user_id", values: followingIds)
            .gt("expires_at", value: now)
            .order("created_at", ascending: false)
            .execute()
            .value
        
        print("📖 Fetched \(stories.count) stories from \(followingIds.count) followed users")
        for story in stories {
            print("📖 - Story from \(story.username ?? "unknown"): \(story.imageUrl.prefix(50))...")
        }
        
        // Get viewed stories for this user
        let viewedStories = try await getViewedStoryIds(userId: userId)
        
        // Group stories by user
        var storiesByUser: [String: [Story]] = [:]
        var userInfo: [String: (username: String, avatarUrl: String?, isProMember: Bool)] = [:]
        
        for var story in stories {
            story.hasViewed = viewedStories.contains(story.id)
            
            if storiesByUser[story.userId] == nil {
                storiesByUser[story.userId] = []
                userInfo[story.userId] = (
                    username: story.username ?? "Användare",
                    avatarUrl: story.avatarUrl,
                    isProMember: story.isProMember ?? false
                )
            }
            storiesByUser[story.userId]?.append(story)
        }
        
        // Convert to UserStories array
        var userStoriesArray: [UserStories] = []
        for (userId, stories) in storiesByUser {
            if let info = userInfo[userId] {
                let hasUnviewed = stories.contains { !$0.hasViewed }
                userStoriesArray.append(UserStories(
                    id: userId,
                    userId: userId,
                    username: info.username,
                    avatarUrl: info.avatarUrl,
                    isProMember: info.isProMember,
                    stories: stories.sorted { $0.createdAt < $1.createdAt },
                    hasUnviewedStories: hasUnviewed
                ))
            }
        }
        
        // Sort: unviewed first, then by latest story time
        userStoriesArray.sort { a, b in
            if a.hasUnviewedStories != b.hasUnviewedStories {
                return a.hasUnviewedStories
            }
            return (a.latestStory?.createdAt ?? .distantPast) > (b.latestStory?.createdAt ?? .distantPast)
        }
        
        await MainActor.run {
            self.friendsStories = userStoriesArray
        }
        
        return userStoriesArray
    }
    
    // MARK: - Fetch My Stories
    func fetchMyStories(userId: String) async throws -> [Story] {
        print("📖 Fetching MY stories for user: \(userId)")
        let now = ISO8601DateFormatter().string(from: Date())
        
        let stories: [Story] = try await supabase
            .from("stories")
            .select("""
                id,
                user_id,
                image_url,
                created_at,
                expires_at,
                profiles!stories_user_id_fkey(username, avatar_url, is_pro_member)
            """)
            .eq("user_id", value: userId)
            .gt("expires_at", value: now)
            .order("created_at", ascending: false)
            .execute()
            .value
        
        print("📖 Found \(stories.count) of MY stories")
        
        await MainActor.run {
            self.myStories = stories
        }
        
        return stories
    }
    
    // MARK: - Post Story
    func postStory(userId: String, image: UIImage) async throws -> Story {
        print("📸 Posting story for user: \(userId)")
        
        // Upload image to storage
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            throw NSError(domain: "StoryError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Could not compress image"])
        }
        
        let fileName = "\(userId)/story_\(UUID().uuidString).jpg"
        
        try await supabase.storage
            .from("stories")
            .upload(
                path: fileName,
                file: imageData,
                options: FileOptions(contentType: "image/jpeg")
            )
        
        let publicURL = try supabase.storage
            .from("stories")
            .getPublicURL(path: fileName)
        
        // Create story record
        let storyId = UUID().uuidString
        let now = Date()
        let expiresAt = now.addingTimeInterval(24 * 60 * 60) // 24 hours
        
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        let storyInsert = StoryInsert(
            id: storyId,
            user_id: userId,
            image_url: publicURL.absoluteString,
            created_at: formatter.string(from: now),
            expires_at: formatter.string(from: expiresAt)
        )
        
        try await supabase
            .from("stories")
            .insert(storyInsert)
            .execute()
        
        print("✅ Story posted successfully")
        
        return Story(
            id: storyId,
            userId: userId,
            imageUrl: publicURL.absoluteString,
            createdAt: now,
            expiresAt: expiresAt
        )
    }
    
    // MARK: - Mark Story as Viewed
    func markStoryAsViewed(storyId: String, viewerId: String) async throws {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        let viewInsert = StoryViewInsert(
            story_id: storyId,
            viewer_id: viewerId,
            viewed_at: formatter.string(from: Date())
        )
        
        // Use upsert to avoid duplicates
        try await supabase
            .from("story_views")
            .upsert(viewInsert)
            .execute()
        
        print("👁️ Marked story \(storyId) as viewed")
    }
    
    // MARK: - Get Viewed Story IDs
    private func getViewedStoryIds(userId: String) async throws -> Set<String> {
        struct ViewRecord: Decodable {
            let story_id: String
        }
        
        let views: [ViewRecord] = try await supabase
            .from("story_views")
            .select("story_id")
            .eq("viewer_id", value: userId)
            .execute()
            .value
        
        return Set(views.map { $0.story_id })
    }
    
    // MARK: - Delete Story
    func deleteStory(storyId: String) async throws {
        try await supabase
            .from("stories")
            .delete()
            .eq("id", value: storyId)
            .execute()
        
        print("🗑️ Story deleted")
    }
    
    // MARK: - Get Story Viewers
    func getStoryViewers(storyId: String) async throws -> [StoryViewer] {
        struct ViewerRecord: Decodable {
            let viewer_id: String
            let viewed_at: String
            let profiles: ViewerProfile?
            
            struct ViewerProfile: Decodable {
                let username: String?
                let avatar_url: String?
            }
        }
        
        let records: [ViewerRecord] = try await supabase
            .from("story_views")
            .select("""
                viewer_id,
                viewed_at,
                profiles!story_views_viewer_id_fkey(username, avatar_url)
            """)
            .eq("story_id", value: storyId)
            .order("viewed_at", ascending: false)
            .execute()
            .value
        
        let viewers = records.map { record in
            StoryViewer(
                id: record.viewer_id,
                username: record.profiles?.username ?? "Användare",
                avatarUrl: record.profiles?.avatar_url
            )
        }
        
        print("👁️ Found \(viewers.count) viewers for story \(storyId)")
        return viewers
    }
    
    // MARK: - Get All Viewers for User's Stories
    func getAllViewersForStories(storyIds: [String]) async throws -> [StoryViewer] {
        guard !storyIds.isEmpty else { return [] }
        
        struct ViewerRecord: Decodable {
            let viewer_id: String
            let profiles: ViewerProfile?
            
            struct ViewerProfile: Decodable {
                let username: String?
                let avatar_url: String?
            }
        }
        
        let records: [ViewerRecord] = try await supabase
            .from("story_views")
            .select("""
                viewer_id,
                profiles!story_views_viewer_id_fkey(username, avatar_url)
            """)
            .in("story_id", values: storyIds)
            .order("viewed_at", ascending: false)
            .execute()
            .value
        
        // Deduplicate viewers (same person might have viewed multiple stories)
        var seenIds = Set<String>()
        var uniqueViewers: [StoryViewer] = []
        
        for record in records {
            if !seenIds.contains(record.viewer_id) {
                seenIds.insert(record.viewer_id)
                uniqueViewers.append(StoryViewer(
                    id: record.viewer_id,
                    username: record.profiles?.username ?? "Användare",
                    avatarUrl: record.profiles?.avatar_url
                ))
            }
        }
        
        print("👁️ Found \(uniqueViewers.count) unique viewers across \(storyIds.count) stories")
        return uniqueViewers
    }
    
    // MARK: - Get View Count for Stories
    func getViewCount(storyIds: [String]) async throws -> Int {
        guard !storyIds.isEmpty else { return 0 }
        
        struct CountRecord: Decodable {
            let viewer_id: String
        }
        
        let records: [CountRecord] = try await supabase
            .from("story_views")
            .select("viewer_id")
            .in("story_id", values: storyIds)
            .execute()
            .value
        
        // Count unique viewers
        let uniqueViewers = Set(records.map { $0.viewer_id })
        return uniqueViewers.count
    }
}

// MARK: - Story Viewer Model
struct StoryViewer: Identifiable, Equatable {
    let id: String
    let username: String
    let avatarUrl: String?
}

// MARK: - Helper Structs
private struct FollowRecord: Decodable {
    let following_id: String
}

private struct UserFollowRecord: Decodable {
    let following_id: String
    
    enum CodingKeys: String, CodingKey {
        case following_id = "following_id"
    }
}

