import SwiftUI
import CoreLocation
import PhotosUI
import Supabase
import UIKit
import Combine
import StoreKit
import Contacts

// MARK: - New Unified Onboarding Steps
private enum OnboardingStep: Int, CaseIterable, Identifiable {
    case name
    case profilePicture  // NEW: Add profile picture
    case gender
    case workouts
    case community
    case heightWeight
    case birthday
    case motivation  // NEW: Shows motivation comparison
    case referralCode
    case rating  // NEW: Shows ratings and triggers iOS review popup
    case findFriends
    case appleHealth
    case notifications
    case welcome
    
    var id: Int { rawValue }
    
    var title: String {
        switch self {
        case .name: return L.t(sv: "Välj användarnamn", nb: "Velg brukernavn")
        case .profilePicture: return L.t(sv: "Lägg till profilbild", nb: "Legg til profilbilde")
        case .gender: return L.t(sv: "Välj ditt kön", nb: "Velg ditt kjønn")
        case .workouts: return L.t(sv: "Hur många pass tränar du per vecka?", nb: "Hvor mange økter trener du per uke?")
        case .community: return L.t(sv: "Välkommen till gemenskapen", nb: "Velkommen til fellesskapet")
        case .heightWeight: return L.t(sv: "Längd & vikt", nb: "Høyde & vekt")
        case .birthday: return L.t(sv: "Hur gammal är du?", nb: "Hvor gammel er du?")
        case .motivation: return L.t(sv: "Få 2x så mycket motivation genom att träna med Up&Down", nb: "Få 2x så mye motivasjon ved å trene med Up&Down")
        case .referralCode: return L.t(sv: "Ange kod (valfritt)", nb: "Skriv inn kode (valgfritt)")
        case .rating: return L.t(sv: "Betygsätt oss", nb: "Gi oss en vurdering")
        case .findFriends: return L.t(sv: "Träning är inte en solosport.", nb: "Trening er ikke en solosport.")
        case .appleHealth: return L.t(sv: "Aktivera Apple Health", nb: "Aktiver Apple Health")
        case .notifications: return L.t(sv: "Aktivera notiser", nb: "Aktiver varsler")
        case .welcome: return ""
        }
    }
    
    var subtitle: String {
        switch self {
        case .name: return L.t(sv: "Välj ett användarnamn som visas för andra.", nb: "Velg et brukernavn som vises for andre.")
        case .profilePicture: return L.t(sv: "Allt blir roligare med en profilbild.", nb: "Alt blir morsommere med et profilbilde.")
        case .gender: return L.t(sv: "Vi använder denna datan för att anpassa dig till rätt topplistor.", nb: "Vi bruker disse dataene for å tilpasse deg til riktige topplister.")
        case .workouts: return L.t(sv: "Detta används för att kalibrera din personliga plan.", nb: "Dette brukes for å kalibrere din personlige plan.")
        case .community: return ""
        case .heightWeight: return L.t(sv: "Detta används för att kalibrera din personliga plan.", nb: "Dette brukes for å kalibrere din personlige plan.")
        case .birthday: return L.t(sv: "Vi använder denna datan för att personalisera din statistik och hålla yngre användare säkra.", nb: "Vi bruker disse dataene for å tilpasse statistikken din og holde yngre brukere trygge.")
        case .motivation: return ""
        case .referralCode: return L.t(sv: "Du kan hoppa över detta steg", nb: "Du kan hoppe over dette steget")
        case .rating: return ""
        case .findFriends: return L.t(sv: "Lägg till vänner på Up&Down för att ge och få stöttning, dela träna och hålla motivationen uppe!", nb: "Legg til venner på Up&Down for å gi og få støtte, dele trening og holde motivasjonen oppe!")
        case .appleHealth: return L.t(sv: "Appen behöver hälsodata för att logga dina pass och steg.", nb: "Appen trenger helsedata for å logge øktene og skrittene dine.")
        case .notifications: return L.t(sv: "Så vi kan påminna dig om mål och belöningar.", nb: "Slik at vi kan minne deg på mål og belønninger.")
        case .welcome: return ""
        }
    }
}

// MARK: - Username Check Response
private struct UsernameCheckResponse: Codable {
    let id: String
}

// MARK: - Onboarding Data Model
struct UnifiedOnboardingData {
    // Name
    var firstName: String = ""
    var lastName: String = ""
    
    // Profile picture
    var profileImage: UIImage? = nil
    
    // Referral code (optional)
    var referralCode: String = ""
    
    // Nutrition data
    var gender: String = ""
    var workoutsPerWeek: String = ""
    var heightCm: Int = 170
    var weightKg: Double = 70.0
    var birthDate: Date = Calendar.current.date(byAdding: .year, value: -25, to: Date()) ?? Date()
    var goal: String = ""
    var targetWeightKg: Double = 65.0
    
    // Calculated results
    var dailyCalories: Int = 0
    var dailyProtein: Int = 0
    var dailyCarbs: Int = 0
    var dailyFat: Int = 0
    
    // Permissions
    var healthAuthorized: Bool = false
    var notificationsAuthorized: Bool = false
    
    var age: Int {
        Calendar.current.dateComponents([.year], from: birthDate, to: Date()).year ?? 25
    }
    
    var fullName: String {
        "\(firstName.trimmingCharacters(in: .whitespaces)) \(lastName.trimmingCharacters(in: .whitespaces))".trimmingCharacters(in: .whitespaces)
    }
}

