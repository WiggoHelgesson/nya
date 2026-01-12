import SwiftUI
import CoreLocation
import PhotosUI
import Supabase
import UIKit
import Combine

private enum OnboardingStep: Int, CaseIterable, Identifiable {
    case name
    case sports
    case fitnessLevel
    case goals
    case location
    case appleHealth
    case notifications
    
    var id: Int { rawValue }
    
    var title: String {
        switch self {
        case .name: return "Vad heter du?"
        case .sports: return "Vilka aktiviteter gillar du?"
        case .fitnessLevel: return "Var är du i din träningsresa?"
        case .goals: return "Vad planerar du använda Up&Down för?"
        case .location: return "Aktivera platsinfo"
        case .appleHealth: return "Aktivera Apple Health"
        case .notifications: return "Aktivera notiser"
        }
    }
    
    var subtitle: String {
        switch self {
        case .name: return "Så här kan dina vänner hitta dig på Up&Down."
        case .sports: return "Välj de sporter du vill fokusera på."
        case .fitnessLevel: return "Alla nivåer är välkomna, från nybörjare till proffs."
        case .goals: return "Välj så många som passar."
        case .location: return "Aktivera 'Tillåt alltid' för att spåra dina pass korrekt även i bakgrunden."
        case .appleHealth: return "Appen behöver hälsodata för att logga dina pass."
        case .notifications: return "Så vi kan påminna dig om mål och belöningar."
        }
    }
    
    var allowsSkip: Bool {
        return false
    }
}

// Sports options
private struct SportOption: Identifiable {
    let id = UUID()
    let name: String
    let icon: String
}

private let availableSports: [SportOption] = [
    SportOption(name: "Gym", icon: "dumbbell.fill"),
    SportOption(name: "Löpning", icon: "figure.run"),
    SportOption(name: "Golf", icon: "figure.golf"),
    SportOption(name: "Skidåkning", icon: "figure.skiing.downhill")
]

// Fitness levels
private struct FitnessLevel: Identifiable {
    let id = UUID()
    let title: String
    let description: String
}

private let fitnessLevels: [FitnessLevel] = [
    FitnessLevel(title: "Nybörjare", description: "Jag är ny inom träning eller börjar om."),
    FitnessLevel(title: "Medel", description: "Jag tränar regelbundet med lätta-medelsvåra pass."),
    FitnessLevel(title: "Avancerad", description: "Jag gillar att utmana mig med tuffa pass."),
    FitnessLevel(title: "Proffs", description: "Jag är en professionell idrottare.")
]

// Goals
private struct GoalOption: Identifiable {
    let id = UUID()
    let title: String
}

private let goalOptions: [GoalOption] = [
    GoalOption(title: "Bygga en träningsvana"),
    GoalOption(title: "Förbättra min hälsa"),
    GoalOption(title: "Träna mot ett mål eller event"),
    GoalOption(title: "Utforska nya platser"),
    GoalOption(title: "Tävla med andra"),
    GoalOption(title: "Få kontakt med andra aktiva")
]

