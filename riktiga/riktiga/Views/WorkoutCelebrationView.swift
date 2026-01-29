import SwiftUI
import Photos

struct WorkoutCelebrationView: View {
    let post: SocialWorkoutPost
    let onDismiss: () -> Void
    
    @Environment(\.dismiss) private var dismiss
    @StateObject private var insightsLoader: ShareInsightsLoader
    @State private var showConfetti = false
    @State private var selectedTemplateIndex = 0
    @State private var coverImage: UIImage?
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var alertTitle = "Meddelande"
    @State private var isSaving = false
    @State private var selectedBackground: ShareBackgroundOption = .transparent
    @State private var showBackgroundDialog = false
    
    init(post: SocialWorkoutPost, onDismiss: @escaping () -> Void) {
        self.post = post
        self.onDismiss = onDismiss
        _insightsLoader = StateObject(wrappedValue: ShareInsightsLoader(post: post))
    }
    
    
    private var templates: [ShareCardTemplate] {
        var list: [ShareCardTemplate] = [.stats, .compact]
        
        // Only show streak card if user has an actual streak (2+ consecutive days)
        let streakDays = insightsLoader.insights.streakInfo.currentStreak
        if streakDays >= 2 {
            list.append(.streak)
        }
        
        list.append(.calendar)
        
        if (post.exercises?.isEmpty == false) {
            list.append(.muscles)
        }
        return list
    }
    
    var body: some View {
        ZStack {
            // Background
            Color(.systemBackground)
                .ignoresSafeArea()
            
            // Confetti overlay
            if showConfetti {
                ConfettiView()
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
            }
            
            VStack(spacing: 0) {
                // Header with title and emoji
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Bra jobbat!")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundColor(.primary)
                        
                        Text(workoutCountText)
                            .font(.system(size: 16, weight: .medium, design: .rounded))
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    // Celebration emoji in circle
                    Text("🎉")
                        .font(.system(size: 32))
                        .frame(width: 60, height: 60)
                        .background(Color(.systemGray6))
                        .clipShape(Circle())
                }
                .padding(.horizontal, 24)
                .padding(.top, 50)
                
                // Share card carousel
                if insightsLoader.isLoading {
                    ProgressView()
                        .padding(.top, 40)
                    Spacer()
                } else {
                    cardCarousel
                        .padding(.top, 24)
                    
                    // Page indicator dots
                    HStack(spacing: 8) {
                        ForEach(0..<templates.count, id: \.self) { index in
                            Circle()
                                .fill(index == selectedTemplateIndex ? Color.primary : Color.gray.opacity(0.3))
                                .frame(width: 8, height: 8)
                        }
                    }
                    .padding(.top, 12)
                    
                    Spacer()
                    
                    // Share prompt text
                    Text("Dela passet - Tagga @upanddown")
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                    
                    // Share action buttons - 50/50 width
                    HStack(spacing: 12) {
                        // Background selector
                        Button {
                            showBackgroundDialog = true
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: selectedBackground == .transparent ? "square.dashed" : "square.fill")
                                    .font(.system(size: 18))
                                Text("Bakgrund")
                                    .font(.system(size: 15, weight: .semibold))
                            }
                            .foregroundColor(.primary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color(.systemGray6))
                            .cornerRadius(12)
                        }
                        
                        // Download button
                        Button {
                            saveToPhotos()
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "arrow.down.circle.fill")
                                    .font(.system(size: 18))
                                Text("Ladda ner")
                                    .font(.system(size: 15, weight: .semibold))
                            }
                            .foregroundColor(.primary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color(.systemGray6))
                            .cornerRadius(12)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 16)
                    
