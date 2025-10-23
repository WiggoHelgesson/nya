import Foundation
import Supabase

class ProfileService {
    static let shared = ProfileService()
    private let supabase = SupabaseConfig.supabase
    
    func fetchUserProfile(userId: String) async throws -> User? {
        do {
            print("🔍 Fetching profile for userId: \(userId)")
            
            // Försök att dekoda som User
            do {
                let profiles: [User] = try await supabase
                    .from("profiles")
                    .select("id, username, current_xp, current_level, is_pro_member")
                    .eq("id", value: userId)
                    .execute()
                    .value
                
                print("✅ Decoded profiles: \(profiles)")
                
                if let profile = profiles.first {
                    print("💾 Profile found: \(profile.name), XP: \(profile.currentXP), Level: \(profile.currentLevel)")
                    return profile
                } else {
                    print("❌ No profile found for userId: \(userId)")
                }
            } catch {
                print("⚠️ Decode error: \(error)")
                print("Error details: \(error.localizedDescription)")
            }
            
            return nil
        } catch {
            print("❌ Error fetching profile: \(error)")
            print("Error details: \(error.localizedDescription)")
            return nil
        }
    }
    
    func updateUserXP(userId: String, xpToAdd: Int) async throws {
        print("XP update called: userId: \(userId), xp: \(xpToAdd)")
    }
}
