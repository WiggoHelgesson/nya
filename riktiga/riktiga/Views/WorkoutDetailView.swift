import SwiftUI
import Foundation
import MapKit

struct WorkoutDetailView: View {
    let post: SocialWorkoutPost
    @Environment(\.dismiss) private var dismiss
    @State private var showRouteReplay = false
    
    private var isGymPost: Bool {
        post.activityType == "Gympass"
    }
    
    private var hasRouteData: Bool {
        guard let json = post.routeData, !json.isEmpty,
              let data = json.data(using: .utf8),
              let arr = try? JSONSerialization.jsonObject(with: data) as? [[String: Double]] else {
            return false
        }
        return arr.count >= 2
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
        .navigationTitle(L.t(sv: "Träningsdetaljer", nb: "Treningsdetaljer"))
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
                Text(post.userName ?? L.t(sv: "Användare", nb: "Bruker"))
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
                gymStatColumn(title: L.t(sv: "Tid", nb: "Tid"), value: formattedDuration)
            }
            
            // Volume
            if let volume = calculateVolume() {
                Divider()
                    .frame(height: 40)
                gymStatColumn(title: L.t(sv: "Volym", nb: "Volum"), value: formatVolume(volume))
            }
            
            // Sets
            if let exercises = post.exercises {
                let totalSets = exercises.reduce(0) { $0 + $1.sets }
                Divider()
                    .frame(height: 40)
                gymStatColumn(title: L.t(sv: "Set", nb: "Sett"), value: "\(totalSets)")
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
            Text(L.t(sv: "Muskelfördelning", nb: "Muskelfordeling"))
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
                    Text(L.t(sv: "Visa \(sortedSplits.count - 3) till", nb: "Vis \(sortedSplits.count - 3) til"))
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
            Text(L.t(sv: "Träning", nb: "Trening"))
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
            
            if exercise.isCardio == true, let seconds = exercise.cardioSeconds, seconds > 0 {
                HStack(spacing: 8) {
                    Image(systemName: "timer")
                        .foregroundColor(.black)
                        .font(.system(size: 20))
                    Text(formatCardioTime(seconds))
                        .font(.system(size: 28, weight: .bold, design: .monospaced))
                        .foregroundColor(.primary)
                }
                .padding(.vertical, 14)
                .padding(.horizontal, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.systemGray6))
                .cornerRadius(8)
            } else {
                // Sets table header
                HStack {
                    Text(L.t(sv: "SET", nb: "SETT"))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                        .frame(width: 40, alignment: .leading)
                    
                    Text(L.t(sv: "VIKT & REPS", nb: "VEKT & REPS"))
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
    
    // MARK: - Running Detail View (Strava-style)
    
    private var avgPace: String {
        guard let dist = post.distance, dist > 0, let dur = post.duration, dur > 0 else { return "-" }
        let paceSeconds = Double(dur) / dist
        let m = Int(paceSeconds) / 60
        let s = Int(paceSeconds) % 60
        return String(format: "%d:%02d /km", m, s)
    }
    
    private var movingTime: String {
        guard let duration = post.duration else { return "-" }
        let hours = duration / 3600
        let minutes = (duration % 3600) / 60
        let seconds = duration % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    private var elevationString: String {
        if let e = post.elevationGain, e > 0 {
            return "\(Int(e)) m"
        }
        return "-"
    }
    
    private var routeCoordinates: [CLLocationCoordinate2D] {
        guard let json = post.routeData, let data = json.data(using: .utf8),
              let arr = try? JSONSerialization.jsonObject(with: data) as? [[String: Double]] else { return [] }
        return arr.compactMap { dict in
            guard let lat = dict["lat"], let lon = dict["lon"] else { return nil }
            return CLLocationCoordinate2D(latitude: lat, longitude: lon)
        }
    }
    
    private var runningDetailView: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                
                // MARK: Live route map with play button
                ZStack(alignment: .topLeading) {
                    ZStack(alignment: .bottomTrailing) {
                        if routeCoordinates.count >= 2 {
                            WorkoutRouteMapView(coordinates: routeCoordinates)
                                .frame(height: UIScreen.main.bounds.height * 0.55)
                                .frame(maxWidth: .infinity)
                        } else {
                            SwipeableImageView(routeImage: post.imageUrl, userImage: post.userImageUrl)
                                .frame(maxWidth: .infinity)
                        }
                        
                        // Play button
                        if hasRouteData {
                            Button {
                                showRouteReplay = true
                            } label: {
                                Image(systemName: "play.fill")
                                    .font(.system(size: 22))
                                    .foregroundColor(.black)
                                    .offset(x: 2)
                                    .frame(width: 56, height: 56)
                                    .background(Circle().fill(Color.white))
                                    .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 3)
                            }
                            .padding(.trailing, 20)
                            .padding(.bottom, 20)
                        }
                    }
                    
                    // Back button overlay
                    Button { dismiss() } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.black)
                            .frame(width: 36, height: 36)
                            .background(Circle().fill(Color.white))
                            .shadow(color: .black.opacity(0.15), radius: 4, x: 0, y: 2)
                    }
                    .padding(.leading, 16)
                    .padding(.top, 56)
                }
                
