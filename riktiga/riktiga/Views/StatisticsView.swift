import SwiftUI

struct StatisticsView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            List {
                Section("Steg statistik") {
                    StepStatisticsSectionView()
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                }
                Section {
                    NavigationLink(destination: UppyChatView()) {
                        UppyMenuRow(
                            title: "Prata med UPPY",
                            subtitle: "Chatta med din AI-coach direkt i appen"
                        )
                    }
                    NavigationLink(destination: MonthlyReportView()) {
                        StatisticsMenuRow(
                            icon: "doc.text.magnifyingglass",
                            title: "Månadsrapport",
                            subtitle: "Sammanfattning av dina pass denna månad"
                        )
                    }
                    NavigationLink(destination: CalendarOverviewView()) {
                        StatisticsMenuRow(
                            icon: "calendar",
                            title: "Kalender",
                            subtitle: "Se alla träningsdagar i månad, år eller flera år"
                        )
                    }
                    NavigationLink(destination: ProgressiveOverloadView()) {
                        StatisticsMenuRow(
                            icon: "chart.bar.xaxis",
                            title: "Progressive Overload",
                            subtitle: "Följ din styrkeutveckling över tid"
                        )
                    }
                    NavigationLink(destination: UppyChatView(initialPrompt: "Vilken övning kör jag mest på gymmet?")) {
                        StatisticsMenuRow(
                            icon: "dumbbell.fill",
                            title: "Mest använda gymövningar",
                            subtitle: "Se vilka övningar du gör mest"
                        )
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Statistik")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Stäng") { dismiss() }
                    .foregroundColor(.black)
                }
            }
        }
        .enableSwipeBack()
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
            VStack(spacing: 24) {
                modePicker
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
            .padding(20)
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
                    .background(Color.black)
                    .foregroundColor(.white)
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
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(monthLabel)
                .font(.system(size: 22, weight: .bold))
            
            let weekdaySymbols = calendar.shortWeekdaySymbols
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 7), spacing: 12) {
                ForEach(weekdaySymbols, id: \.self) { symbol in
                    Text(symbol.capitalized)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.gray)
                        .frame(maxWidth: .infinity)
                }
                
                ForEach(0..<firstWeekdayOffset, id: \.self) { _ in
                    Text("")
                        .frame(height: 36)
                }
                
                ForEach(daysInMonth, id: \.self) { day in
                    let date = dayDate(day: day)
                    let isWorkoutDay = date.map { workoutSet.contains(calendar.startOfDay(for: $0)) } ?? false
                    Text("\(day)")
                        .font(.system(size: 15, weight: .semibold))
                        .frame(width: 38, height: 38)
                        .background(
                            Circle()
                                .fill(isWorkoutDay ? Color.black : Color.clear)
                                .overlay(
                                    Circle()
                                        .stroke(Color.black.opacity(0.08), lineWidth: isWorkoutDay ? 0 : 1)
                                )
                        )
                        .foregroundColor(isWorkoutDay ? .white : .primary)
                }
            }
            .padding()
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 6)
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
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(yearFormatter.string(from: referenceDate))
                .font(.system(size: 22, weight: .bold))
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 2), spacing: 16) {
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
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(monthLabel)
                .font(.system(size: 15, weight: .semibold))
            let days = calendar.range(of: .day, in: .month, for: monthStart) ?? 1..<32
            let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)
            LazyVGrid(columns: columns, spacing: 4) {
                ForEach(days, id: \.self) { day in
                    let date = makeDate(day: day)
                    let hasWorkout = date.map { workoutSet.contains(calendar.startOfDay(for: $0)) } ?? false
                    Circle()
                        .fill(hasWorkout ? Color.black : Color(.systemGray5))
                        .frame(width: 10, height: 10)
                }
            }
        }
        .padding(12)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 4)
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
    
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("Flera år")
                .font(.system(size: 22, weight: .bold))
            if years.isEmpty {
                Text("Inga registrerade pass ännu.")
                    .font(.callout)
                    .foregroundColor(.secondary)
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
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("\(year)")
                .font(.system(size: 17, weight: .semibold))
            let months = (0..<12).compactMap { offset -> Date? in
                var comps = DateComponents()
                comps.year = year
                comps.month = offset + 1
                comps.day = 1
                return calendar.date(from: comps)
            }
            LazyVGrid(columns: Array(repeating: GridItem(.fixed(16), spacing: 4), count: 12), spacing: 4) {
                ForEach(months, id: \.self) { monthStart in
                    MiniMonthDot(monthStart: monthStart, workoutSet: workoutSet, calendar: calendar)
                }
            }
        }
        .padding(.vertical, 6)
    }
}

