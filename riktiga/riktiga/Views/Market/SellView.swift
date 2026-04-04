import SwiftUI

struct SellView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @Environment(\.colorScheme) private var colorScheme
    @State private var showBagTerms = false
    @State private var showSendBag = false
    @State private var showMySales = false
    @State private var showHowItWorks = false

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                welcomeSection
                    .padding(.top, 16)

                promoBanner
                    .padding(.top, 24)
                    .padding(.horizontal, 16)

                sectionHeader(L.t(sv: "Sälj dina plagg", nb: "Selg plaggene dine"))
                    .padding(.top, 24)
                    .padding(.horizontal, 16)

                menuItems
                    .padding(.top, 12)
                    .padding(.horizontal, 16)

                sectionHeader(L.t(sv: "Betalningar & intäkter", nb: "Betalinger & inntekter"))
                    .padding(.top, 28)
                    .padding(.horizontal, 16)

                quickActions
                    .padding(.top, 12)
                    .padding(.horizontal, 16)

                Spacer(minLength: 60)
            }
        }
        .background(Color(.systemBackground))
        .sheet(isPresented: $showBagTerms) {
            BagTermsSheet()
        }
        .sheet(isPresented: $showSendBag) {
            SendBagView()
        }
        .sheet(isPresented: $showMySales) {
            MySalesView()
                .environmentObject(authViewModel)
        }
        .sheet(isPresented: $showHowItWorks) {
            HowItWorksSheet()
        }
    }

    // MARK: - Welcome

    private var welcomeSection: some View {
        HStack(spacing: 16) {
            Image("23")
                .resizable()
                .scaledToFit()
                .frame(width: 64, height: 64)
                .clipShape(RoundedRectangle(cornerRadius: 14))

            VStack(alignment: .leading, spacing: 4) {
                Text(L.t(sv: "Välkommen", nb: "Velkommen"))
                    .font(.system(size: 22, weight: .bold))

                Text(L.t(
                    sv: "Hitta allt som rör dina försäljningar här",
                    nb: "Finn alt som gjelder dine salg her"
                ))
                .font(.system(size: 14))
                .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding(.horizontal, 16)
    }

    // MARK: - Section Header

    private func sectionHeader(_ title: String) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.primary)
            Spacer()
        }
    }

    // MARK: - Quick Actions

    private var quickActions: some View {
        VStack(spacing: 10) {
            quickActionRow(
                icon: "creditcard",
                title: L.t(sv: "Tillgängligt saldo", nb: "Tilgjengelig saldo"),
                trailing: {
                    AnyView(
                        Text("\(authViewModel.currentUser?.currentXP ?? 0) XP")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.secondary)
                    )
                }
            )

            quickActionRow(
                icon: "arrow.up.right.square",
                title: L.t(sv: "Mina intäkter", nb: "Mine inntekter"),
                trailing: {
                    AnyView(
                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    )
                }
            )
        }
    }

    private func quickActionRow(icon: String, title: String, trailing: () -> AnyView) -> some View {
        HStack {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(.primary)
                .frame(width: 24)

            Text(title)
                .font(.system(size: 15, weight: .medium))

            Spacer()

            trailing()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(colorScheme == .dark ? Color(red: 0.12, green: 0.12, blue: 0.12) : Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Promo Banner

    private var promoBanner: some View {
        Button {
            showBagTerms = true
        } label: {
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.black)

                HStack {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(L.t(
                            sv: "Köp din påse och få 10-15 plagg sålt direkt",
                            nb: "Kjøp posen din og få 10-15 plagg solgt direkte"
                        ))
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)

                        Text(L.t(
                            sv: "Sälj second hand utan krångel",
                            nb: "Selg second hand uten problemer"
                        ))
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.7))

                        HStack(spacing: 6) {
                            Text(L.t(sv: "Beställ påse", nb: "Bestill pose"))
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.black)

                            Image(systemName: "chevron.right")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.black)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }

                    Spacer()

                    Image(systemName: "shippingbox.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.white)
                }
                .padding(20)
            }
            .frame(height: 160)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Menu Items

    private var menuItems: some View {
        VStack(spacing: 0) {
            menuRow(
                icon: "shippingbox",
                title: L.t(sv: "Beställ påsar", nb: "Bestill poser"),
                action: { showBagTerms = true }
            )

            Divider().padding(.leading, 56)

            menuRow(
                icon: "truck.box",
                title: L.t(sv: "Skicka in påsar", nb: "Send inn poser"),
                action: { showSendBag = true }
            )

            Divider().padding(.leading, 56)

            menuRow(
                icon: "tag",
                title: L.t(sv: "Mina försäljningar", nb: "Mine salg"),
                action: { showMySales = true }
            )

            Divider().padding(.leading, 56)

            menuRow(
                icon: "info.circle",
                title: L.t(sv: "Så funkar det", nb: "Slik fungerer det"),
                action: { showHowItWorks = true }
            )
        }
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(colorScheme == .dark ? Color(red: 0.12, green: 0.12, blue: 0.12) : Color(.systemGray6))
        )
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func menuRow(icon: String, title: String, action: (() -> Void)? = nil) -> some View {
        Button {
            action?()
        } label: {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundColor(.primary)
                    .frame(width: 28)

                Text(title)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.primary)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Bag Terms Sheet

struct BagTermsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var showQuantity = false
    @State private var bagQuantity = 1
    @State private var isLoadingCheckout = false
    @State private var checkoutURL: URL?
    @State private var showSafari = false

    private let bagHandle = "up-down-pasen"

    private let terms: [(icon: String, title: String, subtitle: String)] = [
        ("shippingbox", "Köp din påse", "Beställ enkelt direkt i appen"),
        ("tshirt", "Fyll med 1–15 plagg", "Sportkläder du inte längre använder"),
        ("doc.text", "Skicka in med fraktsedeln i paketet", "Lämna hos närmaste PostNord-ombud"),
        ("hands.clap", "Luta dig tillbaka och få betalt", "Vi säljer dina kläder och du får din andel")
    ]

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button {
                    if showQuantity {
                        withAnimation(.easeInOut(duration: 0.2)) { showQuantity = false }
                    } else {
                        dismiss()
                    }
                } label: {
                    Image(systemName: showQuantity ? "chevron.left" : "xmark")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.primary)
                }

                Spacer()

                Text(L.t(
                    sv: "Up&Down-påsen",
                    nb: "Up&Down-posen"
                ))
                .font(.system(size: 15, weight: .semibold))
                .lineLimit(1)

                Spacer()

                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.clear)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)

            if showQuantity {
                quantityContent
            } else {
                termsContent
            }
        }
        .presentationDetents([.large])
        .fullScreenCover(isPresented: $showSafari) {
            if let url = checkoutURL {
                SafariView(url: url)
                    .ignoresSafeArea()
            }
        }
    }

    // MARK: - Terms

    private var termsContent: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 36) {
                    ForEach(terms, id: \.title) { term in
                        termRow(icon: term.icon, title: term.title, subtitle: term.subtitle)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 28)
            }

            Button {
                withAnimation(.easeInOut(duration: 0.2)) { showQuantity = true }
            } label: {
                Text(L.t(sv: "Beställ påse", nb: "Bestill pose"))
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.primary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(Color(.systemBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.primary.opacity(0.4), lineWidth: 1.5)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
    }

    // MARK: - Quantity

    private var quantityContent: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 24) {
                Image("23")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 64, height: 64)
                    .clipShape(RoundedRectangle(cornerRadius: 14))

                Text(L.t(
                    sv: "Hur många påsar vill du beställa?",
                    nb: "Hvor mange poser vil du bestille?"
                ))
                .font(.system(size: 18, weight: .bold))
                .multilineTextAlignment(.center)

                Text(L.t(
                    sv: "Välj antal påsar",
                    nb: "Velg antall poser"
                ))
                .font(.system(size: 14))
                .foregroundColor(.secondary)

                HStack(spacing: 24) {
                    Button {
                        if bagQuantity > 1 { bagQuantity -= 1 }
                    } label: {
                        Image(systemName: "minus.circle.fill")
                            .font(.system(size: 32))
                            .foregroundColor(bagQuantity > 1 ? .primary : .gray.opacity(0.3))
                    }
                    .disabled(bagQuantity <= 1)

                    Text("\(bagQuantity)")
                        .font(.system(size: 36, weight: .bold))
                        .frame(width: 50)

                    Button {
                        bagQuantity += 1
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 32))
                            .foregroundColor(.primary)
                    }
                }

                Text(L.t(
                    sv: "Räcker till max \(bagQuantity * 15) plagg",
                    nb: "Plass til maks \(bagQuantity * 15) plagg"
                ))
                .font(.system(size: 14))
                .foregroundColor(.secondary)

                Text(priceText)
                    .font(.system(size: 28, weight: .bold))
            }

            Spacer()

            Button {
                Task { await startCheckout() }
            } label: {
                HStack {
                    if isLoadingCheckout {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Text(L.t(sv: "Beställ", nb: "Bestill"))
                            .font(.system(size: 16, weight: .bold))
                    }
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(Color.black)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .disabled(isLoadingCheckout)
            .padding(.horizontal, 20)
            .padding(.bottom, 16)
        }
    }

    // MARK: - Helpers

    private func termRow(icon: String, title: String, subtitle: String) -> some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(.white)
                .frame(width: 54, height: 54)
                .background(Color.black)
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 17, weight: .bold))
                Text(subtitle)
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }
        }
    }

    private var priceText: String {
        let total = bagQuantity * 19
        return "\(total) kr"
    }

    private func startCheckout() async {
        isLoadingCheckout = true
        defer { isLoadingCheckout = false }

        do {
            guard let product = try await ShopifyService.shared.fetchProductByHandle(bagHandle) else {
                print("Bag product not found")
                return
            }

            guard let variant = product.variants.edges.first?.node, variant.availableForSale else {
                print("No available variant for bag")
                return
            }

            let cart = try await ShopifyService.shared.cartCreate(variantId: variant.id, quantity: bagQuantity)

            guard let url = URL(string: cart.checkoutUrl) else {
                print("No checkout URL")
                return
            }

            checkoutURL = url
            showSafari = true
        } catch {
            print("Bag checkout error: \(error.localizedDescription)")
        }
    }
}

