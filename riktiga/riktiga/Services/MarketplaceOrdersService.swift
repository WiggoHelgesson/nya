import Foundation
import Supabase

/// Marketplace order rows, used both by buyers ("Mina köp") and sellers
/// ("Sålda"). RLS on `marketplace_orders` allows both sides to read
/// their own rows.
struct MarketplaceOrderRow: Decodable, Identifiable, Hashable {
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (a: Self, b: Self) -> Bool { a.id == b.id }

    let id: UUID
    /// `listing_id` är nullable i DB efter `allow_delete_listing_with_orders.sql`
    /// (raderade annonser → SET NULL), så vi måste hantera nil i UI.
    let listingId: UUID?
    /// Snapshot från annons vid köp (visas när listningen saknas eller raderats).
    let listingTitle: String?
    let listingBrand: String?
    let listingImageUrl: String?
    let buyerId: UUID
    let sellerId: UUID
    let stripePaymentIntentId: String?
    let stripeChargeId: String?
    let stripeTransferId: String?
    let amountItem: Int
    let amountPlatformFee: Int
    let amountShipping: Int?
    let amountBuyerTotal: Int
    let amountSellerPayout: Int
    let currency: String
    let status: String
    let isHeld: Bool
    let releasedAt: String?
    let buyerShippingName: String?
    let buyerShippingAddress: String?
    let buyerShippingPostal: String?
    let buyerShippingCity: String?
    let buyerEmail: String?
    /// Snapshot av köparens visningsnamn vid köptillfället.
    let buyerUsername: String?
    let createdAt: String?

    // Shipmondo shipping (populated by book-marketplace-shipping).
    let shippingCarrier: String?
    let shippingServiceCode: String?
    let shippingTrackingNumber: String?
    let shippingTrackingUrl: String?
    let shippingLabelUrl: String?
    let shippingQrPayload: String?
    let shippingStatus: String?
    let shippingDeliveredAt: String?
    let shippingServicePointName: String?
    let shippingServicePointAddress: String?
    let shipmondoShipmentId: String?

