import SwiftUI
import Combine
import CoreLocation
import Supabase
import ConfettiSwiftUI

enum GymSessionInputField: Hashable {
    case kg(exerciseId: String, setIndex: Int)
    case reps(exerciseId: String, setIndex: Int)
}

struct GymSessionView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var authViewModel: AuthViewModel
    @Environment(\.scenePhase) private var scenePhase
    @State private var activeSession: SessionManager.ActiveSession? = SessionManager.shared.activeSession
    @StateObject private var viewModel = GymSessionViewModel()
    @StateObject private var celebrationManager = CelebrationManager.shared
    @State private var showCompleteSession = false
    @State private var showCancelConfirmation = false
    @State private var didLoadSavedWorkouts = false
    @State private var hasInitializedSession = false
    @State private var lastPersistedElapsedSeconds: Int = 0
    @FocusState private var focusedField: GymSessionInputField?
    @State private var showWorkoutLibrary = false
    @State private var didLoadExerciseHistory = false
    @State private var isReorderMode = false
    @State private var isResumingSession = false
    @State private var showNoExercisesAlert = false
    @State private var showMissingInfoAlert = false
    @State private var showFinishConfirmation = false
    @State private var navigateToExercisePicker = false
    // Cheer notification state
    @State private var showCheerNotification = false
    @State private var cheerEmoji: String = ""
    @State private var cheerFromUsername: String = ""
    
    // Coach workout - pre-load exercises from coach's routine
    var initialCoachWorkout: SavedGymWorkout?
    @State private var didLoadCoachWorkout = false
    
    private var durationVolumeHeader: some View {
        VStack(spacing: 12) {
            // Spectator indicator (only show when someone is watching)
            if viewModel.spectatorCount > 0 {
                HStack(spacing: 8) {
                    Image(systemName: "eye.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.green)
                    
                    Text(L.t(sv: "\(viewModel.spectatorCount) tittar på ditt pass", nb: "\(viewModel.spectatorCount) ser på økten din"))
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.green)
                    
                    Circle()
                        .fill(Color.green)
                        .frame(width: 8, height: 8)
                        .overlay(
                            Circle()
                                .stroke(Color.green.opacity(0.4), lineWidth: 3)
                                .scaleEffect(1.5)
                        )
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color.green.opacity(0.1))
                .cornerRadius(25)
                .transition(.scale.combined(with: .opacity))
            }
            
            // Stats row
            HStack(spacing: 0) {
                metricView(title: L.t(sv: "Tid", nb: "Tid"), value: viewModel.formattedDuration)
                    .frame(maxWidth: .infinity)
                Divider()
                    .frame(height: 40)
                metricView(title: L.t(sv: "Volym", nb: "Volum"), value: viewModel.formattedVolume)
                    .frame(maxWidth: .infinity)
                Divider()
                    .frame(height: 40)
                metricView(title: L.t(sv: "Sets", nb: "Sett"), value: "\(viewModel.completedSetsCount)")
                    .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 18)
            .background(Color(.systemGray6))
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
            )
        }
        .padding(.horizontal, 16)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: viewModel.spectatorCount)
    }
    
    private var emptyStateContent: some View {
        VStack(spacing: 24) {
            Image(systemName: "dumbbell.fill")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            Text(L.t(sv: "Lägg till övningar för att börja", nb: "Legg til øvelser for å begynne"))
                .font(.headline)
                .foregroundColor(.secondary)
            
            // Main action button
            Button(action: {
                let generator = UIImpactFeedbackGenerator(style: .medium)
                generator.impactOccurred()
                navigateToExercisePicker = true
            }) {
                HStack {
                    Image(systemName: "plus")
                        .font(.system(size: 16, weight: .semibold))
                    Text(L.t(sv: "Lägg till övning", nb: "Legg til øvelse"))
                        .font(.system(size: 16, weight: .semibold))
                }
                .foregroundColor(Color(.systemBackground))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color.primary)
                .cornerRadius(12)
            }
            .padding(.horizontal, 16)
        }
    }
    
    // Bottom buttons for empty state (Gym rutiner)
    private var emptyStateBottomButtons: some View {
        VStack(spacing: 12) {
            // Saved workouts button
            Button(action: {
                let generator = UIImpactFeedbackGenerator(style: .light)
                generator.impactOccurred()
                showWorkoutLibrary = true
            }) {
                HStack {
                    Image(systemName: "folder.fill")
                        .font(.system(size: 15, weight: .semibold))
                    Text(L.t(sv: "Gym rutiner", nb: "Treningsrutiner"))
                        .font(.system(size: 15, weight: .semibold))
                }
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color(.systemGray6))
                .cornerRadius(12)
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 20)
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 0) {
        ScrollView {
            VStack(spacing: 0) {
                durationVolumeHeader
                    .padding(.top, 16)
                
                Spacer()
                    .frame(height: 60)
                
                emptyStateContent
                
                // Bottom action button
                Button(action: {
                    showCancelConfirmation = true
                }) {
                    Text(L.t(sv: "Avbryt pass", nb: "Avbryt økt"))
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.red)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(10)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                        )
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                }
            }
            
            Spacer()
            
            // Bottom buttons (disappear when exercises are added)
            emptyStateBottomButtons
        }
    }
    
    @ViewBuilder
    private var exerciseListView: some View {
        if isReorderMode {
            VStack(spacing: 0) {
                durationVolumeHeader
                    .padding(.top, 16)
                
                List {
                    ForEach(viewModel.exercises) { exercise in
                        exerciseCardView(for: exercise)
                            .listRowInsets(EdgeInsets(top: 1.5, leading: 0, bottom: 1.5, trailing: 0))
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                    }
                    .onMove { source, destination in
                        viewModel.moveExercise(from: source, to: destination)
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .scrollDismissesKeyboard(.interactively)
                .environment(\.editMode, .constant(.active))
                
                Spacer()
                    .frame(height: 20)
            }
        } else {
            ScrollView {
                VStack(spacing: 4) {
                    durationVolumeHeader
                        .padding(.top, 16)
                    
                    ForEach(viewModel.exercises) { exercise in
                        exerciseCardView(for: exercise)
                            .transition(.asymmetric(
                                insertion: .scale(scale: 0.95).combined(with: .opacity),
                                removal: .scale(scale: 0.95).combined(with: .opacity)
                            ))
                    }
                    .animation(.spring(response: 0.35, dampingFraction: 0.8), value: viewModel.exercises.count)
                    
                    // Add Exercise Button
                    Button(action: {
                    let generator = UIImpactFeedbackGenerator(style: .medium)
                    generator.impactOccurred()
                    navigateToExercisePicker = true
                    }) {
                        HStack {
                            Image(systemName: "plus")
                                .font(.system(size: 16, weight: .semibold))
                            Text(L.t(sv: "Lägg till övning", nb: "Legg til øvelse"))
                                .font(.system(size: 16, weight: .semibold))
                        }
                        .foregroundColor(Color(.systemBackground))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.primary)
                        .cornerRadius(12)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    
                    // Bottom action button
                    Button(action: {
                        showCancelConfirmation = true
                    }) {
                        Text(L.t(sv: "Avbryt pass", nb: "Avbryt økt"))
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.red)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color(.secondarySystemBackground))
                            .cornerRadius(10)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                            )
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    
                    Spacer()
                        .frame(height: 40)
                }
            }
            .scrollDismissesKeyboard(.interactively)
        }
    }
    
    private func exerciseCardView(for exercise: GymExercise) -> some View {
        ExerciseCard(
            exercise: exercise,
            previousSets: viewModel.previousSets(for: exercise.name),
            isReorderMode: isReorderMode,
            onAddSet: {
                var transaction = Transaction()
                transaction.disablesAnimations = true
                withTransaction(transaction) {
                    viewModel.addSet(to: exercise.id)
                }
            },
            onUpdateSet: { setIndex, kg, reps in
                viewModel.updateSet(exerciseId: exercise.id, setIndex: setIndex, kg: kg, reps: reps)
            },
            onDeleteSet: { setIndex in
                viewModel.deleteSet(exerciseId: exercise.id, setIndex: setIndex)
            },
            onToggleSetCompletion: { setIndex in
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    viewModel.toggleSetCompletion(exerciseId: exercise.id, setIndex: setIndex)
                }
            },
            onDelete: {
                viewModel.removeExercise(exercise.id)
            },
            onUpdateNotes: { notes in
                viewModel.updateExerciseNotes(exerciseId: exercise.id, notes: notes)
            },
            onToggleReorder: {
                withAnimation {
                    isReorderMode.toggle()
                }
            },
            onToggleMode: {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                    viewModel.toggleExerciseMode(exerciseId: exercise.id)
                }
            },
            onUpdateCardioSeconds: { seconds in
                viewModel.updateCardioSeconds(exerciseId: exercise.id, seconds: seconds)
            },
            focusedField: $focusedField
        )
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemBackground)
                    .ignoresSafeArea()
                
                if viewModel.exercises.isEmpty {
                    emptyStateView
                } else {
                    exerciseListView
                }
                
                // Cheer notification overlay
                if showCheerNotification {
                    cheerNotificationOverlay
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .zIndex(100)
                }
            }
            .onTapGesture {
                // Dismiss keyboard when tapping on non-interactive areas
                dismissKeyboard()
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("NewWorkoutCheer"))) { notification in
                handleCheerNotification(notification)
            }
            .navigationTitle(L.t(sv: "Logga pass", nb: "Logg økt"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            // Minimize workout - keep it active but go back
                            persistSession(force: true)
                            dismiss()
                        } label: {
                            Image(systemName: "chevron.down")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.primary)
                        }
                    }
                    
                    ToolbarItem(placement: .topBarTrailing) {
                        if isReorderMode {
                            Button {
                                withAnimation {
                                    isReorderMode = false
                                }
                            } label: {
                                Text(L.t(sv: "Klar", nb: "Ferdig"))
                                    .font(.system(size: 16, weight: .semibold))
                            }
                        } else {
                            Button {
                                // Check if there are exercises with valid sets before showing confirmation
                                if viewModel.exercises.isEmpty {
                                    showNoExercisesAlert = true
                                } else {
                                    let hasValidData = viewModel.exercises.allSatisfy { exercise in
                                        if exercise.isCardio {
                                            return exercise.cardioSeconds > 0
                                        }
                                        return exercise.sets.contains { set in
                                            set.kg >= 0 && set.reps > 0
                                        }
                                    }
                                    if hasValidData {
                                        showFinishConfirmation = true
                                    } else {
                                        showMissingInfoAlert = true
                                    }
                                }
                            } label: {
                                Text(L.t(sv: "Avsluta", nb: "Avslutt"))
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.primary)
                            }
                        }
                    }
                }
            .sheet(isPresented: $showWorkoutLibrary) {
                SavedWorkoutsSheet(viewModel: viewModel, isPresented: $showWorkoutLibrary)
            }
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button {
                        focusedField = nil
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    } label: {
                        Text(L.t(sv: "Klar", nb: "Ferdig"))
                            .font(.system(size: 17, weight: .bold))
                            .foregroundColor(.blue)
                    }
                }
            }
            .alert(L.t(sv: "Vill du verkligen avsluta?", nb: "Vil du virkelig avslutte?"), isPresented: $showCancelConfirmation) {
                Button(L.t(sv: "Fortsätt", nb: "Fortsett"), role: .cancel) {
                    // Do nothing, just dismiss the alert
                }
                Button(L.t(sv: "Avsluta", nb: "Avslutt"), role: .destructive) {
                    viewModel.stopTimer()
                    finalizeSessionAndDismiss()
                }
            } message: {
                Text(L.t(sv: "Ditt pass kommer inte att sparas om du avbryter nu.", nb: "Økten din vil ikke bli lagret hvis du avbryter nå."))
            }
            .alert(L.t(sv: "Lägg till en övning", nb: "Legg til en øvelse"), isPresented: $showNoExercisesAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(L.t(sv: "Du behöver lägga till minst en övning innan du kan avsluta passet.", nb: "Du må legge til minst én øvelse før du kan avslutte økten."))
            }
            .alert(L.t(sv: "Din övning saknar info", nb: "Øvelsen mangler info"), isPresented: $showMissingInfoAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(L.t(sv: "Alla övningar behöver ha minst ett set med kg och reps ifyllt, eller en avslutad timer för konditionsövningar.", nb: "Alle øvelser må ha minst ett sett med kg og reps fylt inn, eller en fullført timer for kondisøvelser."))
            }
            .alert(L.t(sv: "Är du klar?", nb: "Er du ferdig?"), isPresented: $showFinishConfirmation) {
                Button(L.t(sv: "Nej", nb: "Nei"), role: .cancel) { }
                Button(L.t(sv: "Jag är klar", nb: "Jeg er ferdig")) {
                    saveWorkoutTapped()
                }
            }
            .navigationDestination(isPresented: $navigateToExercisePicker) {
                ExercisePickerView { exercise in
                    viewModel.addExercise(exercise)
                }
            }
            .onAppear {
                // Check if we're resuming an existing session
                if let activeSession = activeSession,
                   activeSession.activityType == ActivityType.walking.rawValue {
                    isResumingSession = true
                }
                
            }
            .fullScreenCover(isPresented: $showCompleteSession) {
                if let sessionData = viewModel.sessionData {
                    SessionCompleteView(
                        activity: .walking,
                        distance: 0,
                        duration: sessionData.duration,
                        earnedPoints: sessionData.earnedXP,
                        routeImage: nil,
                        routeCoordinates: [],
                        elevationGain: 0,
                        maxSpeed: 0,
                        completedSplits: [],
                        gymExercises: sessionData.exercises,
                        sessionLivePhoto: nil,
                        gymSessionStartTime: viewModel.sessionStartTime,
                        gymSessionLatitude: getGymLatitude(),
                        gymSessionLongitude: getGymLongitude(),
                        isPresented: $showCompleteSession,
                        onComplete: {
                            finalizeSessionAndDismiss()
                        },
                        onDelete: {
                            finalizeSessionAndDismiss()
                        }
                    )
                    .environmentObject(authViewModel)
                }
            }
            .onAppear {
                initializeSessionIfNeeded()
            }
            .onDisappear {
                if !showCompleteSession {
                    persistSession(force: true)
                }
                viewModel.stopTimer()
            }
            .onReceive(NotificationCenter.default.publisher(for: .savedGymWorkoutCreated)) { _ in
                guard let userId = authViewModel.currentUser?.id else { return }
                Task {
                    await viewModel.loadSavedWorkouts(userId: userId)
                }
            }
            .onReceive(viewModel.$exercises) { _ in
                persistSession(force: true)
            }
            .onReceive(viewModel.$elapsedSeconds) { newValue in
                if newValue - lastPersistedElapsedSeconds >= 15 {
                    persistSession()
                }
            }
            .onChange(of: scenePhase) { _, newPhase in
                switch newPhase {
                case .active:
                    // App returned to foreground - restart timer to ensure accurate time tracking
                    if viewModel.sessionStartTime != nil {
                        viewModel.startTimer(startTime: viewModel.sessionStartTime)
                    }
                case .inactive, .background:
                    persistSession(force: true)
                @unknown default:
                    break
                }
            }
            .onReceive(SessionManager.shared.$activeSession) { newValue in
                activeSession = newValue
            }
        }
        .confettiCannon(
            counter: $celebrationManager.confettiCounter,
            num: celebrationManager.confettiCount,
            colors: celebrationManager.confettiColors,
            confettiSize: celebrationManager.confettiSize,
            rainHeight: celebrationManager.rainHeight,
            radius: celebrationManager.radius,
            repetitions: celebrationManager.repetitions,
            repetitionInterval: celebrationManager.repetitionInterval
        )
    }
    
    private func saveWorkoutTapped() {
        focusedField = nil
        
        // Validation: Check if there are any exercises
        guard !viewModel.exercises.isEmpty else {
            showNoExercisesAlert = true
            return
        }
        
        let hasValidData = viewModel.exercises.allSatisfy { exercise in
            if exercise.isCardio {
                return exercise.cardioSeconds > 0
            }
            return exercise.sets.contains { set in
                set.kg >= 0 && set.reps > 0
            }
        }
        
        guard hasValidData else {
            showMissingInfoAlert = true
            return
        }
        
        let duration = viewModel.elapsedSeconds
        let isPro = RevenueCatManager.shared.isProMember
        viewModel.completeSession(duration: duration, isPro: isPro)
        
        SessionManager.shared.clearPersistedSession()
        
        // Update streak
        StreakManager.shared.registerActivityCompletion()
        
        // Trigga BIG konfetti celebration för avslutat pass!
        celebrationManager.celebrateSessionCompleted()
        
        // Go directly to session complete
        showCompleteSession = true
    }
    
    private func completeSession() {
        focusedField = nil
        let duration = viewModel.elapsedSeconds
        let isPro = RevenueCatManager.shared.isProMember
        viewModel.completeSession(duration: duration, isPro: isPro)
        
        SessionManager.shared.clearPersistedSession()
        
        // Update streak
        StreakManager.shared.registerActivityCompletion()
        
        // Go directly to session complete
        showCompleteSession = true
    }
    
    private func metricView(title: String, value: String) -> some View {
        VStack(spacing: 6) {
            Text(title.uppercased())
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.secondary)
            Text(value)
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(.primary)
        }
    }
    
    // MARK: - Cheer Notification Overlay
    
    private var cheerNotificationOverlay: some View {
        VStack {
            HStack(spacing: 12) {
                Text(cheerEmoji)
                    .font(.system(size: 40))
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(cheerFromUsername)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                    Text(L.t(sv: "hejar på dig!", nb: "heier på deg!"))
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.9))
                }
                
                Spacer()
            }
            .padding(16)
            .background(
                LinearGradient(
                    colors: [Color.orange, Color.red],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(16)
            .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 5)
            .padding(.horizontal, 16)
            .padding(.top, 60)
            
            Spacer()
        }
    }
    
    private func handleCheerNotification(_ notification: Notification) {
        guard let cheer = notification.userInfo?["cheer"] as? WorkoutCheer else { return }
        
        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
            cheerEmoji = cheer.emoji
            cheerFromUsername = cheer.fromUsername
            showCheerNotification = true
        }
        
        // Haptic feedback
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        
        // Hide after delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            withAnimation(.easeOut(duration: 0.3)) {
                showCheerNotification = false
            }
        }
    }
}

