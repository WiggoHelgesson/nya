import Foundation
import StoreKit

class ReviewManager {
    static let shared = ReviewManager()
    
    // MARK: - UserDefaults Keys
    private let workoutCountKey = "reviewManager_workoutCount"
    private let firstUseDateKey = "reviewManager_firstUseDate"
    private let lastReviewRequestDateKey = "reviewManager_lastReviewRequestDate"
    
    // MARK: - Thresholds
    private let minimumWorkouts = 5
    private let minimumDaysSinceFirstUse = 7
    private let monthsBetweenRequests = 4
    
    private init() {
        // Sätt första användningsdatum om det inte finns
        if firstUseDate == nil {
            firstUseDate = Date()
        }
    }
    
    // MARK: - Tracked Properties
    
    /// Antal avslutade träningspass
    var workoutCount: Int {
        get { UserDefaults.standard.integer(forKey: workoutCountKey) }
        set { UserDefaults.standard.set(newValue, forKey: workoutCountKey) }
    }
    
    /// Datum för första appanvändning
    var firstUseDate: Date? {
        get { UserDefaults.standard.object(forKey: firstUseDateKey) as? Date }
        set { UserDefaults.standard.set(newValue, forKey: firstUseDateKey) }
    }
    
    /// Senaste gången review-popup visades
    var lastReviewRequestDate: Date? {
        get { UserDefaults.standard.object(forKey: lastReviewRequestDateKey) as? Date }
        set { UserDefaults.standard.set(newValue, forKey: lastReviewRequestDateKey) }
    }
    
    // MARK: - Public Methods
    
    /// Anropas när ett träningspass avslutas
    func recordWorkoutCompleted() {
        workoutCount += 1
        print("📊 ReviewManager: Workout count = \(workoutCount)")
    }
    
    /// Visar native iOS review popup
    func requestReview() {
        if #available(iOS 14.0, *) {
            if let scene = UIApplication.shared.connectedScenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene {
                SKStoreReviewController.requestReview(in: scene)
            }
        } else {
            SKStoreReviewController.requestReview()
        }
    }
    
    /// Kontrollerar om alla villkor är uppfyllda för att visa review-popup efter ett träningspass
    func requestReviewAfterWorkoutIfEligible() {
        guard shouldShowReview() else {
            print("📊 ReviewManager: Villkor ej uppfyllda för review")
            return
        }
        
        print("⭐ ReviewManager: Visar review-popup!")
        
        // Visa med kort fördröjning så användaren hinner se sitt resultat först
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            self.requestReview()
            self.lastReviewRequestDate = Date()
        }
    }
    
    // MARK: - Private Methods
    
    private func shouldShowReview() -> Bool {
        // Villkor 1: Minst X träningspass
        guard workoutCount >= minimumWorkouts else {
            print("📊 ReviewManager: För få träningspass (\(workoutCount)/\(minimumWorkouts))")
            return false
        }
        
        // Villkor 2: Minst X dagar sedan första användning
        if let firstUse = firstUseDate {
            let daysSinceFirstUse = Calendar.current.dateComponents([.day], from: firstUse, to: Date()).day ?? 0
            guard daysSinceFirstUse >= minimumDaysSinceFirstUse else {
                print("📊 ReviewManager: För kort tid sedan första användning (\(daysSinceFirstUse)/\(minimumDaysSinceFirstUse) dagar)")
                return false
            }
        }
        
        // Villkor 3: Minst X månader sedan senaste review-förfrågan
        if let lastRequest = lastReviewRequestDate {
            let monthsSinceLastRequest = Calendar.current.dateComponents([.month], from: lastRequest, to: Date()).month ?? 0
            guard monthsSinceLastRequest >= monthsBetweenRequests else {
                print("📊 ReviewManager: För kort tid sedan senaste förfrågan (\(monthsSinceLastRequest)/\(monthsBetweenRequests) månader)")
                return false
            }
        }
        
        return true
    }
    
    // MARK: - Legacy (för bakåtkompatibilitet)
    
    /// Visar review popup med fördröjning
    func requestReviewWithDelay() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.requestReview()
        }
    }
    
    /// Legacy: Kontrollerar om review redan har visats (behålls för bakåtkompatibilitet)
    var hasRequestedReview: Bool {
        get { UserDefaults.standard.bool(forKey: "hasRequestedReview") }
        set { UserDefaults.standard.set(newValue, forKey: "hasRequestedReview") }
    }
    
    /// Legacy: Visar review popup endast om aldrig visats förut
    func requestReviewIfNeeded() {
        guard !hasRequestedReview else { return }
        requestReviewWithDelay()
        hasRequestedReview = true
    }
}
