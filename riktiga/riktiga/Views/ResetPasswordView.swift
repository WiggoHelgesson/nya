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
                        .foregroundColor(.black)
                    
                    Text("Nytt lösenord")
                        .font(.system(size: 28, weight: .bold))
                    
                    Text("Ange ditt nya lösenord nedan.")
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
                        
                        Text("Lösenordet har ändrats!")
                            .font(.system(size: 18, weight: .semibold))
                        
                        Text("Du kan nu logga in med ditt nya lösenord.")
                            .font(.system(size: 15))
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                        
                        Button {
                            dismiss()
                        } label: {
                            Text("Stäng")
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
                        SecureField("Nytt lösenord (minst 6 tecken)", text: $newPassword)
                            .textContentType(.newPassword)
                            .padding(14)
                            .background(Color(.systemGray6))
                            .cornerRadius(12)
                        
                        SecureField("Bekräfta lösenord", text: $confirmPassword)
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
                            Text("Spara nytt lösenord")
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
                    Button("Avbryt") {
                        dismiss()
                    }
                    .foregroundColor(.black)
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
                errorMessage = "Lösenordet måste vara minst 6 tecken"
            } else if newPassword != confirmPassword {
                errorMessage = "Lösenorden matchar inte"
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
                    errorMessage = "Kunde inte uppdatera lösenordet. Försök igen."
                    print("❌ Password update error: \(error)")
                }
            }
        }
    }
}

#Preview {
    ResetPasswordView()
}



