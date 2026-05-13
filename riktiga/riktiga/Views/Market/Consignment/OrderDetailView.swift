import SwiftUI
import Combine
import Supabase
import CoreImage.CIFilterBuiltins
import UIKit

/// Full-page orderdetalj med Blocket-style tidslinje.
///
/// Visas både för köpare och säljare. Köparen får knappar för
/// "Godkänn varan" + "Anmäl problem" när paketet är levererat.
/// Säljaren får länk till fraktsedeln + nedräkning till
/// inlämningsdeadlinen.
struct OrderDetailView: View {
    let orderId: UUID
    let initialOrder: MarketplaceOrderRow?

    @EnvironmentObject var authViewModel: AuthViewModel
    @ObservedObject private var sellerStripe = SellerStripeService.shared
    @Environment(\.dismiss) private var dismiss

    @State private var order: MarketplaceOrderRow?
    @State private var listing: ConsignmentSubmissionRow?
    @State private var isLoading = false
    @State private var errorText: String?
    @State private var isApproving = false
    @State private var showDisputeSheet = false
    @State private var showApproveConfirm = false
    @State private var disputeReason = ""
    @State private var disputeError: String?
    @State private var isSubmittingDispute = false
    @State private var actionFeedback: String?
    @State private var showCancelConfirm = false
    @State private var isCancelling = false
    @State private var isOpeningLabel = false
    @State private var labelOpenError: String?
    @State private var isFetchingShipmondoLabel = false
    @State private var labelFetchError: String?
    @State private var showPrintAtAgent = false
    @State private var isRetryingShipping = false
    @State private var shippingRetryError: String?
    @State private var shippingRetrySuccess: String?
    @State private var showOwnerActions = false
    @State private var showDeleteConfirm = false
    @State private var showEditFlow = false
    @State private var isDeleting = false
    @State private var deleteError: String?
    @State private var nowTick = Date()
    @State private var showSellerBalanceSheet = false
    private let tickTimer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

    init(orderId: UUID, initialOrder: MarketplaceOrderRow? = nil) {
        self.orderId = orderId
        self.initialOrder = initialOrder
        _order = State(initialValue: initialOrder)
    }

    private var iAmBuyer: Bool {
        guard let me = authViewModel.currentUser?.id, let order else { return false }
        return order.buyerId.uuidString.lowercased() == String(describing: me).lowercased()
    }
    private var iAmSeller: Bool {
        guard let me = authViewModel.currentUser?.id, let order else { return false }
        return order.sellerId.uuidString.lowercased() == String(describing: me).lowercased()
    }

