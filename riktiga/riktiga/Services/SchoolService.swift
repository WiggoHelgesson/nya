import Foundation
import Supabase

struct School: Decodable, Identifiable {
    let id: String
    let name: String
    let type: String
    let status: String
    let municipality: String?
}

class SchoolService {
    static let shared = SchoolService()
    private let supabase = SupabaseConfig.supabase
    
    private init() {}
    
    // MARK: - Cached school list
    
    private static var cachedSchools: [School]?
    
    func fetchAllSchools() async -> [School] {
        if let cached = Self.cachedSchools {
            return cached
        }
        
        do {
            let schools: [School] = try await supabase
                .from("schools")
                .select("id, name, type, status, municipality")
                .eq("status", value: "AKTIV")
                .order("name")
                .execute()
                .value
            
            Self.cachedSchools = schools
            return schools
        } catch {
            print("⚠️ Failed to fetch schools: \(error)")
            return Self.fallbackSchools
        }
    }
    
    static let allowedDomains = AuthViewModel.allowedEmailDomains
    
    static func isAllowedDomain(_ email: String) -> Bool {
        let lower = email.lowercased()
        return allowedDomains.contains { lower.hasSuffix($0) }
    }
    
    static let institutionNames: [String: String] = [
        "elev.danderyd.se": "Danderyds gymnasium",
        "uu.se": "Uppsala universitet",
        "lu.se": "Lunds universitet",
        "su.se": "Stockholms universitet",
        "gu.se": "Göteborgs universitet",
        "umu.se": "Umeå universitet",
        "liu.se": "Linköpings universitet",
        "ki.se": "Karolinska Institutet",
        "kth.se": "KTH",
        "chalmers.se": "Chalmers",
        "ltu.se": "Luleå tekniska universitet",
        "kau.se": "Karlstads universitet",
        "lnu.se": "Linnéuniversitetet",
        "miun.se": "Mittuniversitetet",
        "mau.se": "Malmö universitet",
        "slu.se": "Sveriges lantbruksuniversitet",
        "oru.se": "Örebro universitet",
        "bth.se": "Blekinge tekniska högskola"
    ]
    
    private static let fallbackSchools: [School] = institutionNames.map { domain, name in
        School(id: domain, name: name, type: "universitet", status: "AKTIV", municipality: nil)
    }.sorted { $0.name < $1.name }
    
    static func institutionName(for email: String) -> String? {
        let lower = email.lowercased()
        for (domain, name) in institutionNames {
            if lower.hasSuffix(domain) { return name }
        }
        return nil
    }
    
    // MARK: - Verification status
    
    func isSchoolVerified(user: User) -> Bool {
        if user.verifiedSchoolEmail != nil {
            return true
        }
        return Self.isAllowedDomain(user.email)
    }
    
    // MARK: - Auto-verify users who signed up with school/university email
    
    func autoVerifyIfSchoolEmail(userId: String, email: String) async {
        guard Self.isAllowedDomain(email) else { return }
        
        do {
            try await supabase
                .from("profiles")
                .update(["verified_school_email": email.lowercased()])
                .eq("id", value: userId)
                .execute()
            print("✅ Auto-verified school/university email for user \(userId)")
        } catch {
            print("⚠️ Failed to auto-verify school email: \(error)")
        }
    }
    
    // MARK: - Send verification code via Edge Function
    
    func sendVerificationCode(email: String, userId: String) async throws -> Bool {
        let normalizedEmail = email.lowercased().trimmingCharacters(in: .whitespaces)
        
        guard Self.isAllowedDomain(normalizedEmail) else {
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
    
    static func verifiedDomain(for user: User) -> String? {
        let email = user.verifiedSchoolEmail ?? user.email
        let lower = email.lowercased()
        
        if let domainMatch = allowedDomains.first(where: { lower.hasSuffix($0) }) {
            return domainMatch
        }
        
        if lower.hasPrefix("selected@") {
            return String(lower.dropFirst("selected@".count))
        }
        
        return nil
    }
    
    func schoolName(for user: User) -> String? {
        if let name = Self.institutionName(for: user.verifiedSchoolEmail ?? user.email) {
            return name
        }
        
        let email = (user.verifiedSchoolEmail ?? user.email).lowercased()
        if email.hasPrefix("selected@") {
            let schoolId = String(email.dropFirst("selected@".count))
            return Self.cachedSchools?.first(where: { $0.id == schoolId })?.name
        }
        
        return nil
    }
    
    // MARK: - Assign school directly (no verification)
    
    func assignSchool(userId: String, schoolId: String) async {
        let marker = "selected@\(schoolId)"
        do {
            try await supabase
                .from("profiles")
                .update(["verified_school_email": marker])
                .eq("id", value: userId)
                .execute()
            print("✅ School assigned: \(schoolId) for user \(userId)")
        } catch {
            print("❌ Failed to assign school: \(error)")
        }
    }
    
    // MARK: - School feed
    
    private static let feedSelectFields = """
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
        
        let posts: [SocialWorkoutPost] = try await supabase
            .from("workout_posts")
            .select(Self.feedSelectFields)
            .in("user_id", values: ids)
            .order("created_at", ascending: false)
            .limit(50)
            .execute()
            .value
        
        return posts
    }
    
    func getSchoolFeedForDomain(_ domain: String) async throws -> [SocialWorkoutPost] {
        struct UserIdRow: Decodable {
            let user_id: String
        }
        
        let userIds: [UserIdRow] = try await supabase
            .rpc("get_school_user_ids", params: ["p_domain": domain])
            .execute()
            .value
        
        let ids = userIds.map { $0.user_id }
        
        guard !ids.isEmpty else { return [] }
        
        let posts: [SocialWorkoutPost] = try await supabase
            .from("workout_posts")
            .select(Self.feedSelectFields)
            .in("user_id", values: ids)
            .order("created_at", ascending: false)
            .limit(50)
            .execute()
            .value
        
        return posts
    }
}
