import SwiftUI
import Photos
import UIKit
import UniformTypeIdentifiers

struct ShareActivityView: View {
    let post: SocialWorkoutPost
    @Environment(\.dismiss) private var dismiss
    @State private var showingSaveAlert = false
    @State private var saveMessage = ""
    @State private var userImage: UIImage?
    @State private var isLoadingUserImage = false
    @State private var userImageLoadError = false
    @State private var selectedBackgrounds: [ShareCardBackground] = [.transparent]
    @State private var currentBackgroundIndex: Int = 0
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemBackground)
                    .ignoresSafeArea()

                VStack(spacing: 24) {
                    TabView(selection: $currentBackgroundIndex) {
                        ForEach(Array(selectedBackgrounds.enumerated()), id: \.offset) { index, background in
                            ActivityCardPreview(
                                post: post,
                                background: previewBackground(for: background)
                            )
                            .tag(index)
                            .padding(.horizontal, 16)
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                    .frame(height: 560)
                    .animation(.easeInOut, value: selectedBackgrounds.count)
                    .animation(.easeInOut, value: currentBackgroundIndex)

                    if selectedBackgrounds.count > 1 {
                        Picker("Bakgrund", selection: $currentBackgroundIndex) {
                            ForEach(Array(selectedBackgrounds.enumerated()), id: \.offset) { index, background in
                                Text(background.displayName)
                                    .tag(index)
                            }
                        }
                        .pickerStyle(.segmented)
                        .padding(.horizontal, 16)
                    }

                    if selectedBackgrounds.count > 1 {
                        HStack(spacing: 8) {
                            ForEach(0..<selectedBackgrounds.count, id: \.self) { index in
                                Circle()
                                    .fill(index == currentBackgroundIndex ? Color.black : Color.gray.opacity(0.3))
                                    .frame(width: 8, height: 8)
                            }
                        }
                    }

                    if selectedBackgrounds.indices.contains(currentBackgroundIndex) && selectedBackgrounds[currentBackgroundIndex] == .userPhoto {
                        if isLoadingUserImage {
                            HStack(spacing: 8) {
                                ProgressView()
                                Text("Laddar din bild...")
                                    .font(.system(size: 13))
                                    .foregroundColor(.gray)
                            }
                        } else if userImageLoadError {
                            VStack(spacing: 6) {
                                Text("Kunde inte hämta din bild.")
                                    .font(.system(size: 13, weight: .semibold))
                                Button("Försök igen") {
                                    if let url = post.userImageUrl {
                                        loadUserImage(from: url, force: true)
                                    }
                                }
                                .font(.system(size: 13, weight: .semibold))
                            }
                            .foregroundColor(.black)
                        }
                    }

                    Button(action: saveCurrentPreview) {
                        Text("Spara bild")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.black)
                            .cornerRadius(12)
                    }
                    .padding(.horizontal, 16)

                    Spacer()
                }
                .padding(.top, 24)
                .padding(.bottom, 16)
            }
            .navigationTitle("Dela aktivitet")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Stäng") {
                        dismiss()
                    }
                }
            }
            .alert("Meddelande", isPresented: $showingSaveAlert) {
                Button("OK") { dismiss() }
            } message: {
                Text(saveMessage)
            }
        }
        .onAppear {
            setupBackgrounds()
        }
        .onChange(of: selectedBackgrounds) { _ in
            if currentBackgroundIndex >= selectedBackgrounds.count {
                currentBackgroundIndex = max(0, selectedBackgrounds.count - 1)
            }
        }
    }

    private func generateCardImage(backgroundImage: UIImage?) -> UIImage? {
        let canvasSize = CGSize(width: 1080, height: 1920)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 3
        format.opaque = false

        let stats = overlayStats(for: post)

        let renderer = UIGraphicsImageRenderer(size: canvasSize, format: format)
        return renderer.image { context in
            let cg = context.cgContext
            cg.setFillColor(UIColor.clear.cgColor)
            cg.fill(CGRect(origin: .zero, size: canvasSize))

            if let backgroundImage {
                cg.saveGState()
                cg.interpolationQuality = .high
                backgroundImage.draw(in: CGRect(origin: .zero, size: canvasSize))

                if let gradient = CGGradient(
                    colorsSpace: CGColorSpaceCreateDeviceRGB(),
                    colors: [
                        UIColor.black.withAlphaComponent(0.35).cgColor,
                        UIColor.black.withAlphaComponent(0.85).cgColor
                    ] as CFArray,
                    locations: [0.0, 1.0]
                ) {
                    cg.drawLinearGradient(
                        gradient,
                        start: CGPoint(x: canvasSize.width / 2, y: 0),
                        end: CGPoint(x: canvasSize.width / 2, y: canvasSize.height),
                        options: []
                    )
                }
                cg.restoreGState()
            }

            let labelFont = UIFont.systemFont(ofSize: 72, weight: .semibold)
            let primaryValueFont = UIFont.systemFont(ofSize: 150, weight: .heavy)
            let secondaryValueFont = UIFont.systemFont(ofSize: 120, weight: .heavy)
            let brandFont = UIFont.systemFont(ofSize: 110, weight: .black)

            let labelColor = UIColor.white.withAlphaComponent(0.85)
            let valueColor = UIColor.white

            var currentY: CGFloat = 220
            let valueSpacing: CGFloat = 24
            let sectionSpacing: CGFloat = 96

            func drawCentered(_ text: String, attributes: [NSAttributedString.Key: Any], y: CGFloat) -> CGFloat {
                let nsText = text as NSString
                let size = nsText.size(withAttributes: attributes)
                let rect = CGRect(x: (canvasSize.width - size.width) / 2, y: y, width: size.width, height: size.height)
                nsText.draw(in: rect, withAttributes: attributes)
                return rect.maxY
            }

            func drawStat(title: String, value: String, valueFont: UIFont) {
                let titleAttributes: [NSAttributedString.Key: Any] = [
                    .font: labelFont,
                    .foregroundColor: labelColor
                ]
                let valueAttributes: [NSAttributedString.Key: Any] = [
                    .font: valueFont,
                    .foregroundColor: valueColor,
                    .kern: 2.0
                ]

                currentY = drawCentered(title, attributes: titleAttributes, y: currentY)
                currentY = drawCentered(value, attributes: valueAttributes, y: currentY + valueSpacing)
                currentY += sectionSpacing
            }

            for stat in stats {
                let valueFont = stat.isPrimary ? primaryValueFont : secondaryValueFont
                drawStat(title: stat.title, value: stat.value, valueFont: valueFont)
            }

            let brandingTop = currentY + 140

            if let logo = UIImage(named: "23") {
                let logoSize: CGFloat = 260
                let logoRect = CGRect(
                    x: (canvasSize.width - logoSize) / 2,
                    y: brandingTop,
                    width: logoSize,
                    height: logoSize
                )

                let roundedPath = UIBezierPath(roundedRect: logoRect, cornerRadius: logoSize * 0.25)
                cg.saveGState()
                cg.addPath(roundedPath.cgPath)
                cg.clip()
                logo.draw(in: logoRect)
                cg.restoreGState()

                cg.saveGState()
                cg.addPath(roundedPath.cgPath)
                cg.setStrokeColor(UIColor.white.withAlphaComponent(0.6).cgColor)
                cg.setLineWidth(6)
                cg.strokePath()
                cg.restoreGState()

                let textAttributes: [NSAttributedString.Key: Any] = [
                    .font: brandFont,
                    .foregroundColor: valueColor
                ]
                let textSize = ("Up&Down" as NSString).size(withAttributes: textAttributes)
                let textOrigin = CGPoint(
                    x: logoRect.midX - textSize.width / 2,
                    y: logoRect.maxY + 40
                )
                ("Up&Down" as NSString).draw(at: textOrigin, withAttributes: textAttributes)
            }
        }
    }
    
    private func saveToPhotoLibrary(background: ShareCardBackground) {
        if background == .userPhoto && userImage == nil {
            saveMessage = userImageLoadError ? "Bilden kunde inte laddas. Försök igen." : "Bilden laddas fortfarande. Vänta ett ögonblick och försök igen."
            showingSaveAlert = true
            return
        }
        let backgroundImage = background == .userPhoto ? userImage : nil
        guard let image = generateCardImage(backgroundImage: backgroundImage) else {
            saveMessage = "Det uppstod ett fel när bilden skulle skapas"
            showingSaveAlert = true
            return
        }
 
        PHPhotoLibrary.requestAuthorization { status in
            if status == .authorized {
                PHPhotoLibrary.shared().performChanges({
                    if background == .transparent, let pngData = image.pngData() {
                        let request = PHAssetCreationRequest.forAsset()
                        let options = PHAssetResourceCreationOptions()
                        options.uniformTypeIdentifier = UTType.png.identifier
                        request.addResource(with: .photo, data: pngData, options: options)
                    } else {
                        PHAssetChangeRequest.creationRequestForAsset(from: image)
                    }
                }) { success, error in
                    DispatchQueue.main.async {
                        if success {
                            saveMessage = background == .userPhoto ? "Bilden med din bakgrund har sparats till kamerarullen!" : "Den transparenta bilden har sparats till kamerarullen!"
                            showingSaveAlert = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                dismiss()
                            }
                        } else {
                            saveMessage = "Ett fel uppstod när bilden skulle sparas"
                            showingSaveAlert = true
                        }
                    }
                }
            } else {
                DispatchQueue.main.async {
                    saveMessage = "Du måste ge åtkomst till foton för att spara bilden"
                    showingSaveAlert = true
                }
            }
        }
    }
    
    private func saveCurrentPreview() {
        let currentBackground = selectedBackgrounds[currentBackgroundIndex]
        saveToPhotoLibrary(background: currentBackground)
    }

    private var shareActivityIconName: String {
        switch post.activityType {
        case "Löppass": return "figure.run.circle.fill"
        case "Golfrunda": return "flag.circle.fill"
        case "Gympass": return "figure.strengthtraining.traditional.circle.fill"
        case "Bestiga berg": return "mountain.2.circle.fill"
        case "Skidåkning": return "snowflake.circle.fill"
        default: return "figure.run.circle.fill"
        }
    }
    
    private func previewBackground(for background: ShareCardBackground) -> ActivityCardPreview.Background {
        switch background {
        case .transparent:
            return .gradient
        case .userPhoto:
            if let userImage {
                return .map(userImage)
            } else {
                return .loading
            }
        }
    }
    
    private func setupBackgrounds() {
        selectedBackgrounds = [.transparent]
        if let userImageUrl = post.userImageUrl, !userImageUrl.isEmpty {
            selectedBackgrounds.append(.userPhoto)
            loadUserImage(from: userImageUrl)
        }
        currentBackgroundIndex = 0
    }
    
    private func loadUserImage(from urlString: String, force: Bool = false) {
        if userImage != nil && !force { return }
        guard let url = URL(string: urlString) else { return }
        isLoadingUserImage = true
        userImageLoadError = false
        Task {
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                if let image = UIImage(data: data) {
                    await MainActor.run {
                        self.userImage = image
                    }
                } else {
                    await MainActor.run {
                        self.userImageLoadError = true
                    }
                }
            } catch {
                await MainActor.run {
                    self.userImageLoadError = true
                }
            }
            await MainActor.run {
                self.isLoadingUserImage = false
            }
        }
    }
}

