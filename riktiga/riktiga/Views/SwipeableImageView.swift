import SwiftUI

struct SwipeableImageView: View {
    let routeImage: String?
    let userImage: String?
    
    @State private var currentIndex = 0
    
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
            // Multiple images - show with swipe
            ZStack {
                // Image carousel
                TabView(selection: $currentIndex) {
                    ForEach(0..<images.count, id: \.self) { index in
                        LocalAsyncImage(path: images[index].0)
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .always))
                .frame(height: 300)
                
                // Image labels
                VStack {
                    HStack {
                        Text(images[currentIndex].1)
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
                }
            }
        }
    }
}

#Preview {
    SwipeableImageView(
        routeImage: "https://example.com/route.jpg",
        userImage: "https://example.com/user.jpg"
    )
}
