import Foundation
import Supabase

/// Buyer-side + seller-side service for listing price offers ("prisförslag").
///
/// Flow:
///   1. Buyer submits an offer via the `create-marketplace-offer-intent` edge
///      function (no shipping yet). A Stripe PaymentIntent is created with
///      `capture_method: 'manual'` so the card is authorized but no money
///      moves.
///   2. Seller sees pending offers in `MyListingsView` and can accept or
///      decline via `accept-marketplace-offer` / `decline-marketplace-offer`.
///   3. Accept → offer is marked `accepted`, other pending offers cancelled,
///      a DM is sent to the buyer with a "Slutför köp"-card. The PI is NOT
///      captured yet and no order is created.
///   4. Buyer taps "Slutför köp" in chat → `AddressFormView` → buyer calls
///      `finalize-marketplace-offer`, which attaches shipping to the PI,
///      captures it, creates the `marketplace_orders` row and marks the
///      listing sold.
///   5. Decline → PaymentIntent is cancelled, no money moves.
final class MarketplaceOfferService {

    static let shared = MarketplaceOfferService()
    private init() {}

    private var supabase: SupabaseClient { SupabaseConfig.supabase }

    // MARK: - Types

    struct OfferSheet {
        let offerId: UUID
        let paymentIntentClientSecret: String
        let ephemeralKey: String
        let customerId: String
        let publishableKey: String
        let breakdown: MarketplaceCheckoutService.PriceBreakdown
    }

    struct BuyerSummary: Decodable {
        let id: UUID?
        let name: String?
        let avatarUrl: String?
    }

    struct ListingOffer: Identifiable, Decodable {
        let id: UUID
        let listingId: UUID
        let buyerId: UUID
        let sellerId: UUID
        let offeredPriceSek: Int
        let message: String?
        let amountBuyerTotalOre: Int
        let amountSellerPayoutOre: Int
        let status: String
        let createdAt: String?
        let respondedAt: String?
        var buyer: BuyerSummary?

        enum CodingKeys: String, CodingKey {
            case id
            case listingId = "listing_id"
            case buyerId = "buyer_id"
            case sellerId = "seller_id"
            case offeredPriceSek = "offered_price_sek"
            case message
            case amountBuyerTotalOre = "amount_buyer_total_ore"
            case amountSellerPayoutOre = "amount_seller_payout_ore"
            case status
            case createdAt = "created_at"
            case respondedAt = "responded_at"
        }
    }

    private struct BuyerProfileRow: Decodable {
        let id: UUID
        let username: String?
        let avatarUrl: String?

        enum CodingKeys: String, CodingKey {
            case id
            case username
            case avatarUrl = "avatar_url"
        }
    }

    // MARK: - Buyer: create an offer

    func createOffer(
        listingId: UUID,
        offeredPriceSEK: Int,
        message: String?,
        buyerEmail: String,
        accessToken: String,
        shippingCarrier: String? = nil,
        shippingServiceCode: String? = nil,
        shippingProductName: String? = nil,
        shippingAmountOre: Int? = nil,
        shippingBookingToken: String? = nil,
        shippingServicePointToken: String? = nil,
        shippingServicePointName: String? = nil,
        shippingServicePointAddress: String? = nil
    ) async throws -> OfferSheet {
        let url = URL(string: "\(SupabaseConfig.projectURL.absoluteString)/functions/v1/create-marketplace-offer-intent")!

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")

        var body: [String: Any] = [
            "listingId": listingId.uuidString,
            "offeredPriceSEK": offeredPriceSEK,
            "buyerEmail": buyerEmail
        ]
        if let message, !message.isEmpty {
            body["message"] = message
        }
        if let shippingCarrier { body["shippingCarrier"] = shippingCarrier }
        if let shippingServiceCode { body["shippingServiceCode"] = shippingServiceCode }
        if let shippingProductName { body["shippingProductName"] = shippingProductName }
        if let shippingAmountOre { body["shippingAmountOre"] = shippingAmountOre }
        if let shippingBookingToken { body["shippingBookingToken"] = shippingBookingToken }
        if let shippingServicePointToken { body["shippingServicePointToken"] = shippingServicePointToken }
        if let shippingServicePointName { body["shippingServicePointName"] = shippingServicePointName }
        if let shippingServicePointAddress { body["shippingServicePointAddress"] = shippingServicePointAddress }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, _) = try await SupabaseConfig.urlSession.data(for: request)

        struct Response: Codable {
            let success: Bool
            let offerId: String?
            let paymentIntent: String?
            let ephemeralKey: String?
            let customer: String?
            let publishableKey: String?
            let breakdown: MarketplaceCheckoutService.PriceBreakdown?
            let error: String?
        }

        let decoded = try JSONDecoder().decode(Response.self, from: data)

        if !decoded.success {
            throw MarketplaceCheckoutError.apiError(decoded.error ?? "Unknown error")
        }

        guard let offerIdString = decoded.offerId,
              let offerId = UUID(uuidString: offerIdString),
              let paymentIntent = decoded.paymentIntent,
              let ephemeralKey = decoded.ephemeralKey,
              let customer = decoded.customer,
              let publishableKey = decoded.publishableKey,
              let breakdown = decoded.breakdown else {
            throw MarketplaceCheckoutError.invalidResponse
        }

