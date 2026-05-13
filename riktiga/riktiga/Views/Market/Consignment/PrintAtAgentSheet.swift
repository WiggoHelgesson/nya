import SwiftUI
import CoreImage.CIFilterBuiltins
import UIKit

/// Fullskärm/sheet för säljare som ska låta ombudet skriva ut fraktsedeln från QR.
struct PrintAtAgentSheet: View {
    let qrPayload: String
    var carrier: String?
    var trackingNumber: String?

    @Environment(\.dismiss) private var dismiss

    private var carrierPhrase: String {
        if let c = carrier?.trimmingCharacters(in: .whitespacesAndNewlines), !c.isEmpty {
            return c.uppercased()
        }
        return "DHL/Schenker"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Text(L.t(
                        sv: "Visa QR-koden hos \(carrierPhrase)-ombudet — de skannar och skriver ut fraktsedeln åt dig.",
                        nb: "Vis QR-koden hos \(carrierPhrase)-ombud — de skanner og skriver ut fraktseddelen for deg."
                    ))
                    .font(.system(size: 16))
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)

                    if let img = qrImage(from: qrPayload) {
                        Image(uiImage: img)
                            .interpolation(.none)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 280, height: 280)
                            .padding(16)
                            .background(Color.white)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .frame(maxWidth: .infinity)
                    }

                    if let t = trackingNumber?.trimmingCharacters(in: .whitespacesAndNewlines), !t.isEmpty {
                        Text(L.t(sv: "Spårnummer: \(t)", nb: "Sporingsnummer: \(t)"))
                            .font(.system(size: 14, weight: .semibold, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }

                    VStack(alignment: .leading, spacing: 14) {
                        stepRow(
                            n: 1,
                            title: L.t(sv: "Gå till närmaste ombud", nb: "Gå til nærmeste ombud")
                        )
                        stepRow(
                            n: 2,
                            title: L.t(sv: "Visa QR-koden ovan", nb: "Vis QR-koden over")
                        )
                        stepRow(
                            n: 3,
                            title: L.t(sv: "Ombudet skriver ut fraktsedeln", nb: "Ombud skriver ut fraktseddelen")
                        )
                        stepRow(
                            n: 4,
                            title: L.t(sv: "Lämna in paketet", nb: "Lever inn pakken")
                        )
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .padding(20)
                .padding(.bottom, 32)
            }
            .navigationTitle(L.t(sv: "Skriv ut på ombud", nb: "Skriv ut hos ombud"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 22))
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .presentationDetents([.large])
    }

    private func stepRow(n: Int, title: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(n)")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 28, height: 28)
                .background(Circle().fill(Color.black))
            Text(title)
                .font(.system(size: 16))
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
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
