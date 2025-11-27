import Foundation

struct GeneratedWorkoutResult {
    let title: String
    let focus: String
    let estimatedDuration: Int
    let entries: [GeneratedWorkoutEntry]
    let missingExercises: [String]
}

final class WorkoutGeneratorService {
    static let shared = WorkoutGeneratorService()
    
    private let openAIURL = URL(string: "https://api.openai.com/v1/chat/completions")!
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()
    
    private init() {}
    
    func generateWorkout(prompt: String) async throws -> GeneratedWorkoutResult {
        let library = try await ExerciseDBService.shared.fetchAllExercises()
        let summary = buildExerciseSummary(from: library)
        let plan = try await requestPlan(prompt: prompt, exerciseSummary: summary)
        return resolvePlan(plan, with: library)
    }
    
    private func requestPlan(prompt: String, exerciseSummary: String) async throws -> WorkoutGeneratorPlan {
        guard let apiKey = EnvManager.shared.value(for: "OPENAI_API_KEY"),
              !apiKey.isEmpty else {
            throw UppyChatError.missingAPIKey
        }
        
        let systemMessage = ChatMessage(role: "system", content: """
        Du är UPPY, en svensk PT med tillgång till över 1300 övningar i Up&Downs bibliotek (ExerciseDB).
        Skapa detaljerade gympass baserat på användarens önskemål och listan nedan.
        Krav:
        - Returnera ENBART giltig JSON utan extra text.
        - Totalt 6-10 övningar beroende på tid, nivå och mål.
        - Variera muskelgrupper och utrustning.
        - Tilldela rimligt antal set (3-5) och reps (5-15) per övning.
        - Ange bodyPart och equipment (på engelska) som matchar ExerciseDB (t.ex. \"chest\", \"upper arms\", \"barbell\", \"dumbbell\", \"body weight\", \"machine\").
        - Föreslå vila i sekunder mellan set.
        - Prioritera endast övningar som finns i biblioteket nedan.
        
        Tillgängliga övningskategorier & exempel:
        \(exerciseSummary)
        """)
        
        let userMessage = ChatMessage(role: "user", content: """
        Användarens instruktion (max 100 ord):
        \"\(prompt.trimmingCharacters(in: .whitespacesAndNewlines))\"
        
        Returnera JSON på följande format:
        {
          "title": "Kort beskrivning",
          "focus": "Vilket fokus passet har",
          "estimatedDuration": 55,
          "exercises": [
            {
              "name": "Barbell Bench Press",
              "bodyPart": "chest",
              "equipment": "barbell",
              "sets": 4,
              "reps": 10,
              "restSeconds": 90,
              "notes": "Kort tips"
            }
          ]
        }
        """)
        
        let payload = ChatRequest(model: "gpt-4o-mini",
                                  messages: [systemMessage, userMessage],
                                  temperature: 0.7,
                                  maxTokens: 600)
        
        var request = URLRequest(url: openAIURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try encoder.encode(payload)
        request.timeoutInterval = 40
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            if let raw = String(data: data, encoding: .utf8) {
                print("❌ WorkoutGeneratorService error: \(raw)")
            }
            throw UppyChatError.invalidResponse
        }
        
        let decoded = try decoder.decode(ChatResponse.self, from: data)
        guard let rawMessage = decoded.choices.first?.message.content.trimmingCharacters(in: .whitespacesAndNewlines),
              !rawMessage.isEmpty else {
            throw UppyChatError.emptyResponse
        }
        
        let cleanedJSON = WorkoutGeneratorService.cleanJSON(from: rawMessage)
        guard let jsonData = cleanedJSON.data(using: .utf8) else {
            throw UppyChatError.decodingFailed
        }
        
        do {
            return try decoder.decode(WorkoutGeneratorPlan.self, from: jsonData)
        } catch {
            print("❌ Failed to decode workout plan: \(error)")
            throw UppyChatError.decodingFailed
        }
    }
    
