import SwiftUI

enum SellBagConfig {
    /// Shopify-handle för "Up&Down-påsen" (verifierat från admin).
    static let productHandle = "up-down-pasen"
}

struct SellBagProductContainer: View {
    @Binding var showCart: Bool
    var onClose: () -> Void

    @EnvironmentObject var authViewModel: AuthViewModel

    @State private var product: ShopifyProduct?
    @State private var isLoading = true
    @State private var loadError: String?

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemBackground).ignoresSafeArea()

                if let product = product {
                    ProductDetailView(product: product, showCart: $showCart)
                        .environmentObject(authViewModel)
                } else if isLoading {
                    loadingState
                } else if let error = loadError {
                    errorState(message: error)
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(action: onClose) {
                        Image(systemName: "xmark")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.primary)
                    }
                }
            }
        }
        .task { await load() }
    }

    private var loadingState: some View {
        VStack(spacing: 16) {
            ProgressView()
            Text(L.t(sv: "Hämtar påsen…", nb: "Henter posen…"))
                .font(.system(size: 14))
                .foregroundColor(.secondary)
        }
    }

    private func errorState(message: String) -> some View {
        VStack(spacing: 14) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 32))
                .foregroundColor(.orange)
            Text(L.t(sv: "Kunde inte ladda påsen", nb: "Kunne ikke laste posen"))
                .font(.system(size: 17, weight: .semibold))
            Text(message)
                .font(.system(size: 13))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Button {
                Task { await load() }
            } label: {
                Text(L.t(sv: "Försök igen", nb: "Prøv igjen"))
                    .font(.system(size: 15, weight: .semibold))
                    .padding(.horizontal, 24)
                    .padding(.vertical, 10)
                    .background(Color.black)
                    .foregroundColor(.white)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
    }

    private func load() async {
        isLoading = true
        loadError = nil
        do {
            let fetched = try await ShopifyService.shared.fetchProductByHandle(SellBagConfig.productHandle)
            await MainActor.run {
                self.product = fetched
                if fetched == nil {
                    self.loadError = L.t(
                        sv: "Säljpåsen hittades inte i butiken.",
                        nb: "Salgsposen ble ikke funnet i butikken."
                    )
                }
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.loadError = error.localizedDescription
                self.isLoading = false
            }
        }
    }
}
