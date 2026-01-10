import SwiftUI

// MARK: - Sport Type Filter
enum SportType: String, CaseIterable, Identifiable {
    case gym = "Gym"
    case running = "Löpning"
    case golf = "Golf"
    case skiing = "Skidor"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .gym: return "dumbbell.fill"
        case .running: return "figure.run"
        case .golf: return "figure.golf"
        case .skiing: return "figure.skiing.downhill"
        }
    }
    
    var activityTypes: [String] {
        switch self {
        case .gym: return ["gym", "weight_training", "strength"]
        case .running: return ["run", "running", "trail_run"]
        case .golf: return ["golf"]
        case .skiing: return ["skiing", "ski", "alpine_skiing", "cross_country_skiing"]
        }
    }
}

struct StatisticsView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    
    @State private var selectedSport: SportType = .gym
    @State private var allPosts: [WorkoutPost] = []
    @State private var isLoading = true
    @State private var progressStats: ProgressStats = ProgressStats()
    @State private var weeklyData: [WeekData] = []
    @State private var workoutDays: Set<Int> = []
    @State private var currentStreak: Int = 0
    @State private var streakActivities: Int = 0
    @State private var exerciseHistories: [StatExerciseHistory] = []
    
    private let calendar = Calendar.current
    
    private var filteredPosts: [WorkoutPost] {
        allPosts.filter { post in
            let type = post.activityType.lowercased()
            return selectedSport.activityTypes.contains { type.contains($0) }
        }
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // MARK: - Sport Type Filter
                sportTypeFilter
                    .padding(.top, 16)
                
                // MARK: - This Week Stats
                thisWeekSection
                    .padding(.top, 24)
                
                // MARK: - Past 12 Weeks Chart
                past12WeeksChart
                    .padding(.top, 8)
                
                Divider()
                    .padding(.vertical, 24)
                
                // MARK: - Monthly Recap Preview
                monthlyRecapSection
                
                Divider()
                    .padding(.vertical, 24)
                
                // MARK: - Calendar Section
                calendarSection
                
                // MARK: - Progressive Overload Section
                if !exerciseHistories.isEmpty {
                    Divider()
                        .padding(.vertical, 24)
                    
                    progressiveOverloadSection
                }
                
                Spacer(minLength: 100)
            }
        }
        .background(Color(.systemBackground))
        .navigationTitle("Statistik")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadData()
        }
        .enableSwipeBack()
    }
    
    // MARK: - Sport Type Filter
    private var sportTypeFilter: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(SportType.allCases) { sport in
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            selectedSport = sport
                            updateStats()
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: sport.icon)
                                .font(.system(size: 14, weight: .medium))
                            Text(sport.rawValue)
                                .font(.system(size: 14, weight: .medium))
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(selectedSport == sport ? Color.primary : Color.gray.opacity(0.3), lineWidth: selectedSport == sport ? 2 : 1)
                        )
                        .foregroundColor(selectedSport == sport ? .primary : .gray)
                    }
                }
            }
            .padding(.horizontal, 20)
        }
    }
    
    // MARK: - This Week Section
    private var thisWeekSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Denna vecka")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.primary)
            
            HStack(spacing: 0) {
                if selectedSport == .gym {
                    StatColumn(label: "Volym", value: "\(Int(progressStats.distance)) kg")
                    StatColumn(label: "Set", value: "\(Int(progressStats.elevation))")
                    StatColumn(label: "Tid", value: formatDuration(progressStats.duration))
                } else {
                    StatColumn(label: "Distans", value: String(format: "%.2f km", progressStats.distance))
                    StatColumn(label: "Höjdmeter", value: "\(Int(progressStats.elevation)) m")
                    StatColumn(label: "Tid", value: formatDuration(progressStats.duration))
                }
            }
        }
        .padding(.horizontal, 20)
    }
    
    // MARK: - Past 12 Weeks Chart
    private var past12WeeksChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Senaste 12 veckorna")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.gray)
            
            GeometryReader { geometry in
                let maxValue = weeklyData.map { $0.value }.max() ?? 1
                let chartWidth = geometry.size.width
                let chartHeight: CGFloat = 120
                let pointSpacing = chartWidth / CGFloat(max(weeklyData.count - 1, 1))
                
                ZStack(alignment: .bottomLeading) {
                    // Grid lines
                    VStack(spacing: 0) {
                        ForEach(0..<3) { i in
                            Divider()
                                .background(Color.gray.opacity(0.2))
                            if i < 2 {
                                Spacer()
                            }
                        }
                    }
                    .frame(height: chartHeight)
                    
                    // Y-axis labels
                    VStack {
                        let unit = selectedSport == .gym ? "kg" : "km"
                        Text("\(Int(maxValue)) \(unit)")
                            .font(.system(size: 10))
                            .foregroundColor(.gray)
                        Spacer()
                        Text("\(Int(maxValue / 2)) \(unit)")
                            .font(.system(size: 10))
                            .foregroundColor(.gray)
                        Spacer()
                        Text("0 \(unit)")
                            .font(.system(size: 10))
                            .foregroundColor(.gray)
                    }
                    .frame(height: chartHeight)
                    .offset(x: chartWidth + 8)
                    
                    // Line chart with area fill
                    if weeklyData.count > 1 {
                        // Area fill
                        Path { path in
                            path.move(to: CGPoint(x: 0, y: chartHeight))
                            for (index, data) in weeklyData.enumerated() {
                                let x = CGFloat(index) * pointSpacing
                                let y = chartHeight - (data.value / maxValue) * chartHeight
                                path.addLine(to: CGPoint(x: x, y: y))
                            }
                            path.addLine(to: CGPoint(x: CGFloat(weeklyData.count - 1) * pointSpacing, y: chartHeight))
                            path.closeSubpath()
                        }
                        .fill(Color.primary.opacity(0.1))
                        
                        // Line
                        Path { path in
                            for (index, data) in weeklyData.enumerated() {
                                let x = CGFloat(index) * pointSpacing
                                let y = chartHeight - (data.value / maxValue) * chartHeight
                                if index == 0 {
                                    path.move(to: CGPoint(x: x, y: y))
                                } else {
                                    path.addLine(to: CGPoint(x: x, y: y))
                                }
                            }
                        }
                        .stroke(Color.primary, lineWidth: 2)
                        
                        // Data points
                        ForEach(weeklyData.indices, id: \.self) { index in
                            let x = CGFloat(index) * pointSpacing
                            let y = chartHeight - (weeklyData[index].value / maxValue) * chartHeight
                            
                            Circle()
                                .fill(index == weeklyData.count - 1 ? Color.primary : Color(.systemBackground))
                                .frame(width: index == weeklyData.count - 1 ? 12 : 8, height: index == weeklyData.count - 1 ? 12 : 8)
                                .overlay(
                                    Circle()
                                        .stroke(Color.primary, lineWidth: 2)
                                )
                                .position(x: x, y: y)
                        }
                    }
                    
                    // X-axis labels
                    HStack {
                        let currentMonth = calendar.component(.month, from: Date())
                        let months = (0..<3).reversed().map { offset -> String in
                            let month = (currentMonth - offset + 11) % 12 + 1
                            return monthAbbreviation(month).uppercased()
                        }
                        
                        ForEach(months, id: \.self) { month in
                            Text(month)
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(.gray)
                            if month != months.last {
                                Spacer()
                            }
                        }
                    }
                    .offset(y: chartHeight + 16)
                }
                .frame(height: chartHeight + 30)
            }
            .frame(height: 150)
            .padding(.trailing, 50)
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
    }
    
    // MARK: - Monthly Recap Section
    private var monthlyRecapSection: some View {
        let previousMonth = calendar.date(byAdding: .month, value: -1, to: Date()) ?? Date()
        let monthFormatter = DateFormatter()
        monthFormatter.dateFormat = "MMMM"
        monthFormatter.locale = Locale(identifier: "sv_SE")
        let monthName = monthFormatter.string(from: previousMonth).capitalized
        
        let yearFormatter = DateFormatter()
        yearFormatter.dateFormat = "yyyy"
        let year = yearFormatter.string(from: previousMonth)
        
        return VStack(alignment: .leading, spacing: 16) {
            NavigationLink(destination: MonthlyReportView()) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(monthName)
                            .font(.system(size: 48, weight: .light))
                            .foregroundColor(.primary)
                        Text(year)
                            .font(.system(size: 48, weight: .light))
                            .foregroundColor(.gray)
                    }
                    
                    Spacer()
                    
                    // Mini bar chart preview
                    HStack(alignment: .bottom, spacing: 3) {
                        ForEach(0..<12, id: \.self) { i in
                            let heights: [CGFloat] = [20, 35, 25, 15, 30, 20, 40, 35, 45, 50, 30, 8]
                            RoundedRectangle(cornerRadius: 1)
                                .fill(i == 11 ? Color.primary : Color.gray.opacity(0.4))
                                .frame(width: 4, height: heights[i])
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
            .buttonStyle(.plain)
            
            // View recap button
            NavigationLink(destination: MonthlyReportView()) {
                Text("Se din månadsrapport")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.primary)
                    .cornerRadius(30)
            }
            .padding(.horizontal, 20)
        }
    }
    
    // MARK: - Calendar Section
    private var calendarSection: some View {
        let currentMonth = Date()
        let monthFormatter = DateFormatter()
        monthFormatter.dateFormat = "MMMM yyyy"
        monthFormatter.locale = Locale(identifier: "sv_SE")
        
        return VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(monthFormatter.string(from: currentMonth).capitalized)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.primary)
                
                Spacer()
            }
            
            // Streak info
            HStack(spacing: 40) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Din streak")
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                    Text("\(currentStreak) veckor")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.primary)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Streak aktiviteter")
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                    Text("\(streakActivities)")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.primary)
                }
            }
            
            // Calendar grid
            calendarGrid
        }
        .padding(.horizontal, 20)
    }
    
    // MARK: - Calendar Grid
    private var calendarGrid: some View {
        let weekdaySymbols = ["M", "T", "W", "T", "F", "S", "S"]
        let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: Date()))!
        let daysInMonth = calendar.range(of: .day, in: .month, for: startOfMonth)?.count ?? 30
        let rawWeekday = calendar.component(.weekday, from: startOfMonth)
        let leadingDays = rawWeekday == 1 ? 6 : rawWeekday - 2
        let today = calendar.component(.day, from: Date())
        
        return VStack(spacing: 12) {
            // Weekday headers
            HStack {
                ForEach(weekdaySymbols, id: \.self) { symbol in
                    Text(symbol)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.gray)
                        .frame(maxWidth: .infinity)
                }
                
                // Streak column
                Text("")
                    .frame(width: 50)
            }
            
            // Calendar rows
            let totalCells = leadingDays + daysInMonth
            let rows = (totalCells + 6) / 7
            
            ForEach(0..<rows, id: \.self) { row in
                HStack(spacing: 0) {
                    ForEach(0..<7, id: \.self) { col in
                        let index = row * 7 + col
                        let day = index - leadingDays + 1
                        
                        if day > 0 && day <= daysInMonth {
                            ZStack {
                                if workoutDays.contains(day) {
                                    Circle()
                                        .fill(Color.primary)
                                        .frame(width: 32, height: 32)
                                    
                                    Image(systemName: selectedSport.icon)
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(.white)
                                } else if day == today {
                                    Circle()
                                        .stroke(Color.primary, lineWidth: 2)
                                        .frame(width: 32, height: 32)
                                    
                                    Text("\(day)")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(.primary)
                                } else {
                                    Text("\(day)")
                                        .font(.system(size: 14))
                                        .foregroundColor(day > today ? .gray.opacity(0.5) : .primary)
                                }
                            }
                            .frame(maxWidth: .infinity)
                        } else {
                            Text("")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    
                    // Weekly streak indicator (placeholder)
                    Circle()
                        .fill(Color.clear)
                        .frame(width: 32, height: 32)
                        .frame(width: 50)
                }
            }
        }
    }
    
    // MARK: - Progressive Overload Section
    private var progressiveOverloadSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Header
            HStack(alignment: .center) {
                // Icon with gradient background
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(
                            LinearGradient(
                                colors: [Color.green, Color.green.opacity(0.7)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.white)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Progressive Overload")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.primary)
                    
                    Text("Följ din styrkeutveckling")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                NavigationLink {
                    AllExercisesListView(exerciseHistories: exerciseHistories)
                } label: {
                    HStack(spacing: 4) {
                        Text("Se alla")
                            .font(.system(size: 14, weight: .semibold))
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundColor(.green)
                }
            }
            
            // Exercise cards
            VStack(spacing: 0) {
                ForEach(Array(exerciseHistories.prefix(5).enumerated()), id: \.element.id) { index, history in
                    NavigationLink {
                        StatExerciseDetailView(history: history)
                    } label: {
                        StatExerciseRow(history: history, isLast: index == min(4, exerciseHistories.count - 1))
                    }
                    .buttonStyle(.plain)
                }
            }
            .background(Color(.secondarySystemBackground))
            .cornerRadius(20)
            .shadow(color: Color.black.opacity(0.06), radius: 12, x: 0, y: 4)
            
            // See all button
            if exerciseHistories.count > 5 {
                NavigationLink {
                    AllExercisesListView(exerciseHistories: exerciseHistories)
                } label: {
                    HStack {
                        Text("Se alla \(exerciseHistories.count) övningar")
                            .font(.system(size: 15, weight: .semibold))
                        
                        Image(systemName: "arrow.right")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(Color.green)
                            .shadow(color: Color.green.opacity(0.3), radius: 8, x: 0, y: 4)
                    )
                }
            }
        }
        .padding(.horizontal, 20)
    }
    
    // MARK: - Helper Functions
    private func loadData() async {
        guard let userId = authViewModel.currentUser?.id else { return }
        
        do {
            let posts = try await WorkoutService.shared.getUserWorkoutPosts(userId: userId, forceRefresh: true)
            await MainActor.run {
                self.allPosts = posts
                updateStats()
                calculateCalendarData()
                calculateStreaks()
                computeExerciseHistories()
                isLoading = false
            }
        } catch {
            print("Error loading stats: \(error)")
            await MainActor.run {
                isLoading = false
            }
        }
    }
    
    private func computeExerciseHistories() {
        var map: [String: (exerciseId: String?, snapshots: [StatExerciseSnapshot])] = [:]
        
        for post in allPosts {
            let type = post.activityType.lowercased()
            guard type.contains("gym") else { continue }
            guard let exercises = post.exercises, !exercises.isEmpty else { continue }
            guard let date = parseDate(post.createdAt) else { continue }
            
            for exercise in exercises {
                let sets = zip(exercise.kg, exercise.reps)
                    .map { StatSetSnapshot(weight: $0.0, reps: $0.1) }
                    .filter { $0.reps > 0 }
                guard !sets.isEmpty else { continue }
                
                // Best set based on estimated 1RM
                let bestSet = sets.max(by: { $0.estimated1RM < $1.estimated1RM }) ?? sets[0]
                
                let snapshot = StatExerciseSnapshot(
                    date: date,
                    bestSet: bestSet,
                    sets: sets,
                    category: exercise.category
                )
                
                // Store exercise ID if available
                if map[exercise.name] == nil {
                    map[exercise.name] = (exerciseId: exercise.id, snapshots: [snapshot])
                } else {
                    map[exercise.name]?.snapshots.append(snapshot)
                    // Update exerciseId if we have a newer one
                    if let id = exercise.id, map[exercise.name]?.exerciseId == nil {
                        map[exercise.name]?.exerciseId = id
                    }
                }
            }
        }
        
        let histories = map.map { name, data -> StatExerciseHistory in
            let sorted = data.snapshots.sorted { $0.date < $1.date }
            return StatExerciseHistory(
                name: name,
                category: sorted.last?.category,
                exerciseId: data.exerciseId,
                history: sorted
            )
        }
        
        // Sort by latest activity
        exerciseHistories = histories.sorted { (lhs, rhs) -> Bool in
            let leftDate = lhs.latestSnapshot?.date ?? .distantPast
            let rightDate = rhs.latestSnapshot?.date ?? .distantPast
            return leftDate > rightDate
        }
    }
    
    private func updateStats() {
        let posts = filteredPosts
        let now = Date()
        let startOfWeek = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)) ?? now
        
        let thisWeekPosts = posts.filter { post in
            guard let date = parseDate(post.createdAt) else { return false }
            return date >= startOfWeek
        }
        
        if selectedSport == .gym {
            // Calculate volume and sets for gym
            let volume = thisWeekPosts.reduce(0.0) { total, post in
                let postVolume = post.exercises?.reduce(0.0) { exerciseTotal, exercise in
                    let exerciseVolume = zip(exercise.reps, exercise.kg).reduce(0.0) { setTotal, pair in
                        setTotal + Double(pair.0) * pair.1
                    }
                    return exerciseTotal + exerciseVolume
                } ?? 0.0
                return total + postVolume
            }
            
            let sets = thisWeekPosts.reduce(0) { total, post in
                let postSets = post.exercises?.reduce(0) { $0 + $1.sets } ?? 0
                return total + postSets
            }
            
            progressStats = ProgressStats(
                distance: volume, // Using distance field for volume
                elevation: Double(sets), // Using elevation field for sets
                duration: thisWeekPosts.reduce(0) { $0 + Double($1.duration ?? 0) }
            )
        } else {
            // Calculate distance and elevation for cardio
            progressStats = ProgressStats(
                distance: thisWeekPosts.reduce(0) { $0 + (($1.distance ?? 0) / 1000) },
                elevation: thisWeekPosts.reduce(0) { $0 + ($1.elevationGain ?? 0) },
                duration: thisWeekPosts.reduce(0) { $0 + Double($1.duration ?? 0) }
            )
        }
        
        // Calculate weekly data for chart
        var data: [WeekData] = []
        for weekOffset in (0..<12).reversed() {
            guard let weekStart = calendar.date(byAdding: .weekOfYear, value: -weekOffset, to: startOfWeek) else { continue }
            guard let weekEnd = calendar.date(byAdding: .day, value: 7, to: weekStart) else { continue }
            
            let weekPosts = posts.filter { post in
                guard let date = parseDate(post.createdAt) else { return false }
                return date >= weekStart && date < weekEnd
            }
            
            let value: Double
            if selectedSport == .gym {
                value = weekPosts.reduce(0.0) { total, post in
                    let postVolume = post.exercises?.reduce(0.0) { exerciseTotal, exercise in
                        let exerciseVolume = zip(exercise.reps, exercise.kg).reduce(0.0) { setTotal, pair in
                            setTotal + Double(pair.0) * pair.1
                        }
                        return exerciseTotal + exerciseVolume
                    } ?? 0.0
                    return total + postVolume
                }
            } else {
                value = weekPosts.reduce(0.0) { $0 + (($1.distance ?? 0) / 1000) }
            }
            
            data.append(WeekData(weekStart: weekStart, value: value))
        }
        weeklyData = data
    }
    
    private func calculateCalendarData() {
        let posts = filteredPosts
        let thisMonth = calendar.dateComponents([.year, .month], from: Date())
        
        var days: Set<Int> = []
        for post in posts {
            if let date = parseDate(post.createdAt) {
                let postComponents = calendar.dateComponents([.year, .month, .day], from: date)
                if postComponents.year == thisMonth.year && postComponents.month == thisMonth.month {
                    if let day = postComponents.day {
                        days.insert(day)
                    }
                }
            }
        }
        workoutDays = days
    }
    
    private func calculateStreaks() {
        // Simple streak calculation
        let posts = filteredPosts.sorted { parseDate($0.createdAt) ?? Date.distantPast > parseDate($1.createdAt) ?? Date.distantPast }
        
        var streak = 0
        var activities = 0
        var lastWeek: Int?
        
        for post in posts {
            guard let date = parseDate(post.createdAt) else { continue }
            let week = calendar.component(.weekOfYear, from: date)
            
            if lastWeek == nil {
                lastWeek = week
                streak = 1
                activities = 1
            } else if week == lastWeek {
                activities += 1
            } else if week == lastWeek! - 1 || (lastWeek == 1 && week >= 52) {
                streak += 1
                activities += 1
                lastWeek = week
            } else {
                break
            }
        }
        
        currentStreak = streak
        streakActivities = activities
    }
    
    private func parseDate(_ dateString: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: dateString) {
            return date
        }
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: dateString)
    }
    
    private func formatDuration(_ seconds: Double) -> String {
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }
    
    private func monthAbbreviation(_ month: Int) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "sv_SE")
        return formatter.shortMonthSymbols[month - 1].replacingOccurrences(of: ".", with: "")
    }
}

