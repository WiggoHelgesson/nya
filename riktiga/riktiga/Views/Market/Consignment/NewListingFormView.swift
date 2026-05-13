import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

struct NewListingFormView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @ObservedObject var model: SellFlowModel
    @Binding var path: NavigationPath
    /// Användarstyrd avslut (t.ex. X) — förälder kan visa bekräftelse.
    let onClose: () -> Void
    /// Avsluta utan bekräftelsedialog (t.ex. lyckad uppdatering vid redigering).
    var onAbandonWithoutConfirmation: (() -> Void)? = nil
    /// Wizard sista steg döljer full foto-sektion och visar kompakt strip.
    var showPhotosSection: Bool = true
    /// Max antal bilder (wizard: 7, klassisk: 20).
    var maxPhotos: Int = 20
    /// Rubrik/styling för sista steget i annons-wizard.
    var wizardDetailsMode: Bool = false

    @State private var pickerItems: [PhotosPickerItem] = []
    @State private var isLoadingPhotos = false

    @State private var showValidation = false
    @State private var isSubmitting = false
    @State private var submissionError: String?

    @State private var priceText: String = ""

    enum FormField: Hashable {
        case title, description, brand, price
    }

    @FocusState private var focusedField: FormField?

    private let formTeal = Color.black

    private func dismissKeyboard() {
        focusedField = nil
    }

    var body: some View {
        VStack(spacing: 0) {
            headerBar
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    if !showPhotosSection {
                        compactPhotosStrip
                    }
                    if showPhotosSection {
                        photosSection
                    }
                    titleField
                    descriptionField
                    categoryRow
                    if !model.selectedCategory.isEmpty {
                        brandField
                        conditionRow
                        priceField
                        packageSizeRow
                        pickupAddressRow
                    }
                    submissionError.map { err in
                        Text(err)
                            .font(.system(size: 13))
                            .foregroundStyle(.red)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    submitButton
                        .padding(.top, 8)
                        .padding(.bottom, 40)
                }
                .padding(.horizontal, 18)
                .padding(.top, 16)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .background(
            Color(.systemBackground)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture { dismissKeyboard() }
        )
        .simultaneousGesture(
            TapGesture().onEnded { dismissKeyboard() }
        )
        .navigationBarHidden(true)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button(L.t(sv: "Klar", nb: "Ferdig")) {
                    dismissKeyboard()
                }
                .fontWeight(.semibold)
            }
        }
        .onChange(of: pickerItems) { _, items in
            Task { await loadPickedPhotos(items: items) }
        }
        .onChange(of: priceText) { _, newValue in
            let digits = newValue.filter { $0.isNumber }
            if digits != newValue {
                priceText = digits
            }
            model.priceSEK = Int(digits)
        }
        .onChange(of: model.listingDescription) { _, newValue in
            guard wizardDetailsMode, newValue.count > 500 else { return }
            model.listingDescription = String(newValue.prefix(500))
        }
        .onAppear {
            if priceText.isEmpty, let price = model.priceSEK, price > 0 {
                priceText = String(price)
            }
        }
        .task {
            await refreshPickupAddressFromServer()
        }
    }

    private func refreshPickupAddressFromServer() async {
        do {
            if let existing = try await ShipmondoShippingService.shared.fetchSellerPickupAddress() {
                await MainActor.run {
                    model.pickupAddress = existing
                    model.hasSavedPickupAddress = true
                }
            }
        } catch {
            // Leave hasSavedPickupAddress as-is (may still be set from SellFlowView.task).
        }
    }

    // MARK: - Header

    private var headerTitle: String {
        if wizardDetailsMode {
            return L.t(sv: "Ladda upp annons", nb: "Last opp annonse")
        }
        return model.isEditing
            ? L.t(sv: "Redigera", nb: "Rediger")
            : L.t(sv: "Sälj en artikel", nb: "Selg en vare")
    }

    private var headerBar: some View {
        HStack {
            Button {
                onClose()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.primary)
                    .frame(width: 36, height: 36)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Spacer()

            Text(headerTitle)
            .font(.system(size: 17, weight: .semibold))

            Spacer()

            Color.clear.frame(width: 36, height: 36)
        }
        .padding(.horizontal, 12)
        .padding(.top, 8)
        .padding(.bottom, 10)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.black.opacity(0.08))
                .frame(height: 0.5)
        }
    }

    // MARK: - Photos

    private var compactPhotosStrip: some View {
        VStack(alignment: .leading, spacing: 10) {
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
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(Array(model.images.enumerated()), id: \.offset) { index, image in
                        photoTile(image: image, index: index, tileSide: 88)
                    }
                }
                .padding(.vertical, 2)
            }
            .frame(height: 96)
            HStack {
                Text(L.t(sv: "Håll och dra för att ändra ordningen", nb: "Hold og dra for å endre rekkefølgen"))
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                Spacer()
                PhotosPicker(
                    selection: $pickerItems,
                    maxSelectionCount: max(1, maxPhotos - model.images.count),
                    matching: .images
                ) {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                        Text(L.t(sv: "Lägg till", nb: "Legg til"))
                    }
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(formTeal)
                }
                .disabled(model.images.count >= maxPhotos)
                .opacity(model.images.count >= maxPhotos ? 0.4 : 1)
            }
            if isLoadingPhotos {
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small)
                    Text(L.t(sv: "Laddar bilder…", nb: "Laster bilder…"))
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var photosSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            if model.images.isEmpty {
                PhotosPicker(
                    selection: $pickerItems,
                    maxSelectionCount: maxPhotos,
                    matching: .images
                ) {
                    VStack(spacing: 10) {
                        Image(systemName: "photo.on.rectangle.angled")
                            .font(.system(size: 32))
                            .foregroundStyle(formTeal)
                        Text(L.t(sv: "+ Ladda upp foton", nb: "+ Last opp bilder"))
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(formTeal)
                        Text(L.t(sv: "Välj upp till \(maxPhotos) bilder", nb: "Velg opptil \(maxPhotos) bilder"))
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 160)
                    .background(Color(.secondarySystemBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(formTeal.opacity(0.5), style: StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                if showValidation {
                    inlineError(text: L.t(sv: "Lägg till minst en bild", nb: "Legg til minst ett bilde"))
                }
            } else {
                photoSlider
                HStack {
                    Text(L.t(
                        sv: "Håll och dra för att ändra ordningen",
                        nb: "Hold og dra for å endre rekkefølgen"
                    ))
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    Spacer()
                    PhotosPicker(
                        selection: $pickerItems,
                        maxSelectionCount: max(1, maxPhotos - model.images.count),
                        matching: .images
                    ) {
                        HStack(spacing: 4) {
                            Image(systemName: "plus")
                            Text(L.t(sv: "Lägg till", nb: "Legg til"))
                        }
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(formTeal)
                    }
                    .disabled(model.images.count >= maxPhotos)
                    .opacity(model.images.count >= maxPhotos ? 0.4 : 1)
                }
            }
            if isLoadingPhotos {
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small)
                    Text(L.t(sv: "Laddar bilder…", nb: "Laster bilder…"))
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var photoSlider: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(Array(model.images.enumerated()), id: \.offset) { index, image in
                    photoTile(image: image, index: index, tileSide: 120)
                }
            }
            .padding(.vertical, 2)
        }
        .frame(height: 130)
    }

    private func photoTile(image: UIImage, index: Int, tileSide: CGFloat = 120) -> some View {
        let dragPreview = tileSide * 0.75
        return ZStack(alignment: .topTrailing) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: tileSide, height: tileSide)
                .clipShape(RoundedRectangle(cornerRadius: 10))

            if index == 0 {
                Text(L.t(sv: "Omslag", nb: "Omslag"))
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(formTeal)
                    .clipShape(Capsule())
                    .padding(6)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            Button {
                let haptic = UIImpactFeedbackGenerator(style: .light)
                haptic.impactOccurred()
                if index >= 0 && index < model.images.count {
                    model.images.remove(at: index)
                }
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: min(22, tileSide * 0.2)))
                    .foregroundStyle(.white, Color.black.opacity(0.75))
                    .padding(4)
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .frame(width: tileSide, height: tileSide)
        .draggable(PhotoDragItem(index: index)) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: dragPreview, height: dragPreview)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .opacity(0.85)
        }
        .dropDestination(for: PhotoDragItem.self) { items, _ in
            guard let src = items.first?.index else { return false }
            let dst = index
            guard src != dst, src >= 0, src < model.images.count, dst >= 0, dst < model.images.count else {
                return false
            }
            let moving = model.images.remove(at: src)
            let insertAt = dst > src ? dst : dst
            model.images.insert(moving, at: min(insertAt, model.images.count))
            return true
        }
    }

    // MARK: - Text fields

    private var titleField: some View {
        VStack(alignment: .leading, spacing: 6) {
            TextField(
                L.t(sv: "Berätta vad du säljer", nb: "Fortell hva du selger"),
                text: $model.title
            )
            .focused($focusedField, equals: .title)
            .submitLabel(.next)
            .onSubmit { focusedField = .description }
            .font(.system(size: 16))
            .padding(.horizontal, 14)
            .padding(.vertical, 14)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            if showValidation && model.title.trimmed.isEmpty {
                inlineError(text: L.t(sv: "Fyll i titel", nb: "Fyll inn tittel"))
            }
        }
    }

    private var descriptionField: some View {
        VStack(alignment: .leading, spacing: 6) {
            ZStack(alignment: .topLeading) {
                if model.listingDescription.isEmpty {
                    Text(L.t(sv: "Berätta mer…", nb: "Fortell mer…"))
                        .font(.system(size: 16))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 18)
                        .padding(.top, 20)
                }
                TextEditor(text: $model.listingDescription)
                    .focused($focusedField, equals: .description)
                    .font(.system(size: 16))
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 120)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 12)
            }
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            if wizardDetailsMode {
                Text("\(model.listingDescription.count)/500")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            if showValidation && model.listingDescription.trimmed.isEmpty {
                inlineError(text: L.t(sv: "Skriv en beskrivning", nb: "Skriv en beskrivelse"))
            }
        }
    }

    // MARK: - Menu rows

    private var categoryRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            menuRow(
                title: L.t(sv: "Kategori", nb: "Kategori"),
                value: model.selectedCategory.isEmpty ? nil : model.selectedCategory,
                placeholder: L.t(sv: "Välj kategori", nb: "Velg kategori"),
                systemIcon: "list.bullet"
            ) {
                path.append(SellRoute.category)
            }
            if showValidation && model.selectedCategory.isEmpty {
                inlineError(text: L.t(sv: "Välj kategori", nb: "Velg kategori"))
            }
        }
    }

    private var brandField: some View {
        VStack(alignment: .leading, spacing: 6) {
            inlineTextRow(
                title: L.t(sv: "Varumärke", nb: "Varemerke"),
                text: $model.brand,
                placeholder: L.t(sv: "T.ex. Nike", nb: "F.eks. Nike"),
                focus: .brand
            )
            if showValidation && model.brand.trimmed.isEmpty {
                inlineError(text: L.t(sv: "Fyll i varumärke för att fortsätta", nb: "Fyll inn varemerke for å fortsette"))
            }
        }
    }

    private var conditionRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            menuRow(
                title: L.t(sv: "Skick", nb: "Stand"),
                value: conditionDisplay,
                placeholder: L.t(sv: "Välj skick", nb: "Velg stand"),
                systemIcon: "sparkles"
            ) {
                path.append(SellRoute.condition)
            }
            if showValidation && model.condition.isEmpty {
                inlineError(text: L.t(sv: "Välj skick", nb: "Velg stand"))
            }
        }
    }

    private var priceField: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 12) {
                Image(systemName: "tag")
                    .foregroundStyle(.primary)
                    .frame(width: 24)
                Text(L.t(sv: "Pris", nb: "Pris"))
                    .font(.system(size: 16))
                Spacer()
                TextField("0", text: $priceText)
                    .focused($focusedField, equals: .price)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: 120)
                Text("kr")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 14)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 10))

            if showValidation && (model.priceSEK ?? 0) <= 0 {
                inlineError(text: L.t(sv: "Pris måste vara större än 0", nb: "Pris må være større enn 0"))
            }
        }
    }

    private var packageSizeRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            menuRow(
                title: L.t(sv: "Paketstorlek", nb: "Pakkestørrelse"),
                value: packageSizeDisplay,
                placeholder: L.t(sv: "Välj paketstorlek", nb: "Velg pakkestørrelse"),
                systemIcon: "shippingbox"
            ) {
                path.append(SellRoute.packageSize)
            }
            if showValidation && model.packageSize.isEmpty {
                inlineError(text: L.t(sv: "Välj paketstorlek", nb: "Velg pakkestørrelse"))
            }
        }
    }

    private var pickupAddressRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            menuRow(
                title: L.t(sv: "Upphämtningsadress", nb: "Henteadresse"),
                value: pickupAddressSummary,
                placeholder: L.t(sv: "Lägg till adress", nb: "Legg til adresse"),
                systemIcon: "mappin.and.ellipse"
            ) {
                path.append(SellRoute.pickupAddress)
            }
            if showValidation && !model.hasSavedPickupAddress {
                inlineError(text: L.t(
                    sv: "Lägg till var paketet hämtas (krävs för automatisk frakt)",
                    nb: "Legg til hvor pakken hentes (kreves for automatisk frakt)"
                ))
            }
        }
    }

    private var pickupAddressSummary: String? {
        guard model.hasSavedPickupAddress else { return nil }
        if let line = model.pickupAddress?.street, !line.isEmpty {
            return line
        }
        return L.t(sv: "Sparad", nb: "Lagret")
    }

    // MARK: - Submit

    private var submitButton: some View {
        Button {
            handleSubmit()
        } label: {
            HStack(spacing: 10) {
                if isSubmitting {
                    ProgressView().progressViewStyle(.circular).tint(.white)
                }
                Text(
                    model.isEditing
                        ? L.t(sv: "Spara ändringar", nb: "Lagre endringer")
                        : L.t(sv: "Ladda upp", nb: "Last opp")
                )
                .font(.system(size: 17, weight: .bold))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(model.isReadyToSubmit ? formTeal : Color.gray.opacity(0.35))
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
        .disabled(isSubmitting)
    }

    // MARK: - Reusable chrome

    @ViewBuilder
    private func menuRow(
        title: String,
        value: String?,
        placeholder: String,
        systemIcon: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: systemIcon)
                    .foregroundStyle(.primary)
                    .frame(width: 24)
                Text(title)
                    .font(.system(size: 16))
                    .foregroundStyle(.primary)
                Spacer()
                Text(value ?? placeholder)
                    .font(.system(size: 14))
                    .foregroundStyle(value == nil ? .secondary : .primary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 14)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func inlineTextRow(
        title: String,
        text: Binding<String>,
        placeholder: String,
        focus: FormField
    ) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "pencil")
                .foregroundStyle(.primary)
                .frame(width: 24)
            Text(title)
                .font(.system(size: 16))
            Spacer()
            TextField(placeholder, text: text)
                .focused($focusedField, equals: focus)
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: 200)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func inlineError(text: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "exclamationmark.circle.fill")
                .font(.system(size: 12))
            Text(text)
                .font(.system(size: 12, weight: .medium))
        }
        .foregroundStyle(.red)
        .padding(.horizontal, 4)
    }

    // MARK: - Helpers

    private var conditionDisplay: String? {
        guard !model.condition.isEmpty,
              let condition = SellCondition(rawValue: model.condition)
        else { return nil }
        return condition.title
    }

    private var packageSizeDisplay: String? {
        guard !model.packageSize.isEmpty,
              let size = PackageSize(rawValue: model.packageSize)
        else { return nil }
        return size.title
    }

    // MARK: - Actions

    private func handleSubmit() {
        submissionError = nil
        guard model.isReadyToSubmit else {
            showValidation = true
            let haptic = UINotificationFeedbackGenerator()
            haptic.notificationOccurred(.warning)
            return
        }
        guard let userId = authViewModel.currentUser?.id else {
            submissionError = L.t(sv: "Du måste vara inloggad.", nb: "Du må være innlogget.")
            return
        }
        if let editingId = model.editingId {
            submitEdit(userId: userId, rowId: editingId)
        } else {
            submitNew(userId: userId)
        }
    }

    private func submitNew(userId: String) {
        isSubmitting = true
        Task {
            defer { isSubmitting = false }
            do {
                _ = try await ConsignmentSubmissionService.shared.submit(userId: userId, model: model)
                await MainActor.run {
                    model.didSubmit = true
                    path.append(SellRoute.success)
                }
            } catch {
                await MainActor.run {
                    submissionError = error.localizedDescription
                }
            }
        }
    }

    private func submitEdit(userId: String, rowId: UUID) {
        isSubmitting = true
        let previousUrls = model.existingImageUrls
        Task {
            defer { isSubmitting = false }
            do {
                try await ConsignmentSubmissionService.shared.update(
                    userId: userId,
                    rowId: rowId,
                    model: model,
                    previousImageUrls: previousUrls
                )
                await MainActor.run {
                    model.didSubmit = true
                    NotificationCenter.default.post(
                        name: NSNotification.Name("NavigateToMyListings"),
                        object: nil
                    )
                    if let abandon = onAbandonWithoutConfirmation {
                        abandon()
                    } else {
                        onClose()
                    }
                }
            } catch {
                await MainActor.run {
                    submissionError = error.localizedDescription
                }
            }
        }
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
            let available = max(0, maxPhotos - model.images.count)
            model.images.append(contentsOf: loaded.prefix(available))
            pickerItems = []
            isLoadingPhotos = false
        }
    }
}

// MARK: - Draggable payload

struct PhotoDragItem: Codable, Transferable {
    let index: Int

    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .photoDragItem)
    }
}

extension UTType {
    static let photoDragItem = UTType(exportedAs: "com.riktiga.listing.photo-drag-item")
}

private extension String {
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
}
