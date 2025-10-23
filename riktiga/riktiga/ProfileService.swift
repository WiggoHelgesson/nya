import Foundation
import Supabase

class ProfileService {
    static let shared = ProfileService()
    private let supabase = SupabaseConfig.supabase
    
    func fetchUserProfile(userId: String) async throws -> User? {
        do {
            let profiles: [User] = try await supabase
                .from("profiles")
                .select("id, username, current_xp, current_level, is_pro_member")
                .eq("id", value: userId)
                .execute()
                .value
            
            return profiles.first
        } catch {
            print("Error fetching profile: \(error)")
            return nil
        }
    }
    
    func updateUserXP(userId: String, xpToAdd: Int) async throws {
        // För nu hoppar vi RPC - kan implementeras senare
        print("XP update called: userId: \(userId), xp: \(xpToAdd)")
    }
}
