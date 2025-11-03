import SwiftUI

struct SwipeableImageView: View {
    let routeImage: String?
    let userImage: String?
    
    @State private var currentIndex = 0
    @State private var currentId: Int? = 0
    private let peekWidth: CGFloat = 36
    private let gapWidth: CGFloat = 8
    
    var images: [(String, String)] {
        var result: [(String, String)] = []
        if let routeImage = routeImage, !routeImage.isEmpty {
            result.append((routeImage, "Rutt"))
        }
        if let userImage = userImage, !userImage.isEmpty {
            result.append((userImage, "Bild"))
        }
        return result
    }
    
    var body: some View {
        if images.isEmpty {
            // No images
            Color(.systemGray6)
                .frame(height: 300)
        } else if images.count == 1 {
            // Single image - no swipe needed
            LocalAsyncImage(path: images[0].0)
                .frame(height: 300)
        } else {
            // Multiple images - smooth paging ScrollView with right peek + dots
            GeometryReader { geo in
                let pageWidth = max(0, geo.size.width - (peekWidth + gapWidth))
                ZStack {
                    ScrollView(.horizontal) {
                        HStack(spacing: gapWidth) {
                            ForEach(Array(images.enumerated()), id: \.offset) { item in
                                LocalAsyncImage(path: item.element.0)
                                    .frame(width: pageWidth, height: 300)
                                    .clipShape(RoundedRectangle(cornerRadius: 14))
                                    .id(item.offset)
                            }
                        }
                        .scrollTargetLayout()
                    }
                    .scrollTargetBehavior(.paging)
                    .contentMargins(.trailing, peekWidth)
                    .scrollIndicators(.hidden)
                    .frame(height: 300)
                    .scrollPosition(id: $currentId)
                    .onAppear { currentId = 0 }
                    .onChange(of: currentId) { _, newValue in
                        if let idx = newValue { currentIndex = min(max(0, idx), images.count - 1) }
                    }

                    // Label + dots
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
            .frame(height: 300)
        }
    }
}

#Preview {
    SwipeableImageView(
        routeImage: "https://example.com/route.jpg",
        userImage: "https://example.com/user.jpg"
    )
}
