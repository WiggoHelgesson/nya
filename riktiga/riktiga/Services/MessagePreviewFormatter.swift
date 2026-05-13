import Foundation

enum MessagePreviewFormatter {
    /// Converts technical/raw message payloads to inbox-friendly preview text.
    static func preview(from raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return "" }

        // Marketplace / offer system payloads inserted as JSON.
        if trimmed.hasPrefix("{"),
           let data = trimmed.data(using: .utf8),
           let payload = try? JSONDecoder().decode(KindPayload.self, from: data) {
            switch payload.kind {
            case "purchase_completed":
                return L.t(sv: "Köp genomfört", nb: "Kjøp gjennomført")
            case "offer_accepted":
                return L.t(sv: "Prisförslaget accepterades", nb: "Prisforslaget ble akseptert")
            case "offer_captured":
                return L.t(sv: "Köpet är slutfört", nb: "Kjøpet er fullført")
            case "shipping_label_ready":
                return L.t(sv: "Fraktsedel klar", nb: "Fraktseddel klar")
            case "shipping_in_transit":
                return L.t(sv: "Paketet är på väg", nb: "Pakken er på vei")
            case "seller_packed":
                return L.t(sv: "Säljaren har packat", nb: "Selgeren har pakket")
            default:
                break
            }
        }

        // Existing gym invite payloads.
        if trimmed.hasPrefix("{"),
           trimmed.contains("\"gym\""),
           trimmed.contains("\"date\""),
           trimmed.contains("\"time\"") {
            if let data = trimmed.data(using: .utf8),
               let invite = try? JSONDecoder().decode(GymInviteData.self, from: data) {
                return L.t(
                    sv: "Skickade ett träningsförslag: \(invite.resolvedActivityType.displayName) \(invite.resolvedActivityType.emoji)",
                    nb: "Sendte et treningsforslag: \(invite.resolvedActivityType.displayName) \(invite.resolvedActivityType.emoji)"
                )
            }
            return L.t(sv: "Skickade ett träningsförslag", nb: "Sendte et treningsforslag")
        }

        if trimmed == "accepted" {
            return L.t(sv: "Godkände träningsförslaget", nb: "Godkjente treningsforslaget")
        }
        if trimmed == "declined" {
            return L.t(sv: "Avböjde träningsförslaget", nb: "Avslo treningsforslaget")
        }

        return raw
    }

    private struct KindPayload: Decodable {
        let kind: String?
    }
}
