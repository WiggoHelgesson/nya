import Foundation

/// Single source of truth for buyer-side pricing in the community marketplace.
///
/// Fee model (matches `create-marketplace-payment-intent` edge function):
///   item         = priceSEK
///   platformFee  = priceSEK * 5 %  +  7.50 kr      (buyer-protection fee)
///   shipping     = 35.65 kr                         (flat, kept by platform)
///   buyerTotal   = item + platformFee + shipping
///   sellerPayout = item                            (seller keeps 100 %)
enum MarketplacePricing {
    static let platformFeePercent: Double = 0.05
    static let buyerProtectionFlatSEK: Double = 7.5
    /// Default fallback shipping fee when no marketplace rate has been picked
    /// yet. Kept for back-compat with legacy call sites; the multi-carrier
    /// flow always passes a `shippingOre` from the carrier picker.
    static let shippingFlatSEK: Double = 49.0

    /// Computes the platform fee (5 % + 7.50 kr) in kronor for a given sell price.
    static func platformFee(priceSEK: Int) -> Double {
        Double(priceSEK) * platformFeePercent + buyerProtectionFlatSEK
    }

    /// Flat shipping fee in kronor — fallback when no rate is provided.
    static func shipping() -> Double { shippingFlatSEK }

    /// Total amount the buyer is charged, in kronor (item + fee + shipping).
    /// Pass `shippingOre` (from the carrier picker) for the dynamic rate.
    /// När ingen `shippingOre` skickas in lägger vi *inte* på fraktet i
    /// totalen — tidigare gjorde vi en 49 kr-fallback som dök upp på
    /// annonser och listkort vilket fick priset att se ut att inkludera
    /// frakt även innan köparen kommit till checkouten. Frakt syns nu
    /// först när ett fraktpris har valts inne i checkout/prisförslag.
    static func buyerTotal(priceSEK: Int, shippingOre: Int? = nil) -> Double {
        let shippingSEK: Double
        if let shippingOre, shippingOre > 0 {
            shippingSEK = Double(shippingOre) / 100.0
        } else {
            shippingSEK = 0
        }
        return Double(priceSEK) + platformFee(priceSEK: priceSEK) + shippingSEK
    }

    /// Total amount the buyer is charged, rounded to the nearest öre.
    static func buyerTotalOre(priceSEK: Int, shippingOre: Int? = nil) -> Int {
        Int((buyerTotal(priceSEK: priceSEK, shippingOre: shippingOre) * 100).rounded())
    }

    /// Formats the buyer total as `"1234,56 kr"` (Swedish convention).
    static func buyerTotalFormatted(priceSEK: Int, shippingOre: Int? = nil) -> String {
        formatSEK(buyerTotal(priceSEK: priceSEK, shippingOre: shippingOre))
    }

    /// Formats the platform fee as `"57,50 kr"`.
    static func platformFeeFormatted(priceSEK: Int) -> String {
        formatSEK(platformFee(priceSEK: priceSEK))
    }

    /// Formats the flat shipping fee as `"49,00 kr"`.
    static func shippingFormatted() -> String {
        formatSEK(shippingFlatSEK)
    }

    /// Formats a chosen shipping amount (in öre) as `"49,00 kr"`.
    static func shippingFormatted(shippingOre: Int) -> String {
        formatSEK(Double(shippingOre) / 100.0)
    }

    static func formatSEK(_ amount: Double) -> String {
        let whole = Int(amount)
        let cents = Int(((amount - Double(whole)) * 100).rounded())
        return String(format: "%d,%02d kr", whole, abs(cents))
    }
}
