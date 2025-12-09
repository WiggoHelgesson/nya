import SwiftUI
import Foundation
import UIKit

// MARK: - Image Cache Manager
class ImageCacheManager {
    static let shared = ImageCacheManager()
    private let cache = NSCache<NSString, UIImage>()
    private let fileManager = FileManager.default
    private let cacheDirectory: URL
    private let prefetchLock = NSLock()
    private var prefetchingURLs: Set<String> = []
    
    private init() {
        // Configure memory cache
        cache.countLimit = 100
        cache.totalCostLimit = 50 * 1024 * 1024 // 50MB
        
        // Setup disk cache directory
        let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        cacheDirectory = documentsPath.appendingPathComponent("ImageCache")
        
        // Create cache directory if it doesn't exist
        try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
    }
    
    func getImage(for url: String) -> UIImage? {
        let key = NSString(string: url)
        
        // Try memory cache first
        if let cachedImage = cache.object(forKey: key) {
            return cachedImage
        }
        
        // Try disk cache
        if let diskImage = loadFromDisk(key: key) {
            cache.setObject(diskImage, forKey: key)
            return diskImage
        }
        
        return nil
    }
    
    func setImage(_ image: UIImage, for url: String) {
        let key = NSString(string: url)
        
        // Store in memory cache
        cache.setObject(image, forKey: key)
        
        // Store in disk cache
        saveToDisk(image: image, key: key)
    }

    func hasImage(for url: String) -> Bool {
        let key = NSString(string: url)
        if cache.object(forKey: key) != nil {
            return true
        }
        let fileURL = cacheFileURL(for: key)
        return fileManager.fileExists(atPath: fileURL.path)
    }
    
    private func loadFromDisk(key: NSString) -> UIImage? {
        let fileURL = cacheFileURL(for: key)
        
        guard let data = try? Data(contentsOf: fileURL),
              let image = UIImage(data: data) else {
            return nil
        }
        
        return image
    }
    
    private func cacheFileURL(for key: NSString) -> URL {
        let sanitized = key.replacingOccurrences(of: "/", with: "_")
        return cacheDirectory.appendingPathComponent(sanitized)
    }
    
    private func saveToDisk(image: UIImage, key: NSString) {
        guard let data = image.jpegData(compressionQuality: 0.8) else { return }
        
        let fileURL = cacheFileURL(for: key)
        
        try? data.write(to: fileURL)
    }
    
    @discardableResult
    func downloadAndCacheImage(from urlString: String) async throws -> UIImage {
        if urlString.hasPrefix("/"), fileManager.fileExists(atPath: urlString) {
            guard let localImage = UIImage(contentsOfFile: urlString) else {
                throw URLError(.cannotDecodeContentData)
            }
            setImage(localImage, for: urlString)
            return localImage
        }
        
        guard let url = URL(string: urlString) else {
            throw URLError(.badURL)
        }
        
        let (data, _) = try await URLSession.shared.data(from: url)
        guard let image = UIImage(data: data) else {
            throw URLError(.cannotDecodeContentData)
        }
        setImage(image, for: urlString)
        return image
    }
    
    func prefetch(urls: [String]) {
        // Use DispatchQueue for thread-safe access instead of locks in async context
        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self else { return }
            
            for url in urls where !url.isEmpty {
                if self.hasImage(for: url) { continue }
                
                var shouldDownload = false
                self.prefetchLock.lock()
                if !self.prefetchingURLs.contains(url) {
                    self.prefetchingURLs.insert(url)
                    shouldDownload = true
                }
                self.prefetchLock.unlock()
                
                guard shouldDownload else { continue }
                
                Task.detached(priority: .utility) { [weak self] in
                    guard let self else { return }
                    defer {
                        DispatchQueue.global(qos: .utility).async {
                            self.prefetchLock.lock()
                            self.prefetchingURLs.remove(url)
                            self.prefetchLock.unlock()
                        }
                    }
                    
                    do {
                        _ = try await self.downloadAndCacheImage(from: url)
                    } catch {
                        // Ignore failures silently
                    }
                }
            }
        }
    }
    
    func clearCache() {
        cache.removeAllObjects()
        try? fileManager.removeItem(at: cacheDirectory)
        try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
    }
}

