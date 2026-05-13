import SwiftUI
import CoreImage.CIFilterBuiltins
import UIKit

/// System-message card rendered inside the listing chat for shipping
/// updates from `book-marketplace-shipping` and the Shipmondo webhook / polling.
///
/// `shipping_label_ready` (sent to seller):
///   - Big QR code (rendered with `CIQRCodeGenerator`) from carrier QR-payload
///     eller från kollinr — säljaren visar den vid DHL/Schenker-ombud.
///   - "Öppna PDF"-button → signed URL from `ShippingLabelService` so the
///     seller can print at home if they prefer.
///   - Tracking link.
///
/// `shipping_in_transit` (sent to buyer):
///   - Compact thumbnail + tracking link + ETA so the buyer knows when
///     to expect the package.
struct ShippingLabelCard: View {
    let message: DirectMessage
    let currentUserId: UUID?

    @State private var labelURL: URL?
    @State private var labelLoading = false
    @State private var labelError: String?
    @State private var labelUrlOverride: String?
    @State private var qrPayloadOverride: String?
    @State private var trackingNumberOverride: String?
    @State private var trackingUrlOverride: String?
    @State private var isFetchingShipmondoLabel = false
    @State private var showPrintAtAgent = false

    private var payload: ShippingCardData? { message.shippingCardData }

    private var isSeller: Bool {
        message.isShippingLabelReady
    }

    var body: some View {
        if let payload {
            VStack(alignment: .leading, spacing: 12) {
                header(payload: payload)
                if isSeller {
                    sellerBody(payload: payload)
                } else {
                    buyerBody(payload: payload)
                }
                if let labelError {
                    Text(labelError)
                        .font(.system(size: 12))
                        .foregroundColor(.red)
                }
            }
            .padding(14)
            .frame(maxWidth: 320, alignment: .leading)
            .background(Color(.secondarySystemBackground))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color.black.opacity(0.08), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .onChange(of: message.id) { _, _ in
                labelUrlOverride = nil
                qrPayloadOverride = nil
                trackingNumberOverride = nil
                trackingUrlOverride = nil
                labelError = nil
                showPrintAtAgent = false
            }
            .sheet(isPresented: $showPrintAtAgent) {
                let raw = (qrPayloadOverride ?? payload.qrPayload)?
                    .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                if !raw.isEmpty {
                    PrintAtAgentSheet(
                        qrPayload: raw,
                        carrier: payload.carrier,
                        trackingNumber: trackingNumberOverride ?? payload.trackingNumber
                    )
                }
            }
        } else {
            EmptyView()
        }
    }

    // MARK: - Header

