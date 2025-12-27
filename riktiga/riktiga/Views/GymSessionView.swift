import SwiftUI

enum GymSessionInputField: Hashable {
    case kg(exerciseId: String, setIndex: Int)
    case reps(exerciseId: String, setIndex: Int)
}

struct GymSessionView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var authViewModel: AuthViewModel
    @Environment(\.scenePhase) private var scenePhase
    @State private var activeSession: SessionManager.ActiveSession? = SessionManager.shared.activeSession
    @State private var isPremium = RevenueCatManager.shared.isProMember
    @StateObject private var viewModel = GymSessionViewModel()
    @State private var showExercisePicker = false
    @State private var showCompleteSession = false
    @State private var showCancelConfirmation = false
    @State private var didLoadSavedWorkouts = false
    @State private var hasInitializedSession = false
    @State private var lastPersistedElapsedSeconds: Int = 0
    @FocusState private var focusedField: GymSessionInputField?
    @State private var showWorkoutGenerator = false
    @State private var generatorPrompt: String = ""
    @State private var generatorWordCount: Int = 0
    @State private var generatorError: String?
    @State private var isGeneratingWorkout = false
    @State private var showSubscriptionView = false
    @State private var generatorResultMessage: String?
    @State private var showGeneratorResultAlert = false
    @State private var didLoadExerciseHistory = false
    
    private let generatorWordLimit = 100
    
    
    private var uppyGeneratorButton: some View {
        HStack(alignment: .center, spacing: 12) {
            Button(action: handleGeneratorButtonTap) {
                HStack(spacing: 8) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 16, weight: .semibold))
                    Text("Skapa ett pass med UPPY")
                        .font(.system(size: 15, weight: .semibold))
                }
                .foregroundColor(Color(.systemBackground))
                .padding(.vertical, 14)
                .frame(maxWidth: .infinity)
                .background(Color.primary)
                .cornerRadius(14)
            }
            
            Text("Beta version")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 16)
    }
    
    private var workoutGeneratorSheet: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text("Beskriv passet du vill skapa (max 100 ord).")
                    .font(.system(size: 14))
                    .foregroundColor(.gray)
                
                ZStack(alignment: .topLeading) {
                    if generatorPrompt.isEmpty {
                        Text("Exempel: \"Vill ha ett 45 min benpass med fokus på explosivitet och maskiner.\"")
                            .font(.system(size: 14))
                            .foregroundColor(.gray.opacity(0.8))
                            .padding(.horizontal, 20)
                            .padding(.vertical, 16)
                    }
                    
                    TextEditor(text: $generatorPrompt)
                        .frame(minHeight: 180)
                        .padding(12)
                        .background(Color(.systemGray6))
                        .cornerRadius(16)
                        .onChange(of: generatorPrompt) { newValue in
                            updateGeneratorWordCount(for: newValue)
                        }
                }
                
                HStack {
                    Text("\(generatorWordCount)/\(generatorWordLimit) ord")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(generatorWordCount > generatorWordLimit ? .red : .gray)
                    Spacer()
                    if isGeneratingWorkout {
                        ProgressView()
                    }
                }
                
                if let generatorError {
                    Text(generatorError)
                        .font(.system(size: 13))
                        .foregroundColor(.red)
                }
                
                Button(action: generateWorkoutFromPrompt) {
                    HStack {
                        Image(systemName: "wand.and.stars")
                        Text(isGeneratingWorkout ? "Skapar pass..." : "Generera pass")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(generatorWordCount == 0 || isGeneratingWorkout ? Color.secondary.opacity(0.3) : Color.primary)
                    .foregroundColor(generatorWordCount == 0 || isGeneratingWorkout ? .secondary : Color(.systemBackground))
                    .cornerRadius(16)
                }
                .disabled(generatorWordCount == 0 || isGeneratingWorkout)
                
                Spacer()
            }
            .padding()
            .navigationTitle("Skapa med UPPY")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Stäng") {
                        showWorkoutGenerator = false
                    }
                }
            }
        }
    }

    private func handleGeneratorButtonTap() {
        guard isPremium else {
            showSubscriptionView = true
            return
        }
        generatorError = nil
        showWorkoutGenerator = true
    }
    
    private func updateGeneratorWordCount(for text: String) {
        let components = text
            .split { $0.isWhitespace || $0.isNewline }
        if components.count <= generatorWordLimit {
            generatorWordCount = components.count
            return
        }
        let trimmed = components.prefix(generatorWordLimit).joined(separator: " ")
        generatorPrompt = trimmed
        generatorWordCount = generatorWordLimit
    }
    
    private func generateWorkoutFromPrompt() {
        let trimmed = generatorPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            generatorError = "Beskriv passet du vill skapa."
            return
        }
        guard !isGeneratingWorkout else { return }
        
        isGeneratingWorkout = true
        generatorError = nil
        
        Task {
            do {
                let result = try await WorkoutGeneratorService.shared.generateWorkout(prompt: trimmed)
                guard !result.entries.isEmpty else {
                    await MainActor.run {
                        generatorError = "UPPY hittade inga övningar, försök specificera passet mer."
                    }
                    return
                }
                await MainActor.run {
                    viewModel.appendGeneratedExercises(result.entries)
                    generatorPrompt = ""
                    generatorWordCount = 0
                    showWorkoutGenerator = false
                    generatorResultMessage = generatorResultText(for: result)
                    showGeneratorResultAlert = true
                }
            } catch {
                await MainActor.run {
                    generatorError = error.localizedDescription
                }
            }
            await MainActor.run {
                isGeneratingWorkout = false
            }
        }
    }
    
    private func generatorResultText(for result: GeneratedWorkoutResult) -> String {
        var summary = "UPPY lade till \(result.entries.count) övningar."
        if !result.missingExercises.isEmpty {
            let missing = result.missingExercises.joined(separator: ", ")
            summary += "\nKunde inte hitta: \(missing)."
        }
        return summary
    }
    
    @ViewBuilder
    private var savedWorkoutsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Sparade pass")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.primary)
                .padding(.horizontal, 16)
            
            if viewModel.isLoadingSavedWorkouts {
                ProgressView()
                    .padding(.horizontal, 16)
                    .padding(.top, 4)
            } else if viewModel.savedWorkouts.isEmpty {
                Text("Du har inga sparade pass ännu.")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 16)
            } else {
                ForEach(viewModel.savedWorkouts) { workout in
                    Button {
                        viewModel.applySavedWorkout(workout)
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(workout.name)
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.primary)
                                Text("\(workout.exercises.count) övningar")
                                    .font(.system(size: 13))
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Image(systemName: "arrow.down.circle.fill")
                                .foregroundColor(.primary)
                                .font(.system(size: 18))
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(12)
                    }
                    .padding(.horizontal, 16)
                }
            }
            
            uppyGeneratorButton
        }
        .padding(.top, 8)
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemBackground)
                    .ignoresSafeArea()
                
                if viewModel.exercises.isEmpty {
                    // Empty state with centered main content
                    ScrollView {
                        VStack(spacing: 0) {
                            // Spacer to push content to center
                            Spacer()
                                .frame(height: 120)
                            
                            // Centered empty state
                            VStack(spacing: 24) {
                                Image(systemName: "dumbbell.fill")
                                    .font(.system(size: 60))
                                    .foregroundColor(.secondary)
                                
                                Text("Lägg till övningar för att börja")
                                    .font(.headline)
                                    .foregroundColor(.secondary)
                                
                                Button(action: {
                                    showExercisePicker = true
                                }) {
                                    HStack {
                                        Image(systemName: "plus.circle.fill")
                                        Text("Lägg till övning")
                                    }
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.primary)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 16)
                                    .background(Color(.secondarySystemBackground))
                                    .cornerRadius(12)
                                }
                                .padding(.horizontal, 16)
                            }
                            
                            // Duration & Volume header - always visible
                            HStack(spacing: 0) {
                                metricView(title: "Tid", value: viewModel.formattedDuration)
                                    .frame(maxWidth: .infinity)
                                Divider()
                                    .frame(height: 40)
                                metricView(title: "Volym", value: viewModel.formattedVolume)
                                    .frame(maxWidth: .infinity)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 18)
                            .background(Color(.systemGray6))
                            .cornerRadius(16)
                            .padding(.top, 16)
                            .padding(.horizontal, 16)
                            
                            // Spacer before scrollable sections
                            Spacer()
                                .frame(height: 40)
                            
                            // Scrollable sections below
                            VStack(spacing: 24) {
                                savedWorkoutsSection
                            }
                            .padding(.bottom, 100)
                        }
                    }
                } else {
                    // Exercise list
                    ScrollView {
                        VStack(spacing: 16) {
                            // Duration & Volume header
                            HStack(spacing: 0) {
                                metricView(title: "Tid", value: viewModel.formattedDuration)
                                    .frame(maxWidth: .infinity)
                                Divider()
                                    .frame(height: 40)
                                metricView(title: "Volym", value: viewModel.formattedVolume)
                                    .frame(maxWidth: .infinity)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 18)
                            .background(Color(.systemGray6))
                            .cornerRadius(16)
                            .padding(.top, 16)
                            .padding(.horizontal, 16)
                            
                            // Exercises
                            ForEach(viewModel.exercises) { exercise in
                                ExerciseCard(
                                    exercise: exercise,
                                    previousSets: viewModel.previousSets(for: exercise.name),
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
                                    focusedField: $focusedField
                                )
                            }
                            
                            // Add exercise button
                            Button(action: {
                                showExercisePicker = true
                            }) {
                                HStack {
                                    Image(systemName: "plus.circle.fill")
                                    Text("Lägg till övning")
                                }
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.primary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(Color(.secondarySystemBackground))
                                .cornerRadius(12)
                            }
                            .padding(.horizontal, 16)
                        }
                        .padding(.bottom, 100)
                    }
                }
            }
            .navigationTitle("Gympass")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        showCancelConfirmation = true
                    }) {
                        Image(systemName: "xmark")
                            .foregroundColor(.primary)
                            .font(.system(size: 16, weight: .semibold))
                    }
                }
                
            }
            .alert("Vill du verkligen avsluta?", isPresented: $showCancelConfirmation) {
                Button("Fortsätt", role: .cancel) {
                    // Do nothing, just dismiss the alert
                }
                Button("Avsluta", role: .destructive) {
                    viewModel.stopTimer()
                    finalizeSessionAndDismiss()
                }
            } message: {
                Text("Ditt pass kommer inte att sparas om du avbryter nu.")
            }
            .sheet(isPresented: $showExercisePicker) {
                ExercisePickerView { exercise in
                    viewModel.addExercise(exercise)
                }
            }
            .sheet(isPresented: $showWorkoutGenerator) {
                workoutGeneratorSheet
            }
            .sheet(isPresented: $showSubscriptionView) {
                PresentPaywallView()
            }
            .fullScreenCover(isPresented: $showCompleteSession) {
                if let sessionData = viewModel.sessionData {
                    SessionCompleteView(
                        activity: .walking,
                        distance: 0,
                        duration: sessionData.duration,
                        earnedPoints: sessionData.earnedXP,
                        routeImage: nil,
                        routeCoordinates: [],  // No route for gym sessions
                        elevationGain: 0,
                        maxSpeed: 0,
                        completedSplits: [],
                        gymExercises: sessionData.exercises,  // Pass gym exercises
                        sessionLivePhoto: nil,  // No live photo for gym sessions
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
                persistSession(force: true)
                viewModel.stopTimer()
            }
            .interactiveDismissDisabled()
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
                if newPhase == .inactive || newPhase == .background {
                    persistSession(force: true)
                }
            }
            .onReceive(SessionManager.shared.$activeSession) { newValue in
                activeSession = newValue
            }
            .onReceive(RevenueCatManager.shared.$isProMember) { newValue in
                isPremium = newValue
            }
            .alert("UPPY", isPresented: $showGeneratorResultAlert, presenting: generatorResultMessage) { _ in
                Button("Okej", role: .cancel) {}
            } message: { message in
                Text(message)
            }
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Klart") {
                        focusedField = nil
                    }
                    .font(.system(size: 16, weight: .semibold))
                }
            }
            .safeAreaInset(edge: .bottom) {
                if viewModel.exercises.isEmpty {
                    Color.clear.frame(height: 0)
                } else {
                    HoldToSaveButton(title: "Spara pass", duration: 1.0) {
                        completeSession()
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 12)
                }
            }
        }
    }
    
    private func completeSession() {
        focusedField = nil
        persistSession(force: true)
        let duration = viewModel.elapsedSeconds
        let isPro = isPremium
        viewModel.completeSession(duration: duration, isPro: isPro)
        
        // Update streak
        StreakManager.shared.registerWorkoutCompletion()
        
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
}

