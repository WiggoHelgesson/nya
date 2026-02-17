import Foundation
import Supabase
import Combine

// MARK: - Referral Models
struct ReferralCode: Codable, Identifiable {
    let id: String
    let userId: String
    let code: String
    let createdAt: String
    let lastCodeEditedAt: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case code
        case createdAt = "created_at"
        case lastCodeEditedAt = "last_code_edited_at"
    }
}

struct ReferralUsage: Codable, Identifiable {
    let id: String
    let referralCodeId: String
    let referredUserId: String
    let createdAt: String
    
    enum CodingKeys: String, CodingKey {
        case id
        case referralCodeId = "referral_code_id"
        case referredUserId = "referred_user_id"
        case createdAt = "created_at"
    }
}

struct ReferralEarning: Codable, Identifiable {
    let id: String
    let referralCodeId: String
    let referredUserId: String
    let amountSek: Double
    let purchaseType: String
    let createdAt: String
    
    enum CodingKeys: String, CodingKey {
        case id
        case referralCodeId = "referral_code_id"
        case referredUserId = "referred_user_id"
        case amountSek = "amount_sek"
        case purchaseType = "purchase_type"
        case createdAt = "created_at"
    }
}

struct ReferralPayout: Codable, Identifiable {
    let id: String
    let userId: String
    let amountSek: Double
    let status: String // pending, processing, completed, failed
    let stripeTransferId: String?
    let createdAt: String
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case amountSek = "amount_sek"
        case status
        case stripeTransferId = "stripe_transfer_id"
        case createdAt = "created_at"
    }
}

struct ReferralStats {
    let totalReferrals: Int
    let totalEarnings: Double
    let pendingEarnings: Double
    let paidOutEarnings: Double
    let canWithdraw: Bool
}

struct SupportingCodeInfo {
    let code: String
    let ownerUsername: String
    let ownerId: String
}

// MARK: - Referral Service
class ReferralService: ObservableObject {
    static let shared = ReferralService()
    
    private let supabase = SupabaseConfig.supabase
    private let commissionRate: Double = 0.40 // 40%
    private let minimumWithdrawal: Double = 300.0 // 300 SEK
    
    @Published var myReferralCode: String?
    @Published var referralStats: ReferralStats?
    @Published var isLoading = false
    
    private init() {}
    
    // MARK: - Generate Unique Code
    private func generateUniqueCode() -> String {
        let characters = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        let length = 6
        return String((0..<length).map { _ in characters.randomElement()! })
    }
    
    // MARK: - Get or Create Referral Code
    func getOrCreateReferralCode(userId: String) async throws -> String {
        // First try to get existing code
        struct CodeRecord: Decodable {
            let code: String
        }
        
        let existingCodes: [CodeRecord] = try await supabase
            .from("referral_codes")
            .select("code")
            .eq("user_id", value: userId)
            .limit(1)
            .execute()
            .value
        
        if let existing = existingCodes.first {
            await MainActor.run {
                self.myReferralCode = existing.code
            }
            return existing.code
        }
        
        // Generate new unique code
        var newCode = generateUniqueCode()
        var attempts = 0
        let maxAttempts = 10
        
        while attempts < maxAttempts {
            // Check if code already exists
            let existingWithCode: [CodeRecord] = try await supabase
                .from("referral_codes")
                .select("code")
                .eq("code", value: newCode)
                .limit(1)
                .execute()
                .value
            
            if existingWithCode.isEmpty {
                break
            }
            
            newCode = generateUniqueCode()
            attempts += 1
        }
        
        // Insert new code
        struct NewCode: Encodable {
            let id: String
            let user_id: String
            let code: String
        }
        
        let codeToInsert = NewCode(
            id: UUID().uuidString,
            user_id: userId,
            code: newCode
        )
        
        try await supabase
            .from("referral_codes")
            .insert(codeToInsert)
            .execute()
        
        await MainActor.run {
            self.myReferralCode = newCode
        }
        
        print("✅ Created new referral code: \(newCode)")
        return newCode
    }
    
