import SwiftUI
import PhotosUI

// MARK: - Weight Progress Entry Model (Cloud-based)
struct WeightProgressEntry: Codable, Identifiable {
    let id: String
    let userId: String
    let imageUrl: String
    let weightKg: Double
    let photoDate: Date
    let createdAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case imageUrl = "image_url"
        case weightKg = "weight_kg"
        case photoDate = "photo_date"
        case createdAt = "created_at"
    }
    
    // Custom decoder for dates
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        userId = try container.decode(String.self, forKey: .userId)
        imageUrl = try container.decode(String.self, forKey: .imageUrl)
        weightKg = try container.decode(Double.self, forKey: .weightKg)
        
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let isoFormatterNoMs = ISO8601DateFormatter()
        isoFormatterNoMs.formatOptions = [.withInternetDateTime]
        
        let photoDateString = try container.decode(String.self, forKey: .photoDate)
        if let date = isoFormatter.date(from: photoDateString) {
            photoDate = date
        } else if let date = isoFormatterNoMs.date(from: photoDateString) {
            photoDate = date
        } else {
            // Try date-only format
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            photoDate = dateFormatter.date(from: photoDateString) ?? Date()
        }
        
        let createdAtString = try container.decode(String.self, forKey: .createdAt)
        if let date = isoFormatter.date(from: createdAtString) {
            createdAt = date
        } else if let date = isoFormatterNoMs.date(from: createdAtString) {
            createdAt = date
        } else {
            createdAt = Date()
        }
    }
    
    init(id: String, userId: String, imageUrl: String, weightKg: Double, photoDate: Date, createdAt: Date) {
        self.id = id
        self.userId = userId
        self.imageUrl = imageUrl
        self.weightKg = weightKg
        self.photoDate = photoDate
        self.createdAt = createdAt
    }
}

// For inserting new photos
struct WeightProgressEntryInsert: Encodable {
    let id: String
    let userId: String
    let imageUrl: String
    let weightKg: Double
    let photoDate: String
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case imageUrl = "image_url"
        case weightKg = "weight_kg"
        case photoDate = "photo_date"
    }
}

// MARK: - Progress Photos Full View
struct ProgressPhotosView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var authViewModel: AuthViewModel
    
    @State private var photos: [WeightProgressEntry] = []
    @State private var isLoading = true
    @State private var showAddPhoto = false
    @State private var selectedPhoto: WeightProgressEntry? = nil
    
    private var groupedPhotos: [(String, [WeightProgressEntry])] {
        let grouped = Dictionary(grouping: photos) { photo -> String in
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "sv_SE")
            formatter.dateFormat = "MMMM yyyy"
            return formatter.string(from: photo.photoDate).capitalized
        }
        return grouped.sorted { $0.key > $1.key }
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                if isLoading {
                    ProgressView()
                        .padding(.top, 100)
                } else if photos.isEmpty {
                    emptyState
                        .padding(.top, 60)
                } else {
                    LazyVStack(alignment: .leading, spacing: 24) {
                        ForEach(groupedPhotos, id: \.0) { month, monthPhotos in
                            VStack(alignment: .leading, spacing: 12) {
                                Text(month)
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.secondary)
                                    .padding(.horizontal, 20)
                                
                                LazyVGrid(columns: [
                                    GridItem(.flexible(), spacing: 12),
                                    GridItem(.flexible(), spacing: 12)
                                ], spacing: 12) {
                                    ForEach(monthPhotos) { photo in
                                        WeightEntryCard(photo: photo)
                                            .onTapGesture {
                                                selectedPhoto = photo
                                            }
                                    }
                                }
                                .padding(.horizontal, 20)
                            }
                        }
                    }
                    .padding(.top, 16)
                    .padding(.bottom, 100)
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Progress Bilder")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "arrow.left")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.primary)
                            .frame(width: 40, height: 40)
                            .background(Color(.secondarySystemBackground))
                            .clipShape(Circle())
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showAddPhoto = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.primary)
                            .frame(width: 40, height: 40)
                            .background(Color(.secondarySystemBackground))
                            .clipShape(Circle())
                    }
                }
            }
        }
        .sheet(isPresented: $showAddPhoto) {
            AddWeightProgressView(onPhotoAdded: { newPhoto in
                photos.insert(newPhoto, at: 0)
            })
            .environmentObject(authViewModel)
        }
        .sheet(item: $selectedPhoto) { photo in
            WeightEntryDetailView(photo: photo, onDelete: {
                photos.removeAll { $0.id == photo.id }
            })
        }
        .task {
            await loadPhotos()
        }
    }
    
    private var emptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "person.crop.artframe")
                .font(.system(size: 60))
                .foregroundColor(.gray.opacity(0.4))
            
            VStack(spacing: 8) {
                Text("Inga progress bilder än")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.primary)
                
                Text("Lägg till din första bild för att\nfölja din resa")
                    .font(.system(size: 15))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            Button {
                showAddPhoto = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "plus")
                        .font(.system(size: 14, weight: .semibold))
                    Text("Lägg till bild")
                        .font(.system(size: 16, weight: .semibold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 14)
                .background(Color.black)
                .cornerRadius(25)
            }
            .padding(.top, 8)
        }
        .padding(.horizontal, 40)
    }
    
    private func loadPhotos() async {
        guard let userId = authViewModel.currentUser?.id else {
            isLoading = false
            return
        }
        
        do {
            photos = try await ProgressPhotoService.shared.fetchPhotos(for: userId)
        } catch {
            print("❌ Error loading progress photos: \(error)")
        }
        
        isLoading = false
    }
}

