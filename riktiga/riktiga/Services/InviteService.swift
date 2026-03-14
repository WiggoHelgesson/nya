import Foundation
import Supabase

struct InviteCode: Codable, Identifiable {
    let id: String
    let code: String
    let ownerId: String
    let usedBy: String?
    let usedAt: String?
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case id, code
        case ownerId = "owner_id"
        case usedBy = "used_by"
        case usedAt = "used_at"
        case createdAt = "created_at"
    }

    var isUsed: Bool { usedBy != nil }
}

class InviteService {
    static let shared = InviteService()
    private let supabase = SupabaseConfig.supabase

    private init() {}

    // MARK: - Fetch user's invite codes

    func getMyInvites(userId: String) async throws -> [InviteCode] {
        let invites: [InviteCode] = try await supabase
            .from("invite_codes")
            .select()
            .eq("owner_id", value: userId)
            .order("created_at")
            .execute()
            .value
        return invites
    }

    // MARK: - Validate an invite code (unused)

    func validateInviteCode(code: String) async -> Bool {
        struct CodeCheck: Decodable { let id: String; let used_by: String? }

        do {
            let results: [CodeCheck] = try await supabase
                .from("invite_codes")
                .select("id, used_by")
                .eq("code", value: code.uppercased())
                .limit(1)
                .execute()
                .value

            guard let invite = results.first else { return false }
            return invite.used_by == nil
        } catch {
            print("❌ Error validating invite code: \(error)")
            return false
        }
    }

    // MARK: - Redeem an invite code via RPC

    func redeemInviteCode(code: String, userId: String) async -> Bool {
        struct RPCResult: Decodable {
            let success: Bool
            let error: String?
        }

        do {
            let params: [String: String] = [
                "p_code": code.uppercased(),
                "p_user_id": userId
            ]

            let result: RPCResult = try await supabase
                .rpc("redeem_invite_code", params: params)
                .execute()
                .value

            if result.success {
                print("✅ Invite code redeemed: \(code)")
            } else {
                print("❌ Invite redeem failed: \(result.error ?? "unknown")")
            }
            return result.success
        } catch {
            print("❌ Error redeeming invite code: \(error)")
            return false
        }
    }

    // MARK: - Share helpers

    func generateShareLink(code: String) -> URL? {
        URL(string: "https://upanddownapp.com/invite?code=\(code.uppercased())")
    }

    func generateDeepLink(code: String) -> URL? {
        URL(string: "upanddown://invite?code=\(code.uppercased())")
    }

    func shareText(code: String) -> String {
        "Jag bjuder in dig till Up & Down! Använd min kod: \(code.uppercased())\n\nhttps://upanddownapp.com/invite?code=\(code.uppercased())"
    }
}
