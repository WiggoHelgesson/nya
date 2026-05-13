import Foundation
import UserNotifications
import SwiftUI

/// Centraliserad styrning av när vi visar in-app soft-prompt för att
/// be användaren slå på push-notiser. Vi vill ALDRIG triggas iOS:s
/// systemdialog (`requestAuthorization`) utan att först visa en
/// kontextuell förklaring för användaren — bättre acceptansgrad och
/// färre nekanden.
///
/// Strategi:
///   - `currentStatus()` läser nuvarande iOS-tillstånd.
///   - `shouldAskInContext(_:)` säger ja bara om
///       1. status är `.notDetermined`
///       2. vi inte redan visat samma kontext nyligen
///         (UserDefaults-stämpel, default 14 dagar).
///   - `markDismissed(_:)` stämplar tiden så vi inte tjatar.
///   - `request()` triggar äntligen iOS-dialogen.
@MainActor
final class PushPermissionPrompter {
    static let shared = PushPermissionPrompter()
    private init() {}

    /// Var i appen vi befinner oss när vi vill be om notiser. Varje
    /// kontext har sin egen UserDefaults-nyckel så vi kan visa olika
    /// prompts om användaren tackat nej i ett annat sammanhang.
    enum Context: String, CaseIterable {
        case purchaseSuccess
        case saleSuccess
        case offerSent
        case firstOpenList

        var dismissKey: String { "PushPermissionPrompter.dismissed.\(rawValue)" }

        var headline: String {
            switch self {
            case .purchaseSuccess:
                return L.t(
                    sv: "Få notis när säljaren skickar",
                    nb: "Få varsling når selger sender"
                )
            case .saleSuccess:
                return L.t(
                    sv: "Missa inga köp",
                    nb: "Ikke gå glipp av kjøp"
                )
            case .offerSent:
                return L.t(
                    sv: "Få svar på prisförslaget",
                    nb: "Få svar på prisforslaget"
                )
            case .firstOpenList:
                return L.t(
                    sv: "Slå på notiser",
                    nb: "Slå på varslinger"
                )
            }
        }

        var body: String {
            switch self {
            case .purchaseSuccess:
                return L.t(
                    sv: "Vi pingar dig när säljaren skickat och paketet är levererat — så du vet när det är dags att godkänna varan.",
                    nb: "Vi pinger deg når selger har sendt og pakken er levert — slik at du vet når du skal godkjenne varen."
                )
            case .saleSuccess:
                return L.t(
                    sv: "Vi påminner dig om 3-dagarsdeadlinen för att skicka och pingar när köparen godkänt varan.",
                    nb: "Vi minner deg om 3-dagersfristen for å sende og pinger når kjøperen har godkjent varen."
                )
            case .offerSent:
                return L.t(
                    sv: "Få en notis så fort säljaren accepterar eller avböjer ditt prisförslag.",
                    nb: "Få en varsling med en gang selger aksepterer eller avslår prisforslaget."
                )
            case .firstOpenList:
                return L.t(
                    sv: "Få direkt notis när dina köp eller försäljningar uppdateras.",
                    nb: "Få varsling med en gang kjøp eller salg oppdateres."
                )
            }
        }
    }

    /// Hur länge vi backar oss om användaren stänger eller säger "Inte nu".
    private let dismissCooldown: TimeInterval = 14 * 24 * 60 * 60

    func currentStatus() async -> UNAuthorizationStatus {
        await withCheckedContinuation { continuation in
            UNUserNotificationCenter.current().getNotificationSettings { settings in
                continuation.resume(returning: settings.authorizationStatus)
            }
        }
    }

    /// True om vi ska visa soft-prompten nu.
    func shouldAskInContext(_ context: Context) async -> Bool {
        let status = await currentStatus()
        guard status == .notDetermined else { return false }

        if let last = UserDefaults.standard.object(forKey: context.dismissKey) as? Date {
            if Date().timeIntervalSince(last) < dismissCooldown {
                return false
            }
        }
        return true
    }

    func markDismissed(_ context: Context) {
        UserDefaults.standard.set(Date(), forKey: context.dismissKey)
    }

    /// Trigga själva iOS-dialogen + APNs-registrering. Marker som
    /// dismissad oavsett resultat så vi inte visar soft-prompten igen
    /// (om användaren nekar går de till Inställningar).
    func request(context: Context) {
        markDismissed(context)
        PushNotificationService.shared.requestPermissionAndRegister()
    }
}

// MARK: - SwiftUI sheet

struct EnableNotificationsSheet: View {
    let context: PushPermissionPrompter.Context
    let onDecision: (Bool) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 22) {
            ZStack {
                Circle()
                    .fill(Color.black.opacity(0.06))
                    .frame(width: 92, height: 92)
                Image(systemName: "bell.badge.fill")
                    .font(.system(size: 38, weight: .semibold))
                    .foregroundColor(.black)
            }
            .padding(.top, 12)

            Text(context.headline)
                .font(.system(size: 22, weight: .heavy, design: .rounded))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)

            Text(context.body)
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 28)

            Spacer(minLength: 0)

            VStack(spacing: 10) {
                Button {
                    PushPermissionPrompter.shared.request(context: context)
                    onDecision(true)
                    dismiss()
                } label: {
                    Text(L.t(sv: "Slå på notiser", nb: "Slå på varslinger"))
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.black)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }

                Button {
                    PushPermissionPrompter.shared.markDismissed(context)
                    onDecision(false)
                    dismiss()
                } label: {
                    Text(L.t(sv: "Inte nu", nb: "Ikke nå"))
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 18)
        }
        .padding(.vertical, 24)
        .presentationDetents([.height(420)])
        .presentationDragIndicator(.visible)
    }
}

// MARK: - View modifier helper

extension View {
    /// Visar `EnableNotificationsSheet` om soft-prompten ska visas i
    /// den givna kontexten. Kontroll sker async i `task` när
    /// `trigger` flippar från false → true. Hooks använder en
    /// `@State Bool`-toggle som de slår på efter t.ex. ett lyckat köp.
    func notificationPrompt(
        for context: PushPermissionPrompter.Context,
        trigger: Binding<Bool>
    ) -> some View {
        modifier(NotificationPromptModifier(context: context, trigger: trigger))
    }
}

private struct NotificationPromptModifier: ViewModifier {
    let context: PushPermissionPrompter.Context
    @Binding var trigger: Bool
    @State private var showSheet = false

    func body(content: Content) -> some View {
        content
            .task(id: trigger) {
                guard trigger else { return }
                let allowed = await PushPermissionPrompter.shared.shouldAskInContext(context)
                if allowed {
                    showSheet = true
                }
                trigger = false
            }
            .sheet(isPresented: $showSheet) {
                EnableNotificationsSheet(context: context) { _ in
                    showSheet = false
                }
            }
    }
}