struct AuthenticationView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @Environment(\.colorScheme) private var colorScheme
    @State private var locationAuthStatus: CLAuthorizationStatus = LocationManager.shared.authorizationStatus
    @State private var showLanding = true
    @State private var currentHeroIndex = 0
    @State private var onboardingStep: OnboardingStep? = nil
    @State private var showSignupForm = false
    @State private var data = UnifiedOnboardingData()
    @State private var healthRequestStatus: String?
    @State private var notificationsStatus: String?
    
    // Signup form
    @State private var signupEmail: String = ""
    @State private var signupPassword: String = ""
    
    // Invite code (set via deep link or manual entry)
    @State private var pendingInviteCode: String? = nil
    @State private var showInviteCodeField = false
    @State private var inviteCodeInput: String = ""
    @State private var inviteCodeValid: Bool? = nil
    @State private var isValidatingInvite = false
    
    
    
    // Animation
    @State private var contentOpacity: Double = 1
    @State private var contentOffset: CGFloat = 0
    // Motivation step animation
    @State private var motivationAnimationComplete: Bool = false
    @State private var showMotivationBars: Bool = false
    
    // Profile picture
    @State private var selectedProfileImage: UIImage? = nil
    @State private var profilePhotoPickerItem: PhotosPickerItem? = nil
    
    // Username validation
    @State private var isCheckingUsername: Bool = false
    @State private var usernameIsTaken: Bool = false
    @State private var usernameCheckTask: Task<Void, Never>? = nil
    
    // Find Friends step
    @State private var onboardingContacts: [(id: String, name: String, avatarUrl: String?)] = []
    @State private var onboardingFollowingStatus: [String: Bool] = [:]
    @State private var onboardingContactsGranted = false
    @State private var onboardingContactsLoading = false
    
    // Soft paywall after onboarding
    @State private var showOnboardingPaywall = false
    @State private var onboardingDataReady = false
    
    private let heroImages = ["84", "83", "85", "86"]
    private let onboardingSteps = OnboardingStep.allCases
    private let totalSteps = OnboardingStep.allCases.count
    
    // MARK: - Dark Mode Colors
    private var isDarkMode: Bool { colorScheme == .dark }
    private var backgroundColor: Color { isDarkMode ? .black : .white }
    private var primaryTextColor: Color { isDarkMode ? .white : .black }
    private var secondaryTextColor: Color { isDarkMode ? .white.opacity(0.7) : .black.opacity(0.6) }
    private var buttonBackgroundColor: Color { isDarkMode ? .white : .black }
    private var buttonTextColor: Color { isDarkMode ? .black : .white }
    private var cardBackgroundColor: Color { isDarkMode ? Color(.systemGray6) : Color(.systemGray6) }
    private var selectedCardBackgroundColor: Color { isDarkMode ? .white : .black }
    private var selectedCardTextColor: Color { isDarkMode ? .black : .white }
    private var unselectedCardTextColor: Color { isDarkMode ? .white : .black }
    
    var body: some View {
        ZStack {
            backgroundColor.ignoresSafeArea()
            
            if let step = onboardingStep {
                onboardingView(for: step)
            } else if showSignupForm {
                signupFormView
            } else if showLanding {
                landingView
            } else {
                formView
            }
        }
        .onChange(of: showOnboardingPaywall) { _, newValue in
            if newValue && onboardingDataReady {
                // Show Superwall paywall
                SuperwallService.shared.showPaywall()
                showOnboardingPaywall = false
                // Finalize onboarding after a short delay to let paywall show
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    finalizeOnboarding()
                }
            }
        }
        .onAppear {
            // Pick up invite code set via deep link
            if let code = authViewModel.pendingInviteCode {
                pendingInviteCode = code
                inviteCodeInput = code
                inviteCodeValid = true
                showInviteCodeField = true
            }
            
            // If user has a session but needs onboarding (e.g. app restart after partial signup),
            // skip the landing/login screens and go straight to onboarding
            if authViewModel.needsOnboarding {
                showLanding = false
                showSignupForm = false
                onboardingStep = onboardingSteps.first
                
                // Pre-fill username from existing profile if available
                if let existingName = authViewModel.currentUser?.name,
                   !existingName.isEmpty,
                   !existingName.hasPrefix("user-"),
                   existingName != "Användare" {
                    data.firstName = existingName.lowercased().replacingOccurrences(of: " ", with: "_")
                }
            } else {
                showLanding = true
                onboardingStep = nil
            }
            authViewModel.errorMessage = ""
            
            let healthAuthorized = HealthKitManager.shared.isHealthDataAuthorized()
            data.healthAuthorized = healthAuthorized
            healthRequestStatus = healthAuthorized ? L.t(sv: "Apple Health aktiverad", nb: "Apple Health aktivert") : nil
            
            // Set up Apple Sign In callback
            authViewModel.onAppleSignInComplete = { success, _, appleFirstName, appleLastName in
                if success {
                    showLanding = false
                    showSignupForm = false
                    
                    // Pre-fill username with Apple's name as a suggestion (user can change it)
                    if let firstName = appleFirstName, !firstName.isEmpty {
                        // Suggest username based on Apple name (lowercase, no spaces)
                        let suggestedUsername = firstName.lowercased().replacingOccurrences(of: " ", with: "_")
                        data.firstName = suggestedUsername
                    }
                    
                    // Always start from the username step so user can choose their username
                    onboardingStep = onboardingSteps.first
                }
            }
            
            // Set up Google Sign In callback
            authViewModel.onGoogleSignInComplete = { success, onboardingData, googleName in
                if success {
                    showLanding = false
                    showSignupForm = false
                    
                    // Start onboarding for new users or users who didn't finish onboarding
                    // googleName is non-nil when the user needs onboarding (new or incomplete)
                    if googleName != nil {
                        // Pre-fill username with Google's name as a suggestion (user can change it)
                        if let name = googleName, !name.isEmpty {
                            let suggestedUsername = name.lowercased().replacingOccurrences(of: " ", with: "_")
                            data.firstName = suggestedUsername
                        }
                        
                        // Start onboarding
                        onboardingStep = onboardingSteps.first
                    }
                    // Existing users who completed onboarding go directly to main app (isLoggedIn = true handles this)
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            let authorized = HealthKitManager.shared.isHealthDataAuthorized()
            data.healthAuthorized = authorized
            healthRequestStatus = authorized ? L.t(sv: "Apple Health aktiverad", nb: "Apple Health aktivert") : nil
        }
    }
    
    // MARK: - Landing View
    private var landingView: some View {
        VStack(spacing: 0) {
            Spacer()
            
            VStack(spacing: 24) {
                Image("upanddownlog")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 90, height: 90)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                
                VStack(spacing: 8) {
                    if pendingInviteCode != nil {
                        Text(L.t(sv: "Skapa ditt konto", nb: "Opprett kontoen din"))
                            .font(.system(size: 26, weight: .bold))
                            .multilineTextAlignment(.center)
                            .foregroundColor(primaryTextColor)
                        
                        Text(L.t(sv: "Med din kod får du en exklusiv chans att skapa ett Up&Down konto", nb: "Med koden din får du en eksklusiv sjanse til å opprette en Up&Down-konto"))
                            .font(.system(size: 15))
                            .multilineTextAlignment(.center)
                            .foregroundColor(secondaryTextColor)
                    } else {
                        Text(L.t(sv: "Enbart för Danderyds Gymnasium elever", nb: "Kun for Danderyds Gymnasium elever"))
                            .font(.system(size: 26, weight: .bold))
                            .multilineTextAlignment(.center)
                            .foregroundColor(primaryTextColor)
                        
                        Text(L.t(sv: "Du behöver en elev.danderyd.se mail för att skapa ett konto", nb: "Du trenger en elev.danderyd.se e-post for å opprette en konto"))
                            .font(.system(size: 15))
                            .multilineTextAlignment(.center)
                            .foregroundColor(secondaryTextColor)
                    }
                }
                
                VStack(spacing: 12) {
                    if pendingInviteCode != nil {
                        Button {
                            authViewModel.pendingInviteCode = pendingInviteCode
                            authViewModel.signInWithApple()
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "apple.logo")
                                    .font(.system(size: 20, weight: .medium))
                                Text(L.t(sv: "Fortsätt med Apple", nb: "Fortsett med Apple"))
                                    .font(.system(size: 17, weight: .medium))
                            }
                            .foregroundColor(primaryTextColor)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(RoundedRectangle(cornerRadius: 30).stroke(Color(.systemGray3), lineWidth: 1))
                        }
                        .disabled(authViewModel.isLoading)
                    }
                    
                    Button {
                        authViewModel.pendingInviteCode = pendingInviteCode
                        authViewModel.signInWithGoogle(onboardingData: OnboardingData())
                    } label: {
                        HStack(spacing: 12) {
                            Image("78")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 20, height: 20)
                            Text(L.t(sv: "Fortsätt med Google", nb: "Fortsett med Google"))
                                .font(.system(size: 17, weight: .medium))
                        }
                        .foregroundColor(primaryTextColor)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(RoundedRectangle(cornerRadius: 30).stroke(Color(.systemGray3), lineWidth: 1))
                    }
                    .disabled(authViewModel.isLoading)
                    
                    Button {
                        showLanding = false
                        showSignupForm = true
                    } label: {
                        Text(L.t(sv: "Skapa konto med mail", nb: "Opprett konto med e-post"))
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(buttonTextColor)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(buttonBackgroundColor)
                            .clipShape(Capsule())
                    }
                    
                    if !authViewModel.errorMessage.isEmpty {
                        Text(authViewModel.errorMessage)
                            .font(.system(size: 14))
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                    }
                    
                    if authViewModel.isLoading {
                        ProgressView()
                            .padding(.top, 4)
                    }
                }
                .padding(.horizontal, 24)
            }
            .padding(.horizontal, 8)
            
            Spacer()
            
            VStack(spacing: 10) {
                Text(L.t(sv: "Har du ingen skolmail? Få en kod av en befintlig Up&Down användare för att skapa konto.", nb: "Har du ingen skole-e-post? Få en kode av en eksisterende Up&Down-bruker for å opprette konto."))
                    .font(.system(size: 13))
                    .foregroundColor(secondaryTextColor.opacity(0.7))
                    .multilineTextAlignment(.center)
                
                if let code = pendingInviteCode {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundColor(.green)
                        Text(L.t(sv: "Inbjudningskod aktiv: \(code)", nb: "Invitasjonskode aktiv: \(code)"))
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.green)
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity)
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(10)
                } else {
                    HStack {
                        TextField(L.t(sv: "Ange kod", nb: "Skriv inn kode"), text: $inviteCodeInput)
                            .textInputAutocapitalization(.characters)
                            .autocorrectionDisabled()
                            .padding(14)
                            .background(Color(.systemGray6))
                            .cornerRadius(10)
                            .onChange(of: inviteCodeInput) { _, newValue in
                                inviteCodeValid = nil
                            }
                        
                        Button {
                            validateAndSetInviteCode()
                        } label: {
                            if isValidatingInvite {
                                ProgressView()
                                    .frame(width: 44, height: 44)
                            } else {
                                Text(L.t(sv: "Aktivera", nb: "Aktiver"))
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(buttonTextColor)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 14)
                                    .background(buttonBackgroundColor)
                                    .cornerRadius(10)
                            }
                        }
                        .disabled(inviteCodeInput.trimmingCharacters(in: .whitespaces).isEmpty || isValidatingInvite)
                    }
                    
                    if let valid = inviteCodeValid, !valid {
                        Text(L.t(sv: "Ogiltig eller redan använd kod", nb: "Ugyldig eller allerede brukt kode"))
                            .font(.system(size: 13))
                            .foregroundColor(.red)
                    }
                }
                
                Button {
                    showLanding = false
                    showSignupForm = false
                    authViewModel.errorMessage = ""
                } label: {
                    Text(L.t(sv: "Har du redan ett konto? Logga in", nb: "Har du allerede en konto? Logg inn"))
                        .font(.system(size: 15))
                        .foregroundColor(secondaryTextColor)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
        .background(backgroundColor)
    }
    
    // MARK: - Login Form View
    private var formView: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Button {
                    showLanding = true
                    authViewModel.errorMessage = ""
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(secondaryTextColor)
                        .frame(width: 36, height: 36)
                        .background(Color(.systemGray5))
                        .clipShape(Circle())
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    Text(L.t(sv: "Logga in på Up&Down", nb: "Logg inn på Up&Down"))
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(primaryTextColor)
                        .padding(.top, 8)
                    
                    LoginFormView()
                        .environmentObject(authViewModel)
                    
                    HStack {
                        Rectangle().fill(Color(.systemGray4)).frame(height: 1)
                        Text(L.t(sv: "eller", nb: "eller")).font(.system(size: 14)).foregroundColor(.gray).padding(.horizontal, 16)
                        Rectangle().fill(Color(.systemGray4)).frame(height: 1)
                    }
                    
                    Button {
                        authViewModel.signInWithApple()
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "apple.logo")
                                .font(.system(size: 20, weight: .medium))
                            Text(L.t(sv: "Logga in med Apple", nb: "Logg inn med Apple"))
                                .font(.system(size: 17, weight: .medium))
                            Spacer()
                        }
                        .foregroundColor(primaryTextColor)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 16)
                        .background(RoundedRectangle(cornerRadius: 30).stroke(Color(.systemGray3), lineWidth: 1.5))
                    }
                    .disabled(authViewModel.isLoading)
                    
                    Button {
                        authViewModel.signInWithGoogle()
                    } label: {
                        HStack(spacing: 12) {
                            Image("78")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 20, height: 20)
                            Text(L.t(sv: "Logga in med Google", nb: "Logg inn med Google"))
                                .font(.system(size: 17, weight: .medium))
                            Spacer()
                        }
                        .foregroundColor(primaryTextColor)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 16)
                        .background(RoundedRectangle(cornerRadius: 30).stroke(Color(.systemGray3), lineWidth: 1.5))
                    }
                    .disabled(authViewModel.isLoading)
                    
                    Text(L.t(sv: "Genom att fortsätta godkänner du våra [användarvillkor](https://wiggio.se/privacy) och [integritetspolicy](https://wiggio.se/privacy).", nb: "Ved å fortsette godtar du våre [brukervilkår](https://wiggio.se/privacy) og [personvern](https://wiggio.se/privacy)."))
                        .font(.system(size: 13))
                        .foregroundColor(.gray)
                        .tint(primaryTextColor)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            }
        }
    }
    
    // MARK: - Signup Form View
    private var signupFormView: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Button {
                    showSignupForm = false
                    showLanding = true
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(secondaryTextColor)
                        .frame(width: 36, height: 36)
                        .background(Color(.systemGray5))
                        .clipShape(Circle())
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Text(L.t(sv: "Enbart studenter från Danderyds Gymnasium kan skapa konto just nu", nb: "Kun elever fra Danderyds Gymnasium kan opprette konto akkurat nå"))
                        .font(.system(size: 26, weight: .bold))
                        .foregroundColor(primaryTextColor)
                        .padding(.top, 8)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text(L.t(sv: "E-post", nb: "E-post")).font(.system(size: 15)).foregroundColor(primaryTextColor)
                        TextField(L.t(sv: "E-post", nb: "E-post"), text: $signupEmail)
                            .keyboardType(.emailAddress)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .padding(14)
                            .background(Color(.systemGray6))
                            .cornerRadius(10)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text(L.t(sv: "Lösenord", nb: "Passord")).font(.system(size: 15)).foregroundColor(primaryTextColor)
                        SecureField(L.t(sv: "Minst 6 tecken", nb: "Minst 6 tegn"), text: $signupPassword)
                            .padding(14)
                            .background(Color(.systemGray6))
                            .cornerRadius(10)
                    }
                    
                    Button {
                        createAccountAndStartOnboarding()
                    } label: {
                        if authViewModel.isLoading {
                            ProgressView().tint(buttonTextColor).frame(maxWidth: .infinity).padding(.vertical, 16).background(buttonBackgroundColor).clipShape(Capsule())
                        } else {
                            Text(L.t(sv: "Registrera dig", nb: "Registrer deg"))
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundColor(canCreateAccount ? buttonTextColor : .gray)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(canCreateAccount ? buttonBackgroundColor : Color(.systemGray5))
                                .clipShape(Capsule())
                        }
                    }
                    .disabled(!canCreateAccount || authViewModel.isLoading)
                    
                    if !authViewModel.errorMessage.isEmpty {
                        Text(authViewModel.errorMessage).font(.system(size: 14)).foregroundColor(.red)
                    }
                    
                    // Invite code section
                    if let code = pendingInviteCode {
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.seal.fill")
                                .foregroundColor(.green)
                            Text(L.t(sv: "Inbjudningskod aktiv: \(code)", nb: "Invitasjonskode aktiv: \(code)"))
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.green)
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity)
                        .background(Color.green.opacity(0.1))
                        .cornerRadius(10)
                    } else {
                        if showInviteCodeField {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(L.t(sv: "Inbjudningskod", nb: "Invitasjonskode"))
                                    .font(.system(size: 15))
                                    .foregroundColor(primaryTextColor)
                                HStack {
                                    TextField(L.t(sv: "Ange kod", nb: "Skriv inn kode"), text: $inviteCodeInput)
                                        .textInputAutocapitalization(.characters)
                                        .autocorrectionDisabled()
                                        .padding(14)
                                        .background(Color(.systemGray6))
                                        .cornerRadius(10)
                                        .onChange(of: inviteCodeInput) { _, newValue in
                                            inviteCodeValid = nil
                                        }
                                    
                                    Button {
                                        validateAndSetInviteCode()
                                    } label: {
                                        if isValidatingInvite {
                                            ProgressView()
                                                .frame(width: 44, height: 44)
                                        } else {
                                            Text(L.t(sv: "Aktivera", nb: "Aktiver"))
                                                .font(.system(size: 15, weight: .semibold))
                                                .foregroundColor(buttonTextColor)
                                                .padding(.horizontal, 16)
                                                .padding(.vertical, 14)
                                                .background(buttonBackgroundColor)
                                                .cornerRadius(10)
                                        }
                                    }
                                    .disabled(inviteCodeInput.trimmingCharacters(in: .whitespaces).isEmpty || isValidatingInvite)
                                }
                                if let valid = inviteCodeValid, !valid {
                                    Text(L.t(sv: "Ogiltig eller redan använd kod", nb: "Ugyldig eller allerede brukt kode"))
                                        .font(.system(size: 13))
                                        .foregroundColor(.red)
                                }
                            }
                        } else {
                            Button {
                                showInviteCodeField = true
                            } label: {
                                Text(L.t(sv: "Har du en inbjudningskod?", nb: "Har du en invitasjonskode?"))
                                    .font(.system(size: 15))
                                    .foregroundColor(primaryTextColor.opacity(0.7))
                            }
                        }
                    }
                    
                    Text(L.t(sv: "Genom att fortsätta godkänner du våra [Användarvillkor](https://www.upanddownapp.com/terms) och [Integritetspolicy](https://www.upanddownapp.com/privacy).", nb: "Ved å fortsette godtar du våre [Brukervilkår](https://www.upanddownapp.com/terms) og [Personvern](https://www.upanddownapp.com/privacy)."))
                        .font(.system(size: 13))
                        .foregroundColor(.gray)
                        .tint(primaryTextColor)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            }
        }
    }
    
    private var canCreateAccount: Bool {
        let trimmedEmail = signupEmail.trimmingCharacters(in: .whitespacesAndNewlines)
        let emailValid = trimmedEmail.range(of: #"^\S+@\S+\.\S+$"#, options: .regularExpression) != nil
        return emailValid && signupPassword.count >= 6
    }
    
    // MARK: - Community Fullscreen Step
    private var communityStepView: some View {
        ZStack {
            Image("91")
                .resizable()
                .scaledToFill()
                .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
                .clipped()
            
            LinearGradient(
                colors: [
                    .clear,
                    .clear,
                    .black.opacity(0.3),
                    .black.opacity(0.7),
                    .black.opacity(0.85)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            
            VStack {
                Spacer()
                
                VStack(spacing: 12) {
                    Text(L.t(sv: "Välkommen till gemenskapen", nb: "Velkommen til fellesskapet"))
                        .font(.system(size: 26, weight: .heavy))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                    
                    Text(L.t(sv: "Tusentals svenskar använder Up&Down och är redo att stötta dig!", nb: "Tusenvis av nordmenn bruker Up&Down og er klare til å støtte deg!"))
                        .font(.system(size: 16))
                        .foregroundColor(.white.opacity(0.9))
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 32)
                
                Button {
                    continueFromStep(.community)
                } label: {
                    Text(L.t(sv: "Fortsätt", nb: "Fortsett"))
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                .padding(.horizontal, 24)
                .padding(.top, 24)
                .padding(.bottom, 16)
            }
            .padding(.bottom, 16)
        }
        .ignoresSafeArea()
        .opacity(contentOpacity)
        .offset(y: contentOffset)
    }
    
    // MARK: - Welcome Fullscreen Step
    private var welcomeStepView: some View {
        ZStack {
            Image("83")
                .resizable()
                .scaledToFill()
                .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
                .clipped()
            
            LinearGradient(
                colors: [
                    .clear,
                    .clear,
                    .black.opacity(0.2),
                    .black.opacity(0.6),
                    .black.opacity(0.85)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            
            VStack {
                Spacer()
                
                VStack(spacing: 12) {
                    Text(L.t(
                        sv: "Välkommen, \(data.firstName)!",
                        nb: "Velkommen, \(data.firstName)!"
                    ))
                        .font(.system(size: 32, weight: .heavy))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                    
                    Text(L.t(
                        sv: "Du är redo att köra igång. Tracka gympass, löppass & annat och dela dina pass med alla andra tusentals användare, gå ut och slakta det!",
                        nb: "Du er klar til å kjøre i gang. Track gymøkter, løpeøkter og annet og del øktene dine med alle de andre tusenvis av brukere, kom deg ut og knus det!"
                    ))
                        .font(.system(size: 16))
                        .foregroundColor(.white.opacity(0.9))
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 32)
                
                Button {
                    completeOnboarding()
                } label: {
                    Text(L.t(sv: "Kom igång!", nb: "Kom i gang!"))
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                .padding(.horizontal, 24)
                .padding(.top, 24)
                .padding(.bottom, 16)
            }
            .padding(.bottom, 16)
        }
        .ignoresSafeArea()
        .opacity(contentOpacity)
        .offset(y: contentOffset)
    }
    
    // MARK: - Onboarding View
    private func onboardingView(for step: OnboardingStep) -> some View {
        Group {
            if step == .community {
                communityStepView
            } else if step == .welcome {
                welcomeStepView
            } else {
                standardOnboardingView(for: step)
            }
        }
        .onChange(of: step) { oldStep, newStep in }
    }
    
    private func standardOnboardingView(for step: OnboardingStep) -> some View {
        VStack(spacing: 0) {
            // Header with back button and progress bar
            HStack(spacing: 16) {
                Button {
                    goToPreviousStep()
                } label: {
                    Image(systemName: "arrow.left")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(primaryTextColor)
                        .frame(width: 40, height: 40)
                        .background(Color(.systemGray6))
                        .clipShape(Circle())
                }
                .opacity(step == .name ? 0 : 1)
                .disabled(step == .name)
                
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Rectangle()
                            .fill(Color(.systemGray5))
                            .frame(height: 4)
                            .cornerRadius(2)
                        
                        let progress = CGFloat((onboardingSteps.firstIndex(of: step) ?? 0) + 1) / CGFloat(totalSteps)
                        Rectangle()
                            .fill(buttonBackgroundColor)
                            .frame(width: geometry.size.width * progress, height: 4)
                            .cornerRadius(2)
                            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: step)
                    }
                }
                .frame(height: 4)
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 24)
            
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(step == .profilePicture
                         ? L.t(sv: "Välkommen, \(data.firstName)! Lägg till en profilbild", nb: "Velkommen, \(data.firstName)! Legg til et profilbilde")
                         : step == .birthday
                         ? L.t(sv: "Välkommen, \(data.firstName)! \(step.title)", nb: "Velkommen, \(data.firstName)! \(step.title)")
                         : step.title)
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(primaryTextColor)
                    
                    Text(step.subtitle)
                        .font(.system(size: 16))
                        .foregroundColor(.gray)
                        .padding(.bottom, 8)
                    
                    onboardingContent(for: step)
                }
                .padding(.horizontal, 24)
                .opacity(contentOpacity)
                .offset(y: contentOffset)
            }
            
            // Continue button
            VStack(spacing: 0) {
                Button {
                    continueFromStep(step)
                } label: {
                    Text(continueButtonText(for: step))
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(canContinue(step) ? buttonTextColor : .gray)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(canContinue(step) ? buttonBackgroundColor : Color(.systemGray5))
                        .clipShape(Capsule())
                }
                .disabled(!canContinue(step) || (step == .referralCode && isValidatingCode))
                .padding(.horizontal, 24)
                .padding(.vertical, 16)
            }
            .background(backgroundColor)
        }
    }
    
    @ViewBuilder
    private func onboardingContent(for step: OnboardingStep) -> some View {
            switch step {
            case .name:
            nameStepContent
        case .profilePicture:
            profilePictureStepContent
        case .referralCode:
            referralCodeStepContent
        case .rating:
            ratingStepContent
        case .gender:
            genderStepContent
        case .workouts:
            workoutsStepContent
        case .community:
            EmptyView()
        case .heightWeight:
            heightWeightStepContent
        case .birthday:
            birthdayStepContent
        case .motivation:
            motivationStepContent
        case .findFriends:
            findFriendsStepContent
        case .appleHealth:
            appleHealthStepContent
        case .notifications:
            notificationsStepContent
        case .welcome:
            EmptyView()
        }
    }
    
    // MARK: - Step Contents
    private var nameStepContent: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                Text(L.t(sv: "Användarnamn", nb: "Brukernavn"))
                    .font(.system(size: 15))
                    .foregroundColor(primaryTextColor)
                TextField(L.t(sv: "t.ex. johan_123", nb: "f.eks. johan_123"), text: $data.firstName)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .padding(16)
                    .background(RoundedRectangle(cornerRadius: 8).stroke(Color(.systemGray3), lineWidth: 1))
                    .onChange(of: data.firstName) { _, _ in
                        checkUsernameAvailability()
                    }
            }
            
            Text(L.t(sv: "Detta är namnet som visas för andra användare i appen.", nb: "Dette er navnet som vises for andre brukere i appen."))
                .font(.system(size: 13))
                .foregroundColor(.gray)
            
            // Username availability status
            if !data.firstName.isEmpty {
                HStack(spacing: 8) {
                    if isCheckingUsername {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text(L.t(sv: "Kontrollerar tillgänglighet...", nb: "Sjekker tilgjengelighet..."))
                            .font(.system(size: 14))
                            .foregroundColor(.gray)
                    } else if usernameIsTaken {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.red)
                        Text(L.t(sv: "Användarnamnet \"\(data.firstName)\" är redan taget", nb: "Brukernavnet \"\(data.firstName)\" er allerede tatt"))
                            .font(.system(size: 14))
                            .foregroundColor(.red)
                    } else {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text(L.t(sv: "Användarnamnet är tillgängligt", nb: "Brukernavnet er tilgjengelig"))
                            .font(.system(size: 14))
                            .foregroundColor(.green)
                    }
                }
                .padding(.top, 4)
                .animation(.easeInOut(duration: 0.2), value: isCheckingUsername)
                .animation(.easeInOut(duration: 0.2), value: usernameIsTaken)
            } else {
                Text(L.t(sv: "Din profil är offentlig som standard.", nb: "Profilen din er offentlig som standard."))
                    .font(.system(size: 14))
                    .foregroundColor(.gray)
            }
        }
    }
    
    // MARK: - Profile Picture Step
    private var profilePictureStepContent: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                Text(L.t(sv: "Profilbild", nb: "Profilbilde"))
                    .font(.system(size: 15))
                    .foregroundColor(primaryTextColor)
                
                // Profile picture picker area
                PhotosPicker(selection: $profilePhotoPickerItem, matching: .images) {
                    HStack(spacing: 16) {
                        // Profile picture preview
                        ZStack {
                            if let image = selectedProfileImage {
                                Image(uiImage: image)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 80, height: 80)
                                    .clipShape(Circle())
                            } else {
                                Circle()
                                    .fill(Color(.systemGray6))
                                    .frame(width: 80, height: 80)
                                    .overlay(
                                        Image(systemName: "camera.fill")
                                            .font(.system(size: 24))
                                            .foregroundColor(.gray)
                                    )
                            }
                            
                            // Edit badge
                            if selectedProfileImage != nil {
                                Circle()
                                    .fill(Color.primary)
                                    .frame(width: 24, height: 24)
                                    .overlay(
                                        Image(systemName: "pencil")
                                            .font(.system(size: 12, weight: .semibold))
                                            .foregroundColor(Color(.systemBackground))
                                    )
                                    .offset(x: 28, y: 28)
                            }
                        }
                        
                        // Text beside the image
                        VStack(alignment: .leading, spacing: 4) {
                            Text(selectedProfileImage == nil ? L.t(sv: "Lägg till foto", nb: "Legg til bilde") : L.t(sv: "Byt foto", nb: "Bytt bilde"))
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.primary)
                            
                            Text(L.t(sv: "Tryck för att välja från biblioteket", nb: "Trykk for å velge fra biblioteket"))
                                .font(.system(size: 14))
                                .foregroundColor(.gray)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.gray)
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color(.systemGray3), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                .onChange(of: profilePhotoPickerItem) { _, newValue in
                    Task {
                        if let imageData = try? await newValue?.loadTransferable(type: Data.self),
                           let image = UIImage(data: imageData) {
                            await MainActor.run {
                                selectedProfileImage = image
                                // Also save directly to data for onboarding completion
                                data.profileImage = image
                                print("📸 Profile image selected and saved to data: \(image.size)")
                            }
                        }
                    }
                }
            }
            
            Text(L.t(sv: "Din profilbild visas för dina vänner på Up&Down.", nb: "Profilbildet ditt vises for vennene dine på Up&Down."))
                .font(.system(size: 14))
                .foregroundColor(.gray)
        }
    }
    
    // MARK: - Referral Code Step
    @State private var referralCodeInput: String = ""
    @State private var isValidatingCode = false
    @State private var codeValidationResult: Bool? = nil
    
    private var referralCodeStepContent: some View {
        VStack(alignment: .leading, spacing: 24) {
            Spacer()
            
            // Referral code input with Submit button
            HStack(spacing: 12) {
                TextField(L.t(sv: "Kod", nb: "Kode"), text: $referralCodeInput)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .padding(.horizontal, 16)
                    .padding(.vertical, 18)
                    .onChange(of: referralCodeInput) { _, newValue in
                        referralCodeInput = newValue.uppercased()
                        codeValidationResult = nil
                        data.referralCode = newValue.uppercased()
                    }
                
                Button {
                    validateReferralCode()
                } label: {
                    if isValidatingCode {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Text(L.t(sv: "Skicka", nb: "Send"))
                            .font(.system(size: 16, weight: .semibold))
                    }
                }
                .foregroundColor(referralCodeInput.isEmpty ? .gray : .white)
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
                .background(referralCodeInput.isEmpty ? Color(.systemGray5) : Color(.systemGray3))
                .cornerRadius(20)
                .disabled(referralCodeInput.isEmpty || isValidatingCode)
            }
            .background(Color(.systemGray6))
            .cornerRadius(16)
            
            if codeValidationResult == true {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text(L.t(sv: "Kod aktiverad!", nb: "Kode aktivert!"))
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.green)
                }
            } else if codeValidationResult == false {
                HStack(spacing: 8) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.red)
                    Text(L.t(sv: "Koden hittades inte", nb: "Koden ble ikke funnet"))
                        .font(.system(size: 14))
                        .foregroundColor(.red)
                }
            }
            
            Spacer()
            Spacer()
        }
    }
    
    private func validateReferralCode() {
        guard !referralCodeInput.isEmpty else { return }
        isValidatingCode = true
        
        Task {
            let isValid = await ReferralService.shared.isCodeValid(code: referralCodeInput)
            await MainActor.run {
                codeValidationResult = isValid
                isValidatingCode = false
                if isValid {
                    data.referralCode = referralCodeInput
                }
            }
        }
    }
    
    // MARK: - Rating Step
    private var ratingStepContent: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 24) {
                // Rating card
                VStack(spacing: 8) {
                    HStack(spacing: 4) {
                        // Laurel left
                        Image(systemName: "laurel.leading")
                            .font(.system(size: 28))
                            .foregroundColor(Color(red: 0.85, green: 0.65, blue: 0.4))
                        
                        VStack(spacing: 4) {
                            HStack(spacing: 6) {
                                Text("4,9")
                                    .font(.system(size: 28, weight: .bold))
                                    .foregroundColor(primaryTextColor)
                                
                                HStack(spacing: 2) {
                                    ForEach(0..<5) { _ in
                                        Image(systemName: "star.fill")
                                            .font(.system(size: 16))
                                            .foregroundColor(Color(red: 0.85, green: 0.65, blue: 0.4))
                                    }
                                }
                            }
                            
                            Text(L.t(sv: "50+ AppStore betyg", nb: "50+ AppStore vurderinger"))
                                .font(.system(size: 14))
                                .foregroundColor(Color(red: 0.85, green: 0.65, blue: 0.4))
                        }
                        
                        // Laurel right
                        Image(systemName: "laurel.trailing")
                            .font(.system(size: 28))
                            .foregroundColor(Color(red: 0.85, green: 0.65, blue: 0.4))
                    }
                }
                .padding(.vertical, 20)
                .padding(.horizontal, 24)
                .frame(maxWidth: .infinity)
                .background(Color(.systemBackground))
                .cornerRadius(16)
                .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
                
                // "Made for people like you" section
                VStack(spacing: 16) {
                    Text(L.t(sv: "Up&Down skapades för\nmänniskor som du", nb: "Up&Down ble laget for\nmennesker som deg"))
                        .font(.system(size: 24, weight: .bold))
                        .multilineTextAlignment(.center)
                        .foregroundColor(primaryTextColor)
                    
                    // User avatars
                    HStack(spacing: -12) {
                        ForEach(["70", "71", "72"], id: \.self) { imageName in
                            Image(imageName)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 60, height: 60)
                                .clipShape(Circle())
                                .overlay(Circle().stroke(Color(.systemBackground), lineWidth: 3))
                        }
                    }
                    
                    Text(L.t(sv: "4k+ Up&Down användare", nb: "4k+ Up&Down brukere"))
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.gray)
                }
                .padding(.vertical, 20)
                
                // Reviews
                VStack(spacing: 12) {
                    OnboardingReviewCardSimple(
                        name: "Biffoli1",
                        review: L.t(sv: "Laddade ner appen i sommras och sen dess har jag alltid använt den när jag har gymmat. Grymt bra sätt att tracka sina pass samtidigt som man blir belönad för det, riktigt bra har inte sett ngn liknande app innan.", nb: "Lastet ned appen i sommer og siden da har jeg alltid brukt den når jeg har trent. Kjempebra måte å registrere øktene sine på samtidig som man blir belønnet for det, virkelig bra har ikke sett noen lignende app før.")
                    )
                    
                    OnboardingReviewCardSimple(
                        name: "Frank Höglund",
                        review: L.t(sv: "Jag har använt appen i någon månad nu och tycker verkligen att det har gett mig motivation både att hålla uppe min gym träning men framförallt har det hjälpt mig att tracka mina kalorier eftersom det är så lätt.", nb: "Jeg har brukt appen i noen måneder nå og synes virkelig det har gitt meg motivasjon både til å holde oppe gymtreningen min, men fremfor alt har det hjulpet meg å registrere kaloriene mine siden det er så lett.")
                    )
                }
            }
            .padding(.top, 8)
        }
        .onAppear {
            // Request iOS review popup
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                requestAppReview()
            }
        }
    }
    
    private func requestAppReview() {
        if let scene = UIApplication.shared.connectedScenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene {
            SKStoreReviewController.requestReview(in: scene)
        }
    }
    
    // MARK: - Progress Step (Weight Transition Graph)
    private var genderStepContent: some View {
        VStack(spacing: 12) {
            Spacer().frame(height: 40)
            genderButton(title: L.t(sv: "Man", nb: "Mann"), value: "male")
            genderButton(title: L.t(sv: "Kvinna", nb: "Kvinne"), value: "female")
            genderButton(title: L.t(sv: "Annat", nb: "Annet"), value: "other")
            
            Text(L.t(sv: "Denna datan kommer inte visas på din profil.", nb: "Disse dataene vil ikke vises på profilen din."))
                .font(.system(size: 13))
                .foregroundColor(.gray)
                .padding(.top, 8)
        }
    }
    
    private func genderButton(title: String, value: String) -> some View {
                        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                data.gender = value
            }
            hapticFeedback()
                        } label: {
            Text(title)
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(data.gender == value ? selectedCardTextColor : unselectedCardTextColor)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
                .background(RoundedRectangle(cornerRadius: 16).fill(data.gender == value ? selectedCardBackgroundColor : cardBackgroundColor))
        }
    }
    
    private var workoutsStepContent: some View {
        VStack(spacing: 12) {
            Spacer().frame(height: 20)
            workoutButton(range: "0-2", description: L.t(sv: "Tränar då och då", nb: "Trener av og til"), icon: "circle.fill", value: "0-2")
            workoutButton(range: "3-5", description: L.t(sv: "Några pass i veckan", nb: "Noen økter i uken"), icon: "circle.grid.2x1.fill", value: "3-5")
            workoutButton(range: "6+", description: L.t(sv: "Dedikerad atlet", nb: "Dedikert atlet"), icon: "circle.grid.3x3.fill", value: "6+")
        }
    }
    
    private func workoutButton(range: String, description: String, icon: String, value: String) -> some View {
                        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                data.workoutsPerWeek = value
            }
            hapticFeedback()
                        } label: {
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(range).font(.system(size: 18, weight: .semibold)).foregroundColor(primaryTextColor)
                    Text(description).font(.system(size: 14)).foregroundColor(.gray)
                }
                Spacer()
            }
                            .padding(18)
                            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(data.workoutsPerWeek == value ? Color(.systemGray5) : cardBackgroundColor)
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(data.workoutsPerWeek == value ? buttonBackgroundColor : Color.clear, lineWidth: 2))
            )
        }
    }
    
    private var heightWeightStepContent: some View {
        VStack(spacing: 20) {
            Spacer().frame(height: 20)
            
            HStack(spacing: 20) {
                VStack(spacing: 8) {
                    Text(L.t(sv: "Längd", nb: "Høyde")).font(.system(size: 16, weight: .semibold)).foregroundColor(primaryTextColor)
                    Picker(L.t(sv: "Längd", nb: "Høyde"), selection: $data.heightCm) {
                        ForEach(140...220, id: \.self) { cm in
                            Text("\(cm) cm").tag(cm)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(height: 150)
                }
                .frame(maxWidth: .infinity)
                
                VStack(spacing: 8) {
                    Text(L.t(sv: "Vikt", nb: "Vekt")).font(.system(size: 16, weight: .semibold)).foregroundColor(primaryTextColor)
                    Picker(L.t(sv: "Vikt", nb: "Vekt"), selection: Binding(
                        get: { Int(data.weightKg) },
                        set: { data.weightKg = Double($0) }
                    )) {
                        ForEach(40...200, id: \.self) { kg in
                            Text("\(kg) kg").tag(kg)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(height: 150)
                }
                .frame(maxWidth: .infinity)
            }
        }
    }
    
    private var birthdayStepContent: some View {
        VStack {
            Spacer().frame(height: 60)
            DatePicker("", selection: $data.birthDate, in: ...Date(), displayedComponents: .date)
                .datePickerStyle(.wheel)
                .labelsHidden()
                .environment(\.locale, Locale(identifier: "sv_SE"))
        }
    }
    
    // MARK: - Motivation Step Content
    private var motivationStepContent: some View {
        VStack(spacing: 32) {
            Spacer().frame(height: 40)
            
            // Comparison card
            VStack(spacing: 24) {
                // Bar chart comparison
                HStack(spacing: 16) {
                    VStack(spacing: 12) {
                        Text(L.t(sv: "Utan", nb: "Uten"))
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.gray)
                        Text("Up&Down")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        // Small bar
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(.systemGray5))
                            .frame(width: 100, height: showMotivationBars ? 80 : 0)
                            .overlay(
                                Text("1X")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(.gray)
                                    .opacity(showMotivationBars ? 1 : 0)
                            )
                            .animation(.spring(response: 0.8, dampingFraction: 0.7).delay(0.3), value: showMotivationBars)
                    }
                    .frame(height: 200)
                    
                    VStack(spacing: 12) {
                        Text(L.t(sv: "Med", nb: "Med"))
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.gray)
                        Text("Up&Down")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        // Large bar
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.black)
                            .frame(width: 100, height: showMotivationBars ? 160 : 0)
                            .overlay(
                                Text("2X")
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundColor(.white)
                                    .opacity(showMotivationBars ? 1 : 0)
                            )
                            .animation(.spring(response: 0.8, dampingFraction: 0.7).delay(0.5), value: showMotivationBars)
                    }
                    .frame(height: 200)
                }
                .padding(.horizontal, 20)
                
                Text(L.t(sv: "Genom att dela med vänner, få belöningar, se statistik & tracka dina pass håller våra användare igång längre jämfört med innan de började träna med Up&Down.", nb: "Ved å dele med venner, få belønninger, se statistikk og registrere øktene dine holder brukerne våre det gående lenger sammenlignet med før de begynte å trene med Up&Down."))
                    .font(.system(size: 14))
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                    .opacity(showMotivationBars ? 1 : 0)
                    .animation(.easeOut(duration: 0.5).delay(0.8), value: showMotivationBars)
            }
            .padding(.vertical, 32)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(Color(.systemGray6).opacity(0.5))
            )
            .padding(.horizontal, 20)
            
            Spacer()
        }
        .onAppear {
            // Reset and animate
            showMotivationBars = false
            motivationAnimationComplete = false
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                withAnimation {
                    showMotivationBars = true
                }
            }
            
            // Enable continue button after animation completes
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                withAnimation(.easeOut(duration: 0.3)) {
                    motivationAnimationComplete = true
                }
            }
        }
    }
    
    // MARK: - Find Friends Step Content
    private var findFriendsStepContent: some View {
        VStack(spacing: 0) {
            if !onboardingContactsGranted {
                VStack(spacing: 16) {
                    HStack(spacing: 12) {
                        Image(systemName: "person.crop.rectangle.stack")
                            .font(.system(size: 24))
                            .foregroundColor(primaryTextColor)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(L.t(sv: "Hitta vänner från kontakter", nb: "Finn venner fra kontakter"))
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(primaryTextColor)
                            Text(L.t(sv: "Se vilka av dina kontakter som redan finns på Up&Down", nb: "Se hvilke av kontaktene dine som allerede er på Up&Down"))
                                .font(.system(size: 13))
                                .foregroundColor(.gray)
                        }
                        
                        Spacer()
                    }
                    
                    Button {
                        requestOnboardingContactsPermission()
                    } label: {
                        Text(L.t(sv: "Aktivera kontakter", nb: "Aktiver kontakter"))
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(buttonTextColor)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(buttonBackgroundColor)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
                .padding(16)
                .background(RoundedRectangle(cornerRadius: 16).fill(cardBackgroundColor))
            } else if onboardingContactsLoading {
                VStack(spacing: 12) {
                    ProgressView()
                    Text(L.t(sv: "Söker efter vänner...", nb: "Søker etter venner..."))
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                }
                .padding(.vertical, 30)
            } else if !onboardingContacts.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text(L.t(sv: "\(onboardingContacts.count) kontakter på Up&Down", nb: "\(onboardingContacts.count) kontakter på Up&Down"))
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.gray)
                        .padding(.horizontal, 4)
                    
                    ForEach(onboardingContacts, id: \.id) { contact in
                        onboardingUserRow(id: contact.id, name: contact.name, avatarUrl: contact.avatarUrl, badge: nil)
                    }
                }
                .padding(.top, 8)
            } else if onboardingContactsGranted {
                VStack(spacing: 8) {
                    Image(systemName: "person.2.slash")
                        .font(.system(size: 28))
                        .foregroundColor(.gray)
                    Text(L.t(sv: "Inga kontakter hittade på Up&Down ännu", nb: "Ingen kontakter funnet på Up&Down ennå"))
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                }
                .padding(.vertical, 20)
            }
        }
    }
    
    private func onboardingUserRow(id: String, name: String, avatarUrl: String?, badge: String?) -> some View {
        HStack(spacing: 12) {
            if let url = avatarUrl, !url.isEmpty {
                AsyncImage(url: URL(string: SupabaseConfig.rewriteURL(url))) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    Circle().fill(Color(.systemGray5))
                        .overlay(Text(String(name.prefix(1)).uppercased()).font(.system(size: 16, weight: .semibold)).foregroundColor(.gray))
                }
                .frame(width: 44, height: 44)
                .clipShape(Circle())
            } else {
                Circle().fill(Color(.systemGray5))
                    .frame(width: 44, height: 44)
                    .overlay(Text(String(name.prefix(1)).uppercased()).font(.system(size: 16, weight: .semibold)).foregroundColor(.gray))
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(primaryTextColor)
                if let badge = badge {
                    Text(badge)
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                }
            }
            
            Spacer()
            
            Button {
                toggleOnboardingFollow(userId: id)
            } label: {
                Text(onboardingFollowingStatus[id] == true
                     ? L.t(sv: "Följer", nb: "Følger")
                     : L.t(sv: "Följ", nb: "Følg"))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(onboardingFollowingStatus[id] == true ? .gray : buttonTextColor)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        onboardingFollowingStatus[id] == true
                        ? Color(.systemGray5)
                        : buttonBackgroundColor
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .padding(.vertical, 6)
    }
    
    
    private func requestOnboardingContactsPermission() {
        let store = CNContactStore()
        store.requestAccess(for: .contacts) { granted, error in
            DispatchQueue.main.async {
                onboardingContactsGranted = granted
                if granted {
                    loadOnboardingContacts()
                }
            }
        }
    }
    
    private func loadOnboardingContacts() {
        onboardingContactsLoading = true
        Task {
            do {
                let store = CNContactStore()
                let keysToFetch: [CNKeyDescriptor] = [
                    CNContactGivenNameKey as CNKeyDescriptor,
                    CNContactFamilyNameKey as CNKeyDescriptor
                ]
                let request = CNContactFetchRequest(keysToFetch: keysToFetch)
                var contactNames: [String] = []
                
                try store.enumerateContacts(with: request) { contact, _ in
                    let fullName = "\(contact.givenName) \(contact.familyName)".trimmingCharacters(in: .whitespaces)
                    if !fullName.isEmpty {
                        contactNames.append(fullName)
                    }
                }
                
                let matched = try await SocialService.shared.findUsersByNames(names: contactNames)
                
                await MainActor.run {
                    self.onboardingContacts = matched.map { (id: $0.id, name: $0.name, avatarUrl: $0.avatarUrl) }
                    self.onboardingContactsLoading = false
                }
            } catch {
                print("❌ Error loading onboarding contacts: \(error)")
                await MainActor.run {
                    self.onboardingContactsLoading = false
                }
            }
        }
    }
    
    private func toggleOnboardingFollow(userId: String) {
        guard let currentUserId = authViewModel.currentUser?.id else { return }
        let isFollowing = onboardingFollowingStatus[userId] == true
        
        onboardingFollowingStatus[userId] = !isFollowing
        
        Task {
            do {
                if isFollowing {
                    try await SocialService.shared.unfollowUser(followerId: currentUserId, followingId: userId)
                } else {
                    try await SocialService.shared.followUser(followerId: currentUserId, followingId: userId)
                }
            } catch {
                await MainActor.run {
                    onboardingFollowingStatus[userId] = isFollowing
                }
            }
        }
    }
    
    private var appleHealthStepContent: some View {
                VStack(spacing: 20) {
                    Image("30")
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: 260)
                        .shadow(color: Color.black.opacity(0.1), radius: 20, x: 0, y: 12)
                        .padding(.top, 8)

            Text(data.healthAuthorized
                             ? L.t(sv: "Apple Health är aktiverat. Du kan gå vidare.", nb: "Apple Health er aktivert. Du kan gå videre.")
                 : L.t(sv: "Tryck på Fortsätt för att aktivera Apple Health.", nb: "Trykk på Fortsett for å aktivere Apple Health."))
                            .multilineTextAlignment(.center)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(secondaryTextColor)
                            .padding(.horizontal, 12)
                        
                        if let status = healthRequestStatus {
                            Text(status)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.green)
                        }
                    }
                }
    
    private var notificationsStepContent: some View {
                VStack(alignment: .leading, spacing: 20) {
            Spacer().frame(height: 20)
            
            Image(systemName: "bell.badge.fill")
                .resizable()
                .scaledToFit()
                .frame(width: 80, height: 80)
                .foregroundColor(primaryTextColor)
                .frame(maxWidth: .infinity)
            
                    Text(L.t(sv: "Få påminnelser om pass och nya belöningar.", nb: "Få påminnelser om økter og nye belønninger."))
                .font(.system(size: 16))
                .foregroundColor(secondaryTextColor)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
            
            Text(data.notificationsAuthorized
                 ? L.t(sv: "Notiser är aktiverade – tryck Fortsätt.", nb: "Varsler er aktivert – trykk Fortsett.")
                 : L.t(sv: "Tryck på Fortsätt för att aktivera notiser.", nb: "Trykk på Fortsett for å aktivere varsler."))
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(secondaryTextColor)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                    
                    if let status = notificationsStatus {
                        Text(status)
                            .font(.system(size: 14, weight: .medium))
                    .foregroundColor(data.notificationsAuthorized ? .green : .red)
                    .frame(maxWidth: .infinity)
            }
        }
    }
    
    // MARK: - Username Validation
    private func checkUsernameAvailability() {
        // Cancel previous check
        usernameCheckTask?.cancel()
        
        let username = data.firstName.trimmingCharacters(in: .whitespaces)
        guard !username.isEmpty, username.count >= 2 else {
            usernameIsTaken = false
            isCheckingUsername = false
            return
        }
        
        isCheckingUsername = true
        
        usernameCheckTask = Task {
            // Small delay for debouncing
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            
            guard !Task.isCancelled else { return }
            
            do {
                let response: [UsernameCheckResponse] = try await SupabaseConfig.supabase
                    .from("profiles")
                    .select("id")
                    .eq("username", value: username)
                    .execute()
                    .value
                
                await MainActor.run {
                    guard !Task.isCancelled else { return }
                    usernameIsTaken = !response.isEmpty
                    isCheckingUsername = false
                }
            } catch {
                await MainActor.run {
                    guard !Task.isCancelled else { return }
                    isCheckingUsername = false
                    usernameIsTaken = false // Assume available on error
                    print("⚠️ Error checking username: \(error)")
                }
            }
        }
    }
    
    // MARK: - Helper Functions
    private func canContinue(_ step: OnboardingStep) -> Bool {
        switch step {
        case .name:
            return !data.firstName.trimmingCharacters(in: .whitespaces).isEmpty &&
                   data.firstName.count >= 2 &&
                   !usernameIsTaken &&
                   !isCheckingUsername
        case .profilePicture:
            return selectedProfileImage != nil
        case .referralCode: return true // Always can continue (optional step)
        case .rating: return true
        case .gender: return !data.gender.isEmpty
        case .workouts: return !data.workoutsPerWeek.isEmpty
        case .community: return true
        case .heightWeight: return true
        case .birthday: return true
        case .motivation: return motivationAnimationComplete
        case .findFriends: return true
        case .appleHealth: return true
        case .notifications: return true
        case .welcome: return true
        }
    }
    
    private func continueButtonText(for step: OnboardingStep) -> String {
        switch step {
        case .referralCode:
            return L.t(sv: "Hoppa över", nb: "Hopp over")
        default:
            return L.t(sv: "Fortsätt", nb: "Fortsett")
        }
    }
    
    private func continueFromStep(_ step: OnboardingStep) {
        hapticFeedback()
        
        switch step {
        case .profilePicture:
            // Save profile image to data
            print("📸 Saving profile image from selectedProfileImage: \(selectedProfileImage != nil ? "YES" : "NO")")
            data.profileImage = selectedProfileImage
            if data.profileImage != nil {
                print("✅ Profile image saved to data.profileImage")
            } else {
                print("⚠️ data.profileImage is nil after assignment")
            }
            goToNextStep()
        case .appleHealth:
            if !data.healthAuthorized {
                HealthKitManager.shared.requestAuthorization { _ in
                    DispatchQueue.main.async {
                        let authorized = HealthKitManager.shared.isHealthDataAuthorized()
                        data.healthAuthorized = authorized
                        healthRequestStatus = authorized ? L.t(sv: "Apple Health aktiverad", nb: "Apple Health aktivert") : nil
                        goToNextStep()
                    }
                }
            } else {
                goToNextStep()
            }
        case .notifications:
            if !data.notificationsAuthorized {
                NotificationManager.shared.requestAuthorization { granted in
                    DispatchQueue.main.async {
                        data.notificationsAuthorized = granted
                        notificationsStatus = granted ? L.t(sv: "Notiser aktiverade", nb: "Varsler aktivert") : L.t(sv: "Notiser nekades", nb: "Varsler nektet")
                        goToNextStep()
                    }
                }
            } else {
                goToNextStep()
            }
        case .referralCode:
            // If a code was entered, validate and save it
            if !referralCodeInput.trimmingCharacters(in: .whitespaces).isEmpty {
                isValidatingCode = true
                Task {
                    let isValid = await ReferralService.shared.isCodeValid(code: referralCodeInput)
                    await MainActor.run {
                        isValidatingCode = false
                        codeValidationResult = isValid
                        
                        if isValid {
                            data.referralCode = referralCodeInput.uppercased()
                            // Small delay to show checkmark, then proceed
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                goToNextStep()
                            }
                        }
                    }
                }
            } else {
                // No code entered, just skip
                goToNextStep()
            }
        default:
            goToNextStep()
        }
    }
    
    private func goToNextStep() {
        if let step = onboardingStep, let index = onboardingSteps.firstIndex(of: step), index < onboardingSteps.count - 1 {
            // Animate out current content smoothly
            withAnimation(.easeOut(duration: 0.2)) {
                contentOpacity = 0
                contentOffset = -20
            }
            
            // Change step after animation completes
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
                
                // Immediately set initial state for new content (no animation)
                var transaction = Transaction()
                transaction.disablesAnimations = true
                withTransaction(transaction) {
                    contentOpacity = 0
                    contentOffset = 30
                }
                
                // Update the step
                onboardingStep = onboardingSteps[index + 1]
                
                // Small delay then animate in
                try? await Task.sleep(nanoseconds: 50_000_000) // 0.05 seconds
                
                withAnimation(.spring(response: 0.45, dampingFraction: 0.9)) {
                    contentOpacity = 1
                    contentOffset = 0
                }
            }
        }
    }
    
    private func goToPreviousStep() {
        if let step = onboardingStep, let index = onboardingSteps.firstIndex(of: step), index > 0 {
            hapticFeedback()
            
            // Animate out current content (slide right for going back)
            withAnimation(.easeOut(duration: 0.2)) {
                contentOpacity = 0
                contentOffset = 20
            }
            
            // Change step after animation completes
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
                
                // Immediately set initial state for new content (no animation)
                var transaction = Transaction()
                transaction.disablesAnimations = true
                withTransaction(transaction) {
                    contentOpacity = 0
                    contentOffset = -30
                }
                
                // Update the step
                onboardingStep = onboardingSteps[index - 1]
                
                // Small delay then animate in
                try? await Task.sleep(nanoseconds: 50_000_000) // 0.05 seconds
                
                withAnimation(.spring(response: 0.45, dampingFraction: 0.9)) {
                    contentOpacity = 1
                    contentOffset = 0
                }
            }
        }
    }
    
    private func animateContentIn() {
        // Only animate if coming from outside (not from goToNextStep)
        // goToNextStep handles its own animation
        guard contentOpacity != 0 else { return }
        
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            contentOpacity = 0
            contentOffset = 30
        }
        
        withAnimation(.spring(response: 0.45, dampingFraction: 0.9).delay(0.05)) {
            contentOpacity = 1
            contentOffset = 0
        }
    }
    
    private func hapticFeedback() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
    }
    
    private func calculateNutritionPlan() {
        let bmr: Double
        let weight = data.weightKg
        let height = Double(data.heightCm)
        let age = Double(data.age)
        
        if data.gender == "male" {
            bmr = 10 * weight + 6.25 * height - 5 * age + 5
        } else {
            bmr = 10 * weight + 6.25 * height - 5 * age - 161
        }
        
        let activityMultiplier: Double
        switch data.workoutsPerWeek {
        case "0-2": activityMultiplier = 1.375
        case "3-5": activityMultiplier = 1.55
        case "6+": activityMultiplier = 1.725
        default: activityMultiplier = 1.375
        }
        
        var tdee = bmr * activityMultiplier
        
        switch data.goal {
        case "lose": tdee -= 500
        case "gain": tdee += 300
        default: break
        }
        
        let calories = Int(tdee)
        let protein = Int(weight * 2.0)
        let fat = Int(tdee * 0.25 / 9)
        let carbs = Int((tdee - Double(protein * 4) - Double(fat * 9)) / 4)
        
        data.dailyCalories = calories
        data.dailyProtein = protein
        data.dailyCarbs = max(carbs, 50)
        data.dailyFat = fat
    }
    
    private func validateAndSetInviteCode() {
        let code = inviteCodeInput.trimmingCharacters(in: .whitespaces).uppercased()
        guard !code.isEmpty else { return }
        
        isValidatingInvite = true
        Task {
            let valid = await InviteService.shared.validateInviteCode(code: code)
            await MainActor.run {
                isValidatingInvite = false
                inviteCodeValid = valid
                if valid {
                    pendingInviteCode = code
                    authViewModel.pendingInviteCode = code
                    authViewModel.errorMessage = ""
                }
            }
        }
    }
    
    private func createAccountAndStartOnboarding() {
        let trimmedEmail = signupEmail.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Danderyd domain restriction
        let isAllowedDomain = trimmedEmail.lowercased().hasSuffix(AuthViewModel.allowedEmailDomain)
        let hasValidInvite = pendingInviteCode != nil
        
        if !isAllowedDomain && !hasValidInvite {
            authViewModel.errorMessage = AuthViewModel.domainRestrictionMessage
            return
        }
        
        Task {
            await MainActor.run {
                authViewModel.isLoading = true
                authViewModel.errorMessage = ""
            }
            
            do {
                let response = try await SupabaseConfig.supabase.auth.signUp(email: trimmedEmail, password: signupPassword)
                let userId = response.user.id.uuidString
                
                let placeholderUsername = "user-\(userId.prefix(6))"
                let newUser = User(id: userId, name: placeholderUsername, email: trimmedEmail)
                try await ProfileService.shared.createUserProfile(newUser)
                
                // Redeem invite code if used
                if let inviteCode = pendingInviteCode {
                    let redeemed = await InviteService.shared.redeemInviteCode(code: inviteCode, userId: userId)
                    if redeemed { print("✅ Invite code redeemed during signup") }
                    await MainActor.run { pendingInviteCode = nil }
                }
                
                await RevenueCatManager.shared.logInFor(appUserId: userId)
                
                await MainActor.run {
                    authViewModel.currentUser = newUser
                    authViewModel.isLoading = false
                    showSignupForm = false
                    onboardingStep = onboardingSteps.first
                }
            } catch {
                await MainActor.run {
                    authViewModel.errorMessage = L.t(sv: "Kunde inte skapa konto: \(error.localizedDescription)", nb: "Kunne ikke opprette konto: \(error.localizedDescription)")
                    authViewModel.isLoading = false
                }
            }
        }
    }
    
    private func completeOnboarding() {
        Task {
            if let userId = authViewModel.currentUser?.id {
                let finalUsername = data.firstName.trimmingCharacters(in: .whitespaces)
                
                // Apply referral code if entered
                if !data.referralCode.isEmpty {
                    print("🎁 Applying referral code: \(data.referralCode)")
                    do {
                        let success = try await ReferralService.shared.useReferralCode(
                            code: data.referralCode,
                            referredUserId: userId
                        )
                        if success {
                            print("✅ Referral code applied successfully")
                        } else {
                            print("⚠️ Referral code could not be applied")
                        }
                    } catch {
                        print("❌ Error applying referral code: \(error)")
                    }
                }
                
                // Debug: Log nutrition values before saving
                print("🔍 ONBOARDING DEBUG:")
                print("   User ID: \(userId)")
                print("   Calories: \(data.dailyCalories)")
                print("   Protein: \(data.dailyProtein)")
                print("   Carbs: \(data.dailyCarbs)")
                print("   Fat: \(data.dailyFat)")
                
                calculateNutritionPlan()
                
                // Step 1: Try to update username (with fallback if duplicate)
                var usernameUpdated = false
                do {
                    print("📝 Updating username to: '\(finalUsername)'")
                    try await ProfileService.shared.updateUsername(userId: userId, username: finalUsername)
                    print("✅ Username updated successfully to: '\(finalUsername)'")
                    usernameUpdated = true
                } catch {
                    print("⚠️ Username update failed: \(error)")
                    // Try with unique suffix if duplicate
                    let uniqueUsername = "\(finalUsername)_\(String(userId.prefix(4)))"
                    do {
                        print("📝 Trying unique username: '\(uniqueUsername)'")
                        try await ProfileService.shared.updateUsername(userId: userId, username: uniqueUsername)
                        print("✅ Username updated with unique suffix: '\(uniqueUsername)'")
                        usernameUpdated = true
                    } catch {
                        print("❌ Username update failed even with unique suffix: \(error)")
                    }
                }
                
                // Step 2: Update nutrition/profile data (separate from username)
                do {
                    let dateFormatter = DateFormatter()
                    dateFormatter.dateFormat = "yyyy-MM-dd"
                    let birthDateString = dateFormatter.string(from: data.birthDate)
                    
                    let updateData = NutritionProfileUpdate(
                        daily_calories_goal: data.dailyCalories,
                        daily_protein_goal: data.dailyProtein,
                        daily_carbs_goal: data.dailyCarbs,
                        daily_fat_goal: data.dailyFat,
                        target_weight: data.targetWeightKg,
                        height_cm: data.heightCm,
                        weight_kg: data.weightKg,
                        gender: data.gender,
                        fitness_goal: data.goal,
                        workouts_per_week: data.workoutsPerWeek,
                        birth_date: birthDateString
                    )
                    
                    try await SupabaseConfig.supabase
                        .from("profiles")
                        .update(updateData)
                        .eq("id", value: userId)
                        .execute()
                    
                    print("✅ Nutrition/profile data saved")
                } catch {
                    print("⚠️ Failed to save nutrition data: \(error)")
                }
                
                // Step 3: Upload profile picture (always try, regardless of previous errors)
                if let profileImage = data.profileImage {
                    print("📸 Uploading profile picture... Size: \(profileImage.size)")
                    await uploadProfilePicture(image: profileImage, userId: userId)
                } else if let fallbackImage = selectedProfileImage {
                    print("📸 Using fallback selectedProfileImage... Size: \(fallbackImage.size)")
                    await uploadProfilePicture(image: fallbackImage, userId: userId)
                } else {
                    print("⚠️ No profile image to upload")
                }
                
                // Save locally (user-specific)
                print("💾 Saving goals locally for user: \(userId)")
                print("   Calories: \(data.dailyCalories), Protein: \(data.dailyProtein), Carbs: \(data.dailyCarbs), Fat: \(data.dailyFat)")
                
                NutritionGoalsManager.shared.saveGoals(
                    calories: data.dailyCalories,
                    protein: data.dailyProtein,
                    carbs: data.dailyCarbs,
                    fat: data.dailyFat,
                    userId: userId
                )
                
                // Verify save was successful
                if let savedGoals = NutritionGoalsManager.shared.loadGoals(userId: userId) {
                    print("✅ Verified saved goals - Calories: \(savedGoals.calories)")
                } else {
                    print("❌ Failed to verify saved goals!")
                }
                
                // Fetch updated profile and make sure we have the new username
                do {
                    if let updatedProfile = try await ProfileService.shared.fetchUserProfile(userId: userId) {
                        await MainActor.run {
                            authViewModel.currentUser = updatedProfile
                            print("✅ Profile loaded with name: '\(updatedProfile.name)'")
                        }
                    } else {
                        // Fallback: manually update the current user's name
                        await MainActor.run {
                            authViewModel.currentUser?.name = finalUsername
                            print("⚠️ Profile fetch returned nil, manually set name to: '\(finalUsername)'")
                        }
                    }
                } catch {
                    // Fallback: manually update the current user's name
                    await MainActor.run {
                        authViewModel.currentUser?.name = finalUsername
                        print("⚠️ Profile fetch failed: \(error), manually set name to: '\(finalUsername)'")
                    }
                }
                
                // Set current user for scan limit managers
                await MainActor.run {
                    AIScanLimitManager.shared.setCurrentUser(userId: userId)
                    BarcodeScanLimitManager.shared.setCurrentUser(userId: userId)
                    
                    // Mark onboarding data as ready and show soft paywall
                    onboardingDataReady = true
                    showOnboardingPaywall = true
                    print("💳 Showing soft paywall after onboarding...")
                }
            }
        }
    }
    
    /// Called after paywall is dismissed (either purchased or skipped)
    private func finalizeOnboarding() {
        guard onboardingDataReady else { return }
        
        // Mark onboarding as completed in database
        if let userId = authViewModel.currentUser?.id {
            Task {
                try? await ProfileService.shared.updateOnboardingCompleted(userId: userId)
            }
        }
        
        // Update local user model
        authViewModel.currentUser?.onboardingCompleted = true
        authViewModel.needsOnboarding = false
        
        // Enter the app
        authViewModel.isLoggedIn = true
        
        // Set user for streak manager (new user starts fresh)
        if let userId = authViewModel.currentUser?.id {
            StreakManager.shared.setUser(userId: userId)
            GymLocationManager.shared.setUser(userId: userId)
        }
        
        print("✅ Onboarding complete, entering app with name: '\(authViewModel.currentUser?.name ?? "unknown")'")
        
        // Post notification after a small delay to ensure HomeView is ready
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            NotificationCenter.default.post(name: NSNotification.Name("NutritionGoalsUpdated"), object: nil)
            print("📢 Posted NutritionGoalsUpdated notification")
        }
        
        // Reset state
        onboardingDataReady = false
    }
    
    private func uploadProfilePicture(image: UIImage, userId: String) async {
        // Resize and compress image
        let maxSize: CGFloat = 500
        let scale = min(maxSize / image.size.width, maxSize / image.size.height, 1.0)
        let newSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        
        UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
        image.draw(in: CGRect(origin: .zero, size: newSize))
        let resizedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        guard let imageData = resizedImage?.jpegData(compressionQuality: 0.8) else {
            print("❌ Failed to convert profile image to data")
            return
        }
        
        let fileName = "\(userId)/avatar.jpg"
        
        do {
            print("📤 Uploading to avatars bucket, path: \(fileName)")
            
            // Upload to Supabase Storage
            try await SupabaseConfig.supabase.storage
                .from("avatars")
                .upload(
                    path: fileName,
                    file: imageData,
                    options: FileOptions(contentType: "image/jpeg", upsert: true)
                )
            
            print("✅ Upload to storage successful")
            
            // Get public URL
            let publicURL = try SupabaseConfig.supabase.storage
                .from("avatars")
                .getPublicURL(path: fileName)
            
            // Add timestamp to URL to bypass cache
            let avatarUrlString = publicURL.absoluteString + "?t=\(Date().timeIntervalSince1970)"
            
            print("🔗 Avatar URL: \(avatarUrlString)")
            
            // Update profile with avatar URL
            try await SupabaseConfig.supabase
                .from("profiles")
                .update(["avatar_url": avatarUrlString])
                .eq("id", value: userId)
                .execute()
            
            print("✅ Profile updated with avatar URL")
            
            print("✅ Profile picture uploaded successfully")
            
            // Update local user
            await MainActor.run {
                authViewModel.currentUser?.avatarUrl = avatarUrlString
            }
        } catch {
            print("❌ Failed to upload profile picture: \(error)")
        }
    }
}

