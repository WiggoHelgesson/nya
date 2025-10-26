import SwiftUI
import Supabase

struct AuthenticationView: View {
    @State private var isLoginMode = true
    @EnvironmentObject var authViewModel: AuthViewModel
    
    var body: some View {
        ZStack {
            // Vit bakgrund
            AppColors.white
                .ignoresSafeArea()
            
            VStack(spacing: 16) {
                // Bild från Xcode (Image 23)
                Image("23")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 160)
                    .cornerRadius(16)
                    .clipped()
                    .padding(.vertical, 12)
                    .padding(.top, 32)
                
                // Text under bilden - WANTZEN Style
                VStack(spacing: 2) {
                    Text("TRÄNA,")
                        .font(.system(size: 44, weight: .black))
                        .foregroundColor(.black)
                    
                    HStack(spacing: 0) {
                        Text("FÅ BELÖNINGAR")
                            .font(.system(size: 44, weight: .black))
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(AppColors.brandBlue)
                    .cornerRadius(6)
                    .rotationEffect(.degrees(-2))
                }
                .multilineTextAlignment(.center)
                .padding(.bottom, 12)
                
                Spacer()
                
                // Login/Signup formulär
                VStack(spacing: 16) {
                    Picker("Välj läge", selection: $isLoginMode) {
                        Text("Logga in").tag(true)
                        Text("Skapa konto").tag(false)
                    }
                    .pickerStyle(.segmented)
                    .padding(.bottom, 12)
                    
                    if isLoginMode {
                        LoginFormView()
                            .environmentObject(authViewModel)
                    } else {
                        SignupFormView()
                            .environmentObject(authViewModel)
                    }
                }
                .padding(24)
                .background(Color(.systemGray6))
                .cornerRadius(16)
                .padding(16)
                
                Spacer()
            }
        }
    }
}

struct LoginFormView: View {
    @State private var email = ""
    @State private var password = ""
    @State private var isPasswordVisible = false
    @EnvironmentObject var authViewModel: AuthViewModel
    
    var body: some View {
        VStack(spacing: 12) {
            TextField("Email", text: $email)
                .textContentType(.emailAddress)
                .keyboardType(.emailAddress)
                .padding(12)
                .background(Color.white)
                .cornerRadius(8)
                .autocapitalization(.none)
            
            ZStack(alignment: .trailing) {
                if isPasswordVisible {
                    TextField("Lösenord", text: $password)
                        .textContentType(.password)
                        .padding(12)
                        .background(Color.white)
                        .cornerRadius(8)
                } else {
                    SecureField("Lösenord", text: $password)
                        .textContentType(.password)
                        .padding(12)
                        .background(Color.white)
                        .cornerRadius(8)
                }
                
                Button(action: {
                    isPasswordVisible.toggle()
                }) {
                    Image(systemName: isPasswordVisible ? "eye.slash.fill" : "eye.fill")
                        .foregroundColor(.gray)
                        .padding(.trailing, 12)
                }
            }
            
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
                    Text("LOGGA IN")
                        .font(.system(size: 16, weight: .black))
                }
            }
            .frame(maxWidth: .infinity)
            .padding(14)
            .background(AppColors.brandBlue)
            .foregroundColor(.white)
            .cornerRadius(10)
            .disabled(authViewModel.isLoading)
            
        }
    }
}

struct SignupFormView: View {
    @State private var name = ""
    @State private var username = ""
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var isPasswordVisible = false
    @State private var isConfirmPasswordVisible = false
    @EnvironmentObject var authViewModel: AuthViewModel
    
    var body: some View {
        VStack(spacing: 12) {
            TextField("Namn", text: $name)
                .padding(12)
                .background(Color.white)
                .cornerRadius(8)
            
            TextField("Användarnamn", text: $username)
                .padding(12)
                .background(Color.white)
                .cornerRadius(8)
                .autocapitalization(.none)
            
            TextField("Email", text: $email)
                .textContentType(.emailAddress)
                .keyboardType(.emailAddress)
                .padding(12)
                .background(Color.white)
                .cornerRadius(8)
                .autocapitalization(.none)
            
            ZStack(alignment: .trailing) {
                if isPasswordVisible {
                    TextField("Lösenord", text: $password)
                        .textContentType(.newPassword)
                        .padding(12)
                        .background(Color.white)
                        .cornerRadius(8)
                } else {
                    SecureField("Lösenord", text: $password)
                        .textContentType(.newPassword)
                        .padding(12)
                        .background(Color.white)
                        .cornerRadius(8)
                }
                
                Button(action: {
                    isPasswordVisible.toggle()
                }) {
                    Image(systemName: isPasswordVisible ? "eye.slash.fill" : "eye.fill")
                        .foregroundColor(.gray)
                        .padding(.trailing, 12)
                }
            }
            
            ZStack(alignment: .trailing) {
                if isConfirmPasswordVisible {
                    TextField("Bekräfta lösenord", text: $confirmPassword)
                        .textContentType(.newPassword)
                        .padding(12)
                        .background(Color.white)
                        .cornerRadius(8)
                } else {
                    SecureField("Bekräfta lösenord", text: $confirmPassword)
                        .textContentType(.newPassword)
                        .padding(12)
                        .background(Color.white)
                        .cornerRadius(8)
                }
                
                Button(action: {
                    isConfirmPasswordVisible.toggle()
                }) {
                    Image(systemName: isConfirmPasswordVisible ? "eye.slash.fill" : "eye.fill")
                        .foregroundColor(.gray)
                        .padding(.trailing, 12)
                }
            }
            
            // Valideringsfel
            if !authViewModel.errorMessage.isEmpty {
                Text(authViewModel.errorMessage)
                    .foregroundColor(.red)
                    .font(.caption)
            } else if password != confirmPassword && !password.isEmpty && !confirmPassword.isEmpty {
                Text("Lösenorden matchar inte")
                    .foregroundColor(.red)
                    .font(.caption)
            }
            
            Button(action: {
                // Validera lösenorden matchar
                if password != confirmPassword {
                    authViewModel.errorMessage = "Lösenorden matchar inte"
                } else {
                    authViewModel.signup(name: name, username: username, email: email, password: password, confirmPassword: confirmPassword)
                }
            }) {
                if authViewModel.isLoading {
                    ProgressView()
                        .tint(.white)
                } else {
                    Text("SKAPA KONTO")
                        .font(.system(size: 16, weight: .black))
                }
            }
            .frame(maxWidth: .infinity)
            .padding(14)
            .background(AppColors.brandGreen)
            .foregroundColor(.black)
            .cornerRadius(10)
            .disabled(authViewModel.isLoading || password != confirmPassword || username.isEmpty)
        }
    }
}

#Preview {
    AuthenticationView()
        .environmentObject(AuthViewModel())
}
