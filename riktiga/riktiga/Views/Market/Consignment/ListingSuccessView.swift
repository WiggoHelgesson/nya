import SwiftUI

struct ListingSuccessView: View {
    let onDone: () -> Void

    @State private var animate = false

    private let accent = Color.black

    var body: some View {
        VStack(spacing: 28) {
            Spacer()
            ZStack {
                Circle()
                    .fill(Color.green.opacity(0.12))
                    .frame(width: 140, height: 140)
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 96, weight: .bold))
                    .foregroundStyle(.white, Color.green)
                    .scaleEffect(animate ? 1 : 0.6)
                    .opacity(animate ? 1 : 0)
                    .animation(.spring(response: 0.5, dampingFraction: 0.6), value: animate)
            }

            VStack(spacing: 10) {
                Text(L.t(sv: "Annonsen är upplagd!", nb: "Annonsen er lagt ut!"))
                    .font(.system(size: 24, weight: .bold))
                    .multilineTextAlignment(.center)
                Text(L.t(
                    sv: "Vi granskar din annons inom kort.",
                    nb: "Vi går gjennom annonsen din snart."
                ))
                .font(.system(size: 15))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            }

            Spacer()

            Button {
                NotificationCenter.default.post(name: .communityListingsNeedRefresh, object: nil)
                onDone()
            } label: {
                Text(L.t(sv: "Klar", nb: "Ferdig"))
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(accent)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.white.ignoresSafeArea())
        .navigationBarBackButtonHidden(true)
        .onAppear {
            animate = true
            let haptic = UINotificationFeedbackGenerator()
            haptic.notificationOccurred(.success)
        }
    }
}
