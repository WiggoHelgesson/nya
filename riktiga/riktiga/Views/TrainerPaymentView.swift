import SwiftUI
import StripePaymentSheet

struct TrainerPaymentView: View {
    let trainer: GolfTrainer
    let amount: Int
    let lessonType: TrainerLessonType?
    let onPaymentSuccess: (String?) -> Void // Returns payment ID
    
    @Environment(\.dismiss) private var dismiss
    @StateObject private var stripeService = StripeService.shared
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showError = false
    @State private var paymentSheet: PaymentSheet?
    @State private var paymentIntentId: String?
    
    // Convenience init for simple payments (backwards compatible)
    init(trainer: GolfTrainer, onPaymentSuccess: @escaping () -> Void) {
        self.trainer = trainer
        self.amount = trainer.hourlyRate
        self.lessonType = nil
        self.onPaymentSuccess = { _ in onPaymentSuccess() }
    }
    
    // Full init for booking flow
    init(trainer: GolfTrainer, amount: Int, lessonType: TrainerLessonType?, onPaymentSuccess: @escaping (String?) -> Void) {
        self.trainer = trainer
        self.amount = amount
        self.lessonType = lessonType
        self.onPaymentSuccess = onPaymentSuccess
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Trainer Info
                VStack(spacing: 16) {
                    ProfileImage(url: trainer.avatarUrl, size: 100)
                    
                    Text(trainer.name)
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    HStack(spacing: 20) {
                        StatBadge(icon: "figure.golf", value: "HCP \(trainer.handicap)")
                        if let lessonType = lessonType {
                            StatBadge(icon: "clock", value: "\(lessonType.durationMinutes) min")
                        } else {
                            StatBadge(icon: "clock", value: "\(trainer.hourlyRate) kr/h")
                        }
                    }
                }
                .padding(.top, 20)
                
                Divider()
                    .padding(.horizontal)
                
                // Payment Info
                VStack(alignment: .leading, spacing: 16) {
                    Text("Boka lektion")
                        .font(.headline)
                    
                    Text("För att boka en lektion med \(trainer.name) behöver du betala bokningsavgiften.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    // Price breakdown
                    VStack(spacing: 12) {
                        HStack {
                            Text(lessonType?.name ?? "Lektionsavgift")
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("\(amount) kr")
                                .fontWeight(.medium)
                        }
                        
                        Divider()
                        
                        HStack {
                            Text("Totalt")
                                .font(.headline)
                            Spacer()
                            Text("\(amount) kr")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.primary)
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                }
                .padding(.horizontal)
                
                Spacer()
                
                // Payment Button
                if let paymentSheet = paymentSheet {
                    PaymentSheet.PaymentButton(
                        paymentSheet: paymentSheet,
                        onCompletion: handlePaymentCompletion
                    ) {
                        HStack {
                            Image(systemName: "creditcard.fill")
                            Text("Betala \(amount) kr")
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.black)
                        .cornerRadius(14)
                    }
                    .padding(.horizontal)
                } else {
                    Button {
                        preparePaymentSheet()
                    } label: {
                        HStack {
                            if isLoading {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Image(systemName: "creditcard.fill")
                                Text("Betala \(amount) kr")
                            }
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(isLoading ? Color.gray : Color.black)
                        .cornerRadius(14)
                    }
                    .disabled(isLoading)
                    .padding(.horizontal)
                }
                
                // Secure payment note
                HStack(spacing: 6) {
                    Image(systemName: "lock.fill")
                        .font(.caption)
                    Text("Säker betalning via Stripe")
                        .font(.caption)
                }
                .foregroundColor(.secondary)
                .padding(.bottom, 20)
            }
            .navigationTitle("Betala")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Avbryt") {
                        dismiss()
                    }
                }
            }
            .alert("Fel", isPresented: $showError) {
                Button("OK") { }
            } message: {
                Text(errorMessage ?? "Ett fel uppstod")
            }
            .task {
                await preparePaymentSheetAsync()
            }
        }
    }
    
    private func preparePaymentSheet() {
        isLoading = true
        
        Task {
            await preparePaymentSheetAsync()
        }
    }
    
    private func preparePaymentSheetAsync() async {
        isLoading = true
        
        do {
            let params = try await stripeService.createPaymentIntent(
                trainerId: trainer.id,
                amount: amount * 100 // Convert to öre
            )
            
            // Store payment intent ID
            paymentIntentId = params.paymentIntent.components(separatedBy: "_secret_").first
            
            // Configure Stripe
            STPAPIClient.shared.publishableKey = params.publishableKey
            
            // Create PaymentSheet configuration
            var configuration = PaymentSheet.Configuration()
            configuration.merchantDisplayName = "Up&Down Golf"
            configuration.customer = .init(
                id: params.customer,
                ephemeralKeySecret: params.ephemeralKey
            )
            configuration.allowsDelayedPaymentMethods = false
            configuration.applePay = .init(
                merchantId: "merchant.com.upanddown.golf",
                merchantCountryCode: "SE"
            )
            
            // Style
            configuration.appearance.colors.primary = UIColor.systemGreen
            configuration.appearance.cornerRadius = 12
            
            await MainActor.run {
                self.paymentSheet = PaymentSheet(
                    paymentIntentClientSecret: params.paymentIntent,
                    configuration: configuration
                )
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.showError = true
                self.isLoading = false
            }
        }
    }
    
    private func handlePaymentCompletion(_ result: PaymentSheetResult) {
        switch result {
        case .completed:
            stripeService.confirmPaymentSuccess(trainerId: trainer.id)
            onPaymentSuccess(paymentIntentId)
            dismiss()
            
        case .canceled:
            // User canceled, do nothing
            break
            
        case .failed(let error):
            errorMessage = error.localizedDescription
            showError = true
        }
    }
}

#Preview {
    TrainerPaymentView(
        trainer: GolfTrainer(
            id: UUID(),
            userId: UUID().uuidString,
            name: "Test Tranare",
            description: "En bra tranare",
            hourlyRate: 500,
            handicap: 5,
            latitude: 59.33,
            longitude: 18.06,
            avatarUrl: nil,
            createdAt: nil,
            city: nil,
            bio: nil,
            experienceYears: nil,
            clubAffiliation: nil,
            averageRating: nil,
            totalReviews: nil,
            totalLessons: nil,
            isActive: true,
            serviceRadiusKm: 10.0
        ),
        onPaymentSuccess: { }
    )
}
