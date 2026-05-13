import Foundation
import UIKit

/// GPT-4o-mini vision helpers för ny annons-wizard (kategori + rubrik/beskrivning).
enum ListingDraftAIService {
    private static let baseURL = URL(string: "https://api.openai.com/v1/chat/completions")!
    private static let session: URLSession = SupabaseConfig.urlSession

    struct TitleDescriptionResult {
        let title: String
        let description: String
    }

    /// Bygger `selectedCategory` som i `SellSubcategoryPickerView` / `SellCategoryPickerView`.
    static func formatSelectedCategory(topCategoryId: String, subCategoryId: String?) -> String? {
        guard let top = SportCategory.find(id: topCategoryId) else { return nil }
        if top.subcategories.isEmpty {
            return top.displayName
        }
        guard let sid = subCategoryId?.trimmingCharacters(in: .whitespacesAndNewlines), !sid.isEmpty,
              let sub = top.subcategories.first(where: { $0.id == sid })
        else {
            return nil
        }
        return "\(top.displayName) / \(sub.displayName)"
    }

    /// Returnerar normaliserad `selectedCategory`-sträng eller `nil` vid fel/ogiltigt svar.
    static func suggestCategory(images: [UIImage]) async throws -> String? {
        guard let apiKey = EnvManager.shared.value(for: "OPENAI_API_KEY"), !apiKey.isEmpty else {
            throw ListingDraftAIError.missingApiKey
        }
        let subset = Array(images.prefix(4))
        guard !subset.isEmpty else { throw ListingDraftAIError.noImages }

        let taxonomyJSON = Self.buildTaxonomyJSON()

        var content: [[String: Any]] = [[
            "type": "text",
            "text": """
            Du ser foton av begagnad sportutrustning till en annons. Välj den mest passande kategorin från listan nedan.

            KATEGORIER (JSON — använd exakt id:n):
            \(taxonomyJSON)

            Svara ENDAST med JSON:
            {"top_category_id":"<id>","sub_category_id":"<id eller tom sträng om endast top>"}

            Om en top-kategori har underkategorier MÅSTE du välja en underkategori (sub_category_id).
            Om top saknar underkategorier: sätt sub_category_id till "".
            """
        ]]

        for img in subset {
            guard let data = resizeAndEncode(image: img, maxDimension: 768, quality: 0.72) else { continue }
            let dataURL = "data:image/jpeg;base64,\(data.base64EncodedString())"
            content.append([
                "type": "image_url",
                "image_url": ["url": dataURL, "detail": "low"]
            ])
        }

        let body: [String: Any] = [
            "model": "gpt-4o-mini",
            "messages": [
                ["role": "system", "content": "Du är en noggrann produktklassificerare. Svara bara med giltig JSON."],
                ["role": "user", "content": content]
            ],
            "temperature": 0.2,
            "max_tokens": 120,
            "response_format": ["type": "json_object"]
        ]

        let raw = try await performChat(body: body, apiKey: apiKey)
        guard let data = raw.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let topId = obj["top_category_id"] as? String,
              !topId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else { return nil }

        let top = topId.trimmingCharacters(in: .whitespacesAndNewlines)
        let subRaw = (obj["sub_category_id"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let sub: String? = subRaw.isEmpty ? nil : subRaw

        guard let formatted = formatSelectedCategory(topCategoryId: top, subCategoryId: sub) else {
            return nil
        }
        return formatted
    }

    static func suggestTitleDescription(images: [UIImage], categoryDisplayName: String) async throws -> TitleDescriptionResult {
        guard let apiKey = EnvManager.shared.value(for: "OPENAI_API_KEY"), !apiKey.isEmpty else {
            throw ListingDraftAIError.missingApiKey
        }
        let subset = Array(images.prefix(4))
        guard !subset.isEmpty else { throw ListingDraftAIError.noImages }

        var content: [[String: Any]] = [[
            "type": "text",
            "text": """
            Skriv en säljande men ärlig annonsrubrik och beskrivning på svenska för denna sportprodukt.
            Kategori (vägledning): \(categoryDisplayName)

            Rubrik: max 65 tecken, ingen ALL CAPS.
            Beskrivning: max 480 tecken, konkret skick, vad som ingår, mått om synligt.

            Svara ENDAST med JSON:
            {"title":"...","description":"..."}
            """
        ]]

        for img in subset {
            guard let data = resizeAndEncode(image: img, maxDimension: 768, quality: 0.72) else { continue }
            let dataURL = "data:image/jpeg;base64,\(data.base64EncodedString())"
            content.append([
                "type": "image_url",
                "image_url": ["url": dataURL, "detail": "low"]
            ])
        }

        let body: [String: Any] = [
            "model": "gpt-4o-mini",
            "messages": [
                ["role": "system", "content": "Du skriver annonser för svensk secondhand-sportmarknad. Bara JSON."],
                ["role": "user", "content": content]
            ],
            "temperature": 0.35,
            "max_tokens": 500,
            "response_format": ["type": "json_object"]
        ]

        let raw = try await performChat(body: body, apiKey: apiKey)
        guard let data = raw.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let title = obj["title"] as? String,
              let description = obj["description"] as? String
        else {
            throw ListingDraftAIError.parseFailed
        }

        let t = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let d = description.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty, !d.isEmpty else { throw ListingDraftAIError.parseFailed }

        return TitleDescriptionResult(
            title: String(t.prefix(70)),
            description: String(d.prefix(500))
        )
    }

    // MARK: - Private

    private static func buildTaxonomyJSON() -> String {
        let payload: [[String: Any]] = SportCategory.all.map { cat in
            [
                "top_id": cat.id,
                "top_name_sv": cat.nameSV,
                "subs": cat.subcategories.map { [
                    "id": $0.id,
                    "name_sv": $0.nameSV
                ]}
            ]
        }
        guard let data = try? JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted]),
              let s = String(data: data, encoding: .utf8) else {
            return "[]"
        }
        return s
    }

