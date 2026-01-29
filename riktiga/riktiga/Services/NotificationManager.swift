import Foundation
import UserNotifications
import UIKit

final class NotificationManager {
    static let shared = NotificationManager()
    private init() {}

    func requestAuthorization(completion: ((Bool) -> Void)? = nil) {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            DispatchQueue.main.async {
                completion?(granted)
            }
        }
    }

    // MARK: - Daily Steps Reminder
    func scheduleDailyStepsReminder(atHour hour: Int = 19, minute: Int = 0) {
        // Remove existing to avoid duplicates
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["daily-10k-steps"]) 

        let content = UNMutableNotificationContent()
        content.title = "Dagens mål: 10 000 steg"
        content.body = "Ta en kort promenad nu så når du målet idag!"
        content.sound = .default

        var date = DateComponents()
        date.hour = hour
        date.minute = minute

        let trigger = UNCalendarNotificationTrigger(dateMatching: date, repeats: true)
        let request = UNNotificationRequest(identifier: "daily-10k-steps", content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
    }

    func cancelDailyStepsReminder() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["daily-10k-steps"]) 
    }
    
    // MARK: - Daily Meal Reminders
    
    /// Schedule daily lunch reminder at 12:00
    func scheduleLunchReminder() {
        // Remove existing to avoid duplicates
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["daily-lunch-reminder"])
        
        let content = UNMutableNotificationContent()
        content.title = "🍽️ Lunch dags!"
        content.body = "Glöm inte registrera din måltid"
        content.sound = .default
        content.userInfo = ["type": "meal_reminder", "meal": "lunch"]
        
        var dateComponents = DateComponents()
        dateComponents.hour = 12
        dateComponents.minute = 0
        
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(identifier: "daily-lunch-reminder", content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("❌ Failed to schedule lunch reminder: \(error)")
            } else {
                print("✅ Lunch reminder scheduled for 12:00 daily")
            }
        }
    }
    
    /// Schedule daily dinner reminder at 17:30
    func scheduleDinnerReminder() {
        // Remove existing to avoid duplicates
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["daily-dinner-reminder"])
        
        let content = UNMutableNotificationContent()
        content.title = "🍝 Dags för middag?"
        content.body = "Regga på några sekunder med AI"
        content.sound = .default
        content.userInfo = ["type": "meal_reminder", "meal": "dinner"]
        
        var dateComponents = DateComponents()
        dateComponents.hour = 17
        dateComponents.minute = 30
        
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(identifier: "daily-dinner-reminder", content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("❌ Failed to schedule dinner reminder: \(error)")
            } else {
                print("✅ Dinner reminder scheduled for 17:30 daily")
            }
        }
    }
    
    /// Schedule all meal reminders
    func scheduleMealReminders() {
        scheduleLunchReminder()
        scheduleDinnerReminder()
    }
    
    /// Cancel all meal reminders
    func cancelMealReminders() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [
            "daily-lunch-reminder",
            "daily-dinner-reminder"
        ])
        print("🔕 Meal reminders cancelled")
    }
    
    // MARK: - Social Activity Notifications
    
    /// Send a push notification when someone likes a post
    func sendLikeNotification(fromUserName: String, postTitle: String) {
        let content = UNMutableNotificationContent()
        content.title = "❤️ \(fromUserName) gillade din post"
        content.body = postTitle
        content.sound = .default
        content.badge = NSNumber(value: UIApplication.shared.applicationIconBadgeNumber + 1)
        
        // Add custom data
        content.userInfo = ["type": "like", "userName": fromUserName]
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
    }
    
    /// Send a push notification when someone comments on a post
    func sendCommentNotification(fromUserName: String, commentText: String) {
        let content = UNMutableNotificationContent()
        content.title = "💬 \(fromUserName) kommenterade på din post"
        
        // Truncate comment to 60 characters
        let truncatedComment = commentText.count > 60 ? String(commentText.prefix(60)) + "..." : commentText
        content.body = truncatedComment
        content.sound = .default
        content.badge = NSNumber(value: UIApplication.shared.applicationIconBadgeNumber + 1)
        
        // Add custom data
        content.userInfo = ["type": "comment", "userName": fromUserName]
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
    }
    
    /// Send a push notification when someone follows the user
    func sendFollowNotification(fromUserName: String) {
        let content = UNMutableNotificationContent()
        content.title = "👤 \(fromUserName) började följa dig"
        content.body = "Du har en ny följare!"
        content.sound = .default
        content.badge = NSNumber(value: UIApplication.shared.applicationIconBadgeNumber + 1)
        
        // Add custom data
        content.userInfo = ["type": "follow", "userName": fromUserName]
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
    }
    
    // MARK: - Workout Complete Notification
    
    /// Schedule a motivational notification 15 seconds after completing a workout
    func scheduleWorkoutCompleteNotification(userName: String?) {
        // Remove any existing workout complete notification to avoid duplicates
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["workout-complete-motivation"])
        
        let content = UNMutableNotificationContent()
        
        // Use first name if available, otherwise use a generic message
        let firstName = userName?.components(separatedBy: " ").first ?? "du"
        content.title = "Grymt jobbat \(firstName)! 💪"
        content.body = "Håll din streak uppe och fortsätt slakta det!"
        content.sound = .default
        content.userInfo = ["type": "workout_complete"]
        
        // Trigger after 15 seconds
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 15, repeats: false)
        let request = UNNotificationRequest(identifier: "workout-complete-motivation", content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("❌ Failed to schedule workout complete notification: \(error)")
            } else {
                print("✅ Workout complete notification scheduled for 15 seconds from now")
            }
        }
    }
    
    // MARK: - Streak Broken Notification
    
    /// Send an immediate notification when the user's streak is broken
    func sendStreakBrokenNotification() {
        let content = UNMutableNotificationContent()
        content.title = "Alla missar en dag ibland 💪"
        content.body = "Starta en ny streak och nå dina mål, vi tror på dig!"
        content.sound = .default
        content.userInfo = ["type": "streak_broken"]
        
        // Trigger immediately (1 second delay for system)
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: "streak-broken", content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("❌ Failed to send streak broken notification: \(error)")
            } else {
                print("✅ Streak broken notification sent")
            }
        }
    }
    
    // MARK: - Friend Started Workout Notification
    
    /// Send a notification when a friend starts a workout (for local testing)
    func sendFriendStartedWorkoutNotification(friendName: String, activityType: String) {
        let content = UNMutableNotificationContent()
        let firstName = friendName.components(separatedBy: " ").first ?? friendName
        
        let activityText: String
        switch activityType.lowercased() {
        case "gym", "walking":
            activityText = "gympass"
        case "running":
            activityText = "löppass"
        default:
            activityText = "träningspass"
        }
        
        content.title = "\(firstName) startade ett \(activityText)! 💪"
        content.body = "Ge lite motivation!"
        content.sound = .default
        content.userInfo = [
            "type": "active_session",
            "deepLink": "upanddown://active-friends"
        ]
        
        // Trigger immediately
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(
            identifier: "friend-workout-\(UUID().uuidString)",
            content: content,
            trigger: trigger
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("❌ Failed to send friend workout notification: \(error)")
            } else {
                print("✅ Friend workout notification sent for \(firstName)")
            }
        }
    }
}


