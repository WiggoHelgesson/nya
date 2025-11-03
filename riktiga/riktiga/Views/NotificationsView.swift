import SwiftUI

struct NotificationsView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var notifications: [AppNotification] = []
    @State private var isLoading = false
    @State private var task: Task<Void, Never>?
    @State private var hasMarkedRead = false
    var onDismiss: (() -> Void)? = nil
    
    var body: some View {
        NavigationStack {
            VStack {
                HStack {
                    Text("Notifikationer")
                        .font(.headline)
                    Spacer()
                    Button(action: {
                        markAllAsReadIfNeeded()
                        dismiss()
                    }) {
                        Image(systemName: "xmark")
                            .foregroundColor(.black)
                    }
                }
                .padding()
                
                if isLoading {
                    VStack(spacing: 20) {
                        ProgressView()
                            .tint(.blue)
                        Text("Laddar notifikationer...")
                            .font(.system(size: 14))
                            .foregroundColor(.gray)
                    }
                    .frame(maxHeight: .infinity)
                } else if notifications.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "bell.slash.fill")
                            .font(.system(size: 48))
                            .foregroundColor(.gray)
                        
                        Text("Inga notifikationer")
                            .font(.headline)
                        
                        Text("Du har inga nya notifikationer just nu")
                            .font(.caption)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxHeight: .infinity)
                    .padding()
                } else {
                    List {
                        ForEach(notifications) { notification in
                            NavigationLink(destination: UserProfileView(userId: notification.triggeredByUserId)) {
                                NotificationRow(notification: notification)
                            }
                            .listRowSeparator(.hidden)
                        }
                    }
                    .listStyle(.plain)
                }
                
                Spacer()
            }
            .task {
                await loadNotifications()
            }
            .onDisappear {
                markAllAsReadIfNeeded()
            }
        }
    }
    
    private func loadNotifications() async {
        guard let userId = authViewModel.currentUser?.id else { return }
        
        isLoading = true
        do {
            notifications = try await NotificationService.shared.getNotifications(userId: userId)
            isLoading = false
        } catch {
            print("❌ Error loading notifications: \(error)")
            isLoading = false
        }
    }
    
    private func markAllAsReadIfNeeded() {
        guard !hasMarkedRead, let userId = authViewModel.currentUser?.id else { return }
        hasMarkedRead = true
        Task {
            do {
                try await NotificationService.shared.markAllAsRead(userId: userId)
            } catch {
                print("⚠️ Failed to mark notifications as read: \(error)")
            }
            await MainActor.run {
                onDismiss?()
            }
        }
    }
}

struct NotificationRow: View {
    let notification: AppNotification
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // User avatar
            if let avatarUrl = notification.triggeredByUserAvatar, !avatarUrl.isEmpty {
                AsyncImage(url: URL(string: avatarUrl)) { image in
                    image
                        .resizable()
                        .scaledToFill()
                } placeholder: {
                    Image(systemName: "person.circle.fill")
                        .foregroundColor(.gray)
                }
                .frame(width: 44, height: 44)
                .clipShape(Circle())
            } else {
                Image(systemName: "person.circle.fill")
                    .font(.system(size: 44))
                    .foregroundColor(.gray)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                // User name with action type
                HStack(spacing: 4) {
                    Text(notification.triggeredByUserName)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.black)
                    
                    Image(systemName: getIconForType(notification.type))
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(getColorForType(notification.type))
                }
                
                // Description
                Text(notification.displayText)
                    .font(.system(size: 13))
                    .foregroundColor(.gray)
                    .lineLimit(2)
                
                // Time
                Text(formatTime(notification.createdAt))
                    .font(.system(size: 12))
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            // Unread indicator
            if !notification.isRead {
                Circle()
                    .fill(Color.blue)
                    .frame(width: 8, height: 8)
            }
        }
        .padding(12)
        .background(Color(.systemGray6))
        .cornerRadius(8)
        .padding(.vertical, 4)
    }
    
    private func getIconForType(_ type: AppNotification.NotificationType) -> String {
        switch type {
        case .like:
            return "heart.fill"
        case .comment:
            return "bubble.right.fill"
        case .follow:
            return "person.badge.plus.fill"
        }
    }
    
    private func getColorForType(_ type: AppNotification.NotificationType) -> Color {
        switch type {
        case .like:
            return .red
        case .comment:
            return .blue
        case .follow:
            return .green
        }
    }
    
    private func formatTime(_ dateString: String) -> String {
        let formatter = ISO8601DateFormatter()
        guard let date = formatter.date(from: dateString) else {
            return "just nu"
        }
        
        let calendar = Calendar.current
        let now = Date()
        let components = calendar.dateComponents([.minute, .hour, .day], from: date, to: now)
        
        if let day = components.day, day >= 1 {
            return "\(day)d sedan"
        } else if let hour = components.hour, hour >= 1 {
            return "\(hour)h sedan"
        } else if let minute = components.minute, minute >= 1 {
            return "\(minute)m sedan"
        } else {
            return "just nu"
        }
    }
}

#Preview {
    NotificationsView()
        .environmentObject(AuthViewModel())
}
