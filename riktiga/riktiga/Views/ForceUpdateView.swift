import SwiftUI
import UIKit

struct ForceUpdateView: View {
    let message: String
    let appStoreUrl: String
    let isForced: Bool
    var onDismiss: (() -> Void)? = nil
    
    var body: some View {
        ZStack {
            // Background
            Color.white.ignoresSafeArea()
            
            VStack(spacing: 32) {
                Spacer()
                
                // Icon
                Image(systemName: "arrow.down.app.fill")
                    .font(.system(size: 80))
                    .foregroundColor(.primary)
                
                // Title
                Text(isForced ? L.t(sv: "Uppdatering krävs", nb: "Oppdatering kreves") : L.t(sv: "Uppdatering tillgänglig", nb: "Oppdatering tilgjengelig"))
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.primary)
                
                // Message
                Text(L.t(sv: "Uppdatera appen via App Store för att använda den", nb: "Oppdater appen via App Store for å bruke den"))
                    .font(.system(size: 16))
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                
                Spacer()
                
                // Buttons
                VStack(spacing: 12) {
                    // Update button - opens App Store app
                    Button {
                        openAppStore()
                    } label: {
                        Text(L.t(sv: "Uppdatera nu", nb: "Oppdater nå"))
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.black)
                            .cornerRadius(14)
                    }
                    
                    // Skip button (only if not forced)
                    if !isForced, let dismiss = onDismiss {
                        Button {
                            dismiss()
                        } label: {
                            Text(L.t(sv: "Senare", nb: "Senere"))
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.gray)
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            }
        }
    }
    
    private func openAppStore() {
        // Opens App Store app directly (not Safari)
        if let url = URL(string: "https://apps.apple.com/se/app/up-down/id6749190145?l=en-GB") {
            UIApplication.shared.open(url)
        }
    }
}

#Preview {
    ForceUpdateView(
        message: "En ny version av appen finns tillgänglig med viktiga förbättringar och buggfixar.",
        appStoreUrl: "https://apps.apple.com",
        isForced: true
    )
}