private enum ShareCardBackground: Hashable {
    case transparent
    case userPhoto
}

private extension ShareCardBackground {
    var displayName: String {
        switch self {
        case .transparent:
            return "Transparent"
        case .userPhoto:
            return "Din bild"
        }
    }
}

struct ActivityCardPreview: View {
    enum Background {
        case gradient
        case map(UIImage)
        case loading
    }
    
    let post: SocialWorkoutPost
    var background: Background = .gradient
    
    var body: some View {
        ZStack {
            previewBackground
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()

            overlayContent
                .padding(.horizontal, 32)
                .padding(.vertical, 48)
        }
        .frame(width: 340, height: 550)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }

    @ViewBuilder
    private var previewBackground: some View {
        switch background {
        case .gradient:
            LinearGradient(
                colors: [Color.black.opacity(0.9), Color.black.opacity(0.6)],
                startPoint: .top,
                endPoint: .bottom
            )
        case .map(let image):
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .overlay(
                    LinearGradient(
                        colors: [Color.black.opacity(0.3), Color.black.opacity(0.85)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
        case .loading:
            LinearGradient(
                colors: [Color.black.opacity(0.9), Color.black.opacity(0.6)],
                startPoint: .top,
                endPoint: .bottom
            )
            .overlay(
                VStack(spacing: 12) {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(.white)
                    Text("Laddar bild...")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white.opacity(0.8))
                }
            )
        }
    }

    private var overlayContent: some View {
        VStack(spacing: 32) {
            if let badge = badgeText {
                Text(badge)
                    .font(.system(size: 12, weight: .bold))
                    .textCase(.uppercase)
                    .kerning(1.2)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(Color.white.opacity(0.12))
                    )
                    .foregroundColor(.white.opacity(0.9))
            }

            statStack

            Spacer()
            brandSignature
        }
        .frame(maxWidth: .infinity)
        .multilineTextAlignment(.center)
    }

    private var statStack: some View {
        VStack(spacing: 24) {
            ForEach(sharePreviewStats(for: post), id: \.title) { stat in
                statBlock(title: stat.title, value: stat.value, isPrimary: stat.isPrimary)
            }
        }
    }

    private func statBlock(title: String, value: String, isPrimary: Bool) -> some View {
        VStack(spacing: 6) {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white.opacity(0.8))
            Text(value)
                .font(.system(size: isPrimary ? 42 : 34, weight: .heavy))
                .foregroundColor(.white)
        }
        .frame(maxWidth: .infinity)
    }

