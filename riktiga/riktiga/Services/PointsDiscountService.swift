import Foundation
import Supabase

struct DiscountTier: Identifiable {
    let id = UUID()
    let xpCost: Int
    let freePercent: Int
    let proPercent: Int

    func percent(isPro: Bool) -> Int {
        isPro ? proPercent : freePercent
    }

    func label(isPro: Bool) -> String {
        "\(percent(isPro: isPro))% rabatt"
    }
}

struct DiscountResult: Decodable {
    let code: String
    let percent: Int
}

class PointsDiscountService {
    static let shared = PointsDiscountService()

    static let tiers: [DiscountTier] = [
        DiscountTier(xpCost: 200, freePercent: 5, proPercent: 10),
        DiscountTier(xpCost: 500, freePercent: 10, proPercent: 20),
        DiscountTier(xpCost: 1000, freePercent: 25, proPercent: 40),
    ]

    private let supabase = SupabaseConfig.supabase

    private init() {}

    func availableTiers(currentXP: Int) -> [DiscountTier] {
        Self.tiers.filter { currentXP >= $0.xpCost }
    }

    func redeemDiscount(userId: String, tier: DiscountTier, isPro: Bool) async throws -> DiscountResult {
        struct RequestBody: Encodable {
            let userId: String
            let xpCost: Int
            let percent: Int
        }

        let percent = tier.percent(isPro: isPro)
        let body = RequestBody(userId: userId, xpCost: tier.xpCost, percent: percent)

        let result: DiscountResult = try await supabase.functions.invoke(
            "create-points-discount",
            options: FunctionInvokeOptions(body: body)
        )

        return result
    }
}
