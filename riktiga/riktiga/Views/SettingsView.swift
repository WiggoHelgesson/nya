import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @Environment(\.dismiss) var dismiss
    @StateObject private var purchaseService = PurchaseService.shared
    @StateObject private var revenueCatManager = RevenueCatManager.shared
    @State private var showSubscriptionView = false
    @State private var showProManagementView = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGray6)
                    .ignoresSafeArea()
                
                VStack(spacing: 24) {
                    // MARK: - PRENUMERATION Section
                    VStack(alignment: .leading, spacing: 0) {
                        Text("PRENUMERATION")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.gray)
                            .padding(.horizontal, 16)
                            .padding(.bottom, 8)
                        
                        VStack(spacing: 0) {
                            // PRO Status Row
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Up&Down PRO")
                                        .font(.system(size: 16))
                                        .foregroundColor(.black)
                                    
                                    if revenueCatManager.isPremium {
                                        Text("Aktiv prenumeration")
                                            .font(.system(size: 12))
                                            .foregroundColor(.green)
                                    } else {
                                        Text("Inaktiv")
                                            .font(.system(size: 12))
                                            .foregroundColor(.red)
                                    }
                                }
                                
                                Spacer()
                                
                                if revenueCatManager.isPremium {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 16))
                                        .foregroundColor(.green)
                                } else {
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(.gray)
                                }
                            }
                            .padding(16)
                            .onTapGesture {
                                if !revenueCatManager.isPremium {
                                    showSubscriptionView = true
                                }
                            }
                            
                            Divider()
                                .padding(.leading, 16)
                            
                            // Upgrade to PRO Row (only show if not premium)
                            if !revenueCatManager.isPremium {
                                SettingsRow(
                                    title: "Uppgradera till PRO",
                                    icon: "chevron.right",
                                    action: {
                                        showSubscriptionView = true
                                    }
                                )
                                
                                Divider()
                                    .padding(.leading, 16)
                            }
                            
                            // Manage Subscription Row
                            SettingsRow(
                                title: "Hantera prenumeration",
                                icon: "chevron.right",
                                action: {
                                    showProManagementView = true
                                }
                            )
                        }
                        .background(Color.white)
                        .cornerRadius(12)
                    }
                    
                    // MARK: - INFORMATION Section
                    VStack(alignment: .leading, spacing: 0) {
                        Text("INFORMATION")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.gray)
                            .padding(.horizontal, 16)
                            .padding(.bottom, 8)
                        
                        VStack(spacing: 0) {
                            SettingsRow(
                                title: "Hur du använder Up&Down",
                                icon: "chevron.right",
                                action: {}
                            )
                            
                            Divider()
                                .padding(.leading, 16)
                            
                            SettingsRow(
                                title: "Vanliga frågor",
                                icon: "chevron.right",
                                action: {}
                            )
                            
                            Divider()
                                .padding(.leading, 16)
                            
                            SettingsRow(
                                title: "Kontakta oss",
                                icon: "chevron.right",
                                action: {}
                            )
                            
                            Divider()
                                .padding(.leading, 16)
                            
                            SettingsRow(
                                title: "Privacy Policy",
                                icon: "chevron.right",
                                action: {}
                            )
                        }
                        .background(Color.white)
                        .cornerRadius(12)
                    }
                    
                    Spacer()
                    
                    // MARK: - Logga ut Button
                    Button(action: {
                        authViewModel.logout()
                        dismiss()
                    }) {
                        HStack(spacing: 12) {
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                                .font(.system(size: 16))
                                .foregroundColor(.red)
                            
                            Text("Logga ut")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.red)
                            
                            Spacer()
                        }
                        .padding(16)
                        .background(Color.white)
                        .cornerRadius(12)
                    }
                }
                .padding(16)
            }
            .navigationTitle("Inställningar")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Klar") {
                        dismiss()
                    }
                    .foregroundColor(.black)
                }
            }
            .sheet(isPresented: $showSubscriptionView) {
                SubscriptionView()
            }
            .sheet(isPresented: $showProManagementView) {
                ProManagementView()
            }
            .onAppear {
                Task {
                    await revenueCatManager.loadCustomerInfo()
                }
            }
        }
    }
}

struct SettingsRow: View {
    let title: String
    let icon: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Text(title)
                    .font(.system(size: 16))
                    .foregroundColor(.black)
                
                Spacer()
                
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.gray)
            }
            .padding(16)
        }
    }
}

#Preview {
    SettingsView()
        .environmentObject(AuthViewModel())
}
