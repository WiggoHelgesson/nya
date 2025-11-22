import SwiftUI
import PhotosUI
import Combine

struct ProgressPhoto: Identifiable, Codable, Equatable {
    let id: UUID
    let fileName: String
    let date: Date
}

@MainActor
final class ProgressPhotoStore: ObservableObject {
    @Published private(set) var photos: [ProgressPhoto] = []
    
    private let metadataURL: URL
    private let directoryURL: URL
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()
    
    init() {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        directoryURL = documents.appendingPathComponent("progress_photos", isDirectory: true)
        metadataURL = directoryURL.appendingPathComponent("metadata.json")
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        createStorageDirectoryIfNeeded()
        load()
    }
    
    func addPhoto(data: Data, date: Date = Date()) throws {
        let id = UUID()
        let fileName = "\(id.uuidString).jpg"
        let url = directoryURL.appendingPathComponent(fileName)
        try data.write(to: url, options: [.atomic])
        let photo = ProgressPhoto(id: id, fileName: fileName, date: date)
        photos.append(photo)
        sortPhotos()
        try save()
    }
    
    func deletePhoto(_ photo: ProgressPhoto) {
        let url = directoryURL.appendingPathComponent(photo.fileName)
        try? FileManager.default.removeItem(at: url)
        photos.removeAll { $0.id == photo.id }
        try? save()
    }
    
    func image(for photo: ProgressPhoto) -> UIImage? {
        let url = directoryURL.appendingPathComponent(photo.fileName)
        return UIImage(contentsOfFile: url.path)
    }
    
    private func createStorageDirectoryIfNeeded() {
        if !FileManager.default.fileExists(atPath: directoryURL.path) {
            try? FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        }
    }
    
    private func load() {
        guard let data = try? Data(contentsOf: metadataURL),
              let decoded = try? decoder.decode([ProgressPhoto].self, from: data) else {
            photos = []
            return
        }
        photos = decoded
        sortPhotos()
    }
    
    private func save() throws {
        createStorageDirectoryIfNeeded()
        let data = try encoder.encode(photos)
        try data.write(to: metadataURL, options: [.atomic])
    }
    
    private func sortPhotos() {
        photos.sort { $0.date < $1.date }
    }
}

struct ProgressDevelopmentView: View {
    @StateObject private var store = ProgressPhotoStore()
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var showPhotoPicker = false
    @State private var selectedPhoto: ProgressPhoto?
    @State private var showSlideshow = false
    @State private var isSavingPhoto = false
    @State private var saveError: String?
    
