import SwiftUI

struct ShopifyProductSearchView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var products: [ShopifyProduct] = []
    @State private var isLoading = false
    @StateObject private var recents = RecentMarketSearchesStore.shared

    private let columns = [
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8)
    ]

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 12, pinnedViews: [.sectionHeaders]) {
                Section {
                    content
                        .padding(.horizontal, 12)
                        .padding(.top, 12)
                        .padding(.bottom, 20)
                } header: {
                    header
                }
            }
        }
        .background(Color(.systemBackground))
    }

    private var header: some View {
        VStack(spacing: 10) {
            HStack(alignment: .center, spacing: 8) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.primary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(L.t(sv: "Tillbaka", nb: "Tilbake"))

                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.gray)
                    TextField(L.t(sv: "Sök produkter", nb: "Sok produkter"), text: $query)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .onSubmit {
                            Task { await runSearch() }
                        }
                    if !query.isEmpty {
                        Button {
                            query = ""
                            products = []
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.gray)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color(.systemGray6))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.black.opacity(0.08), lineWidth: 1)
                )
            }
        }
        .padding(.horizontal, 14)
        .padding(.top, 10)
        .padding(.bottom, 8)
        .background(Color(.systemBackground))
        .overlay(alignment: .bottom) { Divider() }
    }

    @ViewBuilder
    private var content: some View {
        if isLoading && products.isEmpty {
            LazyVGrid(columns: columns, spacing: 14) {
                ForEach(0..<4, id: \.self) { _ in
                    ProductCardSkeleton()
                }
            }
        } else if query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            if recents.items.isEmpty {
                Spacer()
                    .frame(height: 40)
            } else {
                recentsSection
            }
        } else if products.isEmpty {
            VStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 28))
                    .foregroundStyle(.secondary)
                Text(L.t(sv: "Inga produkter hittades", nb: "Ingen produkter funnet"))
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 40)
        } else {
            LazyVGrid(columns: columns, spacing: 14) {
                ForEach(products, id: \.id) { product in
                    NavigationLink(value: product) {
                        ProductCard(product: product)
                    }
                    .buttonStyle(.plain)
                }
            }
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
                        query = term
                        recents.add(term)
                        Task { await runSearch() }
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

    private func runSearch() async {
        let search = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if search.isEmpty {
            products = []
            return
        }
        isLoading = true
        defer { isLoading = false }
        do {
            recents.add(search)
            let connection = try await ShopifyService.shared.fetchProducts(
                first: 50,
                query: search
            )
            products = connection.edges.map(\.node)
        } catch {
            print("[ShopifyProductSearchView] Search failed: \(error)")
            products = []
        }
    }
}
