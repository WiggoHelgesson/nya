import SwiftUI
import Combine
import Supabase

struct TrainerDashboardView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = TrainerDashboardViewModel()
    @State private var selectedBooking: TrainerBooking?
    @State private var showChatSheet = false
    @State private var showEditProfile = false
    @State private var showFullEditFlow = false
    @State private var showDeactivateConfirmation = false
    @State private var isDeactivating = false
    
    // Stripe Connect states
    @State private var stripeAccountId: String?
    @State private var stripeStatus: StripeConnectService.AccountStatusResponse?
    @State private var isLoadingStripe = false
    @State private var stripeError: String?
    @State private var showStripeOnboarding = false
    @State private var lastStripeLoad: Date?
    private let stripeLoadThrottle: TimeInterval = 60 // 1 minute cache for Stripe status
    
    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 20) {
                    // Stripe Connect Section - Payouts
                    stripeConnectSection
                    
                    // Manage Ad Button
                    manageAdButton
                    
                    // Stats Overview
                    statsOverview
                    
                    // Deactivate Account Button
                    deactivateButton
                }
                .padding()
            }
            .navigationTitle("Utbetalningar & info")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Stäng") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task {
                            // Force refresh both bookings and Stripe status
                            lastStripeLoad = nil // Reset cache to force reload
                            async let bookingsTask: () = viewModel.refresh()
                            async let stripeTask: () = loadStripeStatus()
                            _ = await (bookingsTask, stripeTask)
                        }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
            .task {
                // Load trainer ID first (needed for other operations)
                await viewModel.loadTrainerIdIfNeeded()
                
                // Then load bookings and stripe status in parallel
                async let bookingsTask: () = viewModel.loadBookings()
                async let stripeTask: () = loadStripeStatus()
                _ = await (bookingsTask, stripeTask)
            }
            .refreshable {
                await viewModel.refresh()
            }
            .sheet(isPresented: $showChatSheet) {
                if let booking = selectedBooking {
                    BookingChatView(booking: booking)
                }
            }
            .sheet(isPresented: $showEditProfile) {
                EditTrainerProfileView()
            }
            .fullScreenCover(isPresented: $showFullEditFlow) {
                TrainerOnboardingView(isEditMode: true)
                    .environmentObject(AuthViewModel.shared)
            }
            .alert("Avaktivera tränarkonto", isPresented: $showDeactivateConfirmation) {
                Button("Avbryt", role: .cancel) {}
                Button("Avaktivera", role: .destructive) {
                    Task {
                        await deactivateTrainerAccount()
                    }
                }
            } message: {
                Text("Är du säker på att du vill avaktivera ditt tränarkonto? Din annons kommer att tas bort från kartan men du kan aktivera det igen senare.")
            }
        }
    }
    
    // MARK: - Deactivate Trainer Account
    
    private func deactivateTrainerAccount() async {
        isDeactivating = true
        
        do {
            guard let userId = AuthViewModel.shared.currentUser?.id else {
                print("❌ No user ID")
                isDeactivating = false
                return
            }
            
            // Set is_active to false in trainer_profiles
            try await SupabaseConfig.supabase
                .from("trainer_profiles")
                .update(["is_active": false])
                .eq("user_id", value: userId)
                .execute()
            
            print("✅ Trainer account deactivated")
            
            await MainActor.run {
                isDeactivating = false
                
                // Post notification BEFORE dismissing so ProfileView updates first
                NotificationCenter.default.post(
                    name: NSNotification.Name("RefreshTrainerStatus"),
                    object: nil,
                    userInfo: ["isTrainer": false]
                )
                
                // Small delay to ensure notification is processed
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    self.dismiss()
                }
            }
            
        } catch {
            print("❌ Failed to deactivate trainer account: \(error)")
            await MainActor.run {
                isDeactivating = false
            }
        }
    }
    
    // MARK: - Stripe Connect Section
    
    private var stripeConnectSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "creditcard.fill")
                    .foregroundColor(.black)
                Text("Utbetalningar")
                    .font(.system(size: 18, weight: .bold))
                Spacer()
            }
            
            if isLoadingStripe {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Laddar...")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
            } else if let status = stripeStatus, status.isFullyOnboarded == true {
                // Account is fully set up - show status and balance
                stripeActiveAccountCard(status: status)
            } else if stripeAccountId != nil {
                // Account exists but not fully onboarded
                stripeOnboardingRequiredCard
            } else {
                // No account - show setup button
                stripeSetupCard
            }
            
            if let error = stripeError {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.gray)
                    .padding(.horizontal, 4)
            }
        }
        .padding(16)
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
    
    private func stripeActiveAccountCard(status: StripeConnectService.AccountStatusResponse) -> some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.black)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Konto aktivt")
                        .font(.system(size: 14, weight: .semibold))
                    Text("Redo att ta emot betalningar")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                Spacer()
            }
            
            // Show balance if available
            if let balance = status.balance {
                Divider()
                
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Tillgängligt")
                            .font(.caption)
                            .foregroundColor(.gray)
                        if let available = balance.available?.first {
                            Text(StripeConnectService.formatBalance(available.amount, currency: available.currency))
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.black)
                        } else {
                            Text("0 SEK")
                                .font(.system(size: 18, weight: .bold))
                        }
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("Väntande")
                            .font(.caption)
                            .foregroundColor(.gray)
                        if let pending = balance.pending?.first {
                            Text(StripeConnectService.formatBalance(pending.amount, currency: pending.currency))
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.gray)
                        } else {
                            Text("0 SEK")
                                .font(.system(size: 18, weight: .bold))
                        }
                    }
                }
            }
            
            // Link to Stripe Express dashboard
            Button {
                openStripeDashboard()
            } label: {
                HStack {
                    Text("Öppna Stripe Dashboard")
                        .font(.system(size: 14, weight: .medium))
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 12))
                }
                .foregroundColor(.black)
            }
            .padding(.top, 4)
        }
        .padding(16)
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private var stripeOnboardingRequiredCard: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "exclamationmark.circle.fill")
                    .foregroundColor(.gray)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Slutför registrering")
                        .font(.system(size: 14, weight: .semibold))
                    Text(stripeStatus?.statusMessage ?? "Fyll i dina uppgifter för att ta emot betalningar")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                Spacer()
            }
            
            Button {
                Task { await startStripeOnboarding() }
            } label: {
                HStack {
                    if showStripeOnboarding {
                        ProgressView()
                            .scaleEffect(0.8)
                            .tint(.white)
                    }
                    Text("Slutför registrering")
                        .font(.system(size: 14, weight: .bold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.black)
                .foregroundColor(.white)
                .cornerRadius(8)
            }
            .disabled(showStripeOnboarding)
        }
        .padding(16)
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private var stripeSetupCard: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "plus.circle.fill")
                    .foregroundColor(.black)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Koppla betalningar")
                        .font(.system(size: 14, weight: .semibold))
                    Text("Ta emot betalningar direkt till ditt bankkonto")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                Spacer()
            }
            
            Button {
                Task { await setupStripeAccount() }
            } label: {
                HStack {
                    if isLoadingStripe {
                        ProgressView()
                            .scaleEffect(0.8)
                            .tint(.white)
                    }
                    Text("Kom igång med Stripe")
                        .font(.system(size: 14, weight: .bold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.black)
                .foregroundColor(.white)
                .cornerRadius(8)
            }
            .disabled(isLoadingStripe)
            
            Text("15% går till plattformen, resten till dig")
                .font(.caption2)
                .foregroundColor(.gray)
        }
        .padding(16)
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    // MARK: - Stripe Functions
    
    private func loadStripeStatus() async {
        // Throttle Stripe status checks
        if let lastLoad = lastStripeLoad,
           Date().timeIntervalSince(lastLoad) < stripeLoadThrottle,
           stripeStatus != nil || stripeAccountId != nil {
            return
        }
        
        // First check if trainer has a Stripe account
        var trainerId = viewModel.trainerId
        
        // If trainerId not loaded yet, try to fetch it
        if trainerId == nil {
            guard let userId = AuthViewModel.shared.currentUser?.id else { return }
            
            do {
                struct TrainerIdResponse: Decodable {
                    let id: String
                }
                
                let response: TrainerIdResponse = try await SupabaseConfig.supabase
                    .from("trainer_profiles")
                    .select("id")
                    .eq("user_id", value: userId)
                    .single()
                    .execute()
                    .value
                
                trainerId = response.id
                await MainActor.run {
                    viewModel.trainerId = response.id
                }
            } catch {
                print("❌ Failed to load trainer ID for Stripe status: \(error)")
                return
            }
        }
        
        guard let finalTrainerId = trainerId else { return }
        
        do {
            // Fetch trainer profile to get stripe_account_id
            let profile: TrainerProfileStripe = try await SupabaseConfig.supabase
                .from("trainer_profiles")
                .select("stripe_account_id")
                .eq("id", value: finalTrainerId)
                .single()
                .execute()
                .value
            
            guard let accountId = profile.stripe_account_id, !accountId.isEmpty else {
                await MainActor.run {
                    stripeAccountId = nil
                    stripeStatus = nil
                }
                return
            }
            
            await MainActor.run {
                stripeAccountId = accountId
                isLoadingStripe = true
            }
            
            // Get status from Stripe
            let status = try await StripeConnectService.shared.getAccountStatus(
                stripeAccountId: accountId,
                trainerId: finalTrainerId
            )
            
            await MainActor.run {
                stripeStatus = status
                isLoadingStripe = false
                stripeError = nil
                lastStripeLoad = Date()
            }
            
        } catch {
            print("❌ Failed to load Stripe status: \(error)")
            await MainActor.run {
                isLoadingStripe = false
                stripeError = error.localizedDescription
            }
        }
    }
    
    private func setupStripeAccount() async {
        // Try to get trainerId - if not loaded yet, fetch it
        var trainerId = viewModel.trainerId
        
        if trainerId == nil {
            // Fetch trainer ID directly
            guard let userId = AuthViewModel.shared.currentUser?.id else {
                stripeError = "Du måste vara inloggad"
                return
            }
            
            do {
                struct TrainerIdResponse: Decodable {
                    let id: String
                }
                
                let response: TrainerIdResponse = try await SupabaseConfig.supabase
                    .from("trainer_profiles")
                    .select("id")
                    .eq("user_id", value: userId)
                    .single()
                    .execute()
                    .value
                
                trainerId = response.id
                await MainActor.run {
                    viewModel.trainerId = response.id
                }
            } catch {
                stripeError = "Kunde inte hitta ditt tränarkonto"
                return
            }
        }
        
        guard let finalTrainerId = trainerId,
              let email = AuthViewModel.shared.currentUser?.email else {
            stripeError = "Kunde inte hitta användarinformation"
            return
        }
        
        await MainActor.run {
            isLoadingStripe = true
            stripeError = nil
        }
        
        do {
            // Create the Connect account
            let response = try await StripeConnectService.shared.createConnectAccount(
                trainerId: finalTrainerId,
                email: email
            )
            
            guard let accountId = response.accountId else {
                throw StripeConnectError.noAccountId
            }
            
            await MainActor.run {
                stripeAccountId = accountId
            }
            
            // Now start onboarding
            await startStripeOnboarding()
            
        } catch {
            print("❌ Failed to setup Stripe account: \(error)")
            await MainActor.run {
                isLoadingStripe = false
                // Show user-friendly error message
                let errorMsg = error.localizedDescription
                if errorMsg.contains("platform profile") || errorMsg.contains("questionnaire") {
                    stripeError = "Stripe Connect konfigureras just nu. Försök igen om några minuter."
                } else {
                    stripeError = "Kunde inte ansluta till Stripe. Försök igen senare."
                }
            }
        }
    }
    
    private func startStripeOnboarding() async {
        guard let accountId = stripeAccountId else {
            stripeError = "Inget Stripe-konto hittat"
            return
        }
        
        await MainActor.run {
            showStripeOnboarding = true
            stripeError = nil
        }
        
        do {
            let response = try await StripeConnectService.shared.getOnboardingLink(
                stripeAccountId: accountId
            )
            
            if response.alreadyComplete == true {
                // Already done - refresh status
                await loadStripeStatus()
                await MainActor.run {
                    showStripeOnboarding = false
                }
                return
            }
            
            guard let urlString = response.url, let url = URL(string: urlString) else {
                throw StripeConnectError.apiError("Ingen onboarding-länk")
            }
            
            // Open in Safari
            await MainActor.run {
                UIApplication.shared.open(url)
                showStripeOnboarding = false
                isLoadingStripe = false
            }
            
        } catch {
            print("❌ Failed to start Stripe onboarding: \(error)")
            await MainActor.run {
                showStripeOnboarding = false
                stripeError = error.localizedDescription
            }
        }
    }
    
    private func openStripeDashboard() {
        // Stripe Express dashboard URL
        if let url = URL(string: "https://dashboard.stripe.com/express") {
            UIApplication.shared.open(url)
        }
    }
    
    // MARK: - Manage Ad Section
    
    private var manageAdButton: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "megaphone.fill")
                    .foregroundColor(.black)
                Text("Hantera annons")
                    .font(.system(size: 18, weight: .bold))
                Spacer()
            }
            
            Text("Redigera din annons och gå igenom hela flödet med din befintliga information förifyld.")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Button {
                showFullEditFlow = true
            } label: {
                HStack {
                    Image(systemName: "pencil.circle.fill")
                        .font(.title3)
                    
                    Text("Redigera annons")
                        .font(.system(size: 15, weight: .semibold))
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.gray)
                }
                .foregroundColor(.white)
                .padding(14)
                .background(Color.black)
                .cornerRadius(10)
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    // MARK: - Deactivate Button
    
    private var deactivateButton: some View {
        Button {
            showDeactivateConfirmation = true
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundColor(.white)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Avaktivera tränarkonto")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text("Ta bort din annons från kartan")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.8))
                }
                
                Spacer()
                
                if isDeactivating {
                    ProgressView()
                        .tint(.white)
                } else {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white.opacity(0.7))
                }
            }
            .padding(16)
            .background(Color(.systemGray3))
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
        .disabled(isDeactivating)
    }
    
    // MARK: - Stats Overview
    
    private var statsOverview: some View {
        HStack(spacing: 16) {
            StatCard(
                title: "Väntande",
                value: "\(viewModel.pendingBookings.count)",
                icon: "clock.fill",
                color: .gray
            )
            
            StatCard(
                title: "Bokade",
                value: "\(viewModel.acceptedBookings.count)",
                icon: "checkmark.circle.fill",
                color: .black
            )
            
            StatCard(
                title: "Totalt",
                value: "\(viewModel.allBookings.count)",
                icon: "calendar.badge.plus",
                color: .black
            )
        }
    }
    
    // MARK: - Bookings Section
    
    private func bookingsSection(title: String, bookings: [TrainerBooking], emptyMessage: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
            
            if bookings.isEmpty && !emptyMessage.isEmpty {
                Text(emptyMessage)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
            } else {
                ForEach(bookings) { booking in
                    BookingCard(booking: booking) {
                        selectedBooking = booking
                        showChatSheet = true
                    }
                }
            }
        }
    }
}

