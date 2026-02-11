import SwiftUI

struct NewMessageView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @Environment(\.dismiss) private var dismiss
    
    var onConversationCreated: (UUID, String, String, String?) -> Void
    
    @State private var searchText = ""
    @State private var followers: [UserSearchResult] = []
    @State private var filteredFollowers: [UserSearchResult] = []
    @State private var selectedUserId: String? = nil
    @State private var isLoading = true
    @State private var showGuidelines = false
    @State private var selectedUser: UserSearchResult? = nil
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search bar
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 16))
                        .foregroundColor(.gray)
                    
                    TextField("Sök bland dina följare", text: $searchText)
                        .font(.system(size: 16))
                        .onChange(of: searchText) { _, newValue in
                            filterFollowers(query: newValue)
                        }
                    
                    if !searchText.isEmpty {
                        Button {
                            searchText = ""
                            filteredFollowers = followers
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.gray)
                        }
                    }
                }
                .padding(12)
                .background(Color(.systemGray6))
                .cornerRadius(10)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                
                Divider()
                
                // Content
                if isLoading {
                    Spacer()
                    ProgressView()
                    Spacer()
                } else if filteredFollowers.isEmpty {
                    Spacer()
                    VStack(spacing: 8) {
                        Image(systemName: "person.2.slash")
                            .font(.system(size: 36))
                            .foregroundColor(.secondary)
                        Text(searchText.isEmpty ? "Inga följare än" : "Inga resultat")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                } else {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(filteredFollowers) { user in
                                Button {
                                    selectedUserId = selectedUserId == user.id ? nil : user.id
                                    selectedUser = selectedUserId == user.id ? user : nil
                                } label: {
                                    HStack(spacing: 12) {
                                        ProfileImage(url: user.avatarUrl, size: 44)
                                        
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(user.name)
                                                .font(.system(size: 15, weight: .medium))
                                                .foregroundColor(.primary)
                                        }
                                        
                                        Spacer()
                                        
                                        // Checkbox
                                        ZStack {
                                            RoundedRectangle(cornerRadius: 4)
                                                .stroke(selectedUserId == user.id ? Color.black : Color(.systemGray4), lineWidth: 1.5)
                                                .frame(width: 22, height: 22)
                                            
                                            if selectedUserId == user.id {
                                                RoundedRectangle(cornerRadius: 4)
                                                    .fill(Color.black)
                                                    .frame(width: 22, height: 22)
                                                    .overlay(
                                                        Image(systemName: "checkmark")
                                                            .font(.system(size: 12, weight: .bold))
                                                            .foregroundColor(.white)
                                                    )
                                            }
                                        }
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 10)
                                }
                                .buttonStyle(.plain)
                                
                                Divider()
                                    .padding(.leading, 72)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Nytt meddelande")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Stäng") {
                        dismiss()
                    }
                    .foregroundColor(.primary)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Skapa") {
                        if selectedUser != nil {
                            showGuidelines = true
                        }
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(selectedUserId != nil ? .primary : .gray)
                    .disabled(selectedUserId == nil)
                }
            }
            .task {
                await loadFollowers()
            }
        }
        .overlay {
            if showGuidelines, let user = selectedUser {
                guidelinesOverlay(for: user)
            }
        }
    }
    
    // MARK: - Guidelines Overlay
    
    private func guidelinesOverlay(for user: UserSearchResult) -> some View {
        ZStack {
            // Background dim
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        showGuidelines = false
                    }
                }
            
            // Card
            VStack(spacing: 0) {
                Spacer()
                
                VStack(spacing: 20) {
                    // Profile pictures with chat icon
                    HStack(spacing: 16) {
                        ProfileImage(url: authViewModel.currentUser?.avatarUrl, size: 52)
                        
                        Image(systemName: "bubble.left.and.bubble.right.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.secondary)
                        
                        ProfileImage(url: user.avatarUrl, size: 52)
                    }
                    .padding(.top, 8)
                    
                    Text("Skicka \(user.name) ett meddelande")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.center)
                    
                    Text("Följ våra **riktlinjer** och var respektfull när du skickar meddelanden. Låt oss hålla Up&Down positivt!")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 12)
                    
                    // OK button
                    Button {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            showGuidelines = false
                        }
                        createConversation(with: user)
                    } label: {
                        Text("OK")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.black)
                            .cornerRadius(28)
                    }
                }
                .padding(24)
                .background(Color(.systemBackground))
                .cornerRadius(20)
                .shadow(color: .black.opacity(0.15), radius: 20, x: 0, y: -5)
                .padding(.horizontal, 16)
                .padding(.bottom, 20)
            }
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: showGuidelines)
    }
    
    // MARK: - Helpers
    
    private func loadFollowers() async {
        guard let userId = authViewModel.currentUser?.id else {
            isLoading = false
            return
        }
        
        do {
            let results = try await SocialService.shared.getFollowerUsers(userId: userId)
            await MainActor.run {
                followers = results
                filteredFollowers = results
                isLoading = false
            }
        } catch {
            print("❌ Failed to load followers: \(error)")
            isLoading = false
        }
    }
    
    private func filterFollowers(query: String) {
        if query.isEmpty {
            filteredFollowers = followers
        } else {
            filteredFollowers = followers.filter {
                $0.name.localizedCaseInsensitiveContains(query)
            }
        }
    }
    
    private func createConversation(with user: UserSearchResult) {
        Task {
            do {
                let conversationId = try await DirectMessageService.shared.getOrCreateConversation(withUserId: user.id)
                await MainActor.run {
                    onConversationCreated(conversationId, user.id, user.name, user.avatarUrl)
                }
            } catch {
                print("❌ Failed to create conversation: \(error)")
            }
        }
    }
}
