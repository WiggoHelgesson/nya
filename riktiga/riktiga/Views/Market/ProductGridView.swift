import SwiftUI
import Combine

@MainActor
final class ShopifyFeedStore: ObservableObject {
    static let shared = ShopifyFeedStore()

    @Published private(set) var products: [ShopifyProduct] = []
    @Published private(set) var isLoading = false

    private init() {}

    func loadIfNeeded() async {
        guard products.isEmpty else { return }
        await refresh()
    }

    func refresh() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let connection = try await ShopifyService.shared.fetchProducts(first: 50)
            products = connection.edges.map(\.node)
        } catch {
            print("[ShopifyFeedStore] Failed to load products: \(error)")
            products = []
        }
    }
}

/// Produkter-feeden. Toppen har två pill-flikar — Begagnat (community-
/// annonser i sticky-header + 2-kols grid) och "Sälj till Up&Down" (hero,
/// payout-kalkylator, fyra trust-badges och en stor Up&Down-påse-produkt).
struct ProductGridView: View {
    @Binding var showCart: Bool
    @Binding var marketSubTab: Int
    /// Called when the sticky search bar is tapped. The container pushes
    /// `MarketSearchView` onto its `NavigationStack`.
    var onOpenSearch: (() -> Void)? = nil
    /// Öppnar Up&Down-påsen (`SellBagProductContainer`) som full-skärmsmodal.
    /// Presenteras av `ProductsContainerView`.
    var onOpenSellBag: (() -> Void)? = nil

    @Environment(\.marketplaceHeroNamespace) private var heroNS
    @ObservedObject private var community = CommunityListingsCache.shared
    @State private var isRefreshingCommunity = false
    @State private var topTab: TopTab = .begagnat
    @State private var selectedTrustInfo: TrustBadgeInfo?
    @State private var selectedCategoryFilter: String?

    private enum TopTab: String, Hashable, CaseIterable {
        case begagnat, saljTillUpAndDown
        var title: String {
            switch self {
            case .begagnat: return L.t(sv: "Begagnat", nb: "Brukt")
            case .saljTillUpAndDown: return L.t(sv: "Sälj till Up&Down", nb: "Selg til Up&Down")
            }
        }
    }