    // Buyer protection (Blocket-style escrow)
    let shipByDeadline: String?
    let shippedAt: String?
    let buyerApprovalDeadline: String?
    let buyerApprovedAt: String?
    let disputeOpenedAt: String?
    let disputeReason: String?
    let disputeResolvedAt: String?
    let disputeResolution: String?
    let disputeAdminNote: String?
    let disputeRefundAmountOre: Int?
    let autoCancelledAt: String?
    let payoutFailedAt: String?
    let payoutFailureReason: String?
    /// Säljaren tryckte "Jag har packat".
    let sellerPackedAt: String?
    /// Idempotent flag för 48h-påminnelse (process-marketplace-deadlines).
    let shipByReminder48hAt: String?
    /// Simulerad/admin-testorder — ska inte räknas mot säljarens riktiga väntande utbetalning.
    let isTest: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case listingId = "listing_id"
        case listingTitle = "listing_title"
        case listingBrand = "listing_brand"
        case listingImageUrl = "listing_image_url"
        case buyerId = "buyer_id"
        case sellerId = "seller_id"
        case stripePaymentIntentId = "stripe_payment_intent_id"
        case stripeChargeId = "stripe_charge_id"
        case stripeTransferId = "stripe_transfer_id"
        case amountItem = "amount_item"
        case amountPlatformFee = "amount_platform_fee"
        case amountShipping = "amount_shipping"
        case amountBuyerTotal = "amount_buyer_total"
        case amountSellerPayout = "amount_seller_payout"
        case currency
        case status
        case isHeld = "is_held"
        case releasedAt = "released_at"
        case buyerShippingName = "buyer_shipping_name"
        case buyerShippingAddress = "buyer_shipping_address"
        case buyerShippingPostal = "buyer_shipping_postal"
        case buyerShippingCity = "buyer_shipping_city"
        case buyerEmail = "buyer_email"
        case buyerUsername = "buyer_username"
        case createdAt = "created_at"
        case shippingCarrier = "shipping_carrier"
        case shippingServiceCode = "shipping_service_code"
        case shippingTrackingNumber = "shipping_tracking_number"
        case shippingTrackingUrl = "shipping_tracking_url"
        case shippingLabelUrl = "shipping_label_url"
        case shippingQrPayload = "shipping_qr_payload"
        case shippingStatus = "shipping_status"
        case shippingDeliveredAt = "shipping_delivered_at"
        case shippingServicePointName = "shipping_service_point_name"
        case shippingServicePointAddress = "shipping_service_point_address"
        case shipmondoShipmentId = "shipmondo_shipment_id"
        case shipByDeadline = "ship_by_deadline"
        case shippedAt = "shipped_at"
        case buyerApprovalDeadline = "buyer_approval_deadline"
        case buyerApprovedAt = "buyer_approved_at"
        case disputeOpenedAt = "dispute_opened_at"
        case disputeReason = "dispute_reason"
        case disputeResolvedAt = "dispute_resolved_at"
        case disputeResolution = "dispute_resolution"
        case disputeAdminNote = "dispute_admin_note"
        case disputeRefundAmountOre = "dispute_refund_amount_ore"
        case autoCancelledAt = "auto_cancelled_at"
        case payoutFailedAt = "payout_failed_at"
        case payoutFailureReason = "payout_failure_reason"
        case sellerPackedAt = "seller_packed_at"
        case shipByReminder48hAt = "ship_by_reminder_48h_at"
        case isTest = "is_test"
    }

    private enum LegacyShipmentKeys: String, CodingKey {
        case sendify_shipment_id
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let legacy = try decoder.container(keyedBy: LegacyShipmentKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        listingId = try c.decodeIfPresent(UUID.self, forKey: .listingId)
        listingTitle = try c.decodeIfPresent(String.self, forKey: .listingTitle)
        listingBrand = try c.decodeIfPresent(String.self, forKey: .listingBrand)
        listingImageUrl = try c.decodeIfPresent(String.self, forKey: .listingImageUrl)
        buyerId = try c.decode(UUID.self, forKey: .buyerId)
        sellerId = try c.decode(UUID.self, forKey: .sellerId)
        stripePaymentIntentId = try c.decodeIfPresent(String.self, forKey: .stripePaymentIntentId)
        stripeChargeId = try c.decodeIfPresent(String.self, forKey: .stripeChargeId)
        stripeTransferId = try c.decodeIfPresent(String.self, forKey: .stripeTransferId)
        amountItem = try c.decode(Int.self, forKey: .amountItem)
        amountPlatformFee = try c.decode(Int.self, forKey: .amountPlatformFee)
        amountShipping = try c.decodeIfPresent(Int.self, forKey: .amountShipping)
        amountBuyerTotal = try c.decode(Int.self, forKey: .amountBuyerTotal)
        amountSellerPayout = try c.decode(Int.self, forKey: .amountSellerPayout)
        currency = try c.decode(String.self, forKey: .currency)
        status = try c.decode(String.self, forKey: .status)
        isHeld = try c.decode(Bool.self, forKey: .isHeld)
        releasedAt = try c.decodeIfPresent(String.self, forKey: .releasedAt)
        buyerShippingName = try c.decodeIfPresent(String.self, forKey: .buyerShippingName)
        buyerShippingAddress = try c.decodeIfPresent(String.self, forKey: .buyerShippingAddress)
        buyerShippingPostal = try c.decodeIfPresent(String.self, forKey: .buyerShippingPostal)
        buyerShippingCity = try c.decodeIfPresent(String.self, forKey: .buyerShippingCity)
        buyerEmail = try c.decodeIfPresent(String.self, forKey: .buyerEmail)
        buyerUsername = try c.decodeIfPresent(String.self, forKey: .buyerUsername)
        createdAt = try c.decodeIfPresent(String.self, forKey: .createdAt)
        shippingCarrier = try c.decodeIfPresent(String.self, forKey: .shippingCarrier)
        shippingServiceCode = try c.decodeIfPresent(String.self, forKey: .shippingServiceCode)
        shippingTrackingNumber = try c.decodeIfPresent(String.self, forKey: .shippingTrackingNumber)
        shippingTrackingUrl = try c.decodeIfPresent(String.self, forKey: .shippingTrackingUrl)
        shippingLabelUrl = try c.decodeIfPresent(String.self, forKey: .shippingLabelUrl)
        shippingQrPayload = try c.decodeIfPresent(String.self, forKey: .shippingQrPayload)
        shippingStatus = try c.decodeIfPresent(String.self, forKey: .shippingStatus)
        shippingDeliveredAt = try c.decodeIfPresent(String.self, forKey: .shippingDeliveredAt)
        shippingServicePointName = try c.decodeIfPresent(String.self, forKey: .shippingServicePointName)
        shippingServicePointAddress = try c.decodeIfPresent(String.self, forKey: .shippingServicePointAddress)
        shipmondoShipmentId = try c.decodeIfPresent(String.self, forKey: .shipmondoShipmentId)
            ?? legacy.decodeIfPresent(String.self, forKey: .sendify_shipment_id)
        shipByDeadline = try c.decodeIfPresent(String.self, forKey: .shipByDeadline)
        shippedAt = try c.decodeIfPresent(String.self, forKey: .shippedAt)
        buyerApprovalDeadline = try c.decodeIfPresent(String.self, forKey: .buyerApprovalDeadline)
        buyerApprovedAt = try c.decodeIfPresent(String.self, forKey: .buyerApprovedAt)
        disputeOpenedAt = try c.decodeIfPresent(String.self, forKey: .disputeOpenedAt)
        disputeReason = try c.decodeIfPresent(String.self, forKey: .disputeReason)
        disputeResolvedAt = try c.decodeIfPresent(String.self, forKey: .disputeResolvedAt)
        disputeResolution = try c.decodeIfPresent(String.self, forKey: .disputeResolution)
        disputeAdminNote = try c.decodeIfPresent(String.self, forKey: .disputeAdminNote)
        disputeRefundAmountOre = try c.decodeIfPresent(Int.self, forKey: .disputeRefundAmountOre)
        autoCancelledAt = try c.decodeIfPresent(String.self, forKey: .autoCancelledAt)
        payoutFailedAt = try c.decodeIfPresent(String.self, forKey: .payoutFailedAt)
        payoutFailureReason = try c.decodeIfPresent(String.self, forKey: .payoutFailureReason)
        sellerPackedAt = try c.decodeIfPresent(String.self, forKey: .sellerPackedAt)
        shipByReminder48hAt = try c.decodeIfPresent(String.self, forKey: .shipByReminder48hAt)
        isTest = try c.decodeIfPresent(Bool.self, forKey: .isTest) ?? false
    }

    /// Human-readable status label in Swedish.
    var statusLabel: String {
        switch status {
        case "pending": return L.t(sv: "Betalning pågår", nb: "Betaling pågår")
        case "succeeded": return shippingStatusLabel
        case "released": return L.t(sv: "Avslutad", nb: "Avsluttet")
        case "held_awaiting_seller": return L.t(sv: "Väntar på säljare", nb: "Venter på selger")
        case "failed": return L.t(sv: "Misslyckades", nb: "Mislyktes")
        case "refunded": return L.t(sv: "Återbetald", nb: "Refundert")
        case "disputed": return L.t(sv: "Anmäld", nb: "Anmeldt")
        case "cancelled": return L.t(sv: "Avbruten", nb: "Avbrutt")
        default: return status
        }
    }

    /// Mer detaljerad status med fokus på frakt-/godkännande-fasen.
    var shippingStatusLabel: String {
        if disputeOpenedAt != nil {
            return L.t(sv: "Anmäld", nb: "Anmeldt")
        }
        if buyerApprovedAt != nil {
            return L.t(sv: "Godkänd", nb: "Godkjent")
        }
        if shippingDeliveredAt != nil {
            return L.t(sv: "Levererad – godkänn varan", nb: "Levert – godkjenn varen")
        }
        switch shippingStatus ?? "" {
        case "in_transit": return L.t(sv: "På väg", nb: "På vei")
        case "picked_up": return L.t(sv: "Inlämnad", nb: "Innlevert")
        case "label_ready": return L.t(sv: "Fraktsedel klar", nb: "Fraktseddel klar")
        case "arrived_servicepoint":
            return L.t(sv: "Framme hos ombud", nb: "Framme hos utleveringssted")
        case "manual": return L.t(sv: "Manuell hantering", nb: "Manuell behandling")
        case "returned": return L.t(sv: "Returnerad", nb: "Returnert")
        case "failed": return L.t(sv: "Frakt misslyckades", nb: "Frakt feilet")
        default: return L.t(sv: "Betald – väntar på frakt", nb: "Betalt – venter på frakt")
        }
    }

    var payoutStatusLabel: String {
        if stripeTransferId != nil {
            return L.t(sv: "Utbetald", nb: "Utbetalt")
        }
        if isHeld {
            return L.t(sv: "Hålls i köparskydd", nb: "Holdes i kjøperbeskyttelse")
        }
        return L.t(sv: "Utbetalas direkt", nb: "Utbetales direkte")
    }

    // MARK: - Date helpers

    private static let isoFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()
    private static let isoFormatterNoFrac: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    private static func parseDate(_ value: String?) -> Date? {
        guard let value, !value.isEmpty else { return nil }
        return isoFormatter.date(from: value) ?? isoFormatterNoFrac.date(from: value)
    }

    var shipByDeadlineDate: Date? { Self.parseDate(shipByDeadline) }
    var buyerApprovalDeadlineDate: Date? { Self.parseDate(buyerApprovalDeadline) }
    var shippingDeliveredAtDate: Date? { Self.parseDate(shippingDeliveredAt) }
    var shippedAtDate: Date? { Self.parseDate(shippedAt) }
    var buyerApprovedAtDate: Date? { Self.parseDate(buyerApprovedAt) }
    var disputeOpenedAtDate: Date? { Self.parseDate(disputeOpenedAt) }
    var releasedAtDate: Date? { Self.parseDate(releasedAt) }
    var createdAtDate: Date? { Self.parseDate(createdAt) }
    var autoCancelledAtDate: Date? { Self.parseDate(autoCancelledAt) }
    var sellerPackedAtDate: Date? { Self.parseDate(sellerPackedAt) }

    /// QR för utskrift hos ombud: Shipmondo-QR om den finns, annars spårnummer.
    var effectiveQrPayloadForAgent: String? {
        let q = shippingQrPayload?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !q.isEmpty { return q }
        let t = shippingTrackingNumber?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return t.isEmpty ? nil : t
    }

    /// True om köparen kan godkänna varan just nu.
    var canBuyerApprove: Bool {
        status == "succeeded"
            && shippingDeliveredAt != nil
            && buyerApprovedAt == nil
            && disputeOpenedAt == nil
    }

    /// True om köparen kan anmäla problem just nu.
    var canBuyerDispute: Bool {
        (status == "succeeded" || status == "disputed")
            && buyerApprovedAt == nil
            && disputeOpenedAt == nil
            && releasedAt == nil
    }

    /// True om köparen ännu kan avboka köpet manuellt (paketet har inte
    /// lämnats in). Används i framtida "Avboka köp"-knapp.
    var canBuyerCancel: Bool {
        status == "succeeded"
            && shippedAt == nil
            && disputeOpenedAt == nil
            && autoCancelledAt == nil
            && (shippingStatus == "pending" || shippingStatus == "label_ready" || shippingStatus == "manual" || shippingStatus == nil)
    }

    /// "X tim Y min kvar" till en godkännande-deadline (eller nil om passerat).
    var approvalCountdownText: String? {
        guard let deadline = buyerApprovalDeadlineDate else { return nil }
        let remaining = deadline.timeIntervalSinceNow
        guard remaining > 0 else { return nil }
        let hours = Int(remaining) / 3600
        let minutes = (Int(remaining) % 3600) / 60
        if hours >= 1 {
            return "\(hours) tim \(minutes) min kvar"
        }
        return "\(minutes) min kvar"
    }

    /// "X dag Y tim kvar" till ship-by-deadline (eller nil om passerat).
    var shipByCountdownText: String? {
        guard let deadline = shipByDeadlineDate else { return nil }
        let remaining = deadline.timeIntervalSinceNow
        guard remaining > 0 else { return nil }
        let days = Int(remaining) / 86_400
        let hours = (Int(remaining) % 86_400) / 3600
        if days >= 1 {
            return "\(days) dag\(days == 1 ? "" : "ar") \(hours) tim kvar"
        }
        let minutes = (Int(remaining) % 3600) / 60
        return "\(hours) tim \(minutes) min kvar"
    }

    var shipByIsUrgent: Bool {
        guard let deadline = shipByDeadlineDate else { return false }
        let remaining = deadline.timeIntervalSinceNow
        return remaining > 0 && remaining < 24 * 60 * 60
    }

    /// True when köparen godkänt (eller auto-release) men Connect-transfer ännu inte gått — samma gate som `process-pending-seller-payouts`.
    private var countsTowardPendingSellerPayout: Bool {
        if isTest { return false }
        if let tid = stripeTransferId, !tid.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return false
        }
        if releasedAt != nil { return false }
        guard status == "succeeded" else { return false }
        guard isHeld else { return false }
        guard buyerApprovedAt != nil else { return false }
        if disputeOpenedAt != nil && disputeResolvedAt == nil { return false }
        return true
    }

    /// Sum of `amount_seller_payout` (öre) för godkända köp som väntar på Connect-transfer (ej köp under skydd före godkännande).
    static func totalPendingSellerPayoutOre(orders: [MarketplaceOrderRow]) -> Int {
        orders.filter { $0.countsTowardPendingSellerPayout }.reduce(0) { $0 + $1.amountSellerPayout }
    }
}

