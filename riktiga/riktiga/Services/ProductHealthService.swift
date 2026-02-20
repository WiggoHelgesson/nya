import Foundation
import Supabase

// MARK: - Product Health Service (ChatGPT analysis)

final class ProductHealthService {
    static let shared = ProductHealthService()
    
    private let baseURL = URL(string: "https://api.openai.com/v1/chat/completions")!
    private let session: URLSession
    
    // In-memory cache to avoid duplicate GPT calls
    private var cache: [String: ProductHealthAnalysis] = [:]
    
    private init(session: URLSession = .shared) {
        self.session = session
    }
    
    // MARK: - Supabase cache model
    
    private struct CachedAnalysisRow: Codable {
        let barcode: String
        let product_name: String
        let brand: String?
        let analysis_json: String
    }
    
    // MARK: - Analyze Product
    
    /// Fetches product data from Open Food Facts and runs a ChatGPT health analysis.
    /// Checks in-memory cache and Supabase cache first.
    func analyzeBarcode(_ barcode: String) async throws -> ProductHealthAnalysis {
        // Check in-memory cache first
        if let cached = cache[barcode] {
            print("✅ [Health] Using in-memory cached analysis for \(barcode)")
            return cached
        }
        
        // Check Supabase cache
        if let dbCached = await fetchFromSupabaseCache(barcode: barcode) {
            cache[barcode] = dbCached
            print("✅ [Health] Using Supabase cached analysis for \(barcode)")
            return dbCached
        }
        
        // Step 1: Fetch from Open Food Facts (extended fields)
        let offData = try await fetchOpenFoodFacts(barcode: barcode)
        
        // Step 2: Send to ChatGPT for full health analysis
        let analysis = try await runGPTAnalysis(offData: offData, barcode: barcode)
        
        // Step 3: Cache result (memory + Supabase)
        cache[barcode] = analysis
        await saveToSupabaseCache(analysis)
        
        return analysis
    }
    
    /// Clear cached analysis (e.g. on memory warning)
    func clearCache() {
        cache.removeAll()
    }
    
    // MARK: - Supabase Cache
    
    private func fetchFromSupabaseCache(barcode: String) async -> ProductHealthAnalysis? {
        do {
            struct CacheRow: Decodable {
                let analysis_json: String
            }
            let rows: [CacheRow] = try await SupabaseConfig.supabase
                .from("product_health_analyses")
                .select("analysis_json")
                .eq("barcode", value: barcode)
                .limit(1)
                .execute()
                .value
            
            guard let row = rows.first,
                  let data = row.analysis_json.data(using: .utf8) else {
                return nil
            }
            
            return try JSONDecoder().decode(ProductHealthAnalysis.self, from: data)
        } catch {
            print("⚠️ [Health] Supabase cache fetch failed: \(error)")
            return nil
        }
    }
    
    private func saveToSupabaseCache(_ analysis: ProductHealthAnalysis) async {
        guard let barcode = analysis.barcode else { return }
        do {
            let jsonData = try JSONEncoder().encode(analysis)
            guard let jsonString = String(data: jsonData, encoding: .utf8) else { return }
            
            struct InsertRow: Codable {
                let barcode: String
                let product_name: String
                let brand: String?
                let analysis_json: String
            }
            
            let row = InsertRow(
                barcode: barcode,
                product_name: analysis.productName,
                brand: analysis.brand,
                analysis_json: jsonString
            )
            
            try await SupabaseConfig.supabase
                .from("product_health_analyses")
                .upsert(row, onConflict: "barcode")
                .execute()
            
            print("✅ [Health] Saved to Supabase cache for \(barcode)")
        } catch {
            print("⚠️ [Health] Supabase cache save failed: \(error)")
        }
    }
    
    // MARK: - Open Food Facts (extended query)
    
