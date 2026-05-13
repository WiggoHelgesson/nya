import SwiftUI

/// Fullskärms-söksida som pushas in från `ProductGridView`: sökfält,
/// senaste sökningar när fältet är tomt, och 2-kols resultat-grid under sökning.
struct MarketSearchView: View {
    var onSelectListing: (ConsignmentSubmissionRow) -> Void

    @ObservedObject private var listingsCache = CommunityListingsCache.shared
    @Environment(\.dismiss) private var dismiss
    @StateObject private var recents = RecentMarketSearchesStore.shared
    @State private var searchText: String = ""
    @FocusState private var focused: Bool

    private let resultColumns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10)
    ]

    var body: some View {
        VStack(spacing: 0) {
            topSearchBar
            Divider()

            if searchText.trimmingCharacters(in: .whitespaces).isEmpty {
                idleContent
            } else {
                resultsGrid
            }
        }
        .background(Color(.systemBackground))
        .navigationBarHidden(true)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                focused = true
            }
        }
    }

    // MARK: - Top bar

    private var topSearchBar: some View {
        HStack(spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.gray)
                    .font(.system(size: 16))

                TextField(L.t(sv: "Sök på hela Up&Down", nb: "Søk på hele Up&Down"),
                          text: $searchText)
                    .font(.system(size: 15))
                    .focused($focused)
                    .submitLabel(.search)
                    .onSubmit {
                        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
                        if !trimmed.isEmpty { recents.add(trimmed) }
                    }

                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray)
                            .font(.system(size: 16))
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color(.systemGray6))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.black.opacity(0.08), lineWidth: 1)
            )

            Button {
                focused = false
                dismiss()
            } label: {
                Text(L.t(sv: "Avbryt", nb: "Avbryt"))
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.primary)
            }
        }
        .padding(.horizontal, 14)
        .padding(.top, 10)
        .padding(.bottom, 10)
    }

    // MARK: - Idle content (no search term)

    private var idleContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                if !recents.items.isEmpty {
                    recentsSection
                }
            }
            .padding(.horizontal, 14)
            .padding(.top, 16)
            .padding(.bottom, 40)
        }
    }

    private var recentsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(L.t(sv: "Senaste sökningar", nb: "Siste søk"))
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)
                Spacer()
                Button {
                    recents.clearAll()
                } label: {
                    Text(L.t(sv: "Ta bort alla", nb: "Fjern alle"))
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)
                }
            }

            VStack(spacing: 0) {
                ForEach(recents.items, id: \.self) { term in
                    Button {
                        searchText = term
                        recents.add(term)
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "magnifyingglass")
                                .foregroundColor(.secondary)
                                .font(.system(size: 15))
                            Text(term)
                                .font(.system(size: 15))
                                .foregroundColor(.primary)
                            Spacer()
                            Button {
                                recents.remove(term)
                            } label: {
                                Image(systemName: "xmark")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(.secondary)
                                    .padding(6)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.vertical, 12)
                    }
                    .buttonStyle(.plain)

                    if term != recents.items.last {
                        Divider()
                    }
                }
            }
        }
    }

    // MARK: - Results grid

    private var filteredListings: [ConsignmentSubmissionRow] {
        let query = searchText.trimmingCharacters(in: .whitespaces).lowercased()
        guard !query.isEmpty else { return [] }
        return listingsCache.listings.filter { row in
            let haystacks: [String?] = [
                row.title,
                row.description,
                row.category,
                SportCategory.all.first(where: { $0.id == row.category })?.displayName,
                row.userBrand,
                row.userCondition,
                SellCondition.localizedTitle(raw: row.userCondition),
                row.material
            ]
            if haystacks.compactMap({ $0?.lowercased() }).contains(where: { $0.contains(query) }) {
                return true
            }
            return row.colors.contains(where: { $0.lowercased().contains(query) })
        }
    }

    @ViewBuilder
    private var resultsGrid: some View {
        let rows = filteredListings
        ScrollView {
            if rows.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 28))
                        .foregroundStyle(.secondary)
                    Text(L.t(sv: "Inga annonser matchade sökningen",
                             nb: "Ingen annonser matchet søket"))
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 50)
                .padding(.horizontal, 24)
            } else {
                LazyVGrid(columns: resultColumns, spacing: 14) {
                    ForEach(rows) { row in
                        Button {
                            focused = false
                            let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
                            if !trimmed.isEmpty { recents.add(trimmed) }
                            onSelectListing(row)
                        } label: {
                            CommunityListingCard(row: row)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.top, 12)
                .padding(.bottom, 40)
            }
        }
    }
}
