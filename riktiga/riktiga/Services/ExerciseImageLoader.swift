import Foundation
import UIKit
import SwiftUI
import Combine

class ExerciseImageLoader: ObservableObject {
    @Published var image: UIImage?
    @Published var isLoading = false
    
    private let apiKey = "4695be4a29msh147831944f1aae7p1da0afjsn9353381d0966"
    private static let memoryCache = NSCache<NSString, UIImage>()
    private static let fileManager = FileManager.default
    private static let diskDirectory: URL = {
        let url = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
            .appendingPathComponent("exercise_images", isDirectory: true)
        if !FileManager.default.fileExists(atPath: url.path) {
            try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        }
        return url
    }()
    
    private static func cacheKey(for exerciseId: String) -> NSString {
        return NSString(string: exerciseId)
    }
    
    private static func diskURL(for exerciseId: String) -> URL {
        diskDirectory.appendingPathComponent("\(exerciseId).img")
    }
    
    private static func cachedImage(for exerciseId: String) -> UIImage? {
        if let cached = memoryCache.object(forKey: cacheKey(for: exerciseId)) {
            return cached
        }
        let url = diskURL(for: exerciseId)
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        if let data = try? Data(contentsOf: url), let image = UIImage(data: data) {
            memoryCache.setObject(image, forKey: cacheKey(for: exerciseId))
            return image
        }
        return nil
    }
    
    private static func storeImage(_ imageData: Data, for exerciseId: String) {
        let url = diskURL(for: exerciseId)
        if let image = UIImage(data: imageData) {
            memoryCache.setObject(image, forKey: cacheKey(for: exerciseId))
        }
        try? imageData.write(to: url, options: .atomic)
    }
    
    func load(exerciseId: String, gifUrl: String?) {
        if let cachedImage = ExerciseImageLoader.cachedImage(for: exerciseId) {
            self.image = cachedImage
            self.isLoading = false
            return
        }
        
        isLoading = true
        
        let urlString = "https://exercisedb.p.rapidapi.com/image?exerciseId=\(exerciseId)&resolution=360"
        print("🔗 Loading image from RapidAPI: \(urlString)")
        
        guard let url = URL(string: urlString) else {
            print("❌ Invalid URL: \(urlString)")
            isLoading = false
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 15
        request.setValue(apiKey, forHTTPHeaderField: "X-RapidAPI-Key")
        request.setValue("exercisedb.p.rapidapi.com", forHTTPHeaderField: "X-RapidAPI-Host")
        print("🔑 Added RapidAPI headers for image request")
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            if let error = error {
                print("❌ Error loading image for exercise \(exerciseId): \(error)")
                self?.loadFromFallbackIfNeeded(exerciseId: exerciseId, gifUrl: gifUrl)
                return
            }
            
            if let httpResponse = response as? HTTPURLResponse {
                print("📥 Image response status: \(httpResponse.statusCode) for exercise \(exerciseId)")
                if httpResponse.statusCode != 200 {
                    print("⚠️ Non-200 status for URL: \(urlString)")
                    self?.loadFromFallbackIfNeeded(exerciseId: exerciseId, gifUrl: gifUrl)
                    return
                }
            }
            
            guard let data = data, let uiImage = UIImage(data: data) else {
                print("⚠️ Could not convert data to image for exercise \(exerciseId)")
                self?.loadFromFallbackIfNeeded(exerciseId: exerciseId, gifUrl: gifUrl)
                return
            }
            
            ExerciseImageLoader.storeImage(data, for: exerciseId)
            DispatchQueue.main.async {
                self?.image = uiImage
                self?.isLoading = false
                print("✅ Successfully loaded image for exercise \(exerciseId)")
            }
        }.resume()
    }
    
    private func loadFromFallbackIfNeeded(exerciseId: String, gifUrl: String?) {
        guard let gifUrl, let url = URL(string: gifUrl) else {
            DispatchQueue.main.async { [weak self] in
                self?.isLoading = false
            }
            return
        }
        
        URLSession.shared.dataTask(with: url) { data, _, _ in
            defer {
                DispatchQueue.main.async { [weak self] in
                    self?.isLoading = false
                }
            }
            guard let data = data, let image = UIImage(data: data) else { return }
            ExerciseImageLoader.storeImage(data, for: exerciseId)
            DispatchQueue.main.async { [weak self] in
                self?.image = image
            }
        }.resume()
    }
}

struct ExerciseGIFView: View {
    let exerciseId: String
    let gifUrl: String?
    var width: CGFloat? = 60
    var height: CGFloat? = 60
    @StateObject private var loader = ExerciseImageLoader()
    
    var body: some View {
        Group {
            if loader.isLoading {
                ProgressView()
                    .frame(width: width, height: height)
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else if let image = loader.image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: width, height: height)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                Image(systemName: "figure.strengthtraining.traditional")
                    .font(.system(size: (width ?? 60) * 0.4))
                    .foregroundColor(.gray)
                    .frame(width: width, height: height)
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .onAppear {
            loader.load(exerciseId: exerciseId, gifUrl: gifUrl)
        }
    }
}

