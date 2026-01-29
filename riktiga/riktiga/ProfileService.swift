import Foundation
import UIKit
import Supabase
import PostgREST

class ProfileService {
    static let shared = ProfileService()
    private let supabase = SupabaseConfig.supabase
    private var personalBestColumnsAvailable: Bool?
    private let avatarBucket = "profile-images"
    
    private struct UsernameRow: Decodable { let id: String }
    
    func isUsernameAvailable(_ username: String, excludingUserId: String? = nil) async -> Bool {
        let trimmed = username.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        
        do {
            var query = supabase
                .from("profiles")
                .select("id", count: .exact)
                .ilike("username", value: trimmed)
            
            if let excludingUserId {
                query = query.neq("id", value: excludingUserId)
            }
            
            let response: PostgrestResponse<[UsernameRow]> = try await query
                .limit(1)
                .execute()
            let count = response.count ?? response.value.count
            return count == 0
        } catch {
            print("⚠️ Username availability check failed: \(error.localizedDescription)")
            return false
        }
    }
    
    func fetchUserProfile(userId: String) async throws -> User? {
        do {
            try await AuthSessionManager.shared.ensureValidSession()
            print("🔍 Fetching profile for userId: \(userId)")
            
            // Försök att dekoda - Email finns INTE i profiles tabellen
            do {
                let baseColumns = "id, username, current_xp, current_level, is_pro_member, avatar_url, banner_url, climbed_mountains, completed_races"
                let personalBestColumns = ", pb_5km_minutes, pb_10km_hours, pb_10km_minutes, pb_marathon_hours, pb_marathon_minutes"
                var profiles: [User]
                let shouldAttemptPBColumns = personalBestColumnsAvailable ?? true

                if shouldAttemptPBColumns {
                    do {
                        profiles = try await supabase
                            .from("profiles")
                            .select(baseColumns + personalBestColumns)
                            .eq("id", value: userId)
                            .execute()
                            .value
                        personalBestColumnsAvailable = true
                    } catch {
                        if isMissingPersonalBestColumnsError(error) {
                            personalBestColumnsAvailable = false
                            print("ℹ️ Personal best columns missing. Falling back to basic profile select.")
                            profiles = try await supabase
                                .from("profiles")
                                .select(baseColumns)
                                .eq("id", value: userId)
                                .execute()
                                .value
                        } else {
                            throw error
                        }
                    }
                } else {
                    profiles = try await supabase
                        .from("profiles")
                        .select(baseColumns)
                        .eq("id", value: userId)
                        .execute()
                        .value
                }

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
            
            let profileData: [String: DynamicEncodable] = [
                "id": DynamicEncodable(user.id),
                "username": DynamicEncodable(user.name),
                "current_xp": DynamicEncodable(0),
                "current_level": DynamicEncodable(1),
                "is_pro_member": DynamicEncodable(false),
                "avatar_url": DynamicEncodable(user.avatarUrl ?? "")
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
    
    func updateUsername(userId: String, username: String) async throws {
        do {
            print("🔄 Updating username for userId: \(userId), username: \(username)")
            
            try await supabase
                .from("profiles")
                .update(["username": username])
                .eq("id", value: userId)
                .execute()
            
            print("✅ Username updated successfully")
        } catch {
            print("❌ Error updating username: \(error)")
            throw error
        }
    }
    
    func applyOnboardingData(userId: String, data: OnboardingData) async -> String? {
        var updates: [String: DynamicEncodable] = [:]
        if !data.trimmedUsername.isEmpty {
            let isAvailable = await isUsernameAvailable(data.trimmedUsername, excludingUserId: userId)
            if isAvailable {
                updates["username"] = DynamicEncodable(data.trimmedUsername)
            } else {
                print("⚠️ Username \(data.trimmedUsername) already taken. Skipping update for userId: \(userId)")
            }
        }
        if let golfHcp = data.golfHcp {
            updates["golf_hcp"] = DynamicEncodable(golfHcp)
        }
        if let pb5 = data.pb5kmMinutes {
            updates["pb_5km_minutes"] = DynamicEncodable(pb5)
        }
        if let pb10h = data.pb10kmHours {
            updates["pb_10km_hours"] = DynamicEncodable(pb10h)
        }
        if let pb10m = data.pb10kmMinutes {
            updates["pb_10km_minutes"] = DynamicEncodable(pb10m)
        }
        if let pbMaraH = data.pbMarathonHours {
            updates["pb_marathon_hours"] = DynamicEncodable(pbMaraH)
        }
        if let pbMaraM = data.pbMarathonMinutes {
            updates["pb_marathon_minutes"] = DynamicEncodable(pbMaraM)
        }
        
        var newAvatarURL: String?
        if let imageData = data.profileImageData {
            do {
                newAvatarURL = try await uploadAvatarImageData(imageData, userId: userId)
                if let url = newAvatarURL {
                    updates["avatar_url"] = DynamicEncodable(url)
                }
            } catch {
                print("⚠️ Failed to upload onboarding profile image: \(error.localizedDescription)")
            }
        }
        
        guard !updates.isEmpty else { return newAvatarURL }
        
        do {
            try await supabase
                .from("profiles")
                .update(updates)
                .eq("id", value: userId)
                .execute()
            print("✅ Applied onboarding data for userId: \(userId)")
        } catch {
            print("⚠️ Failed to apply onboarding data: \(error.localizedDescription)")
        }
        return newAvatarURL
    }

    func uploadAvatarImageData(_ imageData: Data, userId: String) async throws -> String {
        let dataToUpload: Data
        if let image = UIImage(data: imageData),
           let jpegData = image.jpegData(compressionQuality: 0.85) {
            dataToUpload = jpegData
        } else {
            dataToUpload = imageData
        }
        
        let timestamp = Int(Date().timeIntervalSince1970)
        let fileName = "\(userId)_avatar_\(timestamp).jpg"
        
        print("🔄 Uploading profile image: \(fileName) to bucket: \(avatarBucket)")
        
        do {
            // Try upload with upsert=true to overwrite if exists
            try await supabase.storage
                .from(avatarBucket)
                .upload(
                    fileName,
                    data: dataToUpload,
                    options: FileOptions(contentType: "image/jpeg", upsert: true)
                )
            
            print("✅ Upload successful: \(fileName)")
            
            let publicURL = try supabase.storage
                .from(avatarBucket)
                .getPublicURL(path: fileName)
            
            print("✅ Public URL generated: \(publicURL.absoluteString)")
            return publicURL.absoluteString
            
        } catch let uploadError {
            print("❌ Upload failed with error: \(uploadError)")
            print("❌ Error details: \(uploadError.localizedDescription)")
            
            let message = uploadError.localizedDescription.lowercased()
            
            // If bucket doesn't exist, create it
            if message.contains("bucket not found") || message.contains("does not exist") {
                print("⚠️ Bucket not found, creating bucket: \(avatarBucket)")
                do {
                    try await supabase.storage.createBucket(
                        avatarBucket,
                        options: BucketOptions(public: true)
                    )
                    print("✅ Bucket created successfully")
                } catch let createError {
                    print("❌ Failed to create bucket: \(createError.localizedDescription)")
                    throw createError
                }
                
                // Retry upload after creating bucket
                print("🔄 Retrying upload after bucket creation...")
                try await supabase.storage
                    .from(avatarBucket)
                    .upload(fileName, data: dataToUpload, options: FileOptions(contentType: "image/jpeg", upsert: true))
                
                let publicURL = try supabase.storage
                    .from(avatarBucket)
                    .getPublicURL(path: fileName)
                return publicURL.absoluteString
            }
            
            // For RLS policy errors, provide helpful error message
            if message.contains("row-level security") || message.contains("policy") {
                print("❌ RLS Policy Error - The database is blocking the upload")
                throw NSError(
                    domain: "ProfileService",
                    code: 403,
                    userInfo: [
                        NSLocalizedDescriptionKey: "Databasregeln blockerar uppladdningen. Kör SQL-skriptet i Supabase SQL Editor för att fixa detta."
                    ]
                )
            }
            
            // Re-throw original error
            throw uploadError
        }
    }
    
    func updateUserAvatar(userId: String, imageData: Data) async throws -> String {
        let publicURL = try await uploadAvatarImageData(imageData, userId: userId)
        
        try await supabase
            .from("profiles")
            .update(["avatar_url": publicURL])
            .eq("id", value: userId)
            .execute()
        
        return publicURL
    }
    
    func deleteUserAccount(userId: String) async throws {
        do {
            print("🗑️ Deleting user account for userId: \(userId)")
            
            // 1) Ta bort relationer (likes, comments, follows, notifications, monthly steps)
            _ = try await supabase
                .from("workout_post_likes")
                .delete()
                .eq("user_id", value: userId)
                .execute()

            _ = try await supabase
                .from("workout_post_comments")
                .delete()
                .eq("user_id", value: userId)
                .execute()

            _ = try await supabase
                .from("user_follows")
                .delete()
                .or("follower_id.eq.\(userId),following_id.eq.\(userId)")
                .execute()

            _ = try await supabase
                .from("notifications")
                .delete()
                .or("user_id.eq.\(userId),triggered_by_user_id.eq.\(userId)")
                .execute()

            _ = try await supabase
                .from("monthly_steps")
                .delete()
                .eq("user_id", value: userId)
                .execute()

            // 2) Ta bort användarens inlägg
            _ = try await supabase
                .from("workout_posts")
                .delete()
                .eq("user_id", value: userId)
                .execute()

            // 3) Ta bort användarens profil från databasen
            try await supabase
                .from("profiles")
                .delete()
                .eq("id", value: userId)
                .execute()
            
            // 4) Försök även radera auth-användaren via Edge Function (om konfigurerad)
            do {
                let session = try await supabase.auth.session
                try await deleteAuthUserViaEdgeFunction(userId: userId, accessToken: session.accessToken)
            } catch {
                print("ℹ️ Could not call delete-user edge function: \(error)")
            }
            
            // Logga ut lokalt
            try? await supabase.auth.signOut()
            
            print("✅ User account deleted successfully")
        } catch {
            print("❌ Error deleting user account: \(error)")
            throw error
        }
    }

    // MARK: - Edge Function call to delete auth user
    private func deleteAuthUserViaEdgeFunction(userId: String, accessToken: String) async throws {
        // Build function URL: https://<project>.functions.supabase.co/delete-user
        guard let host = SupabaseConfig.projectURL.host,
              let scheme = SupabaseConfig.projectURL.scheme else {
            throw NSError(domain: "EdgeFunction", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid Supabase URL"])
        }
        var components = URLComponents()
        components.scheme = scheme
        components.host = host
        components.path = "/functions/v1/delete-user"
        guard let url = components.url else {
            throw NSError(domain: "EdgeFunction", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid delete-user URL"])
        }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.addValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        req.addValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: String] = ["userId": userId]
        req.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])
        let (_, resp) = try await URLSession.shared.data(for: req)
        if let http = resp as? HTTPURLResponse, http.statusCode >= 400 {
            throw NSError(domain: "EdgeFunction", code: http.statusCode, userInfo: [NSLocalizedDescriptionKey: "delete-user failed with status \(http.statusCode)"])
        }
        print("✅ Edge function delete-user invoked successfully")
    }

    func hasPersonalBestColumns() -> Bool {
        personalBestColumnsAvailable ?? true
    }

    func isMissingPersonalBestColumnsError(_ error: Error) -> Bool {
        guard let postgrestError = error as? PostgrestError else { return false }
        let missingColumnCodes: Set<String> = ["42703", "PGRST204"]
        if let code = postgrestError.code, missingColumnCodes.contains(code) {
            return true
        }
        return false
    }
}
