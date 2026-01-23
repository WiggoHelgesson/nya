import SwiftUI

struct WorkoutDetailView: View {
    let post: SocialWorkoutPost
    @Environment(\.dismiss) private var dismiss
    
    private var isGymPost: Bool {
        post.activityType == "Gympass"
    }
    
    var body: some View {
        if isGymPost {
            gymDetailView
        } else {
            runningDetailView
        }
    }
    
    // MARK: - Gym Detail View
    private var gymDetailView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // Header
                gymHeader
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                
                // Description if any
                if let description = post.description, !description.isEmpty {
                    Text(description)
                        .font(.system(size: 15))
                        .foregroundColor(.primary)
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                }
                
                // Stats Row
                gymStatsRow
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                
                Divider()
                    .padding(.vertical, 16)
                    .padding(.horizontal, 16)
                
                // Like/Comment/Share Row
                socialActionsRow
                    .padding(.horizontal, 16)
                
                Divider()
                    .padding(.vertical, 16)
                    .padding(.horizontal, 16)
                
                // Muscle Split Section
                if let exercises = post.exercises, !exercises.isEmpty {
                    muscleSplitSection(exercises: exercises)
                        .padding(.horizontal, 16)
                    
                    Divider()
                        .padding(.vertical, 16)
                        .padding(.horizontal, 16)
                    
                    // Workout Exercises Section
                    workoutSection(exercises: exercises)
                        .padding(.horizontal, 16)
                }
                