// MARK: - Supporting Types
private struct ProgressStats {
    var distance: Double = 0
    var elevation: Double = 0
    var duration: Double = 0
}

private struct WeekData: Identifiable {
    let id = UUID()
    let weekStart: Date
    let value: Double
}

private struct StatColumn: View {
    let label: String
    let value: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 12))
                .foregroundColor(.gray)
            Text(value)
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct SectionHeader: View {
    let title: String
    let icon: String
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.secondary)
            
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.secondary)
                .textCase(.uppercase)
        }
    }
}

private enum CalendarMode: String, CaseIterable, Identifiable {
    case month = "Månad"
    case year = "År"
    case multiYear = "Flera år"
    
    var id: String { rawValue }
}

private struct CalendarOverviewView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var workoutDates: [Date] = []
    @State private var workoutSet: Set<Date> = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var mode: CalendarMode = .month
    @State private var referenceDate = Date()
    @State private var earliestDate: Date?
    
    private var calendar: Calendar {
        var cal = Calendar(identifier: .iso8601)
        cal.locale = Locale(identifier: "sv_SE")
        cal.firstWeekday = 2
        return cal
    }
    
    private let isoFormatterWithMs: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
    
    private let isoFormatterNoMs: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header card
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "calendar")
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundColor(.primary)
                        
                        Text("Träningskalender")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.primary)
                        
                        Spacer()
                    }
                    
                    Text("Visualisera dina träningsdagar och håll koll på din kontinuitet.")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                    
                    // Stats row
                    HStack(spacing: 12) {
                        CalendarStatItem(value: "\(workoutDates.count)", label: "Pass", color: .primary)
                        CalendarStatItem(value: "\(workoutSet.count)", label: "Dagar", color: .secondary)
                        CalendarStatItem(value: "\(currentStreak)", label: "Streak", color: .green)
                    }
                    .padding(.top, 8)
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.systemBackground))
                .cornerRadius(16)
                .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 4)
                
                // Mode picker card
                VStack(spacing: 16) {
                    modePicker
                }
                .padding(16)
                .background(Color(.systemBackground))
                .cornerRadius(16)
                .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 4)
                
                // Calendar card
                VStack {
                    switch mode {
                    case .month:
                        MonthCalendarView(referenceDate: $referenceDate,
                                          workoutSet: workoutSet,
                                          calendar: calendar)
                    case .year:
                        YearCalendarView(referenceDate: $referenceDate,
                                         workoutSet: workoutSet,
                                         calendar: calendar)
                    case .multiYear:
                        MultiYearCalendarView(referenceDate: referenceDate,
                                              earliestDate: earliestDate,
                                              workoutSet: workoutSet,
                                              calendar: calendar)
                    }
                }
                .padding(16)
                .background(Color(.systemBackground))
                .cornerRadius(16)
                .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 4)
            }
            .padding(16)
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .navigationTitle("Kalender")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: reload) {
                    Image(systemName: "arrow.clockwise")
                }
                .disabled(isLoading)
            }
        }
        .overlay(alignment: .center) {
            if isLoading {
                ProgressView("Hämtar träningsdagar…")
                    .padding(.horizontal, 24)
                    .padding(.vertical, 16)
                    .background(Color(.systemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .shadow(color: Color.black.opacity(0.15), radius: 10, x: 0, y: 6)
            } else if let errorMessage {
                VStack(spacing: 12) {
                    Text(errorMessage)
                        .font(.callout)
                        .multilineTextAlignment(.center)
                    Button("Försök igen") {
                        reload()
                    }
                    .font(.system(size: 14, weight: .semibold))
                    .padding(.horizontal, 18)
                    .padding(.vertical, 8)
                    .background(Color.primary)
                    .foregroundColor(Color(.systemBackground))
                    .clipShape(Capsule())
                }
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(18)
                .shadow(color: Color.black.opacity(0.15), radius: 10, x: 0, y: 6)
            }
        }
        .task {
            await loadWorkoutDates()
        }
        .refreshable {
            await loadWorkoutDates(force: true)
        }
    }
    
    private var currentStreak: Int {
        guard !workoutSet.isEmpty else { return 0 }
        
        var streak = 0
        var currentDate = calendar.startOfDay(for: Date())
        
        // Check if today or yesterday was a workout day to start the streak
        if !workoutSet.contains(currentDate) {
            if let yesterday = calendar.date(byAdding: .day, value: -1, to: currentDate) {
                currentDate = yesterday
            }
        }
        
        // Count consecutive days backwards
        while workoutSet.contains(currentDate) {
            streak += 1
            if let previousDay = calendar.date(byAdding: .day, value: -1, to: currentDate) {
                currentDate = previousDay
            } else {
                break
            }
        }
        
        return streak
    }
    
    private var modePicker: some View {
        VStack(spacing: 12) {
            Picker("Vy", selection: $mode) {
                ForEach(CalendarMode.allCases) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            
            switch mode {
            case .month:
                MonthNavigationControls(referenceDate: $referenceDate, calendar: calendar)
            case .year:
                YearNavigationControls(referenceDate: $referenceDate, calendar: calendar)
            case .multiYear:
                EmptyView()
            }
        }
    }
    
    private func reload() {
        Task {
            await loadWorkoutDates(force: true)
        }
    }
    
    private func loadWorkoutDates(force: Bool = false) async {
        guard let userId = authViewModel.currentUser?.id else {
            await MainActor.run {
                self.errorMessage = "Logga in för att se kalendern."
                self.isLoading = false
            }
            return
        }
        
        await MainActor.run {
            if force || workoutDates.isEmpty {
                isLoading = true
            }
            errorMessage = nil
        }
        
        do {
            let posts = try await WorkoutService.shared.getUserWorkoutPosts(userId: userId, forceRefresh: force)
            let fetchedDates: [Date] = posts.compactMap { post in
                if let date = isoFormatterWithMs.date(from: post.createdAt) {
                    return date
                }
                return isoFormatterNoMs.date(from: post.createdAt)
            }
            let daySet = Set(fetchedDates.map { calendar.startOfDay(for: $0) })
            let earliest = fetchedDates.min()
            
            await MainActor.run {
                withAnimation {
                    self.workoutDates = fetchedDates
                    self.workoutSet = daySet
                    self.earliestDate = earliest
                    self.isLoading = false
                }
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "Kunde inte hämta kalenderdata just nu."
                self.isLoading = false
            }
        }
    }
}

private struct CalendarStatItem: View {
    let value: String
    let label: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 8) {
            Text(value)
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(color)
            
            Text(label)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(color.opacity(0.1))
        .cornerRadius(12)
    }
}

