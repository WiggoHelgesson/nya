import SwiftUI
import Combine

// MARK: - Shop Categories

/// Kategorier i Vår shop. Varje kategori motsvarar en Shopify-kollektion.
/// Handles följer Shopifys standardtransliteration (ö→o, ä→a) — justera här
/// om en kollektion har en annan handle i Shopify-adminen.
enum ShopCategory: String, CaseIterable, Identifiable {
    case all, golf, gym, running, training

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: return L.t(sv: "Allt", nb: "Alt")
        case .golf: return "Golf"
        case .gym: return "Gym"
        case .running: return L.t(sv: "Löpning", nb: "Løping")
        case .training: return L.t(sv: "Träning", nb: "Trening")
        }
    }

    var collectionHandle: String {
        switch self {
        case .all: return "roliga"
        case .golf: return "golf"
        case .gym: return "gym"
        case .running: return "lopning"
        case .training: return "traning"
        }
    }
}

// MARK: - Sort

enum ShopSortOption: String, CaseIterable, Identifiable {
    case featured, priceAsc, priceDesc, nameAsc

    var id: String { rawValue }

    var title: String {
        switch self {
        case .featured: return L.t(sv: "Populärast", nb: "Mest populær")
        case .priceAsc: return L.t(sv: "Pris: Lägst först", nb: "Pris: Lavest først")
        case .priceDesc: return L.t(sv: "Pris: Högst först", nb: "Pris: Høyest først")
        case .nameAsc: return L.t(sv: "Namn A–Ö", nb: "Navn A–Å")
        }
    }

    func sorted(_ products: [ShopifyProduct]) -> [ShopifyProduct] {
        switch self {
        case .featured:
            return products
        case .priceAsc:
            return products.sorted { (Double($0.minPrice) ?? 0) < (Double($1.minPrice) ?? 0) }
        case .priceDesc:
            return products.sorted { (Double($0.minPrice) ?? 0) > (Double($1.minPrice) ?? 0) }
        case .nameAsc:
            return products.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        }
    }
}

// MARK: - Feed Store

@MainActor
final class ShopifyFeedStore: ObservableObject {
    static let shared = ShopifyFeedStore()

    @Published private(set) var productsByHandle: [String: [ShopifyProduct]] = [:]
    @Published private(set) var isLoading = false
    @Published private(set) var hasLoadedOnce = false
    @Published var selectedCategory: ShopCategory = .all

    private init() {}

    /// Produkterna för den valda kategorin.
    var products: [ShopifyProduct] {
        productsByHandle[selectedCategory.collectionHandle] ?? []
    }

    func select(_ category: ShopCategory) async {
        selectedCategory = category
        await loadIfNeeded(category)
    }

    func loadIfNeeded(_ category: ShopCategory? = nil) async {
        let cat = category ?? selectedCategory
        guard productsByHandle[cat.collectionHandle, default: []].isEmpty else { return }
        await refresh(cat)
    }

    func refresh(_ category: ShopCategory? = nil) async {
        let cat = category ?? selectedCategory
        isLoading = true
        defer { isLoading = false }
        do {
            let fetched = try await ShopifyService.shared.fetchCollectionProducts(
                handle: cat.collectionHandle,
                first: 50
            )
            productsByHandle[cat.collectionHandle] = fetched
            hasLoadedOnce = true
        } catch {
            print("[ShopifyFeedStore] Failed to load products for '\(cat.collectionHandle)': \(error)")
        }
    }
}

// MARK: - Recently Viewed

/// Lättviktig snapshot av en produkt för "Nyligen visade"-raden (sparas i UserDefaults).
struct RecentProductSnapshot: Codable, Identifiable, Equatable {
    let handle: String
    let title: String
    let vendor: String
    let formattedPrice: String
    let imageURL: String?

    var id: String { handle }
}

@MainActor
final class RecentlyViewedStore: ObservableObject {
    static let shared = RecentlyViewedStore()

    @Published private(set) var items: [RecentProductSnapshot] = []

    private let key = "shop.recently_viewed"
    private let maxCount = 10

    private init() { load() }

    func record(_ product: ShopifyProduct) {
        let snapshot = RecentProductSnapshot(
            handle: product.handle,
            title: product.title,
            vendor: product.vendor,
            formattedPrice: product.formattedPrice,
            imageURL: product.images.edges.first?.node.url
        )
        var next = items.filter { $0.handle != snapshot.handle }
        next.insert(snapshot, at: 0)
        if next.count > maxCount { next = Array(next.prefix(maxCount)) }
        items = next
        save()
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode([RecentProductSnapshot].self, from: data) else { return }
        items = decoded
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(items) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }
}