extension GymSessionView {
    private func dismissKeyboard() {
        focusedField = nil
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
    
    private func initializeSessionIfNeeded() {
        guard !hasInitializedSession else { return }
        hasInitializedSession = true
        
        // CRITICAL: Request location permissions EARLY for friend detection
        GymLocationManager.shared.requestPermissions()
        print("📍 Location permissions requested for gym session")

        if !didLoadSavedWorkouts, let userId = authViewModel.currentUser?.id {
            didLoadSavedWorkouts = true
            Task {
                await viewModel.loadSavedWorkouts(userId: userId)
            }
        }
        
        if !didLoadExerciseHistory, let userId = authViewModel.currentUser?.id {
            didLoadExerciseHistory = true
            Task {
                await viewModel.loadExerciseHistory(userId: userId)
            }
        }

        if let activeSession = activeSession,
           activeSession.activityType == ActivityType.walking.rawValue {
            let startTime = activeSession.startTime
            let exercises = activeSession.gymExercises ?? []
            SessionManager.shared.beginSession()
            viewModel.restoreSession(exercises: exercises, startTime: startTime)
            viewModel.startTimer(startTime: startTime)
            lastPersistedElapsedSeconds = viewModel.elapsedSeconds
            return
        }

        SessionManager.shared.beginSession()
        viewModel.resetSession()
        let now = Date()
        viewModel.startTimer(startTime: now)
        lastPersistedElapsedSeconds = 0
        persistSession(force: true)
        
        // Load coach workout if provided
        if let coachWorkout = initialCoachWorkout, !didLoadCoachWorkout {
            didLoadCoachWorkout = true
            print("🏋️ Loading coach workout: \(coachWorkout.name) with \(coachWorkout.exercises.count) exercises")
            viewModel.loadWorkout(coachWorkout)
        }
        
        // Track gym location for smart reminders
        GymLocationManager.shared.gymSessionStarted()
        
        // Start active session for friends map (notifies followers)
        if let userId = authViewModel.currentUser?.id {
            let userName = authViewModel.currentUser?.name
            print("🚀 Starting active session - userId: \(userId), userName: \(userName ?? "nil")")
            Task {
                do {
                    // CRITICAL: Get current location for friend detection
                    let currentLocation = GymLocationManager.shared.currentLocation
                    if currentLocation != nil {
                        print("📍 Starting session with location: \(currentLocation!.coordinate.latitude), \(currentLocation!.coordinate.longitude)")
                    } else {
                        print("⚠️ Starting session without location - friend detection may not work")
                    }
                    
                    let sessionId = try await ActiveSessionService.shared.startSession(
                        userId: userId,
                        activityType: "gym",
                        location: currentLocation,
                        userName: userName
                    )
                    print("✅ Active session started successfully!")
                    
                    // Start real-time syncing for spectators
                    if let sessionId = sessionId {
                        await MainActor.run {
                            viewModel.startRealtimeSync(sessionId: sessionId, userId: userId)
                        }
                        print("📡 Real-time sync started for session: \(sessionId)")
                    }
                    
                    // Notify followers
                    if let name = userName {
                        await ActiveSessionService.shared.notifyFollowers(userId: userId, userName: name, activityType: "gym")
                    }
                } catch {
                    print("❌ Failed to start active session: \(error)")
                }
            }
        } else {
            print("⚠️ Cannot start active session - no currentUser id")
        }
    }

    private func persistSession(force: Bool = false) {
        guard let startTime = viewModel.sessionStartTime else { return }
        let elapsed = viewModel.elapsedSeconds

        if !force && elapsed == lastPersistedElapsedSeconds {
            return
        }

        SessionManager.shared.saveActiveSession(
            activityType: ActivityType.walking.rawValue,
            startTime: startTime,
            isPaused: false,
            duration: elapsed,
            distance: 0,
            routeCoordinates: [],
            completedSplits: [],
            gymExercises: viewModel.exercises
        )

        lastPersistedElapsedSeconds = elapsed
    }

    // MARK: - Location Helpers for Trained-With Detection
    
    private func getGymLatitude() -> Double? {
        // CRITICAL: Prioritize current location over saved locations for accuracy
        if let currentLocation = GymLocationManager.shared.currentLocation {
            return currentLocation.coordinate.latitude
        }
        // Fallback to saved gym location
        if let savedGym = GymLocationManager.shared.savedGymLocations.first {
            return savedGym.latitude
        }
        return nil
    }
    
    private func getGymLongitude() -> Double? {
        // CRITICAL: Prioritize current location over saved locations for accuracy
        if let currentLocation = GymLocationManager.shared.currentLocation {
            return currentLocation.coordinate.longitude
        }
        // Fallback to saved gym location
        if let savedGym = GymLocationManager.shared.savedGymLocations.first {
            return savedGym.longitude
        }
        return nil
    }
    
    private func finalizeSessionAndDismiss() {
        focusedField = nil
        SessionManager.shared.finalizeSession()
        viewModel.resetSession()
        showCompleteSession = false
        
        // End gym location tracking
        GymLocationManager.shared.gymSessionEnded()
        
        // End active session for friends map
        if let userId = authViewModel.currentUser?.id {
            Task {
                try? await ActiveSessionService.shared.endSession(userId: userId)
            }
        }
        
        dismiss()
    }
}

private struct HoldToSaveButton: View {
    let title: String
    let duration: Double
    let onComplete: () -> Void
    
