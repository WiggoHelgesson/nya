import Foundation
import UIKit
import SwiftUI
import Combine

/// Caps simultaneous network requests for exercise GIFs. Supabase Storage tolerates
/// high concurrency, but the throttling smooths bursts when the `ensure-exercise-gif`
/// Edge Function is hit for many ids at once on first run.
private actor ExerciseImageGate {
    static let shared = ExerciseImageGate()
    private var inFlight = 0
    private let maxConcurrent = 8
    private var waiters: [CheckedContinuation<Void, Never>] = []

    func acquire() async {
        while inFlight >= maxConcurrent {
            await withCheckedContinuation { waiters.append($0) }
        }
        inFlight += 1
    }

    func release() {
        inFlight -= 1
        if !waiters.isEmpty {
            let c = waiters.removeFirst()
            c.resume()
        }
    }

    func withSlot<T>(_ work: () async throws -> T) async rethrows -> T {
        await acquire()
        defer { release() }
        return try await work()
    }
}

/// One in-flight network fetch per storage key so duplicate `ExerciseGIFView`s share work.
private actor ExerciseImageFetchCoordinator {
    static let shared = ExerciseImageFetchCoordinator()
    private var tasks: [String: Task<Void, Never>] = [:]

    func runOnce(storageKey: String, operation: @Sendable @escaping () async -> Void) async {
        if let existing = tasks[storageKey] {
            await existing.value
            return
        }
        let task = Task {
            await operation()
        }
        tasks[storageKey] = task
        await task.value
        tasks[storageKey] = nil
    }
}

class ExerciseImageLoader: ObservableObject {
    @Published var image: UIImage?
    @Published var isLoading = false

    private static let memoryCache = NSCache<NSString, UIImage>()
    private static let legacyCacheMigrationDefaultsKey = "ExerciseImageCacheMigratedExerciseImagesRapidapi_v1"

    private static let diskDirectory: URL = {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        if !UserDefaults.standard.bool(forKey: legacyCacheMigrationDefaultsKey) {
            let legacy = caches.appendingPathComponent("exercise_images", isDirectory: true)
            if FileManager.default.fileExists(atPath: legacy.path) {
                try? FileManager.default.removeItem(at: legacy)
            }
            UserDefaults.standard.set(true, forKey: legacyCacheMigrationDefaultsKey)
        }
        let url = caches.appendingPathComponent("exercise_images_rapidapi", isDirectory: true)
        if !FileManager.default.fileExists(atPath: url.path) {
            try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        }
        return url
    }()

    private static func storageKey(exerciseId: String) -> String {
        let trimmed = exerciseId.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "_missing_exercise_key" : trimmed
    }

    private static func cacheKey(forStorageKey key: String) -> NSString {
        NSString(string: key)
    }

    private static func diskURL(forStorageKey key: String) -> URL {
        diskDirectory.appendingPathComponent("\(key).img")
    }

    private static func cachedImage(forStorageKey key: String) -> UIImage? {
        if let cached = memoryCache.object(forKey: cacheKey(forStorageKey: key)) {
            return cached
        }
        let url = diskURL(forStorageKey: key)
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        if let data = try? Data(contentsOf: url), let image = UIImage(data: data) {
            memoryCache.setObject(image, forKey: cacheKey(forStorageKey: key))
            return image
        }
        return nil
    }

    private static func storeImage(_ imageData: Data, forStorageKey key: String) {
        let url = diskURL(forStorageKey: key)
        if let image = UIImage(data: imageData) {
            memoryCache.setObject(image, forKey: cacheKey(forStorageKey: key))
        }
        try? imageData.write(to: url, options: .atomic)
    }

    private static func bucketURL(forExerciseId id: String) -> URL? {
        URL(string: "\(SupabaseConfig.storageBaseURL)/exercise-gifs/\(id).gif")
    }

    private static var ensureFunctionURL: URL? {
        URL(string: "\(SupabaseConfig.projectURL.absoluteString)/functions/v1/ensure-exercise-gif")
    }

    /// Loads exercise image from Supabase Storage. If missing, triggers the
    /// `ensure-exercise-gif` Edge Function once and retries the bucket fetch.
    /// The app never talks to RapidAPI directly.
    func load(exerciseId: String) {
        let key = Self.storageKey(exerciseId: exerciseId)

        if let cachedImage = ExerciseImageLoader.cachedImage(forStorageKey: key) {
            self.image = cachedImage
            self.isLoading = false
            return
        }

        isLoading = true

        let trimmedId = exerciseId.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedId.isEmpty {
            isLoading = false
            return
        }

        Task { [weak self] in
            await ExerciseImageFetchCoordinator.shared.runOnce(storageKey: key) {
                await ExerciseImageLoader.fetchAndCache(exerciseId: trimmedId, storageKey: key)
            }
            await MainActor.run { [weak self] in
                guard let self else { return }
                if let img = Self.cachedImage(forStorageKey: key) {
                    self.image = img
                }
                self.isLoading = false
            }
        }
    }

    private static func fetchAndCache(exerciseId: String, storageKey: String) async {
        guard let bucket = bucketURL(forExerciseId: exerciseId) else { return }

        if await fetchAndStoreIfImage(url: bucket, storageKey: storageKey) {
            return
        }

        if await triggerEnsureFunction(exerciseId: exerciseId) {
            _ = await fetchAndStoreIfImage(url: bucket, storageKey: storageKey)
        }
    }

    /// Returns true if a usable image was downloaded and cached.
    private static func fetchAndStoreIfImage(url: URL, storageKey: String) async -> Bool {
        let result: (Data, URLResponse)? = await ExerciseImageGate.shared.withSlot {
            do {
                return try await SupabaseConfig.urlSession.data(from: url)
            } catch {
                print("❌ exercise-gifs GET error for \(storageKey): \(error)")
                return nil
            }
        }
        guard let (data, response) = result else { return false }
        if let http = response as? HTTPURLResponse, http.statusCode != 200 {
            return false
        }
        guard UIImage(data: data) != nil else {
            return false
        }
        storeImage(data, forStorageKey: storageKey)
        return true
    }

    /// Calls `ensure-exercise-gif` so the bucket gets populated. Returns true on success.
    private static func triggerEnsureFunction(exerciseId: String) async -> Bool {
        guard let url = ensureFunctionURL else { return false }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 25
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(SupabaseConfig.anonKey)", forHTTPHeaderField: "Authorization")
        let payload: [String: String] = ["exerciseId": exerciseId]
        request.httpBody = try? JSONSerialization.data(withJSONObject: payload)

        return await ExerciseImageGate.shared.withSlot {
            do {
                let (_, response) = try await SupabaseConfig.urlSession.data(for: request)
                if let http = response as? HTTPURLResponse {
                    if http.statusCode == 200 {
                        return true
                    }
                    print("⚠️ ensure-exercise-gif returned \(http.statusCode) for \(exerciseId)")
                }
                return false
            } catch {
                print("❌ ensure-exercise-gif call failed for \(exerciseId): \(error)")
                return false
            }
        }
    }
}

struct ExerciseGIFView: View {
    let exerciseId: String
    /// Unused: kept for call-site compatibility.
    let gifUrl: String?
    /// Unused: kept for call-site compatibility.
    var exerciseName: String? = nil
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
            loader.load(exerciseId: exerciseId)
        }
    }
}
