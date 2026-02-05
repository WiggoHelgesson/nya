import SwiftUI

struct CoachTabView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var coachRelation: CoachClientRelation?
    @State private var assignments: [CoachProgramAssignment] = []
    @State private var isLoading = true
    @State private var showChat = false
    @State private var selectedRoutineWrapper: SelectedRoutineWrapper?
    
    // Day selection
    @State private var selectedDate: Date = Date()
    @State private var weeks: [WeekInfo] = []
    @State private var currentWeekIndex: Int = 4
    
    struct SelectedRoutineWrapper: Identifiable {
        let id: String
        let routine: ProgramRoutine
        let program: CoachProgram
        let coachName: String?
    }
    
    // Week/Day models
    struct WeekInfo: Identifiable {
        let id = UUID()
        var days: [DayInfo]
        let weekNumber: Int
        var containsSelectedDate: Bool
        var containsToday: Bool
    }
    
    struct DayInfo: Identifiable {
        let id = UUID()
        let date: Date
        let dayLetter: String
        let dayNumber: Int
        var isSelected: Bool
        let isToday: Bool
        var hasWorkout: Bool
    }
    
    // Weekday index from selected date (0 = Monday, 6 = Sunday)
    private var selectedWeekdayIndex: Int {
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: selectedDate)
        return (weekday + 5) % 7 // Convert to Monday = 0
    }
    
    // Rutiner för vald dag
    private var routinesForSelectedDay: [(routine: ProgramRoutine, program: CoachProgram, coachName: String?)] {
        var result: [(ProgramRoutine, CoachProgram, String?)] = []
        for assignment in assignments {
            guard let program = assignment.program,
                  let routines = program.programData.routines else { continue }
            for routine in routines {
                // Kolla om rutinen är tilldelad för denna veckodag
                if let scheduledDays = routine.scheduledDays, scheduledDays.contains(selectedWeekdayIndex) {
                    result.append((routine, program, coachRelation?.coach?.username))
                } else if routine.scheduledDays == nil {
                    // Om ingen schemaläggning finns, visa alla
                    result.append((routine, program, coachRelation?.coach?.username))
                }
            }
        }
        return result
    }
    
    // Tips för vald dag
    private var tipForSelectedDay: String? {
        for assignment in assignments {
            guard let program = assignment.program else { continue }
            if let dailyTips = program.dailyTips,
               selectedWeekdayIndex < dailyTips.count {
                return dailyTips[selectedWeekdayIndex]
            }
        }
        return nil
    }
    
    // Aktuellt program
    private var currentProgram: CoachProgram? {
        assignments.first?.program
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // MARK: - Top Navigation (samma som andra sidor)
            CoachHeaderView(showChat: $showChat, hasCoach: coachRelation != nil)
                .environmentObject(authViewModel)
            
            ZStack {
                // Background
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()
                
                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if coachRelation != nil {
                    ScrollView {
                        VStack(spacing: 16) {
                            // MARK: - Day Picker
                            weekCalendarView
                                .padding(.top, 8)
                            
                            // MARK: - Dagens träning
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Dagens träning")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(.black)
                                    .padding(.horizontal, 20)
                                
                                if routinesForSelectedDay.isEmpty {
                                    noWorkoutForDayView
                                        .padding(.horizontal, 16)
                                } else {
                                    ForEach(routinesForSelectedDay, id: \.routine.id) { item in
                                        routineCard(routine: item.routine, program: item.program, coachName: item.coachName)
                                            .padding(.horizontal, 16)
                                    }
                                }
                            }
                            
                            // MARK: - Tips från tränaren
                            if let tip = tipForSelectedDay, !tip.isEmpty {
                                VStack(alignment: .leading, spacing: 12) {
                                    Text("Tips från tränaren")
                                        .font(.system(size: 18, weight: .bold))
                                        .foregroundColor(.black)
                                        .padding(.horizontal, 20)
                                    
                                    coachTipCard(tip: tip)
                                        .padding(.horizontal, 16)
                                }
                            }
                            
                            // MARK: - Program & Tränare info
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Mitt program")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(.black)
                                    .padding(.horizontal, 20)
                                
                                if let coach = coachRelation?.coach {
                                    coachAndProgramCard(coach: coach)
                                        .padding(.horizontal, 16)
                                }
                            }
                            
                            Spacer(minLength: 120)
                        }
                        .padding(.top, 8)
                    }
                } else {
                    noCoachView
                }
            }
        }
        .task {
            generateWeekDates()
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
                }
            )
        }
    }
    
    // MARK: - Week Calendar View
    
    private var weekCalendarView: some View {
        let weeksCount = weeks.count
        return TabView(selection: $currentWeekIndex) {
            ForEach(0..<weeksCount, id: \.self) { index in
                weekView(week: weeks[index])
                    .tag(index)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .frame(height: 100)
    }
    
    private func weekView(week: WeekInfo) -> some View {
        HStack(spacing: 0) {
            ForEach(week.days) { dayInfo in
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        selectDate(dayInfo.date)
                    }
                } label: {
                    VStack(spacing: 8) {
                        Text(dayInfo.dayLetter)
                            .font(.system(size: 13, weight: dayInfo.isSelected || dayInfo.isToday ? .semibold : .medium))
                            .foregroundColor(dayInfo.isSelected ? .black : (dayInfo.isToday ? Color.black.opacity(0.7) : Color.gray.opacity(0.6)))
                        
                        ZStack {
                            // Ring - solid för idag/vald, dashed för workout
                            if dayInfo.isSelected {
                                Circle()
                                    .stroke(Color.black, lineWidth: 2)
                                    .frame(width: 40, height: 40)
                            } else if dayInfo.isToday {
                                Circle()
                                    .stroke(Color.black.opacity(0.3), lineWidth: 1.5)
                                    .frame(width: 40, height: 40)
                            } else if dayInfo.hasWorkout {
                                Circle()
                                    .stroke(Color.black.opacity(0.2), style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                                    .frame(width: 40, height: 40)
                            } else {
                                Circle()
                                    .stroke(Color.gray.opacity(0.2), style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                                    .frame(width: 40, height: 40)
                            }
                            
                            Text("\(dayInfo.dayNumber)")
                                .font(.system(size: 15, weight: dayInfo.isSelected || dayInfo.isToday ? .bold : .medium))
                                .foregroundColor(dayInfo.isSelected ? .black : (dayInfo.isToday ? Color.black.opacity(0.85) : Color.black.opacity(0.7)))
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
    }
    
    // MARK: - Routine Card
    
    private func routineCard(routine: ProgramRoutine, program: CoachProgram, coachName: String?) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(routine.name)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.black)
                    
                    Text("\(routine.exercises.count) övningar")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
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
            
            // Övningslista (max 3)
            let exerciseNames = routine.exercises.prefix(3).map { $0.name }.joined(separator: " • ")
            if !exerciseNames.isEmpty {
                Text(exerciseNames)
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            
            Button {
                startCoachWorkout(routine: routine, program: program, coachName: coachName)
            } label: {
                Text("Starta pass")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.black)
                    .cornerRadius(12)
            }
        }
        .padding(16)
        .background(Color(.systemBackground))
        .cornerRadius(16)
    }
    
    // MARK: - Start Coach Workout
    
    private func startCoachWorkout(routine: ProgramRoutine, program: CoachProgram, coachName: String?) {
        // Convert routine to SavedGymWorkout
        let workout = CoachService.shared.convertRoutineToSavedWorkout(routine, programTitle: program.title, coachName: coachName)
        
        // Send notification to start gym session with this workout
        NotificationCenter.default.post(
            name: NSNotification.Name("StartCoachWorkout"),
            object: workout
        )
    }
    
    // MARK: - Coach Tip Card
    
    private func coachTipCard(tip: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "lightbulb.fill")
                .font(.system(size: 20))
                .foregroundColor(.orange)
            
            Text(tip)
                .font(.system(size: 15))
                .foregroundColor(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemBackground))
        .cornerRadius(16)
    }
    
    // MARK: - Coach and Program Card
    
    private func coachAndProgramCard(coach: CoachProfile) -> some View {
        VStack(spacing: 16) {
            // Coach info
            HStack(spacing: 14) {
                if let avatarUrl = coach.avatarUrl, !avatarUrl.isEmpty {
                    AsyncImage(url: URL(string: avatarUrl)) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Circle()
                            .fill(Color(.systemGray4))
                    }
                    .frame(width: 56, height: 56)
                    .clipShape(Circle())
                } else {
                    Circle()
                        .fill(Color(.systemGray4))
                        .frame(width: 56, height: 56)
                        .overlay(
                            Image(systemName: "person.fill")
                                .font(.system(size: 24))
                                .foregroundColor(.gray)
                        )
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(coach.username ?? "Din tränare")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.black)
                    
                    Text("Din personliga tränare")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            
            // Program info
            if let program = currentProgram {
                Divider()
                
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Program")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                        
                        Text(program.title)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.black)
                    }
                    
                    Spacer()
                    
                    if let routines = program.programData.routines {
                        VStack(alignment: .trailing, spacing: 4) {
                            Text("Pass")
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                            
                            Text("\(routines.count)")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.black)
                        }
                    }
                }
            }
        }
        .padding(16)
        .background(Color(.systemBackground))
        .cornerRadius(16)
    }
    
    // MARK: - No Workout View
    
    private var noWorkoutForDayView: some View {
        VStack(spacing: 12) {
            Image(systemName: "moon.zzz.fill")
                .font(.system(size: 36))
                .foregroundColor(.gray.opacity(0.5))
            
            Text("Vilodag")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.primary)
            
            Text("Inga pass schemalagda för denna dag")
                .font(.system(size: 14))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .background(Color(.systemBackground))
        .cornerRadius(16)
    }
    
    // MARK: - No Coach View
    
    private var noCoachView: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.crop.circle.badge.questionmark")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text("Ingen aktiv tränare")
                .font(.system(size: 18, weight: .semibold))
            
            Text("Du har ingen aktiv tränare just nu. När en tränare bjuder in dig och du accepterar kommer du se dem här.")
                .font(.system(size: 14))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, minHeight: 300)
    }
    
    // MARK: - Date Helpers
    
    private func selectDate(_ date: Date) {
        selectedDate = date
        
        // Update week selection status
        for i in 0..<weeks.count {
            for j in 0..<weeks[i].days.count {
                weeks[i].days[j].isSelected = Calendar.current.isDate(weeks[i].days[j].date, inSameDayAs: date)
            }
            weeks[i].containsSelectedDate = weeks[i].days.contains { $0.isSelected }
        }
        
        // Update hasWorkout for days
        updateWorkoutStatus()
    }
    
    private func generateWeekDates() {
        var calendar = Calendar.current
        calendar.firstWeekday = 2 // Monday = 2
        let today = calendar.startOfDay(for: Date())
        
        let weekday = calendar.component(.weekday, from: today)
        let daysFromMonday = (weekday + 5) % 7
        guard let mondayOfCurrentWeek = calendar.date(byAdding: .day, value: -daysFromMonday, to: today) else { return }
        
        var allWeeks: [WeekInfo] = []
        let dayLetters = ["Mån", "Tis", "Ons", "Tor", "Fre", "Lör", "Sön"]
        
        for weekOffset in -4...3 {
            guard let weekStart = calendar.date(byAdding: .weekOfYear, value: weekOffset, to: mondayOfCurrentWeek) else { continue }
            
            var days: [DayInfo] = []
            var containsSelected = false
            var containsToday = false
            
            for dayOffset in 0..<7 {
                guard let date = calendar.date(byAdding: .day, value: dayOffset, to: weekStart) else { continue }
                
                let dayNumber = calendar.component(.day, from: date)
                let isSelected = calendar.isDate(date, inSameDayAs: selectedDate)
                let isToday = calendar.isDate(date, inSameDayAs: today)
                
                if isSelected { containsSelected = true }
                if isToday { containsToday = true }
                
                days.append(DayInfo(
                    date: date,
                    dayLetter: dayLetters[dayOffset],
                    dayNumber: dayNumber,
                    isSelected: isSelected,
                    isToday: isToday,
                    hasWorkout: false
                ))
            }
            
            let weekNumber = calendar.component(.weekOfYear, from: weekStart)
            allWeeks.append(WeekInfo(
                days: days,
                weekNumber: weekNumber,
                containsSelectedDate: containsSelected,
                containsToday: containsToday
            ))
        }
        
        self.weeks = allWeeks
        
        if let index = allWeeks.firstIndex(where: { $0.containsSelectedDate }) {
            self.currentWeekIndex = index
        }
    }
    
    private func updateWorkoutStatus() {
        // Markera vilka dagar som har pass schemalagda
        for i in 0..<weeks.count {
            for j in 0..<weeks[i].days.count {
                let dayIndex = j // 0 = Monday
                var hasWorkout = false
                
                for assignment in assignments {
                    guard let program = assignment.program,
                          let routines = program.programData.routines else { continue }
                    for routine in routines {
                        if let scheduledDays = routine.scheduledDays, scheduledDays.contains(dayIndex) {
                            hasWorkout = true
                            break
                        }
                    }
                    if hasWorkout { break }
                }
                
                weeks[i].days[j].hasWorkout = hasWorkout
            }
        }
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
                updateWorkoutStatus()
            }
        } catch {
            print("❌ Failed to load coach data: \(error)")
            await MainActor.run {
                isLoading = false
            }
        }
    }
}

// MARK: - Coach Header View

struct CoachHeaderView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @Binding var showChat: Bool
    let hasCoach: Bool
    
    var body: some View {
        HStack {
            Spacer()
            
            Text("Coach")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.black)
            
            Spacer()
        }
        .overlay(alignment: .trailing) {
            if hasCoach {
                Button {
                    showChat = true
                } label: {
                    Image(systemName: "message")
                        .font(.system(size: 18))
                        .foregroundColor(.black)
                }
                .padding(.trailing, 16)
            }
        }
        .padding(.vertical, 12)
        .background(Color(.systemBackground))
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
                    .foregroundColor(.black.opacity(0.3))
                
                Text("Chatt kommer snart")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.black)
                
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
                    .foregroundColor(.black)
                }
            }
        }
    }
}

#Preview {
    CoachTabView()
        .environmentObject(AuthViewModel())
}