    @State private var progress: CGFloat = 0
    @State private var isHolding = false
    @State private var holdCompleted = false
    
    private let startFeedback = UIImpactFeedbackGenerator(style: .heavy)
    private let completionFeedback = UINotificationFeedbackGenerator()
    private let idleIndicatorFraction: CGFloat = 0.08
    
    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let minFillWidth = width * idleIndicatorFraction
            let fillWidth = max(width * progress, minFillWidth)
            
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color(.systemGray5))
                
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.primary)
                    .frame(width: min(fillWidth, width))
                
                Text(title.uppercased())
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(Color(.systemBackground))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(height: 54)
            .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .onLongPressGesture(
                minimumDuration: duration,
                maximumDistance: 50,
                pressing: { pressing in
                    if pressing {
                        startHold()
                    } else if !holdCompleted {
                        cancelHold(animated: true)
                    }
                },
                perform: {
                    finishHold()
                }
            )
        }
        .frame(height: 54)
    }
    
    private func startHold() {
        guard !isHolding else { return }
        isHolding = true
        holdCompleted = false
        startFeedback.prepare()
        completionFeedback.prepare()
        startFeedback.impactOccurred(intensity: 0.7)
        withAnimation(.linear(duration: duration)) {
            progress = 1
        }
    }
    
    private func cancelHold(animated: Bool) {
        guard isHolding else { return }
        isHolding = false
        holdCompleted = false
        let reset = {
            progress = 0
        }
        if animated {
            withAnimation(.easeOut(duration: 0.2)) {
                reset()
            }
        } else {
            reset()
        }
    }
    
    private func finishHold() {
        guard isHolding else { return }
        holdCompleted = true
        isHolding = false
        progress = 1
        completionFeedback.notificationOccurred(.success)
        onComplete()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            holdCompleted = false
            withAnimation(.easeOut(duration: 0.2)) {
                progress = 0
            }
        }
    }
}

// MARK: - Cardio Timer View
struct CardioTimerView: View {
    let exerciseId: String
    let accumulatedSeconds: Int
    let onUpdateSeconds: (Int) -> Void
    
    @State private var isRunning = false
    @State private var isFinished = false
    @State private var displaySeconds: Int
    @State private var timer: Timer?
    @State private var timerStartDate: Date?
    @State private var secondsBeforeCurrentRun: Int = 0
    @Environment(\.scenePhase) private var scenePhase
    
    init(exerciseId: String, accumulatedSeconds: Int, onUpdateSeconds: @escaping (Int) -> Void) {
        self.exerciseId = exerciseId
        self.accumulatedSeconds = accumulatedSeconds
        self.onUpdateSeconds = onUpdateSeconds
        self._displaySeconds = State(initialValue: accumulatedSeconds)
        self._isFinished = State(initialValue: accumulatedSeconds > 0)
    }
    
    private var timeString: String {
        let h = displaySeconds / 3600
        let m = (displaySeconds % 3600) / 60
        let s = displaySeconds % 60
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, s)
        }
        return String(format: "%02d:%02d", m, s)
    }
    
    var body: some View {
        VStack(spacing: 16) {
            Text(timeString)
                .font(.system(size: 48, weight: .bold, design: .monospaced))
                .foregroundColor(.primary)
                .padding(.top, 12)
            
            if isFinished && !isRunning {
                HStack(spacing: 12) {
                    Button {
                        isFinished = false
                        displaySeconds = 0
                        secondsBeforeCurrentRun = 0
                        timerStartDate = nil
                        onUpdateSeconds(0)
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.counterclockwise")
                            Text(L.t(sv: "Återställ", nb: "Tilbakestill"))
                        }
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.black)
                        .cornerRadius(12)
                    }
                }
            } else {
                HStack(spacing: 12) {
                    Button {
                        if isRunning {
                            pauseTimer()
                        } else {
                            startTimer()
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: isRunning ? "pause.fill" : "play.fill")
                            Text(isRunning ? L.t(sv: "Pausa", nb: "Pause") : (displaySeconds > 0 ? L.t(sv: "Fortsätt", nb: "Fortsett") : L.t(sv: "Starta", nb: "Start")))
                        }
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.black)
                        .cornerRadius(12)
                    }
                    
                    if displaySeconds > 0 {
                        Button {
                            stopTimer()
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "stop.fill")
                                Text(L.t(sv: "Avsluta", nb: "Avslutt"))
                            }
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.black)
                            .cornerRadius(12)
                        }
                    }
                }
            }
        }
        .padding(.bottom, 8)
        .onDisappear {
            timer?.invalidate()
            timer = nil
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active, isRunning, let start = timerStartDate {
                let elapsed = secondsBeforeCurrentRun + max(0, Int(Date().timeIntervalSince(start)))
                displaySeconds = elapsed
                onUpdateSeconds(displaySeconds)
            }
        }
    }
    
    private func startTimer() {
        isRunning = true
        isFinished = false
        secondsBeforeCurrentRun = displaySeconds
        timerStartDate = Date()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            guard let start = timerStartDate else { return }
            let elapsed = secondsBeforeCurrentRun + max(0, Int(Date().timeIntervalSince(start)))
            displaySeconds = elapsed
            onUpdateSeconds(displaySeconds)
        }
    }
    
    private func pauseTimer() {
        isRunning = false
        timer?.invalidate()
        timer = nil
        if let start = timerStartDate {
            displaySeconds = secondsBeforeCurrentRun + max(0, Int(Date().timeIntervalSince(start)))
        }
        timerStartDate = nil
    }
    
    private func stopTimer() {
        isRunning = false
        isFinished = true
        timer?.invalidate()
        timer = nil
        if let start = timerStartDate {
            displaySeconds = secondsBeforeCurrentRun + max(0, Int(Date().timeIntervalSince(start)))
        }
        timerStartDate = nil
        onUpdateSeconds(displaySeconds)
    }
}

// MARK: - Exercise Card
struct ExerciseCard: View {
    let exercise: GymExercise
    let previousSets: [PreviousExerciseSet]
    let isReorderMode: Bool
    let onAddSet: () -> Void
    let onUpdateSet: (Int, Double, Int) -> Void
    let onDeleteSet: (Int) -> Void
    let onToggleSetCompletion: (Int) -> Void
    let onDelete: () -> Void
    let onUpdateNotes: (String) -> Void
    let onToggleReorder: () -> Void
    let onToggleMode: () -> Void
    let onUpdateCardioSeconds: (Int) -> Void
    let focusedField: FocusState<GymSessionInputField?>.Binding
    
    @State private var showDeleteConfirmation = false
    @State private var notesText: String
    
