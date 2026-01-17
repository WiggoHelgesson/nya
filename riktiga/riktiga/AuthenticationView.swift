import SwiftUI
import CoreLocation
import PhotosUI
import Supabase
import UIKit
import Combine

// MARK: - New Unified Onboarding Steps
private enum OnboardingStep: Int, CaseIterable, Identifiable {
    case name
    case gender
    case workouts
    case heightWeight
    case birthday
    case goal
    case targetWeight
    case appleHealth
    case notifications
    
    var id: Int { rawValue }
    
    var title: String {
        switch self {
        case .name: return "Vad heter du?"
        case .gender: return "Välj ditt kön"
        case .workouts: return "Hur många pass tränar du per vecka?"
        case .heightWeight: return "Längd & vikt"
        case .birthday: return "När är du född?"
        case .goal: return "Vad är ditt mål?"
        case .targetWeight: return "Vad är din målvikt?"
        case .appleHealth: return "Aktivera Apple Health"
        case .notifications: return "Aktivera notiser"
        }
    }
    
    var subtitle: String {
        switch self {
        case .name: return "Så här kan dina vänner hitta dig på Up&Down."
        case .gender: return "Detta används för att kalibrera din personliga plan."
        case .workouts: return "Detta används för att kalibrera din personliga plan."
        case .heightWeight: return "Detta används för att kalibrera din personliga plan."
        case .birthday: return "Detta används för att kalibrera din personliga plan."
        case .goal: return "Detta hjälper oss skapa en plan för ditt kaloriintag."
        case .targetWeight: return "Välj den vikt du vill uppnå."
        case .appleHealth: return "Appen behöver hälsodata för att logga dina pass och steg."
        case .notifications: return "Så vi kan påminna dig om mål och belöningar."
        }
    }
}

// MARK: - Onboarding Data Model
struct UnifiedOnboardingData {
    // Name
    var firstName: String = ""
    var lastName: String = ""
    
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
    
