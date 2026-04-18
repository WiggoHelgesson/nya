import SwiftUI

struct SplashScreenView: View {
    var onComplete: (() -> Void)? = nil

    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()

            HStack(spacing: 14) {
                Image("23")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 64, height: 64)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                VStack(alignment: .leading, spacing: 2) {
                    Text("Up&Down")
                        .font(.system(size: 40, weight: .black, design: .rounded))
                        .kerning(-1)
                        .foregroundStyle(.black)

                    Text("Vi gör sport billigt")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(.black.opacity(0.75))
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

#Preview {
    SplashScreenView()
}
