import SwiftUI

struct ReferralView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var referralCode: String = ""
    @State private var stats: ReferralStats?
    @State private var isLoading = true
    @State private var showCopiedToast = false
    
    // Code editing states
    @State private var showEditCodeSheet = false
    @State private var editedCode: String = ""
    @State private var canEditCode = false
    @State private var daysUntilEdit = 0
    @State private var isUpdatingCode = false
    @State private var codeUpdateError: String?
    @State private var showCodeUpdateSuccess = false
    @State private var showPayoutAlert = false
    @State private var showPayoutSuccess = false
    @State private var isRequestingPayout = false
    @State private var stripeAccountStatus: StripeAccountStatus?
    @State private var showStripeOnboarding = false
    @State private var stripeOnboardingUrl: String?
    @State private var isSettingUpStripe = false
    @State private var estimatedUsers: Double = 10
    
    // Supporting code states
    @State private var supportingCodeInfo: SupportingCodeInfo?
    @State private var showChangeSupportCodeSheet = false
    @State private var newSupportCode: String = ""
    @State private var isChangingSupportCode = false
    @State private var changeSupportCodeError: String?
    @State private var showSupportCodeChangeSuccess = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header section with avatars
                headerSection
                
                // Promo code section
                promoCodeSection
                
                // Supporting code section (if user is supporting someone)
                if let supportingInfo = supportingCodeInfo {
                    supportingCodeSection(info: supportingInfo)
                } else if !isLoading {
                    // Show option to add a support code if they don't have one
                    addSupportCodeSection
                }
                
                // Share button
                shareButton
                
                // How to earn section
                howToEarnSection
                
                // Earnings calculator section
                earningsCalculatorSection
                
                // Stats section (if has referrals)
                if let stats = stats, stats.totalReferrals > 0 {
                    statsSection(stats: stats)
                }
                
                // Payout section (if can withdraw)
                if let stats = stats, stats.canWithdraw {
                    payoutSection(stats: stats)
                }
                
                Spacer(minLength: 40)
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
        }
        .background(Color(.systemGray6).opacity(0.5))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text(L.t(sv: "Referera och tjäna", nb: "Referer og tjen"))
                    .font(.system(size: 17, weight: .semibold))
            }
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
        .navigationBarBackButtonHidden(true)
        .task {
            await loadData()
        }
        .overlay {
            if showCopiedToast {
                VStack {
                    Spacer()
                    Text(L.t(sv: "Kopierad!", nb: "Kopiert!"))
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(Color.black)
                        .cornerRadius(25)
                        .padding(.bottom, 100)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .alert(L.t(sv: "Begär utbetalning", nb: "Be om utbetaling"), isPresented: $showPayoutAlert) {
            Button(L.t(sv: "Avbryt", nb: "Avbryt"), role: .cancel) { }
            Button(L.t(sv: "Bekräfta", nb: "Bekreft")) {
                requestPayout()
            }
        } message: {
            if let stats = stats {
                Text(L.t(sv: "Du kommer att få \(Int(stats.pendingEarnings)) kr utbetalt till ditt kopplade Stripe-konto.", nb: "Du vil få \(Int(stats.pendingEarnings)) kr utbetalt til din tilkoblede Stripe-konto."))
            }
        }
        .alert(L.t(sv: "Utbetalning begärd!", nb: "Utbetaling forespurt!"), isPresented: $showPayoutSuccess) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(L.t(sv: "Din utbetalning behandlas. Pengarna kommer att överföras inom 3-5 arbetsdagar.", nb: "Utbetalingen din behandles. Pengene vil bli overført innen 3-5 virkedager."))
        }
        .alert(L.t(sv: "Kod uppdaterad!", nb: "Kode oppdatert!"), isPresented: $showCodeUpdateSuccess) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(L.t(sv: "Din referenskod har ändrats till \(referralCode)", nb: "Referansekoden din er endret til \(referralCode)"))
        }
        .alert(L.t(sv: "Kod uppdaterad!", nb: "Kode oppdatert!"), isPresented: $showSupportCodeChangeSuccess) {
            Button("OK", role: .cancel) { }
        } message: {
            if let info = supportingCodeInfo {
                Text(L.t(sv: "Du stödjer nu \(info.ownerUsername) med kod \(info.code)", nb: "Du støtter nå \(info.ownerUsername) med kode \(info.code)"))
            }
        }
        .sheet(isPresented: $showEditCodeSheet) {
            editCodeSheet
        }
        .sheet(isPresented: $showChangeSupportCodeSheet) {
            changeSupportCodeSheet
        }
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        VStack(spacing: 16) {
            // Title
            Text(L.t(sv: "Referera en vän", nb: "Referer en venn"))
                .font(.system(size: 32, weight: .bold))
                .frame(maxWidth: .infinity, alignment: .leading)
            
            // Avatar grid - decorative
            HStack(spacing: -10) {
                ForEach(0..<6, id: \.self) { index in
                    Circle()
                        .fill(avatarColors[index % avatarColors.count])
                        .frame(width: 56, height: 56)
                        .overlay(
                            Image(systemName: "person.fill")
                                .font(.system(size: 20))
                                .foregroundColor(.white.opacity(0.8))
                        )
                        .offset(y: index % 2 == 0 ? -10 : 10)
                }
            }
            .padding(.vertical, 20)
            
            // Center logo
            Circle()
                .fill(Color(.systemGray5))
                .frame(width: 70, height: 70)
                .overlay(
                    Image("23")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 40, height: 40)
                        .cornerRadius(8)
                )
                .offset(y: -30)
            
            // Subtitle
            VStack(spacing: 4) {
                Text(L.t(sv: "Hjälp dina vänner", nb: "Hjelp vennene dine"))
                    .font(.system(size: 22, weight: .semibold))
                Text(L.t(sv: "& tjäna pengar tillsammans", nb: "& tjen penger sammen"))
                    .font(.system(size: 16))
                    .foregroundColor(.gray)
            }
            .offset(y: -20)
        }
    }
    
    private let avatarColors: [Color] = [
        Color(red: 0.3, green: 0.5, blue: 0.3),
        Color(red: 0.5, green: 0.7, blue: 0.5),
        Color(red: 0.4, green: 0.6, blue: 0.8),
        Color(red: 0.9, green: 0.7, blue: 0.5),
        Color(red: 0.8, green: 0.5, blue: 0.5),
        Color(red: 0.6, green: 0.5, blue: 0.8)
    ]
    
    // MARK: - Promo Code Section
    private var promoCodeSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(L.t(sv: "Din personliga kod", nb: "Din personlige kode"))
                    .font(.system(size: 14))
                    .foregroundColor(.gray)
                
                Spacer()
                
                // Edit button
                Button {
                    editedCode = referralCode
                    showEditCodeSheet = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "pencil")
                            .font(.system(size: 12))
                        Text(canEditCode ? L.t(sv: "Redigera", nb: "Rediger") : L.t(sv: "Redigera om \(daysUntilEdit) dagar", nb: "Rediger om \(daysUntilEdit) dager"))
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundColor(canEditCode ? .black : .gray)
                }
                .disabled(!canEditCode)
            }
            
            HStack {
                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    Text(referralCode)
                        .font(.system(size: 24, weight: .bold))
                        .tracking(2)
                }
                
                Spacer()
                
                Button {
                    copyCode()
                } label: {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 20))
                        .foregroundColor(.black)
                }
            }
            .padding(20)
            .background(Color.white)
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
            )
        }
    }
    
    // MARK: - Share Button
    private var shareButton: some View {
        Button {
            shareCode()
        } label: {
            Text(L.t(sv: "Dela", nb: "Del"))
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(Color.black)
                .cornerRadius(30)
        }
    }
    
    // MARK: - How to Earn Section
    private var howToEarnSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                Text(L.t(sv: "Så tjänar du", nb: "Slik tjener du"))
                    .font(.system(size: 18, weight: .semibold))
                
                Circle()
                    .fill(Color.orange.opacity(0.2))
                    .frame(width: 28, height: 28)
                    .overlay(
                        Text("💰")
                            .font(.system(size: 14))
                    )
            }
            
            VStack(alignment: .leading, spacing: 12) {
                bulletPoint(L.t(sv: "Dela din kod med dina vänner", nb: "Del koden din med vennene dine"))
                bulletPoint(L.t(sv: "Tjäna 40% på alla köp de gör", nb: "Tjen 40% på alle kjøp de gjør"))
                bulletPoint(L.t(sv: "Ta ut pengarna när du nått 300 kr", nb: "Ta ut pengene når du har nådd 300 kr"))
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemGray6))
        .cornerRadius(16)
    }
    
    private func bulletPoint(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text("✱")
                .font(.system(size: 14, weight: .bold))
            Text(text)
                .font(.system(size: 15))
        }
    }
    
    // MARK: - Earnings Calculator Section
    private var earningsCalculatorSection: some View {
        VStack(spacing: 0) {
            // Top section - User slider
            VStack(alignment: .leading, spacing: 16) {
                Text(L.t(sv: "Betalande användare du kan värva", nb: "Betalende brukere du kan verve"))
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.primary.opacity(0.8))
                
                Text("\(Int(estimatedUsers))")
                    .font(.system(size: 56, weight: .bold))
                    .foregroundColor(.black)
                
                // Custom slider
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        // Background track
                        Capsule()
                            .fill(Color(.systemGray4))
                            .frame(height: 8)
                        
                        // Filled track
                        Capsule()
                            .fill(Color.black)
                            .frame(width: max(0, min(geometry.size.width, geometry.size.width * (estimatedUsers / 500))), height: 8)
                        
                        // Thumb
                        Circle()
                            .fill(Color.black)
                            .frame(width: 28, height: 28)
                            .shadow(color: Color.black.opacity(0.2), radius: 4, x: 0, y: 2)
                            .offset(x: max(0, min(geometry.size.width - 28, (geometry.size.width - 28) * (estimatedUsers / 500))))
                            .gesture(
                                DragGesture(minimumDistance: 0)
                                    .onChanged { value in
                                        let newValue = min(max(0, value.location.x / geometry.size.width * 500), 500)
                                        estimatedUsers = max(1, newValue)
                                        
                                        // Light haptic
                                        let generator = UIImpactFeedbackGenerator(style: .light)
                                        generator.impactOccurred()
                                    }
                            )
                    }
                }
                .frame(height: 28)
                .padding(.top, 8)
            }
            .padding(28)
            
            // Divider
            Divider()
                .padding(.horizontal, 20)
            
            // Bottom section - Estimated earnings
            VStack(alignment: .leading, spacing: 12) {
                Text(L.t(sv: "Beräknad intjäning", nb: "Beregnet inntjening"))
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.primary.opacity(0.8))
                
                Text("\(Int(estimatedUsers * 160)) kr")
                    .font(.system(size: 42, weight: .bold))
                    .foregroundColor(.black)
                
                Text(L.t(sv: "baserat på årsabonnemang (160 kr/person med 40%)", nb: "basert på årsabonnement (160 kr/person med 40%)"))
                    .font(.system(size: 14))
                    .foregroundColor(.gray)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(28)
        }
        .background(Color(.systemGray6).opacity(0.8))
        .cornerRadius(24)
    }
    
    // MARK: - Stats Section
    private func statsSection(stats: ReferralStats) -> some View {
        VStack(spacing: 16) {
            Text(L.t(sv: "Din statistik", nb: "Din statistikk"))
                .font(.system(size: 18, weight: .semibold))
                .frame(maxWidth: .infinity, alignment: .leading)
            
            HStack(spacing: 16) {
                statCard(
                    title: L.t(sv: "Refererade", nb: "Refererte"),
                    value: "\(stats.totalReferrals)",
                    icon: "person.2.fill",
                    color: .blue
                )
                
                statCard(
                    title: L.t(sv: "Intjänat", nb: "Opptjent"),
                    value: "\(Int(stats.totalEarnings)) kr",
                    icon: "banknote.fill",
                    color: .green
                )
            }
            
            HStack(spacing: 16) {
                statCard(
                    title: L.t(sv: "Tillgängligt", nb: "Tilgjengelig"),
                    value: "\(Int(stats.pendingEarnings)) kr",
                    icon: "wallet.pass.fill",
                    color: .orange
                )
                
                statCard(
                    title: L.t(sv: "Utbetalt", nb: "Utbetalt"),
                    value: "\(Int(stats.paidOutEarnings)) kr",
                    icon: "checkmark.circle.fill",
                    color: .purple
                )
            }
        }
    }
    
    private func statCard(title: String, value: String, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(color)
                Spacer()
            }
            
            Text(value)
                .font(.system(size: 24, weight: .bold))
            
            Text(title)
                .font(.system(size: 13))
                .foregroundColor(.gray)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.gray.opacity(0.15), lineWidth: 1)
        )
    }
    
    // MARK: - Payout Section
    private func payoutSection(stats: ReferralStats) -> some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(L.t(sv: "Redo för utbetalning!", nb: "Klar for utbetaling!"))
                        .font(.system(size: 18, weight: .semibold))
                    Text(L.t(sv: "Du har \(Int(stats.pendingEarnings)) kr tillgängligt", nb: "Du har \(Int(stats.pendingEarnings)) kr tilgjengelig"))
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                Image(systemName: "party.popper.fill")
                    .font(.system(size: 28))
                    .foregroundColor(.orange)
            }
            
            // Check if Stripe account needs setup
            if stripeAccountStatus?.needsOnboarding == true || stripeAccountStatus == nil {
                // Setup Stripe Connect button
                Button {
                    setupStripeConnect()
                } label: {
                    HStack {
                        if isSettingUpStripe {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Image(systemName: "link.badge.plus")
                            Text(L.t(sv: "Koppla bankkonto", nb: "Koble bankkonto"))
                        }
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.blue)
                    .cornerRadius(14)
                }
                .disabled(isSettingUpStripe)
                
                Text(L.t(sv: "Du behöver koppla ett bankkonto för att ta emot utbetalningar.", nb: "Du må koble en bankkonto for å motta utbetalinger."))
                    .font(.system(size: 13))
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
            } else {
                // Request payout button
                Button {
                    showPayoutAlert = true
                } label: {
                    HStack {
                        if isRequestingPayout {
                            ProgressView()
                                .tint(.black)
                        } else {
                            Image(systemName: "arrow.down.to.line")
                            Text(L.t(sv: "Begär utbetalning", nb: "Be om utbetaling"))
                        }
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.orange.opacity(0.2))
                    .cornerRadius(14)
                }
                .disabled(isRequestingPayout)
            }
        }
        .padding(20)
        .background(
            LinearGradient(
                colors: [Color.orange.opacity(0.1), Color.yellow.opacity(0.05)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.orange.opacity(0.3), lineWidth: 1)
        )
    }
    
    // MARK: - Setup Stripe Connect
    private func setupStripeConnect() {
        isSettingUpStripe = true
        
        Task {
            do {
                // Try to create a new Connect account or get onboarding link
                if let onboardingUrl = try await ReferralService.shared.createStripeConnectAccount() {
                    await MainActor.run {
                        self.stripeOnboardingUrl = onboardingUrl
                        self.isSettingUpStripe = false
                        
                        // Open the URL in Safari
                        if let url = URL(string: onboardingUrl) {
                            UIApplication.shared.open(url)
                        }
                    }
                } else {
                    await MainActor.run {
                        self.isSettingUpStripe = false
                    }
                }
            } catch {
                print("❌ Stripe setup error: \(error)")
                await MainActor.run {
                    self.isSettingUpStripe = false
                }
            }
        }
    }
    
    // MARK: - Edit Code Sheet
    private var editCodeSheet: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: "pencil.circle.fill")
                        .font(.system(size: 50))
                        .foregroundColor(.black)
                    
                    Text(L.t(sv: "Ändra din kod", nb: "Endre koden din"))
                        .font(.system(size: 24, weight: .bold))
                    
                    Text(L.t(sv: "Skriv in din nya personliga kod", nb: "Skriv inn din nye personlige kode"))
                        .font(.system(size: 15))
                        .foregroundColor(.gray)
                }
                .padding(.top, 20)
                
                // Input field
                VStack(alignment: .leading, spacing: 8) {
                    Text(L.t(sv: "Ny kod (3-12 tecken)", nb: "Ny kode (3-12 tegn)"))
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                    
                    TextField(L.t(sv: "T.ex. MITTNAMN", nb: "F.eks. MITTNAVNN"), text: $editedCode)
                        .font(.system(size: 20, weight: .semibold))
                        .textCase(.uppercase)
                        .autocorrectionDisabled()
                        .padding(16)
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                        .onChange(of: editedCode) { _, newValue in
                            // Filter to only alphanumeric and limit to 12 chars
                            let filtered = newValue.uppercased().filter { $0.isLetter || $0.isNumber }
                            if filtered.count <= 12 {
                                editedCode = filtered
                            } else {
                                editedCode = String(filtered.prefix(12))
                            }
                        }
                }
                .padding(.horizontal, 20)
                
                // Error message
                if let error = codeUpdateError {
                    Text(error)
                        .font(.system(size: 14))
                        .foregroundColor(.red)
                        .padding(.horizontal, 20)
                }
                
                // Info text
                Text(L.t(sv: "Du kan ändra din kod var 6:e dag. Koden måste vara unik.", nb: "Du kan endre koden din hver 6. dag. Koden må være unik."))
                    .font(.system(size: 13))
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
                
                Spacer()
                
                // Save button
                Button {
                    updateCode()
                } label: {
                    HStack {
                        if isUpdatingCode {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Text(L.t(sv: "Spara", nb: "Lagre"))
                                .font(.system(size: 17, weight: .semibold))
                        }
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(editedCode.count >= 3 ? Color.black : Color.gray)
                    .cornerRadius(14)
                }
                .disabled(editedCode.count < 3 || isUpdatingCode)
                .padding(.horizontal, 20)
                .padding(.bottom, 30)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        showEditCodeSheet = false
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.black)
                            .frame(width: 36, height: 36)
                            .background(Color(.systemGray5))
                            .clipShape(Circle())
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }
    
    private func updateCode() {
        guard let userId = authViewModel.currentUser?.id else { return }
        
        // Validate code format
        let normalizedCode = editedCode.uppercased().trimmingCharacters(in: .whitespaces)
        guard normalizedCode.count >= 3 && normalizedCode.count <= 12 else {
            codeUpdateError = L.t(sv: "Koden måste vara 3-12 tecken", nb: "Koden må være 3-12 tegn")
            return
        }
        
        isUpdatingCode = true
        codeUpdateError = nil
        
        Task {
            do {
                // Check if user can edit (in case they're trying to change to a different code)
                let (canEdit, daysLeft) = try await ReferralService.shared.canEditCode(userId: userId)
                
                // Get current code to check if they're trying to change or keep the same
                let currentCode = referralCode.uppercased()
                let isChangingCode = normalizedCode != currentCode
                
                if isChangingCode && !canEdit {
                    await MainActor.run {
                        isUpdatingCode = false
                        codeUpdateError = L.t(sv: "Du kan ändra koden om \(daysLeft) dagar", nb: "Du kan endre koden om \(daysLeft) dager")
                    }
                    return
                }
                
                let success = try await ReferralService.shared.updateReferralCode(userId: userId, newCode: editedCode)
                
                await MainActor.run {
                    isUpdatingCode = false
                    
                    if success {
                        referralCode = editedCode.uppercased()
                        showEditCodeSheet = false
                        showCodeUpdateSuccess = true
                        
                        // Refresh edit status
                        Task {
                            await checkEditStatus()
                        }
                    } else {
                        codeUpdateError = L.t(sv: "Koden är redan tagen av någon annan", nb: "Koden er allerede tatt av noen andre")
                    }
                }
            } catch {
                print("❌ Error updating code: \(error)")
                await MainActor.run {
                    isUpdatingCode = false
                    codeUpdateError = L.t(sv: "Kunde inte uppdatera koden. Försök igen.", nb: "Kunne ikke oppdatere koden. Prøv igjen.")
                }
            }
        }
    }
    
    private func checkEditStatus() async {
        guard let userId = authViewModel.currentUser?.id else { return }
        
        do {
            let (canEdit, daysLeft) = try await ReferralService.shared.canEditCode(userId: userId)
            await MainActor.run {
                self.canEditCode = canEdit
                self.daysUntilEdit = daysLeft
            }
        } catch {
            print("❌ Error checking edit status: \(error)")
        }
    }
    
    // MARK: - Supporting Code Sections
    
    private func supportingCodeSection(info: SupportingCodeInfo) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(L.t(sv: "Du stödjer", nb: "Du støtter"))
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                    
                    HStack(spacing: 8) {
                        Text(info.ownerUsername)
                            .font(.system(size: 20, weight: .bold))
                        
                        Text(info.code)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Color.green)
                            .cornerRadius(8)
                    }
                }
                
                Spacer()
                
                Button {
                    newSupportCode = ""
                    showChangeSupportCodeSheet = true
                } label: {
                    Text(L.t(sv: "Byt", nb: "Bytt"))
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.black)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color(.systemGray5))
                        .cornerRadius(20)
                }
            }
            
            Text(L.t(sv: "Genom att stödja \(info.ownerUsername) hjälper du dem att tjäna 40% provision på alla dina köp i appen.", nb: "Ved å støtte \(info.ownerUsername) hjelper du dem med å tjene 40% provisjon på alle dine kjøp i appen."))
                .font(.system(size: 13))
                .foregroundColor(.secondary)
        }
        .padding(16)
        .background(Color.white)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.green.opacity(0.3), lineWidth: 1.5)
        )
    }
    
    private var addSupportCodeSection: some View {
        Button {
            newSupportCode = ""
            showChangeSupportCodeSheet = true
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "person.badge.plus")
                    .font(.system(size: 24))
                    .foregroundColor(.blue)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(L.t(sv: "Stöd någon", nb: "Støtt noen"))
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    Text(L.t(sv: "Ange en referenskod för att stödja någon", nb: "Skriv inn en referansekode for å støtte noen"))
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14))
                    .foregroundColor(.gray)
            }
            .padding(16)
            .background(Color.white)
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Change Support Code Sheet
    
    private var changeSupportCodeSheet: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: "person.badge.plus.fill")
                        .font(.system(size: 50))
                        .foregroundColor(.green)
                    
                    Text(supportingCodeInfo == nil ? L.t(sv: "Stöd någon", nb: "Støtt noen") : L.t(sv: "Byt vem du stödjer", nb: "Bytt hvem du støtter"))
                        .font(.system(size: 24, weight: .bold))
                    
                    if let currentInfo = supportingCodeInfo {
                        Text(L.t(sv: "Du stödjer just nu \(currentInfo.ownerUsername)", nb: "Du støtter akkurat nå \(currentInfo.ownerUsername)"))
                            .font(.system(size: 15))
                            .foregroundColor(.gray)
                    } else {
                        Text(L.t(sv: "Ange en referenskod för att stödja någon", nb: "Skriv inn en referansekode for å støtte noen"))
                            .font(.system(size: 15))
                            .foregroundColor(.gray)
                    }
                }
                .padding(.top, 20)
                
                // Input field
                VStack(alignment: .leading, spacing: 8) {
                    Text(L.t(sv: "Referenskod", nb: "Referansekode"))
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                    
                    TextField(L.t(sv: "T.ex. WIGGO123", nb: "F.eks. WIGGO123"), text: $newSupportCode)
                        .font(.system(size: 20, weight: .semibold))
                        .textCase(.uppercase)
                        .autocorrectionDisabled()
                        .padding(16)
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                        .onChange(of: newSupportCode) { _, newValue in
                            // Filter to only alphanumeric
                            let filtered = newValue.uppercased().filter { $0.isLetter || $0.isNumber }
                            if filtered.count <= 12 {
                                newSupportCode = filtered
                            } else {
                                newSupportCode = String(filtered.prefix(12))
                            }
                        }
                }
                .padding(.horizontal, 20)
                
                // Error message
                if let error = changeSupportCodeError {
                    Text(error)
                        .font(.system(size: 14))
                        .foregroundColor(.red)
                        .padding(.horizontal, 20)
                }
                
                // Info text
                VStack(spacing: 8) {
                    Text(L.t(sv: "Genom att stödja någon hjälper du dem att tjäna 40% provision på alla dina köp.", nb: "Ved å støtte noen hjelper du dem med å tjene 40% provisjon på alle dine kjøp."))
                        .font(.system(size: 13))
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                    
                    if supportingCodeInfo != nil {
                        Text(L.t(sv: "Du kan byta när som helst.", nb: "Du kan bytte når som helst."))
                            .font(.system(size: 13))
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(.horizontal, 20)
                
                Spacer()
                
                // Save button
                Button {
                    changeSupportCode()
                } label: {
                    HStack {
                        if isChangingSupportCode {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Text(L.t(sv: "Spara", nb: "Lagre"))
                                .font(.system(size: 17, weight: .semibold))
                        }
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(newSupportCode.count >= 3 ? Color.green : Color.gray)
                    .cornerRadius(14)
                }
                .disabled(newSupportCode.count < 3 || isChangingSupportCode)
                .padding(.horizontal, 20)
                .padding(.bottom, 30)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        showChangeSupportCodeSheet = false
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.black)
                            .frame(width: 36, height: 36)
                            .background(Color(.systemGray5))
                            .clipShape(Circle())
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }
    
    private func changeSupportCode() {
        guard let userId = authViewModel.currentUser?.id else { return }
        
        let normalizedCode = newSupportCode.uppercased().trimmingCharacters(in: .whitespaces)
        guard normalizedCode.count >= 3 else {
            changeSupportCodeError = L.t(sv: "Koden måste vara minst 3 tecken", nb: "Koden må være minst 3 tegn")
            return
        }
        
        isChangingSupportCode = true
        changeSupportCodeError = nil
        
        Task {
            do {
                let success = try await ReferralService.shared.changeSupportingCode(userId: userId, newCode: normalizedCode)
                
                await MainActor.run {
                    isChangingSupportCode = false
                    
                    if success {
                        showChangeSupportCodeSheet = false
                        showSupportCodeChangeSuccess = true
                        
                        // Reload supporting code info
                        Task {
                            await loadSupportingCodeInfo()
                        }
                    } else {
                        changeSupportCodeError = L.t(sv: "Koden hittades inte eller är ogiltig", nb: "Koden ble ikke funnet eller er ugyldig")
                    }
                }
            } catch {
                print("❌ Error changing support code: \(error)")
                await MainActor.run {
                    isChangingSupportCode = false
                    changeSupportCodeError = L.t(sv: "Kunde inte ändra kod. Försök igen.", nb: "Kunne ikke endre kode. Prøv igjen.")
                }
            }
        }
    }
    
    // MARK: - Actions
    private func loadData() async {
        guard let userId = authViewModel.currentUser?.id else { return }
        
        do {
            // Get or create referral code
            let code = try await ReferralService.shared.getOrCreateReferralCode(userId: userId)
            
            // Check if user can edit code
            let (canEdit, daysLeft) = try await ReferralService.shared.canEditCode(userId: userId)
            
            // Get stats
            let fetchedStats = try await ReferralService.shared.getReferralStats(userId: userId)
            
            // Check Stripe account status (only if can withdraw)
            var accountStatus: StripeAccountStatus? = nil
            if fetchedStats.canWithdraw {
                accountStatus = try? await ReferralService.shared.checkStripeAccountStatus()
            }
            
            // Get supporting code info
            await loadSupportingCodeInfo()
            
            await MainActor.run {
                self.referralCode = code
                self.canEditCode = canEdit
                self.daysUntilEdit = daysLeft
                self.stats = fetchedStats
                self.stripeAccountStatus = accountStatus
                self.isLoading = false
            }
        } catch {
            print("❌ Error loading referral data: \(error)")
            await MainActor.run {
                self.isLoading = false
            }
        }
    }
    
    private func loadSupportingCodeInfo() async {
        guard let userId = authViewModel.currentUser?.id else { return }
        
        do {
            let info = try await ReferralService.shared.getCurrentSupportingCode(userId: userId)
            await MainActor.run {
                self.supportingCodeInfo = info
            }
        } catch {
            print("❌ Error loading supporting code info: \(error)")
            await MainActor.run {
                self.supportingCodeInfo = nil
            }
        }
    }
    
    private func copyCode() {
        UIPasteboard.general.string = referralCode
        
        // Haptic feedback
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        
        // Show toast
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            showCopiedToast = true
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation {
                showCopiedToast = false
            }
        }
    }
    
    private func shareCode() {
        let message = L.t(
            sv: """
            Gå med mig på Up&Down! 💪
            
            Använd min kod: \(referralCode)
            
            Ladda ner appen här: https://apps.apple.com/app/upanddown/id123456789
            """,
            nb: """
            Bli med meg på Up&Down! 💪
            
            Bruk koden min: \(referralCode)
            
            Last ned appen her: https://apps.apple.com/app/upanddown/id123456789
            """
        )
        
        let activityVC = UIActivityViewController(
            activityItems: [message],
            applicationActivities: nil
        )
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let rootVC = window.rootViewController {
            rootVC.present(activityVC, animated: true)
        }
    }
    
    private func requestPayout() {
        guard let userId = authViewModel.currentUser?.id else { return }
        
        isRequestingPayout = true
        
        Task {
            do {
                let success = try await ReferralService.shared.requestPayout(userId: userId)
                
                await MainActor.run {
                    isRequestingPayout = false
                    if success {
                        showPayoutSuccess = true
                        // Refresh stats
                        Task {
                            await loadData()
                        }
                    }
                }
            } catch {
                print("❌ Payout error: \(error)")
                await MainActor.run {
                    isRequestingPayout = false
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        ReferralView()
            .environmentObject(AuthViewModel())
    }
}
