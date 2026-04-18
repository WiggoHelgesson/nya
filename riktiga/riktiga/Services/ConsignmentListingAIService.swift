import Foundation
import UIKit

enum ConsignmentAIError: LocalizedError {
    case missingAPIKey
    case badResponse
    case parseFailed

    var errorDescription: String? {
        switch self {
        case .missingAPIKey: return "OpenAI API-nyckel saknas."
        case .badResponse: return "Kunde inte nå AI-tjänsten."
        case .parseFailed: return "Kunde inte tolka svaret från AI."
        }
    }
}

final class ConsignmentListingAIService {
    static let shared = ConsignmentListingAIService()

    private let url = URL(string: "https://api.openai.com/v1/chat/completions")!
    private let model = "gpt-4o"

    private lazy var longSession: URLSession = {
        let c = URLSessionConfiguration.default
        c.timeoutIntervalForRequest = 90
        c.timeoutIntervalForResource = 120
        return URLSession(configuration: c)
    }()

    private init() {}

    // MARK: - Category suggestions (1 image)

    /// Broad, non golf-biased fallback if the model answer cannot be parsed
    /// or filtered to valid categories. The user can still tap "Välj en annan
    /// kategori" to pick the exact one.
    private let fallbackCategorySuggestions: [String] = [
        "Övrigt / Sport och fritid",
        "Golf / Driver",
        "Träning / Löparskor"
    ]

    func suggestCategories(firstImageJPEG: Data) async throws -> [String] {
        let base64 = firstImageJPEG.base64EncodedString()
        let catalogue = SellConsignmentCategories.all.joined(separator: "\n")
        let systemPrompt = """
        Du är en bilddigenkänningsexpert för begagnad sport- och golfutrustning.
        Svara ALLTID med enbart giltig JSON. Inga markdown-fences. Inga förklaringar.
        """
        let userPrompt = """
        Identifiera först vad som visas på bilden (t.ex. löparsko, golfklubba, cykelhjälm).
        Välj sedan exakt tre kategorier från listan nedan som bäst passar varan.
        Ordna från mest trolig först. Varje sträng måste vara ordagrant en rad från listan (inklusive snedstreck).
        Om du är osäker på vad det är, inkludera "Övrigt / Sport och fritid" som tredje alternativ.

        Svara ENDAST med JSON i formatet: {"suggestions":["...","...","..."]}

        Lista:
        \(catalogue)
        """

        let raw = try await chatJSON(
            messages: [
                systemMessage(text: systemPrompt),
                userMessage(text: userPrompt, imageJPEGBase64: [base64])
            ],
            maxTokens: 200
        )
        let clean = raw
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard let data = clean.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let arr = obj["suggestions"] as? [String] else {
            print("⚠️ Category AI raw response: \(raw)")
            throw ConsignmentAIError.parseFailed
        }
        let valid = Set(SellConsignmentCategories.all)
        let filtered = arr.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { valid.contains($0) }
        if filtered.count >= 3 { return Array(filtered.prefix(3)) }
        if !filtered.isEmpty {
            var merged = filtered
            for c in fallbackCategorySuggestions where merged.count < 3 {
                if !merged.contains(c) { merged.append(c) }
            }
            return Array(merged.prefix(3))
        }
        return fallbackCategorySuggestions
    }

    // MARK: - Full listing analysis

    func analyzeListing(imagesJPEG: [Data], category: String) async throws -> SellAnalysisResult {
        guard !imagesJPEG.isEmpty else { throw ConsignmentAIError.badResponse }
        let bases = imagesJPEG.map { $0.base64EncodedString() }
        let prompt = """
        Du är expert på second hand av sport- och golfutrustning i Sverige.
        Användaren har valt kategori: "\(category)".
        Analysera ALLA bifogade bilder. Identifiera märke/modell om möjligt.
        Uppskatta ett rimligt försäljningsprisintervall i SEK (blocketpriser) och ett lägre intervall för vad säljaren typiskt får ut efter avgifter/plattformsandel (ungefär 55–65 procent av försäljningspriset, anpassat efter typ av vara).

        Svara ENDAST med JSON (inga markdown-fences):
        {
          "product_name": "Kort produktnamn",
          "condition": "Ett av: Nytt skick, Mycket bra skick, Bra skick, Okej skick, Tydligt använt",
          "price_range_label": "1500–2200 kr",
          "title": "Säljsrubrik max 80 tecken, lockande",
          "description": "2–4 meningar på svenska, ärlig och säljande",
          "brand_guess": "Varumärke eller Okänt",
          "seller_payout_range": "900–1300 kr"
        }
        """

        let raw = try await chatJSON(
            messages: [
                userMessage(text: prompt, imageJPEGBase64: bases)
            ],
            maxTokens: 900
        )
        let clean = raw
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard let data = clean.data(using: .utf8) else { throw ConsignmentAIError.parseFailed }
        let dec = JSONDecoder()
        if let r = try? dec.decode(SellAnalysisResult.self, from: data) { return r }
        if let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            return SellAnalysisResult(
                productName: obj["product_name"] as? String ?? "",
                condition: obj["condition"] as? String ?? "",
                priceRangeLabel: obj["price_range_label"] as? String ?? "",
                title: obj["title"] as? String ?? "",
                description: obj["description"] as? String ?? "",
                brandGuess: obj["brand_guess"] as? String ?? "",
                sellerPayoutRange: obj["seller_payout_range"] as? String ?? ""
            )
        }
        throw ConsignmentAIError.parseFailed
    }

    // MARK: - OpenAI request

    private func systemMessage(text: String) -> [String: Any] {
        return ["role": "system", "content": text]
    }

    private func userMessage(text: String, imageJPEGBase64: [String]) -> [String: Any] {
        var parts: [[String: Any]] = [["type": "text", "text": text]]
        for b64 in imageJPEGBase64 {
            parts.append([
                "type": "image_url",
                "image_url": [
                    "url": "data:image/jpeg;base64,\(b64)",
                    "detail": "high"
                ]
            ])
        }
        return ["role": "user", "content": parts]
    }

    private func chatJSON(messages: [[String: Any]], maxTokens: Int) async throws -> String {
        guard let apiKey = EnvManager.shared.value(for: "OPENAI_API_KEY"), !apiKey.isEmpty else {
            throw ConsignmentAIError.missingAPIKey
        }
        let body: [String: Any] = [
            "model": model,
            "messages": messages,
            "max_tokens": maxTokens,
            "response_format": ["type": "json_object"]
        ]
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, _) = try await longSession.data(for: req)
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let first = choices.first,
              let message = first["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw ConsignmentAIError.badResponse
        }
        return content
    }
}
