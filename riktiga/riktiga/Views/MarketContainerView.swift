import SwiftUI

enum MarketTab: String, CaseIterable {
    case buy = "Köp"
    case sell = "Sälj"
}

struct MarketContainerView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @ObservedObject private var cartManager = CartManager.shared
    let popToRootTrigger: Int
    @State private var navigationPath = NavigationPath()
    @State private var showCart = false
    @State private var selectedMarketTab: MarketTab = .buy
    @State private var showConsignmentSellFlow = false

    var body: some View {
        NavigationStack(path: $navigationPath) {
            VStack(spacing: 0) {
                headerBar
                marketTabPicker

                comingSoonPlaceholder
            }
            .navigationBarHidden(true)
            .navigationDestination(for: ShopifyProduct.self) { product in
                ProductDetailView(product: product, showCart: $showCart)
            }
        }
        .sheet(isPresented: $showCart) {
            CartView()
        }
        .fullScreenCover(isPresented: $showConsignmentSellFlow, onDismiss: {
            withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
                selectedMarketTab = .buy
            }
        }) {
            SellBagProductContainer(showCart: $showCart) {
                showConsignmentSellFlow = false
                withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
                    selectedMarketTab = .buy
                }
            }
            .environmentObject(authViewModel)
        }
        .onChange(of: selectedMarketTab) { _, tab in
            if tab == .sell {
                showConsignmentSellFlow = true
            } else {
                showConsignmentSellFlow = false
            }
        }
        .onChange(of: popToRootTrigger) { _, _ in
            navigationPath = NavigationPath()
            showConsignmentSellFlow = false
            selectedMarketTab = .buy
        }
    }

    private var headerBar: some View {
        HStack(spacing: 10) {
            Image("23")
                .resizable()
                .scaledToFit()
                .frame(width: 34, height: 34)
                .clipShape(RoundedRectangle(cornerRadius: 8))

            (Text("UP&DOWN").font(.system(size: 20, weight: .bold)) + Text("Market").font(.system(size: 20, weight: .regular)))
                .foregroundColor(.primary)

            Spacer()

            Button { showCart = true } label: {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: "bag")
                        .font(.system(size: 20))
                        .foregroundColor(.primary)

                    if cartManager.itemCount > 0 {
                        Text("\(cartManager.itemCount)")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 16, height: 16)
                            .background(Color.black)
                            .clipShape(Circle())
                            .offset(x: 6, y: -6)
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    @Environment(\.colorScheme) private var colorScheme

    private var comingSoonPlaceholder: some View {
        ScrollView {
            VStack(spacing: 24) {
                Spacer(minLength: 40)

                VStack(spacing: 20) {
                    Image("23")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 72, height: 72)
                        .clipShape(RoundedRectangle(cornerRadius: 16))

                    VStack(spacing: 8) {
                        Text(L.t(sv: "Kommer snart", nb: "Kommer snart"))
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(.primary)

                        Text(L.t(
                            sv: "Köp second hand sportprodukter direkt i appen",
                            nb: "Kjøp second hand sportprodukter direkte i appen"
                        ))
                        .font(.system(size: 15))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    }
                }
                .padding(.vertical, 32)
                .padding(.horizontal, 24)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(colorScheme == .dark ? Color(red: 0.12, green: 0.12, blue: 0.12) : Color(.systemGray6))
                )
                .padding(.horizontal, 16)

                VStack(spacing: 0) {
                    HStack(spacing: 14) {
                        Image("101")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 24, height: 24)
                            .frame(width: 28)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(L.t(sv: "Använd dina poäng för rabatter", nb: "Bruk poengene dine for rabatter"))
                                .font(.system(size: 15, weight: .semibold))
                            Text(L.t(sv: "På riktiga produkter", nb: "På ekte produkter"))
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                        }

                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    Divider().padding(.leading, 56)
                    comingSoonRow(
                        icon: "hands.clap",
                        title: L.t(sv: "Sälj dina gamla kläder", nb: "Selg de gamle klærne dine"),
                        subtitle: L.t(sv: "Tjäna utan något jobb alls", nb: "Tjen uten noe arbeid i det hele tatt")
                    )
                    Divider().padding(.leading, 56)
                    comingSoonRow(
                        icon: "tag",
                        title: L.t(sv: "Second hand till bra priser", nb: "Second hand til gode priser"),
                        subtitle: L.t(sv: "Kvalitetskläder för träning", nb: "Kvalitetsklær for trening")
                    )
                    Divider().padding(.leading, 56)
                    comingSoonRow(
                        icon: "leaf",
                        title: L.t(sv: "Hållbart mode", nb: "Bærekraftig mote"),
                        subtitle: L.t(sv: "Ge plaggen ett nytt liv", nb: "Gi plaggene et nytt liv")
                    )
                    Divider().padding(.leading, 56)
                    comingSoonRow(
                        icon: "bolt",
                        title: L.t(sv: "Snabb leverans", nb: "Rask levering"),
                        subtitle: L.t(sv: "Direkt till din dörr", nb: "Direkte til din dør")
                    )
                }
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(colorScheme == .dark ? Color(red: 0.12, green: 0.12, blue: 0.12) : Color(.systemGray6))
                )
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .padding(.horizontal, 16)

                Spacer(minLength: 60)
            }
        }
    }

    private func comingSoonRow(icon: String, title: String, subtitle: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(.primary)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                Text(subtitle)
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    private var marketTabPicker: some View {
        HStack(spacing: 0) {
            ForEach(MarketTab.allCases, id: \.self) { tab in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedMarketTab = tab
                    }
                } label: {
                    VStack(spacing: 8) {
                        Text(tab.rawValue)
                            .font(.system(size: 15, weight: selectedMarketTab == tab ? .bold : .regular))
                            .foregroundColor(selectedMarketTab == tab ? .primary : .gray)

                        Rectangle()
                            .fill(selectedMarketTab == tab ? Color.primary : Color.clear)
                            .frame(height: 2)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .background(Color(.systemBackground))
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
