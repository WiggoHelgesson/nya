import Foundation
import Supabase

class SchoolService {
    static let shared = SchoolService()
    private let supabase = SupabaseConfig.supabase
    
    private init() {}
    
    static let schoolDomain = "@elev.danderyd.se"
    
    // MARK: - Verification status
    
    func isSchoolVerified(user: User) -> Bool {
        if user.verifiedSchoolEmail != nil {
            return true
        }
        return user.email.lowercased().hasSuffix(Self.schoolDomain)
    }
    
    // MARK: - Auto-verify users who signed up with school email
    
    func autoVerifyIfSchoolEmail(userId: String, email: String) async {
        guard email.lowercased().hasSuffix(Self.schoolDomain) else { return }
        
        do {
            try await supabase
                .from("profiles")
                .update(["verified_school_email": email.lowercased()])
                .eq("id", value: userId)
                .execute()
            print("✅ Auto-verified school email for user \(userId)")
        } catch {
            print("⚠️ Failed to auto-verify school email: \(error)")
        }
    }
    
    // MARK: - Send verification code via Edge Function
    
    func sendVerificationCode(email: String, userId: String) async throws -> Bool {
        let normalizedEmail = email.lowercased().trimmingCharacters(in: .whitespaces)
        
        guard normalizedEmail.hasSuffix(Self.schoolDomain) else {
            return false
        }
        
        struct EdgeResponse: Decodable {
            let success: Bool
            let error: String?
        }
        
        let payload: [String: String] = [
            "user_id": userId,
            "email": normalizedEmail
        ]
        
        let response: EdgeResponse = try await supabase.functions.invoke(
            "send-school-verification",
            options: FunctionInvokeOptions(body: payload)
        )
        
        return response.success
    }
    
    // MARK: - Verify the code via RPC
    
    func verifyCode(userId: String, email: String, code: String) async throws -> Bool {
        struct RPCResult: Decodable {
            let success: Bool
            let error: String?
        }
        
        let params: [String: String] = [
            "p_user_id": userId,
            "p_email": email.lowercased().trimmingCharacters(in: .whitespaces),
            "p_code": code.trimmingCharacters(in: .whitespaces)
        ]
        
        let result: RPCResult = try await supabase
            .rpc("verify_school_code", params: params)
            .execute()
            .value
        
        if result.success {
            print("✅ School email verified: \(email)")
        }
        return result.success
    }
    
    // MARK: - School feed
    
    func getSchoolFeed() async throws -> [SocialWorkoutPost] {
        struct UserIdRow: Decodable {
            let user_id: String
        }
        
        let userIds: [UserIdRow] = try await supabase
            .rpc("get_danderyd_user_ids")
            .execute()
            .value
        
        let ids = userIds.map { $0.user_id }
        
        guard !ids.isEmpty else { return [] }
        
        let selectFields = """
            id,
            user_id,
            activity_type,
            title,
            description,
            distance,
            duration,
            image_url,
            user_image_url,
            elevation_gain,
            max_speed,
            created_at,
            split_data,
            exercises_data,
            pb_exercise_name,
            pb_value,
            streak_count,
            source,
            device_name,
            location,
            trained_with,
            route_data,
            is_public,
            profiles!workout_posts_user_id_fkey(username, avatar_url, is_pro_member),
            workout_post_likes(count),
            workout_post_comments(count)
        """
        
        let posts: [SocialWorkoutPost] = try await supabase
            .from("workout_posts")
            .select(selectFields)
            .in("user_id", values: ids)
            .order("created_at", ascending: false)
            .limit(50)
            .execute()
            .value
        
        return posts
    }
}
