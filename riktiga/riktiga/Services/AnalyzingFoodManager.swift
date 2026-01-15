import SwiftUI
import Combine
import Supabase
import UserNotifications

// MARK: - Analyzing Food Manager (Singleton)
class AnalyzingFoodManager: ObservableObject {
    static let shared = AnalyzingFoodManager()
    
    @Published var isAnalyzing = false
    @Published var progress: Double = 0
    @Published var statusText = "Analyserar mat..."
    @Published var capturedImage: UIImage?
    @Published var result: AnalyzedFoodResult?
    @Published var showNotifyBanner = true
    @Published var noFoodDetected = false
    @Published var errorMessage: String?
    @Published var notificationsEnabled = false
    
    private var progressTimer: Timer?
    
    private init() {
        checkNotificationPermission()
    }
    
    // MARK: - Notification Handling
    private func checkNotificationPermission() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                self.notificationsEnabled = settings.authorizationStatus == .authorized
            }
        }
    }
    
    func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            DispatchQueue.main.async {
                self.notificationsEnabled = granted
                if granted {
                    print("✅ Notification permission granted")
                } else {
                    print("❌ Notification permission denied: \(error?.localizedDescription ?? "unknown")")
                }
            }
        }
    }
    
    private func sendAnalysisCompleteNotification(foodName: String) {
        // Only send if app is in background
        guard UIApplication.shared.applicationState != .active else {
            print("ℹ️ App is active, skipping notification")
            return
        }
        
        let content = UNMutableNotificationContent()
        content.title = "Din analys är klar"
        content.body = "Din analys är redo att läggas in!"
        content.sound = .default
        
        // Add food name as subtitle if available
        if !foodName.isEmpty {
            content.subtitle = foodName
        }
        
        // Trigger immediately
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.5, repeats: false)
        
        let request = UNNotificationRequest(
            identifier: "food-analysis-complete-\(UUID().uuidString)",
            content: content,
            trigger: trigger
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("❌ Failed to send notification: \(error)")
            } else {
                print("✅ Analysis complete notification sent")
            }
        }
    }
    
    struct AnalyzedFoodResult: Identifiable {
        let id = UUID()
        let foodName: String
        let calories: Int
        let protein: Int
        let carbs: Int
        let fat: Int
        let servingSize: String?
        let image: UIImage?
    }
    
    func startAnalyzing(image: UIImage) {
        DispatchQueue.main.async {
            self.isAnalyzing = true
            self.progress = 0
            self.statusText = "Analyserar mat..."
            self.capturedImage = image
            self.result = nil
            self.noFoodDetected = false
            self.errorMessage = nil
            self.showNotifyBanner = true
        }
        
        // Start fake progress animation
        startProgressAnimation()
        
        // Actually analyze with AI
        analyzeWithAI(image)
    }
    
    private func startProgressAnimation() {
        progressTimer?.invalidate()
        
        // Animate progress from 0 to ~85% over 3 seconds while waiting for API
        var currentProgress: Double = 0
        progressTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] timer in
            guard let self = self, self.isAnalyzing else {
                timer.invalidate()
                return
            }
            
            // Slow down as we approach 85%
            let increment = max(0.5, (85 - currentProgress) * 0.05)
            currentProgress = min(85, currentProgress + increment)
            
            DispatchQueue.main.async {
                self.progress = currentProgress
            }
        }
    }
    
    private func analyzeWithAI(_ image: UIImage) {
        Task {
            do {
                guard let imageData = image.jpegData(compressionQuality: 0.7) else {
                    throw NSError(domain: "ImageError", code: -1)
                }
                
                let base64Image = imageData.base64EncodedString()
                
                await MainActor.run {
                    self.statusText = "AI analyserar..."
                }
                
                let result = try await sendToGPTVision(base64Image: base64Image)
                
                // Complete the progress to 100%
                await MainActor.run {
                    withAnimation(.easeOut(duration: 0.3)) {
                        self.progress = 100
                    }
                }
                
                // Small delay before showing result
                try? await Task.sleep(nanoseconds: 500_000_000)
                
                await MainActor.run {
                    self.progressTimer?.invalidate()
                    
                    // Check if no food was detected
                    if result.noFood {
                        self.noFoodDetected = true
                        self.errorMessage = "Ingen mat hittades"
                        self.isAnalyzing = false
                    } else {
                        self.result = AnalyzedFoodResult(
                            foodName: result.name,
                            calories: result.calories,
                            protein: result.protein,
                            carbs: result.carbs,
                            fat: result.fat,
                            servingSize: result.servingSize,
                            image: image
                        )
                        self.isAnalyzing = false
                        
                        // Send notification that analysis is complete
                        self.sendAnalysisCompleteNotification(foodName: result.name)
                    }
                }
            } catch {
                await MainActor.run {
                    self.progressTimer?.invalidate()
                    self.noFoodDetected = true
                    self.errorMessage = "Kunde inte analysera bilden"
                    self.isAnalyzing = false
                }
                print("❌ AI Analysis error: \(error)")
            }
        }
    }
    
    struct GPTResult {
        let noFood: Bool
        let name: String
        let calories: Int
        let protein: Int
        let carbs: Int
        let fat: Int
        let servingSize: String?
    }
    
    private func sendToGPTVision(base64Image: String) async throws -> GPTResult {
        guard let apiKey = EnvManager.shared.value(for: "OPENAI_API_KEY"), !apiKey.isEmpty else {
            throw NSError(domain: "APIKeyError", code: -1, userInfo: [NSLocalizedDescriptionKey: "OpenAI API key not found"])
        }
        
        guard let url = URL(string: "https://api.openai.com/v1/chat/completions") else {
            throw NSError(domain: "URLError", code: -1)
        }
        
        let prompt = """
        Analysera denna bild. Om du ser mat eller dryck, identifiera vad det är och uppskatta näringsvärden per portion.
        
        Om du INTE kan se någon mat eller dryck i bilden, svara med:
        {
            "no_food": true,
            "name": "",
            "calories": 0,
            "protein": 0,
            "carbs": 0,
            "fat": 0,
            "serving_size": ""
        }
        
        Om du SER mat eller dryck, svara med:
        {
            "no_food": false,
            "name": "Namn på maten/drycken på svenska",
            "calories": 0,
            "protein": 0,
            "carbs": 0,
            "fat": 0,
            "serving_size": "Uppskattad portionsstorlek"
        }
        
        Svara ENDAST med JSON (inga andra tecken).
        - calories, protein, carbs, fat ska vara heltal
        """
        
        let requestBody: [String: Any] = [
            "model": "gpt-4o-mini",
            "messages": [
                [
                    "role": "user",
                    "content": [
                        ["type": "text", "text": prompt],
                        ["type": "image_url", "image_url": ["url": "data:image/jpeg;base64,\(base64Image)"]]
                    ]
                ]
            ],
            "max_tokens": 500
        ]
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        request.timeoutInterval = 60
        
        let (data, _) = try await URLSession.shared.data(for: request)
        
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let firstChoice = choices.first,
              let message = firstChoice["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw NSError(domain: "ParseError", code: -1)
        }
        
        // Extract JSON from response
        let cleanContent = content
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard let resultData = cleanContent.data(using: .utf8),
              let result = try? JSONSerialization.jsonObject(with: resultData) as? [String: Any] else {
            throw NSError(domain: "JSONError", code: -1)
        }
        
        return GPTResult(
            noFood: result["no_food"] as? Bool ?? false,
            name: result["name"] as? String ?? "Okänd mat",
            calories: result["calories"] as? Int ?? 0,
            protein: result["protein"] as? Int ?? 0,
            carbs: result["carbs"] as? Int ?? 0,
            fat: result["fat"] as? Int ?? 0,
            servingSize: result["serving_size"] as? String
        )
    }
    
    func dismissResult() {
        result = nil
        capturedImage = nil
        noFoodDetected = false
        errorMessage = nil
    }
    
    func dismissNoFoodError() {
        noFoodDetected = false
        capturedImage = nil
        errorMessage = nil
    }
    
    func retryAnalysis() {
        guard let image = capturedImage else { return }
        noFoodDetected = false
        errorMessage = nil
        isAnalyzing = true
        progress = 0
        showNotifyBanner = true
        startProgressAnimation()
        analyzeWithAI(image)
    }
    
    func dismissNotifyBanner() {
        showNotifyBanner = false
    }
    
    func addResultToLog() {
        guard let result = result else { return }
        
        Task {
            do {
                guard let userId = try? await SupabaseConfig.supabase.auth.session.user.id.uuidString else {
                    print("❌ No user logged in")
                    return
                }
                
                // Upload image if available
                var imageUrl: String? = nil
                if let image = result.image,
                   let imageData = image.jpegData(compressionQuality: 0.7) {
                    imageUrl = try await uploadFoodImage(data: imageData, userId: userId)
                }
                
                let entry = FoodLogInsertForAnalysis(
                    id: UUID().uuidString,
                    userId: userId,
                    name: result.foodName,
                    calories: result.calories,
                    protein: result.protein,
                    carbs: result.carbs,
                    fat: result.fat,
                    mealType: "snack",
                    loggedAt: ISO8601DateFormatter().string(from: Date()),
                    imageUrl: imageUrl
                )
                
                try await SupabaseConfig.supabase
                    .from("food_logs")
                    .insert(entry)
                    .execute()
                
                print("✅ Added analyzed food: \(result.foodName) with image: \(imageUrl ?? "none")")
                
                await MainActor.run {
                    NotificationCenter.default.post(name: NSNotification.Name("RefreshFoodLogs"), object: nil)
                    self.dismissResult()
                }
            } catch {
                print("❌ Error saving: \(error)")
            }
        }
    }
    
    private func uploadFoodImage(data: Data, userId: String) async throws -> String {
        let fileName = "\(userId)/food_\(UUID().uuidString).jpg"
        
        try await SupabaseConfig.supabase.storage
            .from("food-images")
            .upload(
                path: fileName,
                file: data,
                options: FileOptions(contentType: "image/jpeg")
            )
        
        // Get public URL
        let publicURL = try SupabaseConfig.supabase.storage
            .from("food-images")
            .getPublicURL(path: fileName)
        
        return publicURL.absoluteString
    }
}

struct FoodLogInsertForAnalysis: Codable {
    let id: String
    let userId: String
    let name: String
    let calories: Int
    let protein: Int
    let carbs: Int
    let fat: Int
    let mealType: String
    let loggedAt: String
    let imageUrl: String?
    
    enum CodingKeys: String, CodingKey {
        case id, name, calories, protein, carbs, fat
        case userId = "user_id"
        case mealType = "meal_type"
        case loggedAt = "logged_at"
        case imageUrl = "image_url"
    }
}

