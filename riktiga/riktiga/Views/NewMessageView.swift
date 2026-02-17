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
    
    // Group mode
    @State private var isGroupMode = false
    @State private var selectedGroupUsers: Set<String> = []
    @State private var selectedGroupUsersList: [UserSearchResult] = []
    @State private var groupName = ""
    @State private var showGroupGuidelines = false
    @State private var isCreatingGroup = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Group / Direct toggle
                if !isGroupMode {
                    // "Skapa grupp" button
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isGroupMode = true
                            selectedUserId = nil
                            selectedUser = nil
                        }
                    } label: {
                        HStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(Color(.systemGray6))
                                    .frame(width: 44, height: 44)
                                Image(systemName: "person.3.fill")
                                    .font(.system(size: 16))
                                    .foregroundColor(.primary)
                            }
                            
                            Text("Skapa grupp")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(.primary)
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                    }
                    .buttonStyle(.plain)
                    
                    Divider()
                }
                
                // Group name field (group mode only)
                if isGroupMode {
                    VStack(spacing: 0) {
                        HStack(spacing: 10) {
                            Image(systemName: "pencil")
                                .font(.system(size: 16))
                                .foregroundColor(.gray)
                            
                            TextField("Gruppnamn", text: $groupName)
                                .font(.system(size: 16))
                        }
                        .padding(12)
                        .background(Color(.systemGray6))
                        .cornerRadius(10)
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                        .padding(.bottom, 6)
                        
                        // Selected members chips
                        if !selectedGroupUsersList.isEmpty {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(selectedGroupUsersList) { user in
                                        HStack(spacing: 6) {
                                            ProfileImage(url: user.avatarUrl, size: 24)
                                            Text(user.name)
                                                .font(.system(size: 13, weight: .medium))
                                                .foregroundColor(.primary)
                                            Button {
                                                toggleGroupUser(user)
                                            } label: {
                                                Image(systemName: "xmark")
                                                    .font(.system(size: 10, weight: .bold))
                                                    .foregroundColor(.secondary)
                                            }
                                        }
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 6)
                                        .background(Color(.systemGray6))
                                        .cornerRadius(16)
                                    }
                                }
                                .padding(.horizontal, 16)
                                .padding(.bottom, 6)
                            }
                        }
                    }
                }
                
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
                .padding(.vertical, isGroupMode ? 6 : 12)
                
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
                                    if isGroupMode {
                                        toggleGroupUser(user)
                                    } else {
                                        selectedUserId = selectedUserId == user.id ? nil : user.id
                                        selectedUser = selectedUserId == user.id ? user : nil
                                    }
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
                                            let isSelected = isGroupMode ? selectedGroupUsers.contains(user.id) : selectedUserId == user.id
                                            
                                            RoundedRectangle(cornerRadius: 4)
                                                .stroke(isSelected ? Color.black : Color(.systemGray4), lineWidth: 1.5)
                                                .frame(width: 22, height: 22)
                                            
                                            if isSelected {
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
            .navigationTitle(isGroupMode ? "Skapa grupp" : "Nytt meddelande")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(isGroupMode ? "Tillbaka" : "Stäng") {
                        if isGroupMode {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                isGroupMode = false
                                selectedGroupUsers.removeAll()
                                selectedGroupUsersList.removeAll()
                                groupName = ""
                            }
                        } else {
                            dismiss()
                        }
                    }
                    .foregroundColor(.primary)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Skapa") {
                        if isGroupMode {
                            if selectedGroupUsers.count >= 2 {
                                showGroupGuidelines = true
                            }
                        } else if selectedUser != nil {
                            showGuidelines = true
                        }
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(createButtonEnabled ? .primary : .gray)
                    .disabled(!createButtonEnabled)
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
            
            if showGroupGuidelines {
                groupGuidelinesOverlay
            }
        }
    }
    
    private var createButtonEnabled: Bool {
        if isGroupMode {
            return selectedGroupUsers.count >= 2 && !groupName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        return selectedUserId != nil
    }
    
    // MARK: - Group User Toggle
    
    private func toggleGroupUser(_ user: UserSearchResult) {
        if selectedGroupUsers.contains(user.id) {
            selectedGroupUsers.remove(user.id)
            selectedGroupUsersList.removeAll { $0.id == user.id }
        } else {
            selectedGroupUsers.insert(user.id)
            selectedGroupUsersList.append(user)
        }
    }
    
    // MARK: - Guidelines Overlay (1-on-1)
    
    private func guidelinesOverlay(for user: UserSearchResult) -> some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        showGuidelines = false
                    }
                }
            
            VStack(spacing: 0) {
                Spacer()
                
                VStack(spacing: 20) {
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
    
    // MARK: - Group Guidelines Overlay
    
    private var groupGuidelinesOverlay: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        showGroupGuidelines = false
                    }
                }
            
            VStack(spacing: 0) {
                Spacer()
                
                VStack(spacing: 20) {
                    // Overlapping group avatars
                    HStack(spacing: -12) {
                        ProfileImage(url: authViewModel.currentUser?.avatarUrl, size: 44)
                            .zIndex(3)
                        
                        ForEach(Array(selectedGroupUsersList.prefix(3).enumerated()), id: \.element.id) { index, user in
                            ProfileImage(url: user.avatarUrl, size: 44)
                                .zIndex(Double(2 - index))
                        }
                        
                        if selectedGroupUsersList.count > 3 {
                            ZStack {
                                Circle()
                                    .fill(Color(.systemGray5))
                                    .frame(width: 44, height: 44)
                                Text("+\(selectedGroupUsersList.count - 3)")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(.primary)
                            }
                        }
                    }
                    .padding(.top, 8)
                    
                    Text("Skapa grupp \"\(groupName.trimmingCharacters(in: .whitespacesAndNewlines))\"")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.center)
                    
                    Text("\(selectedGroupUsers.count + 1) medlemmar")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                    
                    Text("Följ våra **riktlinjer** och var respektfull i gruppkonversationer. Låt oss hålla Up&Down positivt!")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 12)
                    
                    Button {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            showGroupGuidelines = false
                        }
                        createGroupConversation()
                    } label: {
                        HStack(spacing: 8) {
                            if isCreatingGroup {
                                ProgressView()
                                    .tint(.white)
                            }
                            Text("Skapa grupp")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.white)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.black)
                        .cornerRadius(28)
                    }
                    .disabled(isCreatingGroup)
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
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: showGroupGuidelines)
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
    
    private func createGroupConversation() {
        let name = groupName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, selectedGroupUsers.count >= 2 else { return }
        
        isCreatingGroup = true
        
        Task {
            do {
                let conversationId = try await DirectMessageService.shared.createGroupConversation(
                    withUserIds: Array(selectedGroupUsers),
                    groupName: name
                )
                await MainActor.run {
                    isCreatingGroup = false
                    let participantNames = selectedGroupUsersList.map { $0.name }.joined(separator: ", ")
                    onConversationCreated(conversationId, "", name, nil)
                }
            } catch {
                print("❌ Failed to create group: \(error)")
                await MainActor.run { isCreatingGroup = false }
            }
        }
    }
}
