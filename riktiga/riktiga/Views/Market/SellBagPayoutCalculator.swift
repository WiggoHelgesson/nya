import SwiftUI

/// Slider-baserad kalkylator som visar hur mycket en säljare får tillbaka
/// per vara via Up&Down-påsen. Self-contained — används både på produkt-
/// detaljsidan för påsen och på Nybegagnat-fliken i Produkter-feeden.
///
/// Formel: säljaren får 60 % upp till 4 000 kr. Över det ökar andelen med
/// 1 % per 100 kr, upp till maximalt 85 %.
struct SellBagPayoutCalculator: View {
    private let priceMin = 50
    private let priceMax = 10000
    private let priceStep = 50
    private let baseKeepPercent = 60
    private let maxKeepPercent = 85
    private let bonusStartPrice = 4000
    private let bonusStepPrice = 100

    @State private var sellPrice: Double = 500

    private var sellKeepPercent: Int {
        let price = Int(sellPrice)
        guard price > bonusStartPrice else { return baseKeepPercent }
        let bonus = (price - bonusStartPrice) / bonusStepPrice
        return min(maxKeepPercent, baseKeepPercent + bonus)
    }

    private var sellReturnSEK: Int {
        Int((Double(Int(sellPrice)) * Double(sellKeepPercent) / 100).rounded())
    }

    var body: some View {
        VStack(alignment: .center, spacing: 16) {
            Text(L.t(
                sv: "Räkna på vad du får tillbaka per vara",
                nb: "Regn ut hva du får tilbake per vare"
            ))
            .font(.system(size: 16, weight: .bold))
            .foregroundColor(.primary)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)

            VStack(spacing: 4) {
                Text("\(Int(sellPrice)) SEK")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                    .contentTransition(.numericText())
                    .animation(.snappy, value: sellPrice)

                Text(L.t(sv: "Vi säljer varan för", nb: "Vi selger varen for"))
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)

            Slider(
                value: $sellPrice,
                in: Double(priceMin)...Double(priceMax),
                step: Double(priceStep)
            )
            .tint(.primary)

            HStack(alignment: .top, spacing: 12) {
                VStack(spacing: 4) {
                    Text("\(sellReturnSEK)")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                        .contentTransition(.numericText())
                        .animation(.snappy, value: sellReturnSEK)
                    Text(L.t(sv: "Du får tillbaka (SEK)", nb: "Du får tilbake (SEK)"))
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)

                VStack(spacing: 4) {
                    Text("\(sellKeepPercent)")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                        .contentTransition(.numericText())
                        .animation(.snappy, value: sellKeepPercent)
                    Text(L.t(sv: "Du får tillbaka (%)", nb: "Du får tilbake (%)"))
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
            }

            Text(L.t(
                sv: "Upp till 4 000 kr = 60%. Över 4 000 kr ökar andelen med 1% per 100 kr, upp till max 85%.",
                nb: "Opp til 4 000 kr = 60%. Over 4 000 kr øker andelen med 1% per 100 kr, opp til maks 85%."
            ))
            .font(.system(size: 11))
            .foregroundColor(.secondary)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
    }
}