extension GymSessionView {
    private func initializeSessionIfNeeded() {
        guard !hasInitializedSession else { return }
        hasInitializedSession = true

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

    private func finalizeSessionAndDismiss() {
        focusedField = nil
        SessionManager.shared.finalizeSession()
        viewModel.resetSession()
        showCompleteSession = false
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

// MARK: - Exercise Card
struct ExerciseCard: View {
    let exercise: GymExercise
    let previousSets: [PreviousExerciseSet]
    let onAddSet: () -> Void
    let onUpdateSet: (Int, Double, Int) -> Void
    let onDeleteSet: (Int) -> Void
    let onToggleSetCompletion: (Int) -> Void
    let onDelete: () -> Void
    let focusedField: FocusState<GymSessionInputField?>.Binding
    
    @State private var showDeleteConfirmation = false
    
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
                
                Button(action: {
                    showDeleteConfirmation = true
                }) {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                        .font(.system(size: 18))
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            
            // Sets header
            HStack(spacing: 8) {
                Text("SET")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.secondary)
                    .frame(width: 32, alignment: .center)
                Text("FÖRRA")
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
            }
            .animation(.none, value: exercise.sets.count)
            
            // Add set button
            Button(action: onAddSet) {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("Lägg till set")
                }
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.blue)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
        }
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
        .padding(.horizontal, 16)
        .confirmationDialog("Ta bort övning?", isPresented: $showDeleteConfirmation) {
            Button("Ta bort", role: .destructive) {
                onDelete()
            }
            Button("Avbryt", role: .cancel) {}
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
    @State private var showMuscleSheet = false
    @State private var selectedEquipment: String? = nil
    @State private var selectedTarget: String? = nil
    @State private var equipmentList: [String] = []
    @State private var targetList: [String] = []
    @State private var hasLoadedExercises = false
    @State private var recentlyUsedExercises: [ExerciseDBExercise] = []
    
    var filteredExercises: [ExerciseDBExercise] {
        if searchText.isEmpty {
            return exercises
        }
        return exercises.filter { $0.displayName.localizedCaseInsensitiveContains(searchText) }
    }
    
    var equipmentButtonText: String {
        if let equipment = selectedEquipment {
            return equipment.prefix(1).capitalized + equipment.dropFirst()
        }
        return "All utrustning"
    }
    
    var muscleButtonText: String {
        if let target = selectedTarget {
            return target.prefix(1).capitalized + target.dropFirst()
        }
        return "Alla muskler"
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.gray)
                    TextField("Sök övning", text: $searchText)
                }
                .padding(12)
                .background(Color(.systemGray6))
                .cornerRadius(10)
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .background(Color(.systemBackground))
                
                // Filter buttons
                HStack(spacing: 12) {
                    Button(action: {
                        showEquipmentSheet = true
                    }) {
                        HStack {
                            Text(equipmentButtonText)
                                .font(.system(size: 14, weight: .medium))
                            Image(systemName: "chevron.down")
                                .font(.system(size: 12))
                        }
                        .foregroundColor(.primary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .padding(.horizontal, 8)
                        .background(selectedEquipment != nil ? Color.primary.opacity(0.1) : Color(.systemGray6))
                        .cornerRadius(10)
                    }
                    
                    Button(action: {
                        showMuscleSheet = true
                    }) {
                        HStack {
                            Text(muscleButtonText)
                                .font(.system(size: 14, weight: .medium))
                            Image(systemName: "chevron.down")
                                .font(.system(size: 12))
                        }
                        .foregroundColor(.primary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .padding(.horizontal, 8)
                        .background(selectedTarget != nil ? Color.primary.opacity(0.1) : Color(.systemGray6))
                        .cornerRadius(10)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color(.systemBackground))
                
                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let errorMessage = errorMessage {
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 48))
                            .foregroundColor(.orange)
                        Text("Kunde inte ladda övningar")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        Button("Försök igen") {
                            Task {
                                await loadExercises()
                            }
                        }
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(Color.primary)
                        .foregroundColor(Color(.systemBackground))
                        .cornerRadius(8)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if exercises.isEmpty && hasLoadedExercises {
                    VStack(spacing: 16) {
                        Image(systemName: "dumbbell")
                            .font(.system(size: 48))
                            .foregroundColor(.gray)
                        Text("Inga övningar hittades")
                            .font(.headline)
                            .foregroundColor(.gray)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            // Recently used exercises section
                            if !recentlyUsedExercises.isEmpty && searchText.isEmpty {
                                VStack(alignment: .leading, spacing: 12) {
                                    Text("Senast använda")
                                        .font(.system(size: 18, weight: .bold))
                                        .foregroundColor(.primary)
                                        .padding(.horizontal, 16)
                                        .padding(.top, 16)
                                    
                                    ForEach(recentlyUsedExercises) { exercise in
                                        Button(action: {
                                            let template = ExerciseTemplate(
                                                id: exercise.id,
                                                name: exercise.displayName,
                                                category: exercise.swedishBodyPart
                                            )
                                            RecentExerciseStore.shared.record(exerciseId: exercise.id)
                                            onSelect(template)
                                            dismiss()
                                        }) {
                                            HStack(spacing: 12) {
                                                ExerciseGIFView(exerciseId: exercise.id, gifUrl: exercise.gifUrl)
                                                
                                                VStack(alignment: .leading, spacing: 4) {
                                                    Text(exercise.displayName)
                                                        .font(.system(size: 16, weight: .medium))
                                                        .foregroundColor(.primary)
                                                    Text(exercise.swedishBodyPart)
                                                        .font(.system(size: 13))
                                                        .foregroundColor(.secondary)
                                                }
                                                Spacer()
                                                Image(systemName: "clock.arrow.circlepath")
                                                    .foregroundColor(.orange)
                                                    .font(.system(size: 18))
                                            }
                                            .padding(.vertical, 12)
                                            .padding(.horizontal, 16)
                                            .background(Color(.systemGray6).opacity(0.5))
                                        }
                                    }
                                    
                                    Divider()
                                        .padding(.vertical, 12)
                                    
                                    Text("Alla övningar")
                                        .font(.system(size: 18, weight: .bold))
                                        .foregroundColor(.primary)
                                        .padding(.horizontal, 16)
                                }
                            }
                            
                            ForEach(filteredExercises) { exercise in
                                Button(action: {
                                    let template = ExerciseTemplate(
                                        id: exercise.id,
                                        name: exercise.displayName,
                                        category: exercise.swedishBodyPart
                                    )
                                    RecentExerciseStore.shared.record(exerciseId: exercise.id)
                                    onSelect(template)
                                    dismiss()
                                }) {
                                    HStack(spacing: 12) {
                                        // Exercise GIF from RapidAPI
                                        ExerciseGIFView(exerciseId: exercise.id, gifUrl: exercise.gifUrl)
                                        
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(exercise.displayName)
                                                .font(.system(size: 16, weight: .medium))
                                                .foregroundColor(.primary)
                                                .multilineTextAlignment(.leading)
                                            
                                            Text(exercise.swedishBodyPart)
                                                .font(.system(size: 14))
                                                .foregroundColor(.secondary)
                                        }
                                        
                                        Spacer()
                                        
                                        Image(systemName: "arrow.up.right")
                                            .font(.system(size: 18))
                                            .foregroundColor(.primary)
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 12)
                                    .background(Color(.systemBackground))
                                }
                                
                                Divider()
                                    .padding(.leading, 88)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Lägg till övning")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Avbryt") {
                        dismiss()
                    }
                    .foregroundColor(.blue)
                }
            }
            .task {
                await initializeData()
            }
            .sheet(isPresented: $showEquipmentSheet) {
                EquipmentFilterSheet(
                    equipmentList: equipmentList,
                    selectedEquipment: $selectedEquipment,
                    onSelect: { equipment in
                        Task {
                            if let equipment = equipment {
                                await loadExercisesByEquipment(equipment)
                            } else {
                                await loadExercises()
                            }
                        }
                    }
                )
            }
            .sheet(isPresented: $showMuscleSheet) {
                MuscleFilterSheet(
                    targetList: targetList,
                    selectedTarget: $selectedTarget,
                    onSelect: { target in
                        Task {
                            if let target = target {
                                await loadExercisesByTarget(target)
                            } else {
                                await loadExercises()
                            }
                        }
                    }
                )
            }
            .background(Color(.systemBackground))
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
        await loadExercises()
        _ = await bodyPartsTask
        _ = await filterTask
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
    
    private func loadExercisesByTarget(_ target: String) async {
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }
        do {
            let targetExercises = try await ExerciseDBService.shared.fetchExercisesByTarget(target)
            await MainActor.run {
                exercises = targetExercises
                isLoading = false
                hasLoadedExercises = true
            }
        } catch {
            await MainActor.run {
                isLoading = false
                errorMessage = error.localizedDescription
                hasLoadedExercises = true
            }
            print("❌ Error loading exercises for target \(target): \(error)")
        }
    }
}

// MARK: - Equipment Filter Sheet
struct EquipmentFilterSheet: View {
    @Environment(\.dismiss) var dismiss
    let equipmentList: [String]
    @Binding var selectedEquipment: String?
    let onSelect: (String?) -> Void
    
