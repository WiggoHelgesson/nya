import SwiftUI
import CoreLocation
import PhotosUI
import Supabase
import UIKit
import Combine
import StoreKit

// MARK: - New Unified Onboarding Steps
private enum OnboardingStep: Int, CaseIterable, Identifiable {
    case name
    case profilePicture  // NEW: Add profile picture
    case gender
    case workouts
    case heightWeight
    case birthday
    case goal
    case results  // NEW: Shows animated graph
    case targetWeight
    case motivation  // NEW: Shows motivation comparison
    case referralCode
    case rating  // NEW: Shows ratings and triggers iOS review popup
    case progress  // NEW: Shows progress graph
    case appleHealth
    case notifications
    
    var id: Int { rawValue }
    
    var title: String {
        switch self {
        case .name: return "Välj användarnamn"
        case .profilePicture: return "Lägg till profilbild"
        case .gender: return "Välj ditt kön"
        case .workouts: return "Hur många pass tränar du per vecka?"
        case .heightWeight: return "Längd & vikt"
        case .birthday: return "När är du född?"
        case .goal: return "Vad är ditt mål?"
        case .results: return "Up&Down gör det lättare för dig att nå dina mål"
        case .targetWeight: return "Vad är din målvikt?"
        case .motivation: return "Få 2x så mycket motivation genom att träna med Up&Down"
        case .referralCode: return "Ange kod (valfritt)"
        case .rating: return "Betygsätt oss"
        case .progress: return "Att nå sina mål tar lite tid men du fixar det!"
        case .appleHealth: return "Aktivera Apple Health"
        case .notifications: return "Aktivera notiser"
        }
    }
    
