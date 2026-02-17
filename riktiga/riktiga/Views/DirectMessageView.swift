import SwiftUI
import PhotosUI
import UIKit

// MARK: - Animated GIF View (UIKit-backed for proper GIF animation)

struct AnimatedGifView: UIViewRepresentable {
    let url: URL
    var fillMode: UIView.ContentMode = .scaleAspectFit
    
    func makeUIView(context: Context) -> UIView {
        let container = UIView()
        container.backgroundColor = .clear
        container.clipsToBounds = true
        
        let imageView = UIImageView()
        imageView.contentMode = fillMode
        imageView.clipsToBounds = true
        imageView.backgroundColor = .clear
        imageView.tag = 100
        imageView.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(imageView)
        
        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: container.topAnchor),
            imageView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            imageView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
        ])
        
        // Loading indicator
        let spinner = UIActivityIndicatorView(style: .medium)
        spinner.tag = 200
        spinner.translatesAutoresizingMaskIntoConstraints = false
        spinner.startAnimating()
        container.addSubview(spinner)
        NSLayoutConstraint.activate([
            spinner.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            spinner.centerYAnchor.constraint(equalTo: container.centerYAnchor),
        ])
        
        return container
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        guard let imageView = uiView.viewWithTag(100) as? UIImageView else { return }
        let spinner = uiView.viewWithTag(200) as? UIActivityIndicatorView
        
        // Avoid re-loading if already displaying this URL
        if context.coordinator.loadedURL == url { return }
        context.coordinator.loadedURL = url
        
        spinner?.startAnimating()
        spinner?.isHidden = false
        
        let task = URLSession.shared.dataTask(with: url) { data, _, error in
            guard let data = data, error == nil else {
                DispatchQueue.main.async {
                    spinner?.stopAnimating()
                    spinner?.isHidden = true
                }
                return
            }
            
            // Create animated image from GIF data
            let animatedImage = UIImage.gifImage(from: data)
            
            DispatchQueue.main.async {
                imageView.image = animatedImage
                spinner?.stopAnimating()
                spinner?.isHidden = true
            }
        }
        task.resume()
    }
    
    func makeCoordinator() -> Coordinator { Coordinator() }
    
    class Coordinator {
        var loadedURL: URL?
    }
}

// MARK: - UIImage GIF Extension

extension UIImage {
    static func gifImage(from data: Data) -> UIImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        let count = CGImageSourceGetCount(source)
        
        guard count > 1 else {
            // Not animated, return single image
            return UIImage(data: data)
        }
        
        var images: [UIImage] = []
        var totalDuration: Double = 0
        
        for i in 0..<count {
            guard let cgImage = CGImageSourceCreateImageAtIndex(source, i, nil) else { continue }
            images.append(UIImage(cgImage: cgImage))
            
            // Get frame duration
            if let properties = CGImageSourceCopyPropertiesAtIndex(source, i, nil) as? [String: Any],
               let gifDict = properties[kCGImagePropertyGIFDictionary as String] as? [String: Any] {
                let delay = gifDict[kCGImagePropertyGIFUnclampedDelayTime as String] as? Double
                    ?? gifDict[kCGImagePropertyGIFDelayTime as String] as? Double
                    ?? 0.1
                totalDuration += max(delay, 0.02) // Minimum 20ms per frame
            } else {
                totalDuration += 0.1
            }
        }
        
        guard !images.isEmpty else { return UIImage(data: data) }
        return UIImage.animatedImage(with: images, duration: totalDuration)
    }
}

struct DirectMessageView: View {
    let conversationId: UUID
    let otherUserId: String
    let otherUsername: String
    let otherAvatarUrl: String?
    var isGroup: Bool = false
    var memberCount: Int = 2
    
    @EnvironmentObject var authViewModel: AuthViewModel
    @Environment(\.dismiss) private var dismiss
    @StateObject private var dmService = DirectMessageService.shared
    
    @State private var messageText = ""
    @State private var currentUserId: UUID?
    @State private var isLoading = true
    @State private var showSettings = false
    @State private var otherUserLastSeen: Date? = nil
    @State private var senderNames: [UUID: String] = [:]
    @State private var senderAvatars: [UUID: String] = [:]
    @State private var showGymInviteSheet = false
    @State private var showGifPicker = false
    @State private var selectedPhotoItem: PhotosPickerItem? = nil
    @State private var photoPickerPresented = false
    @State private var isSendingImage = false
    @State private var showUserProfile = false
    @State private var profileUserIdToShow: String? = nil
    @State private var chatAppeared = true
    @State private var activeReactionMessageId: UUID? = nil
    @FocusState private var isInputFocused: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            chatHeader
            
            // Messages
            if isLoading {
                Spacer()
                ProgressView()
                    .scaleEffect(1.2)
                    .transition(.opacity)
                Spacer()
            } else {
                messagesScrollView
                    .opacity(chatAppeared ? 1 : 0)
                    .offset(y: chatAppeared ? 0 : 4)
                    .animation(.easeOut(duration: 0.3), value: chatAppeared)
            }
            
