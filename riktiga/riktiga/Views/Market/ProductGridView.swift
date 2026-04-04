import SwiftUI

struct ProductGridView: View {
    @Binding var showCart: Bool
    @ObservedObject private var cartManager = CartManager.shared
    @State private var products: [ShopifyProduct] = []
    @State private var searchText = ""
    @State private var selectedTab = "Alla"
    @State private var selectedSubcategory: String?
    @State private var isLoading = true
    @State private var hasNextPage = false
    @State private var endCursor: String?
    @State private var isLoadingMore = false
    @State private var showSearchOverlay = false
    @State private var showMarketInfo = false
    @FocusState private var isSearchFocused: Bool

    private let popularBrands = [
        "Nike", "Adidas", "J.Lindeberg", "Puma", "Under Armour",
        "The North Face", "Salomon", "Helly Hansen", "Peak Performance", "Craft"
    ]
    private let popularSearches = [
        "Löparskor", "Tights", "Träningströja", "Jacka", "Shorts",
        "Hoodie", "Ryggsäck", "Sportbh"
    ]

    private let tabs = ["Alla", "Herr", "Dam", "Accessoarer", "Skor"]

    private let subcategories: [(icon: String, title: String, query: String)] = [
        ("figure.golf", "Golf", "Golf"),
        ("dumbbell", "Gym", "Gym"),
        ("figure.run", "Löpning", "Löpning"),
        ("figure.open.water.swim", "Triathlon", "Triathlon")
    ]

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        VStack(spacing: 0) {
            if showSearchOverlay {
                searchOverlay
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        searchBar
                            .padding(.horizontal, 16)
                            .padding(.top, 8)
                            .zIndex(1)

                        marketBanner
                            .padding(.horizontal, 16)
                            .padding(.top, 12)

                        sectionTitle(L.t(sv: "Utforska kategorier", nb: "Utforsk kategorier"))
                            .padding(.top, 20)

                        tabBar
                            .padding(.top, 8)

                        categoryBoxes
                            .padding(.top, 12)
                            .padding(.horizontal, 16)

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
        }
        .background(Color(.systemBackground))
        .sheet(isPresented: $showMarketInfo) {
            MarketInfoSheet()
        }
        .task {
            if products.isEmpty { await loadProducts(reset: true) }
        }
    }

    // MARK: - Search

    private var searchBar: some View {
        Button {
            showSearchOverlay = true
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.gray)
                    .font(.system(size: 16))

                Text(searchText.isEmpty ? L.t(sv: "Vad vill du handla?", nb: "Hva vil du handle?") : searchText)
                    .font(.system(size: 15))
                    .foregroundColor(searchText.isEmpty ? .gray : .primary)

                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(Color(.systemGray6))
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Market Banner

    private var marketBanner: some View {
        Button {
            showMarketInfo = true
        } label: {
            Image("94")
                .resizable()
                .scaledToFill()
                .frame(height: 180)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .contentShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Section Title

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 20, weight: .bold))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
    }

    // MARK: - Search Overlay

