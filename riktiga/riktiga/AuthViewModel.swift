import Foundation
import SwiftUI
import Combine
import Supabase
import UIKit
import AuthenticationServices
import CryptoKit
import GoogleSignIn

class AuthViewModel: NSObject, ObservableObject {
    static let shared = AuthViewModel()
    
    @Published var isLoggedIn = false
    @Published var currentUser: User?
    @Published var errorMessage = ""
    @Published var isLoading = false
    @Published var showUsernameRequiredPopup = false
    @Published var showPaywallAfterSignup = false
    @Published var needsOnboarding = false
    
    private let supabase = SupabaseConfig.supabase
    private var cancellables = Set<AnyCancellable>()
    
    // Apple Sign In
    private var currentNonce: String?
    var onAppleSignInComplete: ((Bool, OnboardingData?, String?, String?) -> Void)? // (success, onboardingData, appleFirstName, appleLastName)
    var pendingOnboardingData: OnboardingData?
    @Published var appleProvidedFirstName: String?
    @Published var appleProvidedLastName: String?
    
    // Google Sign In
    var onGoogleSignInComplete: ((Bool, OnboardingData?, String?) -> Void)? // (success, onboardingData, googleName)
    var pendingGoogleOnboardingData: OnboardingData?
    
    override init() {
        super.init()
        // Kontrollera om användaren redan är inloggad vid appstart
        checkAuthStatus()
        
        // Lyssna på auth-state ändringar från Supabase
        setupAuthStateListener()
        
        // Lyssna på Pro-status ändringar från RevenueCat
        setupProStatusListener()
    }
    
    func setupAuthStateListener() {
        // Supabase hanterar automatiskt session-persistens
        // Vi behöver bara kontrollera vid appstart
        print("ℹ️ Auth state listener setup complete")
    }
    
