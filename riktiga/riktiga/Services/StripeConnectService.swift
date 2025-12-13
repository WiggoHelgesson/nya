import Foundation

/// Service for handling Stripe Connect operations for trainers
/// Manages account creation, onboarding, and payment processing
final class StripeConnectService {
    
    static let shared = StripeConnectService()
    
    private init() {}
    
    // MARK: - Supabase Edge Function URLs
    
    private var baseURL: String {
        // Use the Supabase project URL for edge functions
        return SupabaseConfig.projectURL.absoluteString + "/functions/v1"
    }
    
    // MARK: - Response Models
    
    struct CreateAccountResponse: Codable {
        let success: Bool
        let accountId: String?
        let alreadyExists: Bool?
        let chargesEnabled: Bool?
        let payoutsEnabled: Bool?
        let detailsSubmitted: Bool?
        let error: String?
    }
    
    struct OnboardingLinkResponse: Codable {
        let success: Bool
        let url: String?
        let expiresAt: Int?
        let alreadyComplete: Bool?
        let message: String?
        let error: String?
    }
    
    struct AccountStatusResponse: Codable {
        let success: Bool
        let accountId: String?
        let detailsSubmitted: Bool?
        let chargesEnabled: Bool?
        let payoutsEnabled: Bool?
        let isFullyOnboarded: Bool?
        let statusMessage: String?
        let statusType: String?
        let balance: BalanceInfo?
        let error: String?
        
        struct BalanceInfo: Codable {
            let available: [BalanceAmount]?
            let pending: [BalanceAmount]?
        }
        
        struct BalanceAmount: Codable {
            let amount: Int
            let currency: String
        }
    }
    
    struct CheckoutResponse: Codable {
        let success: Bool
        let checkoutUrl: String?
        let sessionId: String?
        let breakdown: PaymentBreakdown?
        let error: String?
        
        struct PaymentBreakdown: Codable {
            let totalAmount: Double
            let platformFee: Double
            let platformFeePercent: Int
            let trainerAmount: Double
            let currency: String
        }
    }
    
    // MARK: - Create Connect Account
    
    /// Creates a new Stripe Connect account for a trainer
    /// - Parameters:
    ///   - trainerId: The trainer's ID in the database
    ///   - email: The trainer's email address
    /// - Returns: The Stripe account ID and status
    func createConnectAccount(trainerId: String, email: String) async throws -> CreateAccountResponse {
        let url = URL(string: "\(baseURL)/create-connect-account")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(SupabaseConfig.anonKey)", forHTTPHeaderField: "Authorization")
        
        let body: [String: Any] = [
            "trainerId": trainerId,
            "email": email,
            "country": "SE"
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw StripeConnectError.invalidResponse
        }
        
        let decoded = try JSONDecoder().decode(CreateAccountResponse.self, from: data)
        
        if !decoded.success {
            throw StripeConnectError.apiError(decoded.error ?? "Unknown error")
        }
        
        return decoded
    }
    
    // MARK: - Get Onboarding Link
    
    /// Gets a URL for the trainer to complete Stripe onboarding
    /// - Parameter stripeAccountId: The Stripe account ID
    /// - Returns: The onboarding URL
    func getOnboardingLink(stripeAccountId: String) async throws -> OnboardingLinkResponse {
        let url = URL(string: "\(baseURL)/create-onboarding-link")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(SupabaseConfig.anonKey)", forHTTPHeaderField: "Authorization")
        
        // Don't send URLs - let the server use its HTTPS defaults
        // Stripe requires HTTPS URLs for account links
        let body: [String: Any] = [
            "stripeAccountId": stripeAccountId
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, _) = try await URLSession.shared.data(for: request)
        let decoded = try JSONDecoder().decode(OnboardingLinkResponse.self, from: data)
        
        if !decoded.success && decoded.alreadyComplete != true {
            throw StripeConnectError.apiError(decoded.error ?? "Unknown error")
        }
        
        return decoded
    }
    
    // MARK: - Get Account Status
    
    /// Gets the current status of a Stripe Connect account
    /// - Parameters:
    ///   - stripeAccountId: The Stripe account ID
    ///   - trainerId: Optional trainer ID to update database
    /// - Returns: Account status information
    func getAccountStatus(stripeAccountId: String, trainerId: String? = nil) async throws -> AccountStatusResponse {
        let url = URL(string: "\(baseURL)/get-account-status")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(SupabaseConfig.anonKey)", forHTTPHeaderField: "Authorization")
        
        var body: [String: Any] = [
            "stripeAccountId": stripeAccountId
        ]
        if let trainerId = trainerId {
            body["trainerId"] = trainerId
        }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, _) = try await URLSession.shared.data(for: request)
        let decoded = try JSONDecoder().decode(AccountStatusResponse.self, from: data)
        
        if !decoded.success {
            throw StripeConnectError.apiError(decoded.error ?? "Unknown error")
        }
        
        return decoded
    }
    
    // MARK: - Create Lesson Checkout
    
    /// Creates a checkout session for a lesson booking
    /// - Parameters:
    ///   - bookingId: The booking ID
    ///   - trainerId: The trainer's profile ID
    ///   - studentId: The student's user ID
    ///   - amount: Amount in SEK (e.g., 500 for 500 kr)
    ///   - trainerName: Trainer's display name
    ///   - lessonDescription: Description of the lesson
    ///   - studentEmail: Student's email for receipt
    /// - Returns: Checkout URL and payment breakdown
    func createLessonCheckout(
        bookingId: String,
        trainerId: String,
        studentId: String,
        amount: Double,
        trainerName: String,
        lessonDescription: String,
        studentEmail: String
    ) async throws -> CheckoutResponse {
        let url = URL(string: "\(baseURL)/create-lesson-checkout")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(SupabaseConfig.anonKey)", forHTTPHeaderField: "Authorization")
        
        let body: [String: Any] = [
            "bookingId": bookingId,
            "trainerId": trainerId,
            "studentId": studentId,
            "amount": amount,
            "trainerName": trainerName,
            "lessonDescription": lessonDescription,
            "studentEmail": studentEmail
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, _) = try await URLSession.shared.data(for: request)
        let decoded = try JSONDecoder().decode(CheckoutResponse.self, from: data)
        
        if !decoded.success {
            throw StripeConnectError.apiError(decoded.error ?? "Unknown error")
        }
        
        return decoded
    }
    
    // MARK: - Helper: Format Balance
    
    /// Formats a balance amount in öre to a readable string
    static func formatBalance(_ amountInOre: Int, currency: String = "SEK") -> String {
        let amountInKr = Double(amountInOre) / 100.0
        return String(format: "%.2f %@", amountInKr, currency.uppercased())
    }
}

// MARK: - Errors

enum StripeConnectError: LocalizedError {
    case invalidResponse
    case apiError(String)
    case noAccountId
    case onboardingRequired
    
    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Ogiltigt svar från servern"
        case .apiError(let message):
            return message
        case .noAccountId:
            return "Inget Stripe-konto kopplat"
        case .onboardingRequired:
            return "Du måste slutföra Stripe-registreringen först"
        }
    }
}

