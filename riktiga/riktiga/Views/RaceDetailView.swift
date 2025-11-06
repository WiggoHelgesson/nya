import SwiftUI
import PhotosUI
import Supabase

struct RaceDetailView: View {
    let race: Race
    let isOwner: Bool
    let userId: String
    
    @State private var memories: [RaceMemory] = []
    @State private var isLoading = true
    @State private var photosPickerItems: [PhotosPickerItem] = []
    @State private var isUploading = false
    @State private var errorMessage: String?
    @State private var showError = false
    @State private var selectedImageUrl: String?
    @State private var memoryToDelete: RaceMemory?
    @State private var showDeleteConfirmation = false
    @EnvironmentObject private var authViewModel: AuthViewModel
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Race Header
                VStack(spacing: 12) {
                    Image(race.imageName)
                        .resizable()
                        .scaledToFill()
                        .frame(height: 200)
                        .frame(maxWidth: .infinity)
                        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                        .padding(.horizontal, 16)
                    
                    Text(race.name)
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.black)
                }
                .padding(.top, 8)
                
                // Add Photos Section (only for owner)
                if isOwner {
                    VStack(spacing: 12) {
                        Text("Lägg till minnen")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.black)
                        
                        PhotosPicker(selection: $photosPickerItems, maxSelectionCount: 10, matching: .images) {
                            HStack(spacing: 8) {
                                Image(systemName: "photo.on.rectangle.angled")
                                    .font(.system(size: 16, weight: .semibold))
                                Text("Välj foton")
                                    .font(.system(size: 16, weight: .semibold))
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.black)
                            .cornerRadius(12)
                        }
                        .disabled(isUploading)
                        .padding(.horizontal, 16)
                        
                        if isUploading {
                            HStack(spacing: 8) {
                                ProgressView()
                                    .tint(.black)
                                Text("Laddar upp...")
                                    .font(.system(size: 14))
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                    .padding(.vertical, 12)
                    .background(Color(.systemGray6))
                    .cornerRadius(16)
                    .padding(.horizontal, 16)
                }
                
                // Memories Grid
                if isLoading {
                    ProgressView()
                        .tint(.black)
                        .padding(.top, 40)
                } else if memories.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "photo.on.rectangle.angled")
                            .font(.system(size: 48))
                            .foregroundColor(.gray)
                        Text(isOwner ? "Inga minnen ännu" : "Inga minnen har lagts till")
                            .font(.system(size: 16))
                            .foregroundColor(.gray)
                        if isOwner {
                            Text("Lägg till dina första minnen från denna resa")
                                .font(.system(size: 14))
                                .foregroundColor(.gray.opacity(0.8))
                        }
                    }
                    .padding(.top, 40)
                } else {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Minnen (\(memories.count))")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.black)
                            .padding(.horizontal, 16)
                        
                        LazyVGrid(columns: [
                            GridItem(.flexible(), spacing: 8),
                            GridItem(.flexible(), spacing: 8)
                        ], spacing: 8) {
                            ForEach(memories) { memory in
                                GeometryReader { geometry in
                                    ZStack(alignment: .topTrailing) {
                                        Button(action: {
                                            selectedImageUrl = memory.imageUrl
                                        }) {
                                            AsyncImage(url: URL(string: memory.imageUrl)) { phase in
                                                switch phase {
                                                case .empty:
                                                    Rectangle()
                                                        .fill(Color(.systemGray5))
                                                        .overlay(
                                                            ProgressView()
                                                                .tint(.gray)
                                                        )
                                                case .success(let image):
                                                    image
                                                        .resizable()
                                                        .aspectRatio(contentMode: .fill)
                                                        .frame(width: geometry.size.width, height: geometry.size.width)
                                                        .clipped()
                                                case .failure:
                                                    Rectangle()
                                                        .fill(Color(.systemGray5))
                                                        .overlay(
                                                            Image(systemName: "photo")
                                                                .foregroundColor(.gray)
                                                        )
                                                @unknown default:
                                                    EmptyView()
                                                }
                                            }
                                            .frame(width: geometry.size.width, height: geometry.size.width)
                                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                        }
                                        .buttonStyle(PlainButtonStyle())
                                    
                                        if isOwner {
                                            Button(action: {
                                                memoryToDelete = memory
                                                showDeleteConfirmation = true
                                            }) {
                                                Image(systemName: "xmark.circle.fill")
                                                    .font(.system(size: 24))
                                                    .foregroundColor(.white)
                                                    .background(Circle().fill(Color.black.opacity(0.6)))
                                                    .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
                                            }
                                            .padding(8)
                                        }
                                    }
                                }
                                .aspectRatio(1, contentMode: .fit)
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                }
            }
            .padding(.vertical, 16)
        }
        .navigationTitle("Tävling")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadMemories()
        }
        .onChange(of: photosPickerItems) { newItems in
            Task {
                await uploadPhotos(items: newItems)
            }
        }
        .alert("Fel", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "Ett fel uppstod")
        }
        .confirmationDialog("Ta bort minne?", isPresented: $showDeleteConfirmation, presenting: memoryToDelete) { memory in
            Button("Ta bort", role: .destructive) {
                Task {
                    await deleteMemory(memory)
                }
            }
            Button("Avbryt", role: .cancel) {}
        } message: { _ in
            Text("Detta kommer att ta bort bilden permanent")
        }
        .overlay {
            if let selectedImageUrl = selectedImageUrl {
                FullScreenImageView(imageUrl: selectedImageUrl, isPresented: Binding(
                    get: { self.selectedImageUrl != nil },
                    set: { if !$0 { self.selectedImageUrl = nil } }
                ))
            }
        }
    }
    
    private func loadMemories() async {
        isLoading = true
        defer { isLoading = false }
        
        let supabase = SupabaseConfig.supabase
        
        do {
            let response: [RaceMemory] = try await supabase
                .from("race_memories")
                .select()
                .eq("user_id", value: userId)
                .eq("race_id", value: race.id)
                .order("created_at", ascending: false)
                .execute()
                .value
            
            await MainActor.run {
                self.memories = response
            }
        } catch {
            print("❌ Error loading race memories: \(error)")
        }
    }
    
    private func uploadPhotos(items: [PhotosPickerItem]) async {
        guard !items.isEmpty else { return }
        guard let currentUserId = authViewModel.currentUser?.id else { return }
        
        await MainActor.run {
            isUploading = true
        }
        
        defer {
            Task { @MainActor in
                isUploading = false
                photosPickerItems = []
            }
        }
        
        let supabase = SupabaseConfig.supabase
        
        for item in items {
            do {
                guard let imageData = try await item.loadTransferable(type: Data.self) else {
                    continue
                }
                
                // Upload to Supabase storage
                let fileName = "\(currentUserId)/races/\(race.id)/\(UUID().uuidString).jpg"
                
                _ = try await supabase.storage
                    .from("avatars")
                    .upload(path: fileName, file: imageData, options: .init(contentType: "image/jpeg"))
                
                let publicURL = try supabase.storage
                    .from("avatars")
                    .getPublicURL(path: fileName)
                
                // Save to database
                let memoryData: [String: AnyEncodable] = [
                    "user_id": AnyEncodable(currentUserId),
                    "race_id": AnyEncodable(race.id),
                    "image_url": AnyEncodable(publicURL.absoluteString)
                ]
                
                try await supabase
                    .from("race_memories")
                    .insert(memoryData)
                    .execute()
                
                print("✅ Race memory uploaded successfully")
            } catch {
                print("❌ Error uploading race memory: \(error)")
                await MainActor.run {
                    errorMessage = "Kunde inte ladda upp bild"
                    showError = true
                }
            }
        }
        
        // Reload memories
        await loadMemories()
    }
    
    private func deleteMemory(_ memory: RaceMemory) async {
        let supabase = SupabaseConfig.supabase
        
        do {
            // Delete from database
            try await supabase
                .from("race_memories")
                .delete()
                .eq("id", value: memory.id)
                .execute()
            
            // Delete from storage (optional - you may want to keep storage files)
            // Extract file path from URL if needed
            
            print("✅ Race memory deleted successfully")
            
            // Reload memories
            await loadMemories()
        } catch {
            print("❌ Error deleting race memory: \(error)")
            await MainActor.run {
                errorMessage = "Kunde inte ta bort bilden"
                showError = true
            }
        }
    }
}

#Preview {
    NavigationStack {
        RaceDetailView(
            race: Race.all[0],
            isOwner: true,
            userId: "preview-user-id"
        )
        .environmentObject(AuthViewModel())
    }
}