    struct OpenFoodFactsData {
        let productName: String
        let brand: String?
        let ingredientsText: String?
        let additivesTags: [String]
        let nutriscoreGrade: String?
        let novaGroup: Int?
        let calories: Int
        let protein: Int
        let carbs: Int
        let fat: Int
        let sugar: Double?
        let fiber: Double?
        let salt: Double?
        let saturatedFat: Double?
        let imageUrl: String?
        let categories: String?
        let packaging: String?
    }
    
    private func fetchOpenFoodFacts(barcode: String) async throws -> OpenFoodFactsData {
        let fields = "code,product_name,brands,nutriments,ingredients_text,additives_tags,nutriscore_grade,nova_group,image_front_url,categories,packaging"
        guard let url = URL(string: "https://world.openfoodfacts.org/api/v2/product/\(barcode)?fields=\(fields)") else {
            throw ProductHealthError.invalidBarcode
        }
        
        var request = URLRequest(url: url)
        request.setValue("UpAndDown iOS App", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 10
        
        let (data, _) = try await session.data(for: request)
        
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let status = json["status"] as? Int, status == 1,
              let product = json["product"] as? [String: Any] else {
            throw ProductHealthError.productNotFound
        }
        
        let nutriments = product["nutriments"] as? [String: Any] ?? [:]
        
        return OpenFoodFactsData(
            productName: product["product_name"] as? String ?? "Okänd produkt",
            brand: product["brands"] as? String,
            ingredientsText: product["ingredients_text"] as? String,
            additivesTags: product["additives_tags"] as? [String] ?? [],
            nutriscoreGrade: product["nutriscore_grade"] as? String,
            novaGroup: product["nova_group"] as? Int,
            calories: Int(nutriments["energy-kcal_100g"] as? Double ?? 0),
            protein: Int(nutriments["proteins_100g"] as? Double ?? 0),
            carbs: Int(nutriments["carbohydrates_100g"] as? Double ?? 0),
            fat: Int(nutriments["fat_100g"] as? Double ?? 0),
            sugar: nutriments["sugars_100g"] as? Double,
            fiber: nutriments["fiber_100g"] as? Double,
            salt: nutriments["salt_100g"] as? Double,
            saturatedFat: nutriments["saturated-fat_100g"] as? Double,
            imageUrl: product["image_front_url"] as? String,
            categories: product["categories"] as? String,
            packaging: product["packaging"] as? String
        )
    }
    
    // MARK: - ChatGPT Health Analysis
    
    private func runGPTAnalysis(offData: OpenFoodFactsData, barcode: String) async throws -> ProductHealthAnalysis {
        guard let apiKey = EnvManager.shared.value(for: "OPENAI_API_KEY"), !apiKey.isEmpty else {
            throw ProductHealthError.missingAPIKey
        }
        
        let systemPrompt = """
        Du är en expert livsmedelsanalytiker. Analysera produkten baserat på data från Open Food Facts och returnera en komplett hälsoanalys.
        
        Du MÅSTE svara med ENBART giltig JSON (ingen markdown, inga kommentarer) med exakt denna struktur:
        {
          "product_name": "Produktnamn",
          "brand": "Varumärke eller null",
          "health_score": 50,
          "health_grade": "Dåligt|Medel|Bra|Utmärkt",
          "harmful_additives": 3,
          "has_seed_oil": false,
          "total_ingredients": 8,
          "nova_group": 4,
          "is_ultra_processed": true,
          "natural_percentage": 33,
          "processed_percentage": 67,
          "ingredient_classifications": [
            {"name": "Vatten", "is_natural": true, "note": null},
            {"name": "Aspartam", "is_natural": false, "note": "Artificiellt sötningsmedel"}
          ],
          "brand_trust_score": "Clear|Warning|Danger",
          "brand_trust_note": "Kort beskrivning av varumärkets rykte",
          "additives": [
            {
              "name": "Fosforsyra",
              "code": "E338",
              "risk_level": "Low risk|Moderate risk|High risk",
              "description": "Kort beskrivning av tillsatsen",
              "function": "ANTIOXIDANT/REGULATOR"
            }
          ],
          "microplastic_risk": "Ingen|Låg|Måttlig|Hög",
          "microplastic_note": "Kort förklaring om förpackningsrelaterad risk",
          "heavy_metal_risk_score": 8,
          "heavy_metal_note": "Kort förklaring",
          "metal_breakdown": {
            "lead": "Low|Moderate|High|Undetected",
            "cadmium": "Low|Moderate|High|Undetected",
            "arsenic": "Low|Moderate|High|Undetected",
            "mercury": "Low|Moderate|High|Undetected",
            "primary_sources": "Kort text om källor",
            "data_coverage": 85
          }
        }
        
        VIKTIGA REGLER:
        - health_score: 1-100 baserat på ingredienser, tillsatser, näringsinnehåll och bearbetningsgrad
        - Var ärlig och faktabaserad. Använd NOVA-klassificering, Nutri-Score och kända risker
        - Om ingredienslista saknas, gör bästa uppskattning baserat på produktnamn och kategori
        - natural_percentage + processed_percentage MÅSTE bli 100
        - Alla texter på SVENSKA
        - Svara ENBART med JSON, inget annat
        """
        
        var userInput = "Analysera denna produkt:\n"
        userInput += "Namn: \(offData.productName)\n"
        if let brand = offData.brand { userInput += "Varumärke: \(brand)\n" }
        if let ingredients = offData.ingredientsText { userInput += "Ingredienser: \(ingredients)\n" }
        if !offData.additivesTags.isEmpty { userInput += "Tillsatser (taggar): \(offData.additivesTags.joined(separator: ", "))\n" }
        if let nutriscore = offData.nutriscoreGrade { userInput += "Nutri-Score: \(nutriscore.uppercased())\n" }
        if let nova = offData.novaGroup { userInput += "NOVA-grupp: \(nova)\n" }
        userInput += "Näring per 100g: \(offData.calories) kcal, \(offData.protein)g protein, \(offData.carbs)g kolhydrater, \(offData.fat)g fett"
        if let sugar = offData.sugar { userInput += ", \(sugar)g socker" }
        if let fiber = offData.fiber { userInput += ", \(fiber)g fiber" }
        if let salt = offData.salt { userInput += ", \(salt)g salt" }
        if let satFat = offData.saturatedFat { userInput += ", \(satFat)g mättat fett" }
        userInput += "\n"
        if let categories = offData.categories { userInput += "Kategorier: \(categories)\n" }
        if let packaging = offData.packaging { userInput += "Förpackning: \(packaging)\n" }
        
        let requestBody: [String: Any] = [
            "model": "gpt-4o-mini",
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": userInput]
            ],
            "temperature": 0.3,
            "max_tokens": 2000,
            "response_format": ["type": "json_object"]
        ]
        
        let bodyData = try JSONSerialization.data(withJSONObject: requestBody)
        
        var lastError: Error = ProductHealthError.gptRequestFailed
        let maxAttempts = 2
        
        for attempt in 1...maxAttempts {
            var urlRequest = URLRequest(url: baseURL)
            urlRequest.httpMethod = "POST"
            urlRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
            urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
            urlRequest.httpBody = bodyData
            urlRequest.timeoutInterval = 60
            
            do {
                let (data, response) = try await session.data(for: urlRequest)
                
                guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                    let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
                    print("⚠️ GPT request failed with status \(statusCode) (attempt \(attempt)/\(maxAttempts))")
                    lastError = ProductHealthError.gptRequestFailed
                    if attempt < maxAttempts {
                        try await Task.sleep(nanoseconds: 2_000_000_000)
                        continue
                    }
                    throw ProductHealthError.gptRequestFailed
                }
                
                guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let choices = json["choices"] as? [[String: Any]],
                      let firstChoice = choices.first,
                      let message = firstChoice["message"] as? [String: Any],
                      let content = message["content"] as? String,
                      let contentData = content.data(using: .utf8) else {
                    throw ProductHealthError.invalidGPTResponse
                }
                
                let decoder = JSONDecoder()
                let gptResult = try decoder.decode(GPTHealthResult.self, from: contentData)
                
                // Build full analysis by merging GPT result with OFF data — continued below
                return try buildAnalysis(gptResult: gptResult, offData: offData, barcode: barcode)
                
            } catch let urlError as URLError where urlError.code == .timedOut {
                print("⚠️ GPT request timed out (attempt \(attempt)/\(maxAttempts))")
                lastError = ProductHealthError.analysisTimedOut
                if attempt < maxAttempts {
                    try await Task.sleep(nanoseconds: 1_000_000_000)
                    continue
                }
            } catch let error as ProductHealthError {
                throw error
            } catch {
                print("⚠️ GPT request error: \(error) (attempt \(attempt)/\(maxAttempts))")
                lastError = error
                if attempt < maxAttempts {
                    try await Task.sleep(nanoseconds: 2_000_000_000)
                    continue
                }
            }
        }
        
