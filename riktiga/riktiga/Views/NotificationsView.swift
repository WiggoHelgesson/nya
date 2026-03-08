import SwiftUI

struct NotificationsView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    private let notificationService = NotificationService.shared
    @State private var isLoading = false
    @State private var notifications: [AppNotification] = []
    @State private var pendingCoachInvitations: [CoachInvitation] = []
    @State private var selectedNotification: AppNotification?
    @State private var selectedProfileId: String?
    @State private var selectedPostForComments: SocialWorkoutPost?
    @State private var errorMessage: String?
    @State private var hasMarkedAsRead = false
    @State private var showCoachInvitation: CoachInvitation?
    @State private var showCoachPrograms = false
    var onDismiss: (() -> Void)? = nil
    
    var body: some View {
        ZStack {
            Color(UIColor.systemGroupedBackground)
                .ignoresSafeArea()
            
            if isLoading && notifications.isEmpty {
                // Skeleton loading for notifications
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(0..<6, id: \.self) { _ in
                            SkeletonNotificationRow()
                            Divider()
                                .padding(.leading, 72)
                        }
                    }
                }
                .scrollDisabled(true)
            } else if let error = errorMessage {
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 50))
                        .foregroundColor(.orange)
                    
                    Text(L.t(sv: "Kunde inte ladda notiser", nb: "Kunne ikke laste varsler"))
                        .font(.system(size: 18, weight: .bold))
                    
                    Text(error)
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    
                    Button(L.t(sv: "Försök igen", nb: "Prøv igjen")) {
                        Task { await loadNotifications() }
                    }
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color.black)
                    .cornerRadius(20)
                }
            } else if notifications.isEmpty && pendingCoachInvitations.isEmpty {
                emptyStateView
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        // Coach invitations at the top (special cards)
                        ForEach(pendingCoachInvitations) { invitation in
                            CoachInvitationNotificationRow(
                                invitation: invitation,
                                onAccept: {
                                    handleAcceptInvitation(invitation)
                                },
                                onDecline: {
                                    handleDeclineInvitation(invitation)
                                }
                            )
                            
                            Divider()
                                .padding(.leading, 76)
                        }
                        
                        // Regular notifications
                        ForEach(notifications) { notification in
                            NotificationRowStrava(notification: notification) {
                                handleNotificationTap(notification)
                            }
                            
                            Divider()
                                .padding(.leading, 76)
                        }
                    }
                    .background(Color(.systemBackground))
                }
            }
        }
        .navigationTitle(L.t(sv: "Notiser", nb: "Varsler"))
        .navigationBarTitleDisplayMode(.inline)
        .refreshable {
            await loadNotifications()
        }
        .task {
            await loadNotifications()
            // Mark all as read when entering the page
            await markAllAsReadOnEntry()
        }
        .onAppear {
            NavigationDepthTracker.shared.setAtRoot(false)
        }
        .onDisappear {
            NavigationDepthTracker.shared.setAtRoot(true)
            onDismiss?()
        }
        .navigationDestination(isPresented: Binding(
            get: { selectedProfileId != nil },
            set: { if !$0 { selectedProfileId = nil } }
        )) {
            if let userId = selectedProfileId {
                UserProfileView(userId: userId)
            }
        }
        .navigationDestination(isPresented: Binding(
            get: { selectedPostForComments != nil },
            set: { if !$0 { selectedPostForComments = nil } }
        )) {
            if let post = selectedPostForComments {
                CommentsView(post: post, onCommentAdded: nil)
                    .environmentObject(authViewModel)
            }
        }
        .sheet(isPresented: Binding(
            get: { showCoachInvitation != nil },
            set: { if !$0 { showCoachInvitation = nil } }
        )) {
            if let invitation = showCoachInvitation {
                NavigationStack {
                    CoachInvitationView(
                        invitation: invitation,
                        onAccept: {
                            showCoachInvitation = nil
                            // Refresh notifications
                            Task { await loadNotifications() }
                        },
                        onDecline: {
                            showCoachInvitation = nil
                            // Refresh notifications
                            Task { await loadNotifications() }
                        }
                    )
                    .navigationTitle(L.t(sv: "Coach-inbjudan", nb: "Trener-invitasjon"))
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button(L.t(sv: "Stäng", nb: "Lukk")) {
                                showCoachInvitation = nil
                            }
                        }
                    }
                }
                .presentationDetents([.medium])
            }
        }
        .navigationDestination(isPresented: $showCoachPrograms) {
            CoachProgramsListView()
                .environmentObject(authViewModel)
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "bell.slash")
                .font(.system(size: 50))
                .foregroundColor(.gray)
            
            Text(L.t(sv: "Inga notiser ännu", nb: "Ingen varsler ennå"))
                .font(.system(size: 18, weight: .bold))
            
            Text(L.t(sv: "När någon gillar, kommenterar eller följer dig kommer det att visas här.", nb: "Når noen liker, kommenterer eller følger deg vil det vises her."))
                .font(.system(size: 14))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
    }
    
    private func loadNotifications() async {
        guard let userId = authViewModel.currentUser?.id else { return }
        
        // Only show loading indicator on first load
        if notifications.isEmpty && pendingCoachInvitations.isEmpty {
            await MainActor.run {
                isLoading = true
                errorMessage = nil
            }
        }
        
        do {
            // Fetch both notifications and coach invitations in parallel
            async let notificationsTask = notificationService.fetchNotifications(userId: userId)
            async let invitationsTask = CoachService.shared.fetchPendingInvitations(for: userId)
            
            let (fetched, invitations) = try await (notificationsTask, invitationsTask)
            
            // Prefetch all avatar images for faster loading
            var avatarUrls = fetched.compactMap { $0.actorAvatarUrl }.filter { !$0.isEmpty }
            avatarUrls.append(contentsOf: invitations.compactMap { $0.coach?.avatarUrl }.filter { !$0.isEmpty })
            ImageCacheManager.shared.prefetch(urls: avatarUrls)
            
            await MainActor.run {
                notifications = fetched
                pendingCoachInvitations = invitations
                isLoading = false
                errorMessage = nil
            }
        } catch let error as NSError {
            // Ignore cancelled errors (happens during pull-to-refresh)
            if error.code == NSURLErrorCancelled {
                print("⚠️ Notification fetch cancelled (normal during refresh)")
                return
            }
            
            print("❌ Error loading notifications: \(error)")
            await MainActor.run {
                isLoading = false
                // Only show error if we don't have any notifications yet
                if notifications.isEmpty && pendingCoachInvitations.isEmpty {
                    errorMessage = error.localizedDescription
                }
            }
        } catch {
            print("❌ Error loading notifications: \(error)")
            await MainActor.run {
                isLoading = false
                if notifications.isEmpty && pendingCoachInvitations.isEmpty {
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    private func markAllAsReadOnEntry() async {
        guard !hasMarkedAsRead else { return }
        guard let userId = authViewModel.currentUser?.id else { return }
        
        hasMarkedAsRead = true
        
        do {
            try await notificationService.markAllAsRead(userId: userId)
            await MainActor.run {
                notifications = notifications.map { item in
                    var updated = item
                    updated.isRead = true
                    return updated
                }
            }
        } catch {
            print("⚠️ Could not mark notifications as read: \(error)")
        }
    }
    
    private func handleNotificationTap(_ notification: AppNotification) {
        Task {
            // For comment, reply, and like notifications, navigate to the post's comments
            switch notification.type {
            case .comment, .reply, .like:
                if let postId = notification.postId, !postId.isEmpty {
                    do {
                        // Fetch the post
                        let post = try await SocialService.shared.getPost(postId: postId)
                        await MainActor.run {
                            selectedPostForComments = post
                        }
                    } catch {
                        print("❌ Error fetching post for notification: \(error)")
                        // Fallback to profile navigation
                        await MainActor.run {
                            if !notification.actorId.isEmpty {
                                selectedProfileId = notification.actorId
                            }
                        }
                    }
                } else {
                    // No post ID, go to profile
                    await MainActor.run {
                        if !notification.actorId.isEmpty {
                            selectedProfileId = notification.actorId
                        }
                    }
                }
                
            case .follow:
                // For follow notifications, go to the user's profile
                await MainActor.run {
                    if !notification.actorId.isEmpty {
                        selectedProfileId = notification.actorId
                    }
                }
                
            case .coachInvitation:
                // Fetch the invitation and show acceptance view
                if let invitationId = notification.postId {
                    await handleCoachInvitation(invitationId: invitationId)
                }
                
            case .coachProgramAssigned:
                // Navigate to coach programs view
                await MainActor.run {
                    showCoachPrograms = true
                }
                
            default:
                // Default: go to profile
                await MainActor.run {
                    if !notification.actorId.isEmpty {
                        selectedProfileId = notification.actorId
                    }
                }
            }
        }
    }
    
    private func handleCoachInvitation(invitationId: String) async {
        guard let userId = authViewModel.currentUser?.id else { return }
        
        do {
            // Hämta pending invitations och hitta rätt
            let invitations = try await CoachService.shared.fetchPendingInvitations(for: userId)
            if let invitation = invitations.first(where: { $0.id == invitationId }) {
                await MainActor.run {
                    showCoachInvitation = invitation
                }
            }
        } catch {
            print("❌ Error fetching coach invitation: \(error)")
        }
    }
    
    private func handleAcceptInvitation(_ invitation: CoachInvitation) {
        Task {
            do {
                try await CoachService.shared.acceptCoachInvitation(invitationId: invitation.id)
                print("✅ Accepted invitation from \(invitation.coach?.displayName ?? "coach")")
                
                // Remove from list and refresh
                await MainActor.run {
                    pendingCoachInvitations.removeAll { $0.id == invitation.id }
                    
                    // Notify MainTabView to show Coach tab
                    NotificationCenter.default.post(name: NSNotification.Name("CoachStatusChanged"), object: nil)
                }
                
                // Refresh to get updated data
                await loadNotifications()
            } catch {
                print("❌ Failed to accept invitation: \(error)")
                await MainActor.run {
                    errorMessage = L.t(sv: "Kunde inte acceptera inbjudan: \(error.localizedDescription)", nb: "Kunne ikke godta invitasjon: \(error.localizedDescription)")
                }
                // Refresh to reset state
                await loadNotifications()
            }
        }
    }
    
    private func handleDeclineInvitation(_ invitation: CoachInvitation) {
        Task {
            do {
                try await CoachService.shared.declineCoachInvitation(invitationId: invitation.id)
                print("❌ Declined invitation from \(invitation.coach?.displayName ?? "coach")")
                
                // Remove from list
                await MainActor.run {
                    pendingCoachInvitations.removeAll { $0.id == invitation.id }
                }
                
                // Refresh to get updated data
                await loadNotifications()
            } catch {
                print("❌ Failed to decline invitation: \(error)")
                await MainActor.run {
                    errorMessage = L.t(sv: "Kunde inte avböja inbjudan: \(error.localizedDescription)", nb: "Kunne ikke avslå invitasjon: \(error.localizedDescription)")
                }
                // Refresh to reset state
                await loadNotifications()
            } catch {
                print("❌ Failed to decline invitation: \(error)")
            }
        }
    }
}

// MARK: - Coach Invitation Notification Row

struct CoachInvitationNotificationRow: View {
    let invitation: CoachInvitation
    let onAccept: () -> Void
    let onDecline: () -> Void
    
    @State private var isAccepting = false
    @State private var isDeclining = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                // Coach avatar
                if let avatarUrl = invitation.coach?.avatarUrl, !avatarUrl.isEmpty {
                    AsyncImage(url: URL(string: avatarUrl)) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Circle()
                            .fill(Color(.systemGray5))
                    }
                    .frame(width: 52, height: 52)
                    .clipShape(Circle())
                } else {
                    Circle()
                        .fill(Color(.systemGray5))
                        .frame(width: 52, height: 52)
                        .overlay(
                            Image(systemName: "person.fill")
                                .font(.system(size: 22))
                                .foregroundColor(.gray)
                        )
                }
                
                // Content
                VStack(alignment: .leading, spacing: 4) {
                    Text(L.t(sv: "Coach-inbjudan", nb: "Trener-invitasjon"))
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.primary)
                    
                    Text(L.t(sv: "\(invitation.coach?.displayName ?? "En tränare") vill coacha dig!", nb: "\(invitation.coach?.displayName ?? "En trener") vil coache deg!"))
                        .font(.system(size: 14))
                        .foregroundColor(.primary)
                    
                    Text(formatDate(invitation.createdAt))
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                        .padding(.top, 2)
                }
                
                Spacer()
            }
            
            // Accept/Decline buttons
            HStack(spacing: 12) {
                Button {
                    guard !isAccepting && !isDeclining else { return }
                    isAccepting = true
                    onAccept()
                } label: {
                    HStack {
                        if isAccepting {
                            ProgressView()
                                .scaleEffect(0.8)
                                .tint(.white)
                        } else {
                            Text(L.t(sv: "Godkänn", nb: "Godkjenn"))
                        }
                    }
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color.black)
                    .cornerRadius(8)
                }
                .disabled(isAccepting || isDeclining)
                
                Button {
                    guard !isAccepting && !isDeclining else { return }
                    isDeclining = true
                    onDecline()
                } label: {
                    HStack {
                        if isDeclining {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else {
                            Text(L.t(sv: "Avböj", nb: "Avslå"))
                        }
                    }
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.primary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                }
                .disabled(isAccepting || isDeclining)
            }
            .padding(.leading, 64) // Align with text content
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(Color(.systemGreen).opacity(0.08)) // Subtle green tint for coach invitations
    }
    
    private func formatDate(_ isoString: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        var date = formatter.date(from: isoString)
        if date == nil {
            formatter.formatOptions = [.withInternetDateTime]
            date = formatter.date(from: isoString)
        }
        
        guard let parsedDate = date else { return isoString }
        
        let now = Date()
        let diff = now.timeIntervalSince(parsedDate)
        
        let calendar = Calendar.current
        if calendar.isDateInToday(parsedDate) {
            let timeFormatter = DateFormatter()
            timeFormatter.dateFormat = "HH:mm"
            timeFormatter.locale = Locale(identifier: "sv_SE")
            return L.t(sv: "Idag kl \(timeFormatter.string(from: parsedDate))", nb: "I dag kl \(timeFormatter.string(from: parsedDate))")
        }
        
        if calendar.isDateInYesterday(parsedDate) {
            let timeFormatter = DateFormatter()
            timeFormatter.dateFormat = "HH:mm"
            timeFormatter.locale = Locale(identifier: "sv_SE")
            return L.t(sv: "Igår kl \(timeFormatter.string(from: parsedDate))", nb: "I går kl \(timeFormatter.string(from: parsedDate))")
        }
        
        if diff < 604800 {
            let days = Int(diff / 86400)
            return L.t(sv: "\(days) dagar sedan", nb: "\(days) dager siden")
        }
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "d MMM yyyy 'kl' HH:mm"
        dateFormatter.locale = Locale(identifier: "sv_SE")
        return dateFormatter.string(from: parsedDate)
    }
}

