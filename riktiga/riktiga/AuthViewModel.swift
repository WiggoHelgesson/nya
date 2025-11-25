import Foundation
import SwiftUI
import Combine
import Supabase
import UIKit

class AuthViewModel: NSObject, ObservableObject {
    static let shared = AuthViewModel()
    
    @Published var isLoggedIn = false
    @Published var currentUser: User?
    @Published var errorMessage = ""
    @Published var isLoading = false
    @Published var showUsernameRequiredPopup = false
    @Published var showPaywallAfterSignup = false
    
    private let supabase = SupabaseConfig.supabase
    private var cancellables = Set<AnyCancellable>()
    
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
                self?.updateLocalProStatus(isPremium: isPremium)
            }
            .store(in: &cancellables)
    }
    
    private func updateLocalProStatus(isPremium: Bool) {
        guard var user = currentUser else { return }
        user.isProMember = isPremium
        currentUser = user
        print("🔄 Updated local Pro status: \(isPremium)")
        
        // Also update the profile in the database to keep it in sync
        Task {
            do {
                try await ProfileService.shared.updateProStatus(userId: user.id, isPro: isPremium)
                print("✅ Pro status synced to database: \(isPremium)")
            } catch {
                print("❌ Error syncing Pro status to database: \(error)")
            }
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
                    DispatchQueue.main.async {
                        self.currentUser = profile
                        self.isLoggedIn = true
                        
                        // Check if user has a valid username (not "Användare" or empty)
                        let hasValidUsername = !profile.name.isEmpty && profile.name != "Användare"
                        
                        if !hasValidUsername {
                            self.showUsernameRequiredPopup = true
                        }
                        
                        print("✅ User automatically logged in: \(profile.name)")
                    }
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
                        
                        // Visa review popup efter lyckad inloggning
                        ReviewManager.shared.requestReviewIfNeeded()
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
                    self.isLoggedIn = true
                    self.isLoading = false
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
                    self.isLoggedIn = false
                    self.currentUser = nil
                    print("✅ User logged out successfully (graceful)")
                }
            } catch {
                await MainActor.run {
                    // Even if network signOut fails, force local logout so user isn't stuck
                    AppCacheManager.shared.clearAllCache()
                    self.isLoggedIn = false
                    self.currentUser = nil
                    self.errorMessage = "Logout: \(error.localizedDescription) – fortsätter lokalt"
                    print("❌ Logout error (forced local logout): \(error)")
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
}
