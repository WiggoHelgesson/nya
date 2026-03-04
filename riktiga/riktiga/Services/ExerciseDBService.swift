import Foundation

class ExerciseDBService {
    static let shared = ExerciseDBService()
    
    private var cachedExercises: [ExerciseDBExercise]?
    
    private init() {}
    
    private func loadBundledExercises() -> [ExerciseDBExercise] {
        if let cached = cachedExercises {
            return cached
        }
        guard let url = Bundle.main.url(forResource: "exercises", withExtension: "json") else {
            print("❌ exercises.json not found in bundle")
            return []
        }
        do {
            let data = try Data(contentsOf: url)
            let exercises = try JSONDecoder().decode([ExerciseDBExercise].self, from: data)
            cachedExercises = exercises
            print("📦 Loaded \(exercises.count) exercises from bundle")
            return exercises
        } catch {
            print("❌ Failed to decode bundled exercises: \(error)")
            return []
        }
    }
    
    // MARK: - Fetch All Exercises
    func fetchAllExercises(forceRefresh: Bool = false) async throws -> [ExerciseDBExercise] {
        return loadBundledExercises()
    }
    
    // MARK: - Fetch Exercises by Body Part
    func fetchExercisesByBodyPart(_ bodyPart: String) async throws -> [ExerciseDBExercise] {
        return loadBundledExercises().filter { $0.bodyPart.lowercased() == bodyPart.lowercased() }
    }
    
    // MARK: - Fetch Exercises by Target Muscle
    func fetchExercisesByTarget(_ target: String) async throws -> [ExerciseDBExercise] {
        return loadBundledExercises().filter { $0.target.lowercased() == target.lowercased() }
    }
    
    // MARK: - Fetch Body Part List
    func fetchBodyPartList() async throws -> [String] {
        let all = loadBundledExercises()
        return Array(Set(all.map { $0.bodyPart })).sorted()
    }
    
    // MARK: - Fetch Equipment List
    func fetchEquipmentList() async throws -> [String] {
        let all = loadBundledExercises()
        return Array(Set(all.map { $0.equipment })).sorted()
    }
    
    // MARK: - Fetch Target Muscle List
    func fetchTargetList() async throws -> [String] {
        let all = loadBundledExercises()
        return Array(Set(all.map { $0.target })).sorted()
    }
    
    // MARK: - Fetch Exercises by Equipment
    func fetchExercisesByEquipment(_ equipment: String) async throws -> [ExerciseDBExercise] {
        return loadBundledExercises().filter { $0.equipment.lowercased() == equipment.lowercased() }
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
    
    var nameSlug: String {
        return name
            .lowercased()
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: " ", with: "-")
            .replacingOccurrences(of: "'", with: "")
            .replacingOccurrences(of: "\"", with: "")
    }
    
    var safeGifUrl: String {
        if let gif = gifUrl, !gif.isEmpty {
            return gif
        }
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
    case bundleNotFound
    
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
        case .bundleNotFound:
            return "Exercise data not found in app bundle"
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
        return name.split(separator: " ")
            .map { $0.prefix(1).uppercased() + $0.dropFirst() }
            .joined(separator: " ")
    }
}