    private let columns = [
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8)
    ]

    private struct CategoryChip: Identifiable, Hashable {
        let id: String
        let title: String
    }

    var body: some View {
        VStack(spacing: 0) {
            topTabBar
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 6)

            switch topTab {
            case .begagnat:
                begagnatScroll
            case .saljTillUpAndDown:
                saljTillUpAndDownScroll
            }
        }
        .background(Color(.systemBackground))
        .sheet(item: $selectedTrustInfo) { info in
            TrustBadgeInfoSheet(info: info, onOpenBag: { onOpenSellBag?() })
        }
        .task {
            await loadCommunityIfNeeded()
        }
        .onReceive(NotificationCenter.default.publisher(for: .communityListingsNeedRefresh)) { _ in
            Task { @MainActor in
                isRefreshingCommunity = true
                await community.refresh(force: true)
                isRefreshingCommunity = false
            }
        }
    }

    private func loadCommunityIfNeeded() async {
        guard community.listings.isEmpty else { return }
        isRefreshingCommunity = true
        await community.refresh(force: true)
        isRefreshingCommunity = false
    }

    private func refreshCommunity() async {
        isRefreshingCommunity = true
        await community.refresh(force: true)
        isRefreshingCommunity = false
    }

    // MARK: - Top tab bar

    private var topTabBar: some View {
        HStack(spacing: 6) {
            ForEach(TopTab.allCases, id: \.self) { tab in
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    if tab == .saljTillUpAndDown {
                        // "Sälj till Up&Down"-fliken öppnar direkt
                        // produktsidan för Up&Down-påsen istället för
                        // att visa egen flik med hero/kalkylator/badges.
                        onOpenSellBag?()
                        return
                    }
                    withAnimation(.easeInOut(duration: 0.15)) {
                        topTab = tab
                    }
                } label: {
                    Text(tab.title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(topTab == tab ? .white : .primary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(
                            Capsule()
                                .fill(topTab == tab ? Color.black : Color(.systemGray6))
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Begagnat (current feed with sticky header)

    private var begagnatScroll: some View {
        ScrollView {
            LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
                // MARKET HIDDEN: sticky-header (sök + kategori-chips) och
                // listings-griden är dolda tills marketplace lanseras.
                // Hero-bannern ("Billigare än nytt...") och Up&Down-påsen-
                // kortet visas full-bleed överst.
                VStack(spacing: 16) {
                    marketHero
                    upAndDownBagPromoCard
                }
                .padding(.top, 8)
                .padding(.bottom, 12)

                if false {
                    Section {
                        VStack(spacing: 0) {
                            grid2Col
                                .padding(.horizontal, 12)
                                .padding(.top, 12)
                                .padding(.bottom, 20)
                        }
                    } header: {
                        stickyHeader
                    }
                }
            }
        }
        .refreshable { await refreshCommunity() }
    }

    // MARK: - Sälj till Up&Down (hero, payout, trust badges, bag-produkt)

    private var saljTillUpAndDownScroll: some View {
        ScrollView {
            VStack(spacing: 0) {
                marketHero
                    .padding(.top, 8)

                SellBagPayoutCalculator()
                    .padding(.horizontal, 16)
                    .padding(.top, 20)

                trustBadges
                    .padding(.top, 16)

                upAndDownBagPromoCard
                    .padding(.horizontal, 16)
                    .padding(.top, 20)
                    .padding(.bottom, 24)
            }
        }
    }

    // MARK: - Sticky header

    private var stickyHeader: some View {
        VStack(spacing: 10) {
            searchBarButton
            categoryChipsRow
        }
        .padding(.horizontal, 14)
        .padding(.top, 10)
        .padding(.bottom, 8)
        .background(Color(.systemBackground))
        .overlay(alignment: .bottom) {
            Divider()
        }
    }

    private var searchBarButton: some View {
        Button {
            onOpenSearch?()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.gray)
                    .font(.system(size: 16))

                Text(L.t(sv: "Sök på hela Up&Down", nb: "Søk på hele Up&Down"))
                    .font(.system(size: 15))
                    .foregroundColor(.gray)

                Spacer()
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
        .buttonStyle(.plain)
    }

    private var categoryChipsRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                categoryChipButton(
                    title: L.t(sv: "Alla", nb: "Alle"),
                    isSelected: selectedCategoryFilter == nil
                ) {
                    selectedCategoryFilter = nil
                }
                ForEach(availableCategoryChips) { chip in
                    categoryChipButton(
                        title: chip.title,
                        isSelected: selectedCategoryFilter == chip.title
                    ) {
                        selectedCategoryFilter = (selectedCategoryFilter == chip.title) ? nil : chip.title
                    }
                }
            }
            .padding(.horizontal, 1)
        }
    }

    private func categoryChipButton(
        title: String,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(isSelected ? .white : .primary)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(isSelected ? Color.black : Color(.systemGray6))
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Grid

    @ViewBuilder
    private var grid2Col: some View {
        if community.listings.isEmpty && isRefreshingCommunity {
            LazyVGrid(columns: columns, spacing: 14) {
                ForEach(0..<4, id: \.self) { _ in
                    ProductCardSkeleton()
                }
            }
        } else {
            if filteredListings.isEmpty {
                emptyState
            } else {
                if filteredListings.count > 4 {
                    VStack(spacing: 14) {
                        LazyVGrid(columns: columns, spacing: 14) {
                            ForEach(Array(filteredListings.prefix(4))) { row in
                                listingCard(for: row)
                            }
                        }

                        nybegagnatHero

                        LazyVGrid(columns: columns, spacing: 14) {
                            ForEach(Array(filteredListings.dropFirst(4))) { row in
                                listingCard(for: row)
                            }
                        }
                    }
                } else {
                    LazyVGrid(columns: columns, spacing: 14) {
                        ForEach(filteredListings) { row in
                            listingCard(for: row)
                        }
                    }
                }
            }
        }
    }

    private func listingCard(for row: ConsignmentSubmissionRow) -> some View {
        NavigationLink(value: MarketplaceRoute.listing(row)) {
            CommunityListingCard(row: row)
        }
        .buttonStyle(PressableCardButtonStyle())
        .modifier(MarketplaceHeroSourceModifier(id: row.id, namespace: heroNS))
    }

    private var filteredListings: [ConsignmentSubmissionRow] {
        guard let selectedCategoryFilter else { return community.listings }
        return community.listings.filter { normalizeCategory($0.category) == normalizeCategory(selectedCategoryFilter) }
    }

    private var availableCategoryChips: [CategoryChip] {
        let liveCategorySet = Set(community.listings.map { normalizeCategory($0.category) })
        return allCategoryChips.filter { liveCategorySet.contains(normalizeCategory($0.title)) }
    }

    private var allCategoryChips: [CategoryChip] {
        var chips: [CategoryChip] = []
        var seen: Set<String> = []

        for category in SportCategory.all {
            appendCategoryChip(title: category.displayName, into: &chips, seen: &seen)
            for subcategory in category.subcategories {
                appendCategoryChip(title: subcategory.displayName, into: &chips, seen: &seen)
            }
        }

        return chips
    }

    private func appendCategoryChip(
        title: String,
        into chips: inout [CategoryChip],
        seen: inout Set<String>
    ) {
        let normalized = normalizeCategory(title)
        guard !normalized.isEmpty, !seen.contains(normalized) else { return }
        seen.insert(normalized)
        chips.append(CategoryChip(id: normalized, title: title))
    }

    private func normalizeCategory(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .replacingOccurrences(of: "&", with: "och")
            .replacingOccurrences(of: "-", with: " ")
            .replacingOccurrences(of: ",", with: " ")
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    private var nybegagnatHero: some View {
        Image("106")
            .resizable()
            .scaledToFit()
            .frame(maxWidth: .infinity)
            .padding(.top, 8)
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 32))
                .foregroundStyle(.secondary)
            Text(emptyStateText)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 40)
        .padding(.horizontal, 24)
    }

    private var emptyStateText: String {
        L.t(sv: "Inga annonser just nu", nb: "Ingen annonser akkurat nå")
    }

    // MARK: - Market Hero

    /// Full-bleed hero som renderar asset "106" i sin naturliga bildförhållande
    /// (ingen beskärning, ingen overlay) — används överst på Sälj-fliken.
    private var marketHero: some View {
        Image("106")
            .resizable()
            .scaledToFit()
            .frame(maxWidth: .infinity)
    }

    // MARK: - Up&Down-påsen (stor full-width produkt)

    /// Up&Down-påsen som ett produkt-stilskort: stor kvadratisk produktbild
    /// med en "Up&DownMarket"-badge överst-vänster, följt av pris, titel och
    /// en grön "I lager"-indikator. Tap öppnar fortfarande
    /// `SellBagProductContainer` fullscreen via `onOpenSellBag?()`.
    private var upAndDownBagPromoCard: some View {
        Button {
            onOpenSellBag?()
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                Image("108")
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity)
                    .overlay(alignment: .bottomLeading) {
                        HStack(spacing: 6) {
                            Image("23")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 16, height: 16)
                            Text("Up&DownMarket")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.black)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(Color.white))
                        .padding(12)
                    }

                VStack(alignment: .leading, spacing: 4) {
                    Text("39 SEK")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.primary)

                    Text(L.t(sv: "Up&Down-påsen", nb: "Up&Down-posen"))
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.primary)

                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 13))
                            .foregroundColor(.green)
                        Text(L.t(sv: "I lager", nb: "På lager"))
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal, 16)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Trust Badges (2x2)

    private var trustBadges: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                trustBadge(
                    icon: .symbol("arrow.triangle.2.circlepath"),
                    title: L.t(sv: "Hur det funkar", nb: "Slik funker det"),
                    info: .howItWorks
                )
                trustBadge(
                    icon: .symbol("shippingbox.fill"),
                    title: L.t(sv: "1–3 dagars leverans", nb: "1–3 dagers levering"),
                    info: .delivery
                )
            }
            HStack(spacing: 10) {
                trustBadge(
                    icon: .symbol("hand.thumbsup.fill"),
                    title: L.t(sv: "Nöjdhetsgaranti", nb: "Fornøydhetsgaranti"),
                    info: .satisfaction
                )
                trustBadge(
                    icon: .symbol("checkmark.seal.fill"),
                    title: L.t(sv: "Hitta våra produkter", nb: "Finn våre produkter"),
                    info: .findProducts
                )
            }
        }
        .padding(.horizontal, 16)
    }

    private func trustBadge(icon: TrustBadgeIcon, title: String, info: TrustBadgeInfo) -> some View {
        Button {
            selectedTrustInfo = info
        } label: {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(Color.black)
                        .frame(width: 28, height: 28)
                    switch icon {
                    case .symbol(let name):
                        Image(systemName: name)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.white)
                    case .asset(let name):
                        Image(name)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 18, height: 18)
                    }
                }
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color(.systemGray6))
            )
        }
        .buttonStyle(.plain)
    }

}

