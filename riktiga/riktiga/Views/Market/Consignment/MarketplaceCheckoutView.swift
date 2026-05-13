import SwiftUI
import StripePaymentSheet
import Supabase
import Auth

/// Buyer-side checkout for community listings — Vinted-style single-page flow.
/// Sections: listing, address, carrier picker (Shipmondo rates), payment, price
/// breakdown. Total + Apple Pay button pinned to the bottom.
struct MarketplaceCheckoutView: View {
    let row: ConsignmentSubmissionRow

    @EnvironmentObject var authViewModel: AuthViewModel
    @Environment(\.dismiss) private var dismiss

    // MARK: - State

    @State private var shippingAddress: BuyerShippingAddress?

    // Shipmondo-quoted rates (replaces the hardcoded pickup/home toggle).
    @State private var rates: [ShipmondoShippingService.Rate] = []
    @State private var selectedRateId: String?
    @State private var ratesLoading: Bool = false
    @State private var ratesError: String?

    // Ombud / service-point picker (only shown when the chosen rate has
    // `requiresServicePoint == true`).
    @State private var servicePoints: [ShipmondoShippingService.ServicePoint] = []
    @State private var selectedServicePointToken: String?
    @State private var servicePointsLoading: Bool = false
    @State private var servicePointsError: String?

    @State private var buyerEmail: String = ""

    @State private var flowController: PaymentSheet.FlowController?
    @State private var paymentOption: PaymentSheet.FlowController.PaymentOptionDisplayData?
    @State private var isPreparing = false
    @State private var isConfirming = false
    @State private var prepareError: String?
    @State private var didComplete = false
    /// Undviker dubbel releaseHideTabBar när Stäng dismissar samtidigt som tab-byte (SwiftUI race).
    @State private var tabBarHideAcquired = false
    @State private var triggerNotificationPrompt = false
    /// Filled when Stripe PaymentSheet prep succeeds (same PI the buyer pays).
    @State private var purchaseReceipt: PurchaseReceiptSnapshot?

    @State private var showAddressForm = false
    @State private var showProtectionInfo = false
    @State private var acceptedTerms = false

    private let accent = Color.black

    private struct PurchaseReceiptSnapshot {
        let orderId: String
        let breakdown: MarketplaceCheckoutService.PriceBreakdown
    }

    private var selectedRate: ShipmondoShippingService.Rate? {
        guard let id = selectedRateId else { return nil }
        return rates.first(where: { $0.id == id })
    }

    private var selectedShippingOre: Int? { selectedRate?.priceOre }

