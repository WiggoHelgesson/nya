import Foundation
import UIKit

/// Verifies that the photos uploaded with a "Ny annons"-flödet actually depict
/// a real product (any kind of product counts). The bar is intentionally low —
/// we want to auto-approve as many listings as possible and only fall back to
/// manual review when the images are clearly junk (selfies, random scenery,
/// blank screens, memes, etc.).
final class ListingImageVerificationService {
    static let shared = ListingImageVerificationService()

    struct Result {
        let isProduct: Bool
        let confidence: Double
        let reason: String
    }

    private let baseURL = URL(string: "https://api.openai.com/v1/chat/completions")!
    private let session: URLSession

    private init(session: URLSession = .shared) {
        self.session = session
    }

    /// Runs the "is this a product photo?" check against up to `maxImages`
    /// images. On any error (no API key, network failure, bad parsing) we
    /// return `isProduct = false` so the submission falls back to manual
    /// review — never auto-approve on an error.
    func verify(images: [UIImage], maxImages: Int = 3) async -> Result {
        let subset = Array(images.prefix(maxImages))
        guard !subset.isEmpty else {
            return Result(isProduct: false, confidence: 0, reason: "no_images")
        }

        guard
            let apiKey = EnvManager.shared.value(for: "OPENAI_API_KEY"),
            !apiKey.isEmpty
        else {
            return Result(isProduct: false, confidence: 0, reason: "missing_api_key")
        }

        let encodedImages: [String] = subset.compactMap { image in
            guard let data = resizeAndEncode(image: image, maxDimension: 768, quality: 0.7) else {
                return nil
            }
            return "data:image/jpeg;base64,\(data.base64EncodedString())"
        }

        guard !encodedImages.isEmpty else {
            return Result(isProduct: false, confidence: 0, reason: "encode_failed")
        }

        let systemPrompt = """
        You are a friendly, extremely lenient moderator for a Swedish peer-to-peer sports-gear marketplace. Users upload photos of items they want to sell. Your only job: decide if the photos contain ANY identifiable product that someone could plausibly sell (clothing, shoes, gear, bikes, accessories, equipment, gadgets, even partially visible items, items in packaging, items on a floor / bed / hanger etc.).

        Be VERY generous. A blurry photo, a mirror selfie where the user is wearing the product, a photo taken at an odd angle, or a product lying on a messy bed all count as a product. Only reject if the images clearly contain NO product at all — e.g. pure landscape shots, random selfies without any item, memes/screenshots of text, blank/black/white screens, food, animals alone, or clearly off-topic content.

        Respond with ONLY JSON in this exact shape (no markdown):
        {"is_product": true|false, "confidence": 0.0-1.0, "reason": "short swedish explanation"}
        """

        var content: [[String: Any]] = [[
            "type": "text",
            "text": "Granska dessa foton från en sport-annons. Svara med JSON enligt instruktionen."
        ]]
        for dataURL in encodedImages {
            content.append([
                "type": "image_url",
                "image_url": [
                    "url": dataURL,
                    "detail": "low"
                ]
            ])
        }

        let body: [String: Any] = [
            "model": "gpt-4o-mini",
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": content]
            ],
            "temperature": 0.1,
            "max_tokens": 200,
            "response_format": ["type": "json_object"]
        ]

        guard let bodyData = try? JSONSerialization.data(withJSONObject: body) else {
            return Result(isProduct: false, confidence: 0, reason: "encode_body_failed")
        }

        var request = URLRequest(url: baseURL)
        request.httpMethod = "POST"
        request.timeoutInterval = 30
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = bodyData

        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                let status = (response as? HTTPURLResponse)?.statusCode ?? 0
                print("ℹ️ ListingImageVerification non-200 status: \(status)")
                return Result(isProduct: false, confidence: 0, reason: "http_\(status)")
            }

            guard
                let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                let choices = json["choices"] as? [[String: Any]],
                let first = choices.first,
                let message = first["message"] as? [String: Any],
                let rawContent = message["content"] as? String,
                let contentData = rawContent.data(using: .utf8),
                let parsed = try? JSONSerialization.jsonObject(with: contentData) as? [String: Any]
            else {
                return Result(isProduct: false, confidence: 0, reason: "parse_failed")
            }

            let isProduct = (parsed["is_product"] as? Bool) ?? false
            let confidence = (parsed["confidence"] as? Double) ?? {
                if let intValue = parsed["confidence"] as? Int {
                    return Double(intValue)
                }
                if let str = parsed["confidence"] as? String, let v = Double(str) {
                    return v
                }
                return 0
            }()
            let reason = (parsed["reason"] as? String) ?? ""

            return Result(isProduct: isProduct, confidence: confidence, reason: reason)
        } catch {
            print("ℹ️ ListingImageVerification network/parse error: \(error)")
            return Result(isProduct: false, confidence: 0, reason: "exception")
        }
    }

    private func resizeAndEncode(image: UIImage, maxDimension: CGFloat, quality: CGFloat) -> Data? {
        let longest = max(image.size.width, image.size.height)
        let resized: UIImage
        if longest > maxDimension {
            let scale = maxDimension / longest
            let newSize = CGSize(
                width: floor(image.size.width * scale),
                height: floor(image.size.height * scale)
            )
            let renderer = UIGraphicsImageRenderer(size: newSize)
            resized = renderer.image { _ in
                image.draw(in: CGRect(origin: .zero, size: newSize))
            }
        } else {
            resized = image
        }
        return resized.jpegData(compressionQuality: quality)
    }
}
