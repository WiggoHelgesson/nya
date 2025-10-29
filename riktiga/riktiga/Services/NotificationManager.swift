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
}
