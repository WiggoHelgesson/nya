import SwiftUI
import Supabase
import PostgREST
import Realtime

struct CoachTabView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var coachRelation: CoachClientRelation?
    @State private var assignments: [CoachProgramAssignment] = []
    @State private var isLoading = true
    @State private var showChat = false
    @State private var selectedRoutineWrapper: SelectedRoutineWrapper?
    @State private var coachTrainerProfile: GolfTrainer?
    @State private var realtimeChannel: RealtimeChannelV2?
    
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
        NavigationStack {
            VStack(spacing: 0) {
                // MARK: - Top Navigation (samma som Belöningar-sidan)
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
                                
                                // MARK: - Meddelande från tränaren
                                if let tip = tipForSelectedDay, !tip.isEmpty {
                                    VStack(alignment: .leading, spacing: 12) {
                                        Text("Dagens meddelande")
                                            .font(.system(size: 18, weight: .bold))
                                            .foregroundColor(.black)
                                            .padding(.horizontal, 20)
                                        
                                        coachTipCard(tip: tip)
                                            .padding(.horizontal, 16)
                                    }
                                }
                                
                                // MARK: - Mitt program
                                VStack(alignment: .leading, spacing: 12) {
                                    Text("Mitt program")
                                        .font(.system(size: 18, weight: .bold))
                                        .foregroundColor(.black)
                                        .padding(.horizontal, 20)
                                    
                                    if let program = currentProgram {
                                        programInfoCard(program: program)
                                            .padding(.horizontal, 16)
                                    }
                                }
                                
                                // MARK: - Coach Info & Chat Button (längst ner)
                                if let coach = coachRelation?.coach {
                                    VStack(spacing: 12) {
                                        // Coach avatar & name
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
                                        
                                        // "Skriv med tränaren" button
                                        Button {
                                            // If profile already loaded, open chat immediately
                                            if coachTrainerProfile != nil {
                                                showChat = true
                                            } else {
                                                // Load profile first, then open chat
                                                Task {
                                                    if let coachId = coachRelation?.coachId {
                                                        await loadCoachTrainerProfile(coachUserId: coachId)
                                                        await MainActor.run {
                                                            if coachTrainerProfile != nil {
                                                                showChat = true
                                                            }
                                                        }
                                                    }
                                                }
                                            }
                                        } label: {
                                            HStack(spacing: 8) {
                                                Image(systemName: "bubble.left.and.bubble.right.fill")
                                                    .font(.system(size: 16))
                                                Text("Skriv med tränaren")
                                                    .font(.system(size: 16, weight: .semibold))
                                            }
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
                                    .padding(.horizontal, 16)
                                }
                                
                                Spacer(minLength: 120)
                            }
                            .padding(.top, 0)
                        }
                    } else {
                        noCoachView
                    }
                }
            }
            .navigationBarHidden(true)
        }
        .task {
            generateWeekDates()
            await loadData()
            await setupRealtimeListener()
        }
        .refreshable {
            await loadData()
        }
        .onDisappear {
            // Clean up realtime channel when view disappears
            Task {
                await realtimeChannel?.unsubscribe()
                realtimeChannel = nil
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("OpenCoachChat"))) { _ in
            if coachTrainerProfile != nil {
                showChat = true
            }
        }
        .sheet(isPresented: $showChat) {
            NavigationStack {
                if let trainer = coachTrainerProfile {
                    TrainerChatView(trainer: trainer)
                        .toolbar {
                            ToolbarItem(placement: .navigationBarTrailing) {
                                Button("Stäng") {
                                    showChat = false
                                }
                                .foregroundColor(.black)
                            }
                        }
                } else {
                    // If no trainer profile, close sheet immediately
                    Color.clear
                        .task {
                            // Try one quick load attempt
                            if let coachId = coachRelation?.coachId {
                                await loadCoachTrainerProfile(coachUserId: coachId)
                                // If still no profile after load, close sheet
                                if coachTrainerProfile == nil {
                                    await MainActor.run {
                                        showChat = false
                                    }
                                }
                            } else {
                                // No coachId, close immediately
                                await MainActor.run {
                                    showChat = false
                                }
                            }
                        }
                }
            }
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
            VStack(alignment: .leading, spacing: 4) {
                Text(routine.name)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.black)
                
                Text("\(routine.exercises.count) övningar")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
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
        VStack(alignment: .leading, spacing: 12) {
            // Tränare info rad
            HStack(spacing: 10) {
                // Tränarens profilbild
                if let avatarUrl = coachRelation?.coach?.avatarUrl, !avatarUrl.isEmpty {
                    AsyncImage(url: URL(string: avatarUrl)) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Circle()
                            .fill(Color(.systemGray4))
                    }
                    .frame(width: 36, height: 36)
                    .clipShape(Circle())
                } else {
                    Circle()
                        .fill(Color(.systemGray4))
                        .frame(width: 36, height: 36)
                        .overlay(
                            Image(systemName: "person.fill")
                                .font(.system(size: 16))
                                .foregroundColor(.gray)
                        )
                }
                
                Text("Meddelande från \(coachRelation?.coach?.username ?? "tränaren")")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.secondary)
            }
            
            // Meddelande
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
    
    // MARK: - Program Info Card
    
    private func programInfoCard(program: CoachProgram) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(program.title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.black)
                
                if let note = program.note, !note.isEmpty {
                    Text(note)
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
            }
            
            Spacer()
            
            if let routines = program.programData.routines {
                VStack(alignment: .trailing, spacing: 4) {
                    Text("\(routines.count)")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.black)
                    
                    Text("pass")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
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
            // Fetch coach first to get coachId
            let coach = try await CoachService.shared.fetchMyCoach(for: userId)
            
            // If we have a coach, load profile and programs in parallel
            if let coachId = coach?.coachId {
                async let profileTask = loadCoachTrainerProfileAsync(coachUserId: coachId)
                async let programsTask = CoachService.shared.fetchAssignedPrograms(for: userId)
                
                let (_, programs) = try await (profileTask, programsTask)
                
                await MainActor.run {
                    coachRelation = coach
                    assignments = programs
                    isLoading = false
                    updateWorkoutStatus()
                }
            } else {
                // No coach, just load programs
                let programs = try await CoachService.shared.fetchAssignedPrograms(for: userId)
                
                await MainActor.run {
                    coachRelation = coach
                    assignments = programs
                    isLoading = false
                    updateWorkoutStatus()
                }
            }
        } catch {
            print("❌ Failed to load coach data: \(error)")
            await MainActor.run {
                isLoading = false
            }
        }
    }
    
    // MARK: - Realtime Listener
    
    /// Listen for changes to coach programs and assignments in real-time
    private func setupRealtimeListener() async {
        guard let userId = authViewModel.currentUser?.id else { return }
        
        // Clean up any existing channel
        if let existing = realtimeChannel {
            await existing.unsubscribe()
        }
        
        let channel = SupabaseConfig.supabase.channel("coach-updates-\(userId)")
        
        // Listen for new program assignments
        let newAssignments = channel.postgresChange(
            InsertAction.self,
            schema: "public",
            table: "coach_program_assignments",
            filter: "client_id=eq.\(userId)"
        )
        
        // Listen for assignment status changes (active → paused, etc.)
        let assignmentUpdates = channel.postgresChange(
            UpdateAction.self,
            schema: "public",
            table: "coach_program_assignments",
            filter: "client_id=eq.\(userId)"
        )
        
        // Listen for program updates (schedule changes, daily tips, etc.)
        let programUpdates = channel.postgresChange(
            UpdateAction.self,
            schema: "public",
            table: "coach_programs"
        )
        
        await channel.subscribe()
        realtimeChannel = channel
        
        print("📡 [COACH] Realtime listener set up for user \(userId)")
        
        // Listen for new assignments
        Task {
            for await _ in newAssignments {
                print("📡 [COACH] New program assigned - reloading data")
                await loadData()
            }
        }
        
        // Listen for assignment updates
        Task {
            for await _ in assignmentUpdates {
                print("📡 [COACH] Program assignment updated - reloading data")
                await loadData()
            }
        }
        
        // Listen for program changes (schedule, tips, etc.)
        Task {
            for await _ in programUpdates {
                print("📡 [COACH] Program updated - reloading data")
                await loadData()
            }
        }
    }
    
    /// Fetch the trainer_profiles entry for this coach so we can open chat
    private func loadCoachTrainerProfile(coachUserId: String) async {
        do {
            let trainers: [GolfTrainer] = try await SupabaseConfig.supabase
                .from("trainer_profiles")
                .select()
                .eq("user_id", value: coachUserId)
                .limit(1)
                .execute()
                .value
            
            if let trainer = trainers.first {
                await MainActor.run {
                    coachTrainerProfile = trainer
                }
                print("✅ Loaded coach trainer profile: \(trainer.name)")
            } else {
                print("⚠️ Coach has no trainer_profiles entry, chat will use placeholder")
            }
        } catch {
            print("❌ Failed to load coach trainer profile: \(error)")
        }
    }
    
    private func loadCoachTrainerProfileAsync(coachUserId: String) async throws {
        let trainers: [GolfTrainer] = try await SupabaseConfig.supabase
            .from("trainer_profiles")
            .select()
            .eq("user_id", value: coachUserId)
            .limit(1)
            .execute()
            .value
        
        if let trainer = trainers.first {
            await MainActor.run {
                coachTrainerProfile = trainer
            }
            print("✅ Loaded coach trainer profile: \(trainer.name)")
        } else {
            print("⚠️ Coach has no trainer_profiles entry, chat will use placeholder")
        }
    }
}