private struct MonthNavigationControls: View {
    @Binding var referenceDate: Date
    let calendar: Calendar
    
    var body: some View {
        HStack {
            Button(action: { changeMonth(-1) }) {
                Image(systemName: "chevron.left")
                    .font(.headline)
                    .padding(8)
                    .background(Color(.systemGray5))
                    .clipShape(Circle())
            }
            Spacer()
            Text(monthFormatter.string(from: referenceDate).capitalized)
                .font(.system(size: 18, weight: .bold))
            Spacer()
            Button(action: { changeMonth(1) }) {
                Image(systemName: "chevron.right")
                    .font(.headline)
                    .padding(8)
                    .background(Color(.systemGray5))
                    .clipShape(Circle())
            }
        }
    }
    
    private var monthFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "LLLL yyyy"
        formatter.locale = Locale(identifier: "sv_SE")
        return formatter
    }
    
    private func changeMonth(_ offset: Int) {
        if let newDate = calendar.date(byAdding: .month, value: offset, to: referenceDate) {
            referenceDate = newDate
        }
    }
}

private struct YearNavigationControls: View {
    @Binding var referenceDate: Date
    let calendar: Calendar
    
    var body: some View {
        HStack {
            Button(action: { shiftYear(-1) }) {
                Image(systemName: "chevron.left")
                    .font(.headline)
                    .padding(8)
                    .background(Color(.systemGray5))
                    .clipShape(Circle())
            }
            Spacer()
            Text(yearFormatter.string(from: referenceDate))
                .font(.system(size: 18, weight: .bold))
            Spacer()
            Button(action: { shiftYear(1) }) {
                Image(systemName: "chevron.right")
                    .font(.headline)
                    .padding(8)
                    .background(Color(.systemGray5))
                    .clipShape(Circle())
            }
        }
    }
    
    private var yearFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy"
        formatter.locale = Locale(identifier: "sv_SE")
        return formatter
    }
    
    private func shiftYear(_ offset: Int) {
        if let newDate = calendar.date(byAdding: .year, value: offset, to: referenceDate) {
            referenceDate = newDate
        }
    }
}

private struct MonthCalendarView: View {
    @Binding var referenceDate: Date
    let workoutSet: Set<Date>
    let calendar: Calendar
    
