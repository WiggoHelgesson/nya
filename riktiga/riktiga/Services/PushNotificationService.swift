import Foundation
import UIKit
import UserNotifications
import Supabase
import Functions
import Combine
import SuperwallKit

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
    
    private func saveTokenToDatabase(_ tokenString: String) async throws {
        guard let userId = try? await SupabaseConfig.supabase.auth.session.user.id else {
            print("⚠️ No user logged in, skipping token save")
            return
        }
        
        try await AuthSessionManager.shared.ensureValidSession()
        
        struct TokenPayload: Encodable {
            let user_id: String
            let token: String
            let platform: String
            let device_type: String
            let is_active: Bool
        }
        
        let payload = TokenPayload(
            user_id: userId.uuidString,
            token: tokenString,
            platform: "ios",
            device_type: "iPhone",
            is_active: true
        )
        
        print("🔔 [PUSH] Saving device token for user: \(userId.uuidString)")
        
        // Delete old tokens for this user first, then insert new one
        try? await SupabaseConfig.supabase
            .from("device_tokens")
            .delete()
            .eq("user_id", value: userId.uuidString)
            .execute()
        
        try await SupabaseConfig.supabase
            .from("device_tokens")
            .insert(payload)
            .execute()
        
        print("✅ [PUSH] Device token saved successfully")
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
        print("🔔 [PUSH] Starting notification flow for workout by \(userName)")
        print("🔔 [PUSH] User ID: \(userId), Activity: \(activityType), Post ID: \(postId)")
        
        do {
            // Get all followers
            let followers = try await SocialService.shared.getFollowers(userId: userId)
            
            guard !followers.isEmpty else {
                print("📭 [PUSH] No followers to notify for user \(userId)")
                return
            }
            
            print("🔔 [PUSH] Found \(followers.count) followers to notify: \(followers)")
            
            // Create in-app notification AND send push for each follower
            for followerId in followers {
                // Don't notify yourself
                guard followerId != userId else {
                    print("⏭️ [PUSH] Skipping self-notification for \(followerId)")
                    continue
                }
                
                print("📤 [PUSH] Sending notification to follower: \(followerId)")
                
                do {
                    // 1. Create in-app notification
                    try await createWorkoutNotification(
                        forUserId: followerId,
                        fromUserId: userId,
                        fromUserName: userName,
                        fromUserAvatar: userAvatar,
                        activityType: activityType,
                        postId: postId
                    )
                    print("✅ [PUSH] In-app notification created for \(followerId)")
                    
                    // 2. Send real iOS push notification via Edge Function
                    await sendRealPushNotification(
                        toUserId: followerId,
                        title: "Nytt träningspass",
                        body: "\(userName) har slutfört ett \(activityType.lowercased())",
                        data: ["type": "new_workout", "post_id": postId, "actor_id": userId]
                    )
                    print("✅ [PUSH] Push notification sent to \(followerId)")
                } catch {
                    print("⚠️ [PUSH] Failed to notify follower \(followerId): \(error)")
                }
            }
            
            print("✅ [PUSH] All \(followers.count) followers notified with push notifications")
        } catch {
            print("❌ [PUSH] Failed to get followers for notification: \(error)")
        }
    }
    
    // MARK: - Notify Followers About New Story
    
    func notifyFollowersAboutStory(
        userId: String,
        userName: String,
        userAvatar: String?
    ) async {
        print("📖 [PUSH] Starting story notification flow for \(userName)")
        
        do {
            // Get all followers
            let followers = try await SocialService.shared.getFollowers(userId: userId)
            
            guard !followers.isEmpty else {
                print("📭 [PUSH] No followers to notify about story")
                return
            }
            
            print("📖 [PUSH] Found \(followers.count) followers to notify about new story")
            
            for followerId in followers {
                guard followerId != userId else { continue }
                
                do {
                    // Create in-app notification
                    try await createStoryNotification(
                        forUserId: followerId,
                        fromUserId: userId,
                        fromUserName: userName,
                        fromUserAvatar: userAvatar
                    )
                    
                    // Send real iOS push notification
                    await sendRealPushNotification(
                        toUserId: followerId,
                        title: "📸 Ny händelse",
                        body: "\(userName) laddade upp en ny story!",
                        data: ["type": "new_story", "actor_id": userId]
                    )
                } catch {
                    print("⚠️ [PUSH] Failed to notify follower \(followerId) about story: \(error)")
                }
            }
            
            print("✅ [PUSH] All followers notified about new story")
        } catch {
            print("❌ [PUSH] Failed to get followers for story notification: \(error)")
        }
    }
    
    // MARK: - Create Story Notification in Database
    
    private func createStoryNotification(
        forUserId: String,
        fromUserId: String,
        fromUserName: String,
        fromUserAvatar: String?
    ) async throws {
        try await AuthSessionManager.shared.ensureValidSession()
        
        struct NotificationPayload: Encodable {
            let user_id: String
            let actor_id: String
            let actor_username: String
            let actor_avatar_url: String?
            let type: String
        }
        
        let payload = NotificationPayload(
            user_id: forUserId,
            actor_id: fromUserId,
            actor_username: fromUserName,
            actor_avatar_url: fromUserAvatar,
            type: "new_story"
        )
        
        try await SupabaseConfig.supabase
            .from("notifications")
            .insert(payload)
            .execute()
        
        print("✅ [PUSH] Created story notification for user \(forUserId)")
    }
    
    // MARK: - Notify Followers About New PB
    
    func notifyFollowersAboutPB(
        userId: String,
        userName: String,
        userAvatar: String?,
        exerciseName: String,
        pbValue: String,
        postId: String
    ) async {
        print("🏆 [PUSH] Starting PB notification flow for \(userName)")
        print("🏆 [PUSH] Exercise: \(exerciseName), PB: \(pbValue)")
        
        do {
            // Get all followers
            let followers = try await SocialService.shared.getFollowers(userId: userId)
            
            guard !followers.isEmpty else {
                print("📭 [PUSH] No followers to notify about PB")
                return
            }
            
            print("🏆 [PUSH] Found \(followers.count) followers to notify about PB")
            
            for followerId in followers {
                guard followerId != userId else { continue }
                
                do {
                    // Create in-app notification
                    try await createPBNotification(
                        forUserId: followerId,
                        fromUserId: userId,
                        fromUserName: userName,
                        fromUserAvatar: userAvatar,
                        exerciseName: exerciseName,
                        pbValue: pbValue,
                        postId: postId
                    )
                    
                    // Send real iOS push notification
                    await sendRealPushNotification(
                        toUserId: followerId,
                        title: "🏆 Nytt PB!",
                        body: "\(userName) slog nytt PB i \(exerciseName) (\(pbValue)), gå in och supporta!",
                        data: ["type": "new_pb", "post_id": postId, "actor_id": userId]
                    )
                } catch {
                    print("⚠️ [PUSH] Failed to notify follower \(followerId) about PB: \(error)")
                }
            }
            
            print("✅ [PUSH] All followers notified about PB")
        } catch {
            print("❌ [PUSH] Failed to get followers for PB notification: \(error)")
        }
    }
    
    // MARK: - Create PB Notification in Database
    
    private func createPBNotification(
        forUserId: String,
        fromUserId: String,
        fromUserName: String,
        fromUserAvatar: String?,
        exerciseName: String,
        pbValue: String,
        postId: String
    ) async throws {
        struct NotificationPayload: Encodable {
            let user_id: String
            let type: String
            let actor_id: String
            let actor_name: String
            let actor_avatar: String?
            let reference_id: String
            let message: String
        }
        
        let payload = NotificationPayload(
            user_id: forUserId,
            type: "new_pb",
            actor_id: fromUserId,
            actor_name: fromUserName,
            actor_avatar: fromUserAvatar,
            reference_id: postId,
            message: "\(fromUserName) slog nytt PB i \(exerciseName): \(pbValue)"
        )
        
        try await SupabaseConfig.supabase
            .from("notifications")
            .insert(payload)
            .execute()
    }
    
    // MARK: - Send Real iOS Push via Edge Function
    
    func sendRealPushNotification(
        toUserId userId: String,
        title: String,
        body: String,
        data: [String: String]? = nil
    ) async {
        print("📱 [PUSH] Calling Edge Function for user: \(userId)")
        print("📱 [PUSH] Title: \(title), Body: \(body)")
        
        do {
            struct PushPayload: Encodable {
                let user_id: String
                let title: String
                let body: String
                let data: [String: String]?
            }
            
            let payload = PushPayload(
                user_id: userId,
                title: title,
                body: body,
                data: data
            )
            
            // Call the Edge Function to send real iOS push
            try await SupabaseConfig.supabase.functions.invoke(
                "send-push-notification",
                options: FunctionInvokeOptions(body: payload)
            )
            
            print("✅ [PUSH] Real push notification sent to user: \(userId)")
        } catch {
            print("⚠️ [PUSH] Failed to send real push notification to \(userId): \(error)")
            // Don't throw - push failures shouldn't block the main flow
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
    
    // MARK: - Notify All Users About News
    
    func notifyAllUsersAboutNews(newsId: String) async {
        print("🔔 [PUSH] Sending news notification to all users")
        
        do {
            // Get all device tokens (all active users)
            struct DeviceToken: Decodable {
                let user_id: String
            }
            
            let tokens: [DeviceToken] = try await SupabaseConfig.supabase
                .from("device_tokens")
                .select("user_id")
                .eq("is_active", value: true)
                .execute()
                .value
            
            let uniqueUserIds = Set(tokens.map { $0.user_id })
            print("🔔 [PUSH] Found \(uniqueUserIds.count) users to notify about news")
            
            // Send push to each user
            for userId in uniqueUserIds {
                await sendRealPushNotification(
                    toUserId: userId,
                    title: "Ny Nyhet",
                    body: "Up&Down la ut en ny nyhet!",
                    data: ["type": "news", "news_id": newsId]
                )
            }
            
            print("✅ [PUSH] News notification sent to all users")
        } catch {
            print("❌ [PUSH] Failed to send news notifications: \(error)")
        }
    }
    
    // MARK: - Notify User About Shared Workout
    
    func notifyUserAboutSharedWorkout(
        receiverId: String,
        senderName: String,
        workoutName: String
    ) async {
        print("🏋️ [PUSH] Sending shared workout notification to \(receiverId)")
        print("🏋️ [PUSH] Sender: \(senderName), Workout: \(workoutName)")
        
        // Send push notification
        await sendRealPushNotification(
            toUserId: receiverId,
            title: "\(senderName) delade ett pass med dig",
            body: "Tryck för att komma till passet",
            data: ["type": "shared_workout", "sender_name": senderName, "workout_name": workoutName]
        )
        
        print("✅ [PUSH] Shared workout notification sent to \(receiverId)")
    }
    
    // MARK: - Send Custom Announcement to All Users
    
    func sendAnnouncementToAllUsers(title: String, body: String) async {
        print("📢 [ANNOUNCEMENT] Sending announcement to all users")
        print("📢 Title: \(title)")
        print("📢 Body: \(body)")
        
        do {
            // Get all device tokens (all active users)
            struct DeviceToken: Decodable {
                let user_id: String
            }
            
            let tokens: [DeviceToken] = try await SupabaseConfig.supabase
                .from("device_tokens")
                .select("user_id")
                .eq("is_active", value: true)
                .execute()
                .value
            
            let uniqueUserIds = Set(tokens.map { $0.user_id })
            print("📢 [ANNOUNCEMENT] Found \(uniqueUserIds.count) users to notify")
            
            // Send push to each user
            for userId in uniqueUserIds {
                await sendRealPushNotification(
                    toUserId: userId,
                    title: title,
                    body: body,
                    data: ["type": "announcement"]
                )
            }
            
            print("✅ [ANNOUNCEMENT] Announcement sent to \(uniqueUserIds.count) users!")
        } catch {
            print("❌ [ANNOUNCEMENT] Failed to send announcement: \(error)")
        }
    }
}

// MARK: - Notification Navigation Manager

class NotificationNavigationManager: ObservableObject {
    static let shared = NotificationNavigationManager()
    
    @Published var shouldNavigateToNews = false
    @Published var shouldNavigateToPost: String? = nil
    @Published var shouldNavigateToActiveFriends = false
    @Published var shouldNavigateToSharedWorkouts = false
    @Published var shouldNavigateToNotifications = false
    
    func navigateToNews() {
        DispatchQueue.main.async {
            self.shouldNavigateToNews = true
        }
    }
    
    func navigateToPost(postId: String) {
        DispatchQueue.main.async {
            self.shouldNavigateToPost = postId
        }
    }
    
    func navigateToActiveFriends() {
        DispatchQueue.main.async {
            // First navigate to social tab
            NotificationCenter.default.post(name: NSNotification.Name("NavigateToSocial"), object: nil)
            // Then switch to active friends tab after a short delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                NotificationCenter.default.post(name: NSNotification.Name("NavigateToActiveFriendsTab"), object: nil)
            }
            self.shouldNavigateToActiveFriends = true
        }
    }
    
    func navigateToSharedWorkouts() {
        DispatchQueue.main.async {
            // Navigate to profile tab first
            NotificationCenter.default.post(name: NSNotification.Name("NavigateToProfile"), object: nil)
            // Then open shared workouts after a short delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                NotificationCenter.default.post(name: NSNotification.Name("NavigateToSharedWorkouts"), object: nil)
            }
            self.shouldNavigateToSharedWorkouts = true
        }
    }
    
    func navigateToNotifications() {
        DispatchQueue.main.async {
            // Navigate to social tab first (where notifications bell is)
            NotificationCenter.default.post(name: NSNotification.Name("NavigateToSocial"), object: nil)
            // Then open notifications view after a short delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                NotificationCenter.default.post(name: NSNotification.Name("OpenNotifications"), object: nil)
            }
            self.shouldNavigateToNotifications = true
        }
    }
    
    func resetNavigation() {
        shouldNavigateToNews = false
        shouldNavigateToPost = nil
        shouldNavigateToActiveFriends = false
        shouldNavigateToSharedWorkouts = false
        shouldNavigateToNotifications = false
    }
}