    // MARK: - Get Last Code Edit Date
    func getLastCodeEditDate(userId: String) async throws -> Date? {
        struct CodeEditDate: Decodable {
            let last_code_edited_at: String?
            let created_at: String
        }
        
        let codes: [CodeEditDate] = try await supabase
            .from("referral_codes")
            .select("last_code_edited_at, created_at")
            .eq("user_id", value: userId)
            .limit(1)
            .execute()
            .value
        
        guard let code = codes.first else { return nil }
        
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        // Return last edit date if exists, otherwise return created date
        if let lastEdit = code.last_code_edited_at {
            return dateFormatter.date(from: lastEdit)
        }
        
        // Fallback without fractional seconds
        dateFormatter.formatOptions = [.withInternetDateTime]
        if let lastEdit = code.last_code_edited_at {
            return dateFormatter.date(from: lastEdit)
        }
        
        return dateFormatter.date(from: code.created_at)
    }
    
    // MARK: - Check if Can Edit Code (every 6 days)
    func canEditCode(userId: String) async throws -> (canEdit: Bool, daysUntilEdit: Int) {
        guard let lastEditDate = try await getLastCodeEditDate(userId: userId) else {
            return (true, 0) // No code yet, can create
        }
        
        let daysSinceEdit = Calendar.current.dateComponents([.day], from: lastEditDate, to: Date()).day ?? 0
        let editIntervalDays = 6
        
        if daysSinceEdit >= editIntervalDays {
            return (true, 0)
        } else {
            return (false, editIntervalDays - daysSinceEdit)
        }
    }
    
    // MARK: - Update Referral Code
    func updateReferralCode(userId: String, newCode: String) async throws -> Bool {
        let normalizedCode = newCode.uppercased().trimmingCharacters(in: .whitespaces)
        
        // Validate code format (alphanumeric, 3-12 characters)
        let allowedCharacters = CharacterSet.alphanumerics
        guard normalizedCode.unicodeScalars.allSatisfy({ allowedCharacters.contains($0) }),
              normalizedCode.count >= 3,
              normalizedCode.count <= 12 else {
            print("❌ Invalid code format")
            return false
        }
        
        // First, get the user's current code
        struct CurrentCode: Decodable {
            let code: String
        }
        
        let currentCodeResult: [CurrentCode] = try await supabase
            .from("referral_codes")
            .select("code")
            .eq("user_id", value: userId)
            .limit(1)
            .execute()
            .value
        
        // If the user already has this exact code, just return success (no change needed)
        if let currentCode = currentCodeResult.first?.code, 
           currentCode.uppercased() == normalizedCode {
            print("✅ Code is already set to \(normalizedCode), no update needed")
            await MainActor.run {
                self.myReferralCode = normalizedCode
            }
            return true
        }
        
        // Check if user can edit (only if actually changing the code)
        let (canEdit, _) = try await canEditCode(userId: userId)
        guard canEdit else {
            print("❌ Cannot edit code yet - 6 days haven't passed")
            return false
        }
        
        // Use RPC function to update the code (bypasses RLS issues)
        let params: [String: String] = [
            "p_user_id": userId,
            "p_new_code": normalizedCode
        ]
        
        struct RPCResult: Decodable, Sendable {
            let success: Bool
            let error: String?
            let code: String?
        }
        
        let result: RPCResult = try await supabase.database
            .rpc("update_referral_code", params: params)
            .execute()
            .value
        
        if result.success, let updatedCode = result.code {
            print("✅ Code successfully updated to \(updatedCode) via RPC")
            await MainActor.run {
                self.myReferralCode = updatedCode
            }
            return true
        } else {
            let errorMsg = result.error ?? "Unknown error"
            print("❌ RPC update failed: \(errorMsg)")
            return false
        }
    }
    
