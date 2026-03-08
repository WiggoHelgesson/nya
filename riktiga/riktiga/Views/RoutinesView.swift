import SwiftUI

// MARK: - Routines View
struct RoutinesView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var savedWorkouts: [SavedGymWorkout] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var selectedWorkout: SavedGymWorkout?
    @State private var showDeleteAlert = false
    @State private var workoutToDelete: SavedGymWorkout?
    @State private var showCreateRoutine = false
    @ObservedObject private var pinnedStore = PinnedRoutineStore.shared
    
    var body: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()
            
            if isLoading {
                ProgressView()
                    .progressViewStyle(.circular)
            } else if let error = errorMessage {
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 50))
                        .foregroundColor(.gray)
                    Text(error)
                        .font(.system(size: 15))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    
                    Button(L.t(sv: "Försök igen", nb: "Prøv igjen")) {
                        Task { await loadSavedWorkouts() }
                    }
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.black)
                }
                .padding()
            } else if savedWorkouts.isEmpty {
                emptyState
            } else {
                workoutsList
            }
        }
        .navigationTitle(L.t(sv: "Gym rutiner", nb: "Gymrutiner"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(L.t(sv: "Stäng", nb: "Lukk")) {
                    dismiss()
                }
            }
            
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { showCreateRoutine = true }) {
                    Image(systemName: "plus")
                        .font(.system(size: 16, weight: .semibold))
                }
            }
        }
        .sheet(item: $selectedWorkout) { workout in
            NavigationStack {
                SavedWorkoutDetailView(
                    workout: workout,
                    onDelete: {
                        Task {
                            await deleteWorkout(workout)
                        }
                    }
                )
                .environmentObject(authViewModel)
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
        .alert(L.t(sv: "Ta bort pass", nb: "Fjern økt"), isPresented: $showDeleteAlert) {
            Button(L.t(sv: "Avbryt", nb: "Avbryt"), role: .cancel) { }
            Button(L.t(sv: "Ta bort", nb: "Fjern"), role: .destructive) {
                if let workout = workoutToDelete {
                    Task {
                        await deleteWorkout(workout)
                    }
                }
            }
        } message: {
            Text(L.t(sv: "Är du säker på att du vill ta bort denna gym rutin?", nb: "Er du sikker på at du vil fjerne denne gymrutinen?"))
        }
        .task {
            await loadSavedWorkouts()
        }
    }
    
    // MARK: - Empty State
    private var emptyState: some View {
        VStack(spacing: 24) {
            Image("23")
                .resizable()
                .scaledToFit()
                .frame(width: 80, height: 80)
                .cornerRadius(16)
            
            VStack(spacing: 8) {
                Text(L.t(sv: "Inga gym rutiner", nb: "Ingen gymrutiner"))
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.primary)
                
                Text(L.t(sv: "Skapa en ny rutin eller spara ett gympass efter träningen.", nb: "Opprett en ny rutine eller lagre en gymøkt etter treningen."))
                    .font(.system(size: 15))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            
            Button(action: { showCreateRoutine = true }) {
                HStack(spacing: 8) {
                    Image(systemName: "plus")
                        .font(.system(size: 16, weight: .semibold))
                    Text(L.t(sv: "Skapa ny rutin", nb: "Opprett ny rutine"))
                        .font(.system(size: 16, weight: .semibold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 14)
                .background(Color.black)
                .cornerRadius(12)
            }
        }
    }
    
    // MARK: - Workouts List
    private var workoutsList: some View {
        ScrollView {
            VStack(spacing: 12) {
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
                        
                        Text(L.t(sv: "Skapa ny rutin", nb: "Opprett ny rutine"))
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
                    SavedWorkoutCard(
                        workout: workout,
                        onTap: { selectedWorkout = workout },
                        onDelete: {
                            workoutToDelete = workout
                            showDeleteAlert = true
                        },
                        onTogglePin: {
                            pinnedStore.toggle(workout.id)
                            withAnimation(.smooth(duration: 0.3)) {
                                savedWorkouts.sort {
                                    let p0 = pinnedStore.isPinned($0.id)
                                    let p1 = pinnedStore.isPinned($1.id)
                                    if p0 != p1 { return p0 }
                                    return $0.createdAt > $1.createdAt
                                }
                            }
                        },
                        isPinned: pinnedStore.isPinned(workout.id)
                    )
                }
            }
            .padding(16)
        }
    }
    
    // MARK: - Data Loading
    private func loadSavedWorkouts() async {
        guard let userId = authViewModel.currentUser?.id else {
            errorMessage = L.t(sv: "Kunde inte hitta användare", nb: "Kunne ikke finne bruker")
            isLoading = false
            return
        }
        
        do {
            let workouts = try await SavedWorkoutService.shared.fetchSavedWorkouts(for: userId)
            await MainActor.run {
                self.savedWorkouts = workouts.sorted {
                    let p0 = pinnedStore.isPinned($0.id)
                    let p1 = pinnedStore.isPinned($1.id)
                    if p0 != p1 { return p0 }
                    return $0.createdAt > $1.createdAt
                }
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.errorMessage = L.t(sv: "Kunde inte hämta gym rutiner", nb: "Kunne ikke hente gymrutiner")
                self.isLoading = false
            }
        }
    }
    
    private func deleteWorkout(_ workout: SavedGymWorkout) async {
        guard let userId = authViewModel.currentUser?.id else { return }
        
        do {
            try await SavedWorkoutService.shared.deleteWorkoutTemplate(id: workout.id, userId: userId)
            await MainActor.run {
                withAnimation {
                    savedWorkouts.removeAll { $0.id == workout.id }
                }
            }
        } catch {
            print("Error deleting workout: \(error)")
        }
    }
}

// MARK: - Saved Workout Card
struct SavedWorkoutCard: View {
    let workout: SavedGymWorkout
    let onTap: () -> Void
    let onDelete: () -> Void
    let onTogglePin: () -> Void
    var isPinned: Bool = false
    
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "sv_SE")
        formatter.dateFormat = "d MMM yyyy"
        return formatter
    }()
    
    // Calculate total volume
    private var totalVolume: Double {
        workout.exercises.reduce(0) { total, exercise in
            let exerciseVolume = zip(exercise.kg, exercise.reps).reduce(0.0) { setTotal, pair in
                setTotal + (pair.0 * Double(pair.1))
            }
            return total + exerciseVolume
        }
    }
    
    var body: some View {
        Button(action: onTap) {
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
                    
                    Text(L.t(sv: "\(workout.exercises.count) övningar", nb: "\(workout.exercises.count) øvelser"))
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                    
                    Text(dateFormatter.string(from: workout.createdAt))
                        .font(.system(size: 12))
                        .foregroundColor(.secondary.opacity(0.7))
                }
                
                Spacer()
                
                // Volume badge
                if totalVolume > 0 {
                    Text(formatVolume(totalVolume))
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.black)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.black.opacity(0.1))
                        .cornerRadius(6)
                }
                
                // Pin button
                Button(action: onTogglePin) {
                    Image(systemName: isPinned ? "pin.fill" : "pin")
                        .font(.system(size: 15))
                        .foregroundColor(isPinned ? .black : .gray)
                        .padding(8)
                }
                .buttonStyle(.plain)
                
                // Delete button
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(.system(size: 16))
                        .foregroundColor(.gray)
                        .padding(8)
                }
                .buttonStyle(.plain)
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.secondary)
            }
            .padding(16)
            .background(Color(.secondarySystemBackground))
            .cornerRadius(16)
        }
        .buttonStyle(.plain)
    }
    
    private func formatVolume(_ volume: Double) -> String {
        if volume >= 1000 {
            return String(format: "%.1fk kg", volume / 1000)
        } else {
            return String(format: "%.0f kg", volume)
        }
    }
}

