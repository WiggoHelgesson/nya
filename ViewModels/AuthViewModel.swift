import Foundation

class AuthViewModel: ObservableObject {
    @Published var isLoggedIn = false
    @Published var currentUser: User?
    @Published var errorMessage = ""
    
    func login(email: String, password: String) {
        // Simulerad login - i en riktigt app skulle detta anropa en backend API
        if email.contains("@") && password.count >= 6 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.currentUser = User(id: UUID().uuidString, name: email.prefix(while: { $0 != "@" }).capitalized, email: email)
                self.isLoggedIn = true
            }
        } else {
            errorMessage = "Ogiltig email eller lösenord (min 6 tecken)"
        }
    }
    
    func signup(name: String, email: String, password: String, confirmPassword: String) {
        // Validering
        if name.isEmpty {
            errorMessage = "Namnet kan inte vara tomt"
            return
        }
        if !email.contains("@") {
            errorMessage = "Ogiltig email-adress"
            return
        }
        if password.count < 6 {
            errorMessage = "Lösenordet måste vara minst 6 tecken"
            return
        }
        if password != confirmPassword {
            errorMessage = "Lösenorden matchar inte"
            return
        }
        
        // Simulerad signup - i en riktigt app skulle detta anropa en backend API
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.currentUser = User(id: UUID().uuidString, name: name, email: email)
            self.isLoggedIn = true
        }
    }
    
    func logout() {
        isLoggedIn = false
        currentUser = nil
    }
}