final class MarketplaceOrdersService {
    static let shared = MarketplaceOrdersService()
    private init() {}

    private var supabase: SupabaseClient { SupabaseConfig.supabase }

    /// Rader vi räknar som "synliga" i Mina köp / Mina försäljningar.
    /// `pending` och `failed` filtreras bort (övergivna checkouts), men
    /// `disputed` och `cancelled` ska synas så köpare/säljare kan följa
    /// hela livscykeln.
    private static let visibleStatuses: [String] = [
        "succeeded",
        "released",
        "refunded",
        "disputed",
        "cancelled",
        "held_awaiting_seller",
    ]

    /// Köparsidan: endast genomförda / relevanta köp (ej avbrutna utan leverans).
    private static let buyerVisibleStatuses: [String] = [
        "succeeded",
        "held_awaiting_seller",
        "released",
        "refunded",
        "disputed",
    ]

    /// Buyer: fetches the current user's purchases.
    func fetchMyPurchases(limit: Int = 100) async throws -> [MarketplaceOrderRow] {
        try await AuthSessionManager.shared.ensureValidSession()
        guard let uid = try? await supabase.auth.session.user.id.uuidString else {
            throw MarketplaceCheckoutError.notAuthenticated
        }
        return try await supabase
            .from("marketplace_orders")
            .select()
            .eq("buyer_id", value: uid)
            .in("status", values: Self.buyerVisibleStatuses)
            .not("stripe_payment_intent_id", operator: .is, value: "null")
            .order("created_at", ascending: false)
            .limit(limit)
            .execute()
            .value
    }

