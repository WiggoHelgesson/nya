import Foundation
import Supabase

/// iOS-side client for the Shipmondo-backed shipping integration (via Supabase edge functions).
///
/// Surfaces:
///   - `fetchRates(...)` — buyer-side carrier picker in the price-offer modal.
///   - `fetchSellerPickupAddress()` — seller-side check before accepting an offer.
///   - `saveSellerPickupAddress(...)` — saves the address to
///     `public.seller_pickup_addresses` so `book-marketplace-shipping` can
///     send packages from it.
///
/// All HTTP calls go through the user's Supabase access token so RLS
/// policies on `seller_pickup_addresses` apply.
final class ShipmondoShippingService {

    static let shared = ShipmondoShippingService()
    private init() {}

    private var supabase: SupabaseClient { SupabaseConfig.supabase }

    // MARK: - Rate model

    struct Rate: Decodable, Identifiable {
        let carrier: String
        let carrierName: String?
        let productName: String?
        let serviceCode: String
        let name: String
        let priceOre: Int
        let etaText: String
        let qrSupported: Bool
        let requiresServicePoint: Bool
        let bookingToken: String
        let shipmentId: String

        var id: String { "\(carrier)-\(serviceCode)" }

        enum CodingKeys: String, CodingKey {
            case carrier
            case carrierName
            case productName
            case serviceCode
            case name
            case priceOre
            case etaText
            case qrSupported
            case requiresServicePoint
            case bookingToken
            case shipmentId
        }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            self.carrier = try c.decode(String.self, forKey: .carrier)
            self.carrierName = try? c.decode(String.self, forKey: .carrierName)
            self.productName = try? c.decode(String.self, forKey: .productName)
            self.serviceCode = try c.decode(String.self, forKey: .serviceCode)
            self.name = try c.decode(String.self, forKey: .name)
            self.priceOre = try c.decode(Int.self, forKey: .priceOre)
            self.etaText = try c.decode(String.self, forKey: .etaText)
            self.qrSupported = (try? c.decode(Bool.self, forKey: .qrSupported)) ?? false
            self.requiresServicePoint = (try? c.decode(Bool.self, forKey: .requiresServicePoint)) ?? false
            self.bookingToken = (try? c.decode(String.self, forKey: .bookingToken)) ?? ""
            self.shipmentId = (try? c.decode(String.self, forKey: .shipmentId)) ?? ""
        }
    }

    private struct RatesResponse: Decodable {
        let success: Bool
        let rates: [Rate]?
        let error: String?
    }

    // MARK: - Service-point model

    struct ServicePoint: Decodable, Identifiable {
        let token: String
        let name: String
        let carrier: String
        let addressLine: String
        let postalCode: String
        let city: String
        let country: String
        let distanceMeters: Int

        var id: String { token }

        enum CodingKeys: String, CodingKey {
            case token, name, carrier, addressLine, postalCode, city, country, distanceMeters
        }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            self.token = try c.decode(String.self, forKey: .token)
            self.name = try c.decode(String.self, forKey: .name)
            self.carrier = try c.decode(String.self, forKey: .carrier)
            self.addressLine = (try? c.decode(String.self, forKey: .addressLine)) ?? ""
            self.postalCode = (try? c.decode(String.self, forKey: .postalCode)) ?? ""
            self.city = (try? c.decode(String.self, forKey: .city)) ?? ""
            self.country = (try? c.decode(String.self, forKey: .country)) ?? "SE"
            if let n = try? c.decode(Int.self, forKey: .distanceMeters) {
                self.distanceMeters = n
            } else if let d = try? c.decode(Double.self, forKey: .distanceMeters) {
                self.distanceMeters = Int(d)
            } else {
                self.distanceMeters = 0
            }
        }
    }

    private struct ServicePointsResponse: Decodable {
        let success: Bool
        let servicePoints: [ServicePoint]?
        let error: String?
    }

    // MARK: - Buyer: rate quotes

    func fetchRates(
        listingId: UUID,
        buyerPostal: String,
        buyerCity: String,
        accessToken: String
    ) async throws -> [Rate] {
        let url = URL(string: "\(SupabaseConfig.projectURL.absoluteString)/functions/v1/get-marketplace-shipping-rates")!

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")

        let body: [String: Any] = [
            "listingId": listingId.uuidString,
            "buyerPostal": buyerPostal,
            "buyerCity": buyerCity
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, _) = try await SupabaseConfig.urlSession.data(for: request)

        let decoded = try JSONDecoder().decode(RatesResponse.self, from: data)
        if !decoded.success {
            throw NSError(
                domain: "Shipmondo",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: decoded.error ?? "Kunde inte hämta fraktpriser"]
            )
        }
        return decoded.rates ?? []
    }

    // MARK: - Buyer: service-point picker (ombud)

    func fetchServicePoints(
        carrier: String,
        addressLine: String,
        postalCode: String,
        city: String,
        accessToken: String,
        limit: Int = 8
    ) async throws -> [ServicePoint] {
        let url = URL(string: "\(SupabaseConfig.projectURL.absoluteString)/functions/v1/list-marketplace-service-points")!

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")

        let body: [String: Any] = [
            "carrier": carrier,
            "addressLine": addressLine,
            "postalCode": postalCode,
            "city": city,
            "limit": limit
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, _) = try await SupabaseConfig.urlSession.data(for: request)

        let decoded = try JSONDecoder().decode(ServicePointsResponse.self, from: data)
        if !decoded.success {
            throw NSError(
                domain: "Shipmondo",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: decoded.error ?? "Kunde inte hämta ombud"]
            )
        }
        return decoded.servicePoints ?? []
    }

    // MARK: - Seller: pickup address

    private struct PickupRow: Codable {
        let userId: UUID
        let fullName: String
        let phone: String
        let street: String
        let postalCode: String
        let city: String
        let country: String
        let updatedAt: String?

        enum CodingKeys: String, CodingKey {
            case userId = "user_id"
            case fullName = "full_name"
            case phone
            case street
            case postalCode = "postal_code"
            case city
            case country
            case updatedAt = "updated_at"
        }
    }

    func fetchSellerPickupAddress() async throws -> ShippingAddress? {
        try await AuthSessionManager.shared.ensureValidSession()
        let session = try await supabase.auth.session
        let uid = session.user.id

        let rows: [PickupRow] = try await supabase
            .from("seller_pickup_addresses")
            .select()
            .eq("user_id", value: uid.uuidString)
            .limit(1)
            .execute()
            .value

        guard let row = rows.first else { return nil }
        return ShippingAddress(
            fullName: row.fullName,
            phone: row.phone,
            street: row.street,
            postalCode: row.postalCode,
            city: row.city,
            country: row.country
        )
    }

    func saveSellerPickupAddress(_ address: ShippingAddress) async throws {
        try await AuthSessionManager.shared.ensureValidSession()
        let session = try await supabase.auth.session
        let uid = session.user.id

        struct UpsertPayload: Encodable {
            let user_id: String
            let full_name: String
            let phone: String
            let street: String
            let postal_code: String
            let city: String
            let country: String
            let updated_at: String
        }

        let payload = UpsertPayload(
            user_id: uid.uuidString,
            full_name: address.fullName,
            phone: address.phone,
            street: address.street,
            postal_code: address.postalCode,
            city: address.city,
            country: address.country.isEmpty ? "SE" : address.country,
            updated_at: ISO8601DateFormatter().string(from: Date())
        )

        try await supabase
            .from("seller_pickup_addresses")
            .upsert(payload, onConflict: "user_id")
            .execute()
    }
}
