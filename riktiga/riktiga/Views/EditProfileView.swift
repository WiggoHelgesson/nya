import SwiftUI
import PhotosUI
import Supabase

struct EditProfileView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var username: String = ""
    @State private var selectedImage: UIImage?
    @State private var showImagePicker = false
    @State private var isSaving = false
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var photosPickerItem: PhotosPickerItem?
    @State private var supportsPersonalBests = ProfileService.shared.hasPersonalBestColumns()
    @State private var pb5kmMinutesText: String = ""
    @State private var pb10kmHoursText: String = ""
    @State private var pb10kmMinutesText: String = ""
    @State private var pbMarathonHoursText: String = ""
    @State private var pbMarathonMinutesText: String = ""
    
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
                                .foregroundColor(.black)
                            
                            TextField("Användarnamn", text: $username)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .padding(.horizontal, 16)
                        }

                        // Personal Best Section
                        if supportsPersonalBests {
                            VStack(alignment: .leading, spacing: 16) {
                                Text("Personliga rekord")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.black)
                                    .padding(.horizontal, 16)
                                
                                VStack(alignment: .leading, spacing: 12) {
                                    VStack(alignment: .leading, spacing: 6) {
                                        Text("5 km")
                                            .font(.system(size: 13, weight: .medium))
                                            .foregroundColor(.gray)
                                            .padding(.horizontal, 16)
                                        pbTextField("Minuter", text: $pb5kmMinutesText, maxLength: 2, maxValue: 59)
                                            .padding(.horizontal, 16)
                                    }
                                    
                                    VStack(alignment: .leading, spacing: 6) {
                                        Text("10 km")
                                            .font(.system(size: 13, weight: .medium))
                                            .foregroundColor(.gray)
                                            .padding(.horizontal, 16)
                                        HStack(spacing: 12) {
                                            pbTextField("Timmar", text: $pb10kmHoursText, maxLength: 1, maxValue: 9)
                                                .frame(maxWidth: .infinity)
                                            pbTextField("Minuter", text: $pb10kmMinutesText, maxLength: 2, maxValue: 59)
                                                .frame(maxWidth: .infinity)
                                        }
                                        .padding(.horizontal, 16)
                                    }
                                    
                                    VStack(alignment: .leading, spacing: 6) {
                                        Text("42.2 km")
                                            .font(.system(size: 13, weight: .medium))
                                            .foregroundColor(.gray)
                                            .padding(.horizontal, 16)
                                        HStack(spacing: 12) {
                                            pbTextField("Timmar", text: $pbMarathonHoursText, maxLength: 1, maxValue: 9)
                                                .frame(maxWidth: .infinity)
                                            pbTextField("Minuter", text: $pbMarathonMinutesText, maxLength: 2, maxValue: 59)
                                                .frame(maxWidth: .infinity)
                                        }
                                        .padding(.horizontal, 16)
                                    }
                                }
                            }
                        }
                        
                        // Mountains Section
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Bestigning")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.black)
                                .padding(.horizontal, 16)
                            
                            Text("Kryssa i alla berg du har bestigit för att visa det på din offentliga profil")
                                .font(.system(size: 12))
                                .foregroundColor(.gray)
                                .padding(.horizontal, 16)
                                .padding(.top, 2)
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 16) {
                                    ForEach(Mountain.all) { mountain in
                                        MountainSelectionCard(
                                            mountain: mountain,
                                            isSelected: (authViewModel.currentUser?.climbedMountains ?? []).contains(mountain.id),
                                            onToggle: {
                                                toggleMountain(mountain.id)
                                            },
                                            userId: authViewModel.currentUser?.id ?? ""
                                        )
                                    }
                                }
                                .padding(.horizontal, 16)
                            }
                        }
                        
                        // Races Section
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Tävlingar")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.black)
                                .padding(.horizontal, 16)
                            
                            Text("Kryssa i alla tävlingar du genomfört för att visa de på din offentliga profil")
                                .font(.system(size: 12))
                                .foregroundColor(.gray)
                                .padding(.horizontal, 16)
                                .padding(.top, 2)
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 16) {
                                    ForEach(Race.all) { race in
                                        RaceSelectionCard(
                                            race: race,
                                            isSelected: (authViewModel.currentUser?.completedRaces ?? []).contains(race.id),
                                            onToggle: {
                                                toggleRace(race.id)
                                            },
                                            userId: authViewModel.currentUser?.id ?? ""
                                        )
                                    }
                                }
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
    
    private func pbTextField(_ placeholder: String, text: Binding<String>, maxLength: Int = 2, maxValue: Int? = nil) -> some View {
        TextField(placeholder, text: text)
            .keyboardType(.numberPad)
            .onChange(of: text.wrappedValue) { newValue in
                var filtered = newValue.filter { $0.isNumber }
                
                // Limit length
                if filtered.count > maxLength {
                    filtered = String(filtered.prefix(maxLength))
                }
                
                // Limit value
                if let maxValue = maxValue, let intValue = Int(filtered), intValue > maxValue {
                    filtered = String(maxValue)
                }
                
                if filtered != newValue {
                    text.wrappedValue = filtered
                }
            }
            .padding(12)
            .background(Color(.systemGray6))
            .cornerRadius(10)
    }

    private func loadCurrentProfile() {
        username = authViewModel.currentUser?.name ?? ""
        pb5kmMinutesText = authViewModel.currentUser?.pb5kmMinutes.map { String($0) } ?? ""
        pb10kmHoursText = authViewModel.currentUser?.pb10kmHours.map { String($0) } ?? ""
        pb10kmMinutesText = authViewModel.currentUser?.pb10kmMinutes.map { String($0) } ?? ""
        pbMarathonHoursText = authViewModel.currentUser?.pbMarathonHours.map { String($0) } ?? ""
        pbMarathonMinutesText = authViewModel.currentUser?.pbMarathonMinutes.map { String($0) } ?? ""
        supportsPersonalBests = ProfileService.shared.hasPersonalBestColumns()
    }
    
    private func saveProfile() {
        isSaving = true
        
        let trimmed5km = pb5kmMinutesText.trimmingCharacters(in: .whitespacesAndNewlines)
        var pb5kmValue: Int? = nil
        if !trimmed5km.isEmpty {
            guard let value = Int(trimmed5km), value >= 0 else {
                isSaving = false
                alertMessage = "Ange en giltig tid i minuter för 5 km."
                showAlert = true
                return
            }
            pb5kmValue = value
        }

        let trimmed10kHours = pb10kmHoursText.trimmingCharacters(in: .whitespacesAndNewlines)
        var pb10kHoursValue: Int? = nil
        if !trimmed10kHours.isEmpty {
            guard let value = Int(trimmed10kHours), value >= 0 else {
                isSaving = false
                alertMessage = "Ange ett giltigt antal timmar för 10 km."
                showAlert = true
                return
            }
            pb10kHoursValue = value
        }

        let trimmed10kMinutes = pb10kmMinutesText.trimmingCharacters(in: .whitespacesAndNewlines)
        var pb10kMinutesValue: Int? = nil
        if !trimmed10kMinutes.isEmpty {
            guard let value = Int(trimmed10kMinutes), (0..<60).contains(value) else {
                isSaving = false
                alertMessage = "10 km minuter måste vara mellan 0 och 59."
                showAlert = true
                return
            }
            pb10kMinutesValue = value
        }

        if pb10kMinutesValue != nil && pb10kHoursValue == nil {
            pb10kHoursValue = 0
        }
        if pb10kHoursValue != nil && pb10kMinutesValue == nil {
            pb10kMinutesValue = 0
        }

        let trimmedMarathonHours = pbMarathonHoursText.trimmingCharacters(in: .whitespacesAndNewlines)
        var pbMarathonHoursValue: Int? = nil
        if !trimmedMarathonHours.isEmpty {
            guard let value = Int(trimmedMarathonHours), value >= 0 else {
                isSaving = false
                alertMessage = "Ange ett giltigt antal timmar för 42.2 km."
                showAlert = true
                return
            }
            pbMarathonHoursValue = value
        }

        let trimmedMarathonMinutes = pbMarathonMinutesText.trimmingCharacters(in: .whitespacesAndNewlines)
        var pbMarathonMinutesValue: Int? = nil
        if !trimmedMarathonMinutes.isEmpty {
            guard let value = Int(trimmedMarathonMinutes), (0..<60).contains(value) else {
                isSaving = false
                alertMessage = "42.2 km minuter måste vara mellan 0 och 59."
                showAlert = true
                return
            }
            pbMarathonMinutesValue = value
        }

        if pbMarathonMinutesValue != nil && pbMarathonHoursValue == nil {
            pbMarathonHoursValue = 0
        }
        if pbMarathonHoursValue != nil && pbMarathonMinutesValue == nil {
            pbMarathonMinutesValue = 0
        }

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
                    pb5kmMinutes: pb5kmValue,
                    pb10kmHours: pb10kHoursValue,
                    pb10kmMinutes: pb10kMinutesValue,
                    pbMarathonHours: pbMarathonHoursValue,
                    pbMarathonMinutes: pbMarathonMinutesValue,
                    climbedMountains: authViewModel.currentUser?.climbedMountains ?? [],
                    completedRaces: authViewModel.currentUser?.completedRaces ?? []
                )
                supportsPersonalBests = ProfileService.shared.hasPersonalBestColumns()
                
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
        pb5kmMinutes: Int?,
        pb10kmHours: Int?,
        pb10kmMinutes: Int?,
        pbMarathonHours: Int?,
        pbMarathonMinutes: Int?,
        climbedMountains: [String],
        completedRaces: [String]
    ) async throws {
        guard let userId = authViewModel.currentUser?.id else { return }
        
        let supabase = SupabaseConfig.supabase
        
        var updateData: [String: AnyEncodable] = [
            "username": AnyEncodable(username),
            "pb_5km_minutes": AnyEncodable(pb5kmMinutes),
            "pb_10km_hours": AnyEncodable(pb10kmHours),
            "pb_10km_minutes": AnyEncodable(pb10kmMinutes),
            "pb_marathon_hours": AnyEncodable(pbMarathonHours),
            "pb_marathon_minutes": AnyEncodable(pbMarathonMinutes),
            "climbed_mountains": AnyEncodable(climbedMountains),
            "completed_races": AnyEncodable(completedRaces)
        ]
        
        if let avatarUrl = avatarUrl {
            updateData["avatar_url"] = AnyEncodable(avatarUrl)
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
                authViewModel.currentUser?.pb5kmMinutes = pb5kmMinutes
                authViewModel.currentUser?.pb10kmHours = pb10kmHours
                authViewModel.currentUser?.pb10kmMinutes = pb10kmMinutes
                authViewModel.currentUser?.pbMarathonHours = pbMarathonHours
                authViewModel.currentUser?.pbMarathonMinutes = pbMarathonMinutes
                authViewModel.currentUser?.climbedMountains = climbedMountains
                authViewModel.currentUser?.completedRaces = completedRaces
            }
            print("✅ Profile updated successfully")
        } catch {
            if ProfileService.shared.isMissingPersonalBestColumnsError(error) {
                print("ℹ️ Personal best columns missing during update. Falling back to username/avatar only.")
                var fallbackData: [String: AnyEncodable] = [
                    "username": AnyEncodable(username)
                ]
                if let avatarUrl = avatarUrl {
                    fallbackData["avatar_url"] = AnyEncodable(avatarUrl)
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
                    authViewModel.currentUser?.pb5kmMinutes = nil
                    authViewModel.currentUser?.pb10kmHours = nil
                    authViewModel.currentUser?.pb10kmMinutes = nil
                    authViewModel.currentUser?.pbMarathonHours = nil
                    authViewModel.currentUser?.pbMarathonMinutes = nil
                }
                print("✅ Profile updated successfully (without personal bests)")
            } else {
                throw error
            }
        }
    }
    
    private func toggleMountain(_ mountainId: String) {
        guard var mountains = authViewModel.currentUser?.climbedMountains else { return }
        if mountains.contains(mountainId) {
            mountains.removeAll { $0 == mountainId }
        } else {
            mountains.append(mountainId)
        }
        authViewModel.currentUser?.climbedMountains = mountains
    }
    
    private func toggleRace(_ raceId: String) {
        guard var races = authViewModel.currentUser?.completedRaces else { return }
        if races.contains(raceId) {
            races.removeAll { $0 == raceId }
        } else {
            races.append(raceId)
        }
        authViewModel.currentUser?.completedRaces = races
    }
}

