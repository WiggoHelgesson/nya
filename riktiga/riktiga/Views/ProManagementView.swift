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
                                    Text("Aktiv prenumeration")
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(.green)
                                    
                                    if let customerInfo = customerInfo,
                                       let entitlement = customerInfo.entitlements["premium"] {
                                        Text("Förnyas: \(formatDate(entitlement.expirationDate))")
                                            .font(.system(size: 14))
                                            .foregroundColor(.gray)
                                    }
                                }
                            } else {
                                Text("Ingen aktiv prenumeration")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.red)
                            }
                        }
                        .padding(.top, 20)
                        
                        // MARK: - PRO Benefits
                        VStack(alignment: .leading, spacing: 16) {
                            Text("PRO fördelar")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(.primary)
                            
                            VStack(spacing: 12) {
                                BenefitRow(
                                    icon: "bolt.fill",
                                    title: "1.5x Poäng Boost",
                                    description: "Få 50% fler poäng för varje träningspass"
                                )
                                
                                BenefitRow(
                                    icon: "tag.fill",
                                    title: "Obegränsade rabattkoder",
                                    description: "Köp så många rabattkoder du vill"
                                )
                                
                                BenefitRow(
                                    icon: "star.fill",
                                    title: "Exklusiva erbjudanden",
                                    description: "Få tillgång till specialrabatter"
                                )
                                
                                BenefitRow(
                                    icon: "heart.fill",
                                    title: "Stöd utvecklingen",
                                    description: "Hjälp oss att förbättra appen"
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
                                    Text("Hantera i App Store")
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
                                        Text(isRestoring ? "Återställer..." : "Återställ köp")
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
                                    Text("Uppgradera till PRO")
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
                                        Text(isRestoring ? "Återställer..." : "Återställ köp")
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
            .navigationTitle("PRO Management")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Stäng") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showSubscriptionView) {
                SubscriptionView()
            }
            .alert("Information", isPresented: $showAlert) {
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
                alertMessage = "Köp återställda framgångsrikt!"
            } else {
                alertMessage = "Inga köp att återställa eller återställning misslyckades."
            }
            showAlert = true
            isRestoring = false
        }
    }
    
    private func formatDate(_ date: Date?) -> String {
        guard let date = date else { return "Okänt" }
        
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