            // Input bar
            chatInputBar
                .opacity(chatAppeared ? 1 : 0)
                .animation(.easeOut(duration: 0.25).delay(0.1), value: chatAppeared)
        }
        .onTapGesture {
            isInputFocused = false
            if activeReactionMessageId != nil {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                    activeReactionMessageId = nil
                }
            }
        }
        .animation(.easeInOut(duration: 0.25), value: isLoading)
        .background(Color(.systemBackground))
        .navigationBarHidden(true)
        .task {
            await setupChat()
        }
        .onAppear {
            NavigationDepthTracker.shared.setAtRoot(false)
            NotificationCenter.default.post(name: NSNotification.Name("HideFloatingButton"), object: nil)
        }
        .onDisappear {
            dmService.stopPolling()
            dmService.stopTyping(conversationId: conversationId)
            NavigationDepthTracker.shared.setAtRoot(true)
            NotificationCenter.default.post(name: NSNotification.Name("RefreshUnreadMessages"), object: nil)
            NotificationCenter.default.post(name: NSNotification.Name("ShowFloatingButton"), object: nil)
        }
        .navigationDestination(isPresented: $showSettings) {
            ConversationSettingsView(
                conversationId: conversationId,
                otherUsername: otherUsername,
                otherAvatarUrl: otherAvatarUrl,
                myAvatarUrl: authViewModel.currentUser?.avatarUrl,
                isGroup: isGroup,
                groupName: isGroup ? otherUsername : nil
            )
            .environmentObject(authViewModel)
        }
        .sheet(isPresented: $showUserProfile) {
            if !otherUserId.isEmpty {
                NavigationStack {
                    UserProfileView(userId: otherUserId)
                        .environmentObject(authViewModel)
                        .toolbar {
                            ToolbarItem(placement: .navigationBarLeading) {
                                Button("Stäng") {
                                    showUserProfile = false
                                }
                                .foregroundColor(.primary)
                            }
                        }
                }
            }
        }
        .sheet(isPresented: Binding(
            get: { profileUserIdToShow != nil },
            set: { if !$0 { profileUserIdToShow = nil } }
        )) {
            if let userId = profileUserIdToShow {
                NavigationStack {
                    UserProfileView(userId: userId)
                        .environmentObject(authViewModel)
                        .toolbar {
                            ToolbarItem(placement: .navigationBarLeading) {
                                Button("Stäng") {
                                    profileUserIdToShow = nil
                                }
                                .foregroundColor(.primary)
                            }
                        }
                }
            }
        }
        .sheet(isPresented: $showGymInviteSheet) {
            GymInviteProposalSheet(conversationId: conversationId, otherUsername: otherUsername)
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
                .presentationBackground(Color(.systemBackground))
        }
        .sheet(isPresented: $showGifPicker) {
            GifPickerView(conversationId: conversationId)
                .presentationDetents([.medium, .large])
        }
        .photosPicker(isPresented: $photoPickerPresented, selection: $selectedPhotoItem, matching: .images)
        .onChange(of: selectedPhotoItem) { _, newItem in
            guard let item = newItem else { return }
            handleSelectedPhoto(item)
            selectedPhotoItem = nil
        }
    }
    
    // MARK: - Header
    
    private var chatHeader: some View {
        VStack(spacing: 0) {
            HStack(spacing: 14) {
                // Back button
                Button {
                    dismiss()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 20, weight: .bold))
                        if dmService.totalUnreadCount > 0 {
                            Text("\(dmService.totalUnreadCount)")
                                .font(.system(size: 16, weight: .semibold))
                        }
                    }
                    .foregroundColor(.primary)
                }
                
                Spacer()
                
                // Center: Avatar + Name (tappable)
                Button {
                    if !isGroup && !otherUserId.isEmpty {
                        showUserProfile = true
                    }
                } label: {
                    VStack(spacing: 3) {
                        ProfileImage(url: otherAvatarUrl, size: 36)
                        
                        Text(otherUsername)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.primary)
                            .lineLimit(1)
                    }
                }
                .buttonStyle(.plain)
                
                Spacer()
                
                // Right: Settings
                Button {
                    showSettings = true
                } label: {
                    Image(systemName: "info.circle")
                        .font(.system(size: 22, weight: .medium))
                        .foregroundColor(.primary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            
            Divider()
                .opacity(0.4)
        }
        .background(Color(.systemBackground))
    }
    
    private var isOtherUserOnline: Bool {
        guard let lastSeen = otherUserLastSeen else { return false }
        return Date().timeIntervalSince(lastSeen) < 300 // 5 minutes
    }
    
    private var lastSeenText: String {
        guard let lastSeen = otherUserLastSeen else { return "" }
        
        let interval = Date().timeIntervalSince(lastSeen)
        
        if interval < 300 {
            return "Online"
        }
        
        let minutes = Int(interval / 60)
        let hours = Int(interval / 3600)
        let days = Int(interval / 86400)
        
        if minutes < 60 {
            return "Sågs senast för \(minutes) min sedan"
        } else if hours < 24 {
            return "Sågs senast för \(hours) \(hours == 1 ? "timme" : "timmar") sedan"
        } else {
            return "Sågs senast för \(days) \(days == 1 ? "dag" : "dagar") sedan"
        }
    }
    
    // MARK: - Messages Scroll View
    
    private var messagesScrollView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 0) {
                    // Empty state
                    if dmService.messages.isEmpty {
                        emptyStateView
                    }
                    
                    ForEach(Array(dmService.messages.enumerated()), id: \.element.id) { index, message in
                        let isFromMe = message.senderId == currentUserId
                        let showDateHeader = shouldShowDateHeader(for: index)
                        let lastInGroup = isLastInGroup(at: index)
                        let firstInSenderGroup = isFirstInGroup(at: index)
                        let messageReactions = dmService.reactions[message.id] ?? []
                        
                        // iMessage-style spacing: tight within groups, larger between senders
                        let topSpacing: CGFloat = {
                            if index == 0 { return 0 }
                            if showDateHeader { return 0 }
                            if firstInSenderGroup { return 10 }
                            return 2
                        }()
                        
                        // Show timestamp between sender groups or after 5+ min gap
                        let showTimestamp = lastInGroup && shouldShowTimestamp(at: index)
                        
                        // "Levererat"/"Läst" only on the very last sent message
                        let showReadStatus = isFromMe && index == dmService.messages.count - 1
                        
                        if showDateHeader {
                            DateSeparator(date: message.createdAt ?? Date())
                                .padding(.top, index == 0 ? 4 : 16)
                                .padding(.bottom, 8)
                        }
                        
                        VStack(alignment: isFromMe ? .trailing : .leading, spacing: 0) {
                            // Reaction picker (above the message)
                            if activeReactionMessageId == message.id {
                                HStack {
                                    if isFromMe { Spacer() }
                                    ReactionEmojiPicker(messageId: message.id) { emoji in
                                        reactToMessage(messageId: message.id, emoji: emoji)
                                    } onDismiss: {
                                        withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                                            activeReactionMessageId = nil
                                        }
                                    }
                                    if !isFromMe { Spacer() }
                                }
                                .padding(.horizontal, isFromMe ? 0 : 38)
                                .padding(.bottom, 4)
                                .zIndex(10)
                            }
                            
                            SwipeToDeleteMessage(isFromMe: isFromMe) {
                                deleteMessage(message)
                            } content: {
                                // In group chats, use per-sender avatar; in 1-on-1 use otherAvatarUrl
                                let avatarForMessage: String? = isGroup
                                    ? senderAvatars[message.senderId] ?? otherAvatarUrl
                                    : otherAvatarUrl
                                // In groups, show sender name on first message of each sender group
                                let nameForMessage: String? = isGroup && !isFromMe && firstInSenderGroup
                                    ? (senderNames[message.senderId] ?? otherUsername)
                                    : nil
                                
                                if message.isGymInvite {
                                    GymInviteCard(
                                        message: message,
                                        isFromMe: isFromMe,
                                        currentUserId: currentUserId,
                                        senderName: isFromMe ? "Du" : (senderNames[message.senderId] ?? otherUsername),
                                        otherUsername: otherUsername,
                                        isGroup: isGroup,
                                        memberCount: memberCount
                                    )
                                } else if message.isMediaMessage {
                                    ImageMessageBubble(
                                        message: message,
                                        isFromMe: isFromMe,
                                        otherAvatarUrl: avatarForMessage,
                                        showAvatar: !isFromMe,
                                        isGroupChat: isGroup,
                                        senderName: nameForMessage,
                                        onAvatarTap: {
                                            profileUserIdToShow = message.senderId.uuidString
                                        },
                                        isLastInGroup: lastInGroup,
                                        showTimestamp: showTimestamp,
                                        showReadStatus: showReadStatus
                                    )
                                } else {
                                    MessageBubble(
                                        message: message,
                                        isFromMe: isFromMe,
                                        otherAvatarUrl: avatarForMessage,
                                        showAvatar: !isFromMe,
                                        isGroupChat: isGroup,
                                        senderName: nameForMessage,
                                        onAvatarTap: {
                                            profileUserIdToShow = message.senderId.uuidString
                                        },
                                        isLastInGroup: lastInGroup,
                                        showTimestamp: showTimestamp,
                                        showReadStatus: showReadStatus
                                    )
                                }
                            }
                            .simultaneousGesture(
                                LongPressGesture(minimumDuration: 0.5)
                                    .onEnded { _ in
                                        let generator = UIImpactFeedbackGenerator(style: .medium)
                                        generator.impactOccurred()
                                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                            if activeReactionMessageId == message.id {
                                                activeReactionMessageId = nil
                                            } else {
                                                activeReactionMessageId = message.id
                                            }
                                        }
                                    }
                            )
                            
                            // Reactions display
                            if !messageReactions.isEmpty {
                                HStack {
                                    if isFromMe { Spacer() }
                                    ReactionBubblesView(reactions: messageReactions) { emoji in
                                        reactToMessage(messageId: message.id, emoji: emoji)
                                    }
                                    .padding(.horizontal, isFromMe ? 8 : 42)
                                    if !isFromMe { Spacer() }
                                }
                                .offset(y: -4)
                            }
                        }
                        .padding(.top, topSpacing)
                        .id(message.id)
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .scale(scale: 0.98)).combined(with: .move(edge: .bottom)),
                            removal: .opacity.combined(with: .scale(scale: 0.95))
                        ))
                    }
                    
                    // Typing indicator
                    if dmService.isOtherUserTyping {
                        TypingIndicatorBubble(otherAvatarUrl: otherAvatarUrl)
                            .id("typing-indicator")
                            .padding(.top, 10)
                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                    }
                }
                .padding(.horizontal, 10)
                .padding(.top, 8)
                .padding(.bottom, 12)
            }
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: dmService.messages.count) { _, _ in
                if let lastMessage = dmService.messages.last {
                    withAnimation(.easeOut(duration: 0.2)) {
                        proxy.scrollTo(lastMessage.id, anchor: .bottom)
                    }
                }
                updateLastSeen()
                // Load names/avatars for any new senders (group chats)
                if isGroup {
                    Task { await loadSenderNames() }
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
        VStack(spacing: 18) {
            Spacer()
                .frame(height: 80)
            
            ProfileImage(url: otherAvatarUrl, size: 80)
            
            Text(otherUsername)
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(.primary)
            
            Text("Starta en konversation med \(otherUsername)")
                .font(.system(size: 16))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
    }
    
    // MARK: - Input Bar
    
    private var chatInputBar: some View {
        VStack(spacing: 0) {
            // Sending image indicator
            if isSendingImage {
                HStack(spacing: 8) {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Skickar bild...")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 6)
                .frame(maxWidth: .infinity)
                .background(Color(.systemBackground))
            }
            
            HStack(alignment: .bottom, spacing: 8) {
                // "+" button - opens action menu
                Menu {
                    Section {
                        Button {
                            photoPickerPresented = true
                        } label: {
                            Label("Foto", systemImage: "photo")
                        }
                        
                        Button {
                            isInputFocused = false
                            showGifPicker = true
                        } label: {
                            Label("GIF", systemImage: "face.smiling")
                        }
                        
                        Button {
                            showGymInviteSheet = true
                        } label: {
                            Label("Skicka träningsförslag", systemImage: "figure.run")
                        }
                    }
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 34))
                        .foregroundStyle(.primary)
                        .symbolRenderingMode(.hierarchical)
                }
                
                // Text field
                HStack(alignment: .bottom, spacing: 0) {
                    TextField("Skriv ett meddelande...", text: $messageText, axis: .vertical)
                        .font(.system(size: 17))
                        .lineLimit(1...6)
                        .focused($isInputFocused)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .onChange(of: messageText) { _, newValue in
                            if !newValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                dmService.userDidType(conversationId: conversationId)
                            }
                        }
                    
                    // Send button inside the text field
                    if !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Button {
                            sendMessage()
                        } label: {
                            Image(systemName: "arrow.up.circle.fill")
                                .font(.system(size: 32))
                                .foregroundColor(.primary)
                        }
                        .padding(.trailing, 5)
                        .padding(.bottom, 4)
                        .transition(.scale.combined(with: .opacity))
                    }
                }
                .background(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(Color(.systemGray6))
                )
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .padding(.bottom, 2)
            .background(Color(.systemBackground))
            .animation(.easeInOut(duration: 0.15), value: messageText.isEmpty)
        }
    }
    
    // MARK: - Helpers
    
    private func setupChat() async {
        currentUserId = await dmService.getCurrentUserId()
        dmService.startPolling(conversationId: conversationId)
        updateLastSeen()
        await loadSenderNames()
        isLoading = false
    }
    
    private func updateLastSeen() {
        // Find the most recent message from the other user
        if let otherUUID = UUID(uuidString: otherUserId) {
            let otherMessages = dmService.messages.filter { $0.senderId == otherUUID }
            if let latest = otherMessages.last, let date = latest.createdAt {
                otherUserLastSeen = date
            }
        }
    }
    
    private func handleSelectedPhoto(_ item: PhotosPickerItem) {
        isSendingImage = true
        Task {
            do {
                guard let data = try await item.loadTransferable(type: Data.self) else {
                    await MainActor.run { isSendingImage = false }
                    return
                }
                
                // Compress image
                let compressedData: Data
                if let uiImage = UIImage(data: data) {
                    compressedData = uiImage.jpegData(compressionQuality: 0.7) ?? data
                } else {
                    compressedData = data
                }
                
                try await dmService.sendImageMessage(conversationId: conversationId, imageData: compressedData)
                await MainActor.run { isSendingImage = false }
            } catch {
                print("❌ Failed to send image: \(error)")
                await MainActor.run { isSendingImage = false }
            }
        }
    }
    
    private func sendMessage() {
        let text = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        messageText = ""
        dmService.stopTyping(conversationId: conversationId)
        
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
    
    private func isFirstInGroup(at index: Int) -> Bool {
        guard index > 0 else { return true }
        return dmService.messages[index].senderId != dmService.messages[index - 1].senderId
    }
    
    /// Show timestamp when the next message is from a different sender, or there's a 5+ min gap
    private func shouldShowTimestamp(at index: Int) -> Bool {
        let messages = dmService.messages
        // Always show on the very last message
        if index == messages.count - 1 { return true }
        
        let current = messages[index]
        let next = messages[index + 1]
        
        // Different sender -> show time on last of the group
        if current.senderId != next.senderId { return true }
        
        // Same sender but 5+ min gap
        if let currentDate = current.createdAt, let nextDate = next.createdAt {
            return nextDate.timeIntervalSince(currentDate) > 300
        }
        
        return false
    }
    
    private func reactToMessage(messageId: UUID, emoji: String) {
        // Dismiss the picker
        withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
            activeReactionMessageId = nil
        }
        
        Task {
            do {
                try await dmService.toggleReaction(messageId: messageId, emoji: emoji)
            } catch {
                print("❌ Failed to toggle reaction: \(error)")
            }
        }
    }
    
    private func deleteMessage(_ message: DirectMessage) {
        Task {
            do {
                try await DirectMessageService.shared.deleteMessage(messageId: message.id)
                await MainActor.run {
                    let generator = UINotificationFeedbackGenerator()
                    generator.notificationOccurred(.success)
                }
                print("✅ Message deleted successfully")
            } catch {
                print("❌ Error deleting message: \(error)")
                await MainActor.run {
                    let generator = UINotificationFeedbackGenerator()
                    generator.notificationOccurred(.error)
                }
            }
        }
    }
    
    private func loadSenderNames() async {
        // Collect unique sender IDs we don't have names for yet
        let unknownIds = Set(dmService.messages.map { $0.senderId })
            .filter { senderNames[$0] == nil && $0 != currentUserId }
        guard !unknownIds.isEmpty else { return }
        
        do {
            let idStrings = unknownIds.map { $0.uuidString }
            let profiles = try await DirectMessageService.shared.fetchUserProfiles(userIds: idStrings)
            
            var names = senderNames
            var avatars = senderAvatars
            for profile in profiles {
                if let uuid = UUID(uuidString: profile.id) {
                    if let name = profile.username {
                        names[uuid] = name
                    }
                    if let avatar = profile.avatar_url {
                        avatars[uuid] = avatar
                    }
                }
            }
            await MainActor.run {
                senderNames = names
                senderAvatars = avatars
            }
        } catch {
            print("⚠️ Failed to load sender profiles: \(error)")
        }
    }
}