// MARK: - Optimized Async Image
struct OptimizedAsyncImage: View {
    let url: String?
    let width: CGFloat
    let height: CGFloat
    let cornerRadius: CGFloat
    
    @State private var image: UIImage?
    @State private var isLoading = false
    @State private var hasError = false
    
    init(
        url: String?,
        width: CGFloat = 50,
        height: CGFloat = 50,
        cornerRadius: CGFloat = 0
    ) {
        self.url = url
        self.width = width
        self.height = height
        self.cornerRadius = cornerRadius
    }
    
    var body: some View {
        Group {
            if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: width, height: height)
                    .clipShape(cornerRadius > 0 ? AnyShape(RoundedRectangle(cornerRadius: cornerRadius)) : AnyShape(Circle()))
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
            } else if isLoading {
                // Loading placeholder with shimmer effect
                RoundedRectangle(cornerRadius: cornerRadius > 0 ? cornerRadius : width/2)
                    .fill(Color(.systemGray5))
                    .frame(width: width, height: height)
                    .overlay(
                        ProgressView()
                            .scaleEffect(0.8)
                            .tint(.gray)
                    )
                    .shimmer()
            } else {
                // Error placeholder
                RoundedRectangle(cornerRadius: cornerRadius > 0 ? cornerRadius : width/2)
                    .fill(Color(.systemGray5))
                    .frame(width: width, height: height)
                    .overlay(
                        Image(systemName: "person.fill")
                            .foregroundColor(.gray)
                            .font(.system(size: min(width, height) * 0.4))
                    )
            }
        }
        .onAppear {
            loadImage()
        }
        .onChange(of: url) { _, newUrl in
            if newUrl != url {
                loadImage()
            }
        }
    }
    
    private func loadImage() {
        guard let urlString = url, !urlString.isEmpty else {
            hasError = true
            return
        }
        
        // Check cache first
        if let cachedImage = ImageCacheManager.shared.getImage(for: urlString) {
            withAnimation(.easeInOut(duration: 0.2)) {
                self.image = cachedImage
            }
            return
        }
        
        isLoading = true
        hasError = false
        
        Task {
            do {
                let loadedImage = try await loadImageFromURL(urlString)
                
                await MainActor.run {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        self.image = loadedImage
                        self.isLoading = false
                    }
                }
            } catch {
                await MainActor.run {
                    self.isLoading = false
                    self.hasError = true
                }
            }
        }
    }
    
    private func loadImageFromURL(_ urlString: String) async throws -> UIImage {
        try await ImageCacheManager.shared.downloadAndCacheImage(from: urlString)
    }
}

// MARK: - Shimmer Effect
struct ShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = 0
    
    func body(content: Content) -> some View {
        content
            .overlay(
                Rectangle()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color.clear,
                                Color.white.opacity(0.3),
                                Color.clear
                            ]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .rotationEffect(.degrees(30))
                    .offset(x: phase)
                    .animation(
                        Animation.linear(duration: 1.5)
                            .repeatForever(autoreverses: false),
                        value: phase
                    )
            )
            .onAppear {
                phase = 200
            }
            .clipped()
    }
}

extension View {
    func shimmer() -> some View {
        modifier(ShimmerModifier())
    }
}

// MARK: - Profile Image Component
struct ProfileImage: View {
    let url: String?
    let size: CGFloat
    
    init(url: String?, size: CGFloat = 50) {
        self.url = url
        self.size = size
    }
    
    var body: some View {
        OptimizedAsyncImage(
            url: url,
            width: size,
            height: size,
            cornerRadius: size / 2
        )
    }
}
