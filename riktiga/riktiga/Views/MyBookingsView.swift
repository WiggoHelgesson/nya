import SwiftUI
import Combine

struct MyBookingsView: View {
    @StateObject private var viewModel = MyBookingsViewModel()
    @State private var selectedBooking: TrainerBooking?
    @State private var showChat = false
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                if viewModel.isLoading {
                    ProgressView()
                        .padding(.top, 50)
                } else if viewModel.bookings.isEmpty {
                    emptyState
                } else {
                    // Paid Requests (pending - waiting for trainer to accept)
                    let paidRequests = viewModel.paidRequests
                    if !paidRequests.isEmpty {
                        bookingsSection(
                            title: "Betalda förfrågningar",
                            subtitle: "Väntar på tränarens bekräftelse",
                            bookings: paidRequests
                        )
                    }
                    
                    // Upcoming Bookings (accepted)
                    let upcomingBookings = viewModel.upcomingBookings
                    if !upcomingBookings.isEmpty {
                        bookingsSection(
                            title: "Kommande bokningar",
                            subtitle: nil,
                            bookings: upcomingBookings
                        )
                    }
                    
                    // Past Bookings
                    let pastBookings = viewModel.pastBookings
                    if !pastBookings.isEmpty {
                        bookingsSection(
                            title: "Tidigare",
                            subtitle: nil,
                            bookings: pastBookings
                        )
                    }
                }
            }
            .padding()
        }
        .navigationTitle("Mina bokningar")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.loadBookings()
        }
        .refreshable {
            await viewModel.loadBookings(force: true)
        }
        .sheet(isPresented: $showChat) {
            if let booking = selectedBooking {
                BookingChatView(booking: booking)
                    .onDisappear {
                        Task { await viewModel.loadBookings(force: true) }
                    }
            }
        }
    }
    
    // MARK: - Empty State
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "figure.golf")
                .font(.system(size: 60))
                .foregroundColor(.gray.opacity(0.5))
            
            Text("Inga bokningar ännu")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Hitta en golftränare i Lektioner-fliken och boka din första lektion!")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .padding(.top, 80)
    }
    
    // MARK: - Bookings Section
    
    private func bookingsSection(title: String, subtitle: String?, bookings: [TrainerBooking]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                
                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 4)
            
            ForEach(bookings) { booking in
                StudentBookingCard(booking: booking, onChatTap: {
                    selectedBooking = booking
                    showChat = true
                })
            }
        }
    }
}

// MARK: - Student Booking Card

struct StudentBookingCard: View {
    let booking: TrainerBooking
    let onChatTap: () -> Void
    
    // Static formatter for performance - created once, reused
    private static let relativeDateFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(identifier: "sv_SE")
        formatter.unitsStyle = .short
        return formatter
    }()
    
    var body: some View {
        VStack(spacing: 12) {
            // Main card content
            HStack(spacing: 12) {
                avatarSection
                infoSection
            }
            
            // Chat button - prominent
            Button(action: onChatTap) {
                HStack(spacing: 8) {
                    Image(systemName: "message.fill")
                    Text("Chatta med \(booking.trainerName ?? "tränaren")")
                        .fontWeight(.semibold)
                }
                .font(.subheadline)
                .foregroundColor(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color(.systemGray5))
                .cornerRadius(10)
            }
            .buttonStyle(.plain)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(16)
    }
    
    private var avatarSection: some View {
        ZStack(alignment: .topTrailing) {
            ProfileImage(url: booking.trainerAvatarUrl, size: 56)
            
            if let unread = booking.unreadCount, unread > 0 {
                Text("\(unread)")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .padding(5)
                    .background(Color.black)
                    .clipShape(Circle())
                    .offset(x: 4, y: -4)
            }
        }
    }
    
    private var infoSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Header row
            HStack {
                Text(booking.trainerName ?? "Tränare")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                StudentStatusBadge(status: booking.bookingStatus)
            }
            
            // Scheduled date & time
            if let date = booking.formattedDate, let time = booking.formattedTime {
                HStack(spacing: 8) {
                    Label(date, systemImage: "calendar")
                    Label(time, systemImage: "clock")
                }
                .font(.subheadline)
                .foregroundColor(.black)
            }
            
            // Price
            if let price = booking.price {
                Text("\(price) kr")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.black)
            }
            
            // Location info
            if let city = booking.trainerCity {
                Label(city, systemImage: "mappin.circle.fill")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // Booked date
            if let date = booking.createdAt {
                Text("Bokad \(Self.relativeDateFormatter.localizedString(for: date, relativeTo: Date()))")
                    .font(.caption2)
                    .foregroundColor(.gray)
            }
        }
    }
}

// MARK: - Student Status Badge

struct StudentStatusBadge: View {
    let status: BookingStatus
    
    var body: some View {
        Text(statusText)
            .font(.caption)
            .fontWeight(.semibold)
            .foregroundColor(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(statusColor)
            .cornerRadius(8)
    }
    
    private var statusText: String {
        switch status {
        case .pending: return "Betald"
        case .accepted: return "Bekräftad"
        case .declined: return "Nekad"
        case .cancelled: return "Avbokad"
        }
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

// MARK: - View Model

class MyBookingsViewModel: ObservableObject {
    @Published var bookings: [TrainerBooking] = [] {
        didSet {
            // Update cached filtered arrays when bookings change
            _paidRequests = bookings.filter { $0.bookingStatus == .pending }
            _upcomingBookings = bookings.filter { $0.bookingStatus == .accepted }
            _pastBookings = bookings.filter { $0.bookingStatus == .declined || $0.bookingStatus == .cancelled }
        }
    }
    @Published var isLoading = false
    
    // Cached filtered bookings to avoid recomputation
    private var _paidRequests: [TrainerBooking] = []
    private var _upcomingBookings: [TrainerBooking] = []
    private var _pastBookings: [TrainerBooking] = []
    
    var paidRequests: [TrainerBooking] { _paidRequests }
    var upcomingBookings: [TrainerBooking] { _upcomingBookings }
    var pastBookings: [TrainerBooking] { _pastBookings }
    
    private var lastLoadTime: Date?
    private let cacheThrottle: TimeInterval = 15 // 15 seconds cache
    
    @MainActor
    func loadBookings(force: Bool = false) async {
        // Use cached data if recent
        if !force,
           let lastLoad = lastLoadTime,
           Date().timeIntervalSince(lastLoad) < cacheThrottle,
           !bookings.isEmpty {
            return
        }
        
        // Only show loading if we have no data
        if bookings.isEmpty {
            isLoading = true
        }
        
        do {
            bookings = try await TrainerService.shared.getBookingsForStudent()
            lastLoadTime = Date()
        } catch {
            print("❌ Failed to load student bookings: \(error)")
        }
        
        isLoading = false
    }
}

#Preview {
    NavigationStack {
        MyBookingsView()
    }
}

