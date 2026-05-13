import Combine
import SwiftUI
import Supabase
import Auth

@MainActor
final class MyListingsViewModel: ObservableObject {
    @Published var rows: [ConsignmentSubmissionRow] = []
    @Published var sales: [MarketplaceOrderRow] = []
    @Published var offersByListing: [UUID: [MarketplaceOfferService.ListingOffer]] = [:]
    @Published var isLoading = false
    @Published var errorText: String?
    @Published var actionErrorText: String?

    func load(userId: String) async {
        isLoading = true
        defer { isLoading = false }
        do {
            async let fetched = ConsignmentSubmissionService.shared.fetchMine(userId: userId)
            async let salesFetched = MarketplaceOrdersService.shared.fetchMySales()

            let listings = try await fetched
            rows = listings
            errorText = nil
            ImageCacheManager.shared.prefetch(urls: listings.flatMap { $0.imageUrls })

            if let result = try? await salesFetched {
                sales = result
            }

            await loadOffers(for: listings)
        } catch {
            errorText = error.localizedDescription
        }
    }

    func loadOffers(for listings: [ConsignmentSubmissionRow]) async {
        let active = listings.filter { $0.soldAt == nil && $0.adminStatus.lowercased() == "accepted" }
        var dict: [UUID: [MarketplaceOfferService.ListingOffer]] = [:]
        await withTaskGroup(of: (UUID, [MarketplaceOfferService.ListingOffer]?).self) { group in
            for listing in active {
                group.addTask {
                    let offers = try? await MarketplaceOfferService.shared.fetchOffersForMyListing(listingId: listing.id)
                    return (listing.id, offers)
                }
            }
            for await (listingId, offers) in group {
                if let offers, !offers.isEmpty {
                    dict[listingId] = offers
                }
            }
        }
        offersByListing = dict
    }

    func acceptOffer(_ offer: MarketplaceOfferService.ListingOffer) async {
        do {
            let session = try await SupabaseConfig.supabase.auth.session
            try await MarketplaceOfferService.shared.acceptOffer(
                offerId: offer.id,
                accessToken: session.accessToken
            )
            // Keep the accepted offer visible as "väntar på köparen" until
            // the buyer finalises and it flips to captured (which then
            // also moves the listing into the sold bucket). The list is
            // refreshed on the screen via load() after the alert closes.
        } catch {
            actionErrorText = error.localizedDescription
        }
    }

    func declineOffer(_ offer: MarketplaceOfferService.ListingOffer) async {
        do {
            let session = try await SupabaseConfig.supabase.auth.session
            try await MarketplaceOfferService.shared.declineOffer(
                offerId: offer.id,
                accessToken: session.accessToken
            )
            if var remaining = offersByListing[offer.listingId] {
                remaining.removeAll { $0.id == offer.id }
                offersByListing[offer.listingId] = remaining.isEmpty ? nil : remaining
            }
        } catch {
            actionErrorText = error.localizedDescription
        }
    }

    func listing(forOrder order: MarketplaceOrderRow) -> ConsignmentSubmissionRow? {
        guard let listingId = order.listingId else { return nil }
        return rows.first(where: { $0.id == listingId })
    }

    func order(forListing id: UUID) -> MarketplaceOrderRow? {
        sales.first(where: { $0.listingId == id })
    }
}

