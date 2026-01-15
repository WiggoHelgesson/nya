import SwiftUI

struct SplashScreenView: View {
    var onComplete: (() -> Void)? = nil
    
    var body: some View {
        ZStack {
            // Vit bakgrund
            Color.white
                .ignoresSafeArea()
            
            // MARK: - Centered Logo (statisk, ingen animation)
            Image("23")
                .resizable()
                .scaledToFit()
                .frame(width: 180, height: 180)
                .cornerRadius(32)
                .shadow(color: .black.opacity(0.08), radius: 30, x: 0, y: 15)
        }
        .onAppear {
            // Vänta en kort stund och sedan gå vidare
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                onComplete?()
            }
        }
    }
}

#Preview {
    SplashScreenView()
}
