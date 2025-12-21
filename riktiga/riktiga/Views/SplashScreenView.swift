import SwiftUI

struct SplashScreenView: View {
    var onComplete: (() -> Void)? = nil
    @State private var logoScale: CGFloat = 0.6
    @State private var logoOpacity: Double = 0
    
    var body: some View {
        ZStack {
            // Vit bakgrund
            Color.white
                .ignoresSafeArea()
            
            // MARK: - Centered Logo med snygg zoom animation
            Image("23")
                .resizable()
                .scaledToFit()
                .frame(width: 180, height: 180)
                .cornerRadius(32)
                .scaleEffect(logoScale)
                .opacity(logoOpacity)
                .shadow(color: .black.opacity(0.08), radius: 30, x: 0, y: 15)
        }
        .onAppear {
            animateSplash()
        }
    }
    
    private func animateSplash() {
        // Smidig zoom-in animation med spring-effekt
        withAnimation(.spring(response: 0.7, dampingFraction: 0.7, blendDuration: 0)) {
            logoScale = 1.0
            logoOpacity = 1.0
        }
        
        // Anropa onComplete efter animationen
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            onComplete?()
        }
    }
}

#Preview {
    SplashScreenView()
}
