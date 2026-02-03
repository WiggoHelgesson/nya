import SwiftUI

// MARK: - Shared Routines View
struct SharedRoutinesView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var authViewModel: AuthViewModel
    @StateObject private var revenueCatManager = RevenueCatManager.shared
    
    @State private var selectedTab: SharedRoutineTab = .myRoutines
    @State private var savedWorkouts: [SavedGymWorkout] = []
    @State private var receivedWorkouts: [SharedWorkout] = []
    @State private var isLoading = true
    @State private var showCreateRoutine = false
    @State private var selectedWorkoutToShare: SavedGymWorkout?
    @State private var selectedReceivedWorkout: SharedWorkout?
    @State private var unreadCount: Int = 0
    @State private var showPaywall = false
    
    enum SharedRoutineTab: String, CaseIterable {
        case myRoutines = "Mina rutiner"
        case sharedWithMe = "Delas med mig"
    }
    
    var body: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Tab selector
                tabSelector
                
                // Content
                if isLoading {
                    Spacer()
                    ProgressView()
                    Spacer()
                } else {
                    TabView(selection: $selectedTab) {
                        myRoutinesContent
                            .tag(SharedRoutineTab.myRoutines)
                        
                        sharedWithMeContent
                            .tag(SharedRoutineTab.sharedWithMe)
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                }
            }
        }
        .navigationTitle("Dela pass med vänner")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Stäng") {
                    dismiss()
                }
            }
            
            ToolbarItem(placement: .navigationBarTrailing) {
                if selectedTab == .myRoutines {
                    Button(action: { showCreateRoutine = true }) {
                        Image(systemName: "plus")
                            .font(.system(size: 16, weight: .semibold))
                    }
                }
            }
        }
        .sheet(isPresented: $showCreateRoutine) {
            NavigationStack {
                CreateRoutineView(onSave: { newWorkout in
                    savedWorkouts.insert(newWorkout, at: 0)
                })
                .environmentObject(authViewModel)
            }
        }
        .sheet(item: $selectedWorkoutToShare) { workout in
            NavigationStack {
                ShareWorkoutView(workout: workout)
                    .environmentObject(authViewModel)
            }
        }
        .sheet(item: $selectedReceivedWorkout) { sharedWorkout in
            NavigationStack {
                ReceivedWorkoutDetailView(
                    sharedWorkout: sharedWorkout,
                    onSaveAsRoutine: { savedWorkout in
                        // Optionally navigate to routines or show confirmation
                    },
                    onDismiss: {
                        // Mark as read and reload
                        Task {
                            try? await SharedWorkoutService.shared.markAsRead(workoutId: sharedWorkout.id)
                            await loadData()
                        }
                    }
                )
                .environmentObject(authViewModel)
            }
        }
        .task {
            await loadData()
        }
        .onChange(of: showPaywall) { _, newValue in
            if newValue {
                SuperwallService.shared.showPaywall()
                showPaywall = false
            }
        }
    }
    
    // MARK: - Tab Selector
    private var tabSelector: some View {
        HStack(spacing: 0) {
            ForEach(SharedRoutineTab.allCases, id: \.self) { tab in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedTab = tab
                    }
                } label: {
                    VStack(spacing: 8) {
                        HStack(spacing: 6) {
                            Text(tab.rawValue)
                                .font(.system(size: 15, weight: selectedTab == tab ? .bold : .medium))
                                .foregroundColor(selectedTab == tab ? .primary : .gray)
                            
                            // Show unread badge for "Delas med mig"
                            if tab == .sharedWithMe && unreadCount > 0 {
                                Text("\(unreadCount)")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.red)
                                    .clipShape(Capsule())
                            }
                        }
                        
                        Rectangle()
                            .fill(selectedTab == tab ? Color.primary : Color.clear)
                            .frame(height: 2)
                    }
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }
    
    // MARK: - My Routines Content
    private var myRoutinesContent: some View {
        ScrollView {
            if savedWorkouts.isEmpty {
                emptyMyRoutinesState
            } else {
                LazyVStack(spacing: 12) {
                    // Create new button
                    Button(action: { showCreateRoutine = true }) {
                        HStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(Color.black.opacity(0.1))
                                    .frame(width: 50, height: 50)
                                
                                Image(systemName: "plus")
                                    .font(.system(size: 20, weight: .semibold))
                                    .foregroundColor(.black)
                            }
                            
                            Text("Skapa ny rutin")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.primary)
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                        .padding(16)
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(16)
                    }
                    .buttonStyle(.plain)
                    
                    // Saved workouts
                    ForEach(savedWorkouts) { workout in
                        ShareableWorkoutCard(
                            workout: workout,
                            onShare: {
                                // Check if user is Pro
                                if revenueCatManager.isProMember {
                                    selectedWorkoutToShare = workout
                                } else {
                                    SuperwallService.shared.showPaywall()
                                }
                            }
                        )
                    }
                }
                .padding(16)
            }
        }
    }
    
    // MARK: - Shared With Me Content
    private var sharedWithMeContent: some View {
        ScrollView {
            if receivedWorkouts.isEmpty {
                emptySharedWithMeState
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(receivedWorkouts) { sharedWorkout in
                        ReceivedWorkoutCard(
                            sharedWorkout: sharedWorkout,
                            onTap: { selectedReceivedWorkout = sharedWorkout }
                        )
                    }
                }
                .padding(16)
            }
        }
    }
    
    // MARK: - Empty States
    private var emptyMyRoutinesState: some View {
        VStack(spacing: 24) {
            Image(systemName: "dumbbell.fill")
                .font(.system(size: 50))
                .foregroundColor(.gray.opacity(0.5))
            
            VStack(spacing: 8) {
                Text("Inga rutiner än")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.primary)
                
                Text("Skapa en rutin och dela den med dina vänner.")
                    .font(.system(size: 15))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            
            Button(action: { showCreateRoutine = true }) {
                HStack(spacing: 8) {
                    Image(systemName: "plus")
                        .font(.system(size: 16, weight: .semibold))
                    Text("Skapa ny rutin")
                        .font(.system(size: 16, weight: .semibold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 14)
                .background(Color.black)
                .cornerRadius(12)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, 80)
    }
    
    private var emptySharedWithMeState: some View {
        VStack(spacing: 24) {
            Image(systemName: "tray.fill")
                .font(.system(size: 50))
                .foregroundColor(.gray.opacity(0.5))
            
            VStack(spacing: 8) {
                Text("Inga delade pass")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.primary)
                
                Text("Här visas pass som dina vänner delat med dig.")
                    .font(.system(size: 15))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, 80)
    }
    
    // MARK: - Load Data
    private func loadData() async {
        guard let userId = authViewModel.currentUser?.id else {
            isLoading = false
            return
        }
        
        do {
            async let workoutsTask = SavedWorkoutService.shared.fetchSavedWorkouts(for: userId)
            async let receivedTask = SharedWorkoutService.shared.fetchReceivedWorkouts(for: userId)
            async let unreadTask = SharedWorkoutService.shared.getUnreadCount(for: userId)
            
            let (workouts, received, unread) = try await (workoutsTask, receivedTask, unreadTask)
            
            await MainActor.run {
                self.savedWorkouts = workouts.sorted { $0.createdAt > $1.createdAt }
                self.receivedWorkouts = received
                self.unreadCount = unread
                self.isLoading = false
            }
        } catch {
            print("Error loading shared routines: \(error)")
            await MainActor.run {
                self.isLoading = false
            }
        }
    }
}

// MARK: - Shareable Workout Card
struct ShareableWorkoutCard: View {
    let workout: SavedGymWorkout
    let onShare: () -> Void
    
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "sv_SE")
        formatter.dateFormat = "d MMM yyyy"
        return formatter
    }()
    
    var body: some View {
        HStack(spacing: 14) {
            // Logo icon
            Image("23")
                .resizable()
                .scaledToFit()
                .frame(width: 50, height: 50)
                .cornerRadius(12)
            
            // Info
            VStack(alignment: .leading, spacing: 4) {
                Text(workout.name)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
                Text("\(workout.exercises.count) övningar")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                
                Text(dateFormatter.string(from: workout.createdAt))
                    .font(.system(size: 12))
                    .foregroundColor(.secondary.opacity(0.7))
            }
            
            Spacer()
            
            // Share button
            Button(action: onShare) {
                HStack(spacing: 6) {
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 14))
                    Text("Dela")
                        .font(.system(size: 14, weight: .semibold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Color.black)
                .cornerRadius(8)
            }
        }
        .padding(16)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(16)
    }
}

