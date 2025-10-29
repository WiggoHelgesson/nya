import SwiftUI
import Photos

struct ShareActivityView: View {
    let post: SocialWorkoutPost
    @Environment(\.dismiss) private var dismiss
    @State private var shareImage: UIImage?
    @State private var showingSaveAlert = false
    @State private var saveMessage = ""
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemBackground).ignoresSafeArea()
                
                VStack(spacing: 20) {
                    // Preview of the shareable card
                    ActivityCardPreview(post: post)
                        .padding()
                    
                    // Action buttons
                    VStack(spacing: 12) {
                        Button(action: saveToPhotoLibrary) {
                            HStack {
                                Image(systemName: "photo.badge.plus")
                                Text("Spara till kamerarull")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(AppColors.brandBlue)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                        }
                        
                        Button(action: shareViaActivityViewController) {
                            HStack {
                                Image(systemName: "square.and.arrow.up")
                                Text("Dela")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color(.systemGray5))
                            .foregroundColor(.black)
                            .cornerRadius(8)
                        }
                    }
                    .padding()
                    
                    Spacer()
                }
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
    }
    
    private func generateCardImage() -> UIImage? {
        let cardSize = CGSize(width: 340, height: 550)
        
        let renderer = UIGraphicsImageRenderer(size: cardSize)
        let image = renderer.image { context in
            // Draw background - use map image if available
            if let imageUrl = post.imageUrl, let url = URL(string: imageUrl) {
                // Try to load the image from URL
                if let data = try? Data(contentsOf: url), let backgroundImage = UIImage(data: data) {
                    backgroundImage.draw(in: CGRect(origin: .zero, size: cardSize))
                } else {
                    // Fallback to gradient if URL loading fails
                    UIColor.darkGray.setFill()
                    context.cgContext.fill(CGRect(origin: .zero, size: cardSize))
                }
            } else {
                // Fallback to gradient
                UIColor.darkGray.setFill()
                context.cgContext.fill(CGRect(origin: .zero, size: cardSize))
            }
            
            // Draw gradient overlay
            let colorSpace = CGColorSpaceCreateDeviceRGB()
            let colors = [UIColor.clear.cgColor, UIColor.black.withAlphaComponent(0.7).cgColor] as CFArray
            let gradient = CGGradient(colorsSpace: colorSpace, colors: colors, locations: nil)
            
            if let gradient = gradient {
                let startPoint = CGPoint(x: cardSize.width, y: 0)
                let endPoint = CGPoint(x: 0, y: cardSize.height)
                context.cgContext.drawLinearGradient(gradient, start: startPoint, end: endPoint, options: [])
            }
            
            // Draw content at bottom
            let bottomPadding: CGFloat = 30
            var currentY = cardSize.height - bottomPadding
            
            // Title
            let titleFont = UIFont.systemFont(ofSize: 24, weight: .bold)
            let titleAttributes: [NSAttributedString.Key: Any] = [
                .font: titleFont,
                .foregroundColor: UIColor.white
            ]
            let titleSize = (post.title as NSString).size(withAttributes: titleAttributes)
            (post.title as NSString).draw(at: CGPoint(x: 16, y: currentY - titleSize.height), withAttributes: titleAttributes)
            currentY -= titleSize.height + 20
            
            // Distance
            let labelFont = UIFont.systemFont(ofSize: 12, weight: .regular)
            let labelAttributes: [NSAttributedString.Key: Any] = [
                .font: labelFont,
                .foregroundColor: UIColor.white.withAlphaComponent(0.7)
            ]
            ("Distans" as NSString).draw(at: CGPoint(x: 16, y: currentY), withAttributes: labelAttributes)
            
            let valueFont = UIFont.systemFont(ofSize: 18, weight: .bold)
            let valueAttributes: [NSAttributedString.Key: Any] = [
                .font: valueFont,
                .foregroundColor: UIColor.white
            ]
            let distanceText = String(format: "%.2f km", post.distance ?? 0)
            (distanceText as NSString).draw(at: CGPoint(x: 16, y: currentY + 16), withAttributes: valueAttributes)
            
            // Time
            ("Tid" as NSString).draw(at: CGPoint(x: 180, y: currentY), withAttributes: labelAttributes)
            
            let durationText = formatDuration(post.duration ?? 0)
            (durationText as NSString).draw(at: CGPoint(x: 180, y: currentY + 16), withAttributes: valueAttributes)
            
            // Draw Up&Down logo at top
            let logoX: CGFloat = 16
            let logoY: CGFloat = 16
            let logoSize: CGFloat = 40
            
            // Draw a simple rounded rectangle as logo placeholder
            let logoRect = CGRect(x: logoX, y: logoY, width: logoSize, height: logoSize)
            let logoPath = UIBezierPath(roundedRect: logoRect, cornerRadius: 6)
            UIColor.white.withAlphaComponent(0.2).setFill()
            logoPath.fill()
            
            let logoText = "U&D"
            let logoTextFont = UIFont.systemFont(ofSize: 14, weight: .bold)
            let logoTextAttributes: [NSAttributedString.Key: Any] = [
                .font: logoTextFont,
                .foregroundColor: UIColor.white
            ]
            let logoTextSize = (logoText as NSString).size(withAttributes: logoTextAttributes)
            let logoTextX = logoX + (logoSize - logoTextSize.width) / 2
            let logoTextY = logoY + (logoSize - logoTextSize.height) / 2
            (logoText as NSString).draw(at: CGPoint(x: logoTextX, y: logoTextY), withAttributes: logoTextAttributes)
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
    
    private func saveToPhotoLibrary() {
        guard let image = generateCardImage() else {
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
                            saveMessage = "Bilden har sparats till kamerarullen!"
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
    
    private func shareViaActivityViewController() {
        guard let image = generateCardImage() else {
            saveMessage = "Det uppstod ett fel när bilden skulle skapas"
            showingSaveAlert = true
            return
        }
        
        let activityViewController = UIActivityViewController(activityItems: [image], applicationActivities: nil)
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let rootViewController = window.rootViewController {
            rootViewController.present(activityViewController, animated: true)
        }
    }
}

struct ActivityCardPreview: View {
    let post: SocialWorkoutPost
    
    var body: some View {
        ZStack(alignment: .bottomLeading) {
            // Background - show map image if available
            if let imageUrl = post.imageUrl {
                AsyncImage(url: URL(string: imageUrl)) { image in
                    image
                        .resizable()
                        .scaledToFill()
                } placeholder: {
                    Color.gray
                }
                .ignoresSafeArea()
            } else {
                // Fallback gradient
                LinearGradient(
                    gradient: Gradient(colors: [Color.gray, Color(.systemGray3)]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
            
            // Gradient overlay
            LinearGradient(
                gradient: Gradient(colors: [Color.clear, Color.black.opacity(0.8)]),
                startPoint: .topTrailing,
                endPoint: .bottomLeading
            )
            
            // Content at bottom
            VStack(alignment: .leading, spacing: 8) {
                // Logo
                HStack {
                    ZStack {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.white.opacity(0.2))
                            .frame(width: 40, height: 40)
                        
                        Text("U&D")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                    }
                    Spacer()
                }
                
                // Title
                Text(post.title)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.white)
                
                // Stats
                HStack(spacing: 24) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Distans")
                            .font(.system(size: 11, weight: .regular))
                            .foregroundColor(.white.opacity(0.7))
                        Text(String(format: "%.2f km", post.distance ?? 0))
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Tid")
                            .font(.system(size: 11, weight: .regular))
                            .foregroundColor(.white.opacity(0.7))
                        Text(formatDuration(post.duration ?? 0))
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)
                    }
                    
                    Spacer()
                }
            }
            .padding(16)
        }
        .frame(height: 450)
        .cornerRadius(12)
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
