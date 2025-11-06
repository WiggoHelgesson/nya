import SwiftUI
import RevenueCat
import RevenueCatUI
import UIKit

struct SettingsView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @Environment(\.dismiss) var dismiss
    @ObservedObject private var purchaseService = PurchaseService.shared
    @ObservedObject private var revenueCatManager = RevenueCatManager.shared
    @State private var showSubscriptionView = false
    @State private var showDeleteAccountConfirmation = false
    @State private var isDeletingAccount = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGray6)
                    .ignoresSafeArea()

                ScrollView {
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
                                    
                                    if revenueCatManager.isLoading {
                                        ProgressView()
                                            .scaleEffect(0.7)
                                            .frame(height: 16)
                                    } else {
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
                                }
                                
                                Spacer()
                                
                                if !revenueCatManager.isLoading {
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
                            }
                            .padding(16)
                            .onTapGesture {
                                if !revenueCatManager.isLoading && !revenueCatManager.isPremium {
                                    showSubscriptionView = true
                                }
                            }
                            
                            Divider()
                                .padding(.leading, 16)
                            
                            // Upgrade to PRO Row (only show if not premium)
                            if !revenueCatManager.isLoading && !revenueCatManager.isPremium {
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
                                action: openSubscriptionManagement
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
                        
                        HealthDataDisclosureView(
                            title: "Så använder vi Apple Health",
                            description: "Up&Down läser dina steg- och distansdata från Apple Health för att visa statistik och topplistor. Du kan när som helst ändra behörigheten i Hälsa-appen.",
                            showsManageButton: true,
                            manageAction: openHealthSettings
                        )
                        .padding(.horizontal, 16)
                        .padding(.bottom, 12)
                        
                        VStack(spacing: 0) {
                            SettingsRow(
                                title: "Hur du använder Up&Down",
                                icon: "chevron.right",
                                action: {
                                    openURL("https://wiggio.se")
                                }
                            )
                            
                            Divider()
                                .padding(.leading, 16)
                            
                            SettingsRow(
                                title: "Vanliga frågor",
                                icon: "chevron.right",
                                action: {
                                    openURL("https://wiggio.se")
                                }
                            )
                            
                            Divider()
                                .padding(.leading, 16)
                            
                            SettingsRow(
                                title: "Kontakta oss",
                                icon: "chevron.right",
                                action: {
                                    openURL("https://wiggio.se")
                                }
                            )
                            
                            Divider()
                                .padding(.leading, 16)
                            
                            SettingsRow(
                                title: "Privacy Policy",
                                icon: "chevron.right",
                                action: {
                                    openURL("https://wiggio.se/privacy")
                                }
                            )
                        }
                        .background(Color.white)
                        .cornerRadius(12)
                    }

                    // MARK: - Radera konto Button
                    Button(action: {
                        showDeleteAccountConfirmation = true
                    }) {
                        HStack(spacing: 12) {
                            Image(systemName: "trash.fill")
                                .font(.system(size: 16))
                                .foregroundColor(.red)
                            
                            Text("Radera konto")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.red)
                            
                            Spacer()
                        }
                        .padding(16)
                        .background(Color.white)
                        .cornerRadius(12)
                    }

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
                    .padding(.bottom, 8)
                }
                .frame(maxWidth: 640)
                .padding(.horizontal, 16)
                .padding(.vertical, 32)
            }
            .scrollIndicators(.hidden)
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
                PresentPaywallView()
            }
            .task {
                // Only load if not already loaded or loading
                await revenueCatManager.syncAndRefresh()
            }
            .confirmationDialog("Radera konto", isPresented: $showDeleteAccountConfirmation, titleVisibility: .visible) {
                Button("Radera konto", role: .destructive) {
                    Task {
                        await deleteAccount()
                    }
                }
                Button("Avbryt", role: .cancel) {}
            } message: {
                Text("Är du säker på att du vill radera ditt konto? Denna åtgärd kan inte ångras.")
            }
        }
    }
    
    private func deleteAccount() async {
        isDeletingAccount = true
        
        do {
            guard let userId = authViewModel.currentUser?.id else {
                isDeletingAccount = false
                return
            }
            
            // Ta bort användare från databasen
            try await ProfileService.shared.deleteUserAccount(userId: userId)
            
            // Logga ut användaren
            await MainActor.run {
                authViewModel.logout()
                dismiss()
            }
        } catch {
            print("❌ Error deleting account: \(error)")
            isDeletingAccount = false
        }
    }
    
    private func openURL(_ urlString: String) {
        if let url = URL(string: urlString) {
            UIApplication.shared.open(url)
        }
    }
    
    private func openHealthSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
    
    private func openSubscriptionManagement() {
        guard let url = URL(string: "https://apps.apple.com/account/subscriptions") else { return }
        UIApplication.shared.open(url)
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

struct PresentPaywallView: View {
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        PaywallView()
    }
}

#Preview {
    SettingsView()
        .environmentObject(AuthViewModel())
}