// MARK: - App Delegate for Push Notifications

import InsertAffiliateSwift

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    
    // Keep reference to purchase controller
    private let purchaseController = RCPurchaseController()
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        
        // IMPORTANT: Initialize RevenueCat FIRST (before Superwall)
        // This triggers RevenueCatManager.shared initialization
        _ = RevenueCatManager.shared
        print("✅ RevenueCat initialized")
        
        // Initialize Superwall SDK with RevenueCat purchase controller
        Superwall.configure(
            apiKey: "pk_V87Rb4tJLmrkuA7OTpCsV",
            purchaseController: purchaseController
        )
        print("✅ Superwall configured with RevenueCat integration")
        
        // Start syncing subscription status between RevenueCat and Superwall
        purchaseController.syncSubscriptionStatus()
        print("✅ Subscription status sync started")
        
        // Initialize Insert Affiliate SDK
        InsertAffiliateSwift.initialize(
            companyCode: "Ooc4ERYgmYaZtJeCBnR7TjZb1BL2",
            verboseLogging: false
        )
        
        return true
    }
    
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        PushNotificationService.shared.saveDeviceToken(deviceToken)
    }
    
    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("❌ Failed to register for remote notifications: \(error)")
    }
    
    // Called when app is about to go to background
    func applicationDidEnterBackground(_ application: UIApplication) {
        print("📥 [AppDelegate] App entering background - ensuring session is saved")
        // Force save any active session
        if SessionManager.shared.hasActiveSession {
            SessionManager.shared.forceSaveCurrentSession()
            print("💾 [AppDelegate] Force saved active session on background")
        }
        // Force synchronize UserDefaults to disk
        UserDefaults.standard.synchronize()
    }
    
    // Called when app is about to be terminated
    func applicationWillTerminate(_ application: UIApplication) {
        print("🛑 [AppDelegate] App will terminate - force saving all data")
        // Force save any active session
        if SessionManager.shared.hasActiveSession {
            SessionManager.shared.forceSaveCurrentSession()
            print("💾 [AppDelegate] Force saved active session on terminate")
        }
        // Force synchronize UserDefaults to disk before termination
        UserDefaults.standard.synchronize()
    }
    
    // Handle notification when app is in foreground
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound, .badge])
    }
    
    // Handle notification tap
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        let userInfo = response.notification.request.content.userInfo
        print("📱 Notification tapped: \(userInfo)")
        
        // Check notification type and navigate accordingly
        if let type = userInfo["type"] as? String {
            switch type {
            case "news":
                NotificationNavigationManager.shared.navigateToNews()
            case "new_workout", "like", "comment":
                if let postId = userInfo["post_id"] as? String {
                    NotificationNavigationManager.shared.navigateToPost(postId: postId)
                }
            case "active_session":
                // Navigate to active friends map
                NotificationNavigationManager.shared.navigateToActiveFriends()
            case "shared_workout":
                // Navigate to shared workouts view
                NotificationNavigationManager.shared.navigateToSharedWorkouts()
            case "coach_invitation":
                // Navigate to notifications to see and respond to coach invitation
                NotificationNavigationManager.shared.navigateToNotifications()
            case "coach_program_assigned":
                // Navigate to notifications to see assigned program
                NotificationNavigationManager.shared.navigateToNotifications()
            default:
                break
            }
        }
        
        // Also check for deep link in userInfo
        if let deepLink = userInfo["deepLink"] as? String, deepLink == "upanddown://active-friends" {
            NotificationNavigationManager.shared.navigateToActiveFriends()
        }
        
        completionHandler()
    }
}

