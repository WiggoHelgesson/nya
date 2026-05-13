import SwiftUI

struct SplashScreenView: View {
    var onComplete: (() -> Void)? = nil

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color.white.ignoresSafeArea()

                SplashCollageBackground(size: geo.size)
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    Spacer()
                    Image("AppLogo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 168, height: 168)
                        .clipShape(RoundedRectangle(cornerRadius: 36, style: .continuous))
                        .shadow(color: .black.opacity(0.18), radius: 24, x: 0, y: 12)
                    Spacer()
                }
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                onComplete?()
            }
        }
    }
}

// MARK: - Collage background

private struct SplashCollageBackground: View {
    let size: CGSize

    private struct Tile: Identifiable {
        let id = UUID()
        let image: String
        let xRatio: CGFloat
        let yRatio: CGFloat
        let widthRatio: CGFloat
        let aspect: CGFloat
        let rotation: Double
    }

    private var tiles: [Tile] {
        [
            Tile(image: "96",  xRatio: 0.18, yRatio: 0.14, widthRatio: 0.40, aspect: 1.05, rotation: -7),
            Tile(image: "97",  xRatio: 0.78, yRatio: 0.20, widthRatio: 0.36, aspect: 1.20, rotation:  6),
            Tile(image: "98",  xRatio: 0.16, yRatio: 0.78, widthRatio: 0.38, aspect: 1.15, rotation:  4),
            Tile(image: "99",  xRatio: 0.82, yRatio: 0.74, widthRatio: 0.42, aspect: 1.05, rotation: -5),
            Tile(image: "100", xRatio: 0.50, yRatio: 0.93, widthRatio: 0.46, aspect: 0.85, rotation:  2),
        ]
    }

    var body: some View {
        ZStack {
            ForEach(tiles) { tile in
                let w = size.width * tile.widthRatio
                let h = w * tile.aspect
                Image(tile.image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: w, height: h)
                    .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
                    .shadow(color: .black.opacity(0.10), radius: 14, x: 0, y: 6)
                    .rotationEffect(.degrees(tile.rotation))
                    .position(
                        x: size.width * tile.xRatio,
                        y: size.height * tile.yRatio
                    )
            }
        }
        .opacity(0.85)
        .overlay(
            // Mjuk vit vinjettering så loggan i mitten alltid har bra kontrast.
            RadialGradient(
                colors: [Color.white.opacity(0.85), Color.white.opacity(0.0)],
                center: .center,
                startRadius: 30,
                endRadius: max(size.width, size.height) * 0.45
            )
            .allowsHitTesting(false)
        )
    }
}

#Preview {
    SplashScreenView()
}
