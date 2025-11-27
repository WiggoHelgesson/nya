import SwiftUI
import Photos
import UIKit
import Combine

struct ShareActivityView: View {
    let post: SocialWorkoutPost
    var onFinish: (() -> Void)?
    
    @Environment(\.dismiss) private var dismiss
    @StateObject private var insightsLoader: ShareInsightsLoader
    
    @State private var selectedTemplateIndex = 0
    @State private var selectedBackground: ShareBackgroundOption = .transparent
    @State private var showBackgroundDialog = false
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var coverImage: UIImage?
    
    init(post: SocialWorkoutPost, onFinish: (() -> Void)? = nil) {
        self.post = post
        self.onFinish = onFinish
        _insightsLoader = StateObject(wrappedValue: ShareInsightsLoader(post: post))
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                header
                
                if insightsLoader.isLoading {
                    Spacer()
                    ProgressView("Skapar dina delningskort...")
                        .progressViewStyle(.circular)
                        .padding(.top, 32)
                    Spacer()
                } else {
                    cardCarousel
                    actionRow
                    doneButton
                }
            }
            .background(Color(.systemBackground))
            .navigationBarHidden(true)
        }
        .interactiveDismissDisabled(onFinish != nil)
        .task {
            await loadCoverImageIfNeeded()
        }
        .confirmationDialog("Välj bakgrund", isPresented: $showBackgroundDialog, titleVisibility: .visible) {
            ForEach(ShareBackgroundOption.allCases) { option in
                Button(option.displayName) {
                    selectedBackground = option
                }
            }
            Button("Avbryt", role: .cancel) {}
        }
        .alert("Meddelande", isPresented: $showAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(alertMessage)
        }
    }
    
    private var header: some View {
        VStack(spacing: 6) {
            Text("Up&Down")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.black)
            Text(headerSubtitle)
                .font(.system(size: 15, weight: .medium))
                                    .foregroundColor(.gray)
                            }
        .padding(.top, 32)
    }
    
    private var headerSubtitle: String {
        let total = max(insightsLoader.insights.totalWorkouts, 1)
        return "Detta är ditt \(ordinalString(for: total)) pass"
    }
    
    private var templates: [ShareCardTemplate] {
        var list: [ShareCardTemplate] = [.stats, .streak, .calendar]
        if (post.exercises?.isEmpty == false) {
            list.append(.muscles)
        }
        return list
    }
    
    private var cardCarousel: some View {
        VStack(spacing: 24) {
            TabView(selection: $selectedTemplateIndex) {
                ForEach(Array(templates.enumerated()), id: \.offset) { index, template in
                    ShareCardView(
                        template: template,
                        post: post,
                        insights: insightsLoader.insights,
                        background: selectedBackground,
                        size: CGSize(width: UIScreen.main.bounds.width - 48,
                                     height: (UIScreen.main.bounds.width - 48) * 1.25),
                        coverImage: coverImage
                    )
                    .tag(index)
                    .padding(.horizontal, 24)
                    .padding(.top, 16)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .automatic))
            .frame(height: (UIScreen.main.bounds.width - 48) * 1.35)
        }
    }
    
    private var actionRow: some View {
        HStack(spacing: 14) {
            ShareActionButton(icon: "square.and.arrow.down", label: "Spara") {
                saveCurrentCardToPhotos()
            }
            ShareActionButton(icon: "paintpalette.fill", label: "Bakgrund") {
                showBackgroundDialog = true
            }
            ShareActionButton(icon: "camera.viewfinder", label: "Stories") {
                shareToInstagramStories()
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 20)
    }
    
    private var doneButton: some View {
        Button(action: finishSharing) {
            Text("Klar")
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color.black)
                .cornerRadius(18)
                .padding(.horizontal, 24)
                .padding(.top, 20)
                .padding(.bottom, 30)
        }
    }
    
    private func finishSharing() {
        dismiss()
        onFinish?()
    }
    
    private func renderCurrentCardImage() -> UIImage? {
        guard templates.indices.contains(selectedTemplateIndex) else { return nil }
        let template = templates[selectedTemplateIndex]
        let exportSize = CGSize(width: 1080, height: 1920)
        let view = ShareCardView(
            template: template,
            post: post,
            insights: insightsLoader.insights,
            background: selectedBackground,
            size: exportSize,
            coverImage: coverImage
        )
        let renderer = ImageRenderer(content: view)
        renderer.scale = 3
        renderer.isOpaque = selectedBackground != .transparent
        return renderer.uiImage
    }
    
    private func shareToInstagramStories() {
        guard let image = renderCurrentCardImage(),
              let pngData = image.pngData() else {
            showAlert(message: "Kunde inte skapa bilden.")
            return
        }
        UIPasteboard.general.setItems([["com.instagram.sharedSticker.backgroundImage": pngData]],
                                      options: [.expirationDate: Date().addingTimeInterval(300)])
        guard let url = URL(string: "instagram-stories://share") else {
            showAlert(message: "Kunde inte öppna Instagram Stories.")
            return
        }
        UIApplication.shared.open(url, options: [:]) { success in
            if !success {
                showAlert(message: "Kunde inte öppna Instagram Stories. Kontrollera att appen är installerad.")
            }
        }
    }
    
    private func saveCurrentCardToPhotos() {
        guard let image = renderCurrentCardImage() else {
            showAlert(message: "Kunde inte skapa bilden.")
            return
        }
 
        PHPhotoLibrary.requestAuthorization { status in
            guard status == .authorized || status == .limited else {
                showAlert(message: "Ge åtkomst till foton i inställningar.")
                return
            }
                PHPhotoLibrary.shared().performChanges({
                        PHAssetChangeRequest.creationRequestForAsset(from: image)
            }) { success, _ in
                DispatchQueue.main.async {
                    showAlert(message: success ? "Bilden sparades i kamerarullen." : "Kunde inte spara bilden.")
                }
            }
        }
    }
    
    private func showAlert(message: String) {
        alertMessage = message
        showAlert = true
    }
    
    private var workoutLink: String {
        let base = EnvManager.shared.value(for: "SHARE_BASE_URL") ?? "https://updownapp.com/workouts"
        return "\(base)/\(post.id)"
    }
    
    private var summaryText: String {
        var parts: [String] = [post.title]
        if let distance = post.distance {
            parts.append(String(format: "%.2f km", distance))
        }
        if let duration = post.duration {
            parts.append(overlayDurationString(duration))
        }
        return parts.joined(separator: " · ")
    }
    
    private func loadCoverImageIfNeeded() async {
        guard coverImage == nil else { return }
        let candidate = post.userImageUrl ?? post.imageUrl
        guard let urlString = candidate, let url = URL(string: urlString) else { return }
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                if let image = UIImage(data: data) {
                await MainActor.run {
                    coverImage = image
                }
            }
        } catch {
            // Ignore, fallback to gradient
        }
    }
    
    private func ordinalString(for number: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .ordinal
        formatter.locale = Locale(identifier: "sv_SE")
        return formatter.string(from: NSNumber(value: number)) ?? "\(number):e"
    }
}