// MARK: - Onboarding Review Card
struct OnboardingReviewCard: View {
    let name: String
    let review: String
    let imageName: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(imageName)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 44, height: 44)
                    .clipShape(Circle())
                
                Text(name)
                    .font(.system(size: 16, weight: .semibold))
                
                Spacer()
                
                HStack(spacing: 2) {
                    ForEach(0..<5) { _ in
                        Image(systemName: "star.fill")
                            .font(.system(size: 12))
                            .foregroundColor(Color(red: 0.85, green: 0.65, blue: 0.4))
                    }
                }
            }
            
            Text(review)
                .font(.system(size: 14))
                .foregroundColor(.gray)
                .lineLimit(3)
        }
        .padding(16)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
    }
}

// MARK: - Onboarding Review Card Simple (without image)
struct OnboardingReviewCardSimple: View {
    let name: String
    let review: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(name)
                    .font(.system(size: 16, weight: .semibold))
                
                Spacer()
                
                HStack(spacing: 2) {
                    ForEach(0..<5) { _ in
                        Image(systemName: "star.fill")
                            .font(.system(size: 12))
                            .foregroundColor(Color(red: 0.85, green: 0.65, blue: 0.4))
                    }
                }
            }
            
            Text(review)
                .font(.system(size: 14))
                .foregroundColor(.gray)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
    }
}