// MARK: - Stat Card

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - Booking Card

struct BookingCard: View {
    let booking: TrainerBooking
    let onTap: () -> Void
    
    // Static formatter for performance
    private static let relativeDateFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(identifier: "sv_SE")
        formatter.unitsStyle = .short
        return formatter
    }()
    
    var body: some View {
        Button(action: onTap) {
            cardContent
        }
        .buttonStyle(.plain)
    }
    
    private var cardContent: some View {
        HStack(spacing: 12) {
            avatarSection
            infoSection
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private var avatarSection: some View {
        ZStack(alignment: .topTrailing) {
            ProfileImage(url: booking.studentAvatarUrl, size: 50)
            
            if let unread = booking.unreadCount, unread > 0 {
                Text("\(unread)")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .padding(4)
                    .background(Color.black)
                    .clipShape(Circle())
                    .offset(x: 4, y: -4)
            }
        }
    }
    
    private var infoSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(booking.studentUsername ?? "Okänd användare")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                StatusBadge(status: booking.bookingStatus)
            }
            
            Text(booking.message)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .lineLimit(2)
            
            HStack {
                if let date = booking.createdAt {
                    Text(Self.relativeDateFormatter.localizedString(for: date, relativeTo: Date()))
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
    }
}

// MARK: - Status Badge

struct StatusBadge: View {
    let status: BookingStatus
    
    var body: some View {
        Text(status.displayName)
            .font(.caption)
            .fontWeight(.semibold)
            .foregroundColor(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(statusColor)
            .cornerRadius(8)
    }
    
    private var statusColor: Color {
        switch status {
        case .pending: return .gray
        case .accepted: return .black
        case .declined: return .black
        case .cancelled: return .gray
        }
    }
}

// MARK: - Booking Response View

struct BookingResponseView: View {
    let booking: TrainerBooking
    let onRespond: (BookingStatus, String?) -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var responseMessage = ""
    @State private var isProcessing = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                // Student Info
                HStack(spacing: 12) {
                    ProfileImage(url: booking.studentAvatarUrl, size: 60)
                    
                    VStack(alignment: .leading) {
                        Text(booking.studentUsername ?? "Okänd användare")
                            .font(.headline)
                        Text("Vill boka en lektion")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
                
                // Message
                VStack(alignment: .leading, spacing: 8) {
                    Text("Meddelande")
                        .font(.headline)
                    
                    Text(booking.message)
                        .font(.body)
                        .foregroundColor(.secondary)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                }
                
                // Response
                VStack(alignment: .leading, spacing: 8) {
                    Text("Ditt svar (valfritt)")
                        .font(.headline)
                    
                    TextField("Skriv ett meddelande...", text: $responseMessage, axis: .vertical)
                        .lineLimit(3...5)
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                }
                
                Spacer()
                
                // Action Buttons
                HStack(spacing: 16) {
                    Button {
                        isProcessing = true
                        onRespond(.declined, responseMessage.isEmpty ? nil : responseMessage)
                    } label: {
                        HStack {
                            Image(systemName: "xmark")
                            Text("Avböj")
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(.systemGray3))
                        .cornerRadius(12)
                    }
                    .disabled(isProcessing)
                    
                    Button {
                        isProcessing = true
                        onRespond(.accepted, responseMessage.isEmpty ? nil : responseMessage)
                    } label: {
                        HStack {
                            Image(systemName: "checkmark")
                            Text("Godkänn")
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.black)
                        .cornerRadius(12)
                    }
                    .disabled(isProcessing)
                }
            }
            .padding()
            .navigationTitle("Bokningsförfrågan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Avbryt") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - View Model

class TrainerDashboardViewModel: ObservableObject {
    @Published var allBookings: [TrainerBooking] = [] {
        didSet {
            // Update cached filtered arrays when bookings change
            _pendingBookings = allBookings.filter { $0.bookingStatus == .pending }
            _acceptedBookings = allBookings.filter { $0.bookingStatus == .accepted }
            _pastBookings = allBookings.filter { $0.bookingStatus == .declined || $0.bookingStatus == .cancelled }
        }
    }
    @Published var isLoading = false
    @Published var trainerId: String?
    
    // Cached filtered bookings to avoid recomputation
    private var _pendingBookings: [TrainerBooking] = []
    private var _acceptedBookings: [TrainerBooking] = []
    private var _pastBookings: [TrainerBooking] = []
    
    var pendingBookings: [TrainerBooking] { _pendingBookings }
    var acceptedBookings: [TrainerBooking] { _acceptedBookings }
    var pastBookings: [TrainerBooking] { _pastBookings }
    
    private var lastLoadTime: Date?
    private var lastTrainerIdLoad: Date?
    private let cacheThrottle: TimeInterval = 15 // 15 seconds cache
    private let trainerIdCacheThrottle: TimeInterval = 300 // 5 minutes for trainer ID
    
    // Don't load on init - let the view control when to load
    init() {}
    
    @MainActor
    func loadTrainerIdIfNeeded() async {
        // Return if we already have trainerId and it's recent
        if trainerId != nil,
           let lastLoad = lastTrainerIdLoad,
           Date().timeIntervalSince(lastLoad) < trainerIdCacheThrottle {
            return
        }
        
        guard let userId = AuthViewModel.shared.currentUser?.id else { return }
        
        do {
            struct TrainerIdResponse: Decodable {
                let id: String
            }
            
            let response: TrainerIdResponse = try await SupabaseConfig.supabase
                .from("trainer_profiles")
                .select("id")
                .eq("user_id", value: userId)
                .single()
                .execute()
                .value
            
            trainerId = response.id
            lastTrainerIdLoad = Date()
        } catch {
            print("❌ Failed to load trainer ID: \(error)")
        }
    }
    
    @MainActor
    func loadBookings(force: Bool = false) async {
        // Use cached data if recent
        if !force,
           let lastLoad = lastLoadTime,
           Date().timeIntervalSince(lastLoad) < cacheThrottle,
           !allBookings.isEmpty {
            return
        }
        
        // Only show loading if we have no data
        if allBookings.isEmpty {
            isLoading = true
        }
        
        do {
            allBookings = try await TrainerService.shared.getBookingsForTrainer()
            lastLoadTime = Date()
        } catch {
            print("❌ Failed to load bookings: \(error)")
        }
        
        isLoading = false
    }
    
    @MainActor
    func refresh() async {
        await loadBookings(force: true)
    }
    
    @MainActor
    func updateBookingStatus(bookingId: UUID, status: BookingStatus, response: String?) async {
        do {
            try await TrainerService.shared.updateBookingStatus(
                bookingId: bookingId,
                status: status,
                response: response
            )
            
            // Refresh the list (force reload after update)
            await loadBookings(force: true)
        } catch {
            print("❌ Failed to update booking status: \(error)")
        }
    }
}

// MARK: - Helper Struct for Stripe

private struct TrainerProfileStripe: Decodable {
    let stripe_account_id: String?
}

#Preview {
    TrainerDashboardView()
}

