import Foundation
import SwiftUI
import Combine
import Supabase

class AuthViewModel: ObservableObject {
    @Published var isLoggedIn = false
    @Published var currentUser: User?
    @Published var errorMessage = ""
    @Published var isLoading = false
    
    private let supabase = SupabaseConfig.supabase
    
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
    
    func signup(name: String, email: String, password: String, confirmPassword: String) {
        isLoading = true
        errorMessage = ""
        
        // Validering
        if name.isEmpty {
            errorMessage = "Namnet kan inte vara tomt"
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
                    }
                } else {
                    // Fallback om profil inte finns
                    DispatchQueue.main.async {
                        self.currentUser = User(
                            id: session.user.id.uuidString,
                            name: name,
                            email: email
                        )
                        self.isLoggedIn = true
                        self.isLoading = false
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
                }
            } catch {
                DispatchQueue.main.async {
                    self.errorMessage = "Logout misslyckades: \(error.localizedDescription)"
                }
            }
        }
    }
    
    func updateProfileImage(image: UIImage) {
        guard let currentUser = currentUser else { return }
        
        Task {
            do {
                // Konvertera UIImage till Data
                guard let imageData = image.jpegData(compressionQuality: 0.8) else {
                    DispatchQueue.main.async {
                        self.errorMessage = "Kunde inte konvertera bilden"
                    }
                    return
                }
                
                // Skapa unikt filnamn
                let fileName = "\(currentUser.id)_avatar.jpg"
                
                // Ladda upp till Supabase Storage
                let filePath = "avatars/\(fileName)"
                _ = try await supabase.storage.from("avatars").upload(
                    path: filePath,
                    file: imageData,
                    options: FileOptions(contentType: "image/jpeg")
                )
                
                // Hämta public URL
                let publicURL = try supabase.storage.from("avatars").getPublicURL(path: filePath)
                
                // Uppdatera användarens avatar_url i databasen
                try await supabase
                    .from("profiles")
                    .update(["avatar_url": publicURL.absoluteString])
                    .eq("id", value: currentUser.id)
                    .execute()
                
                // Uppdatera lokal användardata
                DispatchQueue.main.async {
                    self.currentUser?.avatarUrl = publicURL.absoluteString
                }
                
            } catch {
                DispatchQueue.main.async {
                    self.errorMessage = "Kunde inte uppdatera profilbild: \(error.localizedDescription)"
                }
            }
        }
    }
}
