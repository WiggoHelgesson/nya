import SwiftUI
import Combine
import Supabase

struct TrainerDashboardView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = TrainerDashboardViewModel()
    @State private var selectedBooking: TrainerBooking?
    @State private var showChatSheet = false
    @State private var showEditProfile = false
    @State private var showDeactivateConfirmation = false
    @State private var isDeactivating = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Manage Ad Button
                    manageAdButton
                    
                    // Deactivate Account Button
                    deactivateButton
                    
                    // Stats Overview
                    statsOverview
                    
                    // Pending Bookings
                    if !viewModel.pendingBookings.isEmpty {
                        bookingsSection(
                            title: "Väntande förfrågningar",
                            bookings: viewModel.pendingBookings,
                            emptyMessage: ""
                        )
                    }
                    
                    // Accepted Bookings
                    bookingsSection(
                        title: "Kommande lektioner",
                        bookings: viewModel.acceptedBookings,
                        emptyMessage: "Inga bokade lektioner"
                    )
                    
                    // Past Bookings
                    if !viewModel.pastBookings.isEmpty {
                        bookingsSection(
                            title: "Tidigare",
                            bookings: viewModel.pastBookings,
                            emptyMessage: ""
                        )
                    }
                }
                .padding()
            }
            .navigationTitle("Mina bokningar")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Stäng") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await viewModel.refresh() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
            .task {
                await viewModel.loadBookings()
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
    
    // MARK: - Manage Ad Button
    
    private var manageAdButton: some View {
        Button {
            showEditProfile = true
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "megaphone.fill")
                    .font(.title2)
                    .foregroundColor(.white)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Hantera annons")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text("Andra pris, plats och beskrivning")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.8))
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white.opacity(0.7))
            }
            .padding(16)
            .background(
                LinearGradient(
                    colors: [Color.blue, Color.blue.opacity(0.7)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
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
            .background(Color.red.opacity(0.8))
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
                color: .orange
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
                color: .blue
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
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Student Avatar with unread badge
                ZStack(alignment: .topTrailing) {
                    AsyncImage(url: URL(string: booking.studentAvatarUrl ?? "")) { image in
                        image
                            .resizable()
                            .scaledToFill()
                    } placeholder: {
                        Image(systemName: "person.circle.fill")
                            .resizable()
                            .foregroundColor(.gray)
                    }
                    .frame(width: 50, height: 50)
                    .clipShape(Circle())
                    
                    if let unread = booking.unreadCount, unread > 0 {
                        Text("\(unread)")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .padding(4)
                            .background(Color.red)
                            .clipShape(Circle())
                            .offset(x: 4, y: -4)
                    }
                }
                
                // Booking Info
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
                            Text(formatDate(date))
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
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(identifier: "sv_SE")
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
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
        case .pending: return .orange
        case .accepted: return .black
        case .declined: return .red
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
                    AsyncImage(url: URL(string: booking.studentAvatarUrl ?? "")) { image in
                        image.resizable().scaledToFill()
                    } placeholder: {
                        Image(systemName: "person.circle.fill").resizable().foregroundColor(.gray)
                    }
                    .frame(width: 60, height: 60)
                    .clipShape(Circle())
                    
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
                        .background(Color.red)
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
    @Published var allBookings: [TrainerBooking] = []
    @Published var isLoading = false
    
    private var lastLoadTime: Date?
    private let cacheThrottle: TimeInterval = 15 // 15 seconds cache
    
    var pendingBookings: [TrainerBooking] {
        allBookings.filter { $0.bookingStatus == .pending }
    }
    
    var acceptedBookings: [TrainerBooking] {
        allBookings.filter { $0.bookingStatus == .accepted }
    }
    
    var pastBookings: [TrainerBooking] {
        allBookings.filter { $0.bookingStatus == .declined || $0.bookingStatus == .cancelled }
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

#Preview {
    TrainerDashboardView()
}

