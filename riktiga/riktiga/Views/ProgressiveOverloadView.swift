import SwiftUI

@MainActor
struct ProgressiveOverloadView: View {
    @EnvironmentObject private var authViewModel: AuthViewModel
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var exerciseProgress: [ExerciseProgress] = []
    private let weightFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "sv_SE")
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 1
        return formatter
    }()
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "sv_SE")
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()
    private let isoFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }()
    private let isoFallbackFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }()
    private let changeThreshold: Double = 0.25
    
    var body: some View {
        ZStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Följ din styrkeutveckling")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.black)
                        Text("Vi jämför de två senaste passen per övning och visar om vikten ökar, står still eller minskar. Endast övningar som loggats minst två gånger visas.")
                            .font(.system(size: 13))
                            .foregroundColor(.gray)
                    }
                    .padding(.vertical, 4)
                }
                Section {
                    if let errorMessage {
                        Text(errorMessage)
                            .font(.system(size: 14))
                            .foregroundColor(.red)
                            .multilineTextAlignment(.leading)
                            .padding(.vertical, 8)
                            .listRowBackground(Color(.systemGroupedBackground))
                    } else if exerciseProgress.isEmpty {
                        Text("Logga samma övning i minst två gympass för att se din utveckling här.")
                            .font(.system(size: 14))
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.leading)
                            .padding(.vertical, 8)
                            .listRowBackground(Color(.systemGroupedBackground))
                    } else {
                        ForEach(exerciseProgress) { progress in
                            ExerciseProgressRow(
                                progress: progress,
                                weightFormatter: weightFormatter,
                                dateFormatter: dateFormatter
                            )
                            .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))
                            .listRowBackground(Color(.systemGroupedBackground))
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Progressive Overload")
            .refreshable { await loadProgress() }
            .task { await loadProgress() }
            
            if isLoading {
                ProgressView()
                    .progressViewStyle(.circular)
            }
        }
        .background(Color(.systemGroupedBackground))
    }
    
    private func loadProgress() async {
        guard let userId = authViewModel.currentUser?.id else {
            self.errorMessage = "Kunde inte hitta användare."
            self.exerciseProgress = []
            self.isLoading = false
            return
        }
        self.isLoading = true
        self.errorMessage = nil
        do {
            let posts = try await WorkoutService.shared.getUserWorkoutPosts(userId: userId, forceRefresh: true)
            let progress = computeProgress(from: posts)
            self.exerciseProgress = progress
            self.isLoading = false
        } catch {
            self.errorMessage = "Kunde inte hämta träningsdata just nu. Försök igen senare."
            self.exerciseProgress = []
            self.isLoading = false
        }
    }
    
    private func computeProgress(from posts: [WorkoutPost]) -> [ExerciseProgress] {
        var history: [String: [ExerciseSnapshot]] = [:]
        for post in posts {
            let type = post.activityType.lowercased()
            guard type.contains("gym") else { continue }
            guard let exercises = post.exercises else { continue }
            guard let date = parseDate(post.createdAt) else { continue }
            for exercise in exercises {
                let sets = zip(exercise.kg, exercise.reps)
                    .map { ExerciseSetSnapshot(weight: $0.0, reps: $0.1) }
                    .filter { $0.reps > 0 }
                guard !sets.isEmpty else { continue }
                guard let bestSet = sets.max(by: { $0.weight < $1.weight }) else { continue }
                let snapshot = ExerciseSnapshot(
                    date: date,
                    bestSet: bestSet,
                    sets: sets,
                    category: exercise.category
                )
                history[exercise.name, default: []].append(snapshot)
            }
        }
        var results: [ExerciseProgress] = []
        for (name, snapshots) in history {
            let sorted = snapshots.sorted { $0.date < $1.date }
            guard sorted.count >= 2 else { continue }
            let trimmedHistory = Array(sorted.suffix(8))
            guard let previous = trimmedHistory.dropLast().last, let latest = trimmedHistory.last else { continue }
            let delta = latest.bestSet.weight - previous.bestSet.weight
            let trend: ExerciseProgress.Trend
            if delta > changeThreshold {
                trend = .increase
            } else if delta < -changeThreshold {
                trend = .decrease
            } else {
                trend = .same
            }
            let progress = ExerciseProgress(
                name: name,
                category: latest.category,
                history: trimmedHistory,
                change: delta,
                trend: trend
            )
            results.append(progress)
        }
        return results.sorted { lhs, rhs in
            if lhs.trend.sortPriority != rhs.trend.sortPriority {
                return lhs.trend.sortPriority < rhs.trend.sortPriority
            }
            return lhs.latestDate > rhs.latestDate
        }
    }
}