    private let gridColumns = [GridItem(.adaptive(minimum: 140), spacing: 16)]
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        formatter.locale = Locale(identifier: "sv_SE")
        return formatter
    }()
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                headerSection
                actionButtons
                gallerySection
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 24)
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .navigationTitle("Din utveckling")
        .sheet(item: $selectedPhoto) { photo in
            NavigationStack {
                ProgressPhotoDetailView(
                    store: store,
                    initialPhoto: photo
                )
            }
        }
        .sheet(isPresented: $showSlideshow) {
            ProgressSlideshowView(store: store)
        }
        .photosPicker(isPresented: $showPhotoPicker, selection: $selectedPhotoItem, matching: .images)
        .onChange(of: selectedPhotoItem) { _, newItem in
            guard let newItem else { return }
            Task { await importPhoto(from: newItem) }
        }
        .alert("Kunde inte spara bilden", isPresented: Binding(
            get: { saveError != nil },
            set: { _ in saveError = nil }
        ), actions: {
            Button("OK", role: .cancel) {}
        }, message: {
            Text(saveError ?? "")
        })
    }
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Följ din visuella utveckling")
                .font(.system(size: 20, weight: .bold))
            Text("Lägg till framstegsbilder, jämför dem sida vid sida eller spela upp hela resan som en kort film.")
                .font(.system(size: 14))
                .foregroundColor(.secondary)
        }
    }
    
    private var actionButtons: some View {
        VStack(spacing: 12) {
            Button {
                showSlideshow = true
            } label: {
                HStack {
                    Image(systemName: "film")
                    Text("Se film")
                        .fontWeight(.semibold)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(store.photos.isEmpty ? Color.gray : Color.black)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .disabled(store.photos.isEmpty)
            
            Button {
                showPhotoPicker = true
            } label: {
                HStack {
                    Image(systemName: "camera.fill")
                    Text(isSavingPhoto ? "Laddar..." : "Lägg till framsteg")
                        .fontWeight(.semibold)
                }
                .foregroundColor(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 4)
            }
            .disabled(isSavingPhoto)
        }
    }
    
    private var gallerySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            if store.photos.isEmpty {
                Text("Inga framsteg än")
                    .font(.headline)
                Text("Lägg till din första bild för att börja spåra din resa.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            } else {
                LazyVGrid(columns: gridColumns, spacing: 16) {
                    ForEach(store.photos) { photo in
                        Button {
                            selectedPhoto = photo
                        } label: {
                            ProgressPhotoCard(image: store.image(for: photo), date: dateFormatter.string(from: photo.date))
                        }
                        .buttonStyle(PlainButtonStyle())
                        .contextMenu {
                            Button(role: .destructive) {
                                store.deletePhoto(photo)
                            } label: {
                                Label("Ta bort", systemImage: "trash")
                            }
                        }
                    }
                }
            }
        }
    }
    
    private func importPhoto(from item: PhotosPickerItem) async {
        isSavingPhoto = true
        defer {
            isSavingPhoto = false
            selectedPhotoItem = nil
            showPhotoPicker = false
        }
        guard let data = try? await item.loadTransferable(type: Data.self) else {
            await MainActor.run {
                saveError = "Kunde inte läsa bilden."
            }
            return
        }
        if let image = UIImage(data: data), let compressed = image.jpegData(compressionQuality: 0.9) {
            do {
                try store.addPhoto(data: compressed)
            } catch {
                saveError = "Något gick fel när bilden skulle sparas."
            }
        } else {
            saveError = "Kunde inte bearbeta bilden."
        }
    }
}

private struct ProgressPhotoCard: View {
    let image: UIImage?
    let date: String
    
    var body: some View {
        ZStack(alignment: .bottomLeading) {
            Group {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                } else {
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .overlay(
                            Image(systemName: "photo")
                                .font(.system(size: 32))
                                .foregroundColor(.gray)
                        )
                }
            }
            .frame(height: 200)
            .frame(maxWidth: .infinity)
            .clipped()
            .cornerRadius(18)
            .overlay(
                LinearGradient(colors: [.black.opacity(0.0), .black.opacity(0.6)], startPoint: .center, endPoint: .bottom)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            )
            
            Text(date)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white)
                .padding(10)
        }
    }
}

private struct ProgressPhotoDetailView: View {
    @ObservedObject var store: ProgressPhotoStore
    let initialPhoto: ProgressPhoto
    
    @State private var mode: Mode = .single
    @State private var primaryPhoto: ProgressPhoto
    @State private var comparisonPhoto: ProgressPhoto?
    
