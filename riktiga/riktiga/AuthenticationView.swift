import SwiftUI
import CoreLocation
import PhotosUI
import Supabase
import UIKit
import Combine

private enum OnboardingStep: Int, CaseIterable, Identifiable {
    case username
    case location
    case appleHealth
    case golfHcp
    case runningPB
    case notifications
    
    var id: Int { rawValue }
    
    var title: String {
        switch self {
        case .username: return "Välj ditt användarnamn"
        case .location: return "Aktivera platsinfo"
        case .appleHealth: return "Aktivera Apple Health"
        case .golfHcp: return "Vad är ditt Golf HCP?"
        case .runningPB: return "Vad är dina PB inom löpning?"
        case .notifications: return "Aktivera notiser"
        }
    }
    
    var subtitle: String {
        switch self {
        case .username: return "Detta blir ditt namn i appen (max 10 tecken)."
        case .location: return "Aktivera 'Tillåt alltid' för att spåra dina pass korrekt även i bakgrunden."
        case .appleHealth: return "Appen behöver hälsodata för att logga dina pass."
        case .golfHcp: return "Används för att anpassa rekommendationer."
        case .runningPB: return "Fyll i dina personbästa eller hoppa över."
        case .notifications: return "Så vi kan påminna dig om mål och belöningar."
        }
    }
    
