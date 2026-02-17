import SwiftUI

struct SwipeableImageView: View {
    let routeImage: String?
    let userImage: String?
    var onTapImage: (() -> Void)? = nil
    
    @State private var currentIndex = 0
    @State private var currentId: Int? = 0
    private let peekWidth: CGFloat = 36
    private let gapWidth: CGFloat = 8
    private let imageHeight: CGFloat = 300
    
    // Cached computed property for images array - filters out empty/invalid paths
    private var images: [String] {
        var result: [String] = []
        if let routeImage = routeImage?.trimmingCharacters(in: .whitespacesAndNewlines), 
           !routeImage.isEmpty,
           isValidImagePath(routeImage) {
            result.append(routeImage)
        }
        if let userImage = userImage?.trimmingCharacters(in: .whitespacesAndNewlines), 
           !userImage.isEmpty,
           isValidImagePath(userImage) {
            result.append(userImage)
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
            ZStack {
                Color(.systemGray6)
                LocalAsyncImage(path: images[0])
            }
            .frame(height: imageHeight)
            .clipped()
            .overlay(
                    // Tap only center area
                    Color.clear
                        .contentShape(Rectangle())
                        .onTapGesture {
                            onTapImage?()
                        }
                        .padding(.horizontal, 50)
                        .padding(.vertical, 50)
                )
        } else {
            // Multiple images - smooth paging ScrollView with right peek + dots
            GeometryReader { geo in
                let pageWidth = max(0, geo.size.width - (peekWidth + gapWidth))
                ZStack {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: gapWidth) {
                            ForEach(Array(images.enumerated()), id: \.offset) { index, imagePath in
                                ZStack {
                                    Color(.systemGray6)
                                    LocalAsyncImage(path: imagePath)
                                }
                                .frame(width: pageWidth, height: imageHeight)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                                    .overlay(
                                        // Tap only center area
                                        Color.clear
                                            .contentShape(Rectangle())
                                            .onTapGesture {
                                                onTapImage?()
                                            }
                                            .padding(.horizontal, 50)
                                            .padding(.vertical, 50)
                                    )
                                    .id(index)
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

                    // Dots overlay (no label)
                    VStack {
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
