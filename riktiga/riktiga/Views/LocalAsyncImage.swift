import SwiftUI
import Supabase

// Helper view for loading images
struct LocalAsyncImage: View {
    let path: String
    @State private var image: UIImage?
    @State private var isLoading = true
    @State private var loadFailed = false
    
    private func loadImageFromSupabaseStorage(filename: String, originalPath: String) async throws {
        print("🔄 Attempting to load \(filename) using Supabase client...")
        
        // Try to create a signed URL using Supabase client
        let supabase = SupabaseConfig.supabase
        
        do {
            let signedURL = try await supabase.storage
                .from("workout-images")
                .createSignedURL(path: filename, expiresIn: 3600)
            
            print("✅ Got signed URL: \(signedURL)")
            
            // Download using the signed URL
            guard let url = URL(string: signedURL.absoluteString) else {
                throw NSError(domain: "InvalidURL", code: 1)
            }
            
            var request = URLRequest(url: url)
            request.timeoutInterval = 10
            
            let (data, _) = try await URLSession.shared.data(for: request)
            
            guard let downloadedImage = UIImage(data: data) else {
                throw NSError(domain: "InvalidImage", code: 1)
            }
            
            // Cache using the original path as key
            ImageCacheManager.shared.setImage(downloadedImage, for: originalPath)
            
            await MainActor.run {
                self.image = downloadedImage
                self.isLoading = false
                print("✅ Successfully loaded image using signed URL: \(filename)")
            }
        } catch {
            print("❌ Failed to load using Supabase client: \(error.localizedDescription)")
            await MainActor.run {
                self.isLoading = false
                self.loadFailed = true
            }
            throw error
        }
    }
    
    var body: some View {
        Group {
            if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else if isLoading {
                Rectangle()
                    .fill(Color(.systemGray4))
                    .overlay(ProgressView().scaleEffect(0.8))
            } else if loadFailed {
                // Plain gray background when image fails to load
                Rectangle()
                    .fill(Color(.systemGray4))
            } else {
                // Fallback - treat as failed, plain gray background
                Rectangle()
                    .fill(Color(.systemGray4))
            }
        }
        .task {
            // Handle empty path immediately
            if path.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                isLoading = false
                loadFailed = true
                return
            }
            await loadImage()
        }
        .onChange(of: path) { _, newPath in
            image = nil
            loadFailed = false
            
            // Handle empty path immediately
            if newPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                isLoading = false
                loadFailed = true
                return
            }
            
