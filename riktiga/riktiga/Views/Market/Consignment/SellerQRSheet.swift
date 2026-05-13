import SwiftUI
import CoreImage.CIFilterBuiltins
import UIKit

/// Lightweight QR sheet för säljaren i chatbanner / snabbåtgärder.
struct SellerQRSheet: View {
    let qrPayload: String
    var carrier: String?
    var trackingNumber: String?

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text(L.t(
                    sv: "Visa denna kod för ombudet eller skanna själv i terminalen.",
                    nb: "Vis denne koden for ombudet eller skann selv i terminalen."
                ))
                .font(.system(size: 15))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 8)

                if let img = qrImage(from: qrPayload) {
                    Image(uiImage: img)
                        .interpolation(.none)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 260, height: 260)
                        .padding(16)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }

                if let t = trackingNumber?.trimmingCharacters(in: .whitespacesAndNewlines), !t.isEmpty {
                    Text(L.t(sv: "Spårnummer: \(t)", nb: "Sporingsnummer: \(t)"))
                        .font(.system(size: 14, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 0)
            }
            .padding(20)
            .navigationTitle(L.t(sv: "QR-kod", nb: "QR-kode"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(L.t(sv: "Klar", nb: "Ferdig")) { dismiss() }
                }
            }
        }
    }

    private func qrImage(from payload: String) -> UIImage? {
        let context = CIContext()
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(payload.utf8)
        filter.correctionLevel = "M"
        guard let output = filter.outputImage else { return nil }
        let scaled = output.transformed(by: CGAffineTransform(scaleX: 8, y: 8))
        guard let cg = context.createCGImage(scaled, from: scaled.extent) else { return nil }
        return UIImage(cgImage: cg)
    }
}