// MARK: - Reaction Emoji Picker (iMessage-style popup)

struct ReactionEmojiPicker: View {
    let messageId: UUID
    let onReact: (String) -> Void
    let onDismiss: () -> Void
    
    private let quickEmojis = ["👍", "👎", "❤️", "😂", "😮", "😢", "🔥", "💪"]
    
    var body: some View {
        HStack(spacing: 6) {
            ForEach(quickEmojis, id: \.self) { emoji in
                Button {
                    let generator = UIImpactFeedbackGenerator(style: .light)
                    generator.impactOccurred()
                    onReact(emoji)
                } label: {
                    Text(emoji)
                        .font(.system(size: 32))
                        .frame(width: 44, height: 44)
                        .background(Color(.systemBackground).opacity(0.01))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.18), radius: 16, x: 0, y: 6)
        )
        .transition(.asymmetric(
            insertion: .scale(scale: 0.5).combined(with: .opacity),
            removal: .scale(scale: 0.8).combined(with: .opacity)
        ))
    }
}

// MARK: - Reaction Bubbles Display (below message)

struct ReactionBubblesView: View {
    let reactions: [ReactionGroup]
    let onTapReaction: (String) -> Void
    
    var body: some View {
        if !reactions.isEmpty {
            HStack(spacing: 5) {
                ForEach(reactions) { group in
                    Button {
                        onTapReaction(group.emoji)
                    } label: {
                        HStack(spacing: 3) {
                            Text(group.emoji)
                                .font(.system(size: 16))
                            if group.count > 1 {
                                Text("\(group.count)")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundColor(.primary)
                            }
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(group.hasReactedByMe ? Color.black.opacity(0.12) : Color(.systemGray5))
                        )
                        .overlay(
                            Capsule()
                                .stroke(group.hasReactedByMe ? Color.black.opacity(0.3) : Color.clear, lineWidth: 1.5)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

// MARK: - Swipe to Delete Message Wrapper

struct SwipeToDeleteMessage<Content: View>: View {
    let isFromMe: Bool
    let onDelete: () -> Void
    @ViewBuilder let content: () -> Content
    
    @State private var swipeOffset: CGFloat = 0
    @GestureState private var dragOffset: CGFloat = 0
    @State private var showDeleteConfirmation = false
    
    private let deleteThreshold: CGFloat = -80
    private let maxSwipe: CGFloat = -120
    
    private var currentOffset: CGFloat {
        let total = swipeOffset + dragOffset
        if total > 0 { return 0 }
        if total < maxSwipe {
            let overflow = total - maxSwipe
            return maxSwipe + overflow * 0.3
        }
        return total
    }
    
    private var actionOpacity: Double {
        let progress = min(1.0, abs(currentOffset) / abs(deleteThreshold))
        return progress
    }
    
    var body: some View {
        ZStack(alignment: .trailing) {
            // Delete action background
            HStack {
                Spacer()
                
                ZStack {
                    Color.red
                    
                    VStack(spacing: 2) {
                        Image(systemName: "trash.fill")
                            .font(.system(size: 16, weight: .semibold))
                        Text("Radera")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .opacity(actionOpacity)
                }
                .frame(width: abs(min(currentOffset, 0)))
                .cornerRadius(12)
            }
            
            // Message content
            content()
                .offset(x: currentOffset)
                .gesture(
                    DragGesture(minimumDistance: 15)
                        .updating($dragOffset) { value, state, _ in
                            guard isFromMe else { return }
                            let horizontalAmount = abs(value.translation.width)
                            let verticalAmount = abs(value.translation.height)
                            
                            if horizontalAmount > verticalAmount * 1.5 && value.translation.width < 0 {
                                state = value.translation.width
                            }
                        }
                        .onEnded { value in
                            guard isFromMe else { return }
                            let horizontalAmount = abs(value.translation.width)
                            let verticalAmount = abs(value.translation.height)
                            guard horizontalAmount > verticalAmount else {
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                                    swipeOffset = 0
                                }
                                return
                            }
                            
                            let finalOffset = swipeOffset + value.translation.width
                            
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                                if finalOffset < deleteThreshold {
                                    let generator = UIImpactFeedbackGenerator(style: .medium)
                                    generator.impactOccurred()
                                    showDeleteConfirmation = true
                                }
                                swipeOffset = 0
                            }
                        }
                )
        }
        .clipped()
        .alert("Radera meddelande?", isPresented: $showDeleteConfirmation) {
            Button("Avbryt", role: .cancel) { }
            Button("Radera", role: .destructive) {
                onDelete()
            }
        } message: {
            Text("Det här meddelandet kommer att tas bort permanent.")
        }
    }
}

// MARK: - iMessage-style Bubble Shape

struct MessageBubbleShape: Shape {
    let isFromMe: Bool
    let hasTail: Bool
    
    func path(in rect: CGRect) -> Path {
        let r: CGFloat = 22
        let tailR: CGFloat = hasTail ? 4 : r
        
        if isFromMe {
            return UnevenRoundedRectangle(
                topLeadingRadius: r,
                bottomLeadingRadius: r,
                bottomTrailingRadius: tailR,
                topTrailingRadius: r,
                style: .continuous
            ).path(in: rect)
        } else {
            return UnevenRoundedRectangle(
                topLeadingRadius: r,
                bottomLeadingRadius: tailR,
                bottomTrailingRadius: r,
                topTrailingRadius: r,
                style: .continuous
            ).path(in: rect)
        }
    }
}

// MARK: - Message Bubble

struct MessageBubble: View {
    let message: DirectMessage
    let isFromMe: Bool
    let otherAvatarUrl: String?
    let showAvatar: Bool
    var isGroupChat: Bool = false
    var senderName: String? = nil
    var onAvatarTap: (() -> Void)? = nil
    var isLastInGroup: Bool = true
    var showTimestamp: Bool = false
    var showReadStatus: Bool = false
    
    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if isFromMe {
                Spacer(minLength: 50)
            } else {
                if showAvatar && isLastInGroup {
                    Button {
                        onAvatarTap?()
                    } label: {
                        ProfileImage(url: otherAvatarUrl, size: 34)
                    }
                    .buttonStyle(.plain)
                } else {
                    Color.clear
                        .frame(width: 34)
                }
            }
            
            VStack(alignment: isFromMe ? .trailing : .leading, spacing: 2) {
                // Sender name for group chats
                if let name = senderName, isGroupChat, !isFromMe {
                    Text(name)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.secondary)
                        .padding(.leading, 6)
                        .padding(.bottom, 2)
                }
                
                Text(message.message)
                    .font(.system(size: 17))
                    .foregroundColor(isFromMe ? .white : .primary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(isFromMe ? Color.black : Color(.systemGray5))
                    .clipShape(MessageBubbleShape(isFromMe: isFromMe, hasTail: isLastInGroup))
                
                // Timestamp
                if showTimestamp {
                    if let date = message.createdAt {
                        Text(formatMessageTime(date))
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(Color(.systemGray))
                            .padding(.horizontal, 6)
                            .padding(.top, 2)
                    }
                }
                
                // Read status
                if isFromMe && showReadStatus {
                    Text(message.isRead ? "Läst" : "Levererat")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Color(.systemGray))
                        .padding(.horizontal, 6)
                        .padding(.top, 2)
                }
            }
            
            if !isFromMe {
                Spacer(minLength: 50)
            }
        }
    }
    
    private func formatMessageTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}

// MARK: - Image/GIF Message Bubble

struct ImageMessageBubble: View {
    let message: DirectMessage
    let isFromMe: Bool
    let otherAvatarUrl: String?
    let showAvatar: Bool
    var isGroupChat: Bool = false
    var senderName: String? = nil
    var onAvatarTap: (() -> Void)? = nil
    var isLastInGroup: Bool = true
    var showTimestamp: Bool = false
    var showReadStatus: Bool = false
    
    @State private var showFullImage = false
    
    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if isFromMe {
                Spacer(minLength: 50)
            } else {
                if showAvatar && isLastInGroup {
                    Button {
                        onAvatarTap?()
                    } label: {
                        ProfileImage(url: otherAvatarUrl, size: 34)
                    }
                    .buttonStyle(.plain)
                } else {
                    Color.clear
                        .frame(width: 34)
                }
            }
            
            VStack(alignment: isFromMe ? .trailing : .leading, spacing: 2) {
                // Sender name for group chats
                if let name = senderName, isGroupChat, !isFromMe {
                    Text(name)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.secondary)
                        .padding(.leading, 6)
                        .padding(.bottom, 2)
                }
                
                // Image / GIF
                if let imageUrl = message.imageUrl, let url = URL(string: imageUrl) {
                    if message.isGif {
                        AnimatedGifView(url: url)
                            .frame(width: 240, height: 190)
                            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                    } else {
                        Button {
                            showFullImage = true
                        } label: {
                            AsyncImage(url: url) { phase in
                                switch phase {
                                case .success(let image):
                                    image
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(maxWidth: 260, maxHeight: 300)
                                        .clipped()
                                case .failure:
                                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                                        .fill(Color(.systemGray5))
                                        .frame(width: 220, height: 170)
                                        .overlay(
                                            Image(systemName: "photo")
                                                .font(.system(size: 32))
                                                .foregroundColor(.secondary)
                                        )
                                case .empty:
                                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                                        .fill(Color(.systemGray6))
                                        .frame(width: 220, height: 170)
                                        .overlay(ProgressView())
                                @unknown default:
                                    EmptyView()
                                }
                            }
                            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                }
                
                // Timestamp
                if showTimestamp {
                    if let date = message.createdAt {
                        Text(formatMessageTime(date))
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(Color(.systemGray))
                            .padding(.horizontal, 6)
                            .padding(.top, 2)
                    }
                }
                
                // Read status
                if isFromMe && showReadStatus {
                    Text(message.isRead ? "Läst" : "Levererat")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Color(.systemGray))
                        .padding(.horizontal, 6)
                        .padding(.top, 2)
                }
            }
            
            if !isFromMe {
                Spacer(minLength: 50)
            }
        }
        .fullScreenCover(isPresented: $showFullImage) {
            ChatFullScreenImageView(imageUrl: message.imageUrl, isGif: message.isGif)
        }
    }
    
    private func formatMessageTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}

// MARK: - Full Screen Image View

struct ChatFullScreenImageView: View {
    let imageUrl: String?
    var isGif: Bool = false
    @Environment(\.dismiss) private var dismiss
    @State private var scale: CGFloat = 1.0
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            if let urlString = imageUrl, let url = URL(string: urlString) {
                if isGif {
                    AnimatedGifView(url: url)
                        .scaleEffect(scale)
                        .gesture(
                            MagnifyGesture()
                                .onChanged { value in
                                    scale = value.magnification
                                }
                                .onEnded { _ in
                                    withAnimation { scale = 1.0 }
                                }
                        )
                } else {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .scaleEffect(scale)
                                .gesture(
                                    MagnifyGesture()
                                        .onChanged { value in
                                            scale = value.magnification
                                        }
                                        .onEnded { _ in
                                            withAnimation { scale = 1.0 }
                                        }
                                )
                        case .failure:
                            Image(systemName: "photo")
                                .font(.system(size: 48))
                                .foregroundColor(.white.opacity(0.5))
                        case .empty:
                            ProgressView()
                                .tint(.white)
                        @unknown default:
                            EmptyView()
                        }
                    }
                }
            }
            
            // Close button
            VStack {
                HStack {
                    Spacer()
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 28))
                            .foregroundColor(.white.opacity(0.8))
                    }
                    .padding(16)
                }
                Spacer()
            }
        }
        .onTapGesture(count: 2) {
            withAnimation {
                scale = scale > 1.0 ? 1.0 : 2.0
            }
        }
    }
}

