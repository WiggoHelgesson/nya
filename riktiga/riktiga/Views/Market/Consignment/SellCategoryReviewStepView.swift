import SwiftUI

/// Steg: visa AI-kategori och låt användaren redigera via befintlig picker-stack.
struct SellCategoryReviewStepView: View {
    @ObservedObject var model: SellFlowModel
    @Binding var path: NavigationPath
    var categoryAIError: String?
    var onCancel: () -> Void
    var onContinue: () -> Void

    private let accent = Color.black

    var body: some View {
        VStack(spacing: 0) {
            SellWizardNavigationBar(
                title: L.t(sv: "Ladda upp annons", nb: "Last opp annonse"),
                onBack: onCancel
            )

            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    Text(L.t(sv: "Kategori", nb: "Kategori"))
                        .font(SellWizardChrome.wizardMainHeadlineFont)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 8)

                    if let categoryAIError, !categoryAIError.isEmpty {
                        Text(categoryAIError)
                            .font(.system(size: 13))
                            .foregroundStyle(.orange)
                            .padding(SellWizardChrome.cardPadding)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.orange.opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: SellWizardChrome.cardCornerRadius))
                    }

                    categoryPreviewCard

                    Text(L.t(
                        sv: "Du kan ändra kategori innan du går vidare.",
                        nb: "Du kan endre kategori før du går videre."
                    ))
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                }
                .padding(.horizontal, SellWizardChrome.horizontalPadding)
                .padding(.top, 12)
                .padding(.bottom, 24)
            }

            continueBar
                .padding(.horizontal, SellWizardChrome.horizontalPadding)
                .padding(.top, 10)
                .padding(.bottom, 12)
                .background(SellWizardChrome.bottomBarFill.shadow(color: .black.opacity(0.06), radius: 8, y: -2))
        }
        .background(Color(.systemBackground).ignoresSafeArea())
    }

    private var canContinue: Bool {
        !model.selectedCategory.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var continueBar: some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            onContinue()
        } label: {
            Text(L.t(sv: "Fortsätt", nb: "Fortsett"))
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, SellWizardChrome.primaryButtonVerticalPadding)
                .background(canContinue ? accent : Color.gray.opacity(0.35))
                .clipShape(RoundedRectangle(cornerRadius: SellWizardChrome.primaryButtonCornerRadius, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(!canContinue)
    }

    private var categoryPreviewCard: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text(displayCategoryLines.primary)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.primary)
                if let second = displayCategoryLines.secondary {
                    Text(second)
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 8)
            Button {
                path.append(SellRoute.category)
            } label: {
                Text(L.t(sv: "Redigera", nb: "Rediger"))
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(accent)
            }
            .buttonStyle(.plain)
        }
        .padding(SellWizardChrome.cardPadding)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: SellWizardChrome.cardCornerRadius, style: .continuous))
    }

    private var displayCategoryLines: (primary: String, secondary: String?) {
        let raw = model.selectedCategory.trimmingCharacters(in: .whitespacesAndNewlines)
        if raw.isEmpty {
            return (L.t(sv: "Ingen kategori vald än", nb: "Ingen kategori valgt ennå"), nil)
        }
        let parts = raw.components(separatedBy: "/").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        if parts.count >= 2 {
            return (parts[0], parts.dropFirst().joined(separator: " → "))
        }
        return (raw, nil)
    }
}