// MARK: - Saved Workout Detail View
struct SavedWorkoutDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var authViewModel: AuthViewModel
    let workout: SavedGymWorkout
    let onDelete: () -> Void
    
    @State private var showDeleteAlert = false
    
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "sv_SE")
        formatter.dateFormat = "d MMMM yyyy 'kl.' HH:mm"
        return formatter
    }()
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header with logo
                VStack(spacing: 8) {
                    Image("23")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 70, height: 70)
                        .cornerRadius(16)
                    
                    Text(workout.name)
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.primary)
                    
                    Text(L.t(sv: "Sparat \(dateFormatter.string(from: workout.createdAt))", nb: "Lagret \(dateFormatter.string(from: workout.createdAt))"))
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
                .padding(.top, 20)
                
                // Stats
                HStack(spacing: 12) {
                    RoutineStatBox(value: "\(workout.exercises.count)", label: L.t(sv: "Övningar", nb: "Øvelser"))
                    RoutineStatBox(value: "\(totalSets)", label: L.t(sv: "Set", nb: "Sett"))
                    RoutineStatBox(value: formatVolume(totalVolume), label: L.t(sv: "Volym", nb: "Volum"))
                }
                .padding(.horizontal, 16)
                
                // Exercises list
                VStack(alignment: .leading, spacing: 12) {
                    Text(L.t(sv: "Övningar", nb: "Øvelser"))
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.primary)
                        .padding(.horizontal, 16)
                    
                    VStack(spacing: 0) {
                        ForEach(Array(workout.exercises.enumerated()), id: \.offset) { index, exercise in
                            VStack(spacing: 0) {
                                HStack(spacing: 12) {
                                    // Exercise number
                                    Text("\(index + 1)")
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundColor(.white)
                                        .frame(width: 28, height: 28)
                                        .background(Color.black)
                                        .cornerRadius(8)
                                    
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(exercise.name)
                                            .font(.system(size: 15, weight: .semibold))
                                            .foregroundColor(.primary)
                                        
                                        if let category = exercise.category {
                                            Text(category)
                                                .font(.system(size: 12))
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                    
                                    Spacer()
                                    
                                    // Sets info
                                    VStack(alignment: .trailing, spacing: 2) {
                                        Text(L.t(sv: "\(exercise.sets) set", nb: "\(exercise.sets) sett"))
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundColor(.primary)
                                        
                                        if let maxKg = exercise.kg.max(), maxKg > 0 {
                                            Text("\(Int(maxKg)) kg")
                                                .font(.system(size: 12))
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                }
                                .padding(14)
                                
                                if index < workout.exercises.count - 1 {
                                    Divider()
                                        .padding(.leading, 54)
                                }
                            }
                        }
                    }
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(16)
                    .padding(.horizontal, 16)
                }
                
                // Delete button
                Button(action: { showDeleteAlert = true }) {
                    HStack {
                        Image(systemName: "trash")
                        Text(L.t(sv: "Ta bort sparat pass", nb: "Fjern lagret økt"))
                    }
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.gray)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.black.opacity(0.05))
                    .cornerRadius(12)
                }
                .padding(.horizontal, 16)
                .padding(.top, 20)
                .padding(.bottom, 40)
            }
        }
        .navigationTitle(L.t(sv: "Detaljer", nb: "Detaljer"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(L.t(sv: "Stäng", nb: "Lukk")) {
                    dismiss()
                }
            }
        }
        .alert(L.t(sv: "Ta bort pass", nb: "Fjern økt"), isPresented: $showDeleteAlert) {
            Button(L.t(sv: "Avbryt", nb: "Avbryt"), role: .cancel) { }
            Button(L.t(sv: "Ta bort", nb: "Fjern"), role: .destructive) {
                onDelete()
                dismiss()
            }
        } message: {
            Text(L.t(sv: "Är du säker på att du vill ta bort denna gym rutin?", nb: "Er du sikker på at du vil fjerne denne gymrutinen?"))
        }
    }
    
    private var totalSets: Int {
        workout.exercises.reduce(0) { $0 + $1.sets }
    }
    
    private var totalVolume: Double {
        workout.exercises.reduce(0) { total, exercise in
            let exerciseVolume = zip(exercise.kg, exercise.reps).reduce(0.0) { setTotal, pair in
                setTotal + (pair.0 * Double(pair.1))
            }
            return total + exerciseVolume
        }
    }
    
    private func formatVolume(_ volume: Double) -> String {
        if volume >= 1000 {
            return String(format: "%.1fk", volume / 1000)
        } else {
            return String(format: "%.0f", volume)
        }
    }
}

