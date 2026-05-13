import SwiftUI

/// Fast banner för säljaren över chattmeddelanden: order + QR + deadline.
struct SellerShippingBanner: View {
    let order: MarketplaceOrderRow
    var onShowQR: () -> Void = {}

    private var hasQrPayload: Bool {
        order.effectiveQrPayloadForAgent != nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "shippingbox.fill")
                    .font(.system(size: 16))
                Text(L.t(sv: "Dags att lämna in paketet", nb: "Tid å levere pakken"))
                    .font(.system(size: 14, weight: .bold))
                Spacer(minLength: 0)
            }

            if let deadline = order.shipByDeadlineDate {
                TimelineView(.periodic(from: .now, by: 60)) { context in
                    let remaining = deadline.timeIntervalSince(context.date)
                    if remaining > 0 {
                        let urgent = remaining < 24 * 60 * 60
                        Text(countdownText(remaining: remaining))
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(urgent ? Color.red : Color.primary)
                    } else {
                        Text(L.t(sv: "Sista inlämningsdatum har passerat — öppna ordern för nästa steg.", nb: "Siste leveringsfrist er passert — åpne ordren."))
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                    }
                }
            } else {
                Text(L.t(
                    sv: "Fraktsedeln finns under ordern så snart bokningen är klar.",
                    nb: "Fraktseddelen finnes under ordren når bokingen er klar."
                ))
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
            }

            HStack(spacing: 8) {
                NavigationLink(value: MarketplaceRoute.orderDetail(order)) {
                    Text(L.t(sv: "Skriv ut fraktsedel", nb: "Skriv ut fraktseddel"))
                        .font(.system(size: 13, weight: .semibold))
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color.black)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .buttonStyle(.plain)

                Button {
                    onShowQR()
                } label: {
                    Text(L.t(sv: "Visa QR-kod", nb: "Vis QR-kode"))
                        .font(.system(size: 13, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color(.systemGray5))
                        .foregroundStyle(hasQrPayload ? Color.primary : Color.secondary)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(!hasQrPayload)
            }
        }
        .padding(12)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func countdownText(remaining: TimeInterval) -> String {
        let total = max(0, Int(remaining))
        let days = total / 86_400
        let hours = (total % 86_400) / 3_600
        let bit: String = {
            if days > 0 { return hours > 0 ? "\(days) d \(hours) h" : "\(days) d" }
            if hours > 0 { return "\(hours) h" }
            let m = max(1, total / 60)
            return "\(m) min"
        }()
        return L.t(sv: "Lämna in inom \(bit)", nb: "Lever inn innen \(bit)")
    }
}
