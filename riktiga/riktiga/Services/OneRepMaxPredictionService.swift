import Foundation

// MARK: - 1RM Prediction Service using ChatGPT

final class OneRepMaxPredictionService {
    static let shared = OneRepMaxPredictionService()
    
    private let baseURL = URL(string: "https://api.openai.com/v1/chat/completions")!
    private let session: URLSession
    private let jsonDecoder: JSONDecoder
    private let jsonEncoder: JSONEncoder
    
    // Cache predictions to avoid repeated API calls - only refresh once per week
    private var predictionCache: [String: CachedPrediction] = [:]
    private let cacheExpirationDays: Int = 7
    
    private init(session: URLSession = .shared) {
        self.session = session
        self.jsonDecoder = JSONDecoder()
        self.jsonEncoder = JSONEncoder()
        loadCacheFromDisk()
        validateAndCleanCache()
    }
    
    /// Validate cache entries and remove any that are corrupted or expired
    private func validateAndCleanCache() {
        let now = Date()
        var keysToRemove: [String] = []
        
        for (key, cached) in predictionCache {
            // Check if expired (7 days)
            let daysSinceCache = Calendar.current.dateComponents([.day], from: cached.timestamp, to: now).day ?? 0
            if daysSinceCache >= cacheExpirationDays {
                keysToRemove.append(key)
                continue
            }
            
            // Validate prediction data
            if cached.prediction.exerciseName.isEmpty || cached.prediction.current1RM <= 0 {
                keysToRemove.append(key)
            }
        }
        
        if !keysToRemove.isEmpty {
            print("🧹 Cleaning \(keysToRemove.count) invalid/expired cache entries")
            for key in keysToRemove {
                predictionCache.removeValue(forKey: key)
            }
            saveCacheToDisk()
        }
    }
    
    // MARK: - Data Models
    
    struct ExerciseWorkoutData: Codable {
        let name: String
        let category: String?
        let calculatedCurrent1RM: Double // Pre-calculated 1RM from app using Epley formula
        let sessions: [SessionData]
        
        struct SessionData: Codable {
            let date: String
            let sets: [SetData]
        }
        
        struct SetData: Codable {
            let weight: Double
            let reps: Int
            let estimated1RM: Double // Pre-calculated 1RM for this set
        }
    }
    
    struct AIPrediction: Codable {
        let exerciseName: String
        let current1RM: Double
        let prediction3Months: Double
        let prediction6Months: Double
        let prediction1Year: Double
        let monthlyProgressRate: Double
        let confidence: String // "high", "medium", "low"
        let reasoning: String
        let tips: String?
    }
    
    struct CachedPrediction: Codable {
        let prediction: AIPrediction
        let timestamp: Date
        let dataHash: String
    }
    
    // MARK: - Public API
    
    func getPredictions(for exerciseHistories: [StatExerciseHistory]) async throws -> [AIPrediction] {
        guard !exerciseHistories.isEmpty else { return [] }
        
        // Check if we have valid cached predictions (less than 7 days old)
        if let cached = getValidCachedPredictions() {
            print("✅ Using cached 1RM predictions (valid for \(daysUntilCacheExpires()) more days)")
            return cached
        }
        
        print("🤖 Fetching new 1RM predictions from AI (cache expired or empty)...")
        
        // Filter to only include last 3 months of data for better analysis
        let threeMonthsAgo = Calendar.current.date(byAdding: .month, value: -3, to: Date()) ?? Date()
        
        // Convert to API-friendly format with filtered data
        let workoutData = exerciseHistories.compactMap { history -> ExerciseWorkoutData? in
            // Filter sessions to last 3 months
            let recentSessions = history.history.filter { $0.date >= threeMonthsAgo }
            
            // Skip exercises with no recent data
            guard !recentSessions.isEmpty else { return nil }
            
            // Current 1RM = the HEAVIEST weight the user has actually lifted (not calculated)
            let maxWeightLifted = recentSessions.flatMap { $0.sets }.map { $0.weight }.max() ?? 0
            
            return ExerciseWorkoutData(
                name: history.name,
                category: history.category,
                calculatedCurrent1RM: maxWeightLifted, // This is the actual max weight lifted
                sessions: recentSessions.map { snapshot in
                    ExerciseWorkoutData.SessionData(
                        date: formatDate(snapshot.date),
                        sets: snapshot.sets.map { set in
                            ExerciseWorkoutData.SetData(
                                weight: set.weight, 
                                reps: set.reps,
                                estimated1RM: set.weight // Just use the actual weight
                            )
                        }
                    )
                }
            )
        }
        
        // If no exercises have recent data, return empty
        guard !workoutData.isEmpty else {
            print("⚠️ No exercises with data from last 3 months")
            return []
        }
        
        do {
            let predictions = try await fetchPredictionsFromAI(workoutData: workoutData)
            
            // Cache the results only if successful
            cachePredictions(predictions)
            
            return predictions
        } catch {
            // Clear any potentially corrupted cache on error
            print("⚠️ Error fetching predictions, clearing cache: \(error)")
            clearCache()
            throw error
        }
    }
    