// MARK: - Stat Box
private struct RoutineStatBox: View {
    let value: String
    let label: String
    
    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(.primary)
            
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

// MARK: - Create Routine View
struct CreateRoutineView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var authViewModel: AuthViewModel
    let onSave: (SavedGymWorkout) -> Void
    
    @State private var routineName = ""
    @State private var selectedExercises: [GymExercisePost] = []
    @State private var showExercisePicker = false
    @State private var isSaving = false
    
    // For adding exercise with sets selection
    @State private var pendingExercise: ExerciseTemplate?
    @State private var showSetsSelector = false
    @State private var selectedSets = 3
    @State private var selectedReps = 10
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                headerSection
                nameFieldSection
                exercisesSection
            }
            .padding(.bottom, 100)
        }
        .navigationTitle(L.t(sv: "Skapa ny rutin", nb: "Opprett ny rutine"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { toolbarContent }
        .navigationDestination(isPresented: $showExercisePicker) {
            ExercisePickerView { exercise in
                // Store the pending exercise, hide picker, and show sets selector
                pendingExercise = exercise
                showExercisePicker = false
                // Small delay to allow picker to dismiss before showing sheet
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    showSetsSelector = true
                }
            }
        }
        .sheet(isPresented: $showSetsSelector) {
            if let exercise = pendingExercise {
                SetsSelectorSheet(
                    exerciseName: exercise.name,
                    selectedSets: $selectedSets,
                    selectedReps: $selectedReps,
                    onConfirm: {
                        addExerciseWithSets(exercise: exercise, sets: selectedSets, reps: selectedReps)
                        showSetsSelector = false
                        pendingExercise = nil
                    }
                )
                .presentationDetents([.height(450)])
                .presentationDragIndicator(.visible)
            }
        }
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        Image("23")
            .resizable()
            .scaledToFit()
            .frame(width: 60, height: 60)
            .cornerRadius(14)
            .padding(.top, 10)
    }
    
    // MARK: - Name Field Section
    private var nameFieldSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L.t(sv: "Namn på rutin", nb: "Navn på rutine"))
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.secondary)
            
            TextField(L.t(sv: "T.ex. Benpass, Push-dag...", nb: "F.eks. Bendag, Push-dag..."), text: $routineName)
                .font(.system(size: 16))
                .padding(14)
                .background(Color(.secondarySystemBackground))
                .cornerRadius(12)
        }
        .padding(.horizontal, 16)
    }
    
    // MARK: - Exercises Section
    private var exercisesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            exercisesSectionHeader
            
            if selectedExercises.isEmpty {
                emptyExercisesPlaceholder
            } else {
                exercisesList
                addMoreButton
            }
        }
    }
    
    private var exercisesSectionHeader: some View {
        HStack {
            Text(L.t(sv: "Övningar (\(selectedExercises.count))", nb: "Øvelser (\(selectedExercises.count))"))
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.secondary)
            
            Spacer()
            
            Button(action: { showExercisePicker = true }) {
                HStack(spacing: 4) {
                    Image(systemName: "plus")
                    Text(L.t(sv: "Lägg till", nb: "Legg til"))
                }
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.black)
            }
        }
        .padding(.horizontal, 16)
    }
    
    private var emptyExercisesPlaceholder: some View {
        VStack(spacing: 12) {
            Image(systemName: "dumbbell")
                .font(.system(size: 30))
                .foregroundColor(.gray.opacity(0.5))
            
            Text(L.t(sv: "Inga övningar tillagda", nb: "Ingen øvelser lagt til"))
                .font(.system(size: 14))
                .foregroundColor(.secondary)
            
            Button(action: { showExercisePicker = true }) {
                Text(L.t(sv: "Sök övningar", nb: "Søk øvelser"))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(Color.black)
                    .cornerRadius(8)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
        .padding(.horizontal, 16)
    }
    
    private var exercisesList: some View {
        VStack(spacing: 0) {
            ForEach(Array(selectedExercises.enumerated()), id: \.offset) { index, exercise in
                CreateRoutineExerciseRow(
                    index: index,
                    exercise: exercise,
                    isLast: index >= selectedExercises.count - 1,
                    onRemove: { [index] in
                        withAnimation {
                            _ = self.selectedExercises.remove(at: index)
                        }
                    },
                    onChangeSets: { [index] newSets, newReps in
                        updateExerciseSets(at: index, newSets: newSets, newReps: newReps)
                    }
                )
            }
        }
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
        .padding(.horizontal, 16)
    }
    
    private func updateExerciseSets(at index: Int, newSets: Int, newReps: Int) {
        guard index < selectedExercises.count else { return }
        var updatedExercise = selectedExercises[index]
        
        // Adjust reps and kg arrays to match new sets count
        let reps = Array(repeating: newReps, count: newSets)
        let kg = Array(repeating: 0.0, count: newSets)
        
        updatedExercise = GymExercisePost(
            id: updatedExercise.id,
            name: updatedExercise.name,
            category: updatedExercise.category,
            sets: newSets,
            reps: reps,
            kg: kg,
            notes: updatedExercise.notes
        )
        
        selectedExercises[index] = updatedExercise
    }
    
    private var addMoreButton: some View {
        Button(action: { showExercisePicker = true }) {
            HStack(spacing: 8) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 18))
                Text(L.t(sv: "Lägg till fler övningar", nb: "Legg til flere øvelser"))
                    .font(.system(size: 14, weight: .medium))
            }
            .foregroundColor(.black)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(Color.black.opacity(0.08))
            .cornerRadius(10)
        }
        .padding(.horizontal, 16)
    }
    
    // MARK: - Toolbar
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .navigationBarLeading) {
            Button(L.t(sv: "Avbryt", nb: "Avbryt")) {
                dismiss()
            }
        }
        
        ToolbarItem(placement: .navigationBarTrailing) {
            Button(L.t(sv: "Spara", nb: "Lagre")) {
                saveRoutine()
            }
            .font(.system(size: 16, weight: .semibold))
            .disabled(routineName.isEmpty || selectedExercises.isEmpty || isSaving)
        }
    }
    
    // MARK: - Add Exercise with Sets
    private func addExerciseWithSets(exercise: ExerciseTemplate, sets: Int, reps: Int) {
        let repsArray = Array(repeating: reps, count: sets)
        let kg = Array(repeating: 0.0, count: sets)
        
        let gymExercise = GymExercisePost(
            id: exercise.id,
            name: exercise.name,
            category: exercise.category,
            sets: sets,
            reps: repsArray,
            kg: kg,
            notes: nil
        )
        selectedExercises.append(gymExercise)
    }
    
    private func saveRoutine() {
        guard let userId = authViewModel.currentUser?.id else { return }
        isSaving = true
        
        Task {
            do {
                let saved = try await SavedWorkoutService.shared.saveWorkoutTemplate(
                    userId: userId,
                    name: routineName,
                    exercises: selectedExercises
                )
                await MainActor.run {
                    onSave(saved)
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

// MARK: - Create Routine Exercise Row
private struct CreateRoutineExerciseRow: View {
    let index: Int
    let exercise: GymExercisePost
    let isLast: Bool
    let onRemove: () -> Void
    let onChangeSets: (Int, Int) -> Void // (sets, reps)
    
    @State private var showSetsSelector = false
    @State private var selectedSets: Int
    @State private var selectedReps: Int
    
    init(index: Int, exercise: GymExercisePost, isLast: Bool, onRemove: @escaping () -> Void, onChangeSets: @escaping (Int, Int) -> Void) {
        self.index = index
        self.exercise = exercise
        self.isLast = isLast
        self.onRemove = onRemove
        self.onChangeSets = onChangeSets
        self._selectedSets = State(initialValue: exercise.sets)
        // Use first rep count as default, or 10 if empty
        self._selectedReps = State(initialValue: exercise.reps.first ?? 10)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                exerciseImage
                exerciseInfo
                Spacer()
                setsButton
                removeButton
            }
            .padding(12)
            
            if !isLast {
                Divider()
                    .padding(.leading, 68)
            }
        }
        .sheet(isPresented: $showSetsSelector) {
            SetsSelectorSheet(
                exerciseName: exercise.name,
                selectedSets: $selectedSets,
                selectedReps: $selectedReps,
                onConfirm: {
                    onChangeSets(selectedSets, selectedReps)
                    showSetsSelector = false
                }
            )
            .presentationDetents([.height(450)])
            .presentationDragIndicator(.visible)
        }
    }
    
    @ViewBuilder
    private var exerciseImage: some View {
        if let exerciseId = exercise.id {
            ExerciseGIFView(exerciseId: exerciseId, gifUrl: nil)
                .frame(width: 44, height: 44)
                .clipShape(RoundedRectangle(cornerRadius: 10))
        } else {
            Text("\(index + 1)")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 28, height: 28)
                .background(Color.black)
                .cornerRadius(8)
        }
    }
    
    private var exerciseInfo: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(exercise.name)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.primary)
                .lineLimit(1)
            
            if let category = exercise.category {
                Text(category)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private var setsButton: some View {
        Button(action: {
            selectedSets = exercise.sets
            selectedReps = exercise.reps.first ?? 10
            showSetsSelector = true
        }) {
            VStack(spacing: 2) {
                HStack(spacing: 3) {
                    Text("\(exercise.sets)")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.primary)
                    Text(L.t(sv: "set", nb: "sett"))
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                HStack(spacing: 3) {
                    Text("\(exercise.reps.first ?? 10)")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.secondary)
                    Text(L.t(sv: "reps", nb: "reps"))
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color(.systemGray6))
            .cornerRadius(8)
        }
    }
    
    private var removeButton: some View {
        Button(action: onRemove) {
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 20))
                .foregroundColor(.gray.opacity(0.5))
        }
    }
}