    private var monthLabel: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "LLLL yyyy"
        formatter.locale = Locale(identifier: "sv_SE")
        return formatter.string(from: referenceDate).capitalized
    }
    
    private var daysInMonth: [Int] {
        guard let range = calendar.range(of: .day, in: .month, for: referenceDate) else { return [] }
        return Array(range)
    }
    
    private var firstWeekdayOffset: Int {
        let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: referenceDate)) ?? referenceDate
        let weekday = calendar.component(.weekday, from: monthStart)
        let normalized = (weekday - calendar.firstWeekday + 7) % 7
        return normalized
    }
    
    private var workoutCountThisMonth: Int {
        daysInMonth.filter { day in
            guard let date = dayDate(day: day) else { return false }
            return workoutSet.contains(calendar.startOfDay(for: date))
        }.count
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Month header with stats
            HStack {
                Text(monthLabel)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.primary)
                
                Spacer()
                
                HStack(spacing: 4) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.green)
                    Text("\(workoutCountThisMonth) pass")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.green)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.green.opacity(0.12))
                .cornerRadius(10)
            }
            
            // Weekday headers
            let weekdaySymbols = calendar.shortWeekdaySymbols
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 7), spacing: 12) {
                ForEach(weekdaySymbols, id: \.self) { symbol in
                    Text(symbol.capitalized)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity)
                }
                
                // Empty cells for offset
                ForEach(0..<firstWeekdayOffset, id: \.self) { _ in
                    Text("")
                        .frame(height: 36)
                }
                
                // Day cells
                ForEach(daysInMonth, id: \.self) { day in
                    let date = dayDate(day: day)
                    let isWorkoutDay = date.map { workoutSet.contains(calendar.startOfDay(for: $0)) } ?? false
                    let isToday = date.map { calendar.isDateInToday($0) } ?? false
                    
                    Text("\(day)")
                        .font(.system(size: 15, weight: isWorkoutDay || isToday ? .bold : .medium))
                        .frame(width: 38, height: 38)
                        .background(
                            ZStack {
                                if isWorkoutDay {
                                    Circle()
                                        .fill(Color.green)
                                } else if isToday {
                                    Circle()
                                        .stroke(Color.primary, lineWidth: 2)
                                } else {
                                    Circle()
                                        .fill(Color(.systemGray6))
                                }
                            }
                        )
                        .foregroundColor(isWorkoutDay ? .white : .primary)
                }
            }
        }
    }
    
    private func dayDate(day: Int) -> Date? {
        var comps = calendar.dateComponents([.year, .month], from: referenceDate)
        comps.day = day
        return calendar.date(from: comps)
    }
}

private struct YearCalendarView: View {
    @Binding var referenceDate: Date
    let workoutSet: Set<Date>
    let calendar: Calendar
    
    private var months: [Date] {
        guard let yearStart = calendar.date(from: calendar.dateComponents([.year], from: referenceDate)) else { return [] }
        return (0..<12).compactMap { calendar.date(byAdding: .month, value: $0, to: yearStart) }
    }
    
    private var totalWorkoutsThisYear: Int {
        months.reduce(0) { total, monthStart in
            let days = calendar.range(of: .day, in: .month, for: monthStart) ?? 1..<32
            return total + days.filter { day in
                var comps = calendar.dateComponents([.year, .month], from: monthStart)
                comps.day = day
                guard let date = calendar.date(from: comps) else { return false }
                return workoutSet.contains(calendar.startOfDay(for: date))
            }.count
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Year header with total stats
            HStack {
                Text(yearFormatter.string(from: referenceDate))
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.primary)
                
                Spacer()
                
                HStack(spacing: 4) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.green)
                    Text("\(totalWorkoutsThisYear) pass totalt")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.green)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.green.opacity(0.12))
                .cornerRadius(10)
            }
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 2), spacing: 12) {
                ForEach(months, id: \.self) { monthStart in
                    MiniMonthCard(monthStart: monthStart, workoutSet: workoutSet, calendar: calendar)
                }
            }
        }
    }
    
    private var yearFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy"
        formatter.locale = Locale(identifier: "sv_SE")
        return formatter
    }
}

private struct MiniMonthCard: View {
    let monthStart: Date
    let workoutSet: Set<Date>
    let calendar: Calendar
    
    private var monthLabel: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM"
        formatter.locale = Locale(identifier: "sv_SE")
        return formatter.string(from: monthStart).capitalized
    }
    
    private var workoutCount: Int {
        let days = calendar.range(of: .day, in: .month, for: monthStart) ?? 1..<32
        return days.filter { day in
            guard let date = makeDate(day: day) else { return false }
            return workoutSet.contains(calendar.startOfDay(for: date))
        }.count
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(monthLabel)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.primary)
                
                Spacer()
                
                if workoutCount > 0 {
                    Text("\(workoutCount)")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color.green)
                        .cornerRadius(8)
                }
            }
            
            let days = calendar.range(of: .day, in: .month, for: monthStart) ?? 1..<32
            let columns = Array(repeating: GridItem(.flexible(), spacing: 3), count: 7)
            LazyVGrid(columns: columns, spacing: 3) {
                ForEach(days, id: \.self) { day in
                    let date = makeDate(day: day)
                    let hasWorkout = date.map { workoutSet.contains(calendar.startOfDay(for: $0)) } ?? false
                    RoundedRectangle(cornerRadius: 2)
                        .fill(hasWorkout ? Color.green : Color(.systemGray5))
                        .frame(width: 12, height: 12)
                }
            }
        }
        .padding(14)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
    
    private func makeDate(day: Int) -> Date? {
        var comps = calendar.dateComponents([.year, .month], from: monthStart)
        comps.day = day
        return calendar.date(from: comps)
    }
}

private struct MultiYearCalendarView: View {
    let referenceDate: Date
    let earliestDate: Date?
    let workoutSet: Set<Date>
    let calendar: Calendar
    
    private var years: [Int] {
        let refYear = calendar.component(.year, from: referenceDate)
        guard let earliest = earliestDate else { return [refYear] }
        let earliestYear = calendar.component(.year, from: earliest)
        return Array(earliestYear...refYear).reversed()
    }
    
    private var totalWorkouts: Int {
        workoutSet.count
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Header
            HStack {
                Text("Historik")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.primary)
                
                Spacer()
                
                HStack(spacing: 4) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.green)
                    Text("\(totalWorkouts) pass totalt")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.green)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.green.opacity(0.12))
                .cornerRadius(10)
            }
            
            if years.isEmpty {
                HStack(spacing: 12) {
                    Image(systemName: "calendar.badge.exclamationmark")
                        .font(.system(size: 24))
                        .foregroundColor(.secondary)
                    
                    Text("Inga registrerade pass ännu.")
                        .font(.system(size: 15))
                        .foregroundColor(.secondary)
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.systemGray6))
                .cornerRadius(12)
            } else {
                ForEach(years, id: \.self) { year in
                    YearHeatRow(year: year, workoutSet: workoutSet, calendar: calendar)
                }
            }
        }
    }
}

private struct YearHeatRow: View {
    let year: Int
    let workoutSet: Set<Date>
    let calendar: Calendar
    
    private var workoutsThisYear: Int {
        let months = (0..<12).compactMap { offset -> Date? in
            var comps = DateComponents()
            comps.year = year
            comps.month = offset + 1
            comps.day = 1
            return calendar.date(from: comps)
        }
        return months.reduce(0) { total, monthStart in
            let range = calendar.range(of: .day, in: .month, for: monthStart) ?? 1..<32
            return total + range.filter { day in
                var comps = calendar.dateComponents([.year, .month], from: monthStart)
                comps.day = day
                guard let date = calendar.date(from: comps) else { return false }
                return workoutSet.contains(calendar.startOfDay(for: date))
            }.count
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("\(year)")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.primary)
                
                Spacer()
                
                Text("\(workoutsThisYear) pass")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.secondary)
            }
            
            let months = (0..<12).compactMap { offset -> Date? in
                var comps = DateComponents()
                comps.year = year
                comps.month = offset + 1
                comps.day = 1
                return calendar.date(from: comps)
            }
            
            // Month labels
            HStack(spacing: 4) {
                ForEach(["J", "F", "M", "A", "M", "J", "J", "A", "S", "O", "N", "D"], id: \.self) { label in
                    Text(label)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }
            
            // Activity dots
            HStack(spacing: 4) {
                ForEach(months, id: \.self) { monthStart in
                    MiniMonthDot(monthStart: monthStart, workoutSet: workoutSet, calendar: calendar)
                }
            }
        }
        .padding(16)
        .background(Color(.systemGray6))
        .cornerRadius(14)
    }
}

private struct MiniMonthDot: View {
    let monthStart: Date
    let workoutSet: Set<Date>
    let calendar: Calendar
    
    private var workoutCountInMonth: Int {
        let range = calendar.range(of: .day, in: .month, for: monthStart) ?? 1..<32
        return range.filter { day in
            var comps = calendar.dateComponents([.year, .month], from: monthStart)
            comps.day = day
            guard let date = calendar.date(from: comps) else { return false }
            return workoutSet.contains(calendar.startOfDay(for: date))
        }.count
    }
    
    private var intensity: Double {
        let count = workoutCountInMonth
        if count == 0 { return 0 }
        if count <= 3 { return 0.3 }
        if count <= 7 { return 0.5 }
        if count <= 12 { return 0.75 }
        return 1.0
    }
    
    var body: some View {
        RoundedRectangle(cornerRadius: 4, style: .continuous)
            .fill(workoutCountInMonth > 0 ? Color.green.opacity(intensity) : Color(.systemGray5))
            .frame(maxWidth: .infinity, minHeight: 20)
    }
}

private struct StatisticsMenuRow: View {
    let icon: String
    let assetName: String?
    let title: String
    let subtitle: String
    var iconColor: Color
    var showDivider: Bool
    
    init(icon: String, assetName: String? = nil, title: String, subtitle: String, iconColor: Color = .primary, showDivider: Bool = false) {
        self.icon = icon
        self.assetName = assetName
        self.title = title
        self.subtitle = subtitle
        self.iconColor = iconColor
        self.showDivider = showDivider
    }
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(iconColor.opacity(0.12))
                        .frame(width: 44, height: 44)
                    if let assetName {
                        Image(assetName)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 38, height: 38)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    } else {
                        Image(systemName: icon)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(iconColor)
                    }
                }
                
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary)
                    Text(subtitle)
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.secondary.opacity(0.5))
            }
            .padding(.vertical, 12)
            
            if showDivider {
                Divider()
                    .padding(.leading, 58)
            }
        }
    }
}

private struct UppyMenuRow: View {
    let title: String
    let subtitle: String
    
    private var prefixText: String {
        guard let range = title.range(of: "UPPY", options: .caseInsensitive) else {
            return title
        }
        return title[..<range.lowerBound].trimmingCharacters(in: .whitespaces)
    }
    