// MARK: - ShareInsightsLoader
final class ShareInsightsLoader: ObservableObject {
    @Published private(set) var insights = ShareInsights()
    @Published var isLoading = true
    
    private let post: SocialWorkoutPost
    private let isoFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
    
    init(post: SocialWorkoutPost) {
        self.post = post
        Task { @MainActor in
            await load()
        }
    }
    
    @MainActor
    private func load() async {
        let calendar = Calendar.current
        let referenceDate = isoFormatter.date(from: post.createdAt) ?? Date()
        let targetComponents = calendar.dateComponents([.year, .month], from: referenceDate)
        
        func postDateIfInTargetMonth(_ isoString: String) -> Date? {
            guard let date = isoFormatter.date(from: isoString) else { return nil }
            let comps = calendar.dateComponents([.year, .month], from: date)
            guard comps.year == targetComponents.year, comps.month == targetComponents.month else { return nil }
            return date
        }
        
        func dedupDates(_ dates: [Date]) -> [Date] {
            var seen: Set<String> = []
            var result: [Date] = []
            for date in dates.sorted() {
                let comps = calendar.dateComponents([.year, .month, .day], from: date)
                let key = "\(comps.year ?? 0)-\(comps.month ?? 0)-\(comps.day ?? 0)"
                if !seen.contains(key) {
                    seen.insert(key)
                    result.append(date)
                }
            }
            return result
        }
        
        let currentWorkoutDate = postDateIfInTargetMonth(post.createdAt)
        
        if post.userId.isEmpty {
            let monthDates = currentWorkoutDate.map { [$0] } ?? []
            insights = ShareInsights(
                totalWorkouts: monthDates.isEmpty ? 0 : 1,
                monthWorkoutDates: monthDates,
                monthReferenceDate: referenceDate,
                exerciseVolume: calculateGymVolume(from: post.exercises),
                totalSets: post.exercises?.reduce(0) { $0 + $1.sets } ?? 0,
                muscleGroups: muscleGroups(from: post.exercises)
            )
            isLoading = false
            return
        }
        
        do {
            let posts = try await WorkoutService.shared.getUserWorkoutPosts(userId: post.userId, forceRefresh: true)
            var monthDates: [Date] = posts.compactMap { postDateIfInTargetMonth($0.createdAt) }
            if let currentWorkoutDate {
                monthDates.append(currentWorkoutDate)
            }
            monthDates = dedupDates(monthDates)
            
            insights = ShareInsights(
                totalWorkouts: max(posts.count, monthDates.count),
                monthWorkoutDates: monthDates,
                monthReferenceDate: referenceDate,
                exerciseVolume: calculateGymVolume(from: self.post.exercises),
                totalSets: post.exercises?.reduce(0) { $0 + $1.sets } ?? 0,
                muscleGroups: muscleGroups(from: post.exercises)
            )
        } catch {
            let monthDates = currentWorkoutDate.map { [$0] } ?? []
            insights = ShareInsights(
                totalWorkouts: monthDates.isEmpty ? 0 : 1,
                monthWorkoutDates: monthDates,
                monthReferenceDate: referenceDate,
                exerciseVolume: calculateGymVolume(from: self.post.exercises),
                totalSets: post.exercises?.reduce(0) { $0 + $1.sets } ?? 0,
                muscleGroups: muscleGroups(from: post.exercises)
            )
        }
        
        isLoading = false
    }
    