// MARK: - Weight Entry Card
struct WeightEntryCard: View {
    let photo: WeightProgressEntry
    
    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "sv_SE")
        formatter.dateFormat = "d MMM"
        return formatter.string(from: photo.photoDate)
    }
    
    private var formattedWeight: String {
        String(format: "%.1f kg", photo.weightKg)
    }
    
    var body: some View {
        ZStack(alignment: .bottomLeading) {
            AsyncImage(url: URL(string: photo.imageUrl)) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(3/4, contentMode: .fill)
                case .failure:
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .overlay(
                            Image(systemName: "photo")
                                .font(.system(size: 30))
                                .foregroundColor(.gray)
                        )
                case .empty:
                    Rectangle()
                        .fill(Color.gray.opacity(0.1))
                        .overlay(ProgressView())
                @unknown default:
                    Rectangle()
                        .fill(Color.gray.opacity(0.1))
                }
            }
            .aspectRatio(3/4, contentMode: .fill)
            .clipped()
            
            // Gradient overlay
            LinearGradient(
                colors: [.clear, .black.opacity(0.7)],
                startPoint: .center,
                endPoint: .bottom
            )
            
            // Weight and date
            VStack(alignment: .leading, spacing: 2) {
                Text(formattedWeight)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                Text(formattedDate)
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.8))
            }
            .padding(12)
        }
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
    }
}