    init(exercise: GymExercise, 
         previousSets: [PreviousExerciseSet],
         isReorderMode: Bool,
         onAddSet: @escaping () -> Void,
         onUpdateSet: @escaping (Int, Double, Int) -> Void,
         onDeleteSet: @escaping (Int) -> Void,
         onToggleSetCompletion: @escaping (Int) -> Void,
         onDelete: @escaping () -> Void,
         onUpdateNotes: @escaping (String) -> Void,
         onToggleReorder: @escaping () -> Void,
         onToggleMode: @escaping () -> Void,
         onUpdateCardioSeconds: @escaping (Int) -> Void,
         focusedField: FocusState<GymSessionInputField?>.Binding) {
        self.exercise = exercise
        self.previousSets = previousSets
        self.isReorderMode = isReorderMode
        self.onAddSet = onAddSet
        self.onUpdateSet = onUpdateSet
        self.onDeleteSet = onDeleteSet
        self.onToggleSetCompletion = onToggleSetCompletion
        self.onDelete = onDelete
        self.onUpdateNotes = onUpdateNotes
        self.onToggleReorder = onToggleReorder
        self.onToggleMode = onToggleMode
        self.onUpdateCardioSeconds = onUpdateCardioSeconds
        self.focusedField = focusedField
        self._notesText = State(initialValue: exercise.notes ?? "")
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Exercise header
            HStack(spacing: 12) {
                // Exercise GIF
                ExerciseGIFView(exerciseId: exercise.id, gifUrl: nil)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(exercise.name)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    if let category = exercise.category {
                        Text(category)
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                HStack(spacing: 12) {
                    if !isReorderMode {
                        Button(action: {
                            showDeleteConfirmation = true
                        }) {
                            Image(systemName: "trash")
                                .foregroundColor(.red)
                                .font(.system(size: 18))
                        }
                        
                        Button(action: {
                            onToggleReorder()
                        }) {
                            Image(systemName: "line.3.horizontal")
                                .foregroundColor(.gray)
                                .font(.system(size: 18))
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            
            // Notes TextField
            TextField(L.t(sv: "Skriv anteckningar här...", nb: "Skriv notater her..."), text: $notesText)
                .font(.system(size: 14))
                .foregroundColor(.secondary)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color(.systemGray6))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.gray.opacity(0.15), lineWidth: 1)
                )
                .padding(.horizontal, 16)
                .onChange(of: notesText) { _, newValue in
                    onUpdateNotes(newValue)
                }
            
            // Mode picker: Vikt / Kondition
            Picker(L.t(sv: "Typ", nb: "Type"), selection: Binding<Bool>(
                get: { exercise.isCardio },
                set: { _ in onToggleMode() }
            )) {
                Text(L.t(sv: "Vikt", nb: "Vekt")).tag(false)
                Text(L.t(sv: "Kondition", nb: "Kondisjon")).tag(true)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16)
            
            if exercise.isCardio {
                // Cardio timer mode
                CardioTimerView(
                    exerciseId: exercise.id,
                    accumulatedSeconds: exercise.cardioSeconds,
                    onUpdateSeconds: onUpdateCardioSeconds
                )
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
            } else {
                // Sets header
                HStack(spacing: 8) {
                    Text(L.t(sv: "SET", nb: "SETT"))
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.secondary)
                        .frame(width: 32, alignment: .center)
                    Text(L.t(sv: "FÖRRA", nb: "FORRIGE"))
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.secondary)
                        .frame(width: 55, alignment: .leading)
                    Text("KG")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.secondary)
                        .frame(width: 60, alignment: .center)
                    Text("REPS")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.secondary)
                        .frame(width: 60, alignment: .center)
                    Spacer()
                }
                .padding(.horizontal, 24)
                
                // Sets
                ForEach(Array(exercise.sets.enumerated()), id: \.offset) { index, set in
                    SetRow(
                        exerciseId: exercise.id,
                        setIndex: index,
                        setNumber: index + 1,
                        kg: set.kg,
                        reps: set.reps,
                        isCompleted: set.isCompleted,
                        focusedField: focusedField,
                        previousSet: previousSet(for: index),
                        onUpdate: { kg, reps in
                            onUpdateSet(index, kg, reps)
                        },
                        onToggleCompletion: {
                            onToggleSetCompletion(index)
                        },
                        onDelete: {
                            onDeleteSet(index)
                        }
                    )
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.95).combined(with: .opacity),
                        removal: .opacity
                    ))
                }
                .animation(.spring(response: 0.3, dampingFraction: 0.85), value: exercise.sets.count)
                
                // Add set button
                Button(action: onAddSet) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text(L.t(sv: "Lägg till set", nb: "Legg til sett"))
                    }
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.primary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
            }
        }
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
        )
        .padding(.horizontal, 16)
        .confirmationDialog(L.t(sv: "Ta bort övning?", nb: "Fjerne øvelse?"), isPresented: $showDeleteConfirmation) {
            Button(L.t(sv: "Ta bort", nb: "Fjern"), role: .destructive) {
                onDelete()
            }
            Button(L.t(sv: "Avbryt", nb: "Avbryt"), role: .cancel) {}
        }
    }
    
    private func previousSet(for index: Int) -> PreviousExerciseSet? {
        guard !previousSets.isEmpty else { return nil }
        if index < previousSets.count {
            return previousSets[index]
        }
        return previousSets.last
    }
}

// MARK: - Set Row
struct SetRow: View {
    let exerciseId: String
    let setIndex: Int
    let setNumber: Int
    @State var kg: Double
    @State var reps: Int
    let isCompleted: Bool
    let focusedField: FocusState<GymSessionInputField?>.Binding
    let previousSet: PreviousExerciseSet?
    let onUpdate: (Double, Int) -> Void
    let onToggleCompletion: () -> Void
    let onDelete: () -> Void
    
    @State private var kgText: String
    @State private var repsText: String
    
    init(exerciseId: String,
         setIndex: Int,
         setNumber: Int,
         kg: Double,
         reps: Int,
         isCompleted: Bool,
         focusedField: FocusState<GymSessionInputField?>.Binding,
         previousSet: PreviousExerciseSet?,
         onUpdate: @escaping (Double, Int) -> Void,
         onToggleCompletion: @escaping () -> Void,
         onDelete: @escaping () -> Void) {
        self.exerciseId = exerciseId
        self.setIndex = setIndex
        self.setNumber = setNumber
        self.kg = kg
        self.reps = reps
        self.isCompleted = isCompleted
        self.focusedField = focusedField
        self.previousSet = previousSet
        self.onUpdate = onUpdate
        self.onToggleCompletion = onToggleCompletion
        self.onDelete = onDelete
        _kgText = State(initialValue: kg > 0 ? String(format: "%.0f", kg) : "")
        _repsText = State(initialValue: reps > 0 ? "\(reps)" : "")
    }
    
    var body: some View {
        let inputBackground = isCompleted ? Color(.systemBackground).opacity(0.95) : Color(.systemGray6)
        let rowBackground = isCompleted ? Color(red: 210/255, green: 248/255, blue: 210/255) : Color(.secondarySystemBackground)
        let checkBackground = isCompleted ? Color(red: 47/255, green: 158/255, blue: 68/255) : Color(.systemGray5)
        
        HStack(spacing: 8) {
            // Set number
            Text("\(setNumber)")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.primary)
                .frame(width: 32, alignment: .center)
            
            VStack(alignment: .leading, spacing: 2) {
                if let previousSet {
                    Text(formattedWeight(previousSet.kg))
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.secondary)
                    Text("\(previousSet.reps) reps")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                } else {
                    Text("—")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
            }
            .frame(width: 55, alignment: .leading)
            
            // KG input
            TextField("0", text: $kgText)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.center)
                .font(.system(size: 16, weight: .medium))
                .frame(width: 60)
                .padding(.vertical, 8)
                .background(inputBackground)
                .cornerRadius(8)
                .focused(focusedField, equals: .kg(exerciseId: exerciseId, setIndex: setIndex))
                .onChange(of: kgText) { newValue in
                    if let value = Double(newValue) {
                        kg = value
                        onUpdate(kg, reps)
                    }
                }
            
            // Reps input
            TextField("0", text: $repsText)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.center)
                .font(.system(size: 16, weight: .medium))
                .frame(width: 60)
                .padding(.vertical, 8)
                .background(inputBackground)
                .cornerRadius(8)
                .focused(focusedField, equals: .reps(exerciseId: exerciseId, setIndex: setIndex))
                .onChange(of: repsText) { newValue in
                    if let value = Int(newValue) {
                        reps = value
                        onUpdate(kg, reps)
                    }
                }
            
            Spacer()
            
            Button(action: {
                onToggleCompletion()
            }) {
                Image(systemName: isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(isCompleted ? .white : Color(.systemGray3))
                    .frame(width: 32, height: 32)
                    .background(
                        Circle()
                            .fill(checkBackground)
                    )
            }
            .buttonStyle(.plain)
            
            Button(action: onDelete) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.red)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(rowBackground)
        )
        .padding(.horizontal, 12) // Margin from card edges
        .animation(.spring(response: 0.3, dampingFraction: 0.85), value: isCompleted)
    }
    
    private func formattedWeight(_ value: Double) -> String {
        if abs(value.rounded() - value) < 0.01 {
            return "\(Int(value.rounded())) kg"
        }
        return String(format: "%.1f kg", value)
    }
}

// MARK: - Exercise Picker
struct ExercisePickerView: View {
    @Environment(\.dismiss) var dismiss
    let onSelect: (ExerciseTemplate) -> Void
    
    @State private var searchText = ""
    @State private var exercises: [ExerciseDBExercise] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var selectedBodyPart: String = "all"
    @State private var bodyParts: [String] = []
    
    @State private var showEquipmentSheet = false
    @State private var selectedEquipment: String? = nil
    @State private var equipmentList: [String] = []
    @State private var targetList: [String] = []
    @State private var hasLoadedExercises = false
    @State private var recentlyUsedExercises: [ExerciseDBExercise] = []
    @State private var showOnlyFavorites = false
    @ObservedObject private var favoriteStore = FavoriteExerciseStore.shared
    
    // Multi-selection state
    @State private var selectedExercises: Set<String> = []
    @State private var selectedCategory: String? = nil
    
