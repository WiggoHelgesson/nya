import Foundation
import Supabase

class ProfileService {
    static let shared = ProfileService()
    private let supabase = SupabaseConfig.supabase
    
    func fetchUserProfile(userId: String) async throws -> User? {
        do {
            print("🔍 Fetching profile for userId: \(userId)")
            
            // Hämta raw data från Supabase
            let response = try await supabase
                .from("profiles")
                .select()
                .eq("id", value: userId)
                .execute()
            
            print("📦 Response data: \(response.data)")
            
            let profiles: [User] = try await supabase
                .from("profiles")
                .select("id, username, current_xp, current_level, is_pro_member")
                .eq("id", value: userId)
                .execute()
                .value
            
            print("✅ Fetched profiles: \(profiles)")
            
            if let profile = profiles.first {
                print("💾 Profile found: \(profile.name), XP: \(profile.currentXP)")
                return profile
            } else {
                print("❌ No profile found for userId: \(userId)")
                return nil
            }
        } catch {
            print("❌ Error fetching profile: \(error)")
            print("Error details: \(error.localizedDescription)")
            return nil
        }
    }
    
    func updateUserXP(userId: String, xpToAdd: Int) async throws {
        // För nu hoppar vi RPC - kan implementeras senare
        print("XP update called: userId: \(userId), xp: \(xpToAdd)")
    }
}