    private func muscleGroups(from exercises: [GymExercisePost]?) -> [String: Int] {
        guard let exercises else { return [:] }
        var map: [String: Int] = [:]
        for exercise in exercises {
            let key = (exercise.category ?? "Överkropp").capitalized
            map[key, default: 0] += 1
        }
        return map
    }
}

// MARK: - ShareInsights
struct ShareInsights {
    var totalWorkouts: Int = 1
    var monthWorkoutDates: [Date] = []
    var monthReferenceDate: Date = Date()
    var streakInfo: StreakInfo = StreakManager.shared.getCurrentStreak()
    var exerciseVolume: Double = 0
    var totalSets: Int = 0
    var muscleGroups: [String: Int] = [:]
}

// MARK: - ShareBackgroundOption
enum ShareBackgroundOption: String, CaseIterable, Identifiable {
    case transparent, white, black
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .transparent: return "Transparent"
        case .white: return "Vit"
        case .black: return "Svart"
        }
    }
    
    var color: Color {
        switch self {
        case .transparent: return .clear
        case .white: return .white
        case .black: return .black
        }
    }
    
    var overlayGradient: [Color] {
        switch self {
        case .transparent:
            return [Color.black.opacity(0.35), Color.black.opacity(0.8)]
        case .white:
            return [Color.white.opacity(0.1), Color.white.opacity(0.45)]
        case .black:
            return [Color.black.opacity(0.55), Color.black.opacity(0.9)]
        }
    }
    
    var preferredTextColor: Color {
        switch self {
        case .white: return .black
        default: return .white
        }
    }
}