    // Quick filter state (Senast använda / Tidigare använt)
    @State private var quickFilter: QuickFilterType? = nil
    @State private var previouslyUsedExerciseIds: Set<String> = []
    @State private var isLoadingPreviouslyUsed = false
    
    enum QuickFilterType {
        case recentlyUsed   // Top 20 most recently used
        case previouslyUsed // All exercises ever used
    }
    
    // Dynamic popularity data from database
    @State private var popularityRanking: [String: Int] = [:] // exerciseId -> rank (lower = more popular)
    
    // Muscle categories for the slider menu
    private var muscleCategories: [(name: String, apiValue: String)] {
        [
            (L.t(sv: "Alla", nb: "Alle"), "all"),
            (L.t(sv: "Bröst", nb: "Bryst"), "chest"),
            (L.t(sv: "Ben", nb: "Ben"), "upper legs"),
            (L.t(sv: "Armar", nb: "Armer"), "upper arms"),
            (L.t(sv: "Rygg", nb: "Rygg"), "back"),
            (L.t(sv: "Axlar", nb: "Skuldre"), "shoulders"),
            (L.t(sv: "Mage", nb: "Mage"), "waist"),
            (L.t(sv: "Kondition", nb: "Kondisjon"), "cardio")
        ]
    }
    
    // Fallback popular exercises (used when no database data exists yet)
    private let fallbackPopularIds: Set<String> = [
        "0025", "0007", "0032", "0047", "0083", "0095", "0129", "0148",
        "0161", "0175", "0192", "0210", "0227", "0251", "0262", "0289"
    ]
    
    var filteredExercises: [ExerciseDBExercise] {
        var result = exercises
        
        // Apply quick filter if selected
        if let filter = quickFilter {
            switch filter {
            case .recentlyUsed:
                let recentIds = RecentExerciseStore.shared.loadAll()
                let topRecent = Array(recentIds.prefix(20))
                result = result.filter { topRecent.contains($0.id) }
                // Sort by recency order
                result.sort { a, b in
                    let aIndex = topRecent.firstIndex(of: a.id) ?? Int.max
                    let bIndex = topRecent.firstIndex(of: b.id) ?? Int.max
                    return aIndex < bIndex
                }
            case .previouslyUsed:
                result = result.filter { previouslyUsedExerciseIds.contains($0.id) }
            }
        }
        
        // Filter by favorites if enabled
        if showOnlyFavorites {
            result = result.filter { favoriteStore.isFavorite($0.id) }
        }
        
        // Filter by search text
        if !searchText.isEmpty {
            result = result.filter { $0.displayName.localizedCaseInsensitiveContains(searchText) }
        }
        
        // Sort by popularity if no quick filter (quick filter already sorted)
        if quickFilter == nil {
            return sortByPopularity(result)
        }
        
        return result
    }
    
    private func sortByPopularity(_ exercises: [ExerciseDBExercise]) -> [ExerciseDBExercise] {
        let recentIds = Set(RecentExerciseStore.shared.load())
        
        return exercises.sorted { a, b in
            let aRecent = recentIds.contains(a.id)
            let bRecent = recentIds.contains(b.id)
            
            // Recent exercises first (user's own history)
            if aRecent != bRecent { return aRecent }
            
            // Smart ranking (global popularity + trending combined)
            let aRank = popularityRanking[a.id] ?? Int.max
            let bRank = popularityRanking[b.id] ?? Int.max
            if aRank != bRank { return aRank < bRank }
            
            // Fallback to static popular list if no database data
            let aFallback = fallbackPopularIds.contains(a.id)
            let bFallback = fallbackPopularIds.contains(b.id)
            if aFallback != bFallback { return aFallback }
            
            // Then alphabetically
            return a.displayName < b.displayName
        }
    }
    
    private func isSelectedCategory(_ apiValue: String) -> Bool {
        if apiValue == "all" {
            return selectedCategory == nil
        }
        return selectedCategory == apiValue
    }
    
    private func selectedCategoryName() -> String {
        // Show quick filter name if active
        if let filter = quickFilter {
            switch filter {
            case .recentlyUsed:
                return L.t(sv: "Senast använda", nb: "Sist brukt")
            case .previouslyUsed:
                return L.t(sv: "Tidigare använt", nb: "Tidligere brukt")
            }
        }
        
        guard let selected = selectedCategory else { return L.t(sv: "Alla övningar", nb: "Alle øvelser") }
        return muscleCategories.first(where: { $0.apiValue == selected })?.name ?? L.t(sv: "Alla övningar", nb: "Alle øvelser")
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header: X | Lägg till övningar | Favorites
            HStack(spacing: 16) {
                        Button(action: {
                    dismiss()
                }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.black)
                }
                
                Text(L.t(sv: "Lägg till övningar", nb: "Legg til øvelser"))
                    .font(.system(size: 19, weight: .bold, design: .rounded))
                    .foregroundColor(.black)
                
                Spacer()
                
                    Button(action: {
                            showOnlyFavorites.toggle()
                }) {
                    Image(systemName: showOnlyFavorites ? "bookmark.fill" : "bookmark")
                        .font(.system(size: 18))
                        .foregroundColor(.black)
                    }
                }
                .padding(.horizontal, 16)
                        .padding(.vertical, 12)
            
