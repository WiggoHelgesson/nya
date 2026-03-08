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
                        
                        Text(L.t(sv: "Uppgradera till Premium", nb: "Oppgrader til Premium"))
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(.primary)
                        
                        Text(L.t(sv: "Få tillgång till alla rabattkoder och exklusiva erbjudanden", nb: "Få tilgang til alle rabattkoder og eksklusive tilbud"))
                            .font(.system(size: 16))
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 20)
                    
                    // Features
                    VStack(alignment: .leading, spacing: 16) {
                        Text(L.t(sv: "Premium fördelar", nb: "Premium-fordeler"))
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.primary)
                        
                        VStack(spacing: 12) {
                            FeatureRow(icon: "tag.fill", text: L.t(sv: "Obegränsade rabattkoder", nb: "Ubegrensede rabattkoder"))
                            FeatureRow(icon: "star.fill", text: L.t(sv: "Exklusiva erbjudanden", nb: "Eksklusive tilbud"))
                            FeatureRow(icon: "bolt.fill", text: L.t(sv: "Prioriterad support", nb: "Prioritert support"))
                            FeatureRow(icon: "heart.fill", text: L.t(sv: "Stöd utvecklingen", nb: "Støtt utviklingen"))
                        }
                    }
                    .padding(.horizontal, 20)
                    
                    // Pricing options
                    if let offerings = offerings,
                       let currentOffering = offerings.current {
                        VStack(spacing: 16) {
                            Text(L.t(sv: "Välj din plan", nb: "Velg din plan"))
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(.primary)
                            
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
                            
                            Text(L.t(sv: "Laddar priser...", nb: "Laster priser..."))
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
                            Text(isProcessingPurchase ? L.t(sv: "Bearbetar...", nb: "Behandler...") : L.t(sv: "Börja prenumeration", nb: "Start abonnement"))
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
                        Text(L.t(sv: "Återställ köp", nb: "Gjenopprett kjøp"))
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.gray)
                    }
                    .padding(.bottom, 20)
                }
            }
            .navigationTitle(L.t(sv: "Premium", nb: "Premium"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(L.t(sv: "Stäng", nb: "Lukk")) {
                        dismiss()
                    }
                }
            }
            .alert(L.t(sv: "Fel", nb: "Feil"), isPresented: $showError) {
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
            errorMessage = L.t(sv: "Köp misslyckades. Försök igen.", nb: "Kjøp mislyktes. Prøv igjen.")
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
            errorMessage = L.t(sv: "Återställning misslyckades. Kontrollera att du har köpt något tidigare.", nb: "Gjenoppretting mislyktes. Sjekk at du har kjøpt noe tidligere.")
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
                .foregroundColor(.primary)
                .frame(width: 20)
            
            Text(text)
                .font(.system(size: 16))
                .foregroundColor(.primary)
            
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
                        .foregroundColor(.primary)
                    
                    Text(package.storeProduct.localizedDescription)
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                        .lineLimit(2)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text(package.localizedPriceString)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.primary)
                    
                    if package.packageType == .annual {
                        Text(L.t(sv: "Bästa valet", nb: "Beste valget"))
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

