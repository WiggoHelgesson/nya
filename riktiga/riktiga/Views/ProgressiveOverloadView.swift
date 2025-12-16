import SwiftUI
import Charts

@MainActor
struct ProgressiveOverloadView: View {
    @EnvironmentObject private var authViewModel: AuthViewModel
    @State private var isLoading = true
    @State private var isRefreshing = false
    @State private var errorMessage: String?
    @State private var exerciseHistories: [ExerciseHistory] = []
    
    // Pro membership
    @State private var isPremium = RevenueCatManager.shared.isPremium
    @State private var showPaywall = false
    private let freeExerciseLimit = 3
    
    // Static cache for computed histories to avoid recomputing
    private static var cachedHistories: [ExerciseHistory] = []
    private static var cacheUserId: String?
    private static var cacheTime: Date = .distantPast
    private static let cacheValidDuration: TimeInterval = 120 // 2 minutes
    
    // Shared formatters (created once)
    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "sv_SE")
        formatter.dateFormat = "d MMM yyyy"
        return formatter
    }()
    
    private static let shortDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "sv_SE")
        formatter.dateFormat = "d MMM"
        return formatter
    }()
    
    private static let isoFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }()
    
    private static let isoFallbackFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }()
    
    var body: some View {
        ZStack {
            if isLoading && exerciseHistories.isEmpty {
                ProgressView()
                    .progressViewStyle(.circular)
            } else if let errorMessage, exerciseHistories.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 50))
                        .foregroundColor(.gray)
                    Text(errorMessage)
                        .font(.system(size: 16))
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
            } else if exerciseHistories.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "chart.bar")
                        .font(.system(size: 50))
                        .foregroundColor(.gray)
                    Text("Logga gympass för att se din utveckling här")
                        .font(.system(size: 16))
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        // Header section
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Följ din styrkeutveckling")
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundColor(.black)
                                
                                if isRefreshing {
                                    ProgressView()
                                        .scaleEffect(0.7)
                                }
                            }
                            Text("Spåra ditt personbästa över tid. Tryck på en övning för att se graf och detaljerad historik.")
                                .font(.system(size: 14))
                                .foregroundColor(.gray)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(16)
                        .background(Color.white)
                        .cornerRadius(12)
                        .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
                        .padding(.horizontal, 16)
                        .padding(.top, 16)
                        .padding(.bottom, 20)
                        
                        // Exercise list
                        LazyVStack(spacing: 12) {
                            ForEach(Array(exerciseHistories.enumerated()), id: \.element.id) { index, history in
                                if isPremium || index < freeExerciseLimit {
                                    // Full access for Pro or first 3 exercises
                                    NavigationLink {
                                        ExerciseHistoryDetailView(history: history, dateFormatter: Self.dateFormatter, shortDateFormatter: Self.shortDateFormatter)
                                    } label: {
                                        ExerciseHistoryRow(history: history, dateFormatter: Self.dateFormatter)
                                    }
                                    .buttonStyle(.plain)
                                } else {
                                    // Blurred row for non-Pro users
                                    Button {
                                        showPaywall = true
                                    } label: {
                                        ExerciseHistoryRow(history: history, dateFormatter: Self.dateFormatter)
                                            .blur(radius: 6)
                                            .overlay(
                                                HStack(spacing: 6) {
                                                    Image(systemName: "lock.fill")
                                                        .font(.system(size: 14, weight: .bold))
                                                    Text("PRO")
                                                        .font(.system(size: 14, weight: .black))
                                                }
                                                .foregroundColor(.black)
                                                .padding(.horizontal, 12)
                                                .padding(.vertical, 6)
                                                .background(
                                                    Capsule()
                                                        .fill(Color.white)
                                                        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                                                )
                                            )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 16)
                    }
                }
            }
        }
        .navigationTitle("Progressive Overload")
        .background(Color(.systemGroupedBackground))
        .task { await loadExercises(forceRefresh: false) }
        .refreshable { await loadExercises(forceRefresh: true) }
        .sheet(isPresented: $showPaywall) {
            PresentPaywallView()
        }
        .onReceive(RevenueCatManager.shared.$isPremium) { newValue in
            isPremium = newValue
        }
    }
    
    private func loadExercises(forceRefresh: Bool) async {
        guard let userId = authViewModel.currentUser?.id else {
            errorMessage = "Kunde inte hitta användare."
            exerciseHistories = []
            isLoading = false
            return
        }
        
        // Check cache first (show immediately if available)
        let cacheValid = Self.cacheUserId == userId && 
                         Date().timeIntervalSince(Self.cacheTime) < Self.cacheValidDuration
        
        if !forceRefresh && cacheValid && !Self.cachedHistories.isEmpty {
            exerciseHistories = Self.cachedHistories
            isLoading = false
            return
        }
        
        // Show loading only if no cached data
        if exerciseHistories.isEmpty {
            isLoading = true
        } else {
            isRefreshing = true
        }
        
        errorMessage = nil
        
        do {
            // Use cached workout data unless force refreshing
            let posts = try await WorkoutService.shared.getUserWorkoutPosts(userId: userId, forceRefresh: forceRefresh)
            
            // Compute histories
            let histories = computeHistories(from: posts)
            
            // Update cache
            Self.cachedHistories = histories
            Self.cacheUserId = userId
            Self.cacheTime = Date()
            
            exerciseHistories = histories
            isLoading = false
            isRefreshing = false
        } catch {
            // If we have cached data, keep showing it
            if exerciseHistories.isEmpty {
                errorMessage = "Kunde inte hämta träningsdata just nu. Försök igen senare."
            }
            isLoading = false
            isRefreshing = false
        }
    }
    
    private func computeHistories(from posts: [WorkoutPost]) -> [ExerciseHistory] {
        var map: [String: [ExerciseSnapshot]] = [:]
        
        // Use local formatters to avoid main actor issues
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        isoFormatter.timeZone = TimeZone(secondsFromGMT: 0)
        
        let isoFallbackFormatter = ISO8601DateFormatter()
        isoFallbackFormatter.formatOptions = [.withInternetDateTime]
        isoFallbackFormatter.timeZone = TimeZone(secondsFromGMT: 0)
        
        func parseDate(_ isoString: String) -> Date? {
            if let date = isoFormatter.date(from: isoString) {
                return date
            }
            return isoFallbackFormatter.date(from: isoString)
        }
        
        for post in posts {
            let type = post.activityType.lowercased()
            guard type.contains("gym") else { continue }
            guard let exercises = post.exercises, !exercises.isEmpty else { continue }
            guard let date = parseDate(post.createdAt) else { continue }
            
            for exercise in exercises {
                let sets = zip(exercise.kg, exercise.reps)
                    .map { ExerciseSetSnapshot(weight: $0.0, reps: $0.1) }
                    .filter { $0.reps > 0 }
                guard !sets.isEmpty else { continue }
                
                // Best set based on estimated 1RM (more accurate than volume)
                let bestSet = sets.max(by: { $0.estimated1RM < $1.estimated1RM }) ?? sets[0]
                
                let snapshot = ExerciseSnapshot(
                    date: date,
                    bestSet: bestSet,
                    sets: sets,
                    category: exercise.category
                )
                map[exercise.name, default: []].append(snapshot)
            }
        }
        
        let histories = map.map { name, snapshots -> ExerciseHistory in
            let sorted = snapshots.sorted { $0.date < $1.date }
            return ExerciseHistory(
                name: name,
                category: sorted.last?.category,
                history: sorted
            )
        }
        
        // Sort by latest activity
        return histories.sorted { (lhs, rhs) -> Bool in
            let leftDate = lhs.latestSnapshot?.date ?? .distantPast
            let rightDate = rhs.latestSnapshot?.date ?? .distantPast
            return leftDate > rightDate
        }
    }
}

