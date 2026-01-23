//
//  SuperwallPurchaseController.swift
//  Up&Down
//
//  Official Superwall + RevenueCat integration
//  Based on: https://superwall.com/docs/ios/guides/using-revenuecat
//

import SuperwallKit
import RevenueCat
import StoreKit

enum PurchasingError: LocalizedError {
    case sk2ProductNotFound
    
    var errorDescription: String? {
        switch self {
        case .sk2ProductNotFound:
            return "Superwall didn't pass a StoreKit 2 product to purchase. Are you sure you're not "
            + "configuring Superwall with a SuperwallOption to use StoreKit 1?"
        }
    }
}

final class RCPurchaseController: PurchaseController {
    
    // MARK: Sync Subscription Status
    /// Makes sure that Superwall knows the customer's entitlements by
    /// changing `Superwall.shared.subscriptionStatus`
    func syncSubscriptionStatus() {
        assert(Purchases.isConfigured, "You must configure RevenueCat before calling this method.")
        Task {
            for await customerInfo in Purchases.shared.customerInfoStream {
                // Gets called whenever new CustomerInfo is available
                let superwallEntitlements = customerInfo.entitlements.activeInCurrentEnvironment.keys.map {
                    Entitlement(id: $0)
                }
                await MainActor.run { [superwallEntitlements] in
                    if superwallEntitlements.isEmpty {
                        Superwall.shared.subscriptionStatus = .inactive
                        print("📊 Superwall subscriptionStatus synced: inactive")
                    } else {
                        Superwall.shared.subscriptionStatus = .active(Set(superwallEntitlements))
                        print("📊 Superwall subscriptionStatus synced: active with \(superwallEntitlements.count) entitlements")
                    }
                }
                
                // Also update RevenueCatManager
                await RevenueCatManager.shared.loadCustomerInfo()
            }
        }
    }
    
    // MARK: Handle Purchases
    /// Makes a purchase with RevenueCat and returns its result. This gets called when
    /// someone tries to purchase a product on one of your paywalls.
    func purchase(product: SuperwallKit.StoreProduct) async -> PurchaseResult {
        print("🛒 Superwall: Starting purchase for \(product.productIdentifier)")
        
        do {
            guard let sk2Product = product.sk2Product else {
                throw PurchasingError.sk2ProductNotFound
            }
            let storeProduct = RevenueCat.StoreProduct(sk2Product: sk2Product)
            let revenueCatResult = try await Purchases.shared.purchase(product: storeProduct)
            
            if revenueCatResult.userCancelled {
                print("ℹ️ Purchase cancelled by user")
                return .cancelled
            } else {
                print("✅ Purchase successful!")
                return .purchased
            }
        } catch let error as ErrorCode {
            if error == .paymentPendingError {
                print("⏳ Purchase pending")
                return .pending
            } else {
                print("❌ Purchase failed: \(error)")
                return .failed(error)
            }
        } catch {
            print("❌ Purchase failed: \(error)")
            return .failed(error)
        }
    }
    
    // MARK: Handle Restores
    /// Makes a restore with RevenueCat and returns `.restored`, unless an error is thrown.
    /// This gets called when someone tries to restore purchases on one of your paywalls.
    func restorePurchases() async -> RestorationResult {
        print("🔄 Superwall: Restoring purchases")
        
        do {
            _ = try await Purchases.shared.restorePurchases()
            print("✅ Restore successful")
            return .restored
        } catch let error {
            print("❌ Restore failed: \(error)")
            return .failed(error)
        }
    }
}