        return OfferSheet(
            offerId: offerId,
            paymentIntentClientSecret: paymentIntent,
            ephemeralKey: ephemeralKey,
            customerId: customer,
            publishableKey: publishableKey,
            breakdown: breakdown
        )
    }

    // MARK: - Seller: list incoming offers

    /// Fetches all pending offers on a single listing owned by the current
    /// user. RLS restricts the rows to ones where the caller is the seller.
    /// Buyer profile info (name + avatar) is hydrated in a second query so
    /// we don't depend on a PostgREST FK between `listing_offers.buyer_id`
    /// and `profiles.id` (the FK points at `auth.users`).
    func fetchOffersForMyListing(listingId: UUID) async throws -> [ListingOffer] {
        try await AuthSessionManager.shared.ensureValidSession()
        var rows: [ListingOffer] = try await supabase
            .from("listing_offers")
            .select()
            .eq("listing_id", value: listingId.uuidString)
            .in("status", values: ["pending", "accepted"])
            .order("created_at", ascending: false)
            .execute()
            .value

        let buyerIds = Array(Set(rows.map { $0.buyerId.uuidString }))
        if buyerIds.isEmpty { return rows }

        let profiles: [BuyerProfileRow] = (try? await supabase
            .from("profiles")
            .select("id, username, avatar_url")
            .in("id", values: buyerIds)
            .execute()
            .value) ?? []

        let byId: [UUID: BuyerProfileRow] = Dictionary(
            uniqueKeysWithValues: profiles.map { ($0.id, $0) }
        )

        for i in rows.indices {
            if let profile = byId[rows[i].buyerId] {
                rows[i].buyer = BuyerSummary(
                    id: profile.id,
                    name: profile.username,
                    avatarUrl: profile.avatarUrl
                )
            }
        }
        return rows
    }

    /// Buyer-side: their own outgoing offers (any status). Surface for a
    /// future "Mina prisförslag"-vy (not used in this release).
    func fetchMyOutgoingOffers(limit: Int = 50) async throws -> [ListingOffer] {
        try await AuthSessionManager.shared.ensureValidSession()
        guard let uid = try? await supabase.auth.session.user.id.uuidString else {
            throw MarketplaceCheckoutError.notAuthenticated
        }
        let rows: [ListingOffer] = try await supabase
            .from("listing_offers")
            .select()
            .eq("buyer_id", value: uid)
            .order("created_at", ascending: false)
            .limit(limit)
            .execute()
            .value
        return rows
    }

    // MARK: - Seller: accept / decline

    func acceptOffer(offerId: UUID, accessToken: String) async throws {
        try await postAction(
            path: "accept-marketplace-offer",
            offerId: offerId,
            accessToken: accessToken
        )
    }

    func declineOffer(offerId: UUID, accessToken: String) async throws {
        try await postAction(
            path: "decline-marketplace-offer",
            offerId: offerId,
            accessToken: accessToken
        )
    }

    private func postAction(path: String, offerId: UUID, accessToken: String) async throws {
        let url = URL(string: "\(SupabaseConfig.projectURL.absoluteString)/functions/v1/\(path)")!

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "offerId": offerId.uuidString
        ])

        let (data, _) = try await SupabaseConfig.urlSession.data(for: request)

        struct Response: Decodable {
            let success: Bool
            let error: String?
        }

        let decoded = try JSONDecoder().decode(Response.self, from: data)
        if !decoded.success {
            throw MarketplaceCheckoutError.apiError(decoded.error ?? "Unknown error")
        }
    }

    // MARK: - Buyer: finalise accepted offer (collect shipping + capture)

    /// Buyer calls this after the seller has accepted. Passes the shipping
    /// address to `finalize-marketplace-offer` which attaches it to the PI,
    /// captures the authorization, creates the order row and marks the
    /// listing sold.
    func finalizeOffer(
        offerId: UUID,
        shipping: BuyerShippingAddress,
        accessToken: String
    ) async throws {
        let url = URL(string: "\(SupabaseConfig.projectURL.absoluteString)/functions/v1/finalize-marketplace-offer")!

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")

        let body: [String: Any] = [
            "offerId": offerId.uuidString,
            "shipping": [
                "name": shipping.fullName,
                "address": shipping.displayLine,
                "postal": shipping.postalCode,
                "city": shipping.city,
                "country": shipping.country
            ]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, _) = try await SupabaseConfig.urlSession.data(for: request)

        struct Response: Decodable {
            let success: Bool
            let error: String?
        }

        let decoded = try JSONDecoder().decode(Response.self, from: data)
        if !decoded.success {
            throw MarketplaceCheckoutError.apiError(decoded.error ?? "Unknown error")
        }
    }

    /// Fetch a single offer by id. Used by the chat "Slutför köp"-card so
    /// we can display the current state (pending / accepted / captured /
    /// cancelled / expired).
    func fetchOffer(offerId: UUID) async throws -> ListingOffer? {
        try await AuthSessionManager.shared.ensureValidSession()
        let rows: [ListingOffer] = try await supabase
            .from("listing_offers")
            .select()
            .eq("id", value: offerId.uuidString)
            .limit(1)
            .execute()
            .value
        return rows.first
    }
}
