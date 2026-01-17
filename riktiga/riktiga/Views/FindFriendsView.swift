import SwiftUI
import Combine
import Contacts

struct FindFriendsView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @Environment(\.dismiss) private var dismiss
    @StateObject private var findFriendsViewModel = FindFriendsViewModel()
    @State private var searchText = ""
    @State private var recommendedUsers: [UserSearchResult] = []
    @State private var isLoadingRecommended = false
    @State private var recommendedFollowingStatus: [String: Bool] = [:]
    @State private var searchDebounceTask: Task<Void, Never>?
    @State private var selectedTab: FindFriendsTab = .suggested
    @State private var contactsPermissionGranted = false
    @State private var showContactsPermissionAlert = false
    @State private var contactsOnApp: [UserSearchResult] = []
    @State private var contactsToInvite: [ContactToInvite] = []
    @State private var isLoadingContacts = false
    @State private var contactsFollowingStatus: [String: Bool] = [:]
    
    enum FindFriendsTab {
        case suggested
        case contacts
    }
    
    struct ContactToInvite: Identifiable {
        let id = UUID()
        let name: String
        let initials: String
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Main tab - Vänner (always selected, single tab)
            HStack {
                Text("Vänner")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.black)
                
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 4)
            
            // Black underline
            HStack {
                Rectangle()
                    .fill(Color.black)
                    .frame(width: 60, height: 2)
                Spacer()
            }
            .padding(.horizontal, 16)
            
            // Search Bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.gray)
                
                TextField("Sök efter personer...", text: $searchText)
                    .textFieldStyle(PlainTextFieldStyle())
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .onChange(of: searchText) { _, newValue in
                        searchDebounceTask?.cancel()
                        
                        if newValue.count >= 2 {
                            searchDebounceTask = Task {
                                try? await Task.sleep(nanoseconds: 300_000_000)
                                if !Task.isCancelled {
                                    await MainActor.run {
                                        performSearch()
                                    }
                                }
                            }
                        } else {
                            findFriendsViewModel.searchResults = []
                        }
                    }
                
                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                        findFriendsViewModel.searchResults = []
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
            .padding(.top, 12)
            
            // Sub-tabs: Gemensamma & Kontakter
            HStack(spacing: 0) {
                // Gemensamma tab
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedTab = .suggested
                    }
                } label: {
                    VStack(spacing: 8) {
                        Image(systemName: "person.2")
                            .font(.system(size: 20))
                        Text("Gemensamma")
                            .font(.system(size: 11))
                    }
                    .foregroundColor(selectedTab == .suggested ? .black : .gray)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        VStack {
                            Spacer()
                            if selectedTab == .suggested {
                                Rectangle()
                                    .fill(Color.black)
                                    .frame(height: 2)
                            }
                        }
                    )
                }
                
                // Kontakter tab
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedTab = .contacts
                    }
                } label: {
                    VStack(spacing: 8) {
                        Image(systemName: "person.crop.rectangle.stack")
                            .font(.system(size: 20))
                        Text("Kontakter")
                            .font(.system(size: 11))
                    }
                    .foregroundColor(selectedTab == .contacts ? .black : .gray)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        VStack {
                            Spacer()
                            if selectedTab == .contacts {
                                Rectangle()
                                    .fill(Color.black)
                                    .frame(height: 2)
                            }
                        }
                    )
                }
            }
            .padding(.top, 8)
            
            Divider()
            
            // Content based on search or selected tab
            if !searchText.isEmpty {
                searchResultsView
            } else {
                switch selectedTab {
                case .suggested:
                    suggestedFriendsView
                case .contacts:
                    contactsView
                }
            }
            
            Spacer()
            
            // Bottom invite section
            VStack(spacing: 12) {
                Divider()
                
                Text("Bjud in vänner som inte är med ännu")
                    .font(.system(size: 14))
                    .foregroundColor(.gray)
                
                Button {
                    shareApp()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "square.and.arrow.up")
                        Text("Bjud in")
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.black)
                    .cornerRadius(25)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }
        }
        .navigationTitle("Sök")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    dismiss()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .semibold))
                        Text("Tillbaka")
                            .font(.system(size: 17))
                    }
                    .foregroundColor(.black)
                }
            }
        }
        .task {
            await loadFollowingIds()
            loadRecommendedUsers()
            checkContactsPermission()
        }
        .onAppear {
            NavigationDepthTracker.shared.pushView()
        }
        .onDisappear {
            NavigationDepthTracker.shared.popView()
        }
    }
    
    // MARK: - Search Results View
    private var searchResultsView: some View {
        Group {
            if findFriendsViewModel.isLoading && findFriendsViewModel.searchResults.isEmpty {
                VStack {
                    Spacer()
                    ProgressView("Söker...")
                        .foregroundColor(.gray)
                    Spacer()
                }
            } else if findFriendsViewModel.searchResults.isEmpty && !findFriendsViewModel.isLoading {
                VStack {
                    Spacer()
                    VStack(spacing: 16) {
                        Image(systemName: "person.crop.circle.badge.questionmark")
                            .font(.system(size: 48))
                            .foregroundColor(.gray)
                        Text("Inga användare hittades")
                            .font(.headline)
                        Text("Prova att söka efter ett annat namn")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    Spacer()
                }
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(findFriendsViewModel.searchResults) { user in
                            NavigationLink(destination: UserProfileView(userId: user.id)) {
                                FriendSearchRow(
                                    user: user,
                                    isFollowing: findFriendsViewModel.followingStatus[user.id] ?? false,
                                    mutualInfo: "Du har gemensamma vänner",
                                    onFollowToggle: {
                                        toggleFollow(userId: user.id)
                                    }
                                )
                            }
                            .buttonStyle(.plain)
                            
                            Divider()
                                .padding(.leading, 78)
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Suggested Friends View
    private var suggestedFriendsView: some View {
        Group {
            if isLoadingRecommended && recommendedUsers.isEmpty {
                VStack {
                    Spacer()
                    ProgressView("Laddar förslag...")
                        .foregroundColor(.gray)
                    Spacer()
                }
            } else if recommendedUsers.isEmpty {
                VStack {
                    Spacer()
                    VStack(spacing: 16) {
                        Image(systemName: "person.2")
                            .font(.system(size: 48))
                            .foregroundColor(.gray)
                        Text("Inga förslag just nu")
                            .font(.headline)
                        Text("Följ fler personer för att få förslag")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    Spacer()
                }
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        // Header
                        HStack {
                            Text("\(recommendedUsers.count) PERSONER ATT FÖLJA")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.gray)
                            
                            Spacer()
                            
                            Button {
                                followAllRecommended()
                            } label: {
                                Text("Följ alla")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(.black)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 15)
                                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                                    )
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(Color(.systemGray6))
                        
                        ForEach(recommendedUsers) { user in
                            NavigationLink(destination: UserProfileView(userId: user.id)) {
                                FriendSearchRow(
                                    user: user,
                                    isFollowing: recommendedFollowingStatus[user.id] ?? false,
                                    mutualInfo: "Du har gemensamma vänner",
                                    onFollowToggle: {
                                        toggleRecommendedFollow(userId: user.id)
                                    }
                                )
                            }
                            .buttonStyle(.plain)
                            
                            Divider()
                                .padding(.leading, 78)
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Contacts View
    private var contactsView: some View {
        Group {
            if !contactsPermissionGranted {
                // Request contacts permission
                VStack(spacing: 24) {
                    Spacer()
                    
                    Image(systemName: "person.crop.rectangle.stack")
                        .font(.system(size: 60))
                        .foregroundColor(.black)
                    
                    Text("Anslut kontakter")
                        .font(.system(size: 22, weight: .bold))
                    
                    Text("Dina vänner finns här. Se vad de gör genom att ansluta dina telefonkontakter.")
                        .font(.system(size: 15))
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                    
                    Button {
                        requestContactsPermission()
                    } label: {
                        Text("Anslut säkert")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.black)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 20)
                                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                            )
                    }
                    
                    Spacer()
                }
            } else if isLoadingContacts {
                VStack {
                    Spacer()
                    ProgressView("Söker efter vänner...")
                        .foregroundColor(.gray)
                    Spacer()
                }
            } else {
                // Show contacts that are on the app
                ScrollView {
                    LazyVStack(spacing: 0) {
                        // Contacts on app section
                        if !contactsOnApp.isEmpty {
                            HStack {
                                Text("\(contactsOnApp.count) KONTAKTER PÅ APPEN")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.gray)
                                
                                Spacer()
                                
                                Button {
                                    followAllContacts()
                                } label: {
                                    Text("Följ alla")
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundColor(.black)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 15)
                                                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                                        )
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(Color(.systemGray6))
                            
                            ForEach(contactsOnApp) { user in
                                NavigationLink(destination: UserProfileView(userId: user.id)) {
                                    FriendSearchRow(
                                        user: user,
                                        isFollowing: contactsFollowingStatus[user.id] ?? false,
                                        mutualInfo: nil,
                                        onFollowToggle: {
                                            toggleContactFollow(userId: user.id)
                                        }
                                    )
                                }
                                .buttonStyle(.plain)
                                
                                Divider()
                                    .padding(.leading, 78)
                            }
                        }
                        
                        // Contacts to invite section
                        if !contactsToInvite.isEmpty {
                            HStack {
                                Text("BJUD IN KONTAKTER")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.gray)
                                
                                Spacer()
                                
                                Button {
                                    shareApp()
                                } label: {
                                    Text("Bjud in alla")
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundColor(.black)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 15)
                                                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                                        )
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(Color(.systemGray6))
                            
                            ForEach(contactsToInvite) { contact in
                                HStack(spacing: 12) {
                                    // Initials circle
                                    Circle()
                                        .fill(Color(.systemGray4))
                                        .frame(width: 50, height: 50)
                                        .overlay(
                                            Text(contact.initials)
                                                .font(.system(size: 16, weight: .semibold))
                                                .foregroundColor(.gray)
                                        )
                                    
                                    Text(contact.name)
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(.black)
                                    
                                    Spacer()
                                    
                                    Button {
                                        inviteContact(name: contact.name)
                                    } label: {
                                        Text("Bjud in")
                                            .font(.system(size: 14, weight: .medium))
                                            .foregroundColor(.black)
                                            .frame(width: 70, height: 32)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 16)
                                                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                                            )
                                    }
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                                
                                Divider()
                                    .padding(.leading, 78)
                            }
                        }
                        
                        // Empty state
                        if contactsOnApp.isEmpty && contactsToInvite.isEmpty {
                            VStack(spacing: 16) {
                                Image(systemName: "person.2.slash")
                                    .font(.system(size: 48))
                                    .foregroundColor(.gray)
                                Text("Inga kontakter hittades")
                                    .font(.headline)
                                Text("Lägg till kontakter i din telefon för att hitta vänner")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                                    .multilineTextAlignment(.center)
                            }
                            .padding(.top, 60)
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Helper Functions
    private func checkContactsPermission() {
        let status = CNContactStore.authorizationStatus(for: .contacts)
        contactsPermissionGranted = (status == .authorized)
        
        // If already granted, load contacts
        if contactsPermissionGranted {
            loadContactsAndMatch()
        }
    }
    
    private func requestContactsPermission() {
        let store = CNContactStore()
        store.requestAccess(for: .contacts) { granted, error in
            DispatchQueue.main.async {
                contactsPermissionGranted = granted
                if granted {
                    print("✅ Contacts permission granted")
                    loadContactsAndMatch()
                } else if let error = error {
                    print("❌ Contacts permission denied: \(error)")
                }
            }
        }
    }
    
    private func loadContactsAndMatch() {
        isLoadingContacts = true
        
        Task {
            do {
                // Fetch all contacts
                let store = CNContactStore()
                let keysToFetch: [CNKeyDescriptor] = [
                    CNContactGivenNameKey as CNKeyDescriptor,
                    CNContactFamilyNameKey as CNKeyDescriptor,
                    CNContactEmailAddressesKey as CNKeyDescriptor,
                    CNContactPhoneNumbersKey as CNKeyDescriptor
                ]
                
                let request = CNContactFetchRequest(keysToFetch: keysToFetch)
                var contactNames: [String] = []
                var contactsForInvite: [ContactToInvite] = []
                
                try store.enumerateContacts(with: request) { contact, _ in
                    let fullName = "\(contact.givenName) \(contact.familyName)".trimmingCharacters(in: .whitespaces)
                    if !fullName.isEmpty {
                        contactNames.append(fullName)
                        
                        // Create initials
                        let initials = String(contact.givenName.prefix(1) + contact.familyName.prefix(1)).uppercased()
                        contactsForInvite.append(ContactToInvite(name: fullName, initials: initials.isEmpty ? "?" : initials))
                    }
                }
                
                print("📇 Found \(contactNames.count) contacts")
                
                // Search for matching users in the app
                let matchedUsers = try await SocialService.shared.findUsersByNames(names: contactNames)
                print("✅ Found \(matchedUsers.count) contacts on app")
                
                // Update follow status for matched users
                var followStatus: [String: Bool] = [:]
                for user in matchedUsers {
                    followStatus[user.id] = findFriendsViewModel.followingIds.contains(user.id)
                }
                
                // Filter out matched users from invite list
                let matchedNames = Set(matchedUsers.map { $0.name.lowercased() })
                let filteredInvites = contactsForInvite.filter { !matchedNames.contains($0.name.lowercased()) }
                
                await MainActor.run {
                    self.contactsOnApp = matchedUsers
                    self.contactsToInvite = Array(filteredInvites.prefix(20)) // Limit to 20
                    self.contactsFollowingStatus = followStatus
                    self.isLoadingContacts = false
                }
            } catch {
                print("❌ Error loading contacts: \(error)")
                await MainActor.run {
                    self.isLoadingContacts = false
                }
            }
        }
    }
    
    private func shareApp() {
        // Open SMS app directly with pre-filled message
        let appStoreLink = "https://apps.apple.com/app/upanddown/id123456789" // Replace with real App Store ID
        let message = "Gå med mig i Up&Down för att tracka dina gympass, kalorier & följa alla mina pass! 💪\n\n\(appStoreLink)"
        
        // URL encode the message
        if let encodedMessage = message.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
           let smsURL = URL(string: "sms:&body=\(encodedMessage)") {
            UIApplication.shared.open(smsURL)
        }
    }
    
    private func inviteContact(name: String) {
        // Open SMS app directly with pre-filled message
        let appStoreLink = "https://apps.apple.com/app/upanddown/id123456789" // Replace with real App Store ID
        let message = "Gå med mig i Up&Down för att tracka dina gympass, kalorier & följa alla mina pass! 💪\n\n\(appStoreLink)"
        
        // URL encode the message
        if let encodedMessage = message.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
           let smsURL = URL(string: "sms:&body=\(encodedMessage)") {
            UIApplication.shared.open(smsURL)
        }
    }
    
    private func followAllRecommended() {
        for user in recommendedUsers {
            if !(recommendedFollowingStatus[user.id] ?? false) {
                toggleRecommendedFollow(userId: user.id)
            }
        }
    }
    
    private func followAllContacts() {
        for user in contactsOnApp {
            if !(contactsFollowingStatus[user.id] ?? false) {
                toggleContactFollow(userId: user.id)
            }
        }
    }
    
    private func toggleContactFollow(userId: String) {
        guard let currentUserId = authViewModel.currentUser?.id else { return }
        
        let isCurrentlyFollowing = contactsFollowingStatus[userId] ?? false
        
        contactsFollowingStatus[userId] = !isCurrentlyFollowing
        findFriendsViewModel.followingStatus[userId] = !isCurrentlyFollowing
        if isCurrentlyFollowing {
            findFriendsViewModel.followingIds.remove(userId)
        } else {
            findFriendsViewModel.followingIds.insert(userId)
        }
        
        Task {
            do {
                if isCurrentlyFollowing {
                    try await SocialService.shared.unfollowUser(followerId: currentUserId, followingId: userId)
                } else {
                    try await SocialService.shared.followUser(followerId: currentUserId, followingId: userId)
                }
                NotificationCenter.default.post(name: .profileStatsUpdated, object: nil)
            } catch {
                await MainActor.run {
                    contactsFollowingStatus[userId] = isCurrentlyFollowing
                    findFriendsViewModel.followingStatus[userId] = isCurrentlyFollowing
                    if isCurrentlyFollowing {
                        findFriendsViewModel.followingIds.insert(userId)
                    } else {
                        findFriendsViewModel.followingIds.remove(userId)
                    }
                }
                print("❌ Error toggling follow: \(error)")
            }
        }
    }
    
    private func loadFollowingIds() async {
        guard let userId = authViewModel.currentUser?.id else { return }
        await findFriendsViewModel.loadFollowingIds(userId: userId)
    }
    
    private func loadRecommendedUsers() {
        guard let userId = authViewModel.currentUser?.id else { return }
        
        isLoadingRecommended = true
        
        if let cached = AppCacheManager.shared.getCachedRecommendedUsers(userId: userId) {
            self.recommendedUsers = cached
            for user in cached {
                recommendedFollowingStatus[user.id] = findFriendsViewModel.followingIds.contains(user.id)
            }
            self.isLoadingRecommended = false
        }
        
        Task {
            do {
                let recommended = try await SocialService.shared.getRecommendedUsers(userId: userId, limit: 20)
                
                var followStatus: [String: Bool] = [:]
                for user in recommended {
                    followStatus[user.id] = findFriendsViewModel.followingIds.contains(user.id)
                }
                
                await MainActor.run {
                    self.recommendedUsers = recommended
                    self.recommendedFollowingStatus = followStatus
                    self.isLoadingRecommended = false
                }
                AppCacheManager.shared.saveRecommendedUsers(recommended, userId: userId)
            } catch {
                print("❌ Error loading recommended users: \(error)")
                await MainActor.run {
                    self.isLoadingRecommended = false
                }
            }
        }
    }
    
    private func performSearch() {
        guard !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              let currentUserId = authViewModel.currentUser?.id else { return }
        
        findFriendsViewModel.searchUsers(query: searchText, currentUserId: currentUserId)
    }
    
    private func toggleFollow(userId: String) {
        guard let currentUserId = authViewModel.currentUser?.id else { return }
        findFriendsViewModel.toggleFollow(followerId: currentUserId, followingId: userId)
    }
    
    private func toggleRecommendedFollow(userId: String) {
        guard let currentUserId = authViewModel.currentUser?.id else { return }
        
        let isCurrentlyFollowing = recommendedFollowingStatus[userId] ?? false
        
        recommendedFollowingStatus[userId] = !isCurrentlyFollowing
        findFriendsViewModel.followingStatus[userId] = !isCurrentlyFollowing
        if isCurrentlyFollowing {
            findFriendsViewModel.followingIds.remove(userId)
        } else {
            findFriendsViewModel.followingIds.insert(userId)
        }
        
        Task {
            do {
                if isCurrentlyFollowing {
                    try await SocialService.shared.unfollowUser(followerId: currentUserId, followingId: userId)
                } else {
                    try await SocialService.shared.followUser(followerId: currentUserId, followingId: userId)
                }
                NotificationCenter.default.post(name: .profileStatsUpdated, object: nil)
            } catch {
                await MainActor.run {
                    recommendedFollowingStatus[userId] = isCurrentlyFollowing
                    findFriendsViewModel.followingStatus[userId] = isCurrentlyFollowing
                    if isCurrentlyFollowing {
                        findFriendsViewModel.followingIds.insert(userId)
                    } else {
                        findFriendsViewModel.followingIds.remove(userId)
                    }
                }
                print("❌ Error toggling follow: \(error)")
            }
        }
    }
}

// MARK: - Friend Search Row
struct FriendSearchRow: View {
    let user: UserSearchResult
    let isFollowing: Bool
    let mutualInfo: String?
    let onFollowToggle: () -> Void
    @State private var isProcessing = false
    
    var body: some View {
        HStack(spacing: 12) {
            // Profile picture
            ProfileImage(url: user.avatarUrl, size: 50)
            
            // User info
            VStack(alignment: .leading, spacing: 4) {
                Text(user.name)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.black)
                
                if let info = mutualInfo {
                    Text(info)
                        .font(.system(size: 13))
                        .foregroundColor(.gray)
                }
            }
            
            Spacer()
            
            // Follow button
            Button {
                guard !isProcessing else { return }
                isProcessing = true
                onFollowToggle()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    isProcessing = false
                }
            } label: {
                if isProcessing {
                    ProgressView()
                        .scaleEffect(0.8)
                        .frame(width: 70, height: 32)
                } else {
                    Text(isFollowing ? "Följer" : "Följ")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(isFollowing ? .gray : .black)
                        .frame(width: 70, height: 32)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(isFollowing ? Color.gray.opacity(0.3) : Color.black, lineWidth: 1)
                        )
                }
            }
            .buttonStyle(.borderless)
            .disabled(isProcessing)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

// MARK: - ViewModel (kept from original)
class FindFriendsViewModel: ObservableObject {
    @Published var searchResults: [UserSearchResult] = []
    @Published var isLoading = false
    @Published var followingStatus: [String: Bool] = [:]
    @Published var followingIds: Set<String> = []
    
    private let cacheManager = AppCacheManager.shared
    
    func loadFollowingIds(userId: String) async {
        do {
            let ids = try await SocialService.shared.getFollowing(userId: userId)
            await MainActor.run {
                self.followingIds = Set(ids)
            }
        } catch {
            print("❌ Error loading following IDs: \(error)")
        }
    }
    
    func searchUsers(query: String, currentUserId: String) {
        isLoading = true
        
        let lowercasedQuery = query.lowercased()
        
        if let cachedUsers = cacheManager.getCachedAllUsers() {
            let filteredUsers = cachedUsers.filter { user in
                user.name.lowercased().contains(lowercasedQuery)
            }
            
            if !filteredUsers.isEmpty {
                self.searchResults = filteredUsers
                for user in filteredUsers {
                    self.followingStatus[user.id] = self.followingIds.contains(user.id)
                }
                self.isLoading = false
            }
        }
        
        Task {
            do {
                let results = try await SocialService.shared.searchUsers(query: query, currentUserId: currentUserId)
                
                await MainActor.run {
                    self.searchResults = results
                    for user in results {
                        self.followingStatus[user.id] = self.followingIds.contains(user.id)
                    }
                    self.isLoading = false
                    self.cacheManager.saveAllUsers(results)
                }
            } catch {
                await MainActor.run {
                    self.isLoading = false
                }
            }
        }
    }
    
    func toggleFollow(followerId: String, followingId: String) {
        let isCurrentlyFollowing = followingStatus[followingId] ?? false
        
        followingStatus[followingId] = !isCurrentlyFollowing
        if isCurrentlyFollowing {
            followingIds.remove(followingId)
        } else {
            followingIds.insert(followingId)
        }
        
        Task {
            do {
                if isCurrentlyFollowing {
                    try await SocialService.shared.unfollowUser(followerId: followerId, followingId: followingId)
                } else {
                    try await SocialService.shared.followUser(followerId: followerId, followingId: followingId)
                }
                NotificationCenter.default.post(name: .profileStatsUpdated, object: nil)
            } catch {
                await MainActor.run {
                    self.followingStatus[followingId] = isCurrentlyFollowing
                    if isCurrentlyFollowing {
                        self.followingIds.insert(followingId)
                    } else {
                        self.followingIds.remove(followingId)
                    }
                }
            }
        }
    }
}

#Preview {
    FindFriendsView()
        .environmentObject(AuthViewModel())
}
