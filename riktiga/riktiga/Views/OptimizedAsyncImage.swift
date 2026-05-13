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
        // Configure memory cache - reduced for better performance
        cache.countLimit = 75 // Reduced from 100
        cache.totalCostLimit = 30 * 1024 * 1024 // 30MB (reduced from 50MB)
        
        // Setup disk cache directory
        let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        cacheDirectory = documentsPath.appendingPathComponent("ImageCache")
        
        // Create cache directory if it doesn't exist
        try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        
        // Auto-cleanup old disk cache on init
        Task.detached(priority: .background) {
            self.cleanupOldDiskCache()
        }
    }
    
    /// Clean up disk cache files older than 7 days
    private func cleanupOldDiskCache() {
        let maxAge: TimeInterval = 7 * 24 * 60 * 60 // 7 days
        let cutoffDate = Date().addingTimeInterval(-maxAge)
        
        guard let files = try? fileManager.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: [.creationDateKey]) else { return }
        
        for file in files {
            guard let attributes = try? fileManager.attributesOfItem(atPath: file.path),
                  let creationDate = attributes[.creationDate] as? Date else { continue }
            
            if creationDate < cutoffDate {
                try? fileManager.removeItem(at: file)
            }
        }
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
        
        let rewritten = SupabaseConfig.rewriteURL(urlString)
        guard let url = URL(string: rewritten) else {
            print("❌ [IMG] Bad URL: \(urlString)")
            throw URLError(.badURL)
        }

        // Truncated DB URLs: /object/sign/... without ?token= — go straight to public URL (no wasted 400).
        if WorkoutImageURL.signURLMissingToken(urlString),
           let publicStr = WorkoutImageURL.publicFallbackURL(from: urlString),
           let publicURL = URL(string: publicStr) {
            #if DEBUG
            print("📷 [IMG] Sign URL missing token — loading public URL directly")
            #endif
            let (dataP, responseP) = try await SupabaseConfig.urlSession.data(from: publicURL)
            let codeP = (responseP as? HTTPURLResponse)?.statusCode ?? 0
            #if DEBUG
            if codeP != 200 {
                print("❌ [IMG] HTTP \(codeP) for public workout-image: \(publicStr.prefix(120))")
            }
            #endif
            if (200...299).contains(codeP), let img = UIImage(data: dataP) {
                setImage(img, for: urlString)
                return img
            }
        }
        
        #if DEBUG
        print("📷 [IMG] Downloading: \(url.absoluteString.prefix(120))")
        #endif
        
        let (data, response) = try await SupabaseConfig.urlSession.data(from: url)
        let http = response as? HTTPURLResponse
        let status = http?.statusCode ?? 0
        
        #if DEBUG
        if status == 400, data.count < 512 {
            let body = String(data: data, encoding: .utf8) ?? ""
            print("❌ [IMG] HTTP 400 body (prefix): \(body.prefix(200))")
        }
        if status != 200 {
            print("❌ [IMG] HTTP \(status) for: \(url.absoluteString.prefix(120))")
        }
        #endif
        
        var image = UIImage(data: data)
        let statusOK = (200...299).contains(status)
        
        if !statusOK || image == nil,
           let fallback = WorkoutImageURL.publicFallbackURL(from: urlString),
           let fallbackURL = URL(string: fallback),
           fallback != rewritten {
            #if DEBUG
            print("📷 [IMG] Retrying public URL for workout-images")
            #endif
            let (data2, response2) = try await SupabaseConfig.urlSession.data(from: fallbackURL)
            let http2 = response2 as? HTTPURLResponse
            let status2 = http2?.statusCode ?? 0
            #if DEBUG
            if status2 == 400, data2.count < 512 {
                let body2 = String(data: data2, encoding: .utf8) ?? ""
                print("❌ [IMG] Fallback HTTP 400 body (prefix): \(body2.prefix(200))")
            }
            #endif
            if (200...299).contains(status2), let img2 = UIImage(data: data2) {
                setImage(img2, for: urlString)
                return img2
            }
        }
        
        guard statusOK, let final = image else {
            print("❌ [IMG] Cannot decode image data (\(data.count) bytes) from: \(url.absoluteString.prefix(120))")
            throw URLError(.cannotDecodeContentData)
        }
        setImage(final, for: urlString)
        return final
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
    
    /// High-priority prefetch for immediately visible images (first few posts)
    func prefetchHighPriority(urls: [String]) async {
        await withTaskGroup(of: Void.self) { group in
            for url in urls.prefix(12) where !url.isEmpty {
                if hasImage(for: url) { continue }
                
                group.addTask {
                    do {
                        _ = try await self.downloadAndCacheImage(from: url)
                    } catch {
                        // Ignore failures
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
    
    /// Trim memory cache to reduce memory pressure (keeps disk cache intact)
    func trimCache() {
        // Reduce in-memory cache limit temporarily to force eviction
        let currentLimit = cache.countLimit
        cache.countLimit = 20 // Keep only 20 most recent images in memory
        cache.countLimit = currentLimit // Restore limit
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
    @State private var loadedUrl: String? // Track which URL we've loaded
    
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
        
        // Check cache immediately at init to avoid flash of loading state
        if let urlString = url, !urlString.isEmpty,
           let cachedImage = ImageCacheManager.shared.getImage(for: urlString) {
            _image = State(initialValue: cachedImage)
            _isLoading = State(initialValue: false)
            _loadedUrl = State(initialValue: urlString)
        }
    }
    
    var body: some View {
        Group {
            if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: width, height: height)
                    .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
            } else if isLoading {
                // Loading placeholder with shimmer effect
                RoundedRectangle(cornerRadius: cornerRadius)
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
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(Color(.systemGray5))
                    .frame(width: width, height: height)
                    .overlay(
                        Image(systemName: "photo")
                            .foregroundColor(.gray)
                            .font(.system(size: min(width, height) * 0.3))
                    )
            }
        }
        .onAppear {
            loadImageIfNeeded()
        }
        .onChange(of: url) { oldUrl, newUrl in
            // URL changed - reset state and reload
            if oldUrl != newUrl {
                image = nil
                isLoading = false
                hasError = false
                loadedUrl = nil
                loadImageIfNeeded()
            }
        }
    }
    
    private func loadImageIfNeeded() {
        // Skip if already loaded THIS URL
        if let loaded = loadedUrl, loaded == url, image != nil {
            return
        }
        
        guard let urlString = url, !urlString.isEmpty else {
            hasError = true
            return
        }
        
        // Check cache first (double-check in case it was cached after init)
        if let cachedImage = ImageCacheManager.shared.getImage(for: urlString) {
            // No animation needed if loading from cache - appear instantly
            self.image = cachedImage
            self.loadedUrl = urlString
            self.isLoading = false
            return
        }
        
        isLoading = true
        hasError = false
        
        // Capture the URL we're loading to check later
        let urlToLoad = urlString
        
        Task {
            do {
                let loadedImage = try await loadImageFromURL(urlToLoad)
                
                await MainActor.run {
                    // Only set the image if the URL hasn't changed while loading
                    guard self.url == urlToLoad else { return }
                    
                    withAnimation(.easeInOut(duration: 0.2)) {
                        self.image = loadedImage
                        self.loadedUrl = urlToLoad
                        self.isLoading = false
                    }
                }
            } catch {
                await MainActor.run {
                    // Only set error if URL hasn't changed
                    guard self.url == urlToLoad else { return }
                    
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
    
    /// Apple-style entrance animation - content fades in and slides up from its resting position
    func pageEntrance(delay: Double = 0) -> some View {
        modifier(PageEntranceModifier(delay: delay))
    }
}

// MARK: - Page Entrance Animation
struct PageEntranceModifier: ViewModifier {
    let delay: Double
    @State private var isVisible = false
    
    func body(content: Content) -> some View {
        content
            .opacity(isVisible ? 1 : 0)
            .onAppear {
                withAnimation(.smooth(duration: 0.5).delay(delay)) {
                    isVisible = true
                }
            }
    }
}

// MARK: - Profile Image Component
struct ProfileImage: View {
    let url: String?
    let size: CGFloat
    let isPro: Bool
    
    init(url: String?, size: CGFloat = 50, isPro: Bool = false) {
        self.url = url
        self.size = size
        self.isPro = isPro
    }
    
    var body: some View {
        if isPro {
            ZStack {
                RoundedRectangle(cornerRadius: size * 0.3)
                    .fill(
                        LinearGradient(
                            colors: [.black, Color(.systemGray2), .white, Color(.systemGray2), .black],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: size + 5, height: size + 5)
                
                OptimizedAsyncImage(
                    url: url,
                    width: size,
                    height: size,
                    cornerRadius: size * 0.28
                )
            }
            .id(url ?? "no-url")
        } else {
            OptimizedAsyncImage(
                url: url,
                width: size,
                height: size,
                cornerRadius: size / 2
            )
            .id(url ?? "no-url")
        }
    }
}

// MARK: - Cached Remote Image (flexible size, scaledToFill)
//
// Drop-in replacement for `AsyncImage` when you need a remote image rendered
// with `.scaledToFill()` inside a parent-provided frame (cards, carousels,
// cover photos). Uses the shared `ImageCacheManager` memory + disk cache so
// the same URL never has to hit the network twice.
struct CachedRemoteImage<Placeholder: View>: View {
    let url: String?
    @ViewBuilder var placeholder: () -> Placeholder

    @State private var image: UIImage?
    @State private var loadedUrl: String?
    @State private var isLoading: Bool = false

    init(url: String?, @ViewBuilder placeholder: @escaping () -> Placeholder) {
        self.url = url
        self.placeholder = placeholder

        if let urlString = url, !urlString.isEmpty,
           let cached = ImageCacheManager.shared.getImage(for: urlString) {
            _image = State(initialValue: cached)
            _loadedUrl = State(initialValue: urlString)
        }
    }

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                placeholder()
            }
        }
        .onAppear { loadIfNeeded() }
        .onChange(of: url) { _, _ in
            image = nil
            loadedUrl = nil
            isLoading = false
            loadIfNeeded()
        }
    }

    private func loadIfNeeded() {
        if let loadedUrl, loadedUrl == url, image != nil { return }
        guard let urlString = url, !urlString.isEmpty else { return }

        if let cached = ImageCacheManager.shared.getImage(for: urlString) {
            self.image = cached
            self.loadedUrl = urlString
            return
        }

        guard !isLoading else { return }
        isLoading = true
        let urlToLoad = urlString

        Task {
            do {
                let loaded = try await ImageCacheManager.shared.downloadAndCacheImage(from: urlToLoad)
                await MainActor.run {
                    guard self.url == urlToLoad else { return }
                    self.image = loaded
                    self.loadedUrl = urlToLoad
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    guard self.url == urlToLoad else { return }
                    self.isLoading = false
                }
            }
        }
    }
}

// Keep for backward compatibility
struct ProProfileImage: View {
    let url: String?
    let size: CGFloat
    
    init(url: String?, size: CGFloat = 50) {
        self.url = url
        self.size = size
    }
    
    var body: some View {
        ProfileImage(url: url, size: size, isPro: true)
    }
}