    private var uppyText: String? {
        guard let range = title.range(of: "UPPY", options: .caseInsensitive) else {
            return nil
        }
        return String(title[range])
    }
    
    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color(.systemGray6))
                    .frame(width: 48, height: 48)
                Image("23")
                    .resizable()
                    .scaledToFill()
                    .frame(width: 42, height: 42)
                    .clipShape(Circle())
            }
            
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(prefixText.isEmpty ? title : prefixText.replacingOccurrences(of: " ", with: ""))
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    if let uppyText {
                        LinearGradient(
                            colors: [Color.primary, Color.gray.opacity(0.75), Color.gray.opacity(0.55)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        .mask(
                            Text(uppyText.uppercased())
                                .font(.system(size: 16, weight: .heavy))
                        )
                        .accessibilityLabel("UPPY")
                        
                        Image(systemName: "sparkle.fill")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.primary)
                            .accessibilityHidden(true)
                    }
                }
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundColor(.gray)
            }
        }
        .padding(.vertical, 4)
    }
}

private struct StepStatisticsSectionView: View {
    @State private var todaySteps: Int?
    @State private var lastWeekSteps: Int?
    @State private var lastMonthSteps: Int?
    @State private var isAuthorized = HealthKitManager.shared.isHealthDataAuthorized()
    @State private var isLoading = false
    @State private var hasInitialized = false
    @State private var pendingRequests = 0
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Din aktivitet")
                        .font(.system(size: 17, weight: .semibold))
                    Text("Synkas från Apple Hälsa")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
                Spacer()
                if isAuthorized {
                    Button {
                        loadStepData()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 16, weight: .semibold))
                            .padding(8)
                            .background(Color(.systemGray6))
                            .clipShape(Circle())
                    }
                    .disabled(isLoading)
                    .accessibilityLabel("Uppdatera stegstatistik")
                }
            }
            
            if !isAuthorized {
                VStack(alignment: .leading, spacing: 12) {
                    Text("För att se din stegstatistik behöver du ge appen tillgång till stegdata i Apple Hälsa.")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                    HStack {
                        Button(action: requestAuthorization) {
                            Text("Tillåt stegdata")
                                .font(.system(size: 14, weight: .semibold))
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(Color.primary)
                                .foregroundColor(Color(.systemBackground))
                                .clipShape(Capsule())
                        }
                        Button(action: HealthKitManager.shared.handleManageAuthorizationButton) {
                            Text("Öppna inställningar")
                                .font(.system(size: 14, weight: .medium))
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(Color(.systemGray5))
                                .clipShape(Capsule())
                        }
                    }
                }
            } else if isLoading {
                HStack(spacing: 12) {
                    ProgressView()
                    Text("Hämtar stegdata…")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                VStack(spacing: 12) {
                    StepStatRow(title: "Idag", steps: todaySteps)
                    Divider()
                    StepStatRow(title: "Förra veckan", steps: lastWeekSteps, subtitle: "Mån–Sön föregående vecka")
                    Divider()
                    StepStatRow(title: "Förra månaden", steps: lastMonthSteps)
                }
            }
        }
        .padding(16)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .drawingGroup() // GPU-accelerated rendering
        .onAppear {
            guard !hasInitialized else { return }
            hasInitialized = true
            if isAuthorized {
                loadStepData()
            } else {
                requestAuthorizationIfPossible()
            }
        }
    }
    
    private func requestAuthorization() {
        requestAuthorizationIfPossible()
    }
    
    private func requestAuthorizationIfPossible() {
        HealthKitManager.shared.requestAuthorization { granted in
            DispatchQueue.main.async {
                self.isAuthorized = granted
                if granted {
                    self.loadStepData()
                }
            }
        }
    }
    
    private func loadStepData() {
        guard isAuthorized else { return }
        isLoading = true
        pendingRequests = 3
        
        let calendar = Calendar(identifier: .iso8601)
        let now = Date()
        
        HealthKitManager.shared.getStepsForDate(now) { steps in
            self.todaySteps = steps
            self.markRequestComplete()
        }
        
        if let startOfCurrentWeek = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)),
           let startOfLastWeek = calendar.date(byAdding: .weekOfYear, value: -1, to: startOfCurrentWeek) {
            HealthKitManager.shared.getStepsTotal(from: startOfLastWeek, to: startOfCurrentWeek) { steps in
                self.lastWeekSteps = steps
                self.markRequestComplete()
            }
        } else {
            self.lastWeekSteps = 0
            markRequestComplete()
        }
        
        if let startOfCurrentMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: now)),
           let startOfLastMonth = calendar.date(byAdding: .month, value: -1, to: startOfCurrentMonth) {
            HealthKitManager.shared.getStepsTotal(from: startOfLastMonth, to: startOfCurrentMonth) { steps in
                self.lastMonthSteps = steps
                self.markRequestComplete()
            }
        } else {
            self.lastMonthSteps = 0
            markRequestComplete()
        }
    }
    
    private func markRequestComplete() {
        pendingRequests -= 1
        if pendingRequests <= 0 {
            isLoading = false
        }
    }
}

private struct StepStatRow: View {
    let title: String
    let steps: Int?
    var subtitle: String?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                Spacer()
                Text(formattedSteps)
                    .font(.system(size: 20, weight: .bold))
            }
            if let subtitle {
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            Text(kilometerText)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
        }
    }
    
    private var formattedSteps: String {
        guard let steps = steps else { return "--" }
        return NumberFormatter.stepsFormatter.string(from: NSNumber(value: steps)) ?? "\(steps)"
    }
    
    private var kilometerText: String {
        guard let steps = steps, steps > 0 else { return "Ingen data" }
        let kilometers = StepSyncService.convertStepsToKilometers(steps)
        return String(format: "≈ %.1f km", kilometers)
    }
}

private extension NumberFormatter {
    static let stepsFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        return formatter
    }()
}

private struct MonthlySummary {
    let totalSessions: Int
    let totalDurationSeconds: Int
    let totalVolumeKg: Double
    let highlightedDays: Set<Int>
    let monthStartDate: Date
}