// MARK: - ShareCardTemplate
enum ShareCardTemplate: String, CaseIterable, Identifiable {
    case stats, streak, calendar, muscles
    var id: String { rawValue }
}

// MARK: - ShareCardView
struct ShareCardView: View {
    let template: ShareCardTemplate
    let post: SocialWorkoutPost
    let insights: ShareInsights
    let background: ShareBackgroundOption
    let size: CGSize
    let coverImage: UIImage?
    
    private var scale: CGFloat {
        size.width / 320
    }
    
    private var shouldShowCoverImage: Bool {
        coverImage != nil && template == .stats
    }
    
    var body: some View {
        ZStack {
            backgroundView
            content
        }
        .frame(width: size.width, height: size.height)
        .clipShape(RoundedRectangle(cornerRadius: 32 * scale, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 32 * scale, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 2)
        )
    }

    private var backgroundView: some View {
        ZStack {
            if background == .transparent {
                CheckerboardBackground()
            } else {
                background.color
            }
            
            if shouldShowCoverImage, let coverImage {
                Image(uiImage: coverImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: size.width, height: size.height)
                    .clipped()
            }
            
            if shouldShowCoverImage {
                LinearGradient(
                    colors: background.overlayGradient,
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
        }
    }
    
    @ViewBuilder
    private var content: some View {
        VStack(spacing: 32 * scale) {
            Spacer()
            
            switch template {
            case .stats: statsCard
            case .streak: streakCard
            case .calendar: calendarCard
            case .muscles: muscleCard
            }

            Spacer()
            
            brandSignature
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .foregroundColor(textColor)
    }
    
    private var textColor: Color {
        shouldShowCoverImage ? .white : background.preferredTextColor
    }
    
    private var statsCard: some View {
        VStack(spacing: 24 * scale) {
            ForEach(sharePreviewStats(for: post), id: \.title) { stat in
                VStack(spacing: 6 * scale) {
                    Text(stat.title)
                        .font(.system(size: 14 * scale, weight: .semibold))
                        .foregroundColor(textColor.opacity(0.8))
                    Text(stat.value)
                        .font(.system(size: stat.isPrimary ? 42 * scale : 34 * scale, weight: .heavy))
                        .foregroundColor(textColor)
                }
                .frame(maxWidth: .infinity)
            }
        }
    }
    
    private var streakCard: some View {
        VStack(spacing: 24 * scale) {
            Image(systemName: "flame.fill")
                .font(.system(size: 60 * scale))
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color.orange, Color.red],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            
            Text("Week Streak")
                .font(.system(size: 20 * scale, weight: .semibold))
                .foregroundColor(textColor)
            
            Text("Du har tränat \(insights.streakInfo.consecutiveDays) dagar i rad!")
                .font(.system(size: 16 * scale))
                .foregroundColor(textColor.opacity(0.7))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24 * scale)
            
            Spacer()
            
            Text(shareHandle(for: post))
                .font(.system(size: 18 * scale, weight: .semibold))
                .foregroundColor(textColor)
                .padding(.bottom, 28 * scale)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var calendarCard: some View {
        let calendar = Calendar.current
        let referenceDate = insights.monthReferenceDate
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "sv_SE")
        formatter.dateFormat = "MMMM"
        let monthName = formatter.string(from: referenceDate).capitalized
        let daysRange = calendar.range(of: .day, in: .month, for: referenceDate) ?? 1..<31
        let days = Array(daysRange)
        let firstOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: referenceDate)) ?? referenceDate
        let firstWeekday = (calendar.component(.weekday, from: firstOfMonth) + 5) % 7
        let workoutDays = Set(insights.monthWorkoutDates.compactMap {
            calendar.isDate($0, equalTo: referenceDate, toGranularity: .month)
            ? calendar.component(.day, from: $0)
            : nil
        })
        
        // Create all grid items in one array
        let weekdayHeaders = ["M","T","O","T","F","L","S"]
        let emptyDays = Array(repeating: -1, count: firstWeekday)
        let allItems = emptyDays + days
        
        return VStack(spacing: 12 * scale) {
            Text("\(insights.monthWorkoutDates.count) pass i \(monthName)")
                .font(.system(size: 22 * scale, weight: .semibold))
                .foregroundColor(textColor)
                .padding(.top, 24 * scale)
            
            VStack(spacing: 8 * scale) {
                // Weekday headers
                HStack(spacing: 8 * scale) {
                    ForEach(weekdayHeaders, id: \.self) { day in
                        Text(day)
                            .font(.system(size: 12 * scale, weight: .medium))
                            .foregroundColor(textColor.opacity(0.6))
                            .frame(maxWidth: .infinity)
                    }
                }
                
                // Calendar grid
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8 * scale), count: 7), spacing: 8 * scale) {
                    ForEach(allItems.indices, id: \.self) { index in
                        let day = allItems[index]
                        if day == -1 {
                            Text(" ")
                                .frame(height: 28 * scale)
                        } else {
                            let isWorkout = workoutDays.contains(day)
                            Text("\(day)")
                                .font(.system(size: 14 * scale, weight: .semibold))
                                .frame(height: 32 * scale)
                                .frame(maxWidth: .infinity)
                                .background(
                                    Circle()
                                        .fill(isWorkout ? Color.white : Color.white.opacity(0.08))
                                        .shadow(color: isWorkout ? Color.black.opacity(0.15) : .clear, radius: isWorkout ? 4 * scale : 0, x: 0, y: 2)
                                )
                                .foregroundColor(isWorkout ? .black : textColor.opacity(0.7))
                        }
                    }
                }
            }
            .padding(.horizontal, 16 * scale)
            
            Spacer()
            Text(shareHandle(for: post))
                .font(.system(size: 18 * scale, weight: .semibold))
                .foregroundColor(textColor)
                .padding(.bottom, 24 * scale)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var muscleCard: some View {
        let topGroups = insights.muscleGroups.sorted { $0.value > $1.value }.prefix(3)
        return VStack(alignment: .leading, spacing: 12 * scale) {
            Text("Fokusområden")
                .font(.system(size: 22 * scale, weight: .bold))
                .foregroundColor(textColor)
                .padding(.horizontal, 24 * scale)
                .padding(.top, 24 * scale)
            
            ForEach(Array(topGroups.enumerated()), id: \.offset) { index, element in
                HStack {
                    Text(element.key)
                        .font(.system(size: 18 * scale, weight: .medium))
                        .foregroundColor(textColor.opacity(0.9))
                    Spacer()
                    Text("\(element.value) övningar")
                        .font(.system(size: 18 * scale, weight: .medium))
                        .foregroundColor(textColor.opacity(0.7))
                }
                .padding(.horizontal, 24 * scale)
            }
            
            Spacer()
            Text(shareHandle(for: post))
                .font(.system(size: 18 * scale, weight: .semibold))
                .foregroundColor(textColor)
                .padding(.bottom, 24 * scale)
                .frame(maxWidth: .infinity, alignment: .center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var brandSignature: some View {
        HStack(spacing: 16 * scale) {
            Image("23")
                .resizable()
                .renderingMode(.original)
                .scaledToFit()
                .frame(width: 64 * scale, height: 64 * scale)
                .clipShape(RoundedRectangle(cornerRadius: 16 * scale))
                .overlay(
                    RoundedRectangle(cornerRadius: 16 * scale)
                        .stroke(Color.white.opacity(0.6), lineWidth: 2 * scale)
                )
            VStack(alignment: .leading, spacing: 4 * scale) {
                Text("Up&Down")
                    .font(.system(size: 24 * scale, weight: .bold))
                    .foregroundColor(textColor)
                Text(shareHandle(for: post))
                    .font(.system(size: 15 * scale, weight: .semibold))
                    .foregroundColor(textColor.opacity(0.85))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.bottom, 24 * scale)
    }
    
    private func shareHandle(for post: SocialWorkoutPost) -> String {
        let username = post.userName?
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "@", with: "")
            ?? "uppy"
        let cleaned = username.isEmpty ? "uppy" : username
        let prefix = cleaned.prefix(7)
        return "@" + String(prefix)
    }

    private func sharePreviewStats(for post: SocialWorkoutPost) -> [ShareStat] {
    var stats: [ShareStat] = []

    if post.activityType == "Gympass" {
        stats.append(ShareStat(title: "Volym", value: formatGymVolume(from: post.exercises), isPrimary: true))
        stats.append(ShareStat(title: "Tid", value: overlayDurationString(post.duration), isPrimary: false))
    } else {
            stats.append(ShareStat(title: "Distans", value: formatDistance(post.distance), isPrimary: true))
        if let pace = formattedPace(distance: post.distance, duration: post.duration) {
                stats.append(ShareStat(title: "Tempo", value: pace, isPrimary: false))
        }
            stats.append(ShareStat(title: "Tid", value: overlayDurationString(post.duration), isPrimary: false))
    }

    return stats
}

    private func formatDistance(_ distance: Double?) -> String {
    guard let distance = distance else { return "0.00 km" }
    return String(format: "%.2f km", distance)
}

    private func formatGymVolume(from exercises: [GymExercisePost]?) -> String {
    let volume = calculateGymVolume(from: exercises)
    return String(format: "%.0f kg", volume)
}

    private func formattedPace(distance: Double?, duration: Int?) -> String? {
        guard let distance = distance, distance > 0,
              let duration = duration, duration > 0 else { return nil }
        let paceSeconds = Double(duration) / distance
        let minutes = Int(paceSeconds) / 60
        let seconds = Int(paceSeconds) % 60
        return String(format: "%d:%02d /km", minutes, seconds)
    }
}

// MARK: - ShareActionButton
struct ShareActionButton: View {
    let icon: String
    let label: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.black)
                Text(label)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.gray)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 80)
            .background(Color(.systemGray6))
            .cornerRadius(14)
        }
    }
}

