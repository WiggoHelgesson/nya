import Foundation
import StoreKit

class ReviewManager {
    static let shared = ReviewManager()
    
    private init() {}
    
    /// Visar native iOS review popup
    func requestReview() {
        // Använd SKStoreReviewController som fungerar på alla iOS-versioner
        if #available(iOS 10.3, *) {
            SKStoreReviewController.requestReview()
        }
    }
    
    /// Visar review popup med fördröjning (för att undvika att visa direkt vid app-start)
    func requestReviewWithDelay() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.requestReview()
        }
    }
    
    /// Kontrollerar om användaren redan har lämnat ett omdöme
    /// (Detta är en approximation eftersom Apple inte tillhandahåller en direkt metod)
    var hasRequestedReview: Bool {
        get {
            UserDefaults.standard.bool(forKey: "hasRequestedReview")
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "hasRequestedReview")
        }
    }
    
    /// Visar review popup endast om användaren inte redan har lämnat ett omdöme
    func requestReviewIfNeeded() {
        guard !hasRequestedReview else { return }
        
        requestReviewWithDelay()
        hasRequestedReview = true
    }
}