// MARK: - Login Form
struct LoginFormView: View {
    @State private var email = ""
    @State private var password = ""
    @State private var isPasswordVisible = false
    @State private var showForgotPassword = false
    @State private var forgotPasswordEmail = ""
    @State private var isResettingPassword = false
    @State private var resetMessage = ""
    @State private var resetSuccess = false
    @EnvironmentObject var authViewModel: AuthViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text(L.t(sv: "E-post", nb: "E-post")).font(.system(size: 14, weight: .medium)).foregroundColor(.black)
                TextField(L.t(sv: "E-post", nb: "E-post"), text: $email)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)
                    .padding(14)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text(L.t(sv: "Lösenord", nb: "Passord")).font(.system(size: 14, weight: .medium)).foregroundColor(.black)
                ZStack(alignment: .trailing) {
                    if isPasswordVisible {
                        TextField(L.t(sv: "Lösenord", nb: "Passord"), text: $password).textContentType(.password).padding(14).background(Color(.systemGray6)).cornerRadius(8)
                    } else {
                        SecureField(L.t(sv: "Lösenord", nb: "Passord"), text: $password).textContentType(.password).padding(14).background(Color(.systemGray6)).cornerRadius(8)
                    }
                    Button { isPasswordVisible.toggle() } label: {
                        Image(systemName: isPasswordVisible ? "eye.slash.fill" : "eye.fill").foregroundColor(.gray).padding(.trailing, 14)
                    }
                }
            }
            
            Button {
                forgotPasswordEmail = email
                showForgotPassword = true
            } label: {
                Text(L.t(sv: "Glömt lösenord?", nb: "Glemt passord?")).font(.system(size: 14, weight: .medium)).foregroundColor(.black.opacity(0.7)).underline()
            }
            
            if !authViewModel.errorMessage.isEmpty {
                Text(authViewModel.errorMessage).foregroundColor(.red).font(.system(size: 13))
            }
            
            Button {
                authViewModel.login(email: email, password: password)
            } label: {
                HStack {
                    Spacer()
                    if authViewModel.isLoading {
                        ProgressView().tint(.black.opacity(0.6))
                    } else {
                        Text(L.t(sv: "Logga in", nb: "Logg inn")).font(.system(size: 17, weight: .semibold)).foregroundColor(email.isEmpty || password.isEmpty ? .black.opacity(0.4) : .black)
                    }
                    Spacer()
                }
                .padding(.vertical, 16)
                .background(RoundedRectangle(cornerRadius: 30).fill(Color(red: 0.9, green: 0.88, blue: 0.85)))
            }
            .disabled(authViewModel.isLoading || email.isEmpty || password.isEmpty)
            .opacity(email.isEmpty || password.isEmpty ? 0.7 : 1)
        }
        .sheet(isPresented: $showForgotPassword) {
            ForgotPasswordSheet(email: $forgotPasswordEmail, isLoading: $isResettingPassword, message: $resetMessage, success: $resetSuccess, onReset: {
                    Task {
                        isResettingPassword = true
                        let result = await authViewModel.resetPassword(email: forgotPasswordEmail)
                        await MainActor.run {
                            resetMessage = result.message
                            resetSuccess = result.success
                            isResettingPassword = false
                        }
                    }
            }, onDismiss: {
                    showForgotPassword = false
                    resetMessage = ""
                    resetSuccess = false
            })
            .presentationDetents([.medium])
        }
    }
}