extension ProgressiveOverloadView {
    private func parseDate(_ isoString: String) -> Date? {
        if let date = isoFormatter.date(from: isoString) {
            return date
        }
        return isoFallbackFormatter.date(from: isoString)
    }
}

private struct ExerciseSetSnapshot: Identifiable {
    let id = UUID()
    let weight: Double
    let reps: Int
}

private struct ExerciseSnapshot: Identifiable {
    let id = UUID()
    let date: Date
    let bestSet: ExerciseSetSnapshot
    let sets: [ExerciseSetSnapshot]
    let category: String?
}

private struct ExerciseProgressRow: View {
    let progress: ExerciseProgress
    let weightFormatter: NumberFormatter
    let dateFormatter: DateFormatter
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(progress.name)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.primary)
                    if let category = progress.category, !category.isEmpty {
                        Text(category)
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                    }
                }
                Spacer()
                TrendBadge(progress: progress)
            }
            
            SparklineView(progress: progress, weightFormatter: weightFormatter)
                .frame(height: 120)
                .padding(.horizontal, 4)
            
            HStack(alignment: .top, spacing: 20) {
                ProgressColumn(
                    title: "Senaste pass",
                    snapshot: progress.latestSnapshot,
                    weightFormatter: weightFormatter,
                    dateFormatter: dateFormatter
                )
                Divider()
                    .frame(height: 60)
                ProgressColumn(
                    title: "Föregående",
                    snapshot: progress.previousSnapshot,
                    weightFormatter: weightFormatter,
                    dateFormatter: dateFormatter
                )
            }
        }
        .padding(20)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(20)
        .shadow(color: Color.black.opacity(0.06), radius: 10, x: 0, y: 5)
    }
}

private struct SparklineView: View {
    let progress: ExerciseProgress
    let weightFormatter: NumberFormatter
    
    private var trackColor: Color {
        switch progress.trend {
        case .increase: return Color.green.opacity(0.9)
        case .same: return Color.gray.opacity(0.8)
        case .decrease: return Color.red.opacity(0.9)
        }
    }
    
    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let height = geometry.size.height
            let values = progress.history.map { $0.bestSet.weight }
            let minValue = values.min() ?? 0
            let maxValue = values.max() ?? 1
            let range = max(maxValue - minValue, 0.5)
            let verticalPadding: CGFloat = 24
            let stepX = progress.history.count > 1 ? width / CGFloat(progress.history.count - 1) : width
            
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.tertiarySystemBackground))
                
                if progress.history.count >= 2 {
                    let points = progress.history.enumerated().map { index, snapshot -> CGPoint in
                        let normalized = (snapshot.bestSet.weight - minValue) / range
                        let y = height - (CGFloat(normalized) * (height - verticalPadding) + verticalPadding / 2)
                        let x = CGFloat(index) * stepX
                        return CGPoint(x: x, y: y)
                    }
                    
                    Path { path in
                        guard let first = points.first else { return }
                        path.move(to: first)
                        for point in points.dropFirst() {
                            path.addLine(to: point)
                        }
                    }
                    .stroke(trackColor, style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))
                    .shadow(color: trackColor.opacity(0.25), radius: 6, x: 0, y: 5)
                    
                    HStack(spacing: 0) {
                        SparklineDot(value: progress.previousWeight, label: "Tidigare", formatter: weightFormatter, color: Color(.systemGray))
                        Spacer()
                        SparklineDot(value: progress.latestWeight, label: "Nu", formatter: weightFormatter, color: trackColor)
                    }
                    .padding(.horizontal, 4)
                    .padding(.top, 8)
                } else {
                    Text("För lite data")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
}