private struct MiniMonthDot: View {
    let monthStart: Date
    let workoutSet: Set<Date>
    let calendar: Calendar
    
    var body: some View {
        let hasWorkout = monthHasWorkout
        RoundedRectangle(cornerRadius: 4, style: .continuous)
            .fill(hasWorkout ? Color.black : Color(.systemGray5))
            .frame(width: 14, height: 14)
    }
    
    private var monthHasWorkout: Bool {
        let range = calendar.range(of: .day, in: .month, for: monthStart) ?? 1..<32
        for day in range {
            var comps = calendar.dateComponents([.year, .month], from: monthStart)
            comps.day = day
            if let date = calendar.date(from: comps) {
                if workoutSet.contains(calendar.startOfDay(for: date)) {
                    return true
                }
            }
        }
        return false
    }
}

private struct StatisticsMenuRow: View {
    let icon: String
    let assetName: String?
    let title: String
    let subtitle: String
    
    init(icon: String, assetName: String? = nil, title: String, subtitle: String) {
        self.icon = icon
        self.assetName = assetName
        self.title = title
        self.subtitle = subtitle
    }
    
    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color(.systemGray6))
                    .frame(width: 48, height: 48)
                if let assetName {
                    Image(assetName)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 42, height: 42)
                        .clipShape(Circle())
                } else {
                    Image(systemName: icon)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.black)
                }
            }
            VStack(alignment: .leading, spacing: 4) {
            Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.black)
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundColor(.gray)
            }
        }
        .padding(.vertical, 4)
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
                        .foregroundColor(.black)
                    
                    if let uppyText {
                        LinearGradient(
                            colors: [Color.black, Color.gray.opacity(0.75), Color.gray.opacity(0.55)],
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
                            .foregroundColor(.yellow)
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
                                .background(Color.black)
                                .foregroundColor(.white)
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
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 6)
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

private struct MonthlyReportView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var summary: MonthlySummary?
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var hasLoaded = false
    
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
    
    private let monthFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "LLLL yyyy"
        formatter.locale = Locale(identifier: "sv_SE")
        return formatter
    }()
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                if isLoading {
                    loadingView
                } else if let errorMessage {
                    errorView(errorMessage)
                } else if let summary {
                    summaryContent(for: summary)
                } else {
                    Text("Inga data att visa ännu.")
                        .font(.callout)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 40)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 24)
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .navigationTitle("Månadsrapport")
        .task {
            if !hasLoaded {
                hasLoaded = true
                await loadMonthlySummary()
            }
        }
    }
    
    private var loadingView: some View {
        HStack(spacing: 12) {
            ProgressView()
            Text("Hämtar månadsdata…")
                .font(.callout)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.top, 60)
    }
    
    private func errorView(_ message: String) -> some View {
        VStack(spacing: 12) {
            Text(message)
                .font(.callout)
                .foregroundColor(.primary)
                .multilineTextAlignment(.center)
            Button(action: {
                Task { await loadMonthlySummary() }
            }) {
                Text("Försök igen")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 10)
                    .background(Color.black)
                    .clipShape(Capsule())
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
    }
    
    private func summaryContent(for summary: MonthlySummary) -> some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Så går det i \(monthFormatter.string(from: summary.monthStartDate).capitalized)")
                    .font(.system(size: 22, weight: .bold))
                Text("Statistiken gäller pass registrerade från månadens början fram till idag.")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }
            
            let statsData: [(title: String, value: String, subtitle: String)] = [
                ("Pass", "\(summary.totalSessions)", "denna månad"),
                ("Tid", formatDuration(summary.totalDurationSeconds), "total tid"),
                ("Volym", formatVolume(summary.totalVolumeKg), "summa kg")
            ]
            
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 12)], spacing: 12) {
                ForEach(statsData, id: \.title) { data in
                    MonthlyStatCard(title: data.title, value: data.value, subtitle: data.subtitle)
                }
            }
            
            if summary.totalSessions == 0 {
                Text("Inga pass är registrerade ännu den här månaden. Ditt första pass kommer att dyka upp här!")
                    .font(.callout)
                    .foregroundColor(.secondary)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 6)
            }
            
            VStack(alignment: .leading, spacing: 16) {
                MonthlyCalendarView(monthStart: summary.monthStartDate, highlightedDays: summary.highlightedDays)
                
                if summary.highlightedDays.isEmpty {
                    Text("Planera in dina pass för att se kalendern fyllas med träningsdagar.")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                } else {
                    let dayCount = summary.highlightedDays.count
                    Text("\(dayCount) \(dayCount == 1 ? "dag" : "dagar") markerade som träningsdag denna månad.")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .shadow(color: Color.black.opacity(0.05), radius: 14, x: 0, y: 10)
        }
    }
    
    private func loadMonthlySummary() async {
        guard let userId = authViewModel.currentUser?.id else {
            await MainActor.run {
                self.errorMessage = "Det gick inte att hämta användaruppgifter. Logga in och försök igen."
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
            let summary = calculateSummary(from: posts)
            await MainActor.run {
                self.summary = summary
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "Kunde inte hämta statistik just nu."
                self.isLoading = false
            }
        }
    }
    
    private func calculateSummary(from posts: [WorkoutPost]) -> MonthlySummary {
        let calendar = Calendar.current
        let now = Date()
        guard let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: now)),
              let startOfNextMonth = calendar.date(byAdding: .month, value: 1, to: startOfMonth) else {
            return MonthlySummary(
                totalSessions: 0,
                totalDurationSeconds: 0,
                totalVolumeKg: 0,
                highlightedDays: [],
                monthStartDate: Date()
            )
        }
        
        var totalSessions = 0
        var totalDuration = 0
        var totalVolumeKg = 0.0
        var highlightedDays: Set<Int> = []
        
        for post in posts {
            guard let date = parseDate(post.createdAt) else { continue }
            if date >= startOfMonth && date < startOfNextMonth {
                totalSessions += 1
                totalDuration += post.duration ?? 0
                totalVolumeKg += volumeFromExercises(post.exercises)
                if let day = calendar.dateComponents([.day], from: date).day {
                    highlightedDays.insert(day)
                }
            }
        }
        
        return MonthlySummary(
            totalSessions: totalSessions,
            totalDurationSeconds: totalDuration,
            totalVolumeKg: totalVolumeKg,
            highlightedDays: highlightedDays,
            monthStartDate: startOfMonth
        )
    }
    
    private func parseDate(_ isoString: String) -> Date? {
        if let date = isoFormatterWithFraction.date(from: isoString) {
            return date
        }
        return isoFormatterWithoutFraction.date(from: isoString)
    }
    
    private func volumeFromExercises(_ exercises: [GymExercisePost]?) -> Double {
        guard let exercises else { return 0 }
        return exercises.reduce(0) { runningTotal, exercise in
            let setVolume = zip(exercise.kg, exercise.reps).reduce(0.0) { $0 + $1.0 * Double($1.1) }
            return runningTotal + setVolume
        }
    }
    
    private func formatDuration(_ seconds: Int) -> String {
        guard seconds > 0 else { return "0 min" }
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        if hours > 0 {
            return minutes > 0 ? "\(hours) h \(minutes) min" : "\(hours) h"
        }
        return "\(minutes) min"
    }
    
    private func formatVolume(_ volume: Double) -> String {
        String(format: "%.0f kg", volume)
    }
}

