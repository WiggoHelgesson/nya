import SwiftUI

struct MyConsignmentSubmissionsView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var rows: [ConsignmentSubmissionRow] = []
    @State private var isLoading = true
    @State private var errorText: String?

    @State private var addressRow: ConsignmentSubmissionRow?
    @State private var labelRow: ConsignmentSubmissionRow?
    @State private var signedLabelUrl: URL?
    @State private var isPreparingLabel = false
    @State private var labelError: String?
    @State private var autoOpenSubmissionId: UUID?

    init(autoOpenLabelForSubmissionId: UUID? = nil) {
        _autoOpenSubmissionId = State(initialValue: autoOpenLabelForSubmissionId)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground).ignoresSafeArea()

                if isLoading {
                    ProgressView()
                } else if let errorText {
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 40))
                            .foregroundColor(.orange)
                        Text(errorText)
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        Button(L.t(sv: "Försök igen", nb: "Prøv igjen")) {
                            Task { await load() }
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding(24)
                } else if rows.isEmpty {
                    emptyState
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(rows, id: \.id) { row in
                                SubmissionRowCard(
                                    row: row,
                                    onAddAddress: { addressRow = row },
                                    onOpenLabel: { Task { await openLabel(for: row) } },
                                    onMarkShipped: { Task { await markShipped(row: row) } }
                                )
                            }
                        }
                        .padding(16)
                    }
                }
            }
            .navigationTitle(L.t(sv: "Mina inskickade produkter", nb: "Mine innsendte produkter"))
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
            .task { await load() }
            .sheet(item: $addressRow) { row in
                ConsignmentShippingAddressView(
                    submissionId: row.id,
                    initialAddress: row.shippingAddress
                ) { _ in
                    Task { await load() }
                }
            }
            .sheet(item: $labelRow, onDismiss: {
                signedLabelUrl = nil
            }) { _ in
                LabelSheetContent(signedUrl: signedLabelUrl)
            }
            .alert(L.t(sv: "Fel", nb: "Feil"), isPresented: Binding(
                get: { labelError != nil },
                set: { if !$0 { labelError = nil } }
            )) {
                Button("OK") { labelError = nil }
            } message: {
                Text(labelError ?? "")
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "shippingbox")
                .font(.system(size: 48))
                .foregroundColor(.gray.opacity(0.6))
            Text(L.t(sv: "Du har inte skickat in något än.", nb: "Du har ikke sendt inn noe ennå."))
                .font(.system(size: 16, weight: .semibold))
                .multilineTextAlignment(.center)
            Text(L.t(
                sv: "Ta en bild av din produkt i sälj-flödet så dyker den upp här medan vi granskar.",
                nb: "Ta et bilde av produktet i salgsflyten, så dukker den opp her mens vi gjennomgår."
            ))
                .font(.system(size: 13))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .padding(.vertical, 60)
    }

    private func load() async {
        guard let userId = authViewModel.currentUser?.id else {
            await MainActor.run {
                isLoading = false
                errorText = L.t(sv: "Inte inloggad.", nb: "Ikke innlogget.")
            }
            return
        }
        await MainActor.run {
            isLoading = true
            errorText = nil
        }
        do {
            let list = try await ConsignmentSubmissionService.shared.fetchMine(userId: userId)
            await MainActor.run {
                rows = list
                isLoading = false
                ImageCacheManager.shared.prefetch(urls: list.flatMap { $0.imageUrls })
                if let autoId = autoOpenSubmissionId,
                   let match = list.first(where: { $0.id == autoId }) {
                    autoOpenSubmissionId = nil
                    Task { await openLabel(for: match) }
                }
            }
        } catch {
            await MainActor.run {
                isLoading = false
                errorText = error.localizedDescription
            }
        }
    }

    private func openLabel(for row: ConsignmentSubmissionRow) async {
        guard row.shippingLabelUrl != nil else { return }
        await MainActor.run {
            isPreparingLabel = true
            labelError = nil
            labelRow = row
            signedLabelUrl = nil
        }
        do {
            let url = try await ShippingLabelService.shared.signedUrlForLabel(
                submissionId: row.id,
                userId: row.userId
            )
            await MainActor.run {
                signedLabelUrl = url
                isPreparingLabel = false
            }
        } catch {
            await MainActor.run {
                isPreparingLabel = false
                labelError = error.localizedDescription
                labelRow = nil
            }
        }
    }

    private func markShipped(row: ConsignmentSubmissionRow) async {
        do {
            try await ShippingLabelService.shared.markShipped(submissionId: row.id)
            await load()
        } catch {
            await MainActor.run {
                labelError = error.localizedDescription
            }
        }
    }
}

