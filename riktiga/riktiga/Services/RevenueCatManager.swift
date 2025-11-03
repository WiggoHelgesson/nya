import Foundation
import RevenueCat
import Combine
import Supabase

class RevenueCatManager: NSObject, ObservableObject {
    static let shared = RevenueCatManager()
    
    @Published var customerInfo: CustomerInfo?
    @Published var offerings: Offerings?
    @Published var isPremium: Bool = false
    @Published var activeEntitlementId: String? = nil
    @Published var activeExpirationDate: Date? = nil
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
    func loadCustomerInfo() async {
        await MainActor.run {
            isLoading = true
            errorMessage = ""
        }
        
        do {
            let customerInfo = try await Purchases.shared.customerInfo()
            await MainActor.run {
                self.customerInfo = customerInfo
                if let firstActive = customerInfo.entitlements.active.values.first {
                    self.isPremium = true
                    self.activeEntitlementId = firstActive.identifier
                    self.activeExpirationDate = firstActive.expirationDate
                } else {
                    self.isPremium = false
                    self.activeEntitlementId = nil
                    self.activeExpirationDate = nil
                }
                self.isLoading = false
                print("✅ Customer info loaded. Premium: \(self.isPremium) id: \(self.activeEntitlementId ?? "-")")
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to load customer info: \(error.localizedDescription)"
                self.isLoading = false
                print("❌ Error loading customer info: \(error)")
            }
        }
    }
    
    // MARK: - Offerings
    func loadOfferings() async {
        do {
            let offerings = try await Purchases.shared.offerings()
            await MainActor.run {
                self.offerings = offerings
                print("✅ Offerings loaded: \(offerings.all.count) packages")
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to load offerings: \(error.localizedDescription)"
                print("❌ Error loading offerings: \(error)")
            }
        }
    }
    
    // MARK: - Purchase Methods
    func purchasePackage(_ package: Package) async -> Bool {
        await MainActor.run {
            isLoading = true
            errorMessage = ""
        }
        
        do {
            let result = try await Purchases.shared.purchase(package: package)
            
            if !result.userCancelled {
                await self.applyCustomerInfo(result.customerInfo)
                
                // Update Pro status in database
                if self.isPremium {
                    await updateProStatusInDatabase(isPro: true)
                }
                
                print("✅ Purchase successful: \(package.storeProduct.productIdentifier)")
                
                await MainActor.run {
                    isLoading = false
                }
                return true
            } else {
                print("ℹ️ Purchase cancelled by user")
                await MainActor.run {
                    isLoading = false
                }
                return false
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "Purchase failed: \(error.localizedDescription)"
                self.isLoading = false
            }
            print("❌ Purchase error: \(error)")
            return false
        }
    }
    
    func purchaseProduct(_ productId: String) async -> Bool {
        await MainActor.run {
            isLoading = true
            errorMessage = ""
        }
        
        do {
            // First get the product from offerings
            guard let offerings = offerings,
                  let product = offerings.all.values.flatMap({ $0.availablePackages }).first(where: { $0.storeProduct.productIdentifier == productId }) else {
                await MainActor.run {
                    self.errorMessage = "Product not found: \(productId)"
                    self.isLoading = false
                }
                return false
            }
            
            let result = try await Purchases.shared.purchase(package: product)
            
            if !result.userCancelled {
                await MainActor.run {
                    self.customerInfo = result.customerInfo
                    self.isPremium = result.customerInfo.entitlements["premium"]?.isActive == true
                    self.isLoading = false
                }
                print("✅ Purchase successful: \(productId)")
                return true
            } else {
                print("ℹ️ Purchase cancelled by user")
                await MainActor.run {
                    isLoading = false
                }
                return false
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "Purchase failed: \(error.localizedDescription)"
                isLoading = false
            }
            print("❌ Purchase error: \(error)")
            return false
        }
    }
    
    // MARK: - Restore Purchases
    func restorePurchases() async -> Bool {
        await MainActor.run {
            isLoading = true
            errorMessage = ""
        }
        
        do {
            let customerInfo = try await Purchases.shared.restorePurchases()
            await self.applyCustomerInfo(customerInfo)
            await MainActor.run { self.isLoading = false }
            print("✅ Purchases restored successfully")
            return true
        } catch {
            await MainActor.run {
                self.errorMessage = "Restore failed: \(error.localizedDescription)"
                self.isLoading = false
            }
            print("❌ Restore error: \(error)")
            return false
        }
    }
    
    // MARK: - Check Purchase Status
    func checkPurchaseStatus() -> Bool {
        return !(customerInfo?.entitlements.active.isEmpty ?? true)
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

    // MARK: - Helpers
    @MainActor
    private func applyCustomerInfo(_ info: CustomerInfo) async {
        self.customerInfo = info
        if let firstActive = info.entitlements.active.values.first {
            self.isPremium = true
            self.activeEntitlementId = firstActive.identifier
            self.activeExpirationDate = firstActive.expirationDate
        } else {
            self.isPremium = false
            self.activeEntitlementId = nil
            self.activeExpirationDate = nil
        }
    }

    func syncAndRefresh() async {
        await MainActor.run { self.isLoading = true }
        do {
            try await Purchases.shared.syncPurchases()
            let info = try await Purchases.shared.customerInfo()
            await self.applyCustomerInfo(info)
        } catch {
            await MainActor.run { self.errorMessage = error.localizedDescription }
        }
        await MainActor.run { self.isLoading = false }
    }

    // Bind RevenueCat purchases to our Supabase user id
    func logInFor(appUserId: String) async {
        do {
            let result = try await Purchases.shared.logIn(appUserId)
            await self.applyCustomerInfo(result.customerInfo)
            print("✅ RevenueCat logged in as appUserId=\(appUserId)")
        } catch {
            print("❌ RevenueCat logIn failed: \(error)")
        }
    }

    func logOutRevenueCat() async {
        do {
            _ = try await Purchases.shared.logOut()
            let info = try await Purchases.shared.customerInfo()
            await self.applyCustomerInfo(info)
            print("✅ RevenueCat logged out")
        } catch {
            print("❌ RevenueCat logOut failed: \(error)")
        }
    }
}

// MARK: - PurchasesDelegate
extension RevenueCatManager: PurchasesDelegate {
    func purchases(_ purchases: Purchases, receivedUpdated customerInfo: CustomerInfo) {
        DispatchQueue.main.async {
            self.customerInfo = customerInfo
            if let firstActive = customerInfo.entitlements.active.values.first {
                self.isPremium = true
                self.activeEntitlementId = firstActive.identifier
                self.activeExpirationDate = firstActive.expirationDate
            } else {
                self.isPremium = false
                self.activeEntitlementId = nil
                self.activeExpirationDate = nil
            }
            print("🔄 Customer info updated. Premium: \(self.isPremium) id: \(self.activeEntitlementId ?? "-")")
            
            // Update Pro status in database when subscription changes
            Task {
                await self.updateProStatusInDatabase(isPro: self.isPremium)
            }
        }
    }
}
