import SwiftUI

struct ProductGridView: View {
    @Binding var showCart: Bool
    @ObservedObject private var cartManager = CartManager.shared
    @State private var products: [ShopifyProduct] = []
    @State private var searchText = ""
    @State private var selectedCategory = "Alla"
    @State private var isLoading = true
    @State private var hasNextPage = false
    @State private var endCursor: String?
    @State private var isLoadingMore = false

    private let categories = ["Alla", "Tröjor", "Byxor", "Accessoarer", "Skor", "Väskor"]
    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        VStack(spacing: 0) {
            headerBar
            ScrollView {
                VStack(spacing: 0) {
                    searchBar
                        .padding(.horizontal, 16)
                        .padding(.top, 8)

                    categoryTabs
                        .padding(.top, 12)

                    if isLoading && products.isEmpty {
                        loadingGrid
                    } else if products.isEmpty {
                        emptyState
                    } else {
                        productGrid
                    }
                }
                .padding(.bottom, 20)
            }
            .refreshable {
                await loadProducts(reset: true)
            }
        }
        .background(Color(.systemBackground))
        .task {
            if products.isEmpty { await loadProducts(reset: true) }
        }
    }

    // MARK: - Header

    private var headerBar: some View {
        HStack {
            Text("Market")
                .font(.system(size: 22, weight: .bold))

            Spacer()

            Button { showCart = true } label: {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: "bag")
                        .font(.system(size: 20))
                        .foregroundColor(.primary)

                    if cartManager.itemCount > 0 {
                        Text("\(cartManager.itemCount)")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 16, height: 16)
                            .background(Color.black)
                            .clipShape(Circle())
                            .offset(x: 6, y: -6)
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    // MARK: - Search

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.gray)
                .font(.system(size: 16))

            TextField(L.t(sv: "Sök produkter...", nb: "Søk produkter..."), text: $searchText)
                .font(.system(size: 15))
                .submitLabel(.search)
                .onSubmit { Task { await loadProducts(reset: true) } }

            if !searchText.isEmpty {
                Button {
                    searchText = ""
                    Task { await loadProducts(reset: true) }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.gray)
                        .font(.system(size: 16))
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Categories

    private var categoryTabs: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(categories, id: \.self) { category in
                    Button {
                        selectedCategory = category
                        Task { await loadProducts(reset: true) }
                    } label: {
                        Text(category)
                            .font(.system(size: 14, weight: selectedCategory == category ? .semibold : .regular))
                            .foregroundColor(selectedCategory == category ? .white : .primary)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(selectedCategory == category ? Color.black : Color(.systemGray6))
                            .clipShape(Capsule())
                    }
                }
            }
            .padding(.horizontal, 16)
        }
    }

    // MARK: - Product Grid

    private var productGrid: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L.t(sv: "Rekommenderat för dig", nb: "Anbefalt for deg"))
                .font(.system(size: 18, weight: .bold))
                .padding(.horizontal, 16)
                .padding(.top, 16)

            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(products) { product in
                    NavigationLink(value: product) {
                        ProductCard(product: product)
                    }
                    .buttonStyle(.plain)
                    .onAppear {
                        if product.id == products.last?.id && hasNextPage {
                            Task { await loadMore() }
                        }
                    }
                }
            }
            .padding(.horizontal, 16)

            if isLoadingMore {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
                .padding()
            }
        }
    }

    // MARK: - Loading / Empty

    private var loadingGrid: some View {
        LazyVGrid(columns: columns, spacing: 16) {
            ForEach(0..<6, id: \.self) { _ in
                ProductCardSkeleton()
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 20)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "storefront")
                .font(.system(size: 40))
                .foregroundColor(.gray)
            Text(L.t(sv: "Inga produkter hittades", nb: "Ingen produkter funnet"))
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
    }

    // MARK: - Data

    private func loadProducts(reset: Bool) async {
        if reset {
            isLoading = true
            endCursor = nil
        }

        let query = buildQuery()
        do {
            let result = try await ShopifyService.shared.fetchProducts(first: 20, query: query, after: reset ? nil : endCursor)
            let newProducts = result.edges.map(\.node)

            await MainActor.run {
                if reset {
                    products = newProducts
                } else {
                    products.append(contentsOf: newProducts)
                }
                hasNextPage = result.pageInfo?.hasNextPage ?? false
                endCursor = result.pageInfo?.endCursor
                isLoading = false
                isLoadingMore = false
            }
        } catch {
            print("❌ Failed to load products: \(error)")
            await MainActor.run {
                isLoading = false
                isLoadingMore = false
            }
        }
    }

    private func loadMore() async {
        guard !isLoadingMore, hasNextPage else { return }
        isLoadingMore = true
        await loadProducts(reset: false)
    }

    private func buildQuery() -> String? {
        var parts: [String] = []
        if !searchText.isEmpty { parts.append(searchText) }
        if selectedCategory != "Alla" { parts.append("product_type:\(selectedCategory)") }
        return parts.isEmpty ? nil : parts.joined(separator: " ")
    }
}

// MARK: - Product Card

struct ProductCard: View {
    let product: ShopifyProduct
    @ObservedObject private var cartManager = CartManager.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .bottomLeading) {
                if let imageURL = product.firstImage {
                    AsyncImage(url: imageURL) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFill()
                        case .failure:
                            imagePlaceholder
                        default:
                            ProgressView()
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        }
                    }
                    .frame(height: 200)
                    .clipped()
                } else {
                    imagePlaceholder
                        .frame(height: 200)
                }

                HStack(spacing: 6) {
                    Button {
                        Task {
                            guard let variant = product.firstAvailableVariant else { return }
                            await cartManager.addToCart(variantId: variant.id)
                        }
                    } label: {
                        Image(systemName: "cart.badge.plus")
                            .font(.system(size: 13))
                            .foregroundColor(.primary)
                            .padding(6)
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                    }
                }
                .padding(8)
            }
            .clipShape(RoundedRectangle(cornerRadius: 12))

            VStack(alignment: .leading, spacing: 3) {
                Text(product.vendor)
                    .font(.system(size: 11))
                    .foregroundColor(.gray)
                    .lineLimit(1)

                Text(product.title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                Text(product.formattedPrice)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.primary)
            }
            .padding(.horizontal, 4)
            .padding(.top, 8)
            .padding(.bottom, 4)
        }
    }

    private var imagePlaceholder: some View {
        Rectangle()
            .fill(Color(.systemGray5))
            .overlay {
                Image(systemName: "photo")
                    .foregroundColor(.gray)
                    .font(.system(size: 24))
            }
    }
}

// MARK: - Skeleton

struct ProductCardSkeleton: View {
    @State private var isAnimating = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            RoundedRectangle(cornerRadius: 12)
                .fill(shimmerGradient)
                .frame(height: 200)

            RoundedRectangle(cornerRadius: 4)
                .fill(shimmerGradient)
                .frame(width: 60, height: 12)

            RoundedRectangle(cornerRadius: 4)
                .fill(shimmerGradient)
                .frame(height: 14)

            RoundedRectangle(cornerRadius: 4)
                .fill(shimmerGradient)
                .frame(width: 80, height: 14)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                isAnimating = true
            }
        }
    }

    private var shimmerGradient: LinearGradient {
        LinearGradient(
            colors: [Color(.systemGray5), Color(.systemGray4), Color(.systemGray5)],
            startPoint: isAnimating ? .leading : .trailing,
            endPoint: isAnimating ? .trailing : .leading
        )
    }
}