                    // Done button
                    Button(action: finishAndDismiss) {
                        Text("Klar")
                            .font(.system(size: 17, weight: .semibold, design: .rounded))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.black)
                            .cornerRadius(14)
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 20)
                    .padding(.bottom, 40)
                }
            }
        }
        .onAppear {
            // Start confetti after a short delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                withAnimation {
                    showConfetti = true
                }
            }
            
            // Stop confetti after 3 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.3) {
                withAnimation {
                    showConfetti = false
                }
            }
        }
        .task {
            await loadCoverImageIfNeeded()
        }
        .alert(alertTitle, isPresented: $showAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(alertMessage)
        }
        .confirmationDialog("Välj bakgrund", isPresented: $showBackgroundDialog, titleVisibility: .visible) {
            ForEach(ShareBackgroundOption.allCases) { option in
                Button(option.displayName) {
                    selectedBackground = option
                }
            }
            Button("Avbryt", role: .cancel) {}
        }
    }
    
    private var workoutCountText: String {
        let total = max(insightsLoader.insights.totalWorkouts, 1)
        return "Detta är ditt \(ordinalString(for: total)) pass"
    }
    
    private func ordinalString(for number: Int) -> String {
        // Swedish ordinal: 1:a, 2:a, 3:e, 4:e, etc.
        switch number {
        case 1: return "1:a"
        case 2: return "2:a"
        default: return "\(number):e"
        }
    }
    
    private var cardCarousel: some View {
        let count = templates.count
        return VStack(spacing: 24) {
            TabView(selection: $selectedTemplateIndex) {
                ForEach(0..<count, id: \.self) { index in
                    ShareCardView(
                        template: templates[index],
                        post: post,
                        insights: insightsLoader.insights,
                        background: selectedBackground,
                        size: CGSize(width: UIScreen.main.bounds.width - 48,
                                     height: (UIScreen.main.bounds.width - 48) * 1.25),
                        coverImage: coverImage,
                        isPreview: true
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
    
    private func loadCoverImageIfNeeded() async {
        guard let imageUrlString = post.imageUrl,
              let url = URL(string: imageUrlString) else { return }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            if let image = UIImage(data: data) {
                await MainActor.run {
                    coverImage = image
                }
            }
        } catch {
            print("❌ Failed to load cover image: \(error)")
        }
    }
    
    private func renderCurrentCardImage() -> UIImage? {
        guard templates.indices.contains(selectedTemplateIndex) else { return nil }
        let template = templates[selectedTemplateIndex]
        let exportSize = CGSize(width: 1080, height: 1920)
        
        // Render with transparent background for downloads
        let view = ShareCardView(
            template: template,
            post: post,
            insights: insightsLoader.insights,
            background: .transparent,
            size: exportSize,
            coverImage: coverImage,
            isPreview: false
        )
        
        let renderer = ImageRenderer(content: view)
        renderer.scale = 3
        renderer.isOpaque = false
        
        guard let cgImage = renderer.cgImage else { return nil }
        return UIImage(cgImage: cgImage)
    }
    
    private func saveToPhotos() {
        isSaving = true
        
        guard let image = renderCurrentCardImage() else {
            alertTitle = "Fel"
            alertMessage = "Kunde inte skapa bilden."
            showAlert = true
            isSaving = false
            return
        }
        
        PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
            DispatchQueue.main.async {
                if status == .authorized || status == .limited {
                    UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
                    alertTitle = "Sparat!"
                    alertMessage = "Bilden har sparats till dina foton."
                    showAlert = true
                } else {
                    alertTitle = "Åtkomst nekad"
                    alertMessage = "Tillåt åtkomst till foton i Inställningar för att spara bilden."
                    showAlert = true
                }
                isSaving = false
            }
        }
    }
    
    private func shareToInstagramStories() {
        guard let image = renderCurrentCardImage(),
              let pngData = image.pngData() else {
            alertTitle = "Error"
            alertMessage = "Could not create image."
            showAlert = true
            return
        }
        
        UIPasteboard.general.setItems([["com.instagram.sharedSticker.backgroundImage": pngData]],
                                      options: [.expirationDate: Date().addingTimeInterval(300)])
        
        guard let url = URL(string: "instagram-stories://share") else {
            alertTitle = "Error"
            alertMessage = "Could not open Instagram Stories."
            showAlert = true
            return
        }
        
        UIApplication.shared.open(url, options: [:]) { success in
            if !success {
                DispatchQueue.main.async {
                    alertTitle = "Error"
                    alertMessage = "Could not open Instagram Stories. Make sure the app is installed."
                    showAlert = true
                }
            }
        }
    }
    
    private func finishAndDismiss() {
        // First dismiss the celebration view, then notify parent after animation completes
        dismiss()
        // onDismiss will be called by the parent when the fullScreenCover is dismissed
        // Adding a small delay to ensure smooth dismissal
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            onDismiss()
        }
    }
}

// MARK: - Celebration Action Button
struct CelebrationActionButton<Background: ShapeStyle>: View {
    let icon: String
    let label: String
    var iconColor: Color = .primary
    var backgroundColor: Background = Color(.systemGray6) as! Background
    var isSelected: Bool = false
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(backgroundColor)
                        .frame(width: 56, height: 56)
                    
                    Image(systemName: icon)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundColor(iconColor)
                }
                
                Text(label)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
            }
        }
        .buttonStyle(.plain)
    }
}

