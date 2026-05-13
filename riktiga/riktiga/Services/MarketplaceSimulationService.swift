import Foundation
import Supabase

struct SimulatedPurchaseResult: Decodable {
    let success: Bool
    let orderId: String
    let conversationId: String?
    let bookedShipping: Bool
    let replaySecondPassSkipped: Bool?

    enum CodingKeys: String, CodingKey {
        case success
        case orderId
        case conversationId
        case bookedShipping
        case replaySecondPassSkipped
    }
}

@MainActor
final class MarketplaceSimulationService {
    static let shared = MarketplaceSimulationService()

    private let supabase = SupabaseConfig.supabase

    private init() {}

    struct DeadlineSweepResult: Decodable {
        let success: Bool
        let shipReminders: Int?
        let shipReminders48h: Int?
        let autoCancelled: Int?
        let autoReleased: Int?
        let errors: Int?
        let includeTestOrders: Bool?
        let error: String?
    }

    func simulatePurchase(listingId: UUID, bookShipping: Bool = true, replay: Bool = false) async throws -> SimulatedPurchaseResult {
        struct RequestBody: Encodable {
            let listing_id: String
            let book_shipping: Bool
            let replay: Bool
        }

        let body = RequestBody(
            listing_id: listingId.uuidString.lowercased(),
            book_shipping: bookShipping,
            replay: replay
        )

        return try await supabase.functions.invoke(
            "simulate-marketplace-purchase",
            options: FunctionInvokeOptions(body: body)
        )
    }

    func runDeadlineSweep(limit: Int = 200, includeTestOrders: Bool = true) async throws -> DeadlineSweepResult {
        struct RequestBody: Encodable {
            let limit: Int
            let bypass_is_test: Bool
        }
        let body = RequestBody(limit: limit, bypass_is_test: includeTestOrders)
        return try await supabase.functions.invoke(
            "process-marketplace-deadlines",
            options: FunctionInvokeOptions(body: body)
        )
    }
}
