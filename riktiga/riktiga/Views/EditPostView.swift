import SwiftUI
import PhotosUI

struct EditPostView: View {
    let post: SocialWorkoutPost
    let onSave: (String, String, UIImage?) -> Void
    @Environment(\.dismiss) var dismiss
    
    @State private var title: String
    @State private var description: String
    @State private var newImage: UIImage?
    @State private var selectedItem: PhotosPickerItem?
    @State private var isSaving = false
    
    init(post: SocialWorkoutPost, onSave: @escaping (String, String, UIImage?) -> Void) {
        self.post = post
        self.onSave = onSave
        _title = State(initialValue: post.title)
        _description = State(initialValue: post.description ?? "")
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Title Section
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Titel")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.secondary)
                        
                        TextField("Titel", text: $title)
                            .font(.system(size: 18, weight: .semibold))
                            .padding(14)
                            .background(Color(.secondarySystemBackground))
                            .cornerRadius(12)
                    }
                    
                    // Description Section
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Beskrivning")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.secondary)
                        
                        TextEditor(text: $description)
                            .frame(minHeight: 100)
                            .padding(10)
                            .background(Color(.secondarySystemBackground))
                            .cornerRadius(12)
                    }
                    
                    // Image Section
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Bild")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.secondary)
                        
                        if let newImage {
                            Image(uiImage: newImage)
                                .resizable()
                                .scaledToFill()
                                .frame(height: 200)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .overlay(alignment: .topTrailing) {
                                    Button {
                                        self.newImage = nil
                                        self.selectedItem = nil
                                    } label: {
                                        Image(systemName: "xmark.circle.fill")
                                            .font(.system(size: 24))
                                            .foregroundStyle(.white, .black.opacity(0.6))
                                    }
                                    .padding(8)
                                }
                        } else if let imageUrl = post.userImageUrl, !imageUrl.isEmpty {
                            AsyncImage(url: URL(string: imageUrl)) { phase in
                                switch phase {
                                case .success(let image):
                                    image
                                        .resizable()
                                        .scaledToFill()
                                        .frame(height: 200)
                                        .clipShape(RoundedRectangle(cornerRadius: 12))
                                case .failure:
                                    imagePlaceholder
                                case .empty:
                                    ProgressView()
                                        .frame(height: 200)
                                @unknown default:
                                    imagePlaceholder
                                }
                            }
                        } else {
                            imagePlaceholder
                        }
                        
                        PhotosPicker(selection: $selectedItem, matching: .images) {
                            HStack {
                                Image(systemName: "photo.on.rectangle")
                                Text(newImage != nil || post.userImageUrl != nil ? "Byt bild" : "Lägg till bild")
                            }
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.primary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color(.secondarySystemBackground))
                            .cornerRadius(12)
                        }
                    }
                    
                    Spacer(minLength: 40)
                }
                .padding(20)
            }
            .navigationTitle("Redigera inlägg")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Avbryt") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        savePost()
                    } label: {
                        if isSaving {
                            ProgressView()
                        } else {
                            Text("Spara")
                                .fontWeight(.semibold)
                        }
                    }
                    .disabled(title.isEmpty || isSaving)
                }
            }
            .onChange(of: selectedItem) { _, newItem in
                handleImageSelection(newItem)
            }
        }
    }
    
    private var imagePlaceholder: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(Color(.secondarySystemBackground))
            .frame(height: 200)
            .overlay(
                VStack(spacing: 8) {
                    Image(systemName: "photo")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary)
                    Text("Ingen bild")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
            )
    }
    
    private func handleImageSelection(_ item: PhotosPickerItem?) {
        guard let item else { return }
        
        Task {
            if let data = try? await item.loadTransferable(type: Data.self),
               let image = UIImage(data: data) {
                await MainActor.run {
                    newImage = image
                }
            }
        }
    }
    
    private func savePost() {
        isSaving = true
        onSave(title, description, newImage)
    }
}

