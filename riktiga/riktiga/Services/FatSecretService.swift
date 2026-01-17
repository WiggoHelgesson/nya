import Foundation

// MARK: - FatSecret API Service
class FatSecretService {
    static let shared = FatSecretService()
    
    private let clientId = "fbbae7f3fcc24b7e96d41cf4b4ebf855"
    private let clientSecret = "abb53452c6124bfb896602c003a16211"
    private let tokenURL = "https://oauth.fatsecret.com/connect/token"
    private let apiBaseURL = "https://platform.fatsecret.com/rest/server.api"
    
    private var accessToken: String?
    private var tokenExpiration: Date?
    
    private init() {}
    
    // MARK: - Get Access Token (OAuth 2.0)
    private func getAccessToken() async throws -> String {
        // Check if we have a valid token
        if let token = accessToken, let expiration = tokenExpiration, Date() < expiration {
            print("🔑 Using cached FatSecret token")
            return token
        }
        
        // Request new token
        guard let url = URL(string: tokenURL) else {
            throw FatSecretError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        // Basic auth header
        let credentials = "\(clientId):\(clientSecret)"
        guard let credentialsData = credentials.data(using: .utf8) else {
            throw FatSecretError.authenticationFailed
        }
        let base64Credentials = credentialsData.base64EncodedString()
        request.setValue("Basic \(base64Credentials)", forHTTPHeaderField: "Authorization")
        
        // Body - just grant_type, no scope
        let body = "grant_type=client_credentials"
        request.httpBody = body.data(using: .utf8)
        request.timeoutInterval = 30
        
        print("🔑 Requesting FatSecret token from: \(tokenURL)")
        print("🔑 Client ID: \(clientId.prefix(10))...")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            let responseString = String(data: data, encoding: .utf8) ?? "No response body"
            print("📡 FatSecret raw response: \(responseString)")
            
            if let httpResponse = response as? HTTPURLResponse {
                print("📡 FatSecret token response status: \(httpResponse.statusCode)")
                
                if httpResponse.statusCode != 200 {
                    print("❌ FatSecret token error: Status \(httpResponse.statusCode)")
                    throw FatSecretError.authenticationFailed
                }
            }
            
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                print("❌ FatSecret: Could not parse JSON response")
                throw FatSecretError.invalidResponse
            }
            
            print("📡 FatSecret JSON: \(json)")
            
            guard let token = json["access_token"] as? String else {
                print("❌ FatSecret: No access_token in response")
                throw FatSecretError.invalidResponse
            }
            
            let expiresIn = json["expires_in"] as? Int ?? 86400
            
            self.accessToken = token
            self.tokenExpiration = Date().addingTimeInterval(TimeInterval(expiresIn - 60))
            
            print("✅ FatSecret access token obtained! Token: \(token.prefix(20))...")
            return token
        } catch let error as FatSecretError {
            throw error
        } catch {
            print("❌ FatSecret token network error: \(error.localizedDescription)")
            throw FatSecretError.authenticationFailed
        }
    }
    
    // MARK: - Search Foods
    func searchFoods(query: String, maxResults: Int = 20) async throws -> [FatSecretFood] {
        let token = try await getAccessToken()
        
        // Build URL with query parameters
        let urlString = "\(apiBaseURL)?method=foods.search&search_expression=\(query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query)&max_results=\(maxResults)&format=json"
        
        guard let url = URL(string: urlString) else {
            print("❌ FatSecret: Invalid search URL")
            throw FatSecretError.invalidURL
        }
        
        print("🔎 FatSecret search URL: \(urlString)")
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 20
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            let responseString = String(data: data, encoding: .utf8) ?? "No response"
            print("📡 FatSecret search raw response: \(responseString.prefix(500))...")
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw FatSecretError.invalidResponse
            }
            
            print("📡 FatSecret search status: \(httpResponse.statusCode)")
            
            if httpResponse.statusCode != 200 {
                print("❌ FatSecret search failed with status: \(httpResponse.statusCode)")
                throw FatSecretError.searchFailed
            }
            
            // Parse response
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                print("❌ FatSecret: Could not parse search JSON")
                return []
            }
            
            print("📡 FatSecret search JSON keys: \(json.keys)")
            
            guard let foods = json["foods"] as? [String: Any] else {
                print("❌ FatSecret: No 'foods' key in response")
                print("📡 Full response: \(json)")
                return []
            }
            
            // Handle both single food and array of foods
            var foodArray: [[String: Any]] = []
            if let food = foods["food"] as? [[String: Any]] {
                foodArray = food
                print("📡 FatSecret: Found \(food.count) foods (array)")
            } else if let food = foods["food"] as? [String: Any] {
                foodArray = [food]
                print("📡 FatSecret: Found 1 food (single)")
            } else {
                print("❌ FatSecret: No 'food' in foods object")
                print("📡 Foods object: \(foods)")
            }
            
            let results = foodArray.compactMap { parseFatSecretFood($0) }
            print("✅ FatSecret parsed \(results.count) results for '\(query)'")
            return results
            
        } catch let error as FatSecretError {
            throw error
        } catch {
            print("❌ FatSecret search network error: \(error.localizedDescription)")
            throw FatSecretError.searchFailed
        }
    }
    
    // MARK: - Get Food Details
    func getFoodDetails(foodId: String) async throws -> FatSecretFoodDetail? {
        let token = try await getAccessToken()
        
        guard var urlComponents = URLComponents(string: apiBaseURL) else {
            throw FatSecretError.invalidURL
        }
        
        urlComponents.queryItems = [
            URLQueryItem(name: "method", value: "food.get.v4"),
            URLQueryItem(name: "food_id", value: foodId),
            URLQueryItem(name: "format", value: "json")
        ]
        
        guard let url = urlComponents.url else {
            throw FatSecretError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 15
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw FatSecretError.searchFailed
        }
        
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let food = json["food"] as? [String: Any] else {
            return nil
        }
        
        return parseFatSecretFoodDetail(food)
    }
    
    // MARK: - Parse Food from Search Results
    private func parseFatSecretFood(_ dict: [String: Any]) -> FatSecretFood? {
        guard let foodId = dict["food_id"] as? String,
              let foodName = dict["food_name"] as? String else {
            return nil
        }
        
        let brandName = dict["brand_name"] as? String
        let foodDescription = dict["food_description"] as? String
        
        // Parse nutrition from description (format: "Per 100g - Kalorier: 250kcal | Fett: 10g | Kolh: 30g | Protein: 8g")
        var calories = 0
        var fat = 0.0
        var carbs = 0.0
        var protein = 0.0
        var servingSize = "100g"
        
        if let desc = foodDescription {
            // Extract serving size
            if let perRange = desc.range(of: "Per ") {
                let afterPer = desc[perRange.upperBound...]
                if let dashRange = afterPer.range(of: " -") {
                    servingSize = String(afterPer[..<dashRange.lowerBound])
                }
            }
            
            // Extract calories
            if let calMatch = desc.range(of: "Calories: ") ?? desc.range(of: "Kalorier: ") {
                let afterCal = desc[calMatch.upperBound...]
                if let kcalRange = afterCal.range(of: "kcal") {
                    let calStr = String(afterCal[..<kcalRange.lowerBound])
                    calories = Int(calStr) ?? 0
                }
            }
            
            // Extract fat
            if let fatMatch = desc.range(of: "Fat: ") ?? desc.range(of: "Fett: ") {
                let afterFat = desc[fatMatch.upperBound...]
                if let gRange = afterFat.range(of: "g") {
                    let fatStr = String(afterFat[..<gRange.lowerBound])
                    fat = Double(fatStr.replacingOccurrences(of: ",", with: ".")) ?? 0
                }
            }
            
            // Extract carbs
            if let carbMatch = desc.range(of: "Carbs: ") ?? desc.range(of: "Kolh: ") {
                let afterCarb = desc[carbMatch.upperBound...]
                if let gRange = afterCarb.range(of: "g") {
                    let carbStr = String(afterCarb[..<gRange.lowerBound])
                    carbs = Double(carbStr.replacingOccurrences(of: ",", with: ".")) ?? 0
                }
            }
            
            // Extract protein
            if let protMatch = desc.range(of: "Protein: ") ?? desc.range(of: "Prot: ") {
                let afterProt = desc[protMatch.upperBound...]
                if let gRange = afterProt.range(of: "g") {
                    let protStr = String(afterProt[..<gRange.lowerBound])
                    protein = Double(protStr.replacingOccurrences(of: ",", with: ".")) ?? 0
                }
            }
        }
        
        return FatSecretFood(
            foodId: foodId,
            foodName: foodName,
            brandName: brandName,
            calories: calories,
            fat: fat,
            carbs: carbs,
            protein: protein,
            servingSize: servingSize
        )
    }
    
    // MARK: - Parse Food Details
    private func parseFatSecretFoodDetail(_ dict: [String: Any]) -> FatSecretFoodDetail? {
        guard let foodId = dict["food_id"] as? String,
              let foodName = dict["food_name"] as? String else {
            return nil
        }
        
        let brandName = dict["brand_name"] as? String
        
        // Parse servings
        var servings: [FatSecretServing] = []
        if let servingsDict = dict["servings"] as? [String: Any] {
            if let servingArray = servingsDict["serving"] as? [[String: Any]] {
                servings = servingArray.compactMap { parseServing($0) }
            } else if let singleServing = servingsDict["serving"] as? [String: Any] {
                if let serving = parseServing(singleServing) {
                    servings = [serving]
                }
            }
        }
        
        return FatSecretFoodDetail(
            foodId: foodId,
            foodName: foodName,
            brandName: brandName,
            servings: servings
        )
    }
    
    private func parseServing(_ dict: [String: Any]) -> FatSecretServing? {
        let servingId = dict["serving_id"] as? String ?? ""
        let servingDescription = dict["serving_description"] as? String ?? "1 serving"
        let metricServingAmount = dict["metric_serving_amount"] as? String
        let metricServingUnit = dict["metric_serving_unit"] as? String
        
        let calories = Int(dict["calories"] as? String ?? "0") ?? 0
        let fat = Double(dict["fat"] as? String ?? "0") ?? 0
        let carbs = Double(dict["carbohydrate"] as? String ?? "0") ?? 0
        let protein = Double(dict["protein"] as? String ?? "0") ?? 0
        let fiber = Double(dict["fiber"] as? String ?? "0") ?? 0
        let sugar = Double(dict["sugar"] as? String ?? "0") ?? 0
        let sodium = Double(dict["sodium"] as? String ?? "0") ?? 0
        
        return FatSecretServing(
            servingId: servingId,
            servingDescription: servingDescription,
            metricServingAmount: metricServingAmount,
            metricServingUnit: metricServingUnit,
            calories: calories,
            fat: fat,
            carbs: carbs,
            protein: protein,
            fiber: fiber,
            sugar: sugar,
            sodium: sodium
        )
    }
}