// MARK: - Supporting Models
private struct ExerciseSetSnapshot: Identifiable {
    let id = UUID()
    let weight: Double
    let reps: Int
    
    var effectiveLoad: Double {
        weight * Double(reps)
    }
    
    /// Epley formula for estimated 1RM
    var estimated1RM: Double {
        guard reps > 0 else { return weight }
        if reps == 1 { return weight }
        return weight * (1 + Double(reps) / 30.0)
    }
}

private struct ExerciseSnapshot: Identifiable {
    let id = UUID()
    let date: Date
    let bestSet: ExerciseSetSnapshot
    let sets: [ExerciseSetSnapshot]
    let category: String?
    
    var estimated1RM: Double {
        bestSet.estimated1RM
    }
}

private struct ExerciseHistory: Identifiable {
    let id = UUID()
    let name: String
    let category: String?
    let history: [ExerciseSnapshot]
    
    var latestSnapshot: ExerciseSnapshot? { history.last }
    
    /// Simple trend for list view (fast, no full regression)
    var simpleTrendInfo: TrendInfo {
        guard history.count >= 2 else {
            return TrendInfo(type: .needsMoreData, slope: 0, r2: 0, message: "Behöver mer data")
        }
        
        let firstWeight = history.first?.bestSet.weight ?? 0
        let lastWeight = history.last?.bestSet.weight ?? 0
        let percentChange = firstWeight > 0 ? ((lastWeight - firstWeight) / firstWeight) * 100 : 0
        
        // Simple slope approximation
        let simpleSlope = history.count > 1 ? (lastWeight - firstWeight) / Double(history.count - 1) : 0
        
        let trendType: TrendType
        let message: String
        
        if percentChange > 5 {
            trendType = history.count >= 4 ? .strongIncrease : .increasing
            message = trendType == .strongIncrease ? "🔥 +\(String(format: "%.0f", percentChange))%" : "📈 +\(String(format: "%.0f", percentChange))%"
        } else if percentChange > 0 {
            trendType = .increasing
            message = "📈 +\(String(format: "%.1f", percentChange))%"
        } else if percentChange < -5 {
            trendType = history.count >= 4 ? .strongDecrease : .decreasing
            message = "📉 \(String(format: "%.0f", percentChange))%"
        } else if percentChange < 0 {
            trendType = .decreasing
            message = "\(String(format: "%.1f", percentChange))%"
        } else {
            trendType = .plateau
            message = "⏸️ Platå"
        }
        
        return TrendInfo(type: trendType, slope: simpleSlope, r2: 0, message: message)
    }
    