// MARK: - Sets Selector Sheet
struct SetsSelectorSheet: View {
    let exerciseName: String
    @Binding var selectedSets: Int
    @Binding var selectedReps: Int
    let onConfirm: () -> Void
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 20) {
            // Handle bar
            RoundedRectangle(cornerRadius: 3)
                .fill(Color(.systemGray4))
                .frame(width: 40, height: 5)
                .padding(.top, 8)
            
            VStack(spacing: 8) {
                Text(L.t(sv: "Konfigurera övning", nb: "Konfigurer øvelse"))
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.primary)
                
                Text(exerciseName)
                    .font(.system(size: 15))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            
            // Sets section
            VStack(alignment: .leading, spacing: 12) {
                Text(L.t(sv: "Antal set", nb: "Antall sett"))
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 16)
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(1...6, id: \.self) { sets in
                            Button(action: {
                                selectedSets = sets
                                let haptic = UIImpactFeedbackGenerator(style: .light)
                                haptic.impactOccurred()
                            }) {
                                VStack(spacing: 4) {
                                    Text("\(sets)")
                                        .font(.system(size: 20, weight: .bold))
                                        .foregroundColor(selectedSets == sets ? .white : .primary)
                                    
                                    Text(L.t(sv: "set", nb: "sett"))
                                        .font(.system(size: 11))
                                        .foregroundColor(selectedSets == sets ? .white.opacity(0.8) : .secondary)
                                }
                                .frame(width: 60, height: 60)
                                .background(selectedSets == sets ? Color.black : Color(.systemGray6))
                                .cornerRadius(12)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }
            
            // Reps section
            VStack(alignment: .leading, spacing: 12) {
                Text(L.t(sv: "Repetitioner per set", nb: "Repetisjoner per sett"))
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 16)
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(3...20, id: \.self) { reps in
                            Button(action: {
                                selectedReps = reps
                                let haptic = UIImpactFeedbackGenerator(style: .light)
                                haptic.impactOccurred()
                            }) {
                                VStack(spacing: 4) {
                                    Text("\(reps)")
                                        .font(.system(size: 20, weight: .bold))
                                        .foregroundColor(selectedReps == reps ? .white : .primary)
                                    
                                    Text(L.t(sv: "reps", nb: "reps"))
                                        .font(.system(size: 11))
                                        .foregroundColor(selectedReps == reps ? .white.opacity(0.8) : .secondary)
                                }
                                .frame(width: 60, height: 60)
                                .background(selectedReps == reps ? Color.black : Color(.systemGray6))
                                .cornerRadius(12)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }
            
            // Summary
            HStack(spacing: 8) {
                Image(systemName: "info.circle")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                Text(L.t(sv: "\(selectedSets) set × \(selectedReps) reps", nb: "\(selectedSets) sett × \(selectedReps) reps"))
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.secondary)
            }
            .padding(.top, 4)
            
            // Confirm button
            Button(action: {
                onConfirm()
                dismiss()
            }) {
                Text(L.t(sv: "Bekräfta", nb: "Bekreft"))
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.black)
                    .cornerRadius(14)
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            
            Spacer()
        }
        .background(Color(.systemBackground))
    }
}

#Preview {
    NavigationStack {
        RoutinesView()
            .environmentObject(AuthViewModel())
    }
}

