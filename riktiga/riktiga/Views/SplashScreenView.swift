import SwiftUI

struct SplashScreenView: View {
    var onComplete: (() -> Void)? = nil

    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()

            Image("115")
                .resizable()
                .scaledToFit()
                .frame(width: 168, height: 168)
                .clipShape(RoundedRectangle(cornerRadius: 36, style: .continuous))
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                onComplete?()
            }
        }
    }
}

#Preview {
    SplashScreenView()
}
