import Foundation
import Supabase

class ProfileService {
    static let shared = ProfileService()
    private let supabase = SupabaseConfig.supabase
    
    func fetchUserProfile(userId: String) async throws -> User? {
        do {
            print("🔍 Fetching profile for userId: \(userId)")
            
            // Försök att dekoda - Email finns INTE i profiles tabellen
            do {
                var profiles: [User] = try await supabase
                    .from("profiles")
                    .select("id, username, current_xp, current_level, is_pro_member, avatar_url")  // Added avatar_url
                    .eq("id", value: userId)
                    .execute()
                    .value
                
                print("✅ Decoded profiles: \(profiles)")
                
                if var profile = profiles.first {
                    // Hämta email från auth.user
                    let session = try await supabase.auth.session
                    profile.email = session.user.email ?? ""
                    print("💾 Profile found: \(profile.name), Email: \(profile.email), XP: \(profile.currentXP), Level: \(profile.currentLevel), Avatar: \(profile.avatarUrl ?? "nil")")
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
