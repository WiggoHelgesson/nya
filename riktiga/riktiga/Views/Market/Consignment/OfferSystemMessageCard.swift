import SwiftUI
import Supabase
import Auth

/// System message shown inside a listing chat when a seller accepts a
/// buyer's price offer (`message_type == "offer_accepted"`) or when the
/// buyer has finalised the purchase (`message_type == "offer_captured"`).
///
/// For the buyer the "accepted" card shows a "Slutför köp"-CTA that opens
/// `AddressFormView` and calls `finalize-marketplace-offer`. Both sides see
/// a confirmation state once the offer reaches `captured`.
struct OfferSystemMessageCard: View {
    let message: DirectMessage
    let currentUserId: UUID?

    @EnvironmentObject var authViewModel: AuthViewModel

    @State private var showAddressForm = false
    @State private var isFinalising = false
    @State private var errorText: String?
    @State private var liveStatus: String?

    private var payload: OfferCardData? { message.offerCardData }

    private var isBuyer: Bool {
        guard let uid = currentUserId, let buyerId = payload?.buyerId else { return false }
        return uid == buyerId
    }

    private var isCaptured: Bool {
        message.isOfferCaptured || liveStatus == "captured"
    }

    private var isCancelled: Bool {
        liveStatus == "cancelled" || liveStatus == "declined" || liveStatus == "expired"
    }

    private var priceLabel: String? {
        guard let p = payload?.offeredPriceSek else { return nil }
        return "\(p) kr"
    }

    private var totalLabel: String? {
        guard let ore = payload?.amountBuyerTotalOre else { return nil }
        let kr = Int((Double(ore) / 100.0).rounded())
        return "\(kr) kr"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header

            if let title = payload?.listingTitle, !title.isEmpty {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.primary)
                    .lineLimit(2)
            }

            if priceLabel != nil || totalLabel != nil {
                VStack(alignment: .leading, spacing: 4) {
                    if let priceLabel {
                        HStack(spacing: 6) {
                            Text(L.t(sv: "Pris", nb: "Pris"))
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                            Text(priceLabel)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.primary)
                        }
                    }
                    if let totalLabel {
                        HStack(spacing: 6) {
                            Text(L.t(sv: "Totalt m. köpskydd", nb: "Totalt m. kjøperbeskyttelse"))
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                            Text(totalLabel)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.primary)
                        }
                    }
                }
            }

            if let errorText {
                Text(errorText)
                    .font(.system(size: 12))
                    .foregroundColor(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            actionArea
        }
        .padding(14)
        .frame(maxWidth: 320, alignment: .leading)
        .background(Color(.secondarySystemBackground))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.black.opacity(0.08), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .task { await refreshLiveStatus() }
        .sheet(isPresented: $showAddressForm) {
            AddressFormView(
                initial: UserDefaults.standard.loadBuyerShippingAddress()
            ) { address in
                UserDefaults.standard.saveBuyerShippingAddress(address)
                Task { await finalize(address: address) }
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(isCaptured ? Color.green : Color.black)
                    .frame(width: 32, height: 32)
                Image(systemName: isCaptured ? "checkmark" : "checkmark.seal.fill")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.white)
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(headerTitle)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.primary)
                Text(headerSubtitle)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
    }

    private var headerTitle: String {
        if isCaptured {
            return L.t(sv: "Köpet är slutfört", nb: "Kjøpet er fullført")
        }
        if isCancelled {
            return L.t(sv: "Prisförslag avbrutet", nb: "Prisforslag avbrutt")
        }
        return L.t(sv: "Prisförslag accepterat", nb: "Prisforslag akseptert")
    }

    private var headerSubtitle: String {
        if isCaptured {
            return L.t(sv: "Leveransadressen finns i ordern.",
                       nb: "Leveringsadressen ligger i ordren.")
        }
        if isCancelled {
            return L.t(sv: "Reservationen på kortet är frisläppt.",
                       nb: "Reservasjonen på kortet er frigjort.")
        }
        if isBuyer {
            return L.t(
                sv: "Fyll i din leveransadress för att slutföra köpet.",
                nb: "Fyll inn leveringsadressen for å fullføre kjøpet."
            )
        }
        return L.t(
            sv: "Väntar på att köparen fyller i leveransadress.",
            nb: "Venter på at kjøperen fyller inn leveringsadresse."
        )
    }

    // MARK: - Action area

    @ViewBuilder
    private var actionArea: some View {
        if isCaptured {
            captionLabel(
                L.t(sv: "Tack! Säljaren packar och skickar inom kort.",
                    nb: "Takk! Selgeren pakker og sender snart.")
            )
        } else if isCancelled {
            captionLabel(
                L.t(sv: "Den här annonsen har stängts eller förslaget löpt ut.",
                    nb: "Denne annonsen har stengt eller forslaget har gått ut.")
            )
        } else if isBuyer {
            Button {
                errorText = nil
                showAddressForm = true
            } label: {
                HStack(spacing: 8) {
                    if isFinalising {
                        ProgressView().tint(.white)
                    }
                    Text(L.t(sv: "Slutför köp", nb: "Fullfør kjøp"))
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 11)
                .background(Color.black)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.plain)
            .disabled(isFinalising)
        }
    }

    private func captionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12))
            .foregroundColor(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Actions

    private func finalize(address: BuyerShippingAddress) async {
        guard let payload else { return }
        await MainActor.run {
            isFinalising = true
            errorText = nil
        }
        do {
            let session = try await SupabaseConfig.supabase.auth.session
            try await MarketplaceOfferService.shared.finalizeOffer(
                offerId: payload.offerId,
                shipping: address,
                accessToken: session.accessToken
            )
            await MainActor.run {
                liveStatus = "captured"
                isFinalising = false
            }
        } catch {
            await MainActor.run {
                errorText = error.localizedDescription
                isFinalising = false
            }
        }
    }

    private func refreshLiveStatus() async {
        guard let payload else { return }
        if let offer = try? await MarketplaceOfferService.shared.fetchOffer(offerId: payload.offerId) {
            await MainActor.run {
                liveStatus = offer.status
            }
        }
    }
}
