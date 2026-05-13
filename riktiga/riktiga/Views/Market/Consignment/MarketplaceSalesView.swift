import SwiftUI
import Combine
import Supabase
import UIKit

/// "Mina försäljningar" — orders där den inloggade användaren är säljare.
/// Visar inlämnings-deadline för paket som inte skickats än, samt
/// pushar `OrderDetailView` när man trycker på en rad.
struct MarketplaceSalesView: View {
    /// Inbäddad utan egen `NavigationStack` när föräldern redan har `NavigationStack`.
    var embedInParentNavigation: Bool = false

    @EnvironmentObject var authViewModel: AuthViewModel

    @State private var orders: [MarketplaceOrderRow] = []
    @State private var listings: [UUID: ConsignmentSubmissionRow] = [:]
    @State private var isLoading = false
    @State private var errorText: String?
    @State private var nowTick = Date()
    @State private var path: [MarketplaceRoute] = []
    @State private var triggerNotificationPrompt = false
    @State private var salesListLabelFetchOrderId: UUID?
    @State private var qrSheetOrder: MarketplaceOrderRow?

    private let tickTimer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

    var body: some View {
        Group {
            if embedInParentNavigation {
                salesContent
            } else {
                NavigationStack(path: $path) {
                    salesContent
                        .navigationTitle(L.t(sv: "Mina försäljningar", nb: "Mine salg"))
                        .navigationBarTitleDisplayMode(.inline)
                }
                .onReceive(tickTimer) { nowTick = $0 }
                .marketplaceDestinations()
                .notificationPrompt(for: .firstOpenList, trigger: $triggerNotificationPrompt)
            }
        }
        .sheet(item: $qrSheetOrder) { row in
            if let raw = row.effectiveQrPayloadForAgent {
                PrintAtAgentSheet(
                    qrPayload: raw,
                    carrier: row.shippingCarrier,
                    trackingNumber: row.shippingTrackingNumber
                )
            }
        }
    }