private struct SparklineDot: View {
    let value: Double
    let label: String
    let formatter: NumberFormatter
    let color: Color
    
    var body: some View {
        VStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 12, height: 12)
                .overlay(Circle().stroke(Color.white, lineWidth: 2))
                .shadow(color: color.opacity(0.6), radius: 4, x: 0, y: 2)
            VStack(spacing: 2) {
                Text("\(formattedValue) kg")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(color)
                Text(label)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private var formattedValue: String {
        formatter.string(from: NSNumber(value: value)) ?? String(format: "%.1f", value)
    }
}

private struct ProgressColumn: View {
    let title: String
    let snapshot: ExerciseSnapshot
    let weightFormatter: NumberFormatter
    let dateFormatter: DateFormatter
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title.uppercased())
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.secondary)
            Text("\(formattedWeight) kg")
                .font(.system(size: 20, weight: .bold))
            Text("\(snapshot.bestSet.reps) reps")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.secondary)
            Text(dateFormatter.string(from: snapshot.date))
                .font(.system(size: 12))
                .foregroundColor(.secondary)
            
            if !snapshot.sets.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(snapshot.sets) { set in
                            Text("\(format(set.weight)) kg × \(set.reps)")
                                .font(.system(size: 11, weight: .semibold))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Color(.systemGray6))
                                .clipShape(Capsule())
                        }
                    }
                }
                .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private var formattedWeight: String {
        weightFormatter.string(from: NSNumber(value: snapshot.bestSet.weight)) ?? String(format: "%.1f", snapshot.bestSet.weight)
    }
    
    private func format(_ value: Double) -> String {
        weightFormatter.string(from: NSNumber(value: value)) ?? String(format: "%.1f", value)
    }
}

private struct TrendBadge: View {
    let progress: ExerciseProgress
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: progress.trend.systemImage)
                .font(.system(size: 13, weight: .semibold))
            Text(progress.trend.title)
                .font(.system(size: 13, weight: .semibold))
            Text(progress.changeDescription)
                .font(.system(size: 12, weight: .semibold))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .foregroundColor(progress.trend.foregroundColor)
        .background(progress.trend.backgroundColor.opacity(0.15))
        .clipShape(Capsule())
    }
}

private struct ExerciseProgress: Identifiable {
    let id = UUID()
    let name: String
    let category: String?
    let history: [ExerciseSnapshot]
    let change: Double
    let trend: Trend
    
    var latestSnapshot: ExerciseSnapshot {
        history.last!
    }
    
    var previousSnapshot: ExerciseSnapshot {
        history.dropLast().last!
    }
    
    var latestWeight: Double { latestSnapshot.bestSet.weight }
    var latestDate: Date { latestSnapshot.date }
    var previousWeight: Double { previousSnapshot.bestSet.weight }
    var previousDate: Date { previousSnapshot.date }
    
    enum Trend {
        case increase
        case same
        case decrease
        
        var title: String {
            switch self {
            case .increase: return "Ökar"
            case .same: return "Oförändrad"
            case .decrease: return "Minskar"
            }
        }
        
        var systemImage: String {
            switch self {
            case .increase: return "arrow.up.right"
            case .same: return "minus"
            case .decrease: return "arrow.down.right"
            }
        }
        
        var foregroundColor: Color {
            switch self {
            case .increase: return Color.green
            case .same: return Color.gray
            case .decrease: return Color.red
            }
        }
        
        var backgroundColor: Color {
            switch self {
            case .increase: return Color.green
            case .same: return Color.gray
            case .decrease: return Color.red
            }
        }
        
        var sortPriority: Int {
            switch self {
            case .increase: return 0
            case .same: return 1
            case .decrease: return 2
            }
        }
    }
    
    var changeDescription: String {
        let absolute = abs(change)
        if absolute < 0.05 { return "±0 kg" }
        let formatted = String(format: "%.1f", absolute)
        let sign = change > 0 ? "+" : "−"
        return "\(sign)\(formatted) kg"
    }
}

#Preview {
    ProgressiveOverloadView()
        .environmentObject(AuthViewModel())
}