    private var brandSignature: some View {
        HStack(spacing: 16) {
            Image("23")
                .resizable()
                .renderingMode(.original)
                .scaledToFit()
                .frame(width: 64, height: 64)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.6), lineWidth: 2)
                )
            Text("Up&Down")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.white)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 24)
    }

    private var badgeText: String? {
        switch background {
        case .gradient:
            return "Transparent"
        case .map:
            return nil
        case .loading:
            return nil
        }
    }
    
    private func paceString(distance: Double?, duration: Int?) -> String? {
        formattedPace(distance: distance, duration: duration)
    }
}

private struct ShareStat {
    let title: String
    let value: String
    let isPrimary: Bool
}

private func overlayStats(for post: SocialWorkoutPost) -> [ShareStat] {
    statsForPost(post)
}

private func sharePreviewStats(for post: SocialWorkoutPost) -> [ShareStat] {
    statsForPost(post)
}

private func statsForPost(_ post: SocialWorkoutPost) -> [ShareStat] {
    var stats: [ShareStat] = []

    if post.activityType == "Gympass" {
        stats.append(ShareStat(title: "Volym", value: formatGymVolume(from: post.exercises), isPrimary: true))
        stats.append(ShareStat(title: "Tid", value: overlayDurationString(post.duration), isPrimary: false))
    } else {
        stats.append(ShareStat(title: "Distance", value: formatDistance(post.distance), isPrimary: true))
        if let pace = formattedPace(distance: post.distance, duration: post.duration) {
            stats.append(ShareStat(title: "Pace", value: pace, isPrimary: false))
        }
        stats.append(ShareStat(title: "Time", value: overlayDurationString(post.duration), isPrimary: false))
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

private func calculateGymVolume(from exercises: [GymExercisePost]?) -> Double {
    guard let exercises = exercises else { return 0 }
    return exercises.reduce(0) { total, exercise in
        let pairs = zip(exercise.kg, exercise.reps)
        let exerciseVolume = pairs.reduce(0.0) { $0 + $1.0 * Double($1.1) }
        return total + exerciseVolume
    }
}

private func formattedPace(distance: Double?, duration: Int?) -> String? {
    guard let distance = distance, distance > 0,
          let duration = duration, duration > 0 else { return nil }
    let paceSeconds = Double(duration) / distance
    let minutes = Int(paceSeconds) / 60
    let seconds = Int(paceSeconds) % 60
    return String(format: "%d:%02d /km", minutes, seconds)
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

#Preview {
    ShareActivityView(post: SocialWorkoutPost(
        from: WorkoutPost(
            id: "1",
            userId: "user1",
            activityType: "Löppass",
            title: "Lunch Run",
            description: "Trevlig löprunda",
            distance: 20.80,
            duration: 11280,
            imageUrl: nil,
            elevationGain: nil,
            maxSpeed: nil
        ),
        userName: "John Doe",
        userAvatarUrl: nil,
        userIsPro: false,
        location: "Stockholm",
        strokes: nil,
        likeCount: 5,
        commentCount: 2,
        isLikedByCurrentUser: false
    ))
}