// MARK: - Date Separator

struct DateSeparator: View {
    let date: Date
    
    var body: some View {
        Text(formatDate(date))
            .font(.system(size: 13, weight: .bold))
            .foregroundColor(Color(.systemGray))
            .frame(maxWidth: .infinity)
    }
    
    private func formatDate(_ date: Date) -> String {
        let calendar = Calendar.current
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "sv_SE")
        
        if calendar.isDateInToday(date) {
            return "Idag"
        } else if calendar.isDateInYesterday(date) {
            return "Igår"
        } else if calendar.isDate(date, equalTo: Date(), toGranularity: .weekOfYear) {
            formatter.dateFormat = "EEEE"
            return formatter.string(from: date).capitalized
        } else if calendar.isDate(date, equalTo: Date(), toGranularity: .year) {
            formatter.dateFormat = "d MMM"
            return formatter.string(from: date)
        } else {
            formatter.dateFormat = "d MMM yyyy"
            return formatter.string(from: date)
        }
    }
}

// MARK: - Typing Indicator Bubble (iMessage-style)

struct TypingIndicatorBubble: View {
    let otherAvatarUrl: String?
    
    @State private var dotOffset1: CGFloat = 0
    @State private var dotOffset2: CGFloat = 0
    @State private var dotOffset3: CGFloat = 0
    
    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            ProfileImage(url: otherAvatarUrl, size: 34)
            
