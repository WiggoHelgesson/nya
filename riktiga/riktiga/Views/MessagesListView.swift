import SwiftUI

struct MessagesListView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @Environment(\.dismiss) private var dismiss
    @StateObject private var dmService = DirectMessageService.shared
    
    @State private var isLoading = true
    @State private var showNewMessage = false
    
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
                Spacer()
            } else if dmService.conversations.isEmpty {
                emptyState
            } else {
                conversationList
            }
        }
        .background(Color(.systemBackground))
        .navigationBarHidden(true)
        .task {
            await loadConversations()
            dmService.startConversationListPolling()
        }
        .onDisappear {
            dmService.stopConversationListPolling()
        }
        .sheet(isPresented: $showNewMessage) {
            NewMessageView(onConversationCreated: { conversationId, otherUserId, otherUsername, otherAvatarUrl in
                showNewMessage = false
                // Reload conversations to include the new one
                Task { await loadConversations() }
            })
            .environmentObject(authViewModel)
        }
    }
    
    // MARK: - Conversation List
    
    private var conversationList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(dmService.conversations) { conversation in
                    NavigationLink(destination: DirectMessageView(
                        conversationId: conversation.id,
                        otherUserId: conversation.otherUserId ?? "",
                        otherUsername: conversation.otherUsername ?? "Användare",
                        otherAvatarUrl: conversation.otherAvatarUrl
                    ).environmentObject(authViewModel)) {
                        ConversationRow(conversation: conversation, currentUserId: authViewModel.currentUser?.id ?? "")
                    }
                    .buttonStyle(.plain)
                    
                    Divider()
                        .padding(.leading, 72)
                }
            }
        }
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
    
    private func loadConversations() async {
        isLoading = true
        _ = try? await dmService.fetchConversations()
        isLoading = false
    }
}

// MARK: - Conversation Row

struct ConversationRow: View {
    let conversation: DirectConversation
    let currentUserId: String
    
    var body: some View {
        HStack(spacing: 12) {
            // Avatar
            ProfileImage(url: conversation.otherAvatarUrl, size: 50)
            
            // Name + last message
            VStack(alignment: .leading, spacing: 3) {
                Text(conversation.otherUsername ?? "Användare")
                    .font(.system(size: 15, weight: hasUnread ? .bold : .semibold))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
                if let lastMessage = conversation.lastMessage, !lastMessage.isEmpty {
                    HStack(spacing: 0) {
                        // Show "Du: " prefix if the current user sent the last message
                        if conversation.lastMessageSenderId == currentUserId {
                            Text("Du: ")
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                        }
                        
                        Text(lastMessage)
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
