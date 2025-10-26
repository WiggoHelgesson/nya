import Foundation
import SwiftUI
import Combine
import Supabase
import UIKit
import AuthenticationServices

class AuthViewModel: NSObject, ObservableObject {
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
                } else {
                    // Fallback om profil inte finns
                    DispatchQueue.main.async {
                        self.currentUser = User(
                            id: session.user.id.uuidString,
                            name: session.user.email?.prefix(while: { $0 != "@" }).capitalized ?? "Användare",
                            email: session.user.email ?? ""
                        )
                        self.isLoggedIn = true
                        print("✅ User automatically logged in (fallback): \(self.currentUser?.name ?? "Unknown")")
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
                } else {
                    // Fallback om profil inte finns
                    DispatchQueue.main.async {
                        self.currentUser = User(
                            id: session.user.id.uuidString,
                            name: email.prefix(while: { $0 != "@" }).capitalized,
                            email: email
                        )
                        self.isLoggedIn = true
                        self.isLoading = false
                        
                        // Visa review popup efter lyckad inloggning
                        ReviewManager.shared.requestReviewIfNeeded()
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
    
    func signup(name: String, username: String, email: String, password: String, confirmPassword: String) {
        isLoading = true
        errorMessage = ""
        
        // Validering
        if name.isEmpty {
            errorMessage = "Namnet kan inte vara tomt"
            isLoading = false
            return
        }
        if username.isEmpty {
            errorMessage = "Användarnamnet kan inte vara tomt"
            isLoading = false
            return
        }
        if !email.contains("@") {
            errorMessage = "Ogiltig email-adress"
            isLoading = false
            return
        }
        if password.count < 6 {
            errorMessage = "Lösenordet måste vara minst 6 tecken"
            isLoading = false
            return
        }
        if password != confirmPassword {
            errorMessage = "Lösenorden matchar inte"
            isLoading = false
            return
        }
        
        Task {
            do {
                let session = try await supabase.auth.signUp(email: email, password: password)
                
                // Hämta profil-data från Supabase
                if let profile = try await ProfileService.shared.fetchUserProfile(userId: session.user.id.uuidString) {
                    DispatchQueue.main.async {
                        self.currentUser = profile
                        self.isLoggedIn = true
                        self.isLoading = false
                        // Visa paywall efter lyckad registrering
                        self.showPaywallAfterSignup = true
                    }
                } else {
                    // Fallback om profil inte finns
                    DispatchQueue.main.async {
                        self.currentUser = User(
                            id: session.user.id.uuidString,
                            name: username,  // Use username as the name
                            email: email
                        )
                        self.isLoggedIn = true
                        self.isLoading = false
                        // Visa paywall efter lyckad registrering
                        self.showPaywallAfterSignup = true
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    self.errorMessage = "Signup misslyckades: \(error.localizedDescription)"
                    self.isLoading = false
                }
            }
        }
    }
    
    func logout() {
        Task {
            do {
                try await supabase.auth.signOut()
                
                DispatchQueue.main.async {
                    self.isLoggedIn = false
                    self.currentUser = nil
                    print("✅ User logged out successfully")
                }
            } catch {
                DispatchQueue.main.async {
                    self.errorMessage = "Logout misslyckades: \(error.localizedDescription)"
                    print("❌ Logout error: \(error)")
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
    
    func signInWithApple() {
        isLoading = true
        errorMessage = ""
        
        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.requestedScopes = [.fullName, .email]
        
        let authorizationController = ASAuthorizationController(authorizationRequests: [request])
        authorizationController.delegate = self
        authorizationController.presentationContextProvider = self
        authorizationController.performRequests()
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
                
                // Skapa unikt filnamn med timestamp för att undvika cache-problem
                let timestamp = Int(Date().timeIntervalSince1970)
                let fileName = "\(currentUser.id)_avatar_\(timestamp).jpg"
                print("📁 Uploading file: \(fileName)")
                
                // Ladda upp till Supabase Storage
                let filePath = "avatars/\(fileName)"
                
                // Kontrollera om bucket finns, skapa om den inte finns
                do {
                    _ = try await supabase.storage.from("avatars").upload(
                        filePath,
                        data: imageData,
                        options: FileOptions(contentType: "image/jpeg")
                    )
                } catch {
                    print("❌ Upload failed, trying to create bucket first: \(error)")
                    // Försök skapa bucket om den inte finns
                    try await supabase.storage.createBucket("avatars", options: BucketOptions(public: true))
                    print("✅ Created avatars bucket")
                    
                    // Försök upload igen
                    _ = try await supabase.storage.from("avatars").upload(
                        filePath,
                        data: imageData,
                        options: FileOptions(contentType: "image/jpeg")
                    )
                }
                
                print("✅ Image uploaded to storage: \(filePath)")
                
                // Hämta public URL
                let publicURL = try supabase.storage.from("avatars").getPublicURL(path: filePath)
                print("🔗 Public URL: \(publicURL.absoluteString)")
                
                // Uppdatera användarens avatar_url i databasen
                try await supabase
                    .from("profiles")
                    .update(["avatar_url": publicURL.absoluteString])
                    .eq("id", value: currentUser.id)
                    .execute()
                
                print("✅ Database updated with new avatar URL")
                
                // Uppdatera lokal användardata och trigga UI-uppdatering
                DispatchQueue.main.async {
                    self.currentUser?.avatarUrl = publicURL.absoluteString
                    print("✅ Local user data updated")
                    
                    // Skicka notifikation för att uppdatera UI
                    NotificationCenter.default.post(name: .profileImageUpdated, object: publicURL.absoluteString)
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

// MARK: - Apple Sign In Delegate
extension AuthViewModel: ASAuthorizationControllerDelegate {
    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            DispatchQueue.main.async {
                self.errorMessage = "Apple Sign-In misslyckades: Ogiltig autentisering"
                self.isLoading = false
            }
            return
        }
        
        guard let identityToken = appleIDCredential.identityToken,
              let identityTokenString = String(data: identityToken, encoding: .utf8) else {
            DispatchQueue.main.async {
                self.errorMessage = "Apple Sign-In misslyckades: Ingen identitetstoken"
                self.isLoading = false
            }
            return
        }
        
        Task {
            do {
                let session = try await supabase.auth.signInWithIdToken(
                    credentials: .init(
                        provider: .apple,
                        idToken: identityTokenString,
                        nonce: nil
                    )
                )
                
                print("✅ Apple Sign-In successful for user: \(session.user.id)")
                
                // Hämta profil-data från Supabase
                if let profile = try await ProfileService.shared.fetchUserProfile(userId: session.user.id.uuidString) {
                    DispatchQueue.main.async {
                        self.currentUser = profile
                        self.isLoggedIn = true
                        self.isLoading = false
                        print("✅ User logged in with Apple: \(profile.name)")
                        
                        // Visa review popup efter lyckad inloggning
                        ReviewManager.shared.requestReviewIfNeeded()
                    }
                } else {
                    // Skapa profil för ny Apple-användare
                    let fullName = appleIDCredential.fullName
                    let displayName = [fullName?.givenName, fullName?.familyName]
                        .compactMap { $0 }
                        .joined(separator: " ")
                    
                    let userName = displayName.isEmpty ? "Apple User" : displayName
                    
                    DispatchQueue.main.async {
                        self.currentUser = User(
                            id: session.user.id.uuidString,
                            name: userName,
                            email: session.user.email ?? ""
                        )
                        self.isLoggedIn = true
                        self.isLoading = false
                        print("✅ New Apple user logged in: \(userName)")
                        
                        // Visa review popup efter lyckad inloggning
                        ReviewManager.shared.requestReviewIfNeeded()
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    self.errorMessage = "Apple Sign-In misslyckades: \(error.localizedDescription)"
                    self.isLoading = false
                    print("❌ Apple Sign-In error: \(error)")
                }
            }
        }
    }
    
    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        DispatchQueue.main.async {
            self.errorMessage = "Apple Sign-In avbröts: \(error.localizedDescription)"
            self.isLoading = false
            print("❌ Apple Sign-In cancelled or failed: \(error)")
        }
    }
}

extension AuthViewModel: ASAuthorizationControllerPresentationContextProviding {
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else {
            // Fallback för simulator/test
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                return UIWindow(windowScene: windowScene)
            }
            return UIWindow()
        }
        return window
    }
}
