import SwiftUI

struct DirectMessageView: View {
    let conversationId: UUID
    let otherUserId: String
    let otherUsername: String
    let otherAvatarUrl: String?
    
    @EnvironmentObject var authViewModel: AuthViewModel
    @Environment(\.dismiss) private var dismiss
    @StateObject private var dmService = DirectMessageService.shared
    
    @State private var messageText = ""
    @State private var currentUserId: UUID?
    @State private var isLoading = true
    @State private var showSettings = false
    @FocusState private var isInputFocused: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            chatHeader
            
            Divider()
            
            // Messages
            if isLoading {
                Spacer()
                ProgressView()
                    .scaleEffect(1.2)
                Spacer()
            } else {
                messagesScrollView
            }
            
            // Input bar
            chatInputBar
        }
        .background(Color(.systemBackground))
        .navigationBarHidden(true)
        .task {
            await setupChat()
        }
        .onDisappear {
            dmService.stopPolling()
            // Notify to refresh unread count
            NotificationCenter.default.post(name: NSNotification.Name("RefreshUnreadMessages"), object: nil)
        }
        .navigationDestination(isPresented: $showSettings) {
            ConversationSettingsView(
                conversationId: conversationId,
                otherUsername: otherUsername,
                otherAvatarUrl: otherAvatarUrl,
                myAvatarUrl: authViewModel.currentUser?.avatarUrl
            )
            .environmentObject(authViewModel)
        }
    }
    
    // MARK: - Header
    
    private var chatHeader: some View {
        HStack(spacing: 12) {
            Button {
                dismiss()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .medium))
                    Text("Meddelanden")
                        .font(.system(size: 15))
                }
                .foregroundColor(.primary)
            }
            
            Spacer()
            
            // Center: Name
            VStack(spacing: 1) {
                Text(otherUsername)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.primary)
                
                Text("Online")
                    .font(.system(size: 11))
                    .foregroundColor(.green)
            }
            
            Spacer()
            
            // Settings
            Button {
                showSettings = true
            } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 20, weight: .regular))
                    .foregroundColor(.primary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color(.systemBackground))
    }
    
    // MARK: - Messages Scroll View
    
    private var messagesScrollView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 4) {
                    // Empty state
                    if dmService.messages.isEmpty {
                        emptyStateView
                    }
                    
                    ForEach(Array(dmService.messages.enumerated()), id: \.element.id) { index, message in
                        let isFromMe = message.senderId == currentUserId
                        let showDateHeader = shouldShowDateHeader(for: index)
                        
                        if showDateHeader {
                            DateSeparator(date: message.createdAt ?? Date())
                                .padding(.vertical, 8)
                        }
                        
                        MessageBubble(
                            message: message,
                            isFromMe: isFromMe,
                            otherAvatarUrl: otherAvatarUrl,
                            showAvatar: !isFromMe && isLastInGroup(at: index)
                        )
                        .id(message.id)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 16)
            }
            .onChange(of: dmService.messages.count) { _, _ in
                if let lastMessage = dmService.messages.last {
                    withAnimation(.easeOut(duration: 0.2)) {
                        proxy.scrollTo(lastMessage.id, anchor: .bottom)
                    }
                }
            }
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    if let lastMessage = dmService.messages.last {
                        proxy.scrollTo(lastMessage.id, anchor: .bottom)
                    }
                }
            }
        }
    }
    
    // MARK: - Empty State
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Spacer()
                .frame(height: 80)
            
            ProfileImage(url: otherAvatarUrl, size: 64)
            
            Text(otherUsername)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.primary)
            
            Text("Starta en konversation med \(otherUsername)")
                .font(.system(size: 14))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
    }
    
    // MARK: - Input Bar
    
    private var chatInputBar: some View {
        VStack(spacing: 0) {
            Divider()
            
            HStack(spacing: 12) {
                HStack {
                    TextField("Skicka ett meddelande", text: $messageText, axis: .vertical)
                        .font(.system(size: 15))
                        .lineLimit(1...5)
                        .focused($isInputFocused)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                }
                .background(Color(.systemGray6))
                .cornerRadius(20)
                
                // Send button
                if !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Button {
                        sendMessage()
                    } label: {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 32))
                            .foregroundColor(.black)
                    }
                    .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(.systemBackground))
            .animation(.easeInOut(duration: 0.15), value: messageText.isEmpty)
        }
    }
    
    // MARK: - Helpers
    
    private func setupChat() async {
        currentUserId = await dmService.getCurrentUserId()
        dmService.startPolling(conversationId: conversationId)
        isLoading = false
    }
    
    private func sendMessage() {
        let text = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        messageText = ""
        
        Task {
            do {
                try await dmService.sendMessage(conversationId: conversationId, message: text)
            } catch {
                print("❌ Failed to send message: \(error)")
            }
        }
    }
    
    private func shouldShowDateHeader(for index: Int) -> Bool {
        guard index > 0 else { return true }
        let currentDate = dmService.messages[index].createdAt ?? Date()
        let previousDate = dmService.messages[index - 1].createdAt ?? Date()
        return !Calendar.current.isDate(currentDate, inSameDayAs: previousDate)
    }
    
    private func isLastInGroup(at index: Int) -> Bool {
        guard index < dmService.messages.count - 1 else { return true }
        return dmService.messages[index].senderId != dmService.messages[index + 1].senderId
    }
}

// MARK: - Message Bubble

struct MessageBubble: View {
    let message: DirectMessage
    let isFromMe: Bool
    let otherAvatarUrl: String?
    let showAvatar: Bool
    
    var body: some View {
        HStack(alignment: .bottom, spacing: 6) {
            if isFromMe {
                Spacer(minLength: 60)
            } else {
                if showAvatar {
                    ProfileImage(url: otherAvatarUrl, size: 28)
                } else {
                    Spacer()
                        .frame(width: 28)
                }
            }
            
            VStack(alignment: isFromMe ? .trailing : .leading, spacing: 2) {
                Text(message.message)
                    .font(.system(size: 15))
                    .foregroundColor(isFromMe ? .white : .primary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 9)
                    .background(isFromMe ? Color.black : Color(.systemGray6))
                    .cornerRadius(18)
                
                // Timestamp + read status
                HStack(spacing: 3) {
                    if let date = message.createdAt {
                        Text(formatMessageTime(date))
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                    
                    if isFromMe {
                        Image(systemName: message.isRead ? "checkmark.circle.fill" : "checkmark")
                            .font(.system(size: 10))
                            .foregroundColor(message.isRead ? .green : .secondary)
                    }
                }
                .padding(.horizontal, 4)
            }
            
            if !isFromMe {
                Spacer(minLength: 60)
            }
        }
        .padding(.vertical, 1)
    }
    
    private func formatMessageTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}

// MARK: - Date Separator

struct DateSeparator: View {
    let date: Date
    
    var body: some View {
        Text(formatDate(date))
            .font(.system(size: 12, weight: .semibold))
            .foregroundColor(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 5)
            .background(Color.black.opacity(0.6))
            .cornerRadius(12)
    }
    
    private func formatDate(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return "Idag"
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
