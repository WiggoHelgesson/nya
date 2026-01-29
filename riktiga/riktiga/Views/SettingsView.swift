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
    @State private var showStravaDisconnectConfirmation = false
    @State private var showConnectDevices = false
    @State private var showNutritionOnboarding = false
    @State private var showPersonalDetails = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    prenumerationSection
                    bjudInVannerSection
                    dittKontoSection
                    kopplingarSection
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
            .sheet(isPresented: $showConnectDevices) {
                ConnectDeviceView()
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
    
    // MARK: - Section Views
    
    private var prenumerationSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Prenumeration")
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
                            
                            Text(isLoadingPremium ? "Laddar..." : (isPremium ? "Aktiv prenumeration" : "Inaktiv"))
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
                    NewSettingsRow(icon: "creditcard", title: "Hantera prenumeration")
                }
            }
            .background(Color(.systemBackground))
            .cornerRadius(12)
        }
    }
    
    private var bjudInVannerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Bjud in vänner")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.secondary)
                .padding(.horizontal, 4)
            
            Button(action: { showReferralView = true }) {
                HStack(spacing: 14) {
                    Image(systemName: "person.badge.plus")
                        .font(.system(size: 20))
                        .foregroundColor(.primary)
                        .frame(width: 24)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Referera en vän och tjäna")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.primary)
                        
                        Text("Tjäna 30% på alla köp din vän gör")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(Color(.systemGray3))
                }
                .padding(16)
                .background(Color(.systemBackground))
                .cornerRadius(12)
            }
        }
    }
    
    private var dittKontoSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Ditt konto")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.secondary)
                .padding(.horizontal, 4)
            
            VStack(spacing: 0) {
                Button(action: { showPersonalDetails = true }) {
                    NewSettingsRow(icon: "person.text.rectangle", title: "Personliga detaljer")
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
            Text("Kopplingar")
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
                            
                            Text(stravaService.isConnected ? "Ansluten" : "Inte ansluten")
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
                            Text("Anslut")
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
    
    private var naringOchMalSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Näring & mål")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.secondary)
                .padding(.horizontal, 4)
            
            VStack(spacing: 0) {
                Button(action: { showNutritionOnboarding = true }) {
                    NewSettingsRow(icon: "target", title: "Uppdatera näringsinställningar")
                }
                
                SettingsItemDivider()
                
                Button(action: { showPersonalDetails = true }) {
                    NewSettingsRow(icon: "flag", title: "Mål & nuvarande vikt")
                }
            }
            .background(Color(.systemBackground))
            .cornerRadius(12)
        }
    }
    
    private var kundtjanstSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Kundtjänst & legalt")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.secondary)
                .padding(.horizontal, 4)
            
            VStack(spacing: 0) {
                Button(action: { openMailTo() }) {
                    NewSettingsRow(icon: "envelope", title: "Skicka ett mail")
                }
                
                SettingsItemDivider()
                
                Button(action: { openURL("https://www.upanddownapp.com/privacy") }) {
                    NewSettingsRow(icon: "lock.shield", title: "Privacy Policy")
                }
                
                SettingsItemDivider()
                
                Button(action: { openURL("https://www.upanddownapp.com/terms") }) {
                    NewSettingsRow(icon: "doc.text", title: "Våra Villkor")
                }
            }
            .background(Color(.systemBackground))
            .cornerRadius(12)
        }
    }
    
    private var foljOssSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Följ oss")
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
                Text("Admin")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 4)
                
                VStack(spacing: 0) {
                    Button(action: { showAdmin = true }) {
                        NewSettingsRow(icon: "person.badge.key", title: "Admin (ansökningar)")
                    }
                    
                    SettingsItemDivider()
                    
                    Button(action: { showAnnouncement = true }) {
                        NewSettingsRow(icon: "megaphone", title: "Skicka notis till alla")
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
                            Text("Målvikt")
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                            Text("\(Int(goalWeight)) kg")
                                .font(.system(size: 24, weight: .bold))
                        }
                        
                        Spacer()
                        
                        Button("Ändra mål") {
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
                    detailRow(title: "Nuvarande vikt", value: "\(Int(currentWeight)) kg") {
                        showCurrentWeightPicker = true
                    }
                    
                    Divider().padding(.leading, 16)
                    
                    // Height
                    detailRow(title: "Längd", value: "\(height) cm") {
                        showHeightPicker = true
                    }
                    
                    Divider().padding(.leading, 16)
                    
                    // Birth Date
                    detailRow(title: "Födelsedatum", value: formatDate(birthDate)) {
                        showBirthDatePicker = true
                    }
                    
                    Divider().padding(.leading, 16)
                    
                    // Gender
                    detailRow(title: "Kön", value: genderDisplayName) {
                        showGenderPicker = true
                    }
                    
                    Divider().padding(.leading, 16)
                    
                    // Daily Step Goal
                    detailRow(title: "Dagligt stegmål", value: "\(dailyStepGoal) steg") {
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
        .navigationTitle("Personliga detaljer")
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
            weightPickerSheet(title: "Målvikt", weight: $goalWeight, onSave: saveGoalWeight)
        }
        .sheet(isPresented: $showCurrentWeightPicker) {
            weightPickerSheet(title: "Nuvarande vikt", weight: $currentWeight, onSave: saveCurrentWeight)
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
        case "male": return "Man"
        case "female": return "Kvinna"
        default: return "Annat"
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
        
        // Load profile data
        do {
            if let profile = try await ProfileService.shared.fetchUserProfile(userId: userId) {
                await MainActor.run {
                    // Set values from profile if available
                    isLoading = false
                }
            }
        } catch {
            print("❌ Error loading profile: \(error)")
        }
        
        isLoading = false
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
                    Button("Avbryt") {
                        showGoalWeightPicker = false
                        showCurrentWeightPicker = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Spara") {
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
            .navigationTitle("Längd")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Avbryt") { showHeightPicker = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Spara") {
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
            .navigationTitle("Födelsedatum")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Avbryt") { showBirthDatePicker = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Spara") {
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
                    Text("Man").tag("male")
                    Text("Kvinna").tag("female")
                    Text("Annat").tag("other")
                }
                .pickerStyle(.wheel)
            }
            .navigationTitle("Kön")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Avbryt") { showGenderPicker = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Spara") {
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
                        Text("\(steps) steg").tag(steps)
                    }
                }
                .pickerStyle(.wheel)
            }
            .navigationTitle("Dagligt stegmål")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Avbryt") { showStepGoalPicker = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Spara") {
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
        // Save birth date logic
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
                    Text("Laddar...")
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