struct MonthlyReportView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var allPosts: [WorkoutPost] = []
    @State private var yearlyData: [Int: Double] = [:] // month: hours
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var hasLoaded = false
    
    private let calendar = Calendar.current
    
    private let isoFormatterWithFraction: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }()
    
    private let isoFormatterWithoutFraction: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }()
    
    // Get last month's date
    private var lastMonthDate: Date {
        calendar.date(byAdding: .month, value: -1, to: Date()) ?? Date()
    }
    
    private var currentMonth: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "LLLL"
        formatter.locale = Locale(identifier: "sv_SE")
        return formatter.string(from: lastMonthDate).capitalized
    }
    
    private var currentYear: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy"
        return formatter.string(from: lastMonthDate)
    }
    
    private var monthPosts: [WorkoutPost] {
        // Get last month's start and end
        guard let startOfLastMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: lastMonthDate)),
              let startOfCurrentMonth = calendar.date(byAdding: .month, value: 1, to: startOfLastMonth) else {
            return []
        }
        return allPosts.filter { post in
            guard let date = parseDate(post.createdAt) else { return false }
            return date >= startOfLastMonth && date < startOfCurrentMonth
        }
    }
    
    private var totalDays: Int {
        Set(monthPosts.compactMap { post -> Int? in
            guard let date = parseDate(post.createdAt) else { return nil }
            return calendar.component(.day, from: date)
        }).count
    }
    
    private var totalHours: Double {
        Double(monthPosts.reduce(0) { $0 + ($1.duration ?? 0) }) / 3600.0
    }
    
    private var totalDistance: Double {
        monthPosts.reduce(0) { $0 + ($1.distance ?? 0) } / 1000.0
    }
    
    private var totalElevation: Double {
        monthPosts.reduce(0) { $0 + ($1.elevationGain ?? 0) }
    }
    
    private var longestActivity: WorkoutPost? {
        monthPosts.max(by: { ($0.distance ?? 0) < ($1.distance ?? 0) })
    }
    
    private var highlightedDays: Set<Int> {
        Set(monthPosts.compactMap { post -> Int? in
            guard let date = parseDate(post.createdAt) else { return nil }
            return calendar.component(.day, from: date)
        })
    }
    
    private var sportBreakdown: [(type: String, count: Int, percentage: Double, color: Color)] {
        var counts: [String: Int] = [:]
        for post in monthPosts {
            let type = post.activityType
            counts[type, default: 0] += 1
        }
        let total = counts.values.reduce(0, +)
        guard total > 0 else { return [] }
        
        let colors: [Color] = [.primary, Color(.systemGray2), Color(.systemGray4), Color(.systemGray5)]
        return counts.sorted { $0.value > $1.value }.enumerated().map { index, item in
            (type: item.key, count: item.value, percentage: Double(item.value) / Double(total) * 100, color: colors[index % colors.count])
        }
    }
    
    private var topSport: String {
        sportBreakdown.first?.type ?? "Träning"
    }
    
    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: 0) {
                    if isLoading {
                        loadingView
                            .frame(width: geometry.size.width, height: geometry.size.height)
                    } else if let errorMessage {
                        errorView(errorMessage)
                            .frame(width: geometry.size.width, height: geometry.size.height)
                    } else {
                        // Black header section
                        headerSection(geometry: geometry)
                        
                        // Year chart
                        yearChartSection(geometry: geometry)
                        
                        // Month totals
                        monthTotalsSection(geometry: geometry)
                        
                        // Calendar
                        calendarSection(geometry: geometry)
                        
                        // Top Sports
                        topSportsSection(geometry: geometry)
                        
                        // Longest Activity
                        longestActivitySection(geometry: geometry)
                        
                        // Kudos section
                        kudosSection(geometry: geometry)
                    }
                }
            }
        }
        .background(Color(.systemBackground))
        .navigationTitle("Månadsrecap")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if !hasLoaded {
                hasLoaded = true
                await loadData()
            }
        }
    }
    
    // MARK: - Header Section
    private func headerSection(geometry: GeometryProxy) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(authViewModel.currentUser?.name.uppercased() ?? "DIN RECAP")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.gray)
                .tracking(2)
            
            Spacer()
            
            VStack(alignment: .leading, spacing: -10) {
                Text(currentMonth)
                    .font(.system(size: min(geometry.size.width * 0.16, 60), weight: .light))
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                Text(currentYear)
                    .font(.system(size: min(geometry.size.width * 0.16, 60), weight: .light))
                    .foregroundColor(.gray.opacity(0.6))
                    .lineLimit(1)
            }
            
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 40)
        .frame(maxWidth: .infinity, minHeight: geometry.size.height * 0.7, alignment: .leading)
        .background(Color.black)
    }
    
    // MARK: - Year Chart Section
    private func yearChartSection(geometry: GeometryProxy) -> some View {
        let screenWidth = geometry.size.width
        let barWidth = max(8, (screenWidth - 60) / 14)
        
        return VStack(spacing: 0) {
            Spacer()
            HStack(alignment: .bottom, spacing: 2) {
                ForEach(1...12, id: \.self) { month in
                    VStack(spacing: 6) {
                        let hours = yearlyData[month] ?? 0
                        let maxHours = max(yearlyData.values.max() ?? 1, 1)
                        let barHeight: CGFloat = 120
                        let height = maxHours > 0 ? (hours / maxHours) * barHeight : 0
                        
                        if month == calendar.component(.month, from: lastMonthDate) && hours > 0 {
                            Text("\(Int(hours))h")
                                .font(.system(size: 7, weight: .bold))
                                .foregroundColor(.white)
                                .fixedSize()
                        }
                        
                        RoundedRectangle(cornerRadius: 2)
                            .fill(month == calendar.component(.month, from: lastMonthDate) ? Color.white : Color.white.opacity(0.3))
                            .frame(width: barWidth, height: max(4, height))
                        
                        Text(monthAbbreviation(month))
                            .font(.system(size: 7, weight: .bold))
                            .foregroundColor(month == calendar.component(.month, from: lastMonthDate) ? .white : .white.opacity(0.4))
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, 16)
            Spacer()
        }
        .frame(maxWidth: .infinity, minHeight: 220)
        .background(Color.black)
    }
    
    // MARK: - Month Totals Section
    private func monthTotalsSection(geometry: GeometryProxy) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("TOTALS")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.primary)
                .tracking(1)
            
            HStack(alignment: .top, spacing: 12) {
                // Large Days on the left
                VStack(alignment: .leading, spacing: 0) {
                    Rectangle()
                        .fill(Color.primary)
                        .frame(height: 2)
                        .padding(.bottom, 6)
                    
                    HStack {
                        Spacer()
                        Text("DAYS")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.gray)
                    }
                    
                    Text("\(totalDays)")
                        .font(.system(size: min(geometry.size.width * 0.22, 90), weight: .thin))
                        .foregroundColor(.primary)
                        .minimumScaleFactor(0.5)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity)
                
                // Other stats on the right
                VStack(alignment: .leading, spacing: 0) {
                    // Hours
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(height: 1)
                    HStack {
                        Image(systemName: "clock")
                            .font(.system(size: 14))
                            .foregroundColor(.primary)
                        Text(String(format: "%.0f", totalHours))
                            .font(.system(size: 24, weight: .regular))
                            .foregroundColor(.primary)
                        Spacer()
                        Text("HRS")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.gray)
                    }
                    .padding(.vertical, 12)
                    
                    // Distance
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(height: 1)
                    HStack {
                        Image(systemName: "location.north.fill")
                            .font(.system(size: 14))
                            .foregroundColor(.primary)
                            .rotationEffect(.degrees(45))
                        Text(String(format: "%.1f", totalDistance))
                            .font(.system(size: 24, weight: .regular))
                            .foregroundColor(.primary)
                        Spacer()
                        Text("KM")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.gray)
                    }
                    .padding(.vertical, 12)
                    
                    // Elevation
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(height: 1)
                    HStack {
                        Image(systemName: "mountain.2.fill")
                            .font(.system(size: 14))
                            .foregroundColor(.primary)
                        Text(String(format: "%.0f", totalElevation))
                            .font(.system(size: 24, weight: .regular))
                            .foregroundColor(.primary)
                        Spacer()
                        Text("M")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.gray)
                    }
                    .padding(.vertical, 12)
                    
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(height: 1)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 30)
        .frame(maxWidth: .infinity)
        .background(Color(.systemBackground))
    }
    
    // MARK: - Calendar Section
    private func calendarSection(geometry: GeometryProxy) -> some View {
        let weekdaySymbols = ["M", "T", "W", "T", "F", "S", "S"]
        let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: lastMonthDate))!
        let daysInMonth = calendar.range(of: .day, in: .month, for: startOfMonth)?.count ?? 30
        let rawWeekday = calendar.component(.weekday, from: startOfMonth)
        let leadingDays = rawWeekday == 1 ? 6 : rawWeekday - 2
        let cellSize: CGFloat = min((geometry.size.width - 80) / 7, 36)
        
        return VStack(alignment: .leading, spacing: 20) {
            HStack {
                ForEach(weekdaySymbols, id: \.self) { symbol in
                    Text(symbol)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.gray)
                        .frame(maxWidth: .infinity)
                }
            }
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7), spacing: 16) {
                ForEach(0..<leadingDays, id: \.self) { _ in
                    Circle()
                        .fill(Color.clear)
                        .frame(width: 4, height: 4)
                }
                
                ForEach(1...daysInMonth, id: \.self) { day in
                    if highlightedDays.contains(day) {
                        ZStack {
                            Circle()
                                .fill(Color.primary)
                                .frame(width: cellSize, height: cellSize)
                            Text("\(day)")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(Color(.systemBackground))
                        }
                    } else {
                        Circle()
                            .fill(Color(.systemGray4))
                            .frame(width: 5, height: 5)
                    }
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 30)
        .frame(maxWidth: .infinity)
        .background(Color(.systemBackground))
    }
    
    // MARK: - Top Sports Section
    private func topSportsSection(geometry: GeometryProxy) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("TOP SPORTS")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.primary)
                .tracking(1)
            
            Text(topSport)
                .font(.system(size: min(geometry.size.width * 0.18, 70), weight: .thin))
                .foregroundColor(.primary)
                .minimumScaleFactor(0.5)
                .lineLimit(1)
            
            if !sportBreakdown.isEmpty {
                // Legend - wrapped
                FlowLayout(spacing: 12) {
                    ForEach(sportBreakdown, id: \.type) { sport in
                        HStack(spacing: 6) {
                            Circle()
                                .fill(sport.color)
                                .frame(width: 8, height: 8)
                            Image(systemName: sportIcon(for: sport.type))
                                .font(.system(size: 12))
                                .foregroundColor(.primary)
                            Text("\(Int(sport.percentage))%")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.gray)
                        }
                    }
                }
                .padding(.vertical, 8)
                
                // Stacked bar
                GeometryReader { barGeometry in
                    HStack(spacing: 0) {
                        ForEach(sportBreakdown, id: \.type) { sport in
                            Rectangle()
                                .fill(sport.color)
                                .frame(width: barGeometry.size.width * (sport.percentage / 100))
                        }
                    }
                    .cornerRadius(4)
                }
                .frame(height: 80)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 40)
        .frame(maxWidth: .infinity)
        .background(Color(.systemGroupedBackground))
    }
    
    // MARK: - Longest Activity Section
    @ViewBuilder
    private func longestActivitySection(geometry: GeometryProxy) -> some View {
        if let post = longestActivity {
            VStack(alignment: .leading, spacing: 16) {
                Text("LONGEST ACTIVITY")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.primary)
                    .tracking(1)
                    .padding(.horizontal, 20)
                
                ZStack(alignment: .bottomLeading) {
                    if let imageUrl = post.imageUrl, let url = URL(string: imageUrl) {
                        AsyncImage(url: url) { image in
                            image
                                .resizable()
                                .scaledToFill()
                        } placeholder: {
                            Rectangle()
                                .fill(Color.gray.opacity(0.1))
                        }
                        .frame(width: geometry.size.width, height: 350)
                        .clipped()
                    } else {
                        Rectangle()
                            .fill(Color.gray.opacity(0.2))
                            .frame(width: geometry.size.width, height: 350)
                            .overlay(
                                Image(systemName: "map.fill")
                                    .font(.system(size: 50))
                                    .foregroundColor(.gray)
                            )
                    }
                    
                    // Overlay info
                    VStack(alignment: .leading, spacing: 6) {
                        Text(post.title)
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.white)
                            .lineLimit(1)
                        
                        HStack(spacing: 12) {
                            Image(systemName: "calendar")
                                .font(.system(size: 12))
                            Text(formatActivityDate(post.createdAt))
                                .font(.system(size: 13, weight: .medium))
                        }
                        .foregroundColor(.white.opacity(0.9))
                        
                        HStack(spacing: 12) {
                            Image(systemName: "location")
                                .font(.system(size: 12))
                            if let distance = post.distance {
                                Text("\(String(format: "%.1f", distance / 1000)) km")
                                    .font(.system(size: 13, weight: .medium))
                            }
                            if let elevation = post.elevationGain {
                                Text("\(String(format: "%.0f", elevation)) m")
                                    .font(.system(size: 13, weight: .medium))
                            }
                        }
                        .foregroundColor(.white.opacity(0.9))
                    }
                    .padding(20)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        LinearGradient(colors: [.black.opacity(0.85), .clear], startPoint: .bottom, endPoint: .top)
                    )
                }
            }
            .padding(.top, 20)
            .frame(maxWidth: .infinity)
            .background(Color(.systemBackground))
        }
    }
    
    // MARK: - Kudos Section
    private func kudosSection(geometry: GeometryProxy) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            Spacer()
            
            Text("Bra jobbat, \(authViewModel.currentUser?.name ?? "du")!")
                .font(.system(size: min(geometry.size.width * 0.11, 44), weight: .light))
                .foregroundColor(.primary)
                .minimumScaleFactor(0.6)
                .lineLimit(2)
            
            Text("Du har tränat \(totalDays) \(totalDays == 1 ? "dag" : "dagar") denna \(currentMonth.lowercased()).")
                .font(.system(size: 17))
                .foregroundColor(.gray)
            
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 60)
        .frame(maxWidth: .infinity, minHeight: 300)
        .background(Color(.systemBackground))
    }
    
    // Simple flow layout for wrapping
    private struct FlowLayout: Layout {
        var spacing: CGFloat = 8
        
        func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
            let result = layout(subviews: subviews, proposal: proposal)
            return result.size
        }
        
        func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
            let result = layout(subviews: subviews, proposal: proposal)
            for (index, frame) in result.frames.enumerated() {
                subviews[index].place(at: CGPoint(x: bounds.minX + frame.minX, y: bounds.minY + frame.minY), proposal: .unspecified)
            }
        }
        
        private func layout(subviews: Subviews, proposal: ProposedViewSize) -> (size: CGSize, frames: [CGRect]) {
            var frames: [CGRect] = []
            var x: CGFloat = 0
            var y: CGFloat = 0
            var lineHeight: CGFloat = 0
            let maxWidth = proposal.width ?? .infinity
            
            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)
                if x + size.width > maxWidth && x > 0 {
                    x = 0
                    y += lineHeight + spacing
                    lineHeight = 0
                }
                frames.append(CGRect(origin: CGPoint(x: x, y: y), size: size))
                lineHeight = max(lineHeight, size.height)
                x += size.width + spacing
            }
            
            return (CGSize(width: maxWidth, height: y + lineHeight), frames)
        }
    }
    
    // MARK: - Loading & Error Views
    private var loadingView: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text("Hämtar din månadsrecap…")
                .font(.callout)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 400)
    }
    
    private func errorView(_ message: String) -> some View {
        VStack(spacing: 12) {
            Text(message)
                .font(.callout)
                .foregroundColor(.primary)
                .multilineTextAlignment(.center)
            Button(action: {
                Task { await loadData() }
            }) {
                Text("Försök igen")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 10)
                    .background(Color.primary)
                    .clipShape(Capsule())
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
    }
    
    // MARK: - Helper Functions
    private func loadData() async {
        guard let userId = authViewModel.currentUser?.id else {
            await MainActor.run {
                self.errorMessage = "Kunde inte hämta användaruppgifter."
                self.isLoading = false
            }
            return
        }
        
        await MainActor.run {
            self.isLoading = true
            self.errorMessage = nil
        }
        
        do {
            let posts = try await WorkoutService.shared.getUserWorkoutPosts(userId: userId, forceRefresh: true)
            
            // Calculate yearly data
            var yearData: [Int: Double] = [:]
            let currentYear = calendar.component(.year, from: Date())
            
            for post in posts {
                guard let date = parseDate(post.createdAt) else { continue }
                let year = calendar.component(.year, from: date)
                if year == currentYear {
                    let month = calendar.component(.month, from: date)
                    let hours = Double(post.duration ?? 0) / 3600.0
                    yearData[month, default: 0] += hours
                }
            }
            
            await MainActor.run {
                self.allPosts = posts
                self.yearlyData = yearData
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "Kunde inte hämta statistik just nu."
                self.isLoading = false
            }
        }
    }
    
    private func parseDate(_ isoString: String) -> Date? {
        if let date = isoFormatterWithFraction.date(from: isoString) {
            return date
        }
        return isoFormatterWithoutFraction.date(from: isoString)
    }
    
    private func formatActivityDate(_ isoString: String) -> String {
        let date = parseDate(isoString) ?? Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM d, yyyy"
        formatter.locale = Locale(identifier: "sv_SE")
        return formatter.string(from: date)
    }
    
    private func volumeFromExercises(_ exercises: [GymExercisePost]?) -> Double {
        guard let exercises else { return 0 }
        return exercises.reduce(0) { runningTotal, exercise in
            let setVolume = zip(exercise.kg, exercise.reps).reduce(0.0) { $0 + $1.0 * Double($1.1) }
            return runningTotal + setVolume
        }
    }
    
    private func monthAbbreviation(_ month: Int) -> String {
        let abbreviations = ["", "JAN", "FEB", "MAR", "APR", "MAY", "JUN", "JUL", "AUG", "SEP", "OCT", "NOV", "DEC"]
        return abbreviations[month]
    }
    
    private func sportIcon(for type: String) -> String {
        switch type.lowercased() {
        case "run", "löpning", "running": return "figure.run"
        case "swim", "simning", "swimming": return "figure.pool.swim"
        case "cycle", "cykling", "cycling": return "figure.outdoor.cycle"
        case "gym", "gympass", "strength": return "dumbbell.fill"
        case "golf": return "figure.golf"
        default: return "figure.walk"
        }
    }
}