private struct MonthlyStatCard: View {
    let title: String
    let value: String
    let subtitle: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.secondary)
            Text(value)
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.black)
            Text(subtitle)
                .font(.system(size: 13))
                .foregroundColor(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: Color.black.opacity(0.05), radius: 12, x: 0, y: 8)
    }
}

private struct MonthlyCalendarView: View {
    let monthStart: Date
    let highlightedDays: Set<Int>
    
    private let calendar = Calendar.current
    private let weekdaySymbols = ["Mån", "Tis", "Ons", "Tor", "Fre", "Lör", "Sön"]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Kalender")
                .font(.system(size: 18, weight: .semibold))
            
            HStack {
                ForEach(weekdaySymbols, id: \.self) { symbol in
                    Text(symbol)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 7), spacing: 12) {
                ForEach(0..<leadingEmptyDays, id: \.self) { _ in
                    Rectangle()
                        .foregroundColor(.clear)
                        .frame(height: 32)
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
        
        return Text("\(day)")
            .font(.system(size: 15, weight: .semibold))
            .frame(maxWidth: .infinity, minHeight: 32)
            .padding(6)
            .background(
                Circle()
                    .fill(isHighlighted ? Color.black : Color.clear)
                    .overlay(
                        Circle()
                            .stroke(Color.black.opacity(isFuture ? 0.1 : 0.15), lineWidth: isHighlighted ? 0 : 1)
                    )
            )
            .foregroundColor(isHighlighted ? .white : (isFuture ? .gray.opacity(0.4) : .black))
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