// Convenience initializer for non-gradient backgrounds
extension CelebrationActionButton where Background == Color {
    init(icon: String, label: String, iconColor: Color = .primary, isSelected: Bool = false, action: @escaping () -> Void) {
        self.icon = icon
        self.label = label
        self.iconColor = iconColor
        self.backgroundColor = Color(.systemGray6)
        self.isSelected = isSelected
        self.action = action
    }
}

// MARK: - Confetti View
struct ConfettiView: View {
    @State private var confettiPieces: [ConfettiPiece] = []
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ForEach(confettiPieces) { piece in
                    ConfettiPieceView(piece: piece, screenHeight: geometry.size.height)
                }
            }
            .onAppear {
                createConfetti(in: geometry.size)
            }
        }
    }
    
    private func createConfetti(in size: CGSize) {
        confettiPieces = (0..<80).map { _ in
            ConfettiPiece(
                color: [Color.red, Color.blue, Color.green, Color.yellow, Color.orange, Color.purple, Color.pink].randomElement()!,
                x: CGFloat.random(in: 0...size.width),
                delay: Double.random(in: 0...0.5),
                duration: Double.random(in: 2.5...4.0),
                rotation: Double.random(in: 0...360),
                size: CGFloat.random(in: 8...14)
            )
        }
    }
}

struct ConfettiPiece: Identifiable {
    let id = UUID()
    let color: Color
    let x: CGFloat
    let delay: Double
    let duration: Double
    let rotation: Double
    let size: CGFloat
}

struct ConfettiPieceView: View {
    let piece: ConfettiPiece
    let screenHeight: CGFloat
    
    @State private var yOffset: CGFloat = -50
    @State private var opacity: Double = 1.0
    @State private var rotationAngle: Double = 0
    
    var body: some View {
        Rectangle()
            .fill(piece.color)
            .frame(width: piece.size, height: piece.size * 0.6)
            .rotationEffect(.degrees(rotationAngle))
            .offset(x: piece.x - UIScreen.main.bounds.width / 2, y: yOffset)
            .opacity(opacity)
            .onAppear {
                withAnimation(
                    Animation.easeIn(duration: piece.duration)
                        .delay(piece.delay)
                ) {
                    yOffset = screenHeight + 50
                    opacity = 0
                }
                
                withAnimation(
                    Animation.linear(duration: piece.duration)
                        .repeatForever(autoreverses: false)
                        .delay(piece.delay)
                ) {
                    rotationAngle = piece.rotation + 720
                }
            }
    }
}

// MARK: - Hevy-Style Share Card
struct HevyStyleShareCard: View {
    let template: ShareCardTemplate
    let post: SocialWorkoutPost
    let insights: ShareInsights
    let weekStreak: Int
    let useTransparentBackground: Bool
    let size: CGSize
    
    private var scale: CGFloat {
        size.width / 320
    }
    
    private var textColor: Color {
        // Dynamic text color based on background
        useTransparentBackground ? .black : .white
    }
    
    var body: some View {
        ZStack {
            // Background
            if useTransparentBackground {
                Color.clear
            } else {
                HevyDarkBackground(scale: scale)
            }
            
            // Content based on template
            switch template {
            case .streak:
                weekStreakContent
            case .calendar:
                calendarContent
            case .stats:
                statsStackedContent
            case .compact:
                statsHorizontalContent
            case .muscles:
                statsStackedContent // Fallback to stacked stats
            }
        }
        .frame(width: size.width, height: size.height)
        .clipShape(RoundedRectangle(cornerRadius: 24 * scale, style: .continuous))
    }
    