    // MARK: - Validate and Use Referral Code
    func useReferralCode(code: String, referredUserId: String) async throws -> Bool {
        // Find the referral code
        struct CodeWithId: Decodable {
            let id: String
            let user_id: String
        }
        
        let codes: [CodeWithId] = try await supabase
            .from("referral_codes")
            .select("id, user_id")
            .eq("code", value: code.uppercased())
            .limit(1)
            .execute()
            .value
        
        guard let referralCode = codes.first else {
            print("❌ Referral code not found: \(code)")
            return false
        }
        
        // Make sure user isn't using their own code
        if referralCode.user_id.lowercased() == referredUserId.lowercased() {
            print("❌ Cannot use own referral code")
            return false
        }
        
        // Check if user has already used a referral code
        struct UsageCheck: Decodable {
            let id: String
        }
        
        let existingUsage: [UsageCheck] = try await supabase
            .from("referral_usages")
            .select("id")
            .eq("referred_user_id", value: referredUserId)
            .limit(1)
            .execute()
            .value
        
        if !existingUsage.isEmpty {
            print("❌ User has already used a referral code")
            return false
        }
        
        // Record the usage
        struct NewUsage: Encodable {
            let id: String
            let referral_code_id: String
            let referred_user_id: String
        }
        
        let usage = NewUsage(
            id: UUID().uuidString,
            referral_code_id: referralCode.id,
            referred_user_id: referredUserId
        )
        
        try await supabase
            .from("referral_usages")
            .insert(usage)
            .execute()
        
        print("✅ Referral code used successfully")
        return true
    }
    
    // MARK: - Record Earning (Call this when referred user makes a purchase)
    func recordEarning(referredUserId: String, purchaseAmountSek: Double, purchaseType: String) async throws {
        // Find if this user was referred
        struct UsageWithCode: Decodable {
            let referral_code_id: String
        }
        
        let usages: [UsageWithCode] = try await supabase
            .from("referral_usages")
            .select("referral_code_id")
            .eq("referred_user_id", value: referredUserId)
            .limit(1)
            .execute()
            .value
        
        guard let usage = usages.first else {
            print("ℹ️ User was not referred, no earning to record")
            return
        }
        
        // Calculate commission
        let commission = purchaseAmountSek * commissionRate
        
        // Record the earning
        struct NewEarning: Encodable {
            let id: String
            let referral_code_id: String
            let referred_user_id: String
            let amount_sek: Double
            let purchase_type: String
        }
        
        let earning = NewEarning(
            id: UUID().uuidString,
            referral_code_id: usage.referral_code_id,
            referred_user_id: referredUserId,
            amount_sek: commission,
            purchase_type: purchaseType
        )
        
        try await supabase
            .from("referral_earnings")
            .insert(earning)
            .execute()
        
        print("✅ Recorded referral earning: \(commission) SEK")
    }
    
    // MARK: - Get Referral Stats
    func getReferralStats(userId: String) async throws -> ReferralStats {
        await MainActor.run {
            self.isLoading = true
        }
        
        defer {
            Task { @MainActor in
                self.isLoading = false
            }
        }
        
        // Get user's referral code ID
        struct CodeId: Decodable {
            let id: String
        }
        
        let codes: [CodeId] = try await supabase
            .from("referral_codes")
            .select("id")
            .eq("user_id", value: userId)
            .limit(1)
            .execute()
            .value
        
        guard let codeRecord = codes.first else {
            let emptyStats = ReferralStats(
                totalReferrals: 0,
                totalEarnings: 0,
                pendingEarnings: 0,
                paidOutEarnings: 0,
                canWithdraw: false
            )
            await MainActor.run {
                self.referralStats = emptyStats
            }
            return emptyStats
        }
        
        // Count referrals
        struct UsageCount: Decodable {
            let id: String
        }
        
        let usages: [UsageCount] = try await supabase
            .from("referral_usages")
            .select("id")
            .eq("referral_code_id", value: codeRecord.id)
            .execute()
            .value
        
        let totalReferrals = usages.count
        
        // Sum earnings
        struct EarningAmount: Decodable {
            let amount_sek: Double
        }
        
        let earnings: [EarningAmount] = try await supabase
            .from("referral_earnings")
            .select("amount_sek")
            .eq("referral_code_id", value: codeRecord.id)
            .execute()
            .value
        
        let totalEarnings = earnings.reduce(0) { $0 + $1.amount_sek }
        
        // Sum payouts
        struct PayoutAmount: Decodable {
            let amount_sek: Double
        }
        
        let payouts: [PayoutAmount] = try await supabase
            .from("referral_payouts")
            .select("amount_sek")
            .eq("user_id", value: userId)
            .eq("status", value: "completed")
            .execute()
            .value
        
        let paidOutEarnings = payouts.reduce(0) { $0 + $1.amount_sek }
        let pendingEarnings = totalEarnings - paidOutEarnings
        
        let stats = ReferralStats(
            totalReferrals: totalReferrals,
            totalEarnings: totalEarnings,
            pendingEarnings: pendingEarnings,
            paidOutEarnings: paidOutEarnings,
            canWithdraw: pendingEarnings >= minimumWithdrawal
        )
        
        await MainActor.run {
            self.referralStats = stats
        }
        
        return stats
    }
    