    var body: some View {
        ZStack(alignment: .top) {
            Color(.systemGroupedBackground).ignoresSafeArea()
            content
            customHeader
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .onAppear { NavigationDepthTracker.shared.acquireHideTabBar() }
        .onDisappear { NavigationDepthTracker.shared.releaseHideTabBar() }
        .task { await load() }
        .refreshable { await load(force: true) }
        .onReceive(tickTimer) { nowTick = $0 }
        .sheet(isPresented: $showDisputeSheet) { disputeSheet }
        .alert(
            L.t(sv: "Godkänn varan?", nb: "Godkjenn varen?"),
            isPresented: $showApproveConfirm
        ) {
            Button(L.t(sv: "Godkänn", nb: "Godkjenn"), role: .destructive) {
                Task { await approve() }
            }
            Button(L.t(sv: "Avbryt", nb: "Avbryt"), role: .cancel) { }
        } message: {
            Text(L.t(
                sv: "När du godkänner släpps pengarna direkt till säljaren. Detta går inte att ångra.",
                nb: "Når du godkjenner sendes pengene direkte til selger. Dette kan ikke angres."
            ))
        }
        .alert(
            L.t(sv: "Avboka köpet?", nb: "Avbestille kjøpet?"),
            isPresented: $showCancelConfirm
        ) {
            Button(L.t(sv: "Avboka", nb: "Avbestill"), role: .destructive) {
                Task { await cancelPurchase() }
            }
            Button(L.t(sv: "Behåll", nb: "Behold"), role: .cancel) { }
        } message: {
            Text(L.t(
                sv: "Hela beloppet återbetalas inom 5 bankdagar och annonsen blir åter publicerad. Detta går inte att ångra.",
                nb: "Hele beløpet refunderes innen 5 virkedager og annonsen publiseres igjen. Dette kan ikke angres."
            ))
        }
        .confirmationDialog(
            L.t(sv: "Välj åtgärd", nb: "Velg handling"),
            isPresented: $showOwnerActions,
            titleVisibility: .hidden
        ) {
            Button(L.t(sv: "Redigera", nb: "Rediger")) {
                showEditFlow = true
            }
            Button(L.t(sv: "Radera", nb: "Slett"), role: .destructive) {
                showDeleteConfirm = true
            }
            Button(L.t(sv: "Stäng", nb: "Lukk"), role: .cancel) {}
        }
        .confirmationDialog(
            L.t(sv: "Ta bort annonsen?", nb: "Slette annonsen?"),
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button(L.t(sv: "Radera", nb: "Slett"), role: .destructive) {
                performDeleteListing()
            }
            Button(L.t(sv: "Avbryt", nb: "Avbryt"), role: .cancel) {}
        } message: {
            Text(L.t(
                sv: "Det här går inte att ångra.",
                nb: "Dette kan ikke angres."
            ))
        }
        .alert(
            L.t(sv: "Kunde inte radera", nb: "Kunne ikke slette"),
            isPresented: Binding(
                get: { deleteError != nil },
                set: { if !$0 { deleteError = nil } }
            )
        ) {
            Button("OK", role: .cancel) { deleteError = nil }
        } message: {
            Text(deleteError ?? "")
        }
        .fullScreenCover(isPresented: $showEditFlow) {
            if let listing {
                SellFlowView(
                    editingRow: listing,
                    onAbandonFlow: {
                        showEditFlow = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                            NotificationCenter.default.post(
                                name: NSNotification.Name("NavigateToMyListings"),
                                object: nil
                            )
                        }
                        dismiss()
                    }
                )
                .environmentObject(authViewModel)
            }
        }
        .sheet(isPresented: $showPrintAtAgent) {
            if let order,
               let raw = order.effectiveQrPayloadForAgent {
                PrintAtAgentSheet(
                    qrPayload: raw,
                    carrier: order.shippingCarrier,
                    trackingNumber: order.shippingTrackingNumber
                )
            }
        }
        .sheet(isPresented: $showSellerBalanceSheet) {
            NavigationStack {
                SellerBalanceView()
                    .environmentObject(authViewModel)
            }
        }
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        if let order {
            ScrollView {
                VStack(spacing: 16) {
                    headerCard(order: order)
                    if iAmSeller, let countdown = shipByCountdownCard(order: order) {
                        countdown
                    }
                    if let banner = bannerInfo(order) {
                        bannerCard(banner)
                    }
                    if iAmSeller, showSellerShippingSection(order) {
                        sellerShippingLabelSection(order: order)
                    }
                    timelineCard(order: order)
                    actionButtons(order: order)
                    if iAmSeller, shouldShowManualShippingRetry(order) {
                        manualShippingRetryCard(order: order)
                    }
                    if order.shippingTrackingUrl != nil {
                        trackingCard(order: order)
                    }
                    deliveryAddressCard(order: order)
                    if iAmSeller {
                        sellerPayoutCard(order: order)
                    }
                    pricingCard(order: order)
                    if let feedback = actionFeedback {
                        Text(feedback)
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 18)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 76)
                .padding(.bottom, 40)
            }
        } else if isLoading {
            ProgressView().padding(.top, 120)
        } else if let errorText {
            VStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 38))
                    .foregroundColor(.orange)
                Text(errorText)
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Button(L.t(sv: "Försök igen", nb: "Prøv igjen")) {
                    Task { await load(force: true) }
                }
                .buttonStyle(.bordered)
            }
            .padding(.horizontal, 24)
            .padding(.top, 120)
        }
    }

    // MARK: - Header (custom — vi är gömda i toolbar)

    private var customHeader: some View {
        HStack(spacing: 12) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.primary)
                    .frame(width: 36, height: 36)
                    .background(.ultraThinMaterial, in: Circle())
            }
            Text(L.t(sv: "Order", nb: "Ordre"))
                .font(.system(size: 17, weight: .semibold))
            Spacer()
            if iAmSeller, listing != nil {
                Button {
                    showOwnerActions = true
                } label: {
                    ZStack {
                        if isDeleting {
                            ProgressView()
                                .progressViewStyle(.circular)
                                .tint(.primary)
                        } else {
                            Image(systemName: "ellipsis")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundColor(.primary)
                        }
                    }
                    .frame(width: 36, height: 36)
                    .background(.ultraThinMaterial, in: Circle())
                }
                .buttonStyle(.plain)
                .disabled(isDeleting)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    // MARK: - Header card

    private func headerCard(order: MarketplaceOrderRow) -> some View {
        let thumbUrl = listing?.imageUrls.first ?? order.listingImageUrl
        let resolvedTitle = [listing?.title, order.listingTitle]
            .compactMap { $0 }
            .first { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        let resolvedBrand = [listing?.userBrand, order.listingBrand]
            .compactMap { $0 }
            .first { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        return HStack(spacing: 14) {
            CachedRemoteImage(url: thumbUrl) {
                Color(.tertiarySystemFill)
            }
            .frame(width: 80, height: 80)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(resolvedTitle ?? L.t(sv: "Annons", nb: "Annonse"))
                    .font(.system(size: 15, weight: .semibold))
                    .lineLimit(2)
                if let brand = resolvedBrand {
                    Text(brand)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                Text(MarketplacePricing.formatSEK(Double(order.amountBuyerTotal) / 100.0))
                    .font(.system(size: 14, weight: .semibold))
                statusPill(order.shippingStatusLabel, color: pillColor(for: order))
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.primary.opacity(0.06), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.06), radius: 10, x: 0, y: 2)
    }

    private func statusPill(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(color.opacity(0.18))
            .foregroundStyle(color)
            .clipShape(Capsule())
    }

    private func pillColor(for order: MarketplaceOrderRow) -> Color {
        if order.disputeOpenedAt != nil { return .red }
        if order.status == "released" || order.buyerApprovedAt != nil { return .green }
        if order.shippingDeliveredAt != nil { return .orange }
        if order.status == "cancelled" || order.status == "refunded" { return .gray }
        return .blue
    }

    // MARK: - Banners (deadlines & action prompts)

    private struct BannerInfo {
        let title: String
        let subtitle: String
        let icon: String
        let tint: Color
    }

    private func bannerInfo(_ order: MarketplaceOrderRow) -> BannerInfo? {
        // Köparens 48h-fönster
        if iAmBuyer,
           order.shippingDeliveredAt != nil,
           order.buyerApprovedAt == nil,
           order.disputeOpenedAt == nil,
           let deadline = order.buyerApprovalDeadlineDate {
            let remaining = deadline.timeIntervalSince(nowTick)
            if remaining > 0 {
                return BannerInfo(
                    title: L.t(sv: "Godkänn varan inom \(Self.formatRemaining(remaining))",
                               nb: "Godkjenn varen innen \(Self.formatRemaining(remaining))"),
                    subtitle: L.t(
                        sv: "Pengarna släpps automatiskt om du inte gör något.",
                        nb: "Pengene slippes automatisk hvis du ikke gjør noe."
                    ),
                    icon: "checkmark.shield",
                    tint: .orange
                )
            }
        }

        // Säljarens 3-dagars inlämningsfönster
        if iAmSeller,
           order.shippedAt == nil,
           let deadline = order.shipByDeadlineDate {
            let remaining = deadline.timeIntervalSince(nowTick)
            if remaining > 0 {
                return BannerInfo(
                    title: L.t(sv: "Lämna in paketet inom \(Self.formatRemaining(remaining))",
                               nb: "Lever inn pakken innen \(Self.formatRemaining(remaining))"),
                    subtitle: L.t(
                        sv: "Annars cancelleras ordern och köparen återbetalas.",
                        nb: "Ellers kanselleres ordren og kjøper refunderes."
                    ),
                    icon: "shippingbox",
                    tint: .red
                )
            }
        }

        if order.disputeOpenedAt != nil {
            return BannerInfo(
                title: L.t(sv: "Anmälan mottagen", nb: "Anmeldelse mottatt"),
                subtitle: L.t(
                    sv: "Vår support hör av sig till båda parter inom kort.",
                    nb: "Vår support kontakter begge parter snart."
                ),
                icon: "exclamationmark.triangle",
                tint: .red
            )
        }

        if order.status == "released" || order.buyerApprovedAt != nil {
            return BannerInfo(
                title: L.t(sv: "Affären är avslutad", nb: "Handelen er avsluttet"),
                subtitle: L.t(
                    sv: "Tack för att du handlade på Up&Down!",
                    nb: "Takk for at du handlet på Up&Down!"
                ),
                icon: "checkmark.seal.fill",
                tint: .green
            )
        }

        if order.status == "cancelled" {
            let subtitle: String
            if order.autoCancelledAt != nil {
                subtitle = L.t(
                    sv: "Säljaren lämnade inte in paketet i tid. Du har fått pengarna återbetalade.",
                    nb: "Selger leverte ikke inn pakken i tide. Du har fått pengene tilbake."
                )
            } else {
                subtitle = L.t(
                    sv: "Pengarna har återbetalats.",
                    nb: "Pengene har blitt refundert."
                )
            }
            return BannerInfo(
                title: L.t(sv: "Ordern är avbruten", nb: "Ordren er avbrutt"),
                subtitle: subtitle,
                icon: "xmark.octagon",
                tint: .gray
            )
        }

        if order.status == "refunded" {
            return BannerInfo(
                title: L.t(sv: "Återbetald", nb: "Refundert"),
                subtitle: L.t(
                    sv: "Beloppet har återförts till ditt kort.",
                    nb: "Beløpet er tilbakeført til kortet ditt."
                ),
                icon: "arrow.uturn.backward.circle",
                tint: .gray
            )
        }

        return nil
    }

    private func bannerCard(_ banner: BannerInfo) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: banner.icon)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(banner.tint)
            VStack(alignment: .leading, spacing: 4) {
                Text(banner.title)
                    .font(.system(size: 14, weight: .semibold))
                Text(banner.subtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(banner.tint.opacity(0.10))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(banner.tint.opacity(0.25), lineWidth: 1)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.primary.opacity(0.06), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .shadow(color: Color.black.opacity(0.06), radius: 10, x: 0, y: 2)
    }

    private func shipByCountdownCard(order: MarketplaceOrderRow) -> AnyView? {
        guard order.shippedAt == nil, let deadline = order.shipByDeadlineDate else { return nil }
        let remaining = deadline.timeIntervalSince(nowTick)
        guard remaining > 0 else { return nil }

        return AnyView(
            VStack(spacing: 8) {
                Text(L.t(sv: "Dags att skicka", nb: "På tide å sende"))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)
                TimelineView(.periodic(from: .now, by: 60)) { context in
                    let rem = deadline.timeIntervalSince(context.date)
                    let urgent = rem < 24 * 60 * 60
                    Text(rem > 0 ? Self.formatRemaining(rem) : L.t(sv: "Tiden har gått ut", nb: "Tiden er ute"))
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(urgent ? Color.red : Color.primary)
                }
                Text(L.t(
                    sv: "Lämna in paketet innan tiden går ut, annars återbetalas köpet automatiskt.",
                    nb: "Lever inn pakken før tiden går ut, ellers refunderes kjøpet automatisk."
                ))
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            }
            .padding(14)
            .frame(maxWidth: .infinity)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.primary.opacity(0.06), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.06), radius: 10, x: 0, y: 2)
        )
    }

    // MARK: - Timeline

    private func timelineCard(order: MarketplaceOrderRow) -> some View {
        let steps = TimelineStep.allFor(order: order)
        return VStack(alignment: .leading, spacing: 0) {
            Text(L.t(sv: "Status", nb: "Status"))
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
                .padding(.bottom, 12)

            ForEach(Array(steps.enumerated()), id: \.offset) { idx, step in
                timelineRow(step: step, isLast: idx == steps.count - 1)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.primary.opacity(0.06), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.06), radius: 10, x: 0, y: 2)
    }

    private func timelineRow(step: TimelineStep, isLast: Bool) -> some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(spacing: 0) {
                ZStack {
                    Circle()
                        .fill(step.state.dotColor.opacity(step.state == .done ? 1 : 0.25))
                        .frame(width: 22, height: 22)
                    if step.state == .done {
                        Image(systemName: "checkmark")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.white)
                    } else if step.state == .current {
                        Circle()
                            .fill(step.state.dotColor)
                            .frame(width: 8, height: 8)
                    }
                }
                if !isLast {
                    Rectangle()
                        .fill(Color.primary.opacity(0.10))
                        .frame(width: 2)
                        .frame(maxHeight: .infinity)
                }
            }
            .frame(width: 22)

            VStack(alignment: .leading, spacing: 2) {
                Text(step.title)
                    .font(.system(size: 14, weight: step.state == .current ? .semibold : .regular))
                    .foregroundColor(step.state == .pending ? .secondary : .primary)
                if let sub = step.subtitle, !sub.isEmpty {
                    Text(sub)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.bottom, isLast ? 0 : 14)
            Spacer(minLength: 0)
        }
    }

    // MARK: - Actions

    @ViewBuilder
    private func actionButtons(order: MarketplaceOrderRow) -> some View {
        if iAmBuyer {
            VStack(spacing: 10) {
                if order.canBuyerApprove {
                    Button {
                        showApproveConfirm = true
                    } label: {
                        HStack {
                            Image(systemName: "checkmark.seal.fill")
                            Text(L.t(sv: "Godkänn varan", nb: "Godkjenn varen"))
                                .font(.system(size: 16, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.black)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .disabled(isApproving)
                }
                if order.canBuyerDispute {
                    Button {
                        showDisputeSheet = true
                    } label: {
                        HStack {
                            Image(systemName: "exclamationmark.bubble")
                            Text(L.t(sv: "Anmäl problem", nb: "Anmeld problem"))
                                .font(.system(size: 15, weight: .semibold))
                        }
                        .foregroundColor(.red)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .background(Color.red.opacity(0.10))
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                }
                if order.canBuyerCancel {
                    Button {
                        showCancelConfirm = true
                    } label: {
                        HStack {
                            Image(systemName: "xmark.circle")
                            Text(L.t(sv: "Avboka köpet", nb: "Avbestille kjøpet"))
                                .font(.system(size: 15, weight: .semibold))
                        }
                        .foregroundColor(.primary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .background(Color(.tertiarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .disabled(isCancelling)
                }
                if isApproving || isCancelling {
                    ProgressView().padding(.top, 4)
                }
            }
        }
    }

    private func cancelPurchase() async {
        guard let id = order?.id else { return }
        isCancelling = true
        defer { isCancelling = false }
        do {
            _ = try await MarketplaceOrdersService.shared.cancelOrder(orderId: id)
            actionFeedback = L.t(
                sv: "Köpet är avbokat — pengarna återbetalas inom 5 bankdagar.",
                nb: "Kjøpet er avbestilt — pengene refunderes innen 5 virkedager."
            )
            await load(force: true)
        } catch {
            actionFeedback = error.localizedDescription
        }
    }

    private func performDeleteListing() {
        guard let userId = authViewModel.currentUser?.id,
              let row = listing else {
            deleteError = L.t(sv: "Du måste vara inloggad.", nb: "Du må være innlogget.")
            return
        }
        isDeleting = true
        let rowId = row.id
        let urls = row.imageUrls
        Task {
            defer { Task { @MainActor in isDeleting = false } }
            do {
                try await ConsignmentSubmissionService.shared.delete(
                    userId: userId,
                    rowId: rowId,
                    imageUrls: urls,
                    asAdmin: false
                )
                await MainActor.run {
                    NotificationCenter.default.post(
                        name: NSNotification.Name("NavigateToMyListings"),
                        object: nil
                    )
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    deleteError = error.localizedDescription
                }
            }
        }
    }

    // MARK: - Cards

    private func shouldShowManualShippingRetry(_ order: MarketplaceOrderRow) -> Bool {
        guard iAmSeller else { return false }
        guard order.shippingStatus == "manual" else { return false }
        if let sid = order.shipmondoShipmentId, !sid.isEmpty { return false }
        return true
    }

    private func manualShippingRetryCard(order: MarketplaceOrderRow) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(
                L.t(sv: "Automatisk frakt misslyckades", nb: "Automatisk frakt mislyktes"),
                systemImage: "exclamationmark.triangle.fill"
            )
            .font(.system(size: 14, weight: .semibold))
            Text(L.t(
                sv: "När din upphämtningsadress är sparad kan du försöka skapa fraktsedeln igen. Kontrollera även Inställningar → Upphämtningsadress för frakt.",
                nb: "Når henteadressen er lagret kan du prøve å lage fraktseddel på nytt."
            ))
            .font(.system(size: 12))
            .foregroundStyle(.secondary)

            if let shippingRetryError {
                Text(shippingRetryError)
                    .font(.system(size: 12))
                    .foregroundStyle(.red)
            }
            if let shippingRetrySuccess {
                Text(shippingRetrySuccess)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }

            Button {
                Task { await retryBookShipping(orderId: order.id) }
            } label: {
                HStack {
                    if isRetryingShipping {
                        ProgressView().tint(.white)
                    }
                    Text(L.t(sv: "Försök boka frakt igen", nb: "Prøv å booke frakt igjen"))
                        .font(.system(size: 14, weight: .semibold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.black)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .disabled(isRetryingShipping)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.primary.opacity(0.06), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.06), radius: 10, x: 0, y: 2)
    }

    private func retryBookShipping(orderId: UUID) async {
        shippingRetryError = nil
        shippingRetrySuccess = nil
        isRetryingShipping = true
        defer { isRetryingShipping = false }
        do {
            try await MarketplaceOrdersService.shared.retryBookMarketplaceShipping(orderId: orderId)
            shippingRetrySuccess = L.t(
                sv: "Frakt bokad — uppdaterar…",
                nb: "Frakt booket — oppdaterer…"
            )
            await load(force: true)
        } catch {
            shippingRetryError = error.localizedDescription
        }
    }

    private func showSellerShippingSection(_ order: MarketplaceOrderRow) -> Bool {
        if let sm = order.shipmondoShipmentId, !sm.isEmpty { return true }
        if let u = order.shippingLabelUrl, !u.isEmpty { return true }
        if order.effectiveQrPayloadForAgent != nil { return true }
        if order.shippedAt != nil { return false }
        if order.status == "succeeded" { return true }
        if order.status == "held_awaiting_seller" { return true }
        return false
    }

    private func sellerPayoutCard(order: MarketplaceOrderRow) -> some View {
        let stripeReady = sellerStripe.status.isFullyActive
        let title: String
        let subtitle: String
        if order.releasedAt != nil {
            title = L.t(sv: "Utbetald", nb: "Utbetalt")
            subtitle = L.t(
                sv: "Pengarna har skickats till ditt Stripe-konto.",
                nb: "Pengene er sendt til Stripe-kontoen din."
            )
        } else if order.buyerApprovedAt != nil && order.releasedAt == nil {
            if stripeReady {
                title = L.t(sv: "Pengarna är på väg till ditt Stripe-konto", nb: "Pengene er på vei til Stripe-kontoen din")
                subtitle = L.t(
                    sv: "Utbetalning sker normalt inom några bankdagar.",
                    nb: "Utbetaling skjer vanligvis innen noen bankdager."
                )
            } else {
                title = L.t(sv: "Utbetalning väntar på Stripe", nb: "Utbetaling venter på Stripe")
                subtitle = L.t(
                    sv: "Köparen har godkänt — slutför Stripe-koppling under Saldo & utbetalningar så flyttar vi pengarna till ditt konto.",
                    nb: "Kjøperen har godkjent — fullfør Stripe-kobling under Saldo og utbetalinger så flytter vi pengene til kontoen din."
                )
            }
        } else if order.shippingDeliveredAt != nil, order.buyerApprovedAt == nil {
            title = L.t(sv: "Köparen har mottagit paketet", nb: "Kjøper har mottatt pakken")
            let base: String = {
                if let deadline = order.buyerApprovalDeadlineDate {
                    let remaining = deadline.timeIntervalSince(nowTick)
                    if remaining > 0 {
                        let fmt = Self.formatPayoutReleaseRemaining(remaining)
                        return L.t(
                            sv: "Frigörs automatiskt om \(fmt) om köparen inte anmäler problem.",
                            nb: "Frigjøres automatisk om \(fmt) om kjøperen ikke melder fra om problem."
                        )
                    }
                    return L.t(
                        sv: "Frigörs automatiskt om köparen inte anmäler problem.",
                        nb: "Frigjøres automatisk om kjøperen ikke melder fra om problem."
                    )
                }
                return L.t(
                    sv: "Frigörs automatiskt inom 48 h om köparen inte anmäler problem.",
                    nb: "Frigjøres automatisk innen 48 t om kjøperen ikke melder fra om problem."
                )
            }()
            if stripeReady {
                subtitle = base
            } else {
                subtitle = base + " " + L.t(
                    sv: "Du måste slutföra Stripe-koppling för att ta emot utbetalningen.",
                    nb: "Du må fullføre Stripe-kobling for å motta utbetalingen."
                )
            }
        } else if order.status == "succeeded" {
            title = L.t(sv: "Pengarna reserveras hos UP&DOWN", nb: "Pengene reserveres hos UP&DOWN")
            let core = L.t(
                sv: "Du får betalt när köparen mottagit varan. UP&DOWN skyddar köpare och säljare.",
                nb: "Du får betalt når kjøperen har mottatt varen. UP&DOWN beskytter kjøper og selger."
            )
            if stripeReady {
                subtitle = core
            } else {
                subtitle = core + " " + L.t(
                    sv: "Koppla Stripe under Saldo & utbetalningar så vi kan överföra pengarna till dig i tid.",
                    nb: "Koble Stripe under Saldo og utbetalinger så vi kan overføre pengene til deg i tide."
                )
            }
        } else {
            title = L.t(sv: "Utbetalning", nb: "Utbetaling")
            subtitle = order.payoutStatusLabel
        }

        return VStack(alignment: .leading, spacing: 8) {
            Label(L.t(sv: "Utbetalning", nb: "Utbetaling"), systemImage: "banknote")
                .font(.system(size: 14, weight: .semibold))
            Text(title)
                .font(.system(size: 15, weight: .bold))
            Text(subtitle)
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if iAmSeller, !stripeReady {
                Button {
                    showSellerBalanceSheet = true
                } label: {
                    Text(L.t(sv: "Öppna Saldo & utbetalningar", nb: "Åpne Saldo og utbetalinger"))
                        .font(.system(size: 14, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color.black)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .buttonStyle(.plain)
                .padding(.top, 4)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.primary.opacity(0.06), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.06), radius: 10, x: 0, y: 2)
    }

    private static func formatPayoutReleaseRemaining(_ seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds))
        let hours = total / 3_600
        let minutes = (total % 3_600) / 60
        if hours >= 24 {
            let days = hours / 24
            let remH = hours % 24
            return remH > 0 ? "\(days) d \(remH) tim" : "\(days) d"
        }
        if hours >= 1 { return "\(hours) tim \(minutes) min" }
        return "\(max(1, minutes)) min"
    }

    private func sellerShippingLabelSection(order: MarketplaceOrderRow) -> some View {
        let stored = order.shippingLabelUrl?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let hasLabel = !stored.isEmpty
        let hasShipmondo = order.shipmondoShipmentId.map { !$0.isEmpty } ?? false
        let qrSource = order.effectiveQrPayloadForAgent

        return VStack(alignment: .leading, spacing: 12) {
            Label(
                L.t(sv: "Fraktsedel", nb: "Fraktseddel"),
                systemImage: "qrcode.viewfinder"
            )
            .font(.system(size: 15, weight: .bold))

            Text(L.t(
                sv: "Visa eller skriv ut fraktsedeln innan du lämnar in paketet.",
                nb: "Vis eller skriv ut fraktseddelen før du leverer inn pakken."
            ))
            .font(.system(size: 12))
            .foregroundStyle(.secondary)

            Text(L.t(
                sv: "Status uppdateras automatiskt när ombudet skannat paketet (Shipmondo).",
                nb: "Status oppdateres automatisk når utleveringsstedet har skannet pakken (Shipmondo)."
            ))
            .font(.system(size: 11))
            .foregroundStyle(.secondary)

            if let qrSource, let qrImage = orderDetailQrCode(from: qrSource) {
                Image(uiImage: qrImage)
                    .interpolation(.none)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 200, height: 200)
                    .padding(8)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .frame(maxWidth: .infinity)
            }

            if let nr = order.shippingTrackingNumber, !nr.isEmpty {
                HStack {
                    Text(L.t(sv: "Spårnummer", nb: "Sporingsnummer"))
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(nr)
                        .font(.system(size: 13, weight: .semibold, design: .monospaced))
                }
            }

            if let labelFetchError {
                Text(labelFetchError)
                    .font(.system(size: 12))
                    .foregroundStyle(.red)
            }
            if let labelOpenError {
                Text(labelOpenError)
                    .font(.system(size: 12))
                    .foregroundStyle(.red)
            }

            if order.effectiveQrPayloadForAgent != nil {
                Button {
                    showPrintAtAgent = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "printer")
                        Text(L.t(sv: "Skriv ut på ombud", nb: "Skriv ut hos ombud"))
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundColor(.primary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Color.black.opacity(0.18), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }

            if hasLabel {
                Button {
                    Task { await openSellerLabel(order: order, storedPath: stored) }
                } label: {
                    HStack(spacing: 8) {
                        if isOpeningLabel {
                            ProgressView().tint(.white)
                        }
                        Image(systemName: "qrcode.viewfinder")
                        Text(L.t(sv: "Visa fraktsedel", nb: "Vis fraktseddel"))
                            .font(.system(size: 16, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.black)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(isOpeningLabel || isFetchingShipmondoLabel)
            } else if hasShipmondo {
                Button {
                    Task { await fetchShipmondoLabel(orderId: order.id) }
                } label: {
                    HStack(spacing: 8) {
                        if isFetchingShipmondoLabel {
                            ProgressView().tint(.white)
                        }
                        Image(systemName: "arrow.down.doc")
                        Text(L.t(sv: "Hämta fraktsedel", nb: "Hent fraktseddel"))
                            .font(.system(size: 16, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.black)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(isFetchingShipmondoLabel || isOpeningLabel)
            } else if !hasLabel, !hasShipmondo, order.effectiveQrPayloadForAgent == nil,
                      order.shippedAt == nil,
                      order.status == "succeeded" || order.status == "held_awaiting_seller" {
                Text(L.t(
                    sv: "Fraktsedel och QR visas här när frakten är bokad. Drag nedåt för att uppdatera.",
                    nb: "Fraktseddel og QR vises her når frakten er booket. Dra ned for å oppdatere."
                ))
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            }

            if let urlStr = order.shippingTrackingUrl, let url = URL(string: urlStr) {
                Link(destination: url) {
                    HStack {
                        Text(L.t(sv: "Spåra paketet", nb: "Spor pakken"))
                            .font(.system(size: 14, weight: .semibold))
                        Spacer()
                        Image(systemName: "arrow.up.right")
                    }
                    .foregroundColor(.primary)
                    .padding(.vertical, 12)
                    .padding(.horizontal, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Color.black.opacity(0.15), lineWidth: 1)
                    )
                }
            }

            Text(L.t(
                sv: "Du får betalt när köparen mottagit varan. UP&DOWN skyddar köpare och säljare.",
                nb: "Du får betalt når kjøperen har mottatt varen. UP&DOWN beskytter kjøper og selger."
            ))
            .font(.system(size: 12))
            .foregroundStyle(.secondary)
            .padding(.top, 4)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.primary.opacity(0.06), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.06), radius: 10, x: 0, y: 2)
    }

    private func orderDetailQrCode(from payload: String) -> UIImage? {
        let context = CIContext()
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(payload.utf8)
        filter.correctionLevel = "M"
        guard let output = filter.outputImage else { return nil }
        let scaled = output.transformed(by: CGAffineTransform(scaleX: 8, y: 8))
        guard let cg = context.createCGImage(scaled, from: scaled.extent) else { return nil }
        return UIImage(cgImage: cg)
    }

    private func fetchShipmondoLabel(orderId: UUID) async {
        labelFetchError = nil
        isFetchingShipmondoLabel = true
        defer { isFetchingShipmondoLabel = false }
        do {
            _ = try await MarketplaceOrdersService.shared.refreshShipmondoLabel(orderId: orderId)
            await load(force: true)
            guard let o = order else { return }
            let path = o.shippingLabelUrl?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if !path.isEmpty {
                await openSellerLabel(order: o, storedPath: path)
            } else if o.effectiveQrPayloadForAgent != nil {
                showPrintAtAgent = true
            }
        } catch {
            labelFetchError = error.localizedDescription
        }
    }

    private func openSellerLabel(order: MarketplaceOrderRow, storedPath: String) async {
        labelOpenError = nil
        isOpeningLabel = true
        defer { isOpeningLabel = false }
        do {
            let urlToOpen: URL
            if storedPath.hasPrefix("http"), let direct = URL(string: storedPath) {
                urlToOpen = direct
            } else {
                urlToOpen = try await ShippingLabelService.shared.signedUrlForMarketplaceOrderLabel(
                    orderId: order.id,
                    sellerId: order.sellerId,
                    storedPath: storedPath
                )
            }
            await UIApplication.shared.open(urlToOpen)
        } catch {
            labelOpenError = error.localizedDescription
        }
    }

    private func trackingCard(order: MarketplaceOrderRow) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(L.t(sv: "Spårning", nb: "Sporing"), systemImage: "shippingbox.fill")
                .font(.system(size: 14, weight: .semibold))
            if let nr = order.shippingTrackingNumber {
                HStack {
                    Text(L.t(sv: "Spårnummer", nb: "Sporingsnummer"))
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(nr).font(.system(size: 13, design: .monospaced))
                }
            }
            if let urlStr = order.shippingTrackingUrl, let url = URL(string: urlStr) {
                Link(destination: url) {
                    HStack {
                        Text(L.t(sv: "Spåra paketet", nb: "Spor pakken"))
                        Spacer()
                        Image(systemName: "arrow.up.right")
                    }
                    .font(.system(size: 14, weight: .medium))
                    .padding(12)
                    .background(Color(.tertiarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.primary.opacity(0.06), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.06), radius: 10, x: 0, y: 2)
    }

    private func deliveryAddressCard(order: MarketplaceOrderRow) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(L.t(sv: "Levereras till", nb: "Leveres til"))
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
            if let name = order.buyerShippingName { Text(name).font(.system(size: 13, weight: .semibold)) }
            if let street = order.buyerShippingAddress { Text(street).font(.system(size: 13)) }
            if let p = order.buyerShippingPostal, let c = order.buyerShippingCity {
                Text("\(p) \(c)").font(.system(size: 13))
            }
            if let sp = order.shippingServicePointName, !sp.isEmpty {
                Divider().padding(.vertical, 4)
                Label(L.t(sv: "Hämtas hos ombud", nb: "Hentes hos utleveringssted"),
                      systemImage: "mappin.and.ellipse")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                Text(sp).font(.system(size: 13, weight: .semibold))
                if let addr = order.shippingServicePointAddress, !addr.isEmpty {
                    Text(addr).font(.system(size: 12)).foregroundStyle(.secondary)
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func pricingCard(order: MarketplaceOrderRow) -> some View {
        VStack(spacing: 8) {
            row(L.t(sv: "Vara", nb: "Vare"), value: Double(order.amountItem) / 100.0)
            if let shipping = order.amountShipping, shipping > 0 {
                row(L.t(sv: "Frakt", nb: "Frakt"),
                    value: Double(shipping) / 100.0)
            }
            row(L.t(sv: "Köparskydd & avgift", nb: "Kjøperbeskyttelse & avgift"),
                value: Double(order.amountPlatformFee) / 100.0)
            Divider()
            row(L.t(sv: "Totalt", nb: "Totalt"),
                value: Double(order.amountBuyerTotal) / 100.0,
                bold: true)
        }
        .padding(14)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func row(_ title: String, value: Double, bold: Bool = false) -> some View {
        HStack {
            Text(title).font(.system(size: 13))
            Spacer()
            Text(MarketplacePricing.formatSEK(value))
                .font(.system(size: 13, weight: bold ? .bold : .regular))
        }
    }

    // MARK: - Dispute sheet

    private var disputeSheet: some View {
        NavigationStack {
            Form {
                Section {
                    Text(L.t(
                        sv: "Beskriv kort vad som är fel med varan eller leveransen. Vår support tittar manuellt på varje anmälan och hör av sig inom 24 h.",
                        nb: "Beskriv kort hva som er feil med varen eller leveransen. Vår support gjennomgår hver anmeldelse og hører fra seg innen 24 t."
                    ))
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                } header: {
                    Text(L.t(sv: "Vad är problemet?", nb: "Hva er problemet?"))
                }
                Section {
                    TextField(
                        L.t(sv: "Beskriv problemet (minst 5 tecken)",
                            nb: "Beskriv problemet (minst 5 tegn)"),
                        text: $disputeReason,
                        axis: .vertical
                    )
                    .lineLimit(3...8)
                }
                if let disputeError {
                    Section {
                        Text(disputeError).foregroundColor(.red).font(.system(size: 13))
                    }
                }
                Section {
                    Button {
                        Task { await openDispute() }
                    } label: {
                        HStack {
                            Spacer()
                            if isSubmittingDispute {
                                ProgressView().tint(.white)
                            } else {
                                Text(L.t(sv: "Skicka anmälan", nb: "Send anmeldelse"))
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.white)
                            }
                            Spacer()
                        }
                        .padding(.vertical, 6)
                    }
                    .listRowBackground(disputeReason.trimmingCharacters(in: .whitespaces).count >= 5 ? Color.red : Color.gray.opacity(0.4))
                    .disabled(disputeReason.trimmingCharacters(in: .whitespaces).count < 5 || isSubmittingDispute)
                }
            }
            .navigationTitle(L.t(sv: "Anmäl problem", nb: "Anmeld problem"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L.t(sv: "Avbryt", nb: "Avbryt")) { showDisputeSheet = false }
                }
            }
        }
        .presentationDetents([.large, .medium])
    }

    // MARK: - Networking

    private func load(force: Bool = false) async {
        if order != nil && !force {
            await refreshSellerStripeIfSeller()
            return
        }
        isLoading = true
        defer { isLoading = false }
        do {
            let fresh = try await MarketplaceOrdersService.shared.fetchOrder(id: orderId)
            order = fresh
            errorText = nil
            // Annonsen kan vara raderad (`listing_id = nil`); då hoppar vi över
            // listinghämtningen och visar order-snapshot direkt.
            if let lid = fresh.listingId {
                await loadListing(id: lid)
            }
            await refreshSellerStripeIfSeller()
        } catch {
            errorText = error.localizedDescription
        }
    }

    private func refreshSellerStripeIfSeller() async {
        guard let uidStr = authViewModel.currentUser?.id,
              let uid = UUID(uuidString: uidStr),
              let o = order,
              o.sellerId == uid else { return }
        await sellerStripe.refresh(userId: uidStr)
    }

    private func loadListing(id: UUID) async {
        do {
            let row: ConsignmentSubmissionRow = try await SupabaseConfig.supabase
                .from("consignment_submissions")
                .select()
                .eq("id", value: id.uuidString)
                .single()
                .execute()
                .value
            listing = row
            ImageCacheManager.shared.prefetch(urls: row.imageUrls)
        } catch {
            // Annonsen kan vara borttagen — det är OK, vi har ändå order-info.
            print("OrderDetailView.loadListing failed: \(error)")
        }
    }

    private func approve() async {
        guard let order else { return }
        isApproving = true
        defer { isApproving = false }
        do {
            let result = try await MarketplaceOrdersService.shared.approveOrder(orderId: order.id)
            actionFeedback = result.releasePending
                ? L.t(sv: "Godkänt! Säljaren får sina pengar när Stripe-onboardingen är klar.",
                      nb: "Godkjent! Selger får pengene sine når Stripe-onboarding er klar.")
                : L.t(sv: "Tack! Pengarna har skickats till säljaren.",
                      nb: "Takk! Pengene har blitt sendt til selger.")
            await load(force: true)
        } catch {
            actionFeedback = error.localizedDescription
        }
    }

    private func openDispute() async {
        guard let order else { return }
        let trimmed = disputeReason.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 5 else {
            disputeError = L.t(sv: "Skriv minst 5 tecken", nb: "Skriv minst 5 tegn")
            return
        }
        isSubmittingDispute = true
        defer { isSubmittingDispute = false }
        do {
            _ = try await MarketplaceOrdersService.shared.disputeOrder(
                orderId: order.id,
                reason: trimmed
            )
            showDisputeSheet = false
            disputeReason = ""
            disputeError = nil
            actionFeedback = L.t(
                sv: "Anmälan skickad. Vi hör av oss inom 24 h.",
                nb: "Anmeldelsen er sendt. Vi hører fra oss innen 24 t."
            )
            await load(force: true)
        } catch {
            disputeError = error.localizedDescription
        }
    }

    // MARK: - Helpers

    private static func formatRemaining(_ seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds))
        let days = total / 86_400
        let hours = (total % 86_400) / 3_600
        let minutes = (total % 3_600) / 60
        if days > 0 {
            if hours > 0 {
                return "\(days)d \(hours)h"
            }
            return "\(days)d"
        }
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }
}

// MARK: - Timeline model

private struct TimelineStep {
    enum State { case done, current, pending
        var dotColor: Color {
            switch self {
            case .done:    return .green
            case .current: return .blue
            case .pending: return .gray
            }
        }
    }

    let title: String
    let subtitle: String?
    let state: State

    static func allFor(order: MarketplaceOrderRow) -> [TimelineStep] {
        let isCancelled = order.status == "cancelled" || order.status == "refunded"
        if isCancelled {
            return [
                TimelineStep(
                    title: L.t(sv: "Betald", nb: "Betalt"),
                    subtitle: order.createdAtDate.map { Self.shortDate($0) },
                    state: .done
                ),
                TimelineStep(
                    title: L.t(sv: "Avbruten", nb: "Avbrutt"),
                    subtitle: order.autoCancelledAtDate.map { Self.shortDate($0) },
                    state: .done
                ),
            ]
        }

        // Tvist pausar tidslinjen vid "Anmäld" — visa hela vägen fram
        // till leverans men byt sista noden mot dispute-noden istället
        // för "Godkänd av köpare".
        if order.disputeOpenedAt != nil {
            return [
                TimelineStep(
                    title: L.t(sv: "Betald", nb: "Betalt"),
                    subtitle: order.createdAtDate.map { Self.shortDate($0) },
                    state: .done
                ),
                TimelineStep(
                    title: L.t(sv: "Inlämnad hos ombud", nb: "Levert hos utleveringssted"),
                    subtitle: order.shippedAtDate.map { Self.shortDate($0) },
                    state: order.shippedAt != nil ? .done : .pending
                ),
                TimelineStep(
                    title: L.t(sv: "Levererad", nb: "Levert"),
                    subtitle: order.shippingDeliveredAtDate.map { Self.shortDate($0) },
                    state: order.shippingDeliveredAt != nil ? .done : .pending
                ),
                TimelineStep(
                    title: L.t(sv: "Anmäld – under granskning", nb: "Anmeldt – under behandling"),
                    subtitle: order.disputeOpenedAtDate.map { Self.shortDate($0) },
                    state: .current
                ),
            ]
        }

        let paid = order.status == "succeeded" || order.status == "released" ||
                   order.status == "disputed"
        let ss = order.shippingStatus ?? ""
        let labelReady = ss == "label_ready" ||
                         ss == "picked_up" ||
                         ss == "in_transit" ||
                         ss == "arrived_servicepoint" ||
                         ss == "delivered" ||
                         order.shippedAt != nil ||
                         order.shippingDeliveredAt != nil
        let droppedAtOmbud = order.shippedAt != nil ||
                             ss == "picked_up" ||
                             ss == "in_transit" ||
                             ss == "arrived_servicepoint" ||
                             ss == "delivered" ||
                             order.shippingDeliveredAt != nil
        let onTheWay = ss == "in_transit" ||
                       ss == "arrived_servicepoint" ||
                       ss == "delivered" ||
                       order.shippingDeliveredAt != nil
        let atRecipientServicePoint = ss == "arrived_servicepoint" ||
                                       order.shippingDeliveredAt != nil
        let delivered = order.shippingDeliveredAt != nil
        let approved = order.buyerApprovedAt != nil || order.status == "released"

        func st(_ done: Bool, currentWhen: Bool) -> State {
            if done { return .done }
            if currentWhen { return .current }
            return .pending
        }

        return [
            TimelineStep(
                title: L.t(sv: "Betald", nb: "Betalt"),
                subtitle: order.createdAtDate.map { Self.shortDate($0) },
                state: st(paid, currentWhen: !paid)
            ),
            TimelineStep(
                title: L.t(sv: "Fraktsedel skapad", nb: "Fraktseddel opprettet"),
                subtitle: nil,
                state: st(labelReady, currentWhen: paid && !labelReady)
            ),
            TimelineStep(
                title: L.t(sv: "Inlämnad hos ombud", nb: "Levert hos utleveringssted"),
                subtitle: order.shippedAtDate.map { Self.shortDate($0) },
                state: st(droppedAtOmbud, currentWhen: labelReady && !droppedAtOmbud)
            ),
            TimelineStep(
                title: L.t(sv: "På väg", nb: "På vei"),
                subtitle: nil,
                state: st(onTheWay, currentWhen: droppedAtOmbud && !onTheWay)
            ),
            TimelineStep(
                title: L.t(sv: "Framme hos mottagarombud", nb: "Framme hos henteombud"),
                subtitle: nil,
                state: st(atRecipientServicePoint, currentWhen: onTheWay && !atRecipientServicePoint)
            ),
            TimelineStep(
                title: L.t(sv: "Levererad", nb: "Levert"),
                subtitle: order.shippingDeliveredAtDate.map { Self.shortDate($0) },
                state: st(delivered, currentWhen: atRecipientServicePoint && !delivered)
            ),
            TimelineStep(
                title: L.t(sv: "Godkänd av köpare", nb: "Godkjent av kjøper"),
                subtitle: order.buyerApprovedAtDate.map { Self.shortDate($0) },
                state: st(approved, currentWhen: delivered && !approved)
            ),
        ]
    }

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "sv_SE")
        f.dateFormat = "d MMM HH:mm"
        return f
    }()

    static func shortDate(_ date: Date) -> String {
        dateFormatter.string(from: date)
    }
}
