import Foundation
import RevenueCat
import Combine
import Supabase

class RevenueCatManager: NSObject, ObservableObject {
    static let shared = RevenueCatManager()
    
    @Published var customerInfo: CustomerInfo?
    @Published var offerings: Offerings?
    @Published var isPremium: Bool = false
    @Published var isLoading: Bool = false
    @Published var errorMessage: String = ""
    
    // Product identifiers - these should match your App Store Connect configuration
    private let premiumProductId = "monthly"
    private let annualProductId = "yearly"
    
    private override init() {
        super.init()
        configureRevenueCat()
    }
    
    private func configureRevenueCat() {
        // Configure RevenueCat with your API key
        Purchases.configure(withAPIKey: "appl_DkqriHJdDtfgXAnntgkijgAqdbN")
        
        // Set up delegate
        Purchases.shared.delegate = self
        
        // Load initial data
        Task {
            await loadCustomerInfo()
            await loadOfferings()
        }
    }
    
    // MARK: - Customer Info
    @MainActor
    func loadCustomerInfo() async {
        isLoading = true
        errorMessage = ""
        
        do {
            let customerInfo = try await Purchases.shared.customerInfo()
            self.customerInfo = customerInfo
            self.isPremium = customerInfo.entitlements["premium"]?.isActive == true
            print("✅ Customer info loaded. Premium: \(isPremium)")
        } catch {
            self.errorMessage = "Failed to load customer info: \(error.localizedDescription)"
            print("❌ Error loading customer info: \(error)")
        }
        
        isLoading = false
    }
    
    // MARK: - Offerings
    @MainActor
    func loadOfferings() async {
        do {
            let offerings = try await Purchases.shared.offerings()
            self.offerings = offerings
            print("✅ Offerings loaded: \(offerings.all.count) packages")
        } catch {
            self.errorMessage = "Failed to load offerings: \(error.localizedDescription)"
            print("❌ Error loading offerings: \(error)")
        }
    }
    
    // MARK: - Purchase Methods
    @MainActor
    func purchasePackage(_ package: Package) async -> Bool {
        isLoading = true
        errorMessage = ""
        
        do {
            let result = try await Purchases.shared.purchase(package: package)
            
            if !result.userCancelled {
                self.customerInfo = result.customerInfo
                self.isPremium = result.customerInfo.entitlements["premium"]?.isActive == true
                
                // Update Pro status in database
                if self.isPremium {
                    await updateProStatusInDatabase(isPro: true)
                }
                
                print("✅ Purchase successful: \(package.storeProduct.productIdentifier)")
                return true
            } else {
                print("ℹ️ Purchase cancelled by user")
                return false
            }
        } catch {
            self.errorMessage = "Purchase failed: \(error.localizedDescription)"
            print("❌ Purchase error: \(error)")
            return false
        }
        
        isLoading = false
    }
    
    @MainActor
    func purchaseProduct(_ productId: String) async -> Bool {
        isLoading = true
        errorMessage = ""
        
        do {
            // First get the product from offerings
            guard let offerings = offerings,
                  let product = offerings.all.values.flatMap({ $0.availablePackages }).first(where: { $0.storeProduct.productIdentifier == productId }) else {
                self.errorMessage = "Product not found: \(productId)"
                self.isLoading = false
                return false
            }
            
            let result = try await Purchases.shared.purchase(package: product)
            
            if !result.userCancelled {
                self.customerInfo = result.customerInfo
                self.isPremium = result.customerInfo.entitlements["premium"]?.isActive == true
                print("✅ Purchase successful: \(productId)")
                return true
            } else {
                print("ℹ️ Purchase cancelled by user")
                return false
            }
        } catch {
            self.errorMessage = "Purchase failed: \(error.localizedDescription)"
            print("❌ Purchase error: \(error)")
            return false
        }
        
        isLoading = false
    }
    
    // MARK: - Restore Purchases
    @MainActor
    func restorePurchases() async -> Bool {
        isLoading = true
        errorMessage = ""
        
        do {
            let customerInfo = try await Purchases.shared.restorePurchases()
            self.customerInfo = customerInfo
            self.isPremium = customerInfo.entitlements["premium"]?.isActive == true
            print("✅ Purchases restored successfully")
            return true
        } catch {
            self.errorMessage = "Restore failed: \(error.localizedDescription)"
            print("❌ Restore error: \(error)")
            return false
        }
        
        isLoading = false
    }
    
    // MARK: - Check Purchase Status
    func checkPurchaseStatus() -> Bool {
        return customerInfo?.entitlements["premium"]?.isActive == true
    }
    
    // MARK: - Get Product Price
    func getProductPrice(for productId: String) -> String? {
        guard let offerings = offerings else { return nil }
        
        for offering in offerings.all.values {
            for package in offering.availablePackages {
                if package.storeProduct.productIdentifier == productId {
                    return package.localizedPriceString
                }
            }
        }
        
        return nil
    }
    
    // MARK: - Get Package for Product
    func getPackage(for productId: String) -> Package? {
        guard let offerings = offerings else { return nil }
        
        for offering in offerings.all.values {
            for package in offering.availablePackages {
                if package.storeProduct.productIdentifier == productId {
                    return package
                }
            }
        }
        
        return nil
    }
    
    // MARK: - Database Updates
    private func updateProStatusInDatabase(isPro: Bool) async {
        // Get current user ID from AuthViewModel or similar
        // For now, we'll need to get this from the current session
        do {
            let session = try await SupabaseConfig.supabase.auth.session
            let userId = session.user.id.uuidString
            
            try await ProfileService.shared.updateProStatus(userId: userId, isPro: isPro)
            print("✅ Pro status updated in database: \(isPro)")
        } catch {
            print("❌ Error updating Pro status in database: \(error)")
        }
    }
}

// MARK: - PurchasesDelegate
extension RevenueCatManager: PurchasesDelegate {
    func purchases(_ purchases: Purchases, receivedUpdated customerInfo: CustomerInfo) {
        DispatchQueue.main.async {
            self.customerInfo = customerInfo
            self.isPremium = customerInfo.entitlements["premium"]?.isActive == true
            print("🔄 Customer info updated. Premium: \(self.isPremium)")
            
            // Update Pro status in database when subscription changes
            Task {
                await self.updateProStatusInDatabase(isPro: self.isPremium)
            }
        }
    }
}