    var body: some View {
        NavigationStack {
            List {
                Button {
                    selectedEquipment = nil
                    onSelect(nil)
                    dismiss()
                } label: {
                    HStack {
                        Text("All utrustning")
                            .foregroundColor(.primary)
                        Spacer()
                        if selectedEquipment == nil {
                            Image(systemName: "checkmark")
                                .foregroundColor(.blue)
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
                            Text(equipment.prefix(1).capitalized + equipment.dropFirst())
                                .foregroundColor(.primary)
                            Spacer()
                            if selectedEquipment == equipment {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Välj maskin")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Stäng") {
                        dismiss()
                    }
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
    
    var body: some View {
        NavigationStack {
            List {
                Button {
                    selectedTarget = nil
                    onSelect(nil)
                    dismiss()
                } label: {
                    HStack {
                        Text("Alla muskler")
                            .foregroundColor(.primary)
                        Spacer()
                        if selectedTarget == nil {
                            Image(systemName: "checkmark")
                                .foregroundColor(.blue)
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
                            Text(target.prefix(1).capitalized + target.dropFirst())
                                .foregroundColor(.primary)
                            Spacer()
                            if selectedTarget == target {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Välj muskel")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Stäng") {
                        dismiss()
                    }
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
    private let storageKey = "recent_gym_exercises"
    private let maxItems = 12
    
    func record(exerciseId: String) {
        var ids = load()
        ids.removeAll { $0 == exerciseId }
        ids.insert(exerciseId, at: 0)
        save(Array(ids.prefix(maxItems)))
    }
    
    func load() -> [String] {
        defaults.stringArray(forKey: storageKey) ?? []
    }
    
    func replace(with ids: [String]) {
        save(Array(ids.prefix(maxItems)))
    }
    
    private func save(_ ids: [String]) {
        defaults.set(ids, forKey: storageKey)
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

