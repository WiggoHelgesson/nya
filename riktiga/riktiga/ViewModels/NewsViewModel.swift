import Foundation
import SwiftUI
import Supabase
import Combine

// MARK: - News Model
struct NewsItem: Identifiable, Codable {
    let id: String
    let content: String
    let authorId: String
    let authorName: String
    let authorAvatarUrl: String?
    let createdAt: String
    let imageUrl: String?
    var likeCount: Int?
    var isLikedByCurrentUser: Bool?
    
    enum CodingKeys: String, CodingKey {
        case id
        case content
        case authorId = "author_id"
        case authorName = "author_name"
        case authorAvatarUrl = "author_avatar_url"
        case createdAt = "created_at"
        case imageUrl = "image_url"
        case likeCount = "like_count"
    }
    
    var formattedDate: String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        guard let date = formatter.date(from: createdAt) else {
            // Try without fractional seconds
            formatter.formatOptions = [.withInternetDateTime]
            guard let date = formatter.date(from: createdAt) else {
                return ""
            }
            return formatRelativeDate(date)
        }
        return formatRelativeDate(date)
    }
    
    private func formatRelativeDate(_ date: Date) -> String {
        let now = Date()
        let diff = now.timeIntervalSince(date)
        
        if diff < 60 {
            return "just nu"
        } else if diff < 3600 {
            let minutes = Int(diff / 60)
            return "\(minutes) min sedan"
        } else if diff < 86400 {
            let hours = Int(diff / 3600)
            return "\(hours) tim sedan"
        } else if diff < 604800 {
            let days = Int(diff / 86400)
            return "\(days) dagar sedan"
        } else {
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "d MMM"
            dateFormatter.locale = Locale(identifier: "sv_SE")
            return dateFormatter.string(from: date)
        }
    }
}

// MARK: - News ViewModel
@MainActor
class NewsViewModel: ObservableObject {
    @Published var news: [NewsItem] = []
    @Published var isLoading = false
    @Published var error: String?
    
    private let supabase = SupabaseConfig.supabase
    
    func fetchNews() async {
        isLoading = true
        error = nil
        
        do {
            let response: [NewsItem] = try await supabase
                .from("news")
                .select()
                .order("created_at", ascending: false)
                .limit(50)
                .execute()
                .value
            
            news = response
            print("✅ Fetched \(response.count) news items")
            
            // Mark which news the current user has liked
            await markLikedNews()
        } catch {
            self.error = error.localizedDescription
            print("❌ Failed to fetch news: \(error)")
        }
        
        isLoading = false
    }
    
    func createNews(content: String, imageUrl: String? = nil) async -> Bool {
        do {
            let user = try await supabase.auth.user()
            
            // Verify this is the admin email
            guard user.email?.lowercased() == "info@bylito.se" else {
                print("❌ Only admin can create news")
                return false
            }
            
            // Fetch news profile settings (separate from personal profile)
            struct NewsSettings: Decodable {
                let avatar_url: String?
            }
            
            let newsSettings: [NewsSettings] = try await supabase
                .from("news_settings")
                .select("avatar_url")
                .limit(1)
                .execute()
                .value
            
            // Use news avatar, fallback to nil (will show default logo)
            let newsAvatar = newsSettings.first?.avatar_url
            
            struct NewsPayload: Encodable {
                let id: String
                let content: String
                let author_id: String
                let author_name: String
                let author_avatar_url: String?
                let image_url: String?
                let created_at: String
            }
            
            let payload = NewsPayload(
                id: UUID().uuidString,
                content: content,
                author_id: user.id.uuidString,
                author_name: "Up&Down",  // Always use Up&Down for news
                author_avatar_url: newsAvatar,
                image_url: imageUrl,
                created_at: ISO8601DateFormatter().string(from: Date())
            )
            
            try await supabase
                .from("news")
                .insert(payload)
                .execute()
            
            print("✅ News created successfully")
            
            // Send push notification to all users
            await PushNotificationService.shared.notifyAllUsersAboutNews(newsId: payload.id)
            
            // Refresh news feed
            await fetchNews()
            
            return true
        } catch {
            print("❌ Failed to create news: \(error)")
            return false
        }
    }
    
    func deleteNews(id: String) async -> Bool {
        do {
            try await supabase
                .from("news")
                .delete()
                .eq("id", value: id)
                .execute()
            
            // Remove from local array
            news.removeAll { $0.id == id }
            
            print("✅ News deleted successfully")
            return true
        } catch {
            print("❌ Failed to delete news: \(error)")
            return false
        }
    }
    
