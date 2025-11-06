import Foundation

class ExerciseDBService {
    static let shared = ExerciseDBService()
    
    private let baseURL = "https://exercisedb.p.rapidapi.com"
    private let apiKey = "4695be4a29msh147831944f1aae7p1da0afjsn9353381d0966"
    private let cacheTTL: TimeInterval = 24 * 60 * 60 // 24 timmar
    
    private var exercisesCacheURL: URL {
        let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        return cacheDir.appendingPathComponent("exercise_cache.json")
    }
    
    private init() {}
    
    private func loadCachedExercises() -> [ExerciseDBExercise]? {
        let url = exercisesCacheURL
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            if let modified = attributes[.modificationDate] as? Date,
               Date().timeIntervalSince(modified) > cacheTTL {
                return nil
            }
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode([ExerciseDBExercise].self, from: data)
        } catch {
            print("⚠️ Failed to load cached exercises: \(error)")
            return nil
        }
    }
    
    private func saveExercisesToCache(_ exercises: [ExerciseDBExercise]) {
        let url = exercisesCacheURL
        do {
            let data = try JSONEncoder().encode(exercises)
            try data.write(to: url, options: .atomic)
        } catch {
            print("⚠️ Failed to cache exercises: \(error)")
        }
    }
    
    // MARK: - Fetch All Exercises
    func fetchAllExercises(forceRefresh: Bool = false) async throws -> [ExerciseDBExercise] {
        if !forceRefresh, let cached = loadCachedExercises(), !cached.isEmpty {
            print("💾 Returning \(cached.count) cached exercises")
            return cached
        }
        
        let urlString = "\(baseURL)/exercises?limit=1400&offset=0"
        guard let url = URL(string: urlString) else {
            throw ExerciseDBError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(apiKey, forHTTPHeaderField: "X-RapidAPI-Key")
        request.setValue("exercisedb.p.rapidapi.com", forHTTPHeaderField: "X-RapidAPI-Host")
        request.timeoutInterval = 30
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw ExerciseDBError.invalidResponse
            }
            
            guard httpResponse.statusCode == 200 else {
                print("❌ HTTP Error: \(httpResponse.statusCode)")
                if let jsonString = String(data: data, encoding: .utf8) {
                    print("Response: \(jsonString.prefix(500))")
                }
                throw ExerciseDBError.httpError(statusCode: httpResponse.statusCode)
            }
            
            let decoder = JSONDecoder()
            let exercises = try decoder.decode([ExerciseDBExercise].self, from: data)
            saveExercisesToCache(exercises)
            
            print("📥 Fetched \(exercises.count) exercises from ExerciseDB API")
            for (index, exercise) in exercises.prefix(3).enumerated() {
                print("   [\(index)] ID: \(exercise.id), Name: \(exercise.name)")
                print("       gifUrl: \(exercise.gifUrl ?? "❌ NIL")")
            }
            
            return exercises
        } catch {
            print("⚠️ Fetch failed, attempting to return cached exercises: \(error)")
            if let cached = loadCachedExercises(), !cached.isEmpty {
                return cached
            }
            throw error
        }
    }
    
    // MARK: - Fetch Exercises by Body Part
    func fetchExercisesByBodyPart(_ bodyPart: String) async throws -> [ExerciseDBExercise] {
        if let cached = loadCachedExercises(), !cached.isEmpty {
            let filtered = cached.filter { $0.bodyPart.lowercased() == bodyPart.lowercased() }
            if !filtered.isEmpty { return filtered }
        }
        let urlString = "\(baseURL)/exercises/bodyPart/\(bodyPart)?limit=300"
        guard let url = URL(string: urlString) else {
            throw ExerciseDBError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(apiKey, forHTTPHeaderField: "X-RapidAPI-Key")
        request.setValue("exercisedb.p.rapidapi.com", forHTTPHeaderField: "X-RapidAPI-Host")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ExerciseDBError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            throw ExerciseDBError.httpError(statusCode: httpResponse.statusCode)
        }
        
        let decoder = JSONDecoder()
        let exercises = try decoder.decode([ExerciseDBExercise].self, from: data)
        
        return exercises
    }
    
    // MARK: - Fetch Exercises by Target Muscle
    func fetchExercisesByTarget(_ target: String) async throws -> [ExerciseDBExercise] {
        if let cached = loadCachedExercises(), !cached.isEmpty {
            let filtered = cached.filter { $0.target.lowercased() == target.lowercased() }
            if !filtered.isEmpty { return filtered }
        }
        let urlString = "\(baseURL)/exercises/target/\(target)"
        guard let url = URL(string: urlString) else {
            throw ExerciseDBError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(apiKey, forHTTPHeaderField: "X-RapidAPI-Key")
        request.setValue("exercisedb.p.rapidapi.com", forHTTPHeaderField: "X-RapidAPI-Host")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ExerciseDBError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            throw ExerciseDBError.httpError(statusCode: httpResponse.statusCode)
        }
        
        let decoder = JSONDecoder()
        let exercises = try decoder.decode([ExerciseDBExercise].self, from: data)
        
        return exercises
    }
    
    // MARK: - Fetch Body Part List
    func fetchBodyPartList() async throws -> [String] {
        let urlString = "\(baseURL)/exercises/bodyPartList"
        guard let url = URL(string: urlString) else {
            throw ExerciseDBError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(apiKey, forHTTPHeaderField: "X-RapidAPI-Key")
        request.setValue("exercisedb.p.rapidapi.com", forHTTPHeaderField: "X-RapidAPI-Host")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ExerciseDBError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            throw ExerciseDBError.httpError(statusCode: httpResponse.statusCode)
        }
        
        let decoder = JSONDecoder()
        let bodyParts = try decoder.decode([String].self, from: data)
        
        return bodyParts
    }
    
    // MARK: - Fetch Equipment List
    func fetchEquipmentList() async throws -> [String] {
        let urlString = "\(baseURL)/exercises/equipmentList"
        guard let url = URL(string: urlString) else {
            throw ExerciseDBError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(apiKey, forHTTPHeaderField: "X-RapidAPI-Key")
        request.setValue("exercisedb.p.rapidapi.com", forHTTPHeaderField: "X-RapidAPI-Host")
        
        let (data, _) = try await URLSession.shared.data(for: request)
        let decoder = JSONDecoder()
        let equipment = try decoder.decode([String].self, from: data)
        return equipment
    }
    
    // MARK: - Fetch Target Muscle List
    func fetchTargetList() async throws -> [String] {
        let urlString = "\(baseURL)/exercises/targetList"
        guard let url = URL(string: urlString) else {
            throw ExerciseDBError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(apiKey, forHTTPHeaderField: "X-RapidAPI-Key")
        request.setValue("exercisedb.p.rapidapi.com", forHTTPHeaderField: "X-RapidAPI-Host")
        
        let (data, _) = try await URLSession.shared.data(for: request)
        let decoder = JSONDecoder()
        let targets = try decoder.decode([String].self, from: data)
        return targets
    }
    
    // MARK: - Fetch Exercises by Equipment
    func fetchExercisesByEquipment(_ equipment: String) async throws -> [ExerciseDBExercise] {
        if let cached = loadCachedExercises(), !cached.isEmpty {
            let filtered = cached.filter { $0.equipment.lowercased() == equipment.lowercased() }
            if !filtered.isEmpty { return filtered }
        }
        let urlString = "\(baseURL)/exercises/equipment/\(equipment)?limit=300"
        guard let url = URL(string: urlString) else {
            throw ExerciseDBError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(apiKey, forHTTPHeaderField: "X-RapidAPI-Key")
        request.setValue("exercisedb.p.rapidapi.com", forHTTPHeaderField: "X-RapidAPI-Host")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ExerciseDBError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            throw ExerciseDBError.httpError(statusCode: httpResponse.statusCode)
        }
        
        let decoder = JSONDecoder()
        let exercises = try decoder.decode([ExerciseDBExercise].self, from: data)
        print("✅ Fetched \(exercises.count) exercises for equipment: \(equipment)")
        return exercises
    }
}

// MARK: - Models
struct ExerciseDBExercise: Codable, Identifiable {
    let bodyPart: String
    let equipment: String
    let id: String
    let name: String
    let target: String
    let secondaryMuscles: [String]?
    let instructions: [String]?
    let gifUrl: String?
    
    enum CodingKeys: String, CodingKey {
        case bodyPart
        case equipment
        case id
        case name
        case target
        case secondaryMuscles
        case instructions
        case gifUrl
    }
    
    // Convert name to slug format for image URL
    // e.g. "3/4 sit-up" -> "3-4-sit-up"
    var nameSlug: String {
        return name
            .lowercased()
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: " ", with: "-")
            .replacingOccurrences(of: "'", with: "")
            .replacingOccurrences(of: "\"", with: "")
    }
    
    // Computed property for guaranteed non-nil URL
    // Using free-exercise-db format which uses name-based slugs
    var safeGifUrl: String {
        if let gif = gifUrl, !gif.isEmpty {
            return gif
        }
        // Use free-exercise-db GitHub repo format
        // Format: https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/{Name_With_Underscores}/images/0.jpg
        let githubName = name
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: " ", with: "_")
        return "https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/\(githubName)/images/0.jpg"
    }
}

// MARK: - Errors
enum ExerciseDBError: Error, LocalizedError {
    case invalidURL
    case invalidResponse
    case httpError(statusCode: Int)
    case decodingError
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .invalidResponse:
            return "Invalid response from server"
        case .httpError(let statusCode):
            return "HTTP error with status code: \(statusCode)"
        case .decodingError:
            return "Failed to decode response"
        }
    }
}

// MARK: - Swedish Translation Helper
extension ExerciseDBExercise {
    var swedishBodyPart: String {
        switch bodyPart.lowercased() {
        case "back": return "Rygg"
        case "cardio": return "Cardio"
        case "chest": return "Bröst"
        case "lower arms": return "Underarmar"
        case "lower legs": return "Underben"
        case "neck": return "Nacke"
        case "shoulders": return "Axlar"
        case "upper arms": return "Överarmar"
        case "upper legs": return "Lår"
        case "waist": return "Midja"
        default: return bodyPart.capitalized
        }
    }
    
    var displayName: String {
        // Capitalize first letter of each word
        return name.split(separator: " ")
            .map { $0.prefix(1).uppercased() + $0.dropFirst() }
            .joined(separator: " ")
    }
}