// MARK: - Received Workout Card
struct ReceivedWorkoutCard: View {
    let sharedWorkout: SharedWorkout
    let onTap: () -> Void
    
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "sv_SE")
        formatter.dateFormat = "d MMM"
        return formatter
    }()
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                // Sender avatar
                ProfileImage(url: sharedWorkout.senderAvatarUrl, size: 50)
                    .overlay(
                        Circle()
                            .stroke(sharedWorkout.isRead ? Color.clear : Color.blue, lineWidth: 2)
                    )
                
                // Info
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(sharedWorkout.senderUsername ?? "Okänd")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.primary)
                        
                        if !sharedWorkout.isRead {
                            Circle()
                                .fill(Color.blue)
                                .frame(width: 8, height: 8)
                        }
                    }
                    
                    Text(sharedWorkout.workoutName)
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                    
                    Text("\(sharedWorkout.exercises.count) övningar • \(dateFormatter.string(from: sharedWorkout.createdAt))")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary.opacity(0.7))
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.secondary)
            }
            .padding(16)
            .background(sharedWorkout.isRead ? Color(.secondarySystemBackground) : Color.blue.opacity(0.08))
            .cornerRadius(16)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Share Workout View
struct ShareWorkoutView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var authViewModel: AuthViewModel
    let workout: SavedGymWorkout
    
    @State private var friends: [FriendForSharing] = []
    @State private var isLoading = true
    @State private var selectedFriend: FriendForSharing?
    @State private var message: String = ""
    @State private var isSending = false
    @State private var showSuccess = false
    @State private var searchText = ""
    
    private var filteredFriends: [FriendForSharing] {
        if searchText.isEmpty {
            return friends
        }
        return friends.filter { $0.username.lowercased().contains(searchText.lowercased()) }
    }
    
    var body: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()
            
            if showSuccess {
                successView
            } else {
                VStack(spacing: 0) {
                    // Workout preview
                    workoutPreview
                    
                    Divider()
                    
                    // Search bar
                    HStack(spacing: 10) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 16))
                            .foregroundColor(.gray)
                        
                        TextField("Sök vän...", text: $searchText)
                            .font(.system(size: 16))
                    }
                    .padding(12)
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(10)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    
                    // Friends list
                    if isLoading {
                        Spacer()
                        ProgressView()
                        Spacer()
                    } else if friends.isEmpty {
                        emptyFriendsState
                    } else {
                        friendsList
                    }
                    
                    // Message field (when friend selected)
                    if selectedFriend != nil {
                        messageField
                    }
                }
            }
        }
        .navigationTitle("Dela pass")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Avbryt") {
                    dismiss()
                }
            }
            
            ToolbarItem(placement: .navigationBarTrailing) {
                if selectedFriend != nil && !showSuccess {
                    Button("Skicka") {
                        sendWorkout()
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .disabled(isSending)
                }
            }
        }
        .task {
            await loadFriends()
        }
    }
    
    // MARK: - Workout Preview
    private var workoutPreview: some View {
        HStack(spacing: 12) {
            Image("23")
                .resizable()
                .scaledToFit()
                .frame(width: 44, height: 44)
                .cornerRadius(10)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(workout.name)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)
                
                Text("\(workout.exercises.count) övningar")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(16)
        .background(Color(.secondarySystemBackground))
    }
    
    // MARK: - Friends List
    private var friendsList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(filteredFriends) { friend in
                    Button(action: {
                        withAnimation {
                            if selectedFriend?.id == friend.id {
                                selectedFriend = nil
                            } else {
                                selectedFriend = friend
                            }
                        }
                    }) {
                        HStack(spacing: 12) {
                            ProfileImage(url: friend.avatarUrl, size: 44)
                            
                            Text(friend.username)
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.primary)
                            
                            Spacer()
                            
                            if selectedFriend?.id == friend.id {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 24))
                                    .foregroundColor(.black)
                            } else {
                                Circle()
                                    .stroke(Color.gray.opacity(0.3), lineWidth: 2)
                                    .frame(width: 24, height: 24)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(selectedFriend?.id == friend.id ? Color.black.opacity(0.05) : Color.clear)
                    }
                    .buttonStyle(.plain)
                    
                    Divider()
                        .padding(.leading, 72)
                }
            }
        }
    }
    
    // MARK: - Empty Friends State
    private var emptyFriendsState: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.2.slash")
                .font(.system(size: 50))
                .foregroundColor(.gray.opacity(0.5))
            
            Text("Inga vänner att dela med")
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(.primary)
            
            Text("Följ andra användare för att kunna dela pass med dem.")
                .font(.system(size: 14))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Message Field
    private var messageField: some View {
        VStack(spacing: 8) {
            Divider()
            
            HStack(spacing: 12) {
                if let friend = selectedFriend {
                    ProfileImage(url: friend.avatarUrl, size: 36)
                    
                    Text("Till: \(friend.username)")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            .padding(.horizontal, 16)
            
            TextField("Lägg till ett meddelande (valfritt)", text: $message)
                .font(.system(size: 15))
                .padding(12)
                .background(Color(.secondarySystemBackground))
                .cornerRadius(10)
                .padding(.horizontal, 16)
        }
        .padding(.bottom, 16)
        .background(Color(.systemBackground))
    }
    
    // MARK: - Success View
    private var successView: some View {
        VStack(spacing: 24) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 70))
                .foregroundColor(.green)
            
            VStack(spacing: 8) {
                Text("Passet har delats!")
                    .font(.system(size: 22, weight: .bold))
                
                if let friend = selectedFriend {
                    Text("\(workout.name) har skickats till \(friend.username)")
                        .font(.system(size: 15))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            
            Button(action: { dismiss() }) {
                Text("Klar")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.black)
                    .cornerRadius(12)
            }
            .padding(.horizontal, 40)
            .padding(.top, 16)
        }
    }
    
    // MARK: - Load Friends
    private func loadFriends() async {
        guard let userId = authViewModel.currentUser?.id else {
            isLoading = false
            return
        }
        
        do {
            let loadedFriends = try await SharedWorkoutService.shared.fetchFriendsForSharing(userId: userId)
            await MainActor.run {
                self.friends = loadedFriends
                self.isLoading = false
            }
        } catch {
            print("Error loading friends: \(error)")
            await MainActor.run {
                self.isLoading = false
            }
        }
    }
    
    // MARK: - Send Workout
    private func sendWorkout() {
        guard let userId = authViewModel.currentUser?.id,
              let friend = selectedFriend else { return }
        
        let senderName = authViewModel.currentUser?.name ?? "Någon"
        
        isSending = true
        
        Task {
            do {
                try await SharedWorkoutService.shared.shareWorkout(
                    senderId: userId,
                    senderName: senderName,
                    receiverId: friend.id,
                    workoutName: workout.name,
                    exercises: workout.exercises,
                    message: message.isEmpty ? nil : message
                )
                
                await MainActor.run {
                    withAnimation {
                        showSuccess = true
                    }
                }
                
                // Auto dismiss after 2 seconds
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                await MainActor.run {
                    dismiss()
                }
            } catch {
                print("Error sharing workout: \(error)")
                await MainActor.run {
                    isSending = false
                }
            }
        }
    }
}