    /// Full trend analysis with linear regression (for detail view)
    var trendInfo: TrendInfo {
        guard history.count >= 2 else {
            return TrendInfo(type: .needsMoreData, slope: 0, r2: 0, message: "Behöver mer data")
        }
        
        let n = Double(history.count)
        let weights = history.map { $0.bestSet.weight }
        let indices = history.indices.map { Double($0) }
        
        // Calculate means
        let meanX = indices.reduce(0, +) / n
        let meanY = weights.reduce(0, +) / n
        
        // Calculate slope and intercept (linear regression)
        var numerator: Double = 0
        var denominator: Double = 0
        
        for i in 0..<history.count {
            let xDiff = Double(i) - meanX
            let yDiff = weights[i] - meanY
            numerator += xDiff * yDiff
            denominator += xDiff * xDiff
        }
        
        let slope = denominator != 0 ? numerator / denominator : 0
        
        // Calculate R² (coefficient of determination)
        var ssRes: Double = 0
        var ssTot: Double = 0
        let intercept = meanY - slope * meanX
        
        for i in 0..<history.count {
            let predicted = intercept + slope * Double(i)
            ssRes += pow(weights[i] - predicted, 2)
            ssTot += pow(weights[i] - meanY, 2)
        }
        
        let r2 = ssTot != 0 ? 1 - (ssRes / ssTot) : 0
        
        // Determine trend type
        let trendType: TrendType
        let message: String
        
        // Calculate percentage increase from first to last
        let firstWeight = history.first?.bestSet.weight ?? 0
        let lastWeight = history.last?.bestSet.weight ?? 0
        let percentChange = firstWeight > 0 ? ((lastWeight - firstWeight) / firstWeight) * 100 : 0
        
        if history.count < 3 {
            if slope > 0.5 {
                trendType = .increasing
                message = "Bra start! +\(String(format: "%.1f", percentChange))%"
            } else if slope < -0.5 {
                trendType = .decreasing
                message = "Nedgång \(String(format: "%.1f", percentChange))%"
            } else {
                trendType = .stable
                message = "Stabil nivå"
            }
        } else if slope > 1.0 && r2 > 0.5 {
            trendType = .strongIncrease
            message = "🔥 Stark utveckling! +\(String(format: "%.1f", percentChange))%"
        } else if slope > 0.3 {
            trendType = .increasing
            message = "📈 Ökar stadigt +\(String(format: "%.1f", percentChange))%"
        } else if slope < -1.0 && r2 > 0.5 {
            trendType = .strongDecrease
            message = "📉 Sjunkande trend \(String(format: "%.1f", percentChange))%"
        } else if slope < -0.3 {
            trendType = .decreasing
            message = "Svag nedgång \(String(format: "%.1f", percentChange))%"
        } else {
            trendType = .plateau
            message = "⏸️ Platå - dags att öka?"
        }
        
        return TrendInfo(type: trendType, slope: slope, r2: r2, message: message)
    }
    