struct AuthenticationView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var locationAuthStatus: CLAuthorizationStatus = LocationManager.shared.authorizationStatus
    @State private var showLanding = true
    @State private var currentHeroIndex = 0
    @State private var onboardingStep: OnboardingStep? = nil
    @State private var showSignupForm = false
    @State private var onboardingData = OnboardingData()
    @State private var locationStatusMessage: String?
    @State private var healthRequestStatus: String?
    @State private var notificationsStatus: String?
    @State private var profileImage: UIImage?
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var isCheckingUsername = false
    @State private var isUsernameAvailable = false
    @State private var lastCheckedUsername = ""
    @State private var usernameCheckTask: Task<Void, Never>?
    
    @State private var signupName: String = ""
    @State private var signupEmail: String = ""
    @State private var signupPassword: String = ""
    @State private var signupConfirmPassword: String = ""
    
    // New onboarding state
    @State private var firstName: String = ""
    @State private var lastName: String = ""
    @State private var selectedSports: Set<String> = []
    @State private var selectedFitnessLevel: String = ""
    @State private var selectedGoals: Set<String> = []
    
    private let heroImages = ["61", "63", "62"]
    private let onboardingSteps = OnboardingStep.allCases
    
    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()
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
        .onAppear {
            showLanding = true
            onboardingStep = nil
            currentHeroIndex = 0
            authViewModel.errorMessage = ""
            locationStatusMessage = nil
            healthRequestStatus = nil
            notificationsStatus = nil
            
            let healthAuthorized = HealthKitManager.shared.isHealthDataAuthorized()
            onboardingData.healthAuthorized = healthAuthorized
            onboardingData.appleHealthAuthorized = healthAuthorized
            healthRequestStatus = healthAuthorized ? "Apple Health aktiverad" : nil
            
             if let imageData = onboardingData.profileImageData {
                 profileImage = UIImage(data: imageData)
             } else {
                 profileImage = nil
             }
            
            updateLocationAuthorizationState(locationAuthStatus)
            scheduleUsernameAvailabilityCheck(for: onboardingData.username)
            
            // Set up Apple Sign In callback
            authViewModel.onAppleSignInComplete = { success, onboardingDataFromApple in
                if success {
                    if onboardingDataFromApple != nil {
                        // New user from Apple Sign In - start onboarding
                        showLanding = false
                        showSignupForm = false
                        onboardingStep = onboardingSteps.first
                        print("✅ Apple Sign In complete for NEW user, starting onboarding")
                    } else {
                        // Existing user from Apple Sign In - already logged in
                        print("✅ Apple Sign In complete for EXISTING user")
                    }
                }
            }
        }
        .onChange(of: locationAuthStatus) { status in
            updateLocationAuthorizationState(status)
        }
        .onReceive(LocationManager.shared.$authorizationStatus) { newStatus in
            locationAuthStatus = newStatus
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            let authorized = HealthKitManager.shared.isHealthDataAuthorized()
            onboardingData.healthAuthorized = authorized
            onboardingData.appleHealthAuthorized = authorized
            healthRequestStatus = authorized ? "Apple Health aktiverad" : nil
        }
        .onChange(of: onboardingData.username) { newValue in
            scheduleUsernameAvailabilityCheck(for: newValue)
        }
        .onDisappear {
            usernameCheckTask?.cancel()
        }
        .onChange(of: selectedPhotoItem) { newItem in
            guard let newItem else { return }
            Task {
                if let data = try? await newItem.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    let compressed = image.jpegData(compressionQuality: 0.85) ?? image.pngData()
                    await MainActor.run {
                        profileImage = image
                        onboardingData.profileImageData = compressed
                    }
                }
            }
        }
    }
    
    // MARK: - Landing (Strava Style)
    private var landingView: some View {
        let autoSwipeTimer = Timer.publish(every: 4, on: .main, in: .common).autoconnect()
        
        return VStack(spacing: 0) {
            // Swipeable hero images - fills to top
            TabView(selection: $currentHeroIndex) {
                ForEach(0..<heroImages.count, id: \.self) { index in
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
            .animation(.spring(response: 0.6, dampingFraction: 0.8, blendDuration: 0.3), value: currentHeroIndex)
            .onReceive(autoSwipeTimer) { _ in
                withAnimation(.spring(response: 0.6, dampingFraction: 0.8, blendDuration: 0.3)) {
                    currentHeroIndex = (currentHeroIndex + 1) % heroImages.count
                }
            }
            
            // Bottom section: dots right above buttons
            VStack(spacing: 24) {
                // Page indicator dots
                HStack(spacing: 8) {
                    ForEach(0..<heroImages.count, id: \.self) { index in
                        Circle()
                            .fill(index == currentHeroIndex ? Color.black : Color.black.opacity(0.25))
                            .frame(width: 8, height: 8)
                            .scaleEffect(index == currentHeroIndex ? 1.2 : 1.0)
                            .animation(.spring(response: 0.4, dampingFraction: 0.7), value: currentHeroIndex)
                    }
                }
                
                // Buttons
                VStack(spacing: 14) {
                    // Create account button
                    Button {
                        showLanding = false
                        showSignupForm = true
                    } label: {
                        Text("Skapa konto helt gratis")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.black)
                            .clipShape(Capsule())
                    }
                    .padding(.horizontal, 24)
                    
                    // Login button
                    Button {
                        showLanding = false
                        showSignupForm = false
                    } label: {
                        Text("Logga in")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.black)
                    }
                }
            }
            .padding(.vertical, 24)
            .background(Color.white)
        }
    }
    
    // MARK: - Form (Login Page - Strava Style)
    private var formView: some View {
        VStack(spacing: 0) {
            // Close button
            HStack {
                Spacer()
                Button {
                    showLanding = true
                    onboardingStep = nil
                    authViewModel.errorMessage = ""
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.black.opacity(0.6))
                        .frame(width: 36, height: 36)
                        .background(Color(.systemGray5))
                        .clipShape(Circle())
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    // Title
                    Text("Logga in på Up&Down")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.black)
                        .padding(.top, 8)
                    
                    // Email Login Section
                    LoginFormView()
                        .environmentObject(authViewModel)
                    
                    // Divider with "or"
                    HStack {
                        Rectangle()
                            .fill(Color(.systemGray4))
                            .frame(height: 1)
                        Text("eller")
                            .font(.system(size: 14))
                            .foregroundColor(.gray)
                            .padding(.horizontal, 16)
                        Rectangle()
                            .fill(Color(.systemGray4))
                            .frame(height: 1)
                    }
                    
                    // Apple Sign In Button
                    Button {
                        authViewModel.signInWithApple()
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "apple.logo")
                                .font(.system(size: 20, weight: .medium))
                                .foregroundColor(.black)
                            
                            Text("Fortsätt med Apple")
                                .font(.system(size: 17, weight: .medium))
                                .foregroundColor(.black)
                            
                            Spacer()
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 30)
                                .stroke(Color(.systemGray3), lineWidth: 1.5)
                        )
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(PlainButtonStyle())
                    .disabled(authViewModel.isLoading)
                    
                    // Terms text
                    Text("Genom att fortsätta godkänner du våra [användarvillkor](https://wiggio.se/privacy) och [integritetspolicy](https://wiggio.se/privacy).")
                        .font(.system(size: 13))
                        .foregroundColor(.gray)
                        .tint(.black)
                        .padding(.top, 8)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            }
        }
    }
    
    // MARK: - Onboarding Steps (Strava Style)
    private func onboardingView(for step: OnboardingStep) -> some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Title
                    Text(step.title)
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(.black)
                        .padding(.top, 60)
                    
                    // Subtitle
                    Text(step.subtitle)
                        .font(.system(size: 16))
                        .foregroundColor(.gray)
                        .padding(.bottom, 8)
                    
                    // Content
                    onboardingContent(for: step)
                }
                .padding(.horizontal, 24)
            }
            
            // Bottom button
            VStack(spacing: 0) {
                Button(action: { continueFromStep(step) }) {
                    Text("Fortsätt")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(canContinue(step) ? .white : .gray)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(canContinue(step) ? Color.black : Color(.systemGray5))
                        .clipShape(Capsule())
                }
                .disabled(!canContinue(step))
                .padding(.horizontal, 24)
                .padding(.vertical, 16)
            }
            .background(Color.white)
        }
    }
    
    private func onboardingContent(for step: OnboardingStep) -> some View {
        Group {
            switch step {
            case .name:
                // Name input (Strava style)
                VStack(alignment: .leading, spacing: 20) {
                    // First name
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Förnamn")
                            .font(.system(size: 15))
                            .foregroundColor(.black)
                        
                        TextField("", text: $firstName)
                            .textInputAutocapitalization(.words)
                            .padding(16)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color(.systemGray3), lineWidth: 1)
                            )
                    }
                    
                    // Last name
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Efternamn")
                            .font(.system(size: 15))
                            .foregroundColor(.black)
                        
                        TextField("", text: $lastName)
                            .textInputAutocapitalization(.words)
                            .padding(16)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color(.systemGray3), lineWidth: 1)
                            )
                    }
                    
                    Text("Din profil är offentlig som standard.")
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                }
                
            case .sports:
                // Sports selection (2x2 grid)
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    ForEach(availableSports) { sport in
                        Button {
                            if selectedSports.contains(sport.name) {
                                selectedSports.remove(sport.name)
                            } else {
                                selectedSports.insert(sport.name)
                            }
                        } label: {
                            VStack(alignment: .leading, spacing: 16) {
                                Image(systemName: sport.icon)
                                    .font(.system(size: 28))
                                    .foregroundColor(.black)
                                
                                Text(sport.name)
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.black)
                            }
                            .frame(maxWidth: .infinity, minHeight: 100, alignment: .leading)
                            .padding(20)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(selectedSports.contains(sport.name) ? Color.black.opacity(0.1) : Color(.systemGray6))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(selectedSports.contains(sport.name) ? Color.black : Color.clear, lineWidth: 2)
                                    )
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                
            case .fitnessLevel:
                // Fitness level selection
                VStack(spacing: 12) {
                    ForEach(fitnessLevels) { level in
                        Button {
                            selectedFitnessLevel = level.title
                        } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(level.title)
                                    .font(.system(size: 17, weight: .semibold))
                                    .foregroundColor(.black)
                                
                                Text(level.description)
                                    .font(.system(size: 14))
                                    .foregroundColor(.gray)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(18)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(selectedFitnessLevel == level.title ? Color.black.opacity(0.1) : Color(.systemGray6))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(selectedFitnessLevel == level.title ? Color.black : Color.clear, lineWidth: 2)
                                    )
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                
            case .goals:
                // Goals selection (multiple choice)
                VStack(spacing: 12) {
                    ForEach(goalOptions) { goal in
                        Button {
                            if selectedGoals.contains(goal.title) {
                                selectedGoals.remove(goal.title)
                            } else {
                                selectedGoals.insert(goal.title)
                            }
                        } label: {
                            Text(goal.title)
                                .font(.system(size: 17, weight: .medium))
                                .foregroundColor(.black)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(18)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(selectedGoals.contains(goal.title) ? Color.black.opacity(0.1) : Color(.systemGray6))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(selectedGoals.contains(goal.title) ? Color.black : Color.clear, lineWidth: 2)
                                        )
                                )
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                
            case .location:
                VStack(spacing: 18) {
                    Image(systemName: "location.circle.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 120, height: 120)
                        .foregroundColor(Color.black)
                        .shadow(color: Color.black.opacity(0.12), radius: 18, x: 0, y: 12)
                        .padding(.top, 8)
                    
                    Text("Aktivera \"Tillåt alltid\" för att vi ska kunna registrera dina pass även i bakgrunden.")
                        .font(.system(size: 15, weight: .medium))
                        .multilineTextAlignment(.center)
                        .foregroundColor(.black.opacity(0.7))
                        .padding(.horizontal, 12)
                    
                    if let status = locationStatusMessage {
                        Text(status)
                            .font(.system(size: 14, weight: .medium))
                            .multilineTextAlignment(.center)
                            .foregroundColor(onboardingData.locationAuthorized ? .green : .red)
                            .padding(.horizontal, 12)
                    }
                    
                    if locationAuthStatus == .authorizedWhenInUse {
                        Button {
                            LocationManager.shared.requestBackgroundLocationPermission()
                        } label: {
                            Text("Begär 'Tillåt alltid' igen")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Color.black)
                                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        }
                        .padding(.horizontal, 12)
                    }
                    
                    if locationAuthStatus == .denied || locationAuthStatus == .authorizedWhenInUse {
                        Button {
                            LocationManager.shared.openSettings()
                        } label: {
                            Text("Öppna inställningar")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(.primary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Color.black.opacity(0.08))
                                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        }
                        .padding(.top, 8)
                    }
                }
            case .appleHealth:
                VStack(spacing: 20) {
                    Image("30")
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: 260)
                        .shadow(color: Color.black.opacity(0.1), radius: 20, x: 0, y: 12)
                        .padding(.top, 8)

                    VStack(spacing: 12) {
                        Text(onboardingData.healthAuthorized
                             ? "Apple Health är aktiverat. Du kan gå vidare."
                             : "Tryck på Aktivera och godkänn båda Apple Health-dialogerna.")
                            .multilineTextAlignment(.center)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.black.opacity(0.65))
                            .padding(.horizontal, 12)
                            .frame(maxWidth: .infinity, alignment: .center)
                        
                        if let status = healthRequestStatus {
                            Text(status)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.green)
                                .frame(maxWidth: .infinity, alignment: .center)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
            case .notifications:
                VStack(alignment: .leading, spacing: 20) {
                    Text("Få påminnelser om pass och nya belöningar.")
                        .font(.system(size: 14))
                        .foregroundColor(.black.opacity(0.6))
                    
                    Text(onboardingData.notificationsAuthorized
                         ? "Notiser är aktiverade – tryck Klart för att fortsätta."
                         : "Tryck på Aktivera för att visa systemdialogen och godkänn notiser.")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.black.opacity(0.7))
                        .padding(.horizontal, 12)
                        .multilineTextAlignment(.leading)
                    
                    if let status = notificationsStatus {
                        Text(status)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(onboardingData.notificationsAuthorized ? .green : .red)
                    }
                }
            }
        }
    }
    
    private func pbField(title: String, binding: Binding<String>) -> some View {
        TextField(title, text: binding)
            .keyboardType(.numberPad)
            .padding(12)
                .background(Color(.systemGray6))
                .cornerRadius(16)
    }
    
    private var currentOnboardingIndex: Int {
        guard let step = onboardingStep, let index = onboardingSteps.firstIndex(of: step) else { return onboardingSteps.count }
        return index
    }
    
    private func primaryButtonTitle(for step: OnboardingStep) -> String {
        switch step {
        case .location:
            return onboardingData.locationAuthorized ? "Fortsätt" : "Aktivera"
        case .appleHealth:
            return "Fortsätt"
        case .notifications:
            return onboardingData.notificationsAuthorized ? "Klart" : "Aktivera"
        default:
            return "Fortsätt"
        }
    }
    
    private func requestHealthAuthorization() {
        HealthKitManager.shared.requestAuthorization { _ in
            DispatchQueue.main.async {
                let authorized = HealthKitManager.shared.isHealthDataAuthorized()
                onboardingData.healthAuthorized = authorized
                onboardingData.appleHealthAuthorized = authorized
                healthRequestStatus = authorized ? "Apple Health aktiverad" : nil
            }
        }
    }
    
    private func updateLocationAuthorizationState(_ status: CLAuthorizationStatus) {
        onboardingData.locationAuthorized = (status == .authorizedAlways)
        
        switch status {
        case .authorizedAlways:
            locationStatusMessage = "Platsinfo aktiverad. Du kan fortsätta."
        case .authorizedWhenInUse:
            locationStatusMessage = "Välj 'Tillåt alltid' i nästa dialog eller i Inställningar."
        case .denied, .restricted:
            locationStatusMessage = "Öppna Inställningar och välj 'Tillåt alltid' för plats."
        case .notDetermined:
            locationStatusMessage = "Tryck på Aktivera för att be om platsåtkomst."
        @unknown default:
            locationStatusMessage = nil
        }
    }
    
    private func continueFromStep(_ step: OnboardingStep) {
        switch step {
        case .name:
            // Set username from full first name + last name
            let fullName = "\(firstName.trimmingCharacters(in: .whitespaces)) \(lastName.trimmingCharacters(in: .whitespaces))"
            onboardingData.username = fullName.trimmingCharacters(in: .whitespaces)
            goToNextStep()
        case .sports:
            // Store selected sports
            onboardingData.selectedSports = Array(selectedSports)
            goToNextStep()
        case .fitnessLevel:
            // Store fitness level
            onboardingData.fitnessLevel = selectedFitnessLevel
            goToNextStep()
        case .goals:
            // Store goals
            onboardingData.goals = Array(selectedGoals)
            goToNextStep()
        case .location:
            if onboardingData.locationAuthorized {
                goToNextStep()
            } else {
                locationStatusMessage = "Tryck på Aktivera och välj 'Tillåt alltid' i dialogen."
                LocationManager.shared.requestLocationPermission()
            }
        case .appleHealth:
            requestHealthAuthorization()
            goToNextStep()
        case .notifications:
            if onboardingData.notificationsAuthorized {
                goToNextStep()
            } else {
                NotificationManager.shared.requestAuthorization { granted in
                    DispatchQueue.main.async {
                        onboardingData.notificationsAuthorized = granted
                        notificationsStatus = granted ? "Notiser aktiverade" : "Notiser nekades"
                        // Auto-advance after authorization (whether granted or denied)
                        goToNextStep()
                    }
                }
            }
        }
    }
    
    private func skipStep(_ step: OnboardingStep) {
        goToNextStep()
    }
    
    private func goToNextStep() {
        if let step = onboardingStep, let index = onboardingSteps.firstIndex(of: step), index < onboardingSteps.count - 1 {
            onboardingStep = onboardingSteps[index + 1]
        } else {
            // Onboarding complete - enter the app
            completeOnboarding()
        }
    }
    
    private func completeOnboarding() {
        // Save onboarding data to user profile
        Task {
            if let userId = authViewModel.currentUser?.id {
                // Use full first name + last name as username
                let fullName = "\(firstName.trimmingCharacters(in: .whitespaces)) \(lastName.trimmingCharacters(in: .whitespaces))"
                let finalUsername = fullName.trimmingCharacters(in: .whitespaces)
                
                print("📝 Saving username: '\(finalUsername)' for user: \(userId)")
                
                // Update user profile with onboarding data
                do {
                    // Update profile using ProfileService (profiles table)
                    try await ProfileService.shared.updateUsername(userId: userId, username: finalUsername)
                    
                    // Update additional onboarding fields
                    try await SupabaseConfig.supabase
                        .from("profiles")
                        .update([
                            "fitness_level": selectedFitnessLevel,
                            "selected_sports": Array(selectedSports).joined(separator: ","),
                            "goals": Array(selectedGoals).joined(separator: ",")
                        ])
                        .eq("id", value: userId)
                        .execute()
                    
                    print("✅ Onboarding data saved successfully")
                } catch {
                    print("⚠️ Failed to save onboarding data: \(error)")
                }
                
                // ALWAYS refresh user profile to get the latest username before entering the app
                // This ensures the user never sees "user-XXXXX"
                if let updatedProfile = try? await ProfileService.shared.fetchUserProfile(userId: userId) {
                    await MainActor.run {
                        authViewModel.currentUser = updatedProfile
                        print("✅ Profile refreshed with username: '\(updatedProfile.name)'")
                    }
                } else {
                    // If we can't fetch the profile, at least update the local user with the name
                    await MainActor.run {
                        if var user = authViewModel.currentUser {
                            user.name = finalUsername
                            authViewModel.currentUser = user
                            print("⚠️ Could not fetch profile, using local username: '\(finalUsername)'")
                        }
                    }
                }
                
                // Onboarding complete - NOW set isLoggedIn = true to enter the app
                await MainActor.run {
                    onboardingStep = nil
                    showSignupForm = false
                    showLanding = false
                    authViewModel.isLoggedIn = true  // This triggers MainTabView to show
                    print("✅ Onboarding complete, entering app with username: '\(authViewModel.currentUser?.name ?? "unknown")'")
                }
            } else {
                // User is not logged in yet - this shouldn't happen normally
                // but if it does, reset to landing
                await MainActor.run {
                    onboardingStep = nil
                    showSignupForm = false
                    showLanding = true
                    print("⚠️ No user logged in after onboarding, returning to landing")
                }
            }
        }
    }
    
    private func canContinue(_ step: OnboardingStep) -> Bool {
        switch step {
        case .name:
            return !firstName.trimmingCharacters(in: .whitespaces).isEmpty &&
                   !lastName.trimmingCharacters(in: .whitespaces).isEmpty
        case .sports:
            return !selectedSports.isEmpty
        case .fitnessLevel:
            return !selectedFitnessLevel.isEmpty
        case .goals:
            return !selectedGoals.isEmpty
        default:
            return true
        }
    }
    
    private func heroImageName(for index: Int) -> String {
        guard index >= 0 && index < heroImages.count else { return heroImages.first ?? "27" }
        return heroImages[index]
    }
}

