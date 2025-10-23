import Foundation
import Supabase

class PurchaseService: ObservableObject {
    static let shared = PurchaseService()
    private let supabase = SupabaseConfig.supabase
    
    @Published var purchases: [Purchase] = []
    
    private init() {}
    
    func savePurchase(_ purchase: Purchase) async throws {
        do {
            _ = try await supabase
                .from("purchases")
                .insert(purchase)
                .execute()
            print("✅ Purchase saved: \(purchase.id)")
            
            // Add to local array
            DispatchQueue.main.async {
                self.purchases.append(purchase)
            }
        } catch {
            print("❌ Error saving purchase: \(error)")
            throw error
        }
    }
    
    func fetchUserPurchases(userId: String) async throws -> [Purchase] {
        do {
            let purchases: [Purchase] = try await supabase
                .from("purchases")
                .select()
                .eq("user_id", value: userId)
                .order("created_at", ascending: false)
                .execute()
                .value
            
            print("✅ Fetched \(purchases.count) purchases for user \(userId)")
            
            DispatchQueue.main.async {
                self.purchases = purchases
            }
            
            return purchases
        } catch {
            print("❌ Error fetching purchases: \(error)")
            return []
        }
    }
    
    // For demo purposes - add mock purchases
    func addMockPurchase(reward: RewardCard, userId: String) {
        let purchase = Purchase(
            userId: userId,
            brandName: reward.brandName,
            discount: reward.discount,
            discountCode: getDiscountCode(for: reward.brandName),
            purchaseDate: Date()
        )
        
        DispatchQueue.main.async {
            self.purchases.insert(purchase, at: 0) // Add to beginning
        }
    }
    
    private func getDiscountCode(for brandName: String) -> String {
        switch brandName {
        case "PLIKTGOLF":
            return "PLIKT2025"
        case "PEGMATE":
            return "PEGMATE2025"
        case "LONEGOLF":
            return "LONE2025"
        case "WINWIZE":
            return "WINWIZE2025"
        case "SCANDIGOLF":
            return "SCANDI2025"
        case "Exotic Golf":
            return "EXOTIC2025"
        case "HAPPYALBA":
            return "HAPPY2025"
        case "RETROGOLF":
            return "RETRO2025"
        case "PUMPLABS":
            return "PUMP2025"
        case "ZEN ENERGY":
            return "ZEN2025"
        default:
            return "CODE2025"
        }
    }
}
