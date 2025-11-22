import Foundation

/// Lightweight helper that reads configuration values from environment variables
/// and optional `.env` resources bundled with the app.
final class EnvManager {
    static let shared = EnvManager()
    
    private var cachedValues: [String: String]
    
    private init() {
        self.cachedValues = Self.loadDotEnvFiles()
    }
    
    /// Returns a configuration value for the given key.
    /// Priority: Process environment > cached `.env` values.
    func value(for key: String) -> String? {
        if let processValue = ProcessInfo.processInfo.environment[key], !processValue.isEmpty {
            return processValue
        }
        return cachedValues[key]
    }
    
    private static func loadDotEnvFiles() -> [String: String] {
        var aggregated: [String: String] = [:]
        let fileManager = FileManager.default
        
        if let envURLs = Bundle.main.urls(forResourcesWithExtension: "env", subdirectory: nil) {
            for url in envURLs {
                do {
                    let contents = try String(contentsOf: url, encoding: .utf8)
                    let pairs = Self.parseDotEnv(contents: contents)
                    aggregated.merge(pairs) { current, _ in current }
                    print("✅ Loaded env file: \(url.lastPathComponent)")
                } catch {
                    print("⚠️ Failed to load \(url.lastPathComponent): \(error)")
                }
            }
        }
        
        if let dotEnvURL = Bundle.main.url(forResource: ".env", withExtension: nil) {
            do {
                let contents = try String(contentsOf: dotEnvURL, encoding: .utf8)
                let pairs = Self.parseDotEnv(contents: contents)
                aggregated.merge(pairs) { current, _ in current }
                print("✅ Loaded env file: .env")
            } catch {
                print("⚠️ Failed to load .env: \(error)")
            }
        }
        
        if aggregated.isEmpty {
            // Log available bundle resources for easier debugging on device builds
            if let resourcePath = Bundle.main.resourcePath,
               let items = try? fileManager.contentsOfDirectory(atPath: resourcePath) {
                let envCandidates = items.filter { $0.lowercased().hasSuffix(".env") || $0 == ".env" }
                print("ℹ️ EnvManager did not load any .env files. Bundle contains: \(envCandidates)")
            }
        }
        
        return aggregated
    }
    
    private static func parseDotEnv(contents: String) -> [String: String] {
        var values: [String: String] = [:]
        
        contents
            .components(separatedBy: .newlines)
            .forEach { rawLine in
                let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !line.isEmpty, !line.hasPrefix("#") else { return }
                
                let parts = line.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
                guard parts.count == 2 else { return }
                
                let key = parts[0].trimmingCharacters(in: .whitespacesAndNewlines)
                var value = parts[1].trimmingCharacters(in: .whitespacesAndNewlines)
                
                if value.hasPrefix("\"") && value.hasSuffix("\"") && value.count >= 2 {
                    value.removeFirst()
                    value.removeLast()
                }
                
                if !key.isEmpty, !value.isEmpty {
                    values[key] = value
                }
            }
        
        return values
    }
}

