import Foundation

enum UppyChatError: LocalizedError {
    case missingAPIKey
    case invalidResponse
    case emptyResponse
    case decodingFailed
    
    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "Saknar API-nyckel för UPPY."
        case .invalidResponse:
            return "Ogiltigt svar från UPPY."
        case .emptyResponse:
            return "UPPY kunde inte skapa ett svar."
        case .decodingFailed:
            return "Misslyckades att tolka svaret från UPPY."
        }
    }
}

final class UppyChatService {
    static let shared = UppyChatService()
    
    private let baseURL = URL(string: "https://api.openai.com/v1/chat/completions")!
    private let session: URLSession
    private let jsonDecoder: JSONDecoder
    private let jsonEncoder: JSONEncoder
    
    private init(session: URLSession = .shared) {
        self.session = session
        self.jsonDecoder = JSONDecoder()
        self.jsonEncoder = JSONEncoder()
    }
    
    struct ChatMessagePayload: Encodable {
        let role: String
        let content: String
    }
    
    struct ChatRequestPayload: Encodable {
        let model: String
        let messages: [ChatMessagePayload]
        let temperature: Double
        let max_tokens: Int
    }
    
    struct ChatResponsePayload: Decodable {
        struct Choice: Decodable {
            struct Message: Decodable {
                let role: String
                let content: String
            }
            let index: Int
            let message: Message
        }
        let choices: [Choice]
    }
    
    func sendConversation(messages: [UppyChatMessage]) async throws -> String {
        guard let apiKey = EnvManager.shared.value(for: "OPENAI_API_KEY"), !apiKey.isEmpty else {
            throw UppyChatError.missingAPIKey
        }
        
        let payloadMessages = messages.map { message in
            ChatMessagePayload(role: message.role.apiRole, content: message.content)
        }
        
        let payload = ChatRequestPayload(
            model: "gpt-4o-mini",
            messages: payloadMessages,
            temperature: 0.7,
            max_tokens: 400
        )
        
        var request = URLRequest(url: baseURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 45
        
        do {
            request.httpBody = try jsonEncoder.encode(payload)
        } catch {
            throw error
        }
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            if let jsonString = String(data: data, encoding: .utf8) {
                print("❌ UPPY API error: \(jsonString)")
            }
            throw UppyChatError.invalidResponse
        }
        
        do {
            let decoded = try jsonDecoder.decode(ChatResponsePayload.self, from: data)
            guard let message = decoded.choices.first?.message.content.trimmingCharacters(in: .whitespacesAndNewlines),
                  !message.isEmpty else {
                throw UppyChatError.emptyResponse
            }
            return message
        } catch {
            throw UppyChatError.decodingFailed
        }
    }
    
    /// Generate a short daily insight based on user statistics
    func generateInsight(context: String) async throws -> String {
        guard let apiKey = EnvManager.shared.value(for: "OPENAI_API_KEY"), !apiKey.isEmpty else {
            throw UppyChatError.missingAPIKey
        }
        
        let systemMessage = ChatMessagePayload(
            role: "system",
            content: """
            Du är UPPY, en personlig träningsassistent. Skapa EN kort, personlig och uppmuntrande mening (max 12 ord) baserat på användarens statistik.
            Fokusera på:
            - Nuvarande streak
            - Progress mot nästa nivå (XP)
            - Veckans/månadens prestationer
            
            Avsluta ALLTID med "//UPPY".
            Exempel:
            - "Du är 5 dagar i streak, fortsätt så! //UPPY"
            - "Bara 800 XP kvar till nästa nivå! //UPPY"
            - "Du sprang 15.2 km denna vecka, grym insats! //UPPY"
            """
        )
        
        let userMessage = ChatMessagePayload(role: "user", content: context)
        
        let payload = ChatRequestPayload(
            model: "gpt-4o-mini",
            messages: [systemMessage, userMessage],
            temperature: 0.8,
            max_tokens: 50
        )
        
        var request = URLRequest(url: baseURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 15
        
        request.httpBody = try jsonEncoder.encode(payload)
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw UppyChatError.invalidResponse
        }
        
        let decoded = try jsonDecoder.decode(ChatResponsePayload.self, from: data)
        guard let message = decoded.choices.first?.message.content.trimmingCharacters(in: .whitespacesAndNewlines),
              !message.isEmpty else {
            throw UppyChatError.emptyResponse
        }
        
        return message
    }
}

