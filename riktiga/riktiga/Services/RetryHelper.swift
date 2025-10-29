import Foundation

struct RetryHelper {
    static let shared = RetryHelper()
    
    /// Retry a function with exponential backoff
    /// - Parameters:
    ///   - maxRetries: Maximum number of attempts (default: 3)
    ///   - delay: Initial delay in seconds (default: 0.5)
    ///   - operation: The async operation to retry
    /// - Returns: The result of the operation
    func retry<T>(
        maxRetries: Int = 3,
        delay: TimeInterval = 0.5,
        operation: @escaping () async throws -> T
    ) async throws -> T {
        var lastError: Error?
        var currentDelay = delay
        
        for attempt in 1...maxRetries {
            do {
                print("📡 Attempt \(attempt)/\(maxRetries)...")
                return try await operation()
            } catch {
                lastError = error
                print("⚠️ Attempt \(attempt) failed: \(error)")
                
                if attempt < maxRetries {
                    print("⏳ Waiting \(currentDelay)s before retry...")
                    try await Task.sleep(nanoseconds: UInt64(currentDelay * 1_000_000_000))
                    currentDelay *= 1.5 // Exponential backoff
                }
            }
        }
        
        if let error = lastError {
            print("❌ All retries failed: \(error)")
            throw error
        }
        
        throw NSError(domain: "RetryHelper", code: -1, userInfo: [NSLocalizedDescriptionKey: "Unknown error"])
    }
}