// MARK: - Label sheet content

private struct LabelSheetContent: View {
    let signedUrl: URL?

    var body: some View {
        if let url = signedUrl {
            RemotePDFViewer(
                signedUrl: url,
                displayName: L.t(sv: "Fraktsedel", nb: "Fraktseddel")
            )
        } else {
            NavigationStack {
                VStack(spacing: 12) {
                    ProgressView()
                    Text(L.t(sv: "Hämtar fraktsedel…", nb: "Henter fraktseddel…"))
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
                .padding(40)
                .navigationTitle(L.t(sv: "Fraktsedel", nb: "Fraktseddel"))
                .navigationBarTitleDisplayMode(.inline)
            }
        }
    }
}

// MARK: - Row card

private struct SubmissionRowCard: View {
    let row: ConsignmentSubmissionRow
    let onAddAddress: () -> Void
    let onOpenLabel: () -> Void
    let onMarkShipped: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                thumbnail
                    .frame(width: 72, height: 72)
                    .background(Color(.systemGray5))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                VStack(alignment: .leading, spacing: 6) {
                    Text(title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.primary)
                        .lineLimit(2)

                    Text(row.category)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .lineLimit(1)

                    if let dateText = formattedDate {
                        Text(dateText)
                            .font(.system(size: 11))
                            .foregroundColor(.secondary.opacity(0.8))
                    }

                    StatusPill(status: row.adminStatus, finalPrice: row.finalPriceRange)

                    if row.adminStatus == "rejected",
                       let notes = row.adminNotes,
                       !notes.isEmpty {
                        Text(notes)
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                            .lineLimit(3)
                            .padding(.top, 2)
                    }
                }

                Spacer(minLength: 0)
            }