    /// Seller: fetches sold rows so the seller can pack & ship.
    func fetchMySales(limit: Int = 100) async throws -> [MarketplaceOrderRow] {
        try await AuthSessionManager.shared.ensureValidSession()
        guard let uid = try? await supabase.auth.session.user.id.uuidString else {
            throw MarketplaceCheckoutError.notAuthenticated
        }
        return try await supabase
            .from("marketplace_orders")
            .select()
            .eq("seller_id", value: uid)
            .in("status", values: Self.visibleStatuses)
            .order("created_at", ascending: false)
            .limit(limit)
            .execute()
            .value
    }

    /// Admin: orders whose automated shipping booking failed and need a manually
    /// uploaded label. Surfaced in `ConsignmentSubmissionsAdminView`.
    /// Relies on `marketplace_orders` RLS policy that grants admins read
    /// access via `public.is_admin()`.
    func fetchManualShippingOrders(limit: Int = 100) async throws -> [MarketplaceOrderRow] {
        try await AuthSessionManager.shared.ensureValidSession()
        return try await supabase
            .from("marketplace_orders")
            .select()
            .eq("shipping_status", value: "manual")
            .order("created_at", ascending: false)
            .limit(limit)
            .execute()
            .value
    }

    /// Admin: open marketplace disputes som väntar på beslut.
    func fetchOpenDisputes(limit: Int = 100) async throws -> [MarketplaceOrderRow] {
        try await AuthSessionManager.shared.ensureValidSession()
        // RLS-policyn `is_admin()` ger admins läsrätt på alla rader.
        return try await supabase
            .from("marketplace_orders")
            .select()
            .eq("status", value: "disputed")
            .filter("dispute_resolved_at", operator: "is", value: "null")
            .order("dispute_opened_at", ascending: true)
            .limit(limit)
            .execute()
            .value
    }