/// Route-typ för "Nyligen visade" så att den inte krockar med
/// `navigationDestination(for: ShopifyProduct.self)` i containern.
struct RecentProductRoute: Hashable, Identifiable {
    let product: ShopifyProduct
    var id: String { product.id }
}

/// Vår shop-fliken: sökfält, hero, gratisprodukt-banner, kategorichips och produktgrid.
struct ProductGridView: View {
    @Binding var showCart: Bool
    @EnvironmentObject var authViewModel: AuthViewModel

    @ObservedObject private var store = ShopifyFeedStore.shared
    @ObservedObject private var rewardService = FreeRewardService.shared
    @ObservedObject private var favorites = ProductFavoritesService.shared
    @ObservedObject private var recentlyViewed = RecentlyViewedStore.shared

    @State private var showShopInfo = false
    @State private var sortOption: ShopSortOption = .featured
    @State private var recentRoute: RecentProductRoute?
    @State private var isLoadingRecent = false
    @State private var featuredProduct: ShopifyProduct?

    /// Produkt som lyfts fram i full bredd direkt under kategorichipsen.
    private static let featuredHandle = "groove-cleaner"

    private let columns = [
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8)
    ]

    private var displayedProducts: [ShopifyProduct] {
        sortOption.sorted(store.products.filter { $0.handle != Self.featuredHandle })
    }

    var body: some View {
        VStack(spacing: 0) {
            StravaStyleHeaderView(
                pageTitle: L.t(sv: "Vår shop", nb: "Vår shop"),
                hideMessages: true,
                cartAction: { showCart = true }
            )
            .environmentObject(authViewModel)
            Divider()
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
                        searchBar
                            .padding(.horizontal, 16)
                            .padding(.top, 12)

                        heroBanner(proxy: proxy)
                            .padding(.top, 12)

                        FreeRewardBanner()
                            .padding(.horizontal, 16)
                            .padding(.top, 12)

                        shopInfoLink
                            .padding(.top, 8)

                        Section(header: categoryChips) {
                            if let featured = featuredProduct {
                                NavigationLink(value: featured) {
                                    FeaturedProductCard(
                                        product: featured,
                                        onQuickAdd: { variant in
                                            Task {
                                                await CartManager.shared.addToCart(variantId: variant.id)
                                                showCart = true
                                            }
                                        }
                                    )
                                }
                                .buttonStyle(.plain)
                                .padding(.horizontal, 16)
                                .padding(.top, 10)
                            }

                            sortRow
                                .padding(.horizontal, 16)
                                .padding(.top, 12)

                            productGrid
                                .padding(.horizontal, 16)
                                .padding(.top, 10)
                                .id("productGrid")

                            if !recentlyViewed.items.isEmpty {
                                recentlyViewedSection
                                    .padding(.top, 24)
                            }

                            Color.clear.frame(height: 20)
                        }
                    }
                }
                .refreshable {
                    await store.refresh()
                    await rewardService.syncAndFetchStatus()
                    await refreshFavorites()
                }
            }
        }
        .background(Color(.systemBackground))
        .task {
            await store.loadIfNeeded()
            await rewardService.syncAndFetchStatus()
            await favorites.loadFavorites()
            await loadFeaturedProduct()
            await refreshFavorites()
        }
        .sheet(isPresented: $showShopInfo) {
            ShopInfoView()
        }
        .navigationDestination(item: $recentRoute) { route in
            ProductDetailView(product: route.product, showCart: $showCart)
                .environmentObject(authViewModel)
        }
    }

    private func refreshFavorites() async {
        await favorites.loadCounts(handles: store.products.map(\.handle) + [Self.featuredHandle])
    }

    private func loadFeaturedProduct() async {
        guard featuredProduct == nil else { return }
        do {
            featuredProduct = try await ShopifyService.shared.fetchProductByHandle(Self.featuredHandle)
        } catch {
            print("[ProductGridView] Failed to load featured product '\(Self.featuredHandle)': \(error)")
        }
    }

    // MARK: - Search bar

    private var searchBar: some View {
        NavigationLink {
            ShopSearchView(showCart: $showCart)
                .environmentObject(authViewModel)
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundColor(.primary)
                Text(L.t(sv: "Vad vill du handla?", nb: "Hva vil du handle?"))
                    .font(.system(size: 15))
                    .foregroundColor(.secondary)
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Color(.systemBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(Color.primary.opacity(0.7), lineWidth: 1.2)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Hero

    private func heroBanner(proxy: ScrollViewProxy) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.4)) {
                proxy.scrollTo("productGrid", anchor: .top)
            }
        } label: {
            Image("116")
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Shop info link

    private var shopInfoLink: some View {
        Button {
            showShopInfo = true
        } label: {
            HStack(spacing: 5) {
                Image(systemName: "questionmark.circle")
                    .font(.system(size: 13))
                Text(L.t(sv: "Läs mer om hur Up&Down Shoppen fungerar", nb: "Les mer om hvordan Up&Down Shoppen fungerer"))
                    .font(.system(size: 13))
            }
            .foregroundColor(.secondary)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Category chips

    private var categoryChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(ShopCategory.allCases) { category in
                    categoryChip(category)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .background(Color(.systemBackground))
    }

    private func categoryChip(_ category: ShopCategory) -> some View {
        let isSelected = store.selectedCategory == category
        return Button {
            guard !isSelected else { return }
            Task {
                await store.select(category)
                await refreshFavorites()
            }
        } label: {
            Text(category.title)
                .font(.system(size: 14, weight: isSelected ? .semibold : .medium))
                .foregroundColor(isSelected ? .white : .primary)
                .padding(.horizontal, 16)
                .padding(.vertical, 9)
                .background(
                    Capsule()
                        .fill(isSelected ? Color.black : Color(.systemGray6))
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Sort row

    private var sortRow: some View {
        HStack {
            Text(L.t(sv: "\(displayedProducts.count) produkter", nb: "\(displayedProducts.count) produkter"))
                .font(.system(size: 13))
                .foregroundColor(.secondary)

            Spacer()

            Menu {
                Picker(L.t(sv: "Sortera", nb: "Sorter"), selection: $sortOption) {
                    ForEach(ShopSortOption.allCases) { option in
                        Text(option.title).tag(option)
                    }
                }
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "arrow.up.arrow.down")
                        .font(.system(size: 12, weight: .semibold))
                    Text(sortOption == .featured ? L.t(sv: "Sortera", nb: "Sorter") : sortOption.title)
                        .font(.system(size: 13, weight: .semibold))
                }
                .foregroundColor(.primary)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(Capsule().fill(Color(.systemGray6)))
            }
        }
    }

    // MARK: - Grid

    @ViewBuilder
    private var productGrid: some View {
        if store.products.isEmpty && store.isLoading {
            LazyVGrid(columns: columns, spacing: 14) {
                ForEach(0..<4, id: \.self) { _ in
                    ProductCardSkeleton()
                }
            }
        } else if store.products.isEmpty && !store.isLoading {
            emptyState
        } else {
            LazyVGrid(columns: columns, spacing: 18) {
                ForEach(displayedProducts) { product in
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
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "bag")
                .font(.system(size: 32))
                .foregroundStyle(.secondary)
            Text(L.t(sv: "Inga produkter just nu", nb: "Ingen produkter akkurat nå"))
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 40)
        .padding(.horizontal, 24)
    }

    // MARK: - Recently viewed

    private var recentlyViewedSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(L.t(sv: "Nyligen visade", nb: "Nylig sett"))
                .font(.system(size: 17, weight: .bold))
                .foregroundColor(.primary)
                .padding(.horizontal, 16)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(recentlyViewed.items) { item in
                        Button {
                            openRecent(item)
                        } label: {
                            RecentProductCard(snapshot: item)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }

    private func openRecent(_ snapshot: RecentProductSnapshot) {
        guard !isLoadingRecent else { return }

        // Finns produkten redan i någon laddad kollektion? Navigera direkt.
        if let cached = store.productsByHandle.values.joined().first(where: { $0.handle == snapshot.handle }) {
            recentRoute = RecentProductRoute(product: cached)
            return
        }

        isLoadingRecent = true
        Task {
            defer { isLoadingRecent = false }
            if let product = try? await ShopifyService.shared.fetchProductByHandle(snapshot.handle) {
                recentRoute = RecentProductRoute(product: product)
            }
        }
    }
}

// MARK: - Recent Product Card

struct RecentProductCard: View {
    let snapshot: RecentProductSnapshot
    @State private var cachedImage: UIImage?

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Group {
                if let image = cachedImage {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                } else {
                    Rectangle()
                        .fill(Color(.systemGray5))
                        .overlay {
                            Image(systemName: "photo")
                                .foregroundColor(.gray)
                        }
                }
            }
            .frame(width: 120, height: 150)
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: 10))

            Text(snapshot.vendor)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.primary)
                .lineLimit(1)

            Text(snapshot.formattedPrice)
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(.primary)
        }
        .frame(width: 120)
        .onAppear { loadImage() }
    }

    private func loadImage() {
        guard let urlString = snapshot.imageURL, !urlString.isEmpty else { return }
        if let cached = ImageCacheManager.shared.getImage(for: urlString) {
            cachedImage = cached
            return
        }
        Task {
            if let image = try? await ImageCacheManager.shared.downloadAndCacheImage(from: urlString) {
                await MainActor.run { cachedImage = image }
            }
        }
    }
}

