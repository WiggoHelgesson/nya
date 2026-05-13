import SwiftUI
import StripePaymentSheet
import Supabase
import Auth

/// Buyer-side price-offer sheet ("Prisförslag").
///
/// Light-themed sheet (matches rest of the app) with black CTAs. The buyer
/// enters a desired price (editable – clear pencil + hint) and an optional
/// message. The CTA "Betala X kr" creates a PaymentIntent with
/// `capture_method: 'manual'`, opens the Stripe PaymentSheet to collect card
/// details, and then authorises (but does not capture) the card. Capture
/// happens later when the buyer fills in shipping inside the chat after the
/// seller has accepted via `finalize-marketplace-offer`.
struct PriceOfferSheetView: View {
    let row: ConsignmentSubmissionRow

    @EnvironmentObject var authViewModel: AuthViewModel
    @Environment(\.dismiss) private var dismiss

    // MARK: - State

    @State private var offeredPriceText: String = ""
    @State private var message: String = ""

    @State private var buyerEmail: String = ""

    // Shipping (carrier picker, populated lazily as the buyer fills in postal/city)
    @State private var buyerPostal: String = ""
    @State private var buyerCity: String = ""
    @State private var rates: [ShipmondoShippingService.Rate] = []
    @State private var selectedRateId: String?
    @State private var ratesLoading: Bool = false
    @State private var ratesError: String?

    // Ombud / service-point picker (only shown when chosen rate has
    // `requiresServicePoint == true`).
    @State private var servicePoints: [ShipmondoShippingService.ServicePoint] = []
    @State private var selectedServicePointToken: String?
    @State private var servicePointsLoading: Bool = false
    @State private var servicePointsError: String?

    @State private var flowController: PaymentSheet.FlowController?
    @State private var paymentOption: PaymentSheet.FlowController.PaymentOptionDisplayData?
    @State private var isSubmitting = false
    @State private var didComplete = false
    @State private var triggerNotificationPrompt = false
    @State private var errorText: String?

    @State private var showProtectionInfo = false
    @FocusState private var priceFocused: Bool
    @FocusState private var postalFocused: Bool
    @FocusState private var cityFocused: Bool

    private let minPriceSEK = 50

    // MARK: - Derived

    private var listingPriceSEK: Int { row.priceSEK ?? 0 }

    private var offeredPriceSEK: Int {
        let digits = offeredPriceText.filter(\.isNumber)
        return Int(digits) ?? 0
    }

    private var maxPriceSEK: Int { max(listingPriceSEK, minPriceSEK) }

    private var canSubmit: Bool {
        guard offeredPriceSEK >= minPriceSEK,
              offeredPriceSEK <= maxPriceSEK,
              selectedRate != nil else { return false }
        if needsServicePoint {
            return selectedServicePointToken != nil
        }
        return true
    }

    private var selectedRate: ShipmondoShippingService.Rate? {
        guard let id = selectedRateId else { return nil }
        return rates.first(where: { $0.id == id })
    }

    private var selectedShippingOre: Int? {
        selectedRate?.priceOre
    }

    private var selectedServicePoint: ShipmondoShippingService.ServicePoint? {
        guard let t = selectedServicePointToken else { return nil }
        return servicePoints.first(where: { $0.token == t })
    }

    private var needsServicePoint: Bool {
        selectedRate?.requiresServicePoint == true
    }

    private var showDiscountStrike: Bool {
        offeredPriceSEK > 0 && offeredPriceSEK < listingPriceSEK
    }

    private var displayTitle: String {
        if let title = row.title, !title.isEmpty { return title }
        if !row.category.isEmpty { return row.category }
        return L.t(sv: "Annons", nb: "Annonse")
    }

    private var borderColor: Color { Color.black.opacity(0.12) }
    private var subtleBackground: Color { Color(.secondarySystemBackground) }

