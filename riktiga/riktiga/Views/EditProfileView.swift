import SwiftUI
import PhotosUI
import Supabase

struct EditProfileView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var username: String = ""
    @State private var selectedImage: UIImage?
    @State private var isSaving = false
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var photosPickerItem: PhotosPickerItem?
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemBackground).ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        // Profile Image Section
                        VStack(spacing: 12) {
                            ZStack(alignment: .bottomTrailing) {
                                if let image = selectedImage {
                                    Image(uiImage: image)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 120, height: 120)
                                        .clipShape(Circle())
                                } else {
                                    ProfileImage(url: authViewModel.currentUser?.avatarUrl, size: 120)
                                }
                                
                                PhotosPicker(selection: $photosPickerItem, matching: .images) {
                                    Image(systemName: "camera.fill")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(.white)
                                        .frame(width: 40, height: 40)
                                        .background(Color.black)
                                        .clipShape(Circle())
                                }
                            }
                            
                            Text("Tryck för att ändra profilbild")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 20)
                        
                        // Username Section
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Användarnamn")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.primary)
                            
                            TextField("Användarnamn", text: $username)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .padding(.horizontal, 16)
                        }

                        Spacer()
                        
                        // Save Button
                        Button(action: saveProfile) {
                            if isSaving {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Text("Spara ändringar")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.white)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(16)
                        .background(Color.black)
                        .cornerRadius(8)
                        .disabled(isSaving)
                        .padding(16)
                    }
                    .padding(.horizontal, 16)
                }
            }
            .navigationTitle("Redigera profil")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Avbryt") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                loadCurrentProfile()
            }
            .onChange(of: photosPickerItem) { newItem in
                Task {
                    if let data = try? await newItem?.loadTransferable(type: Data.self) {
                        if let uiImage = UIImage(data: data) {
                            selectedImage = uiImage
                        }
                    }
                }
            }
            .alert("Meddelande", isPresented: $showAlert) {
                Button("OK") {
                    if alertMessage.contains("sparad") {
                        dismiss()
                    }
                }
            } message: {
                Text(alertMessage)
            }
        }
    }
    
    private func loadCurrentProfile() {
        username = authViewModel.currentUser?.name ?? ""
    }
    
    private func saveProfile() {
        isSaving = true
        
        Task {
            do {
                var imageUrl: String?
                if let selectedImage = selectedImage {
                    imageUrl = try await uploadProfileImage(selectedImage)
                }
                
                try await updateUserProfile(
                    username: username,
                    avatarUrl: imageUrl
                )
                
                await MainActor.run {
                    isSaving = false
                    alertMessage = "Profilen har sparats!"
                    showAlert = true
                }
            } catch {
                await MainActor.run {
                    isSaving = false
                    alertMessage = "Ett fel uppstod: \(error.localizedDescription)"
                    showAlert = true
                }
            }
        }
    }
    
    private func uploadProfileImage(_ image: UIImage) async throws -> String {
        guard let userId = authViewModel.currentUser?.id else {
            throw NSError(domain: "ProfileError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Ingen användare hittades"])
        }
        guard let imageData = image.jpegData(compressionQuality: 0.85) else {
            throw NSError(domain: "ImageError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Kunde inte konvertera bilden"])
        }
        return try await ProfileService.shared.uploadAvatarImageData(imageData, userId: userId)
    }
    
    private func updateUserProfile(
        username: String,
        avatarUrl: String?
    ) async throws {
        guard let userId = authViewModel.currentUser?.id else { return }
        
        let supabase = SupabaseConfig.supabase
        
        var updateData: [String: DynamicEncodable] = [
            "username": DynamicEncodable(username)
        ]
        
        if let avatarUrl = avatarUrl {
            updateData["avatar_url"] = DynamicEncodable(avatarUrl)
        }
        
        do {
            _ = try await supabase
                .from("profiles")
                .update(updateData)
                .eq("id", value: userId)
                .execute()
            
            await MainActor.run {
                authViewModel.currentUser?.name = username
                if let avatarUrl = avatarUrl {
                    authViewModel.currentUser?.avatarUrl = avatarUrl
                }
            }
            print("✅ Profile updated successfully")
        } catch {
            if ProfileService.shared.isMissingPersonalBestColumnsError(error) {
                print("ℹ️ Personal best columns missing during update. Falling back to username/avatar only.")
                var fallbackData: [String: DynamicEncodable] = [
                    "username": DynamicEncodable(username)
                ]
                if let avatarUrl = avatarUrl {
                    fallbackData["avatar_url"] = DynamicEncodable(avatarUrl)
                }
                _ = try await supabase
                    .from("profiles")
                    .update(fallbackData)
                    .eq("id", value: userId)
                    .execute()
                
                await MainActor.run {
                    authViewModel.currentUser?.name = username
                    if let avatarUrl = avatarUrl {
                        authViewModel.currentUser?.avatarUrl = avatarUrl
                    }
                }
                print("✅ Profile updated successfully (without personal bests)")
            } else {
                throw error
            }
        }
    }
    
}

#Preview {
    EditProfileView()
        .environmentObject(AuthViewModel())
}