    func updateNews(id: String, content: String, imageUrl: String? = nil) async -> Bool {
        do {
            struct UpdatePayload: Encodable {
                let content: String
                let image_url: String?
            }
            
            let payload = UpdatePayload(content: content, image_url: imageUrl)
            
            try await supabase
                .from("news")
                .update(payload)
                .eq("id", value: id)
                .execute()
            
            // Update local array
            if let index = news.firstIndex(where: { $0.id == id }) {
                // Refresh to get updated item
                await fetchNews()
            }
            
            print("✅ News updated successfully")
            return true
        } catch {
            print("❌ Failed to update news: \(error)")
            return false
        }
    }
    
    func updateAllNewsAvatars(avatarUrl: String) async {
        do {
            struct AvatarPayload: Encodable {
                let author_avatar_url: String
            }
            
            // Update all news items - use gte on created_at to match all rows
            try await supabase
                .from("news")
                .update(AvatarPayload(author_avatar_url: avatarUrl))
                .gte("created_at", value: "1900-01-01")
                .execute()
            
            // Refresh news to show updated avatars
            await fetchNews()
            
            print("✅ All news avatars updated")
        } catch {
            print("❌ Failed to update news avatars: \(error)")
        }
    }
    
    // MARK: - Like Functions
    
    func likeNews(newsId: String) async -> Bool {
        do {
            let user = try await supabase.auth.user()
            
            struct LikePayload: Encodable {
                let news_id: String
                let user_id: String
            }
            
            try await supabase
                .from("news_likes")
                .insert(LikePayload(news_id: newsId, user_id: user.id.uuidString))
                .execute()
            
            // Update local state
            if let index = news.firstIndex(where: { $0.id == newsId }) {
                var updatedNews = news[index]
                updatedNews.likeCount = (updatedNews.likeCount ?? 0) + 1
                updatedNews.isLikedByCurrentUser = true
                news[index] = updatedNews
            }
            
            print("✅ News liked successfully")
            return true
        } catch {
            print("❌ Failed to like news: \(error)")
            return false
        }
    }
    
    func unlikeNews(newsId: String) async -> Bool {
        do {
            let user = try await supabase.auth.user()
            
            try await supabase
                .from("news_likes")
                .delete()
                .eq("news_id", value: newsId)
                .eq("user_id", value: user.id.uuidString)
                .execute()
            
            // Update local state
            if let index = news.firstIndex(where: { $0.id == newsId }) {
                var updatedNews = news[index]
                updatedNews.likeCount = max((updatedNews.likeCount ?? 0) - 1, 0)
                updatedNews.isLikedByCurrentUser = false
                news[index] = updatedNews
            }
            
            print("✅ News unliked successfully")
            return true
        } catch {
            print("❌ Failed to unlike news: \(error)")
            return false
        }
    }
    
    func checkIfLiked(newsId: String) async -> Bool {
        do {
            let user = try await supabase.auth.user()
            
            struct LikeResult: Decodable {
                let id: String
            }
            
            let result: [LikeResult] = try await supabase
                .from("news_likes")
                .select("id")
                .eq("news_id", value: newsId)
                .eq("user_id", value: user.id.uuidString)
                .limit(1)
                .execute()
                .value
            
            return !result.isEmpty
        } catch {
            print("❌ Failed to check if liked: \(error)")
            return false
        }
    }
    
    func markLikedNews() async {
        do {
            let user = try await supabase.auth.user()
            let newsIds = news.map { $0.id }
            
            guard !newsIds.isEmpty else { return }
            
            struct LikeResult: Decodable {
                let news_id: String
            }
            
            let likes: [LikeResult] = try await supabase
                .from("news_likes")
                .select("news_id")
                .eq("user_id", value: user.id.uuidString)
                .in("news_id", values: newsIds)
                .execute()
                .value
            
            let likedNewsIds = Set(likes.map { $0.news_id })
            
            // Update local state
            for i in 0..<news.count {
                var updatedNews = news[i]
                updatedNews.isLikedByCurrentUser = likedNewsIds.contains(updatedNews.id)
                news[i] = updatedNews
            }
            
            print("✅ Marked \(likedNewsIds.count) news as liked")
        } catch {
            print("❌ Failed to mark liked news: \(error)")
        }
    }
}

