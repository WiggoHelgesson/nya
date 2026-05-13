import SwiftUI
import Supabase
import CoreImage.CIFilterBuiltins
import UIKit

/// Admin-only: kör en riktig Shipmondo-bokning (ingen DB/Stripe). PDF finns ofta
/// i API-svaret; annars räcker QR från kollinr vid ombud.
struct TestSendifyLabelView: View {
    @Environment(\.dismiss) private var dismiss

    private let supabase = SupabaseConfig.supabase

    private static let packageSizes = ["XS", "S", "M", "L", "XL"]

    enum CarrierChoice: String, CaseIterable, Identifiable {
        case auto
        case dhl
        case schenker
        var id: String { rawValue }
        var title: String {
            switch self {
            case .auto: return L.t(sv: "Auto (billigast)", nb: "Auto (billigst)")
            case .dhl: return "DHL"
            case .schenker: return "DB Schenker"
            }
        }
    }

    private struct ShipmondoTestSuccess: Equatable {
        var carrier: String?
        var productName: String?
        var priceSek: Double?
        var trackingNumber: String?
        var trackingUrl: String?
        var labelUrl: String?
    }

    @State private var packageSize = "M"
    @State private var toName = "Test Köpare"
    @State private var toStreet = "Testgatan 1"
    @State private var toPostal = "41122"
    @State private var toCity = "Göteborg"
    @State private var toEmail = "buyer@test.upanddown.se"
    @State private var carrierChoice: CarrierChoice = .auto

    @State private var isLoading = false
    @State private var errorText: String?
    @State private var success: ShipmondoTestSuccess?