// MARK: - Strava-style Notification Row
struct NotificationRowStrava: View {
    let notification: AppNotification
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .top, spacing: 12) {
                // Profile picture (cached)
                ProfileImage(url: notification.actorAvatarUrl, size: 52)
                
                // Content
                VStack(alignment: .leading, spacing: 4) {
                    // Title (bold)
                    Text(notificationTitle)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    // Description
                    Text(notificationDescription)
                        .font(.system(size: 14))
                        .foregroundColor(.primary)
                        .lineLimit(2)
                    
                    // Timestamp
                    Text(formatDate(notification.createdAt))
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                        .padding(.top, 2)
                }
                
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(Color(.systemBackground))
        }
        .buttonStyle(.plain)
    }
    
    private var notificationTitle: String {
        switch notification.type {
        case .like:
            return L.t(sv: "Ny gilla-markering", nb: "Ny liker-markering")
        case .comment:
            return L.t(sv: "Ny kommentar", nb: "Ny kommentar")
        case .follow:
            return L.t(sv: "Ny följare", nb: "Ny følger")
        case .reply:
            return L.t(sv: "Svar på din kommentar", nb: "Svar på din kommentar")
        case .newWorkout:
            return L.t(sv: "Nytt träningspass", nb: "Ny treningsøkt")
        case .coachInvitation:
            return L.t(sv: "Coach-inbjudan", nb: "Trener-invitasjon")
        case .coachProgramAssigned:
            return L.t(sv: "Nytt träningsprogram", nb: "Nytt treningsprogram")
        case .trainerChatMessage:
            return L.t(sv: "Nytt meddelande", nb: "Ny melding")
        case .coachScheduleUpdated:
            return L.t(sv: "Schema uppdaterat", nb: "Timeplan oppdatert")
        case .unknown:
            return L.t(sv: "Notis", nb: "Varsel")
        }
    }
    
    private var notificationDescription: String {
        let name = notification.actorUsername ?? "Någon"
        
        switch notification.type {
        case .like:
            return L.t(sv: "\(name) gillade ditt inlägg", nb: "\(name) likte innlegget ditt")
        case .comment:
            if let text = notification.commentText, !text.isEmpty {
                return L.t(sv: "\(name) kommenterade: \"\(text)\"", nb: "\(name) kommenterte: \"\(text)\"")
            }
            return L.t(sv: "\(name) kommenterade på ditt inlägg", nb: "\(name) kommenterte på innlegget ditt")
        case .follow:
            return L.t(sv: "\(name) började följa dig", nb: "\(name) begynte å følge deg")
        case .reply:
            if let text = notification.commentText, !text.isEmpty {
                return L.t(sv: "\(name) svarade: \"\(text)\"", nb: "\(name) svarte: \"\(text)\"")
            }
            return L.t(sv: "\(name) svarade på din kommentar", nb: "\(name) svarte på kommentaren din")
        case .newWorkout:
            return L.t(sv: "\(name) har avslutat ett träningspass!", nb: "\(name) har fullført en treningsøkt!")
        case .coachInvitation:
            return L.t(sv: "\(name) vill coacha dig! Tryck för att svara.", nb: "\(name) vil coache deg! Trykk for å svare.")
        case .coachProgramAssigned:
            return L.t(sv: "\(name) har tilldelat dig ett nytt träningsprogram", nb: "\(name) har tildelt deg et nytt treningsprogram")
        case .trainerChatMessage:
            return L.t(sv: "\(name) skickade ett meddelande", nb: "\(name) sendte en melding")
        case .coachScheduleUpdated:
            return L.t(sv: "\(name) uppdaterade ditt träningsschema", nb: "\(name) oppdaterte treningsplanen din")
        case .unknown:
            return L.t(sv: "\(name) skickade en notis", nb: "\(name) sendte et varsel")
        }
    }
    
    private func formatDate(_ isoString: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        var date = formatter.date(from: isoString)
        if date == nil {
            formatter.formatOptions = [.withInternetDateTime]
            date = formatter.date(from: isoString)
        }
        
        guard let parsedDate = date else { return isoString }
        
        let now = Date()
        let diff = now.timeIntervalSince(parsedDate)
        
        // If today, show time
        let calendar = Calendar.current
        if calendar.isDateInToday(parsedDate) {
            let timeFormatter = DateFormatter()
            timeFormatter.dateFormat = "HH:mm"
            timeFormatter.locale = Locale(identifier: "sv_SE")
            return L.t(sv: "Idag kl \(timeFormatter.string(from: parsedDate))", nb: "I dag kl \(timeFormatter.string(from: parsedDate))")
        }
        
        // If yesterday
        if calendar.isDateInYesterday(parsedDate) {
            let timeFormatter = DateFormatter()
            timeFormatter.dateFormat = "HH:mm"
            timeFormatter.locale = Locale(identifier: "sv_SE")
            return L.t(sv: "Igår kl \(timeFormatter.string(from: parsedDate))", nb: "I går kl \(timeFormatter.string(from: parsedDate))")
        }
        
        // If within last 7 days
        if diff < 604800 {
            let days = Int(diff / 86400)
            return L.t(sv: "\(days) dagar sedan", nb: "\(days) dager siden")
        }
        
        // Otherwise show full date
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "d MMM yyyy 'kl' HH:mm"
        dateFormatter.locale = Locale(identifier: "sv_SE")
        return dateFormatter.string(from: parsedDate)
    }
}