    /// Admin: orders med Stripe-payout-fel som behöver retry/granskning.
    func fetchPayoutFailures(limit: Int = 100) async throws -> [MarketplaceOrderRow] {
        try await AuthSessionManager.shared.ensureValidSession()
        return try await supabase
            .from("marketplace_orders")
            .select()
            .not("payout_failed_at", operator: .is, value: "null")
            .filter("released_at", operator: "is", value: "null")
            .order("payout_failed_at", ascending: false)
            .limit(limit)
            .execute()
            .value
    }

    /// Senaste order för säljaren på en viss annons där paketet ännu inte är inlämnat.
    func fetchActiveSellerShipmentOrder(listingId: UUID, sellerId: UUID) async throws -> MarketplaceOrderRow? {
        try await AuthSessionManager.shared.ensureValidSession()
        let rows: [MarketplaceOrderRow] = try await supabase
            .from("marketplace_orders")
            .select()
            .eq("listing_id", value: listingId.uuidString)
            .eq("seller_id", value: sellerId.uuidString)
            .in("status", values: ["succeeded", "held_awaiting_seller"])
            .order("created_at", ascending: false)
            .limit(1)
            .execute()
            .value
        guard let row = rows.first else { return nil }
        if row.shippedAt != nil { return nil }
        if row.autoCancelledAt != nil { return nil }
        if row.status == "cancelled" || row.status == "refunded" { return nil }
        return row
    }

