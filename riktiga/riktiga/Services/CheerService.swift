import Foundation
import Supabase

// MARK: - Received Cheer Model
struct ReceivedCheer: Identifiable, Codable {
    let id: String
    let fromUserId: String
    let fromUserName: String
    let toUserId: String
    let emoji: String
    let createdAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case fromUserId = "from_user_id"
        case fromUserName = "from_user_name"
        case toUserId = "to_user_id"
        case emoji
        case createdAt = "created_at"
    }
}

// MARK: - Cheer Insert Model
struct CheerInsert: Encodable {
    let from_user_id: String
    let from_user_name: String
    let to_user_id: String
    let emoji: String
}

// MARK: - Cheer Service
class CheerService {
    static let shared = CheerService()
    
    private init() {}
    
    private let supabase = SupabaseConfig.supabase
    
    // Available cheer emojis
    static let cheerEmojis = ["💪", "🔥", "⚡️", "🏆", "👊", "🎯", "💯", "🚀"]
    
    // MARK: - Send Cheer
    func sendCheer(fromUserId: String, fromUserName: String, toUserId: String, toUserName: String, emoji: String) async throws {
        // 1. Insert cheer into database
        let cheerData = CheerInsert(
            from_user_id: fromUserId,
            from_user_name: fromUserName,
            to_user_id: toUserId,
            emoji: emoji
        )
        
        try await supabase
            .from("workout_cheers")
            .insert(cheerData)
            .execute()
        
        print("✅ Cheer saved to database")
        
        // 2. Send push notification via Edge Function
        await sendCheerNotification(
            fromUserName: fromUserName,
            toUserId: toUserId,
            emoji: emoji
        )
    }
    
    // MARK: - Send Push Notification
    private func sendCheerNotification(fromUserName: String, toUserId: String, emoji: String) async {
        do {
            // Call Supabase Edge Function to send push notification
            let response = try await supabase.functions.invoke(
                "send-cheer-notification",
                options: FunctionInvokeOptions(
                    body: [
                        "toUserId": toUserId,
                        "fromUserName": fromUserName,
                        "emoji": emoji
                    ]
                )
            )
            
            print("✅ Cheer notification sent: \(response)")
        } catch {
            print("⚠️ Failed to send cheer notification: \(error)")
            // Don't throw - the cheer was saved, notification is best-effort
        }
    }
    
    // MARK: - Get Recent Cheers for User
    func getRecentCheers(forUserId userId: String, limit: Int = 10) async throws -> [ReceivedCheer] {
        let response: [ReceivedCheer] = try await supabase
            .from("workout_cheers")
            .select()
            .eq("to_user_id", value: userId)
            .order("created_at", ascending: false)
            .limit(limit)
            .execute()
            .value
        
        return response
    }
    
    // MARK: - Check if User Can Send Cheer (Rate Limiting)
    func canSendCheer(fromUserId: String, toUserId: String) async -> Bool {
        do {
            struct CheerCheck: Decodable {
                let created_at: String
            }
            
            let response: [CheerCheck] = try await supabase
                .from("workout_cheers")
                .select("created_at")
                .eq("from_user_id", value: fromUserId)
                .eq("to_user_id", value: toUserId)
                .order("created_at", ascending: false)
                .limit(1)
                .execute()
                .value
            
            if let lastCheer = response.first {
                let formatter = ISO8601DateFormatter()
                formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                
                if let lastCheerDate = formatter.date(from: lastCheer.created_at) {
                    // Check if at least 1 minute has passed
                    return Date().timeIntervalSince(lastCheerDate) >= 60
                }
            }
            
            return true
        } catch {
            print("⚠️ Error checking cheer rate limit: \(error)")
            return true // Allow on error
        }
    }
}
