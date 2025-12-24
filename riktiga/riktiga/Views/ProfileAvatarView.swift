import SwiftUI
import Supabase

/// A dedicated component for displaying profile avatars that properly respects size constraints
struct ProfileAvatarView: View {
    let path: String
    let size: CGFloat
    
    @State private var image: UIImage?
    @State private var isLoading = true
    @State private var loadFailed = false
    
    init(path: String, size: CGFloat = 72) {
        self.path = path
        self.size = size
    }
    
    var body: some View {
        Group {
            if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: size, height: size)
                    .clipShape(Circle())
            } else if isLoading {
                Circle()
                    .fill(Color(.systemGray5))
                    .frame(width: size, height: size)
                    .overlay(ProgressView().scaleEffect(0.6))
            } else if loadFailed || path.isEmpty {
                Circle()
                    .fill(Color(.systemGray5))
                    .frame(width: size, height: size)
                    .overlay(
                        Image(systemName: "person.fill")
                            .foregroundColor(.gray)
                            .font(.system(size: size * 0.5))
                    )
            } else {
                Circle()
                    .fill(Color(.systemGray5))
                    .frame(width: size, height: size)
                    .overlay(
                        Image(systemName: "person.fill")
                            .foregroundColor(.gray)
                            .font(.system(size: size * 0.5))
                    )
            }
        }
        .frame(width: size, height: size)
        .task(id: path) {
            await loadImage()
        }
    }
    
    private func loadImage() async {
        guard !path.isEmpty else {
            await MainActor.run {
                self.isLoading = false
                self.loadFailed = true
            }
            return
        }
        
        // Check cache first
        if let cachedImage = ImageCacheManager.shared.getImage(for: path) {
            await MainActor.run {
                self.image = cachedImage
                self.isLoading = false
            }
            return
        }
        
        await MainActor.run {
            self.isLoading = true
            self.loadFailed = false
        }
        
        do {
            // Handle full URLs
            if path.hasPrefix("http://") || path.hasPrefix("https://") {
                guard let url = URL(string: path) else {
                    throw NSError(domain: "InvalidURL", code: 0)
                }
                let (data, _) = try await URLSession.shared.data(from: url)
                guard let downloadedImage = UIImage(data: data) else {
                    throw NSError(domain: "InvalidImage", code: 0)
                }
                ImageCacheManager.shared.setImage(downloadedImage, for: path)
                await MainActor.run {
                    self.image = downloadedImage
                    self.isLoading = false
                }
            } else {
                // Try Supabase storage
                try await loadFromSupabase()
            }
        } catch {
            print("❌ ProfileAvatarView failed to load: \(error.localizedDescription)")
            await MainActor.run {
                self.isLoading = false
                self.loadFailed = true
            }
        }
    }
    
    private func loadFromSupabase() async throws {
        let supabase = SupabaseConfig.supabase
        
        // Try avatars bucket first
        let buckets = ["avatars", "workout-images"]
        
        for bucket in buckets {
            do {
                let signedURL = try await supabase.storage
                    .from(bucket)
                    .createSignedURL(path: path, expiresIn: 3600)
                
                guard let url = URL(string: signedURL.absoluteString) else { continue }
                
                var request = URLRequest(url: url)
                request.timeoutInterval = 10
                
                let (data, _) = try await URLSession.shared.data(for: request)
                
                guard let downloadedImage = UIImage(data: data) else { continue }
                
                ImageCacheManager.shared.setImage(downloadedImage, for: path)
                
                await MainActor.run {
                    self.image = downloadedImage
                    self.isLoading = false
                }
                return
            } catch {
                continue
            }
        }
        
        throw NSError(domain: "ImageNotFound", code: 404)
    }
}

#Preview {
    VStack(spacing: 20) {
        ProfileAvatarView(path: "", size: 72)
        ProfileAvatarView(path: "test", size: 48)
        ProfileAvatarView(path: "https://example.com/image.jpg", size: 100)
    }
}