// MARK: - Add Weight Progress View
struct AddWeightProgressView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var authViewModel: AuthViewModel
    
    let onPhotoAdded: (WeightProgressEntry) -> Void
    
    @State private var selectedImage: UIImage? = nil
    @State private var showImagePicker = false
    @State private var weightString: String = ""
    @State private var photoDate: Date = Date()
    @State private var lastWeight: Double? = nil
    @State private var isSaving = false
    @State private var showDatePicker = false
    
    @FocusState private var isWeightFocused: Bool
    
    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "sv_SE")
        if Calendar.current.isDateInToday(photoDate) {
            return "Idag"
        } else if Calendar.current.isDateInYesterday(photoDate) {
            return "Igår"
        } else {
            formatter.dateFormat = "d MMMM yyyy"
            return formatter.string(from: photoDate)
        }
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 8) {
                        Text("Bekräfta din vikt")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(.primary)
                    }
                    .padding(.top, 8)
                    
                    // Weight input
                    VStack(spacing: 8) {
                        HStack(alignment: .lastTextBaseline, spacing: 4) {
                            TextField("0.0", text: $weightString)
                                .font(.system(size: 56, weight: .bold))
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.center)
                                .focused($isWeightFocused)
                                .frame(maxWidth: 180)
                            
                            Text("kg")
                                .font(.system(size: 24, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                        
                        if let lastWeight = lastWeight {
                            Text("Senaste inlägg: \(String(format: "%.1f", lastWeight)) kg")
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 20)
                    
                    Divider()
                        .padding(.horizontal, 20)
                    
                    // Progress Photo section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Progress Bild")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.primary)
                        
                        if let image = selectedImage {
                            ZStack(alignment: .topTrailing) {
                                Image(uiImage: image)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(height: 200)
                                    .clipped()
                                    .cornerRadius(12)
                                
                                Button {
                                    selectedImage = nil
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.system(size: 24))
                                        .foregroundColor(.white)
                                        .shadow(radius: 4)
                                }
                                .padding(8)
                            }
                        } else {
                            Button {
                                showImagePicker = true
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: "plus")
                                        .font(.system(size: 16))
                                    Text("Ladda upp bild")
                                        .font(.system(size: 16, weight: .medium))
                                }
                                .foregroundColor(.primary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(Color(.secondarySystemBackground))
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [5]))
                                        .foregroundColor(.gray.opacity(0.3))
                                )
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    
                    Divider()
                        .padding(.horizontal, 20)
                    
                    // Date picker
                    Button {
                        showDatePicker = true
                    } label: {
                        HStack {
                            Text("Datum")
                                .font(.system(size: 16))
                                .foregroundColor(.primary)
                            
                            Spacer()
                            
                            Text(formattedDate)
                                .font(.system(size: 16))
                                .foregroundColor(.secondary)
                            
                            Image(systemName: "chevron.right")
                                .font(.system(size: 14))
                                .foregroundColor(.gray)
                        }
                        .padding(16)
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(12)
                    }
                    .padding(.horizontal, 20)
                    
                    Spacer(minLength: 40)
                    
                    // Submit button
                    Button {
                        savePhoto()
                    } label: {
                        HStack {
                            if isSaving {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Text("Spara")
                                    .font(.system(size: 17, weight: .semibold))
                            }
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(canSave ? Color.black : Color.gray)
                        .cornerRadius(14)
                    }
                    .disabled(!canSave || isSaving)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 30)
                }
            }
            .background(Color(.systemBackground))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "arrow.left")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.primary)
                            .frame(width: 40, height: 40)
                            .background(Color(.secondarySystemBackground))
                            .clipShape(Circle())
                    }
                }
            }
        }
        .sheet(isPresented: $showImagePicker) {
            WeightPhotoImagePicker(image: $selectedImage)
        }
        .sheet(isPresented: $showDatePicker) {
            WeightPhotoDatePickerSheet(selectedDate: $photoDate)
        }
        .task {
            await loadLastWeight()
            isWeightFocused = true
        }
        .onAppear {
            if let lastWeight = lastWeight {
                weightString = String(format: "%.1f", lastWeight)
            }
        }
    }
    
    private var canSave: Bool {
        guard let weight = Double(weightString.replacingOccurrences(of: ",", with: ".")),
              weight > 0,
              selectedImage != nil else {
            return false
        }
        return true
    }
    
    private func loadLastWeight() async {
        guard let userId = authViewModel.currentUser?.id else { return }
        
        do {
            if let weight = try await ProgressPhotoService.shared.getLatestWeight(for: userId) {
                await MainActor.run {
                    lastWeight = weight
                    weightString = String(format: "%.1f", weight)
                }
            }
        } catch {
            print("❌ Error loading last weight: \(error)")
        }
    }
    
    private func savePhoto() {
        guard let userId = authViewModel.currentUser?.id,
              let image = selectedImage,
              let weight = Double(weightString.replacingOccurrences(of: ",", with: ".")) else {
            return
        }
        
        isSaving = true
        
        Task {
            do {
                let newPhoto = try await ProgressPhotoService.shared.uploadPhoto(
                    userId: userId,
                    image: image,
                    weightKg: weight,
                    photoDate: photoDate
                )
                
                await MainActor.run {
                    onPhotoAdded(newPhoto)
                    isSaving = false
                    dismiss()
                }
            } catch {
                print("❌ Error saving progress photo: \(error)")
                await MainActor.run {
                    isSaving = false
                }
            }
        }
    }
}