            isLoading = true
            Task {
                await loadImage()
            }
        }
    }
    
    private func loadImage() async {
        // Guard against empty paths
        guard !path.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            await MainActor.run {
                self.isLoading = false
                self.loadFailed = true
            }
            return
        }
        
        // Check if this is a Supabase Storage relative path (e.g., "banners/..." or "avatars/...")
        let supabaseStorageBuckets = ["banners/", "avatars/", "workout-images/"]
        let isSupabaseRelativePath = supabaseStorageBuckets.contains { path.hasPrefix($0) }
        
        // Convert to full URL if it's a Supabase relative path
        let effectivePath: String
        if isSupabaseRelativePath {
            // Determine the bucket name from the path
            // Note: Banners are stored in the "avatars" bucket under banners/ folder
            let bucket: String
            if path.hasPrefix("banners/") {
                bucket = "avatars"  // Banners are uploaded to avatars bucket
            } else if path.hasPrefix("avatars/") {
                bucket = "avatars"
            } else {
                bucket = "workout-images"
            }
            effectivePath = "https://xebatkodviqgkpsbyuiv.supabase.co/storage/v1/object/public/\(bucket)/\(path)"
            print("🔗 Converted relative path to Supabase URL: \(effectivePath)")
        } else {
            effectivePath = path
        }
        
        // Create cache key by normalizing the URL
        let cacheKey: String = {
            if effectivePath.hasPrefix("http") {
                // For URLs, remove query parameters to use consistent cache key
                return effectivePath.components(separatedBy: "?")[0]
            } else {
                // For local paths, use the full path
                return effectivePath
            }
        }()
        
        // Check cache first
        if let cachedImage = ImageCacheManager.shared.getImage(for: cacheKey) {
            await MainActor.run {
                self.image = cachedImage
                self.isLoading = false
                print("✅ Loaded image from cache: \(path)")
            }
            return
        }
        
        // Load from URL or file
        if effectivePath.hasPrefix("http") {
            // Remote URL - download and cache
            guard let url = URL(string: effectivePath) else {
                await MainActor.run {
                    self.isLoading = false
                    self.loadFailed = true
                    print("❌ Invalid URL: \(effectivePath)")
                }
                return
            }
            
            do {
                // Create URLRequest with proper caching
                var request = URLRequest(url: url)
                request.cachePolicy = .returnCacheDataElseLoad
                request.timeoutInterval = 30
                
                // Setup URLSession with persistent caching
                let config = URLSessionConfiguration.default
                config.urlCache = URLCache(memoryCapacity: 50 * 1024 * 1024, diskCapacity: 200 * 1024 * 1024, diskPath: "imageCache")
                let session = URLSession(configuration: config)
                
                let (data, response) = try await session.data(for: request)
                
                // Check if request was successful
                if let httpResponse = response as? HTTPURLResponse {
                    print("📡 HTTP Status: \(httpResponse.statusCode) for \(effectivePath)")
                    
                    if httpResponse.statusCode != 200 {
                        await MainActor.run {
                            self.isLoading = false
                            self.loadFailed = true
                            print("❌ Failed to load image: HTTP \(httpResponse.statusCode)")
                        }
                        return
                    }
                }
                
                if let downloadedImage = UIImage(data: data) {
                    // Cache the image using the normalized key (without query params)
                    ImageCacheManager.shared.setImage(downloadedImage, for: cacheKey)
                    
                    await MainActor.run {
                        self.image = downloadedImage
                        self.isLoading = false
                        print("✅ Downloaded and cached image: \(cacheKey)")
                    }
                } else {
                    await MainActor.run {
                        self.isLoading = false
                        self.loadFailed = true
                        print("❌ Could not decode image from URL: \(effectivePath)")
                    }
                }
            } catch {
                await MainActor.run {
                    self.isLoading = false
                    self.loadFailed = true
                    print("❌ Failed to load image from URL: \(error)")
                }
            }
        } else {
            // Local file path
            print("🔍 Attempting to load local image from: \(path)")
            
            // Check if this looks like a local path from another device
            let currentDocumentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!.path
            let isOtherDevicePath = path.contains("/Containers/Data/Application/") && !path.contains(currentDocumentsPath)
            
            if isOtherDevicePath {
                // This is a path from another device - try to extract the filename and load from Supabase Storage
                let filename = (path as NSString).lastPathComponent
                print("⚠️ Local path from another device detected, trying to load from Supabase Storage")
                print("📝 Original path: \(path)")
                print("📝 Extracted filename: \(filename)")
                
                // Try to load from Supabase Storage
                let supabaseStorageURL = "https://xebatkodviqgkpsbyuiv.supabase.co/storage/v1/object/public/workout-images/\(filename)"
                print("🔗 Supabase Storage URL: \(supabaseStorageURL)")
                
                guard let storageURL = URL(string: supabaseStorageURL) else {
                    await MainActor.run {
                        self.isLoading = false
                        self.loadFailed = true
                        print("❌ Could not create Supabase storage URL")
                    }
                    return
                }
                
                // Try to download from Supabase Storage using public URL
                do {
                    var request = URLRequest(url: storageURL)
                    request.cachePolicy = .returnCacheDataElseLoad
                    request.timeoutInterval = 10
                    
                    let config = URLSessionConfiguration.default
                    config.urlCache = URLCache(memoryCapacity: 50 * 1024 * 1024, diskCapacity: 200 * 1024 * 1024, diskPath: "imageCache")
                    let session = URLSession(configuration: config)
                    
                    let (data, response) = try await session.data(for: request)
                    
                    if let httpResponse = response as? HTTPURLResponse {
                        print("📡 HTTP Status: \(httpResponse.statusCode) for \(filename)")
                        
                        if httpResponse.statusCode == 200, let downloadedImage = UIImage(data: data) {
                            // Cache using the original path as key
                            ImageCacheManager.shared.setImage(downloadedImage, for: path)
                            
                            await MainActor.run {
                                self.image = downloadedImage
                                self.isLoading = false
                                print("✅ Successfully loaded image from Supabase Storage: \(filename)")
                            }
                        } else if httpResponse.statusCode == 404 {
                            // Try to use Supabase client to create a signed URL
                            print("⚠️ Public URL returned 404, trying to use Supabase client to fetch signed URL...")
                            try await loadImageFromSupabaseStorage(filename: filename, originalPath: path)
                        } else {
                            print("❌ HTTP Error: \(httpResponse.statusCode)")
                            await MainActor.run {
                                self.isLoading = false
                                self.loadFailed = true
                            }
                        }
                    }
                } catch {
                    print("❌ Error loading from Supabase Storage: \(error.localizedDescription)")
                    // Try to use Supabase client as fallback
                    do {
                        try await loadImageFromSupabaseStorage(filename: filename, originalPath: path)
                    } catch {
                        await MainActor.run {
                            self.isLoading = false
                            self.loadFailed = true
                        }
                    }
                }
            } else {
                // Try to load as local file
                let fileURL = URL(fileURLWithPath: path)
                
                if FileManager.default.fileExists(atPath: fileURL.path) {
                    if let imageData = try? Data(contentsOf: fileURL),
                       let uiImage = UIImage(data: imageData) {
                        // Cache the local image using the full path
                        ImageCacheManager.shared.setImage(uiImage, for: path)
                        
                        await MainActor.run {
                            self.image = uiImage
                            self.isLoading = false
                            print("✅ Successfully loaded local image from: \(path)")
                        }
                    } else {
                        await MainActor.run {
                            self.isLoading = false
                            self.loadFailed = true
                            print("❌ Failed to decode image data from: \(path)")
                        }
                    }
                } else {
                    await MainActor.run {
                        self.isLoading = false
                        self.loadFailed = true
                        print("❌ File does not exist at path: \(path)")
                    }
                }
            }
        }
    }
}

