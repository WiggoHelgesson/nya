import SwiftUI
import Supabase

struct MessagesListView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @Environment(\.dismiss) private var dismiss
    @StateObject private var dmService = DirectMessageService.shared
    @StateObject private var trainerChatService = TrainerChatService.shared
    
    @State private var isLoading = true
    @State private var showNewMessage = false
    @State private var listAppeared = true
    
    // Coach data
    @State private var coachRelation: CoachClientRelation?
    @State private var coachTrainerProfile: GolfTrainer?
    @State private var coachConversationId: UUID?
    @State private var coachLastMessage: String?
    @State private var coachLastMessageAt: Date?
    @State private var coachUnreadCount: Int = 0
    
    /// All content is empty (no DMs, no trainer chats, no coach)
    private var allEmpty: Bool {
        dmService.conversations.isEmpty &&
        trainerChatService.conversations.isEmpty &&
        coachRelation == nil
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 16) {
                Button {
                    dismiss()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .medium))
                        Text("Hem")
                            .font(.system(size: 16))
                    }
                    .foregroundColor(.primary)
                }
                
                Spacer()
                
                Text("Meddelanden")
                    .font(.system(size: 17, weight: .bold))
                
                Spacer()
                
                HStack(spacing: 14) {
                    Button {
                        showNewMessage = true
                    } label: {
                        Image(systemName: "square.and.pencil")
                            .font(.system(size: 20, weight: .regular))
                            .foregroundColor(.primary)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            
            Divider()
            
            // Content
            if isLoading {
                Spacer()
                ProgressView()
                    .scaleEffect(1.2)
                    .transition(.opacity)
                Spacer()
            } else if allEmpty {
                emptyState
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
            } else {
                fullConversationList
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: isLoading)
        .background(Color(.systemBackground))
        .navigationBarHidden(true)
        .task {
            await loadAllConversations()
            dmService.startConversationListPolling()
        }
        .onAppear {
            NavigationDepthTracker.shared.setAtRoot(false)
            NotificationCenter.default.post(name: NSNotification.Name("HideFloatingButton"), object: nil)
        }
        .onDisappear {
            dmService.stopConversationListPolling()
            NavigationDepthTracker.shared.setAtRoot(true)
            NotificationCenter.default.post(name: NSNotification.Name("ShowFloatingButton"), object: nil)
        }
        .sheet(isPresented: $showNewMessage) {
            NewMessageView(onConversationCreated: { conversationId, otherUserId, otherUsername, otherAvatarUrl in
                showNewMessage = false
                Task { await loadAllConversations() }
            })
            .environmentObject(authViewModel)
        }
    }
    
    // MARK: - Full Conversation List (Coach + Trainer + DMs)
    
    private var fullConversationList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                // Coach chat section
                if let coach = coachRelation, let trainerProfile = coachTrainerProfile {
                    sectionHeader("Din coach")
                    
                    NavigationLink(destination: TrainerChatView(trainer: trainerProfile)) {
                        coachRow(coach: coach, trainer: trainerProfile)
                            .opacity(listAppeared ? 1 : 0)
                            .offset(y: listAppeared ? 0 : 12)
                            .animation(
                                .spring(response: 0.4, dampingFraction: 0.85),
                                value: listAppeared
                            )
                    }
                    .buttonStyle(.plain)
                    
                    Divider()
                        .padding(.leading, 72)
                }
                
                // Trainer chats section
                if !trainerChatService.conversations.isEmpty {
                    sectionHeader("Tränare")
                    
                    ForEach(Array(trainerChatService.conversations.enumerated()), id: \.element.id) { index, conversation in
                        trainerConversationRow(conversation: conversation, index: index)
                    }
                }
                
                // Regular DM conversations
                if !dmService.conversations.isEmpty {
                    if coachRelation != nil || !trainerChatService.conversations.isEmpty {
                        sectionHeader("Direktmeddelanden")
                    }
                    
                    ForEach(Array(dmService.conversations.enumerated()), id: \.element.id) { index, conversation in
                        NavigationLink(destination: DirectMessageView(
                            conversationId: conversation.id,
                            otherUserId: conversation.otherUserId ?? "",
                            otherUsername: conversation.displayName,
                            otherAvatarUrl: conversation.otherAvatarUrl,
                            isGroup: conversation.isGroup ?? false,
                            memberCount: conversation.memberCount ?? 2
                        ).environmentObject(authViewModel)) {
                            ConversationRow(conversation: conversation, currentUserId: authViewModel.currentUser?.id ?? "")
                                .opacity(listAppeared ? 1 : 0)
                                .offset(y: listAppeared ? 0 : 12)
                                .animation(
                                    .spring(response: 0.4, dampingFraction: 0.85)
                                    .delay(Double(min(index, 10)) * 0.04),
                                    value: listAppeared
                                )
                        }
                        .buttonStyle(.plain)
                        
                        Divider()
                            .padding(.leading, 72)
                    }
                }
            }
        }
    }
    
    // MARK: - Section Header
    
    private func sectionHeader(_ title: String) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.secondary)
                .textCase(.uppercase)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .padding(.bottom, 6)
    }
    
    // MARK: - Coach Row
    
    private func coachRow(coach: CoachClientRelation, trainer: GolfTrainer) -> some View {
        HStack(spacing: 12) {
            // Avatar with coach badge
            ZStack(alignment: .bottomTrailing) {
                ProfileImage(url: trainer.avatarUrl, size: 50)
                
                Image(systemName: "star.fill")
                    .font(.system(size: 10))
                    .foregroundColor(.white)
                    .padding(3)
                    .background(Color.orange)
                    .clipShape(Circle())
                    .offset(x: 2, y: 2)
            }
            
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(coach.coach?.username ?? trainer.name)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    Text("COACH")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.orange)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.orange.opacity(0.12))
                        .cornerRadius(4)
                }
                
                Text(coachLastMessage ?? "Tryck för att chatta med din coach")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                if let date = coachLastMessageAt {
                    Text(formatTime(date))
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color(.systemBackground))
    }
    
    // MARK: - Trainer Conversation Row
    
    @ViewBuilder
    private func trainerConversationRow(conversation: TrainerConversation, index: Int) -> some View {
        let currentUserId = authViewModel.currentUser?.id ?? ""
        let isTrainer = conversation.trainerUserId == currentUserId
        let displayName = isTrainer ? (conversation.userUsername ?? "Klient") : (conversation.trainerName ?? "Tränare")
        let avatarUrl = isTrainer ? conversation.userAvatarUrl : conversation.trainerAvatarUrl
        
        // Build a GolfTrainer for navigation (we need the trainer to open TrainerChatView)
        let trainer = GolfTrainer(
            id: conversation.trainerId,
            userId: conversation.trainerUserId ?? "",
            name: conversation.trainerName ?? "Tränare",
            description: "",
            hourlyRate: 0,
            handicap: 0,
            latitude: 0,
            longitude: 0,
            avatarUrl: conversation.trainerAvatarUrl,
            createdAt: nil,
            city: nil,
            bio: nil,
            experienceYears: nil,
            clubAffiliation: nil,
            averageRating: nil,
            totalReviews: nil,
            totalLessons: nil,
            isActive: true,
            serviceRadiusKm: nil,
            instagramUrl: nil,
            facebookUrl: nil,
            websiteUrl: nil,
            phoneNumber: nil,
            contactEmail: nil,
            galleryUrls: nil
        )
        
        NavigationLink(destination: TrainerChatView(trainer: trainer)) {
            HStack(spacing: 12) {
                // Avatar with trainer badge
                ZStack(alignment: .bottomTrailing) {
                    ProfileImage(url: avatarUrl, size: 50)
                    
                    Image(systemName: "figure.strengthtraining.traditional")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(.white)
                        .padding(3)
                        .background(Color.blue)
                        .clipShape(Circle())
                        .offset(x: 2, y: 2)
                }
                
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(displayName)
                            .font(.system(size: 15, weight: (conversation.unreadCount ?? 0) > 0 ? .bold : .semibold))
                            .foregroundColor(.primary)
                            .lineLimit(1)
                        
                        Text("TRÄNARE")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.blue)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.12))
                            .cornerRadius(4)
                    }
                    
                    if let lastMessage = conversation.lastMessage, !lastMessage.isEmpty {
                        Text(lastMessage)
                            .font(.system(size: 13, weight: (conversation.unreadCount ?? 0) > 0 ? .medium : .regular))
                            .foregroundColor((conversation.unreadCount ?? 0) > 0 ? .primary : .secondary)
                            .lineLimit(1)
                    } else {
                        Text("Tryck för att chatta")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    if let date = conversation.lastMessageAt {
                        Text(formatTime(date))
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color(.systemBackground))
            .opacity(listAppeared ? 1 : 0)
            .offset(y: listAppeared ? 0 : 12)
            .animation(
                .spring(response: 0.4, dampingFraction: 0.85)
                .delay(Double(min(index, 10)) * 0.04),
                value: listAppeared
            )
        }
        .buttonStyle(.plain)
        
        Divider()
            .padding(.leading, 72)
    }
    
    // MARK: - Empty State
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 50))
                .foregroundColor(.secondary.opacity(0.5))
            
            Text("Inga meddelanden än")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.primary)
            
            Text("Skicka ett meddelande till någon för att starta en konversation")
                .font(.system(size: 14))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 50)
            
            Button {
                showNewMessage = true
            } label: {
                Text("Nytt meddelande")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color.black)
                    .cornerRadius(24)
            }
            .padding(.top, 8)
            
            Spacer()
        }
    }
    
    // MARK: - Load
    
    private func loadAllConversations() async {
        isLoading = true
        
        // Load everything in parallel
        async let dmTask: () = loadDMConversations()
        async let trainerTask: () = loadTrainerConversations()
        async let coachTask: () = loadCoachData()
        
        _ = await (dmTask, trainerTask, coachTask)
        
        isLoading = false
    }
    
    private func loadDMConversations() async {
        _ = try? await dmService.fetchConversations()
    }
    
    private func loadTrainerConversations() async {
        _ = try? await trainerChatService.fetchConversations()
    }
    
    private func loadCoachData() async {
        guard let userId = authViewModel.currentUser?.id else { return }
        
        do {
            let relation = try await CoachService.shared.fetchMyCoach(for: userId)
            
            if let relation = relation, let coachId = UUID(uuidString: relation.coachId) {
                // Load the trainer profile for this coach
                let trainers: [GolfTrainer] = try await SupabaseConfig.supabase
                    .from("trainer_profiles")
                    .select()
                    .eq("user_id", value: relation.coachId)
                    .limit(1)
                    .execute()
                    .value
                
                // Try to get the conversation and last message
                var lastMsg: String? = nil
                var lastMsgAt: Date? = nil
                
                if let trainer = trainers.first {
                    if let convId = try? await trainerChatService.getOrCreateConversation(trainerId: trainer.id) {
                        let messages = try await trainerChatService.fetchMessages(conversationId: convId)
                        if let last = messages.last {
                            lastMsg = last.message
                            lastMsgAt = last.createdAt
                        }
                        await MainActor.run {
                            coachConversationId = convId
                        }
                    }
                }
                
                await MainActor.run {
                    coachRelation = relation
                    coachTrainerProfile = trainers.first
                    coachLastMessage = lastMsg
                    coachLastMessageAt = lastMsgAt
                }
            }
        } catch {
            print("⚠️ Failed to load coach data for messages: \(error)")
        }
    }
    
    // MARK: - Helpers
    
    private func formatTime(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm"
            return formatter.string(from: date)
        } else if calendar.isDateInYesterday(date) {
            return "Igår"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "d MMM"
            formatter.locale = Locale(identifier: "sv_SE")
            return formatter.string(from: date)
        }
    }
}

