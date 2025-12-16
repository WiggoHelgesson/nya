import SwiftUI

struct NotificationsView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    private let notificationService = NotificationService.shared
    @State private var isLoading = false
    @State private var notifications: [AppNotification] = []
    @State private var selectedNotification: AppNotification?
    @State private var selectedProfileId: String?
    @State private var errorMessage: String? // Added for error handling
    var onDismiss: (() -> Void)? = nil
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()
                
                if isLoading && notifications.isEmpty {
                    ProgressView()
                        .scaleEffect(1.5)
                } else if let error = errorMessage {
                    // Error State
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.orange)
                        
                        Text("Kunde inte ladda notiser")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text(error)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        
                        Button("Försök igen") {
                            Task { await loadNotifications() }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                } else if notifications.isEmpty {
                    emptyStateView
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(notifications) { notification in
                                NotificationRow(notification: notification) {
                                    handleNotificationTap(notification)
                                }
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Notiser")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                if !notifications.isEmpty {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Markera alla som lästa") {
                            markAllAsRead()
                        }
                        .font(.system(size: 13, weight: .medium))
                    }
                }
            }
            .refreshable {
                await loadNotifications()
            }
            .onAppear {
                Task {
                    await loadNotifications()
                }
            }
            .onDisappear {
                onDismiss?()
            }
            .navigationDestination(isPresented: Binding(
                get: { selectedProfileId != nil },
                set: { newValue in
                    if !newValue {
                        selectedProfileId = nil
                    }
                }
            )) {
                if let userId = selectedProfileId {
                    UserProfileView(userId: userId)
                }
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "bell.slash.fill")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text("Inga notiser")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("Du kommer att få notiser när någon gillar, kommenterar eller följer dig")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
    }
    
    private func loadNotifications() async {
        guard let userId = authViewModel.currentUser?.id else { return }
        
        await MainActor.run { 
            isLoading = true 
            errorMessage = nil
        }
        do {
            let fetched = try await notificationService.fetchNotifications(userId: userId)
            await MainActor.run {
                notifications = fetched
                isLoading = false
            }
        } catch {
            print("❌ Error loading notifications: \(error)")
            await MainActor.run { 
                isLoading = false
                errorMessage = error.localizedDescription
            }
        }
    }
    
    private func handleNotificationTap(_ notification: AppNotification) {
        Task {
            // Mark as read
            if !notification.isRead {
                try? await notificationService.markAsRead(notificationId: notification.id)
                await MainActor.run {
                    if let index = notifications.firstIndex(where: { $0.id == notification.id }) {
                        notifications[index].isRead = true
                    }
                }
            }
            
            await MainActor.run {
                // Only navigate if we have a valid actorId (system notifications might not)
                if !notification.actorId.isEmpty {
                    selectedProfileId = notification.actorId
                }
            }
        }
    }
    
    private func markAllAsRead() {
        guard let userId = authViewModel.currentUser?.id else { return }
        
        Task {
            try? await notificationService.markAllAsRead(userId: userId)
            await MainActor.run {
                notifications = notifications.map { item in
                    var updated = item
                    updated.isRead = true
                    return updated
                }
            }
        }
    }
}

struct NotificationRow: View {
    let notification: AppNotification
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Avatar
                AsyncImage(url: URL(string: notification.actorAvatarUrl ?? "")) { image in
                    image
                        .resizable()
                        .scaledToFill()
                } placeholder: {
                    Image(systemName: "person.circle.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.gray)
                }
                .frame(width: 50, height: 50)
                .clipShape(Circle())
                
                // Content
                VStack(alignment: .leading, spacing: 4) {
                    Text(notification.displayText)
                        .font(.system(size: 15))
                        .foregroundColor(.primary)
                        .lineLimit(2)
                    
                    Text(relativeTime(from: notification.createdAt))
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Icon and unread indicator
                VStack {
                    Image(systemName: notification.icon)
                        .font(.system(size: 16))
                        .foregroundColor(iconColor(for: notification.iconColor))
                    
                    if !notification.isRead {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 8, height: 8)
                    }
                }
            }
            .padding()
            .background(notification.isRead ? Color(.systemBackground) : Color(.systemBackground).opacity(0.95))
            .cornerRadius(12)
            .shadow(color: notification.isRead ? Color.black.opacity(0.05) : Color.red.opacity(0.1), radius: 4, x: 0, y: 2)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func iconColor(for colorString: String) -> Color {
        switch colorString {
        case "red": return .red
        case "blue": return .blue
        case "green": return .green
        default: return .gray
        }
    }
    
    private func relativeTime(from isoString: String) -> String {
        let formatter = ISO8601DateFormatter()
        guard let date = formatter.date(from: isoString) else { return "" }
        
        let now = Date()
        let diff = now.timeIntervalSince(date)
        
        if diff < 60 {
            return "Just nu"
        } else if diff < 3600 {
            let minutes = Int(diff / 60)
            return "\(minutes)m sedan"
        } else if diff < 86400 {
            let hours = Int(diff / 3600)
            return "\(hours)h sedan"
        } else if diff < 604800 {
            let days = Int(diff / 86400)
            return "\(days)d sedan"
        } else {
            let weeks = Int(diff / 604800)
            return "\(weeks)v sedan"
        }
    }
}
