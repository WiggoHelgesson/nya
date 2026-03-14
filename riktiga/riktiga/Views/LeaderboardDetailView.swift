import SwiftUI

struct LeaderboardDetailView: View {
    let category: LeaderboardCategory
    @EnvironmentObject var authViewModel: AuthViewModel
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss

    @State private var selectedScope: LeaderboardScope = .all
    @State private var entries: [LeaderboardEntry] = []
    @State private var isLoading = true
    @State private var schoolUserIds: [String]? = nil
    @State private var rowsVisible: [Bool] = []
    @State private var headerVisible = false

    private var isDark: Bool { colorScheme == .dark }
    private var currentUserId: String? { authViewModel.currentUser?.id }

    var body: some View {
        VStack(spacing: 0) {
            scopeTabs
                .opacity(headerVisible ? 1 : 0)
                .offset(y: headerVisible ? 0 : -8)
            divider
            tableHeader
                .opacity(headerVisible ? 1 : 0)
            divider

            if isLoading {
                Spacer()
                ProgressView()
                    .transition(.opacity)
                Spacer()
            } else if entries.isEmpty {
                Spacer()
                emptyState
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
                Spacer()
            } else {
                leaderboardList
            }
        }
        .background(isDark ? Color.black : Color(.systemBackground))
        .navigationTitle(category.title)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadSchoolIds()
            await loadEntries()
        }
        .onChange(of: selectedScope) { _, _ in
            withAnimation(.easeOut(duration: 0.2)) {
                rowsVisible = Array(repeating: false, count: entries.count)
            }
            Task {
                await loadEntries()
            }
        }
    }

    // MARK: - Scope Tabs

    private var scopeTabs: some View {
        HStack(spacing: 0) {
            scopeTab(.all, label: L.t(sv: "Alla", nb: "Alle"))
            scopeTab(.school, label: L.t(sv: "Din skola", nb: "Din skole"))
        }
        .padding(.top, 8)
    }

    private func scopeTab(_ scope: LeaderboardScope, label: String) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedScope = scope
            }
        } label: {
            VStack(spacing: 8) {
                Text(label)
                    .font(.system(size: 16, weight: selectedScope == scope ? .semibold : .regular))
                    .foregroundColor(selectedScope == scope ? .primary : .secondary)

                Rectangle()
                    .fill(selectedScope == scope ? Color.primary : Color.clear)
                    .frame(height: 2)
                    .animation(.easeInOut(duration: 0.25), value: selectedScope)
            }
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: - Table Header

    private var tableHeader: some View {
        HStack {
            Text(L.t(sv: "RANK", nb: "RANK"))
                .frame(width: 44, alignment: .leading)
            Text(L.t(sv: "ANVÄNDARE", nb: "BRUKER"))
            Spacer()
            Text(category.valueHeader)
                .frame(alignment: .trailing)
        }
        .font(.system(size: 11, weight: .medium))
        .foregroundColor(.secondary)
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
    }

    private var divider: some View {
        Rectangle()
            .fill(Color(.separator))
            .frame(height: 0.5)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "trophy")
                .font(.system(size: 40))
                .foregroundColor(.secondary)
            Text(L.t(sv: "Inga resultat ännu denna månaden", nb: "Ingen resultater denne måneden ennå"))
                .font(.system(size: 16))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 32)
    }

    // MARK: - Leaderboard List

    private var leaderboardList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                    NavigationLink(destination: UserProfileView(userId: entry.user_id).environmentObject(authViewModel)) {
                        leaderboardRow(rank: index + 1, entry: entry)
                            .opacity(index < rowsVisible.count && rowsVisible[index] ? 1 : 0)
                            .offset(y: index < rowsVisible.count && rowsVisible[index] ? 0 : 12)
                    }
                    .buttonStyle(.plain)
                    divider
                        .opacity(index < rowsVisible.count && rowsVisible[index] ? 1 : 0)
                }
            }
        }
    }

    private func leaderboardRow(rank: Int, entry: LeaderboardEntry) -> some View {
        let isCurrentUser = entry.user_id == currentUserId
        let isPro = entry.is_pro_member ?? false

        return HStack(spacing: 12) {
            Text("\(rank)")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.secondary)
                .frame(width: 28, alignment: .leading)

            ProfileAvatarView(path: entry.avatar_url ?? "", size: 40, isPro: isPro)

            HStack(spacing: 5) {
                Text(entry.username ?? L.t(sv: "Användare", nb: "Bruker"))
                    .font(.system(size: 16, weight: isCurrentUser ? .bold : .regular))
                    .foregroundColor(.primary)
                    .lineLimit(1)

                if isPro {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.blue)
                }
            }

            Spacer()

            Text(entry.displayValue)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.primary)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(isCurrentUser ? Color(.systemGray6) : Color.clear)
    }

    // MARK: - Animations

    private func animateRowsIn() {
        rowsVisible = Array(repeating: false, count: entries.count)

        withAnimation(.easeOut(duration: 0.35)) {
            headerVisible = true
        }

        for index in entries.indices {
            let delay = 0.08 + Double(index) * 0.04
            withAnimation(.spring(response: 0.4, dampingFraction: 0.82).delay(delay)) {
                if index < rowsVisible.count {
                    rowsVisible[index] = true
                }
            }
        }
    }

    // MARK: - Data Loading

    private func loadSchoolIds() async {
        do {
            let ids = try await LeaderboardService.shared.fetchSchoolUserIds()
            await MainActor.run { schoolUserIds = ids }
        } catch {
            print("Failed to load school IDs: \(error)")
        }
    }

    private func loadEntries() async {
        await MainActor.run { isLoading = true }
        do {
            let ids = selectedScope == .school ? schoolUserIds : nil
            let result = try await LeaderboardService.shared.fetchLeaderboard(category: category, userIds: ids)
            await MainActor.run {
                entries = result
                isLoading = false
                animateRowsIn()
            }
        } catch {
            print("Failed to load leaderboard: \(error)")
            await MainActor.run { isLoading = false }
        }
    }
}