// MARK: - Received Workout Detail View
struct ReceivedWorkoutDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var authViewModel: AuthViewModel
    let sharedWorkout: SharedWorkout
    let onSaveAsRoutine: (SavedGymWorkout) -> Void
    let onDismiss: () -> Void
    
    @State private var isSaving = false
    @State private var showSaveSuccess = false
    
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "sv_SE")
        formatter.dateFormat = "d MMMM yyyy 'kl.' HH:mm"
        return formatter
    }()
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Sender info
                HStack(spacing: 12) {
                    ProfileImage(url: sharedWorkout.senderAvatarUrl, size: 50)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(sharedWorkout.senderUsername ?? "Okänd")
                            .font(.system(size: 17, weight: .semibold))
                        
                        Text("Delade \(dateFormatter.string(from: sharedWorkout.createdAt))")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                }
                .padding(16)
                .background(Color(.secondarySystemBackground))
                .cornerRadius(16)
                
                // Message if present
                if let message = sharedWorkout.message, !message.isEmpty {
                    HStack {
                        Text("\"\(message)\"")
                            .font(.system(size: 15))
                            .italic()
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                    .padding(.horizontal, 4)
                }
                
                // Workout header
                VStack(spacing: 8) {
                    Image("23")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 60, height: 60)
                        .cornerRadius(14)
                    
                    Text(sharedWorkout.workoutName)
                        .font(.system(size: 22, weight: .bold))
                }
                
                // Stats
                HStack(spacing: 12) {
                    SharedWorkoutStatBox(value: "\(sharedWorkout.exercises.count)", label: "Övningar")
                    SharedWorkoutStatBox(value: "\(totalSets)", label: "Set")
                }
                
                // Exercises list
                VStack(alignment: .leading, spacing: 12) {
                    Text("Övningar")
                        .font(.system(size: 16, weight: .bold))
                        .padding(.horizontal, 4)
                    
                    VStack(spacing: 0) {
                        ForEach(Array(sharedWorkout.exercises.enumerated()), id: \.offset) { index, exercise in
                            VStack(spacing: 0) {
                                HStack(spacing: 12) {
                                    Text("\(index + 1)")
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundColor(.white)
                                        .frame(width: 28, height: 28)
                                        .background(Color.black)
                                        .cornerRadius(8)
                                    
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(exercise.name)
                                            .font(.system(size: 15, weight: .semibold))
                                        
                                        if let category = exercise.category {
                                            Text(category)
                                                .font(.system(size: 12))
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                    
                                    Spacer()
                                    
                                    Text("\(exercise.sets) set")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(.secondary)
                                }
                                .padding(14)
                                
                                if index < sharedWorkout.exercises.count - 1 {
                                    Divider()
                                        .padding(.leading, 54)
                                }
                            }
                        }
                    }
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(16)
                }
                
                // Save as routine button
                Button(action: saveAsRoutine) {
                    HStack(spacing: 8) {
                        if isSaving {
                            ProgressView()
                                .tint(.white)
                        } else if showSaveSuccess {
                            Image(systemName: "checkmark")
                                .font(.system(size: 16, weight: .semibold))
                            Text("Sparat!")
                        } else {
                            Image(systemName: "bookmark.fill")
                                .font(.system(size: 16, weight: .semibold))
                            Text("Spara som rutin")
                        }
                    }
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(showSaveSuccess ? Color.green : Color.black)
                    .cornerRadius(14)
                }
                .disabled(isSaving || showSaveSuccess)
                .padding(.top, 20)
            }
            .padding(16)
        }
        .navigationTitle("Delat pass")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Stäng") {
                    onDismiss()
                    dismiss()
                }
            }
        }
    }
    
    private var totalSets: Int {
        sharedWorkout.exercises.reduce(0) { $0 + $1.sets }
    }
    
    private func saveAsRoutine() {
        guard let userId = authViewModel.currentUser?.id else { return }
        isSaving = true
        
        Task {
            do {
                let saved = try await SavedWorkoutService.shared.saveWorkoutTemplate(
                    userId: userId,
                    name: sharedWorkout.workoutName,
                    exercises: sharedWorkout.exercises
                )
                
                await MainActor.run {
                    withAnimation {
                        showSaveSuccess = true
                    }
                    onSaveAsRoutine(saved)
                }
                
                // Keep success state for a moment
                try? await Task.sleep(nanoseconds: 1_500_000_000)
                
                await MainActor.run {
                    onDismiss()
                    dismiss()
                }
            } catch {
                print("Error saving routine: \(error)")
                await MainActor.run {
                    isSaving = false
                }
            }
        }
    }
}

// MARK: - Stat Box
private struct SharedWorkoutStatBox: View {
    let value: String
    let label: String
    
    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 22, weight: .bold))
            
            Text(label)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
}

#Preview {
    NavigationStack {
        SharedRoutinesView()
            .environmentObject(AuthViewModel())
    }
}
