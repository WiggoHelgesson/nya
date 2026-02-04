import SwiftUI

struct CoachTabView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var coachRelation: CoachClientRelation?
    @State private var assignments: [CoachProgramAssignment] = []
    @State private var isLoading = true
    @State private var showChat = false
    @State private var selectedRoutineWrapper: SelectedRoutineWrapper?
    
    struct SelectedRoutineWrapper: Identifiable {
        let id: String
        let routine: ProgramRoutine
        let program: CoachProgram
        let coachName: String?
    }
    
    // Alla rutiner från alla program
    private var allRoutines: [(routine: ProgramRoutine, program: CoachProgram, coachName: String?)] {
        var result: [(ProgramRoutine, CoachProgram, String?)] = []
        for assignment in assignments {
            guard let program = assignment.program,
                  let routines = program.programData.routines else { continue }
            for routine in routines {
                result.append((routine, program, coachRelation?.coach?.username))
            }
        }
        return result
    }
    
    // Aktuellt program (första aktiva)
    private var currentProgram: CoachProgram? {
        assignments.first?.program
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    if isLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity, minHeight: 200)
                    } else if let coach = coachRelation?.coach {
                        // Coach Card
                        coachCard(coach: coach)
                        
                        // Program Info
                        if let program = currentProgram {
                            programInfoSection(program: program)
                        }
                        
                        // Routines List
                        if !allRoutines.isEmpty {
                            routinesSection
                        } else {
                            noRoutinesView
                        }
                    } else {
                        noCoachView
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 100)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Coach")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if coachRelation != nil {
                        Button {
                            showChat = true
                        } label: {
                            Image(systemName: "message")
                                .font(.system(size: 18))
                                .foregroundColor(.primary)
                        }
                    }
                }
            }
        }
        .task {
            await loadData()
        }
        .refreshable {
            await loadData()
        }
        .sheet(isPresented: $showChat) {
            CoachChatPlaceholderView()
        }
        .sheet(item: $selectedRoutineWrapper) { item in
            RoutineDetailSheet(
                routine: item.routine,
                program: item.program,
                coachName: item.coachName,
                onStart: {
                    selectedRoutineWrapper = nil
                    // TODO: Navigera till gym-pass med detta pass
                }
            )
        }
    }
    
    // MARK: - Coach Card
    
    private func coachCard(coach: CoachProfile) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 16) {
                // Avatar
                if let avatarUrl = coach.avatarUrl, !avatarUrl.isEmpty {
                    AsyncImage(url: URL(string: avatarUrl)) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Circle()
                            .fill(Color(.systemGray4))
                    }
                    .frame(width: 70, height: 70)
                    .clipShape(Circle())
                } else {
                    Circle()
                        .fill(Color(.systemGray4))
                        .frame(width: 70, height: 70)
                        .overlay(
                            Image(systemName: "person.fill")
                                .font(.system(size: 30))
                                .foregroundColor(.gray)
                        )
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(coach.username ?? "Din tränare")
                        .font(.system(size: 20, weight: .semibold))
                    
                    if let startedAt = coachRelation?.startedAt {
                        Text("Coach since \(formatDate(startedAt))")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
            }
            .padding(20)
        }
        .background(Color(.systemBackground))
        .cornerRadius(16)
    }
    
    // MARK: - Program Info Section
    
    private func programInfoSection(program: CoachProgram) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Program: \(program.title)")
                .font(.system(size: 17, weight: .semibold))
            
            if let assignment = assignments.first, let startDate = assignment.startDate {
                Text("Started on \(formatFullDate(startDate))")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 4)
    }
    
    // MARK: - Routines Section
    
    private var routinesSection: some View {
        VStack(spacing: 12) {
            ForEach(allRoutines, id: \.routine.id) { item in
                routineCard(routine: item.routine, program: item.program, coachName: item.coachName)
            }
        }
    }
    
    private func routineCard(routine: ProgramRoutine, program: CoachProgram, coachName: String?) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(routine.name)
                        .font(.system(size: 18, weight: .semibold))
                    
                    // Visa övningsnamn
                    let exerciseNames = routine.exercises.prefix(3).map { $0.name }.joined(separator: ", ")
                    if !exerciseNames.isEmpty {
                        Text(exerciseNames)
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
                
                Spacer()
                
                Menu {
                    Button {
                        selectedRoutineWrapper = SelectedRoutineWrapper(id: routine.id, routine: routine, program: program, coachName: coachName)
                    } label: {
                        Label("Visa detaljer", systemImage: "eye")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 18))
                        .foregroundColor(.secondary)
                        .frame(width: 32, height: 32)
                }
            }
            
            Button {
                selectedRoutineWrapper = SelectedRoutineWrapper(id: routine.id, routine: routine, program: program, coachName: coachName)
            } label: {
                Text("Start Routine")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.blue)
                    .cornerRadius(12)
            }
        }
        .padding(16)
        .background(Color(.systemBackground))
        .cornerRadius(16)
    }
    
    // MARK: - Empty States
    
    private var noRoutinesView: some View {
        VStack(spacing: 12) {
            Image(systemName: "dumbbell")
                .font(.system(size: 40))
                .foregroundColor(.gray)
            
            Text("Inga pass tilldelade")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.gray)
            
            Text("Din tränare har inte tilldelat dig några pass ännu")
                .font(.system(size: 14))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(40)
    }
    
    private var noCoachView: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.crop.circle.badge.questionmark")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text("Ingen aktiv coach")
                .font(.system(size: 18, weight: .semibold))
            
            Text("Du har ingen aktiv tränare just nu. När en tränare bjuder in dig och du accepterar kommer du se dem här.")
                .font(.system(size: 14))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, minHeight: 300)
    }
    
    // MARK: - Data Loading
    
    private func loadData() async {
        guard let userId = authViewModel.currentUser?.id else { return }
        
        do {
            async let coachTask = CoachService.shared.fetchMyCoach(for: userId)
            async let programsTask = CoachService.shared.fetchAssignedPrograms(for: userId)
            
            let (coach, programs) = try await (coachTask, programsTask)
            
            await MainActor.run {
                coachRelation = coach
                assignments = programs
                isLoading = false
            }
        } catch {
            print("❌ Failed to load coach data: \(error)")
            await MainActor.run {
                isLoading = false
            }
        }
    }
    
    // MARK: - Helpers
    
    private func formatDate(_ isoString: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        var date = formatter.date(from: isoString)
        if date == nil {
            formatter.formatOptions = [.withInternetDateTime]
            date = formatter.date(from: isoString)
        }
        
        guard let parsedDate = date else { return isoString }
        
        let displayFormatter = DateFormatter()
        displayFormatter.dateFormat = "dd MMM, yyyy"
        displayFormatter.locale = Locale(identifier: "en_US")
        return displayFormatter.string(from: parsedDate)
    }
    
    private func formatFullDate(_ isoString: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        var date = formatter.date(from: isoString)
        if date == nil {
            formatter.formatOptions = [.withInternetDateTime]
            date = formatter.date(from: isoString)
        }
        // Try date-only format
        if date == nil {
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            date = dateFormatter.date(from: isoString)
        }
        
        guard let parsedDate = date else { return isoString }
        
        let displayFormatter = DateFormatter()
        displayFormatter.dateFormat = "EEEE - d MMM, yyyy"
        displayFormatter.locale = Locale(identifier: "en_US")
        return displayFormatter.string(from: parsedDate)
    }
}

// MARK: - Chat Placeholder

struct CoachChatPlaceholderView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Spacer()
                
                Image(systemName: "bubble.left.and.bubble.right")
                    .font(.system(size: 60))
                    .foregroundColor(.blue.opacity(0.5))
                
                Text("Chatt kommer snart")
                    .font(.system(size: 22, weight: .bold))
                
                Text("Här kommer du kunna chatta direkt med din tränare")
                    .font(.system(size: 15))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                
                Spacer()
            }
            .navigationTitle("Chatt")
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

#Preview {
    CoachTabView()
        .environmentObject(AuthViewModel())
}
