import SwiftUI
import UniformTypeIdentifiers

struct ConsignmentSubmissionsAdminView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var rows: [ConsignmentSubmissionRow] = []
    @State private var filterPendingOnly = true
    @State private var errorText: String?
    @State private var selectedDetailId: UUID?
    @State private var editedPrice: String = ""
    @State private var editedNotes: String = ""
    @State private var isSaving = false

    @State private var showPdfImporter = false
    @State private var isUploadingLabel = false
    @State private var uploadError: String?
    @State private var editedCarrier: String = ""
    @State private var editedTracking: String = ""

    var body: some View {
        NavigationStack {
            List {
                Toggle(L.t(sv: "Endast väntande", nb: "Kun ventende"), isOn: $filterPendingOnly)
                    .onChange(of: filterPendingOnly) { _, _ in
                        Task { await load() }
                    }

                if let errorText {
                    Text(errorText)
                        .foregroundStyle(.red)
                }

                ForEach(rows, id: \.id) { row in
                    Button {
                        selectedDetailId = row.id
                        editedPrice = row.finalPriceRange ?? row.aiPayload.priceRangeLabel
                        editedNotes = row.adminNotes ?? ""
                        editedCarrier = row.shippingCarrier ?? ""
                        editedTracking = row.shippingTrackingNumber ?? ""
                        uploadError = nil
                    } label: {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(row.aiPayload.title.isEmpty ? row.aiPayload.productName : row.aiPayload.title)
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(.primary)
                            Text(row.category)
                                .font(.system(size: 13))
                                .foregroundStyle(.secondary)
                            Text(row.adminStatus)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(row.adminStatus == "pending" ? .orange : .secondary)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .navigationTitle(L.t(sv: "Inköp / AI-förslag", nb: "Innkjøp / AI-forslag"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L.t(sv: "Stäng", nb: "Lukk")) { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        Task { await load() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
            .task {
                await load()
            }
            .sheet(isPresented: Binding(
                get: { selectedDetailId != nil },
                set: { if !$0 { selectedDetailId = nil } }
            )) {
                if let id = selectedDetailId, let row = rows.first(where: { $0.id == id }) {
                    adminDetailSheet(row: row)
                }
            }
        }
    }

    @ViewBuilder
    private func adminDetailSheet(row: ConsignmentSubmissionRow) -> some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    TabView {
                        ForEach(row.imageUrls, id: \.self) { url in
                            AsyncImage(url: URL(string: url)) { phase in
                                switch phase {
                                case .success(let img):
                                    img.resizable().scaledToFit()
                                case .failure:
                                    Color.gray.opacity(0.2)
                                default:
                                    ProgressView()
                                }
                            }
                            .frame(maxHeight: 280)
                        }
                    }
                    .tabViewStyle(.page)
                    .frame(height: 300)

                    Group {
                        labeled(L.t(sv: "Kategori", nb: "Kategori"), row.category)
                        labeled(L.t(sv: "Användarens märke", nb: "Brukerens merke"), row.userBrand ?? "—")
                        labeled(L.t(sv: "Användarens skick", nb: "Brukerens stand"), row.userCondition ?? "—")
                        labeled(L.t(sv: "AI produkt", nb: "AI produkt"), row.aiPayload.productName)
                        labeled(L.t(sv: "AI skick", nb: "AI stand"), row.aiPayload.condition)
                        labeled(L.t(sv: "AI prisintervall", nb: "AI prisintervall"), row.aiPayload.priceRangeLabel)
                        labeled(L.t(sv: "AI utbetalning", nb: "AI utbetaling"), row.aiPayload.sellerPayoutRange)
                        Text(row.aiPayload.description)
                            .font(.system(size: 14))
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text(L.t(sv: "Slutprisintervall (admin)", nb: "Sluttprisintervall (admin)"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        TextField("1500–2200 kr", text: $editedPrice)
                            .textFieldStyle(.roundedBorder)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text(L.t(sv: "Anteckningar", nb: "Notater"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        TextField("", text: $editedNotes, axis: .vertical)
                            .textFieldStyle(.roundedBorder)
                            .lineLimit(3...6)
                    }

                    HStack(spacing: 12) {
                        Button(role: .destructive) {
                            Task { await save(row: row, status: "rejected") }
                        } label: {
                            Text(L.t(sv: "Avvisa", nb: "Avvis"))
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)

                        Button {
                            Task { await save(row: row, status: "accepted") }
                        } label: {
                            Text(L.t(sv: "Godkänn", nb: "Godkjenn"))
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.black)
                        .disabled(isSaving)
                    }

                    shippingSection(for: row)
                }
                .padding(20)
            }
            .navigationTitle(L.t(sv: "Granska", nb: "Gjennomgå"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L.t(sv: "Stäng", nb: "Lukk")) { selectedDetailId = nil }
                }
            }
            .fileImporter(
                isPresented: $showPdfImporter,
                allowedContentTypes: [.pdf],
                allowsMultipleSelection: false
            ) { result in
                handlePdfImport(result: result, row: row)
            }
        }
    }

    @ViewBuilder
    private func shippingSection(for row: ConsignmentSubmissionRow) -> some View {
        if row.adminStatus == "accepted" {
            let status = row.shippingStatus ?? ShippingStatus.none
            Divider().padding(.vertical, 4)

            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: "shippingbox.fill")
                        .foregroundColor(.blue)
                    Text(L.t(sv: "Frakt", nb: "Frakt"))
                        .font(.system(size: 16, weight: .semibold))
                    Spacer()
                    Text(shippingStatusLabel(status))
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.secondary)
                }

                if let addr = row.shippingAddress {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(addr.fullName).font(.system(size: 14, weight: .semibold))
                        Text(addr.street).font(.system(size: 13))
                        Text("\(addr.postalCode) \(addr.city)").font(.system(size: 13))
                        Text(addr.country).font(.system(size: 13)).foregroundColor(.secondary)
                        if !addr.phone.isEmpty {
                            Text("📞 \(addr.phone)").font(.system(size: 12)).foregroundColor(.secondary)
                        }
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                } else {
                    Text(L.t(
                        sv: "Säljaren har inte fyllt i avsändaradress än.",
                        nb: "Selgeren har ikke fylt inn avsenderadresse ennå."
                    ))
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                }

                if status == ShippingStatus.awaitingLabel || status == ShippingStatus.labelReady {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 8) {
                            TextField(L.t(sv: "Fraktbolag (valfritt)", nb: "Fraktselskap"), text: $editedCarrier)
                                .textFieldStyle(.roundedBorder)
                            TextField(L.t(sv: "Kollinr (valfritt)", nb: "Kollinr"), text: $editedTracking)
                                .textFieldStyle(.roundedBorder)
                        }

                        Button {
                            showPdfImporter = true
                        } label: {
                            HStack {
                                if isUploadingLabel {
                                    ProgressView().tint(.white)
                                } else {
                                    Image(systemName: status == ShippingStatus.labelReady
                                          ? "arrow.triangle.2.circlepath"
                                          : "arrow.up.doc.fill")
                                }
                                Text(status == ShippingStatus.labelReady
                                     ? L.t(sv: "Byt fraktsedel-PDF", nb: "Bytt fraktseddel-PDF")
                                     : L.t(sv: "Ladda upp fraktsedel (PDF)", nb: "Last opp fraktseddel (PDF)"))
                                    .font(.system(size: 14, weight: .semibold))
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.blue)
                        .disabled(row.shippingAddress == nil || isUploadingLabel)
                    }
                }

                if status == ShippingStatus.labelReady || status == ShippingStatus.shipped {
                    Button {
                        Task { await markReceived(row: row) }
                    } label: {
                        Text(L.t(sv: "Markera som mottaget", nb: "Marker som mottatt"))
                            .font(.system(size: 14, weight: .semibold))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(.green)
                }

                if status == ShippingStatus.received,
                   let receivedAt = row.receivedAt {
                    Text(L.t(sv: "Mottaget \(receivedAt)", nb: "Mottatt \(receivedAt)"))
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }

                if let uploadError {
                    Text(uploadError)
                        .font(.system(size: 12))
                        .foregroundColor(.red)
                }
            }
        }
    }

    private func shippingStatusLabel(_ status: String) -> String {
        switch status {
        case ShippingStatus.awaitingAddress: return L.t(sv: "Väntar adress", nb: "Venter adresse")
        case ShippingStatus.awaitingLabel: return L.t(sv: "Väntar fraktsedel", nb: "Venter fraktseddel")
        case ShippingStatus.labelReady: return L.t(sv: "Fraktsedel klar", nb: "Fraktseddel klar")
        case ShippingStatus.shipped: return L.t(sv: "Postad", nb: "Sendt")
        case ShippingStatus.received: return L.t(sv: "Mottaget", nb: "Mottatt")
        default: return "—"
        }
    }

    private func handlePdfImport(result: Result<[URL], Error>, row: ConsignmentSubmissionRow) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            Task { await uploadLabel(fromUrl: url, row: row) }
        case .failure(let error):
            uploadError = error.localizedDescription
        }
    }

    private func uploadLabel(fromUrl url: URL, row: ConsignmentSubmissionRow) async {
        await MainActor.run {
            isUploadingLabel = true
            uploadError = nil
        }
        let shouldStop = url.startAccessingSecurityScopedResource()
        defer { if shouldStop { url.stopAccessingSecurityScopedResource() } }
        do {
            let data = try Data(contentsOf: url)
            _ = try await ShippingLabelService.shared.uploadLabelPDF(
                submissionId: row.id,
                userId: row.userId,
                data: data,
                carrier: editedCarrier.isEmpty ? nil : editedCarrier,
                trackingNumber: editedTracking.isEmpty ? nil : editedTracking
            )
            try? await NotificationService.shared.createConsignmentLabelReadyNotification(
                userId: row.userId.uuidString,
                submissionId: row.id.uuidString
            )
            await MainActor.run {
                isUploadingLabel = false
            }
            await load()
        } catch {
            await MainActor.run {
                isUploadingLabel = false
                uploadError = error.localizedDescription
            }
        }
    }

    private func markReceived(row: ConsignmentSubmissionRow) async {
        do {
            try await ShippingLabelService.shared.markReceived(submissionId: row.id)
            await load()
        } catch {
            await MainActor.run {
                uploadError = error.localizedDescription
            }
        }
    }

    private func labeled(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 15, weight: .medium))
        }
    }

    private func load() async {
        await MainActor.run { errorText = nil }
        do {
            let list = try await ConsignmentAdminService.shared.fetchSubmissions(
                status: filterPendingOnly ? "pending" : nil
            )
            await MainActor.run { rows = list }
        } catch {
            await MainActor.run { errorText = error.localizedDescription }
        }
    }

    private func save(row: ConsignmentSubmissionRow, status: String) async {
        await MainActor.run { isSaving = true }
        do {
            try await ConsignmentAdminService.shared.updateSubmission(
                id: row.id,
                adminStatus: status,
                finalPriceRange: editedPrice.isEmpty ? nil : editedPrice,
                adminNotes: editedNotes.isEmpty ? nil : editedNotes
            )

            if status == "accepted" || status == "rejected" {
                try? await NotificationService.shared.createConsignmentStatusNotification(
                    userId: row.userId.uuidString,
                    status: status,
                    submissionId: row.id.uuidString,
                    finalPriceRange: editedPrice.isEmpty ? nil : editedPrice
                )
            }

            await MainActor.run {
                isSaving = false
                selectedDetailId = nil
            }
            await load()
        } catch {
            await MainActor.run {
                isSaving = false
                errorText = error.localizedDescription
            }
        }
    }
}
