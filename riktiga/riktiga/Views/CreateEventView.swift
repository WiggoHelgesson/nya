import SwiftUI
import PhotosUI

struct CreateEventView: View {
    let userId: String
    var onEventCreated: ((Event) -> Void)? = nil
    
    @Environment(\.dismiss) private var dismiss
    
    @State private var title = ""
    @State private var eventDescription = ""
    @State private var coverPickerItem: PhotosPickerItem?
    @State private var coverImage: UIImage?
    @State private var photosPickerItems: [PhotosPickerItem] = []
    @State private var selectedImages: [UIImage] = []
    @State private var isUploading = false
    @State private var errorMessage: String?
    @State private var showError = false
    
    private var isFormValid: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        && !eventDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        && coverImage != nil
        && !selectedImages.isEmpty
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    
                    // MARK: - Title
                    VStack(alignment: .leading, spacing: 8) {
                        Text(L.t(sv: "Rubrik", nb: "Tittel"))
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.primary)
                        
                        TextField(L.t(sv: "T.ex. Ironman 2025", nb: "F.eks. Ironman 2025"), text: $title)
                            .font(.system(size: 16))
                            .padding(14)
                            .background(Color(.systemGray6))
                            .cornerRadius(12)
                    }
                    
                    // MARK: - Description
                    VStack(alignment: .leading, spacing: 8) {
                        Text(L.t(sv: "Beskrivning", nb: "Beskrivelse"))
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.primary)
                        
                        TextEditor(text: $eventDescription)
                            .font(.system(size: 16))
                            .frame(minHeight: 100)
                            .padding(10)
                            .scrollContentBackground(.hidden)
                            .background(Color(.systemGray6))
                            .cornerRadius(12)
                    }
                    
                    // MARK: - Cover Image
                    VStack(alignment: .leading, spacing: 8) {
                        Text(L.t(sv: "Omslagsbild", nb: "Forsidebilde"))
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.primary)
                        
                        PhotosPicker(selection: $coverPickerItem, matching: .images) {
                            if let coverImage {
                                Image(uiImage: coverImage)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 180)
                                    .clipShape(RoundedRectangle(cornerRadius: 14))
                            } else {
                                VStack(spacing: 10) {
                                    Image(systemName: "photo.badge.plus")
                                        .font(.system(size: 32))
                                        .foregroundColor(.gray)
                                    Text(L.t(sv: "Välj omslagsbild", nb: "Velg forsidebilde"))
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(.gray)
                                }
                                .frame(maxWidth: .infinity)
                                .frame(height: 180)
                                .background(Color(.systemGray6))
                                .cornerRadius(14)
                            }
                        }
                    }
                    
                    // MARK: - Event Photos
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(L.t(sv: "Bilder", nb: "Bilder"))
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(.primary)
                            
                            Spacer()
                            
                            Text("\(selectedImages.count)/20")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.gray)
                        }
                        
                        if !selectedImages.isEmpty {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(Array(selectedImages.enumerated()), id: \.offset) { index, image in
                                        ZStack(alignment: .topTrailing) {
                                            Image(uiImage: image)
                                                .resizable()
                                                .scaledToFill()
                                                .frame(width: 100, height: 100)
                                                .clipShape(RoundedRectangle(cornerRadius: 10))
                                            
                                            Button {
                                                selectedImages.remove(at: index)
                                            } label: {
                                                Image(systemName: "xmark.circle.fill")
                                                    .font(.system(size: 20))
                                                    .foregroundColor(.white)
                                                    .shadow(radius: 2)
                                            }
                                            .offset(x: 4, y: -4)
                                        }
                                    }
                                }
                            }
                        }
                        
                        PhotosPicker(
                            selection: $photosPickerItems,
                            maxSelectionCount: 20,
                            matching: .images
                        ) {
                            HStack(spacing: 8) {
                                Image(systemName: "photo.on.rectangle.angled")
                                    .font(.system(size: 14, weight: .semibold))
                                Text(selectedImages.isEmpty
                                     ? L.t(sv: "Välj bilder", nb: "Velg bilder")
                                     : L.t(sv: "Byt bilder", nb: "Bytt bilder"))
                                    .font(.system(size: 14, weight: .semibold))
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.black)
                            .cornerRadius(10)
                        }
                    }
                    
                    // MARK: - Upload Progress
                    if isUploading {
                        HStack(spacing: 10) {
                            ProgressView()
                                .tint(.black)
                            Text(L.t(sv: "Skapar händelse...", nb: "Oppretter hendelse..."))
                                .font(.system(size: 14))
                                .foregroundColor(.gray)
                        }
                        .padding(.vertical, 8)
                    }
                }
                .padding(20)
            }
            .navigationTitle(L.t(sv: "Ny händelse", nb: "Ny hendelse"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(L.t(sv: "Avbryt", nb: "Avbryt")) {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        Task { await createEvent() }
                    } label: {
                        Text(L.t(sv: "Skapa", nb: "Opprett"))
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .disabled(!isFormValid || isUploading)
                }
            }
            .onChange(of: coverPickerItem) { _, newItem in
                guard let newItem else { return }
                Task {
                    if let data = try? await newItem.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) {
                        await MainActor.run { coverImage = image }
                    }
                }
            }
            .onChange(of: photosPickerItems) { _, newItems in
                Task {
                    var images: [UIImage] = []
                    for item in newItems.prefix(20) {
                        if let data = try? await item.loadTransferable(type: Data.self),
                           let image = UIImage(data: data) {
                            images.append(image)
                        }
                    }
                    await MainActor.run { selectedImages = images }
                }
            }
            .alert(L.t(sv: "Fel", nb: "Feil"), isPresented: $showError) {
                Button("OK") {}
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }
    
    private func createEvent() async {
        guard let coverImage, !selectedImages.isEmpty else { return }
        
        isUploading = true
        
        do {
            let event = try await EventService.shared.createEvent(
                userId: userId,
                title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                description: eventDescription.trimmingCharacters(in: .whitespacesAndNewlines),
                coverImage: coverImage,
                images: selectedImages
            )
            
            await MainActor.run {
                isUploading = false
                onEventCreated?(event)
                dismiss()
            }
        } catch {
            await MainActor.run {
                isUploading = false
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }
}
