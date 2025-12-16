import SwiftUI

struct SwipeableImageView: View {
    let routeImage: String?
    let userImage: String?
    
    @State private var currentIndex = 0
    @State private var currentId: Int? = 0
    private let peekWidth: CGFloat = 36
    private let gapWidth: CGFloat = 8
    private let imageHeight: CGFloat = 300
    
    // Cached computed property for images array - filters out empty/invalid paths
    private var images: [(String, String)] {
        var result: [(String, String)] = []
        if let routeImage = routeImage?.trimmingCharacters(in: .whitespacesAndNewlines), 
           !routeImage.isEmpty,
           isValidImagePath(routeImage) {
            result.append((routeImage, "Rutt"))
        }
        if let userImage = userImage?.trimmingCharacters(in: .whitespacesAndNewlines), 
           !userImage.isEmpty,
           isValidImagePath(userImage) {
            result.append((userImage, "Bild"))
        }
        return result
    }
    
    // Check if path is a valid image path (URL or file path)
    private func isValidImagePath(_ path: String) -> Bool {
        // Must be a URL or a file path
        return path.hasPrefix("http") || 
               path.hasPrefix("/") || 
               path.hasPrefix("file://")
    }
    
    var body: some View {
        if images.isEmpty {
            // No images - show placeholder
            Rectangle()
                .fill(Color(.systemGray6))
                .frame(height: imageHeight)
                .overlay(
                    Image(systemName: "photo")
                        .font(.system(size: 32))
                        .foregroundColor(.gray.opacity(0.5))
                )
        } else if images.count == 1 {
            // Single image - no swipe needed
            LocalAsyncImage(path: images[0].0)
                .frame(height: imageHeight)
                .clipped()
        } else {
            // Multiple images - smooth paging ScrollView with right peek + dots
            GeometryReader { geo in
                let pageWidth = max(0, geo.size.width - (peekWidth + gapWidth))
                ZStack {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: gapWidth) {
                            ForEach(Array(images.enumerated()), id: \.offset) { item in
                                LocalAsyncImage(path: item.element.0)
                                    .frame(width: pageWidth, height: imageHeight)
                                    .clipShape(RoundedRectangle(cornerRadius: 14))
                                    .id(item.offset)
                            }
                        }
                        .scrollTargetLayout()
                    }
                    .scrollTargetBehavior(.paging)
                    .contentMargins(.trailing, peekWidth)
                    .scrollPosition(id: $currentId)
                    .onAppear { currentId = 0 }
                    .onChange(of: currentId) { _, newValue in
                        if let idx = newValue { currentIndex = min(max(0, idx), images.count - 1) }
                    }

                    // Label + dots overlay
                    VStack {
                        HStack {
                            Text(images[min(currentIndex, images.count - 1)].1)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.black.opacity(0.6))
                                .cornerRadius(6)
                            Spacer()
                        }
                        .padding(12)
                        Spacer()
                        HStack(spacing: 6) {
                            ForEach(0..<images.count, id: \.self) { idx in
                                Circle()
                                    .fill(idx == currentIndex ? Color.white : Color.white.opacity(0.4))
                                    .frame(width: 6, height: 6)
                            }
                        }
                        .padding(.bottom, 10)
                    }
                }
            }
            .frame(height: imageHeight)
        }
    }
}

#Preview {
    SwipeableImageView(
        routeImage: "https://example.com/route.jpg",
        userImage: "https://example.com/user.jpg"
    )
}