// MARK: - Coach Programs List View (for navigation from notifications)

struct CoachProgramsListView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var assignments: [CoachProgramAssignment] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    
    var body: some View {
        ZStack {
            Color(UIColor.systemGroupedBackground)
                .ignoresSafeArea()
            
            if isLoading {
                ProgressView()
            } else if let error = errorMessage {
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.orange)
                    
                    Text(L.t(sv: "Kunde inte ladda program", nb: "Kunne ikke laste program"))
                        .font(.system(size: 16, weight: .medium))
                    
                    Text(error)
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                    
                    Button(L.t(sv: "Försök igen", nb: "Prøv igjen")) {
                        Task { await loadPrograms() }
                    }
                    .padding(.top, 8)
                }
            } else if assignments.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "dumbbell.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.gray)
                    
                    Text(L.t(sv: "Inga träningsprogram", nb: "Ingen treningsprogram"))
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.gray)
                    
                    Text(L.t(sv: "Du har inga tilldelade program från din tränare just nu", nb: "Du har ingen tildelte program fra treneren din akkurat nå"))
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
            } else {
                List {
                    ForEach(assignments) { assignment in
                        if let program = assignment.program {
                            Section {
                                VStack(alignment: .leading, spacing: 12) {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(program.title)
                                                .font(.system(size: 17, weight: .semibold))
                                            
                                            Text(L.t(sv: "Från \(assignment.coach?.username ?? "din tränare")", nb: "Fra \(assignment.coach?.username ?? "treneren din")"))
                                                .font(.system(size: 14))
                                                .foregroundColor(.secondary)
                                        }
                                        
                                        Spacer()
                                        
                                        if let avatarUrl = assignment.coach?.avatarUrl, !avatarUrl.isEmpty {
                                            AsyncImage(url: URL(string: avatarUrl)) { image in
                                                image
                                                    .resizable()
                                                    .aspectRatio(contentMode: .fill)
                                            } placeholder: {
                                                Circle()
                                                    .fill(Color(.systemGray5))
                                            }
                                            .frame(width: 40, height: 40)
                                            .clipShape(Circle())
                                        }
                                    }
                                    
                                    if let note = program.note, !note.isEmpty {
                                        Text(note)
                                            .font(.system(size: 14))
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    if let routines = program.programData.routines {
                                        Divider()
                                        
                                        ForEach(routines) { routine in
                                            HStack {
                                                Image(systemName: "dumbbell.fill")
                                                    .font(.system(size: 14))
                                                    .foregroundColor(.indigo)
                                                
                                                VStack(alignment: .leading, spacing: 2) {
                                                    Text(routine.name)
                                                        .font(.system(size: 15, weight: .medium))
                                                    
                                                    Text(L.t(sv: "\(routine.exercises.count) övningar", nb: "\(routine.exercises.count) øvelser"))
                                                        .font(.system(size: 13))
                                                        .foregroundColor(.secondary)
                                                }
                                                
                                                Spacer()
                                            }
                                            .padding(.vertical, 4)
                                        }
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .navigationTitle(L.t(sv: "Pass från tränare", nb: "Økter fra trener"))
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadPrograms()
        }
    }
    
    private func loadPrograms() async {
        guard let userId = authViewModel.currentUser?.id else { return }
        
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }
        
        do {
            let fetched = try await CoachService.shared.fetchAssignedPrograms(for: userId)
            
            await MainActor.run {
                assignments = fetched
                isLoading = false
            }
        } catch {
            print("❌ Failed to load coach programs: \(error)")
            await MainActor.run {
                errorMessage = error.localizedDescription
                isLoading = false
            }
        }
    }
}

#Preview {
    NavigationStack {
        NotificationsView()
            .environmentObject(AuthViewModel())
    }
}