    private static func performChat(body: [String: Any], apiKey: String) async throws -> String {
        guard let bodyData = try? JSONSerialization.data(withJSONObject: body) else {
            throw ListingDraftAIError.encodingFailed
        }
        var request = URLRequest(url: baseURL)
        request.httpMethod = "POST"
        request.timeoutInterval = 90
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = bodyData

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw ListingDraftAIError.httpError((response as? HTTPURLResponse)?.statusCode ?? 0)
        }
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let first = choices.first,
              let message = first["message"] as? [String: Any],
              let rawContent = message["content"] as? String
        else {
            throw ListingDraftAIError.parseFailed
        }
        return rawContent.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func resizeAndEncode(image: UIImage, maxDimension: CGFloat, quality: CGFloat) -> Data? {
        let size = image.size
        guard size.width > 0, size.height > 0 else { return nil }
        let scale = min(maxDimension / size.width, maxDimension / size.height, 1)
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        UIGraphicsBeginImageContextWithOptions(newSize, true, 1)
        image.draw(in: CGRect(origin: .zero, size: newSize))
        let resized = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return resized?.jpegData(compressionQuality: quality)
    }
}

enum ListingDraftAIError: LocalizedError {
    case missingApiKey
    case noImages
    case encodingFailed
    case parseFailed
    case httpError(Int)

    var errorDescription: String? {
        switch self {
        case .missingApiKey:
            return L.t(sv: "AI är inte konfigurerad.", nb: "AI er ikke konfigurert.")
        case .noImages:
            return L.t(sv: "Lägg till bilder först.", nb: "Legg til bilder først.")
        case .encodingFailed, .parseFailed:
            return L.t(sv: "Kunde inte läsa AI-svaret.", nb: "Kunne ikke lese AI-svaret.")
        case .httpError(let c):
            return L.t(sv: "Nätverksfel (\(c))", nb: "Nettverksfeil (\(c))")
        }
    }
}