// MARK: - Conversation Row

struct ConversationRow: View {
    let conversation: DirectConversation
    let currentUserId: String
    
    private var isGroup: Bool { conversation.isGroup ?? false }
    
    var body: some View {
        HStack(spacing: 12) {
            // Avatar
            if isGroup {
                // Group avatar: overlapping circles
                ZStack {
                    Circle()
                        .fill(Color(.systemGray5))
                        .frame(width: 50, height: 50)
                    Image(systemName: "person.3.fill")
                        .font(.system(size: 18))
                        .foregroundColor(.secondary)
                }
            } else {
                ProfileImage(url: conversation.otherAvatarUrl, size: 50)
            }
            
            // Name + last message
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 4) {
                    Text(conversation.displayName)
                        .font(.system(size: 15, weight: hasUnread ? .bold : .semibold))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    if isGroup, let count = conversation.memberCount {
                        Text("(\(count))")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                }
                
                if let lastMessage = conversation.lastMessage, !lastMessage.isEmpty {
                    HStack(spacing: 0) {
                        if conversation.lastMessageSenderId == currentUserId {
                            Text("Du: ")
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                        } else if isGroup, let senderName = conversation.lastMessageSenderName {
                            Text("\(senderName): ")
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                        }
                        
                        Text(formattedLastMessage(lastMessage))
                            .font(.system(size: 13, weight: hasUnread ? .medium : .regular))
                            .foregroundColor(hasUnread ? .primary : .secondary)
                            .lineLimit(1)
                    }
                }
            }
            
            Spacer()
            
            // Time + unread badge
            VStack(alignment: .trailing, spacing: 4) {
                if let date = conversation.lastMessageAt {
                    Text(formatTime(date))
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                
                // Read status checkmarks
                if let senderId = conversation.lastMessageSenderId, senderId == currentUserId {
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color(.systemBackground))
    }
    
    private var hasUnread: Bool {
        (conversation.unreadCount ?? 0) > 0
    }
    
    /// Format last message - detect special message types and show friendly text
    private func formattedLastMessage(_ message: String) -> String {
        let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Detect training invite JSON (starts with { and contains "gym", "date", "time")
        if trimmed.hasPrefix("{"),
           trimmed.contains("\"gym\""),
           trimmed.contains("\"date\""),
           trimmed.contains("\"time\"") {
            // Try to parse activity type for a more specific preview
            if let data = trimmed.data(using: .utf8),
               let invite = try? JSONDecoder().decode(GymInviteData.self, from: data) {
                return "Skickade ett träningsförslag: \(invite.resolvedActivityType.displayName) \(invite.resolvedActivityType.emoji)"
            }
            return "Skickade ett träningsförslag 💪"
        }
        
        // Detect training invite response
        if trimmed == "accepted" {
            return "Godkände träningsförslaget ✅"
        }
        if trimmed == "declined" {
            return "Avböjde träningsförslaget"
        }
        
        return message
    }
    
    private func formatTime(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm"
            return formatter.string(from: date)
        } else if calendar.isDateInYesterday(date) {
            return "Igår"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "d MMM"
            formatter.locale = Locale(identifier: "sv_SE")
            return formatter.string(from: date)
        }
    }
}