// MARK: - Forgot Password Sheet
struct ForgotPasswordSheet: View {
    @Binding var email: String
    @Binding var isLoading: Bool
    @Binding var message: String
    @Binding var success: Bool
    let onReset: () -> Void
    let onDismiss: () -> Void
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                VStack(spacing: 12) {
                    Image(systemName: "envelope.badge").font(.system(size: 50)).foregroundColor(.primary)
                    Text(L.t(sv: "Återställ lösenord", nb: "Tilbakestill passord")).font(.system(size: 24, weight: .bold))
                    Text(L.t(sv: "Ange din e-postadress så skickar vi instruktioner för att återställa ditt lösenord.", nb: "Skriv inn e-postadressen din, så sender vi instruksjoner for å tilbakestille passordet ditt."))
                        .font(.system(size: 15)).foregroundColor(.gray).multilineTextAlignment(.center).padding(.horizontal)
                }
                .padding(.top, 20)
                
                TextField(L.t(sv: "E-postadress", nb: "E-postadresse"), text: $email)
                    .textContentType(.emailAddress).keyboardType(.emailAddress).autocapitalization(.none)
                    .padding(14).background(Color(.systemGray6)).cornerRadius(12).padding(.horizontal, 24)
                
                if !message.isEmpty {
                    Text(message).font(.system(size: 14)).foregroundColor(success ? .black : .red).multilineTextAlignment(.center).padding(.horizontal, 24)
                }
                
                if success {
                    Button { onDismiss() } label: {
                        Text(L.t(sv: "Stäng", nb: "Lukk")).font(.system(size: 16, weight: .semibold)).foregroundColor(.white).frame(maxWidth: .infinity).padding(14).background(Color.black).cornerRadius(12)
                    }
                    .padding(.horizontal, 24)
                } else {
                    Button { onReset() } label: {
                        if isLoading { ProgressView().tint(.white) } else { Text(L.t(sv: "Skicka återställningslänk", nb: "Send tilbakestillingslenke")).font(.system(size: 16, weight: .semibold)) }
                    }
                    .foregroundColor(.white).frame(maxWidth: .infinity).padding(14).background(email.isEmpty ? Color.gray : Color.black).cornerRadius(12).disabled(email.isEmpty || isLoading).padding(.horizontal, 24)
                }
                
                Spacer()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(L.t(sv: "Avbryt", nb: "Avbryt")) { onDismiss() }.foregroundColor(.primary)
                }
            }
        }
    }
}

// MARK: - Macro Result Card (Editable)
#Preview {
    AuthenticationView()
        .environmentObject(AuthViewModel())
}