    private let formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.locale = Locale(identifier: "sv_SE")
        return formatter
    }()
    
    init(store: ProgressPhotoStore, initialPhoto: ProgressPhoto) {
        self.store = store
        self.initialPhoto = initialPhoto
        _primaryPhoto = State(initialValue: initialPhoto)
    }
    
    var body: some View {
        VStack(spacing: 20) {
            Picker("Mode", selection: $mode) {
                Text("Singel").tag(Mode.single)
                Text("Jämförelse").tag(Mode.comparison)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            
            if mode == .single {
                ProgressPhotoLargeView(image: store.image(for: primaryPhoto), caption: formatter.string(from: primaryPhoto.date))
            } else {
                comparisonView
            }
            
            thumbnails
        }
        .padding(.bottom, 16)
        .navigationTitle("Progressbilder")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private var comparisonView: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                ProgressPhotoLargeView(image: store.image(for: primaryPhoto), caption: formatter.string(from: primaryPhoto.date))
                ProgressPhotoLargeView(image: store.image(for: comparisonPhoto ?? primaryPhoto), caption: comparisonCaption)
            }
            .frame(height: 320)
            
            Picker("Jämför med", selection: Binding(
                get: { comparisonPhoto?.id ?? primaryPhoto.id },
                set: { newValue in
                    comparisonPhoto = store.photos.first(where: { $0.id == newValue })
                }
            )) {
                ForEach(store.photos) { photo in
                    Text(formatter.string(from: photo.date))
                        .tag(photo.id)
                }
            }
            .pickerStyle(.menu)
            .padding(.horizontal)
        }
    }
    
    private var thumbnails: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(store.photos) { photo in
                    let isSelected = photo.id == primaryPhoto.id
                    ProgressPhotoThumbnail(image: store.image(for: photo), date: formatter.string(from: photo.date), isSelected: isSelected)
                        .onTapGesture {
                            primaryPhoto = photo
                            if comparisonPhoto == nil {
                                comparisonPhoto = store.photos.filter { $0.id != photo.id }.last
                            }
                        }
                }
            }
            .padding(.horizontal)
        }
    }
    
    private var comparisonCaption: String {
        if let comparisonPhoto {
            return formatter.string(from: comparisonPhoto.date)
        }
        return "Välj bild"
    }
    
    private enum Mode {
        case single
        case comparison
    }
}

private struct ProgressPhotoLargeView: View {
    let image: UIImage?
    let caption: String
    
    var body: some View {
        ZStack(alignment: .bottomLeading) {
            Group {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                } else {
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .overlay(
                            Image(systemName: "photo")
                                .font(.system(size: 32))
                                .foregroundColor(.gray)
                        )
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                LinearGradient(colors: [.clear, .black.opacity(0.7)], startPoint: .center, endPoint: .bottom)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            )
            
            Text(caption)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white)
                .padding(10)
        }
    }
}

private struct ProgressPhotoThumbnail: View {
    let image: UIImage?
    let date: String
    let isSelected: Bool
    
    var body: some View {
        VStack(spacing: 6) {
            Group {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                } else {
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .overlay(
                            Image(systemName: "photo")
                                .foregroundColor(.gray)
                        )
                }
            }
            .frame(width: 90, height: 120)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 3)
            )
            
            Text(date)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.secondary)
        }
    }
}

private struct ProgressSlideshowView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var store: ProgressPhotoStore
    @State private var currentIndex = 0
    
    private let timer = Timer.publish(every: 1.2, on: .main, in: .common).autoconnect()
    private let formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.locale = Locale(identifier: "sv_SE")
        return formatter
    }()
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Din film")
                .font(.title2.bold())
            
            if store.photos.isEmpty {
                Text("Lägg till några bilder för att skapa en film.")
                    .font(.callout)
                    .foregroundColor(.secondary)
            } else {
                TabView(selection: $currentIndex) {
                    ForEach(Array(store.photos.enumerated()), id: \.element.id) { index, photo in
                        VStack {
                            if let image = store.image(for: photo) {
                                Image(uiImage: image)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(maxHeight: 400)
                                    .clipShape(RoundedRectangle(cornerRadius: 20))
                            } else {
                                RoundedRectangle(cornerRadius: 20)
                                    .fill(Color.gray.opacity(0.2))
                            }
                            
                            Text(formatter.string(from: photo.date))
                                .font(.headline)
                                .padding(.top, 8)
                        }
                        .padding()
                        .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .always))
                .frame(height: 480)
                .onReceive(timer) { _ in
                    guard store.photos.count > 1 else { return }
                    withAnimation(.easeInOut(duration: 0.4)) {
                        currentIndex = (currentIndex + 1) % store.photos.count
                    }
                }
            }
            
            Button("Stäng") {
                dismiss()
            }
            .font(.system(size: 16, weight: .semibold))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(Color.black)
            .foregroundColor(.white)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .padding(.horizontal)
        }
        .padding()
        .presentationDetents([.large])
    }
}

