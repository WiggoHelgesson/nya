import SwiftUI

struct AuthenticationView: View {
    @State private var isLoginMode = true
    @EnvironmentObject var authViewModel: AuthViewModel
    
    var body: some View {
        ZStack {
            // Vit bakgrund
            AppColors.white
                .ignoresSafeArea()
            
            VStack(spacing: 16) {
                // Bild från Xcode (Image 1)
                Image("1")
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
            
            SecureField("Lösenord", text: $password)
                .textContentType(.password)
                .padding(12)
                .background(Color.white)
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
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @EnvironmentObject var authViewModel: AuthViewModel
    
    var body: some View {
        VStack(spacing: 12) {
            TextField("Namn", text: $name)
                .padding(12)
                .background(Color.white)
                .cornerRadius(8)
            
            TextField("Email", text: $email)
                .textContentType(.emailAddress)
                .keyboardType(.emailAddress)
                .padding(12)
                .background(Color.white)
                .cornerRadius(8)
                .autocapitalization(.none)
            
            SecureField("Lösenord", text: $password)
                .textContentType(.newPassword)
                .padding(12)
                .background(Color.white)
                .cornerRadius(8)
            
            SecureField("Bekräfta lösenord", text: $confirmPassword)
                .textContentType(.newPassword)
                .padding(12)
                .background(Color.white)
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
                    Text("SKAPA KONTO")
                        .font(.system(size: 16, weight: .black))
                }
            }
            .frame(maxWidth: .infinity)
            .padding(14)
            .background(AppColors.brandGreen)
            .foregroundColor(.black)
            .cornerRadius(10)
            .disabled(authViewModel.isLoading)
        }
    }
}

#Preview {
    AuthenticationView()
        .environmentObject(AuthViewModel())
}
