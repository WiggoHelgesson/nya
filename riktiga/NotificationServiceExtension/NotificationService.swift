//
//  NotificationService.swift
//  NotificationServiceExtension
//
//  Created by Wiggo Helgesson on 2026-01-12.
//

import UserNotifications
import CoreGraphics

class NotificationService: UNNotificationServiceExtension {

    var contentHandler: ((UNNotificationContent) -> Void)?
    var bestAttemptContent: UNMutableNotificationContent?

    override func didReceive(_ request: UNNotificationRequest, withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void) {
        self.contentHandler = contentHandler
        bestAttemptContent = (request.content.mutableCopy() as? UNMutableNotificationContent)
        
        guard let bestAttemptContent = bestAttemptContent else {
            contentHandler(request.content)
            return
        }
        
        // Get the avatar URL from the notification data
        if let avatarUrlString = bestAttemptContent.userInfo["actor_avatar"] as? String,
           !avatarUrlString.isEmpty,
           let avatarUrl = URL(string: avatarUrlString) {
            
            // Download the image and attach it
            downloadImage(from: avatarUrl) { attachment in
                if let attachment = attachment {
                    bestAttemptContent.attachments = [attachment]
                }
                contentHandler(bestAttemptContent)
            }
        } else {
            // No avatar URL, just deliver the notification
            contentHandler(bestAttemptContent)
        }
    }
    
    override func serviceExtensionTimeWillExpire() {
        // Called just before the extension will be terminated by the system.
        // Use this as an opportunity to deliver your "best attempt" at modified content.
        if let contentHandler = contentHandler, let bestAttemptContent = bestAttemptContent {
            contentHandler(bestAttemptContent)
        }
    }
    
    private func downloadImage(from url: URL, completion: @escaping (UNNotificationAttachment?) -> Void) {
        let task = URLSession.shared.downloadTask(with: url) { localUrl, response, error in
            guard let localUrl = localUrl, error == nil else {
                completion(nil)
                return
            }
            
            // Create a unique file URL in the temporary directory
            let fileManager = FileManager.default
            let tempDirectory = fileManager.temporaryDirectory
            let uniqueFileName = UUID().uuidString + ".jpg"
            let destinationUrl = tempDirectory.appendingPathComponent(uniqueFileName)
            
            do {
                // Copy the downloaded file to our destination
                if fileManager.fileExists(atPath: destinationUrl.path) {
                    try fileManager.removeItem(at: destinationUrl)
                }
                try fileManager.copyItem(at: localUrl, to: destinationUrl)
                
                // Create the attachment without thumbnail clipping options
                let attachment = try UNNotificationAttachment(
                    identifier: "avatar",
                    url: destinationUrl,
                    options: nil
                )
                completion(attachment)
            } catch {
                print("❌ Failed to create notification attachment: \(error)")
                completion(nil)
            }
        }
        task.resume()
    }
}