            shippingSection
        }
        .padding(12)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        )
    }

    @ViewBuilder
    private var shippingSection: some View {
        let status = row.shippingStatus ?? ShippingStatus.none
        if row.adminStatus == "accepted" && status != ShippingStatus.none {
            Divider()
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: "shippingbox.fill")
                        .font(.system(size: 13))
                        .foregroundColor(.blue)
                    Text(L.t(sv: "Frakt", nb: "Frakt"))
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.secondary)
                    Spacer()
                    ShippingPill(status: status)
                }

                actionRow(for: status)
            }
        }
    }

    @ViewBuilder
    private func actionRow(for status: String) -> some View {
        switch status {
        case ShippingStatus.awaitingAddress:
            Button(action: onAddAddress) {
                HStack {
                    Image(systemName: "mappin.and.ellipse")
                    Text(L.t(sv: "Ange avsändaradress", nb: "Angi avsenderadresse"))
                        .font(.system(size: 14, weight: .semibold))
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 10)
                .padding(.horizontal, 12)
                .background(Color.yellow.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.plain)
        case ShippingStatus.awaitingLabel:
            HStack(spacing: 8) {
                ProgressView()
                    .scaleEffect(0.7)
                Text(L.t(
                    sv: "Vi förbereder din fraktsedel…",
                    nb: "Vi forbereder fraktseddelen din…"
                ))
                .font(.system(size: 13))
                .foregroundColor(.secondary)
            }
        case ShippingStatus.labelReady:
            VStack(spacing: 8) {
                Button(action: onOpenLabel) {
                    HStack {
                        Image(systemName: "doc.text.fill")
                        Text(L.t(sv: "Öppna fraktsedel", nb: "Åpne fraktseddel"))
                            .font(.system(size: 14, weight: .semibold))
                        Spacer()
                        Image(systemName: "arrow.down.doc.fill")
                    }
                    .padding(.vertical, 10)
                    .padding(.horizontal, 12)
                    .background(Color.green.opacity(0.15))
                    .foregroundColor(.green)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)

                Button(action: onMarkShipped) {
                    Text(L.t(sv: "Jag har postat paketet", nb: "Jeg har sendt pakken"))
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.blue)
                }
                .buttonStyle(.plain)
            }
        case ShippingStatus.shipped:
            HStack(spacing: 8) {
                Image(systemName: "checkmark.seal.fill").foregroundColor(.blue)
                Text(L.t(sv: "Paketet är postat. Vi hör av oss när det är mottaget.",
                         nb: "Pakken er sendt. Vi sier fra når den er mottatt."))
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }
        case ShippingStatus.received:
            HStack(spacing: 8) {
                Image(systemName: "checkmark.seal.fill").foregroundColor(.green)
                Text(L.t(sv: "Mottaget hos oss — vi fortsätter processen.",
                         nb: "Mottatt hos oss — vi fortsetter prosessen."))
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }
        default:
            EmptyView()
        }
    }

    @ViewBuilder
    private var thumbnail: some View {
        if let first = row.imageUrls.first {
            CachedRemoteImage(url: first) {
                ZStack {
                    Color(.secondarySystemBackground)
                    Image(systemName: "photo").foregroundColor(.gray)
                }
            }
            .frame(width: 72, height: 72)
            .clipped()
        } else {
            Image(systemName: "photo")
                .foregroundColor(.gray)
        }
    }

    private var title: String {
        if let t = row.title?.trimmingCharacters(in: .whitespacesAndNewlines), !t.isEmpty {
            return t
        }
        return row.category
    }

    private var formattedDate: String? {
        guard let createdAt = row.createdAt else { return nil }
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let date = iso.date(from: createdAt) ?? {
            let iso2 = ISO8601DateFormatter()
            iso2.formatOptions = [.withInternetDateTime]
            return iso2.date(from: createdAt)
        }()
        guard let date else { return nil }
        let f = DateFormatter()
        f.locale = Locale(identifier: "sv_SE")
        f.dateFormat = "d MMM yyyy"
        return f.string(from: date)
    }
}

// MARK: - Status pill

private struct StatusPill: View {
    let status: String
    let finalPrice: String?

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(label)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(color)
            if let finalPrice, status == "accepted", !finalPrice.isEmpty {
                Text("· \(finalPrice)")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(color.opacity(0.12))
        .clipShape(Capsule())
    }

    private var label: String {
        switch status {
        case "accepted":
            return L.t(sv: "Godkänd", nb: "Godkjent")
        case "rejected":
            return L.t(sv: "Avvisad", nb: "Avvist")
        default:
            return L.t(sv: "Granskas", nb: "Gjennomgås")
        }
    }

    private var color: Color {
        switch status {
        case "accepted": return .green
        case "rejected": return .red
        default: return .orange
        }
    }
}

// MARK: - Shipping pill

private struct ShippingPill: View {
    let status: String

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(label)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(color)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color.opacity(0.12))
        .clipShape(Capsule())
    }

    private var label: String {
        switch status {
        case ShippingStatus.awaitingAddress:
            return L.t(sv: "Ange adress", nb: "Angi adresse")
        case ShippingStatus.awaitingLabel:
            return L.t(sv: "Förbereder fraktsedel", nb: "Forbereder fraktseddel")
        case ShippingStatus.labelReady:
            return L.t(sv: "Fraktsedel klar", nb: "Fraktseddel klar")
        case ShippingStatus.shipped:
            return L.t(sv: "Postad", nb: "Sendt")
        case ShippingStatus.received:
            return L.t(sv: "Mottaget", nb: "Mottatt")
        default:
            return ""
        }
    }

    private var color: Color {
        switch status {
        case ShippingStatus.awaitingAddress: return .orange
        case ShippingStatus.awaitingLabel: return .blue
        case ShippingStatus.labelReady: return .green
        case ShippingStatus.shipped: return .blue
        case ShippingStatus.received: return .green
        default: return .gray
        }
    }
}

#Preview {
    MyConsignmentSubmissionsView()
        .environmentObject(AuthViewModel())
}
