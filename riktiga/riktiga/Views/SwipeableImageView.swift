import SwiftUI

struct SwipeableImageView: View {
    let routeImage: String?
    let userImage: String?
    var onTapImage: (() -> Void)? = nil
    
    @State private var currentIndex = 0
    @State private var currentId: Int? = 0
    private let peekWidth: CGFloat = 8
    private let gapWidth: CGFloat = 8
    private let imageHeight: CGFloat = 300
    
    private var images: [String] {
        var result: [String] = []
        if let routeImage = routeImage?.trimmingCharacters(in: .whitespacesAndNewlines),
           !routeImage.isEmpty, isValidImagePath(routeImage) {
            result.append(routeImage)
        }
        if let raw = userImage?.trimmingCharacters(in: .whitespacesAndNewlines),
           !raw.isEmpty {
            if raw.hasPrefix("["),
               let data = raw.data(using: .utf8),
               let urls = try? JSONDecoder().decode([String].self, from: data) {
                result.append(contentsOf: urls.filter { isValidImagePath($0) })
            } else if isValidImagePath(raw) {
                result.append(raw)
            }
        }
        return result
    }
    
    private func isValidImagePath(_ path: String) -> Bool {
        path.hasPrefix("http") || path.hasPrefix("/") || path.hasPrefix("file://")
    }
    
    var body: some View {
        if images.isEmpty {
            Rectangle()
                .fill(Color(.systemGray6))
                .frame(height: imageHeight)
                .overlay(
                    Image(systemName: "photo")
                        .font(.system(size: 32))
                        .foregroundColor(.gray.opacity(0.5))
                )
        } else if images.count == 1 {
            ZStack {
                Color(.systemGray6)
                LocalAsyncImage(path: images[0])
            }
            .frame(height: imageHeight)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .padding(.horizontal, 2)
            .overlay(
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture { onTapImage?() }
                    .padding(.horizontal, 50)
                    .padding(.vertical, 50)
            )
        } else {
            GeometryReader { geo in
                let sideInset = peekWidth + gapWidth
                let pageWidth = max(0, geo.size.width - 2 * sideInset)
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
                                    Color.clear
                                        .contentShape(Rectangle())
                                        .onTapGesture { onTapImage?() }
                                        .padding(.horizontal, 50)
                                        .padding(.vertical, 50)
                                )
                                .id(index)
                            }
                        }
                        .scrollTargetLayout()
                    }
                    .scrollTargetBehavior(.viewAligned)
                    .contentMargins(.horizontal, sideInset)
                    .scrollPosition(id: $currentId)
                    .onAppear { currentId = 0 }
                    .onChange(of: currentId) { _, newValue in
                        if let idx = newValue { currentIndex = min(max(0, idx), images.count - 1) }
                    }

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
