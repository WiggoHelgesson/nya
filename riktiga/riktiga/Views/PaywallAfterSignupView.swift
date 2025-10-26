import SwiftUI
import RevenueCat
import RevenueCatUI

struct PaywallAfterSignupView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @Environment(\.dismiss) var dismiss
    @State private var showError = false
    @State private var errorMessage = ""
    @StateObject private var revenueCatManager = RevenueCatManager.shared
    @State private var selectedPackage: Package?
    @State private var isProcessingPurchase = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemBackground).ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Close button at top
                        HStack {
                            Button(action: {
                                authViewModel.showPaywallAfterSignup = false
                            }) {
                                Image(systemName: "xmark")
                                    .font(.system(size: 20, weight: .semibold))
                                    .foregroundColor(.gray)
                            }
                            
                            Spacer()
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 20)
                        
                        // Header
                        VStack(spacing: 16) {
                            Image(systemName: "crown.fill")
                                .font(.system(size: 48))
                                .foregroundColor(.yellow)
                            
                            Text("Uppgradera till Premium")
                                .font(.system(size: 28, weight: .bold))
                                .foregroundColor(.black)
                            
                            Text("Få tillgång till alla rabattkoder och exklusiva erbjudanden")
                                .font(.system(size: 16))
                                .foregroundColor(.gray)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.top, 20)
                        
                        // Features
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Premium fördelar")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(.black)
                            
                            VStack(spacing: 12) {
                                FeatureRow(icon: "tag.fill", text: "Obegränsade rabattkoder")
                                FeatureRow(icon: "star.fill", text: "Exklusiva erbjudanden")
                                FeatureRow(icon: "bolt.fill", text: "Prioriterad support")
                                FeatureRow(icon: "heart.fill", text: "Stöd utvecklingen")
                            }
                        }
                        .padding(.horizontal, 20)
                        
                        // Pricing options
                        if let offerings = revenueCatManager.offerings,
                           let currentOffering = offerings.current {
                            VStack(spacing: 16) {
                                Text("Välj din plan")
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundColor(.black)
                                
                                VStack(spacing: 12) {
                                    ForEach(currentOffering.availablePackages, id: \.identifier) { package in
                                        PackageCard(
                                            package: package,
                                            isSelected: selectedPackage?.identifier == package.identifier,
                                            onSelect: {
                                                selectedPackage = package
                                            }
                                        )
                                    }
                                }
                            }
                            .padding(.horizontal, 20)
                        } else {
                            VStack(spacing: 16) {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle())
                                
                                Text("Laddar priser...")
                                    .font(.system(size: 16))
                                    .foregroundColor(.gray)
                            }
                            .padding(.vertical, 40)
                        }
                        
                        Spacer(minLength: 40)
                        
                        // Purchase button
                        Button(action: {
                            Task {
                                await purchaseSelectedPackage()
                            }
                        }) {
                            HStack {
                                if isProcessingPurchase {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        .scaleEffect(0.8)
                                }
                                Text(isProcessingPurchase ? "Bearbetar..." : "Börja prenumeration")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(.white)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(18)
                            .background(selectedPackage == nil ? Color.gray : Color.black)
                            .cornerRadius(12)
                        }
                        .padding(.horizontal, 20)
                        .disabled(selectedPackage == nil || isProcessingPurchase)
                        
                        // Restore purchases button
                        Button(action: {
                            Task {
                                await restorePurchases()
                            }
                        }) {
                            Text("Återställ köp")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.gray)
                        }
                        .padding(.bottom, 20)
                    }
                }
            }
            .navigationBarHidden(true)
            .alert("Fel", isPresented: $showError) {
                Button("OK") { }
            } message: {
                Text(errorMessage)
            }
        }
        .onAppear {
            Task {
                await revenueCatManager.loadOfferings()
                // Auto-select first package if available
                if let offerings = revenueCatManager.offerings,
                   let currentOffering = offerings.current,
                   let firstPackage = currentOffering.availablePackages.first {
                    selectedPackage = firstPackage
                }
            }
        }
    }
    
    private func purchaseSelectedPackage() async {
        guard let package = selectedPackage else { return }
        
        isProcessingPurchase = true
        
        let success = await revenueCatManager.purchasePackage(package)
        
        if success {
            authViewModel.showPaywallAfterSignup = false
        } else {
            errorMessage = "Köp misslyckades. Försök igen."
            showError = true
        }
        
        isProcessingPurchase = false
    }
    
    private func restorePurchases() async {
        isProcessingPurchase = true
        
        let success = await revenueCatManager.restorePurchases()
        
        if success {
            authViewModel.showPaywallAfterSignup = false
        } else {
            errorMessage = "Återställning misslyckades. Kontrollera att du har köpt något tidigare."
            showError = true
        }
        
        isProcessingPurchase = false
    }
}


#Preview {
    PaywallAfterSignupView()
        .environmentObject(AuthViewModel())
}

