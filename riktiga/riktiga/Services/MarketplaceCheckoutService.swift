import Foundation

/// Buyer-side service that creates a Stripe PaymentIntent for a community listing
/// purchase via the `create-marketplace-payment-intent` edge function.
final class MarketplaceCheckoutService {

    static let shared = MarketplaceCheckoutService()
    private init() {}

    // MARK: - Types

    struct ShippingAddress: Codable, Equatable {
        var name: String
        var address: String
        var postal: String
        var city: String
    }

    struct PriceBreakdown: Codable {
        let itemOre: Int
        let platformFeeOre: Int
        let shippingFeeOre: Int?
        let buyerTotalOre: Int
        let sellerPayoutOre: Int
        let currency: String
        let isHeld: Bool

        var itemSEK: Double { Double(itemOre) / 100.0 }
        var platformFeeSEK: Double { Double(platformFeeOre) / 100.0 }
        var shippingFeeSEK: Double { Double(shippingFeeOre ?? 0) / 100.0 }
        var buyerTotalSEK: Double { Double(buyerTotalOre) / 100.0 }
        var sellerPayoutSEK: Double { Double(sellerPayoutOre) / 100.0 }
    }

    struct CheckoutSheet {
        let paymentIntentClientSecret: String
        let ephemeralKey: String
        let customerId: String
        let publishableKey: String
        let breakdown: PriceBreakdown
        let orderId: String
    }

    // MARK: - API

    func createPaymentIntent(
        listingId: UUID,
        shipping: ShippingAddress,
        buyerEmail: String,
        accessToken: String,
        buyerPhone: String? = nil,
        shippingCarrier: String? = nil,
        shippingServiceCode: String? = nil,
        shippingProductName: String? = nil,
        shippingAmountOre: Int? = nil,
        shippingBookingToken: String? = nil,
        shippingServicePointToken: String? = nil,
        shippingServicePointName: String? = nil,
        shippingServicePointAddress: String? = nil
    ) async throws -> CheckoutSheet {
        let url = URL(string: "\(SupabaseConfig.projectURL.absoluteString)/functions/v1/create-marketplace-payment-intent")!

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")

        var body: [String: Any] = [
            "listingId": listingId.uuidString,
            "shipping": [
                "name": shipping.name,
                "address": shipping.address,
                "postal": shipping.postal,
                "city": shipping.city
            ],
            "buyerEmail": buyerEmail
        ]
        if let buyerPhone, !buyerPhone.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            body["buyerPhone"] = buyerPhone.trimmingCharacters(in: .whitespacesAndNewlines)
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
            let paymentIntent: String?
            let ephemeralKey: String?
            let customer: String?
            let publishableKey: String?
            let breakdown: PriceBreakdown?
            let orderId: String?
            let error: String?
        }

        let decoded = try JSONDecoder().decode(Response.self, from: data)

        if !decoded.success {
            throw MarketplaceCheckoutError.apiError(decoded.error ?? "Unknown error")
        }

        guard let paymentIntent = decoded.paymentIntent,
              let ephemeralKey = decoded.ephemeralKey,
              let customer = decoded.customer,
              let publishableKey = decoded.publishableKey,
              let breakdown = decoded.breakdown,
              let orderId = decoded.orderId else {
            throw MarketplaceCheckoutError.invalidResponse
        }

        return CheckoutSheet(
            paymentIntentClientSecret: paymentIntent,
            ephemeralKey: ephemeralKey,
            customerId: customer,
            publishableKey: publishableKey,
            breakdown: breakdown,
            orderId: orderId
        )
    }
}

enum MarketplaceCheckoutError: LocalizedError {
    case invalidResponse
    case apiError(String)
    case notAuthenticated

    var errorDescription: String? {
        switch self {
        case .invalidResponse: return "Ogiltigt svar från betalningsservern"
        case .apiError(let msg): return msg
        case .notAuthenticated: return "Du måste vara inloggad för att köpa"
        }
    }
}