// MARK: - Free Reward Banner

/// Banner överst på Vår shop som förklarar Pro Free Product Reward-systemet:
/// - Intjänad reward: "Du har en gratis produkt att hämta!"
/// - Pro under intjäning: progressbar mot 3 månader
/// - Icke-Pro: upsell till Pro via paywall
struct FreeRewardBanner: View {
    @ObservedObject private var rewardService = FreeRewardService.shared
    @State private var isPremium = RevenueCatManager.shared.isProMember

    private let gold = Color(red: 0.85, green: 0.65, blue: 0.1)

    var body: some View {
        Group {
            if let status = rewardService.status, status.hasEarnedReward {
                earnedBanner(count: status.earnedRewards.count)
            } else if let status = rewardService.status, status.isPro, let days = status.daysRemaining {
                progressBanner(daysRemaining: days, progress: status.periodProgress)
            } else if !isPremium {
                upsellBanner
            }
        }
        .onReceive(RevenueCatManager.shared.$isProMember) { isPremium = $0 }
    }

    private func earnedBanner(count: Int) -> some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.2))
                    .frame(width: 44, height: 44)
                Image(systemName: "gift.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.white)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(count == 1
                     ? L.t(sv: "Du har 1 gratis produkt att hämta!", nb: "Du har 1 gratis produkt å hente!")
                     : L.t(sv: "Du har \(count) gratis produkter att hämta!", nb: "Du har \(count) gratis produkter å hente!"))
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.white)
                Text(L.t(sv: "Välj bland produkter märkta \"GRATIS för Pro\" — frakt tillkommer", nb: "Velg blant produkter merket \"GRATIS for Pro\" — frakt kommer i tillegg"))
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.85))
            }

            Spacer()
        }
        .padding(14)
        .background(
            LinearGradient(
                colors: [gold, Color(red: 0.72, green: 0.52, blue: 0.04)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(16)
    }

    private func progressBanner(daysRemaining: Int, progress: Double) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: "gift")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)
                Text(L.t(sv: "Din nästa gratisprodukt", nb: "Din neste gratisprodukt"))
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.primary)
                Spacer()
                Text(L.t(sv: "\(daysRemaining) dagar kvar", nb: "\(daysRemaining) dager igjen"))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.secondary)
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.primary.opacity(0.1))
                    Capsule()
                        .fill(gold)
                        .frame(width: max(geometry.size.width * progress, 8))
                }
            }
            .frame(height: 8)

            Text(L.t(sv: "Som Pro-medlem får du en gratis produkt var 3:e månad", nb: "Som Pro-medlem får du en gratis produkt hver 3. måned"))
                .font(.system(size: 12))
                .foregroundColor(.secondary)
        }
        .padding(14)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.primary.opacity(0.06), lineWidth: 1)
        )
    }

    private var upsellBanner: some View {
        VStack(spacing: 0) {
            ZStack {
                LinearGradient(
                    colors: [Color(red: 0.08, green: 0.08, blue: 0.12), Color(red: 0.18, green: 0.14, blue: 0.05)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                HStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(gold.opacity(0.18))
                            .frame(width: 52, height: 52)
                        Image(systemName: "gift.fill")
                            .font(.system(size: 22))
                            .foregroundColor(gold.opacity(0.4))
                        Image(systemName: "lock.fill")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(gold)
                            .offset(x: 14, y: 14)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(L.t(sv: "Lås upp din gratis produkt", nb: "Lås opp din gratis produkt"))
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(.white)
                        Text(L.t(sv: "Pro-medlemmar får 1 gratis produkt var 3:e månad — välj fritt bland märkta produkter", nb: "Pro-medlemmer får 1 gratis produkt hver 3. måned — velg fritt blant merkede produkter"))
                            .font(.system(size: 12))
                            .foregroundColor(Color.white.opacity(0.7))
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer()
                }
                .padding(16)
            }

            Button {
                SuperwallService.shared.showPaywall()
            } label: {
                HStack {
                    Spacer()
                    Text(L.t(sv: "Bli Pro nu", nb: "Bli Pro nå"))
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.black)
                    Image(systemName: "arrow.right")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.black)
                    Spacer()
                }
                .padding(.vertical, 12)
                .background(
                    LinearGradient(
                        colors: [gold, Color(red: 0.72, green: 0.52, blue: 0.04)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(12)
                .padding(.horizontal, 16)
                .padding(.top, 10)
                .padding(.bottom, 4)
            }
            .buttonStyle(.plain)
        }
        .background(Color(red: 0.10, green: 0.09, blue: 0.10))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(gold.opacity(0.25), lineWidth: 1)
        )
    }
}

