import SwiftUI

struct AuthenticationView: View {
    @State private var isLoginMode = true
    @EnvironmentObject var authViewModel: AuthViewModel
    
    var body: some View {
        ZStack {
            // Vit bakgrund
            Color.white
                .ignoresSafeArea()
            
            VStack(spacing: 20) {
                // Logo och titel
                VStack(spacing: 10) {
                    Text("up&down")
                        .font(.system(size: 48, weight: .bold))
                        .foregroundColor(Color(red: 0.1, green: 0.6, blue: 0.8))
                    Text("Din aktivitetsapp")
                        .font(.headline)
                        .foregroundColor(.gray)
                }
                .padding(.top, 40)
                
                // Bild från Xcode (Image 1)
                Image("1")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 200)
                    .padding(.vertical, 20)
                
                // Text under bilden
                VStack(spacing: 8) {
                    Text("Träna, Få belöningar")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.black)
                        .multilineTextAlignment(.center)
                }
                .padding(.bottom, 20)
                
                Spacer()
                
                // Login/Signup formulär
                VStack(spacing: 20) {
                    Picker("Välj läge", selection: $isLoginMode) {
                        Text("Logga in").tag(true)
                        Text("Skapa konto").tag(false)
                    }
                    .pickerStyle(.segmented)
                    .padding(.bottom, 20)
                    
                    if isLoginMode {
                        LoginFormView()
                            .environmentObject(authViewModel)
                    } else {
                        SignupFormView()
                            .environmentObject(authViewModel)
                    }
                }
                .padding(30)
                .background(Color.white)
                .cornerRadius(20)
                .shadow(radius: 10)
                .padding(20)
                
                Spacer()
            }
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
                if authViewModel.isLoading {
                    ProgressView()
                        .tint(.white)
                } else {
                    Text("Logga in")
                }
            }
            .frame(maxWidth: .infinity)
            .padding(12)
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color(red: 0.1, green: 0.6, blue: 0.8),
                        Color(red: 0.2, green: 0.4, blue: 0.9)
                    ]),
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .foregroundColor(.white)
            .cornerRadius(8)
            .font(.headline)
            .disabled(authViewModel.isLoading)
        }
    }
}

struct SignupFormView: View {
    @State private var name = ""
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @EnvironmentObject var authViewModel: AuthViewModel
    
    var body: some View {
        VStack(spacing: 16) {
            TextField("Namn", text: $name)
                .padding(12)
                .background(Color(.systemGray6))
                .cornerRadius(8)
            
            TextField("Email", text: $email)
                .textContentType(.emailAddress)
                .keyboardType(.emailAddress)
                .padding(12)
                .background(Color(.systemGray6))
                .cornerRadius(8)
                .autocapitalization(.none)
            
            SecureField("Lösenord", text: $password)
                .textContentType(.newPassword)
                .padding(12)
                .background(Color(.systemGray6))
                .cornerRadius(8)
            
            SecureField("Bekräfta lösenord", text: $confirmPassword)
                .textContentType(.newPassword)
                .padding(12)
                .background(Color(.systemGray6))
                .cornerRadius(8)
            
            if !authViewModel.errorMessage.isEmpty {
                Text(authViewModel.errorMessage)
                    .foregroundColor(.red)
                    .font(.caption)
            }
            
            Button(action: {
                authViewModel.signup(name: name, email: email, password: password, confirmPassword: confirmPassword)
            }) {
                if authViewModel.isLoading {
                    ProgressView()
                        .tint(.white)
                } else {
                    Text("Skapa konto")
                }
            }
            .frame(maxWidth: .infinity)
            .padding(12)
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color(red: 0.1, green: 0.6, blue: 0.8),
                        Color(red: 0.2, green: 0.4, blue: 0.9)
                    ]),
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .foregroundColor(.white)
            .cornerRadius(8)
            .font(.headline)
            .disabled(authViewModel.isLoading)
        }
    }
}

#Preview {
    AuthenticationView()
        .environmentObject(AuthViewModel())
}
