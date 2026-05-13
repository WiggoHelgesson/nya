import PhotosUI
import SwiftUI

/// Steg 1 i annons-wizard: endast bilder (max 7), svart primärknapp, lila AI-toggle.
struct SellPhotoUploadStepView: View {
    @ObservedObject var model: SellFlowModel
    var onCancel: () -> Void
    var onContinue: () -> Void

    @State private var pickerItems: [PhotosPickerItem] = []
    @State private var isLoadingPhotos = false
    @State private var showExamplesSheet = false

    private let maxPhotos = 7
    private let accent = Color.black

    private let slotRows: [[Int]] = [[0, 1, 2], [3, 4, 5], [6]]

    var body: some View {
        VStack(spacing: 0) {
            SellWizardNavigationBar(
                title: L.t(sv: "Ladda upp annons", nb: "Last opp annonse"),
                onBack: onCancel
            )

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text(L.t(sv: "Vad vill du sälja?", nb: "Hva vil du selge?"))
                        .font(SellWizardChrome.wizardMainHeadlineFont)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 12)
                        .padding(.bottom, 4)

                    infoCard

                    HStack(spacing: 6) {
                        Circle()
                            .fill(Color.red.opacity(0.85))
                            .frame(width: 6, height: 6)
                        Text(L.t(sv: "Lägg till bilder", nb: "Legg til bilder"))
                            .font(.system(size: 15, weight: .semibold))
                        Text(L.t(sv: "max \(maxPhotos)", nb: "maks \(maxPhotos)"))
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                    }

                    photoSlotRows

                    aiToggleCard

                    if isLoadingPhotos {
                        HStack(spacing: 8) {
                            ProgressView().controlSize(.small)
                            Text(L.t(sv: "Laddar bilder…", nb: "Laster bilder …"))
                                .font(.system(size: 13))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(.horizontal, SellWizardChrome.horizontalPadding)
                .padding(.bottom, 24)
            }

            continueButton
                .padding(.horizontal, SellWizardChrome.horizontalPadding)
                .padding(.top, 10)
                .padding(.bottom, 12)
                .background(SellWizardChrome.bottomBarFill.shadow(color: .black.opacity(0.06), radius: 8, y: -2))
        }
        .background(Color(.systemBackground).ignoresSafeArea())
        .onChange(of: pickerItems) { _, items in
            Task { await loadPickedPhotos(items: items) }
        }
        .sheet(isPresented: $showExamplesSheet) {
            SellPhotoExamplesSheet(onDismiss: { showExamplesSheet = false })
        }
    }