    func setupProStatusListener() {
        // Lyssna på Pro-status ändringar från RevenueCatManager
        RevenueCatManager.shared.$isPremium
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isPremium in
                self?.updateLocalProStatus(revenueCatPremium: isPremium)
            }
            .store(in: &cancellables)
    }
    
    private func updateLocalProStatus(revenueCatPremium: Bool) {
        guard var user = currentUser else { return }
        
        // Pro status = RevenueCat OR database (allows granting Pro via database only)
        // Use RevenueCatManager.databasePro which is the fresh value from the database
        let databasePro = RevenueCatManager.shared.databasePro
        let combinedProStatus = revenueCatPremium || databasePro
        
        user.isProMember = combinedProStatus
        currentUser = user
        print("🔄 Updated local Pro status: \(combinedProStatus) (RevenueCat: \(revenueCatPremium), Database: \(databasePro))")
        
        // Only sync to database if RevenueCat says Pro (don't overwrite database-granted Pro)
        if revenueCatPremium {
            Task {
                do {
                    try await ProfileService.shared.updateProStatus(userId: user.id, isPro: true)
                    print("✅ Pro status synced to database: true")
                } catch {
                    print("❌ Error syncing Pro status to database: \(error)")
                }
            }
        }
    }
    
    /// Refresh Pro status from database (useful after granting Pro via Supabase)
    func refreshProStatusFromDatabase() async {
        guard let userId = currentUser?.id else { return }
        
        do {
            if let profile = try await ProfileService.shared.fetchUserProfile(userId: userId) {
                await MainActor.run {
                    var user = self.currentUser
                    let revenueCatPro = RevenueCatManager.shared.isPremium
                    let databasePro = profile.isProMember
                    
                    // Update RevenueCatManager's database Pro status
                    RevenueCatManager.shared.updateDatabaseProStatus(databasePro)
                    
                    user?.isProMember = revenueCatPro || databasePro
                    self.currentUser = user
                    print("🔄 Refreshed Pro status from database: \(user?.isProMember ?? false) (RevenueCat: \(revenueCatPro), Database: \(databasePro))")
                }
            }
        } catch {
            print("❌ Error refreshing Pro status: \(error)")
        }
    }
    
    func checkAuthStatus() {
        Task {
            do {
                // Kontrollera om det finns en aktiv session
                let session = try await supabase.auth.session
                
                print("✅ Found existing session for user: \(session.user.id)")
                
                // Hämta profil-data från Supabase
                if let profile = try await ProfileService.shared.fetchUserProfile(userId: session.user.id.uuidString) {
                    
                    // Check if onboarding was completed
                    if !profile.onboardingCompleted {
                        // User has a session + profile but never finished onboarding
                        print("⚠️ User has profile but onboarding not completed, showing onboarding")
                        await MainActor.run {
                            self.currentUser = profile
                            self.needsOnboarding = true
                            self.isLoggedIn = false
                            self.isLoading = false
                            
                            // Set current user for recent exercises (personalized)
                            RecentExerciseStore.shared.setUser(userId: profile.id)
                        }
                        await RevenueCatManager.shared.logInFor(appUserId: session.user.id.uuidString)
                        return
                    }
                    
                    // IMPORTANT: Update database Pro status BEFORE RevenueCat login
                    // to ensure combined status is correct
                    await MainActor.run {
                        self.currentUser = profile
                        self.isLoggedIn = true
                        self.prefetchAvatar(url: profile.avatarUrl)
                        
                        // Set current user for scan limit managers
                        AIScanLimitManager.shared.setCurrentUser(userId: profile.id)
                        BarcodeScanLimitManager.shared.setCurrentUser(userId: profile.id)
                        
                        // Set current user for streak manager (per-user streaks)
                        StreakManager.shared.setUser(userId: profile.id)
                        
                        // Set current user for gym location tracking
                        GymLocationManager.shared.setUser(userId: profile.id)
                        
                        // Set current user for recent exercises (personalized)
                        RecentExerciseStore.shared.setUser(userId: profile.id)
                        
                        // Update database Pro status in RevenueCatManager FIRST
                        RevenueCatManager.shared.updateDatabaseProStatus(profile.isProMember)
                        
                        // Check if user has a valid username (not "Användare" or empty)
                        let hasValidUsername = !profile.name.isEmpty && profile.name != "Användare"
                        
                        if !hasValidUsername {
                            self.showUsernameRequiredPopup = true
                        }
                        
                        print("✅ User automatically logged in: \(profile.name)")
                        print("📊 Database Pro status from profile: \(profile.isProMember)")
                    }
                    
                    // Now login to RevenueCat (after databasePro is already set)
                    await RevenueCatManager.shared.logInFor(appUserId: session.user.id.uuidString)
                } else {
                    // Ingen profil hittades – behandla som raderat/disabled konto
                    try? await supabase.auth.signOut()
                    await MainActor.run {
                        self.isLoggedIn = false
                        self.currentUser = nil
                        self.errorMessage = "Kontot är raderat eller saknas."
                    }
                }
            } catch {
                print("ℹ️ No existing session found: \(error)")
                DispatchQueue.main.async {
                    self.isLoggedIn = false
                    self.currentUser = nil
                }
            }
        }
    }
    
    // MARK: - Password Reset
    
    func resetPassword(email: String) async -> (success: Bool, message: String) {
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !trimmedEmail.isEmpty else {
            return (false, "Ange din e-postadress")
        }
        
        guard trimmedEmail.range(of: #"^\S+@\S+\.\S+$"#, options: .regularExpression) != nil else {
            return (false, "Ogiltig e-postadress")
        }
        
        do {
            try await supabase.auth.resetPasswordForEmail(trimmedEmail)
            return (true, "Vi har skickat ett mejl till \(trimmedEmail) med instruktioner för att återställa ditt lösenord.")
        } catch {
            print("❌ Password reset failed: \(error)")
            return (false, "Kunde inte skicka återställningsmejl. Kontrollera att e-postadressen är korrekt.")
        }
    }
    
    func login(email: String, password: String) {
        isLoading = true
        errorMessage = ""
        
        Task {
            do {
                let session = try await supabase.auth.signIn(email: email, password: password)
                
                // Hämta profil-data från Supabase
                if let profile = try await ProfileService.shared.fetchUserProfile(userId: session.user.id.uuidString) {
                    DispatchQueue.main.async {
                        self.currentUser = profile
                        self.isLoggedIn = true
                        self.isLoading = false
                        self.prefetchAvatar(url: profile.avatarUrl)
                        
                        // Set current user for scan limit managers
                        AIScanLimitManager.shared.setCurrentUser(userId: profile.id)
                        BarcodeScanLimitManager.shared.setCurrentUser(userId: profile.id)
                        
                        // Set current user for streak manager (per-user streaks)
                        StreakManager.shared.setUser(userId: profile.id)
                        
                        // Set current user for gym location tracking
                        GymLocationManager.shared.setUser(userId: profile.id)
                        
                        // Set current user for recent exercises (personalized)
                        RecentExerciseStore.shared.setUser(userId: profile.id)
                    }
                    await RevenueCatManager.shared.logInFor(appUserId: session.user.id.uuidString)
                } else {
                    // Ingen profil hittades – behandla som raderat/disabled konto
                    try? await supabase.auth.signOut()
                    await MainActor.run {
                        self.isLoggedIn = false
                        self.currentUser = nil
                        self.isLoading = false
                        self.errorMessage = "Kontot är raderat eller saknas."
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    self.errorMessage = "Login misslyckades: \(error.localizedDescription)"
                    self.isLoading = false
                }
            }
        }
    }
    
    func signup(name: String,
                username: String,
                email: String,
                password: String,
                confirmPassword: String,
                onboardingData: OnboardingData? = nil) {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedUsername = username.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !trimmedName.isEmpty else {
            errorMessage = "Namnet kan inte vara tomt."
            return
        }
        guard trimmedUsername.count >= 2 else {
            errorMessage = "Välj ett användarnamn (minst 2 tecken)."
            return
        }
        guard trimmedEmail.range(of: #"^\S+@\S+\.\S+$"#, options: .regularExpression) != nil else {
            errorMessage = "Ogiltig e-postadress."
            return
        }
        guard password.count >= 6 else {
            errorMessage = "Lösenordet måste vara minst 6 tecken."
            return
        }
        guard password == confirmPassword else {
            errorMessage = "Lösenorden matchar inte."
            return
        }
        
        isLoading = true
        errorMessage = ""
        
        Task {
            do {
                let response = try await supabase.auth.signUp(
                    email: trimmedEmail,
                    password: password
                )
                
                let userId = response.user.id.uuidString
                
                let placeholderUsername = "user-\(userId.prefix(6))"
                var newUser = User(id: userId, name: placeholderUsername, email: trimmedEmail)
                try await ProfileService.shared.createUserProfile(newUser)
                
                if let onboardingData {
                    _ = await ProfileService.shared.applyOnboardingData(userId: userId, data: onboardingData)
                } else {
                    try await ProfileService.shared.updateUsername(userId: userId, username: trimmedUsername)
                }
                
                if var profile = try await ProfileService.shared.fetchUserProfile(userId: userId) {
                    profile.name = trimmedUsername
                    newUser = profile
                }
                
                await RevenueCatManager.shared.logInFor(appUserId: userId)
                
                await MainActor.run {
                    self.currentUser = newUser
                    // DON'T set isLoggedIn = true here - onboarding must complete first
                    self.isLoading = false
                    self.prefetchAvatar(url: newUser.avatarUrl)
                    
                    // Set current user for recent exercises (personalized)
                    RecentExerciseStore.shared.setUser(userId: newUser.id)
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = "Signup misslyckades: \(error.localizedDescription)"
                    self.isLoading = false
                }
            }
        }
    }
    
    func logout() {
        Task {
            do {
                do {
                    try await supabase.auth.signOut()
                } catch {
                    // If there's no active session, treat as logged out
                    if (error as NSError).localizedDescription.contains("sessionMissing") {
                        print("ℹ️ signOut: sessionMissing – treating as already logged out")
                    } else {
                        throw error
                    }
                }
                await RevenueCatManager.shared.logOutRevenueCat()
                await MainActor.run {
                    // Clear local state and caches regardless
                    AppCacheManager.shared.clearAllCache()
                    
                    // Clear scan limit managers
                    AIScanLimitManager.shared.setCurrentUser(userId: nil)
                    BarcodeScanLimitManager.shared.setCurrentUser(userId: nil)
                    
                    // Clear streak manager user
                    StreakManager.shared.clearUser()
                    
                    // Clear gym location manager
                    GymLocationManager.shared.clearUser()
                    
                    // Clear recent exercises store
                    RecentExerciseStore.shared.clearUser()
                    
                    self.isLoggedIn = false
                    self.currentUser = nil
                    print("✅ User logged out successfully (graceful)")
                }
            } catch {
                await MainActor.run {
                    // Even if network signOut fails, force local logout so user isn't stuck
                    AppCacheManager.shared.clearAllCache()
                    
                    // Clear scan limit managers
                    AIScanLimitManager.shared.setCurrentUser(userId: nil)
                    BarcodeScanLimitManager.shared.setCurrentUser(userId: nil)
                    
                    // Clear streak manager user
                    StreakManager.shared.clearUser()
                    
                    // Clear gym location manager
                    GymLocationManager.shared.clearUser()
                    
                    // Clear recent exercises store
                    RecentExerciseStore.shared.clearUser()
                    
                    self.isLoggedIn = false
                    self.currentUser = nil
                    self.errorMessage = "Logout: \(error.localizedDescription) – fortsätter lokalt"
                    print("❌ Logout error (forced local logout): \(error)")
                }
            }
        }
    }
    
    // MARK: - Apple Sign In
    
    func signInWithApple(onboardingData: OnboardingData? = nil) {
        isLoading = true
        errorMessage = ""
        pendingOnboardingData = onboardingData
        
        let nonce = randomNonceString()
        currentNonce = nonce
        
        let appleIDProvider = ASAuthorizationAppleIDProvider()
        let request = appleIDProvider.createRequest()
        request.requestedScopes = [.fullName, .email]
        request.nonce = sha256(nonce)
        
        let authorizationController = ASAuthorizationController(authorizationRequests: [request])
        authorizationController.delegate = self
        authorizationController.presentationContextProvider = self
        authorizationController.performRequests()
    }
    
    private func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        var randomBytes = [UInt8](repeating: 0, count: length)
        let errorCode = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
        if errorCode != errSecSuccess {
            fatalError("Unable to generate nonce. SecRandomCopyBytes failed with OSStatus \(errorCode)")
        }
        
        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        let nonce = randomBytes.map { byte in
            charset[Int(byte) % charset.count]
        }
        return String(nonce)
    }
    
    private func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashedData = SHA256.hash(data: inputData)
        let hashString = hashedData.compactMap {
            String(format: "%02x", $0)
        }.joined()
        return hashString
    }
    
    // MARK: - Google Sign In
    
    func signInWithGoogle(onboardingData: OnboardingData? = nil) {
        isLoading = true
        errorMessage = ""
        pendingGoogleOnboardingData = onboardingData
        
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = windowScene.windows.first?.rootViewController else {
            DispatchQueue.main.async {
                self.errorMessage = "Kunde inte visa Google-inloggning"
                self.isLoading = false
            }
            return
        }
        
        GIDSignIn.sharedInstance.signIn(withPresenting: rootViewController) { [weak self] result, error in
            guard let self = self else { return }
            
            if let error = error {
                DispatchQueue.main.async {
                    self.errorMessage = "Google Sign In misslyckades: \(error.localizedDescription)"
                    self.isLoading = false
                }
                return
            }
            
            guard let user = result?.user,
                  let idToken = user.idToken?.tokenString else {
                DispatchQueue.main.async {
                    self.errorMessage = "Kunde inte hämta Google-token"
                    self.isLoading = false
                }
                return
            }
            
            let accessToken = user.accessToken.tokenString
            let googleName = user.profile?.givenName
            
            Task {
                do {
                    // Step 1: Sign in with Supabase using Google ID token
                    print("🔐 [Google] Step 1: Signing in with Supabase ID token...")
                    let session: Session
                    do {
                        session = try await self.supabase.auth.signInWithIdToken(
                            credentials: .init(
                                provider: .google,
                                idToken: idToken,
                                accessToken: accessToken
                            )
                        )
                        print("✅ [Google] Step 1 success: Auth session created, userId: \(session.user.id.uuidString)")
                    } catch {
                        print("❌ [Google] Step 1 FAILED - signInWithIdToken error: \(error)")
                        print("❌ [Google] Error type: \(type(of: error))")
                        print("❌ [Google] Error details: \(String(describing: error))")
                        await MainActor.run {
                            self.errorMessage = "Google-inloggning misslyckades (auth): \(error.localizedDescription)\n\nDetaljer: \(String(describing: error))"
                            self.isLoading = false
                            self.onGoogleSignInComplete?(false, nil, nil)
                        }
                        return
                    }
                    
                    let userId = session.user.id.uuidString
                    let email = session.user.email ?? ""
                    
                    // Step 2: Check if profile exists
                    print("🔍 [Google] Step 2: Checking existing profile for userId: \(userId)")
                    let existingProfile: User?
                    do {
                        existingProfile = try await ProfileService.shared.fetchUserProfile(userId: userId)
                        print("✅ [Google] Step 2 success: Profile exists = \(existingProfile != nil), onboardingCompleted = \(existingProfile?.onboardingCompleted ?? false)")
                    } catch {
                        print("⚠️ [Google] Step 2 WARNING - fetchUserProfile error: \(error)")
                        print("⚠️ [Google] Continuing with existingProfile = nil")
                        existingProfile = nil
                    }
                    
                    if let profile = existingProfile, profile.onboardingCompleted {
                        // Existing user who completed onboarding - just log in
                        print("✅ [Google] Existing user with completed onboarding - logging in")
                        await MainActor.run {
                            self.currentUser = profile
                            self.isLoggedIn = true
                            self.isLoading = false
                            
                            // Set current user for recent exercises (personalized)
                            RecentExerciseStore.shared.setUser(userId: profile.id)
                            
                            self.onGoogleSignInComplete?(true, nil, nil)
                        }
                    } else {
                        // New user OR user who didn't finish onboarding - start onboarding
                        var userForOnboarding: User
                        if let profile = existingProfile {
                            // Profile exists but onboarding not completed
                            print("🔄 [Google] Profile exists but onboarding not completed")
                            userForOnboarding = profile
                        } else {
                            // Brand new user - create profile
                            print("🆕 [Google] Step 3: Creating new profile...")
                            let defaultName = googleName ?? email.components(separatedBy: "@").first ?? "Användare"
                            userForOnboarding = User(id: userId, name: defaultName, email: email)
                            do {
                                try await ProfileService.shared.createUserProfile(userForOnboarding)
                                print("✅ [Google] Step 3 success: Profile created")
                            } catch {
                                print("❌ [Google] Step 3 FAILED - createUserProfile error: \(error)")
                                print("❌ [Google] Error type: \(type(of: error))")
                                print("❌ [Google] Error details: \(String(describing: error))")
                                await MainActor.run {
                                    self.errorMessage = "Google-inloggning misslyckades (profil): \(error.localizedDescription)\n\nDetaljer: \(String(describing: error))"
                                    self.isLoading = false
                                    self.onGoogleSignInComplete?(false, nil, nil)
                                }
                                return
                            }
                        }
                        
                        await RevenueCatManager.shared.logInFor(appUserId: userId)
                        
                        await MainActor.run {
                            self.currentUser = userForOnboarding
                            // DON'T set isLoggedIn = true here - wait for onboarding to complete
                            self.isLoading = false
                            
                            // Set current user for recent exercises (personalized)
                            RecentExerciseStore.shared.setUser(userId: userForOnboarding.id)
                            
                            // Trigger onboarding for new/incomplete users
                            self.onGoogleSignInComplete?(true, self.pendingGoogleOnboardingData, googleName)
                        }
                    }
                    
                } catch {
                    print("❌ [Google] Unexpected error: \(error)")
                    print("❌ [Google] Error type: \(type(of: error))")
                    await MainActor.run {
                        self.errorMessage = "Google-inloggning misslyckades: \(error.localizedDescription)\n\nDetaljer: \(String(describing: error))"
                        self.isLoading = false
                        self.onGoogleSignInComplete?(false, nil, nil)
                    }
                }
            }
        }
    }
    
    func loadUserProfile() async {
        guard let userId = currentUser?.id else {
            print("❌ No user ID available for profile reload")
            return
        }
        
        do {
            if let profile = try await ProfileService.shared.fetchUserProfile(userId: userId) {
                DispatchQueue.main.async {
                    self.currentUser = profile
                    print("✅ User profile reloaded: \(profile.name), XP: \(profile.currentXP)")
                    self.prefetchAvatar(url: profile.avatarUrl)
                }
            }
        } catch {
            print("❌ Error reloading user profile: \(error)")
        }
    }
    
    func updateProfileImage(image: UIImage) {
        guard let currentUser = currentUser else { 
            print("❌ No current user found")
            DispatchQueue.main.async {
                self.errorMessage = "Ingen användare hittades"
            }
            return 
        }
        
        print("🔄 Starting profile image update for user: \(currentUser.id)")
        
        // Visa loading state
        DispatchQueue.main.async {
            self.errorMessage = ""
        }
        
        Task {
            do {
                // Konvertera UIImage till Data
                guard let imageData = image.jpegData(compressionQuality: 0.8) else {
                    print("❌ Could not convert image to JPEG data")
                    DispatchQueue.main.async {
                        self.errorMessage = "Kunde inte konvertera bilden"
                    }
                    return
                }
                
                print("✅ Image converted to data, size: \(imageData.count) bytes")
                let publicURL = try await ProfileService.shared.updateUserAvatar(userId: currentUser.id, imageData: imageData)
                
                DispatchQueue.main.async {
                    self.currentUser?.avatarUrl = publicURL
                    print("✅ Local user data updated")
                    self.prefetchAvatar(url: publicURL)
                    
                    // Skicka notifikation för att uppdatera UI
                    NotificationCenter.default.post(name: .profileImageUpdated, object: publicURL)
                }
                
            } catch {
                print("❌ Error updating profile image: \(error)")
                DispatchQueue.main.async {
                    self.errorMessage = "Kunde inte uppdatera profilbild: \(error.localizedDescription)"
                }
            }
        }
    }
    
    private func prefetchAvatar(url: String?) {
        guard let url = url, !url.isEmpty else { return }
        ImageCacheManager.shared.prefetch(urls: [url])
    }
}

