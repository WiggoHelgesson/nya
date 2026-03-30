import SwiftUI
import SafariServices

struct CartView: View {
    @ObservedObject private var cartManager = CartManager.shared
    @EnvironmentObject var authViewModel: AuthViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showCheckout = false
    @State private var showDiscountSection = true
    @State private var isRedeemingDiscount = false
    @State private var discountApplied: String?
    @State private var discountError: String?

    private var cartLines: [ShopifyCartLine] {
        cartManager.cart?.lines.edges.map(\.node) ?? []
    }

    private var currentXP: Int {
        authViewModel.currentUser?.currentXP ?? 0
    }

    private var isPro: Bool {
        RevenueCatManager.shared.isProMember
    }

    var body: some View {
        NavigationStack {
            Group {
                if cartManager.isEmpty {
                    emptyCartView
                } else {
                    cartContent
                }
            }
            .navigationTitle(L.t(sv: "Varukorg", nb: "Handlekurv"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .sheet(isPresented: $showCheckout) {
            if let url = cartManager.checkoutURL {
                SafariView(url: url)
                    .ignoresSafeArea()
                    .onDisappear {
                        cartManager.clearCart()
                        dismiss()
                    }
            }
        }
    }

    // MARK: - Empty

    private var emptyCartView: some View {
        VStack(spacing: 16) {
            Image(systemName: "bag")
                .font(.system(size: 50))
                .foregroundColor(.gray)

            Text(L.t(sv: "Din varukorg är tom", nb: "Handlekurven din er tom"))
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.primary)

            Text(L.t(sv: "Utforska Market för att hitta produkter", nb: "Utforsk Market for å finne produkter"))
                .font(.system(size: 14))
                .foregroundColor(.gray)

            Button {
                dismiss()
            } label: {
                Text(L.t(sv: "Fortsätt handla", nb: "Fortsett å handle"))
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 14)
                    .background(Color.black)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .padding(.top, 8)
        }
    }

    // MARK: - Cart Content

    private var cartContent: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(cartLines) { line in
                        CartLineRow(line: line)
                        Divider().padding(.horizontal, 16)
                    }

                    discountSection
                        .padding(.top, 16)
                }
            }