// MARK: - Send Bag View

struct SendBagView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @State private var showBagTerms = false

    private let currentMonth: String = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "sv_SE")
        formatter.dateFormat = "MMMM"
        return formatter.string(from: Date()).capitalized
    }()

    private var currentSeason: String {
        let month = Calendar.current.component(.month, from: Date())
        switch month {
        case 3...5: return L.t(sv: "Vårsäsong", nb: "Vårsesong")
        case 6...8: return L.t(sv: "Sommarsäsong", nb: "Sommersesong")
        case 9...11: return L.t(sv: "Höstsäsong", nb: "Høstsesong")
        default: return L.t(sv: "Vintersäsong", nb: "Vintersesong")
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.primary)
                }

                Spacer()

                Text(L.t(
                    sv: "Skicka in Up&Down-påse",
                    nb: "Send inn Up&Down-pose"
                ))
                .font(.system(size: 16, weight: .semibold))

                Spacer()

                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.clear)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    postnordCard
                        .padding(.horizontal, 16)
                        .padding(.top, 8)

                    stepsSection
                        .padding(.horizontal, 16)
                        .padding(.top, 24)

                    termsSection
                        .padding(.horizontal, 16)
                        .padding(.top, 24)

                    seasonTipSection
                        .padding(.top, 24)

                    Spacer(minLength: 100)
                }
            }

            Button {
                showBagTerms = true
            } label: {
                Text(L.t(sv: "Köp påse", nb: "Kjøp pose"))
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(Color.black)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 16)
        }
        .presentationDetents([.large])
        .sheet(isPresented: $showBagTerms) {
            BagTermsSheet()
        }
    }

    // MARK: - PostNord Card

    private var postnordCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("postnord")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Color(red: 0.0, green: 0.2, blue: 0.5))
                .clipShape(RoundedRectangle(cornerRadius: 4))

            Text(L.t(
                sv: "Skicka in med Postnord",
                nb: "Send inn med Postnord"
            ))
            .font(.system(size: 18, weight: .bold))

            Text(L.t(
                sv: "Lämna din påse hos närmaste Postnord-ombud med den medföljande fraktsedeln.",
                nb: "Lever posen hos nærmeste Postnord-ombud med den medfølgende fraktseddelen."
            ))
            .font(.system(size: 14))
            .foregroundColor(.secondary)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(red: 0.9, green: 0.96, blue: 0.97))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Steps

    private var stepsSection: some View {
        VStack(spacing: 24) {
            stepRow(
                number: "1",
                icon: "shippingbox",
                title: L.t(sv: "Fyll din Up&Down-påse", nb: "Fyll Up&Down-posen din"),
                subtitle: L.t(sv: "Med sportkläder du vill sälja", nb: "Med sportsklær du vil selge")
            )
            stepRow(
                number: "2",
                icon: "doc.text",
                title: L.t(sv: "Använd den medföljande fraktsedeln", nb: "Bruk den medfølgende fraktseddelen"),
                subtitle: L.t(sv: "Den följde med i din Up&Down-påse", nb: "Den fulgte med i Up&Down-posen din")
            )
            stepRow(
                number: "3",
                icon: "building.2",
                title: L.t(sv: "Lämna in hos närmaste PostNord-ombud", nb: "Lever inn hos nærmeste PostNord-ombud"),
                subtitle: L.t(sv: "Vi skickar ett mejl när påsen kommit fram", nb: "Vi sender en e-post når posen har kommet fram")
            )
        }
    }

    private func stepRow(number: String, icon: String, title: String, subtitle: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Text(number)
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 32, height: 32)
                .background(Color.black)
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 15, weight: .bold))
                Text(subtitle)
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
    }

    // MARK: - Terms

    private var termsSection: some View {
        VStack(spacing: 16) {
            termsRow(icon: "percent", title: L.t(sv: "40% på sålda varor", nb: "40% på solgte varer"), subtitle: L.t(sv: "Ta ut din andel, handla eller skänk", nb: "Ta ut din andel, handle eller doner"))
            termsRow(icon: "diamond", title: L.t(sv: "70% på dyrare varor", nb: "70% på dyrere varer"), subtitle: L.t(sv: "För delen som överstiger 500 SEK", nb: "For delen som overstiger 500 SEK"))
        }
    }

    private func termsRow(icon: String, title: String, subtitle: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(.primary)
                .frame(width: 32, height: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 15, weight: .bold))
                Text(subtitle)
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
    }

    // MARK: - Season Tip

    private var seasonTipSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Divider()

            VStack(alignment: .leading, spacing: 6) {
                Text(L.t(sv: "Försäljningsstart", nb: "Salgsstart"))
                    .font(.system(size: 16, weight: .bold))

                Text(L.t(
                    sv: "3 veckor (\(currentMonth.lowercased()))",
                    nb: "3 uker (\(currentMonth.lowercased()))"
                ))
                .font(.system(size: 14))
                .foregroundColor(.secondary)

                HStack {
                    Text(L.t(sv: "Tips! Packa för relevant säsong:", nb: "Tips! Pakk for relevant sesong:"))
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)

                    HStack(spacing: 6) {
                        Image(systemName: "sparkle")
                            .font(.system(size: 12))
                        Text(currentSeason)
                            .font(.system(size: 13, weight: .medium))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color(.separator), lineWidth: 1)
                    )
                }
                .padding(.top, 4)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)

            Divider()
        }
    }
}

