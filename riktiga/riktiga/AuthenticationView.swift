import SwiftUI
import AuthenticationServices
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
            
            // Divider
            HStack {
                Rectangle()
                    .frame(height: 1)
                    .foregroundColor(.gray.opacity(0.3))
                
                Text("ELLER")
                    .font(.caption)
                    .foregroundColor(.gray)
                    .padding(.horizontal, 8)
                
                Rectangle()
                    .frame(height: 1)
                    .foregroundColor(.gray.opacity(0.3))
            }
            .padding(.vertical, 8)
            
            // Apple Sign In Button
            SignInWithAppleButton(
                onRequest: { request in
                    request.requestedScopes = [.fullName, .email]
                },
                onCompletion: { result in
                    switch result {
                    case .success(let authorization):
                        if let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential {
                            handleAppleSignIn(credential: appleIDCredential, isSignUp: false, authViewModel: authViewModel)
                        }
                    case .failure(let error):
                        authViewModel.errorMessage = "Apple Sign-In misslyckades: \(error.localizedDescription)"
                    }
                }
            )
            .signInWithAppleButtonStyle(.black)
            .frame(height: 50)
            .cornerRadius(10)
        }
    }
}

struct SignupFormView: View {
    @State private var name = ""
    @State private var username = ""
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
                authViewModel.signup(name: name, username: username, email: email, password: password, confirmPassword: confirmPassword)
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
            
            // Divider
            HStack {
                Rectangle()
                    .frame(height: 1)
                    .foregroundColor(.gray.opacity(0.3))
                
                Text("ELLER")
                    .font(.caption)
                    .foregroundColor(.gray)
                    .padding(.horizontal, 8)
                
                Rectangle()
                    .frame(height: 1)
                    .foregroundColor(.gray.opacity(0.3))
            }
            .padding(.vertical, 8)
            
            // Apple Sign In Button
            SignInWithAppleButton(
                onRequest: { request in
                    request.requestedScopes = [.fullName, .email]
                },
                onCompletion: { result in
                    switch result {
                    case .success(let authorization):
                        if let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential {
                            handleAppleSignIn(credential: appleIDCredential, isSignUp: true, authViewModel: authViewModel)
                        }
                    case .failure(let error):
                        authViewModel.errorMessage = "Apple Sign-In misslyckades: \(error.localizedDescription)"
                    }
                }
            )
            .signInWithAppleButtonStyle(.black)
            .frame(height: 50)
            .cornerRadius(10)
        }
    }
}

// MARK: - Apple Sign In Helper
private func handleAppleSignIn(credential: ASAuthorizationAppleIDCredential, isSignUp: Bool, authViewModel: AuthViewModel) {
    guard let identityToken = credential.identityToken,
          let identityTokenString = String(data: identityToken, encoding: .utf8) else {
        return
    }
    
    Task {
        do {
            let supabase = SupabaseConfig.supabase
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
                    authViewModel.currentUser = profile
                    authViewModel.isLoggedIn = true
                    authViewModel.isLoading = false
                    print("✅ User logged in with Apple: \(profile.name)")
                }
            } else {
                // Skapa profil för ny Apple-användare
                let fullName = credential.fullName
                let displayName = [fullName?.givenName, fullName?.familyName]
                    .compactMap { $0 }
                    .joined(separator: " ")
                
                let userName = displayName.isEmpty ? "Apple User" : displayName
                
                // Skapa profil för ny användare
                let newUser = User(
                    id: session.user.id.uuidString,
                    name: userName,
                    email: session.user.email ?? ""
                )
                
                // Spara profil till databasen
                try await ProfileService.shared.createUserProfile(newUser)
                
                DispatchQueue.main.async {
                    authViewModel.currentUser = newUser
                    authViewModel.isLoggedIn = true
                    authViewModel.isLoading = false
                    print("✅ New Apple user created and logged in: \(userName)")
                }
            }
        } catch {
            DispatchQueue.main.async {
                authViewModel.errorMessage = "Apple Sign-In misslyckades: \(error.localizedDescription)"
                authViewModel.isLoading = false
                print("❌ Apple Sign-In error: \(error)")
            }
        }
    }
}

#Preview {
    AuthenticationView()
        .environmentObject(AuthViewModel())
}
