import SwiftUI
import PhotosUI
import Supabase

struct CreateNewsView: View {
    @ObservedObject var newsViewModel: NewsViewModel
    @Environment(\.dismiss) var dismiss
    
    @State private var content: String = ""
    @State private var selectedItem: PhotosPickerItem?
    @State private var selectedImage: UIImage?
    @State private var isPosting = false
    @State private var uploadedImageUrl: String?
    
    private var canPost: Bool {
        !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isPosting
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
                    
                    Button(action: postNews) {
                        if isPosting {
                            ProgressView()
                                .tint(.white)
                                .frame(width: 80, height: 32)
                                .background(Color.black.opacity(0.6))
                                .cornerRadius(16)
                        } else {
                            Text("Publicera")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(width: 90, height: 32)
                                .background(canPost ? Color.black : Color.gray)
                                .cornerRadius(16)
                        }
                    }
                    .disabled(!canPost)
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
                                
                                // Selected image preview
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
                                            uploadedImageUrl = nil
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
            .onChange(of: selectedItem) { _, newValue in
                Task {
                    if let data = try? await newValue?.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) {
                        selectedImage = image
                    }
                }
            }
        }
    }
    
    private func postNews() {
        guard canPost else { return }
        
        isPosting = true
        
        Task {
            // Upload image if selected
            var imageUrl: String? = nil
            
            if let image = selectedImage {
                imageUrl = await uploadImage(image)
            }
            
            let success = await newsViewModel.createNews(
                content: content.trimmingCharacters(in: .whitespacesAndNewlines),
                imageUrl: imageUrl
            )
            
            isPosting = false
            
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
    CreateNewsView(newsViewModel: NewsViewModel())
}