                Spacer(minLength: 40)
            }
        }
        .navigationTitle("Träningsdetaljer")
        .navigationBarTitleDisplayMode(.inline)
        .background(Color(.systemBackground))
    }
    
    // MARK: - Gym Header
    private var gymHeader: some View {
        HStack(spacing: 12) {
            // Avatar
            if let avatarUrl = post.userAvatarUrl, !avatarUrl.isEmpty {
                AsyncImage(url: URL(string: avatarUrl)) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Circle()
                        .fill(Color.gray.opacity(0.2))
                }
                .frame(width: 48, height: 48)
                .clipShape(Circle())
            } else {
                Circle()
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 48, height: 48)
                    .overlay(
                        Image(systemName: "person.fill")
                            .foregroundColor(.gray)
                    )
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(post.userName ?? "Användare")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)
                
                Text(formattedDate)
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
    }
    
    // MARK: - Gym Stats Row
    private var gymStatsRow: some View {
        HStack(spacing: 0) {
            // Time
            if let duration = post.duration {
                gymStatColumn(title: "Tid", value: formattedDuration)
            }
            
            // Volume
            if let volume = calculateVolume() {
                Divider()
                    .frame(height: 40)
                gymStatColumn(title: "Volym", value: formatVolume(volume))
            }
            
            // Sets
            if let exercises = post.exercises {
                let totalSets = exercises.reduce(0) { $0 + $1.sets }
                Divider()
                    .frame(height: 40)
                gymStatColumn(title: "Set", value: "\(totalSets)")
            }
        }
    }
    
    private func gymStatColumn(title: String, value: String) -> some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
            Text(value)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.primary)
        }
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - Social Actions Row
    private var socialActionsRow: some View {
        HStack(spacing: 24) {
            // Like
            HStack(spacing: 6) {
                Image(systemName: "hand.thumbsup")
                    .font(.system(size: 18))
                Text("\(post.likeCount ?? 0)")
                    .font(.system(size: 14, weight: .medium))
            }
            .foregroundColor(.primary)
            
            // Comment
            HStack(spacing: 6) {
                Image(systemName: "bubble.right")
                    .font(.system(size: 18))
                Text("\(post.commentCount ?? 0)")
                    .font(.system(size: 14, weight: .medium))
            }
            .foregroundColor(.primary)
            
            // Share
            Image(systemName: "square.and.arrow.up")
                .font(.system(size: 18))
                .foregroundColor(.primary)
            
            Spacer()
        }
    }
    
    // MARK: - Muscle Split Section
    private func muscleSplitSection(exercises: [GymExercisePost]) -> some View {
        let muscleSplits = calculateMuscleSplits(exercises: exercises)
        let sortedSplits = muscleSplits.sorted { $0.value > $1.value }
        let maxValue = sortedSplits.first?.value ?? 1
        
        return VStack(alignment: .leading, spacing: 12) {
            Text("Muskelfördelning")
                .font(.system(size: 14))
                .foregroundColor(.secondary)
            
            ForEach(sortedSplits.prefix(3), id: \.key) { muscle, percentage in
                VStack(alignment: .leading, spacing: 6) {
                    Text(muscle)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    HStack(spacing: 8) {
                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color.gray.opacity(0.15))
                                    .frame(height: 8)
                                
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color.black)
                                    .frame(width: geometry.size.width * CGFloat(percentage) / CGFloat(maxValue), height: 8)
                            }
                        }
                        .frame(height: 8)
                        
                        Text("\(percentage)%")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                            .frame(width: 40, alignment: .trailing)
                    }
                }
            }
            
            if sortedSplits.count > 3 {
                Button {
                    // Could expand to show all
                } label: {
                    Text("Visa \(sortedSplits.count - 3) till")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.black)
                }
                .padding(.top, 4)
            }
        }
    }
    
    // MARK: - Workout Section
    private func workoutSection(exercises: [GymExercisePost]) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Träning")
                .font(.system(size: 14))
                .foregroundColor(.secondary)
            
            ForEach(Array(exercises.enumerated()), id: \.offset) { index, exercise in
                exerciseCard(exercise: exercise)
            }
        }
    }
    
    private func exerciseCard(exercise: GymExercisePost) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Exercise header with GIF
            HStack(spacing: 12) {
                // Exercise GIF/Image placeholder
                if let exerciseId = exercise.id, !exerciseId.isEmpty {
                    AsyncImage(url: URL(string: "https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/\(exerciseId)/0.jpg")) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.gray.opacity(0.15))
                            .overlay(
                                Image(systemName: "figure.strengthtraining.traditional")
                                    .foregroundColor(.gray)
                            )
                    }
                    .frame(width: 50, height: 50)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                } else {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.gray.opacity(0.15))
                        .frame(width: 50, height: 50)
                        .overlay(
                            Image(systemName: "figure.strengthtraining.traditional")
                                .foregroundColor(.gray)
                        )
                }
                
                Text(exercise.name)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.black)
                
                Spacer()
            }
            
            // Sets table header
            HStack {
                Text("SET")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
                    .frame(width: 40, alignment: .leading)
                
                Text("VIKT & REPS")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
                
                Spacer()
            }
            .padding(.top, 4)
            
            // Sets
            ForEach(0..<exercise.sets, id: \.self) { setIndex in
                let weight = setIndex < exercise.kg.count ? exercise.kg[setIndex] : 0
                let reps = setIndex < exercise.reps.count ? exercise.reps[setIndex] : 0
                
                HStack {
                    Text("\(setIndex + 1)")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.primary)
                        .frame(width: 40, alignment: .leading)
                    
                    Text("\(formatWeight(weight))kg x \(reps) reps")
                        .font(.system(size: 15))
                        .foregroundColor(.primary)
                    
                    Spacer()
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .background(setIndex % 2 == 1 ? Color.gray.opacity(0.08) : Color.clear)
                .cornerRadius(6)
            }
            
            // Notes if any
            if let notes = exercise.notes, !notes.isEmpty {
                Text(notes)
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                    .padding(.top, 4)
            }
        }
        .padding(.bottom, 16)
    }
    
    // MARK: - Running Detail View (Original)
    private var runningDetailView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                SwipeableImageView(routeImage: post.imageUrl, userImage: post.userImageUrl)
                    .frame(maxWidth: .infinity)
                    .cornerRadius(16)
                    .shadow(radius: 6)
                
                overviewSection
                splitsSection
            }
            .padding(20)
        }
        .navigationTitle(post.title)
        .navigationBarTitleDisplayMode(.inline)
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
    }
    
    private var overviewSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                statBlock(title: "Distans", value: formattedDistance)
                Divider()
                statBlock(title: "Tid", value: formattedDuration)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color(.secondarySystemBackground))
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.05), radius: 6, x: 0, y: 3)
        }
    }
    
    private var splitsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Kilometersplittar")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.primary)
            
            if let splits = post.splits, !splits.isEmpty {
                VStack(spacing: 12) {
                    ForEach(splits) { split in
                        HStack {
                            VStack(alignment: .leading) {
                                Text("Km \(split.kilometerIndex)")
                                    .font(.system(size: 16, weight: .semibold))
                                Text(distanceString(for: split))
                                    .font(.system(size: 13))
                                    .foregroundColor(.gray)
                            }
                            Spacer()
                            VStack(alignment: .trailing) {
                                Text(paceString(for: split))
                                    .font(.system(size: 16, weight: .semibold))
                                Text(durationString(for: split))
                                    .font(.system(size: 13))
                                    .foregroundColor(.gray)
                            }
                        }
                        .padding(16)
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(10)
                        .shadow(color: Color.black.opacity(0.03), radius: 4, x: 0, y: 2)
                    }
                }
            } else {
                Text("Inga splits tillgängliga för detta pass.")
                    .font(.system(size: 15))
                    .foregroundColor(.gray)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(10)
                    .shadow(color: Color.black.opacity(0.03), radius: 4, x: 0, y: 2)
            }
        }
    }
    
    // MARK: - Helper Functions
    
    private func calculateVolume() -> Int? {
        guard let exercises = post.exercises else { return nil }
        var total = 0
        for exercise in exercises {
            for i in 0..<min(exercise.kg.count, exercise.reps.count) {
                total += Int(exercise.kg[i]) * exercise.reps[i]
            }
        }
        return total > 0 ? total : nil
    }
    
    private func formatVolume(_ volume: Int) -> String {
        if volume >= 1000 {
            let thousands = Double(volume) / 1000.0
            return String(format: "%.0f", thousands).replacingOccurrences(of: ".0", with: "") + " kg"
        }
        return "\(volume) kg"
    }
    
    private func formatWeight(_ weight: Double) -> String {
        if weight == floor(weight) {
            return String(format: "%.0f", weight)
        } else {
            return String(format: "%.1f", weight)
        }
    }
    
    private func calculateMuscleSplits(exercises: [GymExercisePost]) -> [String: Int] {
        var muscleCount: [String: Int] = [:]
        
        for exercise in exercises {
            let category = exercise.category ?? "Övrigt"
            let swedishCategory = translateCategory(category)
            muscleCount[swedishCategory, default: 0] += 1
        }
        
        let total = muscleCount.values.reduce(0, +)
        guard total > 0 else { return [:] }
        
        var percentages: [String: Int] = [:]
        for (muscle, count) in muscleCount {
            percentages[muscle] = Int(round(Double(count) / Double(total) * 100))
        }
        
        return percentages
    }
    
    private func translateCategory(_ category: String) -> String {
        let translations: [String: String] = [
            "chest": "Bröst",
            "back": "Rygg",
            "shoulders": "Axlar",
            "biceps": "Biceps",
            "triceps": "Triceps",
            "arms": "Armar",
            "legs": "Ben",
            "quadriceps": "Lår",
            "hamstrings": "Baksida lår",
            "glutes": "Rumpa",
            "calves": "Vader",
            "abs": "Mage",
            "core": "Core",
            "cardio": "Kondition",
            "full body": "Helkropp",
            "Bröst": "Bröst",
            "Rygg": "Rygg",
            "Axlar": "Axlar",
            "Armar": "Armar",
            "Ben": "Ben",
            "Mage": "Mage"
        ]
        return translations[category.lowercased()] ?? category.capitalized
    }
    
    private var formattedDate: String {
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        if let date = dateFormatter.date(from: post.createdAt) {
            let displayFormatter = DateFormatter()
            displayFormatter.locale = Locale(identifier: "sv_SE")
            displayFormatter.dateFormat = "EEEE, d MMM yyyy - HH:mm"
            return displayFormatter.string(from: date).capitalized
        }
        
        // Fallback without fractional seconds
        dateFormatter.formatOptions = [.withInternetDateTime]
        if let date = dateFormatter.date(from: post.createdAt) {
            let displayFormatter = DateFormatter()
            displayFormatter.locale = Locale(identifier: "sv_SE")
            displayFormatter.dateFormat = "EEEE, d MMM yyyy - HH:mm"
            return displayFormatter.string(from: date).capitalized
        }
        
        return post.createdAt
    }
    
    private func statBlock(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title.uppercased())
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.gray)
            Text(value)
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private var formattedDistance: String {
        if let distance = post.distance {
            return String(format: "%.2f km", distance)
        }
        return "-"
    }
    
    private var formattedDuration: String {
        guard let duration = post.duration else { return "-" }
        let hours = duration / 3600
        let minutes = (duration % 3600) / 60
        let seconds = duration % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%d:%02dmin", minutes, seconds)
        }
    }
    
    private func paceString(for split: WorkoutSplit) -> String {
        let pace = max(split.paceSecondsPerKm, 0)
        let minutes = Int(pace) / 60
        let seconds = Int(pace) % 60
        return String(format: "%d:%02d /km", minutes, seconds)
    }
    
    private func durationString(for split: WorkoutSplit) -> String {
        let totalSeconds = max(split.durationSeconds, 0)
        let minutes = Int(totalSeconds) / 60
        let seconds = Int(totalSeconds) % 60
        if split.durationSeconds >= 3600 {
            let hours = Int(totalSeconds) / 3600
            return String(format: "%d:%02d:%02d", hours, minutes % 60, seconds)
        }
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    private func distanceString(for split: WorkoutSplit) -> String {
        if abs(split.distanceKm - 1.0) < 0.01 {
            return "1.00 km"
        }
        return String(format: "%.2f km", split.distanceKm)
    }
}