    // MARK: - Request Payout (Stripe Connect)
    func requestPayout(userId: String) async throws -> Bool {
        // Get current stats
        let stats = try await getReferralStats(userId: userId)
        
        guard stats.canWithdraw else {
            print("❌ Cannot withdraw: minimum not reached")
            return false
        }
        
        // Create payout request
        struct NewPayout: Encodable {
            let id: String
            let user_id: String
            let amount_sek: Double
            let status: String
        }
        
        let payoutId = UUID().uuidString
        let payout = NewPayout(
            id: payoutId,
            user_id: userId,
            amount_sek: stats.pendingEarnings,
            status: "pending"
        )
        
        try await supabase
            .from("referral_payouts")
            .insert(payout)
            .execute()
        
        print("✅ Payout request created for \(stats.pendingEarnings) SEK")
        
        // Process payout via Edge Function
        let result = try await callEdgeFunction(
            action: "process_payout",
            payoutId: payoutId
        )
        
        return result
    }
    
    // MARK: - Stripe Connect Methods
    
    /// Check if user has a Stripe Connect account set up
    func checkStripeAccountStatus() async throws -> StripeAccountStatus {
        let response = try await callEdgeFunction(action: "check_account_status", payoutId: nil)
        
        // Parse response - for now return basic status
        return StripeAccountStatus(
            hasAccount: response,
            canReceivePayouts: response,
            needsOnboarding: !response
        )
    }
    
