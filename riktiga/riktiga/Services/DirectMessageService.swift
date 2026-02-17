import Foundation
import Supabase
import Combine

// MARK: - Direct Message Models

struct DirectConversation: Identifiable, Codable, Equatable {
    let id: UUID
    let createdAt: Date?
    let lastMessageAt: Date?
    let createdBy: String?
    let isGroup: Bool?
    let groupName: String?
    let groupImageUrl: String?
    let otherUserId: String?
    let otherUsername: String?
    let otherAvatarUrl: String?
    let groupParticipantNames: String?
    let memberCount: Int?
    let isMuted: Bool?
    let lastMessage: String?
    let lastMessageSenderId: String?
    let lastMessageSenderName: String?
    let unreadCount: Int?
    
    enum CodingKeys: String, CodingKey {
        case id
        case createdAt = "created_at"
        case lastMessageAt = "last_message_at"
        case createdBy = "created_by"
        case isGroup = "is_group"
        case groupName = "group_name"
        case groupImageUrl = "group_image_url"
        case otherUserId = "other_user_id"
        case otherUsername = "other_username"
        case otherAvatarUrl = "other_avatar_url"
        case groupParticipantNames = "group_participant_names"
        case memberCount = "member_count"
        case isMuted = "is_muted"
        case lastMessage = "last_message"
        case lastMessageSenderId = "last_message_sender_id"
        case lastMessageSenderName = "last_message_sender_name"
        case unreadCount = "unread_count"
    }
    
    /// Display name: group name or other user's name
    var displayName: String {
        if isGroup == true {
            return groupName ?? groupParticipantNames ?? "Grupp"
        }
        return otherUsername ?? "Användare"
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
    let messageType: String?
    let imageUrl: String?
    let isRead: Bool
    let createdAt: Date?
    
    var isGymInvite: Bool { messageType == "gym_invite" }
    var isImage: Bool { messageType == "image" }
    var isGif: Bool { messageType == "gif" }
    var isMediaMessage: Bool { isImage || isGif }
    
    /// Parse the JSON message body for gym invites
    var gymInviteData: GymInviteData? {
        guard isGymInvite else { return nil }
        guard let data = message.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(GymInviteData.self, from: data)
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case conversationId = "conversation_id"
        case senderId = "sender_id"
        case message
        case messageType = "message_type"
        case imageUrl = "image_url"
        case isRead = "is_read"
        case createdAt = "created_at"
    }
}

// MARK: - Gym Invite Models

enum TrainingActivityType: String, Codable, CaseIterable {
    case gym = "gym"
    case running = "running"
    case golf = "golf"
    
    var displayName: String {
        switch self {
        case .gym: return "Gympass"
        case .running: return "Löppass"
        case .golf: return "Golfrunda"
        }
    }
    
    var icon: String {
        switch self {
        case .gym: return "dumbbell.fill"
        case .running: return "figure.run"
        case .golf: return "figure.golf"
        }
    }
    
    var emoji: String {
        switch self {
        case .gym: return "💪"
        case .running: return "🏃"
        case .golf: return "⛳"
        }
    }
    
    var notificationVerb: String {
        switch self {
        case .gym: return "gymma"
        case .running: return "springa"
        case .golf: return "spela golf"
        }
    }
}

struct GymInviteData: Codable {
    let date: String    // "2026-02-15"
    let time: String    // "18:00"
    let gym: String     // "Nordic Wellness Kungsbacka"
    var activityType: TrainingActivityType?  // nil = gym (backwards compatible)
    
    var resolvedActivityType: TrainingActivityType {
        activityType ?? .gym
    }
    
    var displayDate: String {
        let inputFormatter = DateFormatter()
        inputFormatter.dateFormat = "yyyy-MM-dd"
        guard let date = inputFormatter.date(from: date) else { return self.date }
        
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return "Idag"
        } else if calendar.isDateInTomorrow(date) {
            return "Imorgon"
        } else {
            let outputFormatter = DateFormatter()
            outputFormatter.dateFormat = "EEEE d MMMM"
            outputFormatter.locale = Locale(identifier: "sv_SE")
            return outputFormatter.string(from: date).capitalized
        }
    }
    
