import SwiftUI
import RevenueCat

struct ProManagementView: View {
    @Environment(\.dismiss) var dismiss
    @State private var isPremium = RevenueCatManager.shared.isProMember
    @State private var isLoadingPremium = RevenueCatManager.shared.isLoading
    @State private var customerInfo: CustomerInfo? = RevenueCatManager.shared.customerInfo
    @State private var showSubscriptionView = false
    @State private var isRestoring = false
    @State private var showAlert = false
    @State private var alertMessage = ""
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGray6)
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // MARK: - PRO Status Header
                        VStack(spacing: 16) {
                            Image(systemName: "crown.fill")
                                .font(.system(size: 48))
                                .foregroundColor(.yellow)
                            
                            Text("Up&Down PRO")
                                .font(.system(size: 28, weight: .bold))
                                .foregroundColor(.primary)
                            
                            if isLoadingPremium {
                                VStack(spacing: 8) {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                        .frame(height: 16)
                                }
                            } else if isPremium {
                                VStack(spacing: 8) {
                                    Text(L.t(sv: "Aktiv prenumeration", nb: "Aktivt abonnement"))
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(.green)
                                    
                                    if let customerInfo = customerInfo,
                                       let entitlement = customerInfo.entitlements["premium"] {
                                        Text(L.t(sv: "Förnyas: \(formatDate(entitlement.expirationDate))", nb: "Fornyes: \(formatDate(entitlement.expirationDate))"))
                                            .font(.system(size: 14))
                                            .foregroundColor(.gray)
                                    }
                                }
                            } else {
                                Text(L.t(sv: "Ingen aktiv prenumeration", nb: "Ingen aktivt abonnement"))
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.red)
                            }
                        }
                        .padding(.top, 20)
                        
                        // MARK: - PRO Benefits
                        VStack(alignment: .leading, spacing: 16) {
                            Text(L.t(sv: "PRO fördelar", nb: "PRO-fordeler"))
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(.primary)
                            
                            VStack(spacing: 12) {
                                BenefitRow(
                                    icon: "bolt.fill",
                                    title: L.t(sv: "1.5x Poäng Boost", nb: "1.5x Poeng Boost"),
                                    description: L.t(sv: "Få 50% fler poäng för varje träningspass", nb: "Få 50% flere poeng for hver treningsøkt")
                                )
                                
                                BenefitRow(
                                    icon: "tag.fill",
                                    title: L.t(sv: "Obegränsade rabattkoder", nb: "Ubegrensede rabattkoder"),
                                    description: L.t(sv: "Köp så många rabattkoder du vill", nb: "Kjøp så mange rabattkoder du vil")
                                )
                                
                                BenefitRow(
                                    icon: "star.fill",
                                    title: L.t(sv: "Exklusiva erbjudanden", nb: "Eksklusive tilbud"),
                                    description: L.t(sv: "Få tillgång till specialrabatter", nb: "Få tilgang til spesialrabatter")
                                )
                                
                                BenefitRow(
                                    icon: "heart.fill",
                                    title: L.t(sv: "Stöd utvecklingen", nb: "Støtt utviklingen"),
                                    description: L.t(sv: "Hjälp oss att förbättra appen", nb: "Hjelp oss med å forbedre appen")
                                )
                            }
                        }
                        .padding(.horizontal, 20)
                        
                        // MARK: - Action Buttons
                        VStack(spacing: 16) {
                            if isPremium {
                                // Premium user actions
                                Button(action: {
                                    // Open App Store subscription management
                                    if let url = URL(string: "https://apps.apple.com/account/subscriptions") {
                                        UIApplication.shared.open(url)
                                    }
                                }) {
                                    Text(L.t(sv: "Hantera i App Store", nb: "Administrer i App Store"))
                                        .font(.system(size: 16, weight: .bold))
                                        .foregroundColor(.white)
                                        .frame(maxWidth: .infinity)
                                        .padding(16)
                                        .background(Color.black)
                                        .cornerRadius(12)
                                }
                                
                                Button(action: {
                                    Task {
                                        await restorePurchases()
                                    }
                                }) {
                                    HStack {
                                        if isRestoring {
                                            ProgressView()
                                                .progressViewStyle(CircularProgressViewStyle(tint: .black))
                                                .scaleEffect(0.8)
                                        }
                                        Text(isRestoring ? L.t(sv: "Återställer...", nb: "Gjenoppretter...") : L.t(sv: "Återställ köp", nb: "Gjenopprett kjøp"))
                                            .font(.system(size: 16, weight: .bold))
                                            .foregroundColor(.primary)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(16)
                                    .background(Color(.secondarySystemBackground))
                                    .cornerRadius(12)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(Color.black, lineWidth: 1)
                                    )
                                }
                                .disabled(isRestoring)
                            } else {
                                // Non-premium user actions
                                Button(action: {
                                    showSubscriptionView = true
                                }) {
                                    Text(L.t(sv: "Uppgradera till PRO", nb: "Oppgrader til PRO"))
                                        .font(.system(size: 18, weight: .bold))
                                        .foregroundColor(.white)
                                        .frame(maxWidth: .infinity)
                                        .padding(18)
                                        .background(Color.black)
                                        .cornerRadius(12)
                                }
                                
                                Button(action: {
                                    Task {
                                        await restorePurchases()
                                    }
                                }) {
                                    HStack {
                                        if isRestoring {
                                            ProgressView()
                                                .progressViewStyle(CircularProgressViewStyle(tint: .black))
                                                .scaleEffect(0.8)
                                        }
                                        Text(isRestoring ? L.t(sv: "Återställer...", nb: "Gjenoppretter...") : L.t(sv: "Återställ köp", nb: "Gjenopprett kjøp"))
                                            .font(.system(size: 16, weight: .bold))
                                            .foregroundColor(.primary)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(16)
                                    .background(Color(.secondarySystemBackground))
                                    .cornerRadius(12)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(Color.black, lineWidth: 1)
                                    )
                                }
                                .disabled(isRestoring)
                            }
                        }
                        .padding(.horizontal, 20)
                        
                        Spacer(minLength: 40)
                    }
                }
            }
            .navigationTitle(L.t(sv: "PRO Management", nb: "PRO-administrasjon"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(L.t(sv: "Stäng", nb: "Lukk")) {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showSubscriptionView) {
                SubscriptionView()
            }
            .alert(L.t(sv: "Information", nb: "Informasjon"), isPresented: $showAlert) {
                Button("OK") { }
            } message: {
                Text(alertMessage)
            }
        }
        .task {
            // Only load if not already loaded or loading
            if !isLoadingPremium && customerInfo == nil {
                await RevenueCatManager.shared.loadCustomerInfo()
            }
        }
        .onReceive(RevenueCatManager.shared.$isProMember) { newValue in
            isPremium = newValue
        }
        .onReceive(RevenueCatManager.shared.$isLoading) { newValue in
            isLoadingPremium = newValue
        }
        .onReceive(RevenueCatManager.shared.$customerInfo) { newValue in
            customerInfo = newValue
        }
    }
    
    private func restorePurchases() async {
        await MainActor.run {
            isRestoring = true
        }
        
        let success = await RevenueCatManager.shared.restorePurchases()
        
        await MainActor.run {
            if success {
                alertMessage = L.t(sv: "Köp återställda framgångsrikt!", nb: "Kjøp gjenopprettet!")
            } else {
                alertMessage = L.t(sv: "Inga köp att återställa eller återställning misslyckades.", nb: "Ingen kjøp å gjenopprette, eller gjenopprettingen mislyktes.")
            }
            showAlert = true
            isRestoring = false
        }
    }
    
    private func formatDate(_ date: Date?) -> String {
        guard let date = date else { return L.t(sv: "Okänt", nb: "Ukjent") }
        
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        formatter.locale = Locale(identifier: "sv_SE")
        
        return formatter.string(from: date)
    }
}

struct BenefitRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(.primary)
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.primary)
                
                Text(description)
                    .font(.system(size: 14))
                    .foregroundColor(.gray)
            }
            
            Spacer()
        }
    }
}

#Preview {
    ProManagementView()
}

