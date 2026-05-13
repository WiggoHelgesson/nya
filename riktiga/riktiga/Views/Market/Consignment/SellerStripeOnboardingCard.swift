import SwiftUI

/// Soft-prompt card shown in the new listing flow + settings page. Encourages
/// the user to connect Stripe so payouts arrive immediately, but does not
/// block listing creation (funds are held on the platform until onboarding
/// completes).
struct SellerStripeOnboardingCard: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @ObservedObject private var stripeService = SellerStripeService.shared

    @State private var isStarting = false
    @State private var errorMessage: String?

    private let accent = Color.black

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "creditcard.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(accent)
                Text(title)
                    .font(.system(size: 15, weight: .bold))
                Spacer()
                if stripeService.status.isFullyActive {
                    Text(L.t(sv: "Aktiverad", nb: "Aktivert"))
                        .font(.system(size: 12, weight: .semibold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.green.opacity(0.15))
                        .foregroundStyle(Color.green)
                        .clipShape(Capsule())
                }
            }

            Text(body(for: stripeService.status))
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if let errorMessage {
                Text(errorMessage)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.red)
            }

            if !stripeService.status.isFullyActive {
                HStack(spacing: 10) {
                    Button {
                        Task { await startOnboarding() }
                    } label: {
                        HStack(spacing: 8) {
                            if isStarting {
                                ProgressView().tint(.white)
                            }
                            Text(primaryButtonTitle)
                                .font(.system(size: 14, weight: .semibold))
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(accent)
                        .clipShape(Capsule())
                    }
                    .disabled(isStarting)
                }
            }
        }
        .padding(14)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .task {
            if let uid = authViewModel.currentUser?.id {
                await stripeService.refresh(userId: uid)
                if stripeService.status.hasAccount {
                    await stripeService.syncStatusAndFlushPayouts(userId: uid)
                }
            }
        }
    }

    private var title: String {
        if stripeService.status.isFullyActive {
            return L.t(sv: "Stripe aktivt", nb: "Stripe aktivt")
        }
        if stripeService.status.hasAccount {
            return L.t(sv: "Slutför Stripe-onboarding", nb: "Fullfør Stripe-onboarding")
        }
        return L.t(sv: "Få pengarna direkt", nb: "Få pengene direkte")
    }

    private func body(for status: SellerStripeService.Status) -> String {
        if status.isFullyActive {
            return L.t(
                sv: "Ditt Stripe-konto är aktiverat. Pengarna skickas direkt till dig varje gång någon köper.",
                nb: "Stripe-kontoen din er aktivert. Pengene sendes direkte til deg hver gang noen kjøper."
            )
        }
        if status.hasAccount {
            return L.t(
                sv: "Slutför din Stripe-onboarding för att få pengarna utbetalda direkt när någon köper.",
                nb: "Fullfør Stripe-onboarding for å få pengene utbetalt direkte når noen kjøper."
            )
        }
        return L.t(
            sv: "Koppla Stripe nu så får du pengarna direkt när någon köper. Du kan göra det senare också – pengarna hålls tryggt tills du slutför.",
            nb: "Koble Stripe nå for å få pengene direkte når noen kjøper. Du kan gjøre det senere også – pengene holdes trygt til du fullfører."
        )
    }

    private var primaryButtonTitle: String {
        stripeService.status.hasAccount
            ? L.t(sv: "Slutför onboarding", nb: "Fullfør onboarding")
            : L.t(sv: "Koppla Stripe", nb: "Koble Stripe")
    }

    private func startOnboarding() async {
        guard let user = authViewModel.currentUser else {
            errorMessage = L.t(sv: "Kunde inte hitta användare.", nb: "Fant ikke bruker.")
            return
        }
        let email = user.email
        guard !email.isEmpty else {
            errorMessage = L.t(sv: "Saknar e-post.", nb: "Mangler e-post.")
            return
        }
        errorMessage = nil
        isStarting = true
        defer { isStarting = false }

        do {
            try await stripeService.startOnboarding(userId: user.id, email: email)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