    private var infoCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L.t(sv: "Börja med att ladda upp bilder", nb: "Begynn med å laste opp bilder"))
                .font(.system(size: 15, weight: .semibold))

            infoCardBody
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(SellWizardChrome.cardPadding)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: SellWizardChrome.cardCornerRadius, style: .continuous))
    }

    private var infoCardBody: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .firstTextBaseline, spacing: 0) {
                Text(L.t(
                    sv: "Välj tydliga bilder som visar framsida, baksida, etikett och detaljer. Här kan du se ",
                    nb: "Velg tydelige bilder som viser forside, bakside, etikett og detaljer. Her kan du se "
                ))
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
                examplesLinkButton
                Text(L.t(sv: ".", nb: "."))
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(L.t(
                    sv: "Välj tydliga bilder som visar framsida, baksida, etikett och detaljer.",
                    nb: "Velg tydelige bilder som viser forside, bakside, etikett og detaljer."
                ))
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
                Button {
                    showExamplesSheet = true
                } label: {
                    Text(L.t(sv: "Se exempelbilder", nb: "Se eksempelbilder"))
                        .font(.system(size: 14, weight: .medium))
                        .underline()
                        .foregroundStyle(.primary)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var examplesLinkButton: some View {
        Button {
            showExamplesSheet = true
        } label: {
            Text(L.t(sv: "exempel", nb: "eksempler"))
                .font(.system(size: 14))
                .underline()
                .foregroundStyle(.primary)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(L.t(sv: "Visa exempelbilder", nb: "Vis eksempelbilder"))
    }

    private var aiToggleCard: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: "sparkles")
                .font(.system(size: 20))
                .foregroundStyle(SellWizardChrome.aiToggleTint)
            VStack(alignment: .leading, spacing: 4) {
                Text(L.t(sv: "Hjälp mig beskriva min vara", nb: "Hjelp meg å beskrive varen"))
                    .font(.system(size: 15, weight: .semibold))
                Text(L.t(
                    sv: "Låt vår AI fylla i annonsbeskrivningen åt dig – smidigare blir det inte!",
                    nb: "La AI-en vår fylle inn annonsebeskrivelsen for deg – enklere blir det ikke!"
                ))
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            Toggle("", isOn: $model.useAiGeneratedCopy)
                .labelsHidden()
                .tint(SellWizardChrome.aiToggleTint)
        }
        .padding(SellWizardChrome.cardPadding)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: SellWizardChrome.cardCornerRadius, style: .continuous))
    }

    private var photoSlotRows: some View {
        GeometryReader { geo in
            let spacing = SellWizardChrome.photoSlotSpacing
            let slotWidth = max(0, (geo.size.width - spacing * 2) / 3)
            let slotH = SellWizardChrome.photoSlotHeight

            VStack(spacing: spacing) {
                ForEach(slotRows.indices, id: \.self) { rowIdx in
                    let indices = slotRows[rowIdx]
                    HStack(spacing: spacing) {
                        ForEach(indices, id: \.self) { index in
                            slotView(for: index, slotWidth: slotWidth, slotHeight: slotH)
                        }
                        ForEach(0..<(3 - indices.count), id: \.self) { _ in
                            Color.clear
                                .frame(width: slotWidth, height: slotH)
                        }
                    }
                }
            }
        }
        .frame(height: CGFloat(slotRows.count) * SellWizardChrome.photoSlotHeight
            + CGFloat(slotRows.count - 1) * SellWizardChrome.photoSlotSpacing)
    }

    @ViewBuilder
    private func slotView(for index: Int, slotWidth: CGFloat, slotHeight: CGFloat) -> some View {
        Group {
            if index < model.images.count {
                photoCell(image: model.images[index], index: index, slotWidth: slotWidth, slotHeight: slotHeight)
            } else {
                addSlotCell(slotWidth: slotWidth, slotHeight: slotHeight)
            }
        }
        .frame(width: slotWidth, height: slotHeight)
    }

    private func photoCell(image: UIImage, index: Int, slotWidth: CGFloat, slotHeight: CGFloat) -> some View {
        ZStack(alignment: .topTrailing) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: slotWidth, height: slotHeight)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: SellWizardChrome.photoSlotCornerRadius, style: .continuous))

            Button {
                if index < model.images.count {
                    model.images.remove(at: index)
                }
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(.white, Color.black.opacity(0.55))
                    .padding(6)
            }
            .buttonStyle(.plain)
            .frame(width: slotWidth, height: slotHeight, alignment: .topTrailing)
        }
    }

    private func addSlotCell(slotWidth: CGFloat, slotHeight: CGFloat) -> some View {
        let remaining = max(0, maxPhotos - model.images.count)
        return PhotosPicker(
            selection: $pickerItems,
            maxSelectionCount: remaining > 0 ? remaining : 1,
            matching: .images
        ) {
            VStack(spacing: 8) {
                Image(systemName: "plus")
                    .font(.system(size: 26, weight: .medium))
                    .foregroundStyle(accent)
                Text(L.t(sv: "Lägg till", nb: "Legg til"))
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .frame(width: slotWidth, height: slotHeight)
            .background(Color(.systemBackground))
            .overlay(
                RoundedRectangle(cornerRadius: SellWizardChrome.photoSlotCornerRadius, style: .continuous)
                    .stroke(Color.primary.opacity(SellWizardChrome.photoStrokeOpacity), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: SellWizardChrome.photoSlotCornerRadius, style: .continuous))
        }
        .disabled(remaining <= 0)
        .opacity(remaining <= 0 ? 0.35 : 1)
    }

    private var continueButton: some View {
        Button {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            onContinue()
        } label: {
            Text(L.t(sv: "Fortsätt", nb: "Fortsett"))
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, SellWizardChrome.primaryButtonVerticalPadding)
                .background(model.images.isEmpty ? Color.gray.opacity(0.35) : accent)
                .clipShape(RoundedRectangle(cornerRadius: SellWizardChrome.primaryButtonCornerRadius, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(model.images.isEmpty)
    }

    private func loadPickedPhotos(items: [PhotosPickerItem]) async {
        guard !items.isEmpty else { return }
        await MainActor.run { isLoadingPhotos = true }
        var loaded: [UIImage] = []
        for item in items {
            if let data = try? await item.loadTransferable(type: Data.self),
               let image = UIImage(data: data) {
                loaded.append(image)
            }
        }
        await MainActor.run {
            let cap = max(0, maxPhotos - model.images.count)
            model.images.append(contentsOf: loaded.prefix(cap))
            pickerItems = []
            isLoadingPhotos = false
        }
    }
}

// MARK: - Exempel-sheet

private struct SellPhotoExamplesSheet: View {
    var onDismiss: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    bulletRow(
                        icon: "camera.viewfinder",
                        text: L.t(
                            sv: "Helhet – visa hela produkten i en bild.",
                            nb: "Helhet – vis hele produktet på ett bilde."
                        )
                    )
                    bulletRow(
                        icon: "text.viewfinder",
                        text: L.t(
                            sv: "Etikett och varumärke – närbild om det syns.",
                            nb: "Etikett og merke – nærbilde om det er synlig."
                        )
                    )
                    bulletRow(
                        icon: "arrow.left.and.right",
                        text: L.t(
                            sv: "Fram- och baksida vid kläder och skor.",
                            nb: "Fram- og bakside for klær og sko."
                        )
                    )
                    bulletRow(
                        icon: "sparkles",
                        text: L.t(
                            sv: "Bra ljus och skärpa – undvik suddiga mobilbilder.",
                            nb: "Godt lys og skarphet – unngå uklare mobilbilder."
                        )
                    )

                    HStack(spacing: 16) {
                        tipIcon("tshirt.fill")
                        tipIcon("shoe.fill")
                        tipIcon("bicycle")
                        tipIcon("figure.run")
                    }
                    .font(.system(size: 28))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 8)
                }
                .padding(20)
            }
            .navigationTitle(L.t(sv: "Exempel", nb: "Eksempler"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(L.t(sv: "Klar", nb: "Ferdig")) {
                        onDismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private func bulletRow(icon: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundStyle(.primary)
                .frame(width: 28, alignment: .center)
            Text(text)
                .font(.system(size: 15))
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func tipIcon(_ name: String) -> some View {
        Image(systemName: name)
            .symbolRenderingMode(.hierarchical)
    }
}