// MARK: - Shop Info Sheet

struct ShopInfoView: View {
    @Environment(\.dismiss) private var dismiss

    private let gold = Color(red: 0.85, green: 0.65, blue: 0.1)

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 28) {
                    howItWorksSection
                    proComparisonSection
                    howToRedeemSection
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 40)
            }
            .navigationTitle(L.t(sv: "Hur shoppen fungerar", nb: "Slik fungerer shoppen"))
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(L.t(sv: "Stäng", nb: "Lukk")) { dismiss() }
                        .font(.system(size: 15, weight: .medium))
                }
            }
        }
    }

    // MARK: Hur shoppen fungerar

    private var howItWorksSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader(
                icon: "cart.fill",
                title: L.t(sv: "Hur shoppen fungerar", nb: "Slik fungerer shoppen")
            )

            VStack(spacing: 0) {
                ForEach(Array(shopSteps.enumerated()), id: \.offset) { index, step in
                    HStack(alignment: .top, spacing: 14) {
                        ZStack {
                            Circle()
                                .fill(gold)
                                .frame(width: 30, height: 30)
                            Text("\(index + 1)")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(.black)
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text(step.title)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.primary)
                            Text(step.description)
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(.top, 5)

                        Spacer()
                    }
                    .padding(.vertical, 10)

                    if index < shopSteps.count - 1 {
                        HStack {
                            Spacer().frame(width: 15)
                            Rectangle()
                                .fill(gold.opacity(0.3))
                                .frame(width: 1, height: 16)
                            Spacer()
                        }
                    }
                }
            }
            .padding(16)
            .background(Color(.secondarySystemBackground))
            .cornerRadius(16)
        }
    }

    private struct ShopStep {
        let title: String
        let description: String
    }

    private var shopSteps: [ShopStep] {
        [
            ShopStep(
                title: L.t(sv: "Handla produkter", nb: "Handle produkter"),
                description: L.t(sv: "Bläddra bland våra utvalda produkter och köp direkt via Shopify.", nb: "Bla gjennom utvalgte produkter og kjøp direkte via Shopify.")
            ),
            ShopStep(
                title: L.t(sv: "Tjäna poäng", nb: "Tjen poeng"),
                description: L.t(sv: "Genomför träningspass för att samla XP-poäng. Poängen spåras automatiskt.", nb: "Gjennomfør treningsøkter for å samle XP-poeng. Poengene spores automatisk.")
            ),
            ShopStep(
                title: L.t(sv: "Bli Pro", nb: "Bli Pro"),
                description: L.t(sv: "Pro-medlemmar låser upp en gratis produkt var 3:e månad och tjänar dubbelt så mycket XP per träningspass.", nb: "Pro-medlemmer låser opp en gratis produkt hver 3. måned og tjener dobbelt så mye XP per treningsøkt.")
            ),
            ShopStep(
                title: L.t(sv: "Hämta din belöning", nb: "Hent belønningen din"),
                description: L.t(sv: "När din gratisprodukt är upplåst — välj en produkt märkt \"GRATIS för Pro\" och hämta den kostnadsfritt.", nb: "Når gratisprodukten din er låst opp — velg et produkt merket \"GRATIS for Pro\" og hent det kostnadsfritt.")
            )
        ]
    }

    // MARK: Pro jämförelse

    private var proComparisonSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader(
                icon: "star.fill",
                title: L.t(sv: "Gratis vs Pro", nb: "Gratis vs Pro")
            )

            VStack(spacing: 0) {
                comparisonHeader
                Divider().padding(.vertical, 2)
                ForEach(Array(comparisonRows.enumerated()), id: \.offset) { index, row in
                    comparisonRow(row, isEven: index % 2 == 0)
                }
            }
            .background(Color(.secondarySystemBackground))
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.primary.opacity(0.06), lineWidth: 1)
            )
        }
    }

    private var comparisonHeader: some View {
        HStack(spacing: 0) {
            Text(L.t(sv: "Förmån", nb: "Fordel"))
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, 16)

            Text(L.t(sv: "Gratis", nb: "Gratis"))
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.secondary)
                .frame(width: 70, alignment: .center)

            HStack(spacing: 4) {
                Image(systemName: "star.fill")
                    .font(.system(size: 10))
                    .foregroundColor(gold)
                Text("Pro")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(gold)
            }
            .frame(width: 70, alignment: .center)
            .padding(.trailing, 8)
        }
        .padding(.vertical, 10)
        .background(Color(.tertiarySystemBackground))
    }

    private struct ComparisonRow {
        let feature: String
        let freeValue: String?
        let proValue: String
    }

    private var comparisonRows: [ComparisonRow] {
        [
            ComparisonRow(
                feature: L.t(sv: "Gratis produkt", nb: "Gratis produkt"),
                freeValue: nil,
                proValue: L.t(sv: "Var 3:e månad", nb: "Hver 3. måned")
            ),
            ComparisonRow(
                feature: L.t(sv: "XP per träningspass", nb: "XP per treningsøkt"),
                freeValue: "5 XP",
                proValue: "10 XP"
            ),
            ComparisonRow(
                feature: L.t(sv: "Handel i shoppen", nb: "Handle i butikken"),
                freeValue: "✓",
                proValue: "✓"
            )
        ]
    }

    private func comparisonRow(_ row: ComparisonRow, isEven: Bool) -> some View {
        HStack(spacing: 0) {
            Text(row.feature)
                .font(.system(size: 13))
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, 16)

            Group {
                if let freeVal = row.freeValue {
                    Text(freeVal)
                        .foregroundColor(.secondary)
                } else {
                    Image(systemName: "minus")
                        .foregroundColor(Color(.systemGray3))
                }
            }
            .font(.system(size: 13, weight: .medium))
            .frame(width: 70, alignment: .center)

            Text(row.proValue)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(row.proValue == "✓" ? Color(red: 0.1, green: 0.7, blue: 0.35) : gold)
                .frame(width: 70, alignment: .center)
                .padding(.trailing, 8)
        }
        .padding(.vertical, 11)
        .background(isEven ? Color(.secondarySystemBackground) : Color(.tertiarySystemBackground).opacity(0.5))
    }

    // MARK: Hur hämtar man

    private var howToRedeemSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader(
                icon: "gift.fill",
                title: L.t(sv: "Hämta din gratisprodukt", nb: "Hent din gratis produkt")
            )

            VStack(spacing: 10) {
                ForEach(Array(redeemSteps.enumerated()), id: \.offset) { _, step in
                    HStack(alignment: .top, spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(gold.opacity(0.15))
                                .frame(width: 36, height: 36)
                            Image(systemName: step.icon)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(gold)
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text(step.title)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.primary)
                            Text(step.description)
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(.top, 2)

                        Spacer()
                    }
                    .padding(12)
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(12)
                }
            }
        }
    }

    private struct RedeemStep {
        let icon: String
        let title: String
        let description: String
    }

    private var redeemSteps: [RedeemStep] {
        [
            RedeemStep(
                icon: "clock.fill",
                title: L.t(sv: "Vänta 90 dagar", nb: "Vent 90 dager"),
                description: L.t(sv: "Din gratisprodukt låses upp automatiskt efter 90 dagars Pro-medlemskap.", nb: "Gratisprodukten din låses opp automatisk etter 90 dagers Pro-medlemskap.")
            ),
            RedeemStep(
                icon: "tag.fill",
                title: L.t(sv: "Hitta en \"GRATIS för Pro\"-produkt", nb: "Finn en \"GRATIS for Pro\"-produkt"),
                description: L.t(sv: "Leta efter den guldiga etiketten på produktkorten i shoppen.", nb: "Se etter den gyldne etiketten på produktkortene i butikken.")
            ),
            RedeemStep(
                icon: "hand.tap.fill",
                title: L.t(sv: "Öppna produkten och välj \"Hämta gratis\"", nb: "Åpne produktet og velg \"Hent gratis\""),
                description: L.t(sv: "Tryck på knappen på produktsidan för att nyttja din belöning.", nb: "Trykk på knappen på produktsiden for å bruke belønningen din.")
            ),
            RedeemStep(
                icon: "checkmark.circle.fill",
                title: L.t(sv: "Frakten ingår gratis", nb: "Frakt er gratis"),
                description: L.t(sv: "Produkten och frakten är helt gratis — inget mer att betala.", nb: "Produktet og frakten er helt gratis — ingenting mer å betale.")
            )
        ]
    }

    // MARK: Helpers

    private func sectionHeader(icon: String, title: String) -> some View {
        HStack(spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(gold.opacity(0.15))
                    .frame(width: 32, height: 32)
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(gold)
            }
            Text(title)
                .font(.system(size: 17, weight: .bold))
                .foregroundColor(.primary)
        }
    }
}

