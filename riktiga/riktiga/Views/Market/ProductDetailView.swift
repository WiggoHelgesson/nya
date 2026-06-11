import SwiftUI

struct ProductDetailView: View {
    @State private var product: ShopifyProduct
    @Binding var showCart: Bool
    @EnvironmentObject var authViewModel: AuthViewModel
    @ObservedObject private var cartManager = CartManager.shared
    @State private var selectedVariant: ShopifyVariant?
    @State private var selectedImageIndex = 0
    @State private var addedToCart = false
    @State private var isFavorite = false
    @State private var isCheckingOut = false
    @State private var checkoutURL: URL?
    @State private var showCheckoutSafari = false
    @State private var isRedeemingDiscount = false
    @State private var redeemingTierId: UUID?
    @State private var showRedeemConfirmation = false
    @State private var pendingRedeemTier: DiscountTier?
    @State private var pendingRedeemVariantId: String?
    @State private var showSizeAlert = false
    @State private var relatedProducts: [ShopifyProduct] = []
    @State private var isLoadingRelated = false
    @State private var isPurchasable = false
    @State private var isHydratingProduct = true
    @State private var checkoutErrorMessage: String?
    @State private var showCheckoutError = false
    @ObservedObject private var rewardService = FreeRewardService.shared
    @State private var isRedeemingFreeReward = false
    @State private var showFreeRewardConfirmation = false
    @Environment(\.dismiss) private var dismiss

    init(product: ShopifyProduct, showCart: Binding<Bool>) {
        _product = State(initialValue: product)
        _showCart = showCart
    }

    private var variants: [ShopifyVariant] {
        product.variants.edges.map(\.node)
    }

    private var images: [URL] {
        product.allImages
    }

    private var conditionLabel: String {
        let tags = product.tags.map { $0.lowercased() }
        if tags.contains("nyskick") || tags.contains("skick a") { return "Nyskick" }
        if tags.contains("gott skick") || tags.contains("skick b") { return "Gott skick" }
        if tags.contains("ok skick") || tags.contains("skick c") { return "OK skick" }
        return "Nyskick"
    }