            // Search bar
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 16))
                            .foregroundColor(.gray)
                
                TextField(L.t(sv: "Sök övning", nb: "Søk øvelse"), text: $searchText)
                    .font(.system(size: 16, weight: .regular, design: .rounded))
                
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color(.systemGray6))
            .cornerRadius(10)
            .padding(.horizontal, 16)
            .padding(.top, 4)
            
            // Muscle category slider menu
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(muscleCategories, id: \.apiValue) { category in
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                quickFilter = nil // Clear quick filter when selecting category
                                if category.apiValue == "all" {
                                    selectedCategory = nil
                                    Task {
                                        async let exercises = loadExercises()
                                        async let popularity = loadPopularityData(for: nil)
                                        _ = await exercises
                                        _ = await popularity
                                    }
                                } else {
                                    selectedCategory = category.apiValue
                                    Task {
                                        async let exercises = loadExercisesByTarget(category.apiValue)
                                        async let popularity = loadPopularityData(for: category.apiValue)
                                        _ = await exercises
                                        _ = await popularity
                                    }
                                }
                            }
                            let haptic = UIImpactFeedbackGenerator(style: .light)
                            haptic.impactOccurred()
                        }) {
                            Text(category.name)
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                                .foregroundColor(isSelectedCategory(category.apiValue) && quickFilter == nil ? .white : .black)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .background(isSelectedCategory(category.apiValue) && quickFilter == nil ? Color.black : Color(.systemGray6))
                                .cornerRadius(20)
                        }
                    }
                }
                                        .padding(.horizontal, 16)
                                }
            .padding(.top, 12)
            
            // Quick filter buttons (Senast använda / Tidigare använt)
            HStack(spacing: 12) {
                // Senast använda
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        if quickFilter == .recentlyUsed {
                            quickFilter = nil
                        } else {
                            quickFilter = .recentlyUsed
                            selectedCategory = nil
                        }
                    }
                    let haptic = UIImpactFeedbackGenerator(style: .light)
                    haptic.impactOccurred()
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.system(size: 13, weight: .medium))
                        Text(L.t(sv: "Senast använda", nb: "Sist brukt"))
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                    }
                    .foregroundColor(quickFilter == .recentlyUsed ? .white : .black)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(quickFilter == .recentlyUsed ? Color.black : Color(.systemGray6))
                    .cornerRadius(20)
                }
                
                // Tidigare använt
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        if quickFilter == .previouslyUsed {
                            quickFilter = nil
                        } else {
                            quickFilter = .previouslyUsed
                            selectedCategory = nil
                            // Load previously used exercises if not already loaded
                            if previouslyUsedExerciseIds.isEmpty {
                                Task {
                                    await loadPreviouslyUsedExercises()
                                }
                            }
                        }
                    }
                    let haptic = UIImpactFeedbackGenerator(style: .light)
                    haptic.impactOccurred()
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "list.bullet.clipboard")
                            .font(.system(size: 13, weight: .medium))
                        Text(L.t(sv: "Tidigare använt", nb: "Tidligere brukt"))
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                    }
                    .foregroundColor(quickFilter == .previouslyUsed ? .white : .black)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(quickFilter == .previouslyUsed ? Color.black : Color(.systemGray6))
                    .cornerRadius(20)
                }
                
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            
            if isLoading || isLoadingPreviouslyUsed {
                // Skeleton loading animation
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        // Section Header skeleton
                        HStack {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color(.systemGray5))
                                .frame(width: 120, height: 20)
                                .shimmer()
                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 20)
                        .padding(.bottom, 12)
                        
                        // Skeleton grid
                        LazyVGrid(columns: [
                            GridItem(.flexible(), spacing: 12),
                            GridItem(.flexible(), spacing: 12)
                        ], spacing: 16) {
                            ForEach(0..<6, id: \.self) { index in
                                ExerciseSkeletonCard()
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                }
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        // Section Header
                        HStack {
                            Text(selectedCategoryName())
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                                .foregroundColor(.black)
                            Spacer()
                            Image(systemName: "list.bullet")
                                .font(.system(size: 16))
                                .foregroundColor(.gray)
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 20)
                        .padding(.bottom, 12)
                        
                        // Empty state for quick filters
                        if filteredExercises.isEmpty && quickFilter != nil {
                            VStack(spacing: 16) {
                                Image(systemName: quickFilter == .recentlyUsed ? "clock.arrow.circlepath" : "list.bullet.clipboard")
                                    .font(.system(size: 40))
                                    .foregroundColor(.gray)
                                
                                Text(quickFilter == .recentlyUsed ?
                                     L.t(sv: "Inga senaste övningar", nb: "Ingen nylige øvelser") :
                                     L.t(sv: "Inga tidigare använda övningar", nb: "Ingen tidligere brukte øvelser"))
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.gray)
                                
                                Text(quickFilter == .recentlyUsed ?
                                     L.t(sv: "Börja logga övningar så visas de här", nb: "Begynn å logge øvelser så vises de her") :
                                     L.t(sv: "Övningar du loggar i dina pass visas här", nb: "Øvelser du logger i øktene dine vises her"))
                                    .font(.system(size: 14))
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.top, 60)
                            .padding(.horizontal, 32)
                        } else {
                            // 2-column Grid
                            LazyVGrid(columns: [
                                GridItem(.flexible(), spacing: 12),
                                GridItem(.flexible(), spacing: 12)
                            ], spacing: 16) {
                                ForEach(filteredExercises) { exercise in
                                    ExerciseGridCard(
                                        exercise: exercise,
                                        isFavorite: favoriteStore.isFavorite(exercise.id),
                                        isSelected: selectedExercises.contains(exercise.id),
                                        onSelect: {
                                            toggleExerciseSelection(exercise)
                                        },
                                        onToggleFavorite: {
                                            favoriteStore.toggle(exercise.id)
                                            let haptic = UIImpactFeedbackGenerator(style: .light)
                                            haptic.impactOccurred()
                                        }
                                    )
                                }
                            }
                            .padding(.horizontal, 16)
                        }
                        
                        Spacer(minLength: selectedExercises.isEmpty ? 20 : 120)
                    }
                }
            }
        }
        .background(Color(.systemBackground))
        .overlay(alignment: .bottom) {
            if !selectedExercises.isEmpty {
                Button(action: {
                    addSelectedExercises()
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 18, weight: .semibold))
                        Text(L.t(sv: "Lägg till \(selectedExercises.count) övning\(selectedExercises.count > 1 ? "ar" : "")", nb: "Legg til \(selectedExercises.count) øvelse\(selectedExercises.count > 1 ? "r" : "")"))
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.black)
                    .cornerRadius(14)
                    .shadow(color: Color.black.opacity(0.2), radius: 10, x: 0, y: 5)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 34)
                .background(
                    LinearGradient(
                        colors: [Color(.systemBackground).opacity(0), Color(.systemBackground)],
                        startPoint: .top,
                        endPoint: .center
                    )
                    .frame(height: 120)
                    .allowsHitTesting(false)
                )
            }
        }
        .navigationBarHidden(true)
        .task { await initializeData() }
            .sheet(isPresented: $showEquipmentSheet) {
            EquipmentFilterSheet(equipmentList: equipmentList, selectedEquipment: $selectedEquipment) { eq in
                Task { if let eq = eq { await loadExercisesByEquipment(eq) } else { await loadExercises() } }
            }
        }
    }
    
    private func toggleExerciseSelection(_ exercise: ExerciseDBExercise) {
        if selectedExercises.contains(exercise.id) {
            selectedExercises.remove(exercise.id)
        } else {
            selectedExercises.insert(exercise.id)
        }
        let haptic = UIImpactFeedbackGenerator(style: .medium)
        haptic.impactOccurred()
    }
    
    private func translateEquipment(_ equipment: String) -> String {
        switch equipment.lowercased() {
        case "barbell": return L.t(sv: "Skivstång", nb: "Vektstang")
        case "dumbbell": return L.t(sv: "Hantlar", nb: "Manualer")
        case "cable": return L.t(sv: "Kabel", nb: "Kabel")
        case "machine": return L.t(sv: "Maskin", nb: "Maskin")
        case "body weight": return L.t(sv: "Kroppsvikt", nb: "Kroppsvekt")
        case "kettlebell": return "Kettlebell"
        case "band": return L.t(sv: "Band", nb: "Bånd")
        case "ez barbell": return L.t(sv: "EZ-stång", nb: "EZ-stang")
        case "smith machine": return L.t(sv: "Smithmaskin", nb: "Smithmaskin")
        case "medicine ball": return L.t(sv: "Medicinboll", nb: "Medisinball")
        case "stability ball": return L.t(sv: "Balansboll", nb: "Balanseball")
        case "rope": return L.t(sv: "Rep", nb: "Tau")
        case "assisted": return L.t(sv: "Assisterad", nb: "Assistert")
        case "leverage machine": return L.t(sv: "Hävstångsmaskin", nb: "Spakmaskin")
        case "weighted": return L.t(sv: "Med vikt", nb: "Med vekt")
        case "bosu ball": return L.t(sv: "Bosuboll", nb: "Bosuball")
        case "resistance band": return L.t(sv: "Motståndsband", nb: "Motstandsbånd")
        case "olympic barbell": return L.t(sv: "Olympisk stång", nb: "Olympisk stang")
        case "trap bar": return L.t(sv: "Trapstång", nb: "Trapstang")
        default: return equipment.prefix(1).capitalized + equipment.dropFirst()
        }
    }
    
    private func addSelectedExercises() {
        // Find the full objects for selected IDs
        let selectedObjects = exercises.filter { selectedExercises.contains($0.id) }
        
        // Prepare for batch popularity tracking
        var exercisesToTrack: [(id: String, name: String, bodyPart: String)] = []
        
        for exercise in selectedObjects {
            let template = ExerciseTemplate(
                id: exercise.id,
                name: exercise.displayName,
                category: exercise.swedishBodyPart
            )
            RecentExerciseStore.shared.record(exerciseId: exercise.id)
            onSelect(template)
            
            // Add to tracking list
            exercisesToTrack.append((
                id: exercise.id,
                name: exercise.displayName,
                bodyPart: exercise.bodyPart
            ))
        }
        
        // Track exercise usage globally (async, don't wait)
        Task {
            await ExercisePopularityService.shared.recordExercisesBatch(exercisesToTrack)
        }
        
        dismiss()
    }
    
    private func translateBodyPart(_ part: String) -> String {
        switch part.lowercased() {
        case "chest": return L.t(sv: "Bröst", nb: "Bryst")
        case "back": return L.t(sv: "Rygg", nb: "Rygg")
        case "shoulders": return L.t(sv: "Axlar", nb: "Skuldre")
        case "upper arms": return L.t(sv: "Armar", nb: "Armer")
        case "upper legs": return L.t(sv: "Ben", nb: "Ben")
        case "waist": return L.t(sv: "Mage", nb: "Mage")
        default: return part.capitalized
        }
    }
    
    private func initializeData() async {
        await MainActor.run {
            isLoading = true
            errorMessage = nil
            hasLoadedExercises = false
        }
        async let bodyPartsTask = loadBodyParts()
        async let filterTask = loadFilterLists()
        async let popularityTask = loadPopularityData(for: nil)
        await loadExercises()
        _ = await bodyPartsTask
        _ = await filterTask
        _ = await popularityTask
    }
    
    private func loadPopularityData(for bodyPart: String?) async {
        let userId = AuthViewModel.shared.currentUser?.id
        let recentIds = RecentExerciseStore.shared.load()
        
        let ranking = await ExercisePopularityService.shared.getSmartRanking(
            bodyPart: bodyPart,
            userRecentIds: recentIds,
            userId: userId
        )
        await MainActor.run {
            popularityRanking = ranking
        }
    }
    
    private func loadBodyParts() async {
        do {
            let parts = try await ExerciseDBService.shared.fetchBodyPartList()
            await MainActor.run {
                bodyParts = parts
            }
        } catch {
            print("❌ Error loading body parts: \(error)")
        }
    }
    
    private func loadFilterLists() async {
        do {
            async let equipment = ExerciseDBService.shared.fetchEquipmentList()
            async let targets = ExerciseDBService.shared.fetchTargetList()
            let equipmentResult = try await equipment
            let targetResult = try await targets
            await MainActor.run {
                equipmentList = equipmentResult
                targetList = targetResult
            }
        } catch {
            print("❌ Error loading filter lists: \(error)")
        }
    }
    
    private func loadExercises() async {
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }
        do {
            let allExercises = try await ExerciseDBService.shared.fetchAllExercises()
            
            // Load recently used exercises
            await loadRecentlyUsedExercises(from: allExercises)
            
            await MainActor.run {
                exercises = allExercises
                isLoading = false
                hasLoadedExercises = true
            }
        } catch {
            await MainActor.run {
                isLoading = false
                errorMessage = error.localizedDescription
                hasLoadedExercises = true
            }
            print("❌ Error loading exercises: \(error)")
        }
    }
    
    private func loadRecentlyUsedExercises(from allExercises: [ExerciseDBExercise]) async {
        var ids = RecentExerciseStore.shared.load()
        
        if ids.isEmpty {
            let fetched = await fetchRecentExerciseIdsFromPosts(using: allExercises)
            if !fetched.isEmpty {
                ids = fetched
                RecentExerciseStore.shared.replace(with: ids)
            }
        }
        
        guard !ids.isEmpty else {
            await MainActor.run { recentlyUsedExercises = [] }
            return
        }
        
        let lookup = Dictionary(uniqueKeysWithValues: allExercises.map { ($0.id, $0) })
        let matched = ids.compactMap { lookup[$0] }
        
        await MainActor.run {
            recentlyUsedExercises = Array(matched.prefix(6))
        }
    }
    
    private func fetchRecentExerciseIdsFromPosts(using allExercises: [ExerciseDBExercise]) async -> [String] {
        guard let userId = AuthViewModel.shared.currentUser?.id else { return [] }
        do {
            let posts = try await WorkoutService.shared.getUserWorkoutPosts(userId: userId, forceRefresh: false)
            var orderedIds: [String] = []
            var pendingNames: [String] = []
            
            for post in posts where post.activityType.lowercased().contains("gym") {
                guard let exercises = post.exercises else { continue }
                for exercise in exercises {
                    if let id = exercise.id, !orderedIds.contains(id) {
                        orderedIds.append(id)
                    } else if exercise.id == nil {
                        pendingNames.append(exercise.name)
                    }
                }
                if orderedIds.count >= 12 { break }
            }
            
            if !pendingNames.isEmpty {
                let nameLookup = Dictionary(uniqueKeysWithValues: allExercises.map { ($0.displayName.normalizedKey, $0.id) })
                for name in pendingNames {
                    let key = name.normalizedKey
                    if let id = nameLookup[key], !orderedIds.contains(id) {
                        orderedIds.append(id)
                    }
                }
            }
            
            return orderedIds
        } catch {
            print("❌ Error loading recent exercise ids: \(error)")
            return []
        }
    }
    
    /// Load all exercises the user has ever used in any workout
    private func loadPreviouslyUsedExercises() async {
        await MainActor.run {
            isLoadingPreviouslyUsed = true
        }
        
        guard let userId = AuthViewModel.shared.currentUser?.id else {
            await MainActor.run {
                isLoadingPreviouslyUsed = false
            }
            return
        }
        
        do {
            // Fetch all user's gym workout posts
            let posts = try await WorkoutService.shared.getUserWorkoutPosts(userId: userId, forceRefresh: false)
            var allExerciseIds: Set<String> = []
            var pendingNames: Set<String> = []
            
            // Collect all exercise IDs from all gym posts
            for post in posts where post.activityType.lowercased().contains("gym") {
                guard let exercises = post.exercises else { continue }
                for exercise in exercises {
                    if let id = exercise.id {
                        allExerciseIds.insert(id)
                    } else {
                        // Exercise has no ID, try to match by name later
                        pendingNames.insert(exercise.name)
                    }
                }
            }
            
            // Try to match pending names to exercise IDs
            if !pendingNames.isEmpty {
                let allExercises = try await ExerciseDBService.shared.fetchAllExercises()
                let nameLookup = Dictionary(uniqueKeysWithValues: allExercises.map { ($0.displayName.normalizedKey, $0.id) })
                for name in pendingNames {
                    let key = name.normalizedKey
                    if let id = nameLookup[key] {
                        allExerciseIds.insert(id)
                    }
                }
            }
            
            await MainActor.run {
                previouslyUsedExerciseIds = allExerciseIds
                isLoadingPreviouslyUsed = false
            }
            
            print("✅ Loaded \(allExerciseIds.count) previously used exercises")
        } catch {
            print("❌ Error loading previously used exercises: \(error)")
            await MainActor.run {
                isLoadingPreviouslyUsed = false
            }
        }
    }
    
    private func loadExercisesByBodyPart(_ bodyPart: String) async {
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }
        do {
            let bodyPartExercises = try await ExerciseDBService.shared.fetchExercisesByBodyPart(bodyPart)
            await MainActor.run {
                exercises = bodyPartExercises
                isLoading = false
                hasLoadedExercises = true
            }
        } catch {
            await MainActor.run {
                isLoading = false
                errorMessage = error.localizedDescription
                hasLoadedExercises = true
            }
            print("❌ Error loading exercises for \(bodyPart): \(error)")
        }
    }
    
    private func loadExercisesByEquipment(_ equipment: String) async {
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }
        do {
            let equipmentExercises = try await ExerciseDBService.shared.fetchExercisesByEquipment(equipment)
            await MainActor.run {
                exercises = equipmentExercises
                isLoading = false
                hasLoadedExercises = true
            }
        } catch {
            await MainActor.run {
                isLoading = false
                errorMessage = error.localizedDescription
                hasLoadedExercises = true
            }
            print("❌ Error loading exercises for equipment \(equipment): \(error)")
        }
    }
    
    private func loadExercisesByTarget(_ bodyPart: String) async {
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }
        do {
            let bodyPartExercises = try await ExerciseDBService.shared.fetchExercisesByBodyPart(bodyPart)
            await MainActor.run {
                exercises = bodyPartExercises
                isLoading = false
                hasLoadedExercises = true
            }
        } catch {
            await MainActor.run {
                isLoading = false
                errorMessage = error.localizedDescription
                hasLoadedExercises = true
            }
            print("❌ Error loading exercises for bodyPart \(bodyPart): \(error)")
        }
    }
}

