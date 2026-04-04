import SwiftUI

struct ProductDetailView: View {
    let product: ShopifyProduct
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
    @State private var showDiscountTiers = false
    @State private var isRedeemingDiscount = false
    @State private var redeemingTierId: UUID?
    @Environment(\.dismiss) private var dismiss

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
                actionButtons
                    .padding(.top, 16)
                    .padding(.horizontal, 16)
                paymentIcons
                    .padding(.top, 16)
                shippingInfo
                    .padding(.top, 24)
                    .padding(.horizontal, 16)
                conditionCard
                    .padding(.top, 20)
                    .padding(.horizontal, 16)
                variantSelector
                    .padding(.top, 20)
                descriptionSection
                    .padding(.top, 24)
                Spacer(minLength: 40)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if selectedVariant == nil {
                selectedVariant = product.firstAvailableVariant ?? variants.first
            }
        }
        .fullScreenCover(isPresented: $showCheckoutSafari) {
            if let url = checkoutURL {
                SafariView(url: url)
                    .ignoresSafeArea()
            }
        }
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
                if images.isEmpty {
                    placeholder.tag(0)
                } else {
                    ForEach(images.indices, id: \.self) { index in
                        AsyncImage(url: images[index]) { phase in
                            switch phase {
                            case .success(let image):
                                image
                                    .resizable()
                                    .scaledToFit()
                            case .failure:
                                placeholder
                            default:
                                ProgressView()
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                            }
                        }
                        .tag(index)
                    }
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(height: 400)
            .background(Color(.systemGray6))

            if images.count > 1 {
                HStack(spacing: 6) {
                    ForEach(images.indices, id: \.self) { index in
                        Circle()
                            .fill(selectedImageIndex == index ? Color.primary : Color.gray.opacity(0.4))
                            .frame(width: 7, height: 7)
                    }
                }
                .padding(.bottom, 12)
            }
        }
    }

    private var placeholder: some View {
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
            HStack(alignment: .top) {
                Text(product.title)
                    .font(.system(size: 22, weight: .bold))
                    .lineLimit(3)

                Spacer()

                ShareLink(item: "https://\(ShopifyService.shared.shopDomain)/products/\(product.handle)") {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 18))
                        .foregroundColor(.primary)
                        .padding(8)
                }
            }

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

    // MARK: - Action Buttons

    private var actionButtons: some View {
        VStack(spacing: 10) {
            // 1. Buy Now
            Button {
                guard let variant = selectedVariant ?? product.firstAvailableVariant else { return }
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                Task { await buyNow(variantId: variant.id) }
            } label: {
                HStack(spacing: 8) {
                    if isCheckingOut {
                        ProgressView().tint(.white)
                    } else {
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 14))
                        Text(L.t(sv: "Köp nu", nb: "Kjøp nå"))
                            .font(.system(size: 16, weight: .bold))
                    }
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color.black)
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .disabled(isCheckingOut || selectedVariant?.availableForSale == false)

            // 2. Points discount dropdown
            pointsDiscountDropdown

            // 3. Add to cart
            Button {
                guard let variant = selectedVariant ?? product.firstAvailableVariant else { return }
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                Task {
                    await cartManager.addToCart(variantId: variant.id)
                    withAnimation(.spring(response: 0.3)) { addedToCart = true }
                    try? await Task.sleep(nanoseconds: 2_000_000_000)
                    withAnimation { addedToCart = false }
                }
            } label: {
                HStack(spacing: 8) {
                    if cartManager.isLoading {
                        ProgressView().tint(.primary)
                    } else if addedToCart {
                        Image(systemName: "checkmark")
                            .font(.system(size: 14, weight: .bold))
                        Text(L.t(sv: "Tillagd!", nb: "Lagt til!"))
                            .font(.system(size: 16, weight: .semibold))
                    } else {
                        Image(systemName: "cart")
                            .font(.system(size: 15))
                        Text(L.t(sv: "Lägg i varukorg", nb: "Legg i handlekurv"))
                            .font(.system(size: 16, weight: .semibold))
                    }
                }
                .foregroundColor(addedToCart ? .white : .primary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    Group {
                        if addedToCart {
                            RoundedRectangle(cornerRadius: 14).fill(Color.green)
                        } else {
                            RoundedRectangle(cornerRadius: 14).stroke(Color(.systemGray3), lineWidth: 1)
                        }
                    }
                )
            }
            .disabled(cartManager.isLoading || selectedVariant?.availableForSale == false)

            // 4. Favorite
            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                withAnimation(.spring(response: 0.3)) { isFavorite.toggle() }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: isFavorite ? "heart.fill" : "heart")
                        .font(.system(size: 15))
                        .foregroundColor(isFavorite ? .red : .primary)
                    Text(L.t(sv: "Spara som favorit", nb: "Lagre som favoritt"))
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.primary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color(.systemGray3), lineWidth: 1)
                )
            }
        }
    }

    // MARK: - Points Discount Dropdown

    private var pointsDiscountDropdown: some View {
        VStack(spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.25)) { showDiscountTiers.toggle() }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 13))
                        .foregroundColor(.orange)

                    Text(L.t(
                        sv: "Har du poäng? Se rabatterat pris",
                        nb: "Har du poeng? Se rabattert pris"
                    ))
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.secondary)

                    Spacer()

                    Text("\(currentXP) XP")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.orange)

                    Image(systemName: showDiscountTiers ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
            }
            .buttonStyle(.plain)

            if showDiscountTiers {
                VStack(spacing: 0) {
                    Divider().padding(.horizontal, 14)

                    ForEach(PointsDiscountService.tiers) { tier in
                        let percent = tier.percent(isPro: isPro)
                        let discounted = productPrice * (1.0 - Double(percent) / 100.0)
                        let canAfford = currentXP >= tier.xpCost
                        let isRedeeming = redeemingTierId == tier.id

                        VStack(spacing: 0) {
                            HStack {
                                VStack(alignment: .leading, spacing: 3) {
                                    HStack(spacing: 6) {
                                        Text("\(tier.xpCost) XP")
                                            .font(.system(size: 14, weight: .bold))
                                            .foregroundColor(canAfford ? .primary : .gray)

                                        Text("\(percent)%")
                                            .font(.system(size: 12, weight: .bold))
                                            .foregroundColor(.white)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(canAfford ? Color.orange : Color.gray.opacity(0.4))
                                            .clipShape(RoundedRectangle(cornerRadius: 4))
                                    }

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
                                    Task { await buyWithDiscount(variantId: variant.id, tier: tier) }
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
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
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
    }

    // MARK: - Checkout Helpers

    private func buyNow(variantId: String) async {
        isCheckingOut = true
        defer { isCheckingOut = false }

        do {
            let cart = try await ShopifyService.shared.cartCreate(variantId: variantId, quantity: 1)
            guard let url = URL(string: cart.checkoutUrl) else { return }
            checkoutURL = url
            showCheckoutSafari = true
        } catch {
            print("Buy now error: \(error.localizedDescription)")
        }
    }

    private func buyWithDiscount(variantId: String, tier: DiscountTier) async {
        isRedeemingDiscount = true
        redeemingTierId = tier.id
        defer {
            isRedeemingDiscount = false
            redeemingTierId = nil
        }

        do {
            guard let userId = authViewModel.currentUser?.id else { return }
            let discount = try await PointsDiscountService.shared.redeemDiscount(
                userId: userId, tier: tier, isPro: isPro
            )
            let cart = try await ShopifyService.shared.cartCreate(variantId: variantId, quantity: 1)
            let updatedCart = try await ShopifyService.shared.cartDiscountCodesUpdate(
                cartId: cart.id, discountCodes: [discount.code]
            )
            guard let url = URL(string: updatedCart.checkoutUrl) else { return }
            checkoutURL = url
            showCheckoutSafari = true
        } catch {
            print("Discount checkout error: \(error.localizedDescription)")
        }
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
                icon: "shippingbox.fill",
                title: L.t(sv: "Snabbast leverans", nb: "Raskeste levering"),
                subtitle: L.t(sv: "Express 1–2 arbetsdagar", nb: "Express 1–2 arbeidsdager")
            )

            Divider().padding(.leading, 52)

            shippingRow(
                icon: "truck.box",
                title: L.t(sv: "Billigast leverans", nb: "Billigste levering"),
                subtitle: L.t(sv: "Standard 3–5 arbetsdagar", nb: "Standard 3–5 arbeidsdager")
            )

            Divider().padding(.leading, 52)

            shippingRow(
                icon: "arrow.counterclockwise",
                title: L.t(sv: "30 dagars returrätt", nb: "30 dagers returrett"),
                subtitle: L.t(sv: "Enkel retur utan krångel", nb: "Enkel retur uten problemer")
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

    @ViewBuilder
    private var variantSelector: some View {
        let availableVariants = variants.filter(\.availableForSale)
        if availableVariants.count > 1 {
            VStack(alignment: .leading, spacing: 8) {
                Text(L.t(sv: "Välj variant", nb: "Velg variant"))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.gray)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(availableVariants) { variant in
                            Button {
                                selectedVariant = variant
                            } label: {
                                Text(variant.title)
                                    .font(.system(size: 14, weight: selectedVariant?.id == variant.id ? .semibold : .regular))
                                    .foregroundColor(selectedVariant?.id == variant.id ? .white : .primary)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 10)
                                    .background(selectedVariant?.id == variant.id ? Color.black : Color(.systemGray6))
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
        }
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
}