    private let heroImages = ["61", "63", "62"]
    private let onboardingSteps = OnboardingStep.allCases
    private let totalSteps = OnboardingStep.allCases.count
    
    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()
            
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
        .onAppear {
            showLanding = true
            onboardingStep = nil
            authViewModel.errorMessage = ""
            
            let healthAuthorized = HealthKitManager.shared.isHealthDataAuthorized()
            data.healthAuthorized = healthAuthorized
            healthRequestStatus = healthAuthorized ? "Apple Health aktiverad" : nil
            
            // Set up Apple Sign In callback
            authViewModel.onAppleSignInComplete = { success, _ in
                if success {
                        showLanding = false
                        showSignupForm = false
                        onboardingStep = onboardingSteps.first
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
        
        return VStack(spacing: 0) {
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
                            .fill(index == currentHeroIndex ? Color.black : Color.black.opacity(0.25))
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
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.black)
                            .clipShape(Capsule())
                    }
                    .padding(.horizontal, 24)
                    
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
                    Text("Logga in på Up&Down")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.black)
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
                            Text("Fortsätt med Apple")
                                .font(.system(size: 17, weight: .medium))
                            Spacer()
                        }
                        .foregroundColor(.black)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 16)
                        .background(RoundedRectangle(cornerRadius: 30).stroke(Color(.systemGray3), lineWidth: 1.5))
                    }
                    .disabled(authViewModel.isLoading)
                    
                    Text("Genom att fortsätta godkänner du våra [användarvillkor](https://wiggio.se/privacy) och [integritetspolicy](https://wiggio.se/privacy).")
                        .font(.system(size: 13))
                        .foregroundColor(.gray)
                        .tint(.black)
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
                    Text("Skapa konto")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(.black)
                        .padding(.top, 8)
                    
                    Button {
                        authViewModel.signInWithApple(onboardingData: OnboardingData())
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "apple.logo")
                                .font(.system(size: 20, weight: .medium))
                            Text("Fortsätt med Apple")
                                .font(.system(size: 17, weight: .medium))
                        }
                        .foregroundColor(.black)
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
                        Text("E-post").font(.system(size: 15)).foregroundColor(.black)
                        TextField("E-post", text: $signupEmail)
                            .keyboardType(.emailAddress)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .padding(14)
                            .background(RoundedRectangle(cornerRadius: 8).stroke(Color(.systemGray4), lineWidth: 1))
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Lösenord").font(.system(size: 15)).foregroundColor(.black)
                        SecureField("Minst 6 tecken", text: $signupPassword)
                            .padding(14)
                            .background(RoundedRectangle(cornerRadius: 8).stroke(Color(.systemGray4), lineWidth: 1))
                    }
                    
                    Button {
                        createAccountAndStartOnboarding()
                    } label: {
                        if authViewModel.isLoading {
                            ProgressView().tint(.white).frame(maxWidth: .infinity).padding(.vertical, 16).background(Color.black).clipShape(Capsule())
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
                        Text(authViewModel.errorMessage).font(.system(size: 14)).foregroundColor(.red)
                    }
                    
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
                    if let currentIndex = onboardingSteps.firstIndex(of: step), currentIndex > 0 {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            onboardingStep = onboardingSteps[currentIndex - 1]
                        }
                    }
                } label: {
                    Image(systemName: "arrow.left")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.black)
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
                            .fill(Color.black)
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
                        .foregroundColor(.black)
                    
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
        .onChange(of: step) { _, _ in
            animateContentIn()
        }
    }
    
    @ViewBuilder
    private func onboardingContent(for step: OnboardingStep) -> some View {
            switch step {
            case .name:
            nameStepContent
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
        case .targetWeight:
            targetWeightStepContent
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
                Text("Förnamn").font(.system(size: 15)).foregroundColor(.black)
                TextField("", text: $data.firstName)
                            .textInputAutocapitalization(.words)
                            .padding(16)
                    .background(RoundedRectangle(cornerRadius: 8).stroke(Color(.systemGray3), lineWidth: 1))
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                Text("Efternamn").font(.system(size: 15)).foregroundColor(.black)
                TextField("", text: $data.lastName)
                            .textInputAutocapitalization(.words)
                            .padding(16)
                    .background(RoundedRectangle(cornerRadius: 8).stroke(Color(.systemGray3), lineWidth: 1))
                    }
                    
                    Text("Din profil är offentlig som standard.")
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
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
                .foregroundColor(data.gender == value ? .white : .black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
                .background(RoundedRectangle(cornerRadius: 16).fill(data.gender == value ? Color.black : Color(.systemGray6)))
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
                                    .foregroundColor(.black)
                    .frame(width: 40)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(range).font(.system(size: 18, weight: .semibold)).foregroundColor(.black)
                    Text(description).font(.system(size: 14)).foregroundColor(.gray)
                }
                Spacer()
            }
                            .padding(18)
                            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(data.workoutsPerWeek == value ? Color(.systemGray5) : Color(.systemGray6))
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(data.workoutsPerWeek == value ? Color.black : Color.clear, lineWidth: 2))
            )
        }
    }
    
    private var heightWeightStepContent: some View {
        VStack(spacing: 20) {
            Spacer().frame(height: 20)
            
            HStack(spacing: 20) {
                VStack(spacing: 8) {
                    Text("Längd").font(.system(size: 16, weight: .semibold)).foregroundColor(.black)
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
                    Text("Vikt").font(.system(size: 16, weight: .semibold)).foregroundColor(.black)
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
                .foregroundColor(data.goal == value ? .white : .black)
                                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.vertical, 20)
                .background(RoundedRectangle(cornerRadius: 16).fill(data.goal == value ? Color.black : Color(.systemGray6)))
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
                Text("\(Int(data.weightKg)) kg").font(.system(size: 14, weight: .semibold)).foregroundColor(.black)
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
                        .foregroundColor(.black)
                }
                .padding(.horizontal, 20)
                                .padding(.vertical, 12)
                .background(Color(.systemGray6))
                .cornerRadius(12)
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
                            .foregroundColor(.black.opacity(0.65))
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
                .foregroundColor(.black)
                .frame(maxWidth: .infinity)
            
                    Text("Få påminnelser om pass och nya belöningar.")
                .font(.system(size: 16))
                .foregroundColor(.black.opacity(0.7))
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
            
            Text(data.notificationsAuthorized
                 ? "Notiser är aktiverade – tryck Fortsätt."
                 : "Tryck på Fortsätt för att aktivera notiser.")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.black.opacity(0.7))
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
                .foregroundColor(.black)
                .contentTransition(.numericText())
                .animation(.easeOut(duration: 0.1), value: calculationProgress)
            
            Text("Vi skapar allt\nåt dig")
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(.black)
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
                    .foregroundColor(.black)
                
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
            Text("•").foregroundColor(.black)
            Text(text).font(.system(size: 15)).foregroundColor(.black)
            Spacer()
            if isChecked {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.black)
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
                            Rectangle().fill(Color.black).frame(height: 4).cornerRadius(2)
                        }
                        .frame(height: 4)
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 50))
                        .foregroundColor(.black)
                    
                    Text("Grattis")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.black)
                    
                    Text("din personliga plan är klar!")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.black)
                }
                
                VStack(spacing: 12) {
                    Text("Du bör:")
                        .font(.system(size: 16))
                        .foregroundColor(.gray)
                    
                    Text(goalPredictionText)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.black)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(Color(.systemGray6))
                        .cornerRadius(20)
                }
                
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Daglig rekommendation")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.black)
                        Text("Du kan ändra detta när som helst")
                            .font(.system(size: 14))
                            .foregroundColor(.gray)
                    }
                    .padding(.horizontal, 24)
                    
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                        MacroResultCard(icon: "flame.fill", iconColor: .black, title: "Kalorier", value: $data.dailyCalories, unit: "", progress: 0.75)
                        MacroResultCard(icon: "leaf.fill", iconColor: .orange, title: "Kolhydrater", value: $data.dailyCarbs, unit: "g", progress: 0.65)
                        MacroResultCard(icon: "drop.fill", iconColor: .red, title: "Protein", value: $data.dailyProtein, unit: "g", progress: 0.70)
                        MacroResultCard(icon: "drop.fill", iconColor: .blue, title: "Fett", value: $data.dailyFat, unit: "g", progress: 0.55)
                    }
                    .padding(.horizontal, 24)
                }
                
                Spacer().frame(height: 20)
                
                Button {
                    completeOnboarding()
                } label: {
                    Text("Kom igång!")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(Color.black)
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
    
    // MARK: - Helper Functions
    private func canContinue(_ step: OnboardingStep) -> Bool {
        switch step {
        case .name:
            return !data.firstName.trimmingCharacters(in: .whitespaces).isEmpty &&
                   !data.lastName.trimmingCharacters(in: .whitespaces).isEmpty
        case .gender: return !data.gender.isEmpty
        case .workouts: return !data.workoutsPerWeek.isEmpty
        case .heightWeight: return true
        case .birthday: return true
        case .goal: return !data.goal.isEmpty
        case .targetWeight: return true
        case .appleHealth: return true
        case .notifications: return true
        }
    }
    
    private func continueFromStep(_ step: OnboardingStep) {
        hapticFeedback()
        
        switch step {
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
        default:
            goToNextStep()
        }
    }
    
    private func goToNextStep() {
        if let step = onboardingStep, let index = onboardingSteps.firstIndex(of: step), index < onboardingSteps.count - 1 {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                onboardingStep = onboardingSteps[index + 1]
            }
        }
    }
    
    private func animateContentIn() {
        contentOpacity = 0
        contentOffset = 20
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.1)) {
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
                let finalUsername = data.fullName
                
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
                
                do {
                    print("📝 Updating username to: '\(finalUsername)'")
                    try await ProfileService.shared.updateUsername(userId: userId, username: finalUsername)
                    print("✅ Username updated successfully to: '\(finalUsername)'")
                    
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
                    
                    print("✅ Onboarding data saved")
                } catch {
                    print("⚠️ Failed to save onboarding data: \(error)")
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
                
                await MainActor.run {
                    // Set current user for AI scan limit manager
                    AIScanLimitManager.shared.setCurrentUser(userId: userId)
                    
                    // First set logged in to show HomeView
                    authViewModel.isLoggedIn = true
                    print("✅ Onboarding complete, entering app with name: '\(authViewModel.currentUser?.name ?? "unknown")'")
                    
                    // Post notification after a small delay to ensure HomeView is ready
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        NotificationCenter.default.post(name: NSNotification.Name("NutritionGoalsUpdated"), object: nil)
                        print("📢 Posted NutritionGoalsUpdated notification")
                    }
                }
            }
        }
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
    let icon: String
    let iconColor: Color
    let title: String
    @Binding var value: Int
    let unit: String
    let progress: Double
    
    @State private var isEditing = false
    @State private var editValue: String = ""
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon).font(.system(size: 14)).foregroundColor(iconColor)
                Text(title).font(.system(size: 14)).foregroundColor(.gray)
                Spacer()
            }
            
            HStack(alignment: .bottom, spacing: 0) {
                ZStack {
                    Circle().stroke(Color(.systemGray5), lineWidth: 6).frame(width: 60, height: 60)
                    Circle().trim(from: 0, to: progress).stroke(iconColor, style: StrokeStyle(lineWidth: 6, lineCap: .round)).frame(width: 60, height: 60).rotationEffect(.degrees(-90))
                    VStack(spacing: 0) {
                        Text("\(value)").font(.system(size: 18, weight: .bold)).foregroundColor(.black)
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
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 2)
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
