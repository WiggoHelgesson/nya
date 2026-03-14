import SwiftUI

struct EventDetailView: View {
    let event: Event
    let isOwnEvent: Bool
    var onDeleted: (() -> Void)? = nil
    
    @State private var images: [EventImage] = []
    @State private var isLoading = true
    @State private var showDeleteConfirmation = false
    @State private var isDeleting = false
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // MARK: - Cover Image
                OptimizedAsyncImage(
                    url: event.coverImageUrl,
                    width: UIScreen.main.bounds.width,
                    height: 240,
                    cornerRadius: 0
                )
                .frame(maxWidth: .infinity)
                .frame(height: 240)
                .clipped()
                
                VStack(alignment: .leading, spacing: 16) {
                    // MARK: - Title
                    Text(event.title)
                        .font(.system(size: 26, weight: .bold))
                        .foregroundColor(.primary)
                    
                    // MARK: - Description
                    Text(event.description)
                        .font(.system(size: 15))
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    
                    Divider()
                        .padding(.vertical, 4)
                    
                    // MARK: - Images
                    if isLoading {
                        HStack {
                            Spacer()
                            ProgressView()
                                .tint(.black)
                            Spacer()
                        }
                        .padding(.vertical, 40)
                    } else if images.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "photo.on.rectangle")
                                .font(.system(size: 40))
                                .foregroundColor(.gray.opacity(0.5))
                            Text(L.t(sv: "Inga bilder", nb: "Ingen bilder"))
                                .font(.system(size: 15))
                                .foregroundColor(.gray)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                    } else {
                        Text(L.t(sv: "Bilder (\(images.count))", nb: "Bilder (\(images.count))"))
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.primary)
                        
                        LazyVStack(spacing: 12) {
                            ForEach(images) { img in
                                EventImageView(imageUrl: img.imageUrl)
                            }
                        }
                    }
                }
                .padding(16)
            }
        }
        .background(Color(.systemBackground))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if isOwnEvent {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showDeleteConfirmation = true
                    } label: {
                        Image(systemName: "trash")
                            .foregroundColor(.red)
                    }
                    .disabled(isDeleting)
                }
            }
        }
        .confirmationDialog(
            L.t(sv: "Ta bort händelse?", nb: "Slett hendelse?"),
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button(L.t(sv: "Ta bort", nb: "Slett"), role: .destructive) {
                Task { await deleteEvent() }
            }
            Button(L.t(sv: "Avbryt", nb: "Avbryt"), role: .cancel) {}
        } message: {
            Text(L.t(
                sv: "Alla bilder och data för denna händelse kommer tas bort permanent.",
                nb: "Alle bilder og data for denne hendelsen vil bli slettet permanent."
            ))
        }
        .task {
            await loadImages()
        }
    }
    
    private func loadImages() async {
        do {
            let fetched = try await EventService.shared.fetchEventImages(eventId: event.id)
            await MainActor.run {
                images = fetched
                isLoading = false
            }
            
            let urls = fetched.map { $0.imageUrl }
            await ImageCacheManager.shared.prefetchHighPriority(urls: urls)
        } catch {
            await MainActor.run { isLoading = false }
        }
    }
    
    private func deleteEvent() async {
        isDeleting = true
        do {
            try await EventService.shared.deleteEvent(eventId: event.id, userId: event.userId)
            await MainActor.run {
                isDeleting = false
                onDeleted?()
                dismiss()
            }
        } catch {
            await MainActor.run { isDeleting = false }
        }
    }
}

// MARK: - Event Image View with retry
private struct EventImageView: View {
    let imageUrl: String
    
    @State private var image: UIImage?
    @State private var isLoading = true
    @State private var loadFailed = false
    @State private var retryCount = 0
    
    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 280)
                    .clipped()
            } else if isLoading {
                Color(.systemGray5)
                    .frame(height: 280)
                    .overlay { ProgressView().tint(.secondary) }
            } else if loadFailed {
                Color(.systemGray5)
                    .frame(height: 280)
                    .overlay {
                        VStack(spacing: 8) {
                            Image(systemName: "photo")
                                .font(.system(size: 24))
                                .foregroundColor(Color(.systemGray3))
                            Button(L.t(sv: "Försök igen", nb: "Prøv igjen")) {
                                retryCount += 1
                            }
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.blue)
                        }
                    }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .task(id: retryCount) {
            await loadImage()
        }
    }
    
    private func loadImage() async {
        let rewrittenUrl = SupabaseConfig.rewriteURL(imageUrl)
        
        if let cached = ImageCacheManager.shared.getImage(for: rewrittenUrl) {
            await MainActor.run {
                self.image = cached
                self.isLoading = false
            }
            return
        }
        
        await MainActor.run {
            isLoading = true
            loadFailed = false
        }
        
        do {
            guard let url = URL(string: rewrittenUrl) else { throw URLError(.badURL) }
            let (data, _) = try await SupabaseConfig.urlSession.data(from: url)
            guard let downloaded = UIImage(data: data) else { throw URLError(.cannotDecodeContentData) }
            
            ImageCacheManager.shared.setImage(downloaded, for: rewrittenUrl)
            
            await MainActor.run {
                self.image = downloaded
                self.isLoading = false
            }
        } catch {
            print("❌ EventImageView failed to load \(rewrittenUrl.prefix(60)): \(error.localizedDescription)")
            await MainActor.run {
                self.isLoading = false
                self.loadFailed = true
            }
        }
    }
}