    /// Full date+time as a Date object (for scheduling reminders)
    var sessionDate: Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        formatter.locale = Locale(identifier: "sv_SE")
        return formatter.date(from: "\(date) \(time)")
    }
    
    enum CodingKeys: String, CodingKey {
        case date, time, gym
        case activityType = "activity_type"
    }
}

struct GymInviteResponse: Identifiable, Codable {
    let id: UUID
    let messageId: UUID
    let userId: UUID
    let response: String
    let respondedAt: Date?
    var username: String?
    
    var isAccepted: Bool { response == "accepted" }
    
    enum CodingKeys: String, CodingKey {
        case id
        case messageId = "message_id"
        case userId = "user_id"
        case response
        case respondedAt = "responded_at"
        case username
    }
}

// MARK: - Message Reaction Model

struct MessageReaction: Identifiable, Codable, Equatable {
    let id: UUID
    let messageId: UUID
    let userId: UUID
    let emoji: String
    let createdAt: Date?
    
    enum CodingKeys: String, CodingKey {
        case id
        case messageId = "message_id"
        case userId = "user_id"
        case emoji
        case createdAt = "created_at"
    }
}

/// Grouped reaction for display (e.g. "👍 3")
struct ReactionGroup: Identifiable, Equatable {
    let emoji: String
    let count: Int
    let userIds: [UUID]
    let hasReactedByMe: Bool
    
    var id: String { emoji }
}

// MARK: - Direct Message Service

final class DirectMessageService: ObservableObject {
    static let shared = DirectMessageService()
    private let supabase = SupabaseConfig.supabase
    
    @Published var messages: [DirectMessage] = []
    @Published var conversations: [DirectConversation] = []
    @Published var totalUnreadCount: Int = 0
    @Published var isOtherUserTyping: Bool = false
    @Published var reactions: [UUID: [ReactionGroup]] = [:]  // messageId -> grouped reactions
    
    private var pollingTimer: Timer?
    private var conversationListTimer: Timer?
    private var currentConversationId: UUID?
    private var typingTimer: Timer?
    private var deletedMessageIds: Set<UUID> = []
    
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
    
    // MARK: - Create Group Conversation
    
    func createGroupConversation(withUserIds userIds: [String], groupName: String) async throws -> UUID {
        guard let currentUserId = try? await supabase.auth.session.user.id else {
            throw DirectMessageError.notAuthenticated
        }
        
        try await AuthSessionManager.shared.ensureValidSession()
        
        struct NewGroupConversation: Encodable {
            let created_by: String
            let is_group: Bool
            let group_name: String
        }
        
        struct ConversationResponse: Decodable {
            let id: UUID
        }
        
        let conversation: ConversationResponse = try await supabase.database
            .from("direct_conversations")
            .insert(NewGroupConversation(
                created_by: currentUserId.uuidString,
                is_group: true,
                group_name: groupName
            ))
            .select("id")
            .single()
            .execute()
            .value
        
        // Add all participants including self
        struct Participant: Encodable {
            let conversation_id: String
            let user_id: String
        }
        
        var participants = [Participant(conversation_id: conversation.id.uuidString, user_id: currentUserId.uuidString)]
        for userId in userIds {
            participants.append(Participant(conversation_id: conversation.id.uuidString, user_id: userId))
        }
        
        try await supabase.database
            .from("direct_conversation_participants")
            .insert(participants)
            .execute()
        
        print("💬 Created group conversation '\(groupName)' with \(participants.count) members: \(conversation.id)")
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
        
        // Filter out locally deleted messages (prevents reappearing after polling)
        let filtered = result.filter { !deletedMessageIds.contains($0.id) }
        
        await MainActor.run {
            self.messages = filtered
        }
        
        return filtered
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
        
        // Send push notification
        await sendDirectMessageNotification(
            conversationId: conversationId,
            senderId: userId.uuidString,
            message: message,
            messageType: "text"
        )
    }
    
    // MARK: - Send Image Message
    