    private var searchOverlay: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Button {
                    isSearchFocused = false
                    showSearchOverlay = false
                    searchText = ""
                } label: {
                    Image(systemName: "arrow.left")
                        .font(.system(size: 18))
                        .foregroundColor(.primary)
                }

                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.gray)
                        .font(.system(size: 16))

                    TextField(L.t(sv: "Sök", nb: "Søk"), text: $searchText)
                        .font(.system(size: 15))
                        .focused($isSearchFocused)
                        .submitLabel(.search)
                        .onSubmit {
                            isSearchFocused = false
                            showSearchOverlay = false
                            Task { await loadProducts(reset: true) }
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
                .background(Color(.systemGray6))
                .clipShape(Capsule())
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(L.t(sv: "Populära varumärken", nb: "Populære merker"))
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.gray)

                        FlowLayout(spacing: 8) {
                            ForEach(popularBrands, id: \.self) { brand in
                                Button {
                                    searchText = brand
                                    isSearchFocused = false
                                    showSearchOverlay = false
                                    Task { await loadProducts(reset: true) }
                                } label: {
                                    Text(brand)
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(.primary)
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 8)
                                        .background(Color(.systemGray6))
                                        .clipShape(Capsule())
                                }
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text(L.t(sv: "Populära sökningar", nb: "Populære søk"))
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.gray)

                        FlowLayout(spacing: 8) {
                            ForEach(popularSearches, id: \.self) { term in
                                Button {
                                    searchText = term
                                    isSearchFocused = false
                                    showSearchOverlay = false
                                    Task { await loadProducts(reset: true) }
                                } label: {
                                    Text(term)
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(.primary)
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 8)
                                        .background(Color(.systemGray6))
                                        .clipShape(Capsule())
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isSearchFocused = true
            }
        }
    }

    // MARK: - Tab Bar (underline style)

    private var tabBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 24) {
                ForEach(tabs, id: \.self) { tab in
                    Button {
                        selectedTab = tab
                        selectedSubcategory = nil
                        Task { await loadProducts(reset: true) }
                    } label: {
                        VStack(spacing: 6) {
                            Text(tab)
                                .font(.system(size: 15, weight: selectedTab == tab ? .semibold : .regular))
                                .foregroundColor(selectedTab == tab ? .primary : .gray)

                            Rectangle()
                                .fill(selectedTab == tab ? Color.primary : Color.clear)
                                .frame(height: 2)
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
        }
    }

    // MARK: - Category Boxes

    private var categoryBoxes: some View {
        let boxColumns = [
            GridItem(.flexible(), spacing: 10),
            GridItem(.flexible(), spacing: 10)
        ]

        return LazyVGrid(columns: boxColumns, spacing: 10) {
            ForEach(subcategories, id: \.title) { cat in
                Button {
                    if selectedSubcategory == cat.query {
                        selectedSubcategory = nil
                    } else {
                        selectedSubcategory = cat.query
                    }
                    Task { await loadProducts(reset: true) }
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: cat.icon)
                            .font(.system(size: 18))
                            .foregroundColor(.primary)
                            .frame(width: 28)

                        Text(cat.title)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.primary)
                            .lineLimit(1)

                        Spacer()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 14)
                    .background(selectedSubcategory == cat.query ? Color(.systemGray4) : Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }
        }
    }

    // MARK: - Product Grid

    private var firstRowProducts: [ShopifyProduct] {
        Array(products.prefix(2))
    }

    private var sliderProducts: [ShopifyProduct] {
        Array(products.dropFirst(2).prefix(8))
    }

    private var midProducts: [ShopifyProduct] {
        Array(products.dropFirst(2).prefix(8))
    }

    private var afterPromoProducts: [ShopifyProduct] {
        Array(products.dropFirst(10))
    }

    private var productGrid: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(L.t(sv: "Rekommenderat för dig", nb: "Anbefalt for deg"))
                .font(.system(size: 20, weight: .bold))
                .padding(.horizontal, 16)
                .padding(.top, 20)

            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(firstRowProducts) { product in
                    NavigationLink(value: product) {
                        ProductCard(product: product)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)

            if !sliderProducts.isEmpty {
                recommendedSlider
                    .padding(.top, 24)
            }

            if !midProducts.isEmpty {
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(midProducts) { product in
                        NavigationLink(value: product) {
                            ProductCard(product: product)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 20)
            }

            sellBagPromo
                .padding(.top, 24)

            if !afterPromoProducts.isEmpty {
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(afterPromoProducts) { product in
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
                .padding(.top, 20)
            }

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

    // MARK: - Recommended Slider

    private var recommendedSlider: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L.t(sv: "Rekommenderade för dig", nb: "Anbefalt for deg"))
                .font(.system(size: 18, weight: .bold))
                .padding(.horizontal, 16)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(sliderProducts) { product in
                        NavigationLink(value: product) {
                            VStack(alignment: .leading, spacing: 6) {
                                ZStack(alignment: .bottomTrailing) {
                                    if let imageURL = product.firstImage {
                                        AsyncImage(url: imageURL) { phase in
                                            switch phase {
                                            case .success(let image):
                                                image
                                                    .resizable()
                                                    .scaledToFill()
                                            case .failure:
                                                sliderPlaceholder
                                            default:
                                                ProgressView()
                                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                                            }
                                        }
                                        .frame(width: 140, height: 140)
                                        .clipped()
                                    } else {
                                        sliderPlaceholder
                                    }
                                }
                                .clipShape(RoundedRectangle(cornerRadius: 12))

                                Text(product.title)
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(.primary)
                                    .lineLimit(1)

                                Text(product.formattedPrice)
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundColor(.primary)
                            }
                            .frame(width: 140)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }

    private var sliderPlaceholder: some View {
        Rectangle()
            .fill(Color(.systemGray5))
            .frame(width: 140, height: 140)
            .overlay {
                Image(systemName: "photo")
                    .foregroundColor(.gray)
                    .font(.system(size: 20))
            }
    }

    // MARK: - Sell Bag Promo

    private var sellBagPromo: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 12) {
                Text(L.t(sv: "Första påsen gratis", nb: "Første posen gratis"))
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.primary)

                Text(L.t(
                    sv: "Att sälja dina gamla saker har aldrig varit enklare. Allt du behöver göra är att packa en Up&Down-påse. Första påsen är gratis – därefter 19 kr st.",
                    nb: "Å selge de gamle tingene dine har aldri vært enklere. Alt du trenger å gjøre er å pakke en Up&Down-pose. Første posen er gratis – deretter 19 kr stk."
                ))
                .font(.system(size: 15))
                .foregroundColor(.secondary)

                Button {
                } label: {
                    Text(L.t(sv: "Beställ påse", nb: "Bestill pose"))
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(Color.black)
                        .clipShape(RoundedRectangle(cornerRadius: 24))
                }
                .padding(.top, 4)
            }
            .padding(20)

            Image("75")
                .resizable()
                .scaledToFill()
                .frame(height: 220)
                .clipped()
        }
        .background(Color(.systemGray6))
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
            Image(systemName: "bag")
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
        if selectedTab != "Alla" { parts.append("tag:\(selectedTab)") }
        if let sub = selectedSubcategory { parts.append("product_type:\(sub)") }
        return parts.isEmpty ? nil : parts.joined(separator: " ")
    }
}

