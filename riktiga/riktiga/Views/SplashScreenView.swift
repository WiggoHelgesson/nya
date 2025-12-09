import SwiftUI

struct SplashScreenView: View {
    @State private var logoScale: CGFloat = 0.3
    @State private var logoOpacity: Double = 0
    
    var body: some View {
        ZStack {
            // Vit bakgrund
            AppColors.white
                .ignoresSafeArea()
            
            // MARK: - Centered Logo
            Image("23")
                .resizable()
                .scaledToFit()
                .frame(width: 200, height: 200)
                .cornerRadius(28)
                .clipped()
                .scaleEffect(logoScale)
                .opacity(logoOpacity)
                .shadow(color: .black.opacity(0.1), radius: 20, x: 0, y: 10)
        }
        .onAppear {
            animateSplash()
        }
    }
    
    private func animateSplash() {
        withAnimation(.easeOut(duration: 0.8)) {
            logoScale = 1.0
            logoOpacity = 1.0
        }
    }
}

#Preview {
    SplashScreenView()
}