    /// Hämtar en enskild order via id. RLS säkrar att endast köpare,
    /// säljare eller admin kan läsa raden.
    func fetchOrder(id: UUID) async throws -> MarketplaceOrderRow {
        try await AuthSessionManager.shared.ensureValidSession()
        return try await supabase
            .from("marketplace_orders")
            .select()
            .eq("id", value: id.uuidString)
            .single()
            .execute()
            .value
    }

    /// Köparen trycker "Godkänn varan" → release.
    @discardableResult
    func approveOrder(orderId: UUID) async throws -> MarketplaceActionResult {
        try await AuthSessionManager.shared.ensureValidSession()
        let token = try await supabase.auth.session.accessToken
        return try await invokeAction(
            functionName: "approve-marketplace-order",
            body: ["orderId": orderId.uuidString],
            accessToken: token
        )
    }

    /// Köparen trycker "Anmäl problem" → tvist öppnas.
    @discardableResult
    func disputeOrder(orderId: UUID, reason: String) async throws -> MarketplaceActionResult {
        try await AuthSessionManager.shared.ensureValidSession()
        let token = try await supabase.auth.session.accessToken
        return try await invokeAction(
            functionName: "dispute-marketplace-order",
            body: ["orderId": orderId.uuidString, "reason": reason],
            accessToken: token
        )
    }