// MARK: - FatSecret Models
struct FatSecretFood: Identifiable {
    let id = UUID()
    let foodId: String
    let foodName: String
    let brandName: String?
    let calories: Int
    let fat: Double
    let carbs: Double
    let protein: Double
    let servingSize: String
    
    var displayName: String {
        if let brand = brandName, !brand.isEmpty {
            return "\(foodName) (\(brand))"
        }
        return foodName
    }
}

struct FatSecretFoodDetail {
    let foodId: String
    let foodName: String
    let brandName: String?
    let servings: [FatSecretServing]
    
    var defaultServing: FatSecretServing? {
        servings.first
    }
}

struct FatSecretServing {
    let servingId: String
    let servingDescription: String
    let metricServingAmount: String?
    let metricServingUnit: String?
    let calories: Int
    let fat: Double
    let carbs: Double
    let protein: Double
    let fiber: Double
    let sugar: Double
    let sodium: Double
}

// MARK: - FatSecret Errors
enum FatSecretError: Error {
    case invalidURL
    case authenticationFailed
    case invalidResponse
    case searchFailed
    
    var localizedDescription: String {
        switch self {
        case .invalidURL: return "Invalid URL"
        case .authenticationFailed: return "Authentication failed"
        case .invalidResponse: return "Invalid response"
        case .searchFailed: return "Search failed"
        }
    }
}

