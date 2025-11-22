import SwiftUI

struct StatisticsView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            List {
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
