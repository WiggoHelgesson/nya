import Foundation
import Combine
import Supabase
import SafariServices
import UIKit

/// Small service dedicated to the seller's Stripe Connect columns on
/// `public.profiles`. Wraps the create/onboard/status edge functions so the
/// UI can stay declarative.
final class SellerStripeService: ObservableObject {

    static let shared = SellerStripeService()

    struct Status {
        var stripeAccountId: String?
        var onboardingComplete: Bool
        var chargesEnabled: Bool
        var payoutsEnabled: Bool

        var hasAccount: Bool { stripeAccountId != nil }
        var isFullyActive: Bool { onboardingComplete && chargesEnabled && payoutsEnabled }
    }

    @Published private(set) var status: Status = Status(
        stripeAccountId: nil,
        onboardingComplete: false,
        chargesEnabled: false,
        payoutsEnabled: false
    )

    private var supabase: SupabaseClient { SupabaseConfig.supabase }

    private init() {}

    // MARK: - Read

    /// Fetches the seller's current Stripe Connect status from `profiles`.
    /// Safe to call repeatedly; last result is cached in `status`.
    @MainActor
    func refresh(userId: String) async {
        struct Row: Decodable {
            let stripe_account_id: String?
            let stripe_onboarding_complete: Bool?
            let stripe_charges_enabled: Bool?
            let stripe_payouts_enabled: Bool?
        }

        do {
            let row: Row = try await supabase
                .from("profiles")
                .select("stripe_account_id, stripe_onboarding_complete, stripe_charges_enabled, stripe_payouts_enabled")
                .eq("id", value: userId)
                .single()
                .execute()
                .value

            status = Status(
                stripeAccountId: row.stripe_account_id,
                onboardingComplete: row.stripe_onboarding_complete ?? false,
                chargesEnabled: row.stripe_charges_enabled ?? false,
                payoutsEnabled: row.stripe_payouts_enabled ?? false
            )
        } catch {
            print("SellerStripeService.refresh failed: \(error)")
        }
    }

    // MARK: - Write / onboard

    /// Starts (or resumes) Stripe Express onboarding. Creates the account if needed,
    /// then opens Stripe's onboarding link in the provided `presenter`.
    @MainActor
    func startOnboarding(userId: String, email: String, from presenter: UIViewController? = nil) async throws {
        let createResponse = try await StripeConnectService.shared.createSellerConnectAccount(
            userId: userId,
            email: email
        )

        guard let accountId = createResponse.accountId else {
            throw StripeConnectError.noAccountId
        }

        let linkResponse = try await StripeConnectService.shared.getOnboardingLink(
            stripeAccountId: accountId
        )

        if linkResponse.alreadyComplete == true {
            await refresh(userId: userId)
            return
        }

        guard let urlString = linkResponse.url, let url = URL(string: urlString) else {
            throw StripeConnectError.apiError("Kunde inte skapa onboarding-länk")
        }

        await MainActor.run {
            let safari = SFSafariViewController(url: url)
            safari.preferredControlTintColor = UIColor(red: 0, green: 0.48, blue: 0.51, alpha: 1)
            let top = presenter ?? UIApplication.shared.topMostViewController()
            top?.present(safari, animated: true)
        }
    }

    /// Polls Stripe for the latest status of the seller's Connect account and
    /// triggers any pending held payouts if the account just became active.
    @MainActor
    func syncStatusAndFlushPayouts(userId: String) async {
        await refresh(userId: userId)
        guard let accountId = status.stripeAccountId else { return }

        do {
            let freshStatus = try await StripeConnectService.shared.getSellerAccountStatus(
                stripeAccountId: accountId,
                sellerId: userId
            )

            let chargesEnabled = freshStatus.chargesEnabled ?? false
            status = Status(
                stripeAccountId: accountId,
                onboardingComplete: freshStatus.detailsSubmitted ?? false,
                chargesEnabled: chargesEnabled,
                payoutsEnabled: freshStatus.payoutsEnabled ?? false
            )

            if chargesEnabled {
                _ = try? await StripeConnectService.shared.triggerPendingPayouts(
                    sellerId: userId
                )
            }
        } catch {
            print("SellerStripeService.syncStatusAndFlushPayouts failed: \(error)")
        }
    }
}

// MARK: - UIKit helper

extension UIApplication {
    func topMostViewController(base: UIViewController? = nil) -> UIViewController? {
        let root: UIViewController? = base ?? {
            let scenes = connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .flatMap { $0.windows }
            return scenes.first(where: { $0.isKeyWindow })?.rootViewController
        }()
        if let nav = root as? UINavigationController {
            return topMostViewController(base: nav.visibleViewController)
        }
        if let tab = root as? UITabBarController, let selected = tab.selectedViewController {
            return topMostViewController(base: selected)
        }
        if let presented = root?.presentedViewController {
            return topMostViewController(base: presented)
        }
        return root
    }
}
