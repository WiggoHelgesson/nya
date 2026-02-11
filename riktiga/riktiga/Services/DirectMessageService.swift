import Foundation
import Supabase
import Combine

// MARK: - Direct Message Models

struct DirectConversation: Identifiable, Codable, Equatable {
    let id: UUID
    let createdAt: Date?
    let lastMessageAt: Date?
    let createdBy: String?
    let otherUserId: String?
    let otherUsername: String?
    let otherAvatarUrl: String?
    let isMuted: Bool?
    let lastMessage: String?
    let lastMessageSenderId: String?
    let unreadCount: Int?
    
    enum CodingKeys: String, CodingKey {
        case id
        case createdAt = "created_at"
        case lastMessageAt = "last_message_at"
        case createdBy = "created_by"
        case otherUserId = "other_user_id"
        case otherUsername = "other_username"
        case otherAvatarUrl = "other_avatar_url"
        case isMuted = "is_muted"
        case lastMessage = "last_message"
        case lastMessageSenderId = "last_message_sender_id"
        case unreadCount = "unread_count"
    }
    
    static func == (lhs: DirectConversation, rhs: DirectConversation) -> Bool {
        lhs.id == rhs.id && lhs.lastMessage == rhs.lastMessage && lhs.unreadCount == rhs.unreadCount
    }
}

struct DirectMessage: Identifiable, Codable, Equatable {
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

// MARK: - Direct Message Service

final class DirectMessageService: ObservableObject {
    static let shared = DirectMessageService()
    private let supabase = SupabaseConfig.supabase
    
    @Published var messages: [DirectMessage] = []
    @Published var conversations: [DirectConversation] = []
    @Published var totalUnreadCount: Int = 0
    
    private var pollingTimer: Timer?
    private var conversationListTimer: Timer?
    private var currentConversationId: UUID?
    
    private init() {}
    
    // MARK: - Get or Create Conversation
    
    func getOrCreateConversation(withUserId otherUserId: String) async throws -> UUID {
        guard let currentUserId = try? await supabase.auth.session.user.id else {
            throw DirectMessageError.notAuthenticated
        }
        
        try await AuthSessionManager.shared.ensureValidSession()
        
        // Try to find existing conversation using the SQL function
        let response = try await supabase.database
            .rpc("find_direct_conversation", params: [
                "p_user1": AnyJSON.string(currentUserId.uuidString),
                "p_user2": AnyJSON.string(otherUserId)
            ])
            .execute()
        
        // The RPC returns a single UUID or null – parse from the raw JSON
        if let jsonString = String(data: response.data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
           jsonString != "null",
           jsonString != "\"\"",
           !jsonString.isEmpty {
            // Remove surrounding quotes if present (e.g. "\"uuid-string\"")
            let cleaned = jsonString.replacingOccurrences(of: "\"", with: "")
            if let existingId = UUID(uuidString: cleaned) {
                print("💬 Found existing conversation: \(existingId)")
                return existingId
            }
        }
        
        // Create new conversation
        struct NewConversation: Encodable {
            let created_by: String
        }
        
        struct ConversationResponse: Decodable {
            let id: UUID
        }
        
        let conversation: ConversationResponse = try await supabase.database
            .from("direct_conversations")
            .insert(NewConversation(created_by: currentUserId.uuidString))
            .select("id")
            .single()
            .execute()
            .value
        
        // Add both participants
        struct Participant: Encodable {
            let conversation_id: String
            let user_id: String
        }
        
        try await supabase.database
            .from("direct_conversation_participants")
            .insert([
                Participant(conversation_id: conversation.id.uuidString, user_id: currentUserId.uuidString),
                Participant(conversation_id: conversation.id.uuidString, user_id: otherUserId)
            ])
            .execute()
        
        print("💬 Created new direct conversation: \(conversation.id)")
        return conversation.id
    }
    
    // MARK: - Fetch Conversations
    
    func fetchConversations() async throws -> [DirectConversation] {
        try await AuthSessionManager.shared.ensureValidSession()
        
        let result: [DirectConversation] = try await supabase.database
            .from("direct_conversations_with_info")
            .select()
            .order("last_message_at", ascending: false)
            .execute()
            .value
        
        await MainActor.run {
            self.conversations = result
            self.totalUnreadCount = result.reduce(0) { $0 + ($1.unreadCount ?? 0) }
        }
        
        return result
    }
    
    // MARK: - Fetch Messages
    
    func fetchMessages(conversationId: UUID) async throws -> [DirectMessage] {
        try await AuthSessionManager.shared.ensureValidSession()
        
        let result: [DirectMessage] = try await supabase.database
            .from("direct_messages")
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
            throw DirectMessageError.notAuthenticated
        }
        
        try await AuthSessionManager.shared.ensureValidSession()
        
        struct NewMessage: Encodable {
            let conversation_id: String
            let sender_id: String
            let message: String
        }
        
        let newMsg: DirectMessage = try await supabase.database
            .from("direct_messages")
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
    }
    
