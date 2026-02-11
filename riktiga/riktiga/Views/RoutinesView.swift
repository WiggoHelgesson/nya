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
                    
                    Button("Försök igen") {
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
        .navigationTitle("Sparade pass")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Stäng") {
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
        .alert("Ta bort pass", isPresented: $showDeleteAlert) {
            Button("Avbryt", role: .cancel) { }
            Button("Ta bort", role: .destructive) {
                if let workout = workoutToDelete {
                    Task {
                        await deleteWorkout(workout)
                    }
                }
            }
        } message: {
            Text("Är du säker på att du vill ta bort detta sparade pass?")
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
                Text("Inga sparade pass")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.primary)
                
                Text("Skapa en ny rutin eller spara ett gympass efter träningen.")
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
                    SavedWorkoutCard(
                        workout: workout,
                        onTap: { selectedWorkout = workout },
                        onDelete: {
                            workoutToDelete = workout
                            showDeleteAlert = true
                        }
                    )
                }
            }
            .padding(16)
        }
    }
    
    // MARK: - Data Loading
    private func loadSavedWorkouts() async {
        guard let userId = authViewModel.currentUser?.id else {
            errorMessage = "Kunde inte hitta användare"
            isLoading = false
            return
        }
        
        do {
            let workouts = try await SavedWorkoutService.shared.fetchSavedWorkouts(for: userId)
            await MainActor.run {
                self.savedWorkouts = workouts.sorted { $0.createdAt > $1.createdAt }
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "Kunde inte hämta sparade pass"
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
                    
                    Text("\(workout.exercises.count) övningar")
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
                    
                    Text("Sparat \(dateFormatter.string(from: workout.createdAt))")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
                .padding(.top, 20)
                
                // Stats
                HStack(spacing: 12) {
                    RoutineStatBox(value: "\(workout.exercises.count)", label: "Övningar")
                    RoutineStatBox(value: "\(totalSets)", label: "Set")
                    RoutineStatBox(value: formatVolume(totalVolume), label: "Volym")
                }
                .padding(.horizontal, 16)
                
                // Exercises list
                VStack(alignment: .leading, spacing: 12) {
                    Text("Övningar")
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
                                        Text("\(exercise.sets) set")
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
                        Text("Ta bort sparat pass")
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
        .navigationTitle("Detaljer")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Stäng") {
                    dismiss()
                }
            }
        }
        .alert("Ta bort pass", isPresented: $showDeleteAlert) {
            Button("Avbryt", role: .cancel) { }
            Button("Ta bort", role: .destructive) {
                onDelete()
                dismiss()
            }
        } message: {
            Text("Är du säker på att du vill ta bort detta sparade pass?")
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
    @State private var showExerciseSearch = false
    @State private var isSaving = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                headerSection
                nameFieldSection
                exercisesSection
            }
            .padding(.bottom, 100)
        }
        .navigationTitle("Skapa ny rutin")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { toolbarContent }
        .sheet(isPresented: $showExerciseSearch) {
            exerciseSearchSheet
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
            Text("Namn på rutin")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.secondary)
            
            TextField("T.ex. Benpass, Push-dag...", text: $routineName)
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
            Text("Övningar (\(selectedExercises.count))")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.secondary)
            
            Spacer()
            
            Button(action: { showExerciseSearch = true }) {
                HStack(spacing: 4) {
                    Image(systemName: "plus")
                    Text("Lägg till")
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
            
            Text("Inga övningar tillagda")
                .font(.system(size: 14))
                .foregroundColor(.secondary)
            
            Button(action: { showExerciseSearch = true }) {
                Text("Sök övningar")
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
                    }
                )
            }
        }
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
        .padding(.horizontal, 16)
    }
    
    private var addMoreButton: some View {
        Button(action: { showExerciseSearch = true }) {
            HStack(spacing: 8) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 18))
                Text("Lägg till fler övningar")
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
            Button("Avbryt") {
                dismiss()
            }
        }
        
        ToolbarItem(placement: .navigationBarTrailing) {
            Button("Spara") {
                saveRoutine()
            }
            .font(.system(size: 16, weight: .semibold))
            .disabled(routineName.isEmpty || selectedExercises.isEmpty || isSaving)
        }
    }
    
    // MARK: - Exercise Search Sheet
    private var exerciseSearchSheet: some View {
        NavigationStack {
            ExerciseSearchView(onSelect: { exercise in
                addExercise(exercise)
            })
        }
    }
    
    private func addExercise(_ exercise: ExerciseDBExercise) {
        let gymExercise = GymExercisePost(
            id: exercise.id,
            name: exercise.name.capitalized,
            category: exercise.bodyPart.capitalized,
            sets: 3,
            reps: [10, 10, 10],
            kg: [0, 0, 0],
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
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                exerciseImage
                exerciseInfo
                Spacer()
                setsLabel
                removeButton
            }
            .padding(12)
            
            if !isLast {
                Divider()
                    .padding(.leading, 68)
            }
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
    
    private var setsLabel: some View {
        Text("\(exercise.sets) set")
            .font(.system(size: 13))
            .foregroundColor(.secondary)
    }
    
    private var removeButton: some View {
        Button(action: onRemove) {
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 20))
                .foregroundColor(.gray.opacity(0.5))
        }
    }
}