    @State private var showPdfViewer = false
    @State private var pdfPreviewURL: URL?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker(L.t(sv: "Paketstorlek", nb: "Pakkestørrelse"), selection: $packageSize) {
                        ForEach(Self.packageSizes, id: \.self) { s in
                            Text(s).tag(s)
                        }
                    }
                    TextField(L.t(sv: "Mottagarens namn", nb: "Mottakers navn"), text: $toName)
                    TextField(L.t(sv: "Gatuadress", nb: "Gateadresse"), text: $toStreet)
                    TextField(L.t(sv: "Postnummer", nb: "Postnummer"), text: $toPostal)
                        .keyboardType(.numbersAndPunctuation)
                    TextField(L.t(sv: "Ort", nb: "Sted"), text: $toCity)
                    TextField(L.t(sv: "E-post (mottagare)", nb: "E-post (mottaker)"), text: $toEmail)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                    Picker(L.t(sv: "Bärare", nb: "Transportør"), selection: $carrierChoice) {
                        ForEach(CarrierChoice.allCases) { c in
                            Text(c.title).tag(c)
                        }
                    }
                } header: {
                    Text(L.t(sv: "Testdata", nb: "Testdata"))
                }

                Section {
                    Button {
                        Task { await runTest() }
                    } label: {
                        HStack {
                            if isLoading { ProgressView() }
                            Text(L.t(sv: "Skapa testfraktsedel", nb: "Lag testfraktseddel"))
                        }
                    }
                    .disabled(isLoading)

                    if let errorText {
                        Text(errorText)
                            .font(.system(size: 13))
                            .foregroundStyle(.red)
                    }
                }

                if let s = success {
                    Section {
                        Label(
                            L.t(sv: "Bokning OK", nb: "Booking OK"),
                            systemImage: "checkmark.circle.fill"
                        )
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.green)

                        if let carrier = s.carrier {
                            Text("\(L.t(sv: "Bärare", nb: "Transportør")): \(carrier)")
                                .font(.system(size: 13))
                                .foregroundStyle(.secondary)
                        }
                        if let product = s.productName {
                            Text("\(L.t(sv: "Produkt", nb: "Produkt")): \(product)")
                                .font(.system(size: 13))
                                .foregroundStyle(.secondary)
                        }
                        if let p = s.priceSek {
                            Text(String(format: "%.2f kr", p))
                                .font(.system(size: 13))
                                .foregroundStyle(.secondary)
                        }
                        if let tn = s.trackingNumber, !tn.isEmpty {
                            Text("\(L.t(sv: "Kollinr", nb: "Sporingsnr")): \(tn)")
                                .font(.system(size: 13, weight: .semibold))
                        }

                        if let tn = s.trackingNumber, !tn.isEmpty, let qrImage = qrCode(from: tn) {
                            VStack(spacing: 8) {
                                Image(uiImage: qrImage)
                                    .interpolation(.none)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 220, height: 220)
                                    .padding(8)
                                    .background(Color.white)
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                                Text(L.t(
                                    sv: "Visa QR-koden eller säg \"\(tn)\" hos DHL/Schenker-ombudet — de skriver ut fraktsedeln åt dig.",
                                    nb: "Vis QR-koden eller si «\(tn)» hos DHL/Schenker-ombud — de skriver ut fraktseddelen for deg."
                                ))
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 4)
                        } else if s.trackingNumber == nil || s.trackingNumber?.isEmpty == true {
                            Text(L.t(
                                sv: "Inget kollinr i svaret — kontrollera i Shipmondo.",
                                nb: "Ingen sporings-ID i svaret."
                            ))
                            .font(.system(size: 12))
                            .foregroundStyle(.orange)
                        }

                        HStack(spacing: 8) {
                            if let raw = s.labelUrl?.trimmingCharacters(in: .whitespacesAndNewlines),
                               !raw.isEmpty,
                               URL(string: raw) != nil {
                                Button {
                                    if let u = URL(string: raw) {
                                        pdfPreviewURL = u
                                        showPdfViewer = true
                                    }
                                } label: {
                                    HStack(spacing: 6) {
                                        Image(systemName: "doc.text.fill")
                                        Text(L.t(sv: "Öppna PDF", nb: "Åpne PDF"))
                                            .font(.system(size: 13, weight: .bold))
                                    }
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .background(Color.black)
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                                }
                                .buttonStyle(.plain)
                            }

                            if let urlString = s.trackingUrl,
                               let url = URL(string: urlString) {
                                Link(destination: url) {
                                    HStack(spacing: 6) {
                                        Image(systemName: "location.fill")
                                        Text(L.t(sv: "Spåra paket", nb: "Spor pakke"))
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
                    } header: {
                        Text(L.t(sv: "Resultat", nb: "Resultat"))
                    }
                }
            }
            .navigationTitle(L.t(sv: "Shipmondo-test", nb: "Shipmondo-test"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L.t(sv: "Stäng", nb: "Lukk")) { dismiss() }
                }
            }
            .sheet(isPresented: $showPdfViewer, onDismiss: { pdfPreviewURL = nil }) {
                Group {
                    if let pdfPreviewURL {
                        RemotePDFViewer(
                            signedUrl: pdfPreviewURL,
                            displayName: L.t(sv: "Shipmondo-test", nb: "Shipmondo-test")
                        )
                    }
                }
            }
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

    private func runTest() async {
        await MainActor.run {
            isLoading = true
            errorText = nil
            success = nil
        }

        struct Body: Encodable {
            let packageSize: String
            let toName: String
            let toStreet: String
            let toPostal: String
            let toCity: String
            let toEmail: String
            let carrier: String?
        }

        let carrierParam: String?
        switch carrierChoice {
        case .auto: carrierParam = nil
        case .dhl: carrierParam = "dhl"
        case .schenker: carrierParam = "schenker"
        }

        let body = Body(
            packageSize: packageSize,
            toName: toName,
            toStreet: toStreet,
            toPostal: toPostal,
            toCity: toCity,
            toEmail: toEmail,
            carrier: carrierParam
        )

        do {
            let ok: TestShipmondoLabelSuccess = try await supabase.functions.invoke(
                "test-shipmondo-label",
                options: FunctionInvokeOptions(body: body)
            )

            guard ok.success else {
                await MainActor.run {
                    errorText = L.t(sv: "Okänt fel", nb: "Ukjent feil")
                    isLoading = false
                }
                return
            }

            let priceSek: Double? = ok.price_ore.map { Double($0) / 100.0 }
            await MainActor.run {
                success = ShipmondoTestSuccess(
                    carrier: ok.carrier,
                    productName: ok.product_name,
                    priceSek: priceSek,
                    trackingNumber: ok.tracking_number,
                    trackingUrl: ok.tracking_url,
                    labelUrl: ok.label_url
                )
                isLoading = false
            }
        } catch let FunctionsError.httpError(_, data) {
            let decoded = try? JSONDecoder().decode(EdgeErrorBody.self, from: data)
            let fallback = String(data: data, encoding: .utf8)
            await MainActor.run {
                errorText = decoded?.error ?? fallback ?? L.t(sv: "Begäran misslyckades", nb: "Forespørsel feilet")
                isLoading = false
            }
        } catch {
            await MainActor.run {
                errorText = error.localizedDescription
                isLoading = false
            }
        }
    }
}

private struct TestShipmondoLabelSuccess: Decodable {
    let success: Bool
    let shipmondo_shipment_id: String?
    let carrier: String?
    let product_name: String?
    let price_ore: Int?
    let tracking_number: String?
    let tracking_url: String?
    let label_url: String?
}

private struct EdgeErrorBody: Decodable {
    let error: String?
}
