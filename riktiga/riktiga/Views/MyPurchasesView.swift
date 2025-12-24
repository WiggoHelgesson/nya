import SwiftUI

struct MyPurchasesView: View {
    @State private var purchases: [Purchase] = PurchaseService.shared.purchases
    @EnvironmentObject var authViewModel: AuthViewModel
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemBackground)
                    .ignoresSafeArea()
                
                if purchases.isEmpty {
                    // Empty state
                    VStack(spacing: 16) {
                        Image(systemName: "cart")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        
                        Text("Inga köp än")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        Text("Dina köpta rabattkoder kommer att visas här")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                } else {
                    // Purchases list
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            ForEach(purchases) { purchase in
                                PurchaseCard(purchase: purchase)
                            }
                        }
                        .padding(16)
                    }
                }
            }
            .navigationTitle("Mina köp")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                if let userId = authViewModel.currentUser?.id {
                    Task {
                        try? await PurchaseService.shared.fetchUserPurchases(userId: userId)
                    }
                }
            }
            .onReceive(PurchaseService.shared.$purchases) { newValue in
                purchases = newValue
            }
        }
    }
}

struct PurchaseCard: View {
    let purchase: Purchase
    @State private var showCodeDetail = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with brand info
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(purchase.brandName)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.primary)
                    
                    Text(purchase.discount)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Text(formatDate(purchase.purchaseDate))
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            .padding(16)
            
            Divider()
            
            // Code section
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Rabattkod")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                    
                    Text(purchase.discountCode)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.primary)
                }
                
                Spacer()
                
                Button(action: {
                    // Copy code to clipboard
                    UIPasteboard.general.string = purchase.discountCode
                }) {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 14))
                        .foregroundColor(Color(.systemBackground))
                        .frame(width: 32, height: 32)
                        .background(Color.primary)
                        .cornerRadius(6)
                }
            }
            .padding(16)
        }
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}

#Preview {
    MyPurchasesView()
        .environmentObject(AuthViewModel())
}
