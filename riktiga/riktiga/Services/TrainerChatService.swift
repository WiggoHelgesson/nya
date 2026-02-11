import Foundation
import Supabase
import Functions
import Combine

// MARK: - Chat Models

struct TrainerConversation: Identifiable, Codable {
    let id: UUID
    let trainerId: UUID
    let userId: UUID
    let lastMessageAt: Date?
    let createdAt: Date?
    
    // From view
    let trainerName: String?
    let trainerAvatarUrl: String?
    let trainerUserId: String?
    let userUsername: String?
    let userAvatarUrl: String?
    let lastMessage: String?
    let unreadCount: Int?
    
    enum CodingKeys: String, CodingKey {
        case id
        case trainerId = "trainer_id"
        case userId = "user_id"
        case lastMessageAt = "last_message_at"
        case createdAt = "created_at"
        case trainerName = "trainer_name"
        case trainerAvatarUrl = "trainer_avatar_url"
        case trainerUserId = "trainer_user_id"
        case userUsername = "user_username"
        case userAvatarUrl = "user_avatar_url"
        case lastMessage = "last_message"
        case unreadCount = "unread_count"
    }
}

struct TrainerChatMessage: Identifiable, Codable, Equatable {
    let id: UUID
    let conversationId: UUID
    let senderId: UUID
    let message: String
    let isRead: Bool
    let createdAt: Date?
    
    enum CodingKeys: String, CodingKey {
        case id
        case conversationId = "conversation_id"
        case senderId = "sender_id"
        case message
        case isRead = "is_read"
        case createdAt = "created_at"
    }
}

// MARK: - Trainer Chat Service

final class TrainerChatService: ObservableObject {
    static let shared = TrainerChatService()
    private let supabase = SupabaseConfig.supabase
    
    @Published var messages: [TrainerChatMessage] = []
    @Published var conversations: [TrainerConversation] = []
    
    private var pollingTimer: Timer?
    private var currentConversationId: UUID?
    
    private init() {}
    
    // MARK: - Get or Create Conversation
    
    /// Gets existing conversation or creates a new one between current user and trainer
    func getOrCreateConversation(trainerId: UUID) async throws -> UUID {
        guard let userId = try? await supabase.auth.session.user.id else {
            throw TrainerChatError.notAuthenticated
        }
        
        try await AuthSessionManager.shared.ensureValidSession()
        
        // Try to find existing conversation
        let existing: [TrainerConversation] = try await supabase.database
            .from("trainer_conversations")
            .select()
            .eq("trainer_id", value: trainerId)
            .eq("user_id", value: userId)
            .execute()
            .value
        
        if let conversation = existing.first {
            return conversation.id
        }
        
        // Create new conversation
        struct NewConversation: Encodable {
            let trainer_id: String
            let user_id: String
        }
        
        struct ConversationResponse: Decodable {
            let id: UUID
        }
        
        let result: ConversationResponse = try await supabase.database
            .from("trainer_conversations")
            .insert(NewConversation(
                trainer_id: trainerId.uuidString,
                user_id: userId.uuidString
            ))
            .select("id")
            .single()
            .execute()
            .value
        
        print("💬 Created new conversation: \(result.id)")
        return result.id
    }
    
    // MARK: - Fetch Messages
    
    func fetchMessages(conversationId: UUID) async throws -> [TrainerChatMessage] {
        try await AuthSessionManager.shared.ensureValidSession()
        
        let result: [TrainerChatMessage] = try await supabase.database
            .from("trainer_chat_messages")
            .select()
            .eq("conversation_id", value: conversationId)
            .order("created_at", ascending: true)
            .execute()
            .value
        
        await MainActor.run {
            self.messages = result
        }
        
        return result
    }
    
    // MARK: - Send Message
    