private struct MonthlyStatCard: View {
    let title: String
    let value: String
    let subtitle: String
    var icon: String = "chart.bar.fill"
    var color: Color = .primary
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(color)
            
            Text(value)
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 8)
        .frame(maxWidth: .infinity)
        .background(Color(.systemBackground))
        .cornerRadius(14)
        .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 4)
    }
}

private struct MonthlyCalendarView: View {
    let monthStart: Date
    let highlightedDays: Set<Int>
    
    private let calendar = Calendar.current
    private let weekdaySymbols = ["Mån", "Tis", "Ons", "Tor", "Fre", "Lör", "Sön"]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Weekday headers
            HStack {
                ForEach(weekdaySymbols, id: \.self) { symbol in
                    Text(symbol)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 7), spacing: 10) {
                ForEach(0..<leadingEmptyDays, id: \.self) { _ in
                    Rectangle()
                        .foregroundColor(.clear)
                        .frame(height: 36)
                }
                
                ForEach(1...daysInMonth, id: \.self) { day in
                    dayCell(for: day)
                }
            }
        }
    }
    
    private var daysInMonth: Int {
        calendar.range(of: .day, in: .month, for: monthStart)?.count ?? 30
    }
    
    private var leadingEmptyDays: Int {
        let weekday = calendar.component(.weekday, from: monthStart)
        return (weekday + 5) % 7
    }
    
    private func dayCell(for day: Int) -> some View {
        let date = calendar.date(byAdding: .day, value: day - 1, to: monthStart) ?? monthStart
        let today = Date()
        let isFuture = date > today
        let isHighlighted = highlightedDays.contains(day)
        let isToday = calendar.isDateInToday(date)
        
        return Text("\(day)")
            .font(.system(size: 15, weight: isHighlighted || isToday ? .bold : .medium))
            .frame(width: 36, height: 36)
            .background(
                ZStack {
                    if isHighlighted {
                        Circle()
                            .fill(Color.green)
                    } else if isToday {
                        Circle()
                            .stroke(Color.primary, lineWidth: 2)
                    } else if !isFuture {
                        Circle()
                            .fill(Color(.systemGray6))
                    }
                }
            )
            .foregroundColor(isHighlighted ? .white : (isFuture ? .secondary.opacity(0.4) : .primary))
    }
}

// MARK: - Progressive Overload Supporting Types

struct StatSetSnapshot: Identifiable {
    let id = UUID()
    let weight: Double
    let reps: Int
    
    var estimated1RM: Double {
        guard reps > 0 else { return weight }
        if reps == 1 { return weight }
        return weight * (1 + Double(reps) / 30.0)
    }
}

struct StatExerciseSnapshot: Identifiable {
    let id = UUID()
    let date: Date
    let bestSet: StatSetSnapshot
    let sets: [StatSetSnapshot]
    let category: String?
    
    var estimated1RM: Double {
        bestSet.estimated1RM
    }
}

struct StatExerciseHistory: Identifiable {
    let id = UUID()
    let name: String
    let category: String?
    let exerciseId: String?
    let history: [StatExerciseSnapshot]
    
    var latestSnapshot: StatExerciseSnapshot? { history.last }
    
    var personalBestWeight: Double? {
        history.flatMap { $0.sets }.map { $0.weight }.max()
    }
    
    var trendPercentage: Double {
        guard history.count >= 2 else { return 0 }
        let firstWeight = history.first?.bestSet.weight ?? 0
        let lastWeight = history.last?.bestSet.weight ?? 0
        return firstWeight > 0 ? ((lastWeight - firstWeight) / firstWeight) * 100 : 0
    }
    
    var trendMessage: String {
        let change = trendPercentage
        if change > 5 {
            return "+\(String(format: "%.0f", change))%"
        } else if change > 0 {
            return "+\(String(format: "%.1f", change))%"
        } else if change < -5 {
            return "\(String(format: "%.0f", change))%"
        } else if change < 0 {
            return "\(String(format: "%.1f", change))%"
        } else {
            return "Platå"
        }
    }
    
    var trendColor: Color {
        let change = trendPercentage
        if change > 0 { return .green }
        if change < 0 { return .secondary }
        return .gray
    }
    
    var trendIcon: String {
        let change = trendPercentage
        if change > 5 { return "flame.fill" }
        if change > 0 { return "arrow.up.right" }
        if change < 0 { return "arrow.down.right" }
        return "pause.fill"
    }
}