            HStack(spacing: 5) {
                Circle()
                    .fill(Color(.systemGray2))
                    .frame(width: 8, height: 8)
                    .offset(y: dotOffset1)
                
                Circle()
                    .fill(Color(.systemGray2))
                    .frame(width: 8, height: 8)
                    .offset(y: dotOffset2)
                
                Circle()
                    .fill(Color(.systemGray2))
                    .frame(width: 8, height: 8)
                    .offset(y: dotOffset3)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(.systemGray5))
            .clipShape(MessageBubbleShape(isFromMe: false, hasTail: true))
            
            Spacer(minLength: 50)
        }
        .onAppear {
            startAnimation()
        }
    }
    
    private func startAnimation() {
        withAnimation(.easeInOut(duration: 0.45).repeatForever(autoreverses: true)) {
            dotOffset1 = -4
        }
        
        withAnimation(.easeInOut(duration: 0.45).repeatForever(autoreverses: true).delay(0.15)) {
            dotOffset2 = -4
        }
        
        withAnimation(.easeInOut(duration: 0.45).repeatForever(autoreverses: true).delay(0.3)) {
            dotOffset3 = -4
        }
    }
}

// MARK: - Gym Invite Proposal Sheet

struct GymInviteProposalSheet: View {
    let conversationId: UUID
    let otherUsername: String
    
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @State private var selectedActivityType: TrainingActivityType = .gym
    @State private var selectedDate = Date()
    @State private var selectedTime = Date()
    @State private var locationName = ""
    @State private var isSending = false
    
    private var locationPlaceholder: String {
        switch selectedActivityType {
        case .gym: return "Nordic Wellness, SATS..."
        case .running: return "Slottsskogen, Stadsparken..."
        case .golf: return "Kungsbacka GK, Hovås GK..."
        }
    }
    
    private var locationLabel: String {
        switch selectedActivityType {
        case .gym: return "Gym / Plats"
        case .running: return "Plats / Rutt"
        case .golf: return "Golfklubb / Bana"
        }
    }
    
    private var canSend: Bool {
        !locationName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isSending
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // MARK: Activity type selector
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Välj träningstyp")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.secondary)
                            .textCase(.uppercase)
                            .padding(.horizontal, 4)
                        
                        HStack(spacing: 10) {
                            ForEach(TrainingActivityType.allCases, id: \.self) { activityType in
                                activityTypeButton(activityType)
                            }
                        }
                    }
                    .padding(.top, 4)
                    
                    // MARK: Date & Time row
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Datum & tid")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.secondary)
                            .textCase(.uppercase)
                            .padding(.horizontal, 4)
                        