private extension AuthenticationView {
    func scheduleUsernameAvailabilityCheck(for username: String) {
        let trimmed = username.trimmingCharacters(in: .whitespacesAndNewlines)
        usernameCheckTask?.cancel()
        
        if trimmed.count < 2 {
            lastCheckedUsername = trimmed
            isCheckingUsername = false
            isUsernameAvailable = false
            return
        }
        
        if trimmed == lastCheckedUsername && !isCheckingUsername {
            return
        }
        
        isCheckingUsername = true
        usernameCheckTask = Task {
            try? await Task.sleep(nanoseconds: 350_000_000)
            guard !Task.isCancelled else { return }
            let available = await ProfileService.shared.isUsernameAvailable(trimmed)
            await MainActor.run {
                if trimmed == onboardingData.trimmedUsername {
                    lastCheckedUsername = trimmed
                    isCheckingUsername = false
                    isUsernameAvailable = available
                }
            }
        }
    }
}

private extension AuthenticationView {
    var signupFormView: some View {
        VStack(spacing: 0) {
            // Close button top right
            HStack {
                Spacer()
                Button {
                    showSignupForm = false
                    showLanding = true
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.black.opacity(0.6))
                        .frame(width: 36, height: 36)
                        .background(Color(.systemGray5))
                        .clipShape(Circle())
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Title
                    Text("Skapa konto")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(.black)
                        .padding(.top, 8)
                    
                    // Apple Sign In Button (outline style)
                    Button {
                        authViewModel.signInWithApple(onboardingData: onboardingData)
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "apple.logo")
                                .font(.system(size: 20, weight: .medium))
                                .foregroundColor(.black)
                            
                            Text("Fortsätt med Apple")
                                .font(.system(size: 17, weight: .medium))
                                .foregroundColor(.black)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 30)
                                .stroke(Color(.systemGray3), lineWidth: 1)
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                    .disabled(authViewModel.isLoading)
                    
                    // Divider
                    HStack {
                        Rectangle()
                            .fill(Color(.systemGray4))
                            .frame(height: 1)
                        Text("eller")
                            .font(.system(size: 14))
                            .foregroundColor(.gray)
                            .padding(.horizontal, 16)
                        Rectangle()
                            .fill(Color(.systemGray4))
                            .frame(height: 1)
                    }
                    
                    // Email field
                    VStack(alignment: .leading, spacing: 8) {
                        Text("E-post")
                            .font(.system(size: 15))
                            .foregroundColor(.black)
                        
                        TextField("E-post", text: $signupEmail)
                            .keyboardType(.emailAddress)
                            .textInputAutocapitalization(.never)
                            .textContentType(.emailAddress)
                            .autocorrectionDisabled()
                            .padding(14)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color(.systemGray4), lineWidth: 1)
                            )
                    }
                    