    var subtitle: String {
        switch self {
        case .name: return "Välj ett användarnamn som visas för andra."
        case .profilePicture: return "Allt blir roligare med en profilbild."
        case .gender: return "Detta används för att kalibrera din personliga plan."
        case .workouts: return "Detta används för att kalibrera din personliga plan."
        case .heightWeight: return "Detta används för att kalibrera din personliga plan."
        case .birthday: return "Detta används för att kalibrera din personliga plan."
        case .goal: return "Detta hjälper oss skapa en plan för ditt kaloriintag."
        case .results: return ""
        case .targetWeight: return "Välj den vikt du vill uppnå."
        case .motivation: return ""
        case .referralCode: return "Du kan hoppa över detta steg"
        case .rating: return ""
        case .progress: return ""
        case .appleHealth: return "Appen behöver hälsodata för att logga dina pass och steg."
        case .notifications: return "Så vi kan påminna dig om mål och belöningar."
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
    
    // Calculation states
    @State private var isCalculating = false
    @State private var calculationProgress: Double = 0
    @State private var calculationStep: String = ""
    @State private var showResults = false
    
    // Animation
    @State private var contentOpacity: Double = 1
    @State private var contentOffset: CGFloat = 0
    @State private var showResultsGraph: Bool = false
    @State private var resultsAnimationComplete: Bool = false
    
    // Motivation step animation
    @State private var motivationAnimationComplete: Bool = false
    @State private var showMotivationBars: Bool = false
    
    // Progress step animation
    @State private var progressAnimationComplete: Bool = false
    @State private var progressLineWidth: CGFloat = 0
    @State private var showProgressDots: [Bool] = [false, false, false, false]
    
    // Profile picture
    @State private var selectedProfileImage: UIImage? = nil
    @State private var profilePhotoPickerItem: PhotosPickerItem? = nil
    
    // Username validation
    @State private var isCheckingUsername: Bool = false
    @State private var usernameIsTaken: Bool = false
    @State private var usernameCheckTask: Task<Void, Never>? = nil
    
    // Soft paywall after onboarding
    @State private var showOnboardingPaywall = false
    @State private var onboardingDataReady = false
    
    private let heroImages = ["65", "66", "67"]
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
            
            if showResults {
                resultsView
            } else if isCalculating {
                calculatingView
            } else if let step = onboardingStep {
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
            healthRequestStatus = healthAuthorized ? "Apple Health aktiverad" : nil
            
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
            healthRequestStatus = authorized ? "Apple Health aktiverad" : nil
        }
    }
    
    // MARK: - Landing View
    private var landingView: some View {
        let autoSwipeTimer = Timer.publish(every: 4, on: .main, in: .common).autoconnect()
        
        let imageCount = heroImages.count
        return VStack(spacing: 0) {
            TabView(selection: $currentHeroIndex) {
                ForEach(0..<imageCount, id: \.self) { index in
                    Image(heroImages[index])
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .clipped()
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .ignoresSafeArea(edges: .top)
            .animation(.spring(response: 0.6, dampingFraction: 0.8), value: currentHeroIndex)
            .onReceive(autoSwipeTimer) { _ in
                withAnimation {
                    currentHeroIndex = (currentHeroIndex + 1) % heroImages.count
                }
            }
            
            VStack(spacing: 24) {
                HStack(spacing: 8) {
                    ForEach(0..<heroImages.count, id: \.self) { index in
                        Circle()
                            .fill(index == currentHeroIndex ? primaryTextColor : primaryTextColor.opacity(0.25))
                            .frame(width: 8, height: 8)
                            .scaleEffect(index == currentHeroIndex ? 1.2 : 1.0)
                    }
                }
                
                VStack(spacing: 14) {
                    Button {
                        showLanding = false
                        showSignupForm = true
                    } label: {
                        Text("Skapa konto helt gratis")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(buttonTextColor)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(buttonBackgroundColor)
                            .clipShape(Capsule())
                    }
                    .padding(.horizontal, 24)
                    
                    Button {
                        showLanding = false
                        showSignupForm = false
                    } label: {
                        Text("Logga in")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(primaryTextColor)
                    }
                }
            }
            .padding(.vertical, 24)
            .background(backgroundColor)
        }
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
                    Text("Logga in på Up&Down")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(primaryTextColor)
                        .padding(.top, 8)
                    
                    LoginFormView()
                        .environmentObject(authViewModel)
                    
                    HStack {
                        Rectangle().fill(Color(.systemGray4)).frame(height: 1)
                        Text("eller").font(.system(size: 14)).foregroundColor(.gray).padding(.horizontal, 16)
                        Rectangle().fill(Color(.systemGray4)).frame(height: 1)
                    }
                    
                    Button {
                        authViewModel.signInWithApple()
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "apple.logo")
                                .font(.system(size: 20, weight: .medium))
                            Text("Logga in med Apple")
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
                            Text("Logga in med Google")
                                .font(.system(size: 17, weight: .medium))
                            Spacer()
                        }
                        .foregroundColor(primaryTextColor)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 16)
                        .background(RoundedRectangle(cornerRadius: 30).stroke(Color(.systemGray3), lineWidth: 1.5))
                    }
                    .disabled(authViewModel.isLoading)
                    
                    Text("Genom att fortsätta godkänner du våra [användarvillkor](https://wiggio.se/privacy) och [integritetspolicy](https://wiggio.se/privacy).")
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
                    Text("Skapa konto")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(primaryTextColor)
                        .padding(.top, 8)
                    
                    Button {
                        authViewModel.signInWithApple(onboardingData: OnboardingData())
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "apple.logo")
                                .font(.system(size: 20, weight: .medium))
                            Text("Skapa konto med Apple")
                                .font(.system(size: 17, weight: .medium))
                        }
                        .foregroundColor(primaryTextColor)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(RoundedRectangle(cornerRadius: 30).stroke(Color(.systemGray3), lineWidth: 1))
                    }
                    .disabled(authViewModel.isLoading)
                    
                    Button {
                        authViewModel.signInWithGoogle(onboardingData: OnboardingData())
                    } label: {
                        HStack(spacing: 12) {
                            Image("78")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 20, height: 20)
                            Text("Skapa konto med Google")
                                .font(.system(size: 17, weight: .medium))
                        }
                        .foregroundColor(primaryTextColor)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(RoundedRectangle(cornerRadius: 30).stroke(Color(.systemGray3), lineWidth: 1))
                    }
                    .disabled(authViewModel.isLoading)
                    
                    HStack {
                        Rectangle().fill(Color(.systemGray4)).frame(height: 1)
                        Text("eller").font(.system(size: 14)).foregroundColor(.gray).padding(.horizontal, 16)
                        Rectangle().fill(Color(.systemGray4)).frame(height: 1)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("E-post").font(.system(size: 15)).foregroundColor(primaryTextColor)
                        TextField("E-post", text: $signupEmail)
                            .keyboardType(.emailAddress)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .padding(14)
                            .background(RoundedRectangle(cornerRadius: 8).stroke(Color(.systemGray4), lineWidth: 1))
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Lösenord").font(.system(size: 15)).foregroundColor(primaryTextColor)
                        SecureField("Minst 6 tecken", text: $signupPassword)
                            .padding(14)
                            .background(RoundedRectangle(cornerRadius: 8).stroke(Color(.systemGray4), lineWidth: 1))
                    }
                    
                    Button {
                        createAccountAndStartOnboarding()
                    } label: {
                        if authViewModel.isLoading {
                            ProgressView().tint(buttonTextColor).frame(maxWidth: .infinity).padding(.vertical, 16).background(buttonBackgroundColor).clipShape(Capsule())
                        } else {
                            Text("Registrera dig")
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
                    
                    Text("Genom att fortsätta godkänner du våra [Användarvillkor](https://www.upanddownapp.com/terms) och [Integritetspolicy](https://www.upanddownapp.com/privacy).")
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
    
    // MARK: - Onboarding View
    private func onboardingView(for step: OnboardingStep) -> some View {
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
                    Text(step.title)
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
        // Animation is handled by goToNextStep/goToPreviousStep
        // This onChange is kept for any programmatic step changes
        .onChange(of: step) { oldStep, newStep in
            // Only animate if not already animated by navigation functions
            // (contentOpacity will already be 0 if navigating via buttons)
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
        case .progress:
            progressStepContent
        case .gender:
            genderStepContent
        case .workouts:
            workoutsStepContent
        case .heightWeight:
            heightWeightStepContent
        case .birthday:
            birthdayStepContent
        case .goal:
            goalStepContent
        case .results:
            resultsStepContent
        case .targetWeight:
            targetWeightStepContent
        case .motivation:
            motivationStepContent
        case .appleHealth:
            appleHealthStepContent
        case .notifications:
            notificationsStepContent
        }
    }
    
    // MARK: - Step Contents
    private var nameStepContent: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Användarnamn")
                    .font(.system(size: 15))
                    .foregroundColor(primaryTextColor)
                TextField("t.ex. johan_123", text: $data.firstName)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .padding(16)
                    .background(RoundedRectangle(cornerRadius: 8).stroke(Color(.systemGray3), lineWidth: 1))
                    .onChange(of: data.firstName) { _, _ in
                        checkUsernameAvailability()
                    }
            }
            
            Text("Detta är namnet som visas för andra användare i appen.")
                .font(.system(size: 13))
                .foregroundColor(.gray)
            
            // Username availability status
            if !data.firstName.isEmpty {
                HStack(spacing: 8) {
                    if isCheckingUsername {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("Kontrollerar tillgänglighet...")
                            .font(.system(size: 14))
                            .foregroundColor(.gray)
                    } else if usernameIsTaken {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.red)
                        Text("Användarnamnet \"\(data.firstName)\" är redan taget")
                            .font(.system(size: 14))
                            .foregroundColor(.red)
                    } else {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("Användarnamnet är tillgängligt")
                            .font(.system(size: 14))
                            .foregroundColor(.green)
                    }
                }
                .padding(.top, 4)
                .animation(.easeInOut(duration: 0.2), value: isCheckingUsername)
                .animation(.easeInOut(duration: 0.2), value: usernameIsTaken)
            } else {
                Text("Din profil är offentlig som standard.")
                    .font(.system(size: 14))
                    .foregroundColor(.gray)
            }
        }
    }
    
    // MARK: - Profile Picture Step
    private var profilePictureStepContent: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Profilbild")
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
                            Text(selectedProfileImage == nil ? "Lägg till foto" : "Byt foto")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.primary)
                            
                            Text("Tryck för att välja från biblioteket")
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
            
            Text("Din profilbild visas för dina vänner på Up&Down.")
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
                TextField("Kod", text: $referralCodeInput)
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
                        Text("Skicka")
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
                    Text("Kod aktiverad!")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.green)
                }
            } else if codeValidationResult == false {
                HStack(spacing: 8) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.red)
                    Text("Koden hittades inte")
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
                            
                            Text("50+ AppStore betyg")
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
                    Text("Up&Down skapades för\nmänniskor som du")
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
                    
                    Text("4k+ Up&Down användare")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.gray)
                }
                .padding(.vertical, 20)
                
                // Reviews
                VStack(spacing: 12) {
                    OnboardingReviewCardSimple(
                        name: "Biffoli1",
                        review: "Laddade ner appen i sommras och sen dess har jag alltid använt den när jag har gymmat. Grymt bra sätt att tracka sina pass samtidigt som man blir belönad för det, riktigt bra har inte sett ngn liknande app innan."
                    )
                    
                    OnboardingReviewCardSimple(
                        name: "Frank Höglund",
                        review: "Jag har använt appen i någon månad nu och tycker verkligen att det har gett mig motivation både att hålla uppe min gym träning men framförallt har det hjälpt mig att tracka mina kalorier eftersom det är så lätt."
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
    private var progressStepContent: some View {
        VStack(spacing: 32) {
            Spacer().frame(height: 20)
            
            // Progress graph card
            VStack(spacing: 20) {
                Text("Din resa")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)
                
                // Graph
                GeometryReader { geometry in
                    let width = geometry.size.width - 40
                    let height: CGFloat = 140
                    
                    ZStack(alignment: .bottomLeading) {
                        // Background gradient
                        LinearGradient(
                            colors: [Color.orange.opacity(0.15), Color.orange.opacity(0.05), Color.clear],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .clipShape(
                            ProgressCurvePath(width: width, height: height, progress: progressLineWidth / width)
                        )
                        .padding(.horizontal, 20)
                        
                        // Progress line
                        Path { path in
                            path.move(to: CGPoint(x: 20, y: height - 20))
                            path.addLine(to: CGPoint(x: 20 + width * 0.2, y: height - 40))
                            path.addLine(to: CGPoint(x: 20 + width * 0.45, y: height - 55))
                            path.addLine(to: CGPoint(x: 20 + width * 0.7, y: height - 80))
                            path.addLine(to: CGPoint(x: 20 + width, y: height - 120))
                        }
                        .trim(from: 0, to: progressLineWidth / width)
                        .stroke(Color.black, style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                        .animation(.easeOut(duration: 1.5), value: progressLineWidth)
                        
                        // Dots on the line
                        if showProgressDots[0] {
                            Circle()
                                .fill(Color.white)
                                .frame(width: 12, height: 12)
                                .overlay(Circle().stroke(Color.black, lineWidth: 2))
                                .position(x: 20, y: height - 20)
                                .transition(.scale.combined(with: .opacity))
                        }
                        
                        if showProgressDots[1] {
                            Circle()
                                .fill(Color.white)
                                .frame(width: 12, height: 12)
                                .overlay(Circle().stroke(Color.black, lineWidth: 2))
                                .position(x: 20 + width * 0.33, y: height - 47)
                                .transition(.scale.combined(with: .opacity))
                        }
                        
                        if showProgressDots[2] {
                            Circle()
                                .fill(Color.white)
                                .frame(width: 12, height: 12)
                                .overlay(Circle().stroke(Color.black, lineWidth: 2))
                                .position(x: 20 + width * 0.66, y: height - 75)
                                .transition(.scale.combined(with: .opacity))
                        }
                        
                        // Trophy at the end
                        if showProgressDots[3] {
                            ZStack {
                                Circle()
                                    .fill(Color.orange)
                                    .frame(width: 36, height: 36)
                                
                                Image(systemName: "trophy.fill")
                                    .font(.system(size: 16))
                                    .foregroundColor(.white)
                            }
                            .position(x: 20 + width, y: height - 120)
                            .transition(.scale.combined(with: .opacity))
                        }
                    }
                    .frame(height: height)
                }
                .frame(height: 140)
                
                // Day labels
                HStack {
                    Text("3 Dagar")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.gray)
                    Spacer()
                    Text("7 Dagar")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.gray)
                    Spacer()
                    Text("30 Dagar")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.gray)
                }
                .padding(.horizontal, 30)
                
                // Description
                Text("Baserat på våra tidigare användare så är det viktigt att man håller igång i ungefär en månad innan resultaten kickar in.")
                    .font(.system(size: 14))
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
                    .opacity(showProgressDots[3] ? 1 : 0)
                    .animation(.easeOut(duration: 0.5), value: showProgressDots[3])
            }
            .padding(.vertical, 24)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(Color(.systemGray6).opacity(0.5))
            )
            .padding(.horizontal, 20)
            
            Spacer()
        }
        .onAppear {
            // Reset animation states
            progressLineWidth = 0
            showProgressDots = [false, false, false, false]
            progressAnimationComplete = false
            
            // Animate the line
            withAnimation(.easeOut(duration: 1.5)) {
                progressLineWidth = UIScreen.main.bounds.width - 80
            }
            
            // Animate dots sequentially
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                    showProgressDots[0] = true
                }
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                    showProgressDots[1] = true
                }
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                    showProgressDots[2] = true
                }
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                    showProgressDots[3] = true
                }
            }
            
            // Enable continue button
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
                withAnimation {
                    progressAnimationComplete = true
                }
            }
        }
    }
    
    private var genderStepContent: some View {
        VStack(spacing: 12) {
            Spacer().frame(height: 40)
            genderButton(title: "Man", value: "male")
            genderButton(title: "Kvinna", value: "female")
            genderButton(title: "Annat", value: "other")
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
            workoutButton(range: "0-2", description: "Tränar då och då", icon: "circle.fill", value: "0-2")
            workoutButton(range: "3-5", description: "Några pass i veckan", icon: "circle.grid.2x1.fill", value: "3-5")
            workoutButton(range: "6+", description: "Dedikerad atlet", icon: "circle.grid.3x3.fill", value: "6+")
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
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(primaryTextColor)
                    .frame(width: 40)
                
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
                    Text("Längd").font(.system(size: 16, weight: .semibold)).foregroundColor(primaryTextColor)
                    Picker("Längd", selection: $data.heightCm) {
                        ForEach(140...220, id: \.self) { cm in
                            Text("\(cm) cm").tag(cm)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(height: 150)
                }
                .frame(maxWidth: .infinity)
                
                VStack(spacing: 8) {
                    Text("Vikt").font(.system(size: 16, weight: .semibold)).foregroundColor(primaryTextColor)
                    Picker("Vikt", selection: Binding(
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
    
    private var goalStepContent: some View {
                VStack(spacing: 12) {
            Spacer().frame(height: 40)
            goalButton(title: "Gå ner i vikt", value: "lose")
            goalButton(title: "Behålla vikt", value: "maintain")
            goalButton(title: "Gå upp i vikt", value: "gain")
        }
    }
    
    private func goalButton(title: String, value: String) -> some View {
                        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                data.goal = value
            }
            hapticFeedback()
                        } label: {
            Text(title)
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(data.goal == value ? selectedCardTextColor : unselectedCardTextColor)
                                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.vertical, 20)
                .background(RoundedRectangle(cornerRadius: 16).fill(data.goal == value ? selectedCardBackgroundColor : cardBackgroundColor))
        }
    }
    
    // MARK: - Results Step (Animated Graph)
    private var resultsStepContent: some View {
        VStack(spacing: 24) {
            Spacer()
            
            // Graph card
            VStack(alignment: .leading, spacing: 16) {
                Text("Din vikt")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(primaryTextColor)
                
                // Graph
                ZStack {
                    // Background grid lines
                    VStack(spacing: 0) {
                        ForEach(0..<3) { _ in
                            Divider()
                                .background(Color.gray.opacity(0.2))
                            Spacer()
                        }
                        Divider()
                            .background(Color.gray.opacity(0.2))
                    }
                    .padding(.vertical, 20)
                    
                    // Traditional diet line (red, goes down then up)
                    GeometryReader { geo in
                        let width = geo.size.width
                        let height = geo.size.height
                        
                        // Red area fill
                        Path { path in
                            path.move(to: CGPoint(x: 0, y: height * 0.15))
                            path.addCurve(
                                to: CGPoint(x: width * 0.45, y: height * 0.55),
                                control1: CGPoint(x: width * 0.15, y: height * 0.15),
                                control2: CGPoint(x: width * 0.35, y: height * 0.55)
                            )
                            path.addCurve(
                                to: CGPoint(x: width, y: height * 0.1),
                                control1: CGPoint(x: width * 0.6, y: height * 0.55),
                                control2: CGPoint(x: width * 0.85, y: height * 0.1)
                            )
                            path.addLine(to: CGPoint(x: width, y: 0))
                            path.addLine(to: CGPoint(x: 0, y: 0))
                            path.closeSubpath()
                        }
                        .fill(Color.red.opacity(showResultsGraph ? 0.1 : 0))
                        .animation(.easeOut(duration: 0.8).delay(0.5), value: showResultsGraph)
                        
                        // Red line
                        Path { path in
                            path.move(to: CGPoint(x: 0, y: height * 0.15))
                            path.addCurve(
                                to: CGPoint(x: width * 0.45, y: height * 0.55),
                                control1: CGPoint(x: width * 0.15, y: height * 0.15),
                                control2: CGPoint(x: width * 0.35, y: height * 0.55)
                            )
                            path.addCurve(
                                to: CGPoint(x: width, y: height * 0.1),
                                control1: CGPoint(x: width * 0.6, y: height * 0.55),
                                control2: CGPoint(x: width * 0.85, y: height * 0.1)
                            )
                        }
                        .trim(from: 0, to: showResultsGraph ? 1 : 0)
                        .stroke(Color.red.opacity(0.7), style: StrokeStyle(lineWidth: 2, lineCap: .round))
                        .animation(.easeOut(duration: 1.0).delay(0.3), value: showResultsGraph)
                        
                        // "Traditionell diet" label
                        Text("Traditionell diet")
                            .font(.system(size: 12))
                            .foregroundColor(.red.opacity(0.8))
                            .offset(x: width * 0.55, y: height * 0.35)
                            .opacity(showResultsGraph ? 1 : 0)
                            .animation(.easeOut(duration: 0.5).delay(1.0), value: showResultsGraph)
                    }
                    
                    // Up&Down line (black, steady decline)
                    GeometryReader { geo in
                        let width = geo.size.width
                        let height = geo.size.height
                        
                        // Gray area fill
                        Path { path in
                            path.move(to: CGPoint(x: 0, y: height * 0.15))
                            path.addCurve(
                                to: CGPoint(x: width * 0.35, y: height * 0.45),
                                control1: CGPoint(x: width * 0.1, y: height * 0.15),
                                control2: CGPoint(x: width * 0.25, y: height * 0.35)
                            )
                            path.addCurve(
                                to: CGPoint(x: width, y: height * 0.75),
                                control1: CGPoint(x: width * 0.5, y: height * 0.6),
                                control2: CGPoint(x: width * 0.75, y: height * 0.75)
                            )
                            path.addLine(to: CGPoint(x: width, y: height))
                            path.addLine(to: CGPoint(x: 0, y: height))
                            path.closeSubpath()
                        }
                        .fill(Color.gray.opacity(showResultsGraph ? 0.15 : 0))
                        .animation(.easeOut(duration: 0.8).delay(0.3), value: showResultsGraph)
                        
                        // Black line
                        Path { path in
                            path.move(to: CGPoint(x: 0, y: height * 0.15))
                            path.addCurve(
                                to: CGPoint(x: width * 0.35, y: height * 0.45),
                                control1: CGPoint(x: width * 0.1, y: height * 0.15),
                                control2: CGPoint(x: width * 0.25, y: height * 0.35)
                            )
                            path.addCurve(
                                to: CGPoint(x: width, y: height * 0.75),
                                control1: CGPoint(x: width * 0.5, y: height * 0.6),
                                control2: CGPoint(x: width * 0.75, y: height * 0.75)
                            )
                        }
                        .trim(from: 0, to: showResultsGraph ? 1 : 0)
                        .stroke(Color.primary, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                        .animation(.easeOut(duration: 1.2).delay(0.1), value: showResultsGraph)
                        
                        // Start circle
                        Circle()
                            .stroke(Color.primary, lineWidth: 2)
                            .fill(Color(.systemBackground))
                            .frame(width: 12, height: 12)
                            .offset(x: -6, y: height * 0.15 - 6)
                            .opacity(showResultsGraph ? 1 : 0)
                            .animation(.easeOut(duration: 0.3), value: showResultsGraph)
                        
                        // End circle
                        Circle()
                            .stroke(Color.primary, lineWidth: 2)
                            .fill(Color(.systemBackground))
                            .frame(width: 12, height: 12)
                            .offset(x: width - 6, y: height * 0.75 - 6)
                            .opacity(showResultsGraph ? 1 : 0)
                            .animation(.easeOut(duration: 0.3).delay(1.2), value: showResultsGraph)
                    }
                    
                    // Up&Down label
                    HStack(spacing: 6) {
                        Image("23")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 16, height: 16)
                            .cornerRadius(3)
                        Text("Up&Down")
                            .font(.system(size: 12, weight: .semibold))
                        
                        Text("Vikt")
                            .font(.system(size: 10))
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.primary)
                            .cornerRadius(10)
                    }
                    .offset(x: -60, y: 55)
                    .opacity(showResultsGraph ? 1 : 0)
                    .animation(.easeOut(duration: 0.5).delay(0.8), value: showResultsGraph)
                }
                .frame(height: 160)
                .padding(.horizontal, 8)
                
                // X-axis labels
                HStack {
                    Text("Månad 1")
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                    Spacer()
                    Text("Månad 6")
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                }
                .padding(.horizontal, 8)
                .opacity(showResultsGraph ? 1 : 0)
                .animation(.easeOut(duration: 0.5).delay(0.6), value: showResultsGraph)
                
                // Bottom text
                Text("80% av Up&Down-användare behåller sin viktnedgång även 6 månader senare")
                    .font(.system(size: 14))
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .padding(.top, 8)
                    .opacity(showResultsGraph ? 1 : 0)
                    .animation(.easeOut(duration: 0.5).delay(1.0), value: showResultsGraph)
            }
            .padding(20)
            .background(Color(.systemBackground))
            .cornerRadius(20)
            .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 5)
            
            Spacer()
        }
        .onAppear {
            // Reset and animate
            showResultsGraph = false
            resultsAnimationComplete = false
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                showResultsGraph = true
            }
            
            // Enable continue button after animation completes
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                withAnimation(.easeOut(duration: 0.3)) {
                    resultsAnimationComplete = true
                }
            }
        }
    }
    
    private var targetWeightStepContent: some View {
        VStack(spacing: 24) {
            Spacer().frame(height: 20)
            
            Text(data.goal == "lose" ? "Gå ner i vikt" : data.goal == "gain" ? "Gå upp i vikt" : "Behåll vikt")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.gray)
            
            HStack {
                Text("Nuvarande vikt:").font(.system(size: 14)).foregroundColor(.gray)
                Text("\(Int(data.weightKg)) kg").font(.system(size: 14, weight: .semibold)).foregroundColor(primaryTextColor)
            }
            
            Picker("Målvikt", selection: Binding(
                get: { Int(data.targetWeightKg) },
                set: { data.targetWeightKg = Double($0) }
            )) {
                ForEach(40...150, id: \.self) { kg in
                    Text("\(kg) kg").tag(kg)
                }
            }
            .pickerStyle(.wheel)
            .frame(height: 150)
            
            let diff = Int(data.targetWeightKg) - Int(data.weightKg)
            if diff != 0 {
                HStack(spacing: 8) {
                    Image(systemName: diff < 0 ? "arrow.down.circle.fill" : "arrow.up.circle.fill")
                        .foregroundColor(diff < 0 ? .green : .orange)
                    Text("\(abs(diff)) kg \(diff < 0 ? "att gå ner" : "att gå upp")")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(primaryTextColor)
                }
                .padding(.horizontal, 20)
                                .padding(.vertical, 12)
                .background(cardBackgroundColor)
                .cornerRadius(12)
                        }
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
                    // Without Up&Down
                    VStack(spacing: 12) {
                        Text("Utan")
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
                    
                    // With Up&Down
                    VStack(spacing: 12) {
                        Text("Med")
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
                
                // Description text
                Text("Genom att dela med vänner, få belöningar, se statistik & tracka dina pass håller våra användare igång längre jämfört med innan de började träna med Up&Down.")
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
    
    private var appleHealthStepContent: some View {
                VStack(spacing: 20) {
                    Image("30")
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: 260)
                        .shadow(color: Color.black.opacity(0.1), radius: 20, x: 0, y: 12)
                        .padding(.top, 8)

            Text(data.healthAuthorized
                             ? "Apple Health är aktiverat. Du kan gå vidare."
                 : "Tryck på Fortsätt för att aktivera Apple Health.")
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
            
                    Text("Få påminnelser om pass och nya belöningar.")
                .font(.system(size: 16))
                .foregroundColor(secondaryTextColor)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
            
            Text(data.notificationsAuthorized
                 ? "Notiser är aktiverade – tryck Fortsätt."
                 : "Tryck på Fortsätt för att aktivera notiser.")
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
    
    // MARK: - Calculating View
    private var calculatingView: some View {
        VStack(spacing: 24) {
            Spacer()
            
            Text("\(Int(calculationProgress))%")
                .font(.system(size: 64, weight: .bold))
                .foregroundColor(primaryTextColor)
                .contentTransition(.numericText())
                .animation(.easeOut(duration: 0.1), value: calculationProgress)
            
            Text("Vi skapar allt\nåt dig")
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(primaryTextColor)
                .multilineTextAlignment(.center)
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle().fill(Color(.systemGray5)).frame(height: 8).cornerRadius(4)
                    Rectangle()
                        .fill(LinearGradient(colors: [Color.red, Color.blue], startPoint: .leading, endPoint: .trailing))
                        .frame(width: geometry.size.width * CGFloat(calculationProgress / 100), height: 8)
                        .cornerRadius(4)
                }
            }
            .frame(height: 8)
            .padding(.horizontal, 40)
            
            Text(calculationStep)
                .font(.system(size: 16))
                .foregroundColor(.gray)
            
            Spacer()
            
            VStack(alignment: .leading, spacing: 12) {
                Text("Daglig rekommendation för")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(primaryTextColor)
                
                checklistItem(text: "Kalorier", isChecked: calculationProgress >= 20)
                checklistItem(text: "Kolhydrater", isChecked: calculationProgress >= 40)
                checklistItem(text: "Protein", isChecked: calculationProgress >= 60)
                checklistItem(text: "Fett", isChecked: calculationProgress >= 80)
                checklistItem(text: "Hälsopoäng", isChecked: calculationProgress >= 100)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 60)
        }
    }
    
    @ViewBuilder
    private func checklistItem(text: String, isChecked: Bool) -> some View {
        HStack(spacing: 12) {
            Text("•").foregroundColor(primaryTextColor)
            Text(text).font(.system(size: 15)).foregroundColor(primaryTextColor)
            Spacer()
            if isChecked {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(primaryTextColor)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isChecked)
    }
    
    // MARK: - Results View
    private var resultsView: some View {
        ScrollView {
            VStack(spacing: 24) {
                VStack(spacing: 16) {
                    HStack {
                        Spacer()
                        GeometryReader { geometry in
                            Rectangle().fill(buttonBackgroundColor).frame(height: 4).cornerRadius(2)
                        }
                        .frame(height: 4)
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 50))
                        .foregroundColor(primaryTextColor)
                    
                    Text("Grattis")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(primaryTextColor)
                    
                    Text("din personliga plan är klar!")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(primaryTextColor)
                }
                
                VStack(spacing: 12) {
                    Text("Du bör:")
                        .font(.system(size: 16))
                        .foregroundColor(.gray)
                    
                    Text(goalPredictionText)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(primaryTextColor)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(cardBackgroundColor)
                        .cornerRadius(20)
                }
                
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Daglig rekommendation")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(primaryTextColor)
                        Text("Du kan ändra detta när som helst")
                            .font(.system(size: 14))
                            .foregroundColor(.gray)
                    }
                    .padding(.horizontal, 24)
                    
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                        MacroResultCard(emoji: "🔥", title: "Kalorier", value: $data.dailyCalories, unit: "", progress: 0.75)
                        MacroResultCard(emoji: "🌾", title: "Kolhydrater", value: $data.dailyCarbs, unit: "g", progress: 0.65)
                        MacroResultCard(emoji: "🍗", title: "Protein", value: $data.dailyProtein, unit: "g", progress: 0.70)
                        MacroResultCard(emoji: "🥑", title: "Fett", value: $data.dailyFat, unit: "g", progress: 0.55)
                    }
                    .padding(.horizontal, 24)
                }
                
                Spacer().frame(height: 20)
                
                Button {
                    completeOnboarding()
                } label: {
                    Text("Kom igång!")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(buttonTextColor)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(buttonBackgroundColor)
                        .clipShape(Capsule())
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            }
        }
    }
    
    private var goalPredictionText: String {
        let weightDiff = abs(data.targetWeightKg - data.weightKg)
        let weeks = Int(weightDiff / 0.5)
        let targetDate = Calendar.current.date(byAdding: .weekOfYear, value: max(weeks, 1), to: Date()) ?? Date()
        
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "sv_SE")
        dateFormatter.dateFormat = "d MMMM"
        
        let action = data.goal == "lose" ? "Gå ner" : data.goal == "gain" ? "Gå upp" : "Behåll"
        return "\(action) \(Int(weightDiff)) kg till \(dateFormatter.string(from: targetDate))"
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
        case .progress: return progressAnimationComplete
        case .gender: return !data.gender.isEmpty
        case .workouts: return !data.workoutsPerWeek.isEmpty
        case .heightWeight: return true
        case .birthday: return true
        case .goal: return !data.goal.isEmpty
        case .results: return resultsAnimationComplete
        case .targetWeight: return true
        case .motivation: return motivationAnimationComplete
        case .appleHealth: return true
        case .notifications: return true
        }
    }
    
    private func continueButtonText(for step: OnboardingStep) -> String {
        switch step {
        case .referralCode:
            return "Hoppa över"
        default:
            return "Fortsätt"
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
                        healthRequestStatus = authorized ? "Apple Health aktiverad" : nil
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
                        notificationsStatus = granted ? "Notiser aktiverade" : "Notiser nekades"
                        startCalculation()
                    }
                }
            } else {
                startCalculation()
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
    
    private func startCalculation() {
        withAnimation {
            onboardingStep = nil
            isCalculating = true
        }
        
        let steps = [
            "Beräknar BMR...",
            "Tillämpar aktivitetsnivå...",
            "Optimerar makrofördelning...",
            "Anpassar efter mål...",
            "Färdigställer plan..."
        ]
        
        var currentStepIndex = 0
        calculationStep = steps[0]
        
        Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [self] timer in
            if self.calculationProgress < 100 {
                DispatchQueue.main.async {
                    self.calculationProgress += 1
                    let newIndex = min(Int(self.calculationProgress / 20), steps.count - 1)
                    if newIndex != currentStepIndex {
                        withAnimation {
                            self.calculationStep = steps[newIndex]
                        }
                    }
                }
            } else {
                timer.invalidate()
                DispatchQueue.main.async {
                    self.calculateNutritionPlan()
                }
            }
        }
    }
    
    private func calculateNutritionPlan() {
        let bmr: Double
        let weight = data.weightKg
        let height = Double(data.heightCm)
        let age = Double(data.age)
        
        print("📊 calculateNutritionPlan() called")
        print("   Input - Weight: \(weight), Height: \(height), Age: \(age), Gender: \(data.gender)")
        
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
        
        print("   Calculated - Calories: \(calories), Protein: \(protein), Carbs: \(carbs), Fat: \(fat)")
        
        // Update data on main thread to ensure SwiftUI observes the changes
        DispatchQueue.main.async {
            self.data.dailyCalories = calories
            self.data.dailyProtein = protein
            self.data.dailyCarbs = max(carbs, 50)
            self.data.dailyFat = fat
            
            print("   Updated data - dailyCalories: \(self.data.dailyCalories)")
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                    self.isCalculating = false
                    self.showResults = true
                }
            }
        }
    }
    
    private func createAccountAndStartOnboarding() {
        let trimmedEmail = signupEmail.trimmingCharacters(in: .whitespacesAndNewlines)
        
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
                
                await RevenueCatManager.shared.logInFor(appUserId: userId)
                
                await MainActor.run {
                    authViewModel.currentUser = newUser
                    authViewModel.isLoading = false
                    showSignupForm = false
                    onboardingStep = onboardingSteps.first
                }
            } catch {
                await MainActor.run {
                    authViewModel.errorMessage = "Kunde inte skapa konto: \(error.localizedDescription)"
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
                
                // Ensure nutrition values are calculated
                if data.dailyCalories == 0 {
                    print("⚠️ Calories is 0, recalculating...")
                    calculateNutritionPlan()
                    print("   Recalculated - Calories: \(data.dailyCalories)")
                }
                
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
                        workouts_per_week: data.workoutsPerWeek
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
                
                // Set current user for AI scan limit manager
                await MainActor.run {
                    AIScanLimitManager.shared.setCurrentUser(userId: userId)
                    
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

// MARK: - Progress Curve Path (for gradient fill)
struct ProgressCurvePath: Shape {
    let width: CGFloat
    let height: CGFloat
    let progress: CGFloat
    
    var animatableData: CGFloat {
        get { progress }
        set { }
    }
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        let clampedProgress = min(max(progress, 0), 1)
        
        // Start at bottom left
        path.move(to: CGPoint(x: 0, y: height))
        
        // Draw the curve up to the current progress point
        path.addLine(to: CGPoint(x: 0, y: height - 20))
        path.addLine(to: CGPoint(x: width * 0.2 * clampedProgress, y: height - 20 - (20 * min(clampedProgress / 0.2, 1))))
        
        if clampedProgress > 0.2 {
            let segmentProgress = min((clampedProgress - 0.2) / 0.25, 1)
            path.addLine(to: CGPoint(x: width * 0.2 + width * 0.25 * segmentProgress, y: height - 40 - (15 * segmentProgress)))
        }
        
        if clampedProgress > 0.45 {
            let segmentProgress = min((clampedProgress - 0.45) / 0.25, 1)
            path.addLine(to: CGPoint(x: width * 0.45 + width * 0.25 * segmentProgress, y: height - 55 - (25 * segmentProgress)))
        }
        
        if clampedProgress > 0.7 {
            let segmentProgress = min((clampedProgress - 0.7) / 0.3, 1)
            path.addLine(to: CGPoint(x: width * 0.7 + width * 0.3 * segmentProgress, y: height - 80 - (40 * segmentProgress)))
        }
        
        // Close the path back to bottom
        path.addLine(to: CGPoint(x: width * clampedProgress, y: height))
        path.closeSubpath()
        
        return path
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
                Text("E-post").font(.system(size: 14, weight: .medium)).foregroundColor(.black)
                TextField("E-post", text: $email)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)
                    .padding(14)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Lösenord").font(.system(size: 14, weight: .medium)).foregroundColor(.black)
                ZStack(alignment: .trailing) {
                    if isPasswordVisible {
                        TextField("Lösenord", text: $password).textContentType(.password).padding(14).background(Color(.systemGray6)).cornerRadius(8)
                    } else {
                        SecureField("Lösenord", text: $password).textContentType(.password).padding(14).background(Color(.systemGray6)).cornerRadius(8)
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
                Text("Glömt lösenord?").font(.system(size: 14, weight: .medium)).foregroundColor(.black.opacity(0.7)).underline()
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
                        Text("Logga in").font(.system(size: 17, weight: .semibold)).foregroundColor(email.isEmpty || password.isEmpty ? .black.opacity(0.4) : .black)
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
                    Text("Återställ lösenord").font(.system(size: 24, weight: .bold))
                    Text("Ange din e-postadress så skickar vi instruktioner för att återställa ditt lösenord.")
                        .font(.system(size: 15)).foregroundColor(.gray).multilineTextAlignment(.center).padding(.horizontal)
                }
                .padding(.top, 20)
                
                TextField("E-postadress", text: $email)
                    .textContentType(.emailAddress).keyboardType(.emailAddress).autocapitalization(.none)
                    .padding(14).background(Color(.systemGray6)).cornerRadius(12).padding(.horizontal, 24)
                
                if !message.isEmpty {
                    Text(message).font(.system(size: 14)).foregroundColor(success ? .black : .red).multilineTextAlignment(.center).padding(.horizontal, 24)
                }
                
                if success {
                    Button { onDismiss() } label: {
                        Text("Stäng").font(.system(size: 16, weight: .semibold)).foregroundColor(.white).frame(maxWidth: .infinity).padding(14).background(Color.black).cornerRadius(12)
                    }
                    .padding(.horizontal, 24)
                } else {
                    Button { onReset() } label: {
                        if isLoading { ProgressView().tint(.white) } else { Text("Skicka återställningslänk").font(.system(size: 16, weight: .semibold)) }
                    }
                    .foregroundColor(.white).frame(maxWidth: .infinity).padding(14).background(email.isEmpty ? Color.gray : Color.black).cornerRadius(12).disabled(email.isEmpty || isLoading).padding(.horizontal, 24)
                }
                
                Spacer()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Avbryt") { onDismiss() }.foregroundColor(.primary)
                }
            }
        }
    }
}

