import SwiftUI
import RevenueCat

struct SubscriptionView: View {
    @Environment(\.dismiss) var dismiss
    @State private var offerings: Offerings? = RevenueCatManager.shared.offerings
    @State private var selectedPackage: Package?
    @State private var isProcessingPurchase = false
    @State private var showError = false
    @State private var errorMessage = ""
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
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
                    if let offerings = offerings,
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
                        .background(Color.black)
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
            .navigationTitle("Premium")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Stäng") {
                        dismiss()
                    }
                }
            }
            .alert("Fel", isPresented: $showError) {
                Button("OK") { }
            } message: {
                Text(errorMessage)
            }
        }
        .onAppear {
            Task {
                await RevenueCatManager.shared.loadOfferings()
            }
        }
        .onReceive(RevenueCatManager.shared.$offerings) { newValue in
            offerings = newValue
        }
    }
    
    private func purchaseSelectedPackage() async {
        guard let package = selectedPackage else { return }
        
        isProcessingPurchase = true
        
        let success = await RevenueCatManager.shared.purchasePackage(package)
        
        if success {
            dismiss()
        } else {
            errorMessage = "Köp misslyckades. Försök igen."
            showError = true
        }
        
        isProcessingPurchase = false
    }
    
    private func restorePurchases() async {
        isProcessingPurchase = true
        
        let success = await RevenueCatManager.shared.restorePurchases()
        
        if success {
            dismiss()
        } else {
            errorMessage = "Återställning misslyckades. Kontrollera att du har köpt något tidigare."
            showError = true
        }
        
        isProcessingPurchase = false
    }
}

struct FeatureRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(.black)
                .frame(width: 20)
            
            Text(text)
                .font(.system(size: 16))
                .foregroundColor(.black)
            
            Spacer()
        }
    }
}

struct PackageCard: View {
    let package: Package
    let isSelected: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(package.storeProduct.localizedTitle)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.black)
                    
                    Text(package.storeProduct.localizedDescription)
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                        .lineLimit(2)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text(package.localizedPriceString)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.black)
                    
                    if package.packageType == .annual {
                        Text("Bästa valet")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Color.green)
                            .cornerRadius(4)
                    }
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isSelected ? Color.black : Color.gray.opacity(0.3), lineWidth: isSelected ? 2 : 1)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    SubscriptionView()
}