struct MyListingsView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @StateObject private var viewModel = MyListingsViewModel()
    @Environment(\.marketplaceHeroNamespace) private var heroNS
    @State private var offerToAccept: MarketplaceOfferService.ListingOffer?
    /// Pending offer the seller wanted to accept but couldn't before
    /// providing a pickup address. Once they save the address (in the
    /// `SellerPickupAddressForm` sheet) we promote it to `offerToAccept`.
    @State private var pendingOfferAwaitingAddress: MarketplaceOfferService.ListingOffer?
    @State private var triggerNotificationPrompt = false
    @State private var showMissingPickupBanner = false

    private let accent = Color.black

    private let gridColumns: [GridItem] = [
        GridItem(.flexible(), spacing: 14),
        GridItem(.flexible(), spacing: 14)
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                if showMissingPickupBanner {
                    missingPickupBanner
                }
                if viewModel.isLoading && viewModel.rows.isEmpty {
                    ProgressView()
                        .padding(.top, 60)
                } else if viewModel.rows.isEmpty {
                    emptyState
                } else {
                    if !viewModel.offersByListing.isEmpty {
                        offersSection
                    }
                    LazyVGrid(columns: gridColumns, spacing: 14) {
                        ForEach(viewModel.rows) { row in
                            listingCard(row: row)
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 32)
        }
        .refreshable {
            if let id = authViewModel.currentUser?.id {
                await viewModel.load(userId: id)
                await refreshPickupBannerState()
            }
        }
        .task {
            if let id = authViewModel.currentUser?.id {
                await viewModel.load(userId: id)
                await refreshPickupBannerState()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("NavigateToMyListings"))) { _ in
            if let id = authViewModel.currentUser?.id {
                Task {
                    await viewModel.load(userId: id)
                    await refreshPickupBannerState()
                }
            }
        }
        .marketplaceDestinations()
        .alert(
            L.t(sv: "Acceptera prisförslag?", nb: "Akseptere prisforslag?"),
            isPresented: Binding(
                get: { offerToAccept != nil },
                set: { if !$0 { offerToAccept = nil } }
            ),
            presenting: offerToAccept
        ) { offer in
            Button(L.t(sv: "Tacka ja", nb: "Takk ja")) {
                Task {
                    await viewModel.acceptOffer(offer)
                    offerToAccept = nil
                    if let id = authViewModel.currentUser?.id {
                        await viewModel.load(userId: id)
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
                        triggerNotificationPrompt = true
                    }
                }
            }
            Button(L.t(sv: "Avbryt", nb: "Avbryt"), role: .cancel) {
                offerToAccept = nil
            }
        } message: { offer in
            Text(L.t(
                sv: "Köparen (\(offer.offeredPriceSek) kr) får ett meddelande i chatten där hen fyller i leveransadress och slutför köpet. Pengar dras först då. Fraktsedel skapas automatiskt när köparen slutför. Andra prisförslag avslås automatiskt.",
                nb: "Kjøperen (\(offer.offeredPriceSek) kr) får en melding i chatten der hen fyller inn leveringsadresse og fullfører kjøpet. Penger trekkes først da. Fraktseddelen lages automatisk når kjøperen fullfører. Andre prisforslag avslås automatisk."
            ))
        }
        .sheet(item: $pendingOfferAwaitingAddress) { offer in
            NavigationStack {
                SellerPickupAddressForm(
                    initialAddress: nil,
                    onSave: { address in
                        try await ShipmondoShippingService.shared.saveSellerPickupAddress(address)
                        await MainActor.run {
                            pendingOfferAwaitingAddress = nil
                            offerToAccept = offer
                        }
                    },
                    onCancel: {
                        pendingOfferAwaitingAddress = nil
                    }
                )
            }
        }
        .alert(
            L.t(sv: "Något gick fel", nb: "Noe gikk galt"),
            isPresented: Binding(
                get: { viewModel.actionErrorText != nil },
                set: { if !$0 { viewModel.actionErrorText = nil } }
            )
        ) {
            Button("OK", role: .cancel) { viewModel.actionErrorText = nil }
        } message: {
            Text(viewModel.actionErrorText ?? "")
        }
        .notificationPrompt(for: .saleSuccess, trigger: $triggerNotificationPrompt)
    }

    @MainActor
    private func refreshPickupBannerState() async {
        do {
            if let _ = try await ShipmondoShippingService.shared.fetchSellerPickupAddress() {
                showMissingPickupBanner = false
            } else {
                showMissingPickupBanner = true
            }
        } catch {
            showMissingPickupBanner = true
        }
    }

    private var missingPickupBanner: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "mappin.and.ellipse")
                .font(.system(size: 18))
                .foregroundStyle(accent)
            Text(L.t(
                sv: "Lägg till din upphämtningsadress under Inställningar eller när du skapar en annons — annars kan automatiska fraktsedlar inte skapas vid köp.",
                nb: "Legg til henteadresse under Innstillinger eller når du lager annonse."
            ))
            .font(.system(size: 13))
            .foregroundStyle(.primary)
            .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.orange.opacity(0.14))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    /// Gates the "Tacka ja"-flow on the seller having a saved pickup
    /// address that marketplace shipping can use as sender. If we have one, jumps straight
    /// to the confirm-accept alert; otherwise shows the address form first.
    private func beginAccept(offer: MarketplaceOfferService.ListingOffer) async {
        do {
            if let _ = try await ShipmondoShippingService.shared.fetchSellerPickupAddress() {
                await MainActor.run { offerToAccept = offer }
            } else {
                await MainActor.run { pendingOfferAwaitingAddress = offer }
            }
        } catch {
            await MainActor.run {
                viewModel.actionErrorText = error.localizedDescription
            }
        }
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "tag")
                .font(.system(size: 40))
                .foregroundStyle(accent)
                .padding(.top, 60)
            Text(L.t(sv: "Inga annonser än", nb: "Ingen annonser enda"))
                .font(.system(size: 18, weight: .semibold))
            Text(L.t(
                sv: "Skapa din första annons från + -ikonen i menyn.",
                nb: "Lag din første annonse fra + -ikonet i menyen."
            ))
            .font(.system(size: 14))
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 40)

            Button {
                NotificationCenter.default.post(name: NSNotification.Name("OpenNewListingFlow"), object: nil)
            } label: {
                Text(L.t(sv: "Skapa annons", nb: "Lag annonse"))
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 28)
                    .padding(.vertical, 12)
                    .background(accent)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .padding(.top, 8)
        }
    }

    // MARK: - Offers section (pending price offers from buyers)

    private var offersSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(L.t(sv: "Prisförslag", nb: "Prisforslag"))
                .font(.system(size: 15, weight: .bold))
                .padding(.horizontal, 4)

            VStack(spacing: 10) {
                ForEach(Array(viewModel.offersByListing.keys), id: \.self) { listingId in
                    if let offers = viewModel.offersByListing[listingId],
                       let listing = viewModel.rows.first(where: { $0.id == listingId }) {
                        offerGroup(listing: listing, offers: offers)
                    }
                }
            }
        }
    }

    private func offerGroup(
        listing: ConsignmentSubmissionRow,
        offers: [MarketplaceOfferService.ListingOffer]
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                CachedRemoteImage(url: listing.imageUrls.first) {
                    Color(.secondarySystemBackground)
                }
                .frame(width: 44, height: 44)
                .clipShape(RoundedRectangle(cornerRadius: 8))

                VStack(alignment: .leading, spacing: 2) {
                    Text(listing.title ?? L.t(sv: "Annons", nb: "Annonse"))
                        .font(.system(size: 14, weight: .semibold))
                        .lineLimit(1)
                    if let price = listing.priceSEK {
                        Text("\(price) kr")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Text("\(offers.count)")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(accent))
            }

            VStack(spacing: 8) {
                ForEach(offers) { offer in
                    offerRow(offer: offer, listingPrice: listing.priceSEK)
                }
            }
        }
        .padding(12)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func offerRow(
        offer: MarketplaceOfferService.ListingOffer,
        listingPrice: Int?
    ) -> some View {
        let isAccepted = offer.status == "accepted"
        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                ProfileImage(
                    url: offer.buyer?.avatarUrl,
                    size: 32,
                    isPro: false
                )
                VStack(alignment: .leading, spacing: 1) {
                    Text(offer.buyer?.name ?? L.t(sv: "Köpare", nb: "Kjøper"))
                        .font(.system(size: 13, weight: .semibold))
                        .lineLimit(1)
                    Text("\(offer.offeredPriceSek) kr")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(accent)
                }
                Spacer()
                if isAccepted {
                    Text(L.t(sv: "Accepterat", nb: "Akseptert"))
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(Color.green))
                }
            }

            if let message = offer.message, !message.isEmpty {
                Text(message)
                    .font(.system(size: 13))
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.systemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            if isAccepted {
                HStack(spacing: 8) {
                    Image(systemName: "hourglass")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.secondary)
                    Text(L.t(
                        sv: "Väntar på att köparen fyller i leveransadress och slutför köpet.",
                        nb: "Venter på at kjøperen fyller inn leveringsadresse og fullfører kjøpet."
                    ))
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(Color(.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                HStack(spacing: 8) {
                    Button {
                        Task { await viewModel.declineOffer(offer) }
                    } label: {
                        Text(L.t(sv: "Tacka nej", nb: "Takk nei"))
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(accent)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(accent, lineWidth: 1.5)
                            )
                    }
                    .buttonStyle(.plain)

                    Button {
                        Task { await beginAccept(offer: offer) }
                    } label: {
                        Text(L.t(sv: "Tacka ja", nb: "Takk ja"))
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(accent)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(10)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Card

    @ViewBuilder
    private func listingCard(row: ConsignmentSubmissionRow) -> some View {
        let route: MarketplaceRoute = {
            if row.soldAt != nil, let order = viewModel.order(forListing: row.id) {
                return .orderDetail(order)
            }
            return .listing(row)
        }()
        VStack(alignment: .leading, spacing: 8) {
            NavigationLink(value: route) {
                VStack(alignment: .leading, spacing: 8) {
                    ZStack(alignment: .topLeading) {
                        Color.clear
                            .aspectRatio(1, contentMode: .fit)
                            .overlay {
                                coverImage(url: row.imageUrls.first)
                            }
                            .clipped()
                            .clipShape(RoundedRectangle(cornerRadius: 12))

                        statusBadge(for: row)
                            .padding(8)
                    }

                    if let title = row.title, !title.isEmpty {
                        Text(title)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.primary)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                    }

                    Text(formattedPrice(row: row))
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.primary)

                }
            }
            .buttonStyle(PressableCardButtonStyle())
            .modifier(MarketplaceHeroSourceModifier(id: row.id, namespace: heroNS))
        }
        .padding(10)
        .background(Color(.systemBackground))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(Color.black.opacity(0.06), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: Color.black.opacity(0.05), radius: 6, x: 0, y: 2)
    }

    @ViewBuilder
    private func coverImage(url: String?) -> some View {
        CachedRemoteImage(url: url) {
            placeholder
        }
    }

    private var placeholder: some View {
        ZStack {
            Color(.secondarySystemBackground)
            Image(systemName: "photo")
                .font(.system(size: 28))
                .foregroundStyle(.secondary)
        }
    }

    private func statusBadge(for row: ConsignmentSubmissionRow) -> some View {
        let info = statusInfo(for: row)
        return HStack(spacing: 5) {
            Circle()
                .fill(info.tint)
                .frame(width: 6, height: 6)
            Text(info.title)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.black.opacity(0.65))
        .clipShape(Capsule())
    }

    private func statusInfo(for row: ConsignmentSubmissionRow) -> (title: String, tint: Color) {
        if row.soldAt != nil {
            return (L.t(sv: "STATUS: DAGS ATT SKICKA", nb: "STATUS: KLAR FOR FORSENDELSE"), .green)
        }
        switch row.adminStatus.lowercased() {
        case "accepted", "approved", "published":
            return (L.t(sv: "Publicerad", nb: "Publisert"), .green)
        case "rejected", "declined":
            return (L.t(sv: "Avvisad", nb: "Avvist"), .red)
        default:
            return (L.t(sv: "Bearbetar", nb: "Behandles"), .orange)
        }
    }

    private func formattedPrice(row: ConsignmentSubmissionRow) -> String {
        if let price = row.priceSEK {
            return "\(price) kr"
        }
        if let range = row.finalPriceRange, !range.isEmpty {
            return range
        }
        return "—"
    }
}