// MARK: - Trust Badge Info

/// Vilket förklaringssheet som ska visas när användaren trycker på en av
/// de fyra trust-rutorna på Sälj-fliken.
enum TrustBadgeInfo: Identifiable {
    case howItWorks, delivery, satisfaction, findProducts
    var id: Self { self }
}

/// Ikon-variant så samma ruta kan rendera antingen en SF Symbol eller en
/// bundled asset.
enum TrustBadgeIcon {
    case symbol(String)
    case asset(String)
}

/// Sheet som förklarar en specifik trust-promise. `.howItWorks` renderar
/// även en CTA-knapp som öppnar Up&Down-påsen.
struct TrustBadgeInfoSheet: View {
    let info: TrustBadgeInfo
    /// Kallas av `.howItWorks`-CTA:n efter sheeten stängt sig.
    var onOpenBag: (() -> Void)? = nil

    @Environment(\.dismiss) private var dismiss

    private let badgeColor = Color.black

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header

                    Text(bodyText)
                        .font(.system(size: 16))
                        .foregroundColor(.secondary)
                        .lineSpacing(4)
                        .fixedSize(horizontal: false, vertical: true)

                    if case .howItWorks = info {
                        Button {
                            dismiss()
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                                onOpenBag?()
                            }
                        } label: {
                            Text(L.t(sv: "Beställ Up&Down-påsen", nb: "Bestill Up&Down-posen"))
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(Color.black)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                        .padding(.top, 4)
                    }
                }
                .padding(20)
                .padding(.bottom, 40)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    @ViewBuilder
    private var header: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(badgeColor)
                    .frame(width: 52, height: 52)
                switch iconVariant {
                case .symbol(let name):
                    Image(systemName: name)
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(.white)
                case .asset(let name):
                    Image(name)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 32, height: 32)
                }
            }

            Text(title)
                .font(.system(size: 24, weight: .bold))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var title: String {
        switch info {
        case .howItWorks:
            return L.t(sv: "Hur det funkar", nb: "Slik funker det")
        case .delivery:
            return L.t(sv: "1–3 dagars leverans", nb: "1–3 dagers levering")
        case .satisfaction:
            return L.t(sv: "Nöjdhetsgaranti", nb: "Fornøydhetsgaranti")
        case .findProducts:
            return L.t(sv: "Hitta våra produkter", nb: "Finn våre produkter")
        }
    }

    private var iconVariant: TrustBadgeIcon {
        switch info {
        case .howItWorks: return .symbol("arrow.triangle.2.circlepath")
        case .delivery: return .symbol("shippingbox.fill")
        case .satisfaction: return .symbol("hand.thumbsup.fill")
        case .findProducts: return .symbol("checkmark.seal.fill")
        }
    }

    private var bodyText: String {
        switch info {
        case .howItWorks:
            return L.t(
                sv: "Fyll Up&Down-påsen med sportutrustning du inte längre använder. Vi hämtar, fotograferar, listar och säljer åt dig — du behåller upp till 85 % av slutpriset. Klart på några dagar, utan att du lyfter ett finger.",
                nb: "Fyll Up&Down-posen med sportutstyr du ikke lenger bruker. Vi henter, fotograferer, lister og selger for deg — du beholder opptil 85 % av sluttprisen. Ferdig på få dager, uten at du løfter en finger."
            )
        case .delivery:
            return L.t(
                sv: "Vi packar och skickar alla beställningar från vårt lager i Sverige inom 24 timmar på vardagar. Med spårbar frakt har du normalt ditt paket inom 1–3 arbetsdagar, oavsett var i landet du bor. Du får ett kvitto och ett spårningsnummer direkt när din order skickas.",
                nb: "Vi pakker og sender alle bestillinger fra lageret vårt i Sverige innen 24 timer på hverdager. Med sporbar frakt har du normalt pakken din innen 1–3 arbeidsdager, uansett hvor i landet du bor. Du får en kvittering og et sporingsnummer så snart bestillingen din er sendt."
            )
        case .satisfaction:
            return L.t(
                sv: "Du ska alltid känna dig trygg när du handlar hos oss. Därför har du alltid 30 dagars öppet köp på allt du köper i Market. Skicka tillbaka varan i oanvänt skick inom 30 dagar så får du pengarna tillbaka utan krångel — inga gissningar, inga undantag.",
                nb: "Du skal alltid føle deg trygg når du handler hos oss. Derfor har du alltid 30 dagers åpent kjøp på alt du kjøper i Market. Send tilbake varen i ubrukt stand innen 30 dager så får du pengene tilbake uten styr — ingen gjetning, ingen unntak."
            )
        case .findProducts:
            return L.t(
                sv: "Varje annons som säljs direkt av Up&Down märks med vår logga. Så du ser i listan att varan är kvalitetssäkrad, packas från vårt lager och skickas inom 1–3 dagar.",
                nb: "Hver annonse som selges direkte av Up&Down merkes med logoen vår. Så du ser i listen at varen er kvalitetssikret, pakkes fra lageret vårt og sendes innen 1–3 dager."
            )
        }
    }
}

// MARK: - Product Card (Shopify)

/// Kvar för att `ProductDetailView` fortfarande renderar relaterade
/// Shopify-produkter i en 2-kolumns grid längst ner på sidan.
struct ProductCard: View {
    let product: ShopifyProduct
    @State private var cachedImage: UIImage?
    @State private var imageLoading = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ZStack {
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
            .frame(maxWidth: .infinity)
            .aspectRatio(4.0 / 5.0, contentMode: .fit)
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

// MARK: - Skeleton

struct ProductCardSkeleton: View {
    @State private var isAnimating = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            RoundedRectangle(cornerRadius: 12)
                .fill(shimmerGradient)
                .frame(maxWidth: .infinity)
                .aspectRatio(4.0 / 5.0, contentMode: .fit)

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
