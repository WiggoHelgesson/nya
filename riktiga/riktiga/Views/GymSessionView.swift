import SwiftUI

enum GymSessionInputField: Hashable {
    case kg(exerciseId: String, setIndex: Int)
    case reps(exerciseId: String, setIndex: Int)
}

struct GymSessionView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var authViewModel: AuthViewModel
    @Environment(\.scenePhase) private var scenePhase
    @ObservedObject private var sessionManager = SessionManager.shared
    @StateObject private var viewModel = GymSessionViewModel()
    @State private var showExercisePicker = false
    @State private var showCompleteSession = false
    @State private var showCancelConfirmation = false
    @State private var didLoadSavedWorkouts = false
    @State private var hasInitializedSession = false
    @State private var lastPersistedElapsedSeconds: Int = 0
    @State private var showXpCelebration = false
    @State private var xpCelebrationPoints: Int = 0
    @FocusState private var focusedField: GymSessionInputField?
    
    @ViewBuilder
    private var savedWorkoutsSection: some View {
        if viewModel.isLoadingSavedWorkouts {
            ProgressView()
                .padding(.top, 8)
        } else if !viewModel.savedWorkouts.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text("Sparade pass")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.black)
                    .padding(.horizontal, 16)
                
                ForEach(viewModel.savedWorkouts) { workout in
                    Button {
                        viewModel.applySavedWorkout(workout)
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(workout.name)
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.black)
                                Text("\(workout.exercises.count) övningar")
                                    .font(.system(size: 13))
                                    .foregroundColor(.gray)
                            }
                            Spacer()
                            Image(systemName: "arrow.down.circle.fill")
                                .foregroundColor(.black)
                                .font(.system(size: 18))
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(Color.white)
                        .cornerRadius(12)
                        .shadow(color: Color.black.opacity(0.05), radius: 6, x: 0, y: 2)
                    }
                    .padding(.horizontal, 16)
                }
            }
            .padding(.top, 8)
        }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemBackground)
                    .ignoresSafeArea()
                
                if viewModel.exercises.isEmpty {
                    // Empty state
                    VStack(spacing: 24) {
                        Image(systemName: "dumbbell.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)
                        
                        Text("Lägg till övningar för att börja")
                            .font(.headline)
                            .foregroundColor(.gray)
                        
                        Button(action: {
                            showExercisePicker = true
                        }) {
                            HStack {
                                Image(systemName: "plus.circle.fill")
                                Text("Lägg till övning")
                            }
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color(.systemGray6))
                            .cornerRadius(12)
                        }
                        .padding(.horizontal, 16)
                        
                        savedWorkoutsSection
                        
                        .padding(.bottom, 100)
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
                                    onAddSet: {
                                        viewModel.addSet(to: exercise.id)
                                    },
                                    onUpdateSet: { setIndex, kg, reps in
                                        viewModel.updateSet(exerciseId: exercise.id, setIndex: setIndex, kg: kg, reps: reps)
                                    },
                                    onDeleteSet: { setIndex in
                                        viewModel.deleteSet(exerciseId: exercise.id, setIndex: setIndex)
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
                                .foregroundColor(.black)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(Color(.systemGray6))
                                .cornerRadius(12)
                            }
                            .padding(.horizontal, 16)
                            
                            if viewModel.isLoadingSavedWorkouts {
                                ProgressView()
                                    .padding(.top, 8)
                            } else if !viewModel.savedWorkouts.isEmpty {
                                VStack(alignment: .leading, spacing: 12) {
                                    Text("Sparade pass")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(.black)
                                        .padding(.horizontal, 16)
                                    
                                    ForEach(viewModel.savedWorkouts) { workout in
                                        Button {
                                            viewModel.applySavedWorkout(workout)
                                        } label: {
                                            HStack {
                                                VStack(alignment: .leading, spacing: 4) {
                                                    Text(workout.name)
                                                        .font(.system(size: 16, weight: .medium))
                                                        .foregroundColor(.black)
                                                    Text("\(workout.exercises.count) övningar")
                                                        .font(.system(size: 13))
                                                        .foregroundColor(.gray)
                                                }
                                                Spacer()
                                                Image(systemName: "arrow.down.circle.fill")
                                                    .foregroundColor(.black)
                                                    .font(.system(size: 18))
                                            }
                                            .padding(.horizontal, 16)
                                            .padding(.vertical, 12)
                                            .background(Color.white)
                                            .cornerRadius(12)
                                            .shadow(color: Color.black.opacity(0.05), radius: 6, x: 0, y: 2)
                                        }
                                        .padding(.horizontal, 16)
                                    }
                                }
                                .padding(.top, 8)
                            }
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
                            .foregroundColor(.black)
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
            .sheet(isPresented: $showXpCelebration) {
                XpCelebrationView(
                    points: xpCelebrationPoints,
                    buttonTitle: "Skapa inlägg"
                ) {
                    showXpCelebration = false
                    showCompleteSession = true
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
                        elevationGain: 0,
                        maxSpeed: 0,
                        completedSplits: [],
                        gymExercises: sessionData.exercises,  // Pass gym exercises
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
        viewModel.completeSession(duration: duration)
        xpCelebrationPoints = viewModel.sessionData?.earnedXP ?? 0
        showXpCelebration = true
    }
    
    private func metricView(title: String, value: String) -> some View {
        VStack(spacing: 6) {
            Text(title.uppercased())
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.gray)
            Text(value)
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(.black)
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

        if let activeSession = sessionManager.activeSession,
           activeSession.activityType == ActivityType.walking.rawValue {
            let startTime = activeSession.startTime
            let exercises = activeSession.gymExercises ?? []
            sessionManager.beginSession()
            viewModel.restoreSession(exercises: exercises, startTime: startTime)
            viewModel.startTimer(startTime: startTime)
            lastPersistedElapsedSeconds = viewModel.elapsedSeconds
            return
        }

        sessionManager.beginSession()
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

        sessionManager.saveActiveSession(
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
        sessionManager.finalizeSession()
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
                    .fill(Color.black)
                    .frame(width: min(fillWidth, width))
                
                Text(title.uppercased())
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
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
    let onAddSet: () -> Void
    let onUpdateSet: (Int, Double, Int) -> Void
    let onDeleteSet: (Int) -> Void
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
                        .foregroundColor(.black)
                    
                    if let category = exercise.category {
                        Text(category)
                            .font(.system(size: 14))
                            .foregroundColor(.gray)
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
            HStack(spacing: 12) {
                Text("SET")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.gray)
                    .frame(width: 40, alignment: .center)
                Text("KG")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.gray)
                    .frame(width: 80, alignment: .center)
                Text("REPS")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.gray)
                    .frame(width: 80, alignment: .center)
                Spacer()
                Color.clear
                    .frame(width: 28)
            }
            .padding(.horizontal, 16)
            
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
                    onUpdate: { kg, reps in
                        onUpdateSet(index, kg, reps)
                    },
                    onDelete: {
                        onDeleteSet(index)
                    }
                )
            }
            
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
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
        .padding(.horizontal, 16)
        .confirmationDialog("Ta bort övning?", isPresented: $showDeleteConfirmation) {
            Button("Ta bort", role: .destructive) {
                onDelete()
            }
            Button("Avbryt", role: .cancel) {}
        }
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
    let onUpdate: (Double, Int) -> Void
    let onDelete: () -> Void
    
    @State private var kgText: String
    @State private var repsText: String
    
    init(exerciseId: String, setIndex: Int, setNumber: Int, kg: Double, reps: Int, isCompleted: Bool, focusedField: FocusState<GymSessionInputField?>.Binding, onUpdate: @escaping (Double, Int) -> Void, onDelete: @escaping () -> Void) {
        self.exerciseId = exerciseId
        self.setIndex = setIndex
        self.setNumber = setNumber
        self.kg = kg
        self.reps = reps
        self.isCompleted = isCompleted
        self.focusedField = focusedField
        self.onUpdate = onUpdate
        self.onDelete = onDelete
        _kgText = State(initialValue: kg > 0 ? String(format: "%.0f", kg) : "")
        _repsText = State(initialValue: reps > 0 ? "\(reps)" : "")
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // Set number
            Text("\(setNumber)")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.black)
                .frame(width: 40, alignment: .center)
            
            // KG input
            TextField("0", text: $kgText)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.center)
                .font(.system(size: 16, weight: .medium))
                .frame(width: 80)
                .padding(.vertical, 8)
                .background(Color(.systemGray6))
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
                .frame(width: 80)
                .padding(.vertical, 8)
                .background(Color(.systemGray6))
                .cornerRadius(8)
                .focused(focusedField, equals: .reps(exerciseId: exerciseId, setIndex: setIndex))
                .onChange(of: repsText) { newValue in
                    if let value = Int(newValue) {
                        reps = value
                        onUpdate(kg, reps)
                    }
                }
            
            Spacer()
            
            Button(action: onDelete) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.red)
            }
            .frame(width: 28, alignment: .center)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color.white)
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
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .padding(.horizontal, 8)
                        .background(selectedEquipment != nil ? Color.black.opacity(0.1) : Color(.systemGray6))
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
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .padding(.horizontal, 8)
                        .background(selectedTarget != nil ? Color.black.opacity(0.1) : Color(.systemGray6))
                        .cornerRadius(10)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                
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
                            .foregroundColor(.gray)
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                        Button("Försök igen") {
                            Task {
                                await loadExercises()
                            }
                        }
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(Color.black)
                        .foregroundColor(.white)
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
                            ForEach(filteredExercises) { exercise in
                                Button(action: {
                                    let template = ExerciseTemplate(
                                        id: exercise.id,
                                        name: exercise.displayName,
                                        category: exercise.swedishBodyPart
                                    )
                                    onSelect(template)
                                    dismiss()
                                }) {
                                    HStack(spacing: 12) {
                                        // Exercise GIF from RapidAPI
                                        ExerciseGIFView(exerciseId: exercise.id, gifUrl: exercise.gifUrl)
                                        
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(exercise.displayName)
                                                .font(.system(size: 16, weight: .medium))
                                                .foregroundColor(.black)
                                                .multilineTextAlignment(.leading)
                                            
                                            Text(exercise.swedishBodyPart)
                                                .font(.system(size: 14))
                                                .foregroundColor(.gray)
                                        }
                                        
                                        Spacer()
                                        
                                        Image(systemName: "arrow.up.right")
                                            .font(.system(size: 18))
                                            .foregroundColor(.black)
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 12)
                                    .background(Color.white)
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
                            .foregroundColor(.black)
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
                                .foregroundColor(.black)
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
                            .foregroundColor(.black)
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
                                .foregroundColor(.black)
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
            .foregroundColor(.black)
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
                .background(isSelected ? Color.black : Color(.systemGray6))
                .foregroundColor(isSelected ? .white : .black)
                .cornerRadius(20)
        }
    }
}

#Preview {
    GymSessionView()
        .environmentObject(AuthViewModel())
}