// MARK: - Date Picker Sheet
struct WeightPhotoDatePickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedDate: Date
    
    var body: some View {
        NavigationStack {
            VStack {
                DatePicker(
                    "Välj datum",
                    selection: $selectedDate,
                    in: ...Date(),
                    displayedComponents: .date
                )
                .datePickerStyle(.graphical)
                .padding()
                
                Spacer()
            }
            .navigationTitle("Välj datum")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Klar") {
                        dismiss()
                    }
                    .font(.system(size: 16, weight: .semibold))
                }
            }
        }
        .presentationDetents([.medium])
    }
}

// MARK: - Weight Entry Detail View
struct WeightEntryDetailView: View {
    @Environment(\.dismiss) private var dismiss
    let photo: WeightProgressEntry
    let onDelete: () -> Void
    
    @State private var showDeleteAlert = false
    @State private var isDeleting = false
    
    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "sv_SE")
        formatter.dateFormat = "d MMMM yyyy"
        return formatter.string(from: photo.photoDate)
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                
                VStack {
                    AsyncImage(url: URL(string: photo.imageUrl)) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                        case .failure:
                            Rectangle()
                                .fill(Color.gray.opacity(0.3))
                                .overlay(
                                    Image(systemName: "photo")
                                        .font(.system(size: 50))
                                        .foregroundColor(.gray)
                                )
                        case .empty:
                            ProgressView()
                                .tint(.white)
                        @unknown default:
                            EmptyView()
                        }
                    }
                    
                    Spacer()
                    
                    // Info bar
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(String(format: "%.1f kg", photo.weightKg))
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(.white)
                            Text(formattedDate)
                                .font(.system(size: 16))
                                .foregroundColor(.white.opacity(0.7))
                        }
                        
                        Spacer()
                        
                        Button {
                            showDeleteAlert = true
                        } label: {
                            Image(systemName: "trash")
                                .font(.system(size: 20))
                                .foregroundColor(.red)
                                .padding(12)
                                .background(Color.white.opacity(0.1))
                                .clipShape(Circle())
                        }
                    }
                    .padding(20)
                    .background(Color.black.opacity(0.5))
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white)
                            .frame(width: 36, height: 36)
                            .background(Color.white.opacity(0.2))
                            .clipShape(Circle())
                    }
                }
            }
        }
        .alert("Radera bild?", isPresented: $showDeleteAlert) {
            Button("Avbryt", role: .cancel) { }
            Button("Radera", role: .destructive) {
                deletePhoto()
            }
        } message: {
            Text("Är du säker på att du vill radera denna progress bild?")
        }
    }
    
    private func deletePhoto() {
        isDeleting = true
        
        Task {
            do {
                try await ProgressPhotoService.shared.deletePhoto(
                    photoId: photo.id,
                    imageUrl: photo.imageUrl,
                    userId: photo.userId
                )
                
                await MainActor.run {
                    onDelete()
                    dismiss()
                }
            } catch {
                print("❌ Error deleting photo: \(error)")
                await MainActor.run {
                    isDeleting = false
                }
            }
        }
    }
}

// MARK: - Image Picker (for Weight Progress)
struct WeightPhotoImagePicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    @Environment(\.dismiss) private var dismiss
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = .photoLibrary
        picker.allowsEditing = true
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: WeightPhotoImagePicker
        
        init(_ parent: WeightPhotoImagePicker) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let editedImage = info[.editedImage] as? UIImage {
                parent.image = editedImage
            } else if let originalImage = info[.originalImage] as? UIImage {
                parent.image = originalImage
            }
            parent.dismiss()
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