// MARK: - Coach Header View

struct CoachHeaderView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @Binding var showChat: Bool
    let hasCoach: Bool
    
    @State private var showMonthlyPrize = false
    @State private var showNonProAlert = false
    @State private var showPublicProfile = false
    @State private var unreadNotifications = 0
    @State private var isFetchingUnread = false
    
    private var isPremium: Bool {
        authViewModel.currentUser?.isProMember ?? false
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Top Row: Profile pic | Månadens pris | Find friends + Bell
            ZStack {
                // Center: Månadens pris
                Button {
                    if isPremium {
                        showMonthlyPrize = true
                    } else {
                        showNonProAlert = true
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "trophy.fill")
                            .font(.system(size: 13, weight: .semibold))
                        Text("Månadens pris")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 9)
                    .background(Color.black)
                    .cornerRadius(20)
                }
                .buttonStyle(.plain)
                
                // Left and Right sides
                HStack {
                    // Profile picture
                    Button {
                        showPublicProfile = true
                    } label: {
                        ProfileImage(url: authViewModel.currentUser?.avatarUrl, size: 36)
                            .overlay(
                                Circle()
                                    .stroke(Color.black.opacity(0.1), lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                    
                    Spacer()
                    
                    // Find Friends + Notifications
                    HStack(spacing: 12) {
                        // Find friends
                        NavigationLink(destination: FindFriendsView().environmentObject(authViewModel)) {
                            Image(systemName: "person.badge.plus")
                                .font(.system(size: 22, weight: .regular))
                                .foregroundColor(.primary)
                                .frame(width: 36, height: 36)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        
                        // Notification bell
                        NavigationLink(destination: NotificationsView(onDismiss: {
                            Task { await refreshUnreadCount() }
                        }).environmentObject(authViewModel)) {
                            ZStack(alignment: .topTrailing) {
                                Image(systemName: "bell")
                                    .font(.system(size: 22, weight: .regular))
                                    .foregroundColor(.primary)
                                
                                // Notification badge
                                if unreadNotifications > 0 {
                                    Circle()
                                        .fill(Color.black)
                                        .frame(width: 18, height: 18)
                                        .overlay(
                                            Text("\(min(unreadNotifications, 99))")
                                                .font(.system(size: 10, weight: .bold))
                                                .foregroundColor(.white)
                                        )
                                        .offset(x: 8, y: -6)
                                }
                            }
                            .frame(width: 36, height: 36)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 16)
        }
        .background(Color(.systemBackground))
        .shadow(color: Color.black.opacity(0.15), radius: 8, x: 0, y: 4)
        .zIndex(2)
        .task {
            await refreshUnreadCount()
        }
        .sheet(isPresented: $showMonthlyPrize) {
            MonthlyPrizeView()
                .environmentObject(authViewModel)
        }
        .sheet(isPresented: $showPublicProfile) {
            if let userId = authViewModel.currentUser?.id {
                NavigationStack {
                    UserProfileView(userId: userId)
                        .environmentObject(authViewModel)
                        .toolbar {
                            ToolbarItem(placement: .navigationBarLeading) {
                                Button("Stäng") {
                                    showPublicProfile = false
                                }
                            }
                        }
                }
            }
        }
        .alert("Enbart för pro medlemmar", isPresented: $showNonProAlert) {
            Button("Stäng", role: .cancel) { }
            Button("Bli Pro") {
                showNonProAlert = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    SuperwallService.shared.showPaywall()
                }
            }
        } message: {
            Text("Uppgradera till Pro för att delta i månadens tävling och vinna häftiga priser!")
        }
    }
    
    private func refreshUnreadCount() async {
        guard !isFetchingUnread else { return }
        guard let userId = authViewModel.currentUser?.id else {
            await MainActor.run { unreadNotifications = 0 }
            return
        }
        isFetchingUnread = true
        do {
            let count = try await NotificationService.shared.fetchUnreadCount(userId: userId)
            await MainActor.run {
                unreadNotifications = count
            }
        } catch {
            print("⚠️ Failed to fetch unread notifications: \(error)")
        }
        isFetchingUnread = false
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
