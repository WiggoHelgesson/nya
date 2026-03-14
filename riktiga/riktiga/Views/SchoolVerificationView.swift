import SwiftUI

struct SchoolVerificationView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    
    @Binding var isVerified: Bool
    var onVerified: () -> Void
    
    private enum Step {
        case prompt
        case emailInput
        case codeInput
        case success
    }
    
    @State private var step: Step = .prompt
    @State private var schoolEmail = ""
    @State private var verificationCode = ""
    @State private var isLoading = false
    @State private var errorMessage = ""
    
    private var isDark: Bool { colorScheme == .dark }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                switch step {
                case .prompt:
                    promptView
                case .emailInput:
                    emailInputView
                case .codeInput:
                    codeInputView
                case .success:
                    successView
                }
            }
            .background(isDark ? Color.black : Color(.systemGroupedBackground))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.secondary)
                            .frame(width: 30, height: 30)
                            .background(Color(.systemGray5))
                            .clipShape(Circle())
                    }
                }
            }
        }
    }
    
    // MARK: - Step 1: Prompt
    
    private var promptView: some View {
        VStack(spacing: 32) {
            Spacer()
            
            Image(systemName: "building.columns.fill")
                .font(.system(size: 56))
                .foregroundColor(.primary)
            
            VStack(spacing: 12) {
                Text(L.t(sv: "Går du på Danderyds Gymnasium?", nb: "Går du på Danderyds Gymnasium?"))
                    .font(.system(size: 24, weight: .bold))
                    .multilineTextAlignment(.center)
                
                Text(L.t(sv: "Verifiera din skolmail för att se inlägg från alla på din skola.", nb: "Verifiser skole-e-posten din for å se innlegg fra alle på skolen din."))
                    .font(.system(size: 15))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 32)
            
            Spacer()
            
            VStack(spacing: 12) {
                Button {
                    handleYesTapped()
                } label: {
                    Text(L.t(sv: "Ja, jag går där", nb: "Ja, jeg går der"))
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(isDark ? .black : .white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(isDark ? Color.white : Color.black)
                        .clipShape(Capsule())
                }
                
                Button {
                    dismiss()
                } label: {
                    Text(L.t(sv: "Nej", nb: "Nei"))
                        .font(.system(size: 17, weight: .medium))
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
    }
    
    // MARK: - Step 2: Email Input
    
    private var emailInputView: some View {
        VStack(spacing: 24) {
            Spacer()
            
            VStack(spacing: 12) {
                Image(systemName: "envelope.badge.shield.half.filled")
                    .font(.system(size: 48))
                    .foregroundColor(.primary)
                
                Text(L.t(sv: "Verifiera din skolmail", nb: "Verifiser skole-e-posten din"))
                    .font(.system(size: 22, weight: .bold))
                
                Text(L.t(sv: "Vi skickar en kod till din @elev.danderyd.se mail.", nb: "Vi sender en kode til din @elev.danderyd.se e-post."))
                    .font(.system(size: 15))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 32)
            
            VStack(alignment: .leading, spacing: 8) {
                Text(L.t(sv: "Skolmail", nb: "Skole-e-post"))
                    .font(.system(size: 15, weight: .medium))
                
                TextField("namn@elev.danderyd.se", text: $schoolEmail)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .padding(14)
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
                
                if !errorMessage.isEmpty {
                    Text(errorMessage)
                        .font(.system(size: 13))
                        .foregroundColor(.red)
                }
            }
            .padding(.horizontal, 24)
            
            Spacer()
            
            Button {
                Task { await sendCode() }
            } label: {
                if isLoading {
                    ProgressView()
                        .tint(isDark ? .black : .white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(isDark ? Color.white : Color.black)
                        .clipShape(Capsule())
                } else {
                    Text(L.t(sv: "Skicka kod", nb: "Send kode"))
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(isDark ? .black : .white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(isValidSchoolEmail ? (isDark ? Color.white : Color.black) : Color(.systemGray4))
                        .clipShape(Capsule())
                }
            }
            .disabled(!isValidSchoolEmail || isLoading)
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
    }
    
    // MARK: - Step 3: Code Input
    
    private var codeInputView: some View {
        VStack(spacing: 24) {
            Spacer()
            
            VStack(spacing: 12) {
                Image(systemName: "lock.shield")
                    .font(.system(size: 48))
                    .foregroundColor(.primary)
                
                Text(L.t(sv: "Ange verifieringskod", nb: "Skriv inn verifiseringskode"))
                    .font(.system(size: 22, weight: .bold))
                
                Text(L.t(sv: "Vi har skickat en 6-siffrig kod till \(schoolEmail)", nb: "Vi har sendt en 6-sifret kode til \(schoolEmail)"))
                    .font(.system(size: 15))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 32)
            
            VStack(alignment: .leading, spacing: 8) {
                TextField(L.t(sv: "6-siffrig kod", nb: "6-sifret kode"), text: $verificationCode)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.center)
                    .font(.system(size: 28, weight: .bold))
                    .tracking(8)
                    .padding(14)
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
                
                if !errorMessage.isEmpty {
                    Text(errorMessage)
                        .font(.system(size: 13))
                        .foregroundColor(.red)
                }
            }
            .padding(.horizontal, 24)
            
            Button {
                Task { await sendCode() }
            } label: {
                Text(L.t(sv: "Skicka ny kod", nb: "Send ny kode"))
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }
            .disabled(isLoading)
            
            Spacer()
            
            Button {
                Task { await verifyCode() }
            } label: {
                if isLoading {
                    ProgressView()
                        .tint(isDark ? .black : .white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(isDark ? Color.white : Color.black)
                        .clipShape(Capsule())
                } else {
                    Text(L.t(sv: "Verifiera", nb: "Verifiser"))
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(isDark ? .black : .white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(verificationCode.count == 6 ? (isDark ? Color.white : Color.black) : Color(.systemGray4))
                        .clipShape(Capsule())
                }
            }
            .disabled(verificationCode.count != 6 || isLoading)
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
    }
    
    // MARK: - Step 4: Success
    
    private var successView: some View {
        VStack(spacing: 24) {
            Spacer()
            
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 64))
                .foregroundColor(.green)
            
            VStack(spacing: 8) {
                Text(L.t(sv: "Verifierad!", nb: "Verifisert!"))
                    .font(.system(size: 24, weight: .bold))
                
                Text(L.t(sv: "Du kan nu se inlägg från alla på Danderyds Gymnasium.", nb: "Du kan nå se innlegg fra alle på Danderyds Gymnasium."))
                    .font(.system(size: 15))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 32)
            
            Spacer()
            
            Button {
                isVerified = true
                onVerified()
                dismiss()
            } label: {
                Text(L.t(sv: "Visa skolflödet", nb: "Vis skolfeeden"))
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(isDark ? .black : .white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(isDark ? Color.white : Color.black)
                    .clipShape(Capsule())
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
    }
    
    // MARK: - Logic
    
    private var isValidSchoolEmail: Bool {
        schoolEmail.lowercased().trimmingCharacters(in: .whitespaces).hasSuffix(SchoolService.schoolDomain)
    }
    
    private func handleYesTapped() {
        guard let user = authViewModel.currentUser else { return }
        
        if user.email.lowercased().hasSuffix(SchoolService.schoolDomain) {
            // Auth email is already a school email -- auto-verify
            isLoading = true
            Task {
                await SchoolService.shared.autoVerifyIfSchoolEmail(userId: user.id, email: user.email)
                await MainActor.run {
                    authViewModel.currentUser?.verifiedSchoolEmail = user.email.lowercased()
                    isLoading = false
                    step = .success
                }
            }
        } else {
            step = .emailInput
        }
    }
    
    private func sendCode() async {
        guard let userId = authViewModel.currentUser?.id else { return }
        
        let email = schoolEmail.lowercased().trimmingCharacters(in: .whitespaces)
        guard email.hasSuffix(SchoolService.schoolDomain) else {
            errorMessage = L.t(sv: "Ange en giltig @elev.danderyd.se mail", nb: "Skriv inn en gyldig @elev.danderyd.se e-post")
            return
        }
        
        isLoading = true
        errorMessage = ""
        
        do {
            let success = try await SchoolService.shared.sendVerificationCode(email: email, userId: userId)
            await MainActor.run {
                isLoading = false
                if success {
                    step = .codeInput
                } else {
                    errorMessage = L.t(sv: "Kunde inte skicka kod. Försök igen.", nb: "Kunne ikke sende kode. Prøv igjen.")
                }
            }
        } catch {
            await MainActor.run {
                isLoading = false
                errorMessage = L.t(sv: "Något gick fel. Försök igen.", nb: "Noe gikk galt. Prøv igjen.")
            }
        }
    }
    
    private func verifyCode() async {
        guard let userId = authViewModel.currentUser?.id else { return }
        
        let email = schoolEmail.lowercased().trimmingCharacters(in: .whitespaces)
        let code = verificationCode.trimmingCharacters(in: .whitespaces)
        
        isLoading = true
        errorMessage = ""
        
        do {
            let success = try await SchoolService.shared.verifyCode(userId: userId, email: email, code: code)
            await MainActor.run {
                isLoading = false
                if success {
                    authViewModel.currentUser?.verifiedSchoolEmail = email
                    step = .success
                } else {
                    errorMessage = L.t(sv: "Ogiltig eller utgången kod. Försök igen.", nb: "Ugyldig eller utløpt kode. Prøv igjen.")
                }
            }
        } catch {
            await MainActor.run {
                isLoading = false
                errorMessage = L.t(sv: "Något gick fel. Försök igen.", nb: "Noe gikk galt. Prøv igjen.")
            }
        }
    }
}
