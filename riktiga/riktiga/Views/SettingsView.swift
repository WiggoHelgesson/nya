import SwiftUI
import RevenueCat
import RevenueCatUI
import UIKit
import Supabase

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
    @ObservedObject private var languageManager = LanguageManager.shared
    @State private var showStravaDisconnectConfirmation = false
    @State private var showNutritionOnboarding = false
    @State private var showPersonalDetails = false
    @State private var showSchoolPicker = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    prenumerationSection
                    dinSkolaSection
                    dittKontoSection
                    kopplingarSection
                    sprakSection
                    naringOchMalSection
                    kundtjanstSection
                    foljOssSection
                    adminSection
                    raderaOchLoggaUtSection
                    Spacer(minLength: 20)
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 40)
            }
            .background(
                // Light blue gradient background
                LinearGradient(
                    colors: [
                        Color(red: 0.95, green: 0.97, blue: 1.0),
                        Color(red: 0.98, green: 0.95, blue: 0.97),
                        Color(.systemGroupedBackground)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
            )
            .scrollIndicators(.hidden)
            .navigationTitle(L.t(sv: "Inställningar", nb: "Innstillinger"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(L.t(sv: "Klar", nb: "Ferdig")) {
                        dismiss()
                    }
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                }
            }
            .onChange(of: showSubscriptionView) { _, newValue in
                if newValue {
                    SuperwallService.shared.showPaywall()
                    showSubscriptionView = false
                }
            }
            .sheet(isPresented: $showAdmin) {
                AdminTrainerApprovalsView()
            }
            .sheet(isPresented: $showAnnouncement) {
                AdminAnnouncementView()
            }
            .navigationDestination(isPresented: $showReferralView) {
                ReferralView()
                    .environmentObject(authViewModel)
            }
            .navigationDestination(isPresented: $showPersonalDetails) {
                PersonalDetailsView()
                    .environmentObject(authViewModel)
            }
            .sheet(isPresented: $showNutritionOnboarding) {
                NutritionSettingsView()
                    .environmentObject(authViewModel)
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
            .confirmationDialog(L.t(sv: "Radera konto", nb: "Slett konto"), isPresented: $showDeleteAccountConfirmation, titleVisibility: .visible) {
                Button(L.t(sv: "Radera konto", nb: "Slett konto"), role: .destructive) {
                    Task {
                        await deleteAccount()
                    }
                }
                Button(L.t(sv: "Avbryt", nb: "Avbryt"), role: .cancel) {}
            } message: {
                Text(L.t(sv: "Är du säker på att du vill radera ditt konto? Denna åtgärd kan inte ångras.", nb: "Er du sikker på at du vil slette kontoen din? Denne handlingen kan ikke angres."))
            }
            .confirmationDialog(L.t(sv: "Koppla bort Strava", nb: "Koble fra Strava"), isPresented: $showStravaDisconnectConfirmation, titleVisibility: .visible) {
                Button(L.t(sv: "Koppla bort", nb: "Koble fra"), role: .destructive) {
                    stravaService.disconnect()
                }
                Button(L.t(sv: "Avbryt", nb: "Avbryt"), role: .cancel) {}
            } message: {
                Text(L.t(sv: "Vill du koppla bort ditt Strava-konto? Dina pass kommer inte längre synkas automatiskt.", nb: "Vil du koble fra Strava-kontoen din? Øktene dine vil ikke lenger synkroniseres automatisk."))
            }
        }
    }
    
    // MARK: - Section Views
    
    private var prenumerationSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L.t(sv: "Prenumeration", nb: "Abonnement"))
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.secondary)
                .padding(.horizontal, 4)
            
            VStack(spacing: 0) {
                Button(action: {
                    if !isLoadingPremium && !isPremium {
                        showSubscriptionView = true
                    }
                }) {
                    HStack(spacing: 14) {
                        Image(systemName: "crown.fill")
                            .font(.system(size: 18))
                            .foregroundColor(.black)
                            .frame(width: 24)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Up&Down PRO")
                                .font(.system(size: 16))
                                .foregroundColor(.primary)
                            
                            Text(isLoadingPremium ? L.t(sv: "Laddar...", nb: "Laster...") : (isPremium ? L.t(sv: "Aktiv prenumeration", nb: "Aktivt abonnement") : L.t(sv: "Inaktiv", nb: "Inaktiv")))
                                .font(.system(size: 13))
                                .foregroundColor(isPremium ? .green : .secondary)
                        }
                        
                        Spacer()
                        
                        if isPremium {
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
                
                SettingsItemDivider()
                
                Button(action: openSubscriptionManagement) {
                    NewSettingsRow(icon: "creditcard", title: L.t(sv: "Hantera prenumeration", nb: "Administrer abonnement"))
                }
            }
            .background(Color(.systemBackground))
            .cornerRadius(12)
        }
    }
    
    private var dinSkolaSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L.t(sv: "Din skola", nb: "Din skole"))
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.secondary)
                .padding(.horizontal, 4)
            
            Button(action: { showSchoolPicker = true }) {
                HStack(spacing: 14) {
                    Image(systemName: "graduationcap.fill")
                        .font(.system(size: 18))
                        .foregroundColor(.primary)
                        .frame(width: 24)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        if let user = authViewModel.currentUser,
                           let schoolName = SchoolService.shared.schoolName(for: user) {
                            Text(schoolName)
                                .font(.system(size: 16))
                                .foregroundColor(.primary)
                            Text(L.t(sv: "Tryck för att byta skola", nb: "Trykk for å bytte skole"))
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                        } else {
                            Text(L.t(sv: "Ingen skola vald", nb: "Ingen skole valgt"))
                                .font(.system(size: 16))
                                .foregroundColor(.primary)
                            Text(L.t(sv: "Tryck för att välja skola", nb: "Trykk for å velge skole"))
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(Color(.systemGray3))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
            }
            .background(Color(.systemBackground))
            .cornerRadius(12)
        }
        .sheet(isPresented: $showSchoolPicker) {
            SchoolVerificationView(isVerified: .constant(true)) {
                showSchoolPicker = false
            }
            .environmentObject(authViewModel)
        }
    }
    
    private var dittKontoSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L.t(sv: "Ditt konto", nb: "Din konto"))
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.secondary)
                .padding(.horizontal, 4)
            
            VStack(spacing: 0) {
                Button(action: { showPersonalDetails = true }) {
                    NewSettingsRow(icon: "person.text.rectangle", title: L.t(sv: "Personliga detaljer", nb: "Personlige detaljer"))
                }
                
                SettingsItemDivider()
                
                Button(action: openHealthSettings) {
                    NewSettingsRow(icon: "heart.fill", title: "Apple Health")
                }
            }
            .background(Color(.systemBackground))
            .cornerRadius(12)
        }
    }
    
    private var kopplingarSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L.t(sv: "Kopplingar", nb: "Koblinger"))
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.secondary)
                .padding(.horizontal, 4)
            
            VStack(spacing: 0) {
                Button(action: {
                    if stravaService.isConnected {
                        showStravaDisconnectConfirmation = true
                    } else {
                        stravaService.startOAuthFlow()
                    }
                }) {
                    HStack(spacing: 14) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.orange)
                                .frame(width: 28, height: 28)
                            
                            Image(systemName: "figure.run")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.white)
                        }
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Strava")
                                .font(.system(size: 16))
                                .foregroundColor(.primary)
                            
                            Text(stravaService.isConnected ? L.t(sv: "Ansluten", nb: "Tilkoblet") : L.t(sv: "Inte ansluten", nb: "Ikke tilkoblet"))
                                .font(.system(size: 13))
                                .foregroundColor(stravaService.isConnected ? .green : .secondary)
                        }
                        
                        Spacer()
                        
                        if stravaService.isLoading {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else if stravaService.isConnected {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 18))
                                .foregroundColor(.green)
                        } else {
                            Text(L.t(sv: "Anslut", nb: "Koble til"))
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.orange)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                }
            }
            .background(Color(.systemBackground))
            .cornerRadius(12)
        }
    }
    
    private var sprakSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L.t(sv: "Språk", nb: "Språk"))
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.secondary)
                .padding(.horizontal, 4)
            
            VStack(spacing: 0) {
                ForEach(AppLanguage.allCases, id: \.self) { language in
                    Button(action: {
                        withAnimation(.smooth(duration: 0.3)) {
                            languageManager.currentLanguage = language
                        }
                    }) {
                        HStack(spacing: 14) {
                            Text(language.flag)
                                .font(.system(size: 22))
                                .frame(width: 24)
                            
                            Text(language.displayName)
                                .font(.system(size: 16))
                                .foregroundColor(.primary)
                            
                            Spacer()
                            
                            if languageManager.currentLanguage == language {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 18))
                                    .foregroundColor(.green)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                    }
                    .buttonStyle(.plain)
                    
                    if language != AppLanguage.allCases.last {
                        SettingsItemDivider()
                    }
                }
            }
            .background(Color(.systemBackground))
            .cornerRadius(12)
        }
    }
    
    private var naringOchMalSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L.t(sv: "Näring & mål", nb: "Ernæring og mål"))
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.secondary)
                .padding(.horizontal, 4)
            
            VStack(spacing: 0) {
                Button(action: { showNutritionOnboarding = true }) {
                    NewSettingsRow(icon: "target", title: L.t(sv: "Uppdatera näringsinställningar", nb: "Oppdater ernæringsinnstillinger"))
                }
                
                SettingsItemDivider()
                
                Button(action: { showPersonalDetails = true }) {
                    NewSettingsRow(icon: "flag", title: L.t(sv: "Mål & nuvarande vikt", nb: "Mål og nåværende vekt"))
                }
            }
            .background(Color(.systemBackground))
            .cornerRadius(12)
        }
    }
    
    private var kundtjanstSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L.t(sv: "Kundtjänst & legalt", nb: "Kundeservice og juridisk"))
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.secondary)
                .padding(.horizontal, 4)
            
            VStack(spacing: 0) {
                Button(action: { openMailTo() }) {
                    NewSettingsRow(icon: "envelope", title: L.t(sv: "Skicka ett mail", nb: "Send en e-post"))
                }
                
                SettingsItemDivider()
                
                Button(action: { openURL("https://www.upanddownapp.com/privacy") }) {
                    NewSettingsRow(icon: "lock.shield", title: L.t(sv: "Integritetspolicy", nb: "Personvernerklæring"))
                }
                
                SettingsItemDivider()
                
                Button(action: { openURL("https://www.upanddownapp.com/terms") }) {
                    NewSettingsRow(icon: "doc.text", title: L.t(sv: "Våra Villkor", nb: "Våre vilkår"))
                }
            }
            .background(Color(.systemBackground))
            .cornerRadius(12)
        }
    }
    
    private var foljOssSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L.t(sv: "Följ oss", nb: "Følg oss"))
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.secondary)
                .padding(.horizontal, 4)
            
            VStack(spacing: 0) {
                Button(action: { openURL("https://instagram.com/upanddownapp") }) {
                    HStack(spacing: 14) {
                        Image(systemName: "camera")
                            .font(.system(size: 18))
                            .foregroundColor(.black)
                            .frame(width: 24)
                        
                        Text("Instagram")
                            .font(.system(size: 16))
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(Color(.systemGray3))
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                }
                
                SettingsItemDivider()
                
                Button(action: { openURL("https://tiktok.com/@upanddownapp") }) {
                    HStack(spacing: 14) {
                        Image(systemName: "play.rectangle")
                            .font(.system(size: 18))
                            .foregroundColor(.primary)
                            .frame(width: 24)
                        
                        Text("TikTok")
                            .font(.system(size: 16))
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(Color(.systemGray3))
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                }
            }
            .background(Color(.systemBackground))
            .cornerRadius(12)
        }
    }
    
    @ViewBuilder
    private var adminSection: some View {
        if isAdmin {
            VStack(alignment: .leading, spacing: 8) {
                Text(L.t(sv: "Admin", nb: "Admin"))
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 4)
                
                VStack(spacing: 0) {
                    Button(action: { showAdmin = true }) {
                        NewSettingsRow(icon: "person.badge.key", title: L.t(sv: "Admin (ansökningar)", nb: "Admin (søknader)"))
                    }
                    
                    SettingsItemDivider()
                    
                    Button(action: { showAnnouncement = true }) {
                        NewSettingsRow(icon: "megaphone", title: L.t(sv: "Skicka notis till alla", nb: "Send varsel til alle"))
                    }
                }
                .background(Color(.systemBackground))
                .cornerRadius(12)
            }
        }
    }
    
    private var raderaOchLoggaUtSection: some View {
        VStack(spacing: 0) {
            Button(action: { showDeleteAccountConfirmation = true }) {
                HStack(spacing: 14) {
                    Image(systemName: "trash")
                        .font(.system(size: 18))
                        .foregroundColor(.red)
                        .frame(width: 24)
                    
                    Text(L.t(sv: "Radera konto", nb: "Slett konto"))
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
                    
                    Text(L.t(sv: "Logga ut", nb: "Logg ut"))
                        .font(.system(size: 16))
                        .foregroundColor(.red)
                    
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
            }
        }
        .background(Color(.systemBackground))
        .cornerRadius(12)
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
    
    private func openMailTo() {
        if let url = URL(string: "mailto:info@wiggio.se") {
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

// MARK: - New Settings Row
struct NewSettingsRow: View {
    let icon: String
    var iconColor: Color = .black
    let title: String
    
    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(iconColor)
                .frame(width: 24)
            
            Text(title)
                .font(.system(size: 16))
                .foregroundColor(.primary)
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(Color(.systemGray3))
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

// MARK: - Personal Details View
struct PersonalDetailsView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var goalWeight: Double = 65.0
    @State private var currentWeight: Double = 70.0
    @State private var height: Int = 170
    @State private var birthDate: Date = Date()
    @State private var gender: String = "male"
    @State private var dailyStepGoal: Int = 10000
    
    @State private var isLoading = true
    @State private var isSaving = false
    @State private var showGoalWeightPicker = false
    @State private var showCurrentWeightPicker = false
    @State private var showHeightPicker = false
    @State private var showBirthDatePicker = false
    @State private var showGenderPicker = false
    @State private var showStepGoalPicker = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Goal Weight Card
                VStack(spacing: 0) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(L.t(sv: "Målvikt", nb: "Målvekt"))
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                            Text("\(Int(goalWeight)) kg")
                                .font(.system(size: 24, weight: .bold))
                        }
                        
                        Spacer()
                        
                        Button(L.t(sv: "Ändra mål", nb: "Endre mål")) {
                            showGoalWeightPicker = true
                        }
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Color.black)
                        .cornerRadius(20)
                    }
                    .padding(20)
                }
                .background(Color(.systemBackground))
                .cornerRadius(16)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                )
                
                // Personal Details Card
                VStack(spacing: 0) {
                    // Current Weight
                    detailRow(title: L.t(sv: "Nuvarande vikt", nb: "Nåværende vekt"), value: "\(Int(currentWeight)) kg") {
                        showCurrentWeightPicker = true
                    }
                    
                    Divider().padding(.leading, 16)
                    
                    // Height
                    detailRow(title: L.t(sv: "Längd", nb: "Høyde"), value: "\(height) cm") {
                        showHeightPicker = true
                    }
                    
                    Divider().padding(.leading, 16)
                    
                    // Birth Date
                    detailRow(title: L.t(sv: "Födelsedatum", nb: "Fødselsdato"), value: formatDate(birthDate)) {
                        showBirthDatePicker = true
                    }
                    
                    Divider().padding(.leading, 16)
                    
                    // Gender
                    detailRow(title: L.t(sv: "Kön", nb: "Kjønn"), value: genderDisplayName) {
                        showGenderPicker = true
                    }
                    
                    Divider().padding(.leading, 16)
                    
                    // Daily Step Goal
                    detailRow(title: L.t(sv: "Dagligt stegmål", nb: "Daglig skrittmål"), value: L.t(sv: "\(dailyStepGoal) steg", nb: "\(dailyStepGoal) skritt")) {
                        showStepGoalPicker = true
                    }
                }
                .background(Color(.systemBackground))
                .cornerRadius(16)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                )
                
                Spacer(minLength: 40)
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(L.t(sv: "Personliga detaljer", nb: "Personlige detaljer"))
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "arrow.left")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.black)
                        .frame(width: 40, height: 40)
                        .background(Color(.systemGray5))
                        .clipShape(Circle())
                }
            }
        }
        .task {
            await loadUserData()
        }
        .sheet(isPresented: $showGoalWeightPicker) {
            weightPickerSheet(title: L.t(sv: "Målvikt", nb: "Målvekt"), weight: $goalWeight, onSave: saveGoalWeight)
        }
        .sheet(isPresented: $showCurrentWeightPicker) {
            weightPickerSheet(title: L.t(sv: "Nuvarande vikt", nb: "Nåværende vekt"), weight: $currentWeight, onSave: saveCurrentWeight)
        }
        .sheet(isPresented: $showHeightPicker) {
            heightPickerSheet()
        }
        .sheet(isPresented: $showBirthDatePicker) {
            birthDatePickerSheet()
        }
        .sheet(isPresented: $showGenderPicker) {
            genderPickerSheet()
        }
        .sheet(isPresented: $showStepGoalPicker) {
            stepGoalPickerSheet()
        }
    }
    
    private var genderDisplayName: String {
        switch gender.lowercased() {
        case "male": return L.t(sv: "Man", nb: "Mann")
        case "female": return L.t(sv: "Kvinna", nb: "Kvinne")
        default: return L.t(sv: "Annat", nb: "Annet")
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
    
    private func detailRow(title: String, value: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Text(title)
                    .font(.system(size: 16))
                    .foregroundColor(.primary)
                
                Spacer()
                
                Text(value)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.primary)
                
                Image(systemName: "pencil")
                    .font(.system(size: 14))
                    .foregroundColor(.gray)
            }
            .padding(16)
        }
    }
    
    private func loadUserData() async {
        guard let userId = authViewModel.currentUser?.id else {
            isLoading = false
            return
        }
        
        // Load from NutritionGoalsManager and profile
        if let goals = NutritionGoalsManager.shared.loadGoals(userId: userId) {
            // Goals loaded
        }
        
        // Load profile data directly from Supabase to get all fields
        do {
            struct ProfileData: Decodable {
                let height_cm: Int?
                let weight_kg: Double?
                let target_weight: Double?
                let gender: String?
                let birth_date: String?
                let daily_step_goal: Int?
            }
            
            let profiles: [ProfileData] = try await SupabaseConfig.supabase
                .from("profiles")
                .select("height_cm, weight_kg, target_weight, gender, birth_date, daily_step_goal")
                .eq("id", value: userId)
                .execute()
                .value
            
            if let profile = profiles.first {
                await MainActor.run {
                    if let heightCm = profile.height_cm {
                        self.height = heightCm
                    }
                    if let weightKg = profile.weight_kg {
                        self.currentWeight = weightKg
                    }
                    if let targetWeight = profile.target_weight {
                        self.goalWeight = targetWeight
                    }
                    if let genderValue = profile.gender {
                        self.gender = genderValue
                    }
                    if let birthDateStr = profile.birth_date {
                        let formatter = DateFormatter()
                        formatter.dateFormat = "yyyy-MM-dd"
                        if let date = formatter.date(from: birthDateStr) {
                            self.birthDate = date
                        }
                    }
                    if let stepGoal = profile.daily_step_goal {
                        self.dailyStepGoal = stepGoal
                    }
                    self.isLoading = false
                }
            } else {
                await MainActor.run {
                    self.isLoading = false
                }
            }
        } catch {
            print("❌ Error loading profile data: \(error)")
            await MainActor.run {
                self.isLoading = false
            }
        }
    }
    
    private func saveGoalWeight() {
        guard let userId = authViewModel.currentUser?.id else { return }
        
        Task {
            do {
                try await SupabaseConfig.supabase
                    .from("profiles")
                    .update(["target_weight": goalWeight])
                    .eq("id", value: userId)
                    .execute()
                print("✅ Goal weight saved: \(goalWeight)")
            } catch {
                print("❌ Error saving goal weight: \(error)")
            }
        }
    }
    
    private func saveCurrentWeight() {
        guard let userId = authViewModel.currentUser?.id else { return }
        
        Task {
            do {
                try await SupabaseConfig.supabase
                    .from("profiles")
                    .update(["weight_kg": currentWeight])
                    .eq("id", value: userId)
                    .execute()
                print("✅ Current weight saved: \(currentWeight)")
            } catch {
                print("❌ Error saving current weight: \(error)")
            }
        }
    }
    
    // MARK: - Picker Sheets
    private func weightPickerSheet(title: String, weight: Binding<Double>, onSave: @escaping () -> Void) -> some View {
        NavigationStack {
            VStack {
                Picker("", selection: weight) {
                    ForEach(30...200, id: \.self) { w in
                        Text("\(w) kg").tag(Double(w))
                    }
                }
                .pickerStyle(.wheel)
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L.t(sv: "Avbryt", nb: "Avbryt")) {
                        showGoalWeightPicker = false
                        showCurrentWeightPicker = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L.t(sv: "Spara", nb: "Lagre")) {
                        onSave()
                        showGoalWeightPicker = false
                        showCurrentWeightPicker = false
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.height(300)])
    }
    
    private func heightPickerSheet() -> some View {
        NavigationStack {
            VStack {
                Picker("", selection: $height) {
                    ForEach(100...250, id: \.self) { h in
                        Text("\(h) cm").tag(h)
                    }
                }
                .pickerStyle(.wheel)
            }
            .navigationTitle(L.t(sv: "Längd", nb: "Høyde"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L.t(sv: "Avbryt", nb: "Avbryt")) { showHeightPicker = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L.t(sv: "Spara", nb: "Lagre")) {
                        saveHeight()
                        showHeightPicker = false
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.height(300)])
    }
    
    private func birthDatePickerSheet() -> some View {
        NavigationStack {
            VStack {
                DatePicker("", selection: $birthDate, displayedComponents: .date)
                    .datePickerStyle(.wheel)
                    .labelsHidden()
            }
            .navigationTitle(L.t(sv: "Födelsedatum", nb: "Fødselsdato"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L.t(sv: "Avbryt", nb: "Avbryt")) { showBirthDatePicker = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L.t(sv: "Spara", nb: "Lagre")) {
                        saveBirthDate()
                        showBirthDatePicker = false
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.height(300)])
    }
    
    private func genderPickerSheet() -> some View {
        NavigationStack {
            VStack {
                Picker("", selection: $gender) {
                    Text(L.t(sv: "Man", nb: "Mann")).tag("male")
                    Text(L.t(sv: "Kvinna", nb: "Kvinne")).tag("female")
                    Text(L.t(sv: "Annat", nb: "Annet")).tag("other")
                }
                .pickerStyle(.wheel)
            }
            .navigationTitle(L.t(sv: "Kön", nb: "Kjønn"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L.t(sv: "Avbryt", nb: "Avbryt")) { showGenderPicker = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L.t(sv: "Spara", nb: "Lagre")) {
                        saveGender()
                        showGenderPicker = false
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.height(300)])
    }
    
    private func stepGoalPickerSheet() -> some View {
        NavigationStack {
            VStack {
                Picker("", selection: $dailyStepGoal) {
                    ForEach([5000, 6000, 7000, 7500, 8000, 10000, 12000, 15000, 20000], id: \.self) { steps in
                        Text(L.t(sv: "\(steps) steg", nb: "\(steps) skritt")).tag(steps)
                    }
                }
                .pickerStyle(.wheel)
            }
            .navigationTitle(L.t(sv: "Dagligt stegmål", nb: "Daglig skrittmål"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L.t(sv: "Avbryt", nb: "Avbryt")) { showStepGoalPicker = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L.t(sv: "Spara", nb: "Lagre")) {
                        saveStepGoal()
                        showStepGoalPicker = false
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.height(300)])
    }
    
    private func saveHeight() {
        guard let userId = authViewModel.currentUser?.id else { return }
        Task {
            do {
                try await SupabaseConfig.supabase
                    .from("profiles")
                    .update(["height_cm": height])
                    .eq("id", value: userId)
                    .execute()
            } catch {
                print("❌ Error saving height: \(error)")
            }
        }
    }
    
    private func saveBirthDate() {
        guard let userId = authViewModel.currentUser?.id else { return }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let dateString = formatter.string(from: birthDate)
        Task {
            do {
                try await SupabaseConfig.supabase
                    .from("profiles")
                    .update(["birth_date": dateString])
                    .eq("id", value: userId)
                    .execute()
            } catch {
                print("❌ Error saving birth date: \(error)")
            }
        }
    }
    
    private func saveGender() {
        guard let userId = authViewModel.currentUser?.id else { return }
        Task {
            do {
                try await SupabaseConfig.supabase
                    .from("profiles")
                    .update(["gender": gender])
                    .eq("id", value: userId)
                    .execute()
            } catch {
                print("❌ Error saving gender: \(error)")
            }
        }
    }
    
    private func saveStepGoal() {
        guard let userId = authViewModel.currentUser?.id else { return }
        UserDefaults.standard.set(dailyStepGoal, forKey: "dailyStepGoal_\(userId)")
    }
}

struct PresentPaywallView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject private var revenueCatManager = RevenueCatManager.shared
    @State private var hasAttemptedLoad = false
    
    var body: some View {
        Group {
            if let offerings = revenueCatManager.offerings {
                // Debug: Print all available offerings
                let _ = print("📦 Available offerings: \(offerings.all.keys.joined(separator: ", "))")
                let _ = print("📦 Current offering: \(offerings.current?.identifier ?? "none")")
                
                if let chatgptOffering = offerings.offering(identifier: "new") {
                    let _ = print("✅ Using 'new' offering")
                    PaywallView(offering: chatgptOffering)
                } else if let currentOffering = offerings.current {
                    let _ = print("⚠️ 'new' not found, using current: \(currentOffering.identifier)")
                    PaywallView(offering: currentOffering)
                } else {
                    let _ = print("⚠️ No offerings available, using default PaywallView")
                    PaywallView()
                }
            } else {
                // Loading state while offerings are being fetched
                VStack(spacing: 20) {
                    ProgressView()
                        .scaleEffect(1.5)
                    Text(L.t(sv: "Laddar...", nb: "Laster..."))
                        .font(.headline)
                        .foregroundColor(.gray)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(.systemBackground))
                .onAppear {
                    if !hasAttemptedLoad {
                        hasAttemptedLoad = true
                        Task {
                            print("📦 Offerings not loaded, fetching...")
                            await revenueCatManager.loadOfferings()
                        }
                    }
                }
            }
        }
    }
}

#Preview {
    SettingsView()
        .environmentObject(AuthViewModel())
}
