import Foundation
import Combine

// MARK: - App Cache Manager
class AppCacheManager: ObservableObject {
    static let shared = AppCacheManager()
    
    private let userDefaults = UserDefaults.standard
    // Default cache time (used for most caches)
    private let cacheExpirationTime: TimeInterval = 7 * 24 * 60 * 60
    // Social feed should refresh more often; use a much shorter TTL
    private let socialFeedTTL: TimeInterval = 5 * 60
    
    private init() {}
    
    // MARK: - Cache Keys
    private enum CacheKeys {
        static let allUsers = "cached_all_users"
        static let followers = "cached_followers_"
        static let following = "cached_following_"
        static let userWorkouts = "cached_user_workouts_"
        static let socialFeed = "cached_social_feed_"
        static let weeklyStats = "cached_weekly_stats_"
        static let recommendedUsers = "cached_recommended_users_"
        static let monthlyLeaderboard = "cached_monthly_leaderboard_"
        static let cacheTimestamp = "cache_timestamp_"
    }
    
    // MARK: - All Users Cache
    func saveAllUsers(_ users: [UserSearchResult]) {
        do {
            let data = try JSONEncoder().encode(users)
            userDefaults.set(data, forKey: CacheKeys.allUsers)
            userDefaults.set(Date(), forKey: CacheKeys.cacheTimestamp + CacheKeys.allUsers)
        } catch {
        }
    }
    
    func getCachedAllUsers() -> [UserSearchResult]? {
        guard let data = userDefaults.data(forKey: CacheKeys.allUsers),
              let timestamp = userDefaults.object(forKey: CacheKeys.cacheTimestamp + CacheKeys.allUsers) as? Date,
              Date().timeIntervalSince(timestamp) < cacheExpirationTime else {
            return nil
        }
        
        do {
            let users = try JSONDecoder().decode([UserSearchResult].self, from: data)
            return users
        } catch {
            return nil
        }
    }
    
    // MARK: - Followers Cache
    func saveFollowers(_ followers: [UserSearchResult], userId: String) {
        let key = CacheKeys.followers + userId
        do {
            let data = try JSONEncoder().encode(followers)
            userDefaults.set(data, forKey: key)
            userDefaults.set(Date(), forKey: CacheKeys.cacheTimestamp + key)
        } catch {
        }
    }
    
    func getCachedFollowers(userId: String) -> [UserSearchResult]? {
        let key = CacheKeys.followers + userId
        guard let data = userDefaults.data(forKey: key),
              let timestamp = userDefaults.object(forKey: CacheKeys.cacheTimestamp + key) as? Date,
              Date().timeIntervalSince(timestamp) < cacheExpirationTime else {
            return nil
        }
        
        do {
            let followers = try JSONDecoder().decode([UserSearchResult].self, from: data)
            return followers
        } catch {
            return nil
        }
    }
    
    // MARK: - Following Cache
    func saveFollowing(_ following: [UserSearchResult], userId: String) {
        let key = CacheKeys.following + userId
        do {
            let data = try JSONEncoder().encode(following)
            userDefaults.set(data, forKey: key)
            userDefaults.set(Date(), forKey: CacheKeys.cacheTimestamp + key)
        } catch {
        }
    }
    
    func getCachedFollowing(userId: String) -> [UserSearchResult]? {
        let key = CacheKeys.following + userId
        guard let data = userDefaults.data(forKey: key),
              let timestamp = userDefaults.object(forKey: CacheKeys.cacheTimestamp + key) as? Date,
              Date().timeIntervalSince(timestamp) < cacheExpirationTime else {
            return nil
        }
        
        do {
            let following = try JSONDecoder().decode([UserSearchResult].self, from: data)
            return following
        } catch {
            return nil
        }
    }
    
    // MARK: - User Workouts Cache
    func saveUserWorkouts(_ workouts: [WorkoutPost], userId: String) {
        let key = CacheKeys.userWorkouts + userId
        do {
            let data = try JSONEncoder().encode(workouts)
            userDefaults.set(data, forKey: key)
            userDefaults.set(Date(), forKey: CacheKeys.cacheTimestamp + key)
        } catch {
        }
    }
    
    func getCachedUserWorkouts(userId: String, allowExpired: Bool = false) -> [WorkoutPost]? {
        let key = CacheKeys.userWorkouts + userId
        guard let data = userDefaults.data(forKey: key) else { return nil }
        if !allowExpired {
            guard let timestamp = userDefaults.object(forKey: CacheKeys.cacheTimestamp + key) as? Date,
                  Date().timeIntervalSince(timestamp) < cacheExpirationTime else {
                return nil
            }
        }
        
        do {
            let workouts = try JSONDecoder().decode([WorkoutPost].self, from: data)
            return workouts
        } catch {
            return nil
        }
    }
    
    // MARK: - Social Feed Cache
    func saveSocialFeed(_ posts: [SocialWorkoutPost], userId: String) {
        let key = CacheKeys.socialFeed + userId
        do {
            let data = try JSONEncoder().encode(posts)
            userDefaults.set(data, forKey: key)
            userDefaults.set(Date(), forKey: CacheKeys.cacheTimestamp + key)
        } catch {
        }
    }
    