    // MARK: - Week Streak Card (Hevy style)
    private var weekStreakContent: some View {
        VStack(spacing: 0) {
            Spacer()
            
            // Flame icon
            Image(systemName: "flame.fill")
                .font(.system(size: 70 * scale, weight: .bold))
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color(red: 1.0, green: 0.4, blue: 0.3), Color(red: 0.9, green: 0.2, blue: 0.2)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            
            // Big number
            Text("\(weekStreak)")
                .font(.system(size: 100 * scale, weight: .heavy))
                .foregroundColor(textColor)
                .padding(.top, 8 * scale)
            
            // "Week Streak" text
            Text("Veckostreak")
                .font(.system(size: 28 * scale, weight: .bold))
                .foregroundColor(textColor)
            
            // Description
            Text("Du har tränat konsekvent i \(weekStreak) \(weekStreak == 1 ? "vecka" : "veckor") i rad!")
                .font(.system(size: 16 * scale, weight: .medium))
                .foregroundColor(textColor.opacity(0.75))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32 * scale)
                .padding(.top, 12 * scale)
            
            Spacer()
            
            // Bottom branding
            bottomBranding
        }
    }
    
    // MARK: - Calendar Card
    private var calendarContent: some View {
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
        let weekdayHeaders = ["M","T","O","T","F","L","S"]
        let emptyDays = Array(repeating: -1, count: firstWeekday)
        let allItems = emptyDays + days
        let today = calendar.component(.day, from: Date())
        let isCurrentMonth = calendar.isDate(referenceDate, equalTo: Date(), toGranularity: .month)
        
        // Color for workout circles (black instead of blue)
        let workoutColor = useTransparentBackground ? Color.black : Color.white
        let workoutBgColor = useTransparentBackground ? Color.black.opacity(0.15) : Color.white.opacity(0.15)
        
        return VStack(spacing: 16 * scale) {
            // Title
            Text("\(insights.monthWorkoutDates.count) pass")
                .font(.system(size: 32 * scale, weight: .bold))
                .foregroundColor(textColor)
                .padding(.top, 28 * scale)
            
            Text("i \(monthName)")
                .font(.system(size: 18 * scale, weight: .medium))
                .foregroundColor(textColor.opacity(0.7))
            
            // Weekday headers
            HStack(spacing: 6 * scale) {
                ForEach(weekdayHeaders, id: \.self) { day in
                    Text(day)
                        .font(.system(size: 12 * scale, weight: .semibold))
                        .foregroundColor(textColor.opacity(0.5))
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, 16 * scale)
            .padding(.top, 8 * scale)
            
            // Calendar grid
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4 * scale), count: 7), spacing: 6 * scale) {
                ForEach(allItems.indices, id: \.self) { index in
                    let day = allItems[index]
                    if day == -1 {
                        Text(" ")
                            .frame(height: 32 * scale)
                    } else {
                        let isWorkout = workoutDays.contains(day)
                        let isToday = isCurrentMonth && day == today
                        
                        Text("\(day)")
                            .font(.system(size: 14 * scale, weight: .semibold))
                            .frame(width: 32 * scale, height: 32 * scale)
                            .background(
                                Circle()
                                    .fill(isWorkout ? workoutColor : workoutBgColor)
                            )
                            .overlay(
                                Circle()
                                    .stroke(isToday ? workoutColor : Color.clear, lineWidth: 2 * scale)
                            )
                            .foregroundColor(isWorkout ? (useTransparentBackground ? .white : .black) : textColor.opacity(0.6))
                    }
                }
            }
            .padding(.horizontal, 16 * scale)
            
            Spacer()
            
            // Bottom branding
            bottomBranding
        }
    }
    
    // MARK: - Stats Stacked (Volume, Time, Logo stacked)
    private var statsStackedContent: some View {
        VStack(spacing: 0) {
            Spacer()
            
            // Volume
            VStack(spacing: 4 * scale) {
                Text(formatGymVolume(from: post.exercises))
                    .font(.system(size: 56 * scale, weight: .heavy))
                    .foregroundColor(textColor)
                Text("Total Volume")
                    .font(.system(size: 16 * scale, weight: .semibold))
                    .foregroundColor(textColor.opacity(0.7))
            }
            
            // Time
            VStack(spacing: 4 * scale) {
                Text(hevyDurationString(post.duration))
                    .font(.system(size: 48 * scale, weight: .heavy))
                    .foregroundColor(textColor)
                Text("Duration")
                    .font(.system(size: 16 * scale, weight: .semibold))
                    .foregroundColor(textColor.opacity(0.7))
            }
            .padding(.top, 24 * scale)
            
            Spacer()
            
            // Bottom branding
            bottomBranding
        }
    }
    
    // MARK: - Stats Horizontal
    private var statsHorizontalContent: some View {
        VStack(spacing: 0) {
            Spacer()
            
            // Stats in horizontal layout
            HStack(spacing: 32 * scale) {
                // Volume
                VStack(spacing: 4 * scale) {
                    Text(formatGymVolume(from: post.exercises))
                        .font(.system(size: 32 * scale, weight: .heavy))
                        .foregroundColor(textColor)
                    Text("Volume")
                        .font(.system(size: 14 * scale, weight: .semibold))
                        .foregroundColor(textColor.opacity(0.7))
                }
                
                // Time
                VStack(spacing: 4 * scale) {
                    Text(hevyDurationString(post.duration))
                        .font(.system(size: 32 * scale, weight: .heavy))
                        .foregroundColor(textColor)
                    Text("Time")
                        .font(.system(size: 14 * scale, weight: .semibold))
                        .foregroundColor(textColor.opacity(0.7))
                }
                
                // Sets (if gym workout)
                if let exercises = post.exercises {
                    let totalSets = exercises.reduce(0) { $0 + $1.sets }
                    VStack(spacing: 4 * scale) {
                        Text("\(totalSets)")
                            .font(.system(size: 32 * scale, weight: .heavy))
                            .foregroundColor(textColor)
                        Text("Sets")
                            .font(.system(size: 14 * scale, weight: .semibold))
                            .foregroundColor(textColor.opacity(0.7))
                    }
                }
            }
            
            Spacer()
            
            // Bottom branding
            bottomBranding
        }
    }
    
    // MARK: - Bottom Branding (Logo + Username)
    private var bottomBranding: some View {
        HStack {
            // Logo and app name
            HStack(spacing: 10 * scale) {
                Image("23")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 32 * scale, height: 32 * scale)
                    .clipShape(RoundedRectangle(cornerRadius: 8 * scale))
                
                Text("UP&DOWN")
                    .font(.system(size: 18 * scale, weight: .heavy))
                    .tracking(1)
                    .foregroundColor(textColor)
            }
            
            Spacer()
            
            // Username
            Text(shareHandle(for: post))
                .font(.system(size: 16 * scale, weight: .semibold))
                .foregroundColor(textColor.opacity(0.8))
        }
        .padding(.horizontal, 24 * scale)
        .padding(.bottom, 24 * scale)
    }
    
    // MARK: - Helper Functions
    private func shareHandle(for post: SocialWorkoutPost) -> String {
        let username = post.userName?
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "@", with: "")
            ?? "uppy"
        let cleaned = username.isEmpty ? "uppy" : username
        let prefix = cleaned.prefix(10)
        return "@" + String(prefix)
    }
    
    private func formatGymVolume(from exercises: [GymExercisePost]?) -> String {
        guard let exercises = exercises else { return "0 kg" }
        var totalVolume: Double = 0
        for exercise in exercises {
            for i in 0..<exercise.sets {
                let kg = i < exercise.kg.count ? exercise.kg[i] : 0
                let reps = i < exercise.reps.count ? exercise.reps[i] : 0
                totalVolume += kg * Double(reps)
            }
        }
        if totalVolume >= 1000 {
            return String(format: "%.1fk kg", totalVolume / 1000)
        }
        return String(format: "%.0f kg", totalVolume)
    }
}