// MARK: - Progress Photos Section (for Statistics View)
struct ProgressPhotosSectionView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    
    @State private var photos: [WeightProgressEntry] = []
    @State private var isLoading = true
    @State private var showAllPhotos = false
    @State private var showAddPhoto = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Text("Progress Bilder")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.primary)
                
                Spacer()
                
                if !photos.isEmpty {
                    Button {
                        showAllPhotos = true
                    } label: {
                        Text("Se alla")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.horizontal, 20)
            
            if isLoading {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
                .frame(height: 150)
            } else if photos.isEmpty {
                // Empty state
                HStack(spacing: 16) {
                    // Icon
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.gray.opacity(0.1))
                            .frame(width: 80, height: 100)
                        
                        Image(systemName: "person.crop.artframe")
                            .font(.system(size: 36))
                            .foregroundColor(.gray.opacity(0.4))
                    }
                    
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Vill du lägga till en bild för att\nfölja din utveckling?")
                            .font(.system(size: 15))
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                        
                        Button {
                            showAddPhoto = true
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "plus")
                                    .font(.system(size: 13, weight: .medium))
                                Text("Ladda upp bild")
                                    .font(.system(size: 14, weight: .medium))
                            }
                            .foregroundColor(.primary)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(Color(.secondarySystemBackground))
                            .cornerRadius(20)
                            .overlay(
                                RoundedRectangle(cornerRadius: 20)
                                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                            )
                        }
                    }
                }
                .padding(16)
                .background(Color(.secondarySystemBackground))
                .cornerRadius(16)
                .padding(.horizontal, 20)
            } else {
                // Photos grid with upload button
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        // Upload button
                        Button {
                            showAddPhoto = true
                        } label: {
                            VStack(spacing: 8) {
                                Image(systemName: "plus")
                                    .font(.system(size: 24))
                                    .foregroundColor(.gray)
                                
                                Text("Ladda upp\nbild")
                                    .font(.system(size: 13))
                                    .foregroundColor(.gray)
                                    .multilineTextAlignment(.center)
                            }
                            .frame(width: 110, height: 150)
                            .background(Color(.secondarySystemBackground))
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [5]))
                                    .foregroundColor(.gray.opacity(0.3))
                            )
                        }
                        
                        // Recent photos
                        ForEach(photos.prefix(4)) { photo in
                            SmallWeightEntryCard(photo: photo)
                                .onTapGesture {
                                    showAllPhotos = true
                                }
                        }
                    }
                    .padding(.horizontal, 20)
                }
            }
        }
        .padding(.vertical, 16)
        .background(Color(.systemBackground))
        .cornerRadius(20)
        .padding(.horizontal, 16)
        .sheet(isPresented: $showAllPhotos) {
            ProgressPhotosView()
                .environmentObject(authViewModel)
        }
        .sheet(isPresented: $showAddPhoto) {
            AddWeightProgressView(onPhotoAdded: { newPhoto in
                photos.insert(newPhoto, at: 0)
            })
            .environmentObject(authViewModel)
        }
        .task {
            await loadPhotos()
        }
    }
    
    private func loadPhotos() async {
        guard let userId = authViewModel.currentUser?.id else {
            isLoading = false
            return
        }
        
        do {
            photos = try await ProgressPhotoService.shared.fetchPhotos(for: userId)
        } catch {
            print("❌ Error loading progress photos: \(error)")
        }
        
        isLoading = false
    }
}

// MARK: - Small Weight Entry Card
struct SmallWeightEntryCard: View {
    let photo: WeightProgressEntry
    
    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "sv_SE")
        formatter.dateFormat = "d MMM"
        return formatter.string(from: photo.photoDate)
    }
    
    var body: some View {
        ZStack(alignment: .bottomLeading) {
            AsyncImage(url: URL(string: photo.imageUrl)) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                case .failure:
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                case .empty:
                    Rectangle()
                        .fill(Color.gray.opacity(0.1))
                        .overlay(ProgressView())
                @unknown default:
                    Rectangle()
                        .fill(Color.gray.opacity(0.1))
                }
            }
            .frame(width: 110, height: 150)
            .clipped()
            
            // Gradient
            LinearGradient(
                colors: [.clear, .black.opacity(0.7)],
                startPoint: .center,
                endPoint: .bottom
            )
            
            // Info
            VStack(alignment: .leading, spacing: 2) {
                Text(String(format: "%.1f kg", photo.weightKg))
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white)
                Text(formattedDate)
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.8))
            }
            .padding(8)
        }
        .frame(width: 110, height: 150)
        .cornerRadius(12)
    }
}
