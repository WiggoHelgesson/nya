import SwiftUI

struct ProductDetailView: View {
    let product: ShopifyProduct
    @Binding var showCart: Bool
    @ObservedObject private var cartManager = CartManager.shared
    @State private var selectedVariant: ShopifyVariant?
    @State private var selectedImageIndex = 0
    @State private var addedToCart = false
    @State private var isFavorite = false
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
                discountBanner
                    .padding(.top, 16)
                    .padding(.horizontal, 16)
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

    // MARK: - Discount Banner

    private var discountBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "tag")
                .font(.system(size: 16))
                .foregroundColor(.primary)

            (Text(L.t(sv: "10% rabatt på din första order — Använd koden ", nb: "10% rabatt på din første ordre — Bruk koden "))
                .font(.system(size: 14))
             + Text("UPDOWN10")
                .font(.system(size: 14, weight: .bold)))
                .foregroundColor(.primary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        VStack(spacing: 10) {
            Button {
                guard let variant = selectedVariant ?? product.firstAvailableVariant else { return }
                let generator = UIImpactFeedbackGenerator(style: .medium)
                generator.impactOccurred()
                Task {
                    await cartManager.addToCart(variantId: variant.id)
                    withAnimation(.spring(response: 0.3)) { addedToCart = true }
                    try? await Task.sleep(nanoseconds: 2_000_000_000)
                    withAnimation { addedToCart = false }
                }
            } label: {
                HStack(spacing: 8) {
                    if cartManager.isLoading {
                        ProgressView()
                            .tint(.white)
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
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(addedToCart ? Color.green : Color.black)
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .disabled(cartManager.isLoading || selectedVariant?.availableForSale == false)

            Button {
                let generator = UIImpactFeedbackGenerator(style: .light)
                generator.impactOccurred()
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