// MARK: - How It Works Sheet

struct HowItWorksSheet: View {
    @Environment(\.dismiss) private var dismiss

    private let steps: [(icon: String, title: String, subtitle: String)] = [
        ("shippingbox", "Köp din påse", "Beställ enkelt direkt i appen"),
        ("tshirt", "Fyll med 1–15 plagg", "Sportkläder du inte längre använder"),
        ("doc.text", "Skicka in med fraktsedeln i paketet", "Lämna hos närmaste PostNord-ombud"),
        ("hands.clap", "Luta dig tillbaka och få betalt", "Vi säljer dina kläder och du får din andel")
    ]

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.primary)
                }

                Spacer()

                Text(L.t(sv: "Så funkar det", nb: "Slik fungerer det"))
                    .font(.system(size: 16, weight: .semibold))

                Spacer()

                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.clear)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)

            ScrollView {
                VStack(alignment: .leading, spacing: 36) {
                    ForEach(steps, id: \.icon) { step in
                        HStack(alignment: .top, spacing: 16) {
                            Image(systemName: step.icon)
                                .font(.system(size: 20))
                                .foregroundColor(.white)
                                .frame(width: 54, height: 54)
                                .background(Color.black)
                                .clipShape(Circle())

                            VStack(alignment: .leading, spacing: 4) {
                                Text(step.title)
                                    .font(.system(size: 17, weight: .bold))
                                Text(step.subtitle)
                                    .font(.system(size: 14))
                                    .foregroundColor(.secondary)
                            }

                            Spacer()
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 28)
            }
        }
        .presentationDetents([.large])
    }
}