                    // Password field
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Lösenord")
                            .font(.system(size: 15))
                            .foregroundColor(.black)
                        
                        SecureField("Minst 6 tecken", text: $signupPassword)
                            .textContentType(.newPassword)
                            .padding(14)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color(.systemGray4), lineWidth: 1)
                            )
                    }
                    
                    // Sign Up button
                    Button {
                        // Create account first, then go to onboarding
                        createAccountAndStartOnboarding()
                    } label: {
                        if authViewModel.isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(Color.black)
                                .clipShape(Capsule())
                        } else {
                            Text("Registrera dig")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundColor(canCreateAccount ? .white : .gray)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(canCreateAccount ? Color.black : Color(.systemGray5))
                                .clipShape(Capsule())
                        }
                    }
                    .disabled(!canCreateAccount || authViewModel.isLoading)
                    
                    if !authViewModel.errorMessage.isEmpty {
                        Text(authViewModel.errorMessage)
                            .font(.system(size: 14))
                            .foregroundColor(.red)
                    }
                    
                    // Terms text
                    Text("Genom att fortsätta godkänner du våra [Användarvillkor](https://www.upanddownapp.com/terms) och [Integritetspolicy](https://www.upanddownapp.com/privacy).")
                        .font(.system(size: 13))
                        .foregroundColor(.gray)
                        .tint(.black)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            }
        }
    }
    
    var canSubmitSignup: Bool {
        let trimmedName = signupName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedEmail = signupEmail.trimmingCharacters(in: .whitespacesAndNewlines)
        let emailValid = trimmedEmail.range(of: #"^\S+@\S+\.\S+$"#, options: .regularExpression) != nil
        return trimmedName.count >= 2 &&
               emailValid &&
               signupPassword.count >= 6 &&
               signupPassword == signupConfirmPassword &&
               !onboardingData.trimmedUsername.isEmpty
    }
    
    var canCreateAccount: Bool {
        let trimmedEmail = signupEmail.trimmingCharacters(in: .whitespacesAndNewlines)
        let emailValid = trimmedEmail.range(of: #"^\S+@\S+\.\S+$"#, options: .regularExpression) != nil
        return emailValid && signupPassword.count >= 6
    }
    
    private func createAccountAndStartOnboarding() {
        let trimmedEmail = signupEmail.trimmingCharacters(in: .whitespacesAndNewlines)
        
        Task {
            await MainActor.run {
                authViewModel.isLoading = true
                authViewModel.errorMessage = ""
            }
            
            do {
                // Create the account in Supabase
                let response = try await SupabaseConfig.supabase.auth.signUp(
                    email: trimmedEmail,
                    password: signupPassword
                )
                
                let userId = response.user.id.uuidString
                
                // Create a basic user profile with placeholder username
                let placeholderUsername = "user-\(userId.prefix(6))"
                let newUser = User(id: userId, name: placeholderUsername, email: trimmedEmail)
                try await ProfileService.shared.createUserProfile(newUser)
                
                // Configure RevenueCat
                await RevenueCatManager.shared.logInFor(appUserId: userId)
                
                await MainActor.run {
                    // Store the user but DON'T set isLoggedIn = true yet!
                    // This keeps us in AuthenticationView for onboarding
                    authViewModel.currentUser = newUser
                    // authViewModel.isLoggedIn stays FALSE until onboarding completes
                    authViewModel.isLoading = false
                    
                    // Navigate to onboarding
                    showSignupForm = false
                    onboardingStep = onboardingSteps.first
                    
                    print("✅ Account created successfully, starting onboarding (isLoggedIn: \(authViewModel.isLoggedIn))")
                }
            } catch {
                await MainActor.run {
                    authViewModel.errorMessage = "Kunde inte skapa konto: \(error.localizedDescription)"
                    authViewModel.isLoading = false
                    print("❌ Account creation failed: \(error)")
                }
            }
        }
    }
}

// MARK: - Login Form (Strava Style)
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
            // Email field
            VStack(alignment: .leading, spacing: 8) {
                Text("E-post")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.black)
                
                TextField("E-post", text: $email)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)
                    .padding(14)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
            }
            
            // Password field
            VStack(alignment: .leading, spacing: 8) {
                Text("Lösenord")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.black)
                
                ZStack(alignment: .trailing) {
                    if isPasswordVisible {
                        TextField("Lösenord", text: $password)
                            .textContentType(.password)
                            .padding(14)
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                    } else {
                        SecureField("Lösenord", text: $password)
                            .textContentType(.password)
                            .padding(14)
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                    }
                    Button {
                        isPasswordVisible.toggle()
                    } label: {
                        Image(systemName: isPasswordVisible ? "eye.slash.fill" : "eye.fill")
                            .foregroundColor(.gray)
                            .padding(.trailing, 14)
                    }
                }
            }
            
            // Forgot password link
            Button {
                forgotPasswordEmail = email
                showForgotPassword = true
            } label: {
                Text("Glömt lösenord?")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.black.opacity(0.7))
                    .underline()
            }
            
            if !authViewModel.errorMessage.isEmpty {
                Text(authViewModel.errorMessage)
                    .foregroundColor(.red)
                    .font(.system(size: 13))
            }
            
            // Login button (Strava style - beige/gray)
            Button {
                authViewModel.login(email: email, password: password)
            } label: {
                HStack {
                    Spacer()
                    if authViewModel.isLoading {
                        ProgressView()
                            .tint(.black.opacity(0.6))
                    } else {
                        Text("Logga in")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(email.isEmpty || password.isEmpty ? .black.opacity(0.4) : .black)
                    }
                    Spacer()
                }
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 30)
                        .fill(Color(red: 0.9, green: 0.88, blue: 0.85))
                )
                .contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle())
            .disabled(authViewModel.isLoading || email.isEmpty || password.isEmpty)
            .opacity(email.isEmpty || password.isEmpty ? 0.7 : 1)
        }
        .sheet(isPresented: $showForgotPassword) {
            ForgotPasswordSheet(
                email: $forgotPasswordEmail,
                isLoading: $isResettingPassword,
                message: $resetMessage,
                success: $resetSuccess,
                onReset: {
                    Task {
                        isResettingPassword = true
                        let result = await authViewModel.resetPassword(email: forgotPasswordEmail)
                        await MainActor.run {
                            resetMessage = result.message
                            resetSuccess = result.success
                            isResettingPassword = false
                        }
                    }
                },
                onDismiss: {
                    showForgotPassword = false
                    resetMessage = ""
                    resetSuccess = false
                }
            )
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
                    Image(systemName: "envelope.badge")
                        .font(.system(size: 50))
                        .foregroundColor(.primary)
                    
                    Text("Återställ lösenord")
                        .font(.system(size: 24, weight: .bold))
                    
                    Text("Ange din e-postadress så skickar vi instruktioner för att återställa ditt lösenord.")
                        .font(.system(size: 15))
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .padding(.top, 20)
                
                TextField("E-postadress", text: $email)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)
                    .padding(14)
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    .padding(.horizontal, 24)
                
                if !message.isEmpty {
                    Text(message)
                        .font(.system(size: 14))
                        .foregroundColor(success ? .black : .red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }
                
                if success {
                    Button {
                        onDismiss()
                    } label: {
                        Text("Stäng")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(14)
                            .background(Color.black)
                            .cornerRadius(12)
                    }
                    .padding(.horizontal, 24)
                } else {
                    Button {
                        onReset()
                    } label: {
                        if isLoading {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Text("Skicka återställningslänk")
                                .font(.system(size: 16, weight: .semibold))
                        }
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(14)
                    .background(email.isEmpty ? Color.gray : Color.black)
                    .cornerRadius(12)
                    .disabled(email.isEmpty || isLoading)
                    .padding(.horizontal, 24)
                }
                
                Spacer()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Avbryt") {
                        onDismiss()
                    }
                    .foregroundColor(.primary)
                }
            }
        }
    }
}

#Preview {
    AuthenticationView()
        .environmentObject(AuthViewModel())
}
