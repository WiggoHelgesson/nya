import SwiftUI
import Combine

struct MyBookingsView: View {
    @StateObject private var viewModel = MyBookingsViewModel()
    @State private var selectedBooking: TrainerBooking?
    @State private var showChat = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if viewModel.isLoading {
                    ProgressView()
                        .padding(.top, 50)
                } else if viewModel.bookings.isEmpty {
                    emptyState
                } else {
                    // Active Bookings
                    if !viewModel.activeBookings.isEmpty {
                        bookingsSection(
                            title: "Aktiva bokningar",
                            bookings: viewModel.activeBookings
                        )
                    }
                    
                    // Pending Bookings
                    if !viewModel.pendingBookings.isEmpty {
                        bookingsSection(
                            title: "Väntande förfrågningar",
                            bookings: viewModel.pendingBookings
                        )
                    }
                    
                    // Past Bookings
                    if !viewModel.pastBookings.isEmpty {
                        bookingsSection(
                            title: "Tidigare",
                            bookings: viewModel.pastBookings
                        )
                    }
                }
            }
            .padding()
        }
        .navigationTitle("Mina lektioner")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.loadBookings()
        }
        .refreshable {
            await viewModel.loadBookings()
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
    
    private func bookingsSection(title: String, bookings: [TrainerBooking]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
                .padding(.horizontal, 4)
            
            ForEach(bookings) { booking in
                StudentBookingCard(booking: booking) {
                    selectedBooking = booking
                    showChat = true
                }
            }
        }
    }
}

// MARK: - Student Booking Card

struct StudentBookingCard: View {
    let booking: TrainerBooking
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Trainer Avatar
                ZStack(alignment: .topTrailing) {
                    AsyncImage(url: URL(string: booking.trainerAvatarUrl ?? "")) { image in
                        image.resizable().scaledToFill()
                    } placeholder: {
                        Image(systemName: "person.circle.fill")
                            .resizable()
                            .foregroundColor(.gray)
                    }
                    .frame(width: 56, height: 56)
                    .clipShape(Circle())
                    
                    if let unread = booking.unreadCount, unread > 0 {
                        Text("\(unread)")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .padding(5)
                            .background(Color.red)
                            .clipShape(Circle())
                            .offset(x: 4, y: -4)
                    }
                }
                
                // Booking Info
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(booking.trainerName ?? "Tränare")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        StudentStatusBadge(status: booking.bookingStatus)
                    }
                    
                    if let rate = booking.hourlyRate {
                        Text("\(rate) kr/h")
                            .font(.subheadline)
                            .foregroundColor(.black)
                    }
                    
                    Text(booking.message)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                    
                    HStack {
                        if let date = booking.createdAt {
                            Text(formatDate(date))
                                .font(.caption2)
                                .foregroundColor(.gray)
                        }
                        
                        Spacer()
                        
                        HStack(spacing: 4) {
                            Image(systemName: "message")
                                .font(.caption2)
                            Text("Chatta")
                                .font(.caption2)
                        }
                        .foregroundColor(.blue)
                    }
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(16)
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
        case .pending: return "Väntar"
        case .accepted: return "Godkänd"
        case .declined: return "Nekad"
        case .cancelled: return "Avbokad"
        }
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

// MARK: - View Model

class MyBookingsViewModel: ObservableObject {
    @Published var bookings: [TrainerBooking] = []
    @Published var isLoading = false
    
    private var lastLoadTime: Date?
    private let cacheThrottle: TimeInterval = 15 // 15 seconds cache
    
    var activeBookings: [TrainerBooking] {
        bookings.filter { $0.bookingStatus == .accepted }
    }
    
    var pendingBookings: [TrainerBooking] {
        bookings.filter { $0.bookingStatus == .pending }
    }
    
    var pastBookings: [TrainerBooking] {
        bookings.filter { $0.bookingStatus == .declined || $0.bookingStatus == .cancelled }
    }
    
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

