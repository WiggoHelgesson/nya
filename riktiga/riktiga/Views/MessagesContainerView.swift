import SwiftUI

/// Meddelanden-tabben: översikt av alla marknadsplats-annonser som användaren
/// har minst en chatt på. Matchar designen: Bild 1 (annons-rader) →
/// `ListingConversationsView` (Bild 2) → `DirectMessageView` (Bild 3).
///
/// Coach/tränar-/vanliga DMs ligger kvar under Social → Meddelanden
/// (`MessagesListView`), så den vyn ändras inte.
struct MessagesContainerView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    let popToRootTrigger: Int

    @StateObject private var dmService = DirectMessageService.shared
    @State private var navigationPath = NavigationPath()
    @State private var groups: [ListingInboxGroup] = []
    @State private var isLoading = true
    @State private var loadError: String?
    @State private var refreshTimer: Timer?

    var body: some View {
        NavigationStack(path: $navigationPath) {
            VStack(spacing: 0) {
                header

                Divider()
                    .opacity(0.2)

                content
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(.systemBackground))
            .navigationBarHidden(true)
            .navigationDestination(for: ListingInboxGroup.self) { group in
                ListingConversationsView(group: group)
                    .environmentObject(authViewModel)
            }
            .navigationDestination(for: DirectConversation.self) { convo in
                DirectMessageView(
                    conversationId: convo.id,
                    otherUserId: convo.otherUserId ?? "",
                    otherUsername: convo.displayName,
                    otherAvatarUrl: convo.otherAvatarUrl,
                    listingId: convo.listingId
                )
                .environmentObject(authViewModel)
            }
        }
        .id(popToRootTrigger)
        .onChange(of: popToRootTrigger) { _, _ in
            navigationPath = NavigationPath()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("PushOpenMarketplaceListingDM"))) { note in
            guard let listingIdStr = note.userInfo?["listing_id"] as? String,
                  let listingUUID = UUID(uuidString: listingIdStr),
                  let otherUserId = note.userInfo?["other_user_id"] as? String
            else { return }
            Task {
                do {
                    let convId = try await dmService.getOrCreateConversation(
                        withUserId: otherUserId,
                        listingId: listingUUID
                    )
                    var list = try await dmService.fetchConversations()
                    var conv = list.first(where: { $0.id == convId })
                    if conv == nil {
                        list = try await dmService.fetchConversations()
                        conv = list.first(where: { $0.id == convId })
                    }
                    await MainActor.run {
                        guard let conv else { return }
                        navigationPath = NavigationPath()
                        navigationPath.append(conv)
                    }
                } catch {
                    print("❌ PushOpenMarketplaceListingDM: \(error)")
                }
            }
        }
        .onAppear {
            NavigationDepthTracker.shared.hideTabBar = !navigationPath.isEmpty
        }
        .onChange(of: navigationPath.count) { _, count in
            NavigationDepthTracker.shared.hideTabBar = count > 0
        }
        .task {
            await load()
            startRefreshTimer()
        }
        .onDisappear {
            stopRefreshTimer()
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Spacer()
            Text(L.t(sv: "Meddelanden", nb: "Meldinger"))
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(.primary)
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.top, 10)
        .padding(.bottom, 14)
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        if isLoading && groups.isEmpty {
            Spacer()
            ProgressView()
                .scaleEffect(1.1)
            Spacer()
        } else if groups.isEmpty {
            Spacer()
            emptyState
            Spacer()
        } else {
            listingList
        }
    }

    private var listingList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(groups) { group in
                    Button {
                        if group.conversationCount == 1, let convo = group.conversations.first {
                            navigationPath.append(convo)
                        } else {
                            navigationPath.append(group)
                        }
                    } label: {
                        ListingInboxRow(group: group)
                    }
                    .buttonStyle(.plain)

                    Divider()
                        .padding(.leading, 108)
                        .opacity(0.15)
                }
            }
            .padding(.top, 6)
        }
        .refreshable {
            await load()
        }
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "envelope")
                .font(.system(size: 44, weight: .light))
                .foregroundColor(.secondary)

            Text(L.t(sv: "Inga meddelanden än", nb: "Ingen meldinger ennå"))
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(.primary)

            Text(L.t(
                sv: "När någon skriver till dig om en annons hamnar chatten här.",
                nb: "Når noen skriver til deg om en annonse havner chatten her."
            ))
            .font(.system(size: 14))
            .foregroundColor(.secondary)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 40)

            if let loadError = loadError {
                Text(loadError)
                    .font(.system(size: 12))
                    .foregroundColor(.red)
                    .padding(.top, 4)
            }
        }
    }

    // MARK: - Data

    private func load() async {
        do {
            let fetched = try await DirectMessageService.shared.fetchListingInboxGroups()
            await MainActor.run {
                self.groups = fetched
                self.isLoading = false
                self.loadError = nil
            }
        } catch {
            await MainActor.run {
                self.isLoading = false
                self.loadError = error.localizedDescription
                print("❌ MessagesContainerView load failed: \(error)")
            }
        }
    }

    private func startRefreshTimer() {
        stopRefreshTimer()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { _ in
            Task { await load() }
        }
    }

    private func stopRefreshTimer() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }
}

// MARK: - Listing Inbox Row (Bild 1)

private struct ListingInboxRow: View {
    let group: ListingInboxGroup

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            cover

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Text(group.title)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.primary)
                        .lineLimit(1)

                    if group.isSold {
                        Text(L.t(sv: "Såld", nb: "Solgt"))
                            .font(.system(size: 11, weight: .bold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.black)
                            .foregroundColor(.white)
                            .clipShape(Capsule())
                    }

                    Spacer(minLength: 0)

                    if let date = group.latestAt {
                        Text(relativeDate(date))
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }
                }

                HStack(spacing: 6) {
                    Text(subtitle)
                        .font(.system(size: 16))
                        .foregroundColor(.secondary)
                        .lineLimit(1)

                    Spacer(minLength: 0)

                    if group.unreadCount > 0 {
                        Text("\(group.unreadCount)")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 9)
                            .padding(.vertical, 3)
                            .background(Color.black)
                            .clipShape(Capsule())
                    }
                }
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private var cover: some View {
        CachedRemoteImage(url: group.coverUrl) {
            Rectangle()
                .fill(Color(.systemGray6))
        }
        .frame(width: 78, height: 78)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var subtitle: String {
        let first = group.conversations.first
        if let raw = first?.lastMessage, !raw.isEmpty {
            let formatted = MessagePreviewFormatter.preview(from: raw)
            let body = formatted.isEmpty ? raw : formatted
            if let sender = first?.lastMessageSenderName, !sender.isEmpty {
                return "\(sender): \(body)"
            }
            return body
        }
        let count = group.conversationCount
        if count == 1 {
            return L.t(sv: "1 konversation", nb: "1 samtale")
        }
        return L.t(sv: "\(count) konversationer", nb: "\(count) samtaler")
    }

    private func relativeDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        formatter.locale = Locale(identifier: "sv_SE")
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}
