import SwiftUI
import UIKit

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
        case .location: return "Aktivera 'Tillåt alltid' så att vi kan logga dina pass korrekt."
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
    @State private var showLanding = true
    @State private var currentHeroIndex = 0
    @State private var onboardingStep: OnboardingStep? = nil
    @State private var onboardingData = OnboardingData()
    @State private var locationStatus: String?
    @State private var healthStatus: String?
    @State private var notificationStatus: String?
    
    private let heroImages = ["27", "28", "29"]
    private let onboardingSteps = OnboardingStep.allCases
    
    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()
            if let step = onboardingStep {
                onboardingView(for: step)
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
            locationStatus = nil
        }
    }
    
    private var landingView: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 60)
            Image(heroImages[currentHeroIndex])
                .resizable()
                .scaledToFit()
                .frame(maxWidth: min(UIScreen.main.bounds.width * 0.82, 360),
                       maxHeight: UIScreen.main.bounds.height * 0.45)
                .shadow(color: Color.black.opacity(0.12), radius: 28, x: 0, y: 18)
                .padding(.horizontal, 24)
            
            Spacer().frame(height: 48)
            
            Text("Träna, få belöningar")
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundColor(.black)
                .padding(.bottom, 32)
            
            VStack(spacing: 18) {
                Button {
                    if currentHeroIndex < heroImages.count - 1 {
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) {
                            currentHeroIndex += 1
                        }
                    } else {
                        showLanding = false
                    }
                } label: {
                    Text(currentHeroIndex < heroImages.count - 1 ? "Nästa" : "Skapa konto")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(Color.black)
                        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
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
                            .foregroundColor(.black)
                            .fontWeight(.semibold)
                    }
                    .font(.system(size: 15))
                }
            }
            
            Spacer(minLength: 60)
        }
    }
    
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
                        .foregroundColor(.white)
                        .padding(10)
                        .background(Color.white.opacity(0.12))
                        .clipShape(Circle())
                }
                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.top, 12)
                
            VStack(spacing: 18) {
                Text("Logga in med ditt konto")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 8)
                
                LoginFormView()
                    .environmentObject(authViewModel)
                
                Text("Det går inte längre att skapa konto eller använda Apple-inloggning.")
                    .font(.system(size: 14))
                    .foregroundColor(.black.opacity(0.6))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(28)
            .frame(maxWidth: 420)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .shadow(color: Color.black.opacity(0.35), radius: 30, x: 0, y: 18)
            .padding(.horizontal, 24)
            
            Spacer()
        }
    }
    
    private func onboardingView(for step: OnboardingStep) -> some View {
        VStack(alignment: .leading, spacing: 24) {
            progressBar
                .padding(.horizontal, 24)
                .padding(.top, 40)
            
            VStack(alignment: .leading, spacing: 8) {
                Text(step.title)
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundColor(.black)
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
                Capsule().fill(Color.black.opacity(0.08)).frame(height: 6)
                Capsule().fill(Color.black)
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
                VStack(alignment: .leading, spacing: 16) {
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
                    
                    VStack(alignment: .leading, spacing: 12) {
                        if onboardingData.profileImageData != nil {
                            Text("Profilbild tillagd!")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.green)
                        } else {
                            Text("Allt blir roligare med en profilbild (:")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.black.opacity(0.7))
                        }
                        
                        Button {
                            onboardingData.profileImageData = Data() // Demo-versionen sparar inte riktig bild
                        } label: {
                            Text(onboardingData.profileImageData == nil ? "Lägg till profilbild" : "Byt profilbild")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(Color.black)
                                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        }
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
                    
                    Text("Aktivera \"Tillåt alltid\" för att spårningen ska fungera även i bakgrunden.")
                        .font(.system(size: 15, weight: .medium))
                        .multilineTextAlignment(.center)
                        .foregroundColor(.black.opacity(0.7))
                        .padding(.horizontal, 12)
                    
                    if let status = locationStatus {
                        Text(status)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(onboardingData.locationAuthorized ? .green : .red)
                            .padding(.horizontal, 12)
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
                    
                    Text(onboardingData.appleHealthAuthorized
                         ? "Apple Health är aktiverat. Du kan gå vidare."
                         : "Tryck på Aktivera för att öppna Apple Health och godkänn åtkomst.")
                        .multilineTextAlignment(.center)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.black.opacity(0.65))
                        .padding(.horizontal, 12)
                    
                    if let status = healthStatus {
                        Text(status)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(onboardingData.appleHealthAuthorized ? .green : .red)
                    }
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
                    
                    if let status = notificationStatus {
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
        guard let step = onboardingStep, let index = onboardingSteps.firstIndex(of: step) else { return 0 }
        return index
    }
    
    private func primaryButtonTitle(for step: OnboardingStep) -> String {
        switch step {
        case .location:
            return onboardingData.locationAuthorized ? "Fortsätt" : "Aktivera"
        case .appleHealth:
            return onboardingData.appleHealthAuthorized ? "Fortsätt" : "Aktivera"
        case .notifications:
            return onboardingData.notificationsAuthorized ? "Klart" : "Aktivera"
        default:
            return "Fortsätt"
        }
    }
    
    private func continueFromStep(_ step: OnboardingStep) {
        switch step {
        case .username:
            onboardingData.username = onboardingData.trimmedUsername
            goToNextStep()
        case .location:
            if onboardingData.locationAuthorized {
                goToNextStep()
            } else {
                onboardingData.locationAuthorized = true
                locationStatus = "Platsinfo aktiverad"
            }
        case .appleHealth:
            if onboardingData.appleHealthAuthorized {
                goToNextStep()
            } else {
                onboardingData.appleHealthAuthorized = true
                healthStatus = "Apple Health aktiverad"
            }
        case .golfHcp, .runningPB:
            goToNextStep()
        case .notifications:
            if onboardingData.notificationsAuthorized {
                goToNextStep()
            } else {
                onboardingData.notificationsAuthorized = true
                notificationStatus = "Notiser aktiverade"
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
        if let step = onboardingStep, let idx = onboardingSteps.firstIndex(of: step), idx < onboardingSteps.count - 1 {
            onboardingStep = onboardingSteps[idx + 1]
        } else {
            onboardingStep = nil
            showLanding = false
        }
    }
    
    private func canContinue(_ step: OnboardingStep) -> Bool {
        switch step {
        case .username:
            return onboardingData.trimmedUsername.count >= 2 && onboardingData.profileImageData != nil
        default:
            return true
        }
    }
}

struct LoginFormView: View {
    @State private var email = ""
    @State private var password = ""
    @EnvironmentObject var authViewModel: AuthViewModel
    
    var body: some View {
        VStack(spacing: 16) {
            TextField("Email", text: $email)
                .textContentType(.emailAddress)
                .keyboardType(.emailAddress)
                .padding(12)
                .background(Color(.systemGray6))
                .cornerRadius(8)
                .autocapitalization(.none)
            SecureField("Lösenord", text: $password)
                .textContentType(.password)
                .padding(12)
                .background(Color(.systemGray6))
                .cornerRadius(8)
            if !authViewModel.errorMessage.isEmpty {
                Text(authViewModel.errorMessage)
                    .foregroundColor(.red)
                    .font(.caption)
            }
            Button(action: {
                authViewModel.login(email: email, password: password)
            }) {
                Text("Logga in")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.black)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                    .font(.headline)
            }
        }
    }
}

#Preview {
    AuthenticationView()
        .environmentObject(AuthViewModel())
}