import SwiftUI

struct SplashScreenView: View {
    @State private var isAnimating = false
    @State private var logoScale: CGFloat = 0.3
    @State private var logoOpacity: Double = 0
    @State private var textOffset: CGFloat = 50
    @State private var textOpacity: Double = 0
    @State private var isFinished = false
    
    var body: some View {
        ZStack {
            // Vit bakgrund
            AppColors.white
                .ignoresSafeArea()
            
            if !isFinished {
                VStack(spacing: 35) {
                    Spacer()
                    
                    // MARK: - Logo Image Animation
                    Image("1")
                        .resizable()
                        .scaledToFit()
                        .frame(height: 160)
                        .cornerRadius(20)
                        .clipped()
                        .scaleEffect(logoScale)
                        .opacity(logoOpacity)
                        .shadow(radius: 10)
                    
                    // MARK: - Text Animation (exakt som auth-sidan)
                    VStack(spacing: 2) {
                        Text("TRÄNA,")
                            .font(.system(size: 40, weight: .black))
                            .foregroundColor(.black)
                            .lineLimit(1)
                        
                        Text("FÅ BELÖNINGAR")
                            .font(.system(size: 32, weight: .black))
                            .foregroundColor(.white)
                            .lineLimit(1)
                            .padding(.horizontal, 18)
                            .padding(.vertical, 11)
                            .background(AppColors.brandBlue)
                            .cornerRadius(8)
                            .rotationEffect(.degrees(-3))
                    }
                    .offset(y: textOffset)
                    .opacity(textOpacity)
                    .padding(.horizontal, 20)
                    
                    Spacer()
                }
                .padding()
                .onAppear {
                    animateSplash()
                }
            }
        }
    }
    
    private func animateSplash() {
        // Logo animation
        withAnimation(.easeOut(duration: 0.8)) {
            logoScale = 1.0
            logoOpacity = 1.0
        }
        
        // Text animation (starts after logo)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation(.easeOut(duration: 0.6)) {
                textOffset = 0
                textOpacity = 1.0
            }
        }
        
        // Finish splash screen after total animation time
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation(.easeInOut(duration: 0.4)) {
                isFinished = true
            }
        }
    }
}

#Preview {
    SplashScreenView()
}
