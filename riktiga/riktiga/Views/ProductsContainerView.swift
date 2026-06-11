import SwiftUI

struct ProductsContainerView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    let popToRootTrigger: Int
    @State private var navigationPath = NavigationPath()

    @State private var showCart = false

    var body: some View {
        NavigationStack(path: $navigationPath) {
            ProductGridView(showCart: $showCart)
                .environmentObject(authViewModel)
                .navigationBarHidden(true)
                .navigationDestination(for: ShopifyProduct.self) { product in
                    ProductDetailView(product: product, showCart: $showCart)
                        .environmentObject(authViewModel)
                }
                .marketplaceDestinations()
        }
        .environmentObject(authViewModel)
        .sheet(isPresented: $showCart) {
            CartView()
                .environmentObject(authViewModel)
        }
        .id(popToRootTrigger)
        .onChange(of: popToRootTrigger) { _, _ in
            navigationPath = NavigationPath()
        }
    }
}