    var allowsSkip: Bool {
        switch self {
        case .golfHcp, .runningPB: return true
        default: return false
        }
    }
}

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
    
    private let heroImages = ["27", "28", "29"]
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
    
    // MARK: - Landing
    private var landingView: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 60)
            ZStack {
                Image(heroImages[currentHeroIndex])
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: min(UIScreen.main.bounds.width * 0.82, 360),
                           maxHeight: UIScreen.main.bounds.height * 0.45)
                    .shadow(color: Color.black.opacity(0.12), radius: 28, x: 0, y: 18)
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 24)
            
            Spacer().frame(height: 48)
            
            Text("Träna, få belöningar")
                .font(.system(size: 34, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                .padding(.bottom, 32)
            
            VStack(spacing: 18) {
                Button {
                    if currentHeroIndex < heroImages.count - 1 {
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) {
                            currentHeroIndex += 1
                        }
                    } else {
                        // Start onboarding flow
                        showLanding = false
                        onboardingStep = onboardingSteps.first
                    }
                } label: {
                    Text(currentHeroIndex < heroImages.count - 1 ? "Nästa" : "Skapa konto")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(
                            Color.black
                                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                        )
                        .shadow(color: Color.black.opacity(0.15), radius: 18, x: 0, y: 14)
                }
                .padding(.horizontal, 32)
                
                Button {
                    showLanding = false
                } label: {
                    HStack(spacing: 4) {
                        Text("Har du redan ett konto?")
                            .foregroundColor(.black.opacity(0.6))
                        Text("Logga in här")
                            .foregroundColor(.primary)
                            .fontWeight(.semibold)
                    }
                    .font(.system(size: 15))
                }
            }
            
            Spacer(minLength: 60)
        }
    }
    
    // MARK: - Form
    private var formView: some View {
        VStack(spacing: 24) {
            HStack {
                Button {
                    showLanding = true
                    onboardingStep = nil
                    authViewModel.errorMessage = ""
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.primary)
                        .padding(10)
                        .background(Color.black.opacity(0.08))
                        .clipShape(Circle())
                }
                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.top, 12)
                
            VStack(spacing: 18) {
                Text("Logga in med ditt konto")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 8)
                
                LoginFormView()
                    .environmentObject(authViewModel)
                
                Text("Kontoskapande är avstängt och Apple-inloggning stöds inte längre.")
                    .font(.system(size: 14))
                    .foregroundColor(.black.opacity(0.6))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(28)
            .frame(maxWidth: 420)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .shadow(color: Color.black.opacity(0.35), radius: 30, x: 0, y: 18)
            .padding(.horizontal, 24)
            
            Spacer()
        }
    }
    
    // MARK: - Onboarding Steps
    private func onboardingView(for step: OnboardingStep) -> some View {
        VStack(alignment: .leading, spacing: 24) {
            progressBar
                .padding(.horizontal, 24)
                .padding(.top, 40)
            
            VStack(alignment: .leading, spacing: 8) {
                Text(step.title)
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                Text(step.subtitle)
                    .font(.system(size: 16))
                    .foregroundColor(.black.opacity(0.6))
            }
            .padding(.horizontal, 24)
            
            onboardingContent(for: step)
                .padding(.horizontal, 24)
            
            Spacer()
            
            VStack(spacing: 12) {
                Button(action: { continueFromStep(step) }) {
                    Text(primaryButtonTitle(for: step))
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(canContinue(step) ? Color.black : Color.black.opacity(0.3))
                        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                }
                .disabled(!canContinue(step))
                .padding(.horizontal, 24)
                
                if step.allowsSkip {
                    Button(action: { skipStep(step) }) {
                        Text("Hoppa över")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.black.opacity(0.6))
                    }
                }
            }
            .padding(.bottom, 32)
        }
    }
    
    private var progressBar: some View {
        GeometryReader { geometry in
            let progress = CGFloat(currentOnboardingIndex + 1) / CGFloat(onboardingSteps.count)
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.black.opacity(0.08))
                    .frame(height: 6)
                Capsule()
                    .fill(Color.black)
                    .frame(width: geometry.size.width * progress, height: 6)
                    .animation(.easeInOut(duration: 0.3), value: progress)
            }
        }
        .frame(height: 6)
    }
    
    private func onboardingContent(for step: OnboardingStep) -> some View {
        Group {
            switch step {
            case .username:
                VStack(alignment: .leading, spacing: 20) {
                    TextField("Användarnamn", text: Binding(
                        get: { onboardingData.username },
                        set: { onboardingData.username = String($0.prefix(10)) }
                    ))
                    .textInputAutocapitalization(.none)
                    .disableAutocorrection(true)
                    .padding(14)
                    .background(Color(.systemGray6))
                    .cornerRadius(18)
                    
                    Text("Tecken kvar: \(max(0, 10 - onboardingData.username.count))")
                        .foregroundColor(.black.opacity(0.5))
                        .font(.system(size: 14))
                    
                    let trimmedUsername = onboardingData.trimmedUsername
                    if trimmedUsername.count >= 2 {
                        if isCheckingUsername {
                            HStack(spacing: 8) {
                                ProgressView()
                                    .scaleEffect(0.7)
                                Text("Kontrollerar användarnamn…")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.black.opacity(0.6))
                            }
                        } else {
                            Text(isUsernameAvailable ? "Användarnamnet är ledigt" : "Användarnamnet är upptaget")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(isUsernameAvailable ? .green : .red)
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 14) {
                        HStack(spacing: 16) {
                            ZStack {
                                if let profileImage = profileImage {
                                    Image(uiImage: profileImage)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 96, height: 96)
                                        .clipShape(Circle())
                                } else {
                                    Circle()
                                        .fill(Color(.systemGray5))
                                        .frame(width: 96, height: 96)
                                        .overlay(
                                            Image(systemName: "camera.fill")
                                                .font(.system(size: 32, weight: .medium))
                                                .foregroundColor(.black.opacity(0.4))
                                        )
                                }
                            }
                            
                            Text("Allt blir roligare med en profilbild (:")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(.black.opacity(0.7))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        
                        PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                            Text(profileImage == nil ? "Lägg till profilbild" : "Byt profilbild")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(Color.black)
                                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        }
                        .photosPickerStyle(.presentation)
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
            case .golfHcp:
                VStack(alignment: .leading, spacing: 24) {
                    Picker("HCP", selection: Binding(
                        get: { onboardingData.golfHcp ?? 0 },
                        set: { onboardingData.golfHcp = $0 }
                    )) {
                        ForEach(0...54, id: \.self) { value in
                            Text("\(value)")
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(height: 140)
                    .clipped()
                    .background(Color(.systemGray6))
                    .cornerRadius(18)
                    
                    if let hcp = onboardingData.golfHcp {
                        Text("Valt HCP: \(hcp)")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.black.opacity(0.7))
                    }
                }
            case .runningPB:
                VStack(alignment: .leading, spacing: 18) {
                    Text("Fyll i de PB du vill (kan ändras senare)")
                        .font(.system(size: 14))
                        .foregroundColor(.black.opacity(0.6))
                    
                    VStack(spacing: 12) {
                        pbField(title: "5 km (min)", binding: Binding(
                            get: { onboardingData.pb5kmMinutes?.description ?? "" },
                            set: { onboardingData.pb5kmMinutes = Int($0.filter({ $0.isNumber })) }
                        ))
                        HStack(spacing: 12) {
                            pbField(title: "10 km (h)", binding: Binding(
                                get: { onboardingData.pb10kmHours?.description ?? "" },
                                set: { onboardingData.pb10kmHours = Int($0.filter({ $0.isNumber })) }
                            ))
                            pbField(title: "10 km (min)", binding: Binding(
                                get: { onboardingData.pb10kmMinutes?.description ?? "" },
                                set: { onboardingData.pb10kmMinutes = Int($0.filter({ $0.isNumber })) }
                            ))
                        }
                        HStack(spacing: 12) {
                            pbField(title: "Marathon (h)", binding: Binding(
                                get: { onboardingData.pbMarathonHours?.description ?? "" },
                                set: { onboardingData.pbMarathonHours = Int($0.filter({ $0.isNumber })) }
                            ))
                            pbField(title: "Marathon (min)", binding: Binding(
                                get: { onboardingData.pbMarathonMinutes?.description ?? "" },
                                set: { onboardingData.pbMarathonMinutes = Int($0.filter({ $0.isNumber })) }
                            ))
                        }
                    }
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
        case .username:
            onboardingData.username = onboardingData.trimmedUsername
            usernameCheckTask?.cancel()
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
        case .golfHcp:
            goToNextStep()
        case .runningPB:
            goToNextStep()
        case .notifications:
            if onboardingData.notificationsAuthorized {
                goToNextStep()
            } else {
                NotificationManager.shared.requestAuthorization { granted in
                    onboardingData.notificationsAuthorized = granted
                    notificationsStatus = granted ? "Notiser aktiverade" : "Notiser nekades"
                    // Daily steps reminder removed - users found it annoying
                }
            }
        }
    }
    
    private func skipStep(_ step: OnboardingStep) {
        switch step {
        case .golfHcp:
            onboardingData.golfHcp = nil
        case .runningPB:
            onboardingData.pb5kmMinutes = nil
            onboardingData.pb10kmHours = nil
            onboardingData.pb10kmMinutes = nil
            onboardingData.pbMarathonHours = nil
            onboardingData.pbMarathonMinutes = nil
        default:
            break
        }
        goToNextStep()
    }
    
    private func goToNextStep() {
        if let step = onboardingStep, let index = onboardingSteps.firstIndex(of: step), index < onboardingSteps.count - 1 {
            onboardingStep = onboardingSteps[index + 1]
        } else {
            onboardingStep = nil
            showSignupForm = true
            showLanding = false
            authViewModel.errorMessage = ""
            signupName = ""
            signupEmail = ""
            signupPassword = ""
            signupConfirmPassword = ""
        }
    }
    
    private func canContinue(_ step: OnboardingStep) -> Bool {
        switch step {
        case .username:
            return onboardingData.trimmedUsername.count >= 2 &&
                   onboardingData.profileImageData != nil &&
                   isUsernameAvailable &&
                   !isCheckingUsername
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
        ScrollView {
            VStack(spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    Button {
                        showSignupForm = false
                        onboardingStep = onboardingSteps.first
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.primary)
                            .padding(10)
                            .background(Color.black.opacity(0.05))
                            .clipShape(Circle())
                    }
                    
                    Text("Skapa konto")
                        .font(.system(size: 32, weight: .black))
                        .foregroundColor(.primary)
                    
                    Text("Fyll i dina kontouppgifter för att slutföra onboarding.")
                        .font(.system(size: 15))
                        .foregroundColor(.black.opacity(0.6))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 24)
                .padding(.top, 40)
                
                VStack(spacing: 18) {
                    TextField("Fullständigt namn", text: $signupName)
                        .textInputAutocapitalization(.words)
                        .padding(14)
                        .background(Color(.systemGray6))
                        .cornerRadius(18)
                    
                    TextField("E-postadress", text: $signupEmail)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .textContentType(.emailAddress)
                        .autocorrectionDisabled()
                        .padding(14)
                        .background(Color(.systemGray6))
                        .cornerRadius(18)
                    
                    SecureField("Lösenord (minst 6 tecken)", text: $signupPassword)
                        .padding(14)
                        .background(Color(.systemGray6))
                        .cornerRadius(18)
                    
                    SecureField("Bekräfta lösenord", text: $signupConfirmPassword)
                        .padding(14)
                        .background(Color(.systemGray6))
                        .cornerRadius(18)
                }
                .padding(.horizontal, 24)
                
                VStack(alignment: .leading, spacing: 12) {
                    Text("Valt användarnamn")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.black.opacity(0.6))
                    
                    HStack {
                        Text("@\(onboardingData.trimmedUsername)")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.primary)
                        Spacer()
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundColor(.green)
                    }
                    .padding(14)
                    .background(Color(.systemGray6))
                    .cornerRadius(18)
                }
                .padding(.horizontal, 24)
                
                if !authViewModel.errorMessage.isEmpty {
                    Text(authViewModel.errorMessage)
                        .font(.system(size: 14))
                        .foregroundColor(.red)
                        .padding(.horizontal, 24)
                }
                
                Button {
                    authViewModel.signup(
                        name: signupName.trimmingCharacters(in: .whitespacesAndNewlines),
                        username: onboardingData.trimmedUsername,
                        email: signupEmail.trimmingCharacters(in: .whitespacesAndNewlines),
                        password: signupPassword,
                        confirmPassword: signupConfirmPassword,
                        onboardingData: onboardingData
                    )
                } label: {
                    if authViewModel.isLoading {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .tint(.white)
                            .frame(maxWidth: .infinity)
                    } else {
                        Text("Skapa konto")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                    }
                }
                .padding(.vertical, 16)
                .background(canSubmitSignup ? Color.black : Color.black.opacity(0.35))
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .padding(.horizontal, 24)
                .disabled(!canSubmitSignup || authViewModel.isLoading)
                
                Button {
                    showSignupForm = false
                    onboardingStep = nil
                    showLanding = true
                } label: {
                    Text("Avbryt")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.black.opacity(0.6))
                }
                .padding(.bottom, 32)
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
        VStack(spacing: 12) {
            TextField("Email", text: $email)
                .textContentType(.emailAddress)
                .keyboardType(.emailAddress)
                .padding(12)
                .background(Color(.systemGray6))
                .cornerRadius(8)
                .autocapitalization(.none)
            
            ZStack(alignment: .trailing) {
                if isPasswordVisible {
                    TextField("Lösenord", text: $password)
                        .textContentType(.password)
                        .padding(12)
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                } else {
                    SecureField("Lösenord", text: $password)
                        .textContentType(.password)
                        .padding(12)
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                }
                Button {
                    isPasswordVisible.toggle()
                } label: {
                    Image(systemName: isPasswordVisible ? "eye.slash.fill" : "eye.fill")
                        .foregroundColor(.gray)
                        .padding(.trailing, 12)
                }
            }
            
            // Forgot password link
            HStack {
                Spacer()
                Button {
                    forgotPasswordEmail = email // Pre-fill with entered email
                    showForgotPassword = true
                } label: {
                    Text("Glömt lösenord?")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.black.opacity(0.7))
                }
            }
            
            if !authViewModel.errorMessage.isEmpty {
                Text(authViewModel.errorMessage)
                    .foregroundColor(.red)
                    .font(.caption)
            }
            
            Button {
                authViewModel.login(email: email, password: password)
            } label: {
                if authViewModel.isLoading {
                    ProgressView().tint(.white)
                } else {
                    Text("LOGGA IN")
                        .font(.system(size: 16, weight: .black))
                        .frame(maxWidth: .infinity)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(14)
            .background(Color.black)
            .foregroundColor(.white)
            .cornerRadius(10)
            .disabled(authViewModel.isLoading)
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