// MARK: - Apple Sign In Delegate
extension AuthViewModel: ASAuthorizationControllerDelegate {
    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential,
              let nonce = currentNonce,
              let appleIDToken = appleIDCredential.identityToken,
              let idTokenString = String(data: appleIDToken, encoding: .utf8) else {
            DispatchQueue.main.async {
                self.errorMessage = "Apple Sign In misslyckades"
                self.isLoading = false
            }
            return
        }
        
        // Get user info from Apple
        let fullName = appleIDCredential.fullName
        let email = appleIDCredential.email
        let displayName = [fullName?.givenName, fullName?.familyName]
            .compactMap { $0 }
            .joined(separator: " ")
        
        Task {
            do {
                // Sign in with Supabase using Apple ID token
                let session = try await supabase.auth.signInWithIdToken(
                    credentials: .init(
                        provider: .apple,
                        idToken: idTokenString,
                        nonce: nonce
                    )
                )
                
                let userId = session.user.id.uuidString
                
                // Get the Apple-provided name
                let appleFirstName = fullName?.givenName
                let appleLastName = fullName?.familyName
                
                // Check if profile exists and whether onboarding was completed
                let existingProfile = try? await ProfileService.shared.fetchUserProfile(userId: userId)
                
                if let profile = existingProfile, profile.onboardingCompleted {
                    // Existing user who completed onboarding - just log in
                    await MainActor.run {
                        self.currentUser = profile
                        self.isLoggedIn = true
                        self.isLoading = false
                        self.prefetchAvatar(url: profile.avatarUrl)
                        
                        // Set current user for scan limit managers
                        AIScanLimitManager.shared.setCurrentUser(userId: profile.id)
                        BarcodeScanLimitManager.shared.setCurrentUser(userId: profile.id)
                        
                        // Set current user for streak manager (per-user streaks)
                        StreakManager.shared.setUser(userId: profile.id)
                        
                        // Set current user for gym location tracking
                        GymLocationManager.shared.setUser(userId: profile.id)
                        
                        // Set current user for recent exercises (personalized)
                        RecentExerciseStore.shared.setUser(userId: profile.id)
                        
                        RevenueCatManager.shared.updateDatabaseProStatus(profile.isProMember)
                        
                        // Check if user has a valid username
                        let hasValidUsername = !profile.name.isEmpty && 
                                              profile.name != "Användare" &&
                                              !profile.name.hasPrefix("user-")
                        
                        if !hasValidUsername {
                            self.showUsernameRequiredPopup = true
                        }
                        
                        self.onAppleSignInComplete?(true, nil, nil, nil)
                    }
                    await RevenueCatManager.shared.logInFor(appUserId: userId)
                } else {
                    // New user OR user who didn't finish onboarding - start onboarding
                    var userForOnboarding: User
                    
                    if let profile = existingProfile {
                        // Profile exists but onboarding not completed
                        userForOnboarding = profile
                    } else {
                        // Brand new user - create profile with Apple's provided name
                        let appleFullName = [appleFirstName, appleLastName]
                            .compactMap { $0 }
                            .joined(separator: " ")
                        
                        let initialUsername = appleFullName.isEmpty ? "user-\(userId.prefix(6))" : appleFullName
                        
                        userForOnboarding = User(
                            id: userId,
                            name: initialUsername,
                            email: email ?? session.user.email ?? ""
                        )
                        
                        try await ProfileService.shared.createUserProfile(userForOnboarding)
                        
                        // If Apple provided a name, also update the username in profiles table
                        if !appleFullName.isEmpty {
                            try? await ProfileService.shared.updateUsername(userId: userId, username: appleFullName)
                        }
                        
                        // Fetch updated profile
                        if let profile = try await ProfileService.shared.fetchUserProfile(userId: userId) {
                            userForOnboarding = profile
                        }
                    }
                    
                    await RevenueCatManager.shared.logInFor(appUserId: userId)
                    
                    await MainActor.run {
                        self.currentUser = userForOnboarding
                        self.appleProvidedFirstName = appleFirstName
                        self.appleProvidedLastName = appleLastName
                        // DON'T set isLoggedIn = true here - wait for onboarding to complete
                        self.isLoading = false
                        self.prefetchAvatar(url: userForOnboarding.avatarUrl)
                        
                        // Set current user for recent exercises (personalized)
                        RecentExerciseStore.shared.setUser(userId: userForOnboarding.id)
                        
                        // Signal that this user needs onboarding, pass Apple name
                        self.onAppleSignInComplete?(true, OnboardingData(), appleFirstName, appleLastName)
                    }
                }
                
                await MainActor.run {
                    self.pendingOnboardingData = nil
                }
                
            } catch {
                await MainActor.run {
                    self.errorMessage = "Apple Sign In misslyckades: \(error.localizedDescription)"
                    self.isLoading = false
                    self.onAppleSignInComplete?(false, nil, nil, nil)
                }
            }
        }
    }
    
    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        DispatchQueue.main.async {
            if let authError = error as? ASAuthorizationError {
                switch authError.code {
                case .canceled:
                    self.errorMessage = ""
                case .failed:
                    self.errorMessage = "Apple Sign In misslyckades"
                case .invalidResponse:
                    self.errorMessage = "Ogiltigt svar från Apple"
                case .notHandled:
                    self.errorMessage = "Apple Sign In kunde inte hanteras"
                case .unknown:
                    self.errorMessage = "Ett okänt fel uppstod"
                case .notInteractive:
                    self.errorMessage = "Apple Sign In kräver interaktion"
                @unknown default:
                    self.errorMessage = "Apple Sign In fel"
                }
            } else {
                self.errorMessage = "Apple Sign In fel: \(error.localizedDescription)"
            }
            self.isLoading = false
        }
    }
}

// MARK: - Presentation Context Provider
extension AuthViewModel: ASAuthorizationControllerPresentationContextProviding {
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = scene.windows.first else {
            return ASPresentationAnchor()
        }
        return window
    }
}
