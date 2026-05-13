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

    // Manual-shipping fallback for marketplace orders whose carrier
    // booking failed in `book-marketplace-shipping`.
    @State private var manualOrders: [MarketplaceOrderRow] = []
    @State private var manualOrderImporting: UUID?
    @State private var manualOrderUploadError: String?
    @State private var manualOrderTracking: [UUID: String] = [:]
    @State private var manualOrderTrackingUrl: [UUID: String] = [:]
    @State private var markingShippedId: UUID?

    // Open marketplace disputes that need admin resolution.
    @State private var openDisputeCount: Int = 0
    @State private var showDisputesView: Bool = false

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

                if openDisputeCount > 0 {
                    Section {
                        Button {
                            showDisputesView = true
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: "exclamationmark.bubble.fill")
                                    .foregroundStyle(.red)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(L.t(sv: "Öppna tvister", nb: "Åpne tvister"))
                                        .font(.system(size: 14, weight: .semibold))
                                    Text("\(openDisputeCount) väntar på beslut")
                                        .font(.system(size: 12))
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundStyle(.tertiary)
                            }
                        }
                    }
                }

                if !manualOrders.isEmpty {
                    Section(header: Text(L.t(
                        sv: "Manuell fraktsedel krävs",
                        nb: "Manuell fraktseddel kreves"
                    ))) {
                        ForEach(manualOrders) { order in
                            manualOrderRow(order: order)
                        }
                        if let manualOrderUploadError {
                            Text(manualOrderUploadError)
                                .font(.system(size: 12))
                                .foregroundStyle(.red)
                        }
                    }
                }

                ForEach(rows, id: \.id) { row in
                    Button {
                        selectedDetailId = row.id
                        editedPrice = row.finalPriceRange ?? row.priceSEK.map { "\($0) kr" } ?? ""
                        editedNotes = row.adminNotes ?? ""
                        editedCarrier = row.shippingCarrier ?? ""
                        editedTracking = row.shippingTrackingNumber ?? ""
                        uploadError = nil
                    } label: {
                        VStack(alignment: .leading, spacing: 6) {
                            Text((row.title?.isEmpty == false ? row.title! : row.category))
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
            .navigationDestination(isPresented: $showDisputesView) {
                AdminDisputesView()
            }
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
                            CachedRemoteImage(url: url) {
                                Color.gray.opacity(0.2).overlay(ProgressView())
                            }
                            .frame(maxHeight: 280)
                            .clipped()
                        }
                    }
                    .tabViewStyle(.page)
                    .frame(height: 300)

                    Group {
                        labeled(L.t(sv: "Kategori", nb: "Kategori"), row.category)
                        labeled(L.t(sv: "Titel", nb: "Tittel"), row.title ?? "—")
                        labeled(L.t(sv: "Märke", nb: "Merke"), row.userBrand ?? "—")
                        labeled(L.t(sv: "Skick", nb: "Stand"), SellCondition.localizedTitle(raw: row.userCondition) ?? "—")
                        labeled(L.t(sv: "Pris", nb: "Pris"), row.priceSEK.map { "\($0) kr" } ?? "—")
                        labeled(L.t(sv: "Material", nb: "Materiale"), row.material ?? "—")
                        labeled(L.t(sv: "Färger", nb: "Farger"), row.colors.isEmpty ? "—" : row.colors.joined(separator: ", "))
                        labeled(L.t(sv: "Paketstorlek", nb: "Pakkestørrelse"), row.packageSize ?? "—")
                        if let description = row.description, !description.isEmpty {
                            Text(description)
                                .font(.system(size: 14))
                        }
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
            await MainActor.run {
                rows = list
                ImageCacheManager.shared.prefetch(urls: list.flatMap { $0.imageUrls })
            }
        } catch {
            await MainActor.run { errorText = error.localizedDescription }
        }

        // Load marketplace orders that need a manually uploaded label
        // (automated booking failed). Best-effort — admins may not be the
        // ones using this view, so we silently swallow RLS-deny errors.
        if let manual = try? await MarketplaceOrdersService.shared.fetchManualShippingOrders() {
            await MainActor.run {
                manualOrders = manual
            }
        } else {
            await MainActor.run { manualOrders = [] }
        }

        // Count open disputes for the toolbar entry. Best-effort.
        if let open = try? await MarketplaceOrdersService.shared.fetchOpenDisputes() {
            await MainActor.run { openDisputeCount = open.count }
        } else {
            await MainActor.run { openDisputeCount = 0 }
        }
    }

    // MARK: - Manual marketplace order shipping fallback

    @ViewBuilder
    private func manualOrderRow(order: MarketplaceOrderRow) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: "shippingbox.and.arrow.backward.fill")
                    .foregroundStyle(.orange)
                Text(L.t(sv: "Order", nb: "Ordre") + " \(order.id.uuidString.prefix(8))")
                    .font(.system(size: 14, weight: .semibold))
                Spacer()
                Text(MarketplacePricing.formatSEK(Double(order.amountBuyerTotal) / 100.0))
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            if let name = order.buyerShippingName,
               let address = order.buyerShippingAddress,
               let postal = order.buyerShippingPostal,
               let city = order.buyerShippingCity {
                Text("\(name) — \(address), \(postal) \(city)")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }

            if let carrier = order.shippingCarrier {
                Text("Carrier: \(carrier.uppercased())")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            // Tracking-info för köparen — sparas på ordern via PDF-uppload
            // *eller* via "Markera som skickad" nedan.
            VStack(spacing: 6) {
                TextField(
                    L.t(sv: "Tracking-nummer", nb: "Tracking-nummer"),
                    text: bindingForTracking(orderId: order.id, fallback: order.shippingTrackingNumber)
                )
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
                .font(.system(size: 13))
                .padding(8)
                .background(Color.gray.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 6))

                TextField(
                    L.t(sv: "Tracking-URL", nb: "Tracking-URL"),
                    text: bindingForTrackingUrl(orderId: order.id, fallback: order.shippingTrackingUrl)
                )
                .keyboardType(.URL)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .font(.system(size: 13))
                .padding(8)
                .background(Color.gray.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }

            Button {
                manualOrderImporting = order.id
            } label: {
                HStack(spacing: 6) {
                    if manualOrderImporting == order.id {
                        ProgressView().tint(.white)
                    } else {
                        Image(systemName: "arrow.up.doc.fill")
                    }
                    Text(L.t(sv: "Ladda upp PDF-fraktsedel", nb: "Last opp PDF-fraktseddel"))
                        .font(.system(size: 13, weight: .bold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(Color.black)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain)
            .disabled(manualOrderImporting != nil || markingShippedId != nil)

            Button {
                Task { await markShipped(order: order) }
            } label: {
                HStack(spacing: 6) {
                    if markingShippedId == order.id {
                        ProgressView().tint(.white)
                    } else {
                        Image(systemName: "shippingbox.fill")
                    }
                    Text(L.t(sv: "Markera som skickad", nb: "Marker som sendt"))
                        .font(.system(size: 13, weight: .bold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(Color.green)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain)
            .disabled(manualOrderImporting != nil || markingShippedId != nil)
        }
        .padding(.vertical, 6)
        .fileImporter(
            isPresented: Binding(
                get: { manualOrderImporting == order.id },
                set: { if !$0 { manualOrderImporting = nil } }
            ),
            allowedContentTypes: [.pdf]
        ) { result in
            Task { await handleManualUpload(order: order, result: result) }
        }
    }

    private func handleManualUpload(
        order: MarketplaceOrderRow,
        result: Result<URL, Error>
    ) async {
        defer {
            Task { @MainActor in manualOrderImporting = nil }
        }
        do {
            let url = try result.get()
            let didStartAccessing = url.startAccessingSecurityScopedResource()
            defer { if didStartAccessing { url.stopAccessingSecurityScopedResource() } }
            let data = try Data(contentsOf: url)
            // Föredra adminens manuella inmatning, fall tillbaka på det
            // som redan finns på ordern (t.ex. delvis ifyllt från boknings-API).
            let typedTracking = (manualOrderTracking[order.id] ?? "").trimmingCharacters(in: .whitespaces)
            let typedUrl = (manualOrderTrackingUrl[order.id] ?? "").trimmingCharacters(in: .whitespaces)
            try await ShippingLabelService.shared.uploadMarketplaceOrderLabelPDF(
                orderId: order.id,
                sellerId: order.sellerId,
                data: data,
                carrier: order.shippingCarrier,
                trackingNumber: typedTracking.isEmpty ? order.shippingTrackingNumber : typedTracking,
                trackingUrl: typedUrl.isEmpty ? order.shippingTrackingUrl : typedUrl
            )
            await load()
        } catch {
            await MainActor.run {
                manualOrderUploadError = error.localizedDescription
            }
        }
    }

    private func markShipped(order: MarketplaceOrderRow) async {
        await MainActor.run { markingShippedId = order.id }
        defer { Task { @MainActor in markingShippedId = nil } }
        do {
            let typedTracking = (manualOrderTracking[order.id] ?? order.shippingTrackingNumber ?? "")
                .trimmingCharacters(in: .whitespaces)
            let typedUrl = (manualOrderTrackingUrl[order.id] ?? order.shippingTrackingUrl ?? "")
                .trimmingCharacters(in: .whitespaces)
            _ = try await MarketplaceOrdersService.shared.markOrderShipped(
                orderId: order.id,
                trackingNumber: typedTracking.isEmpty ? nil : typedTracking,
                trackingUrl: typedUrl.isEmpty ? nil : typedUrl
            )
            await load()
        } catch {
            await MainActor.run {
                manualOrderUploadError = error.localizedDescription
            }
        }
    }

    private func bindingForTracking(orderId: UUID, fallback: String?) -> Binding<String> {
        Binding(
            get: { manualOrderTracking[orderId] ?? fallback ?? "" },
            set: { manualOrderTracking[orderId] = $0 }
        )
    }

    private func bindingForTrackingUrl(orderId: UUID, fallback: String?) -> Binding<String> {
        Binding(
            get: { manualOrderTrackingUrl[orderId] ?? fallback ?? "" },
            set: { manualOrderTrackingUrl[orderId] = $0 }
        )
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
