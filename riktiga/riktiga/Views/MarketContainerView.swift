import SwiftUI

struct MarketContainerView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @ObservedObject private var cartManager = CartManager.shared
    let popToRootTrigger: Int
    @State private var navigationPath = NavigationPath()
    @State private var showCart = false

    var body: some View {
        NavigationStack(path: $navigationPath) {
            ProductGridView(showCart: $showCart)
                .navigationDestination(for: ShopifyProduct.self) { product in
                    ProductDetailView(product: product, showCart: $showCart)
                }
        }
        .sheet(isPresented: $showCart) {
            CartView()
        }
        .onChange(of: popToRootTrigger) { _, _ in
            navigationPath = NavigationPath()
        }
    }
}

extension ShopifyProduct: Hashable {
    static func == (lhs: ShopifyProduct, rhs: ShopifyProduct) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
