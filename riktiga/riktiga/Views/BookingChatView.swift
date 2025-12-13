import SwiftUI
import Combine
import Supabase
import Auth

struct BookingChatView: View {
    let booking: TrainerBooking
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: BookingChatViewModel
    @State private var messageText = ""
    @FocusState private var isTextFieldFocused: Bool
    
    init(booking: TrainerBooking) {
        self.booking = booking
        _viewModel = StateObject(wrappedValue: BookingChatViewModel(booking: booking))
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Status header - always show immediately
                statusHeader
                
                // Messages area - show content or loading inline
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            if viewModel.isLoading && viewModel.messages.isEmpty {
                                // Inline loading - not a blank screen
                                VStack(spacing: 12) {
                                    ProgressView()
                                        .scaleEffect(1.2)
                                    Text("Laddar chatt...")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.top, 80)
                            } else if let error = viewModel.errorMessage {
                                VStack(spacing: 12) {
                                    Image(systemName: "exclamationmark.triangle")
                                        .font(.largeTitle)
                                        .foregroundColor(.orange)
                                    Text(error)
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                        .multilineTextAlignment(.center)
                                    Button("Försök igen") {
                                        Task { await viewModel.loadMessages() }
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .tint(.black)
                                }
                                .padding(.top, 50)
                            } else if viewModel.messages.isEmpty {
                                Text("Inga meddelanden ännu.\nSkriv något för att starta chatten!")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                                    .padding(.top, 50)
                            } else {
                                ForEach(viewModel.messages) { message in
                                    BookingMessageBubble(
                                        message: message,
                                        isCurrentUser: message.senderId == viewModel.currentUserId
                                    )
                                    .id(message.id)
                                }
                            }
                        }
                        .padding()
                    }
                    .onChange(of: viewModel.messages.count) { _ in
                        if let lastMessage = viewModel.messages.last {
                            withAnimation {
                                proxy.scrollTo(lastMessage.id, anchor: .bottom)
                            }
                        }
                    }
                }
                
                // Input bar - always show if booking is active
                if booking.bookingStatus != .declined && booking.bookingStatus != .cancelled {
                    inputBar
                }
            }
            .background(Color(.systemBackground))
            .navigationTitle(booking.trainerName ?? "Chatt")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Stäng") {
                        dismiss()
                    }
                }
                
                if viewModel.isTrainer && booking.bookingStatus == .pending {
                    ToolbarItem(placement: .topBarTrailing) {
                        Menu {
                            Button {
                                Task { await viewModel.acceptBooking() }
                            } label: {
                                Label("Godkänn", systemImage: "checkmark.circle")
                            }
                            
                            Button(role: .destructive) {
                                Task { await viewModel.declineBooking() }
                            } label: {
                                Label("Avböj", systemImage: "xmark.circle")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                        }
                    }
                }
            }
            .task {
                await viewModel.initialize()
            }
            .refreshable {
                await viewModel.loadMessages()
            }
        }
    }
    
    // MARK: - Status Header
    
    private var statusHeader: some View {
        HStack(spacing: 12) {
            // Avatar
            AsyncImage(url: URL(string: viewModel.isTrainer ? (booking.studentAvatarUrl ?? "") : (booking.trainerAvatarUrl ?? ""))) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                Image(systemName: "person.circle.fill")
                    .resizable()
                    .foregroundColor(.gray)
            }
            .frame(width: 44, height: 44)
            .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: 2) {
                Text(viewModel.isTrainer ? (booking.studentUsername ?? "Kund") : (booking.trainerName ?? "Tränare"))
                    .font(.headline)
                
                HStack(spacing: 4) {
                    Circle()
                        .fill(statusColor)
                        .frame(width: 8, height: 8)
                    
                    Text(booking.bookingStatus.displayName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            if let rate = booking.hourlyRate {
                Text("\(rate) kr/h")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemGray6))
    }
    
    private var statusColor: Color {
        switch booking.bookingStatus {
        case .pending: return .orange
        case .accepted: return .black
        case .declined: return .red
        case .cancelled: return .gray
        }
    }
    
    // MARK: - Input Bar
    
    private var inputBar: some View {
        HStack(spacing: 12) {
            TextField("Skriv ett meddelande...", text: $messageText, axis: .vertical)
                .lineLimit(1...4)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(.systemGray6))
                .cornerRadius(20)
                .focused($isTextFieldFocused)
            
            Button {
                sendMessage()
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.title)
                    .foregroundColor(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? .gray : .black)
            }
            .disabled(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding()
        .background(Color(.systemBackground))
    }
    
    private func sendMessage() {
        let text = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        
        Task {
            await viewModel.sendMessage(text)
            messageText = ""
        }
    }
}