    func getCachedSocialFeed(userId: String, allowExpired: Bool = false) -> [SocialWorkoutPost]? {
        let key = CacheKeys.socialFeed + userId
        guard let data = userDefaults.data(forKey: key) else { return nil }
        if !allowExpired {
            guard let timestamp = userDefaults.object(forKey: CacheKeys.cacheTimestamp + key) as? Date,
                  Date().timeIntervalSince(timestamp) < socialFeedTTL else {
                return nil
            }
        }
        
        do {
            let posts = try JSONDecoder().decode([SocialWorkoutPost].self, from: data)
            return posts
        } catch {
            return nil
        }
    }
    
    // MARK: - Weekly Stats Cache
    func saveWeeklyStats(_ stats: WeeklyStats, userId: String) {
        let key = CacheKeys.weeklyStats + userId
        do {
            let data = try JSONEncoder().encode(stats)
            userDefaults.set(data, forKey: key)
            userDefaults.set(Date(), forKey: CacheKeys.cacheTimestamp + key)
        } catch {
        }
    }
    
    func getCachedWeeklyStats(userId: String) -> WeeklyStats? {
        let key = CacheKeys.weeklyStats + userId
        guard let data = userDefaults.data(forKey: key),
              let timestamp = userDefaults.object(forKey: CacheKeys.cacheTimestamp + key) as? Date,
              Date().timeIntervalSince(timestamp) < cacheExpirationTime else {
            return nil
        }
        
        do {
            let stats = try JSONDecoder().decode(WeeklyStats.self, from: data)
            return stats
        } catch {
            return nil
        }
    }
    
    // MARK: - Recommended Friends Cache
    func saveRecommendedUsers(_ users: [UserSearchResult], userId: String) {
        let key = CacheKeys.recommendedUsers + userId
        do {
            let data = try JSONEncoder().encode(users)
            userDefaults.set(data, forKey: key)
            userDefaults.set(Date(), forKey: CacheKeys.cacheTimestamp + key)
        } catch { }
    }
    
    func getCachedRecommendedUsers(userId: String) -> [UserSearchResult]? {
        let key = CacheKeys.recommendedUsers + userId
        guard let data = userDefaults.data(forKey: key),
              let timestamp = userDefaults.object(forKey: CacheKeys.cacheTimestamp + key) as? Date,
              Date().timeIntervalSince(timestamp) < 24*60*60 else { // 24h
            return nil
        }
        do {
            return try JSONDecoder().decode([UserSearchResult].self, from: data)
        } catch { return nil }
    }
    
    // MARK: - Monthly Leaderboard Cache
    func saveMonthlyLeaderboard(_ users: [MonthlyUser], monthKey: String) {
        let key = CacheKeys.monthlyLeaderboard + monthKey
        do {
            let data = try JSONEncoder().encode(users)
            userDefaults.set(data, forKey: key)
            userDefaults.set(Date(), forKey: CacheKeys.cacheTimestamp + key)
        } catch { }
    }
    
    func getCachedMonthlyLeaderboard(monthKey: String) -> [MonthlyUser]? {
        let key = CacheKeys.monthlyLeaderboard + monthKey
        guard let data = userDefaults.data(forKey: key),
              let timestamp = userDefaults.object(forKey: CacheKeys.cacheTimestamp + key) as? Date,
              Date().timeIntervalSince(timestamp) < 6*60*60 else { // 6h
            return nil
        }
        do { return try JSONDecoder().decode([MonthlyUser].self, from: data) } catch { return nil }
    }
    
    // MARK: - Cache Management
    func clearAllCache() {
        let keys = userDefaults.dictionaryRepresentation().keys
        for key in keys {
            if key.hasPrefix("cached_") || key.hasPrefix("cache_timestamp_") {
                userDefaults.removeObject(forKey: key)
            }
        }
    }
    
    func clearCacheForUser(userId: String) {
        let keys = [
            CacheKeys.followers + userId,
            CacheKeys.following + userId,
            CacheKeys.userWorkouts + userId,
            CacheKeys.socialFeed + userId,
            CacheKeys.weeklyStats + userId,
            CacheKeys.cacheTimestamp + CacheKeys.followers + userId,
            CacheKeys.cacheTimestamp + CacheKeys.following + userId,
            CacheKeys.cacheTimestamp + CacheKeys.userWorkouts + userId,
            CacheKeys.cacheTimestamp + CacheKeys.socialFeed + userId,
            CacheKeys.cacheTimestamp + CacheKeys.weeklyStats + userId
        ]
        
        for key in keys {
            userDefaults.removeObject(forKey: key)
        }
    }
    
    func isCacheValid(for key: String) -> Bool {
        guard let timestamp = userDefaults.object(forKey: CacheKeys.cacheTimestamp + key) as? Date else {
            return false
        }
        return Date().timeIntervalSince(timestamp) < cacheExpirationTime
    }
}
