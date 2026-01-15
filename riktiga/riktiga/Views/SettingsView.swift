import SwiftUI
import RevenueCat
import RevenueCatUI
import UIKit

struct SettingsView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @Environment(\.dismiss) var dismiss
    @State private var isPremium = RevenueCatManager.shared.isProMember
    @State private var isLoadingPremium = RevenueCatManager.shared.isLoading
    @State private var showSubscriptionView = false
    @State private var showDeleteAccountConfirmation = false
    @State private var isDeletingAccount = false
    @State private var showAdmin = false
    @State private var showAnnouncement = false
    @State private var hasLoadedOnce = false
    @State private var showReferralView = false
    @StateObject private var stravaService = StravaService.shared
    @State private var showStravaDisconnectConfirmation = false
    @State private var showConnectDevices = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 28) {
                    
                    // MARK: - PRENUMERATION Section
                    SettingsSectionView(title: "PRENUMERATION") {
                        VStack(spacing: 0) {
                            Button(action: {
                                if !isLoadingPremium && !isPremium {
                                    showSubscriptionView = true
                                }
                            }) {
                                SettingsItemRow(
                                    icon: "crown",
                                    title: "Up&Down PRO",
                                    subtitle: isLoadingPremium ? "Laddar..." : (isPremium ? "Aktiv prenumeration" : "Inaktiv"),
                                    subtitleColor: isPremium ? .green : .red,
                                    showCheckmark: isPremium
                                )
                            }
                            
                            if !isLoadingPremium && !isPremium {
                                SettingsItemDivider()
                                
                                Button(action: { showSubscriptionView = true }) {
                                    SettingsItemRow(icon: "star", title: "Uppgradera till PRO")
                                }
                            }
                            
                            SettingsItemDivider()
                            
                            Button(action: openSubscriptionManagement) {
                                SettingsItemRow(icon: "creditcard", title: "Hantera prenumeration")
                            }
                        }
                    }
                    
                    // MARK: - TJÄNA PENGAR Section
                    SettingsSectionView(title: "TJÄNA PENGAR") {
                        Button(action: { showReferralView = true }) {
                            SettingsItemRow(icon: "gift", title: "Referera och tjäna")
                        }
                    }
                    
                    // MARK: - KOPPLINGAR Section
                    SettingsSectionView(title: "KOPPLINGAR") {
                        VStack(spacing: 0) {
                            // Connect Devices (Terra API) - Hidden for now
                            /*
                            Button(action: { showConnectDevices = true }) {
                                HStack(spacing: 14) {
                                    Image(systemName: "applewatch.and.arrow.forward")
                                        .font(.system(size: 18))
                                        .foregroundColor(.black)
                                        .frame(width: 24)
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Anslut din utrustning")
                                            .font(.system(size: 16))
                                            .foregroundColor(.primary)
                                        
                                        Text("Garmin, Fitbit, Polar m.fl.")
                                            .font(.system(size: 13))
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    Spacer()
                                    
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(Color(.systemGray3))
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 14)
                            }
                            
                            SettingsItemDivider()
                            */
                            
                            // Strava
                            Button(action: {
                                if stravaService.isConnected {
                                    showStravaDisconnectConfirmation = true
                                } else {
                                    stravaService.startOAuthFlow()
                                }
                            }) {
                                HStack(spacing: 14) {
                                    Image("59")
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 24, height: 24)
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Synka med Strava")
                                            .font(.system(size: 16))
                                            .foregroundColor(.primary)
                                        
                                        if stravaService.isConnected {
                                            Text(stravaService.athleteName != nil ? "Ansluten som \(stravaService.athleteName!)" : "Ansluten")
                                                .font(.system(size: 13))
                                                .foregroundColor(.green)
                                        }
                                    }
                                    
                                    Spacer()
                                    
                                    if stravaService.isConnected {
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.system(size: 18))
                                            .foregroundColor(.green)
                                    } else {
                                        Image(systemName: "chevron.right")
                                            .font(.system(size: 14, weight: .medium))
                                            .foregroundColor(Color(.systemGray3))
                                    }
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 14)
                            }
                        }
                    }
                    
                    // MARK: - SUPPORT Section
                    SettingsSectionView(title: "SUPPORT") {
                        VStack(spacing: 0) {
                            Button(action: { openURL("https://wiggio.se") }) {
                                SettingsItemRow(icon: "questionmark.circle", title: "Hjälpcenter")
                            }
                            
                            SettingsItemDivider()
                            
                            Button(action: { openURL("https://wiggio.se") }) {
                                SettingsItemRow(icon: "envelope", title: "Kontakta oss")
                            }
                            
                            SettingsItemDivider()
                            
                            Button(action: { openURL("https://wiggio.se/privacy") }) {
                                SettingsItemRow(icon: "lock.shield", title: "Privacy Policy")
                            }
                        }
                    }
                    
                    // MARK: - APPLE HEALTH Section
                    SettingsSectionView(title: "HÄLSODATA") {
                        VStack(spacing: 0) {
                            VStack(alignment: .leading, spacing: 10) {
                                HStack(spacing: 12) {
                                    Image(systemName: "heart.fill")
                                        .font(.system(size: 20))
                                        .foregroundColor(.red)
                                    
                                    Text("Apple Health")
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(.primary)
                                }
                                
                                Text("Up&Down läser steg och distans från Apple Health för statistik.")
                                    .font(.system(size: 14))
                                    .foregroundColor(.secondary)
                                    .lineSpacing(2)
                            }
                            .padding(16)
                            
                            SettingsItemDivider()
                            
                            Button(action: openHealthSettings) {
                                SettingsItemRow(icon: "gear", title: "Hantera behörigheter")
                            }
                        }
                    }

                    // MARK: - ADMIN Section
                    if isAdmin {
                        SettingsSectionView(title: "ADMIN") {
                            VStack(spacing: 0) {
                                Button(action: { showAdmin = true }) {
                                    SettingsItemRow(icon: "person.badge.key", title: "Admin (ansökningar)")
                                }
                                
                                SettingsItemDivider()
                                
                                Button(action: { showAnnouncement = true }) {
                                    SettingsItemRow(icon: "megaphone", title: "Skicka notis till alla")
                                }
                            }
                        }
                    }

                    // MARK: - KONTO Section
                    SettingsSectionView(title: "KONTO") {
                        VStack(spacing: 0) {
                            Button(action: { showDeleteAccountConfirmation = true }) {
                                HStack(spacing: 14) {
                                    Image(systemName: "trash")
                                        .font(.system(size: 18))
                                        .foregroundColor(.red)
                                        .frame(width: 24)
                                    
                                    Text("Radera konto")
                                        .font(.system(size: 16))
                                        .foregroundColor(.red)
                                    
                                    Spacer()
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 14)
                            }
                            
                            SettingsItemDivider()
                            
                            Button(action: {
                                authViewModel.logout()
                                dismiss()
                            }) {
                                HStack(spacing: 14) {
                                    Image(systemName: "rectangle.portrait.and.arrow.right")
                                        .font(.system(size: 18))
                                        .foregroundColor(.red)
                                        .frame(width: 24)
                                    
                                    Text("Logga ut")
                                        .font(.system(size: 16))
                                        .foregroundColor(.red)
                                    
                                    Spacer()
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 14)
                            }
                        }
                    }
                    
                    Spacer(minLength: 20)
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 40)
            }
            .background(Color(.systemGroupedBackground))
            .scrollIndicators(.hidden)
            .navigationTitle("Inställningar")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Klar") {
                        dismiss()
                    }
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                }
            }
            .sheet(isPresented: $showSubscriptionView) {
                PresentPaywallView()
            }
            .sheet(isPresented: $showAdmin) {
                AdminTrainerApprovalsView()
            }
            .sheet(isPresented: $showAnnouncement) {
                AdminAnnouncementView()
            }
            .sheet(isPresented: $showReferralView) {
                ReferralView()
            }
            .sheet(isPresented: $showConnectDevices) {
                ConnectDeviceView()
            }
            .task {
                guard !hasLoadedOnce else { return }
                hasLoadedOnce = true
                
                if !isPremium && !isLoadingPremium {
                    await RevenueCatManager.shared.syncAndRefresh()
                }
            }
            .onReceive(RevenueCatManager.shared.$isProMember) { newValue in
                isPremium = newValue
            }
            .onReceive(RevenueCatManager.shared.$isLoading) { newValue in
                isLoadingPremium = newValue
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
            .confirmationDialog("Koppla bort Strava", isPresented: $showStravaDisconnectConfirmation, titleVisibility: .visible) {
                Button("Koppla bort", role: .destructive) {
                    stravaService.disconnect()
                }
                Button("Avbryt", role: .cancel) {}
            } message: {
                Text("Vill du koppla bort ditt Strava-konto? Dina pass kommer inte längre synkas automatiskt.")
            }
        }
    }
    
    private var isAdmin: Bool {
        let adminEmails: Set<String> = ["admin@updown.app", "wiggohelgesson@gmail.com", "info@wiggio.se", "info@bylito.se"]
        let email = authViewModel.currentUser?.email ?? ""
        return adminEmails.contains(email.lowercased())
    }

    private func deleteAccount() async {
        isDeletingAccount = true
        
        do {
            guard let userId = authViewModel.currentUser?.id else {
                isDeletingAccount = false
                return
            }
            
            try await ProfileService.shared.deleteUserAccount(userId: userId)
            
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

// MARK: - Settings Section View
struct SettingsSectionView<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.secondary)
                .padding(.horizontal, 4)
            
            VStack(spacing: 0) {
                content
            }
            .background(Color(.systemBackground))
            .cornerRadius(12)
        }
    }
}

// MARK: - Settings Item Row
struct SettingsItemRow: View {
    let icon: String
    let title: String
    var subtitle: String? = nil
    var subtitleColor: Color = .secondary
    var showCheckmark: Bool = false
    
    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(.primary.opacity(0.7))
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 16))
                    .foregroundColor(.primary)
                
                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.system(size: 13))
                        .foregroundColor(subtitleColor)
                }
            }
            
            Spacer()
            
            if showCheckmark {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 18))
                    .foregroundColor(.green)
            } else {
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Color(.systemGray3))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .contentShape(Rectangle())
    }
}

// MARK: - Settings Item Divider
struct SettingsItemDivider: View {
    var body: some View {
        Divider()
            .padding(.leading, 54)
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
