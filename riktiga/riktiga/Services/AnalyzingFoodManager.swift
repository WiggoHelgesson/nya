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
    
    // Limit reached state - shows lock icon
    @Published var limitReached = false
    @Published var showPaywallForLimit = false
    
    // Saving state - for "Lägg till" button feedback
    @Published var isSaving = false
    @Published var saveSuccess = false
    
    // Story posting state
    @Published var showStoryPopup = false
    @Published var isPostingStory = false
    @Published var storyPostedSuccess = false
    
    private var progressTimer: Timer?
    private var isPro: Bool = false
    
    private init() {
        checkNotificationPermission()
        // Observe pro status changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(proStatusChanged),
            name: NSNotification.Name("ProStatusChanged"),
            object: nil
        )
    }
    
    @objc private func proStatusChanged() {
        isPro = RevenueCatManager.shared.isProMember
    }
    
    func updateProStatus(_ isPro: Bool) {
        self.isPro = isPro
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
    
    // MARK: - Analyzed Ingredient
    struct AnalyzedIngredient: Identifiable, Codable {
        var id = UUID()
        var name: String
        var calories: Int
        var protein: Int
        var carbs: Int
        var fat: Int
        var amount: String // e.g., "100g", "1 serving", "1/4 medium"
        
        enum CodingKeys: String, CodingKey {
            case name, calories, protein, carbs, fat, amount
        }
        
        init(id: UUID = UUID(), name: String, calories: Int, protein: Int, carbs: Int, fat: Int, amount: String) {
            self.id = id
            self.name = name
            self.calories = calories
            self.protein = protein
            self.carbs = carbs
            self.fat = fat
            self.amount = amount
        }
        
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.id = UUID()
            self.name = try container.decode(String.self, forKey: .name)
            self.calories = try container.decode(Int.self, forKey: .calories)
            self.protein = try container.decode(Int.self, forKey: .protein)
            self.carbs = try container.decode(Int.self, forKey: .carbs)
            self.fat = try container.decode(Int.self, forKey: .fat)
            self.amount = try container.decode(String.self, forKey: .amount)
        }
    }
    
    struct AnalyzedFoodResult: Identifiable {
        let id = UUID()
        var foodName: String
        var calories: Int
        var protein: Int
        var carbs: Int
        var fat: Int
        let servingSize: String?
        let image: UIImage?
        var ingredients: [AnalyzedIngredient]
        
        // Recalculate totals from ingredients
        mutating func recalculateTotals() {
            calories = ingredients.reduce(0) { $0 + $1.calories }
            protein = ingredients.reduce(0) { $0 + $1.protein }
            carbs = ingredients.reduce(0) { $0 + $1.carbs }
            fat = ingredients.reduce(0) { $0 + $1.fat }
        }
    }
    
    // MARK: - Test Helper (for debugging story posting)
    func setTestResult(foodName: String, calories: Int, protein: Int, carbs: Int, fat: Int, image: UIImage?) {
        self.result = AnalyzedFoodResult(
            foodName: foodName,
            calories: calories,
            protein: protein,
            carbs: carbs,
            fat: fat,
            servingSize: nil,
            image: image,
            ingredients: []
        )
        self.capturedImage = image
        print("📷 TEST: Set test result - \(foodName)")
    }
    
    // MARK: - Clear Result (for dismissing scan without saving)
    func clearResult() {
        self.result = nil
        self.capturedImage = nil
        self.noFoodDetected = false
        self.limitReached = false
        self.errorMessage = nil
        self.isSaving = false
        self.saveSuccess = false
        print("🗑️ Cleared analysis result")
    }
    
    func startAnalyzing(image: UIImage) {
        // Check if user is pro or has remaining free scans
        let isProUser = RevenueCatManager.shared.isProMember
        let scanManager = AIScanLimitManager.shared
        
        DispatchQueue.main.async {
            self.isAnalyzing = true
            self.progress = 0
            self.statusText = "Analyserar mat..."
            self.capturedImage = image
            self.result = nil
            self.noFoodDetected = false
            self.errorMessage = nil
            self.showNotifyBanner = true
            self.limitReached = false
        }
        
        // If not pro and at limit, show lock after fake progress
        if !isProUser && scanManager.isAtLimit() {
            showLimitReachedAnimation()
            return
        }
        
        // Start fake progress animation
        startProgressAnimation()
        
        // Actually analyze with AI
        analyzeWithAI(image)
        
        // Count this scan (only for non-pro users)
        if !isProUser {
            scanManager.useScan()
        }
    }
    
    private func showLimitReachedAnimation() {
        // Animate progress up to about 60% then show lock
        var currentProgress: Double = 0
        progressTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] timer in
            guard let self = self else {
                timer.invalidate()
                return
            }
            
            currentProgress += 3
            
            DispatchQueue.main.async {
                self.progress = currentProgress
                
                if currentProgress >= 60 {
                    timer.invalidate()
                    self.progressTimer?.invalidate()
                    
                    // Show limit reached lock
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                        self.limitReached = true
                        self.isAnalyzing = false
                    }
                }
            }
        }
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
                            image: image,
                            ingredients: result.ingredients
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
        let ingredients: [AnalyzedIngredient]
    }
    
    private func sendToGPTVision(base64Image: String) async throws -> GPTResult {
        guard let apiKey = EnvManager.shared.value(for: "OPENAI_API_KEY"), !apiKey.isEmpty else {
            throw NSError(domain: "APIKeyError", code: -1, userInfo: [NSLocalizedDescriptionKey: "OpenAI API key not found"])
        }
        
        guard let url = URL(string: "https://api.openai.com/v1/chat/completions") else {
            throw NSError(domain: "URLError", code: -1)
        }
        
        let prompt = """
        Analysera denna bild. Om du ser mat eller dryck, identifiera vad det är, uppskatta näringsvärden per portion, och lista alla ingredienser med deras individuella näringsvärden.
        
        Om du INTE kan se någon mat eller dryck i bilden, svara med:
        {
            "no_food": true,
            "name": "",
            "calories": 0,
            "protein": 0,
            "carbs": 0,
            "fat": 0,
            "serving_size": "",
            "ingredients": []
        }
        
        Om du SER mat eller dryck, svara med:
        {
            "no_food": false,
            "name": "Namn på maten/drycken på svenska",
            "calories": 0,
            "protein": 0,
            "carbs": 0,
            "fat": 0,
            "serving_size": "Uppskattad portionsstorlek",
            "ingredients": [
                {
                    "name": "Ingrediens 1",
                    "calories": 0,
                    "protein": 0,
                    "carbs": 0,
                    "fat": 0,
                    "amount": "100g"
                },
                {
                    "name": "Ingrediens 2",
                    "calories": 0,
                    "protein": 0,
                    "carbs": 0,
                    "fat": 0,
                    "amount": "1 serving"
                }
            ]
        }
        
        Svara ENDAST med JSON (inga andra tecken).
        - calories, protein, carbs, fat ska vara heltal
        - Inkludera alla uppskattade ingredienser med deras individuella näringsvärden
        - amount ska vara en beskrivande mängd (t.ex. "100g", "1 tablespoon", "1/4 medium", "1 serving")
        - Totalvärdena (calories, protein, carbs, fat) ska vara summan av alla ingredienser
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
        
        // Parse ingredients
        var ingredients: [AnalyzedIngredient] = []
        if let ingredientsArray = result["ingredients"] as? [[String: Any]] {
            for ingredientDict in ingredientsArray {
                let ingredient = AnalyzedIngredient(
                    name: ingredientDict["name"] as? String ?? "Okänd",
                    calories: ingredientDict["calories"] as? Int ?? 0,
                    protein: ingredientDict["protein"] as? Int ?? 0,
                    carbs: ingredientDict["carbs"] as? Int ?? 0,
                    fat: ingredientDict["fat"] as? Int ?? 0,
                    amount: ingredientDict["amount"] as? String ?? "1 portion"
                )
                ingredients.append(ingredient)
            }
        }
        
        return GPTResult(
            noFood: result["no_food"] as? Bool ?? false,
            name: result["name"] as? String ?? "Okänd mat",
            calories: result["calories"] as? Int ?? 0,
            protein: result["protein"] as? Int ?? 0,
            carbs: result["carbs"] as? Int ?? 0,
            fat: result["fat"] as? Int ?? 0,
            servingSize: result["serving_size"] as? String,
            ingredients: ingredients
        )
    }
    
    func dismissResult() {
        result = nil
        capturedImage = nil
        noFoodDetected = false
        errorMessage = nil
        limitReached = false
    }
    
    func dismissNoFoodError() {
        noFoodDetected = false
        capturedImage = nil
        errorMessage = nil
    }
    
    func dismissLimitReached() {
        limitReached = false
        capturedImage = nil
    }
    
    func openPaywallForLimit() {
        showPaywallForLimit = true
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
        print("📝 addResultToLog called")
        
        guard let result = result else {
            print("❌ No result to add")
            return
        }
        
        // IMPORTANT: Also capture the original captured image as backup
        let capturedImageBackup = capturedImage
        
        print("📝 Adding result: \(result.foodName)")
        print("📷 DEBUG: result.image = \(result.image != nil ? "present (\(result.image!.size))" : "NIL")")
        print("📷 DEBUG: capturedImage backup = \(capturedImageBackup != nil ? "present (\(capturedImageBackup!.size))" : "NIL")")
        
        // Show saving state
        let resultToSave = result
        DispatchQueue.main.async {
            self.isSaving = true
        }
        
        Task {
            do {
                guard let userId = try? await SupabaseConfig.supabase.auth.session.user.id.uuidString else {
                    print("❌ No user logged in")
                    await MainActor.run {
                        self.isSaving = false
                    }
                    return
                }
                
                print("📝 User ID: \(userId)")
                
                // Upload image if available - try result.image first, then capturedImage as backup
                var imageUrl: String? = nil
                let imageToUpload = resultToSave.image ?? capturedImageBackup
                
                if let image = imageToUpload,
                   let imageData = image.jpegData(compressionQuality: 0.7) {
                    print("📷 Image found - size: \(image.size), data size: \(imageData.count) bytes")
                    print("📷 Attempting to upload to food-images bucket...")
                    do {
                        imageUrl = try await uploadFoodImage(data: imageData, userId: userId)
                        print("✅ Image uploaded successfully: \(imageUrl ?? "nil")")
                    } catch {
                        print("❌ Image upload FAILED: \(error)")
                        print("❌ Error details: \(error.localizedDescription)")
                    }
                } else {
                    print("⚠️ No image available to upload")
                    print("   - resultToSave.image: \(resultToSave.image != nil)")
                    print("   - capturedImageBackup: \(capturedImageBackup != nil)")
                }
                
                // Convert ingredients to insert format
                let ingredientsToSave: [FoodLogIngredientInsert]? = resultToSave.ingredients.isEmpty ? nil : resultToSave.ingredients.map { ing in
                    FoodLogIngredientInsert(
                        name: ing.name,
                        calories: ing.calories,
                        protein: ing.protein,
                        carbs: ing.carbs,
                        fat: ing.fat,
                        amount: ing.amount
                    )
                }
                
                let entry = FoodLogInsertForAnalysis(
                    id: UUID().uuidString,
                    userId: userId,
                    name: resultToSave.foodName,
                    calories: resultToSave.calories,
                    protein: resultToSave.protein,
                    carbs: resultToSave.carbs,
                    fat: resultToSave.fat,
                    mealType: "snack",
                    loggedAt: ISO8601DateFormatter().string(from: Date()),
                    imageUrl: imageUrl,
                    ingredients: ingredientsToSave
                )
                
                print("📝 Inserting food log...")
                try await SupabaseConfig.supabase
                    .from("food_logs")
                    .insert(entry)
                    .execute()
                
                print("✅ Added analyzed food: \(resultToSave.foodName) with image: \(imageUrl ?? "none")")
                
                // Show success animation, then dismiss
                await MainActor.run {
                    self.isSaving = false
                    self.saveSuccess = true
                    
                    // Haptic feedback for success
                    let haptic = UINotificationFeedbackGenerator()
                    haptic.notificationOccurred(.success)
                }
                
                // Wait a moment to show success, then show story popup
                try? await Task.sleep(nanoseconds: 800_000_000) // 0.8 seconds
                
                // Capture the image BEFORE clearing state
                let imageForStory = self.capturedImage
                
                await MainActor.run {
                    self.saveSuccess = false
                    
                    // Only show story popup if we have a valid image
                    if imageForStory != nil {
                        self.showStoryPopup = true
                    }
                    
                    NotificationCenter.default.post(name: NSNotification.Name("RefreshFoodLogs"), object: nil)
                }
                
                // Register activity for streak
                StreakManager.shared.registerActivityCompletion()
                
                // Check for AI scan achievement AFTER story popup is shown (delayed)
                // This prevents race conditions with multiple fullScreenCovers
                try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds delay
                await MainActor.run {
                    // Only show achievement if story popup is NOT showing
                    if !self.showStoryPopup {
                        AchievementManager.shared.unlock("first_scan")
                    }
                }
            } catch {
                print("❌ Error saving food log: \(error)")
                await MainActor.run {
                    self.isSaving = false
                    self.errorMessage = "Kunde inte spara: \(error.localizedDescription)"
                }
            }
        }
    }
    
    // MARK: - Story Posting
    func postToStory() {
        print("📸 postToStory() called")
        
        // Capture values at the start to prevent race conditions
        guard let image = capturedImage else {
            print("❌ No image to post to story")
            safelyDismissStoryPopup()
            return
        }
        
        guard let foodResult = result else {
            print("❌ No food result to post to story")
            safelyDismissStoryPopup()
            return
        }
        
        // Prevent double-posting
        guard !isPostingStory else {
            print("⚠️ Already posting story, ignoring duplicate call")
            return
        }
        
        print("📸 Starting story post...")
        isPostingStory = true
        
        // Capture ALL values locally to avoid any reference to self during async
        let imageToPost = image
        let foodName = foodResult.foodName
        let calories = foodResult.calories
        let protein = foodResult.protein
        let carbs = foodResult.carbs
        let fat = foodResult.fat
        
        Task { @MainActor in
            do {
                guard let userId = try? await SupabaseConfig.supabase.auth.session.user.id.uuidString else {
                    print("❌ No user logged in")
                    self.isPostingStory = false
                    self.safelyDismissStoryPopup()
                    return
                }
                
                print("📸 Creating composite image...")
                print("📸 Original image size: \(imageToPost.size)")
                
                // Create composite image with error handling
                var compositeImage: UIImage
                do {
                    compositeImage = self.createStoryImageSimple(
                        original: imageToPost,
                        foodName: foodName,
                        calories: calories,
                        protein: protein,
                        carbs: carbs,
                        fat: fat
                    )
                    print("📸 Composite image created successfully: \(compositeImage.size)")
                } catch {
                    print("❌ Failed to create composite image: \(error)")
                    // Fallback: just use the original image
                    compositeImage = imageToPost
                }
                
                print("📸 Posting to StoryService...")
                _ = try await StoryService.shared.postStory(userId: userId, image: compositeImage)
                
                print("✅ Story posted successfully!")
                self.isPostingStory = false
                self.storyPostedSuccess = true
                
                // Haptic feedback
                let haptic = UINotificationFeedbackGenerator()
                haptic.notificationOccurred(.success)
                
                // Notify to refresh stories
                NotificationCenter.default.post(name: NSNotification.Name("RefreshStories"), object: nil)
                
                // Wait a moment then dismiss
                try? await Task.sleep(nanoseconds: 600_000_000) // 0.6 seconds
                
                self.storyPostedSuccess = false
                self.safelyDismissStoryPopup()
                
                // Register activity for streak
                StreakManager.shared.registerActivityCompletion()
                
                // Check achievement after story is posted
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    AchievementManager.shared.unlock("first_scan")
                }
            } catch {
                print("❌ Error posting story: \(error)")
                self.isPostingStory = false
                self.safelyDismissStoryPopup()
            }
        }
    }
    
    /// Simplified story image creation that takes primitive values instead of struct
    private func createStoryImageSimple(original: UIImage, foodName: String, calories: Int, protein: Int, carbs: Int, fat: Int) -> UIImage {
        // Resize image if too large to prevent memory issues
        let maxDimension: CGFloat = 1500
        let resizedImage: UIImage
        if original.size.width > maxDimension || original.size.height > maxDimension {
            let scale = min(maxDimension / original.size.width, maxDimension / original.size.height)
            let newSize = CGSize(width: original.size.width * scale, height: original.size.height * scale)
            UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
            original.draw(in: CGRect(origin: .zero, size: newSize))
            resizedImage = UIGraphicsGetImageFromCurrentImageContext() ?? original
            UIGraphicsEndImageContext()
            print("📸 Resized image from \(original.size) to \(newSize)")
        } else {
            resizedImage = original
        }
        
        let size = resizedImage.size
        // Made card much larger - more than double the previous size
        let cardWidth: CGFloat = min(size.width * 0.92, 1200)
        let cardHeight: CGFloat = cardWidth * 0.55 // Taller card
        let cardX: CGFloat = (size.width - cardWidth) / 2
        let cardY: CGFloat = size.height * 0.55 // Position higher to fit larger card
        let cornerRadius: CGFloat = cardWidth * 0.06
        
        let renderer = UIGraphicsImageRenderer(size: size)
        
        return renderer.image { context in
            // Draw original image
            resizedImage.draw(at: .zero)
            
            let cardRect = CGRect(x: cardX, y: cardY, width: cardWidth, height: cardHeight)
            let cardPath = UIBezierPath(roundedRect: cardRect, cornerRadius: cornerRadius)
            
            // White background with slight transparency
            UIColor.white.withAlphaComponent(0.97).setFill()
            cardPath.fill()
            
            // Subtle shadow effect (draw a darker rect behind)
            context.cgContext.saveGState()
            context.cgContext.setShadow(offset: CGSize(width: 0, height: 8), blur: 20, color: UIColor.black.withAlphaComponent(0.15).cgColor)
            UIColor.white.setFill()
            cardPath.fill()
            context.cgContext.restoreGState()
            
            // Border
            UIColor.gray.withAlphaComponent(0.15).setStroke()
            cardPath.lineWidth = 3
            cardPath.stroke()
            
            // Text sizes - significantly larger
            let titleFontSize: CGFloat = cardWidth * 0.08
            let caloriesFontSize: CGFloat = cardWidth * 0.09
            let macroFontSize: CGFloat = cardWidth * 0.065
            let padding: CGFloat = cardWidth * 0.06
            
            // Draw food name
            let titleFont = UIFont.systemFont(ofSize: titleFontSize, weight: .bold)
            let titleAttributes: [NSAttributedString.Key: Any] = [
                .font: titleFont,
                .foregroundColor: UIColor.black
            ]
            let titleRect = CGRect(x: cardRect.minX + padding, y: cardRect.minY + padding * 1.2, width: cardRect.width - padding * 2, height: titleFontSize * 1.4)
            let truncatedName = foodName.count > 30 ? String(foodName.prefix(27)) + "..." : foodName
            truncatedName.draw(in: titleRect, withAttributes: titleAttributes)
            
            // Draw calories - prominent
            let caloriesY = titleRect.maxY + padding * 0.8
            let caloriesFont = UIFont.systemFont(ofSize: caloriesFontSize, weight: .heavy)
            let caloriesText = "🔥 \(calories) Kalorier"
            let caloriesAttributes: [NSAttributedString.Key: Any] = [.font: caloriesFont, .foregroundColor: UIColor.black]
            let caloriesRect = CGRect(x: cardRect.minX + padding, y: caloriesY, width: cardRect.width - padding * 2, height: caloriesFontSize * 1.4)
            caloriesText.draw(in: caloriesRect, withAttributes: caloriesAttributes)
            
            // Draw macros - larger and more spaced
            let macrosY = caloriesRect.maxY + padding * 0.8
            let macroFont = UIFont.systemFont(ofSize: macroFontSize, weight: .semibold)
            let macrosText = "🐟 \(protein)g    🌿 \(carbs)g    💧 \(fat)g"
            let macroAttributes: [NSAttributedString.Key: Any] = [.font: macroFont, .foregroundColor: UIColor.darkGray]
            let macrosRect = CGRect(x: cardRect.minX + padding, y: macrosY, width: cardRect.width - padding * 2, height: macroFontSize * 1.4)
            macrosText.draw(in: macrosRect, withAttributes: macroAttributes)
        }
    }
    
    /// Safe method to dismiss story popup - handles the sequence properly to avoid crashes
    private func safelyDismissStoryPopup() {
        print("📸 Dismissing story popup safely...")
        
        // First hide the popup WITHOUT animation to avoid SwiftUI issues
        showStoryPopup = false
        
        // Then clear the data after a short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.result = nil
            self?.capturedImage = nil
            self?.noFoodDetected = false
            self?.errorMessage = nil
            self?.limitReached = false
            self?.isPostingStory = false
            print("📸 Story popup state cleared")
        }
    }
    
    // MARK: - Create Story Image with Food Overlay
    private func createStoryImage(original: UIImage, foodResult: AnalyzedFoodResult) -> UIImage {
        // Resize image if too large to prevent memory issues
        let maxDimension: CGFloat = 1500
        let resizedImage: UIImage
        if original.size.width > maxDimension || original.size.height > maxDimension {
            let scale = min(maxDimension / original.size.width, maxDimension / original.size.height)
            let newSize = CGSize(width: original.size.width * scale, height: original.size.height * scale)
            UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
            original.draw(in: CGRect(origin: .zero, size: newSize))
            resizedImage = UIGraphicsGetImageFromCurrentImageContext() ?? original
            UIGraphicsEndImageContext()
        } else {
            resizedImage = original
        }
        
        let size = resizedImage.size
        // Made card much larger - more than double the previous size
        let cardWidth: CGFloat = min(size.width * 0.92, 1200)
        let cardHeight: CGFloat = cardWidth * 0.55 // Taller card
        let cardX: CGFloat = (size.width - cardWidth) / 2
        let cardY: CGFloat = size.height * 0.55 // Position higher to fit larger card
        let cornerRadius: CGFloat = cardWidth * 0.06
        
        let renderer = UIGraphicsImageRenderer(size: size)
        
        return renderer.image { context in
            // Draw original image
            resizedImage.draw(at: .zero)
            
            let cardRect = CGRect(x: cardX, y: cardY, width: cardWidth, height: cardHeight)
            
            // Draw card background with rounded corners
            let cardPath = UIBezierPath(roundedRect: cardRect, cornerRadius: cornerRadius)
            
            // White background with slight transparency
            UIColor.white.withAlphaComponent(0.97).setFill()
            cardPath.fill()
            
            // Add shadow effect
            context.cgContext.saveGState()
            context.cgContext.setShadow(offset: CGSize(width: 0, height: 8), blur: 20, color: UIColor.black.withAlphaComponent(0.15).cgColor)
            UIColor.white.setFill()
            cardPath.fill()
            context.cgContext.restoreGState()
            
            // Draw border
            UIColor.gray.withAlphaComponent(0.15).setStroke()
            cardPath.lineWidth = 3
            cardPath.stroke()
            
            // Text sizes - significantly larger
            let titleFontSize: CGFloat = cardWidth * 0.08
            let caloriesFontSize: CGFloat = cardWidth * 0.09
            let macroFontSize: CGFloat = cardWidth * 0.065
            let padding: CGFloat = cardWidth * 0.06
            
            // Draw food name
            let titleFont = UIFont.systemFont(ofSize: titleFontSize, weight: .bold)
            let titleAttributes: [NSAttributedString.Key: Any] = [
                .font: titleFont,
                .foregroundColor: UIColor.black
            ]
            
            let titleRect = CGRect(
                x: cardRect.minX + padding,
                y: cardRect.minY + padding * 1.2,
                width: cardRect.width - padding * 2,
                height: titleFontSize * 1.4
            )
            
            let truncatedName = foodResult.foodName.count > 30 ? String(foodResult.foodName.prefix(27)) + "..." : foodResult.foodName
            truncatedName.draw(in: titleRect, withAttributes: titleAttributes)
            
            // Draw calories with flame emoji - prominent
            let caloriesY = titleRect.maxY + padding * 0.8
            let caloriesFont = UIFont.systemFont(ofSize: caloriesFontSize, weight: .heavy)
            let caloriesText = "🔥 \(foodResult.calories) Kalorier"
            let caloriesAttributes: [NSAttributedString.Key: Any] = [
                .font: caloriesFont,
                .foregroundColor: UIColor.black
            ]
            
            let caloriesRect = CGRect(
                x: cardRect.minX + padding,
                y: caloriesY,
                width: cardRect.width - padding * 2,
                height: caloriesFontSize * 1.4
            )
            caloriesText.draw(in: caloriesRect, withAttributes: caloriesAttributes)
            
            // Draw macros row - larger and more spaced
            let macrosY = caloriesRect.maxY + padding * 0.8
            let macroFont = UIFont.systemFont(ofSize: macroFontSize, weight: .semibold)
            let macrosText = "🐟 \(foodResult.protein)g    🌿 \(foodResult.carbs)g    💧 \(foodResult.fat)g"
            let macrosAttributes: [NSAttributedString.Key: Any] = [
                .font: macroFont,
                .foregroundColor: UIColor.darkGray
            ]
            
            let macrosRect = CGRect(
                x: cardRect.minX + padding,
                y: macrosY,
                width: cardRect.width - padding * 2,
                height: macroFontSize * 1.4
            )
            macrosText.draw(in: macrosRect, withAttributes: macrosAttributes)
        }
    }
    
    func dismissStoryPopup() {
        // Only dismiss if actually showing
        guard showStoryPopup else { return }
        
        // Use the safe dismissal method
        safelyDismissStoryPopup()
    }
    
    private func uploadFoodImage(data: Data, userId: String) async throws -> String {
        let fileName = "\(userId)/food_\(UUID().uuidString).jpg"
        
        print("📷 Uploading to path: \(fileName)")
        print("📷 Data size: \(data.count) bytes")
        
        do {
            try await SupabaseConfig.supabase.storage
                .from("food-images")
                .upload(
                    path: fileName,
                    file: data,
                    options: FileOptions(contentType: "image/jpeg")
                )
            print("📷 Upload completed")
        } catch {
            print("❌ Storage upload error: \(error)")
            throw error
        }
        
        // Get public URL
        let publicURL = try SupabaseConfig.supabase.storage
            .from("food-images")
            .getPublicURL(path: fileName)
        
        print("📷 Public URL: \(publicURL.absoluteString)")
        return publicURL.absoluteString
    }
}

// MARK: - Ingredient for Insert
struct FoodLogIngredientInsert: Codable {
    let name: String
    let calories: Int
    let protein: Int
    let carbs: Int
    let fat: Int
    let amount: String
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
    let ingredients: [FoodLogIngredientInsert]?
    
    enum CodingKeys: String, CodingKey {
        case id, name, calories, protein, carbs, fat, ingredients
        case userId = "user_id"
        case mealType = "meal_type"
        case loggedAt = "logged_at"
        case imageUrl = "image_url"
    }
}

