import SwiftUI

struct UsernameRequiredView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var username = ""
    @State private var isUpdating = false
    @State private var errorMessage = ""
    
    var body: some View {
        VStack(spacing: 24) {
            // Icon
            Image(systemName: "person.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(AppColors.brandBlue)
                .padding(.top, 40)
            
            // Title
            VStack(spacing: 8) {
                Text("Användarnamn krävs")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.black)
                
                Text("Välj ett användarnamn för att fortsätta")
                    .font(.system(size: 16))
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 32)
            
            // Username input
            VStack(alignment: .leading, spacing: 8) {
                Text("Användarnamn")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.black)
                
                TextField("Användarnamn", text: $username)
                    .padding(12)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                    .autocapitalization(.none)
                    .disabled(isUpdating)
            }
            .padding(.horizontal, 32)
            
            if !errorMessage.isEmpty {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding(.horizontal, 32)
            }
            
            Spacer()
            
            // Update button
            Button(action: {
                updateUsername()
            }) {
                HStack {
                    if isUpdating {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Text("Uppdatera")
                            .font(.system(size: 16, weight: .bold))
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(16)
                .background(username.isEmpty ? Color.gray : AppColors.brandBlue)
                .foregroundColor(.white)
                .cornerRadius(12)
            }
            .disabled(username.isEmpty || isUpdating)
            .padding(.horizontal, 32)
            .padding(.bottom, 40)
        }
        .presentationDetents([.medium])
    }
    
    private func updateUsername() {
        guard !username.isEmpty else { return }
        
        isUpdating = true
        errorMessage = ""
        
        Task {
            do {
                guard let userId = authViewModel.currentUser?.id else {
                    errorMessage = "Fel: Användare inte hittad"
                    isUpdating = false
                    return
                }
                
                // Update username in database
                try await ProfileService.shared.updateUsername(userId: userId, username: username)
                
                // Reload user profile
                if let updatedProfile = try await ProfileService.shared.fetchUserProfile(userId: userId) {
                    await MainActor.run {
                        authViewModel.currentUser = updatedProfile
                        authViewModel.showUsernameRequiredPopup = false
                    }
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Fel: \(error.localizedDescription)"
                    isUpdating = false
                }
            }
        }
    }
}

#Preview {
    UsernameRequiredView()
        .environmentObject(AuthViewModel())
}

