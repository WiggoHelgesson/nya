import SwiftUI
import SafariServices

/// Seller-side "Saldo & utbetalningar"-vy. Visar Stripe-saldot (tillgängligt +
/// på väg in) när Connect är klart, annars hero + knapp för att påbörja onboarding.
struct SellerBalanceView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var sellerStripe = SellerStripeService.shared

    @State private var availableOre: Int = 0
    @State private var pendingOre: Int = 0
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var isOpeningDashboard = false
    @State private var isStartingOnboarding = false
    @State private var pendingTransferOre: Int = 0

    private let accent = Color.black

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().opacity(0.15)

            ScrollView {
                VStack(spacing: 20) {
                    if isLoading {
                        ProgressView()
                            .padding(.top, 60)
                    } else {
                        if !sellerStripe.status.isFullyActive && pendingTransferOre > 0 {
                            pendingConnectBanner
                        } else if !sellerStripe.status.hasAccount {
                            setupHero
                        }
                        if sellerStripe.status.hasAccount {
                            balanceCards
                        }
                        infoBox
                        if sellerStripe.status.isFullyActive {
                            dashboardButton
                        } else {
                            setupButton
                        }
                        if let errorMessage = errorMessage {
                            Text(errorMessage)
                                .font(.system(size: 13))
                                .foregroundColor(.red)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 20)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 40)
            }
            .refreshable { await load() }
        }
        .background(Color(.systemGroupedBackground))
        .navigationBarHidden(true)
        .task { await load() }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                Task {
                    if let uid = authViewModel.currentUser?.id {
                        await sellerStripe.syncStatusAndFlushPayouts(userId: uid)
                    }
                    await load()
                }
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 12) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.primary)
                    .frame(width: 32, height: 32)
            }

            Spacer(minLength: 0)

            Text(L.t(sv: "Saldo & utbetalningar", nb: "Saldo og utbetalinger"))
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.primary)

            Spacer(minLength: 0)

            Color.clear.frame(width: 32, height: 32)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color(.systemBackground))
    }

    // MARK: - Content

    private var setupHero: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L.t(sv: "Koppla Stripe", nb: "Koble Stripe"))
                .font(.system(size: 15, weight: .bold))

            Text(L.t(
                sv: "Du behöver koppla Stripe för att se ditt saldo och få utbetalningar.",
                nb: "Du må koble Stripe for å se saldoen din og få utbetalinger."
            ))
            .font(.system(size: 13))
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color(.systemBackground))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private var pendingConnectBanner: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(L.t(sv: "Pengar väntar på dig", nb: "Penger venter på deg"))
                .font(.system(size: 15, weight: .bold))

            Text(formatSEK(pendingTransferOre))
                .font(.system(size: 34, weight: .bold))

            Text(L.t(
                sv: "Summan gäller köp där köparen redan godkänt — pengarna ska överföras till dig men väntar på att du slutför Stripe. Andra försäljningar som fortfarande ligger i köparskydd visas inte här.",
                nb: "Summen gjelder kjøp der kjøperen allerede har godkjent — pengene skal overføres til deg men venter på at du fullfører Stripe. Andre salg som fortsatt er i kjøperbeskyttelse vises ikke her."
            ))
            .font(.system(size: 13))
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color.orange.opacity(0.12))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.orange.opacity(0.35), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private var balanceCards: some View {
        VStack(spacing: 12) {
            balanceCard(
                title: L.t(sv: "Tillgängligt saldo", nb: "Tilgjengelig saldo"),
                subtitle: L.t(
                    sv: "Kan betalas ut till ditt bankkonto",
                    nb: "Kan utbetales til bankkontoen din"
                ),
                amountOre: availableOre,
                emphasized: true
            )

            balanceCard(
                title: L.t(sv: "På väg in", nb: "På vei inn"),
                subtitle: L.t(
                    sv: "Betalningar som ännu inte har frisläppts",
                    nb: "Betalinger som ennå ikke er frigitt"
                ),
                amountOre: pendingOre,
                emphasized: false
            )
        }
    }

    private func balanceCard(title: String, subtitle: String, amountOre: Int, emphasized: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.secondary)

            Text(formatSEK(amountOre))
                .font(.system(size: emphasized ? 34 : 26, weight: .bold))
                .foregroundColor(.primary)

            Text(subtitle)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color(.systemBackground))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private var infoBox: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "info.circle")
                .foregroundColor(.secondary)
                .font(.system(size: 14, weight: .semibold))
                .padding(.top, 1)

            Text(L.t(
                sv: "Utbetalningar sker automatiskt från Stripe till ditt bankkonto. Det kan ta 1–2 bankdagar.",
                nb: "Utbetalinger skjer automatisk fra Stripe til bankkontoen din. Det kan ta 1–2 bankdager."
            ))
            .font(.system(size: 13))
            .foregroundColor(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color(.systemBackground))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.primary.opacity(0.06), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var setupButton: some View {
        Button {
            Task { await startOnboarding() }
        } label: {
            HStack(spacing: 8) {
                if isStartingOnboarding {
                    ProgressView()
                        .tint(.white)
                } else {
                    Image(systemName: "creditcard.fill")
                }
                Text(L.t(
                    sv: "Sätt upp Stripe för utbetalningar",
                    nb: "Sett opp Stripe for utbetalinger"
                ))
                .font(.system(size: 15, weight: .semibold))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(accent)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .disabled(isStartingOnboarding)
    }

    private var dashboardButton: some View {
        Button {
            Task { await openStripeDashboard() }
        } label: {
            HStack(spacing: 8) {
                if isOpeningDashboard {
                    ProgressView()
                        .tint(.white)
                } else {
                    Image(systemName: "arrow.up.right.square")
                }
                Text(L.t(sv: "Öppna Stripe-dashboard", nb: "Åpne Stripe-dashbord"))
                    .font(.system(size: 15, weight: .semibold))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(accent)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .disabled(isOpeningDashboard)
    }

    // MARK: - Data

    private func load() async {
        guard let userId = authViewModel.currentUser?.id else { return }
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }

        await sellerStripe.refresh(userId: userId)

        var pendingOreFromOrders = 0
        if !sellerStripe.status.isFullyActive {
            if let sales = try? await MarketplaceOrdersService.shared.fetchMySales() {
                pendingOreFromOrders = MarketplaceOrderRow.totalPendingSellerPayoutOre(orders: sales)
            }
        }

        guard let accountId = sellerStripe.status.stripeAccountId else {
            await MainActor.run {
                availableOre = 0
                pendingOre = 0
                pendingTransferOre = pendingOreFromOrders
                isLoading = false
                errorMessage = nil
            }
            return
        }

        do {
            let status = try await StripeConnectService.shared.getSellerAccountStatus(
                stripeAccountId: accountId,
                sellerId: userId
            )

            let availableSek = (status.balance?.available ?? [])
                .filter { $0.currency.lowercased() == "sek" }
                .reduce(0) { $0 + $1.amount }

            let pendingSek = (status.balance?.pending ?? [])
                .filter { $0.currency.lowercased() == "sek" }
                .reduce(0) { $0 + $1.amount }

            await MainActor.run {
                self.availableOre = availableSek
                self.pendingOre = pendingSek
                self.pendingTransferOre = pendingOreFromOrders
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.pendingTransferOre = pendingOreFromOrders
                self.isLoading = false
                self.errorMessage = error.localizedDescription
            }
            print("SellerBalanceView.load failed: \(error)")
        }
    }

    private func startOnboarding() async {
        guard let user = authViewModel.currentUser else { return }
        let email = user.email
        guard !email.isEmpty else {
            await MainActor.run {
                errorMessage = L.t(sv: "Saknar e-post.", nb: "Mangler e-post.")
            }
            return
        }
        await MainActor.run {
            errorMessage = nil
            isStartingOnboarding = true
        }
        defer {
            Task { @MainActor in isStartingOnboarding = false }
        }
        do {
            try await SellerStripeService.shared.startOnboarding(userId: user.id, email: email)
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func openStripeDashboard() async {
        guard let accountId = sellerStripe.status.stripeAccountId else { return }
        await MainActor.run { isOpeningDashboard = true }
        defer {
            Task { @MainActor in isOpeningDashboard = false }
        }
        do {
            let link = try await StripeConnectService.shared.getOnboardingLink(
                stripeAccountId: accountId
            )
            if let urlString = link.url, let url = URL(string: urlString) {
                await MainActor.run {
                    let safari = SFSafariViewController(url: url)
                    UIApplication.shared.topMostViewController()?.present(safari, animated: true)
                }
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
            }
            print("SellerBalanceView.openStripeDashboard failed: \(error)")
        }
    }

    // MARK: - Formatting

    private func formatSEK(_ ore: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "SEK"
        formatter.locale = Locale(identifier: "sv_SE")
        formatter.maximumFractionDigits = 2
        let value = Double(ore) / 100.0
        return formatter.string(from: NSNumber(value: value)) ?? "\(value) kr"
    }
}
