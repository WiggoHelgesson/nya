import Foundation
import Supabase
import StripePaymentSheet
import Combine

// MARK: - Stripe Configuration

enum StripeConfig {
    // Publishable key (safe to include in app) - LIVE MODE
    static let publishableKey = "pk_live_51SZ8AiDGa589KjR0jMkTAI5BfGNf65qPzajTPVHNVYWsdhmgCPNgFoT13BlQkuMOPfBwBYodLhv3wUPSWpfx0Q2x00WI8tmMXu"
    
    // Apple Pay merchant ID (configure in Apple Developer Portal)
    static let appleMerchantId = "merchant.com.upanddown.golf"
    
    static func configure() {
        STPAPIClient.shared.publishableKey = publishableKey
    }
}

// MARK: - Stripe Models

struct PaymentSheetParams: Codable {
    let paymentIntent: String
    let ephemeralKey: String
    let customer: String
    let publishableKey: String
}

struct PaymentResult {
    let success: Bool
    let paymentIntentId: String?
    let error: Error?
}

// MARK: - Stripe Service

@MainActor
class StripeService: ObservableObject {
    static let shared = StripeService()
    
    @Published var isProcessing = false
    @Published var hasPaidForTrainer: [UUID: Bool] = [:]
    
    private let supabase = SupabaseConfig.supabase
    
    private init() {}
    
    // MARK: - Check Payment Status
    
    func checkPaymentStatus(trainerId: UUID) async -> Bool {
        if let cached = hasPaidForTrainer[trainerId] {
            return cached
        }
        
        do {
            let result: Bool = try await supabase.database
                .rpc("has_paid_for_trainer", params: ["p_trainer_id": trainerId.uuidString])
                .execute()
                .value
            
            hasPaidForTrainer[trainerId] = result
            return result
        } catch {
            print("Error checking payment status: \(error)")
            return false
        }
    }
    
    // MARK: - Create Payment Intent
    
    func createPaymentIntent(trainerId: UUID, amount: Int? = nil) async throws -> PaymentSheetParams {
        print("💳 Creating payment intent for trainer: \(trainerId)")
        
        isProcessing = true
        defer { isProcessing = false }
        
        var body: [String: String] = ["trainer_id": trainerId.uuidString]
        if let amount = amount {
            body["amount"] = String(amount)
        }
        
        print("💳 Request body: \(body)")
        
        do {
            // Get raw response as [String: Any]
            let response: [String: String] = try await supabase.functions.invoke(
                "create-payment-intent",
                options: FunctionInvokeOptions(body: body)
            )
            
            print("💳 Response: \(response)")
            
            // Check for error
            if let errorMessage = response["error"] {
                throw StripeError.paymentFailed(errorMessage)
            }
            
            // Extract required fields
            guard let paymentIntent = response["paymentIntent"],
                  let ephemeralKey = response["ephemeralKey"],
                  let customer = response["customer"],
                  let publishableKey = response["publishableKey"] else {
                print("❌ Missing fields in response: \(response)")
                throw StripeError.paymentFailed("Ofullständigt svar från servern")
            }
            
            let params = PaymentSheetParams(
                paymentIntent: paymentIntent,
                ephemeralKey: ephemeralKey,
                customer: customer,
                publishableKey: publishableKey
            )
            
            print("✅ Payment intent created successfully")
            return params
            
        } catch let error as StripeError {
            throw error
        } catch {
            print("❌ Failed: \(error)")
            throw StripeError.paymentFailed(error.localizedDescription)
        }
    }
    
    func confirmPaymentSuccess(trainerId: UUID) {
        hasPaidForTrainer[trainerId] = true
    }
    
    func getPaymentHistory() async throws -> [LessonPayment] {
        let payments: [LessonPayment] = try await supabase.database
            .from("lesson_payments_with_users")
            .select()
            .order("created_at", ascending: false)
            .execute()
            .value
        
        return payments
    }
}

// MARK: - Models

struct LessonPayment: Codable, Identifiable {
    let id: UUID
    let studentId: UUID
    let trainerId: UUID
    let bookingId: UUID?
    let amount: Int
    let currency: String
    let stripePaymentIntentId: String?
    let status: String
    let createdAt: Date?
    let trainerName: String?
    let trainerAvatarUrl: String?
    let studentUsername: String?
    let studentAvatarUrl: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case studentId = "student_id"
        case trainerId = "trainer_id"
        case bookingId = "booking_id"
        case amount
        case currency
        case stripePaymentIntentId = "stripe_payment_intent_id"
        case status
        case createdAt = "created_at"
        case trainerName = "trainer_name"
        case trainerAvatarUrl = "trainer_avatar_url"
        case studentUsername = "student_username"
        case studentAvatarUrl = "student_avatar_url"
    }
    
    var formattedAmount: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency.uppercased()
        formatter.locale = Locale(identifier: "sv_SE")
        return formatter.string(from: NSNumber(value: Double(amount) / 100)) ?? "\(amount / 100) kr"
    }
}

enum StripeError: LocalizedError {
    case noResponse
    case paymentFailed(String)
    case notAuthenticated
    
    var errorDescription: String? {
        switch self {
        case .noResponse:
            return "Fick inget svar fran betalningsservern"
        case .paymentFailed(let message):
            return "Betalningen misslyckades: \(message)"
        case .notAuthenticated:
            return "Du maste vara inloggad for att betala"
        }
    }
}

// For decoding edge function errors
struct EdgeFunctionError: Codable {
    let error: String?
}

