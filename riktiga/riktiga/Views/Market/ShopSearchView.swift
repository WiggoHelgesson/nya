import SwiftUI

/// Fullskärms-söksida för Vår shop (Sellpy-style): sökfält med bakåtpil,
/// kategorichips som snabbsökningar, senaste sökningar när fältet är tomt,
/// och 2-kolumns resultatgrid med live-sökning mot Shopify.
struct ShopSearchView: View {
    @Binding var showCart: Bool
    @EnvironmentObject var authViewModel: AuthViewModel
    @Environment(\.dismiss) private var dismiss

    @StateObject private var recents = RecentMarketSearchesStore.shared
    @ObservedObject private var store = ShopifyFeedStore.shared

    @State private var searchText = ""
    @State private var results: [ShopifyProduct] = []
    @State private var isSearching = false
    @State private var hasSearched = false
    @State private var searchTask: Task<Void, Never>?
    @FocusState private var focused: Bool

    private let resultColumns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10)
    ]

    private var trimmedQuery: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        VStack(spacing: 0) {
            topSearchBar
            Divider()

            if trimmedQuery.isEmpty {
                idleContent
            } else {
                resultsContent
            }
        }
        .background(Color(.systemBackground))
        .navigationBarHidden(true)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                focused = true
            }
        }
        .onChange(of: searchText) { _, _ in
            scheduleSearch()
        }
    }

    // MARK: - Top bar

    private var topSearchBar: some View {
        HStack(spacing: 10) {
            Button {
                focused = false
                dismiss()
            } label: {
                Image(systemName: "arrow.left")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.primary)
                    .frame(width: 30, height: 30)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            TextField(L.t(sv: "Sök", nb: "Søk"), text: $searchText)
                .font(.system(size: 15))
                .focused($focused)
                .submitLabel(.search)
                .onSubmit {
                    if !trimmedQuery.isEmpty { recents.add(trimmedQuery) }
                }

            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.gray)
                        .font(.system(size: 16))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color(.systemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.primary.opacity(0.7), lineWidth: 1.2)
        )
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    // MARK: - Idle (inget sökord)

    private var idleContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                suggestionChips

                if !recents.items.isEmpty {
                    recentsSection
                }
            }
            .padding(.horizontal, 14)
            .padding(.top, 12)
            .padding(.bottom, 40)
        }
    }

    private var suggestionChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(ShopCategory.allCases.filter { $0 != .all }) { category in
                    Button {
                        searchText = category.title
                        recents.add(category.title)
                    } label: {
                        Text(category.title)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.primary)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 9)
                            .background(
                                Capsule()
                                    .fill(Color(red: 0.85, green: 0.92, blue: 0.98))
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var recentsSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(L.t(sv: "Senaste sökningar", nb: "Siste søk"))
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                Spacer()
                Button {
                    recents.clearAll()
                } label: {
                    Text(L.t(sv: "Ta bort alla", nb: "Fjern alle"))
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }

            VStack(spacing: 0) {
                ForEach(recents.items, id: \.self) { term in
                    Button {
                        searchText = term
                        recents.add(term)
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "clock.arrow.circlepath")
                                .foregroundColor(.secondary)
                                .font(.system(size: 15))
                            Text(term)
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(.primary)
                            Spacer()
                            Button {
                                recents.remove(term)
                            } label: {
                                Image(systemName: "xmark")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(.secondary)
                                    .padding(6)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.vertical, 10)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Resultat

    @ViewBuilder
    private var resultsContent: some View {
        ScrollView {
            if isSearching && results.isEmpty {
                LazyVGrid(columns: resultColumns, spacing: 14) {
                    ForEach(0..<4, id: \.self) { _ in
                        ProductCardSkeleton()
                    }
                }
                .padding(.horizontal, 14)
                .padding(.top, 12)
            } else if results.isEmpty && hasSearched {
                VStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 28))
                        .foregroundStyle(.secondary)
                    Text(L.t(sv: "Inga produkter matchade sökningen",
                             nb: "Ingen produkter matchet søket"))
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 50)
                .padding(.horizontal, 24)
            } else {
                LazyVGrid(columns: resultColumns, spacing: 18) {
                    ForEach(results) { product in
                        NavigationLink(value: product) {
                            ProductCard(
                                product: product,
                                onQuickAdd: { variant in
                                    Task {
                                        await CartManager.shared.addToCart(variantId: variant.id)
                                        showCart = true
                                    }
                                }
                            )
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .buttonStyle(.plain)
                        .simultaneousGesture(TapGesture().onEnded {
                            if !trimmedQuery.isEmpty { recents.add(trimmedQuery) }
                        })
                    }
                }
                .padding(.horizontal, 14)
                .padding(.top, 12)
                .padding(.bottom, 40)
            }
        }
        .scrollDismissesKeyboard(.immediately)
    }

    // MARK: - Sökning (debounce + Shopify)

    private func scheduleSearch() {
        searchTask?.cancel()
        let query = trimmedQuery
        guard !query.isEmpty else {
            results = []
            isSearching = false
            hasSearched = false
            return
        }

        isSearching = true
        searchTask = Task {
            try? await Task.sleep(nanoseconds: 350_000_000)
            guard !Task.isCancelled else { return }
            await runSearch(query: query)
        }
    }

    private func runSearch(query: String) async {
        defer { isSearching = false }

        var found: [ShopifyProduct] = []
        do {
            let connection = try await ShopifyService.shared.fetchProducts(first: 30, query: query)
            found = connection.edges.map(\.node)
        } catch {
            print("[ShopSearchView] Shopify search failed: \(error)")
        }

        // Komplettera med lokala träffar från redan laddade kollektioner
        // (täcker t.ex. produkter som inte är publicerade till Headless-kanalen).
        let lowered = query.lowercased()
        let local = store.productsByHandle.values.joined().filter { product in
            product.title.lowercased().contains(lowered)
            || product.vendor.lowercased().contains(lowered)
            || product.productType.lowercased().contains(lowered)
            || product.tags.contains(where: { $0.lowercased().contains(lowered) })
        }

        var seen = Set<String>()
        var merged: [ShopifyProduct] = []
        for product in found + Array(local) {
            guard !seen.contains(product.id) else { continue }
            seen.insert(product.id)
            merged.append(product)
        }

        guard !Task.isCancelled, query == trimmedQuery else { return }
        results = merged
        hasSearched = true

        await ProductFavoritesService.shared.loadCounts(handles: merged.map(\.handle))
    }
}
