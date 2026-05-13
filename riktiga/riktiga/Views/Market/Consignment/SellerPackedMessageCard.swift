import SwiftUI

/// Systemmeddelande `seller_packed` i annonschatten.
struct SellerPackedMessageCard: View {
    let message: DirectMessage

    private var data: SellerPackedCardData? { message.sellerPackedData }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "shippingbox.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(.green)
                Text(L.t(sv: "Säljaren har packat varan", nb: "Selgeren har pakket varen"))
                    .font(.system(size: 15, weight: .bold))
            }
            if let t = data?.listingTitle?.trimmingCharacters(in: .whitespacesAndNewlines), !t.isEmpty {
                Text(t)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            Text(L.t(
                sv: "Säljaren skickar inom kort.",
                nb: "Selgeren sender snart."
            ))
            .font(.system(size: 13))
            .foregroundStyle(.secondary)

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
}
