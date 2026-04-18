import SwiftUI

struct ProductGridView: View {
    @Binding var showCart: Bool
    @Binding var marketSubTab: Int
    /// Opens the full-screen AI sell flow (parent presents `SellFlowView`).
    var onOpenSellFlow: (() -> Void)? = nil
    @ObservedObject private var cartManager = CartManager.shared
    @State private var products: [ShopifyProduct] = []
    @State private var searchText = ""
    @State private var selectedCategory = "Alla"
    @State private var isLoading = true
    @State private var hasNextPage = false
    @State private var endCursor: String?
    @State private var isLoadingMore = false
    @State private var showSearchOverlay = false
    @State private var showMarketInfo = false
    @FocusState private var isSearchFocused: Bool

    private let categoryNames = ["Alla", "Löpning & Gym", "Vardag", "Golf/Premium Sport"]

    private let categoryBrands: [String: [String]] = [
        "Löpning & Gym": ["Gymshark", "Nike", "Under Armour", "Adidas", "YoungLA", "Vanquish Fitness"],
        "Vardag": ["Nike", "Adidas", "New Balance", "Puma", "Carhartt", "The North Face"],
        "Golf/Premium Sport": ["J.Lindeberg", "Callaway", "Nike Golf", "Adidas Golf", "TaylorMade"]
    ]

    private let popularBrands = [
        "Nike", "Adidas", "J.Lindeberg", "Gymshark", "Under Armour",
        "New Balance", "Puma", "The North Face", "Callaway", "Carhartt"
    ]
    private let popularSearches = [
        "Löparskor", "Tights", "Träningströja", "Jacka", "Shorts",
        "Hoodie", "Ryggsäck", "Sportbh"
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

                        categoryChips
                            .padding(.top, 16)

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
                .onChange(of: searchText) { _, _ in
                    products = filterProducts(allCollectionProducts)
                }
                .onChange(of: selectedCategory) { _, _ in
                    products = filterProducts(allCollectionProducts)
                }
            }
        }
        .background(Color(.systemBackground))
        .sheet(isPresented: $showMarketInfo) {
            MarketInfoSheet()
        }
        .alert(
            L.t(sv: "Kommer snart", nb: "Kommer snart"),
            isPresented: $showSearchComingSoon
        ) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(L.t(
                sv: "Denna funktionen lanseras inom kort när fler produkter finns tillgängliga",
                nb: "Denne funksjonen lanseres snart når flere produkter er tilgjengelige"
            ))
        }
        .task {
            if products.isEmpty { await loadProducts(reset: true) }
        }
    }

    // MARK: - Search

    @State private var showSearchComingSoon = false

    private var searchBar: some View {
        Button {
            showSearchComingSoon = true
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

    // MARK: - Category Chips

    private var categoryChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(categoryNames, id: \.self) { name in
                    let isEnabled = name == "Alla"
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedCategory = name
                        }
                    } label: {
                        Text(name)
                            .font(.system(size: 14, weight: selectedCategory == name ? .semibold : .medium))
                            .foregroundColor(
                                selectedCategory == name ? .white :
                                isEnabled ? .primary : .primary.opacity(0.35)
                            )
                            .padding(.horizontal, 16)
                            .padding(.vertical, 9)
                            .background(
                                selectedCategory == name
                                    ? Capsule().fill(Color.black)
                                    : Capsule().fill(Color(.systemGray6))
                            )
                    }
                    .disabled(!isEnabled)
                }
            }
            .padding(.horizontal, 16)
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
                            SliderProductCard(product: product)
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
        VStack(alignment: .leading, spacing: 12) {
            Text(L.t(sv: "Ge dina gamla sportprodukter ett nytt liv", nb: "Gi de gamle sportproduktene dine nytt liv"))
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(.primary)

            Text(L.t(
                sv: "Sälj det du inte längre använder och bli betald. Beställ en Up&Down-påse, packa den och skicka – vi sköter resten.",
                nb: "Selg det du ikke lenger bruker og bli betalt. Bestill en Up&Down-pose, pakk den og send – vi tar oss av resten."
            ))
            .font(.system(size: 15))
            .foregroundColor(.secondary)

            Button {
                if let onOpenSellFlow {
                    onOpenSellFlow()
                } else {
                    withAnimation(.easeInOut(duration: 0.2)) { marketSubTab = 1 }
                }
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
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 16))
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

    @State private var allCollectionProducts: [ShopifyProduct] = []

    private func loadProducts(reset: Bool) async {
        if reset {
            isLoading = true
        }

        do {
            let fetched = try await ShopifyService.shared.fetchCollectionProducts(handle: "up-down", first: 50)

            await MainActor.run {
                allCollectionProducts = fetched
                products = filterProducts(fetched)
                hasNextPage = false
                isLoading = false
                isLoadingMore = false
            }
        } catch {
            print("Failed to load collection products: \(error)")
            await MainActor.run {
                isLoading = false
                isLoadingMore = false
            }
        }
    }

    private func loadMore() async { }

    private func filterProducts(_ source: [ShopifyProduct]) -> [ShopifyProduct] {
        var filtered = source
        if !searchText.isEmpty {
            let query = searchText.lowercased()
            filtered = filtered.filter {
                $0.title.lowercased().contains(query) ||
                $0.vendor.lowercased().contains(query) ||
                $0.productType.lowercased().contains(query) ||
                $0.tags.contains(where: { $0.lowercased().contains(query) })
            }
        }
        if selectedCategory != "Alla", let brands = categoryBrands[selectedCategory] {
            filtered = filtered.filter { product in
                brands.contains(where: { $0.caseInsensitiveCompare(product.vendor) == .orderedSame })
            }
        }
        return filtered
    }
}

