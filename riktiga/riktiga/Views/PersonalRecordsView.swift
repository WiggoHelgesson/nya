import SwiftUI
import Supabase

// MARK: - Models
struct RunningPR: Identifiable {
    let id = UUID()
    let distance: String
    let time: String?
    let date: Date?
}

struct GymPR: Identifiable {
    let id = UUID()
    let exerciseName: String
    let maxWeight: Double
    let reps: Int
    let date: Date?
}

// MARK: - Personal Records View
struct PersonalRecordsView: View {
    let userId: String
    let username: String
    
    @State private var runningPRs: [RunningPR] = []
    @State private var gymPRs: [GymPR] = []
    @State private var isLoading = true
    @State private var hasRunningData = false
    @State private var hasGymData = false
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Running PRs Section
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "figure.run")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(.primary)
                            Text("Löpning PR")
                                .font(.system(size: 20, weight: .bold))
                        }
                        .padding(.horizontal, 16)
                        
                        if isLoading {
                            HStack {
                                Spacer()
                                ProgressView()
                                Spacer()
                            }
                            .padding(.vertical, 20)
                        } else if !hasRunningData {
                            noDataCard(message: "Saknas data")
                        } else {
                            VStack(spacing: 8) {
                                ForEach(runningPRs) { pr in
                                    runningPRCard(pr: pr)
                                }
                            }
                            .padding(.horizontal, 16)
                        }
                    }
                    
                    Divider()
                        .padding(.horizontal, 16)
                    
                    // Gym PRs Section
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "dumbbell.fill")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(.primary)
                            Text("Gym PR")
                                .font(.system(size: 20, weight: .bold))
                        }
                        .padding(.horizontal, 16)
                        
                        if isLoading {
                            HStack {
                                Spacer()
                                ProgressView()
                                Spacer()
                            }
                            .padding(.vertical, 20)
                        } else if !hasGymData {
                            noDataCard(message: "Saknas data")
                        } else {
                            VStack(spacing: 8) {
                                ForEach(gymPRs) { pr in
                                    gymPRCard(pr: pr)
                                }
                            }
                            .padding(.horizontal, 16)
                        }
                    }
                    
                    Spacer(minLength: 40)
                }
                .padding(.top, 20)
            }
            .navigationTitle("\(username)s rekord")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Stäng") {
                        dismiss()
                    }
                }
            }
            .task {
                await loadPersonalRecords()
            }
        }
    }
    
    // MARK: - Card Views
    private func runningPRCard(pr: RunningPR) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(pr.distance)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)
                
                if let date = pr.date {
                    Text(formatDate(date))
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                }
            }
            
            Spacer()
            
            if let time = pr.time {
                Text(time)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.primary)
            } else {
                Text("–")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.gray)
            }
        }
        .padding(16)
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private func gymPRCard(pr: GymPR) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(pr.exerciseName)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)
                
                if let date = pr.date {
                    Text(formatDate(date))
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                }
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(Int(pr.maxWeight)) kg")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.primary)
                Text("\(pr.reps) reps")
                    .font(.system(size: 12))
                    .foregroundColor(.gray)
            }
        }
        .padding(16)
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private func noDataCard(message: String) -> some View {
        HStack {
            Spacer()
            VStack(spacing: 8) {
                Image(systemName: "chart.bar.xaxis")
                    .font(.system(size: 32))
                    .foregroundColor(.gray)
                Text(message)
                    .font(.system(size: 14))
                    .foregroundColor(.gray)
            }
            Spacer()
        }
        .padding(.vertical, 24)
        .padding(.horizontal, 16)
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .padding(.horizontal, 16)
    }
    
    // MARK: - Data Loading
    private func loadPersonalRecords() async {
        isLoading = true
        
        // Load running PRs and gym PRs in parallel
        async let runningTask = loadRunningPRs()
        async let gymTask = loadGymPRs()
        
        let (running, gym) = await (runningTask, gymTask)
        
        await MainActor.run {
            self.runningPRs = running
            self.gymPRs = gym
            self.hasRunningData = running.contains { $0.time != nil }
            self.hasGymData = !gym.isEmpty
            self.isLoading = false
        }
    }
    
    private func loadRunningPRs() async -> [RunningPR] {
        let supabase = SupabaseConfig.supabase
        
        // Fetch workout posts to calculate running PRs
        struct WorkoutData: Decodable {
            let distance: Double?
            let duration: Int?
            let activity_type: String
            let created_at: String
        }
        
        do {
            let workouts: [WorkoutData] = try await supabase
                .from("workout_posts")
                .select("distance, duration, activity_type, created_at")
                .eq("user_id", value: userId)
                .or("activity_type.eq.Löpning,activity_type.eq.Löppass,activity_type.eq.running,activity_type.eq.Running")
                .order("created_at", ascending: false)
                .execute()
                .value
            
            var best5km: (time: Int, date: Date)? = nil
            var best10km: (time: Int, date: Date)? = nil
            
            let dateFormatter = ISO8601DateFormatter()
            dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            
            for workout in workouts {
                guard let distance = workout.distance, let duration = workout.duration else { continue }
                
                let workoutDate = dateFormatter.date(from: workout.created_at)
                
                // Check for 5km PR (distance between 4.9 and 5.1 km)
                if distance >= 4.9 && distance <= 5.5 {
                    if best5km == nil || duration < best5km!.time {
                        best5km = (duration, workoutDate ?? Date())
                    }
                }
                
                // Check for 10km PR (distance between 9.9 and 10.5 km)
                if distance >= 9.9 && distance <= 10.5 {
                    if best10km == nil || duration < best10km!.time {
                        best10km = (duration, workoutDate ?? Date())
                    }
                }
            }
            
            return [
                RunningPR(
                    distance: "5 km",
                    time: best5km.map { formatDuration($0.time) },
                    date: best5km?.date
                ),
                RunningPR(
                    distance: "10 km",
                    time: best10km.map { formatDuration($0.time) },
                    date: best10km?.date
                )
            ]
        } catch {
            print("❌ Error loading running PRs: \(error)")
            return [
                RunningPR(distance: "5 km", time: nil, date: nil),
                RunningPR(distance: "10 km", time: nil, date: nil)
            ]
        }
    }
    
    private func loadGymPRs() async -> [GymPR] {
        let supabase = SupabaseConfig.supabase
        
        // Fetch gym workout posts with exercises
        struct GymWorkout: Decodable {
            let exercises_data: [ExerciseData]?
            let created_at: String
        }
        
        struct ExerciseData: Decodable {
            let name: String
            let kg: [Double]?
            let reps: [Int]?
        }
        
        do {
            let workouts: [GymWorkout] = try await supabase
                .from("workout_posts")
                .select("exercises_data, created_at")
                .eq("user_id", value: userId)
                .eq("activity_type", value: "Gympass")
                .order("created_at", ascending: false)
                .execute()
                .value
            
            // Track best weight for each exercise
            var exercisePRs: [String: (weight: Double, reps: Int, date: Date)] = [:]
            
            let dateFormatter = ISO8601DateFormatter()
            dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            
            for workout in workouts {
                guard let exercises = workout.exercises_data else { continue }
                let workoutDate = dateFormatter.date(from: workout.created_at) ?? Date()
                
                for exercise in exercises {
                    guard let kgs = exercise.kg, let reps = exercise.reps else { continue }
                    
                    // Find max weight for this exercise in this workout
                    for (index, kg) in kgs.enumerated() {
                        let rep = index < reps.count ? reps[index] : 0
                        
                        if let existing = exercisePRs[exercise.name] {
                            if kg > existing.weight {
                                exercisePRs[exercise.name] = (kg, rep, workoutDate)
                            }
                        } else {
                            exercisePRs[exercise.name] = (kg, rep, workoutDate)
                        }
                    }
                }
            }
            
            // Convert to array and sort by weight
            return exercisePRs.map { name, data in
                GymPR(exerciseName: name, maxWeight: data.weight, reps: data.reps, date: data.date)
            }
            .sorted { $0.maxWeight > $1.maxWeight }
            
        } catch {
            print("❌ Error loading gym PRs: \(error)")
            return []
        }
    }
    
    // MARK: - Helpers
    private func formatDuration(_ seconds: Int) -> String {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        let secs = seconds % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        } else {
            return String(format: "%d:%02d", minutes, secs)
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM yyyy"
        formatter.locale = Locale(identifier: "sv_SE")
        return formatter.string(from: date)
    }
}

#Preview {
    PersonalRecordsView(userId: "test", username: "Test")
}

