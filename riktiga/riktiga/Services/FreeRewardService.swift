import Foundation
import Supabase
import Combine

// MARK: - Models

/// En intjänad (ej inlöst) gratisprodukt-belöning.
struct EarnedFreeReward: Decodable, Identifiable {
    let id: String
    let status: String
    let earnedAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case status
        case earnedAt = "earned_at"
    }
}

/// Aktuell status för Pro Free Product Reward-systemet.
struct FreeRewardStatus {
    let isPro: Bool
    let daysRemaining: Int?       // dagar kvar till nästa gratisprodukt (nil om ingen aktiv period)
    let earnedRewards: [EarnedFreeReward]

    var hasEarnedReward: Bool { !earnedRewards.isEmpty }

    /// 0...1 progress genom nuvarande 3-månadersperiod.
    var periodProgress: Double {
        guard let days = daysRemaining else { return 0 }
        let total = 90.0
        return min(max((total - Double(days)) / total, 0), 1)
    }
}

// MARK: - Service

/// Pro-medlemmar tjänar en gratisprodukt från Vår shop var 3:e sammanhängande Pro-månad.
/// Status synkas via `sync_free_reward_progress`-RPC:n och inlösen sker via
/// edge-funktionen `redeem-free-reward` som skapar en produktspecifik 100%-kod
/// (frakt ingår inte) och markerar rewarden som redeemed atomiskt.
@MainActor
final class FreeRewardService: ObservableObject {
    static let shared = FreeRewardService()

    static let eligibleTag = "free_reward_eligible"

    @Published private(set) var status: FreeRewardStatus?
    @Published private(set) var maxRewardCost: Int = 500

    private let supabase = SupabaseConfig.supabase
    private init() {}

    // MARK: - Status

    /// Synkar progress server-side och hämtar aktuell status + intjänade rewards.
    func syncAndFetchStatus() async {
        do {
            struct SyncRow: Decodable {
                let isPro: Bool
                let daysRemaining: Int?

                enum CodingKeys: String, CodingKey {
                    case isPro = "is_pro"
                    case daysRemaining = "days_remaining"
                }
            }

            let rows: [SyncRow] = try await supabase.database
                .rpc("sync_free_reward_progress")
                .execute()
                .value

            guard let row = rows.first else { return }

            let rewards: [EarnedFreeReward] = try await supabase
                .from("free_product_rewards")
                .select("id, status, earned_at")
                .eq("status", value: "earned")
                .order("earned_at", ascending: true)
                .execute()
                .value

            status = FreeRewardStatus(
                isPro: row.isPro,
                daysRemaining: row.daysRemaining,
                earnedRewards: rewards
            )

            await fetchMaxRewardCost()
        } catch {
            print("[FreeRewardService] Failed to sync status: \(error)")
        }
    }

    private func fetchMaxRewardCost() async {
        struct ConfigRow: Decodable {
            let maxRewardCost: Int?
            enum CodingKeys: String, CodingKey {
                case maxRewardCost = "max_reward_cost"
            }
        }

        do {
            let rows: [ConfigRow] = try await supabase
                .from("app_config")
                .select("max_reward_cost")
                .limit(1)
                .execute()
                .value
            if let cost = rows.first?.maxRewardCost {
                maxRewardCost = cost
            }
        } catch {
            print("[FreeRewardService] Failed to fetch max_reward_cost: \(error)")
        }
    }

    // MARK: - Eligibility

    /// En produkt kan väljas gratis om den är taggad `free_reward_eligible`
    /// och priset ligger inom kostnadstaket.
    func isEligible(_ product: ShopifyProduct) -> Bool {
        let tags = product.tags.map { $0.lowercased() }
        guard tags.contains(Self.eligibleTag) else { return false }
        let price = Double(product.minPrice) ?? 0
        return price <= Double(maxRewardCost)
    }

    // MARK: - Redemption

    struct RedeemResult: Decodable {
        let code: String
    }

    /// Löser in användarens äldsta intjänade reward mot en produkt.
    /// Returnerar 100%-rabattkoden som ska appliceras på en cart.
    func redeem(product: ShopifyProduct) async throws -> RedeemResult {
        guard let reward = status?.earnedRewards.first else {
            throw NSError(domain: "FreeReward", code: 1, userInfo: [
                NSLocalizedDescriptionKey: L.t(sv: "Ingen belöning att lösa in.", nb: "Ingen belønning å løse inn.")
            ])
        }

        let session = try await SupabaseConfig.supabase.auth.session
        let userId = session.user.id.uuidString

        struct RequestBody: Encodable {
            let userId: String
            let rewardId: String
            let productId: String
            let productTitle: String
            let productPrice: Double
        }

        let body = RequestBody(
            userId: userId,
            rewardId: reward.id,
            productId: product.id,
            productTitle: product.title,
            productPrice: Double(product.minPrice) ?? 0
        )

        let result: RedeemResult = try await supabase.functions.invoke(
            "redeem-free-reward",
            options: FunctionInvokeOptions(body: body)
        )

        // Uppdatera lokal status så rewarden inte kan användas igen i UI:t
        await syncAndFetchStatus()

        return result
    }
}
