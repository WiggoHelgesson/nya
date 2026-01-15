import Foundation
import UIKit

// MARK: - Food Scanner Service using ChatGPT (GPT-4o Vision)

final class FoodScannerService {
    static let shared = FoodScannerService()
    
    private let baseURL = URL(string: "https://api.openai.com/v1/chat/completions")!
    private let session: URLSession
    private let jsonDecoder: JSONDecoder
    private let jsonEncoder: JSONEncoder
    
    private init(session: URLSession = .shared) {
        self.session = session
        self.jsonDecoder = JSONDecoder()
        self.jsonEncoder = JSONEncoder()
    }
    
    // MARK: - AI Food Analysis (Scan Food Mode)
    
    struct AIFoodAnalysis: Codable {
        let name: String
        let calories: Int
        let protein: Int
        let carbs: Int
        let fat: Int
        let confidence: String // "high", "medium", "low"
        let description: String
    }
    
    func analyzeFoodImage(_ image: UIImage) async throws -> AIFoodAnalysis {
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            throw FoodScannerError.invalidImage
        }
        
        let base64Image = imageData.base64EncodedString()
        
        let systemPrompt = """
        Du är en expert på nutrition och matanalys. Din uppgift är att identifiera mat på bilden och uppskatta näringsvärden.
        
        Svara ENDAST med giltig JSON:
        {
          "name": "Maträttens namn på svenska",
          "calories": 450,
          "protein": 25,
          "carbs": 40,
          "fat": 15,
          "confidence": "high|medium|low",
          "description": "Kort beskrivning av vad du ser"
        }
        """
        
        let userPrompt = "Vad är detta för mat och vad är de ungefärliga näringsvärdena?"
        
        return try await performVisionRequest(base64Image: base64Image, systemPrompt: systemPrompt, userPrompt: userPrompt)
    }
    
    // MARK: - Food Label Analysis (Food Label Mode)
    
    struct FoodLabelAnalysis: Codable {
        let name: String?
        let caloriesPer100g: Int
        let proteinPer100g: Double
        let carbsPer100g: Double
        let fatPer100g: Double
        let fiberPer100g: Double?
        let sugarPer100g: Double?
    }
    
    func analyzeFoodLabelImage(_ image: UIImage) async throws -> FoodLabelAnalysis {
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            throw FoodScannerError.invalidImage
        }
        
        let base64Image = imageData.base64EncodedString()
        
        let systemPrompt = """
        Du är en expert på att läsa näringsdeklarationer. Extrahera värden per 100g från bilden.
        
        Svara ENDAST med giltig JSON:
        {
          "name": "Produktnamn (om synligt, annars null)",
          "caloriesPer100g": 350,
          "proteinPer100g": 12.5,
          "carbsPer100g": 60.0,
          "fatPer100g": 5.0,
          "fiberPer100g": 3.0,
          "sugarPer100g": 10.0
        }
        """
        
        let userPrompt = "Extrahera näringsvärden per 100g från denna etikett."
        
        return try await performVisionRequest(base64Image: base64Image, systemPrompt: systemPrompt, userPrompt: userPrompt)
    }
    
    // MARK: - Private Vision Helper
    
    private func performVisionRequest<T: Codable>(base64Image: String, systemPrompt: String, userPrompt: String) async throws -> T {
        guard let apiKey = EnvManager.shared.value(for: "OPENAI_API_KEY"), !apiKey.isEmpty else {
            throw FoodScannerError.missingAPIKey
        }
        
        let payload: [String: Any] = [
            "model": "gpt-4o-mini",
            "messages": [
                [
                    "role": "system",
                    "content": systemPrompt
                ],
                [
                    "role": "user",
                    "content": [
                        [
                            "type": "text",
                            "text": userPrompt
                        ],
                        [
                            "type": "image_url",
                            "image_url": [
                                "url": "data:image/jpeg;base64,\(base64Image)"
                            ]
                        ]
                    ]
                ]
            ],
            "max_tokens": 1000,
            "response_format": ["type": "json_object"]
        ]
        
        var request = URLRequest(url: baseURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        request.timeoutInterval = 60
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            throw FoodScannerError.apiError
        }
        
        let decodedResponse = try jsonDecoder.decode(ChatResponsePayload.self, from: data)
        guard let content = decodedResponse.choices.first?.message.content else {
            throw FoodScannerError.emptyResponse
        }
        
        guard let jsonData = content.data(using: .utf8) else {
            throw FoodScannerError.parsingFailed
        }
        
        return try jsonDecoder.decode(T.self, from: jsonData)
    }
    
    private struct ChatResponsePayload: Decodable {
        struct Choice: Decodable {
            struct Message: Decodable {
                let content: String
            }
            let message: Message
        }
        let choices: [Choice]
    }
}

// MARK: - Errors

enum FoodScannerError: LocalizedError {
    case missingAPIKey
    case invalidImage
    case apiError
    case emptyResponse
    case parsingFailed
    
    var errorDescription: String? {
        switch self {
        case .missingAPIKey: return "API-nyckel saknas"
        case .invalidImage: return "Ogiltig bild"
        case .apiError: return "Kunde inte kontakta AI-tjänsten"
        case .emptyResponse: return "Tomt svar från AI"
        case .parsingFailed: return "Kunde inte tolka svaret"
        }
    }
}