    /// Köparen trycker "Avboka köp" innan paketet skickats.
    @discardableResult
    func cancelOrder(orderId: UUID) async throws -> MarketplaceActionResult {
        try await AuthSessionManager.shared.ensureValidSession()
        let token = try await supabase.auth.session.accessToken
        return try await invokeAction(
            functionName: "cancel-marketplace-order",
            body: ["orderId": orderId.uuidString],
            accessToken: token
        )
    }

    /// Admin-beslut i tvist. `decision` är ett av:
    /// `refund_buyer`, `release_seller`, `partial_refund`.
    /// `refundOre` krävs för partial_refund.
    @discardableResult
    func resolveDispute(
        orderId: UUID,
        decision: String,
        refundOre: Int? = nil,
        note: String? = nil
    ) async throws -> MarketplaceActionResult {
        try await AuthSessionManager.shared.ensureValidSession()
        let token = try await supabase.auth.session.accessToken
        var body: [String: Any] = [
            "orderId": orderId.uuidString,
            "decision": decision,
        ]
        if let refundOre { body["refundOre"] = refundOre }
        if let note, !note.isEmpty { body["note"] = note }
        return try await invokeAction(
            functionName: "resolve-marketplace-dispute",
            jsonBody: body,
            accessToken: token
        )
    }

    /// Calls `book-marketplace-shipping` as the seller (JWT); server allows seller or service role only.
    func retryBookMarketplaceShipping(orderId: UUID) async throws {
        try await AuthSessionManager.shared.ensureValidSession()
        let token = try await supabase.auth.session.accessToken
        let url = URL(
            string: "\(SupabaseConfig.projectURL.absoluteString)/functions/v1/book-marketplace-shipping"
        )!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")
        request.httpBody = try JSONSerialization.data(withJSONObject: ["orderId": orderId.uuidString])

        let (data, response) = try await SupabaseConfig.urlSession.data(for: request)
        let http = response as? HTTPURLResponse
        struct BookResp: Decodable {
            let success: Bool
            let error: String?
            let alreadyBooked: Bool?
        }
        let decoded = try JSONDecoder().decode(BookResp.self, from: data)
        let code = http?.statusCode ?? 0
        if code == 403 || code == 401 {
            throw MarketplaceCheckoutError.apiError(decoded.error ?? "Ej behörig")
        }
        if !(200...299).contains(code) || !decoded.success {
            throw MarketplaceCheckoutError.apiError(decoded.error ?? "Kunde inte boka frakt")
        }
    }

    struct RefreshShipmondoLabelResult: Decodable {
        let success: Bool
        let hasLabel: Bool?
        let shipping_label_url: String?
        let tracking_number: String?
        let tracking_url: String?
        let qr_payload: String?
        let error: String?
    }

