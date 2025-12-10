import Foundation
import UIKit
import UserNotifications
import Supabase

final class PushNotificationService: NSObject {
    static let shared = PushNotificationService()
    
    private override init() {
        super.init()
    }
    
    // MARK: - Request Permission & Register
    
    func requestPermissionAndRegister() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            print("🔔 Push notification permission granted: \(granted)")
            if granted {
                DispatchQueue.main.async {
                    UIApplication.shared.registerForRemoteNotifications()
                }
            }
        }
    }
    
    // MARK: - Save Device Token
    
    func saveDeviceToken(_ token: Data) {
        let tokenString = token.map { String(format: "%02.2hhx", $0) }.joined()
        print("📱 Device token: \(tokenString)")
        
        Task {
            do {
                try await saveTokenToDatabase(tokenString)
                print("✅ Device token saved to database")
            } catch {
                print("❌ Failed to save device token: \(error)")
            }
        }
    }
    
    private func saveTokenToDatabase(_ token: String) async throws {
        guard let userId = try? await SupabaseConfig.supabase.auth.session.user.id else {
            print("⚠️ No user logged in, skipping token save")
            return
        }
        
        try await AuthSessionManager.shared.ensureValidSession()
        
        struct TokenPayload: Encodable {
            let user_id: String
            let token: String
            let platform: String
            let updated_at: String
        }
        
        let formatter = ISO8601DateFormatter()
        let payload = TokenPayload(
            user_id: userId.uuidString,
            token: token,
            platform: "ios",
            updated_at: formatter.string(from: Date())
        )
        
        // Upsert - insert or update if exists
        try await SupabaseConfig.supabase
            .from("device_tokens")
            .upsert(payload, onConflict: "user_id,token")
            .execute()
    }
    
    // MARK: - Remove Device Token (on logout)
    
    func removeDeviceToken() {
        Task {
            do {
                guard let userId = try? await SupabaseConfig.supabase.auth.session.user.id else { return }
                
                try await SupabaseConfig.supabase
                    .from("device_tokens")
                    .delete()
                    .eq("user_id", value: userId.uuidString)
                    .execute()
                
                print("✅ Device token removed from database")
            } catch {
                print("❌ Failed to remove device token: \(error)")
            }
        }
    }
    
    // MARK: - Notify Followers About New Workout
    
    func notifyFollowersAboutWorkout(
        userId: String,
        userName: String,
        userAvatar: String?,
        activityType: String,
        postId: String
    ) async {
        do {
            // Get all followers
            let followers = try await SocialService.shared.getFollowers(userId: userId)
            
            guard !followers.isEmpty else {
                print("📭 No followers to notify")
                return
            }
            
            print("🔔 Notifying \(followers.count) followers about new workout")
            
            // Create in-app notification for each follower
            for followerId in followers {
                // Don't notify yourself
                guard followerId != userId else { continue }
                
                do {
                    try await createWorkoutNotification(
                        forUserId: followerId,
                        fromUserId: userId,
                        fromUserName: userName,
                        fromUserAvatar: userAvatar,
                        activityType: activityType,
                        postId: postId
                    )
                } catch {
                    print("⚠️ Failed to notify follower \(followerId): \(error)")
                }
            }
            
            print("✅ All followers notified")
        } catch {
            print("❌ Failed to get followers for notification: \(error)")
        }
    }
    
    private func createWorkoutNotification(
        forUserId userId: String,
        fromUserId: String,
        fromUserName: String,
        fromUserAvatar: String?,
        activityType: String,
        postId: String
    ) async throws {
        try await AuthSessionManager.shared.ensureValidSession()
        
        struct NotificationPayload: Encodable {
            let user_id: String
            let actor_id: String
            let actor_username: String
            let actor_avatar_url: String?
            let type: String
            let post_id: String
        }
        
        let payload = NotificationPayload(
            user_id: userId,
            actor_id: fromUserId,
            actor_username: fromUserName,
            actor_avatar_url: fromUserAvatar,
            type: "new_workout",
            post_id: postId
        )
        
        try await SupabaseConfig.supabase
            .from("notifications")
            .insert(payload)
            .execute()
    }
}

// MARK: - App Delegate for Push Notifications

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }
    
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        PushNotificationService.shared.saveDeviceToken(deviceToken)
    }
    
    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("❌ Failed to register for remote notifications: \(error)")
    }
    
    // Handle notification when app is in foreground
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound, .badge])
    }
    
    // Handle notification tap
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        let userInfo = response.notification.request.content.userInfo
        print("📱 Notification tapped: \(userInfo)")
        // Handle navigation based on notification type
        completionHandler()
    }
}

