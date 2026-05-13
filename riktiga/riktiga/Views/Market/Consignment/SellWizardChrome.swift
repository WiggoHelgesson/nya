import SwiftUI

/// Delad layout och mått för annons-wizard (foto, kategori, m.m.).
enum SellWizardChrome {
    static let horizontalPadding: CGFloat = 18
    static let cardCornerRadius: CGFloat = 14
    static let cardPadding: CGFloat = 14
    static let primaryButtonCornerRadius: CGFloat = 14
    static let primaryButtonVerticalPadding: CGFloat = 16
    static let headerHorizontalPadding: CGFloat = 12
    static let headerTopPadding: CGFloat = 8
    static let headerBottomPadding: CGFloat = 10

    static let headerTitleFont = Font.system(size: 17, weight: .semibold)
    static let wizardMainHeadlineFont = Font.system(size: 26, weight: .bold)

    static let photoSlotHeight: CGFloat = 148
    static let photoSlotSpacing: CGFloat = 10
    static let photoSlotCornerRadius: CGFloat = 12
    static let photoStrokeOpacity: CGFloat = 0.15

    /// AI-toggle accent (lila, primärknapp förblir svart).
    static let aiToggleTint = Color(red: 0.58, green: 0.34, blue: 0.92)

    static let bottomBarFill = Color(.systemBackground)
}

/// Gemensam wizard-header: bakåt + centrerad titel + divider.
struct SellWizardNavigationBar: View {
    let title: String
    let onBack: () -> Void

    var body: some View {
        HStack {
            Button {
                onBack()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.primary)
                    .frame(width: 36, height: 36)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text(L.t(sv: "Tillbaka", nb: "Tilbake")))

            Spacer()

            Text(title)
                .font(SellWizardChrome.headerTitleFont)

            Spacer()

            Color.clear.frame(width: 36, height: 36)
        }
        .padding(.horizontal, SellWizardChrome.headerHorizontalPadding)
        .padding(.top, SellWizardChrome.headerTopPadding)
        .padding(.bottom, SellWizardChrome.headerBottomPadding)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.black.opacity(0.08))
                .frame(height: 0.5)
        }
    }
}
