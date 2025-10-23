import SwiftUI

struct MyPurchasesView: View {
    @StateObject private var purchaseService = PurchaseService.shared
    @EnvironmentObject var authViewModel: AuthViewModel
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemBackground)
                    .ignoresSafeArea()
                
                if purchaseService.purchases.isEmpty {
                    // Empty state
                    VStack(spacing: 16) {
                        Image(systemName: "cart")
                            .font(.system(size: 48))
                            .foregroundColor(.gray)
                        
                        Text("Inga köp än")
                            .font(.headline)
                            .foregroundColor(.black)
                        
                        Text("Dina köpta rabattkoder kommer att visas här")
                            .font(.caption)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                    }
                } else {
                    // Purchases list
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            ForEach(purchaseService.purchases) { purchase in
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
                        try? await purchaseService.fetchUserPurchases(userId: userId)
                    }
                }
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
                        .foregroundColor(.black)
                    
                    Text(purchase.discount)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                Text(formatDate(purchase.purchaseDate))
                    .font(.system(size: 12))
                    .foregroundColor(.gray)
            }
            .padding(16)
            
            Divider()
            
            // Code section
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Rabattkod")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.gray)
                    
                    Text(purchase.discountCode)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.black)
                }
                
                Spacer()
                
                Button(action: {
                    // Copy code to clipboard
                    UIPasteboard.general.string = purchase.discountCode
                }) {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 14))
                        .foregroundColor(.white)
                        .frame(width: 32, height: 32)
                        .background(Color.black)
                        .cornerRadius(6)
                }
            }
            .padding(16)
        }
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
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