    private var conditionColor: Color {
        switch conditionLabel {
        case "Nyskick": return .green
        case "Gott skick": return .orange
        default: return .yellow
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                imageCarousel
                productHeader
                    .padding(.top, 20)
                priceSection
                    .padding(.top, 8)
                if rewardService.isEligible(product) {
                    freeRewardCard
                        .padding(.top, 12)
                        .padding(.horizontal, 16)
                }
                if hasMeaningfulVariants {
                    variantSelector
                        .padding(.top, 16)
                }
                if !isHydratingProduct && !isPurchasable {
                    notPurchasableBanner
                        .padding(.top, 16)
                        .padding(.horizontal, 16)
                }
                actionButtons
                    .padding(.top, 16)
                    .padding(.horizontal, 16)
                if isSellBagProduct {
                    sellBagAcceptanceSection
                        .padding(.top, 16)
                        .padding(.horizontal, 16)
                    sellBagEstimatorSection
                        .padding(.top, 16)
                        .padding(.horizontal, 16)
                }
                shippingInfo
                    .padding(.top, 24)
                    .padding(.horizontal, 16)
                descriptionSection
                    .padding(.top, 24)
                if !relatedProducts.isEmpty {
                    relatedProductsSection
                        .padding(.top, 32)
                }
                Spacer(minLength: 40)
            }
        }
        .task(id: product.handle) {
            await hydrateProductFromStorefront()
        }
        .task(id: product.id) {
            await loadRelatedProducts()
        }
        .navigationBarTitleDisplayMode(.inline)
        .alert(
            L.t(sv: "Välj variant", nb: "Velg variant"),
            isPresented: $showSizeAlert
        ) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(L.t(
                sv: "Du måste välja färg och storlek innan du kan köpa",
                nb: "Du må velge farge og størrelse før du kan kjøpe"
            ))
        }
        .alert(
            L.t(sv: "Är du säker?", nb: "Er du sikker?"),
            isPresented: $showRedeemConfirmation
        ) {
            Button(L.t(sv: "Avbryt", nb: "Avbryt"), role: .cancel) {
                pendingRedeemTier = nil
                pendingRedeemVariantId = nil
            }
            Button(L.t(sv: "Fortsätt", nb: "Fortsett")) {
                guard let tier = pendingRedeemTier,
                      let variantId = pendingRedeemVariantId else { return }
                Task { await buyWithDiscount(variantId: variantId, tier: tier) }
                pendingRedeemTier = nil
                pendingRedeemVariantId = nil
            }
        } message: {
            Text(L.t(
                sv: "Dina poäng kommer att dras om du väljer att fortsätta",
                nb: "Poengene dine vil bli trukket hvis du velger å fortsette"
            ))
        }
        .alert(
            L.t(sv: "Hämta gratis produkt?", nb: "Hente gratis produkt?"),
            isPresented: $showFreeRewardConfirmation
        ) {
            Button(L.t(sv: "Avbryt", nb: "Avbryt"), role: .cancel) { }
            Button(L.t(sv: "Fortsätt", nb: "Fortsett")) {
                Task { await redeemFreeProduct() }
            }
        } message: {
            Text(L.t(
                sv: "Du löser in din 3-månadersbelöning. Frakt tillkommer.",
                nb: "Du løser inn 3-månedersbelønningen din. Frakt kommer i tillegg."
            ))
        }
        .task { await rewardService.syncAndFetchStatus() }
        .onAppear { RecentlyViewedStore.shared.record(product) }
        .fullScreenCover(isPresented: $showCheckoutSafari) {
            if let url = checkoutURL {
                SafariView(url: url)
                    .ignoresSafeArea()
            }
        }
        .alert(
            L.t(sv: "Kunde inte slutföra köpet", nb: "Kunne ikke fullføre kjøpet"),
            isPresented: $showCheckoutError
        ) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(checkoutErrorMessage ?? L.t(
                sv: "Något gick fel. Försök igen.",
                nb: "Noe gikk galt. Prøv igjen."
            ))
        }
        .onAppear {
            if selectedVariant == nil {
                selectedVariant = product.firstAvailableVariant ?? variants.first
            }
            NavigationDepthTracker.shared.acquireHideTabBar()
        }
        .onDisappear {
            NavigationDepthTracker.shared.releaseHideTabBar()
        }
    }

    private var hasMeaningfulVariants: Bool {
        if variants.count <= 1 { return false }
        let onlyDefault = variants.allSatisfy { variant in
            variant.selectedOptions.count == 1 &&
            variant.selectedOptions.first?.name.lowercased() == "title" &&
            variant.selectedOptions.first?.value.lowercased() == "default title"
        }
        return !onlyDefault
    }

    private var currentXP: Int {
        authViewModel.currentUser?.currentXP ?? 0
    }

    private var isPro: Bool {
        authViewModel.currentUser?.isProMember ?? false
    }

    private var productPrice: Double {
        Double(selectedVariant?.price.amount ?? product.minPrice) ?? 0
    }

    private var productCurrency: String {
        selectedVariant?.price.currencyCode ?? product.currencyCode
    }

    // MARK: - Image Carousel

    private var imageCarousel: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $selectedImageIndex) {
                if product.allImages.isEmpty {
                    galleryPlaceholder.tag(0)
                } else {
                    ForEach(product.allImages.indices, id: \.self) { index in
                        CachedGalleryImage(urlString: product.allImages[index].absoluteString)
                            .tag(index)
                    }
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(height: 400)
            .background(Color(.systemGray6))
            .task { prefetchGalleryImages() }

            if product.allImages.count > 1 {
                HStack(spacing: 6) {
                    ForEach(product.allImages.indices, id: \.self) { index in
                        Circle()
                            .fill(selectedImageIndex == index ? Color.primary : Color.gray.opacity(0.4))
                            .frame(width: 7, height: 7)
                    }
                }
                .padding(.bottom, 12)
            }
        }
    }

    private func prefetchGalleryImages() {
        let urls = product.images.edges.map(\.node.url)
        ImageCacheManager.shared.prefetch(urls: urls)
    }

    private var galleryPlaceholder: some View {
        Rectangle()
            .fill(Color(.systemGray5))
            .overlay {
                Image(systemName: "photo")
                    .foregroundColor(.gray)
                    .font(.system(size: 40))
            }
    }

    // MARK: - Product Header (title + share)

    private var productHeader: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(product.title)
                .font(.system(size: 22, weight: .bold))
                .lineLimit(3)

            Text(conditionLabel)
                .font(.system(size: 14))
                .foregroundColor(.gray)
        }
        .padding(.horizontal, 16)
    }

    // MARK: - Price

    private var priceSection: some View {
        HStack(spacing: 6) {
            Text(selectedVariant?.formattedPrice ?? product.formattedPrice)
                .font(.system(size: 22, weight: .bold))

            Image(systemName: "info.circle")
                .font(.system(size: 14))
                .foregroundColor(.gray)
        }
        .padding(.horizontal, 16)
    }

    // MARK: - Free Reward Card

    private var rewardGold: Color { Color(red: 0.85, green: 0.65, blue: 0.1) }

    /// Kort under priset på eligible produkter:
    /// - Intjänad reward: hämta gratis-knapp (bekräftelse → checkout med 100%-kod)
    /// - Pro under intjäning: "låses upp om X dagar"
    /// - Icke-Pro: upsell till Pro via paywall
    @ViewBuilder
    private var freeRewardCard: some View {
        let status = rewardService.status

        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "gift.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(rewardGold)
                Text(L.t(sv: "GRATIS för Pro", nb: "GRATIS for Pro"))
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(rewardGold)
                Spacer()
            }

            if status?.hasEarnedReward == true {
                Text(L.t(
                    sv: "Du har en intjänad Pro-belöning — hämta denna produkt gratis. Frakt tillkommer.",
                    nb: "Du har en opptjent Pro-belønning — hent dette produktet gratis. Frakt kommer i tillegg."
                ))
                .font(.system(size: 13))
                .foregroundColor(.primary)
                .fixedSize(horizontal: false, vertical: true)

                Button {
                    guard !isRedeemingFreeReward else { return }
                    if hasMeaningfulVariants && selectedVariant == nil {
                        showSizeAlert = true
                        return
                    }
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    showFreeRewardConfirmation = true
                } label: {
                    HStack(spacing: 8) {
                        if isRedeemingFreeReward {
                            ProgressView().tint(.white)
                        } else {
                            Image(systemName: "gift.fill")
                                .font(.system(size: 14, weight: .semibold))
                            Text(L.t(sv: "Hämta gratis med din Pro-belöning", nb: "Hent gratis med Pro-belønningen din"))
                                .font(.system(size: 15, weight: .bold))
                        }
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(canPurchase ? rewardGold : Color.gray.opacity(0.4))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .disabled(isRedeemingFreeReward || !canPurchase)
            } else if status?.isPro == true, let days = status?.daysRemaining {
                HStack(spacing: 8) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                    Text(L.t(
                        sv: "Din gratisprodukt låses upp om \(days) dagar",
                        nb: "Gratisproduktet ditt låses opp om \(days) dager"
                    ))
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.secondary)
                }
            } else {
                Text(L.t(
                    sv: "Pro-medlemmar får en sådan här produkt gratis var 3:e månad.",
                    nb: "Pro-medlemmer får et slikt produkt gratis hver 3. måned."
                ))
                .font(.system(size: 13))
                .foregroundColor(.primary)
                .fixedSize(horizontal: false, vertical: true)

                Button {
                    SuperwallService.shared.showPaywall()
                } label: {
                    HStack(spacing: 6) {
                        Text("✦")
                            .font(.system(size: 11))
                        Text(L.t(sv: "Bli Pro", nb: "Bli Pro"))
                            .font(.system(size: 14, weight: .bold))
                    }
                    .foregroundColor(Color(red: 0.55, green: 0.42, blue: 0.06))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color(red: 1, green: 0.9, blue: 0.4).opacity(0.9))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(rewardGold.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(rewardGold.opacity(0.35), lineWidth: 1)
        )
    }

    // MARK: - Not Purchasable Banner

    private var notPurchasableBanner: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "info.circle.fill")
                .font(.system(size: 16))
                .foregroundColor(.secondary)
            Text(L.t(
                sv: "Produkten kan visas men är inte tillgänglig för köp i appen ännu.",
                nb: "Produktet kan vises, men er ikke tilgjengelig for kjøp i appen ennå."
            ))
            .font(.system(size: 14))
            .foregroundColor(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6))
        )
    }

    // MARK: - Action Buttons

    private var canPurchase: Bool {
        isPurchasable && !isHydratingProduct
    }

    private var actionButtons: some View {
        VStack(spacing: 10) {
            Button {
                guard let variant = selectedVariant else {
                    showSizeAlert = true
                    return
                }
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                Task { await buyNow(variantId: variant.id) }
            } label: {
                HStack(spacing: 8) {
                    if isCheckingOut || isHydratingProduct {
                        ProgressView().tint(.white)
                    } else {
                        Text(L.t(sv: "Köp nu", nb: "Kjøp nå"))
                            .font(.system(size: 16, weight: .bold))
                    }
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(canPurchase ? Color.black : Color.gray.opacity(0.4))
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .disabled(isCheckingOut || !canPurchase)

            if !isSellBagProduct {
                pointsDiscountDropdown
                    .opacity(canPurchase ? 1 : 0.5)
                    .allowsHitTesting(canPurchase)
            }
        }
    }

    // MARK: - Points Discount Dropdown

    private var pointsDiscountDropdown: some View {
        VStack(spacing: 0) {
            // Header row
            HStack(spacing: 8) {
                Text(L.t(
                    sv: "Lös in poäng mot rabatt",
                    nb: "Løs inn poeng mot rabatt"
                ))
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.primary)

                Spacer()

                HStack(spacing: 6) {
                    Image("101")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 16, height: 16)
                    Text("\(currentXP) XP")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.primary)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)

            VStack(spacing: 0) {
                Divider().padding(.horizontal, 14)

                ForEach(PointsDiscountService.tiers) { tier in
                    let activePercent = tier.percent(isPro: isPro)
                    let discounted = productPrice * (1.0 - Double(activePercent) / 100.0)
                    let canAfford = currentXP >= tier.xpCost
                    let isRedeeming = redeemingTierId == tier.id

                    VStack(spacing: 0) {
                        HStack(alignment: .center) {
                            VStack(alignment: .leading, spacing: 4) {
                                // XP cost + discount badge(es)
                                HStack(spacing: 6) {
                                    Text("\(tier.xpCost) XP")
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundColor(canAfford ? .primary : .gray)

                                    if isPro {
                                        // Pro user: single gold badge
                                        HStack(spacing: 3) {
                                            Text("✦")
                                                .font(.system(size: 9))
                                            Text("\(activePercent)%")
                                                .font(.system(size: 12, weight: .bold))
                                        }
                                        .foregroundColor(canAfford ? Color(red: 0.55, green: 0.42, blue: 0.06) : .gray)
                                        .padding(.horizontal, 7)
                                        .padding(.vertical, 3)
                                        .background(canAfford ? Color(red: 1, green: 0.9, blue: 0.4).opacity(0.9) : Color.gray.opacity(0.15))
                                        .clipShape(RoundedRectangle(cornerRadius: 5))
                                    } else {
                                        // Non-Pro: show free rate in black + Pro rate in gold
                                        Text("\(tier.freePercent)%")
                                            .font(.system(size: 12, weight: .bold))
                                            .foregroundColor(.white)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 3)
                                            .background(canAfford ? Color.black : Color.gray.opacity(0.4))
                                            .clipShape(RoundedRectangle(cornerRadius: 5))

                                        Button {
                                            SuperwallService.shared.showPaywall()
                                        } label: {
                                            HStack(spacing: 3) {
                                                Text("✦")
                                                    .font(.system(size: 9))
                                                Text("\(tier.proPercent)% PRO")
                                                    .font(.system(size: 11, weight: .bold))
                                            }
                                            .foregroundColor(Color(red: 0.55, green: 0.42, blue: 0.06))
                                            .padding(.horizontal, 7)
                                            .padding(.vertical, 3)
                                            .background(Color(red: 1, green: 0.9, blue: 0.4).opacity(0.85))
                                            .clipShape(RoundedRectangle(cornerRadius: 5))
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }

                                // Price row
                                HStack(spacing: 4) {
                                    Text("\(Int(productPrice)) \(productCurrency)")
                                        .font(.system(size: 13))
                                        .strikethrough()
                                        .foregroundColor(.gray)

                                    Text("\(Int(discounted)) \(productCurrency)")
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundColor(canAfford ? .primary : .gray)
                                }
                            }

                            Spacer()

                            Button {
                                guard canAfford else { return }
                                guard let variant = selectedVariant ?? product.firstAvailableVariant else { return }
                                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                pendingRedeemTier = tier
                                pendingRedeemVariantId = variant.id
                                showRedeemConfirmation = true
                            } label: {
                                HStack(spacing: 4) {
                                    if isRedeeming {
                                        ProgressView()
                                            .tint(.white)
                                            .scaleEffect(0.7)
                                    } else {
                                        Text(L.t(sv: "Köp", nb: "Kjøp"))
                                            .font(.system(size: 13, weight: .bold))
                                    }
                                }
                                .foregroundColor(.white)
                                .frame(width: 64, height: 34)
                                .background(canAfford ? Color.black : Color.gray.opacity(0.3))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                            .disabled(!canAfford || isRedeemingDiscount)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)

                        if tier.xpCost != PointsDiscountService.tiers.last?.xpCost {
                            Divider().padding(.horizontal, 14)
                        }
                    }
                }

                // Pro upgrade banner for non-Pro users
                if !isPro {
                    Divider().padding(.horizontal, 14)
                    Button {
                        SuperwallService.shared.showPaywall()
                    } label: {
                        HStack(spacing: 8) {
                            Text("✦")
                                .font(.system(size: 11))
                                .foregroundColor(Color(red: 0.55, green: 0.42, blue: 0.06))
                            Text(L.t(
                                sv: "Bli Pro och dubblera din rabatt — upp till 40 %",
                                nb: "Bli Pro og dobbel rabatten — opptil 40 %"
                            ))
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.primary)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 11)
                        .background(Color(red: 1, green: 0.97, blue: 0.75).opacity(0.6))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6).opacity(0.6))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(.separator).opacity(0.3), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Storefront Hydration

    private func hydrateProductFromStorefront() async {
        isHydratingProduct = true
        defer { isHydratingProduct = false }

        let previousVariant = selectedVariant
        do {
            if let storefrontProduct = try await ShopifyService.shared.fetchProductByHandle(product.handle) {
                product = storefrontProduct
                selectedVariant = matchVariant(previousVariant, in: storefrontProduct.variants.edges.map(\.node))
                isPurchasable = true
            } else {
                isPurchasable = false
            }
        } catch {
            print("[ProductDetail] Storefront hydration failed: \(error.localizedDescription)")
            isPurchasable = false
        }
    }

    private func matchVariant(_ previous: ShopifyVariant?, in newVariants: [ShopifyVariant]) -> ShopifyVariant? {
        guard let previous else {
            return newVariants.first(where: \.availableForSale) ?? newVariants.first
        }
        if let exact = newVariants.first(where: { $0.id == previous.id }) {
            return exact
        }
        return newVariants.first { variant in
            previous.selectedOptions.allSatisfy { option in
                variant.selectedOptions.contains { $0.name == option.name && $0.value == option.value }
            }
        } ?? newVariants.first(where: \.availableForSale) ?? newVariants.first
    }

    // MARK: - Checkout Helpers

    private func buyNow(variantId: String) async {
        guard canPurchase else { return }

        isCheckingOut = true
        defer { isCheckingOut = false }

        do {
            let cart = try await ShopifyService.shared.cartCreate(variantId: variantId, quantity: 1)
            print("[Checkout] cart.checkoutUrl = \(cart.checkoutUrl)")
            guard let url = URL(string: cart.checkoutUrl) else {
                showCheckoutFailure(L.t(
                    sv: "Kunde inte öppna kassan. Försök igen.",
                    nb: "Kunne ikke åpne kassen. Prøv igjen."
                ))
                return
            }
            checkoutURL = url
            showCheckoutSafari = true
        } catch {
            print("[Checkout] Buy now error: \(error.localizedDescription)")
            showCheckoutFailure(error.localizedDescription)
        }
    }

    private func buyWithDiscount(variantId: String, tier: DiscountTier) async {
        guard canPurchase else { return }

        isRedeemingDiscount = true
        redeemingTierId = tier.id
        defer {
            isRedeemingDiscount = false
            redeemingTierId = nil
        }

        do {
            guard let userId = authViewModel.currentUser?.id else { return }

            let cart = try await ShopifyService.shared.cartCreate(variantId: variantId, quantity: 1)
            let discount = try await PointsDiscountService.shared.redeemDiscount(
                userId: userId, tier: tier, isPro: isPro
            )
            let updatedCart = try await ShopifyService.shared.cartDiscountCodesUpdate(
                cartId: cart.id, discountCodes: [discount.code]
            )
            print("[Checkout] discounted checkoutUrl = \(updatedCart.checkoutUrl)")
            guard let url = URL(string: updatedCart.checkoutUrl) else {
                showCheckoutFailure(L.t(
                    sv: "Kunde inte öppna kassan. Försök igen.",
                    nb: "Kunne ikke åpne kassen. Prøv igjen."
                ))
                return
            }
            checkoutURL = url
            showCheckoutSafari = true
        } catch {
            print("[Checkout] Discount checkout error: \(error.localizedDescription)")
            showCheckoutFailure(error.localizedDescription)
        }
    }

    /// Löser in Pro-belöningen: skapar 100%-kod via edge-funktionen, applicerar
    /// den på en ny cart och öppnar checkout (frakt betalas som vanligt).
    private func redeemFreeProduct() async {
        guard canPurchase else { return }
        guard let variant = selectedVariant ?? product.firstAvailableVariant else {
            showSizeAlert = true
            return
        }

        isRedeemingFreeReward = true
        defer { isRedeemingFreeReward = false }

        do {
            let cart = try await ShopifyService.shared.cartCreate(variantId: variant.id, quantity: 1)
            let result = try await FreeRewardService.shared.redeem(product: product)
            let updatedCart = try await ShopifyService.shared.cartDiscountCodesUpdate(
                cartId: cart.id, discountCodes: [result.code]
            )
            print("[Checkout] free reward checkoutUrl = \(updatedCart.checkoutUrl)")
            guard let url = URL(string: updatedCart.checkoutUrl) else {
                showCheckoutFailure(L.t(
                    sv: "Kunde inte öppna kassan. Försök igen.",
                    nb: "Kunne ikke åpne kassen. Prøv igjen."
                ))
                return
            }
            checkoutURL = url
            showCheckoutSafari = true
        } catch {
            print("[Checkout] Free reward redemption error: \(error.localizedDescription)")
            showCheckoutFailure(error.localizedDescription)
        }
    }

    private func showCheckoutFailure(_ message: String) {
        checkoutErrorMessage = message
        showCheckoutError = true
    }

    // MARK: - Payment Icons

    private var paymentIcons: some View {
        HStack(spacing: 10) {
            Spacer()
            paymentBadge("Klarna.", backgroundColor: Color(red: 1.0, green: 0.71, blue: 0.76))
            paymentBadge("MasterCard", backgroundColor: Color(.systemGray5))
            paymentBadge("G Pay", backgroundColor: Color(.systemGray5))
            Spacer()
        }
    }

    private func paymentBadge(_ text: String, backgroundColor: Color) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .bold))
            .foregroundColor(.black)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(backgroundColor)
            .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    // MARK: - Shipping Info

    private var shippingInfo: some View {
        VStack(spacing: 0) {
            shippingRow(
                icon: "arrow.counterclockwise",
                title: L.t(sv: "30 dagars öppet köp", nb: "30 dagers åpent kjøp"),
                subtitle: L.t(sv: "Enkel retur utan krångel", nb: "Enkel retur uten problemer")
            )

            Divider().padding(.leading, 52)

            shippingRow(
                icon: "shippingbox.fill",
                title: L.t(sv: "1–3 dagars leveranstid", nb: "1–3 dagers leveringstid"),
                subtitle: L.t(sv: "Direkt till din dörr", nb: "Direkte til din dør")
            )
        }
    }

    private func shippingRow(icon: String, title: String, subtitle: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(.primary)
                .frame(width: 28, alignment: .center)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                Text(subtitle)
                    .font(.system(size: 13))
                    .foregroundColor(.gray)
            }

            Spacer()
        }
        .padding(.vertical, 12)
    }

    // MARK: - Condition Card

    private var conditionCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Circle()
                    .fill(conditionColor)
                    .frame(width: 10, height: 10)

                Text(L.t(
                    sv: "Skick A — \(conditionLabel)",
                    nb: "Tilstand A — \(conditionLabel)"
                ))
                .font(.system(size: 16, weight: .semibold))
            }

            Text(L.t(
                sv: "Som ny — minimala tecken på användning, fullt funktionell.",
                nb: "Som ny — minimale tegn på bruk, fullt funksjonell."
            ))
            .font(.system(size: 14))
            .foregroundColor(.gray)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Variant Selector

    private var variantSelector: some View {
        VStack(alignment: .leading, spacing: 16) {
            ForEach(sortedOptionNames, id: \.self) { optionName in
                VStack(alignment: .leading, spacing: 8) {
                    let selectedValue = selectedVariant?.selectedOptions.first(where: { $0.name == optionName })?.value
                    HStack(spacing: 6) {
                        Text(optionName)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.gray)
                        if let selectedValue {
                            Text("– \(selectedValue)")
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                        }
                    }

                    let values = uniqueOptionValues(for: optionName)

                    if isColorOption(optionName) {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                ForEach(values, id: \.self) { value in
                                    colorSwatchButton(optionName: optionName, value: value)
                                }
                            }
                        }
                    } else {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(values, id: \.self) { value in
                                    sizeOptionButton(optionName: optionName, value: value)
                                }
                            }
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 16)
    }

    private var sortedOptionNames: [String] {
        var seen = Set<String>()
        let allNames = variants.flatMap { $0.selectedOptions.map(\.name) }
            .filter { seen.insert($0).inserted }
        return allNames.sorted { a, _ in isColorOption(a) }
    }

    private func isColorOption(_ name: String) -> Bool {
        let lower = name.lowercased()
        return lower == "color" || lower == "colour" || lower == "färg" || lower == "farge"
    }

    private func uniqueOptionValues(for optionName: String) -> [String] {
        var seen = Set<String>()
        return variants.compactMap { variant in
            variant.selectedOptions.first(where: { $0.name == optionName })?.value
        }.filter { seen.insert($0).inserted }
    }

    private func colorForName(_ name: String) -> Color? {
        let map: [String: Color] = [
            "black": .black, "svart": .black,
            "white": .white, "vit": .white, "vitt": .white,
            "red": .red, "röd": .red, "rød": .red,
            "blue": .blue, "blå": .blue,
            "green": .green, "grön": .green, "grønn": .green,
            "yellow": .yellow, "gul": .yellow,
            "orange": .orange, "pink": .pink, "rosa": .pink,
            "purple": .purple, "lila": .purple,
            "brown": .brown, "brun": .brown,
            "gray": .gray, "grey": .gray, "grå": .gray,
            "navy": Color(red: 0, green: 0, blue: 0.5),
            "beige": Color(red: 0.96, green: 0.96, blue: 0.86),
            "cream": Color(red: 1.0, green: 0.99, blue: 0.82),
            "burgundy": Color(red: 0.5, green: 0, blue: 0.13),
            "teal": .teal, "cyan": .cyan,
        ]
        return map[name.lowercased().trimmingCharacters(in: .whitespaces)]
    }

    private func findVariant(selecting optionName: String, value: String) -> ShopifyVariant? {
        guard let current = selectedVariant else {
            return variants.first { $0.selectedOptions.contains(where: { $0.name == optionName && $0.value == value }) }
        }
        let otherSelections = current.selectedOptions.filter { $0.name != optionName }
        return variants.first { variant in
            let hasNew = variant.selectedOptions.contains(where: { $0.name == optionName && $0.value == value })
            let matchesOthers = otherSelections.allSatisfy { other in
                variant.selectedOptions.contains(where: { $0.name == other.name && $0.value == other.value })
            }
            return hasNew && matchesOthers
        } ?? variants.first { $0.selectedOptions.contains(where: { $0.name == optionName && $0.value == value }) }
    }

    private func colorSwatchButton(optionName: String, value: String) -> some View {
        let isSelected = selectedVariant?.selectedOptions.contains(where: { $0.name == optionName && $0.value == value }) ?? false
        let matchingVariant = variants.first { $0.selectedOptions.contains(where: { $0.name == optionName && $0.value == value }) }
        let isAvailable = matchingVariant?.availableForSale ?? false
        let swatchColor = colorForName(value)

        return Button {
            if let match = findVariant(selecting: optionName, value: value) {
                withAnimation(.easeInOut(duration: 0.15)) { selectedVariant = match }
                if let variantImageUrl = match.image?.url,
                   let imageIndex = product.allImages.firstIndex(where: { $0.absoluteString == variantImageUrl }) {
                    withAnimation { selectedImageIndex = imageIndex }
                }
            }
        } label: {
            if let swatchColor {
                Circle()
                    .fill(swatchColor)
                    .frame(width: 32, height: 32)
                    .overlay(Circle().stroke(swatchColor == .white ? Color(.systemGray4) : Color.clear, lineWidth: 1))
                    .overlay(Circle().stroke(isSelected ? Color.black : Color.clear, lineWidth: 2.5).frame(width: 38, height: 38))
            } else {
                Text(value)
                    .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                    .foregroundColor(isSelected ? .white : (isAvailable ? .primary : .gray))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(isSelected ? Color.black : Color(.systemGray6)))
                    .overlay(Capsule().stroke(isSelected ? Color.clear : Color(.systemGray4), lineWidth: 0.5))
            }
        }
        .disabled(!isAvailable)
        .opacity(isAvailable ? 1 : 0.4)
    }

    private func sizeOptionButton(optionName: String, value: String) -> some View {
        let isSelected = selectedVariant?.selectedOptions.contains(where: { $0.name == optionName && $0.value == value }) ?? false
        let matchingVariant = variants.first { $0.selectedOptions.contains(where: { $0.name == optionName && $0.value == value }) }
        let isAvailable = matchingVariant?.availableForSale ?? false

        return Button {
            if let match = findVariant(selecting: optionName, value: value) {
                withAnimation(.easeInOut(duration: 0.15)) { selectedVariant = match }
            }
        } label: {
            Text(value)
                .font(.system(size: 14, weight: isSelected ? .semibold : .regular))
                .foregroundColor(isSelected ? .white : (isAvailable ? .primary : .gray))
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(isSelected ? Color.black : Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .disabled(!isAvailable)
        .opacity(isAvailable ? 1 : 0.4)
    }

    // MARK: - Sell Bag Acceptance (visas endast för Up&Down-påsen)

    private var isSellBagProduct: Bool {
        product.handle == SellBagConfig.productHandle
    }

    @State private var sellBagExpanded: Bool = false

    private var sellBagAcceptanceSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            DisclosureGroup(isExpanded: $sellBagExpanded) {
                VStack(alignment: .leading, spacing: 18) {
                    sellBagList(
                        accent: .green,
                        icon: "checkmark.circle.fill",
                        title: L.t(sv: "Vi tar emot", nb: "Vi tar imot"),
                        rows: [
                            L.t(sv: "Golfklubbor (drivers, järnset, putters)",
                                nb: "Golfkøller (drivere, jernsett, puttere)"),
                            L.t(sv: "Premium sportkläder (Nike, J.Lindeberg m.fl.)",
                                nb: "Premium sportsklær (Nike, J.Lindeberg m.fl.)"),
                            L.t(sv: "Produkter i bra skick",
                                nb: "Produkter i god stand")
                        ]
                    )

                    sellBagList(
                        accent: .red,
                        icon: "xmark.circle.fill",
                        title: L.t(sv: "Vi tar inte emot", nb: "Vi tar ikke imot"),
                        rows: [
                            L.t(sv: "Slitna eller trasiga produkter",
                                nb: "Slitte eller ødelagte produkter"),
                            L.t(sv: "Low-end märken",
                                nb: "Low-end merker"),
                            L.t(sv: "Smutsiga eller defekta varor",
                                nb: "Skitne eller defekte varer"),
                            L.t(sv: "Enstaka billiga artiklar",
                                nb: "Enkeltvise billige varer")
                        ]
                    )

                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "heart.fill")
                            .foregroundColor(.orange)
                            .font(.system(size: 14, weight: .bold))
                            .padding(.top, 2)
                        Text(L.t(
                            sv: "Varor som inte uppfyller kraven skänks till välgörenhet och säljs inte.",
                            nb: "Varer som ikke oppfyller kravene doneres til veldedighet og selges ikke."
                        ))
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.orange.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .padding(.top, 16)
            } label: {
                Text(L.t(sv: "Dessa varor accepterar vi", nb: "Disse varene aksepterer vi"))
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.primary)
            }
            .tint(.primary)
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color(.secondarySystemBackground))
            )
        }
    }

    @ViewBuilder
    private func sellBagList(
        accent: Color,
        icon: String,
        title: String,
        rows: [String]
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(accent)
                Text(title)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.primary)
            }

            VStack(alignment: .leading, spacing: 8) {
                ForEach(rows, id: \.self) { row in
                    HStack(alignment: .top, spacing: 10) {
                        Circle()
                            .fill(accent.opacity(0.9))
                            .frame(width: 5, height: 5)
                            .padding(.top, 7)
                        Text(row)
                            .font(.system(size: 14))
                            .foregroundColor(.primary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
    }

    // MARK: - Sell Bag Payout Calculator

    private var sellBagEstimatorSection: some View {
        SellBagPayoutCalculator()
    }

    // MARK: - Description

    private var descriptionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !product.description.isEmpty {
                Text(L.t(sv: "Beskrivning", nb: "Beskrivelse"))
                    .font(.system(size: 16, weight: .bold))

                Text(product.description)
                    .font(.system(size: 15))
                    .foregroundColor(.primary)
            }
        }
        .padding(.horizontal, 16)
    }

    // MARK: - Related Products (Up&Down collections)

    private var relatedProductsSection: some View {
        let columns = [
            GridItem(.flexible(), spacing: 12),
            GridItem(.flexible(), spacing: 12)
        ]

        return VStack(alignment: .leading, spacing: 12) {
            Text(L.t(sv: "Mer från Up&Down", nb: "Mer fra Up&Down"))
                .font(.system(size: 18, weight: .bold))
                .padding(.horizontal, 16)

            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(relatedProducts) { related in
                    NavigationLink(value: related) {
                        ProductCard(product: related)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
        }
    }

    private func loadRelatedProducts() async {
        guard !isLoadingRelated else { return }
        isLoadingRelated = true
        defer { isLoadingRelated = false }

        async let collectionA = try? ShopifyService.shared.fetchCollectionProducts(handle: "up-down", first: 20)
        async let collectionB = try? ShopifyService.shared.fetchCollectionProducts(handle: "upanddown", first: 20)

        let combined = ((await collectionA) ?? []) + ((await collectionB) ?? [])

        // Deduplicate by id and exclude the current product
        var seen = Set<String>()
        var unique: [ShopifyProduct] = []
        for item in combined where item.id != product.id && !seen.contains(item.id) {
            seen.insert(item.id)
            unique.append(item)
        }

        // Prefetch first few images so they appear instantly
        let urls = unique.prefix(9).compactMap { $0.images.edges.first?.node.url }
        ImageCacheManager.shared.prefetch(urls: urls)

        relatedProducts = unique
    }
}

// MARK: - Cached Gallery Image

private struct CachedGalleryImage: View {
    let urlString: String
    @State private var loadedImage: UIImage?
    @State private var isLoading = true

    var body: some View {
        Group {
            if let img = loadedImage {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFit()
            } else if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                Rectangle()
                    .fill(Color(.systemGray5))
                    .overlay {
                        Image(systemName: "photo")
                            .foregroundColor(.gray)
                            .font(.system(size: 40))
                    }
            }
        }
        .onAppear { loadImage() }
    }

    private func loadImage() {
        if let cached = ImageCacheManager.shared.getImage(for: urlString) {
            loadedImage = cached
            isLoading = false
            return
        }
        Task {
            do {
                let image = try await ImageCacheManager.shared.downloadAndCacheImage(from: urlString)
                await MainActor.run {
                    loadedImage = image
                    isLoading = false
                }
            } catch {
                await MainActor.run { isLoading = false }
            }
        }
    }
}
