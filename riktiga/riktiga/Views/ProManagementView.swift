import SwiftUI
import RevenueCat

struct ProManagementView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var revenueCatManager = RevenueCatManager.shared
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
                                .foregroundColor(.black)
                            
                            if revenueCatManager.isPremium {
                                VStack(spacing: 8) {
                                    Text("Aktiv prenumeration")
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(.green)
                                    
                                    if let customerInfo = revenueCatManager.customerInfo,
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
                                .foregroundColor(.black)
                            
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
                            if revenueCatManager.isPremium {
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
                                            .foregroundColor(.black)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(16)
                                    .background(Color.white)
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
                                            .foregroundColor(.black)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(16)
                                    .background(Color.white)
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
        .onAppear {
            Task {
                await revenueCatManager.loadCustomerInfo()
            }
        }
    }
    
    private func restorePurchases() async {
        isRestoring = true
        
        let success = await revenueCatManager.restorePurchases()
        
        if success {
            alertMessage = "Köp återställda framgångsrikt!"
        } else {
            alertMessage = "Inga köp att återställa eller återställning misslyckades."
        }
        
        showAlert = true
        isRestoring = false
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
                .foregroundColor(.black)
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.black)
                
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