                        HStack(spacing: 12) {
                            // Date
                            HStack(spacing: 8) {
                                Image(systemName: "calendar")
                                    .font(.system(size: 15))
                                    .foregroundColor(.secondary)
                                
                                DatePicker("", selection: $selectedDate, in: Date()..., displayedComponents: .date)
                                    .datePickerStyle(.compact)
                                    .labelsHidden()
                                    .environment(\.locale, Locale(identifier: "sv_SE"))
                                    .tint(.primary)
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(.systemGray6))
                            .cornerRadius(12)
                            
                            // Time
                            HStack(spacing: 8) {
                                Image(systemName: "clock")
                                    .font(.system(size: 15))
                                    .foregroundColor(.secondary)
                                
                                DatePicker("", selection: $selectedTime, displayedComponents: .hourAndMinute)
                                    .datePickerStyle(.compact)
                                    .labelsHidden()
                                    .environment(\.locale, Locale(identifier: "sv_SE"))
                                    .tint(.primary)
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 12)
                            .background(Color(.systemGray6))
                            .cornerRadius(12)
                        }
                    }
                    
                    // MARK: Location
                    VStack(alignment: .leading, spacing: 10) {
                        Text(locationLabel)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.secondary)
                            .textCase(.uppercase)
                            .padding(.horizontal, 4)
                        
                        HStack(spacing: 8) {
                            Image(systemName: "mappin.and.ellipse")
                                .font(.system(size: 15))
                                .foregroundColor(.secondary)
                            
                            TextField(locationPlaceholder, text: $locationName)
                                .font(.system(size: 16))
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 14)
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 100) // Space for button
            }
            .scrollDismissesKeyboard(.interactively)
            .safeAreaInset(edge: .bottom) {
                // Send button pinned to bottom
                VStack(spacing: 0) {
                    Divider()
                    
                    Button {
                        sendInvite()
                    } label: {
                        HStack(spacing: 8) {
                            if isSending {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Image(systemName: "paperplane.fill")
                                    .font(.system(size: 15))
                            }
                            Text("Skicka förslag")
                                .font(.system(size: 17, weight: .bold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(canSend ? Color.black : Color(.systemGray3))
                        .cornerRadius(14)
                    }
                    .disabled(!canSend)
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .padding(.bottom, 8)
                }
                .background(Color(.systemBackground))
            }
            .navigationTitle("Träningsförslag")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 28))
                            .symbolRenderingMode(.hierarchical)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .presentationBackground(Color(.systemBackground))
    }
    
    // MARK: - Activity Type Button
    @ViewBuilder
    private func activityTypeButton(_ activityType: TrainingActivityType) -> some View {
        let isSelected = selectedActivityType == activityType
        
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                selectedActivityType = activityType
            }
        } label: {
            VStack(spacing: 8) {
                Image(systemName: activityType.icon)
                    .font(.system(size: 22, weight: .medium))
                
                Text(activityType.displayName)
                    .font(.system(size: 13, weight: .semibold))
            }
            .foregroundColor(isSelected ? .white : .primary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(isSelected ? Color.black : Color(.systemGray6))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(isSelected ? Color.clear : Color(.systemGray4), lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Send
    private func sendInvite() {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dateString = dateFormatter.string(from: selectedDate)
        
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH:mm"
        let timeString = timeFormatter.string(from: selectedTime)
        
        let location = locationName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !location.isEmpty else { return }
        
        isSending = true
        
        Task {
            do {
                try await DirectMessageService.shared.sendGymInvite(
                    conversationId: conversationId,
                    date: dateString,
                    time: timeString,
                    gym: location,
                    activityType: selectedActivityType
                )
                await MainActor.run {
                    dismiss()
                }
            } catch {
                print("❌ Failed to send training invite: \(error)")
                await MainActor.run { isSending = false }
            }
        }
    }
}

// MARK: - Gym Invite Card

struct GymInviteCard: View {
    let message: DirectMessage
    let isFromMe: Bool
    let currentUserId: UUID?
    let senderName: String
    let otherUsername: String
    var isGroup: Bool = false
    var memberCount: Int = 2
    
    @StateObject private var dmService = DirectMessageService.shared
    @State private var responses: [GymInviteResponse] = []
    @State private var myResponse: String? = nil
    @State private var isResponding = false
    
    private var inviteData: GymInviteData? { message.gymInviteData }
    
    // Number of people who need to respond (everyone except the sender)
    private var expectedResponders: Int { max(memberCount - 1, 1) }
    
    private var acceptedCount: Int {
        var count = responses.filter { $0.isAccepted && $0.userId != currentUserId }.count
        if myResponse == "accepted" { count += 1 }
        return count
    }
    
    private var declinedCount: Int {
        var count = responses.filter { !$0.isAccepted && $0.userId != currentUserId }.count
        if myResponse == "declined" { count += 1 }
        return count
    }
    
    /// Overall status of the invite based on all responses
    private var overallStatus: InviteStatus {
        if responses.isEmpty && myResponse == nil { return .pending }
        if acceptedCount > 0 { return .accepted }
        if declinedCount > 0 && acceptedCount == 0 { return .declined }
        return .pending
    }
    
    private var borderColor: Color {
        switch overallStatus {
        case .accepted: return .green
        case .declined: return .red
        case .pending: return Color(.systemGray4)
        }
    }
    
    private var borderWidth: CGFloat {
        overallStatus == .pending ? 0.5 : 2.0
    }
    
    /// Status badge text for groups
    private var statusBadgeText: String {
        if isGroup {
            if acceptedCount > 0 {
                return "\(acceptedCount) KOMMER"
            } else if declinedCount > 0 {
                return "\(declinedCount) KAN EJ"
            }
            return ""
        } else {
            return overallStatus == .accepted ? "GODKÄND" : "AVBÖJD"
        }
    }
    
    enum InviteStatus {
        case pending, accepted, declined
    }
    
    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 12) {
                // Header with status badge
                HStack(spacing: 8) {
                    Image(systemName: inviteData?.resolvedActivityType.icon ?? "dumbbell.fill")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.white)
                        .frame(width: 32, height: 32)
                        .background(overallStatus == .accepted ? Color.green : overallStatus == .declined ? Color.red : Color.black)
                        .cornerRadius(8)
                    
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Träningsförslag – \(inviteData?.resolvedActivityType.displayName ?? "Gympass")")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.primary)
                        
                        Text(isGroup ? "\(senderName) vill att alla \(inviteData?.resolvedActivityType.notificationVerb ?? "tränar")" : "\(senderName) vill \(inviteData?.resolvedActivityType.notificationVerb ?? "träna")")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    // Status badge
                    if overallStatus != .pending {
                        Text(statusBadgeText)
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(overallStatus == .accepted ? Color.green : Color.red)
                            .cornerRadius(10)
                    }
                }
                
                // Details
                if let data = inviteData {
                    VStack(spacing: 8) {
                        // Date
                        HStack(spacing: 8) {
                            Image(systemName: "calendar")
                                .font(.system(size: 14))
                                .foregroundColor(overallStatus == .accepted ? .green : overallStatus == .declined ? .red : .secondary)
                                .frame(width: 20)
                            Text(data.displayDate)
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(.primary)
                            Spacer()
                        }
                        
                        // Time
                        HStack(spacing: 8) {
                            Image(systemName: "clock")
                                .font(.system(size: 14))
                                .foregroundColor(overallStatus == .accepted ? .green : overallStatus == .declined ? .red : .secondary)
                                .frame(width: 20)
                            Text(data.time)
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(.primary)
                            Spacer()
                        }
                        
                        // Gym
                        HStack(spacing: 8) {
                            Image(systemName: "mappin.and.ellipse")
                                .font(.system(size: 14))
                                .foregroundColor(overallStatus == .accepted ? .green : overallStatus == .declined ? .red : .secondary)
                                .frame(width: 20)
                            Text(data.gym)
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(.primary)
                            Spacer()
                        }
                    }
                    .padding(.vertical, 4)
                }
                
                // Group: Response summary bar
                if isGroup && (acceptedCount > 0 || declinedCount > 0) {
                    HStack(spacing: 12) {
                        if acceptedCount > 0 {
                            HStack(spacing: 4) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 13))
                                    .foregroundColor(.green)
                                Text("\(acceptedCount)/\(expectedResponders) kommer")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(.green)
                            }
                        }
                        if declinedCount > 0 {
                            HStack(spacing: 4) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 13))
                                    .foregroundColor(.red)
                                Text("\(declinedCount) kan ej")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(.red)
                            }
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color(.systemGray5).opacity(0.5))
                    .cornerRadius(8)
                }
                
                // Response buttons (only if not from me and not yet responded)
                if !isFromMe && myResponse == nil {
                    HStack(spacing: 10) {
                        Button {
                            respond(with: "accepted")
                        } label: {
                            HStack(spacing: 6) {
                                if isResponding {
                                    ProgressView()
                                        .tint(.white)
                                        .scaleEffect(0.8)
                                } else {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 13, weight: .bold))
                                }
                                Text("Godkänn")
                                    .font(.system(size: 14, weight: .bold))
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(Color.green)
                            .cornerRadius(20)
                        }
                        .disabled(isResponding)
                        
                        Button {
                            respond(with: "declined")
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "xmark")
                                    .font(.system(size: 13, weight: .bold))
                                Text("Kan ej")
                                    .font(.system(size: 14, weight: .bold))
                            }
                            .foregroundColor(.red)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(Color.clear)
                            .overlay(
                                RoundedRectangle(cornerRadius: 20)
                                    .stroke(Color.red.opacity(0.5), lineWidth: 1.5)
                            )
                        }
                        .disabled(isResponding)
                    }
                }
                
                // My response shown
                if let myResp = myResponse {
                    HStack(spacing: 8) {
                        Image(systemName: myResp == "accepted" ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .font(.system(size: 16))
                            .foregroundColor(myResp == "accepted" ? .green : .red)
                        Text(myResp == "accepted" ? "Du har godkänt" : "Du kan inte")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(myResp == "accepted" ? .green : .red)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)
                    .background(
                        (myResp == "accepted" ? Color.green : Color.red).opacity(0.08)
                    )
                    .cornerRadius(10)
                }
                
                // Responses from others (always show in groups, show in 1-on-1 too)
                if !responses.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(responses) { resp in
                            if resp.userId != currentUserId {
                                HStack(spacing: 8) {
                                    Image(systemName: resp.isAccepted ? "checkmark.circle.fill" : "xmark.circle.fill")
                                        .font(.system(size: 14))
                                        .foregroundColor(resp.isAccepted ? .green : .red)
                                    Text(resp.username ?? "Användare")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundColor(.primary)
                                    Text(resp.isAccepted ? "kommer!" : "kan ej")
                                        .font(.system(size: 13))
                                        .foregroundColor(resp.isAccepted ? .green : .red)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.vertical, 6)
                                .padding(.horizontal, 10)
                                .background(
                                    (resp.isAccepted ? Color.green : Color.red).opacity(0.06)
                                )
                                .cornerRadius(8)
                            }
                        }
                    }
                    .padding(.top, 2)
                }
            }
            .padding(16)
            .background(Color(.systemGray6))
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(borderColor, lineWidth: borderWidth)
            )
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .animation(.easeInOut(duration: 0.3), value: acceptedCount)
        .animation(.easeInOut(duration: 0.3), value: declinedCount)
        .task {
            await loadResponses()
        }
    }
    
    private func respond(with response: String) {
        isResponding = true
        
        Task {
            do {
                try await dmService.respondToGymInvite(messageId: message.id, response: response, conversationId: message.conversationId)
                await MainActor.run {
                    myResponse = response
                    isResponding = false
                }
                
                // Schedule reminder if accepted
                if response == "accepted", let data = inviteData, let sessionDate = data.sessionDate {
                    GymInviteReminderManager.scheduleReminder(
                        sessionDate: sessionDate,
                        gym: data.gym,
                        otherUsername: otherUsername,
                        activityType: data.resolvedActivityType
                    )
                }
                
                // Reload responses
                await loadResponses()
            } catch {
                print("❌ Failed to respond to gym invite: \(error)")
                await MainActor.run { isResponding = false }
            }
        }
    }
    
    private func loadResponses() async {
        do {
            let result = try await dmService.fetchInviteResponses(messageId: message.id)
            await MainActor.run {
                responses = result
                // Check if current user already responded
                if let myResp = result.first(where: { $0.userId == currentUserId }) {
                    myResponse = myResp.response
                }
            }
        } catch {
            print("⚠️ Failed to load invite responses: \(error)")
        }
    }
}

