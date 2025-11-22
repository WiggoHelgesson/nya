import Foundation

actor UppyContextBuilder {
    static let shared = UppyContextBuilder()
    
    private struct CachedContext {
        let summary: String
        let workoutIds: [String]
        let generatedAt: Date
    }
    
    private let workoutService = WorkoutService.shared
    private let isoFormatter: ISO8601DateFormatter
    private let dateFormatter: DateFormatter
    private var cache: [String: CachedContext] = [:]
    private let cacheTTL: TimeInterval = 60 * 5 // 5 minutes
    
    private init() {
        isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        isoFormatter.timeZone = TimeZone(secondsFromGMT: 0)
        
        dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "sv_SE")
        dateFormatter.dateFormat = "d MMM yyyy"
    }
    
    func buildContext(for user: User?) async -> String? {
        guard let user = user else { return nil }
        do {
            let workouts = try await workoutService.getUserWorkoutPosts(userId: user.id, forceRefresh: false)
            let ids = workouts.map { $0.id }
            let now = Date()
            if let cached = cache[user.id], cached.workoutIds == ids, now.timeIntervalSince(cached.generatedAt) < cacheTTL {
                return cached.summary
            }
            guard !workouts.isEmpty else {
                let summary = "Användaren har ännu inga loggade träningspass."
                cache[user.id] = CachedContext(summary: summary, workoutIds: ids, generatedAt: now)
                return summary
            }
            let summary = await generateSummary(user: user, workouts: workouts)
            cache[user.id] = CachedContext(summary: summary, workoutIds: ids, generatedAt: now)
            return summary
        } catch {
            print("❌ UppyContextBuilder failed: \(error)")
            return nil
        }
    }
    
    private func generateSummary(user: User, workouts: [WorkoutPost]) async -> String {
        let totalDistance = workouts.compactMap { $0.distance }.reduce(0, +)
        let totalDuration = workouts.compactMap { $0.duration }.reduce(0, +)
        let activityStats = aggregateActivities(workouts: workouts)
        let recent = summarizeRecentWorkouts(workouts.prefix(8))
        let personalBests = formatPersonalBests(user: user)
        
        var lines: [String] = []
        lines.append("Användarnamn: \(user.name)")
        lines.append("Totalt loggade pass: \(workouts.count)")
        if totalDistance > 0 {
            lines.append("Total distans: \(formatDistance(totalDistance))")
        }
        if totalDuration > 0 {
            lines.append("Total träningstid: \(formatDuration(totalDuration))")
        }
        lines.append(contentsOf: activityStats)
        if let personalBests {
            lines.append("Personbästa: \(personalBests)")
        }
        lines.append("Senaste pass:")
        lines.append(contentsOf: recent)
        
        return lines.joined(separator: "\n")
    }
    
    private func aggregateActivities(workouts: [WorkoutPost]) -> [String] {
        var map: [String: (count: Int, distance: Double, duration: Int)] = [:]
        for workout in workouts {
            let key = workout.activityType.isEmpty ? "Okänd" : workout.activityType
            var entry = map[key] ?? (0, 0, 0)
            entry.count += 1
            if let distance = workout.distance {
                entry.distance += distance
            }
            if let duration = workout.duration {
                entry.duration += duration
            }
            map[key] = entry
        }
        guard !map.isEmpty else { return [] }
        let sorted = map.sorted { lhs, rhs in
            if lhs.value.count == rhs.value.count {
                return lhs.key < rhs.key
            }
            return lhs.value.count > rhs.value.count
        }
        let top = sorted.prefix(4)
        var lines: [String] = ["Aktivitetssammanfattning:"]
        for (activity, stats) in top {
            var components: [String] = []
            components.append("• \(activity): \(stats.count) pass")
            if stats.distance > 0 {
                components.append("\(formatDistance(stats.distance))")
            }
            if stats.duration > 0 {
                components.append(formatDuration(stats.duration))
            }
            lines.append(components.joined(separator: " – "))
        }
        return lines
    }
    
    private func summarizeRecentWorkouts(_ workouts: ArraySlice<WorkoutPost>) -> [String] {
        guard !workouts.isEmpty else { return ["• Inga tidigare pass hittades"] }
        var output: [String] = []
        for workout in workouts {
            let dateString = formattedDate(workout.createdAt)
            var headline = "• \(dateString) – \(workout.activityType)"
            if let distance = workout.distance, distance > 0 {
                headline += " – \(formatDistance(distance))"
            }
            if let duration = workout.duration, duration > 0 {
                headline += " – \(formatDuration(duration))"
            }
            output.append(headline)
            if !workout.title.isEmpty {
                output.append("  Titel: \(workout.title)")
            }
            if let exercises = workout.exercises, !exercises.isEmpty {
                let exerciseSummary = summarizeExercises(exercises)
                if !exerciseSummary.isEmpty {
                    output.append("  Övningar: \(exerciseSummary)")
                }
            }
        }
        return output
    }
    
    private func summarizeExercises(_ exercises: [GymExercisePost]) -> String {
        let limited = exercises.prefix(3)
        let parts = limited.map { exercise -> String in
            let setCount = exercise.sets
            let weightInfo: String
            if let maxSet = zip(exercise.kg, exercise.reps).max(by: { $0.0 < $1.0 }) {
                weightInfo = String(format: "%g kg x %d", maxSet.0, maxSet.1)
            } else if let firstWeight = exercise.kg.first, let firstRep = exercise.reps.first {
                weightInfo = String(format: "%g kg x %d", firstWeight, firstRep)
            } else {
                weightInfo = "\(exercise.reps.first ?? 0) reps"
            }
            return "\(exercise.name) (\(setCount) set) – \(weightInfo)"
        }
        return parts.joined(separator: "; ")
    }
    
    private func formattedDate(_ isoString: String) -> String {
        if let date = isoFormatter.date(from: isoString) {
            return dateFormatter.string(from: date)
        }
        return isoString
    }
    
    private func formatDistance(_ distance: Double) -> String {
        if distance >= 1 {
            return String(format: "%.1f km", distance)
        } else {
            return String(format: "%.0f m", distance * 1000)
        }
    }
    
    private func formatDuration(_ seconds: Int) -> String {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        let secs = seconds % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        } else {
            return String(format: "%02d:%02d", minutes, secs)
        }
    }
    
    private func formatPersonalBests(user: User) -> String? {
        var parts: [String] = []
        if let pb = user.pb5kmMinutes {
            parts.append("5 km: \(pb) min")
        }
        if let hours = user.pb10kmHours, let minutes = user.pb10kmMinutes {
            if hours > 0 {
                parts.append("10 km: \(hours) h \(minutes) min")
            } else {
                parts.append("10 km: \(minutes) min")
            }
        }
        if let hours = user.pbMarathonHours, let minutes = user.pbMarathonMinutes {
            parts.append("Marathon: \(hours) h \(minutes) min")
        }
        guard !parts.isEmpty else { return nil }
        return parts.joined(separator: ", ")
    }
}