// MARK: - Booking Message Bubble

struct BookingMessageBubble: View {
    let message: BookingMessage
    let isCurrentUser: Bool
    
    var body: some View {
        HStack {
            if isCurrentUser { Spacer(minLength: 60) }
            
            VStack(alignment: isCurrentUser ? .trailing : .leading, spacing: 4) {
                if !isCurrentUser {
                    Text(message.senderUsername ?? "")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Text(message.message)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(isCurrentUser ? Color.black : Color(.systemGray5))
                    .foregroundColor(isCurrentUser ? .white : .primary)
                    .cornerRadius(18)
                
                if let date = message.createdAt {
                    Text(formatTime(date))
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
            }
            
            if !isCurrentUser { Spacer(minLength: 60) }
        }
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.locale = Locale(identifier: "sv_SE")
        return formatter.string(from: date)
    }
}

// MARK: - View Model

class BookingChatViewModel: ObservableObject {
    @Published var messages: [BookingMessage] = []
    @Published var isLoading = true
    @Published var currentUserId: UUID?
    @Published var errorMessage: String?
    
    let booking: TrainerBooking
    var isTrainer: Bool {
        guard let currentUserId = currentUserId, let trainerUserID = booking.trainerUserID else {
            return false
        }
        return currentUserId == trainerUserID
    }
    
    // Static cache for current user ID to avoid repeated fetches
    private static var cachedUserId: UUID?
    
    init(booking: TrainerBooking) {
        self.booking = booking
        // Use cached user ID immediately if available
        if let cached = Self.cachedUserId {
            self.currentUserId = cached
        }
    }
    
    @MainActor
    func initialize() async {
        // Get current user ID if not cached
        if currentUserId == nil {
            do {
                let session = try await SupabaseConfig.supabase.auth.session
                self.currentUserId = session.user.id
                Self.cachedUserId = session.user.id
            } catch {
                print("❌ Failed to get user session: \(error)")
                // Don't show error for this - still load messages
            }
        }
        
        // Load messages in parallel
        await loadMessages()
    }
    
    @MainActor
    func loadMessages() async {
        isLoading = true
        errorMessage = nil
        
        do {
            messages = try await TrainerService.shared.getMessagesForBooking(bookingId: booking.id)
            print("✅ Loaded \(messages.count) messages")
            
            // Mark as read
            try? await TrainerService.shared.markMessagesAsRead(bookingId: booking.id)
        } catch {
            print("❌ Failed to load messages: \(error)")
            errorMessage = "Kunde inte hämta meddelanden: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    @MainActor
    func sendMessage(_ text: String) async {
        do {
            _ = try await TrainerService.shared.sendMessage(bookingId: booking.id, message: text)
            await loadMessages()
        } catch {
            print("❌ Failed to send message: \(error)")
            errorMessage = "Kunde inte skicka meddelande"
        }
    }
    
    @MainActor
    func acceptBooking() async {
        do {
            try await TrainerService.shared.updateBookingStatus(
                bookingId: booking.id,
                status: .accepted
            )
        } catch {
            print("❌ Failed to accept booking: \(error)")
        }
    }
    
    @MainActor
    func declineBooking() async {
        do {
            try await TrainerService.shared.updateBookingStatus(
                bookingId: booking.id,
                status: .declined
            )
        } catch {
            print("❌ Failed to decline booking: \(error)")
        }
    }
}

#Preview {
    BookingChatView(booking: TrainerBooking(
        id: UUID(),
        trainerId: UUID(),
        studentId: UUID(),
        message: "Hej! Jag vill boka en lektion.",
        status: "pending",
        trainerResponse: nil,
        createdAt: Date(),
        updatedAt: Date(),
        lessonTypeId: nil,
        scheduledDate: "2025-01-15",
        scheduledTime: "14:00:00",
        durationMinutes: 60,
        price: 500,
        locationType: "course",
        golfCourseId: nil,
        customLocationName: nil,
        customLocationLat: nil,
        customLocationLng: nil,
        paymentStatus: "paid",
        stripePaymentId: nil,
        trainerUserID: UUID(),
        trainerName: "Tiger Woods",
        trainerAvatarUrl: nil,
        hourlyRate: 500,
        trainerCity: "Stockholm",
        studentUsername: "John",
        studentAvatarUrl: nil,
        unreadCount: 0
    ))
}

