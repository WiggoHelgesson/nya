import SwiftUI

enum LeaderboardScope: String, CaseIterable {
    case all
    case school

    var label: String {
        switch self {
        case .all: return L.t(sv: "Alla", nb: "Alle")
        case .school: return L.t(sv: "Din skola", nb: "Din skole")
        }
    }
}

struct LeaderboardView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @Environment(\.colorScheme) private var colorScheme
    @State private var selectedScope: LeaderboardScope = .all
    @State private var schoolUserIds: [String]? = nil
    @State private var isLoadingSchoolIds = false

    private var isDark: Bool { colorScheme == .dark }

    var body: some View {
        VStack(spacing: 0) {
            StravaStyleHeaderView(pageTitle: L.t(sv: "Topplistor", nb: "Topplister"))
            
            ScrollView {
                VStack(spacing: 20) {
                    header
                    categoryCards
                }
                .padding(.bottom, 30)
            }
        }
        .background(isDark ? Color.black : Color(.systemBackground))
        .task {
            await preloadSchoolIds()
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 4) {
            Text(L.t(sv: "Topplistor", nb: "Topplister"))
                .font(.system(size: 28, weight: .bold))
                .frame(maxWidth: .infinity, alignment: .leading)

            Text(currentMonthName)
                .font(.system(size: 15))
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
    }

    private var currentMonthName: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "sv_SE")
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: Date()).capitalized
    }

    // MARK: - Scope Picker

    private var scopePicker: some View {
        HStack(spacing: 0) {
            ForEach(LeaderboardScope.allCases, id: \.self) { scope in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedScope = scope
                    }
                } label: {
                    Text(scope.label)
                        .font(.system(size: 15, weight: selectedScope == scope ? .semibold : .medium))
                        .foregroundColor(selectedScope == scope ? (isDark ? .black : .white) : .primary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            selectedScope == scope
                                ? (isDark ? Color.white : Color.black)
                                : Color.clear
                        )
                        .clipShape(Capsule())
                }
            }
        }
        .padding(3)
        .background(Color(.systemGray5))
        .clipShape(Capsule())
        .padding(.horizontal, 20)
    }

    // MARK: - Category Cards

    private var categoryCards: some View {
        VStack(spacing: 16) {
            ForEach(LeaderboardCategory.allCases) { category in
                NavigationLink(value: category) {
                    categoryCard(category)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 20)
    }

    private func categoryCard(_ category: LeaderboardCategory) -> some View {
        ZStack(alignment: .bottomLeading) {
            Image(category.imageName)
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity)
                .frame(height: 180)
                .clipped()
                .contentShape(Rectangle())

            LinearGradient(
                colors: [.black.opacity(0.7), .clear],
                startPoint: .bottom,
                endPoint: .center
            )

            VStack(alignment: .leading, spacing: 4) {
                Text(category.title)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)

                HStack(spacing: 4) {
                    Text(L.t(sv: "Se topplistan", nb: "Se topplisten"))
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.8))
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white.opacity(0.8))
                }
            }
            .padding(20)
        }
        .frame(height: 180)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
        .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    // MARK: - School IDs

    private func preloadSchoolIds() async {
        guard schoolUserIds == nil, !isLoadingSchoolIds else { return }
        isLoadingSchoolIds = true
        do {
            let ids = try await LeaderboardService.shared.fetchSchoolUserIds()
            await MainActor.run { schoolUserIds = ids }
        } catch {
            print("Failed to load school user IDs: \(error)")
        }
        isLoadingSchoolIds = false
    }

    var scopeUserIds: [String]? {
        selectedScope == .school ? schoolUserIds : nil
    }
}
