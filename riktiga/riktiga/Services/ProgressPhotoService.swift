import Foundation
import UIKit
import Supabase

final class ProgressPhotoService {
    static let shared = ProgressPhotoService()
    private let supabase = SupabaseConfig.supabase
    
    private init() {}
    
    // MARK: - Fetch Progress Photos
    func fetchPhotos(for userId: String) async throws -> [WeightProgressEntry] {
        try await AuthSessionManager.shared.ensureValidSession()
        
        let photos: [WeightProgressEntry] = try await supabase
            .from("progress_photos")
            .select("*")
            .eq("user_id", value: userId)
            .order("photo_date", ascending: false)
            .execute()
            .value
        
        return photos
    }
    
    // MARK: - Upload Progress Photo
    func uploadPhoto(
        userId: String,
        image: UIImage,
        weightKg: Double,
        photoDate: Date
    ) async throws -> WeightProgressEntry {
        try await AuthSessionManager.shared.ensureValidSession()
        
        // 1. Compress and upload image to storage
        guard let imageData = image.jpegData(compressionQuality: 0.7) else {
            throw NSError(domain: "ProgressPhotoService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Kunde inte komprimera bilden"])
        }
        
        let fileName = "\(userId)/\(UUID().uuidString).jpg"
        
        try await supabase.storage
            .from("progress-photos")
            .upload(
                fileName,
                data: imageData,
                options: FileOptions(contentType: "image/jpeg")
            )
        
        // 2. Get public URL
        let publicUrl = try supabase.storage
            .from("progress-photos")
            .getPublicURL(path: fileName)
            .absoluteString
        
        // 3. Insert record into database
        let id = UUID().uuidString
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let photoDateString = dateFormatter.string(from: photoDate)
        
        let insertData = WeightProgressEntryInsert(
            id: id,
            userId: userId,
            imageUrl: publicUrl,
            weightKg: weightKg,
            photoDate: photoDateString
        )
        
        try await supabase
            .from("progress_photos")
            .insert(insertData)
            .execute()
        
        print("✅ Progress photo uploaded successfully")
        
        return WeightProgressEntry(
            id: id,
            userId: userId,
            imageUrl: publicUrl,
            weightKg: weightKg,
            photoDate: photoDate,
            createdAt: Date()
        )
    }
    
    // MARK: - Delete Progress Photo
    func deletePhoto(photoId: String, imageUrl: String, userId: String) async throws {
        try await AuthSessionManager.shared.ensureValidSession()
        
        // 1. Delete from storage
        // Extract file path from URL
        if let urlComponents = URLComponents(string: imageUrl),
           let path = urlComponents.path.split(separator: "/").last(where: { $0.contains(".jpg") }) {
            let filePath = "\(userId)/\(path)"
            _ = try? await supabase.storage
                .from("progress-photos")
                .remove(paths: [filePath])
        }
        
        // 2. Delete from database
        try await supabase
            .from("progress_photos")
            .delete()
            .eq("id", value: photoId)
            .execute()
        
        print("✅ Progress photo deleted")
    }
    
    // MARK: - Get Latest Weight Entry
    func getLatestWeight(for userId: String) async throws -> Double? {
        try await AuthSessionManager.shared.ensureValidSession()
        
        let photos: [WeightProgressEntry] = try await supabase
            .from("progress_photos")
            .select("*")
            .eq("user_id", value: userId)
            .order("photo_date", ascending: false)
            .limit(1)
            .execute()
            .value
        
        return photos.first?.weightKg
    }
}
