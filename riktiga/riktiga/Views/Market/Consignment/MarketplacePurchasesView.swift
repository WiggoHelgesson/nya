import SwiftUI
import Supabase

/// "Mina köp" — shows marketplace orders where the current user is the buyer.
/// Trycker man på en rad pushas `OrderDetailView` upp som egen sida med
/// köparskydds-tidslinje + godkänn/anmäl-knappar.
struct MarketplacePurchasesView: View {
    /// Inbäddad utan egen `NavigationStack` när föräldern redan har `NavigationStack`.
    var embedInParentNavigation: Bool = false

    @EnvironmentObject var authViewModel: AuthViewModel

    @State private var orders: [MarketplaceOrderRow] = []
    @State private var listings: [UUID: ConsignmentSubmissionRow] = [:]
    @State private var isLoading = false
    @State private var errorText: String?

    @State private var path: [MarketplaceRoute] = []
    @State private var triggerNotificationPrompt = false

    private let accent = Color.black

    var body: some View {
        Group {
            if embedInParentNavigation {
                purchasesContent
            } else {
                NavigationStack(path: $path) {
                    purchasesContent
                        .navigationTitle(L.t(sv: "Mina köp", nb: "Mine kjøp"))
                        .navigationBarTitleDisplayMode(.inline)
                }
                .marketplaceDestinations()
                .notificationPrompt(for: .firstOpenList, trigger: $triggerNotificationPrompt)
            }
        }
    }

    private var purchasesContent: some View {
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
                        NavigationLink(value: MarketplaceRoute.orderDetail(order)) {
                            purchaseCard(order: order)
                        }
                        .buttonStyle(PressableCardButtonStyle())
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
    }

    // MARK: - Load

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let fetched = try await MarketplaceOrdersService.shared.fetchMyPurchases()
            orders = fetched
            errorText = nil
            await loadListings(for: fetched)
            // Soft-prompt notiser bara om de faktiskt har en pågående
            // order — det är då en notis blir relevant.
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
            print("MyPurchasesView.loadListings failed: \(error)")
        }
    }

    // MARK: - Views

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "bag")
                .font(.system(size: 40))
                .foregroundStyle(accent)
                .padding(.top, 40)
            Text(L.t(sv: "Inga köp ännu", nb: "Ingen kjøp enda"))
                .font(.system(size: 18, weight: .semibold))
            Text(L.t(
                sv: "När du köper en annons dyker det upp här.",
                nb: "Når du kjøper en annonse dukker den opp her."
            ))
            .font(.system(size: 14))
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 40)
        }
    }

    private func purchaseCard(order: MarketplaceOrderRow) -> some View {
        let listing = order.listingId.flatMap { listings[$0] }
        let thumbUrl = listing?.imageUrls.first ?? order.listingImageUrl
        let resolvedTitle = [listing?.title, order.listingTitle]
            .compactMap { $0 }
            .first { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        let resolvedBrand = [listing?.userBrand, order.listingBrand]
            .compactMap { $0 }
            .first { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        return HStack(alignment: .top, spacing: 12) {
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
                if let brand = resolvedBrand {
                    Text(brand)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                Text(MarketplacePricing.formatSEK(Double(order.amountBuyerTotal) / 100.0))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.primary)

                statusPill(order: order)

                if let banner = inlineBanner(order) {
                    Text(banner)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(bannerTint(for: order))
                }
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(14)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
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

    private func inlineBanner(_ order: MarketplaceOrderRow) -> String? {
        if order.canBuyerApprove {
            if let countdown = order.approvalCountdownText {
                return L.t(
                    sv: "Godkänn inom \(countdown)",
                    nb: "Godkjenn innen \(countdown)"
                )
            }
            return L.t(sv: "Tryck för att godkänna", nb: "Trykk for å godkjenne")
        }
        if order.disputeOpenedAt != nil {
            return L.t(
                sv: "Anmälan under granskning",
                nb: "Anmeldelse under behandling"
            )
        }
        if order.status == "cancelled" {
            return L.t(
                sv: "Avbruten — pengarna återbetalas",
                nb: "Avbrutt — pengene refunderes"
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

    private func bannerTint(for order: MarketplaceOrderRow) -> Color {
        if order.canBuyerApprove { return .orange }
        if order.disputeOpenedAt != nil { return .red }
        if order.status == "cancelled" || order.status == "refunded" { return .gray }
        return .secondary
    }
}