    // MARK: - Body

    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()
            if didComplete {
                successView
            } else {
                content
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $showProtectionInfo) {
            protectionInfoSheet
        }
        .onChange(of: selectedRateId) { _, _ in
            servicePoints = []
            selectedServicePointToken = nil
            if needsServicePoint {
                Task { await reloadServicePoints() }
            }
        }
        .onAppear {
            NavigationDepthTracker.shared.acquireHideTabBar()
            if offeredPriceText.isEmpty {
                offeredPriceText = formatWithSpaces(listingPriceSEK)
            }
            if buyerEmail.isEmpty {
                buyerEmail = authViewModel.currentUser?.email ?? ""
            }
            // Pre-fill postal/city. Try the validated full address first,
            // then fall back to the partial values we cache from the offer
            // flow (no full address required to quote rates).
            if let saved = UserDefaults.standard.loadBuyerShippingAddress() {
                if buyerPostal.isEmpty { buyerPostal = saved.postalCode }
                if buyerCity.isEmpty { buyerCity = saved.city }
            } else {
                let defaults = UserDefaults.standard
                if buyerPostal.isEmpty {
                    buyerPostal = defaults.string(forKey: "marketplace.buyer.postal.partial") ?? ""
                }
                if buyerCity.isEmpty {
                    buyerCity = defaults.string(forKey: "marketplace.buyer.city.partial") ?? ""
                }
            }
            if !buyerPostal.isEmpty && !buyerCity.isEmpty && rates.isEmpty {
                Task { await reloadRates() }
            }
        }
        .onDisappear {
            NavigationDepthTracker.shared.releaseHideTabBar()
        }
        .notificationPrompt(for: .offerSent, trigger: $triggerNotificationPrompt)
    }

    // MARK: - Main content

    private var content: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    header
                        .padding(.top, 8)

                    listingRow

                    priceField

                    shippingSection

                    messageField

                    if let errorText {
                        Text(errorText)
                            .font(.system(size: 13))
                            .foregroundColor(Color.red)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(12)
                            .background(Color.red.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }

                    Spacer(minLength: 20)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
            .scrollDismissesKeyboard(.interactively)

            bottomBar
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 10) {
                Text(L.t(sv: "Ditt prisförslag", nb: "Ditt prisforslag"))
                    .font(.system(size: 30, weight: .bold))
                    .foregroundColor(.primary)
                Text(L.t(
                    sv: "Vi meddelar säljaren att du vill köpa varan. Ditt prisförslag är bindande när säljaren har tackat ja.",
                    nb: "Vi gir selgeren beskjed om at du vil kjøpe varen. Ditt prisforslag er bindende når selgeren har takket ja."
                ))
                .font(.system(size: 15))
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 12)
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.primary)
                    .frame(width: 34, height: 34)
                    .background(Circle().fill(subtleBackground))
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Listing row

    private var listingRow: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(displayTitle)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)
                    .lineLimit(2)
                Text(L.t(
                    sv: "Ursprungligt pris \(formatWithSpaces(listingPriceSEK)) kr",
                    nb: "Opprinnelig pris \(formatWithSpaces(listingPriceSEK)) kr"
                ))
                .font(.system(size: 14))
                .foregroundColor(.secondary)
            }
            Spacer(minLength: 8)
            CachedRemoteImage(url: row.imageUrls.first) {
                subtleBackground
            }
            .frame(width: 52, height: 52)
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        }
    }

    // MARK: - Price field

    private var priceField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L.t(sv: "Ditt prisförslag", nb: "Ditt prisforslag"))
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.primary)

            Button {
                priceFocused = true
            } label: {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    TextField("", text: $offeredPriceText)
                        .focused($priceFocused)
                        .keyboardType(.numberPad)
                        .font(.system(size: 34, weight: .bold))
                        .foregroundColor(.primary)
                        .onChange(of: offeredPriceText) { _, newValue in
                            formatPriceInput(newValue)
                        }
                    Text("kr")
                        .font(.system(size: 22, weight: .regular))
                        .foregroundColor(.secondary)
                    Spacer()
                    Image(systemName: "pencil")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary)
                        .padding(.trailing, 2)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 16)
                .background(Color(.systemBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(priceFocused ? Color.black : borderColor,
                                lineWidth: priceFocused ? 1.5 : 1)
                )
            }
            .buttonStyle(.plain)

            Text(L.t(
                sv: "Tryck för att ändra priset",
                nb: "Trykk for å endre prisen"
            ))
            .font(.system(size: 12))
            .foregroundColor(.secondary)

            if offeredPriceSEK > 0 && offeredPriceSEK < minPriceSEK {
                Text(L.t(
                    sv: "Lägsta prisförslag är \(minPriceSEK) kr",
                    nb: "Laveste prisforslag er \(minPriceSEK) kr"
                ))
                .font(.system(size: 12))
                .foregroundColor(Color.orange)
            } else if offeredPriceSEK > maxPriceSEK {
                Text(L.t(
                    sv: "Prisförslaget får inte överstiga annonspriset",
                    nb: "Prisforslaget kan ikke overstige annonseprisen"
                ))
                .font(.system(size: 12))
                .foregroundColor(Color.orange)
            }
        }
    }

    // MARK: - Message field

    private var messageField: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Text(L.t(sv: "Meddelande till säljaren", nb: "Melding til selger"))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.primary)
                Text(L.t(sv: "(valfritt)", nb: "(valgfritt)"))
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }

            ZStack(alignment: .topLeading) {
                if message.isEmpty {
                    Text(L.t(sv: "Skulle gärna köpa den här :)",
                             nb: "Skulle gjerne kjøpt denne :)"))
                        .font(.system(size: 15))
                        .foregroundColor(.secondary.opacity(0.6))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 14)
                }
                TextEditor(text: $message)
                    .font(.system(size: 15))
                    .foregroundColor(.primary)
                    .scrollContentBackground(.hidden)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .frame(minHeight: 52)
                    .onChange(of: message) { _, newValue in
                        if newValue.count > 500 {
                            message = String(newValue.prefix(500))
                        }
                    }
            }
            .background(Color(.systemBackground))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(borderColor, lineWidth: 1)
            )
        }
    }

    // MARK: - Shipping section

    private var shippingSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Text(L.t(sv: "Frakt", nb: "Frakt"))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.primary)
                Spacer()
                if ratesLoading {
                    ProgressView()
                        .controlSize(.small)
                }
            }

            HStack(spacing: 10) {
                postalField
                cityField
            }

            if let ratesError, rates.isEmpty {
                Text(ratesError)
                    .font(.system(size: 12))
                    .foregroundColor(.orange)
            }

            if !rates.isEmpty {
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
            } else if buyerPostal.count >= 5 && buyerCity.isEmpty == false && !ratesLoading {
                Text(L.t(
                    sv: "Tryck på fältet för att ladda fraktpriser",
                    nb: "Trykk på feltet for å laste fraktpriser"
                ))
                .font(.system(size: 12))
                .foregroundColor(.secondary)
            } else if buyerPostal.isEmpty || buyerCity.isEmpty {
                Text(L.t(
                    sv: "Fyll i postnummer och ort för att se fraktpriser",
                    nb: "Fyll inn postnummer og by for å se fraktpriser"
                ))
                .font(.system(size: 12))
                .foregroundColor(.secondary)
            }
        }
    }

    private var postalField: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(L.t(sv: "Postnummer", nb: "Postnummer"))
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.secondary)
            TextField("123 45", text: $buyerPostal)
                .focused($postalFocused)
                .keyboardType(.numberPad)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.primary)
                .padding(.horizontal, 12)
                .padding(.vertical, 12)
                .background(Color(.systemBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(postalFocused ? Color.black : borderColor,
                                lineWidth: postalFocused ? 1.5 : 1)
                )
                .onChange(of: buyerPostal) { _, _ in
                    selectedRateId = nil
                    rates = []
                }
                .onChange(of: postalFocused) { _, focused in
                    if !focused { Task { await reloadRates() } }
                }
        }
        .frame(maxWidth: .infinity)
    }

    private var cityField: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(L.t(sv: "Ort", nb: "By"))
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.secondary)
            TextField("Stockholm", text: $buyerCity)
                .focused($cityFocused)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.primary)
                .textInputAutocapitalization(.words)
                .padding(.horizontal, 12)
                .padding(.vertical, 12)
                .background(Color(.systemBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(cityFocused ? Color.black : borderColor,
                                lineWidth: cityFocused ? 1.5 : 1)
                )
                .onChange(of: buyerCity) { _, _ in
                    selectedRateId = nil
                    rates = []
                }
                .onChange(of: cityFocused) { _, focused in
                    if !focused { Task { await reloadRates() } }
                }
        }
        .frame(maxWidth: .infinity)
    }

    private func rateRow(rate: ShipmondoShippingService.Rate) -> some View {
        let isSelected = rate.id == selectedRateId
        return Button {
            selectedRateId = rate.id
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .stroke(isSelected ? Color.black : borderColor, lineWidth: isSelected ? 5 : 1.5)
                        .frame(width: 20, height: 20)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(rate.name)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.primary)
                    Text(rate.etaText)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                Spacer()
                Text("\(formatWithSpaces(Int((Double(rate.priceOre) / 100.0).rounded()))) kr")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.primary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isSelected ? Color.black.opacity(0.03) : Color(.systemBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(isSelected ? Color.black : borderColor,
                            lineWidth: isSelected ? 1.5 : 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Inline ombud picker

    @ViewBuilder
    private var servicePointPickerInline: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Text(L.t(sv: "Välj ombud", nb: "Velg utleveringssted"))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.primary)
                Spacer()
                if servicePointsLoading {
                    ProgressView().controlSize(.small)
                }
            }

            if servicePointsLoading && servicePoints.isEmpty {
                VStack(spacing: 6) {
                    ForEach(0..<3, id: \.self) { _ in
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(.systemGray5))
                            .frame(height: 40)
                    }
                }
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
                        .strokeBorder(selected ? Color.black : Color(.systemGray3),
                                      lineWidth: selected ? 0 : 1.5)
                        .frame(width: 18, height: 18)
                    if selected {
                        Circle().fill(Color.black).frame(width: 18, height: 18)
                        Image(systemName: "checkmark")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(sp.name)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    Text(servicePointSubtitle(sp))
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                Spacer()
                if sp.distanceMeters > 0 {
                    Text(distanceText(meters: sp.distanceMeters))
                        .font(.system(size: 11, weight: .medium))
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
                    .stroke(selected ? Color.black : borderColor,
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
            return String(format: "%.1f km", Double(meters) / 1000.0)
        }
        return "\(meters) m"
    }

    @MainActor
    private func reloadServicePoints() async {
        guard let rate = selectedRate, rate.requiresServicePoint else { return }
        let postal = buyerPostal.trimmingCharacters(in: .whitespaces)
        let city = buyerCity.trimmingCharacters(in: .whitespaces)
        guard postal.count >= 4, !city.isEmpty else { return }

        servicePointsLoading = true
        servicePointsError = nil
        defer { servicePointsLoading = false }

        do {
            let session = try await SupabaseConfig.supabase.auth.session
            let fetched = try await ShipmondoShippingService.shared.fetchServicePoints(
                carrier: rate.carrier,
                addressLine: "\(postal) \(city)",
                postalCode: postal,
                city: city,
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

    @MainActor
    private func reloadRates() async {
        let postal = buyerPostal.trimmingCharacters(in: .whitespaces)
        let city = buyerCity.trimmingCharacters(in: .whitespaces)
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
            self.rates = fetched
            if let first = fetched.first {
                self.selectedRateId = first.id
                if first.requiresServicePoint {
                    Task { await reloadServicePoints() }
                }
            }
        } catch {
            self.ratesError = error.localizedDescription
        }
    }

    // MARK: - Bottom bar

    private var bottomBar: some View {
        VStack(spacing: 12) {
            Rectangle()
                .fill(borderColor)
                .frame(height: 1)

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(L.t(sv: "Totalt från", nb: "Totalt fra"))
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                Text("\(formatWithSpaces(totalFromKr())) kr")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.primary)
                if showDiscountStrike {
                    Text("\(formatWithSpaces(listingTotalKr())) kr")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary.opacity(0.7))
                        .strikethrough(true, color: .secondary.opacity(0.7))
                }
                Text(L.t(sv: "med Frakt med köpskydd",
                         nb: "med Frakt med kjøperbeskyttelse"))
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                Button {
                    showProtectionInfo = true
                } label: {
                    Image(systemName: "info.circle")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)

            Button {
                submit()
            } label: {
                HStack(spacing: 8) {
                    if isSubmitting {
                        ProgressView().tint(.white)
                    }
                    Text(L.t(
                        sv: "Betala \(formatWithSpaces(totalFromKr())) kr",
                        nb: "Betal \(formatWithSpaces(totalFromKr())) kr"
                    ))
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.white)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .background(canSubmit ? Color.black : Color.black.opacity(0.35))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .disabled(!canSubmit || isSubmitting)
            .padding(.horizontal, 20)
            .padding(.bottom, 12)
        }
        .background(Color(.systemBackground))
    }

    private func totalFromKr() -> Int {
        let total = MarketplacePricing.buyerTotal(
            priceSEK: offeredPriceSEK,
            shippingOre: selectedShippingOre
        )
        return Int(total.rounded())
    }

    private func listingTotalKr() -> Int {
        let total = MarketplacePricing.buyerTotal(
            priceSEK: listingPriceSEK,
            shippingOre: selectedShippingOre
        )
        return Int(total.rounded())
    }

    // MARK: - Success

    private var successView: some View {
        VStack(spacing: 20) {
            Spacer()
            ZStack {
                Circle().fill(Color(.secondarySystemBackground)).frame(width: 100, height: 100)
                Image(systemName: "paperplane.fill")
                    .font(.system(size: 42, weight: .semibold))
                    .foregroundColor(.primary)
            }

            Text(L.t(sv: "Prisförslag skickat!", nb: "Prisforslag sendt!"))
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(.primary)
                .multilineTextAlignment(.center)

            Text(L.t(
                sv: "Säljaren har fått en notis. Kortet är reserverat men inga pengar dras. Om säljaren tackar ja får du ett meddelande i chatten där du fyller i leveransadressen för att slutföra köpet.",
                nb: "Selgeren har fått beskjed. Kortet er reservert, men ingen penger trekkes. Hvis selgeren takker ja får du en melding i chatten hvor du fyller inn leveringsadressen for å fullføre kjøpet."
            ))
            .font(.system(size: 15))
            .foregroundColor(.secondary)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 32)

            Spacer()

            Button {
                dismiss()
            } label: {
                HStack(spacing: 8) {
                    Text(L.t(sv: "Stäng", nb: "Lukk"))
                        .font(.system(size: 16, weight: .semibold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.black)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
    }

    // MARK: - Price input formatting

    private func formatPriceInput(_ newValue: String) {
        let digits = newValue.filter(\.isNumber)
        if digits.isEmpty {
            offeredPriceText = ""
            return
        }
        let number = Int(digits) ?? 0
        offeredPriceText = formatWithSpaces(number)
    }

    private func formatWithSpaces(_ value: Int) -> String {
        let formatter = NumberFormatter()
        formatter.groupingSeparator = " "
        formatter.usesGroupingSeparator = true
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }

    // MARK: - Submit

    private func submit() {
        guard canSubmit else { return }
        errorText = nil
        isSubmitting = true

        Task {
            do {
                let session = try await SupabaseConfig.supabase.auth.session
                let accessToken = session.accessToken

                // Persist the postal/city the buyer typed so future
                // offers prefill instantly.
                let defaults = UserDefaults.standard
                defaults.set(buyerPostal, forKey: "marketplace.buyer.postal.partial")
                defaults.set(buyerCity, forKey: "marketplace.buyer.city.partial")
                if let existing = defaults.loadBuyerShippingAddress() {
                    var updated = existing
                    updated.postalCode = buyerPostal
                    updated.city = buyerCity
                    defaults.saveBuyerShippingAddress(updated)
                }

                let chosen = selectedRate
                let chosenSP = selectedServicePoint
                let sheet = try await MarketplaceOfferService.shared.createOffer(
                    listingId: row.id,
                    offeredPriceSEK: offeredPriceSEK,
                    message: message.trimmingCharacters(in: .whitespacesAndNewlines),
                    buyerEmail: buyerEmail.isEmpty
                        ? (authViewModel.currentUser?.email ?? "")
                        : buyerEmail,
                    accessToken: accessToken,
                    shippingCarrier: chosen?.carrier,
                    shippingServiceCode: chosen?.serviceCode,
                    shippingProductName: chosen?.productName,
                    shippingAmountOre: selectedShippingOre,
                    shippingBookingToken: chosen?.bookingToken,
                    shippingServicePointToken: chosenSP?.token,
                    shippingServicePointName: chosenSP?.name,
                    shippingServicePointAddress: chosenSP.map { servicePointSubtitle($0) }
                )

                try await presentPaymentSheet(sheet: sheet)
            } catch {
                await MainActor.run {
                    self.isSubmitting = false
                    self.errorText = error.localizedDescription
                }
            }
        }
    }

    private func presentPaymentSheet(sheet: MarketplaceOfferService.OfferSheet) async throws {
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
        config.appearance.colors.primary = UIColor.black
        config.appearance.cornerRadius = 12

        let clientSecret = sheet.paymentIntentClientSecret

        let fc: PaymentSheet.FlowController = try await withCheckedThrowingContinuation { cont in
            PaymentSheet.FlowController.create(
                paymentIntentClientSecret: clientSecret,
                configuration: config
            ) { result in
                switch result {
                case .success(let controller): cont.resume(returning: controller)
                case .failure(let err): cont.resume(throwing: err)
                }
            }
        }

        await MainActor.run {
            self.flowController = fc
        }

        guard let presenter = Self.topViewController() else {
            await MainActor.run {
                self.isSubmitting = false
                self.errorText = "Kunde inte öppna betalfönster"
            }
            return
        }

        // Let the user pick a payment method (card / Apple Pay / etc.) and then
        // confirm. Because the PaymentIntent uses capture_method=manual the card
        // will be authorised but no money moves until the seller accepts AND the
        // buyer finalises with a shipping address.
        await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
            fc.presentPaymentOptions(from: presenter) {
                Task { @MainActor in
                    if fc.paymentOption == nil {
                        self.isSubmitting = false
                        cont.resume()
                        return
                    }
                    fc.confirm(from: presenter) { result in
                        Task { @MainActor in
                            self.isSubmitting = false
                            switch result {
                            case .completed:
                                withAnimation { self.didComplete = true }
                                DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                                    self.triggerNotificationPrompt = true
                                }
                            case .canceled:
                                break
                            case .failed(let err):
                                self.errorText = err.localizedDescription
                            }
                            cont.resume()
                        }
                    }
                }
            }
        }
    }

    // MARK: - Info sheet

    private var protectionInfoSheet: some View {
        VStack(spacing: 16) {
            Capsule()
                .fill(Color(.systemGray3))
                .frame(width: 36, height: 4)
                .padding(.top, 10)

            Image(systemName: "checkmark.shield.fill")
                .font(.system(size: 42))
                .foregroundColor(.primary)
                .padding(.top, 4)

            Text(L.t(sv: "Kostnad för köparskydd",
                     nb: "Kostnad for kjøperbeskyttelse"))
                .font(.system(size: 19, weight: .bold))
                .foregroundColor(.primary)
                .multilineTextAlignment(.center)

            Text(L.t(
                sv: "Varje köp är skyddat av vårt köparskydd: om varan inte levereras eller inte stämmer med annonsen får du pengarna tillbaka. Avgiften är 5 % av varans pris plus 7,50 kr. Frakten är 35,65 kr.",
                nb: "Hvert kjøp er beskyttet av vår kjøperbeskyttelse: hvis varen ikke leveres eller ikke stemmer med annonsen får du pengene tilbake. Avgiften er 5 % av varens pris pluss 7,50 kr. Frakt er 35,65 kr."
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
                    .background(Color.black)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
        .background(Color(.systemBackground).ignoresSafeArea())
        .presentationDetents([.medium])
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
}