    func sendMessage(conversationId: UUID, message: String) async throws {
        guard let userId = try? await supabase.auth.session.user.id else {
            throw TrainerChatError.notAuthenticated
        }
        
        try await AuthSessionManager.shared.ensureValidSession()
        
        struct NewMessage: Encodable {
            let conversation_id: String
            let sender_id: String
            let message: String
        }
        
        let newMsg: TrainerChatMessage = try await supabase.database
            .from("trainer_chat_messages")
            .insert(NewMessage(
                conversation_id: conversationId.uuidString,
                sender_id: userId.uuidString,
                message: message
            ))
            .select()
            .single()
            .execute()
            .value
        
        await MainActor.run {
            if !self.messages.contains(where: { $0.id == newMsg.id }) {
                self.messages.append(newMsg)
            }
        }
        
        // Send push notification to the recipient via Edge Function
        await sendChatPushNotification(
            conversationId: conversationId,
            senderId: userId,
            message: message
        )
    }
    
    // MARK: - Send Chat Push Notification
    
    /// Calls the notify-chat-message Edge Function to send a push notification to the recipient
    private func sendChatPushNotification(conversationId: UUID, senderId: UUID, message: String) async {
        do {
            struct ChatNotificationPayload: Encodable {
                let conversation_id: String
                let sender_id: String
                let message: String
            }
            
            let payload = ChatNotificationPayload(
                conversation_id: conversationId.uuidString,
                sender_id: senderId.uuidString,
                message: message
            )
            
            try await supabase.functions.invoke(
                "notify-chat-message",
                options: .init(body: payload)
            )
            
            print("✅ [CHAT] Push notification sent for message in conversation \(conversationId)")
        } catch {
            print("⚠️ [CHAT] Failed to send push notification: \(error)")
            // Don't throw - the message was already sent successfully
        }
    }
    
    // MARK: - Mark Messages as Read
    
    func markMessagesAsRead(conversationId: UUID) async throws {
        guard let userId = try? await supabase.auth.session.user.id else { return }
        
        try await AuthSessionManager.shared.ensureValidSession()
        
        try await supabase.database
            .from("trainer_chat_messages")
            .update(["is_read": true])
            .eq("conversation_id", value: conversationId)
            .neq("sender_id", value: userId)
            .eq("is_read", value: false)
            .execute()
    }
    
    // MARK: - Start Real-Time Polling
    
    func startPolling(conversationId: UUID) {
        stopPolling()
        currentConversationId = conversationId
        
        // Poll every 2 seconds for new messages
        pollingTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            guard let self = self, let convId = self.currentConversationId else { return }
            Task {
                do {
                    let newMessages = try await self.fetchMessages(conversationId: convId)
                    await MainActor.run {
                        self.messages = newMessages
                    }
                    // Mark as read
                    try? await self.markMessagesAsRead(conversationId: convId)
                } catch {
                    print("❌ Chat polling error: \(error)")
                }
            }
        }
        
        // Initial fetch
        Task {
            do {
                _ = try await fetchMessages(conversationId: conversationId)
                try? await markMessagesAsRead(conversationId: conversationId)
            } catch {
                print("❌ Initial chat fetch error: \(error)")
            }
        }
    }
    
    func stopPolling() {
        pollingTimer?.invalidate()
        pollingTimer = nil
        currentConversationId = nil
    }
    
    // MARK: - Fetch Conversations List
    
    func fetchConversations() async throws -> [TrainerConversation] {
        try await AuthSessionManager.shared.ensureValidSession()
        
        let result: [TrainerConversation] = try await supabase.database
            .from("trainer_conversations_with_info")
            .select()
            .order("last_message_at", ascending: false)
            .execute()
            .value
        
        await MainActor.run {
            self.conversations = result
        }
        
        return result
    }
    
    // MARK: - Get Current User ID
    
    func getCurrentUserId() async -> UUID? {
        try? await supabase.auth.session.user.id
    }
}

// MARK: - Errors

enum TrainerChatError: Error, LocalizedError {
    case notAuthenticated
    case conversationNotFound
    
    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "Du måste vara inloggad för att chatta"
        case .conversationNotFound:
            return "Konversationen hittades inte"
        }
    }
}