    private var selectedRateIsBookable: Bool {
        guard let r = selectedRate else { return false }
        return !r.bookingToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var selectedServicePoint: ShipmondoShippingService.ServicePoint? {
        guard let t = selectedServicePointToken else { return nil }
        return servicePoints.first(where: { $0.token == t })
    }

    private var needsServicePoint: Bool {
        selectedRate?.requiresServicePoint == true
    }

    // MARK: - Derived

    private var displayTitle: String {
        if let title = row.title, !title.isEmpty { return title }
        if !row.category.isEmpty { return row.category }
        return L.t(sv: "Annons", nb: "Annonse")
    }

    private var priceSEK: Int { row.priceSEK ?? 0 }

    /// Adress + frakt klara — räcker för att börja ladda Stripe-PaymentMetoder.
    /// Köpvillkor-checkboxen ska INTE blocka detta, annars går "Välj betalsätt"
    /// inte att trycka på och Stripe-prep körs aldrig.
    private var isReadyToLoadPayment: Bool {
        guard shippingAddress?.isValid == true, selectedRate != nil, selectedRateIsBookable else { return false }
        if needsServicePoint {
            return selectedServicePointToken != nil
        }
        return true
    }

    /// Allt klart inkl. accepterade köpvillkor. Gatar enbart Betala-knappen.
    private var canPay: Bool { isReadyToLoadPayment && acceptedTerms }

    private var totalFormatted: String {
        MarketplacePricing.buyerTotalFormatted(
            priceSEK: priceSEK,
            shippingOre: selectedShippingOre
        )
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            if didComplete {
                confirmationScreen
                    .transition(.opacity)
            } else {
                checkoutBody
            }
        }
        .navigationTitle(L.t(sv: "Betalning", nb: "Betaling"))
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(didComplete)
            .onAppear {
                if !tabBarHideAcquired {
                    NavigationDepthTracker.shared.acquireHideTabBar()
                    tabBarHideAcquired = true
                }
                if buyerEmail.isEmpty {
                    buyerEmail = authViewModel.currentUser?.email ?? ""
                }
                // Hydrate from previously saved address so köpare slipper
                // skriva in den varje gång.
                if shippingAddress == nil,
                   let saved = UserDefaults.standard.loadBuyerShippingAddress() {
                    shippingAddress = saved
                }
                if shippingAddress?.isValid == true {
                    Task { await reloadRates() }
                }
                if isReadyToLoadPayment {
                    Task { await prepareFlowControllerIfNeeded() }
                }
            }
            .onDisappear {
                if tabBarHideAcquired {
                    NavigationDepthTracker.shared.releaseHideTabBar()
                    tabBarHideAcquired = false
                }
            }
            .onChange(of: shippingAddress) { _, newAddress in
                rates = []
                selectedRateId = nil
                servicePoints = []
                selectedServicePointToken = nil
                invalidateFlowController()
                if newAddress?.isValid == true {
                    Task { await reloadRates() }
                }
            }
            .onChange(of: selectedRateId) { _, _ in
                // Total changed → need a fresh PI with the new amount.
                invalidateFlowController()
                servicePoints = []
                selectedServicePointToken = nil
                if needsServicePoint {
                    Task { await reloadServicePoints() }
                } else if isReadyToLoadPayment {
                    Task { await prepareFlowControllerIfNeeded() }
                }
            }
            .onChange(of: selectedServicePointToken) { _, _ in
                invalidateFlowController()
                if isReadyToLoadPayment {
                    Task { await prepareFlowControllerIfNeeded() }
                }
            }
            .onChange(of: acceptedTerms) { _, _ in
                // No-op preparation-mässigt — flowController är redan
                // initierad oberoende av terms. Vi behöver bara att SwiftUI
                // räknar om buyButton's `disabled`-binding så Betala blir
                // klickbar i samma stund som checkboxen kryssas.
            }
            .sheet(isPresented: $showAddressForm) {
                AddressFormView(initial: shippingAddress) { address in
                    withAnimation(.easeInOut(duration: 0.15)) {
                        shippingAddress = address
                    }
                    if address.isValid {
                        UserDefaults.standard.saveBuyerShippingAddress(address)
                    }
                }
            }
        .sheet(isPresented: $showProtectionInfo) {
            buyerProtectionInfoSheet
        }
        .notificationPrompt(for: .purchaseSuccess, trigger: $triggerNotificationPrompt)
    }

    // MARK: - Main body

    private var checkoutBody: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                listingRow

                addressSection

                shippingOptionsSection

                paymentSection

                priceBreakdownSection