                // MARK: Header (user + date)
                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: 10) {
                        if let avatarUrl = post.userAvatarUrl, !avatarUrl.isEmpty {
                            AsyncImage(url: URL(string: avatarUrl)) { image in
                                image.resizable().aspectRatio(contentMode: .fill)
                            } placeholder: {
                                Circle().fill(Color(.systemGray5))
                            }
                            .frame(width: 40, height: 40)
                            .clipShape(Circle())
                        } else {
                            Circle()
                                .fill(Color(.systemGray5))
                                .frame(width: 40, height: 40)
                                .overlay(Image(systemName: "person.fill").foregroundColor(.gray).font(.system(size: 16)))
                        }
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(post.userName ?? L.t(sv: "Användare", nb: "Bruker"))
                                .font(.system(size: 15, weight: .semibold))
                            Text(formattedDate)
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .padding(.bottom, 12)
                    
                    // MARK: Title + description
                    if !post.title.isEmpty {
                        Text(post.title)
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(.primary)
                            .padding(.horizontal, 16)
                    }
                    
                    if let desc = post.description, !desc.isEmpty {
                        Text(desc)
                            .font(.system(size: 15))
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 16)
                            .padding(.top, 4)
                    }
                    
                    // MARK: Stats grid
                    VStack(spacing: 0) {
                        HStack(spacing: 0) {
                            runStatCell(label: L.t(sv: "Distans", nb: "Distanse"), value: formattedDistance)
                            runStatCell(label: L.t(sv: "Snittempo", nb: "Snittempo"), value: avgPace)
                        }
                        
                        Divider().padding(.horizontal, 16)
                        
                        HStack(spacing: 0) {
                            runStatCell(label: L.t(sv: "Tid i rörelse", nb: "Tid i bevegelse"), value: movingTime)
                            runStatCell(label: L.t(sv: "Höjdmeter", nb: "Høydemeter"), value: elevationString)
                        }
                    }
                    .padding(.top, 20)
                    
                    Divider()
                        .padding(.top, 16)
                    
                    // MARK: Splits
                    splitsSection
                        .padding(.horizontal, 16)
                        .padding(.top, 16)
                        .padding(.bottom, 40)
                }
            }
        }
        .navigationBarHidden(true)
        .toolbar(.hidden, for: .navigationBar, .tabBar)
        .background(Color.white.ignoresSafeArea())
        .fullScreenCover(isPresented: $showRouteReplay) {
            RouteReplayView(post: post)
        }
    }
    
    private func runStatCell(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
            Text(value)
                .font(.system(size: 20, weight: .bold))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
    
    private var splitsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L.t(sv: "Splits", nb: "Splits"))
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.primary)
            
            if let splits = post.splits, !splits.isEmpty {
                VStack(spacing: 0) {
                    // Header row
                    HStack {
                        Text("KM")
                            .frame(width: 40, alignment: .leading)
                        Spacer()
                        Text("PACE")
                            .frame(width: 80, alignment: .trailing)
                        Text("TID")
                            .frame(width: 60, alignment: .trailing)
                    }
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 4)
                    .padding(.bottom, 8)
                    
                    ForEach(splits) { split in
                        VStack(spacing: 0) {
                            HStack {
                                Text("\(split.kilometerIndex)")
                                    .font(.system(size: 15, weight: .semibold))
                                    .frame(width: 40, alignment: .leading)
                                Spacer()
                                Text(paceString(for: split))
                                    .font(.system(size: 15))
                                    .frame(width: 80, alignment: .trailing)
                                Text(durationString(for: split))
                                    .font(.system(size: 15))
                                    .foregroundColor(.secondary)
                                    .frame(width: 60, alignment: .trailing)
                            }
                            .padding(.vertical, 12)
                            .padding(.horizontal, 4)
                            
                            Divider()
                        }
                    }
                }
            } else {
                Text(L.t(sv: "Inga splits tillgängliga.", nb: "Ingen splits tilgjengelig."))
                    .font(.system(size: 15))
                    .foregroundColor(.secondary)
                    .padding(.top, 4)
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
    
    private func formatCardioTime(_ totalSeconds: Int) -> String {
        let h = totalSeconds / 3600
        let m = (totalSeconds % 3600) / 60
        let s = totalSeconds % 60
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, s)
        }
        return String(format: "%d:%02d", m, s)
    }
    
    private func calculateMuscleSplits(exercises: [GymExercisePost]) -> [String: Int] {
        var muscleCount: [String: Int] = [:]
        
        for exercise in exercises {
            let category = exercise.category ?? L.t(sv: "Övrigt", nb: "Annet")
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
            "chest": L.t(sv: "Bröst", nb: "Bryst"),
            "back": L.t(sv: "Rygg", nb: "Rygg"),
            "shoulders": L.t(sv: "Axlar", nb: "Skuldre"),
            "biceps": L.t(sv: "Biceps", nb: "Biceps"),
            "triceps": L.t(sv: "Triceps", nb: "Triceps"),
            "arms": L.t(sv: "Armar", nb: "Armer"),
            "legs": L.t(sv: "Ben", nb: "Ben"),
            "quadriceps": L.t(sv: "Lår", nb: "Lår"),
            "hamstrings": L.t(sv: "Baksida lår", nb: "Bakside lår"),
            "glutes": L.t(sv: "Rumpa", nb: "Rumpe"),
            "calves": L.t(sv: "Vader", nb: "Legger"),
            "abs": L.t(sv: "Mage", nb: "Mage"),
            "core": L.t(sv: "Core", nb: "Core"),
            "cardio": L.t(sv: "Kondition", nb: "Kondisjon"),
            "full body": L.t(sv: "Helkropp", nb: "Helkropp"),
            "bröst": L.t(sv: "Bröst", nb: "Bryst"),
            "rygg": L.t(sv: "Rygg", nb: "Rygg"),
            "axlar": L.t(sv: "Axlar", nb: "Skuldre"),
            "armar": L.t(sv: "Armar", nb: "Armer"),
            "ben": L.t(sv: "Ben", nb: "Ben"),
            "mage": L.t(sv: "Mage", nb: "Mage")
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

// MARK: - Interactive Route Map

struct WorkoutRouteMapView: UIViewRepresentable {
    let coordinates: [CLLocationCoordinate2D]
    
    func makeCoordinator() -> Coordinator { Coordinator() }
    
    func makeUIView(context: Context) -> MKMapView {
        let map = MKMapView()
        map.delegate = context.coordinator
        map.mapType = .standard
        map.isScrollEnabled = true
        map.isZoomEnabled = true
        map.isRotateEnabled = true
        map.isPitchEnabled = true
        map.showsCompass = true
        map.pointOfInterestFilter = .excludingAll
        
        if coordinates.count >= 2 {
            let polyline = MKPolyline(coordinates: coordinates, count: coordinates.count)
            map.addOverlay(polyline)
            
            let startAnnotation = MKPointAnnotation()
            startAnnotation.coordinate = coordinates.first!
            startAnnotation.title = "start"
            map.addAnnotation(startAnnotation)
            
            let endAnnotation = MKPointAnnotation()
            endAnnotation.coordinate = coordinates.last!
            endAnnotation.title = "end"
            map.addAnnotation(endAnnotation)
            
            let inset: CGFloat = 40
            map.setVisibleMapRect(
                polyline.boundingMapRect,
                edgePadding: UIEdgeInsets(top: inset + 60, left: inset, bottom: inset + 20, right: inset),
                animated: false
            )
        }
        
        return map
    }
    
    func updateUIView(_ uiView: MKMapView, context: Context) {}
    
    class Coordinator: NSObject, MKMapViewDelegate {
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let polyline = overlay as? MKPolyline {
                let renderer = MKPolylineRenderer(polyline: polyline)
                renderer.strokeColor = UIColor(red: 1.0, green: 0.35, blue: 0.0, alpha: 1.0)
                renderer.lineWidth = 5
                renderer.lineCap = .round
                renderer.lineJoin = .round
                return renderer
            }
            return MKOverlayRenderer(overlay: overlay)
        }
        
        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            guard let point = annotation as? MKPointAnnotation else { return nil }
            
            if point.title == "start" {
                let view = MKAnnotationView(annotation: annotation, reuseIdentifier: "start")
                let size: CGFloat = 14
                let renderer = UIGraphicsImageRenderer(size: CGSize(width: size, height: size))
                view.image = renderer.image { ctx in
                    UIColor(red: 0.2, green: 0.8, blue: 0.2, alpha: 1.0).setFill()
                    ctx.cgContext.fillEllipse(in: CGRect(x: 0, y: 0, width: size, height: size))
                }
                view.centerOffset = .zero
                return view
            }
            
            if point.title == "end" {
                let view = MKAnnotationView(annotation: annotation, reuseIdentifier: "end")
                let size: CGFloat = 14
                let renderer = UIGraphicsImageRenderer(size: CGSize(width: size, height: size))
                view.image = renderer.image { ctx in
                    UIColor.red.setFill()
                    ctx.cgContext.fillEllipse(in: CGRect(x: 0, y: 0, width: size, height: size))
                }
                view.centerOffset = .zero
                return view
            }
            
            return nil
        }
    }
}