// MARK: - GIF Picker View (GIPHY API)

struct GifPickerView: View {
    let conversationId: UUID
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @State private var gifs: [GiphyGif] = []
    @State private var trendingGifs: [GiphyGif] = []
    @State private var isLoading = false
    @State private var isSending = false
    @State private var searchTask: Task<Void, Never>?
    @State private var selectedCategory: GifCategory? = nil
    
    // GIPHY API key
    private let giphyApiKey = "4UNM9EUQ3AxZN1ZMSTbkpJW6WqzJcZHG"
    
    // Quick category filters
    enum GifCategory: String, CaseIterable, Identifiable {
        case funny = "funny"
        case reactions = "reactions"
        case love = "love"
        case happy = "happy"
        case sad = "sad"
        case angry = "angry"
        case celebrate = "celebrate"
        case thumbsUp = "thumbs up"
        case facepalm = "facepalm"
        case dance = "dance"
        case sports = "sports"
        case animals = "cute animals"
        
        var id: String { rawValue }
        
        var label: String {
            switch self {
            case .funny: return "Roligt"
            case .reactions: return "Reaktioner"
            case .love: return "Kärlek"
            case .happy: return "Glad"
            case .sad: return "Ledsen"
            case .angry: return "Arg"
            case .celebrate: return "Fira"
            case .thumbsUp: return "Tummen upp"
            case .facepalm: return "Facepalm"
            case .dance: return "Dans"
            case .sports: return "Sport"
            case .animals: return "Djur"
            }
        }
        
        var icon: String {
            switch self {
            case .funny: return "😂"
            case .reactions: return "😮"
            case .love: return "❤️"
            case .happy: return "😊"
            case .sad: return "😢"
            case .angry: return "😡"
            case .celebrate: return "🎉"
            case .thumbsUp: return "👍"
            case .facepalm: return "🤦"
            case .dance: return "💃"
            case .sports: return "⚽"
            case .animals: return "🐶"
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search bar
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 16))
                        .foregroundColor(.secondary)
                    
                    TextField("Sök GIF...", text: $searchText)
                        .font(.system(size: 16))
                        .autocorrectionDisabled()
                    