    private func header(payload: ShippingCardData) -> some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.black)
                    .frame(width: 32, height: 32)
                Image(systemName: isSeller ? "shippingbox.fill" : "truck.box.fill")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.white)
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(headerTitle)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.primary)
                Text(headerSubtitle(payload: payload))
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
    }

    private var headerTitle: String {
        if isSeller {
            return L.t(sv: "Fraktsedel klar", nb: "Fraktseddel klar")
        } else {
            return L.t(sv: "Paketet är på väg", nb: "Pakken er på vei")
        }
    }

    private func headerSubtitle(payload: ShippingCardData) -> String {
        let carrierLabel = payload.carrier?.uppercased() ?? "Frakt"
        if isSeller {
            return L.t(
                sv: "\(carrierLabel) – visa QR-koden vid ombud eller skriv ut PDF om du har en.",
                nb: "\(carrierLabel) – vis QR-koden hos ombud eller skriv ut PDF om du har."
            )
        } else {
            return L.t(
                sv: "\(carrierLabel) hämtar paketet från säljaren snart.",
                nb: "\(carrierLabel) henter pakken hos selgeren snart."
            )
        }
    }

    // MARK: - Seller body

    private func sellerBody(payload: ShippingCardData) -> some View {
        let qrSource: String? = {
            if let q = qrPayloadOverride?.trimmingCharacters(in: .whitespacesAndNewlines), !q.isEmpty {
                return q
            }
            if let q = payload.qrPayload?.trimmingCharacters(in: .whitespacesAndNewlines), !q.isEmpty {
                return q
            }
            let track = trackingNumberOverride ?? payload.trackingNumber
            if let t = track?.trimmingCharacters(in: .whitespacesAndNewlines), !t.isEmpty {
                return t
            }
            return nil
        }()
        let effectiveLabelRaw = labelUrlOverride ?? payload.labelUrl
        let hasPdfSource: Bool = {
            guard let u = effectiveLabelRaw?.trimmingCharacters(in: .whitespacesAndNewlines), !u.isEmpty else {
                return false
            }
            return true
        }()
        let effectiveTrackingNumber = trackingNumberOverride ?? payload.trackingNumber
        let effectiveTrackingUrl = trackingUrlOverride ?? payload.trackingUrl
        let realQrRaw = (qrPayloadOverride ?? payload.qrPayload)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let hasRealQrPayload = !realQrRaw.isEmpty

        return VStack(alignment: .leading, spacing: 12) {
            if let qrSource, let qrImage = qrCode(from: qrSource) {
                VStack(spacing: 6) {
                    Image(uiImage: qrImage)
                        .interpolation(.none)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 220, height: 220)
                        .padding(8)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    Text(L.t(
                        sv: "Visa denna QR-kod hos DHL/Schenker-ombudet — de skannar den och skriver ut fraktsedeln.",
                        nb: "Vis denne QR-koden hos DHL/Schenker-ombud — de skanner og skriver ut fraktseddelen."
                    ))
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
            }

            if let trackingNumber = effectiveTrackingNumber, !trackingNumber.isEmpty {
                infoRow(
                    label: L.t(sv: "Spårningsnr", nb: "Sporingsnr"),
                    value: trackingNumber
                )
            }

            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    if hasPdfSource {
                        Button {
                            Task { await openLabelPDF(payload: payload) }
                        } label: {
                            HStack(spacing: 6) {
                                if labelLoading {
                                    ProgressView().tint(.white)
                                } else {
                                    Image(systemName: "qrcode.viewfinder")
                                }
                                Text(L.t(sv: "Visa fraktsedel", nb: "Vis fraktseddel"))
                                    .font(.system(size: 13, weight: .bold))
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(Color.black)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                        .buttonStyle(.plain)
                        .disabled(labelLoading || isFetchingShipmondoLabel)
                    } else if message.isShippingLabelReady {
                        Button {
                            Task { await fetchShipmondoLabel(payload: payload) }
                        } label: {
                            HStack(spacing: 6) {
                                if isFetchingShipmondoLabel {
                                    ProgressView().tint(.white)
                                } else {
                                    Image(systemName: "arrow.down.doc")
                                }
                                Text(L.t(sv: "Hämta fraktsedel", nb: "Hent fraktseddel"))
                                    .font(.system(size: 13, weight: .bold))
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(Color.black)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                        .buttonStyle(.plain)
                        .disabled(isFetchingShipmondoLabel || labelLoading)
                    }

                    if let urlString = effectiveTrackingUrl, let url = URL(string: urlString) {
                        Link(destination: url) {
                            HStack(spacing: 6) {
                                Image(systemName: "location.fill")
                                Text(L.t(sv: "Spåra", nb: "Spor"))
                                    .font(.system(size: 13, weight: .bold))
                            }
                            .foregroundColor(.primary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color.black.opacity(0.18), lineWidth: 1)
                            )
                        }
                    }
                }

                if hasRealQrPayload {
                    Button {
                        showPrintAtAgent = true
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "printer")
                            Text(L.t(sv: "Skriv ut på ombud", nb: "Skriv ut hos ombud"))
                                .font(.system(size: 13, weight: .semibold))
                        }
                        .foregroundColor(.primary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.black.opacity(0.18), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Buyer body

    private func buyerBody(payload: ShippingCardData) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.black.opacity(0.04))
                        .frame(width: 56, height: 56)
                    Image(systemName: "shippingbox")
                        .font(.system(size: 24))
                        .foregroundColor(.primary)
                }
                VStack(alignment: .leading, spacing: 2) {
                    if let title = payload.listingTitle, !title.isEmpty {
                        Text(title)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.primary)
                            .lineLimit(2)
                    }
                    if let trackingNumber = payload.trackingNumber {
                        Text(L.t(
                            sv: "Spårning: \(trackingNumber)",
                            nb: "Sporing: \(trackingNumber)"
                        ))
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                    }
                }
                Spacer(minLength: 0)
            }

            if let urlString = payload.trackingUrl, let url = URL(string: urlString) {
                Link(destination: url) {
                    HStack(spacing: 6) {
                        Image(systemName: "location.fill")
                        Text(L.t(sv: "Följ paketet", nb: "Følg pakken"))
                            .font(.system(size: 14, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color.black)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }
        }
    }

    // MARK: - Helpers

    private func infoRow(label: String, value: String) -> some View {
        HStack(spacing: 6) {
            Text(label)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
            Text(value)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.primary)
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer(minLength: 0)
        }
    }

    private func qrCode(from payload: String) -> UIImage? {
        let context = CIContext()
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(payload.utf8)
        filter.correctionLevel = "M"
        guard let output = filter.outputImage else { return nil }
        let scaled = output.transformed(by: CGAffineTransform(scaleX: 8, y: 8))
        guard let cg = context.createCGImage(scaled, from: scaled.extent) else { return nil }
        return UIImage(cgImage: cg)
    }

    @MainActor
    private func openLabelPDF(payload: ShippingCardData) async {
        guard !labelLoading else { return }
        labelLoading = true
        labelError = nil
        defer { labelLoading = false }

        do {
            let url: URL
            let raw = labelUrlOverride ?? payload.labelUrl
            if let raw, raw.hasPrefix("http"),
               let direct = URL(string: raw) {
                url = direct
            } else {
                guard let userId = currentUserId else {
                    throw NSError(
                        domain: "ShippingLabelCard",
                        code: -1,
                        userInfo: [NSLocalizedDescriptionKey: "Inte inloggad"]
                    )
                }
                url = try await ShippingLabelService.shared
                    .signedUrlForMarketplaceOrderLabel(
                        orderId: payload.orderId,
                        sellerId: userId,
                        storedPath: raw
                    )
            }
            await UIApplication.shared.open(url)
        } catch {
            labelError = error.localizedDescription
        }
    }

    @MainActor
    private func fetchShipmondoLabel(payload: ShippingCardData) async {
        guard !isFetchingShipmondoLabel else { return }
        isFetchingShipmondoLabel = true
        labelError = nil
        defer { isFetchingShipmondoLabel = false }
        do {
            let r = try await MarketplaceOrdersService.shared.refreshShipmondoLabel(orderId: payload.orderId)
            if let u = r.shipping_label_url?.trimmingCharacters(in: .whitespacesAndNewlines), !u.isEmpty {
                labelUrlOverride = u
            }
            if let q = r.qr_payload?.trimmingCharacters(in: .whitespacesAndNewlines), !q.isEmpty {
                qrPayloadOverride = q
            }
            if let t = r.tracking_number?.trimmingCharacters(in: .whitespacesAndNewlines), !t.isEmpty {
                trackingNumberOverride = t
            }
            if let tu = r.tracking_url?.trimmingCharacters(in: .whitespacesAndNewlines), !tu.isEmpty {
                trackingUrlOverride = tu
            }
            if r.hasLabel != true {
                let path = (labelUrlOverride ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                let qr = (qrPayloadOverride ?? payload.qrPayload)?
                    .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                if path.isEmpty && qr.isEmpty {
                    labelError = L.t(
                        sv: "Fraktsedeln är inte klar än. Försök igen om en stund.",
                        nb: "Fraktseddelen er ikke klar ennå. Prøv igjen om en stund."
                    )
                }
            }
        } catch {
            labelError = error.localizedDescription
        }
    }
}