    /// Poll Shipmondo och ladda upp PDF till bucket om den saknas (säljare).
    @discardableResult
    func refreshShipmondoLabel(orderId: UUID) async throws -> RefreshShipmondoLabelResult {
        try await AuthSessionManager.shared.ensureValidSession()
        let token = try await supabase.auth.session.accessToken
        let url = URL(
            string: "\(SupabaseConfig.projectURL.absoluteString)/functions/v1/refresh-shipmondo-label"
        )!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")
        request.httpBody = try JSONSerialization.data(withJSONObject: ["orderId": orderId.uuidString])

        let (data, response) = try await SupabaseConfig.urlSession.data(for: request)
        let http = response as? HTTPURLResponse
        let decoded = try JSONDecoder().decode(RefreshShipmondoLabelResult.self, from: data)
        let code = http?.statusCode ?? 0
        if code == 403 || code == 401 {
            throw MarketplaceCheckoutError.apiError(decoded.error ?? "Ej behörig")
        }
        if !(200...299).contains(code) || !decoded.success {
            throw MarketplaceCheckoutError.apiError(decoded.error ?? "Kunde inte hämta fraktsedel")
        }
        return decoded
    }

    /// Säljare: "Jag har packat" — DM + `seller_packed_at`.
    func markOrderPacked(orderId: UUID) async throws -> MarketplaceActionResult {
        try await AuthSessionManager.shared.ensureValidSession()
        let token = try await supabase.auth.session.accessToken
        return try await invokeAction(
            functionName: "mark-marketplace-order-packed",
            jsonBody: ["orderId": orderId.uuidString],
            accessToken: token
        )
    }

    /// Säljare: manuellt "Markerad som skickad" om Shipmondo inte uppdaterat än.
    func markOrderShippedBySeller(orderId: UUID) async throws -> MarketplaceActionResult {
        try await AuthSessionManager.shared.ensureValidSession()
        let token = try await supabase.auth.session.accessToken
        return try await invokeAction(
            functionName: "mark-marketplace-order-shipped",
            jsonBody: ["orderId": orderId.uuidString],
            accessToken: token
        )
    }

    /// Admin: markera ordern som skickad (vid manuell hantering när automatisk fraktbokning inte används). Pingar köparen + sätter `shipped_at`.
    func markOrderShipped(
        orderId: UUID,
        trackingNumber: String?,
        trackingUrl: String?
    ) async throws -> MarketplaceActionResult {
        try await AuthSessionManager.shared.ensureValidSession()
        let token = try await supabase.auth.session.accessToken
        var body: [String: Any] = ["orderId": orderId.uuidString]
        if let trackingNumber, !trackingNumber.isEmpty {
            body["trackingNumber"] = trackingNumber
        }
        if let trackingUrl, !trackingUrl.isEmpty {
            body["trackingUrl"] = trackingUrl
        }
        return try await invokeAction(
            functionName: "admin-mark-order-shipped",
            jsonBody: body,
            accessToken: token
        )
    }

    private func invokeAction(
        functionName: String,
        body: [String: String],
        accessToken: String
    ) async throws -> MarketplaceActionResult {
        try await invokeAction(
            functionName: functionName,
            jsonBody: body,
            accessToken: accessToken
        )
    }

    private func invokeAction(
        functionName: String,
        jsonBody: [String: Any],
        accessToken: String
    ) async throws -> MarketplaceActionResult {
        let url = URL(
            string: "\(SupabaseConfig.projectURL.absoluteString)/functions/v1/\(functionName)"
        )!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")
        request.httpBody = try JSONSerialization.data(withJSONObject: jsonBody)

        let (data, _) = try await SupabaseConfig.urlSession.data(for: request)
        struct Response: Decodable {
            let success: Bool
            let error: String?
            let releasePending: Bool?
            let released: Bool?
            let alreadyReleased: Bool?
            let alreadyOpen: Bool?
        }
        let decoded = try JSONDecoder().decode(Response.self, from: data)
        if !decoded.success {
            throw MarketplaceCheckoutError.apiError(decoded.error ?? "Okänt fel")
        }
        return MarketplaceActionResult(
            released: decoded.released ?? decoded.alreadyReleased ?? false,
            releasePending: decoded.releasePending ?? false
        )
    }
}

struct MarketplaceActionResult {
    let released: Bool
    let releasePending: Bool
}