// MARK: - Exercise Search View
struct ExerciseSearchView: View {
    @Environment(\.dismiss) private var dismiss
    let onSelect: (ExerciseDBExercise) -> Void
    
    @State private var searchText = ""
    @State private var exercises: [ExerciseDBExercise] = []
    @State private var allExercises: [ExerciseDBExercise] = []
    @State private var isLoading = false
    @State private var hasSearched = false
    @State private var popularityRanking: [String: Int] = [:]
    @State private var dynamicPopularSearches: [String] = []
    
    // Fallback popular exercises (used when no database data exists)
    private let fallbackPopularExercises = [
        "bench press", "squat", "deadlift", "shoulder press",
        "lat pulldown", "bicep curl", "tricep", "leg press",
        "row", "chest fly", "lunges", "plank"
    ]
    
    private var popularExercises: [String] {
        dynamicPopularSearches.isEmpty ? fallbackPopularExercises : dynamicPopularSearches
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Search bar
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 16))
                    .foregroundColor(.gray)
                
                TextField("Sök övning på engelska...", text: $searchText)
                    .font(.system(size: 16))
                    .submitLabel(.search)
                    .onSubmit {
                        searchExercises()
                    }
                
                if !searchText.isEmpty {
                    Button(action: { 
                        searchText = ""
                        exercises = []
                        hasSearched = false
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray)
                    }
                }
            }
            .padding(12)
            .background(Color(.secondarySystemBackground))
            .cornerRadius(12)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            
            if isLoading {
                Spacer()
                ProgressView()
                Spacer()
            } else if !hasSearched {
                // Show suggestions
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Populära sökningar")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 16)
                        
                        FlowLayoutRoutine(items: popularExercises, spacing: 8) { term in
                            Button(action: {
                                searchText = term
                                searchExercises()
                            }) {
                                Text(term.capitalized)
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(.primary)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 8)
                                    .background(Color(.secondarySystemBackground))
                                    .cornerRadius(8)
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                    .padding(.top, 8)
                }
            } else if exercises.isEmpty {
                Spacer()
                VStack(spacing: 12) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 40))
                        .foregroundColor(.gray)
                    Text("Inga övningar hittades")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.secondary)
                    Text("Prova ett annat sökord på engelska")
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                }
                Spacer()
            } else {
                // Results list
                List(exercises) { exercise in
                    Button(action: {
                        onSelect(exercise)
                        dismiss()
                    }) {
                        HStack(spacing: 12) {
                            // Exercise image
                            ExerciseGIFView(exerciseId: exercise.id, gifUrl: exercise.gifUrl)
                                .frame(width: 50, height: 50)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(exercise.name.capitalized)
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(.primary)
                                    .lineLimit(2)
                                
                                HStack(spacing: 6) {
                                    Text(exercise.bodyPart.capitalized)
                                        .font(.system(size: 12))
                                        .foregroundColor(.secondary)
                                    
                                    Text("•")
                                        .font(.system(size: 8))
                                        .foregroundColor(.secondary.opacity(0.5))
                                    Text(exercise.equipment.capitalized)
                                        .font(.system(size: 12))
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            Spacer()
                            
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 24))
                                .foregroundColor(.black)
                        }
                        .padding(.vertical, 4)
                    }
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("Sök övning")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Stäng") {
                    dismiss()
                }
            }
        }
        .task {
            await loadPopularSearchSuggestions()
        }
    }
    
    private func searchExercises() {
        guard !searchText.isEmpty else { return }
        isLoading = true
        hasSearched = true
        
        Task {
            do {
                // Load all exercises if not already loaded
                if allExercises.isEmpty {
                    allExercises = try await ExerciseDBService.shared.fetchAllExercises()
                }
                
                // Load popularity ranking if not loaded yet
                if popularityRanking.isEmpty {
                    popularityRanking = await ExercisePopularityService.shared.getSmartRanking(
                        bodyPart: nil,
                        userRecentIds: [],
                        userId: AuthViewModel.shared.currentUser?.id
                    )
                }
                
                // Filter locally by search text
                let query = searchText.lowercased()
                let results = allExercises.filter { exercise in
                    exercise.name.lowercased().contains(query) ||
                    exercise.bodyPart.lowercased().contains(query) ||
                    exercise.target.lowercased().contains(query) ||
                    exercise.equipment.lowercased().contains(query)
                }
                
                // Sort by popularity (most used first)
                let ranking = self.popularityRanking
                let sorted = results.sorted { a, b in
                    let aRank = ranking[a.id] ?? Int.max
                    let bRank = ranking[b.id] ?? Int.max
                    if aRank != bRank { return aRank < bRank }
                    return a.name < b.name
                }
                
                await MainActor.run {
                    self.exercises = Array(sorted.prefix(50)) // Limit to 50 results
                    self.isLoading = false
                }
            } catch {
                print("Search error: \(error)")
                await MainActor.run {
                    self.exercises = []
                    self.isLoading = false
                }
            }
        }
    }
    
    private func loadPopularSearchSuggestions() async {
        let popular = await ExercisePopularityService.shared.getPopularExercises(limit: 12)
        if !popular.isEmpty {
            await MainActor.run {
                dynamicPopularSearches = popular.map { $0.exerciseName.lowercased() }
            }
        }
    }
}

