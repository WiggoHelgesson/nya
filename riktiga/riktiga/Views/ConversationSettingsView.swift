import SwiftUI

struct ConversationSettingsView: View {
    let conversationId: UUID
    let otherUsername: String
    let otherAvatarUrl: String?
    let myAvatarUrl: String?
    var isGroup: Bool = false
    var groupName: String? = nil
    
    @EnvironmentObject var authViewModel: AuthViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var isMuted = false
    @State private var isLoading = false
    @State private var showDeleteConfirmation = false
    @State private var participants: [ChatParticipant] = []
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView
            
            Divider()
            
            ScrollView {
                VStack(spacing: 20) {
                    // Profile section
                    profileSection
                        .padding(.top, 24)
                    
                    // Participants (for all chats)
                    if !participants.isEmpty {
                        participantsSection
                    }
                    
                    // Mute toggle
                    muteSection
                    
                    Spacer()
                        .frame(height: 20)
                    
                    // Delete button
                    deleteButton
                }
            }
        }
        .background(Color(.systemGroupedBackground))
        .navigationBarHidden(true)
        .task {
            await loadParticipants()
        }
        .alert("Radera konversation", isPresented: $showDeleteConfirmation) {
            Button("Avbryt", role: .cancel) {}
            Button("Radera", role: .destructive) {
                deleteConversation()
            }
        } message: {
            Text("Är du säker på att du vill radera denna konversation? Alla meddelanden kommer tas bort.")
        }
    }
    
    // MARK: - Header
    
    private var headerView: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .medium))
                    Text("Tillbaka")
                        .font(.system(size: 16))
                }
                .foregroundColor(.primary)
            }
            
            Spacer()
            
            Text("Detaljer")
                .font(.system(size: 17, weight: .bold))
            
            Spacer()
            
            // Invisible spacer for centering
            HStack(spacing: 4) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .medium))
                Text("Tillbaka")
                    .font(.system(size: 16))
            }
            .opacity(0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
    
    // MARK: - Profile Section
    
    private var profileSection: some View {
        VStack(spacing: 12) {
            if isGroup {
                // Group: show all participant avatars in a row
                groupAvatarRow
            } else {
                // 1-on-1: show both profile pictures overlapping
                HStack(spacing: -12) {
                    ProfileImage(url: myAvatarUrl, size: 56)
                        .overlay(Circle().stroke(Color(.systemBackground), lineWidth: 3))
                    
                    ProfileImage(url: otherAvatarUrl, size: 56)
                        .overlay(Circle().stroke(Color(.systemBackground), lineWidth: 3))
                }
            }
            
            Text(isGroup ? (groupName ?? otherUsername) : "Du och \(otherUsername)")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.primary)
            
            if isGroup {
                Text("\(participants.count) medlemmar")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }
        }
    }
    
    // MARK: - Group Avatar Row
    
    private var groupAvatarRow: some View {
        HStack(spacing: -8) {
            ForEach(participants.prefix(6)) { participant in
                ProfileImage(url: participant.avatarUrl, size: 48)
                    .overlay(Circle().stroke(Color(.systemBackground), lineWidth: 2.5))
            }
            
            if participants.count > 6 {
                Text("+\(participants.count - 6)")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 48, height: 48)
                    .background(Color(.systemGray3))
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color(.systemBackground), lineWidth: 2.5))
            }
        }
    }
    
    // MARK: - Participants Section
    
    private var participantsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Deltagare")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.secondary)
                .textCase(.uppercase)
                .padding(.horizontal, 20)
                .padding(.bottom, 8)
            
            VStack(spacing: 0) {
                ForEach(participants) { participant in
                    HStack(spacing: 12) {
                        ProfileImage(url: participant.avatarUrl, size: 38)
                        
                        VStack(alignment: .leading, spacing: 1) {
                            Text(participant.username)
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(.primary)
                            
                            if participant.isCurrentUser {
                                Text("Du")
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    
                    if participant.id != participants.last?.id {
                        Divider()
                            .padding(.leading, 66)
                    }
                }
            }
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .padding(.horizontal, 16)
        }
    }
    
    // MARK: - Mute Section
    
    private var muteSection: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Image(systemName: "bell.slash")
                    .font(.system(size: 20))
                    .foregroundColor(.primary)
                    .frame(width: 28)
                
                Text("Tysta konversation")
                    .font(.system(size: 16))
                    .foregroundColor(.primary)
                
                Spacer()
                
                Toggle("", isOn: $isMuted)
                    .labelsHidden()
                    .tint(.black)
                    .onChange(of: isMuted) { _, newValue in
                        toggleMute()
                    }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .padding(.horizontal, 16)
    }
    
    // MARK: - Delete Button
    
    private var deleteButton: some View {
        Button {
            showDeleteConfirmation = true
        } label: {
            Text("Radera konversation")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.red)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color(.systemBackground))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.red.opacity(0.3), lineWidth: 1)
                )
        }
        .padding(.horizontal, 16)
    }
    
    // MARK: - Data Loading
    
    private func loadParticipants() async {
        guard let currentUserId = authViewModel.currentUser?.id else { return }
        
        do {
            let dmService = DirectMessageService.shared
            
            // Get participant user IDs
            let userIds = try await dmService.fetchParticipantIds(conversationId: conversationId)
            guard !userIds.isEmpty else { return }
            
            // Fetch profiles
            let profiles = try await dmService.fetchUserProfiles(userIds: userIds)
            
            let result = profiles.map { profile in
                ChatParticipant(
                    id: profile.id,
                    username: profile.username ?? "Användare",
                    avatarUrl: profile.avatar_url,
                    isCurrentUser: profile.id == currentUserId
                )
            }
            .sorted { a, b in
                if a.isCurrentUser { return true }
                if b.isCurrentUser { return false }
                return a.username < b.username
            }
            
            await MainActor.run {
                participants = result
            }
        } catch {
            print("❌ Failed to load participants: \(error)")
        }
    }
    
    // MARK: - Actions
    
    private func toggleMute() {
        Task {
            do {
                let newStatus = try await DirectMessageService.shared.toggleMute(conversationId: conversationId)
                await MainActor.run {
                    isMuted = newStatus
                }
            } catch {
                print("❌ Failed to toggle mute: \(error)")
            }
        }
    }
    
    private func deleteConversation() {
        Task {
            do {
                try await DirectMessageService.shared.deleteConversation(conversationId: conversationId)
                await MainActor.run {
                    dismiss()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        dismiss()
                    }
                }
            } catch {
                print("❌ Failed to delete conversation: \(error)")
            }
        }
    }
}

// MARK: - Chat Participant Model

struct ChatParticipant: Identifiable {
    let id: String
    let username: String
    let avatarUrl: String?
    let isCurrentUser: Bool
}
