import SwiftUI
import RevenueCat
import RevenueCatUI

struct PaywallAfterSignupView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @ObservedObject private var revenueCatManager = RevenueCatManager.shared
    @State private var hasAttemptedLoad = false
    
    var body: some View {
        Group {
            if let offerings = revenueCatManager.offerings {
                // Debug: Print all available offerings
                let _ = print("📦 [PaywallAfterSignup] Available offerings: \(offerings.all.keys.joined(separator: ", "))")
                let _ = print("📦 [PaywallAfterSignup] Current offering: \(offerings.current?.identifier ?? "none")")
                
                if let chatgptOffering = offerings.offering(identifier: "new") {
                    let _ = print("✅ [PaywallAfterSignup] Using 'new' offering")
                    PaywallView(offering: chatgptOffering)
                } else if let currentOffering = offerings.current {
                    let _ = print("⚠️ [PaywallAfterSignup] 'new' not found, using current: \(currentOffering.identifier)")
                    PaywallView(offering: currentOffering)
                } else {
                    let _ = print("⚠️ [PaywallAfterSignup] No offerings available, using default PaywallView")
                    PaywallView()
                }
            } else {
                // Loading state while offerings are being fetched
                VStack(spacing: 20) {
                    ProgressView()
                        .scaleEffect(1.5)
                    Text(L.t(sv: "Laddar...", nb: "Laster..."))
                        .font(.headline)
                        .foregroundColor(.gray)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(.systemBackground))
                .onAppear {
                    if !hasAttemptedLoad {
                        hasAttemptedLoad = true
                        Task {
                            print("📦 [PaywallAfterSignup] Offerings not loaded, fetching...")
                            await revenueCatManager.loadOfferings()
                        }
                    }
                }
            }
        }
    }
}


#Preview {
    PaywallAfterSignupView()
        .environmentObject(AuthViewModel())
}

