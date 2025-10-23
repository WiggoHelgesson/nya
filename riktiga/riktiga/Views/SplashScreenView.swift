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
                VStack(spacing: 40) {
                    Spacer()
                    
                    // MARK: - Logo Image Animation
                    Image("1")
                        .resizable()
                        .scaledToFit()
                        .frame(height: 200)
                        .cornerRadius(20)
                        .clipped()
                        .scaleEffect(logoScale)
                        .opacity(logoOpacity)
                        .shadow(radius: 10)
                    
                    // MARK: - Text Animation (på en rad)
                    HStack(spacing: 8) {
                        Text("TRÄNA, FÅ")
                            .font(.system(size: 40, weight: .black))
                            .foregroundColor(.black)
                        
                        Text("BELÖNINGAR")
                            .font(.system(size: 40, weight: .black))
                            .foregroundColor(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 14)
                            .background(AppColors.brandYellow)
                            .cornerRadius(8)
                            .rotationEffect(.degrees(-3))
                    }
                    .offset(y: textOffset)
                    .opacity(textOpacity)
                    
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