// MARK: - Product Card

struct ProductCard: View {
    let product: ShopifyProduct
    @State private var isFavorite = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .bottomTrailing) {
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

                Button {
                    withAnimation(.spring(response: 0.3)) { isFavorite.toggle() }
                } label: {
                    Image(systemName: isFavorite ? "heart.fill" : "heart")
                        .font(.system(size: 16))
                        .foregroundColor(isFavorite ? .red : .gray)
                        .padding(8)
                        .background(.ultraThinMaterial)
                        .clipShape(Circle())
                }
                .padding(8)
            }
            .clipShape(RoundedRectangle(cornerRadius: 12))

            VStack(alignment: .leading, spacing: 3) {
                Text(product.title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.primary)
                    .lineLimit(1)

                Text(product.vendor + ", " + product.productType)
                    .font(.system(size: 12))
                    .foregroundColor(.gray)
                    .lineLimit(1)

                HStack(spacing: 4) {
                    Image(systemName: "shippingbox")
                        .font(.system(size: 10))
                    Text(L.t(sv: "Snabb leverans", nb: "Rask levering"))
                        .font(.system(size: 11))
                }
                .foregroundColor(.gray)
                .padding(.top, 2)

                Text(product.formattedPrice)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.primary)
                    .padding(.top, 2)
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
                .frame(width: 120, height: 14)

            RoundedRectangle(cornerRadius: 4)
                .fill(shimmerGradient)
                .frame(width: 80, height: 12)

            RoundedRectangle(cornerRadius: 4)
                .fill(shimmerGradient)
                .frame(width: 60, height: 14)
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
