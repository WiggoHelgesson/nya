import SwiftUI

/// Bekräftelse innan användaren lämnar skapa-/redigeringsflödet för annons.
struct SellExitConfirmationSheet: View {
    var onContinueEditing: () -> Void
    var onCloseFlow: () -> Void

    private let accent = Color.black

    var body: some View {
        VStack(spacing: 0) {
            Text(L.t(sv: "Vill du ta bort annons?", nb: "Vil du fjerne annonsen?"))
                .font(.system(size: 22, weight: .bold))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
                .padding(.top, 8)
                .padding(.bottom, 28)

            VStack(spacing: 12) {
                Button {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    onCloseFlow()
                } label: {
                    Text(L.t(sv: "Stäng", nb: "Lukk"))
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(accent)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(L.t(sv: "Stäng och lämna annonsflödet", nb: "Lukk og forlat annonsflyten"))

                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    onContinueEditing()
                } label: {
                    Text(L.t(sv: "Fortsätt", nb: "Fortsett"))
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(accent)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color(.systemBackground))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(accent.opacity(0.35), lineWidth: 1.5)
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel(L.t(sv: "Fortsätt redigera annonsen", nb: "Fortsett å redigere annonsen"))
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
        .frame(maxWidth: .infinity)
        .background(Color(.systemBackground))
    }
}
