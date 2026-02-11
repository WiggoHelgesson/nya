import SwiftUI

struct TrainerChatView: View {
    let trainer: GolfTrainer
    @StateObject private var chatService = TrainerChatService.shared
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme
    
    @State private var messageText = ""
    @State private var conversationId: UUID?
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var currentUserId: UUID?
    @FocusState private var isInputFocused: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            // MARK: - Header
            chatHeader
            
            Divider()
            
            // MARK: - Messages
            if isLoading {
                Spacer()
                ProgressView()
                    .scaleEffect(1.2)
                Spacer()
            } else if let error = errorMessage {
                Spacer()
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary)
                    Text(error)
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 40)
                Spacer()
            } else {
                messagesScrollView
            }
            
            // MARK: - Input Bar
            chatInputBar
        }
        .background(Color(.systemBackground))
        .navigationBarHidden(true)
        .task {
            await setupChat()
        }
        .onDisappear {
            chatService.stopPolling()
        }
    }
    
    // MARK: - Header
    
    private var chatHeader: some View {
        HStack(spacing: 12) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)
            }
            
            ProfileImage(url: trainer.avatarUrl, size: 40)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(trainer.name)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)
                
                Text("Personlig tränare")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(.systemBackground))
    }
    
    // MARK: - Messages Scroll View
    
    private var messagesScrollView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 8) {
                    // Welcome message
                    if chatService.messages.isEmpty {
                        emptyStateMessage
                    }
                    
                    ForEach(chatService.messages) { message in
                        MessageBubbleView(
                            message: message,
                            isFromCurrentUser: message.senderId == currentUserId,
                            trainerAvatarUrl: trainer.avatarUrl
                        )
                        .id(message.id)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 16)
            }
            .onChange(of: chatService.messages.count) { _, _ in
                // Auto-scroll to bottom when new messages arrive
                if let lastMessage = chatService.messages.last {
                    withAnimation(.easeOut(duration: 0.2)) {
                        proxy.scrollTo(lastMessage.id, anchor: .bottom)
                    }
                }
            }
            .onAppear {
                // Scroll to bottom on appear
                if let lastMessage = chatService.messages.last {
                    proxy.scrollTo(lastMessage.id, anchor: .bottom)
                }
            }
        }
    }
    
    // MARK: - Empty State
    
    private var emptyStateMessage: some View {
        VStack(spacing: 12) {
            ProfileImage(url: trainer.avatarUrl, size: 64)
            
            Text(trainer.name)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.primary)
            
            Text("Skicka ett meddelande till \(trainer.name) för att komma igång!")
                .font(.system(size: 14))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .padding(.top, 40)
        .padding(.bottom, 20)
    }
    
    // MARK: - Input Bar
    
    private var chatInputBar: some View {
        VStack(spacing: 0) {
            Divider()
            
            HStack(spacing: 12) {
                // Text input
                HStack {
                    TextField("Skriv ett meddelande...", text: $messageText, axis: .vertical)
                        .font(.system(size: 15))
                        .lineLimit(1...5)
                        .focused($isInputFocused)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                }
                .background(Color(.systemGray6))
                .cornerRadius(20)
                
                // Send button
                Button {
                    sendMessage()
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 32))
                        .foregroundColor(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color(.systemGray4) : .primary)
                }
                .disabled(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(.systemBackground))
        }
    }
    
    // MARK: - Setup
    
    private func setupChat() async {
        isLoading = true
        errorMessage = nil
        
        // Get current user ID
        currentUserId = await chatService.getCurrentUserId()
        
        do {
            // Get or create conversation
            let convId = try await chatService.getOrCreateConversation(trainerId: trainer.id)
            conversationId = convId
            
            // Start polling for real-time updates
            chatService.startPolling(conversationId: convId)
            
            isLoading = false
        } catch {
            print("❌ Failed to setup chat: \(error)")
            errorMessage = "Kunde inte starta chatten. Försök igen."
            isLoading = false
        }
    }
    
    // MARK: - Send Message
    
    private func sendMessage() {
        let trimmedMessage = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedMessage.isEmpty, let convId = conversationId else { return }
        
        let messageToSend = trimmedMessage
        messageText = ""
        
        Task {
            do {
                try await chatService.sendMessage(conversationId: convId, message: messageToSend)
            } catch {
                print("❌ Failed to send message: \(error)")
                // Restore message on failure
                await MainActor.run {
                    messageText = messageToSend
                }
            }
        }
    }
}

// MARK: - Message Bubble View

private struct MessageBubbleView: View {
    let message: TrainerChatMessage
    let isFromCurrentUser: Bool
    let trainerAvatarUrl: String?
    
    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if isFromCurrentUser {
                Spacer(minLength: 60)
            } else {
                // Trainer avatar
                ProfileImage(url: trainerAvatarUrl, size: 28)
            }
            
            VStack(alignment: isFromCurrentUser ? .trailing : .leading, spacing: 4) {
                Text(message.message)
                    .font(.system(size: 15))
                    .foregroundColor(isFromCurrentUser ? .white : .primary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(
                        isFromCurrentUser
                            ? Color.primary
                            : Color(.systemGray6)
                    )
                    .cornerRadius(18)
                
                if let date = message.createdAt {
                    Text(formatMessageTime(date))
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 4)
                }
            }
            
            if !isFromCurrentUser {
                Spacer(minLength: 60)
            }
        }
    }
    
    private func formatMessageTime(_ date: Date) -> String {
        let calendar = Calendar.current
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "sv_SE")
        
        if calendar.isDateInToday(date) {
            formatter.dateFormat = "HH:mm"
        } else if calendar.isDateInYesterday(date) {
            formatter.dateFormat = "'Igår' HH:mm"
        } else {
            formatter.dateFormat = "d MMM HH:mm"
        }
        
        return formatter.string(from: date)
    }
}

#Preview {
    TrainerChatView(
        trainer: GolfTrainer(
            id: UUID(),
            userId: "test",
            name: "Josefine",
            description: "Test trainer",
            hourlyRate: 189,
            handicap: 0,
            latitude: 57.7,
            longitude: 11.9,
            avatarUrl: nil,
            createdAt: nil,
            city: "Göteborg",
            bio: nil,
            experienceYears: 6,
            clubAffiliation: nil,
            averageRating: 4.9,
            totalReviews: 5,
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
    )
}
