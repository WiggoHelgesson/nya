import Foundation
import UIKit
import Supabase

final class EventService {
    static let shared = EventService()
    private let supabase = SupabaseConfig.supabase
    
    private init() {}
    
    // MARK: - Fetch Events
    func fetchEvents(userId: String) async throws -> [Event] {
        try await AuthSessionManager.shared.ensureValidSession()
        
        let events: [Event] = try await supabase
            .from("events")
            .select("*")
            .eq("user_id", value: userId)
            .order("created_at", ascending: false)
            .execute()
            .value
        
        return events
    }
    
    // MARK: - Fetch Event Images
    func fetchEventImages(eventId: String) async throws -> [EventImage] {
        let images: [EventImage] = try await supabase
            .from("event_images")
            .select("*")
            .eq("event_id", value: eventId)
            .order("sort_order", ascending: true)
            .execute()
            .value
        
        return images
    }
    
    // MARK: - Create Event
    func createEvent(
        userId: String,
        title: String,
        description: String,
        coverImage: UIImage,
        images: [UIImage]
    ) async throws -> Event {
        try await AuthSessionManager.shared.ensureValidSession()
        
        let eventId = UUID().uuidString
        
        // Upload cover image
        let coverUrl = try await uploadImage(
            image: coverImage,
            userId: userId,
            fileName: "\(userId)/\(eventId)/cover.jpg"
        )
        
        // Insert event record
        let insertData = EventInsert(
            id: eventId,
            user_id: userId,
            title: title,
            description: description,
            cover_image_url: coverUrl
        )
        
        try await supabase
            .from("events")
            .insert(insertData)
            .execute()
        
        // Upload and insert all images (continue on per-image failure)
        for (index, image) in images.enumerated() {
            do {
                let imageUrl = try await uploadImage(
                    image: image,
                    userId: userId,
                    fileName: "\(userId)/\(eventId)/img_\(index).jpg"
                )
                
                let imageInsert = EventImageInsert(
                    id: UUID().uuidString,
                    event_id: eventId,
                    image_url: imageUrl,
                    sort_order: index
                )
                
                try await supabase
                    .from("event_images")
                    .insert(imageInsert)
                    .execute()
            } catch {
                print("⚠️ Failed to upload event image \(index): \(error.localizedDescription)")
            }
        }
        
        return Event(
            id: eventId,
            userId: userId,
            title: title,
            description: description,
            coverImageUrl: coverUrl
        )
    }
    
    // MARK: - Delete Event
    func deleteEvent(eventId: String, userId: String) async throws {
        try await AuthSessionManager.shared.ensureValidSession()
        
        // Fetch images first for storage cleanup
        let images = try await fetchEventImages(eventId: eventId)
        
        // Delete from database (cascade deletes event_images rows)
        try await supabase
            .from("events")
            .delete()
            .eq("id", value: eventId)
            .execute()
        
        // Clean up storage files
        var pathsToRemove: [String] = []
        pathsToRemove.append("\(userId)/\(eventId)/cover.jpg")
        for (index, _) in images.enumerated() {
            pathsToRemove.append("\(userId)/\(eventId)/img_\(index).jpg")
        }
        
        _ = try? await supabase.storage
            .from("event-images")
            .remove(paths: pathsToRemove)
    }
    
    // MARK: - Upload Image Helper
    private func uploadImage(image: UIImage, userId: String, fileName: String) async throws -> String {
        let resized = Self.resizeIfNeeded(image, maxDimension: 2000)
        
        guard let data = resized.jpegData(compressionQuality: 0.7) else {
            throw NSError(domain: "EventService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Kunde inte komprimera bilden"])
        }
        
        try await supabase.storage
            .from("event-images")
            .upload(
                fileName,
                data: data,
                options: FileOptions(contentType: "image/jpeg")
            )
        
        let publicUrl = try supabase.storage
            .from("event-images")
            .getPublicURL(path: fileName)
            .absoluteString
        
        return publicUrl
    }
    
    private static func resizeIfNeeded(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
        let size = image.size
        guard size.width > maxDimension || size.height > maxDimension else { return image }
        
        let scale = min(maxDimension / size.width, maxDimension / size.height)
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        
        let renderer = UIGraphicsImageRenderer(size: newSize)
        let resized = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
        print("📸 Resized event image from \(size) to \(newSize)")
        return resized
    }
}