    /// Personal best 1RM
    var personalBest1RM: Double {
        history.map { $0.estimated1RM }.max() ?? 0
    }
    
    /// Personal best weight (max weight lifted in any set)
    var personalBestWeight: Double? {
        history.flatMap { $0.sets }.map { $0.weight }.max()
    }
}

enum TrendType {
    case strongIncrease
    case increasing
    case stable
    case plateau
    case decreasing
    case strongDecrease
    case needsMoreData
    
    var color: Color {
        switch self {
        case .strongIncrease: return .green
        case .increasing: return .green.opacity(0.8)
        case .stable, .plateau: return .orange
        case .decreasing: return .red.opacity(0.8)
        case .strongDecrease: return .red
        case .needsMoreData: return .gray
        }
    }
    
    var icon: String {
        switch self {
        case .strongIncrease: return "flame.fill"
        case .increasing: return "arrow.up.right"
        case .stable: return "minus"
        case .plateau: return "pause.fill"
        case .decreasing: return "arrow.down.right"
        case .strongDecrease: return "arrow.down"
        case .needsMoreData: return "questionmark"
        }
    }
}

struct TrendInfo {
    let type: TrendType
    let slope: Double
    let r2: Double
    let message: String
}

// MARK: - Exercise History Row
private struct ExerciseHistoryRow: View {
    let history: ExerciseHistory
    let dateFormatter: DateFormatter
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(history.name)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.black)
                    
                    if let category = history.category {
                        Text(category)
                            .font(.system(size: 14))
                            .foregroundColor(.gray)
                    }
                }
                
                Spacer()
                
                // Show personal best (max weight lifted)
                VStack(alignment: .trailing, spacing: 2) {
                    if let bestWeight = history.personalBestWeight {
                        Text("\(String(format: "%.0f", bestWeight)) kg")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(.black)
                        Text("Personbästa")
                            .font(.system(size: 11))
                            .foregroundColor(.gray)
                    }
                }
            }
            
            // Session count and date
            HStack {
                Text("\(history.history.count) pass")
                    .font(.system(size: 13))
                    .foregroundColor(.gray)
                
                if let latest = history.latestSnapshot {
                    Text("•")
                        .foregroundColor(.gray.opacity(0.5))
                    Text(dateFormatter.string(from: latest.date))
                        .font(.system(size: 13))
                        .foregroundColor(.gray)
                }
            }
            
            // Trend badge (using simple trend for performance)
            let trend = history.simpleTrendInfo
            HStack(spacing: 8) {
                Image(systemName: trend.type.icon)
                    .font(.system(size: 13, weight: .bold))
                Text(trend.message)
                    .font(.system(size: 14, weight: .semibold))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(trend.type.color)
            .clipShape(Capsule())
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
        .drawingGroup() // GPU-accelerated rendering
    }
}

// MARK: - Chart Data Point
struct ChartDataPoint: Identifiable {
    let id = UUID()
    let date: Date
    let value: Double
    let label: String
}

// MARK: - Exercise History Detail View
private struct ExerciseHistoryDetailView: View {
    let history: ExerciseHistory
    let dateFormatter: DateFormatter
    let shortDateFormatter: DateFormatter
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Header card with stats
                statsCard
                
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
    
    private var statsCard: some View {
        VStack(spacing: 16) {
            // Exercise name and category
            VStack(spacing: 4) {
                Text(history.name)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.black)
                if let category = history.category {
                    Text(category)
                        .font(.system(size: 15))
                        .foregroundColor(.gray)
                }
            }
            
            Divider()
            
            // Stats row
            HStack(spacing: 0) {
                // Latest weight
                VStack(spacing: 4) {
                    Text("\(String(format: "%.0f", history.latestSnapshot?.bestSet.weight ?? 0))")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.black)
                    Text("Senaste vikt")
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                }
                .frame(maxWidth: .infinity)
                
                // Personal best weight
                VStack(spacing: 4) {
                    Text("\(String(format: "%.0f", history.personalBestWeight ?? 0))")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.green)
                    Text("Personbästa")
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                }
                .frame(maxWidth: .infinity)
                