// MARK: - Flow Layout for Routine
struct FlowLayoutRoutine<Item: Hashable, Content: View>: View {
    let items: [Item]
    let spacing: CGFloat
    let content: (Item) -> Content
    
    @State private var totalHeight: CGFloat = .zero
    
    var body: some View {
        GeometryReader { geometry in
            self.generateContent(in: geometry)
        }
        .frame(height: totalHeight)
    }
    
    private func generateContent(in geometry: GeometryProxy) -> some View {
        var width = CGFloat.zero
        var height = CGFloat.zero
        
        return ZStack(alignment: .topLeading) {
            ForEach(items, id: \.self) { item in
                content(item)
                    .padding(.trailing, spacing)
                    .padding(.bottom, spacing)
                    .alignmentGuide(.leading) { d in
                        if abs(width - d.width) > geometry.size.width {
                            width = 0
                            height -= d.height
                        }
                        let result = width
                        if item == items.last {
                            width = 0
                        } else {
                            width -= d.width
                        }
                        return result
                    }
                    .alignmentGuide(.top) { d in
                        let result = height
                        if item == items.last {
                            height = 0
                        }
                        return result
                    }
            }
        }
        .background(viewHeightReader($totalHeight))
    }
    
    private func viewHeightReader(_ binding: Binding<CGFloat>) -> some View {
        GeometryReader { geometry -> Color in
            DispatchQueue.main.async {
                binding.wrappedValue = geometry.size.height
            }
            return Color.clear
        }
    }
}

#Preview {
    NavigationStack {
        RoutinesView()
            .environmentObject(AuthViewModel())
    }
}