    func sendImageMessage(conversationId: UUID, imageData: Data) async throws {
        guard let userId = try? await supabase.auth.session.user.id else {
            throw DirectMessageError.notAuthenticated
        }
        
        try await AuthSessionManager.shared.ensureValidSession()
        
        // Upload image to Supabase Storage
        let timestamp = Int(Date().timeIntervalSince1970)
        let fileName = "\(userId.uuidString)/\(conversationId.uuidString)_\(timestamp).jpg"
        
        try await supabase.storage
            .from("chat-images")
            .upload(
                fileName,
                data: imageData,
                options: FileOptions(contentType: "image/jpeg", upsert: true)
            )
        
        let publicURL = try supabase.storage
            .from("chat-images")
            .getPublicURL(path: fileName)
        
        struct NewImageMessage: Encodable {
            let conversation_id: String
            let sender_id: String
            let message: String
            let message_type: String
            let image_url: String
        }
        
        let newMsg: DirectMessage = try await supabase.database
            .from("direct_messages")
            .insert(NewImageMessage(
                conversation_id: conversationId.uuidString,
                sender_id: userId.uuidString,
                message: "📷 Bild",
                message_type: "image",
                image_url: publicURL.absoluteString
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
        
        // Send push notification
        await sendDirectMessageNotification(
            conversationId: conversationId,
            senderId: userId.uuidString,
            message: "📷 Skickade en bild",
            messageType: "text"
        )
    }
    
    // MARK: - Send GIF Message
    
    func sendGifMessage(conversationId: UUID, gifUrl: String) async throws {
        guard let userId = try? await supabase.auth.session.user.id else {
            throw DirectMessageError.notAuthenticated
        }
        
        try await AuthSessionManager.shared.ensureValidSession()
        
        struct NewGifMessage: Encodable {
            let conversation_id: String
            let sender_id: String
            let message: String
            let message_type: String
            let image_url: String
        }
        
        let newMsg: DirectMessage = try await supabase.database
            .from("direct_messages")
            .insert(NewGifMessage(
                conversation_id: conversationId.uuidString,
                sender_id: userId.uuidString,
                message: "GIF",
                message_type: "gif",
                image_url: gifUrl
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
        
        // Send push notification
        await sendDirectMessageNotification(
            conversationId: conversationId,
            senderId: userId.uuidString,
            message: "Skickade en GIF",
            messageType: "text"
        )
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
    
    // MARK: - Delete Message
    
    func deleteMessage(messageId: UUID) async throws {
        // Immediately track as deleted so polling won't re-add it
        deletedMessageIds.insert(messageId)
        
        await MainActor.run {
            self.messages.removeAll { $0.id == messageId }
        }
        
        try await AuthSessionManager.shared.ensureValidSession()
        
        // Use RPC function for reliable deletion (bypasses RLS issues)
        do {
            let params: [String: String] = ["p_message_id": messageId.uuidString]
            
            try await supabase.database
                .rpc("delete_own_message", params: params)
                .execute()
            
            print("✅ [DELETE] Message \(messageId) deleted via RPC")
        } catch {
            print("❌ [DELETE] RPC delete failed, trying direct delete: \(error)")
            
            // Fallback: try direct delete (in case RPC doesn't exist yet)
            do {
                try await supabase.database
                    .from("direct_messages")
                    .delete()
                    .eq("id", value: messageId)
                    .execute()
                
                print("✅ [DELETE] Message \(messageId) deleted via direct delete")
            } catch {
                print("❌ [DELETE] Direct delete also failed: \(error)")
                // Keep it in deletedMessageIds so it stays hidden locally
            }
        }
        
        // Don't remove from deletedMessageIds - keep tracking permanently for this session
        // It will be cleared when user leaves the chat (stopPolling)
    }
    
    // MARK: - Gym Invite
    
    func sendGymInvite(conversationId: UUID, date: String, time: String, gym: String, activityType: TrainingActivityType = .gym) async throws {
        guard let userId = try? await supabase.auth.session.user.id else {
            throw DirectMessageError.notAuthenticated
        }
        
        try await AuthSessionManager.shared.ensureValidSession()
        
        let inviteData = GymInviteData(date: date, time: time, gym: gym, activityType: activityType)
        let jsonData = try JSONEncoder().encode(inviteData)
        let jsonString = String(data: jsonData, encoding: .utf8) ?? "{}"
        
        struct NewGymInvite: Encodable {
            let conversation_id: String
            let sender_id: String
            let message: String
            let message_type: String
        }
        
        let newMsg: DirectMessage = try await supabase.database
            .from("direct_messages")
            .insert(NewGymInvite(
                conversation_id: conversationId.uuidString,
                sender_id: userId.uuidString,
                message: jsonString,
                message_type: "gym_invite"
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
        
        // Send push notification
        await sendDirectMessageNotification(
            conversationId: conversationId,
            senderId: userId.uuidString,
            message: jsonString,
            messageType: "gym_invite"
        )
    }
    
    func respondToGymInvite(messageId: UUID, response: String, conversationId: UUID? = nil) async throws {
        guard let userId = try? await supabase.auth.session.user.id else {
            throw DirectMessageError.notAuthenticated
        }
        
        try await AuthSessionManager.shared.ensureValidSession()
        
        struct InviteResponse: Encodable {
            let message_id: String
            let user_id: String
            let response: String
        }
        
        try await supabase.database
            .from("gym_invite_responses")
            .upsert(InviteResponse(
                message_id: messageId.uuidString,
                user_id: userId.uuidString,
                response: response
            ))
            .execute()
        
        // Send push notification to the invite creator
        if let convId = conversationId {
            await sendDirectMessageNotification(
                conversationId: convId,
                senderId: userId.uuidString,
                message: response,
                messageType: "gym_invite_response"
            )
        }
    }
    
    func fetchInviteResponses(messageId: UUID) async throws -> [GymInviteResponse] {
        try await AuthSessionManager.shared.ensureValidSession()
        
        struct ResponseRow: Decodable {
            let id: UUID
            let message_id: UUID
            let user_id: UUID
            let response: String
            let responded_at: Date?
        }
        
        let rows: [ResponseRow] = try await supabase.database
            .from("gym_invite_responses")
            .select("id, message_id, user_id, response, responded_at")
            .eq("message_id", value: messageId)
            .execute()
            .value
        
        // Fetch usernames for each responder
        var responses: [GymInviteResponse] = []
        for row in rows {
            var resp = GymInviteResponse(
                id: row.id,
                messageId: row.message_id,
                userId: row.user_id,
                response: row.response,
                respondedAt: row.responded_at,
                username: nil
            )
            
            // Try to get username
            struct ProfileRow: Decodable {
                let username: String?
            }
            if let profile: ProfileRow = try? await supabase.database
                .from("profiles")
                .select("username")
                .eq("id", value: row.user_id)
                .single()
                .execute()
                .value {
                resp.username = profile.username
            }
            
            responses.append(resp)
        }
        
        return responses
    }
    
    // MARK: - Typing Indicators
    
    func setTyping(conversationId: UUID, isTyping: Bool) async {
        guard let userId = try? await supabase.auth.session.user.id else { return }
        
        struct TypingUpdate: Encodable {
            let is_typing: Bool
            let typing_updated_at: String
        }
        
        do {
            try await supabase.database
                .from("direct_conversation_participants")
                .update(TypingUpdate(
                    is_typing: isTyping,
                    typing_updated_at: ISO8601DateFormatter().string(from: Date())
                ))
                .eq("conversation_id", value: conversationId)
                .eq("user_id", value: userId)
                .execute()
        } catch {
            print("⚠️ Failed to update typing status: \(error)")
        }
    }
    
    func checkOtherUserTyping(conversationId: UUID) async {
        guard let userId = try? await supabase.auth.session.user.id else { return }
        
        struct TypingRow: Decodable {
            let is_typing: Bool?
            let typing_updated_at: Date?
        }
        
        do {
            try await AuthSessionManager.shared.ensureValidSession()
            
            let rows: [TypingRow] = try await supabase.database
                .from("direct_conversation_participants")
                .select("is_typing, typing_updated_at")
                .eq("conversation_id", value: conversationId)
                .neq("user_id", value: userId)
                .execute()
                .value
            
            if let other = rows.first,
               let isTyping = other.is_typing,
               let updatedAt = other.typing_updated_at,
               isTyping,
               Date().timeIntervalSince(updatedAt) < 6 {
                await MainActor.run { self.isOtherUserTyping = true }
            } else {
                await MainActor.run { self.isOtherUserTyping = false }
            }
        } catch {
            await MainActor.run { self.isOtherUserTyping = false }
        }
    }
    
    /// Call this when user types in the text field – auto-resets after 3 seconds of inactivity
    func userDidType(conversationId: UUID) {
        let schedule = { [weak self] in
            self?.typingTimer?.invalidate()
            Task { await self?.setTyping(conversationId: conversationId, isTyping: true) }
            self?.typingTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { [weak self] _ in
                Task { await self?.setTyping(conversationId: conversationId, isTyping: false) }
            }
        }
        if Thread.isMainThread { schedule() } else { DispatchQueue.main.async { schedule() } }
    }
    
    func stopTyping(conversationId: UUID) {
        let stop = { [weak self] in
            self?.typingTimer?.invalidate()
            self?.typingTimer = nil
        }
        if Thread.isMainThread { stop() } else { DispatchQueue.main.async { stop() } }
        Task { await setTyping(conversationId: conversationId, isTyping: false) }
    }
    
    // MARK: - Polling (Real-time messages)
    
    func startPolling(conversationId: UUID) {
        // Ensure timers are always created on the main thread's run loop
        // so they fire reliably regardless of which thread/iOS version calls this
        let setup = { [weak self] in
            guard let self = self else { return }
            self.stopPollingSync()
            self.currentConversationId = conversationId
            
            self.pollingTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
                guard let self = self, let convId = self.currentConversationId else { return }
                Task {
                    do {
                        _ = try await self.fetchMessages(conversationId: convId)
                        try? await self.markMessagesAsRead(conversationId: convId)
                        await self.checkOtherUserTyping(conversationId: convId)
                        await self.fetchReactions(conversationId: convId)
                    } catch {
                        print("❌ DM polling error: \(error)")
                    }
                }
            }
            // Fire immediately so the first poll doesn't wait 2 seconds
            self.pollingTimer?.fire()
        }
        
        if Thread.isMainThread {
            setup()
        } else {
            DispatchQueue.main.async { setup() }
        }
        
        // Initial fetch (always runs, regardless of timer)
        Task {
            do {
                _ = try await fetchMessages(conversationId: conversationId)
                try? await markMessagesAsRead(conversationId: conversationId)
                await checkOtherUserTyping(conversationId: conversationId)
                await fetchReactions(conversationId: conversationId)
            } catch {
                print("❌ Initial DM fetch error: \(error)")
            }
        }
    }
    
    /// Internal synchronous stop – must be called on the main thread
    private func stopPollingSync() {
        pollingTimer?.invalidate()
        pollingTimer = nil
        currentConversationId = nil
        deletedMessageIds.removeAll()
        reactions.removeAll()
    }
    
    func stopPolling() {
        if Thread.isMainThread {
            stopPollingSync()
        } else {
            DispatchQueue.main.async { [weak self] in
                self?.stopPollingSync()
            }
        }
    }
    
    // MARK: - Conversation List Polling
    
    func startConversationListPolling() {
        let setup = { [weak self] in
            guard let self = self else { return }
            self.conversationListTimer?.invalidate()
            self.conversationListTimer = nil
            
            self.conversationListTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
                guard let self = self else { return }
                Task {
                    _ = try? await self.fetchConversations()
                }
            }
            // Fire immediately
            self.conversationListTimer?.fire()
        }
        
        if Thread.isMainThread {
            setup()
        } else {
            DispatchQueue.main.async { setup() }
        }
    }
    
    func stopConversationListPolling() {
        let stop = { [weak self] in
            self?.conversationListTimer?.invalidate()
            self?.conversationListTimer = nil
        }
        if Thread.isMainThread { stop() } else { DispatchQueue.main.async { stop() } }
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
    
    // MARK: - Push Notification for Direct Messages
    
    private func sendDirectMessageNotification(conversationId: UUID, senderId: String, message: String, messageType: String) async {
        struct DMNotificationPayload: Encodable {
            let conversation_id: String
            let sender_id: String
            let message: String
            let message_type: String
        }
        
        let payload = DMNotificationPayload(
            conversation_id: conversationId.uuidString,
            sender_id: senderId,
            message: message,
            message_type: messageType
        )
        
        do {
            try await supabase.functions.invoke(
                "notify-direct-message",
                options: .init(body: payload)
            )
            print("📨 DM push notification sent for \(messageType)")
        } catch {
            print("⚠️ Failed to send DM push notification: \(error)")
        }
    }
    
    // MARK: - Message Reactions
    
    func toggleReaction(messageId: UUID, emoji: String) async throws {
        guard let userId = try? await supabase.auth.session.user.id else {
            throw DirectMessageError.notAuthenticated
        }
        
        try await AuthSessionManager.shared.ensureValidSession()
        
        // Check if reaction already exists
        let existing: [MessageReaction] = try await supabase.database
            .from("direct_message_reactions")
            .select()
            .eq("message_id", value: messageId)
            .eq("user_id", value: userId)
            .eq("emoji", value: emoji)
            .execute()
            .value
        
        if existing.isEmpty {
            // Add reaction
            struct NewReaction: Encodable {
                let message_id: String
                let user_id: String
                let emoji: String
            }
            
            try await supabase.database
                .from("direct_message_reactions")
                .insert(NewReaction(
                    message_id: messageId.uuidString,
                    user_id: userId.uuidString,
                    emoji: emoji
                ))
                .execute()
            
            print("✅ Added reaction \(emoji) to message \(messageId)")
        } else {
            // Remove reaction
            try await supabase.database
                .from("direct_message_reactions")
                .delete()
                .eq("message_id", value: messageId)
                .eq("user_id", value: userId)
                .eq("emoji", value: emoji)
                .execute()
            
            print("✅ Removed reaction \(emoji) from message \(messageId)")
        }
        
        // Refresh reactions for this conversation
        if let convId = currentConversationId {
            await fetchReactions(conversationId: convId)
        }
    }
    
    func fetchReactions(conversationId: UUID) async {
        guard let userId = try? await supabase.auth.session.user.id else { return }
        
        do {
            // Get all message IDs in current conversation
            let messageIds = await MainActor.run { messages.map { $0.id } }
            guard !messageIds.isEmpty else { return }
            
            let allReactions: [MessageReaction] = try await supabase.database
                .from("direct_message_reactions")
                .select()
                .in("message_id", values: messageIds.map { $0.uuidString })
                .execute()
                .value
            
            // Group by message, then by emoji
            var grouped: [UUID: [ReactionGroup]] = [:]
            
            let byMessage = Dictionary(grouping: allReactions) { $0.messageId }
            for (msgId, msgReactions) in byMessage {
                let byEmoji = Dictionary(grouping: msgReactions) { $0.emoji }
                var groups: [ReactionGroup] = []
                for (emoji, emojiReactions) in byEmoji {
                    let userIds = emojiReactions.map { $0.userId }
                    groups.append(ReactionGroup(
                        emoji: emoji,
                        count: emojiReactions.count,
                        userIds: userIds,
                        hasReactedByMe: userIds.contains(userId)
                    ))
                }
                // Sort by count descending, then emoji
                groups.sort { $0.count > $1.count || ($0.count == $1.count && $0.emoji < $1.emoji) }
                grouped[msgId] = groups
            }
            
            await MainActor.run {
                self.reactions = grouped
            }
        } catch {
            print("⚠️ Failed to fetch reactions: \(error)")
        }
    }
    
    // MARK: - Get Current User ID
    
    func getCurrentUserId() async -> UUID? {
        try? await supabase.auth.session.user.id
    }
    
    // MARK: - Fetch User Profiles (name + avatar)
    
    struct UserProfileInfo: Decodable {
        let id: String
        let username: String?
        let avatar_url: String?
    }
    
    func fetchUserProfiles(userIds: [String]) async throws -> [UserProfileInfo] {
        guard !userIds.isEmpty else { return [] }
        try await AuthSessionManager.shared.ensureValidSession()
        
        let profiles: [UserProfileInfo] = try await supabase.database
            .from("profiles")
            .select("id, username, avatar_url")
            .in("id", values: userIds)
            .execute()
            .value
        
        return profiles
    }
    
    // MARK: - Fetch Conversation Participant IDs
    
    func fetchParticipantIds(conversationId: UUID) async throws -> [String] {
        try await AuthSessionManager.shared.ensureValidSession()
        
        struct ParticipantRow: Decodable {
            let user_id: String
        }
        
        let rows: [ParticipantRow] = try await supabase.database
            .from("direct_conversation_participants")
            .select("user_id")
            .eq("conversation_id", value: conversationId)
            .execute()
            .value
        
        return rows.map { $0.user_id }
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
