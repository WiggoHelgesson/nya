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
                Text(isForced ? "Uppdatering krävs" : "Uppdatering tillgänglig")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.primary)
                
                // Message
                Text("Uppdatera appen via App Store för att använda den")
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
                        Text("Uppdatera nu")
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
                            Text("Senare")
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

