import SwiftUI
import Supabase

struct ResetPasswordView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var newPassword = ""
    @State private var confirmPassword = ""
    @State private var isLoading = false
    @State private var errorMessage = ""
    @State private var isSuccess = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 12) {
                    Image(systemName: "lock.rotation")
                        .font(.system(size: 60))
                        .foregroundColor(.primary)
                    
                    Text(L.t(sv: "Nytt lösenord", nb: "Nytt passord"))
                        .font(.system(size: 28, weight: .bold))
                    
                    Text(L.t(sv: "Ange ditt nya lösenord nedan.", nb: "Skriv inn ditt nye passord nedenfor."))
                        .font(.system(size: 15))
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 40)
                
                if isSuccess {
                    // Success state
                    VStack(spacing: 20) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.green)
                        
                        Text(L.t(sv: "Lösenordet har ändrats!", nb: "Passordet er endret!"))
                            .font(.system(size: 18, weight: .semibold))
                        
                        Text(L.t(sv: "Du kan nu logga in med ditt nya lösenord.", nb: "Du kan nå logge inn med ditt nye passord."))
                            .font(.system(size: 15))
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                        
                        Button {
                            dismiss()
                        } label: {
                            Text(L.t(sv: "Stäng", nb: "Lukk"))
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(14)
                                .background(Color.black)
                                .cornerRadius(12)
                        }
                        .padding(.horizontal, 24)
                        .padding(.top, 20)
                    }
                } else {
                    // Form
                    VStack(spacing: 16) {
                        SecureField(L.t(sv: "Nytt lösenord (minst 6 tecken)", nb: "Nytt passord (minst 6 tegn)"), text: $newPassword)
                            .textContentType(.newPassword)
                            .padding(14)
                            .background(Color(.systemGray6))
                            .cornerRadius(12)
                        
                        SecureField(L.t(sv: "Bekräfta lösenord", nb: "Bekreft passord"), text: $confirmPassword)
                            .textContentType(.newPassword)
                            .padding(14)
                            .background(Color(.systemGray6))
                            .cornerRadius(12)
                    }
                    .padding(.horizontal, 24)
                    
                    if !errorMessage.isEmpty {
                        Text(errorMessage)
                            .font(.system(size: 14))
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                    }
                    
                    Button {
                        updatePassword()
                    } label: {
                        if isLoading {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Text(L.t(sv: "Spara nytt lösenord", nb: "Lagre nytt passord"))
                                .font(.system(size: 16, weight: .semibold))
                        }
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(14)
                    .background(canSubmit ? Color.black : Color.gray)
                    .cornerRadius(12)
                    .disabled(!canSubmit || isLoading)
                    .padding(.horizontal, 24)
                }
                
                Spacer()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(L.t(sv: "Avbryt", nb: "Avbryt")) {
                        dismiss()
                    }
                    .foregroundColor(.primary)
                }
            }
        }
    }
    
    private var canSubmit: Bool {
        newPassword.count >= 6 && newPassword == confirmPassword
    }
    
    private func updatePassword() {
        guard canSubmit else {
            if newPassword.count < 6 {
                errorMessage = L.t(sv: "Lösenordet måste vara minst 6 tecken", nb: "Passordet må være minst 6 tegn")
            } else if newPassword != confirmPassword {
                errorMessage = L.t(sv: "Lösenorden matchar inte", nb: "Passordene samsvarer ikke")
            }
            return
        }
        
        isLoading = true
        errorMessage = ""
        
        Task {
            do {
                try await SupabaseConfig.supabase.auth.update(user: .init(password: newPassword))
                await MainActor.run {
                    isLoading = false
                    isSuccess = true
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    errorMessage = L.t(sv: "Kunde inte uppdatera lösenordet. Försök igen.", nb: "Kunne ikke oppdatere passordet. Prøv igjen.")
                    print("❌ Password update error: \(error)")
                }
            }
        }
    }
}

#Preview {
    ResetPasswordView()
}