    /// Create a new Stripe Connect account for the user
    func createStripeConnectAccount() async throws -> String? {
        // This returns the onboarding URL
        guard let url = URL(string: "\(SupabaseConfig.projectURL.absoluteString)/functions/v1/process-referral-payout") else {
            throw NSError(domain: "ReferralService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Get auth token
        let session = try await supabase.auth.session
        request.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")
        
        let body = ["action": "create_connect_account"]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, _) = try await URLSession.shared.data(for: request)
        
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let onboardingUrl = json["onboardingUrl"] as? String {
            return onboardingUrl
        }
        
        return nil
    }
    
    /// Get the Stripe Connect onboarding URL for an existing account
    func getStripeOnboardingUrl() async throws -> String? {
        guard let url = URL(string: "\(SupabaseConfig.projectURL.absoluteString)/functions/v1/process-referral-payout") else {
            throw NSError(domain: "ReferralService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let session = try await supabase.auth.session
        request.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")
        
        let body = ["action": "get_onboarding_link"]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, _) = try await URLSession.shared.data(for: request)
        
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let onboardingUrl = json["onboardingUrl"] as? String {
            return onboardingUrl
        }
        
        return nil
    }
    
    // MARK: - Private Helper
    private func callEdgeFunction(action: String, payoutId: String?) async throws -> Bool {
        guard let url = URL(string: "\(SupabaseConfig.projectURL.absoluteString)/functions/v1/process-referral-payout") else {
            throw NSError(domain: "ReferralService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Get auth token
        let session = try await supabase.auth.session
        request.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")
        
        var body: [String: Any] = ["action": action]
        if let payoutId = payoutId {
            body["payoutId"] = payoutId
        }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, _) = try await URLSession.shared.data(for: request)
        
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let success = json["success"] as? Bool {
            if !success, let error = json["error"] as? String {
                throw NSError(domain: "ReferralService", code: -1, userInfo: [NSLocalizedDescriptionKey: error])
            }
            return success
        }
        
        return false
    }
    
    // MARK: - Check if Code is Valid
    func isCodeValid(code: String) async -> Bool {
        struct CodeCheck: Decodable {
            let id: String
        }
        
        do {
            let codes: [CodeCheck] = try await supabase
                .from("referral_codes")
                .select("id")
                .eq("code", value: code.uppercased())
                .limit(1)
                .execute()
                .value
            
            return !codes.isEmpty
        } catch {
            print("❌ Error checking code: \(error)")
            return false
        }
    }
    
    // MARK: - Get Current Supporting Code
    
    /// Get information about which referral code the user is currently supporting (if any)
    func getCurrentSupportingCode(userId: String) async throws -> SupportingCodeInfo? {
        // Check if user has used a referral code
        struct UsageWithCodeInfo: Decodable {
            let referral_code_id: String
        }
        
        let usages: [UsageWithCodeInfo] = try await supabase
            .from("referral_usages")
            .select("referral_code_id")
            .eq("referred_user_id", value: userId)
            .limit(1)
            .execute()
            .value
        
        guard let usage = usages.first else {
            return nil // User hasn't used any referral code
        }
        
        // Get the referral code details
        struct CodeWithOwner: Decodable {
            let code: String
            let user_id: String
        }
        
        let codes: [CodeWithOwner] = try await supabase
            .from("referral_codes")
            .select("code, user_id")
            .eq("id", value: usage.referral_code_id)
            .limit(1)
            .execute()
            .value
        
        guard let codeInfo = codes.first else {
            return nil
        }
        
        // Get the owner's username
        struct ProfileInfo: Decodable {
            let username: String?
        }
        
        let profiles: [ProfileInfo] = try await supabase
            .from("profiles")
            .select("username")
            .eq("id", value: codeInfo.user_id)
            .limit(1)
            .execute()
            .value
        
        let ownerUsername = profiles.first?.username ?? "Okänd användare"
        
        return SupportingCodeInfo(
            code: codeInfo.code,
            ownerUsername: ownerUsername,
            ownerId: codeInfo.user_id
        )
    }
    
    // MARK: - Change Supporting Code
    
    /// Change which referral code the user is supporting
    /// Uses an RPC function (SECURITY DEFINER) to bypass RLS restrictions on referral_usages
    func changeSupportingCode(userId: String, newCode: String) async throws -> Bool {
        let normalizedCode = newCode.uppercased().trimmingCharacters(in: .whitespaces)
        
        guard normalizedCode.count >= 3, normalizedCode.count <= 12 else {
            print("❌ Invalid code format")
            return false
        }
        
        let params: [String: String] = [
            "p_user_id": userId,
            "p_new_code": normalizedCode
        ]
        
        struct RPCResult: Decodable, Sendable {
            let success: Bool
            let error: String?
            let message: String?
        }
        
        let result: RPCResult = try await supabase.database
            .rpc("change_support_code", params: params)
            .execute()
            .value
        
        if result.success {
            print("✅ Changed supporting code to: \(normalizedCode)")
            return true
        } else {
            let errorMsg = result.error ?? "Unknown error"
            print("❌ Change support code failed: \(errorMsg)")
            return false
        }
    }
}

// MARK: - Stripe Account Status
struct StripeAccountStatus {
    let hasAccount: Bool
    let canReceivePayouts: Bool
    let needsOnboarding: Bool
}