// MARK: - Product Card (Shopify)

/// Sellpy-inspirerat produktkort: bild, snabbköp + hjärta, märke, titel, lagerstatus och pris.
/// Används i shop-griden, sökresultaten och relaterade produkter på produktsidan.
struct ProductCard: View {
    let product: ShopifyProduct
    var onQuickAdd: ((ShopifyVariant) -> Void)? = nil

    @State private var cachedImage: UIImage?
    @State private var imageLoading = false
    @State private var justAdded = false
    @ObservedObject private var rewardService = FreeRewardService.shared
    @ObservedObject private var favorites = ProductFavoritesService.shared

    private var isRewardEligible: Bool {
        rewardService.isEligible(product)
    }

    private var hasEarnedReward: Bool {
        rewardService.status?.hasEarnedReward == true
    }

    /// Snabbköp visas bara när det finns exakt en köpbar variant —
    /// annars måste användaren välja storlek på produktsidan.
    private var quickAddVariant: ShopifyVariant? {
        let available = product.variants.edges.filter { $0.node.availableForSale }
        guard available.count == 1 else { return nil }
        return available.first?.node
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Color.clear
                .aspectRatio(4.0 / 5.0, contentMode: .fit)
                .overlay { productImage }
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(alignment: .topLeading) {
                    if isRewardEligible {
                        freeRewardBadge
                            .padding(6)
                    }
                }
                .onAppear { loadImage() }

            actionRow

            VStack(alignment: .leading, spacing: 2) {
                Text(product.vendor.isEmpty ? "Up&Down" : product.vendor)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.primary)
                    .lineLimit(1)

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

                Text(product.formattedPrice)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.primary)
                    .padding(.top, 1)
            }
            .padding(.horizontal, 2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: Action row (snabbköp + hjärta)

    private var actionRow: some View {
        HStack {
            if let variant = quickAddVariant, let onQuickAdd {
                Button {
                    guard !justAdded else { return }
                    justAdded = true
                    onQuickAdd(variant)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        justAdded = false
                    }
                } label: {
                    Image(systemName: justAdded ? "checkmark" : "cart.badge.plus")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.primary)
                        .frame(width: 32, height: 32)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }

            Spacer()

            Button {
                favorites.toggle(handle: product.handle)
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: favorites.isFavorite(product.handle) ? "heart.fill" : "heart")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(favorites.isFavorite(product.handle) ? .red : .primary)
                    if let count = favorites.counts[product.handle], count > 0 {
                        Text("\(count)")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.primary)
                    }
                }
                .frame(height: 32)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 2)
    }

    private var freeRewardBadge: some View {
        HStack(spacing: 3) {
            Image(systemName: "gift.fill")
                .font(.system(size: 9, weight: .bold))
            Text(L.t(sv: "GRATIS för Pro", nb: "GRATIS for Pro"))
                .font(.system(size: 10, weight: .bold))
        }
        .foregroundColor(.white)
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(
            Capsule()
                .fill(hasEarnedReward
                      ? Color(red: 0.85, green: 0.65, blue: 0.1)
                      : Color.black.opacity(0.65))
        )
    }

    @ViewBuilder
    private var productImage: some View {
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

// MARK: - Featured Product Card

/// Full bredd-kort för en utvald produkt (visas direkt under kategorichipsen).
/// Samma visuella språk som `ProductCard` men en per rad och större.
struct FeaturedProductCard: View {
    let product: ShopifyProduct
    var onQuickAdd: ((ShopifyVariant) -> Void)? = nil

    @State private var cachedImage: UIImage?
    @State private var imageLoading = false
    @State private var justAdded = false
    @ObservedObject private var rewardService = FreeRewardService.shared
    @ObservedObject private var favorites = ProductFavoritesService.shared

    private var isRewardEligible: Bool {
        rewardService.isEligible(product)
    }

    private var hasEarnedReward: Bool {
        rewardService.status?.hasEarnedReward == true
    }

    private var quickAddVariant: ShopifyVariant? {
        let available = product.variants.edges.filter { $0.node.availableForSale }
        guard available.count == 1 else { return nil }
        return available.first?.node
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Color.clear
                .aspectRatio(4.0 / 3.0, contentMode: .fit)
                .overlay { productImage }
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(alignment: .topLeading) {
                    if isRewardEligible {
                        freeRewardBadge
                            .padding(8)
                    }
                }
                .onAppear { loadImage() }

            actionRow

            VStack(alignment: .leading, spacing: 3) {
                Text(product.vendor.isEmpty ? "Up&Down" : product.vendor)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.primary)
                    .lineLimit(1)

                Text(product.title)
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .lineLimit(1)

                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 12, weight: .semibold))
                    Text("I lager")
                        .font(.system(size: 13, weight: .semibold))
                }
                .foregroundColor(Color(red: 10/255, green: 140/255, blue: 80/255))

                Text(product.formattedPrice)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.primary)
                    .padding(.top, 1)
            }
            .padding(.horizontal, 2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var actionRow: some View {
        HStack {
            if let variant = quickAddVariant, let onQuickAdd {
                Button {
                    guard !justAdded else { return }
                    justAdded = true
                    onQuickAdd(variant)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        justAdded = false
                    }
                } label: {
                    Image(systemName: justAdded ? "checkmark" : "cart.badge.plus")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.primary)
                        .frame(width: 34, height: 34)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }

            Spacer()

            Button {
                favorites.toggle(handle: product.handle)
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: favorites.isFavorite(product.handle) ? "heart.fill" : "heart")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(favorites.isFavorite(product.handle) ? .red : .primary)
                    if let count = favorites.counts[product.handle], count > 0 {
                        Text("\(count)")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.primary)
                    }
                }
                .frame(height: 34)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 2)
    }

    private var freeRewardBadge: some View {
        HStack(spacing: 3) {
            Image(systemName: "gift.fill")
                .font(.system(size: 10, weight: .bold))
            Text(L.t(sv: "GRATIS för Pro", nb: "GRATIS for Pro"))
                .font(.system(size: 11, weight: .bold))
        }
        .foregroundColor(.white)
        .padding(.horizontal, 9)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(hasEarnedReward
                      ? Color(red: 0.85, green: 0.65, blue: 0.1)
                      : Color.black.opacity(0.65))
        )
    }

    @ViewBuilder
    private var productImage: some View {
        if let uiImage = cachedImage {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFill()
        } else if imageLoading {
            Rectangle()
                .fill(Color(.systemGray5))
                .overlay { ProgressView().tint(.gray) }
        } else {
            Rectangle()
                .fill(Color(.systemGray5))
                .overlay {
                    Image(systemName: "photo")
                        .foregroundColor(.gray)
                        .font(.system(size: 28))
                }
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
}

// MARK: - Skeleton

struct ProductCardSkeleton: View {
    @State private var isAnimating = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Color.clear
                .aspectRatio(4.0 / 5.0, contentMode: .fit)
                .overlay {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(shimmerGradient)
                }
                .clipShape(RoundedRectangle(cornerRadius: 12))

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
        .frame(maxWidth: .infinity, alignment: .leading)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                isAnimating = true
            }
        }
    }

    private var shimmerGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(.systemGray5),
                Color(.systemGray6),
                Color(.systemGray5)
            ],
            startPoint: isAnimating ? .leading : .trailing,
            endPoint: isAnimating ? .trailing : .leading
        )
    }
}