    func getPrediction(for exerciseName: String, from allPredictions: [AIPrediction]) -> AIPrediction? {
        return allPredictions.first { $0.exerciseName.lowercased() == exerciseName.lowercased() }
    }
    
    // MARK: - API Call
    
    private func fetchPredictionsFromAI(workoutData: [ExerciseWorkoutData]) async throws -> [AIPrediction] {
        guard let apiKey = EnvManager.shared.value(for: "OPENAI_API_KEY"), !apiKey.isEmpty else {
            throw OneRMPredictionError.missingAPIKey
        }
        
        let workoutJSON = try jsonEncoder.encode(workoutData)
        let workoutString = String(data: workoutJSON, encoding: .utf8) ?? "[]"
        
        let systemPrompt = """
        Du är en expert på styrketräning och progression. Din uppgift är att ge FRAMTIDSPREDIKTIONER.
        
        KRITISKT VIKTIGT - CURRENT 1RM:
        - "calculatedCurrent1RM" är den TYNGSTA vikten användaren faktiskt har lyft för denna övning
        - Detta är deras VERKLIGA 1RM - kopiera detta värde EXAKT till "current1RM" i ditt svar
        - ÄNDRA INTE detta värde
        
        KRITISKT VIKTIGT - PREDIKTIONER:
        - Alla prediktioner (3m, 6m, 1 år) MÅSTE vara HÖGRE än current1RM
        - Om current1RM är 100kg → prediction3Months måste vara minst 101kg
        - prediction6Months MÅSTE vara högre än prediction3Months
        - prediction1Year MÅSTE vara högre än prediction6Months
        
        PROGRESSIONSREGLER:
        - Compound-övningar (bänkpress, knäböj, marklyft): +1-2.5kg/månad
        - Isolation-övningar (curls, raises): +0.5-1kg/månad
        - Minst +0.5kg/månad även vid platå
        
        Svara ENDAST med giltig JSON:
        [
          {
            "exerciseName": "Övningsnamn",
            "current1RM": 100.0,
            "prediction3Months": 104.0,
            "prediction6Months": 108.0,
            "prediction1Year": 114.0,
            "monthlyProgressRate": 1.2,
            "confidence": "high|medium|low",
            "reasoning": "Kort förklaring på svenska",
            "tips": "Ett tips (eller null)"
          }
        ]
        """
        
        let userPrompt = """
        Ge framtidsprediktioner för dessa övningar.
        
        REGLER:
        - "calculatedCurrent1RM" = tyngsta vikten användaren lyft = använd som "current1RM"
        - Alla prediktioner MÅSTE vara HÖGRE än current1RM
        
        Data:
        \(workoutString)
        """
        
        let payload = ChatRequestPayload(
            model: "gpt-4o-mini",
            messages: [
                ChatMessagePayload(role: "system", content: systemPrompt),
                ChatMessagePayload(role: "user", content: userPrompt)
            ],
            temperature: 0.3, // Lower temperature for more consistent predictions
            max_tokens: 8000 // Increased to handle many exercises
        )
        
        var request = URLRequest(url: baseURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 120 // Increased timeout for larger responses
        request.httpBody = try jsonEncoder.encode(payload)
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            if let jsonString = String(data: data, encoding: .utf8) {
                print("❌ 1RM API error: \(jsonString)")
            }
            throw OneRMPredictionError.apiError
        }
        
        let decoded = try jsonDecoder.decode(ChatResponsePayload.self, from: data)
        
        guard let content = decoded.choices.first?.message.content else {
            throw OneRMPredictionError.emptyResponse
        }
        
        // Parse the JSON response
        return try parsePredictions(from: content)
    }
    
    private func parsePredictions(from content: String) throws -> [AIPrediction] {
        // Extract JSON from response (might have markdown code blocks)
        var jsonString = content
        
        // Remove markdown code blocks if present
        if jsonString.contains("```json") {
            jsonString = jsonString.replacingOccurrences(of: "```json", with: "")
            jsonString = jsonString.replacingOccurrences(of: "```", with: "")
        } else if jsonString.contains("```") {
            jsonString = jsonString.replacingOccurrences(of: "```", with: "")
        }
        
        jsonString = jsonString.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard let jsonData = jsonString.data(using: .utf8) else {
            throw OneRMPredictionError.parsingFailed
        }
        
        do {
            let predictions = try jsonDecoder.decode([AIPrediction].self, from: jsonData)
            // Validate and fix predictions
            return validateAndFixPredictions(predictions)
        } catch {
            print("❌ Failed to parse predictions: \(error)")
            print("📄 Raw content: \(content)")
            throw OneRMPredictionError.parsingFailed
        }
    }
    
