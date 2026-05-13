import SwiftUI

/// Hash-typer för push-navigeringen inuti Produkter-fliken. `search` pushar
/// in den fullskärms-söksidan ovanpå feed-vyn.
enum MarketRoute: Hashable {
    case search
}

struct ProductsContainerView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    let popToRootTrigger: Int
    @State private var navigationPath = NavigationPath()
    @Namespace private var heroNS

    @State private var showCart = false
    @State private var showSellBag = false

    var body: some View {
        NavigationStack(path: $navigationPath) {
            ProductGridView(
                showCart: $showCart,
                marketSubTab: .constant(0),
                onOpenSearch: {
                    navigationPath.append(MarketRoute.search)
                },
                onOpenSellBag: {
                    showSellBag = true
                }
            )
            .environmentObject(authViewModel)
            .environment(\.marketplaceHeroNamespace, heroNS)
            .navigationBarHidden(true)
            .navigationDestination(for: ShopifyProduct.self) { product in
                ProductDetailView(product: product, showCart: $showCart)
                    .environmentObject(authViewModel)
            }
            .navigationDestination(for: MarketRoute.self) { route in
                switch route {
                case .search:
                    MarketSearchView(
                        onSelectListing: { row in
                            navigationPath.append(MarketplaceRoute.listing(row))
                        }
                    )
                    .navigationBarHidden(true)
                }
            }
            .marketplaceDestinations()
        }
        .environmentObject(authViewModel)
        .sheet(isPresented: $showCart) {
            CartView()
                .environmentObject(authViewModel)
        }
        .fullScreenCover(isPresented: $showSellBag) {
            SellBagProductContainer(showCart: $showCart) {
                showSellBag = false
            }
            .environmentObject(authViewModel)
        }
        .id(popToRootTrigger)
        .onChange(of: popToRootTrigger) { _, _ in
            navigationPath = NavigationPath()
        }
    }
}