// MARK: - Macro Result Card (Editable)
struct MacroResultCard: View {
    let emoji: String
    let title: String
    @Binding var value: Int
    let unit: String
    let progress: Double
    
    @Environment(\.colorScheme) private var colorScheme
    @State private var isEditing = false
    @State private var editValue: String = ""
    
    private var isDarkMode: Bool { colorScheme == .dark }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(emoji).font(.system(size: 14)).grayscale(1)
                Text(title).font(.system(size: 14)).foregroundColor(.gray)
                Spacer()
            }
            
            HStack(alignment: .bottom, spacing: 0) {
                ZStack {
                    Circle().stroke(Color(.systemGray5), lineWidth: 6).frame(width: 60, height: 60)
                    Circle().trim(from: 0, to: progress).stroke(Color.black, style: StrokeStyle(lineWidth: 6, lineCap: .round)).frame(width: 60, height: 60).rotationEffect(.degrees(-90))
                    VStack(spacing: 0) {
                        Text("\(value)").font(.system(size: 18, weight: .bold)).foregroundColor(isDarkMode ? .white : .black)
                        if !unit.isEmpty { Text(unit).font(.system(size: 10)).foregroundColor(.gray) }
                    }
                }
                Spacer()
                Button {
                    editValue = "\(value)"
                    isEditing = true
                } label: {
                    Image(systemName: "pencil").font(.system(size: 14)).foregroundColor(.gray)
                }
            }
        }
        .padding(16)
        .background(isDarkMode ? Color(.systemGray6) : Color.white)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(isDarkMode ? 0 : 0.06), radius: 8, x: 0, y: 2)
        .alert("Ändra \(title.lowercased())", isPresented: $isEditing) {
            TextField("Värde", text: $editValue)
                .keyboardType(.numberPad)
            Button("Avbryt", role: .cancel) { }
            Button("Spara") {
                if let newValue = Int(editValue), newValue > 0 {
                    value = newValue
                    let generator = UIImpactFeedbackGenerator(style: .light)
                    generator.impactOccurred()
                }
            }
        } message: {
            Text("Ange nytt värde för \(title.lowercased())\(unit.isEmpty ? "" : " (\(unit))")")
        }
    }
}

#Preview {
    AuthenticationView()
        .environmentObject(AuthViewModel())
}