    /// Ensure all predictions are higher than current 1RM
    private func validateAndFixPredictions(_ predictions: [AIPrediction]) -> [AIPrediction] {
        return predictions.map { prediction in
            let current = prediction.current1RM
            var pred3m = prediction.prediction3Months
            var pred6m = prediction.prediction6Months
            var pred1y = prediction.prediction1Year
            var rate = prediction.monthlyProgressRate
            
            // Ensure predictions are always >= current (minimum 0.5kg/month progression)
            if pred3m <= current {
                pred3m = current + (rate > 0 ? rate * 3 : 1.5)
            }
            if pred6m <= pred3m {
                pred6m = pred3m + (rate > 0 ? rate * 3 : 1.5)
            }
            if pred1y <= pred6m {
                pred1y = pred6m + (rate > 0 ? rate * 6 : 3.0)
            }
            
            // Ensure rate is positive
            if rate <= 0 {
                rate = 0.5 // Minimum progression rate
            }
            
            // Only create new prediction if values were changed
            if pred3m != prediction.prediction3Months || 
               pred6m != prediction.prediction6Months || 
               pred1y != prediction.prediction1Year ||
               rate != prediction.monthlyProgressRate {
                print("⚠️ Fixed invalid prediction for \(prediction.exerciseName): \(current)kg → 3m:\(pred3m), 6m:\(pred6m), 1y:\(pred1y)")
                return AIPrediction(
                    exerciseName: prediction.exerciseName,
                    current1RM: current,
                    prediction3Months: pred3m,
                    prediction6Months: pred6m,
                    prediction1Year: pred1y,
                    monthlyProgressRate: rate,
                    confidence: prediction.confidence,
                    reasoning: prediction.reasoning,
                    tips: prediction.tips
                )
            }
            
            return prediction
        }
    }
    
    // MARK: - Caching
    
    /// Get cached predictions if they exist and are less than 7 days old (time-based, not data-based)
    private func getValidCachedPredictions() -> [AIPrediction]? {
        // Check if we have any cached predictions
        guard !predictionCache.isEmpty else { return nil }
        
        // Check if the cache is still valid (any prediction less than 7 days old)
        let validPredictions = predictionCache.filter { (_, cached) in
            let daysSinceCache = Calendar.current.dateComponents([.day], from: cached.timestamp, to: Date()).day ?? 0
            return daysSinceCache < cacheExpirationDays
        }
        
        // If we have valid predictions, return all of them
        guard !validPredictions.isEmpty else { 
            print("📅 Cache expired - predictions are older than \(cacheExpirationDays) days")
            return nil 
        }
        
        return validPredictions.values.map { $0.prediction }
    }
    
    /// Days until cache expires
    private func daysUntilCacheExpires() -> Int {
        guard let oldestTimestamp = predictionCache.values.map({ $0.timestamp }).min() else { return 0 }
        let daysSinceCache = Calendar.current.dateComponents([.day], from: oldestTimestamp, to: Date()).day ?? 0
        return max(cacheExpirationDays - daysSinceCache, 0)
    }
    
    /// Check if cache needs refresh (older than 7 days)
    func needsRefresh() -> Bool {
        guard !predictionCache.isEmpty else { return true }
        
        // Check oldest prediction
        guard let oldestTimestamp = predictionCache.values.map({ $0.timestamp }).min() else { return true }
        let daysSinceCache = Calendar.current.dateComponents([.day], from: oldestTimestamp, to: Date()).day ?? 0
        return daysSinceCache >= cacheExpirationDays
    }
    
    private func cachePredictions(_ predictions: [AIPrediction]) {
        let now = Date()
        for prediction in predictions {
            let cached = CachedPrediction(
                prediction: prediction,
                timestamp: now, // All predictions get same timestamp
                dataHash: "" // No longer used - cache is purely time-based
            )
            predictionCache[prediction.exerciseName] = cached
        }
        saveCacheToDisk()
        
        let expirationDate = Calendar.current.date(byAdding: .day, value: cacheExpirationDays, to: now) ?? now
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM"
        print("💾 Cached \(predictions.count) predictions - valid until \(formatter.string(from: expirationDate))")
    }
    
    private func loadCacheFromDisk() {
        guard let data = UserDefaults.standard.data(forKey: "oneRMPredictionCache"),
              let cache = try? jsonDecoder.decode([String: CachedPrediction].self, from: data) else {
            return
        }
        predictionCache = cache
    }
    
    private func saveCacheToDisk() {
        guard let data = try? jsonEncoder.encode(predictionCache) else { return }
        UserDefaults.standard.set(data, forKey: "oneRMPredictionCache")
    }
    
    func clearCache() {
        predictionCache.removeAll()
        UserDefaults.standard.removeObject(forKey: "oneRMPredictionCache")
    }
    
    // MARK: - Helpers
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
    
    // MARK: - Request/Response Models
    
    private struct ChatMessagePayload: Encodable {
        let role: String
        let content: String
    }
    
    private struct ChatRequestPayload: Encodable {
        let model: String
        let messages: [ChatMessagePayload]
        let temperature: Double
        let max_tokens: Int
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

enum OneRMPredictionError: LocalizedError {
    case missingAPIKey
    case apiError
    case emptyResponse
    case parsingFailed
    
    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "API-nyckel saknas"
        case .apiError:
            return "Kunde inte hämta prediktioner"
        case .emptyResponse:
            return "Tomt svar från AI"
        case .parsingFailed:
            return "Kunde inte tolka AI-svaret"
        }
    }
}