                // Sessions
                VStack(spacing: 4) {
                    Text("\(history.history.count)")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.black)
                    Text("Pass")
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                }
                .frame(maxWidth: .infinity)
            }
            
            // Trend badge
            let trend = history.trendInfo
            HStack(spacing: 8) {
                Image(systemName: trend.type.icon)
                    .font(.system(size: 15, weight: .bold))
                Text(trend.message)
                    .font(.system(size: 15, weight: .semibold))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(trend.type.color)
            .clipShape(Capsule())
        }
        .padding(20)
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
    
    private var chartCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Utvecklingskurva")
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(.black)
            
            // Build chart data (personal best weight per session)
            let chartData = history.history.map { snapshot in
                ChartDataPoint(
                    date: snapshot.date,
                    value: snapshot.bestSet.weight,
                    label: shortDateFormatter.string(from: snapshot.date)
                )
            }
            
            Chart {
                // Area under the line
                ForEach(chartData) { point in
                    AreaMark(
                        x: .value("Datum", point.date),
                        y: .value("1RM", point.value)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.green.opacity(0.3), Color.green.opacity(0.05)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                }
                
                // Line
                ForEach(chartData) { point in
                    LineMark(
                        x: .value("Datum", point.date),
                        y: .value("1RM", point.value)
                    )
                    .foregroundStyle(Color.green)
                    .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                }
                
                // Points
                ForEach(chartData) { point in
                    PointMark(
                        x: .value("Datum", point.date),
                        y: .value("1RM", point.value)
                    )
                    .foregroundStyle(Color.green)
                    .symbolSize(60)
                }
                
                // Trend line
                if history.history.count >= 3 {
                    let trend = history.trendInfo
                    let first = chartData.first!
                    let last = chartData.last!
                    let firstY = first.value
                    let lastY = firstY + trend.slope * Double(chartData.count - 1)
                    
                    LineMark(
                        x: .value("Datum", first.date),
                        y: .value("1RM", firstY)
                    )
                    .foregroundStyle(Color.orange.opacity(0.7))
                    .lineStyle(StrokeStyle(lineWidth: 2, dash: [5, 5]))
                    
                    LineMark(
                        x: .value("Datum", last.date),
                        y: .value("1RM", lastY)
                    )
                    .foregroundStyle(Color.orange.opacity(0.7))
                    .lineStyle(StrokeStyle(lineWidth: 2, dash: [5, 5]))
                }
            }
            .chartYAxisLabel("Vikt (kg)")
            .chartYAxis {
                AxisMarks(position: .leading)
            }
            .frame(height: 220)
            
            // Legend
            HStack(spacing: 16) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 10, height: 10)
                    Text("Max vikt")
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                }
                
                if history.history.count >= 3 {
                    HStack(spacing: 6) {
                        RoundedRectangle(cornerRadius: 1)
                            .fill(Color.orange.opacity(0.7))
                            .frame(width: 20, height: 2)
                        Text("Trendlinje")
                            .font(.system(size: 12))
                            .foregroundColor(.gray)
                    }
                }
            }
        }
        .padding(20)
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
    
    private var historyCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Historik")
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(.black)
            
            ForEach(Array(history.history.enumerated().reversed()), id: \.element.id) { index, snapshot in
                let previousSnapshot: ExerciseSnapshot? = index > 0 ? history.history[index - 1] : nil
                
                VStack(spacing: 0) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(dateFormatter.string(from: snapshot.date))
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(.black)
                            
                            Text("\(String(format: "%.1f", snapshot.bestSet.weight)) kg × \(snapshot.bestSet.reps) reps")
                                .font(.system(size: 14))
                                .foregroundColor(.gray)
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing, spacing: 4) {
                            Text("\(String(format: "%.0f", snapshot.bestSet.weight)) kg")
                                .font(.system(size: 17, weight: .bold))
                                .foregroundColor(.black)
                            
                            // Change from previous
                            if let prev = previousSnapshot {
                                let delta = snapshot.bestSet.weight - prev.bestSet.weight
                                let sign = delta >= 0 ? "+" : ""
                                Text("\(sign)\(String(format: "%.1f", delta)) kg")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(delta >= 0 ? .green : .red)
                            }
                        }
                    }
                    .padding(.vertical, 12)
                    
                    if index > 0 {
                        Divider()
                    }
                }
            }
        }
        .padding(20)
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
}
