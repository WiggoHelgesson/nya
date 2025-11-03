import SwiftUI
import Photos
import UIKit

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
        let cardSize = CGSize(width: 340, height: 550)
        let format = UIGraphicsImageRendererFormat()
        format.scale = UIScreen.main.scale
        format.opaque = false
        let renderer = UIGraphicsImageRenderer(size: cardSize, format: format)
        let image = renderer.image { context in
            let cg = context.cgContext
            cg.setFillColor(UIColor.clear.cgColor)
            cg.fill(CGRect(origin: .zero, size: cardSize))

            if let backgroundImage {
                cg.saveGState()
                cg.interpolationQuality = .high
                backgroundImage.draw(in: CGRect(origin: .zero, size: cardSize))
                if let gradient = CGGradient(
                    colorsSpace: CGColorSpaceCreateDeviceRGB(),
                    colors: [UIColor.black.withAlphaComponent(0.15).cgColor, UIColor.black.withAlphaComponent(0.75).cgColor] as CFArray,
                    locations: [0.0, 1.0]
                ) {
                    cg.drawLinearGradient(
                        gradient,
                        start: CGPoint(x: cardSize.width / 2, y: 0),
                        end: CGPoint(x: cardSize.width / 2, y: cardSize.height),
                        options: []
                    )
                }
                cg.restoreGState()
            }

            let padding: CGFloat = 36
            let topOffset: CGFloat = 80
            let iconDiameter: CGFloat = 72
            let iconRect = CGRect(x: padding, y: topOffset, width: iconDiameter, height: iconDiameter)
            
            cg.setFillColor(UIColor.white.cgColor)
            cg.fillEllipse(in: iconRect)
            
            if let icon = UIImage(systemName: shareActivityIconName)?
                .applyingSymbolConfiguration(UIImage.SymbolConfiguration(pointSize: 32, weight: .semibold))?
                .withTintColor(.black, renderingMode: .alwaysOriginal) {
                let inset: CGFloat = (iconDiameter - 32) / 2
                icon.draw(in: iconRect.insetBy(dx: inset, dy: inset))
            }
            
            let titleFont = UIFont.systemFont(ofSize: 34, weight: .heavy)
            let titleAttributes: [NSAttributedString.Key: Any] = [
                .font: titleFont,
                .foregroundColor: UIColor.white
            ]
            let activityTitle = (post.title.isEmpty ? (post.activityType ?? "Aktivitet") : post.title) as NSString
            let titlePoint = CGPoint(x: iconRect.maxX + 18, y: iconRect.midY - titleFont.lineHeight / 2)
            activityTitle.draw(at: titlePoint, withAttributes: titleAttributes)
            
            let labelFont = UIFont.systemFont(ofSize: 14, weight: .semibold)
            let valueFont = UIFont.systemFont(ofSize: 28, weight: .bold)
            let labelAttributes: [NSAttributedString.Key: Any] = [
                .font: labelFont,
                .kern: 0.6,
                .foregroundColor: UIColor.white.withAlphaComponent(0.7)
            ]
            let valueAttributes: [NSAttributedString.Key: Any] = [
                .font: valueFont,
                .foregroundColor: UIColor.white
            ]
            
            let statsTop = iconRect.maxY + 44
            let secondColumnWidth: CGFloat = 140
            let secondColumnX = cardSize.width - padding - secondColumnWidth
            
            ("DISTANCE" as NSString).draw(at: CGPoint(x: padding, y: statsTop), withAttributes: labelAttributes)
            (String(format: "%.2f km", post.distance ?? 0) as NSString).draw(at: CGPoint(x: padding, y: statsTop + labelFont.lineHeight + 6), withAttributes: valueAttributes)
            ("TIME" as NSString).draw(at: CGPoint(x: secondColumnX, y: statsTop), withAttributes: labelAttributes)
            (formatDuration(post.duration ?? 0) as NSString).draw(at: CGPoint(x: secondColumnX, y: statsTop + labelFont.lineHeight + 6), withAttributes: valueAttributes)
            
            if let pace = paceString(distance: post.distance, duration: post.duration) {
                let paceTop = statsTop + labelFont.lineHeight + valueFont.lineHeight + 34
                ("PACE" as NSString).draw(at: CGPoint(x: padding, y: paceTop), withAttributes: labelAttributes)
                (pace as NSString).draw(at: CGPoint(x: padding, y: paceTop + labelFont.lineHeight + 6), withAttributes: valueAttributes)
            }
            
            let brandSize: CGFloat = 60
            let brandRect = CGRect(x: padding, y: cardSize.height - brandSize - 72, width: brandSize, height: brandSize)
            let brandCornerRadius: CGFloat = 16
            let brandPath = UIBezierPath(roundedRect: brandRect, cornerRadius: brandCornerRadius)

            cg.saveGState()
            cg.addPath(brandPath.cgPath)
            cg.setFillColor(UIColor.white.cgColor)
            cg.fillPath()
            cg.restoreGState()

            cg.saveGState()
            brandPath.addClip()
            if let logo = UIImage(named: "23") {
                logo.draw(in: brandRect)
            } else {
                cg.setFillColor(UIColor.black.cgColor)
                cg.fill(brandRect)
            }
            cg.restoreGState()

            cg.saveGState()
            cg.addPath(brandPath.cgPath)
            cg.setStrokeColor(UIColor.white.withAlphaComponent(0.6).cgColor)
            cg.setLineWidth(2)
            cg.strokePath()
            cg.restoreGState()

            let brandFont = UIFont.systemFont(ofSize: 22, weight: .semibold)
            let brandAttributes: [NSAttributedString.Key: Any] = [
                .font: brandFont,
                .foregroundColor: UIColor.white
            ]
            let brandPoint = CGPoint(x: brandRect.maxX + 16, y: brandRect.midY - brandFont.lineHeight / 2)
            ("Up&Down" as NSString).draw(at: brandPoint, withAttributes: brandAttributes)
        }
        return image
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
    
    private func paceString(distance: Double?, duration: Int?) -> String? {
        guard let distance = distance, distance > 0,
              let duration = duration else { return nil }
        let paceSeconds = Double(duration) / distance
        let minutes = Int(paceSeconds) / 60
        let seconds = Int(paceSeconds) % 60
        return String(format: "%d:%02d /km", minutes, seconds)
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
                    PHAssetChangeRequest.creationRequestForAsset(from: image)
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
        case "Promenad": return "figure.walk.circle.fill"
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
        ZStack(alignment: .topLeading) {
            backgroundView
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color.black.opacity(0.0001))
                )
            
            VStack(alignment: .leading, spacing: 32) {
                header
                statsSection
                Spacer()
                brandRow
            }
            .padding(.top, 80)
            .padding(.horizontal, 36)
            .padding(.bottom, 72)
        }
        .frame(width: 340, height: 550)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }

    @ViewBuilder
    private var backgroundView: some View {
        switch background {
        case .gradient:
            LinearGradient(
                colors: [Color.black.opacity(0.95), Color.black.opacity(0.65)],
                startPoint: .top,
                endPoint: .bottom
            )
        case .map(let image):
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .overlay(
                    LinearGradient(
                        colors: [Color.black.opacity(0.15), Color.black.opacity(0.75)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
        case .loading:
            LinearGradient(
                colors: [Color.black.opacity(0.95), Color.black.opacity(0.65)],
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
    
    private var header: some View {
        HStack(alignment: .center, spacing: 18) {
            ZStack {
                Circle()
                    .fill(Color.white)
                Image(systemName: activityIconName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 32, height: 32)
                    .foregroundColor(.black)
            }
            .frame(width: 72, height: 72)
            
            Text(post.title.isEmpty ? (post.activityType ?? "Aktivitet") : post.title)
                .font(.system(size: 34, weight: .heavy))
                .foregroundColor(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
    }
    
    private var statsSection: some View {
        VStack(alignment: .leading, spacing: 28) {
            HStack(alignment: .top, spacing: 32) {
                statBlock(title: "DISTANCE", value: String(format: "%.2f km", post.distance ?? 0))
                Spacer()
                statBlock(title: "TIME", value: formatDuration(post.duration ?? 0))
            }
            statBlock(title: "PACE", value: paceString(distance: post.distance, duration: post.duration) ?? "-")
        }
    }
    
    private func statBlock(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .kerning(0.6)
                .foregroundColor(.white.opacity(0.7))
            Text(value)
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(.white)
        }
    }
    
    private var brandRow: some View {
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.white)
                Image("23")
                    .resizable()
                    .scaledToFit()
                    .padding(10)
            }
            .frame(width: 60, height: 60)
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.white.opacity(0.6), lineWidth: 2)
            )
            Text("Up&Down")
                .font(.system(size: 22, weight: .semibold))
                .foregroundColor(.white)
        }
    }
    
    private var activityIconName: String {
        switch post.activityType {
        case "Löppass": return "figure.run.circle.fill"
        case "Golfrunda": return "flag.circle.fill"
        case "Promenad": return "figure.walk.circle.fill"
        case "Bestiga berg": return "mountain.2.circle.fill"
        case "Skidåkning": return "snowflake.circle.fill"
        default: return "figure.run.circle.fill"
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
    
    private func paceString(distance: Double?, duration: Int?) -> String? {
        guard let distance = distance, distance > 0,
              let duration = duration else { return nil }
        let paceSeconds = Double(duration) / distance
        let minutes = Int(paceSeconds) / 60
        let seconds = Int(paceSeconds) % 60
        return String(format: "%d:%02d /km", minutes, seconds)
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