// MARK: - Exercise Skeleton Card
struct ExerciseSkeletonCard: View {
    @State private var isAnimating = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Image placeholder
            RoundedRectangle(cornerRadius: 0)
                .fill(Color(.systemGray5))
                .frame(height: 180)
                .shimmer()
            
            // Text content placeholder
            VStack(alignment: .leading, spacing: 8) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(.systemGray5))
                    .frame(height: 16)
                    .frame(maxWidth: .infinity)
                    .shimmer()
                
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(.systemGray6))
                    .frame(width: 80, height: 12)
                    .shimmer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 14)
        }
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.gray.opacity(0.1), lineWidth: 1)
        )
    }
}

// MARK: - Exercise Grid Card
struct ExerciseGridCard: View {
    let exercise: ExerciseDBExercise
    let isFavorite: Bool
    let isSelected: Bool
    let onSelect: () -> Void
    let onToggleFavorite: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 0) {
                // Image area with bookmark and info buttons
                ZStack(alignment: .topLeading) {
                    // Exercise image
                    ExerciseGIFView(exerciseId: exercise.id, gifUrl: exercise.gifUrl, width: nil, height: 180)
                        .frame(maxWidth: .infinity)
                        .background(Color.white)
                        .clipped()
                    
                    // Selected overlay
                    if isSelected {
                        Color.black.opacity(0.05)
                    }
                    
                    // Top overlay buttons
                    HStack {
                        // Bookmark button
                        Button(action: onToggleFavorite) {
                            ZStack {
                                Circle()
                                    .fill(Color.white.opacity(0.9))
                                    .frame(width: 32, height: 32)
                                Image(systemName: isFavorite ? "bookmark.fill" : "bookmark")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(isFavorite ? .black : .gray)
                            }
                        }
                        .padding(8)
                        
                        Spacer()
                        
                        // Checkmark when selected
                        if isSelected {
                            ZStack {
                                Circle()
                                    .fill(Color.black)
                                    .frame(width: 28, height: 28)
                                Image(systemName: "checkmark")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(.white)
                            }
                            .padding(8)
                        }
                    }
                }
                
                // Text content
                VStack(alignment: .leading, spacing: 4) {
                    Text(exercise.displayName)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    Text(exercise.swedishBodyPart)
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(isSelected ? Color.black.opacity(0.05) : Color(.systemGray6).opacity(0.3))
            }
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? Color.black : Color.gray.opacity(0.15), lineWidth: isSelected ? 2.5 : 1)
            )
            .shadow(color: isSelected ? Color.black.opacity(0.1) : Color.clear, radius: 8, x: 0, y: 4)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Exercise List Row
struct ExerciseListRow: View {
    let exercise: ExerciseDBExercise
    let isFavorite: Bool
    let isSelected: Bool
    let onSelect: () -> Void
    let onToggleFavorite: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 14) {
                // Exercise GIF
                ExerciseGIFView(exerciseId: exercise.id, gifUrl: exercise.gifUrl, width: 70, height: 70)
                    .frame(width: 70, height: 70)
                    .background(Color.white)
                    .cornerRadius(8)
                    .clipped()
                
                // Exercise info
                VStack(alignment: .leading, spacing: 4) {
                    Text(exercise.displayName)
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    Text(exercise.swedishBodyPart)
                        .font(.system(size: 14, weight: .regular, design: .rounded))
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                // Right side: Favorite toggle or checkmark
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.black)
                } else {
                    Button(action: {
                        onToggleFavorite()
                    }) {
                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundColor(.black)
                            .padding(8)
                            .background(
                                Circle()
                                    .stroke(Color.black, lineWidth: 1.5)
                            )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(isSelected ? Color(.systemGray5) : Color(.systemBackground))
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Saved Workouts Sheet
struct SavedWorkoutsSheet: View {
    @ObservedObject var viewModel: GymSessionViewModel
    @Binding var isPresented: Bool
    @ObservedObject private var pinnedStore = PinnedRoutineStore.shared
    
    private var sortedWorkouts: [SavedGymWorkout] {
        return viewModel.savedWorkouts.sorted {
            let p0 = pinnedStore.isPinned($0.id)
            let p1 = pinnedStore.isPinned($1.id)
            if p0 != p1 { return p0 }
            return $0.createdAt > $1.createdAt
        }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if viewModel.isLoadingSavedWorkouts {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if viewModel.savedWorkouts.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "folder")
                            .font(.system(size: 48))
                            .foregroundColor(.gray)
                        Text(L.t(sv: "Du har inga gym rutiner ännu", nb: "Du har ingen treningsrutiner ennå"))
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.gray)
                        Text(L.t(sv: "Spara ditt nästa pass som mall för att använda det igen", nb: "Lagre neste økt som mal for å bruke den igjen"))
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(sortedWorkouts) { workout in
                            HStack {
                                Button {
                                    viewModel.applySavedWorkout(workout)
                                    isPresented = false
                                } label: {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(workout.name)
                                                .font(.system(size: 16, weight: .semibold))
                                                .foregroundColor(.primary)
                                            
                                            Text(L.t(sv: "\(workout.exercises.count) övningar", nb: "\(workout.exercises.count) øvelser"))
                                                .font(.system(size: 14))
                                                .foregroundColor(.secondary)
                                        }
                                        
                                        Spacer()
                                    }
                                    .padding(.vertical, 4)
                                }
                                
                                Button {
                                    withAnimation(.smooth(duration: 0.3)) {
                                        pinnedStore.toggle(workout.id)
                                    }
                                } label: {
                                    Image(systemName: pinnedStore.isPinned(workout.id) ? "pin.fill" : "pin")
                                        .font(.system(size: 15))
                                        .foregroundColor(pinnedStore.isPinned(workout.id) ? .black : .gray)
                                        .padding(6)
                                }
                                .buttonStyle(.plain)
                                
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 14))
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle(L.t(sv: "Gym rutiner", nb: "Treningsrutiner"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(L.t(sv: "Klar", nb: "Ferdig")) {
                        isPresented = false
                    }
                    .font(.system(size: 16, weight: .semibold))
                }
            }
        }
    }
}

// MARK: - Equipment Filter Sheet
struct EquipmentFilterSheet: View {
    @Environment(\.dismiss) var dismiss
    let equipmentList: [String]
    @Binding var selectedEquipment: String?
    let onSelect: (String?) -> Void
    
