import SwiftUI

// MARK: - Coach Programs Sheet (Pass från tränare)

struct CoachProgramsSheet: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @ObservedObject var viewModel: GymSessionViewModel
    @Binding var isPresented: Bool
    
    @State private var assignments: [CoachProgramAssignment] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var selectedRoutine: (routine: ProgramRoutine, program: CoachProgram, coachName: String?)?
    @State private var showRoutineDetail: ProgramRoutine?
    
    // Alla pass från alla program, platt lista
    private var allRoutines: [(routine: ProgramRoutine, program: CoachProgram, coachName: String?)] {
        var result: [(ProgramRoutine, CoachProgram, String?)] = []
        for assignment in assignments {
            guard let program = assignment.program,
                  let routines = program.programData.routines else { continue }
            for routine in routines {
                result.append((routine, program, assignment.coach?.username))
            }
        }
        return result
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let error = errorMessage {
                    errorView(error)
                } else if allRoutines.isEmpty {
                    emptyStateView
                } else {
                    routinesList
                }
            }
            .navigationTitle("Pass från tränare")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Klar") {
                        isPresented = false
                    }
                    .font(.system(size: 16, weight: .semibold))
                }
            }
        }
        .task {
            await loadPrograms()
        }
        .sheet(item: $showRoutineDetail) { routine in
            if let match = allRoutines.first(where: { $0.routine.id == routine.id }) {
                RoutineDetailSheet(
                    routine: match.routine,
                    program: match.program,
                    coachName: match.coachName,
                    onStart: {
                        showRoutineDetail = nil
                        startRoutine(match.routine, from: match.program, coachName: match.coachName)
                    }
                )
            }
        }
    }
    
    // MARK: - Routines List (platt lista med alla pass)
    
    private var routinesList: some View {
        List {
            ForEach(allRoutines, id: \.routine.id) { item in
                Button {
                    showRoutineDetail = item.routine
                } label: {
                    HStack(spacing: 14) {
                        // Ikon
                        ZStack {
                            Circle()
                                .fill(Color.black.opacity(0.1))
                                .frame(width: 50, height: 50)
                            
                            Image(systemName: "dumbbell.fill")
                                .font(.system(size: 20))
                                .foregroundColor(.black)
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.routine.name)
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundColor(.primary)
                            
                            HStack(spacing: 8) {
                                Text("\(item.routine.exercises.count) övningar")
                                    .font(.system(size: 14))
                                    .foregroundColor(.secondary)
                                
                                Text("•")
                                    .foregroundColor(.secondary)
                                
                                Text("Från \(item.coachName ?? "tränare")")
                                    .font(.system(size: 14))
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 8)
                }
            }
        }
        .listStyle(.insetGrouped)
    }
    
    // MARK: - Empty State
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.crop.rectangle.badge.plus")
                .font(.system(size: 48))
                .foregroundColor(.gray)
            
            Text("Inga pass från tränare")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.gray)
            
            Text("När din tränare tilldelar dig ett träningsprogram kommer det att visas här")
                .font(.system(size: 14))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Error View
    
    private func errorView(_ message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundColor(.orange)
            
            Text("Kunde inte ladda program")
                .font(.system(size: 16, weight: .medium))
            
            Text(message)
                .font(.system(size: 14))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            
            Button("Försök igen") {
                Task { await loadPrograms() }
            }
            .font(.system(size: 15, weight: .semibold))
            .foregroundColor(.white)
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(Color.black)
            .cornerRadius(20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Actions
    
    private func loadPrograms() async {
        guard let userId = authViewModel.currentUser?.id else { return }
        
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }
        
        do {
            let fetched = try await CoachService.shared.fetchAssignedPrograms(for: userId)
            
            // Debug: Logga vad som kom
            for assignment in fetched {
                if let program = assignment.program {
                    print("📋 Program: \(program.title)")
                    if let routines = program.programData.routines {
                        for routine in routines {
                            print("  └─ Rutin: \(routine.name) (\(routine.exercises.count) övningar)")
                            for exercise in routine.exercises {
                                print("      └─ Övning: \(exercise.name), \(exercise.sets) sets x \(exercise.reps) reps")
                            }
                        }
                    } else {
                        print("  └─ Inga rutiner hittades i programData")
                    }
                }
            }
            
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
    
    private func startRoutine(_ routine: ProgramRoutine, from program: CoachProgram, coachName: String?) {
        // Konvertera till format som GymSessionViewModel förstår
        let savedWorkout = CoachService.shared.convertRoutineToSavedWorkout(routine, programTitle: program.title, coachName: coachName)
        
        // Debug
        print("🏋️ Starting routine: \(routine.name)")
        print("   Exercises: \(savedWorkout.exercises.count)")
        for ex in savedWorkout.exercises {
            print("   - \(ex.name): \(ex.sets) sets, reps: \(ex.reps), kg: \(ex.kg)")
        }
        
        // Applicera på gym-sessionen
        viewModel.applySavedWorkout(savedWorkout)
        
        // Stäng sheeten
        isPresented = false
    }
}

// MARK: - Routine Detail Sheet

struct RoutineDetailSheet: View {
    let routine: ProgramRoutine
    let program: CoachProgram
    let coachName: String?
    let onStart: () -> Void
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header
                    VStack(alignment: .leading, spacing: 8) {
                        Text(routine.name)
                            .font(.system(size: 28, weight: .bold))
                        
                        HStack {
                            Label("\(routine.exercises.count) övningar", systemImage: "dumbbell.fill")
                            Text("•")
                            Text("Från \(coachName ?? "din tränare")")
                        }
                        .font(.system(size: 15))
                        .foregroundColor(.secondary)
                        
                        if let note = routine.note, !note.isEmpty {
                            Text(note)
                                .font(.system(size: 15))
                                .foregroundColor(.secondary)
                                .padding(.top, 4)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    
                    // Övningslista
                    VStack(spacing: 0) {
                        ForEach(Array(routine.exercises.enumerated()), id: \.element.id) { index, exercise in
                            HStack(spacing: 14) {
                                // Nummer
                                ZStack {
                                    Circle()
                                        .fill(Color(.systemGray5))
                                        .frame(width: 36, height: 36)
                                    
                                    Text("\(index + 1)")
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundColor(.primary)
                                }
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(exercise.name)
                                        .font(.system(size: 16, weight: .medium))
                                    
                                    Text("\(exercise.sets) set × \(exercise.reps) reps")
                                        .font(.system(size: 14))
                                        .foregroundColor(.secondary)
                                    
                                    if let notes = exercise.notes, !notes.isEmpty {
                                        Text(notes)
                                            .font(.system(size: 13))
                                            .foregroundColor(.orange)
                                            .padding(.top, 2)
                                    }
                                }
                                
                                Spacer()
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 12)
                            
                            if index < routine.exercises.count - 1 {
                                Divider()
                                    .padding(.leading, 70)
                            }
                        }
                    }
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
                    .padding(.horizontal, 16)
                    
                    if routine.exercises.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "exclamationmark.triangle")
                                .font(.system(size: 32))
                                .foregroundColor(.orange)
                            
                            Text("Inga övningar i detta pass")
                                .font(.system(size: 15))
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                    }
                }
                .padding(.bottom, 100)
            }
            .background(Color(.systemGroupedBackground))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Stäng") {
                        dismiss()
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                VStack {
                    Button {
                        onStart()
                    } label: {
                        HStack {
                            Image(systemName: "play.fill")
                            Text("Starta pass")
                        }
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(routine.exercises.isEmpty ? Color.gray : Color.black)
                        .cornerRadius(14)
                    }
                    .disabled(routine.exercises.isEmpty)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 8)
                }
                .background(Color(.systemBackground))
            }
        }
    }
}