        throw lastError as? ProductHealthError ?? ProductHealthError.gptRequestFailed
    }
    
    private func buildAnalysis(gptResult: GPTHealthResult, offData: OpenFoodFactsData, barcode: String) throws -> ProductHealthAnalysis {
        let analysis = ProductHealthAnalysis(
            productName: gptResult.product_name,
            brand: gptResult.brand ?? offData.brand,
            barcode: barcode,
            imageUrl: offData.imageUrl,
            healthScore: gptResult.health_score,
            healthGrade: gptResult.health_grade,
            harmfulAdditives: gptResult.harmful_additives,
            hasSeedOil: gptResult.has_seed_oil,
            totalIngredients: gptResult.total_ingredients,
            novaGroup: gptResult.nova_group ?? offData.novaGroup,
            isUltraProcessed: gptResult.is_ultra_processed,
            naturalPercentage: gptResult.natural_percentage,
            processedPercentage: gptResult.processed_percentage,
            ingredientClassifications: gptResult.ingredient_classifications,
            brandTrustScore: gptResult.brand_trust_score,
            brandTrustNote: gptResult.brand_trust_note,
            additives: gptResult.additives,
            microplasticRisk: gptResult.microplastic_risk,
            microplasticNote: gptResult.microplastic_note,
            heavyMetalRiskScore: gptResult.heavy_metal_risk_score,
            heavyMetalNote: gptResult.heavy_metal_note,
            metalBreakdown: gptResult.metal_breakdown,
            calories: offData.calories,
            protein: offData.protein,
            carbs: offData.carbs,
            fat: offData.fat
        )
        
        print("✅ [Health] GPT analysis complete for \(analysis.productName): score \(analysis.healthScore)")
        return analysis
    }
    
    // MARK: - GPT Response Model (matches GPT JSON schema exactly)
    
    private struct GPTHealthResult: Codable {
        let product_name: String
        let brand: String?
        let health_score: Int
        let health_grade: String
        let harmful_additives: Int
        let has_seed_oil: Bool
        let total_ingredients: Int
        let nova_group: Int?
        let is_ultra_processed: Bool
        let natural_percentage: Int
        let processed_percentage: Int
        let ingredient_classifications: [IngredientClassification]
        let brand_trust_score: String
        let brand_trust_note: String
        let additives: [AdditiveInfo]
        let microplastic_risk: String
        let microplastic_note: String
        let heavy_metal_risk_score: Int
        let heavy_metal_note: String
        let metal_breakdown: MetalBreakdown
    }
}

// MARK: - Errors

enum ProductHealthError: LocalizedError {
    case invalidBarcode
    case productNotFound
    case missingAPIKey
    case gptRequestFailed
    case invalidGPTResponse
    case analysisTimedOut
    
    var errorDescription: String? {
        switch self {
        case .invalidBarcode: return "Ogiltig streckkod"
        case .productNotFound: return "Produkten hittades inte"
        case .missingAPIKey: return "API-nyckel saknas"
        case .gptRequestFailed: return "Analysen misslyckades"
        case .invalidGPTResponse: return "Kunde inte tolka analysresultatet"
        case .analysisTimedOut: return "Analysen tog för lång tid. Försök igen senare."
        }
    }
}