                if let prepareError {
                    Text(prepareError)
                        .font(.system(size: 13))
                        .foregroundColor(.red)
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.red.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 20)
        }
        .safeAreaInset(edge: .bottom) { bottomBar }
    }

    // MARK: - Listing row

    private var listingRow: some View {
        HStack(alignment: .top, spacing: 14) {
            CachedRemoteImage(url: row.imageUrls.first) {
                Color(.secondarySystemBackground)
            }
            .frame(width: 96, height: 124)
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                Text(displayTitle)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)
                    .lineLimit(2)

                if let brand = row.userBrand, !brand.isEmpty, brand != displayTitle {
                    Text(brand)
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }

                if let meta = listingMetaLine {
                    Text(meta)
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }

                Spacer(minLength: 14)

                Text("\(priceSEK),00 kr")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.primary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 4)
    }

    private var listingMetaLine: String? {
        var parts: [String] = []
        if let condition = row.userCondition, !condition.isEmpty {
            parts.append(condition)
        }
        if let size = row.packageSize, !size.isEmpty {
            parts.append(size)
        }
        return parts.isEmpty ? nil : parts.joined(separator: " / ")
    }

    // MARK: - Address section

    private var addressSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle(L.t(sv: "Adress", nb: "Adresse"))

            if let address = shippingAddress, address.isValid {
                Button {
                    showAddressForm = true
                } label: {
                    HStack(alignment: .top, spacing: 12) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(address.fullName)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(.primary)
                            Text(address.displayLine)
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                            Text("\(address.postalCode) \(address.city)")
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Image(systemName: "pencil")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.secondary)
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(Color.black.opacity(0.12), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            } else {
                Button {
                    showAddressForm = true
                } label: {
                    HStack {
                        Text(L.t(sv: "Lägg till din leveransadress",
                                 nb: "Legg til leveringsadresse"))
                            .font(.system(size: 15))
                            .foregroundColor(.primary)
                        Spacer()
                        Image(systemName: "plus")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.primary)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(Color.black.opacity(0.12), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Shipping options (carrier picker)

    private var shippingOptionsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                sectionTitle(L.t(sv: "Leveransalternativ", nb: "Leveringsalternativer"))
                Spacer()
                if ratesLoading {
                    ProgressView().controlSize(.small)
                }
            }

            if shippingAddress?.isValid != true {
                Text(L.t(
                    sv: "Lägg till leveransadress för att se fraktpriser",
                    nb: "Legg til leveringsadresse for å se fraktpriser"
                ))
                .font(.system(size: 13))
                .foregroundColor(.secondary)
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(Color.black.opacity(0.12), lineWidth: 1)
                )
            } else if ratesLoading && rates.isEmpty {
                rateSkeletonRow
                rateSkeletonRow
            } else if let ratesError, rates.isEmpty {
                Text(ratesError)
                    .font(.system(size: 13))
                    .foregroundColor(.orange)
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color.orange.opacity(0.08))
                    )
            } else if rates.isEmpty {
                Text(L.t(
                    sv: "Inga fraktalternativ hittades för adressen.",
                    nb: "Ingen fraktalternativer funnet for adressen."
                ))
                .font(.system(size: 13))
                .foregroundColor(.secondary)
            } else {
                VStack(spacing: 8) {
                    ForEach(rates) { rate in
                        VStack(spacing: 8) {
                            rateRow(rate: rate)
                            if rate.id == selectedRateId, rate.requiresServicePoint {
                                servicePointPickerInline
                                    .transition(.opacity.combined(with: .move(edge: .top)))
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Inline ombud picker

    @ViewBuilder
    private var servicePointPickerInline: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Text(L.t(sv: "Välj ombud", nb: "Velg utleveringssted"))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.primary)
                Spacer()
                if servicePointsLoading {
                    ProgressView().controlSize(.small)
                }
            }

            if servicePointsLoading && servicePoints.isEmpty {
                spLoadingPlaceholder
            } else if let err = servicePointsError, servicePoints.isEmpty {
                Text(err)
                    .font(.system(size: 12))
                    .foregroundColor(.orange)
            } else if servicePoints.isEmpty {
                Text(L.t(
                    sv: "Inga ombud hittades nära din adress.",
                    nb: "Ingen utleveringssteder funnet nær adressen."
                ))
                .font(.system(size: 12))
                .foregroundColor(.secondary)
            } else {
                VStack(spacing: 6) {
                    ForEach(servicePoints) { sp in
                        servicePointRow(sp)
                    }
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.black.opacity(0.03))
        )
        .padding(.leading, 8)
    }

    private var spLoadingPlaceholder: some View {
        VStack(spacing: 6) {
            ForEach(0..<3, id: \.self) { _ in
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(.systemGray5))
                    .frame(height: 44)
            }
        }
    }

    @ViewBuilder
    private func servicePointRow(_ sp: ShipmondoShippingService.ServicePoint) -> some View {
        let selected = sp.token == selectedServicePointToken
        Button {
            withAnimation(.easeInOut(duration: 0.12)) {
                selectedServicePointToken = sp.token
            }
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .strokeBorder(selected ? accent : Color(.systemGray3),
                                      lineWidth: selected ? 0 : 1.5)
                        .frame(width: 18, height: 18)
                    if selected {
                        Circle().fill(accent).frame(width: 18, height: 18)
                        Image(systemName: "checkmark")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(sp.name)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    Text(servicePointSubtitle(sp))
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                Spacer()
                if sp.distanceMeters > 0 {
                    Text(distanceText(meters: sp.distanceMeters))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color(.systemBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(selected ? accent : Color.black.opacity(0.1),
                            lineWidth: selected ? 1.5 : 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func servicePointSubtitle(_ sp: ShipmondoShippingService.ServicePoint) -> String {
        var parts: [String] = []
        if !sp.addressLine.isEmpty { parts.append(sp.addressLine) }
        let cityLine = "\(sp.postalCode) \(sp.city)".trimmingCharacters(in: .whitespaces)
        if !cityLine.isEmpty { parts.append(cityLine) }
        return parts.joined(separator: " · ")
    }

    private func distanceText(meters: Int) -> String {
        if meters >= 1000 {
            let km = Double(meters) / 1000.0
            return String(format: "%.1f km", km)
        }
        return "\(meters) m"
    }

    @MainActor
    private func reloadServicePoints() async {
        guard let address = shippingAddress, address.isValid,
              let rate = selectedRate, rate.requiresServicePoint else { return }

        servicePointsLoading = true
        servicePointsError = nil
        defer { servicePointsLoading = false }

        do {
            let session = try await SupabaseConfig.supabase.auth.session
            let fetched = try await ShipmondoShippingService.shared.fetchServicePoints(
                carrier: rate.carrier,
                addressLine: address.displayLine,
                postalCode: address.postalCode,
                city: address.city,
                accessToken: session.accessToken
            )
            self.servicePoints = fetched
            self.selectedServicePointToken = fetched.first?.token
        } catch {
            self.servicePointsError = error.localizedDescription
            self.servicePoints = []
            self.selectedServicePointToken = nil
        }
    }

    private func rateRow(rate: ShipmondoShippingService.Rate) -> some View {
        let selected = rate.id == selectedRateId
        return Button {
            withAnimation(.easeInOut(duration: 0.12)) {
                selectedRateId = rate.id
            }
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .strokeBorder(selected ? accent : Color(.systemGray3),
                                      lineWidth: selected ? 0 : 1.5)
                        .frame(width: 22, height: 22)
                    if selected {
                        Circle()
                            .fill(accent)
                            .frame(width: 22, height: 22)
                        Image(systemName: "checkmark")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.white)
                    }
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(rate.name)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.primary)
                    Text(rate.etaText)
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }

                Spacer()

                Text(MarketplacePricing.shippingFormatted(shippingOre: rate.priceOre))
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.primary)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(selected ? accent : Color.black.opacity(0.12),
                                  lineWidth: selected ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var rateSkeletonRow: some View {
        HStack(spacing: 14) {
            Circle()
                .fill(Color(.systemGray5))
                .frame(width: 22, height: 22)
            VStack(alignment: .leading, spacing: 6) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(.systemGray5))
                    .frame(height: 14)
                    .frame(maxWidth: 140)
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(.systemGray6))
                    .frame(height: 12)
                    .frame(maxWidth: 90)
            }
            Spacer()
            RoundedRectangle(cornerRadius: 4)
                .fill(Color(.systemGray5))
                .frame(width: 50, height: 14)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(Color.black.opacity(0.08), lineWidth: 1)
        )
    }

    @MainActor
    private func reloadRates() async {
        guard let address = shippingAddress, address.isValid else { return }
        let postal = address.postalCode.trimmingCharacters(in: .whitespaces)
        let city = address.city.trimmingCharacters(in: .whitespaces)
        guard postal.count >= 4, !city.isEmpty else { return }

        ratesLoading = true
        ratesError = nil
        defer { ratesLoading = false }

        do {
            let session = try await SupabaseConfig.supabase.auth.session
            let fetched = try await ShipmondoShippingService.shared.fetchRates(
                listingId: row.id,
                buyerPostal: postal,
                buyerCity: city,
                accessToken: session.accessToken
            )
            let bookable = fetched.filter {
                !$0.bookingToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            }
            if bookable.isEmpty {
                if fetched.isEmpty {
                    self.ratesError = L.t(
                        sv: "Vi kan tyvärr inte erbjuda frakt till den här adressen just nu. Kontrollera postnummer och ort, eller försök igen senare.",
                        nb: "Vi kan dessverre ikke tilby frakt til denne adressen akkurat nå. Sjekk postnummer og sted, eller prøv igjen senere."
                    )
                } else {
                    self.ratesError = L.t(
                        sv: "Frakt kunde inte bokas just nu (saknar bokningsnyckel från transportören). Försök igen om en stund.",
                        nb: "Frakt kunne ikke bestilles akkurat nå. Prøv igjen om litt."
                    )
                }
            } else {
                self.ratesError = nil
            }
            self.rates = bookable
            // Default-select the cheapest rate (sorted server-side already,
            // but be defensive).
            if let cheapest = bookable.min(by: { $0.priceOre < $1.priceOre }) {
                self.selectedRateId = cheapest.id
            } else {
                self.selectedRateId = nil
            }
        } catch {
            self.ratesError = error.localizedDescription
            self.rates = []
            self.selectedRateId = nil
        }
    }

    // MARK: - Payment

    private var paymentSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle(L.t(sv: "Betalning", nb: "Betaling"))

            Button {
                presentPaymentOptions()
            } label: {
                HStack(spacing: 12) {
                    paymentMethodIcon
                        .frame(width: 44, height: 28)
                        .background(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(Color(.systemGray6))
                        )

                    Text(paymentMethodLabel)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.primary)

                    Spacer()

                    if isPreparing && flowController == nil {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "pencil")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.secondary)
                    }
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(Color.black.opacity(0.12), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .disabled(!isReadyToLoadPayment || flowController == nil)
            .opacity((isReadyToLoadPayment && flowController != nil) ? 1.0 : 0.6)
        }
    }

    @ViewBuilder
    private var paymentMethodIcon: some View {
        if let image = paymentOption?.image {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .padding(4)
        } else {
            applePayLogo
        }
    }

    private var paymentMethodLabel: String {
        if let label = paymentOption?.label {
            return label
        }
        if !isReadyToLoadPayment {
            return L.t(sv: "Fyll i adress för att välja betalsätt",
                       nb: "Fyll inn adresse for å velge betalingsmåte")
        }
        if flowController == nil && isPreparing {
            return L.t(sv: "Laddar betalsätt…", nb: "Laster betalingsmåter…")
        }
        return L.t(sv: "Välj betalsätt", nb: "Velg betalingsmåte")
    }

    private var applePayLogo: some View {
        HStack(spacing: 2) {
            Image(systemName: "applelogo")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.primary)
            Text("Pay")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.primary)
        }
    }

    // MARK: - Price breakdown

    private var priceBreakdownSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle(L.t(sv: "Att betala", nb: "Å betale"))

            breakdownRow(
                label: L.t(sv: "Beställning", nb: "Bestilling"),
                value: "\(priceSEK),00 kr"
            )

            HStack {
                HStack(spacing: 6) {
                    Text(L.t(sv: "Kostnad för köparskydd",
                             nb: "Kostnad for kjøperbeskyttelse"))
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                    Button {
                        showProtectionInfo = true
                    } label: {
                        Image(systemName: "info.circle")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
                Text(MarketplacePricing.platformFeeFormatted(priceSEK: priceSEK))
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }

            breakdownRow(
                label: L.t(sv: "Frakt", nb: "Frakt"),
                value: shippingBreakdownValue
            )
        }
    }

    private var shippingBreakdownValue: String {
        if let ore = selectedShippingOre {
            return MarketplacePricing.shippingFormatted(shippingOre: ore)
        }
        return L.t(sv: "Välj fraktsätt", nb: "Velg fraktmåte")
    }

    private func breakdownRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 14))
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.system(size: 14))
                .foregroundColor(.secondary)
        }
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 18, weight: .bold))
            .foregroundColor(.primary)
    }

    // MARK: - Bottom bar (total + Apple Pay)

    private var bottomBar: some View {
        VStack(spacing: 12) {
            Divider()

            HStack {
                Text(L.t(sv: "Totalsumma att betala", nb: "Totalsum å betale"))
                    .font(.system(size: 15, weight: .semibold))
                Spacer()
                Text(totalFormatted)
                    .font(.system(size: 16, weight: .bold))
            }
            .padding(.horizontal, 16)

            termsCheckbox
                .padding(.horizontal, 16)

            buyButton
                .padding(.horizontal, 16)

            HStack(spacing: 6) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 10))
                Text(L.t(
                    sv: "Dina betalningsuppgifter är krypterade och säkra hos oss",
                    nb: "Betalingsopplysningene dine er kryptert og trygge hos oss"
                ))
                .font(.system(size: 11))
            }
            .foregroundColor(.secondary)
            .padding(.bottom, 6)
        }
        .padding(.top, 10)
        .background(
            Color(.systemBackground)
                .ignoresSafeArea(edges: .bottom)
        )
    }

    private var termsCheckbox: some View {
        HStack(alignment: .top, spacing: 10) {
            Button {
                acceptedTerms.toggle()
            } label: {
                Image(systemName: acceptedTerms ? "checkmark.square.fill" : "square")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(acceptedTerms ? .black : .secondary)
            }
            .buttonStyle(.plain)

            // Köpvillkoren behövs juridiskt för B2C-transaktioner.
            // URL-en pekar på den statiska sidan som hostas på upanddown.app.
            (
                Text(L.t(
                    sv: "Jag godkänner ",
                    nb: "Jeg godtar "
                ))
                + Text(L.t(sv: "köpvillkoren", nb: "kjøpsvilkårene"))
                    .underline()
                    .foregroundColor(.blue)
                + Text(".")
            )
            .font(.system(size: 12))
            .foregroundColor(.primary)
            .onTapGesture {
                if let url = URL(string: "https://upanddown.app/legal/buyer-terms") {
                    UIApplication.shared.open(url)
                }
            }

            Spacer()
        }
    }

    @ViewBuilder
    private var buyButton: some View {
        Button {
            confirmPayment()
        } label: {
            buyButtonLabel
        }
        // Knappen är aktiv så fort allt är ifyllt + terms godkända.
        // Om FlowController inte är klar väntar `confirmPayment()` in
        // prep:en så användaren ser en spinner istället för en död knapp.
        .disabled(!canPay || isConfirming)
        .opacity(canPay ? 1.0 : 0.5)
    }

    private var buyButtonLabel: some View {
        HStack(spacing: 8) {
            if isConfirming {
                ProgressView().tint(.white)
            } else if isApplePaySelected {
                Image(systemName: "applelogo")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                Text("Pay")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
            } else {
                Text(buyButtonTitle)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.white)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(Color.black)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var isApplePaySelected: Bool {
        guard let type = paymentOption?.paymentMethodType else { return false }
        return type.lowercased() == "apple_pay"
    }

    private var buyButtonTitle: String {
        if let label = paymentOption?.label, !label.isEmpty {
            return L.t(sv: "Betala med \(label)", nb: "Betal med \(label)")
        }
        return L.t(sv: "Betala", nb: "Betal")
    }

    // MARK: - Payment preparation

    private func invalidateFlowController() {
        flowController = nil
        paymentOption = nil
        purchaseReceipt = nil
    }

    private func prepareFlowControllerIfNeeded() async {
        guard flowController == nil, !isPreparing else { return }
        await prepareFlowController()
    }

    private func prepareFlowController() async {
        guard isReadyToLoadPayment, let address = shippingAddress else { return }
        prepareError = nil
        await MainActor.run { isPreparing = true }

        do {
            let session = try await SupabaseConfig.supabase.auth.session
            let accessToken = session.accessToken

            let shipping = MarketplaceCheckoutService.ShippingAddress(
                name: address.fullName,
                address: address.displayLine,
                postal: address.postalCode,
                city: address.city
            )

            let chosen = selectedRate
            let chosenSP = selectedServicePoint
            let sheet = try await MarketplaceCheckoutService.shared.createPaymentIntent(
                listingId: row.id,
                shipping: shipping,
                buyerEmail: buyerEmail.isEmpty
                    ? (authViewModel.currentUser?.email ?? "")
                    : buyerEmail,
                accessToken: accessToken,
                buyerPhone: address.normalizedPhoneE164,
                shippingCarrier: chosen?.carrier,
                shippingServiceCode: chosen?.serviceCode,
                shippingProductName: chosen?.productName,
                shippingAmountOre: chosen?.priceOre,
                shippingBookingToken: chosen?.bookingToken,
                shippingServicePointToken: chosenSP?.token,
                shippingServicePointName: chosenSP?.name,
                shippingServicePointAddress: chosenSP.map { servicePointSubtitle($0) }
            )

            STPAPIClient.shared.publishableKey = sheet.publishableKey

            var config = PaymentSheet.Configuration()
            config.merchantDisplayName = "Up&Down"
            config.customer = .init(
                id: sheet.customerId,
                ephemeralKeySecret: sheet.ephemeralKey
            )
            config.allowsDelayedPaymentMethods = true
            config.applePay = .init(
                merchantId: StripeConfig.appleMerchantId,
                merchantCountryCode: "SE"
            )
            config.appearance.colors.primary = UIColor(accent)
            config.appearance.cornerRadius = 12

            let clientSecret = sheet.paymentIntentClientSecret

            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                PaymentSheet.FlowController.create(
                    paymentIntentClientSecret: clientSecret,
                    configuration: config
                ) { result in
                    switch result {
                    case .success(let fc):
                        Task { @MainActor in
                            self.flowController = fc
                            self.paymentOption = fc.paymentOption
                            self.purchaseReceipt = PurchaseReceiptSnapshot(
                                orderId: sheet.orderId,
                                breakdown: sheet.breakdown
                            )
                            self.isPreparing = false
                            continuation.resume()
                        }
                    case .failure(let error):
                        Task { @MainActor in
                            self.isPreparing = false
                            continuation.resume(throwing: error)
                        }
                    }
                }
            }
        } catch {
            await MainActor.run {
                self.isPreparing = false
                self.prepareError = error.localizedDescription
            }
        }
    }

    private func presentPaymentOptions() {
        guard let fc = flowController,
              let presenter = Self.topViewController() else { return }
        fc.presentPaymentOptions(from: presenter) {
            Task { @MainActor in
                self.paymentOption = fc.paymentOption
            }
        }
    }

    private func confirmPayment() {
        // Om FlowController inte är klar (men allt är ifyllt) — vänta in
        // pågående prep istället för att tappa kontexten. Användaren ser
        // spinner i Betala-knappen tills Stripe-sheet:en är redo.
        if flowController == nil {
            guard isReadyToLoadPayment else { return }
            isConfirming = true
            Task { @MainActor in
                await prepareFlowControllerIfNeeded()
                guard let fc = flowController,
                      let presenter = Self.topViewController() else {
                    isConfirming = false
                    return
                }
                fc.confirm(from: presenter) { result in
                    Task { @MainActor in
                        self.isConfirming = false
                        self.handlePaymentCompletion(result)
                    }
                }
            }
            return
        }

        guard let fc = flowController,
              let presenter = Self.topViewController() else { return }
        isConfirming = true
        fc.confirm(from: presenter) { result in
            Task { @MainActor in
                self.isConfirming = false
                self.handlePaymentCompletion(result)
            }
        }
    }

    private func handlePaymentCompletion(_ result: PaymentSheetResult) {
        switch result {
        case .completed:
            withAnimation { didComplete = true }
            // Soft-prompt notiser ~3 sekunder efter framgång så
            // användaren först ser bekräftelsen.
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                triggerNotificationPrompt = true
            }
        case .canceled:
            break
        case .failed(let error):
            prepareError = error.localizedDescription
            invalidateFlowController()
            Task { await prepareFlowControllerIfNeeded() }
        }
    }

    // MARK: - Top view controller helper

    private static func topViewController(
        _ base: UIViewController? = nil
    ) -> UIViewController? {
        let root: UIViewController? = base ?? UIApplication.shared
            .connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first(where: { $0.isKeyWindow })?
            .rootViewController

        if let nav = root as? UINavigationController {
            return topViewController(nav.visibleViewController)
        }
        if let tab = root as? UITabBarController,
           let selected = tab.selectedViewController {
            return topViewController(selected)
        }
        if let presented = root?.presentedViewController {
            return topViewController(presented)
        }
        return root
    }

    // MARK: - Confirmation

    private var confirmationScreen: some View {
        ScrollView {
            VStack(spacing: 18) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 72, weight: .semibold))
                    .foregroundColor(accent)
                    .padding(.top, 24)

                Text(L.t(sv: "Köpet är genomfört!", nb: "Kjøpet er gjennomført!"))
                    .font(.system(size: 22, weight: .bold))
                    .multilineTextAlignment(.center)

                Text(displayTitle)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)

                if let snap = purchaseReceipt {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(L.t(sv: "Kvitto", nb: "Kvittering"))
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.secondary)

                        receiptLine(
                            L.t(sv: "Ordernr", nb: "Ordrenummer"),
                            value: snap.orderId
                        )
                        receiptLine(
                            L.t(sv: "Vara", nb: "Vare"),
                            value: MarketplacePricing.formatSEK(snap.breakdown.itemSEK)
                        )
                        receiptLine(
                            L.t(sv: "Köparskydd", nb: "Kjøperbeskyttelse"),
                            value: MarketplacePricing.formatSEK(snap.breakdown.platformFeeSEK)
                        )
                        if let shipOre = snap.breakdown.shippingFeeOre, shipOre > 0 {
                            receiptLine(
                                L.t(sv: "Frakt", nb: "Frakt"),
                                value: MarketplacePricing.formatSEK(snap.breakdown.shippingFeeSEK)
                            )
                        }
                        receiptLine(
                            L.t(sv: "Totalt betalt", nb: "Totalt betalt"),
                            value: MarketplacePricing.formatSEK(snap.breakdown.buyerTotalSEK),
                            emphasized: true
                        )
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color(.secondarySystemBackground))
                    )
                    .padding(.horizontal, 20)

                    if let seller = sellerDisplayNameForReceipt {
                        Text(L.t(sv: "Säljare: \(seller)", nb: "Selger: \(seller)"))
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 24)
                    }
                }

                Text(L.t(
                    sv: "Spårning visas under \"Mina köp\" när säljaren skickat paketet.",
                    nb: "Sporing vises under «Mine kjøp» når selgeren har sendt pakken."
                ))
                .font(.system(size: 14))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)

                if !confirmationReceiptEmail.isEmpty {
                    Text(L.t(
                        sv: "Betalningskvitto skickas också till \(confirmationReceiptEmail) från betalleverantören.",
                        nb: "Betalingskvittering sendes også til \(confirmationReceiptEmail) fra betalingsleverandøren."
                    ))
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                }

                Text(L.t(
                    sv: "Säljaren har fått en notis. Du hittar köpet under \"Mina köp\" på profilen.",
                    nb: "Selgeren har fått beskjed. Du finner kjøpet under «Mine kjøp» på profilen."
                ))
                .font(.system(size: 14))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)

                Button {
                    if tabBarHideAcquired {
                        NavigationDepthTracker.shared.releaseHideTabBar()
                        tabBarHideAcquired = false
                    }
                    NavigationDepthTracker.shared.hideTabBar = false
                    dismiss()
                    NotificationCenter.default.post(
                        name: NSNotification.Name("NavigateToProfile"),
                        object: nil
                    )
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                        NotificationCenter.default.post(
                            name: NSNotification.Name("OpenMyPurchases"),
                            object: nil
                        )
                    }
                } label: {
                    Text(L.t(sv: "Stäng", nb: "Lukk"))
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(accent)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 28)
            }
        }
    }

    private var sellerDisplayNameForReceipt: String? {
        let raw = UserProfileCache.shared.snapshot(for: row.userId.uuidString)?.username
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return raw.isEmpty ? nil : raw
    }

    private var confirmationReceiptEmail: String {
        let e = buyerEmail.isEmpty ? (authViewModel.currentUser?.email ?? "") : buyerEmail
        return e.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func receiptLine(_ label: String, value: String, emphasized: Bool = false) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .font(.system(size: 14, weight: emphasized ? .semibold : .regular))
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.system(size: 14, weight: emphasized ? .bold : .medium))
                .foregroundColor(.primary)
                .multilineTextAlignment(.trailing)
        }
    }

    // MARK: - Buyer protection info

    private var buyerProtectionInfoSheet: some View {
        VStack(spacing: 16) {
            Capsule()
                .fill(Color(.systemGray3))
                .frame(width: 36, height: 4)
                .padding(.top, 10)

            Image(systemName: "checkmark.shield.fill")
                .font(.system(size: 42))
                .foregroundColor(accent)
                .padding(.top, 4)

            Text(L.t(sv: "Kostnad för köparskydd",
                     nb: "Kostnad for kjøperbeskyttelse"))
                .font(.system(size: 19, weight: .bold))
                .multilineTextAlignment(.center)

            Text(L.t(
                sv: "Varje köp är skyddat av vårt köparskydd: om varan inte levereras eller inte stämmer med annonsen får du pengarna tillbaka. Avgiften är 5 % av varans pris plus 7,50 kr.",
                nb: "Hvert kjøp er beskyttet av vår kjøperbeskyttelse: hvis varen ikke leveres eller ikke stemmer med annonsen får du pengene tilbake. Avgiften er 5 % av varens pris pluss 7,50 kr."
            ))
            .font(.system(size: 14))
            .foregroundColor(.secondary)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 24)

            Spacer()

            Button {
                showProtectionInfo = false
            } label: {
                Text(L.t(sv: "Okej", nb: "Greit"))
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(accent)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
        .presentationDetents([.medium])
    }
}
