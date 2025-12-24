import SwiftUI
import InsertAffiliateSwift

struct ReferralView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var affiliateIdentifier: String? = nil
    @State private var isLoading = true
    @State private var copySuccess = false
    
    // Insert Affiliate signup URL - users sign up here to become affiliates
    private let affiliateSignupURL = "https://app.insertaffiliate.com/signup"
    private let affiliateDashboardURL = "https://app.insertaffiliate.com"
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // MARK: - Hero Section
                    VStack(spacing: 16) {
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [Color.black, Color.black.opacity(0.8)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 100, height: 100)
                            
                            Image(systemName: "gift.fill")
                                .font(.system(size: 44))
                                .foregroundColor(.white)
                        }
                        
                        Text("Referera och tjäna")
                            .font(.system(size: 28, weight: .bold))
                        
                        Text("Bli affiliate och tjäna pengar genom att rekommendera Up&Down till andra!")
                            .font(.system(size: 16))
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                    }
                    .padding(.top, 20)
                    
                    // MARK: - How it works
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Så fungerar det")
                            .font(.system(size: 20, weight: .bold))
                            .padding(.horizontal, 20)
                        
                        VStack(spacing: 12) {
                            howItWorksStep(
                                number: "1",
                                title: "Bli affiliate",
                                description: "Registrera dig som affiliate via länken nedan"
                            )
                            
                            howItWorksStep(
                                number: "2",
                                title: "Få din unika länk",
                                description: "Du får en personlig länk att dela med andra"
                            )
                            
                            howItWorksStep(
                                number: "3",
                                title: "Dela och tjäna",
                                description: "När någon prenumererar via din länk får du provision"
                            )
                        }
                        .padding(.horizontal, 20)
                    }
                    
                    // MARK: - Become Affiliate Button
                    VStack(spacing: 16) {
                        Text("Kom igång")
                            .font(.system(size: 18, weight: .bold))
                        
                        // Sign up as affiliate button
                        Button(action: openAffiliateSignup) {
                            HStack(spacing: 12) {
                                Image(systemName: "person.badge.plus")
                                    .font(.system(size: 18, weight: .semibold))
                                Text("Bli affiliate")
                                    .font(.system(size: 17, weight: .semibold))
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 54)
                            .background(Color.black)
                            .cornerRadius(27)
                        }
                        
                        // Already an affiliate? Open dashboard
                        Button(action: openAffiliateDashboard) {
                            HStack(spacing: 8) {
                                Image(systemName: "chart.bar.fill")
                                    .font(.system(size: 16))
                                Text("Öppna affiliate-dashboard")
                                    .font(.system(size: 15, weight: .medium))
                            }
                            .foregroundColor(.primary)
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                            .background(Color(.systemGray6))
                            .cornerRadius(24)
                        }
                    }
                    .padding(.horizontal, 20)
                    
                    // MARK: - Current Affiliate Status
                    if let identifier = affiliateIdentifier {
                        VStack(spacing: 12) {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                Text("Affiliate-koppling aktiv")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.green)
                            }
                            
                            Text("ID: \(identifier)")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.gray)
                        }
                        .padding(16)
                        .frame(maxWidth: .infinity)
                        .background(Color.green.opacity(0.1))
                        .cornerRadius(12)
                        .padding(.horizontal, 20)
                    }
                    
                    // MARK: - Info Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Vanliga frågor")
                            .font(.system(size: 18, weight: .bold))
                        
                        faqItem(
                            question: "Hur mycket kan jag tjäna?",
                            answer: "Du får provision på varje prenumeration som görs via din länk. Exakt belopp beror på prenumerationstyp."
                        )
                        
                        faqItem(
                            question: "När får jag betalt?",
                            answer: "Utbetalningar sker månadsvis via Insert Affiliate-plattformen."
                        )
                        
                        faqItem(
                            question: "Hur spåras mina referrals?",
                            answer: "När någon klickar på din länk och laddar ner appen kopplas de automatiskt till ditt affiliate-konto."
                        )
                    }
                    .padding(.horizontal, 20)
                    
                    Spacer(minLength: 40)
                }
            }
            .background(Color(.systemBackground))
            .navigationTitle("Referera")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Klar") {
                        dismiss()
                    }
                    .foregroundColor(.primary)
                }
            }
            .task {
                loadAffiliateStatus()
            }
        }
    }
    
    // MARK: - Helper Views
    
    private func howItWorksStep(number: String, title: String, description: String) -> some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.black)
                    .frame(width: 36, height: 36)
                
                Text(number)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)
                
                Text(description)
                    .font(.system(size: 14))
                    .foregroundColor(.gray)
            }
            
            Spacer()
        }
        .padding(16)
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private func faqItem(question: String, answer: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(question)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.primary)
            
            Text(answer)
                .font(.system(size: 14))
                .foregroundColor(.gray)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    // MARK: - Actions
    
    private func loadAffiliateStatus() {
        // Check if user has an affiliate identifier stored (they came from an affiliate link)
        affiliateIdentifier = InsertAffiliateSwift.returnInsertAffiliateIdentifier()
        isLoading = false
    }
    
    private func openAffiliateSignup() {
        if let url = URL(string: affiliateSignupURL) {
            UIApplication.shared.open(url)
        }
    }
    
    private func openAffiliateDashboard() {
        if let url = URL(string: affiliateDashboardURL) {
            UIApplication.shared.open(url)
        }
    }
}

#Preview {
    ReferralView()
}

