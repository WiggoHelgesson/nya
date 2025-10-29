import SwiftUI
import PhotosUI
import Supabase

struct EditProfileView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var username: String = ""
    @State private var pb5km: String = ""
    @State private var pb10km: String = ""
    @State private var pbMarathon: String = ""
    @State private var selectedImage: UIImage?
    @State private var showImagePicker = false
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
                                        .background(AppColors.brandBlue)
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
                                .foregroundColor(.black)
                            
                            TextField("Användarnamn", text: $username)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .padding(.horizontal, 16)
                        }
                        
                        // Personal Bests Section
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Personliga rekord")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.black)
                                .padding(.horizontal, 16)
                            
                            // 5K PB
                            VStack(alignment: .leading, spacing: 8) {
                                Label("5 km", systemImage: "figure.run")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.black)
                                    .padding(.horizontal, 16)
                                
                                HStack {
                                    TextField("mm:ss", text: $pb5km, prompt: Text("mm:ss").foregroundColor(.gray))
                                        .keyboardType(.numbersAndPunctuation)
                                    
                                    Text("minuter")
                                        .foregroundColor(.gray)
                                        .font(.system(size: 14))
                                }
                                .padding(12)
                                .background(Color(.systemGray6))
                                .cornerRadius(8)
                                .padding(.horizontal, 16)
                            }
                            
                            // 10K PB
                            VStack(alignment: .leading, spacing: 8) {
                                Label("10 km", systemImage: "figure.run")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.black)
                                    .padding(.horizontal, 16)
                                
                                HStack {
                                    TextField("mm:ss", text: $pb10km, prompt: Text("mm:ss").foregroundColor(.gray))
                                        .keyboardType(.numbersAndPunctuation)
                                    
                                    Text("minuter")
                                        .foregroundColor(.gray)
                                        .font(.system(size: 14))
                                }
                                .padding(12)
                                .background(Color(.systemGray6))
                                .cornerRadius(8)
                                .padding(.horizontal, 16)
                            }
                            
                            // Marathon PB
                            VStack(alignment: .leading, spacing: 8) {
                                Label("Maraton (42.2 km)", systemImage: "figure.run")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.black)
                                    .padding(.horizontal, 16)
                                
                                HStack {
                                    TextField("hh:mm:ss", text: $pbMarathon, prompt: Text("hh:mm:ss").foregroundColor(.gray))
                                        .keyboardType(.numbersAndPunctuation)
                                    
                                    Text("timmar")
                                        .foregroundColor(.gray)
                                        .font(.system(size: 14))
                                }
                                .padding(12)
                                .background(Color(.systemGray6))
                                .cornerRadius(8)
                                .padding(.horizontal, 16)
                            }
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
                        .background(AppColors.brandBlue)
                        .cornerRadius(8)
                        .disabled(isSaving)
                        .padding(16)
                    }
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
                // Upload image if selected
                var imageUrl: String?
                if let selectedImage = selectedImage {
                    imageUrl = try await uploadProfileImage(selectedImage)
                }
                
                // Update user profile
                try await updateUserProfile(
                    username: username,
                    avatarUrl: imageUrl,
                    pb5km: pb5km,
                    pb10km: pb10km,
                    pbMarathon: pbMarathon
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
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            throw NSError(domain: "ImageError", code: -1, userInfo: nil)
        }
        
        let fileName = "profile_\(UUID().uuidString).jpg"
        let supabase = SupabaseConfig.supabase
        
        _ = try await supabase.storage
            .from("profile-images")
            .upload(fileName, data: imageData, options: .init(upsert: true))
        
        let publicURL = try supabase.storage
            .from("profile-images")
            .getPublicURL(path: fileName)
        
        return publicURL.absoluteString
    }
    
    private func updateUserProfile(
        username: String,
        avatarUrl: String?,
        pb5km: String,
        pb10km: String,
        pbMarathon: String
    ) async throws {
        guard let userId = authViewModel.currentUser?.id else { return }
        
        let supabase = SupabaseConfig.supabase
        
        // Build update dictionary directly
        var updateDict: [String: String?] = [
            "username": username,
            "pb_5km": pb5km.isEmpty ? nil : pb5km,
            "pb_10km": pb10km.isEmpty ? nil : pb10km,
            "pb_marathon": pbMarathon.isEmpty ? nil : pbMarathon
        ]
        
        if let avatarUrl = avatarUrl {
            updateDict["avatar_url"] = avatarUrl
        }
        
        _ = try await supabase
            .from("profiles")
            .update(updateDict)
            .eq("id", value: userId)
            .execute()
        
        // Update auth view model
        await MainActor.run {
            authViewModel.currentUser?.name = username
            if let avatarUrl = avatarUrl {
                authViewModel.currentUser?.avatarUrl = avatarUrl
            }
        }
        
        print("✅ Profile updated successfully")
    }
}

#Preview {
    EditProfileView()
        .environmentObject(AuthViewModel())
}