// MARK: - Hevy Dark Background with Diagonal Pattern
struct HevyDarkBackground: View {
    let scale: CGFloat
    
    var body: some View {
        ZStack {
            // Base dark color
            Color(red: 0.12, green: 0.14, blue: 0.18)
            
            // Diagonal stripes pattern
            GeometryReader { geometry in
                Canvas { context, size in
                    let stripeWidth: CGFloat = 40 * scale
                    let stripeSpacing: CGFloat = 60 * scale
                    let stripeColor = Color(red: 0.18, green: 0.20, blue: 0.24)
                    
                    for i in stride(from: -size.height, to: size.width + size.height, by: stripeSpacing) {
                        var path = Path()
                        path.move(to: CGPoint(x: i, y: 0))
                        path.addLine(to: CGPoint(x: i + size.height, y: size.height))
                        path.addLine(to: CGPoint(x: i + size.height + stripeWidth, y: size.height))
                        path.addLine(to: CGPoint(x: i + stripeWidth, y: 0))
                        path.closeSubpath()
                        
                        context.fill(path, with: .color(stripeColor))
                    }
                }
            }
        }
    }
}

// MARK: - Duration Formatter (for HevyStyleShareCard)
private func hevyDurationString(_ duration: Int?) -> String {
    guard let duration = duration else { return "0:00" }
    let hours = duration / 3600
    let minutes = (duration % 3600) / 60
    let seconds = duration % 60
    
    if hours > 0 {
        return String(format: "%d:%02d:%02d", hours, minutes, seconds)
    } else {
        return String(format: "%d:%02d", minutes, seconds)
    }
}

#Preview {
    WorkoutCelebrationView(
        post: SocialWorkoutPost(
            id: "1",
            userId: "user1",
            activityType: "Gympass",
            title: "Morgonpass",
            description: nil,
            distance: nil,
            duration: 3600,
            imageUrl: nil,
            userImageUrl: nil,
            createdAt: ISO8601DateFormatter().string(from: Date()),
            userName: "Test User",
            userAvatarUrl: nil,
            userIsPro: false,
            location: nil,
            strokes: nil,
            likeCount: 0,
            commentCount: 0,
            isLikedByCurrentUser: false,
            splits: nil,
            exercises: nil
        ),
        onDismiss: {}
    )
}
