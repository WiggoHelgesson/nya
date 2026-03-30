import Foundation
import Combine

@MainActor
class CartManager: ObservableObject {
    static let shared = CartManager()

    @Published var cart: ShopifyCart?
    @Published var isLoading = false
    @Published var error: String?

    var itemCount: Int {
        cart?.lines.edges.reduce(0) { $0 + $1.node.quantity } ?? 0
    }

    var isEmpty: Bool { itemCount == 0 }

    private let shopify = ShopifyService.shared

    private init() {}

    func addToCart(variantId: String, quantity: Int = 1) async {
        isLoading = true
        error = nil
        do {
            if let existingCart = cart {
                cart = try await shopify.cartLinesAdd(cartId: existingCart.id, variantId: variantId, quantity: quantity)
            } else {
                cart = try await shopify.cartCreate(variantId: variantId, quantity: quantity)
            }
        } catch {
            self.error = error.localizedDescription
            print("❌ CartManager.addToCart: \(error)")
        }
        isLoading = false
    }

    func updateQuantity(lineId: String, quantity: Int) async {
        guard let cartId = cart?.id else { return }
        isLoading = true
        error = nil
        do {
            if quantity <= 0 {
                cart = try await shopify.cartLinesRemove(cartId: cartId, lineIds: [lineId])
            } else {
                cart = try await shopify.cartLinesUpdate(cartId: cartId, lineId: lineId, quantity: quantity)
            }
        } catch {
            self.error = error.localizedDescription
            print("❌ CartManager.updateQuantity: \(error)")
        }
        isLoading = false
    }

    func removeItem(lineId: String) async {
        guard let cartId = cart?.id else { return }
        isLoading = true
        error = nil
        do {
            cart = try await shopify.cartLinesRemove(cartId: cartId, lineIds: [lineId])
        } catch {
            self.error = error.localizedDescription
            print("❌ CartManager.removeItem: \(error)")
        }
        isLoading = false
    }

    func applyDiscount(code: String) async {
        guard let cartId = cart?.id else { return }
        isLoading = true
        error = nil
        do {
            cart = try await shopify.cartDiscountCodesUpdate(cartId: cartId, discountCodes: [code])
        } catch {
            self.error = error.localizedDescription
            print("❌ CartManager.applyDiscount: \(error)")
        }
        isLoading = false
    }

    func removeDiscount() async {
        guard let cartId = cart?.id else { return }
        isLoading = true
        do {
            cart = try await shopify.cartDiscountCodesUpdate(cartId: cartId, discountCodes: [])
        } catch {
            self.error = error.localizedDescription
            print("❌ CartManager.removeDiscount: \(error)")
        }
        isLoading = false
    }

    var checkoutURL: URL? {
        guard let urlString = cart?.checkoutUrl else { return nil }
        var components = URLComponents(string: urlString)
        let existing = components?.queryItems ?? []
        components?.queryItems = existing + [URLQueryItem(name: "channel", value: "online_store")]
        return components?.url
    }

    func clearCart() {
        cart = nil
        error = nil
    }
}
