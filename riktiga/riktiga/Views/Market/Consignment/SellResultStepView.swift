import SwiftUI

struct SellResultStepView: View {
    @ObservedObject var model: SellFlowModel
    @Binding var path: NavigationPath
    @EnvironmentObject var authViewModel: AuthViewModel

    @State private var isSubmitting = false
    @State private var submitError: String?
    @State private var showThankYou = false

    private var analysis: SellAnalysisResult {
        model.analysis ?? .empty
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if showThankYou {
                    thankYouBlock
                        .transition(.asymmetric(insertion: .opacity.combined(with: .move(edge: .trailing)), removal: .opacity))
                } else {
                    resultContent
                        .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .opacity))
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 40)
            .animation(.spring(response: 0.4, dampingFraction: 0.88), value: showThankYou)
        }
        .background(Color(.systemBackground))
        .navigationBarBackButtonHidden(showThankYou)
        .toolbar {
            if !showThankYou {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
                            if !path.isEmpty { path.removeLast() }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                            Text(L.t(sv: "Kategori", nb: "Kategori"))
                        }
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(Color.black)
                    }
                }
            }
        }
    }

    private var thankYouBlock: some View {
        VStack(alignment: .leading, spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 48))
                .foregroundStyle(Color.green.opacity(0.85))
            Text(L.t(sv: "Tack! Vi har fått din förfrågan.", nb: "Takk! Vi har mottatt forespørselen din."))
                .font(.system(size: 22, weight: .bold))
            Text(L.t(
                sv: "Vi återkommer när vi har granskat din vara.",
                nb: "Vi tar kontakt når vi har gjennomgått varen din."
            ))
            .font(.system(size: 15))
            .foregroundStyle(.secondary)

            Button {
                model.resetForNewListing()
                path = NavigationPath()
            } label: {
                Text(L.t(sv: "Sälj en till", nb: "Selg en til"))
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.black))
            }
            .padding(.top, 12)
        }
        .padding(.vertical, 24)
    }

    private var resultContent: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(L.t(sv: "Hjälp av Up&Down AI", nb: "Hjelp fra Up&Down AI"))
                .font(.system(size: 22, weight: .bold))

            Text(L.t(
                sv: "Vi har fyllt i utkast utifrån dina bilder och kategori. Du kan ändra märke och skick innan du skickar in.",
                nb: "Vi har fylt ut utkast ut fra bildene og kategorien. Du kan endre merke og stand før du sender inn."
            ))
            .font(.system(size: 15))
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)

            heroCard

            infoBanner

            Group {
                Text(L.t(sv: "Rubrik", nb: "Overskrift"))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)
                Text(analysis.title)
                    .font(.system(size: 17, weight: .semibold))

                Text(L.t(sv: "Beskrivning", nb: "Beskrivelse"))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)
                Text(analysis.description)
                    .font(.system(size: 15))

                Text(L.t(sv: "Identifierad produkt", nb: "Identifisert produkt"))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)
                Text(analysis.productName)
                    .font(.system(size: 16, weight: .medium))
            }

            VStack(alignment: .leading, spacing: 8) {
                Text(L.t(sv: "Märke", nb: "Merke"))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)
                TextField(L.t(sv: "Varumärke", nb: "Varemerke"), text: $model.userBrand)
                    .textFieldStyle(.roundedBorder)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text(L.t(sv: "Skick", nb: "Stand"))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)
                TextField(L.t(sv: "Skick", nb: "Stand"), text: $model.userCondition)
                    .textFieldStyle(.roundedBorder)
            }

            if let submitError {
                Text(submitError)
                    .font(.system(size: 14))
                    .foregroundStyle(.red)
            }

            Button {
                Task { await submit() }
            } label: {
                HStack {
                    if isSubmitting {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Text(L.t(sv: "Skicka in till granskning", nb: "Send til gjennomgang"))
                            .font(.system(size: 17, weight: .bold))
                    }
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.black)
                )
            }
            .disabled(isSubmitting || authViewModel.currentUser?.id == nil)
            .padding(.top, 8)
        }
    }

    private var heroCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L.t(sv: "Vi säljer det åt dig. Luta dig tillbaka.", nb: "Vi selger det for deg. Len deg tilbake."))
                .font(.system(size: 18, weight: .bold))
                .fixedSize(horizontal: false, vertical: true)

            (
                Text(L.t(sv: "Du får ca ", nb: "Du får ca "))
                    .font(.system(size: 16, weight: .medium))
                + Text(analysis.sellerPayoutRange)
                    .font(.system(size: 16, weight: .bold))
                + Text(" " + L.t(sv: "efter försäljning", nb: "etter salg"))
                    .font(.system(size: 16, weight: .medium))
            )
            .foregroundStyle(Color.primary.opacity(0.92))

            Text(L.t(sv: "Uppskattat försäljningspris:", nb: "Estimert salgspris:") + " \(analysis.priceRangeLabel)")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
    }

    private var infoBanner: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "info.circle.fill")
                .foregroundStyle(Color.black)
            Text(L.t(
                sv: "Detta är ett utkast. Efter vår granskning kan pris och publicering justeras.",
                nb: "Dette er et utkast. Etter vår gjennomgang kan pris og publisering justeres."
            ))
            .font(.system(size: 13))
            .foregroundStyle(.primary.opacity(0.85))
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(.systemGray6))
        )
    }

    private func submit() async {
        guard let uid = authViewModel.currentUser?.id,
              let a = model.analysis else { return }
        await MainActor.run {
            isSubmitting = true
            submitError = nil
        }
        do {
            try await ConsignmentSubmissionService.shared.submit(
                userId: uid,
                images: model.images,
                category: model.selectedCategory,
                analysis: a,
                userBrand: model.userBrand,
                userCondition: model.userCondition
            )
            await MainActor.run {
                isSubmitting = false
                model.didSubmit = true
                withAnimation(.spring(response: 0.42, dampingFraction: 0.88)) {
                    showThankYou = true
                }
            }
        } catch {
            await MainActor.run {
                isSubmitting = false
                submitError = error.localizedDescription
            }
        }
    }
}