// MARK: - Product Card

struct ProductCard: View {
    let product: ShopifyProduct
    @State private var cachedImage: UIImage?
    @State private var imageLoading = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Group {
                if let uiImage = cachedImage {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                } else if imageLoading {
                    Rectangle()
                        .fill(Color(.systemGray5))
                        .overlay { ProgressView().tint(.gray) }
                } else {
                    imagePlaceholder
                }
            }
            .frame(height: 200)
            .frame(maxWidth: .infinity)
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .onAppear { loadImage() }

            VStack(alignment: .leading, spacing: 2) {
                Text(product.formattedPrice)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.primary)

                Text(product.title)
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                    .lineLimit(1)

                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 11, weight: .semibold))
                    Text("I lager")
                        .font(.system(size: 12, weight: .semibold))
                }
                .foregroundColor(Color(red: 10/255, green: 140/255, blue: 80/255))
                .padding(.top, 1)
            }
            .padding(.horizontal, 2)
        }
    }

    private func loadImage() {
        guard let urlString = product.images.edges.first?.node.url, !urlString.isEmpty else { return }
        if let cached = ImageCacheManager.shared.getImage(for: urlString) {
            cachedImage = cached
            return
        }
        imageLoading = true
        Task {
            do {
                let image = try await ImageCacheManager.shared.downloadAndCacheImage(from: urlString)
                await MainActor.run {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        cachedImage = image
                        imageLoading = false
                    }
                }
            } catch {
                await MainActor.run { imageLoading = false }
            }
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

// MARK: - Slider Product Card

private struct SliderProductCard: View {
    let product: ShopifyProduct
    @State private var cachedImage: UIImage?
    @State private var imageLoading = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Group {
                if let uiImage = cachedImage {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                } else if imageLoading {
                    ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    Rectangle().fill(Color(.systemGray5))
                        .overlay { Image(systemName: "photo").foregroundColor(.gray).font(.system(size: 20)) }
                }
            }
            .frame(width: 140, height: 140)
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .onAppear { loadImage() }

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

    private func loadImage() {
        guard let urlString = product.images.edges.first?.node.url, !urlString.isEmpty else { return }
        if let cached = ImageCacheManager.shared.getImage(for: urlString) {
            cachedImage = cached
            return
        }
        imageLoading = true
        Task {
            do {
                let image = try await ImageCacheManager.shared.downloadAndCacheImage(from: urlString)
                await MainActor.run {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        cachedImage = image
                        imageLoading = false
                    }
                }
            } catch {
                await MainActor.run { imageLoading = false }
            }
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
