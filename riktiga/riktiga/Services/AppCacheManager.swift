import Foundation
import Combine

// MARK: - App Cache Manager
class AppCacheManager: ObservableObject {
    static let shared = AppCacheManager()
    
    private let userDefaults = UserDefaults.standard
    private let cacheExpirationTime: TimeInterval = 300 // 5 minutes
    
    private init() {}
    
    // MARK: - Cache Keys
    private enum CacheKeys {
        static let allUsers = "cached_all_users"
        static let followers = "cached_followers_"
        static let following = "cached_following_"
        static let userWorkouts = "cached_user_workouts_"
        static let cacheTimestamp = "cache_timestamp_"
    }
    
    // MARK: - All Users Cache
    func saveAllUsers(_ users: [UserSearchResult]) {
        do {
            let data = try JSONEncoder().encode(users)
            userDefaults.set(data, forKey: CacheKeys.allUsers)
            userDefaults.set(Date(), forKey: CacheKeys.cacheTimestamp + CacheKeys.allUsers)
            print("✅ Saved \(users.count) users to cache")
        } catch {
            print("❌ Error saving users to cache: \(error)")
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
            print("✅ Loaded \(users.count) users from cache")
            return users
        } catch {
            print("❌ Error loading users from cache: \(error)")
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
            print("✅ Saved \(followers.count) followers for user \(userId) to cache")
        } catch {
            print("❌ Error saving followers to cache: \(error)")
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
            print("✅ Loaded \(followers.count) followers for user \(userId) from cache")
            return followers
        } catch {
            print("❌ Error loading followers from cache: \(error)")
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
            print("✅ Saved \(following.count) following for user \(userId) to cache")
        } catch {
            print("❌ Error saving following to cache: \(error)")
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
            print("✅ Loaded \(following.count) following for user \(userId) from cache")
            return following
        } catch {
            print("❌ Error loading following from cache: \(error)")
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
            print("✅ Saved \(workouts.count) workouts for user \(userId) to cache")
        } catch {
            print("❌ Error saving workouts to cache: \(error)")
        }
    }
    
    func getCachedUserWorkouts(userId: String) -> [WorkoutPost]? {
        let key = CacheKeys.userWorkouts + userId
        guard let data = userDefaults.data(forKey: key),
              let timestamp = userDefaults.object(forKey: CacheKeys.cacheTimestamp + key) as? Date,
              Date().timeIntervalSince(timestamp) < cacheExpirationTime else {
            return nil
        }
        
        do {
            let workouts = try JSONDecoder().decode([WorkoutPost].self, from: data)
            print("✅ Loaded \(workouts.count) workouts for user \(userId) from cache")
            return workouts
        } catch {
            print("❌ Error loading workouts from cache: \(error)")
            return nil
        }
    }
    
    // MARK: - Cache Management
    func clearAllCache() {
        let keys = userDefaults.dictionaryRepresentation().keys
        for key in keys {
            if key.hasPrefix("cached_") || key.hasPrefix("cache_timestamp_") {
                userDefaults.removeObject(forKey: key)
            }
        }
        print("✅ Cleared all app cache")
    }
    
    func clearCacheForUser(userId: String) {
        let keys = [
            CacheKeys.followers + userId,
            CacheKeys.following + userId,
            CacheKeys.userWorkouts + userId,
            CacheKeys.cacheTimestamp + CacheKeys.followers + userId,
            CacheKeys.cacheTimestamp + CacheKeys.following + userId,
            CacheKeys.cacheTimestamp + CacheKeys.userWorkouts + userId
        ]
        
        for key in keys {
            userDefaults.removeObject(forKey: key)
        }
        print("✅ Cleared cache for user \(userId)")
    }
    
    func isCacheValid(for key: String) -> Bool {
        guard let timestamp = userDefaults.object(forKey: CacheKeys.cacheTimestamp + key) as? Date else {
            return false
        }
        return Date().timeIntervalSince(timestamp) < cacheExpirationTime
    }
}
