import Foundation
import Supabase

final class TrainerService {
    static let shared = TrainerService()
    private let supabase = SupabaseConfig.supabase
    
    private init() {}
    
    // MARK: - Fetch Trainers
    
    func fetchTrainers() async throws -> [GolfTrainer] {
        print("🏌️ Fetching golf trainers...")
        
        do {
            try await AuthSessionManager.shared.ensureValidSession()
            
            let result: [GolfTrainer] = try await supabase.database
                .from("trainer_profiles")
                .select()
                .eq("is_active", value: true)
                .order("created_at", ascending: false)
                .execute()
                .value
            
            print("✅ Fetched \(result.count) trainers")
            return result
        } catch {
            print("❌ Failed to fetch trainers: \(error)")
            throw error
        }
    }
    
    // MARK: - Create Trainer Profile
    
    func createTrainerProfile(
        name: String,
        description: String,
        hourlyRate: Int,
        handicap: Int,
        latitude: Double,
        longitude: Double
    ) async throws -> GolfTrainer {
        print("🏌️ Creating trainer profile...")
        
        guard let userId = try? await supabase.auth.session.user.id else {
            throw TrainerServiceError.notAuthenticated
        }
        
        try await AuthSessionManager.shared.ensureValidSession()
        
        // Get user's avatar URL
        let profile = try? await supabase.database
            .from("profiles")
            .select("avatar_url")
            .eq("id", value: userId)
            .single()
            .execute()
            .value as [String: String]?
        
        let avatarUrl = profile?["avatar_url"]
        
        let params: [String: AnyEncodable] = [
            "user_id": AnyEncodable(userId.uuidString),
            "name": AnyEncodable(name),
            "description": AnyEncodable(description),
            "hourly_rate": AnyEncodable(hourlyRate),
            "handicap": AnyEncodable(handicap),
            "latitude": AnyEncodable(latitude),
            "longitude": AnyEncodable(longitude),
            "avatar_url": AnyEncodable(avatarUrl),
            "is_active": AnyEncodable(true)
        ]
        
        let result: GolfTrainer = try await supabase.database
            .from("trainer_profiles")
            .insert(params)
            .select()
            .single()
            .execute()
            .value
        
        print("✅ Created trainer profile: \(result.id)")
        return result
    }
    
    // MARK: - Update Trainer Profile
    
    func updateTrainerProfile(
        trainerId: UUID,
        name: String? = nil,
        description: String? = nil,
        hourlyRate: Int? = nil,
        handicap: Int? = nil,
        latitude: Double? = nil,
        longitude: Double? = nil,
        isActive: Bool? = nil
    ) async throws {
        print("🏌️ Updating trainer profile...")
        
        try await AuthSessionManager.shared.ensureValidSession()
        
        var params: [String: AnyEncodable] = [:]
        
        if let name = name { params["name"] = AnyEncodable(name) }
        if let description = description { params["description"] = AnyEncodable(description) }
        if let hourlyRate = hourlyRate { params["hourly_rate"] = AnyEncodable(hourlyRate) }
        if let handicap = handicap { params["handicap"] = AnyEncodable(handicap) }
        if let latitude = latitude { params["latitude"] = AnyEncodable(latitude) }
        if let longitude = longitude { params["longitude"] = AnyEncodable(longitude) }
        if let isActive = isActive { params["is_active"] = AnyEncodable(isActive) }
        
        try await supabase.database
            .from("trainer_profiles")
            .update(params)
            .eq("id", value: trainerId)
            .execute()
        
        print("✅ Updated trainer profile")
    }
    
    // MARK: - Check if User is Trainer
    
    func isUserTrainer() async throws -> Bool {
        guard let userId = try? await supabase.auth.session.user.id else {
            return false
        }
        
        try await AuthSessionManager.shared.ensureValidSession()
        
        let result: [GolfTrainer] = try await supabase.database
            .from("trainer_profiles")
            .select()
            .eq("user_id", value: userId)
            .execute()
            .value
        
        return !result.isEmpty
    }
    
    // MARK: - Get User's Trainer Profile
    
    func getUserTrainerProfile() async throws -> GolfTrainer? {
        guard let userId = try? await supabase.auth.session.user.id else {
            return nil
        }
        
        try await AuthSessionManager.shared.ensureValidSession()
        
        let result: [GolfTrainer] = try await supabase.database
            .from("trainer_profiles")
            .select()
            .eq("user_id", value: userId)
            .execute()
            .value
        
        return result.first
    }
}

enum TrainerServiceError: Error, LocalizedError {
    case notAuthenticated
    case profileAlreadyExists
    
    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "Du måste vara inloggad för att bli tränare"
        case .profileAlreadyExists:
            return "Du har redan en tränarprofil"
        }
    }
}

// Helper for encoding any value
struct AnyEncodable: Encodable {
    private let _encode: (Encoder) throws -> Void
    
    init<T: Encodable>(_ wrapped: T) {
        _encode = wrapped.encode
    }
    
    func encode(to encoder: Encoder) throws {
        try _encode(encoder)
    }
}

