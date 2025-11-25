import SwiftUI

@MainActor
struct ProgressiveOverloadView: View {
    @EnvironmentObject private var authViewModel: AuthViewModel
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var exerciseHistories: [ExerciseHistory] = []
    
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "sv_SE")
        formatter.dateFormat = "d MMM yyyy"
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
    
    var body: some View {
        ZStack {
            if isLoading {
                ProgressView()
                    .progressViewStyle(.circular)
            } else if let errorMessage {
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
                            Text("Följ din styrkeutveckling")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(.black)
                            Text("Se alla övningar du har loggat. Tryck in på en övning för att se vikter, datum och hur mycket du ökar eller minskar.")
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
                            ForEach(exerciseHistories) { history in
                                NavigationLink {
                                    ExerciseHistoryDetailView(history: history, dateFormatter: dateFormatter)
                                } label: {
                                    ExerciseHistoryRow(history: history, dateFormatter: dateFormatter)
                                }
                                .buttonStyle(.plain)
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
        .task { await loadExercises() }
        .refreshable { await loadExercises() }
    }
    
    private func loadExercises() async {
        guard let userId = authViewModel.currentUser?.id else {
            errorMessage = "Kunde inte hitta användare."
            exerciseHistories = []
            isLoading = false
            return
        }
        isLoading = true
        errorMessage = nil
        do {
            let posts = try await WorkoutService.shared.getUserWorkoutPosts(userId: userId, forceRefresh: true)
            let histories = computeHistories(from: posts)
            exerciseHistories = histories
            isLoading = false
        } catch {
            errorMessage = "Kunde inte hämta träningsdata just nu. Försök igen senare."
            exerciseHistories = []
            isLoading = false
        }
    }
    
    private func computeHistories(from posts: [WorkoutPost]) -> [ExerciseHistory] {
        var map: [String: [ExerciseSnapshot]] = [:]
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
                
                // Best set based on total volume (kg * reps)
                let bestSet = sets.max(by: { ($0.weight * Double($0.reps)) < ($1.weight * Double($1.reps)) }) ?? sets[0]
                
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
    
    private func parseDate(_ isoString: String) -> Date? {
        if let date = isoFormatter.date(from: isoString) {
            return date
        }
        return isoFallbackFormatter.date(from: isoString)
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
}

private struct ExerciseSnapshot: Identifiable {
    let id = UUID()
    let date: Date
    let bestSet: ExerciseSetSnapshot
    let sets: [ExerciseSetSnapshot]
    let category: String?
}

private struct ExerciseHistory: Identifiable {
    let id = UUID()
    let name: String
    let category: String?
    let history: [ExerciseSnapshot]
    
    var latestSnapshot: ExerciseSnapshot? { history.last }
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
                
                if let latest = history.latestSnapshot {
                    Text("\(String(format: "%.0f", latest.bestSet.weight)) kg")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(.black)
                }
            }
            
            if let latest = history.latestSnapshot {
                Text(dateFormatter.string(from: latest.date))
                    .font(.system(size: 14))
                    .foregroundColor(.gray)
                
                if history.history.count >= 2, let change = changeInfo {
                    HStack(spacing: 8) {
                        Image(systemName: change.icon)
                            .font(.system(size: 13, weight: .bold))
                        Text(change.text)
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(change.color)
                    .clipShape(Capsule())
                } else if history.history.count < 2 {
                    Text("Logga övningen två gånger för att se utveckling.")
                        .font(.system(size: 13))
                        .foregroundColor(.gray)
                }
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
    
    private var changeInfo: (text: String, color: Color, icon: String)? {
        guard history.history.count >= 2 else { return nil }
        let latest = history.history[history.history.count - 1]
        let previous = history.history[history.history.count - 2]
        
        let deltaWeight = latest.bestSet.weight - previous.bestSet.weight
        let deltaReps = latest.bestSet.reps - previous.bestSet.reps
        
        // Determine trend based on both weight and reps
        let weightIncreased = deltaWeight > 0.5
        let weightDecreased = deltaWeight < -0.5
        let repsIncreased = deltaReps > 0
        let repsDecreased = deltaReps < 0
        
        if weightIncreased || (abs(deltaWeight) < 0.5 && repsIncreased) {
            // Weight increased OR same weight but more reps
            var text = "Ökar"
            var parts: [String] = []
            if abs(deltaWeight) >= 0.5 {
                parts.append("+\(String(format: "%.1f", deltaWeight)) kg")
            }
            if deltaReps > 0 {
                parts.append("+\(deltaReps) reps")
            }
            if !parts.isEmpty {
                text = "Ökar \(parts.joined(separator: " / "))"
            }
            return (text, .green, "arrow.up")
        } else if weightDecreased || (abs(deltaWeight) < 0.5 && repsDecreased) {
            // Weight decreased OR same weight but fewer reps
            var text = "Minskar"
            var parts: [String] = []
            if abs(deltaWeight) >= 0.5 {
                parts.append("\(String(format: "%.1f", deltaWeight)) kg")
            }
            if deltaReps < 0 {
                parts.append("\(deltaReps) reps")
            }
            if !parts.isEmpty {
                text = "Minskar \(parts.joined(separator: " / "))"
            }
            return (text, .red, "arrow.down")
        } else {
            return ("Oförändrad ±0 kg", .gray, "minus")
        }
    }
}

// MARK: - Exercise History Detail View
private struct ExerciseHistoryDetailView: View {
    let history: ExerciseHistory
    let dateFormatter: DateFormatter
    
    var body: some View {
        ZStack {
            Color(.systemGroupedBackground)
                .ignoresSafeArea()
            
            if history.history.count < 2 {
                VStack(spacing: 16) {
                    Image(systemName: "chart.bar.xaxis")
                        .font(.system(size: 50))
                        .foregroundColor(.gray)
                    Text("Logga denna övning minst två gånger för att se din utveckling")
                        .font(.system(size: 16))
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
            } else {
                List {
                    Section {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(history.name)
                                .font(.system(size: 22, weight: .bold))
                                .foregroundColor(.black)
                            if let category = history.category {
                                Text(category)
                                    .font(.system(size: 15))
                                    .foregroundColor(.gray)
                            }
                        }
                        .padding(.vertical, 8)
                    }
                    
                    Section(header: Text("HISTORIK").font(.system(size: 13, weight: .semibold))) {
                        ForEach(Array(history.history.enumerated().reversed()), id: \.element.id) { index, snapshot in
                            let previousSnapshot = index < history.history.count - 1 ? history.history[history.history.count - index - 2] : nil
                            ExerciseSnapshotRow(
                                snapshot: snapshot,
                                previous: previousSnapshot,
                                dateFormatter: dateFormatter
                            )
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .navigationTitle("Utveckling")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Exercise Snapshot Row
private struct ExerciseSnapshotRow: View {
    let snapshot: ExerciseSnapshot
    let previous: ExerciseSnapshot?
    let dateFormatter: DateFormatter
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(dateFormatter.string(from: snapshot.date))
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.black)
            
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Bästa set:")
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                    Spacer()
                    HStack(spacing: 6) {
                        Text("\(String(format: "%.1f", snapshot.bestSet.weight)) kg")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.black)
                        Text("×")
                            .font(.system(size: 13))
                            .foregroundColor(.gray)
                        Text("\(snapshot.bestSet.reps) reps")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.black)
                    }
                }
                
                if let changeInfo = changeInfo {
                    HStack {
                        Text("Förändring:")
                            .font(.system(size: 14))
                            .foregroundColor(.gray)
                        Spacer()
                        HStack(spacing: 4) {
                            Image(systemName: changeInfo.icon)
                                .font(.system(size: 11, weight: .semibold))
                            Text(changeInfo.text)
                                .font(.system(size: 14, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(changeInfo.color)
                        .clipShape(Capsule())
                    }
                }
            }
        }
        .padding(.vertical, 6)
    }
    
    private var changeInfo: (text: String, color: Color, icon: String)? {
        guard let previous else { return nil }
        
        let deltaWeight = snapshot.bestSet.weight - previous.bestSet.weight
        let deltaReps = snapshot.bestSet.reps - previous.bestSet.reps
        let deltaVolume = snapshot.bestSet.effectiveLoad - previous.bestSet.effectiveLoad
        
        var parts: [String] = []
        if abs(deltaWeight) >= 0.05 {
            let sign = deltaWeight > 0 ? "+" : ""
            parts.append("\(sign)\(String(format: "%.1f", deltaWeight)) kg")
        }
        if deltaReps != 0 {
            let sign = deltaReps > 0 ? "+" : ""
            parts.append("\(sign)\(deltaReps) reps")
        }
        
        guard !parts.isEmpty else { return ("Ingen förändring", .gray, "minus") }
        
        let color: Color
        let icon: String
        if deltaVolume > 0.5 {
            color = .green
            icon = "arrow.up"
        } else if deltaVolume < -0.5 {
            color = .red
            icon = "arrow.down"
        } else {
            color = .gray
            icon = "minus"
        }
        
        return (parts.joined(separator: " / "), color, icon)
    }
}
