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
    
    func updateProStatus(userId: String, isPro: Bool) async throws {
        do {
            print("🔄 Updating Pro status for userId: \(userId), isPro: \(isPro)")
            
            try await supabase
                .from("profiles")
                .update(["is_pro_member": isPro])
                .eq("id", value: userId)
                .execute()
            
            print("✅ Pro status updated successfully")
        } catch {
            print("❌ Error updating Pro status: \(error)")
            throw error
        }
    }
    
    func updateUserPoints(userId: String, pointsToAdd: Int) async throws {
        do {
            print("🔄 Updating points for userId: \(userId), pointsToAdd: \(pointsToAdd)")
            
            // Get current user profile to access current XP
            guard let currentUser = try await fetchUserProfile(userId: userId) else {
                throw NSError(domain: "ProfileError", code: 1, userInfo: [NSLocalizedDescriptionKey: "User profile not found"])
            }
            
            let newXP = currentUser.currentXP + pointsToAdd
            
            // Update with new XP
            try await supabase
                .from("profiles")
                .update(["current_xp": newXP])
                .eq("id", value: userId)
                .execute()
            
            print("✅ Points updated successfully. New XP: \(newXP)")
        } catch {
            print("❌ Error updating points: \(error)")
            throw error
        }
    }
    
    func createUserProfile(_ user: User) async throws {
        do {
            print("🔧 Creating profile for user: \(user.name)")
            
            let profileData: [String: AnyEncodable] = [
                "id": AnyEncodable(user.id),
                "username": AnyEncodable(user.name),
                "current_xp": AnyEncodable(0),
                "current_level": AnyEncodable(1),
                "is_pro_member": AnyEncodable(false),
                "avatar_url": AnyEncodable(user.avatarUrl ?? "")
            ]
            
            try await supabase
                .from("profiles")
                .insert(profileData)
                .execute()
            
            print("✅ Profile created successfully for user: \(user.name)")
        } catch {
            print("❌ Error creating profile: \(error)")
            throw error
        }
    }
}
