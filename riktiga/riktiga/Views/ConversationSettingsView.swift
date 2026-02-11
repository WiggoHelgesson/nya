import SwiftUI

struct ConversationSettingsView: View {
    let conversationId: UUID
    let otherUsername: String
    let otherAvatarUrl: String?
    let myAvatarUrl: String?
    
    @EnvironmentObject var authViewModel: AuthViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var isMuted = false
    @State private var isLoading = false
    @State private var showDeleteConfirmation = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
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
                
                Text("Meddelande")
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
            
            Divider()
            
            ScrollView {
                VStack(spacing: 24) {
                    // Profile section
                    VStack(spacing: 12) {
                        // Two profile pictures overlapping
                        HStack(spacing: -12) {
                            ProfileImage(url: myAvatarUrl, size: 56)
                                .overlay(Circle().stroke(Color(.systemBackground), lineWidth: 3))
                            
                            ProfileImage(url: otherAvatarUrl, size: 56)
                                .overlay(Circle().stroke(Color(.systemBackground), lineWidth: 3))
                        }
                        
                        Text("Du och \(otherUsername)")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.primary)
                        
                        Text("\(otherUsername) startade konversationen")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 32)
                    
                    // Mute toggle
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
                    
                    Spacer()
                        .frame(height: 40)
                    
                    // Delete button
                    Button {
                        showDeleteConfirmation = true
                    } label: {
                        Text("Radera konversation")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.red)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color.red.opacity(0.4), lineWidth: 1.5)
                            )
                    }
                    .padding(.horizontal, 16)
                }
            }
        }
        .background(Color(.systemGroupedBackground))
        .navigationBarHidden(true)
        .alert("Radera konversation", isPresented: $showDeleteConfirmation) {
            Button("Avbryt", role: .cancel) {}
            Button("Radera", role: .destructive) {
                deleteConversation()
            }
        } message: {
            Text("Är du säker på att du vill radera denna konversation? Alla meddelanden kommer tas bort.")
        }
    }
    
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
                    // Go back two levels (settings -> chat -> messages list)
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