                    if !searchText.isEmpty {
                        Button {
                            searchText = ""
                            selectedCategory = nil
                            gifs = trendingGifs
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 16))
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Color(.systemGray6))
                .cornerRadius(12)
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 6)
                
                // Category chips
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        // Trending chip
                        Button {
                            selectedCategory = nil
                            searchText = ""
                            gifs = trendingGifs
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "flame.fill")
                                    .font(.system(size: 11))
                                Text("Trendande")
                                    .font(.system(size: 13, weight: .medium))
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(selectedCategory == nil && searchText.isEmpty ? Color.primary : Color(.systemGray5))
                            .foregroundColor(selectedCategory == nil && searchText.isEmpty ? Color(.systemBackground) : .primary)
                            .cornerRadius(16)
                        }
                        .buttonStyle(.plain)
                        
                        ForEach(GifCategory.allCases) { category in
                            Button {
                                selectCategory(category)
                            } label: {
                                HStack(spacing: 3) {
                                    Text(category.icon)
                                        .font(.system(size: 13))
                                    Text(category.label)
                                        .font(.system(size: 13, weight: .medium))
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 7)
                                .background(selectedCategory == category ? Color.primary : Color(.systemGray5))
                                .foregroundColor(selectedCategory == category ? Color(.systemBackground) : .primary)
                                .cornerRadius(16)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
                }
                
                Divider()
                
                // GIF grid
                if isLoading && gifs.isEmpty {
                    Spacer()
                    ProgressView()
                        .scaleEffect(1.2)
                    Spacer()
                } else if gifs.isEmpty && !isLoading {
                    Spacer()
                    VStack(spacing: 12) {
                        Image(systemName: "photo.on.rectangle.angled")
                            .font(.system(size: 40))
                            .foregroundColor(.secondary)
                        Text("Inga GIFs hittades")
                            .font(.system(size: 15))
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                } else {
                    ScrollView {
                        LazyVGrid(columns: [
                            GridItem(.flexible(), spacing: 4),
                            GridItem(.flexible(), spacing: 4)
                        ], spacing: 4) {
                            ForEach(gifs) { gif in
                                Button {
                                    sendGif(gif)
                                } label: {
                                    if let url = URL(string: gif.previewUrl) {
                                        AnimatedGifView(url: url, fillMode: .scaleAspectFill)
                                            .frame(height: 120)
                                            .cornerRadius(8)
                                            .clipped()
                                    } else {
                                        Rectangle()
                                            .fill(Color(.systemGray6))
                                            .frame(height: 120)
                                            .cornerRadius(8)
                                            .overlay(ProgressView())
                                    }
                                }
                                .buttonStyle(.plain)
                                .disabled(isSending)
                            }
                        }
                        .padding(4)
                        
                        // GIPHY attribution (required)
                        HStack(spacing: 6) {
                            Text("Powered By")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.secondary)
                            Text("GIPHY")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 10)
                    }
                }
                
                if isSending {
                    HStack(spacing: 8) {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("Skickar GIF...")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 8)
                }
            }
            .navigationTitle("Välj GIF")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Stäng") { dismiss() }
                        .foregroundColor(.primary)
                }
            }
        }
        .task {
            await loadTrendingGifs()
        }
        .onChange(of: searchText) { _, newValue in
            // Only do text search if user manually typed (not from category)
            if selectedCategory == nil {
                searchTask?.cancel()
                searchTask = Task {
                    try? await Task.sleep(nanoseconds: 400_000_000) // 400ms debounce
                    guard !Task.isCancelled else { return }
                    if newValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        await MainActor.run { gifs = trendingGifs }
                    } else {
                        await searchGifs(query: newValue)
                    }
                }
            }
        }
    }
    
    // MARK: - Category Selection
    
    private func selectCategory(_ category: GifCategory) {
        selectedCategory = category
        searchText = ""
        Task {
            await searchGifs(query: category.rawValue)
        }
    }
    
    // MARK: - GIPHY API Calls
    
    private func loadTrendingGifs() async {
        isLoading = true
        guard let url = URL(string: "https://api.giphy.com/v1/gifs/trending?api_key=\(giphyApiKey)&limit=30&rating=pg-13") else {
            isLoading = false
            return
        }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let response = try JSONDecoder().decode(GiphyResponse.self, from: data)
            let results = response.data.map { GiphyGif(from: $0) }
            await MainActor.run {
                trendingGifs = results
                gifs = results
                isLoading = false
            }
        } catch {
            print("⚠️ Failed to load trending GIFs: \(error)")
            await MainActor.run { isLoading = false }
        }
    }
    
    private func searchGifs(query: String) async {
        isLoading = true
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        guard let url = URL(string: "https://api.giphy.com/v1/gifs/search?api_key=\(giphyApiKey)&q=\(encoded)&limit=30&rating=pg-13&lang=sv") else {
            isLoading = false
            return
        }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let response = try JSONDecoder().decode(GiphyResponse.self, from: data)
            let results = response.data.map { GiphyGif(from: $0) }
            await MainActor.run {
                gifs = results
                isLoading = false
            }
        } catch {
            print("⚠️ Failed to search GIFs: \(error)")
            await MainActor.run { isLoading = false }
        }
    }
    
    private func sendGif(_ gif: GiphyGif) {
        isSending = true
        Task {
            do {
                try await DirectMessageService.shared.sendGifMessage(
                    conversationId: conversationId,
                    gifUrl: gif.fullUrl
                )
                await MainActor.run {
                    isSending = false
                    dismiss()
                }
            } catch {
                print("❌ Failed to send GIF: \(error)")
                await MainActor.run { isSending = false }
            }
        }
    }
}

// MARK: - GIPHY API Models

struct GiphyResponse: Decodable {
    let data: [GiphyResult]
}

struct GiphyResult: Decodable {
    let id: String
    let images: GiphyImages
}

struct GiphyImages: Decodable {
    let fixed_width_small: GiphyRendition?
    let fixed_width: GiphyRendition?
    let downsized: GiphyRendition?
    let original: GiphyRendition?
}

struct GiphyRendition: Decodable {
    let url: String?
    let width: String?
    let height: String?
}

struct GiphyGif: Identifiable {
    let id: String
    let previewUrl: String   // Small preview for grid (fixed_width_small ~100px)
    let fullUrl: String      // Full GIF for sending (downsized, max 2MB)
    
    init(from result: GiphyResult) {
        self.id = result.id
        // Preview: fixed_width_small (100px wide) for fast loading in grid
        self.previewUrl = result.images.fixed_width_small?.url
            ?? result.images.fixed_width?.url
            ?? result.images.original?.url
            ?? ""
        // Full: downsized (max 2MB) for sending – good balance of quality and size
        self.fullUrl = result.images.downsized?.url
            ?? result.images.fixed_width?.url
            ?? result.images.original?.url
            ?? ""
    }
}

// MARK: - Gym Invite Reminder Manager

import UserNotifications

struct GymInviteReminderManager {
    static func scheduleReminder(sessionDate: Date, gym: String, otherUsername: String, activityType: TrainingActivityType = .gym) {
        let center = UNUserNotificationCenter.current()
        
        // Schedule 1 hour before
        let reminderDate = sessionDate.addingTimeInterval(-3600)
        guard reminderDate > Date() else { return } // Don't schedule if already past
        
        let content = UNMutableNotificationContent()
        
        switch activityType {
        case .gym:
            content.title = "Gympass snart!"
            content.body = "Gympass med \(otherUsername) om 1 timme på \(gym)"
        case .running:
            content.title = "Löppass snart!"
            content.body = "Löppass med \(otherUsername) om 1 timme vid \(gym)"
        case .golf:
            content.title = "Golfrunda snart!"
            content.body = "Golfrunda med \(otherUsername) om 1 timme på \(gym)"
        }
        
        content.sound = .default
        
        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: reminderDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        
        let request = UNNotificationRequest(
            identifier: "training-invite-\(sessionDate.timeIntervalSince1970)",
            content: content,
            trigger: trigger
        )
        
        center.add(request) { error in
            if let error = error {
                print("⚠️ Failed to schedule training reminder: \(error)")
            } else {
                let formatter = DateFormatter()
                formatter.dateFormat = "HH:mm d MMM"
                print("🔔 Training reminder scheduled for \(formatter.string(from: reminderDate))")
            }
        }
    }
}