    // MARK: - Mark Messages as Read
    
    func markMessagesAsRead(conversationId: UUID) async throws {
        guard let userId = try? await supabase.auth.session.user.id else { return }
        
        try await AuthSessionManager.shared.ensureValidSession()
        
        try await supabase.database
            .from("direct_messages")
            .update(["is_read": true])
            .eq("conversation_id", value: conversationId)
            .neq("sender_id", value: userId)
            .eq("is_read", value: false)
            .execute()
    }
    
    // MARK: - Toggle Mute
    
    func toggleMute(conversationId: UUID) async throws -> Bool {
        guard let userId = try? await supabase.auth.session.user.id else {
            throw DirectMessageError.notAuthenticated
        }
        
        try await AuthSessionManager.shared.ensureValidSession()
        
        // Get current mute status
        struct ParticipantRow: Decodable {
            let is_muted: Bool
        }
        
        let current: ParticipantRow = try await supabase.database
            .from("direct_conversation_participants")
            .select("is_muted")
            .eq("conversation_id", value: conversationId)
            .eq("user_id", value: userId)
            .single()
            .execute()
            .value
        
        let newMuteStatus = !current.is_muted
        
        try await supabase.database
            .from("direct_conversation_participants")
            .update(["is_muted": newMuteStatus])
            .eq("conversation_id", value: conversationId)
            .eq("user_id", value: userId)
            .execute()
        
        return newMuteStatus
    }
    
    // MARK: - Delete Conversation
    
    func deleteConversation(conversationId: UUID) async throws {
        try await AuthSessionManager.shared.ensureValidSession()
        
        try await supabase.database
            .from("direct_conversations")
            .delete()
            .eq("id", value: conversationId)
            .execute()
        
        await MainActor.run {
            self.conversations.removeAll { $0.id == conversationId }
        }
    }
    
    // MARK: - Polling (Real-time messages)
    
    func startPolling(conversationId: UUID) {
        stopPolling()
        currentConversationId = conversationId
        
        pollingTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            guard let self = self, let convId = self.currentConversationId else { return }
            Task {
                do {
                    _ = try await self.fetchMessages(conversationId: convId)
                    try? await self.markMessagesAsRead(conversationId: convId)
                } catch {
                    print("❌ DM polling error: \(error)")
                }
            }
        }
        
        // Initial fetch
        Task {
            do {
                _ = try await fetchMessages(conversationId: conversationId)
                try? await markMessagesAsRead(conversationId: conversationId)
            } catch {
                print("❌ Initial DM fetch error: \(error)")
            }
        }
    }
    
    func stopPolling() {
        pollingTimer?.invalidate()
        pollingTimer = nil
        currentConversationId = nil
    }
    
    // MARK: - Conversation List Polling
    
    func startConversationListPolling() {
        stopConversationListPolling()
        
        conversationListTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            Task {
                _ = try? await self.fetchConversations()
            }
        }
    }
    
    func stopConversationListPolling() {
        conversationListTimer?.invalidate()
        conversationListTimer = nil
    }
    
    // MARK: - Fetch Unread Count Only
    
    func fetchTotalUnreadCount() async {
        do {
            let conversations = try await fetchConversations()
            let total = conversations.reduce(0) { $0 + ($1.unreadCount ?? 0) }
            await MainActor.run {
                self.totalUnreadCount = total
            }
        } catch {
            print("⚠️ Failed to fetch DM unread count: \(error)")
        }
    }
    
    // MARK: - Get Current User ID
    
    func getCurrentUserId() async -> UUID? {
        try? await supabase.auth.session.user.id
    }
}

// MARK: - Errors

enum DirectMessageError: Error, LocalizedError {
    case notAuthenticated
    case conversationNotFound
    
    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "Du måste vara inloggad för att skicka meddelanden"
        case .conversationNotFound:
            return "Konversationen hittades inte"
        }
    }
}