// MARK: - ActivityView
struct ActivityView: UIViewControllerRepresentable {
    let activityItems: [Any]
    var applicationActivities: [UIActivity]? = nil
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: activityItems, applicationActivities: applicationActivities)
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Helper Structures
struct ShareStat {
    let title: String
    let value: String
    let isPrimary: Bool
}

// MARK: - Helper Functions
private func calculateGymVolume(from exercises: [GymExercisePost]?) -> Double {
    guard let exercises = exercises else { return 0 }
    return exercises.reduce(0) { total, exercise in
        let pairs = zip(exercise.kg, exercise.reps)
        let exerciseVolume = pairs.reduce(0.0) { $0 + $1.0 * Double($1.1) }
        return total + exerciseVolume
    }
}

private func overlayDurationString(_ seconds: Int?) -> String {
    guard let seconds = seconds else { return "-" }
    let hours = seconds / 3600
    let minutes = (seconds % 3600) / 60
    let secs = seconds % 60

    if hours > 0 {
        if minutes == 0 {
            return "\(hours)h"
        }
        return "\(hours)h \(minutes)m"
    } else if minutes > 0 {
        if secs == 0 {
            return "\(minutes)m"
        }
        return "\(minutes)m \(secs)s"
    } else {
        return "\(secs)s"
    }
}

// MARK: - Checkerboard background
struct CheckerboardBackground: View {
    var squareSize: CGFloat = 28
    
    var body: some View {
        GeometryReader { geometry in
            let columns = Int(ceil(geometry.size.width / squareSize))
            let rows = Int(ceil(geometry.size.height / squareSize))
            
            Color.black.opacity(0.15)
                .overlay(
                    Canvas { context, size in
                        for row in 0...rows {
                            for column in 0...columns {
                                if (row + column).isMultiple(of: 2) {
                                    let rect = CGRect(
                                        x: CGFloat(column) * squareSize,
                                        y: CGFloat(row) * squareSize,
                                        width: squareSize,
                                        height: squareSize
                                    )
                                    context.fill(
                                        Path(rect),
                                        with: .color(Color.black.opacity(0.25))
                                    )
                                }
                            }
                        }
                    }
                )
                .clipped()
        }
    }
}
