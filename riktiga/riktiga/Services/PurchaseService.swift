import Foundation
import Combine
import Supabase
import RevenueCat

class PurchaseService: ObservableObject {
    static let shared = PurchaseService()
    private let supabase = SupabaseConfig.supabase
    private let revenueCatManager = RevenueCatManager.shared
    
    @Published var purchases: [Purchase] = []
    @Published var isPremium: Bool = false
    @Published var isLoading: Bool = false
    
    private init() {
        // Listen to RevenueCat updates
        revenueCatManager.$isPremium
            .assign(to: &$isPremium)
        
        revenueCatManager.$isLoading
            .assign(to: &$isLoading)
    }
    
    // MARK: - RevenueCat Integration
    func purchaseReward(_ reward: RewardCard, userId: String) async throws -> Bool {
        print("🔄 PurchaseService: Starting reward purchase for \(reward.brandName)")
        
        // Proceed with reward purchase (no PRO membership required)
        let purchase = Purchase(
            userId: userId,
            brandName: reward.brandName,
            discount: reward.discount,
            discountCode: getDiscountCode(for: reward.brandName),
            purchaseDate: Date()
        )
        
        print("🔄 PurchaseService: Created purchase object: \(purchase.id)")
        
        try await savePurchase(purchase)
        print("✅ PurchaseService: Purchase saved successfully")
        
        return true
    }
    
    func purchasePremiumSubscription() async -> Bool {
        // Try to purchase premium subscription through RevenueCat
        guard let offerings = revenueCatManager.offerings,
              let currentOffering = offerings.current else {
            print("❌ No current offering available")
            return false
        }
        
        // Try to find monthly package first, then annual
        if let monthlyPackage = currentOffering.monthly {
            return await revenueCatManager.purchasePackage(monthlyPackage)
        } else if let annualPackage = currentOffering.annual {
            return await revenueCatManager.purchasePackage(annualPackage)
        } else if let firstPackage = currentOffering.availablePackages.first {
            return await revenueCatManager.purchasePackage(firstPackage)
        }
        
        return false
    }
    
    func restorePurchases() async -> Bool {
        return await revenueCatManager.restorePurchases()
    }
    
    func checkPremiumStatus() {
        isPremium = revenueCatManager.checkPurchaseStatus()
    }
    
    // MARK: - Legacy Methods (for backward compatibility)
    func savePurchase(_ purchase: Purchase) async throws {
        print("🔄 SavePurchase: Starting to save purchase \(purchase.id)")
        
        do {
            print("🔄 SavePurchase: Inserting into Supabase...")
            _ = try await supabase
                .from("purchases")
                .insert(purchase)
                .execute()
            print("✅ SavePurchase: Purchase saved to database: \(purchase.id)")
            
            // Add to local array
            DispatchQueue.main.async {
                self.purchases.append(purchase)
                print("✅ SavePurchase: Added to local array")
            }
        } catch {
            print("❌ SavePurchase: Error saving purchase: \(error)")
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
    func addMockPurchase(brandName: String, discount: String, userId: String) {
        let purchase = Purchase(
            userId: userId,
            brandName: brandName,
            discount: discount,
            discountCode: getDiscountCode(for: brandName),
            purchaseDate: Date()
        )
        
        DispatchQueue.main.async {
            self.purchases.insert(purchase, at: 0) // Add to beginning
        }
    }
    
    private func getDiscountCode(for brandName: String) -> String {
        switch brandName {
        case "PLIKTGOLF":
            return "T59W1DH7B81J"
        case "PEGMATE":
            return "Pegmate2026"
        case "LONEGOLF":
            return "UP&DOWN_10"
        case "WINWIZE":
            return "9AEWBGBZV5HR"
        case "SCANDIGOLF":
            return "A0Z8JNnsE"
        case "Exotic Golf":
            return "upanddown15"
        case "HAPPYALBA":
            return "HAPPY2025"
        case "RETROGOLF":
            return "Upanddown20"
        case "PUMPLABS":
            return "UPNDOWN15"
        case "ZEN ENERGY":
            return "UPDOWN15"
        default:
            return "CODE2025"
        }
    }
}