struct MountainSelectionCard: View {
    let mountain: Mountain
    let isSelected: Bool
    let onToggle: () -> Void
    let userId: String
    
    var body: some View {
        VStack(spacing: 12) {
            ZStack(alignment: .topTrailing) {
                NavigationLink(destination: MountainDetailView(mountain: mountain, isOwner: true, userId: userId)) {
                    Image(mountain.imageName)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 140, height: 140)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                
                Button(action: onToggle) {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundColor(isSelected ? .green : .white)
                        .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
                }
                .padding(12)
            }
            
            Text(mountain.name)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.black)
        }
        .frame(width: 140)
    }
}

struct RaceSelectionCard: View {
    let race: Race
    let isSelected: Bool
    let onToggle: () -> Void
    let userId: String
    
    var body: some View {
        VStack(spacing: 12) {
            ZStack(alignment: .topTrailing) {
                NavigationLink(destination: RaceDetailView(race: race, isOwner: true, userId: userId)) {
                    Image(race.imageName)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 140, height: 140)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                
                Button(action: onToggle) {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundColor(isSelected ? .green : .white)
                        .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
                }
                .padding(12)
            }
            
            Text(race.name)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.black)
        }
        .frame(width: 140)
    }
}

#Preview {
    EditProfileView()
        .environmentObject(AuthViewModel())
}