    private func resolvePlan(_ plan: WorkoutGeneratorPlan, with library: [ExerciseDBExercise]) -> GeneratedWorkoutResult {
        var normalizedMap: [String: ExerciseDBExercise] = [:]
        for exercise in library {
            let key = Self.normalizedKey(for: exercise.name)
            if normalizedMap[key] == nil {
                normalizedMap[key] = exercise
            }
        }
        var resolvedEntries: [GeneratedWorkoutEntry] = []
        var missing: [String] = []
        
        for exercise in plan.exercises {
            if let match = matchExercise(exercise, normalizedMap: normalizedMap, library: library) {
                let entry = GeneratedWorkoutEntry(
                    exerciseId: match.id,
                    name: match.displayName,
                    category: match.swedishBodyPart,
                    sets: exercise.sets,
                    targetReps: exercise.reps
                )
                resolvedEntries.append(entry)
            } else {
                missing.append(exercise.name)
            }
        }
        
        return GeneratedWorkoutResult(
            title: plan.title,
            focus: plan.focus,
            estimatedDuration: plan.estimatedDuration,
            entries: resolvedEntries,
            missingExercises: missing
        )
    }
    
    private func matchExercise(_ exercise: WorkoutGeneratorPlan.Exercise,
                               normalizedMap: [String: ExerciseDBExercise],
                               library: [ExerciseDBExercise]) -> ExerciseDBExercise? {
        let normalizedName = Self.normalizedKey(for: exercise.name)
        if let exact = normalizedMap[normalizedName] {
            return exact
        }
        
        if let partial = library.first(where: { Self.normalizedKey(for: $0.name).contains(normalizedName) || normalizedName.contains(Self.normalizedKey(for: $0.name)) }) {
            return partial
        }
        
        let bodyMatches = library.filter { $0.bodyPart.caseInsensitiveCompare(exercise.bodyPart) == .orderedSame }
        if let equipmentMatch = bodyMatches.first(where: { $0.equipment.caseInsensitiveCompare(exercise.equipment) == .orderedSame }) {
            return equipmentMatch
        }
        
        return bodyMatches.first
    }
    
    private static func normalizedKey(for name: String) -> String {
        name
            .lowercased()
            .replacingOccurrences(of: "å", with: "a")
            .replacingOccurrences(of: "ä", with: "a")
            .replacingOccurrences(of: "ö", with: "o")
            .replacingOccurrences(of: "-", with: " ")
            .replacingOccurrences(of: "_", with: " ")
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined()
    }
    
    private static func cleanJSON(from message: String) -> String {
        var output = message
        if output.contains("```") {
            output = output.replacingOccurrences(of: "```json", with: "")
            output = output.replacingOccurrences(of: "```JSON", with: "")
            output = output.replacingOccurrences(of: "```", with: "")
        }
        return output.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private func buildExerciseSummary(from library: [ExerciseDBExercise]) -> String {
        let grouped = Dictionary(grouping: library) { $0.bodyPart.capitalized }
        let sortedGroups = grouped.sorted { $0.key < $1.key }
        let limitedGroups = sortedGroups.prefix(8)
        let entries = limitedGroups.map { bodyPart, exercises -> String in
            let samples = exercises.prefix(5).map { $0.name }.joined(separator: ", ")
            return "\(bodyPart): \(samples)"
        }
        return entries.joined(separator: "\n")
    }
}

// MARK: - Networking payloads
private struct ChatMessage: Encodable {
    let role: String
    let content: String
}

private struct ChatRequest: Encodable {
    let model: String
    let messages: [ChatMessage]
    let temperature: Double
    let maxTokens: Int
    
    enum CodingKeys: String, CodingKey {
        case model
        case messages
        case temperature
        case maxTokens = "max_tokens"
    }
}

private struct ChatResponse: Decodable {
    struct Choice: Decodable {
        struct Message: Decodable {
            let role: String
            let content: String
        }
        let message: Message
    }
    
    let choices: [Choice]
}

private struct WorkoutGeneratorPlan: Decodable {
    struct Exercise: Decodable {
        let name: String
        let bodyPart: String
        let equipment: String
        let sets: Int
        let reps: Int
        let restSeconds: Int?
        let notes: String?
    }
    
    let title: String
    let focus: String
    let estimatedDuration: Int
    let exercises: [Exercise]
}

