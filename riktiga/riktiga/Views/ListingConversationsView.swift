import SwiftUI

/// Bild 2: alla konversationer för en specifik annons. Tap på en rad pushar
/// befintlig `DirectMessageView`. Uppdateras automatiskt via timer eftersom
/// DM-systemet fortfarande är polling-baserat.
struct ListingConversationsView: View {
    let group: ListingInboxGroup

    @EnvironmentObject var authViewModel: AuthViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var conversations: [DirectConversation]
    @State private var refreshTimer: Timer?

    init(group: ListingInboxGroup) {
        self.group = group
        self._conversations = State(initialValue: group.conversations)
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            Divider()
                .opacity(0.2)

            if conversations.isEmpty {
                Spacer()
                emptyState
                Spacer()
            } else {
                conversationList
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
        .navigationBarHidden(true)
        .task {
            await refresh()
            startRefreshTimer()
        }
        .onDisappear {
            stopRefreshTimer()
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 12) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.primary)
                    .frame(width: 36, height: 36)
            }

            Spacer(minLength: 0)

            Text(group.title)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.primary)
                .lineLimit(1)

            Spacer(minLength: 0)

            // Placeholder to balance the back button visually
            Color.clear.frame(width: 36, height: 36)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    // MARK: - List

    private var conversationList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(conversations) { convo in
                    NavigationLink(value: convo) {
                        ListingConversationRow(conversation: convo)
                    }
                    .buttonStyle(.plain)

                    Divider()
                        .padding(.leading, 86)
                        .opacity(0.15)
                }
            }
            .padding(.top, 6)
        }
        .refreshable {
            await refresh()
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 40, weight: .light))
                .foregroundColor(.secondary)

            Text(L.t(sv: "Inga konversationer än", nb: "Ingen samtaler ennå"))
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.primary)
        }
    }

    // MARK: - Refresh

    private func refresh() async {
        do {
            let groups = try await DirectMessageService.shared.fetchListingInboxGroups()
            if let updated = groups.first(where: { $0.listingId == group.listingId }) {
                await MainActor.run {
                    self.conversations = updated.conversations
                }
            }
        } catch {
            print("❌ ListingConversationsView refresh failed: \(error)")
        }
    }

    private func startRefreshTimer() {
        stopRefreshTimer()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { _ in
            Task { await refresh() }
        }
    }

    private func stopRefreshTimer() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }
}

// MARK: - Row

private struct ListingConversationRow: View {
    let conversation: DirectConversation

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            avatar

            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 6) {
                    Text(conversation.displayName)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.primary)
                        .lineLimit(1)

                    Spacer(minLength: 0)

                    if let date = conversation.lastMessageAt {
                        Text(relativeDate(date))
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }
                }

                HStack(spacing: 6) {
                    Text({
                        let formatted = MessagePreviewFormatter.preview(from: conversation.lastMessage ?? "")
                        return formatted.isEmpty ? " " : formatted
                    }())
                        .font(.system(size: 15))
                        .foregroundColor(.secondary)
                        .lineLimit(1)

                    Spacer(minLength: 0)

                    if let unread = conversation.unreadCount, unread > 0 {
                        Text("\(unread)")
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
    private var avatar: some View {
        CachedRemoteImage(url: conversation.otherAvatarUrl) {
            ZStack {
                Circle().fill(Color(.systemGray5))
                Image(systemName: "person.fill")
                    .font(.system(size: 22))
                    .foregroundColor(.secondary)
            }
        }
        .frame(width: 56, height: 56)
        .clipShape(Circle())
    }

    private func relativeDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        formatter.locale = Locale(identifier: "sv_SE")
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}