            checkoutBar
        }
    }

    // MARK: - Discount Section

    private var discountSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button {
                withAnimation { showDiscountSection.toggle() }
            } label: {
                HStack {
                    Image(systemName: "tag")
                        .font(.system(size: 14))
                    Text(L.t(sv: "Använd poäng för rabatt", nb: "Bruk poeng for rabatt"))
                        .font(.system(size: 14, weight: .medium))
                    Spacer()
                    Image(systemName: showDiscountSection ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12))
                }
                .foregroundColor(.primary)
                .padding(.horizontal, 16)
            }

            if showDiscountSection {
                VStack(spacing: 8) {
                    HStack {
                        Text(L.t(sv: "Dina poäng:", nb: "Dine poeng:"))
                            .font(.system(size: 13))
                            .foregroundColor(.gray)
                        Text("\(currentXP) XP")
                            .font(.system(size: 13, weight: .bold))
                    }
                    .padding(.horizontal, 16)

                    let tiers = PointsDiscountService.shared.availableTiers(currentXP: currentXP)

                    if tiers.isEmpty {
                        Text(L.t(sv: "Du behöver minst 200 XP för rabatt", nb: "Du trenger minst 200 XP for rabatt"))
                            .font(.system(size: 13))
                            .foregroundColor(.gray)
                            .padding(.horizontal, 16)
                    } else {
                        ForEach(tiers) { tier in
                            Button {
                                Task { await redeemTier(tier) }
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("\(tier.percent(isPro: isPro))% " + L.t(sv: "rabatt", nb: "rabatt"))
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundColor(.primary)
                                        Text("\(tier.xpCost) XP")
                                            .font(.system(size: 12))
                                            .foregroundColor(.gray)
                                    }
                                    Spacer()
                                    if isRedeemingDiscount {
                                        ProgressView()
                                    } else {
                                        Text(L.t(sv: "Använd", nb: "Bruk"))
                                            .font(.system(size: 13, weight: .semibold))
                                            .foregroundColor(.white)
                                            .padding(.horizontal, 16)
                                            .padding(.vertical, 8)
                                            .background(Color.black)
                                            .clipShape(Capsule())
                                    }
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .background(Color(.systemGray6))
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                            }
                            .disabled(isRedeemingDiscount)
                            .padding(.horizontal, 16)
                        }
                    }

                    if let applied = discountApplied {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text(L.t(sv: "Rabattkod \(applied) tillagd!", nb: "Rabattkode \(applied) lagt til!"))
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.green)
                        }
                        .padding(.horizontal, 16)
                    }

                    if let error = discountError {
                        Text(error)
                            .font(.system(size: 13))
                            .foregroundColor(.red)
                            .padding(.horizontal, 16)
                    }
                }
            }
        }
    }

    // MARK: - Checkout Bar

    private var checkoutBar: some View {
        VStack(spacing: 0) {
            Divider()

            VStack(spacing: 8) {
                if let cart = cartManager.cart {
                    HStack {
                        Text(L.t(sv: "Totalt", nb: "Totalt"))
                            .font(.system(size: 16, weight: .semibold))
                        Spacer()
                        Text(cart.totalAmount)
                            .font(.system(size: 18, weight: .bold))
                    }
                }

                Button {
                    showCheckout = true
                } label: {
                    Text(L.t(sv: "Till kassan", nb: "Til kassen"))
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.black)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(.ultraThinMaterial)
        }
    }

    // MARK: - Actions

    private func redeemTier(_ tier: DiscountTier) async {
        guard let userId = authViewModel.currentUser?.id else { return }
        isRedeemingDiscount = true
        discountError = nil

        do {
            let result = try await PointsDiscountService.shared.redeemDiscount(userId: userId, tier: tier, isPro: isPro)
            await cartManager.applyDiscount(code: result.code)
            discountApplied = result.code
        } catch {
            discountError = L.t(sv: "Kunde inte skapa rabattkod just nu. Försök igen senare.", nb: "Kunne ikke opprette rabattkode nå. Prøv igjen senere.")
            print("❌ Discount redeem error: \(error)")
        }

        isRedeemingDiscount = false
    }
}

// MARK: - Cart Line Row

struct CartLineRow: View {
    let line: ShopifyCartLine
    @ObservedObject private var cartManager = CartManager.shared

    var body: some View {
        HStack(spacing: 12) {
            if let imageURL = line.merchandise.image.flatMap({ URL(string: $0.url) }) {
                AsyncImage(url: imageURL) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFill()
                    default:
                        Color(.systemGray5)
                    }
                }
                .frame(width: 80, height: 80)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(line.merchandise.product.title)
                    .font(.system(size: 14, weight: .medium))
                    .lineLimit(2)

                if line.merchandise.title != "Default Title" {
                    Text(line.merchandise.title)
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                }

                Text(line.cost.totalAmount.amount.formattedAsSEK + " " + line.cost.totalAmount.currencyCode)
                    .font(.system(size: 14, weight: .semibold))
            }

            Spacer()

            VStack(spacing: 8) {
                Button {
                    Task { await cartManager.updateQuantity(lineId: line.id, quantity: line.quantity + 1) }
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 12, weight: .medium))
                        .frame(width: 28, height: 28)
                        .background(Color(.systemGray6))
                        .clipShape(Circle())
                }

                Text("\(line.quantity)")
                    .font(.system(size: 14, weight: .semibold))

                Button {
                    Task { await cartManager.updateQuantity(lineId: line.id, quantity: line.quantity - 1) }
                } label: {
                    Image(systemName: line.quantity <= 1 ? "trash" : "minus")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(line.quantity <= 1 ? .red : .primary)
                        .frame(width: 28, height: 28)
                        .background(Color(.systemGray6))
                        .clipShape(Circle())
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

// MARK: - Safari View

struct SafariView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        SFSafariViewController(url: url)
    }

    func updateUIViewController(_ vc: SFSafariViewController, context: Context) {}
}

// MARK: - String Extension

private extension String {
    var formattedAsSEK: String {
        let amount = Double(self) ?? 0
        return "\(Int(amount))"
    }
}
