import SwiftUI

struct ProductsContainerView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    let popToRootTrigger: Int
    @State private var navigationPath = NavigationPath()

    @ObservedObject private var cartManager = CartManager.shared
    @State private var showCart = false
    @State private var marketSubTab = 0
    @State private var showConsignmentSellFlow = false

    var body: some View {
        NavigationStack(path: $navigationPath) {
            VStack(spacing: 0) {
                VStack(spacing: 0) {
                    marketSubTabPicker
                        .padding(.top, 8)

                    Rectangle()
                        .fill(Color.primary)
                        .frame(height: 0.5)
                        .opacity(0.1)
                }
                .background(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.15), radius: 8, x: 0, y: 4)
                .zIndex(2)

                ProductGridView(
                    showCart: $showCart,
                    marketSubTab: $marketSubTab,
                    onOpenSellFlow: {
                        marketSubTab = 1
                        showConsignmentSellFlow = true
                    }
                )
                .environmentObject(authViewModel)
            }
            .navigationBarHidden(true)
            .navigationDestination(for: ShopifyProduct.self) { product in
                ProductDetailView(product: product, showCart: $showCart)
                    .environmentObject(authViewModel)
            }
        }
        .sheet(isPresented: $showCart) {
            CartView()
                .environmentObject(authViewModel)
        }
        .fullScreenCover(isPresented: $showConsignmentSellFlow, onDismiss: {
            withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
                marketSubTab = 0
            }
        }) {
            SellBagProductContainer(showCart: $showCart) {
                showConsignmentSellFlow = false
                withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
                    marketSubTab = 0
                }
            }
            .environmentObject(authViewModel)
        }
        .id(popToRootTrigger)
        .onChange(of: popToRootTrigger) { _, _ in
            navigationPath = NavigationPath()
            marketSubTab = 0
            showConsignmentSellFlow = false
        }
    }

    // MARK: - Market Sub-Tab Picker (Köp / Sälj)

    private var marketSubTabPicker: some View {
        HStack(spacing: 6) {
            marketSubTabButton(L.t(sv: "Köp", nb: "Kjøp"), icon: "bag", index: 0)
            marketSubTabButton(L.t(sv: "Sälj", nb: "Selg"), icon: "tag", index: 1)
        }
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(.systemGray6))
        )
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
    }

    private func marketSubTabButton(_ title: String, icon: String, index: Int) -> some View {
        let isSelected = marketSubTab == index
        return Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                marketSubTab = index
                if index == 1 {
                    showConsignmentSellFlow = true
                } else {
                    showConsignmentSellFlow = false
                }
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .medium))
                Text(title)
                    .font(.system(size: 16, weight: isSelected ? .bold : .medium))
            }
            .foregroundColor(isSelected ? .white : .secondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(isSelected ? Color.black : Color.clear)
                    .shadow(color: isSelected ? Color.black.opacity(0.15) : .clear, radius: 4, y: 2)
            )
        }
        .buttonStyle(.plain)
    }
}
