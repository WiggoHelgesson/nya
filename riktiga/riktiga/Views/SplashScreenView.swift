import SwiftUI

struct SplashScreenView: View {
    @State private var logoScale: CGFloat = 0.3
    @State private var logoOpacity: Double = 0
    @State private var textOpacity: Double = 0
    
    var body: some View {
        ZStack {
            // Vit bakgrund
            AppColors.white
                .ignoresSafeArea()
            
            VStack {
                Spacer()
                
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
                
                Spacer()
                
                // MARK: - Bottom tagline
                Text("Målet om ett aktivare samhälle")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.gray)
                    .opacity(textOpacity)
                    .padding(.bottom, 50)
            }
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
        
        // Fade in text slightly after logo
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            withAnimation(.easeOut(duration: 0.6)) {
                textOpacity = 1.0
            }
        }
    }
}

#Preview {
    SplashScreenView()
}
