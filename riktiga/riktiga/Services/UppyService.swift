import Foundation
import Supabase

// MARK: - Uppy Models

struct Uppy: Identifiable, Codable {
    let id: String
    let sessionId: String
    let fromUserId: String
    let fromUserName: String
    let fromUserAvatar: String?
    let toUserId: String
    let createdAt: String
    
    enum CodingKeys: String, CodingKey {
        case id
        case sessionId = "session_id"
        case fromUserId = "from_user_id"
        case fromUserName = "from_user_name"
        case fromUserAvatar = "from_user_avatar"
        case toUserId = "to_user_id"
        case createdAt = "created_at"
    }
}

struct UppyInsert: Encodable {
    let sessionId: String
    let fromUserId: String
    let fromUserName: String
    let fromUserAvatar: String?
    let toUserId: String
    
    enum CodingKeys: String, CodingKey {
        case sessionId = "session_id"
        case fromUserId = "from_user_id"
        case fromUserName = "from_user_name"
        case fromUserAvatar = "from_user_avatar"
        case toUserId = "to_user_id"
    }
}

// MARK: - Uppy Service

final class UppyService {
    static let shared = UppyService()
    private let supabase = SupabaseConfig.supabase
    
    private init() {}
    
    // MARK: - Send Uppy
    
    /// Send an Uppy to a friend during their active session
    func sendUppy(
        sessionId: String,
        fromUserId: String,
        fromUserName: String,
        fromUserAvatar: String?,
        toUserId: String,
        toUserName: String
    ) async throws {
        print("💪 Sending Uppy from \(fromUserName) to \(toUserName)")
        
        // Check if already sent an Uppy to this session
        let existing: [Uppy] = try await supabase
            .from("session_uppys")
            .select()
            .eq("session_id", value: sessionId)
            .eq("from_user_id", value: fromUserId)
            .execute()
            .value
        
        if !existing.isEmpty {
            print("⚠️ Uppy already sent to this session")
            throw UppyError.alreadySent
        }
        
        // Insert new Uppy
        let uppyData = UppyInsert(
            sessionId: sessionId,
            fromUserId: fromUserId,
            fromUserName: fromUserName,
            fromUserAvatar: fromUserAvatar,
            toUserId: toUserId
        )
        
        try await supabase
            .from("session_uppys")
            .insert(uppyData)
            .execute()
        
        print("✅ Uppy sent successfully")
        
        // Check if this is the 3rd Uppy (for bonus points)
        let allUppys: [Uppy] = try await supabase
            .from("session_uppys")
            .select()
            .eq("session_id", value: sessionId)
            .execute()
            .value
        
        // Send push notification
        try await NotificationService.shared.sendUppyNotification(
            toUserId: toUserId,
            fromUserName: fromUserName,
            uppyCount: allUppys.count
        )
        
        // Award bonus points if reached 3 uppys
        if allUppys.count == 3 {
            print("🎉 3 Uppys reached! Awarding 10 bonus points")
            try await awardUppyBonus(userId: toUserId)
        }
    }
    
    // MARK: - Get Uppys for Session
    
    /// Get all Uppys received for a specific session
    func getUppysForSession(sessionId: String) async throws -> [Uppy] {
        let uppys: [Uppy] = try await supabase
            .from("session_uppys")
            .select()
            .eq("session_id", value: sessionId)
            .order("created_at", ascending: true)
            .execute()
            .value
        
        print("📊 Fetched \(uppys.count) Uppys for session \(sessionId)")
        return uppys
    }
    
    // MARK: - Award Bonus Points
    
    private func awardUppyBonus(userId: String) async throws {
        // Award 10 XP points using ProfileService
        try await ProfileService.shared.updateUserPoints(userId: userId, pointsToAdd: 10)
        print("✅ Awarded 10 bonus points to user \(userId)")
    }
}

// MARK: - Errors

enum UppyError: LocalizedError {
    case alreadySent
    
    var errorDescription: String? {
        switch self {
        case .alreadySent:
            return "Du har redan skickat en Uppy till denna session"
        }
    }
}