    private func translateEquipment(_ equipment: String) -> String {
        switch equipment.lowercased() {
        case "barbell": return L.t(sv: "Skivstång", nb: "Vektstang")
        case "dumbbell": return L.t(sv: "Hantlar", nb: "Manualer")
        case "cable": return L.t(sv: "Kabel", nb: "Kabel")
        case "machine": return L.t(sv: "Maskin", nb: "Maskin")
        case "body weight": return L.t(sv: "Kroppsvikt", nb: "Kroppsvekt")
        case "kettlebell": return "Kettlebell"
        case "band": return L.t(sv: "Band", nb: "Bånd")
        case "ez barbell": return L.t(sv: "EZ-stång", nb: "EZ-stang")
        case "smith machine": return L.t(sv: "Smithmaskin", nb: "Smithmaskin")
        case "medicine ball": return L.t(sv: "Medicinboll", nb: "Medisinball")
        case "stability ball": return L.t(sv: "Balansboll", nb: "Balanseball")
        case "rope": return L.t(sv: "Rep", nb: "Tau")
        case "assisted": return L.t(sv: "Assisterad", nb: "Assistert")
        case "leverage machine": return L.t(sv: "Hävstångsmaskin", nb: "Spakmaskin")
        case "weighted": return L.t(sv: "Med vikt", nb: "Med vekt")
        case "bosu ball": return L.t(sv: "Bosuboll", nb: "Bosuball")
        case "resistance band": return L.t(sv: "Motståndsband", nb: "Motstandsbånd")
        case "olympic barbell": return L.t(sv: "Olympisk stång", nb: "Olympisk stang")
        case "trap bar": return L.t(sv: "Trapstång", nb: "Trapstang")
        default: return equipment.prefix(1).capitalized + equipment.dropFirst()
        }
    }
    
    var body: some View {
        NavigationStack {
            List {
                Button {
                    selectedEquipment = nil
                    onSelect(nil)
                    dismiss()
                } label: {
                    HStack {
                        Text(L.t(sv: "All utrustning", nb: "Alt utstyr"))
                            .font(.system(size: 16, weight: .regular, design: .rounded))
                            .foregroundColor(.primary)
                        Spacer()
                        if selectedEquipment == nil {
                            Image(systemName: "checkmark")
                                .foregroundColor(.black)
                        }
                    }
                }
                
                ForEach(equipmentList, id: \.self) { equipment in
                    Button {
                        selectedEquipment = equipment
                        onSelect(equipment)
                        dismiss()
                    } label: {
                        HStack {
                            Text(translateEquipment(equipment))
                                .font(.system(size: 16, weight: .regular, design: .rounded))
                                .foregroundColor(.primary)
                            Spacer()
                            if selectedEquipment == equipment {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.black)
                            }
                        }
                    }
                }
            }
            .navigationTitle(L.t(sv: "Välj utrustning", nb: "Velg utstyr"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(L.t(sv: "Stäng", nb: "Lukk")) {
                        dismiss()
                    }
                    .font(.system(size: 16, weight: .regular, design: .rounded))
                    .foregroundColor(.black)
                }
            }
        }
    }
}

// MARK: - Muscle Filter Sheet
struct MuscleFilterSheet: View {
    @Environment(\.dismiss) var dismiss
    let targetList: [String]
    @Binding var selectedTarget: String?
    let onSelect: (String?) -> Void
    
    private func translateMuscle(_ muscle: String) -> String {
        switch muscle.lowercased() {
        case "abductors": return L.t(sv: "Abduktorer", nb: "Abduktorer")
        case "abs": return L.t(sv: "Mage", nb: "Mage")
        case "adductors": return L.t(sv: "Adduktorer", nb: "Adduktorer")
        case "biceps": return "Biceps"
        case "calves": return L.t(sv: "Vader", nb: "Legger")
        case "cardiovascular system": return L.t(sv: "Kardio", nb: "Kardio")
        case "delts": return L.t(sv: "Axlar", nb: "Skuldre")
        case "forearms": return L.t(sv: "Underarmar", nb: "Underarmer")
        case "glutes": return L.t(sv: "Rumpa", nb: "Sete")
        case "hamstrings": return L.t(sv: "Baksida lår", nb: "Bakside lår")
        case "lats": return "Latissimus"
        case "levator scapulae": return L.t(sv: "Skulderbladshöjare", nb: "Skulderbladsløfter")
        case "pectorals": return L.t(sv: "Bröst", nb: "Bryst")
        case "quads": return L.t(sv: "Framsida lår", nb: "Framside lår")
        case "serratus anterior": return "Serratus"
        case "spine": return L.t(sv: "Rygg", nb: "Rygg")
        case "traps": return "Trapezius"
        case "triceps": return "Triceps"
        case "upper back": return L.t(sv: "Övre rygg", nb: "Øvre rygg")
        case "chest": return L.t(sv: "Bröst", nb: "Bryst")
        case "back": return L.t(sv: "Rygg", nb: "Rygg")
        case "shoulders": return L.t(sv: "Axlar", nb: "Skuldre")
        case "upper arms": return L.t(sv: "Armar", nb: "Armer")
        case "lower arms": return L.t(sv: "Underarmar", nb: "Underarmer")
        case "upper legs": return L.t(sv: "Övre ben", nb: "Øvre ben")
        case "lower legs": return L.t(sv: "Vader", nb: "Legger")
        case "waist": return L.t(sv: "Mage", nb: "Mage")
        case "cardio": return L.t(sv: "Kondition", nb: "Kondisjon")
        case "neck": return L.t(sv: "Nacke", nb: "Nakke")
        default: return muscle.prefix(1).capitalized + muscle.dropFirst()
        }
    }
    
    var body: some View {
        NavigationStack {
            List {
                Button {
                    selectedTarget = nil
                    onSelect(nil)
                    dismiss()
                } label: {
                    HStack {
                        Text(L.t(sv: "Alla muskler", nb: "Alle muskler"))
                            .font(.system(size: 16, weight: .regular, design: .rounded))
                            .foregroundColor(.primary)
                        Spacer()
                        if selectedTarget == nil {
                            Image(systemName: "checkmark")
                                .foregroundColor(.black)
                        }
                    }
                }
                
                ForEach(targetList, id: \.self) { target in
                    Button {
                        selectedTarget = target
                        onSelect(target)
                        dismiss()
                    } label: {
                        HStack {
                            Text(translateMuscle(target))
                                .font(.system(size: 16, weight: .regular, design: .rounded))
                                .foregroundColor(.primary)
                            Spacer()
                            if selectedTarget == target {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.black)
                            }
                        }
                    }
                }
            }
            .navigationTitle(L.t(sv: "Välj muskelgrupp", nb: "Velg muskelgruppe"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(L.t(sv: "Stäng", nb: "Lukk")) {
                        dismiss()
                    }
                    .font(.system(size: 16, weight: .regular, design: .rounded))
                    .foregroundColor(.black)
                }
            }
        }
    }
}

// MARK: - Exercise Icon View
struct ExerciseIconView: View {
    let bodyPart: String
    
    var iconName: String {
        switch bodyPart.lowercased() {
        case "chest", "pectorals":
            return "figure.strengthtraining.traditional"
        case "back":
            return "figure.climbing"
        case "shoulders":
            return "figure.arms.open"
        case "arms", "biceps", "triceps":
            return "figure.flexibility"
        case "legs", "quadriceps", "hamstrings", "calves":
            return "figure.run"
        case "abs", "waist", "core":
            return "figure.core.training"
        case "glutes":
            return "figure.stairs"
        case "cardio":
            return "figure.cooldown"
        default:
            return "figure.strengthtraining.traditional"
        }
    }
    
    var body: some View {
        Image(systemName: iconName)
            .font(.system(size: 28))
            .foregroundColor(.primary)
            .frame(width: 60, height: 60)
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Filter Button
struct FilterButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: .medium))
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(isSelected ? Color.primary : Color(.systemGray6))
                .foregroundColor(isSelected ? Color(.systemBackground) : .primary)
                .cornerRadius(20)
        }
    }
}

final class RecentExerciseStore {
    static let shared = RecentExerciseStore()
    private let defaults = UserDefaults.standard
    private let baseStorageKey = "recent_gym_exercises"
    private let maxItems = 50 // Store more items for "Senast använda" feature
    
    // Current user ID for personalized storage
    private var currentUserId: String?
    
    /// Set the current user ID - call this when user logs in
    func setUser(userId: String?) {
        currentUserId = userId
    }
    
    /// Get user-specific storage key
    private var storageKey: String {
        if let userId = currentUserId {
            return "\(baseStorageKey)_\(userId)"
        }
        return baseStorageKey
    }
    
    func record(exerciseId: String) {
        var ids = loadAll()
        ids.removeAll { $0 == exerciseId }
        ids.insert(exerciseId, at: 0)
        save(Array(ids.prefix(maxItems)))
    }
    
    /// Load first 12 items (for backward compatibility)
    func load() -> [String] {
        Array((defaults.stringArray(forKey: storageKey) ?? []).prefix(12))
    }
    
    /// Load all stored items (up to maxItems)
    func loadAll() -> [String] {
        defaults.stringArray(forKey: storageKey) ?? []
    }
    
    func replace(with ids: [String]) {
        save(Array(ids.prefix(maxItems)))
    }
    
    private func save(_ ids: [String]) {
        defaults.set(ids, forKey: storageKey)
    }
    
    /// Clear user data on logout
    func clearUser() {
        currentUserId = nil
    }
}

// MARK: - Favorite Exercise Store
final class FavoriteExerciseStore: ObservableObject {
    static let shared = FavoriteExerciseStore()
    private let defaults = UserDefaults.standard
    private let storageKey = "favorite_exercises"
    
    @Published var favoriteIds: Set<String> = []
    
    init() {
        loadFavorites()
    }
    
    func isFavorite(_ exerciseId: String) -> Bool {
        favoriteIds.contains(exerciseId)
    }
    
    func toggle(_ exerciseId: String) {
        if favoriteIds.contains(exerciseId) {
            favoriteIds.remove(exerciseId)
        } else {
            favoriteIds.insert(exerciseId)
        }
        saveFavorites()
    }
    
    func add(_ exerciseId: String) {
        favoriteIds.insert(exerciseId)
        saveFavorites()
    }
    
    func remove(_ exerciseId: String) {
        favoriteIds.remove(exerciseId)
        saveFavorites()
    }
    
    private func loadFavorites() {
        if let ids = defaults.stringArray(forKey: storageKey) {
            favoriteIds = Set(ids)
        }
    }
    
    private func saveFavorites() {
        defaults.set(Array(favoriteIds), forKey: storageKey)
    }
}

private extension String {
    var normalizedKey: String {
        lowercased().folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
    }
}

#Preview {
    GymSessionView()
        .environmentObject(AuthViewModel())
}


