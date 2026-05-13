import SwiftUI

/// Systemrad i annonschatten när köpet gått igenom (`purchase_completed`).
struct PurchaseSystemMessageCard: View {
    let message: DirectMessage
    let currentUserId: UUID?

    private var data: PurchaseCardData? { message.purchaseCardData }

    private var isSeller: Bool {
        guard let uid = currentUserId, let sid = data?.sellerId else { return false }
        return uid == sid
    }

    private var shipByDeadlineDate: Date? {
        guard let s = data?.shipByDeadline?.trimmingCharacters(in: .whitespacesAndNewlines), !s.isEmpty else {
            return nil
        }
        let frac = ISO8601DateFormatter()
        frac.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let plain = ISO8601DateFormatter()
        plain.formatOptions = [.withInternetDateTime]
        return frac.date(from: s) ?? plain.date(from: s)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(.green)
                Text(L.t(sv: "Köp genomfört", nb: "Kjøp gjennomført"))
                    .font(.system(size: 15, weight: .bold))
            }

            if let title = data?.listingTitle, !title.isEmpty {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .lineLimit(2)
            }

            if isSeller, let name = data?.buyerUsername, !name.isEmpty {
                Text(L.t(sv: "Köpare: \(name)", nb: "Kjøper: \(name)"))
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }

            if isSeller {
                Text(
                    L.t(
                        sv: "Din vara är såld! Här är nästa steg:\n1. Packa varan\n2. Skriv ut eller hämta fraktsedeln och lämna in paketet\n3. Lämna paketet inom 3 dagar",
                        nb: "Varen din er solgt! Neste steg:\n1. Pakk varen\n2. Skriv ut eller hent fraktseddelen og lever inn pakken\n3. Lever inn pakken innen 3 dager"
                    )
                )
                .font(.system(size: 13))
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)

                if let deadline = shipByDeadlineDate {
                    TimelineView(.periodic(from: .now, by: 60)) { context in
                        let remaining = deadline.timeIntervalSince(context.date)
                        if remaining > 0 {
                            let urgent = remaining < 24 * 60 * 60
                            Text(countdownText(remaining: remaining))
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(urgent ? Color.red : Color.primary)
                        } else {
                            Text(L.t(
                                sv: "Sista inlämningsdatum har passerat — öppna ordern för nästa steg.",
                                nb: "Siste leveringsfrist er passert — åpne ordren."
                            ))
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                        }
                    }
                }

                Text(L.t(
                    sv: "Pengarna hålls säkert av UP&DOWN tills köparen mottagit varan.",
                    nb: "Pengene holdes trygt av UP&DOWN til kjøperen har mottatt varen."
                ))
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            } else if !isSeller {
                Text(L.t(
                    sv: "Säljaren har nu 3 dagar på sig att skicka varan innan du får återbetalning.",
                    nb: "Selgeren har nå 3 dager på seg til å sende varen før du får refusjon."
                ))
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

                Text(L.t(
                    sv: "Vi betalar säljaren när du fått och godkänt produkten.",
                    nb: "Vi betaler selgeren når du har mottatt og godkjent produktet."
                ))
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            }

            if let ore = data?.amountItemOre {
                let kr = Int((Double(ore) / 100.0).rounded())
                Text(L.t(sv: "Pris: \(kr) kr", nb: "Pris: \(kr) kr"))
                    .font(.system(size: 13, weight: .semibold))
            }

            if let oid = data?.orderId {
                NavigationLink(value: MarketplaceRoute.orderDetailById(oid)) {
                    Text(L.t(sv: "Visa order", nb: "Vis ordre"))
                        .font(.system(size: 14, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color.black)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(14)
        .frame(maxWidth: UIScreen.main.bounds.width * 0.88, alignment: .leading)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
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
