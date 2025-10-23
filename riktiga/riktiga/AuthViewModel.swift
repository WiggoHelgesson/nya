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
}