// MARK: - Coach Invitation View

struct CoachInvitationView: View {
    let invitation: CoachInvitation
    let onAccept: () -> Void
    let onDecline: () -> Void
    
    @State private var isAccepting = false
    @State private var isDeclining = false
    
    var body: some View {
        VStack(spacing: 24) {
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
                .frame(width: 80, height: 80)
                .clipShape(Circle())
            } else {
                Circle()
                    .fill(Color(.systemGray5))
                    .frame(width: 80, height: 80)
                    .overlay(
                        Image(systemName: "person.fill")
                            .font(.system(size: 32))
                            .foregroundColor(.gray)
                    )
            }
            
            // Coach name
            VStack(spacing: 8) {
                Text(invitation.coach?.displayName ?? "En tränare")
                    .font(.system(size: 22, weight: .bold))
                
                Text("vill coacha dig!")
                    .font(.system(size: 17))
                    .foregroundColor(.secondary)
            }
            
            // Buttons
            VStack(spacing: 12) {
                Button {
                    acceptInvitation()
                } label: {
                    HStack {
                        if isAccepting {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Text("Acceptera")
                        }
                    }
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.black)
                    .cornerRadius(12)
                }
                .disabled(isAccepting || isDeclining)
                
                Button {
                    declineInvitation()
                } label: {
                    HStack {
                        if isDeclining {
                            ProgressView()
                        } else {
                            Text("Nej tack")
                        }
                    }
                    .font(.system(size: 17, weight: .medium))
                    .foregroundColor(.primary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                }
                .disabled(isAccepting || isDeclining)
            }
            .padding(.horizontal, 24)
            .padding(.top, 8)
        }
        .padding(.vertical, 32)
    }
    
    private func acceptInvitation() {
        isAccepting = true
        Task {
            do {
                try await CoachService.shared.acceptCoachInvitation(invitationId: invitation.id)
                await MainActor.run {
                    onAccept()
                }
            } catch {
                print("❌ Failed to accept invitation: \(error)")
                await MainActor.run {
                    isAccepting = false
                }
            }
        }
    }
    
    private func declineInvitation() {
        isDeclining = true
        Task {
            do {
                try await CoachService.shared.declineCoachInvitation(invitationId: invitation.id)
                await MainActor.run {
                    onDecline()
                }
            } catch {
                print("❌ Failed to decline invitation: \(error)")
                await MainActor.run {
                    isDeclining = false
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    CoachProgramsSheet(
        viewModel: GymSessionViewModel(),
        isPresented: .constant(true)
    )
    .environmentObject(AuthViewModel())
}