    private var salesContent: some View {
        ScrollView {
            VStack(spacing: 14) {
                if let errorText {
                    Text(errorText)
                        .font(.system(size: 13))
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                }
                if isLoading && orders.isEmpty {
                    ProgressView().padding(.top, 60)
                } else if orders.isEmpty {
                    emptyState
                } else {
                    ForEach(orders) { order in
                        saleRow(order: order)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 32)
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .refreshable { await load() }
        .task { await load() }
        .onReceive(tickTimer) { nowTick = $0 }
    }

    // MARK: - Load

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let fetched = try await MarketplaceOrdersService.shared.fetchMySales()
            orders = fetched
            errorText = nil
            await loadListings(for: fetched)
            if !fetched.isEmpty {
                triggerNotificationPrompt = true
            }
        } catch {
            errorText = error.localizedDescription
        }
    }

    private func loadListings(for orders: [MarketplaceOrderRow]) async {
        let ids = orders.compactMap { $0.listingId?.uuidString }
        guard !ids.isEmpty else { return }
        do {
            let rows: [ConsignmentSubmissionRow] = try await SupabaseConfig.supabase
                .from("consignment_submissions")
                .select()
                .in("id", values: ids)
                .execute()
                .value
            var map: [UUID: ConsignmentSubmissionRow] = [:]
            for row in rows { map[row.id] = row }
            listings = map
            ImageCacheManager.shared.prefetch(urls: rows.flatMap { $0.imageUrls })
        } catch {
            print("MarketplaceSalesView.loadListings failed: \(error)")
        }
    }

    // MARK: - Views

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "shippingbox")
                .font(.system(size: 40))
                .foregroundStyle(Color.black)
                .padding(.top, 40)
            Text(L.t(sv: "Inga försäljningar ännu", nb: "Ingen salg ennå"))
                .font(.system(size: 18, weight: .semibold))
            Text(L.t(
                sv: "Sålda annonser dyker upp här. Du får en notis när första köpet sker.",
                nb: "Solgte annonser dukker opp her. Du får en varsling når første kjøpet skjer."
            ))
            .font(.system(size: 14))
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 40)
        }
    }

    private func saleRow(order: MarketplaceOrderRow) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            NavigationLink(value: MarketplaceRoute.orderDetail(order)) {
                saleCard(order: order)
            }
            .buttonStyle(PressableCardButtonStyle())
            if sellerLabelCTAVisible(order) {
                sellerLabelCTA(order: order)
            }
        }
        .padding(14)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func saleCard(order: MarketplaceOrderRow) -> some View {
        let listing = order.listingId.flatMap { listings[$0] }
        let thumbUrl = listing?.imageUrls.first ?? order.listingImageUrl
        let resolvedTitle = [listing?.title, order.listingTitle]
            .compactMap { $0 }
            .first { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                CachedRemoteImage(url: thumbUrl) {
                    Color(.tertiarySystemFill)
                }
                .frame(width: 76, height: 76)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                VStack(alignment: .leading, spacing: 4) {
                    Text(resolvedTitle ?? L.t(sv: "Annons", nb: "Annonse"))
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.primary)
                        .lineLimit(2)
                    Text(MarketplacePricing.formatSEK(Double(order.amountSellerPayout) / 100.0))
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.primary)
                    statusPill(order: order)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.tertiary)
            }
            if let banner = deadlineBanner(for: order) {
                HStack(spacing: 8) {
                    Image(systemName: banner.icon)
                        .foregroundStyle(banner.tint)
                    Text(banner.title)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(banner.tint)
                }
                .padding(.top, 2)
            }
        }
    }

    private func sellerLabelCTAVisible(_ order: MarketplaceOrderRow) -> Bool {
        switch order.status {
        case "succeeded", "held_awaiting_seller": break
        default: return false
        }
        if order.shippingStatus == "label_ready" { return true }
        if let u = order.shippingLabelUrl?.trimmingCharacters(in: .whitespacesAndNewlines), !u.isEmpty {
            return true
        }
        if let sm = order.shipmondoShipmentId?.trimmingCharacters(in: .whitespacesAndNewlines), !sm.isEmpty,
           order.shippedAt == nil {
            return true
        }
        if order.effectiveQrPayloadForAgent != nil, order.shippedAt == nil {
            return true
        }
        return false
    }

    private func sellerLabelCTA(order: MarketplaceOrderRow) -> some View {
        let path = order.shippingLabelUrl?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let hasStoredLabel = !path.isEmpty
        let qrOnly = !hasStoredLabel && order.effectiveQrPayloadForAgent != nil && order.shippedAt == nil
        let loading = salesListLabelFetchOrderId == order.id
        return Button {
            Task { await handleSalesListLabelTap(order: order) }
        } label: {
            HStack(spacing: 8) {
                if loading {
                    ProgressView()
                        .tint(.white)
                }
                Image(systemName: "qrcode.viewfinder")
                Text(
                    hasStoredLabel
                        ? L.t(sv: "Visa fraktsedel", nb: "Vis fraktseddel")
                        : qrOnly
                            ? L.t(sv: "QR till ombud", nb: "QR til ombud")
                            : L.t(sv: "Hämta fraktsedel", nb: "Hent fraktseddel")
                )
                .font(.system(size: 14, weight: .bold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(Color.black)
            .foregroundColor(.white)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(loading)
    }

    @MainActor
    private func handleSalesListLabelTap(order: MarketplaceOrderRow) async {
        let trimmed = order.shippingLabelUrl?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        errorText = nil
        do {
            if !trimmed.isEmpty {
                let url = try await ShippingLabelService.shared.signedUrlForMarketplaceOrderLabel(
                    orderId: order.id,
                    sellerId: order.sellerId,
                    storedPath: trimmed
                )
                await UIApplication.shared.open(url)
                return
            }
            if order.effectiveQrPayloadForAgent != nil, order.shippedAt == nil {
                qrSheetOrder = order
                return
            }
            salesListLabelFetchOrderId = order.id
            defer { salesListLabelFetchOrderId = nil }
            _ = try await MarketplaceOrdersService.shared.refreshShipmondoLabel(orderId: order.id)
            await load()
            guard let updated = orders.first(where: { $0.id == order.id }) else { return }
            let newPath = updated.shippingLabelUrl?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if !newPath.isEmpty {
                let url = try await ShippingLabelService.shared.signedUrlForMarketplaceOrderLabel(
                    orderId: updated.id,
                    sellerId: updated.sellerId,
                    storedPath: newPath
                )
                await UIApplication.shared.open(url)
                return
            }
            if updated.effectiveQrPayloadForAgent != nil {
                qrSheetOrder = updated
                return
            }
            errorText = L.t(
                sv: "Fraktsedeln är inte klar än. Försök igen om en stund.",
                nb: "Fraktseddelen er ikke klar ennå. Prøv igjen om en stund."
            )
        } catch {
            errorText = error.localizedDescription
        }
    }

    private func statusPill(order: MarketplaceOrderRow) -> some View {
        let color = statusTint(for: order)
        return Text(order.shippingStatusLabel)
            .font(.system(size: 11, weight: .semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.18))
            .foregroundStyle(color)
            .clipShape(Capsule())
    }

    private struct DeadlineBanner {
        let title: String
        let icon: String
        let tint: Color
    }

    private func deadlineBanner(for order: MarketplaceOrderRow) -> DeadlineBanner? {
        if order.disputeOpenedAt != nil {
            return DeadlineBanner(
                title: L.t(
                    sv: "Köparen har anmält problem — kontakta köparen",
                    nb: "Kjøper har anmeldt problem — kontakt kjøperen"
                ),
                icon: "exclamationmark.bubble",
                tint: .red
            )
        }
        if order.shippedAt == nil, let deadline = order.shipByDeadlineDate {
            let remaining = deadline.timeIntervalSince(nowTick)
            if remaining > 0 {
                let urgent = remaining < 24 * 60 * 60
                return DeadlineBanner(
                    title: urgent
                        ? L.t(
                            sv: "Bråttom: lämna in inom \(formatRemaining(remaining))",
                            nb: "Haster: lever inn innen \(formatRemaining(remaining))"
                        )
                        : L.t(
                            sv: "Lämna in inom \(formatRemaining(remaining))",
                            nb: "Lever inn innen \(formatRemaining(remaining))"
                        ),
                    icon: urgent ? "exclamationmark.octagon.fill" : "clock.fill",
                    tint: urgent ? .red : .orange
                )
            }
        }
        if order.status == "released" {
            return DeadlineBanner(
                title: L.t(sv: "Utbetald", nb: "Utbetalt"),
                icon: "checkmark.seal.fill",
                tint: .green
            )
        }
        if order.buyerApprovedAt != nil && order.releasedAt == nil {
            return DeadlineBanner(
                title: L.t(
                    sv: "Godkänd – pengarna är på väg",
                    nb: "Godkjent – pengene er på vei"
                ),
                icon: "checkmark.seal",
                tint: .green
            )
        }
        if order.status == "cancelled" {
            return DeadlineBanner(
                title: L.t(
                    sv: "Avbruten — pengarna återbetalades till köparen",
                    nb: "Avbrutt — pengene refunderes til kjøper"
                ),
                icon: "xmark.octagon",
                tint: .gray
            )
        }
        return nil
    }

    private func statusTint(for order: MarketplaceOrderRow) -> Color {
        if order.disputeOpenedAt != nil { return .red }
        if order.status == "released" || order.buyerApprovedAt != nil { return .green }
        if order.shippingDeliveredAt != nil { return .orange }
        switch order.status {
        case "cancelled", "refunded", "failed": return .gray
        default: return .blue
        }
    }

    private func formatRemaining(_ seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds))
        let days = total / 86_400
        let hours = (total % 86_400) / 3_600
        if days > 0 { return hours > 0 ? "\(days)d \(hours)h" : "\(days)d" }
        let minutes = (total % 3_600) / 60
        if hours > 0 { return "\(hours)h \(minutes)m" }
        return "\(minutes)m"
    }
}