// MARK: - Exercise Row for Statistics
struct StatExerciseRow: View {
    let history: StatExerciseHistory
    var isLast: Bool = false
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 14) {
                // Exercise image from API
                if let exerciseId = history.exerciseId {
                    ExerciseGIFView(exerciseId: exerciseId, gifUrl: nil)
                        .frame(width: 56, height: 56)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                } else {
                    // Fallback gradient icon
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(
                                LinearGradient(
                                    colors: [Color.green.opacity(0.2), Color.green.opacity(0.1)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 56, height: 56)
                        
                        Image(systemName: "dumbbell.fill")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundColor(.green)
                    }
                }
                
                // Exercise info
                VStack(alignment: .leading, spacing: 4) {
                    Text(history.name)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    HStack(spacing: 6) {
                        if let category = history.category {
                            Text(category)
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                        }
                        
                        Text("•")
                            .font(.system(size: 8))
                            .foregroundColor(.secondary.opacity(0.4))
                        
                        Text("\(history.history.count) pass")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                // Weight and trend
                VStack(alignment: .trailing, spacing: 6) {
                    if let bestWeight = history.personalBestWeight {
                        HStack(spacing: 2) {
                            Text("\(String(format: "%.0f", bestWeight))")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(.primary)
                            Text("kg")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    if history.history.count >= 2 {
                        HStack(spacing: 4) {
                            Image(systemName: history.trendIcon)
                                .font(.system(size: 10, weight: .bold))
                            Text(history.trendMessage)
                                .font(.system(size: 12, weight: .bold))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(history.trendColor)
                                .shadow(color: history.trendColor.opacity(0.3), radius: 4, x: 0, y: 2)
                        )
                    }
                }
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.secondary.opacity(0.4))
            }
            .padding(.vertical, 14)
            .padding(.horizontal, 16)
            
            if !isLast {
                Divider()
                    .padding(.leading, 86)
            }
        }
    }
}

// MARK: - All Exercises List View
struct AllExercisesListView: View {
    let exerciseHistories: [StatExerciseHistory]
    @State private var searchText = ""
    
    private var filteredExercises: [StatExerciseHistory] {
        if searchText.isEmpty {
            return exerciseHistories
        }
        return exerciseHistories.filter { 
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            ($0.category?.localizedCaseInsensitiveContains(searchText) ?? false)
        }
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Stats header
                HStack(spacing: 16) {
                    StatMiniCard(
                        value: "\(exerciseHistories.count)",
                        label: "Övningar",
                        icon: "dumbbell.fill",
                        color: .green
                    )
                    
                    StatMiniCard(
                        value: "\(exerciseHistories.filter { $0.trendPercentage > 0 }.count)",
                        label: "Ökar",
                        icon: "arrow.up.right",
                        color: .green
                    )
                    
                    StatMiniCard(
                        value: "\(exerciseHistories.filter { $0.history.count >= 3 }.count)",
                        label: "3+ pass",
                        icon: "star.fill",
                        color: .orange
                    )
                }
                .padding(.horizontal, 16)
                
                // Search bar
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 16))
                        .foregroundColor(.secondary)
                    
                    TextField("Sök övning...", text: $searchText)
                        .font(.system(size: 16))
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(Color(.secondarySystemBackground))
                .cornerRadius(12)
                .padding(.horizontal, 16)
                
                // Exercise list
                VStack(spacing: 0) {
                    ForEach(Array(filteredExercises.enumerated()), id: \.element.id) { index, history in
                        NavigationLink {
                            StatExerciseDetailView(history: history)
                        } label: {
                            StatExerciseRow(history: history, isLast: index == filteredExercises.count - 1)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .background(Color(.secondarySystemBackground))
                .cornerRadius(20)
                .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 4)
                .padding(.horizontal, 16)
                .padding(.bottom, 20)
            }
            .padding(.top, 16)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Alla övningar")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Mini Stat Card
private struct StatMiniCard: View {
    let value: String
    let label: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(color)
            
            Text(value)
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(.primary)
            
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(14)
    }
}

// MARK: - Exercise Detail View with Chart
struct StatExerciseDetailView: View {
    let history: StatExerciseHistory
    
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "sv_SE")
        formatter.dateFormat = "d MMM yyyy"
        return formatter
    }()
    
    private let shortDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "sv_SE")
        formatter.dateFormat = "d MMM"
        return formatter
    }()
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Hero card with image
                heroCard
                
                // Stats grid
                statsGrid
                
                // Chart
                if history.history.count >= 2 {
                    chartCard
                }
                
                // History list
                historyCard
            }
            .padding(16)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(history.name)
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private var heroCard: some View {
        VStack(spacing: 16) {
            // Exercise image
            if let exerciseId = history.exerciseId {
                ExerciseGIFView(exerciseId: exerciseId, gifUrl: nil)
                    .frame(width: 120, height: 120)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 4)
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 20)
                        .fill(
                            LinearGradient(
                                colors: [Color.green.opacity(0.2), Color.green.opacity(0.1)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 120, height: 120)
                    
                    Image(systemName: "dumbbell.fill")
                        .font(.system(size: 44, weight: .medium))
                        .foregroundColor(.green)
                }
            }
            
            VStack(spacing: 6) {
                Text(history.name)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
                
                if let category = history.category {
                    Text(category)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background(Color(.tertiarySystemBackground))
                        .cornerRadius(8)
                }
            }
            
            if history.history.count >= 2 {
                HStack(spacing: 6) {
                    Image(systemName: history.trendIcon)
                        .font(.system(size: 14, weight: .bold))
                    Text(history.trendMessage)
                        .font(.system(size: 15, weight: .bold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 18)
                .padding(.vertical, 10)
                .background(
                    Capsule()
                        .fill(history.trendColor)
                        .shadow(color: history.trendColor.opacity(0.4), radius: 8, x: 0, y: 4)
                )
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(24)
        .shadow(color: Color.black.opacity(0.05), radius: 12, x: 0, y: 4)
    }
    
    private var statsGrid: some View {
        HStack(spacing: 12) {
            StatDetailCard(
                value: "\(String(format: "%.0f", history.latestSnapshot?.bestSet.weight ?? 0))",
                unit: "kg",
                label: "Senaste",
                icon: "clock.fill",
                color: .blue
            )
            
            StatDetailCard(
                value: "\(String(format: "%.0f", history.personalBestWeight ?? 0))",
                unit: "kg",
                label: "Personbästa",
                icon: "trophy.fill",
                color: .green
            )
            
            StatDetailCard(
                value: "\(history.history.count)",
                unit: "",
                label: "Pass",
                icon: "flame.fill",
                color: .orange
            )
        }
    }
    
    private var chartCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "chart.xyaxis.line")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.green)
                
                Text("Utvecklingskurva")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(.primary)
            }
            
            // Simple line chart
            GeometryReader { geometry in
                let data = history.history
                let maxWeight = data.map { $0.bestSet.weight }.max() ?? 1
                let minWeight = data.map { $0.bestSet.weight }.min() ?? 0
                let range = maxWeight - minWeight > 0 ? maxWeight - minWeight : 1
                let chartWidth = geometry.size.width - 50
                let chartHeight: CGFloat = 180
                let pointSpacing = chartWidth / CGFloat(max(data.count - 1, 1))
                
                ZStack(alignment: .bottomLeading) {
                    // Grid lines
                    VStack(spacing: 0) {
                        ForEach(0..<4) { i in
                            Rectangle()
                                .fill(Color.gray.opacity(0.15))
                                .frame(height: 1)
                            if i < 3 { Spacer() }
                        }
                    }
                    .frame(height: chartHeight)
                    .padding(.trailing, 50)
                    
                    // Area fill with gradient
                    if data.count > 1 {
                        Path { path in
                            path.move(to: CGPoint(x: 0, y: chartHeight))
                            for (index, snapshot) in data.enumerated() {
                                let x = CGFloat(index) * pointSpacing
                                let normalizedY = (snapshot.bestSet.weight - minWeight) / range
                                let y = chartHeight - normalizedY * chartHeight
                                path.addLine(to: CGPoint(x: x, y: y))
                            }
                            path.addLine(to: CGPoint(x: CGFloat(data.count - 1) * pointSpacing, y: chartHeight))
                            path.closeSubpath()
                        }
                        .fill(
                            LinearGradient(
                                colors: [Color.green.opacity(0.3), Color.green.opacity(0.05)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        
                        // Line
                        Path { path in
                            for (index, snapshot) in data.enumerated() {
                                let x = CGFloat(index) * pointSpacing
                                let normalizedY = (snapshot.bestSet.weight - minWeight) / range
                                let y = chartHeight - normalizedY * chartHeight
                                if index == 0 {
                                    path.move(to: CGPoint(x: x, y: y))
                                } else {
                                    path.addLine(to: CGPoint(x: x, y: y))
                                }
                            }
                        }
                        .stroke(Color.green, style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                        
                        // Points
                        ForEach(data.indices, id: \.self) { index in
                            let x = CGFloat(index) * pointSpacing
                            let normalizedY = (data[index].bestSet.weight - minWeight) / range
                            let y = chartHeight - normalizedY * chartHeight
                            
                            Circle()
                                .fill(Color(.systemBackground))
                                .frame(width: 12, height: 12)
                                .overlay(
                                    Circle()
                                        .fill(index == data.count - 1 ? Color.green : Color.green.opacity(0.6))
                                        .frame(width: 8, height: 8)
                                )
                                .shadow(color: Color.green.opacity(0.3), radius: 4, x: 0, y: 2)
                                .position(x: x, y: y)
                        }
                    }
                    
                    // Y-axis labels
                    VStack {
                        Text("\(Int(maxWeight)) kg")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("\(Int((maxWeight + minWeight) / 2)) kg")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("\(Int(minWeight)) kg")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                    .frame(height: chartHeight)
                    .offset(x: chartWidth + 10)
                }
                .frame(height: chartHeight)
            }
            .frame(height: 180)
        }
        .padding(20)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(20)
        .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 4)
    }
    
    private var historyCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.blue)
                
                Text("Historik")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(.primary)
                
                Spacer()
                
                Text("\(history.history.count) pass")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.secondary)
            }
            
            ForEach(Array(history.history.enumerated().reversed()), id: \.element.id) { index, snapshot in
                let previousSnapshot: StatExerciseSnapshot? = index > 0 ? history.history[index - 1] : nil
                let isLatest = index == history.history.count - 1
                
                HStack(spacing: 12) {
                    // Timeline indicator
                    VStack(spacing: 0) {
                        Circle()
                            .fill(isLatest ? Color.green : Color.gray.opacity(0.3))
                            .frame(width: 10, height: 10)
                        
                        if index > 0 {
                            Rectangle()
                                .fill(Color.gray.opacity(0.2))
                                .frame(width: 2)
                                .frame(maxHeight: .infinity)
                        }
                    }
                    .frame(width: 10)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(dateFormatter.string(from: snapshot.date))
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(isLatest ? .primary : .secondary)
                        
                        Text("\(String(format: "%.1f", snapshot.bestSet.weight)) kg × \(snapshot.bestSet.reps) reps")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 4) {
                        HStack(spacing: 2) {
                            Text("\(String(format: "%.0f", snapshot.bestSet.weight))")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(isLatest ? .primary : .secondary)
                            Text("kg")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                        
                        if let prev = previousSnapshot {
                            let delta = snapshot.bestSet.weight - prev.bestSet.weight
                            let sign = delta >= 0 ? "+" : ""
                            Text("\(sign)\(String(format: "%.1f", delta)) kg")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(delta >= 0 ? .green : .red)
                        }
                    }
                }
                .padding(.vertical, 8)
            }
        }
        .padding(20)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(20)
        .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 4)
    }
}

// MARK: - Stat Detail Card
private struct StatDetailCard: View {
    let value: String
    let unit: String
    let label: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(color)
            
            HStack(spacing: 2) {
                Text(value)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.primary)
                if !unit.isEmpty {
                    Text(unit)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                }
            }
            
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 2)
    }
}

#Preview {
    NavigationStack {
        StatisticsView()
            .environmentObject(AuthViewModel())
    }
}

#Preview("Monthly report") {
    NavigationStack {
        MonthlyReportView()
            .environmentObject(AuthViewModel())
    }
}
