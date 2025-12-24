import SwiftUI
import PhotosUI
import Supabase

struct EditNewsView: View {
    @ObservedObject var newsViewModel: NewsViewModel
    let news: NewsItem
    @Environment(\.dismiss) var dismiss
    
    @State private var content: String = ""
    @State private var selectedItem: PhotosPickerItem?
    @State private var selectedImage: UIImage?
    @State private var isUpdating = false
    @State private var currentImageUrl: String?
    
    private var canUpdate: Bool {
        !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isUpdating
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header
                HStack {
                    Button("Avbryt") {
                        dismiss()
                    }
                    .foregroundColor(.gray)
                    
                    Spacer()
                    
                    Text("Redigera nyhet")
                        .font(.system(size: 17, weight: .semibold))
                    
                    Spacer()
                    
                    Button(action: updateNews) {
                        if isUpdating {
                            ProgressView()
                                .tint(.white)
                                .frame(width: 80, height: 32)
                                .background(Color.black.opacity(0.6))
                                .cornerRadius(16)
                        } else {
                            Text("Spara")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(width: 70, height: 32)
                                .background(canUpdate ? Color.black : Color.gray)
                                .cornerRadius(16)
                        }
                    }
                    .disabled(!canUpdate)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                
                Divider()
                
                // Content area
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(alignment: .top, spacing: 12) {
                            // Avatar placeholder
                            Image("23")
                                .resizable()
                                .scaledToFill()
                                .frame(width: 48, height: 48)
                                .clipShape(Circle())
                            
                            VStack(alignment: .leading, spacing: 8) {
                                // Text input
                                ZStack(alignment: .topLeading) {
                                    if content.isEmpty {
                                        Text("Vad händer?")
                                            .foregroundColor(.gray)
                                            .padding(.top, 8)
                                    }
                                    
                                    TextEditor(text: $content)
                                        .frame(minHeight: 120)
                                        .scrollContentBackground(.hidden)
                                        .background(Color.clear)
                                }
                                
                                // Current or selected image preview
                                if let image = selectedImage {
                                    ZStack(alignment: .topTrailing) {
                                        Image(uiImage: image)
                                            .resizable()
                                            .scaledToFill()
                                            .frame(maxWidth: .infinity)
                                            .frame(height: 200)
                                            .clipShape(RoundedRectangle(cornerRadius: 12))
                                        
                                        Button(action: {
                                            selectedImage = nil
                                            selectedItem = nil
                                            currentImageUrl = nil
                                        }) {
                                            Image(systemName: "xmark.circle.fill")
                                                .font(.system(size: 24))
                                                .foregroundColor(.white)
                                                .background(Circle().fill(Color.black.opacity(0.6)))
                                        }
                                        .padding(8)
                                    }
                                } else if let imageUrl = currentImageUrl, !imageUrl.isEmpty {
                                    ZStack(alignment: .topTrailing) {
                                        LocalAsyncImage(path: imageUrl)
                                            .frame(maxWidth: .infinity)
                                            .frame(height: 200)
                                            .clipShape(RoundedRectangle(cornerRadius: 12))
                                        
                                        Button(action: {
                                            currentImageUrl = nil
                                        }) {
                                            Image(systemName: "xmark.circle.fill")
                                                .font(.system(size: 24))
                                                .foregroundColor(.white)
                                                .background(Circle().fill(Color.black.opacity(0.6)))
                                        }
                                        .padding(8)
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                    }
                }
                
                Divider()
                
                // Bottom toolbar
                HStack(spacing: 20) {
                    PhotosPicker(selection: $selectedItem, matching: .images) {
                        Image(systemName: "photo")
                            .font(.system(size: 20))
                            .foregroundColor(.blue)
                    }
                    
                    Spacer()
                    
                    // Character count
                    Text("\(content.count)/500")
                        .font(.system(size: 13))
                        .foregroundColor(content.count > 450 ? .orange : .gray)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .navigationBarHidden(true)
            .onAppear {
                content = news.content
                currentImageUrl = news.imageUrl
            }
            .onChange(of: selectedItem) { _, newValue in
                Task {
                    if let data = try? await newValue?.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) {
                        selectedImage = image
                        currentImageUrl = nil // Clear the old image URL when a new image is selected
                    }
                }
            }
        }
    }
    
    private func updateNews() {
        guard canUpdate else { return }
        
        isUpdating = true
        
        Task {
            // Upload new image if selected
            var imageUrl: String? = currentImageUrl
            
            if let image = selectedImage {
                imageUrl = await uploadImage(image)
            }
            
            let success = await newsViewModel.updateNews(
                id: news.id,
                content: content.trimmingCharacters(in: .whitespacesAndNewlines),
                imageUrl: imageUrl
            )
            
            isUpdating = false
            
            if success {
                dismiss()
            }
        }
    }
    
    private func uploadImage(_ image: UIImage) async -> String? {
        guard let imageData = image.jpegData(compressionQuality: 0.7) else { return nil }
        
        let fileName = "news_\(UUID().uuidString).jpg"
        
        do {
            _ = try await SupabaseConfig.supabase.storage
                .from("avatars")
                .upload(fileName, data: imageData, options: .init(contentType: "image/jpeg"))
            
            // Return full public URL
            let fullUrl = "https://xebatkodviqgkpsbyuiv.supabase.co/storage/v1/object/public/avatars/\(fileName)"
            return fullUrl
        } catch {
            print("❌ Failed to upload news image: \(error)")
            return nil
        }
    }
}

#Preview {
    EditNewsView(
        newsViewModel: NewsViewModel(),
        news: NewsItem(
            id: "1",
            content: "Test content",
            authorId: "admin",
            authorName: "Up&Down",
            authorAvatarUrl: nil,
            createdAt: ISO8601DateFormatter().string(from: Date()),
            imageUrl: nil
        )
    )
}

