import SwiftUI

// MARK: - Food Nutrition Detail View
struct FoodNutritionDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var analyzingManager = AnalyzingFoodManager.shared
    
    @State private var ingredients: [AnalyzingFoodManager.AnalyzedIngredient] = []
    @State private var selectedIngredient: AnalyzingFoodManager.AnalyzedIngredient?
    @State private var showEditSheet = false
    @State private var showFixSheet = false
    @State private var fixDescription = ""
    @State private var isFixing = false
    @State private var fixProgress: Double = 0
    
    // Computed totals from ingredients
    private var totalProtein: Int {
        ingredients.reduce(0) { $0 + $1.protein }
    }
    
    private var totalCarbs: Int {
        ingredients.reduce(0) { $0 + $1.carbs }
    }
    
    private var totalFat: Int {
        ingredients.reduce(0) { $0 + $1.fat }
    }
    
    private var totalCalories: Int {
        ingredients.reduce(0) { $0 + $1.calories }
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // MARK: - Macro Summary Cards
                    macroSummarySection
                    
                    // Page indicator dots
                    HStack(spacing: 6) {
                        Circle()
                            .fill(Color.primary)
                            .frame(width: 8, height: 8)
                        Circle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: 8, height: 8)
                    }
                    .padding(.top, -8)
                    
                    // MARK: - Ingredients Section
                    ingredientsSection
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 120)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Näringsvärden")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "arrow.left")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.primary)
                            .padding(10)
                            .background(Color(.secondarySystemBackground))
                            .clipShape(Circle())
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button(role: .destructive) {
                            dismiss()
                        } label: {
                            Label("Avbryt", systemImage: "xmark")
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.primary)
                            .padding(10)
                            .background(Color(.secondarySystemBackground))
                            .clipShape(Circle())
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                bottomButtons
            }
        }
        .onAppear {
            if let result = analyzingManager.result {
                ingredients = result.ingredients
            }
        }
        .sheet(isPresented: $showEditSheet) {
            if let ingredient = selectedIngredient,
               let index = ingredients.firstIndex(where: { $0.id == ingredient.id }) {
                EditIngredientSheet(
                    ingredient: $ingredients[index],
                    onDelete: {
                        ingredients.remove(at: index)
                        showEditSheet = false
                    }
                )
                .presentationDetents([.medium])
            }
        }
    }
    
    // MARK: - Macro Summary Section
    private var macroSummarySection: some View {
        HStack(spacing: 12) {
            MacroSummaryCard(
                emoji: "🥩",
                label: "Protein",
                value: "\(totalProtein)g",
                color: Color(red: 0.95, green: 0.9, blue: 0.9)
            )
            
            MacroSummaryCard(
                emoji: "🌾",
                label: "Kolhydrater",
                value: "\(totalCarbs)g",
                color: Color(red: 0.95, green: 0.93, blue: 0.88)
            )
            
            MacroSummaryCard(
                emoji: "🥑",
                label: "Fett",
                value: "\(totalFat)g",
                color: Color(red: 0.9, green: 0.93, blue: 0.98)
            )
        }
        .padding(.top, 8)
    }
    
    // MARK: - Ingredients Section
    private var ingredientsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Text("Ingredienser")
                    .font(.system(size: 18, weight: .bold))
                
                Spacer()
                
                Button {
                    addNewIngredient()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                            .font(.system(size: 14, weight: .semibold))
                        Text("Lägg till")
                            .font(.system(size: 14, weight: .medium))
                    }
                    .foregroundColor(.primary)
                }
            }
            
            // Ingredients list
            VStack(spacing: 0) {
                ForEach(ingredients) { ingredient in
                    Button {
                        selectedIngredient = ingredient
                        showEditSheet = true
                    } label: {
                        IngredientRow(ingredient: ingredient)
                    }
                    .buttonStyle(.plain)
                    
                    if ingredient.id != ingredients.last?.id {
                        Divider()
                            .padding(.leading, 16)
                    }
                }
            }
            .background(Color(.systemBackground))
            .cornerRadius(16)
        }
    }
    
    // MARK: - Bottom Buttons
    private var bottomButtons: some View {
        HStack(spacing: 12) {
            // Rätta till button
            Button {
                showFixSheet = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 14))
                    Text("Rätta till")
                        .font(.system(size: 16, weight: .medium))
                }
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color(.systemBackground))
                .cornerRadius(28)
                .overlay(
                    RoundedRectangle(cornerRadius: 28)
                        .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                )
            }
            
            // Klar button
            Button {
                saveAndDismiss()
            } label: {
                Text("Klar")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.black)
                    .cornerRadius(28)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            Color(.systemBackground)
                .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: -5)
        )
        .sheet(isPresented: $showFixSheet) {
            FixNutritionSheet(
                fixDescription: $fixDescription,
                isFixing: $isFixing,
                fixProgress: $fixProgress,
                onFix: { performFix() },
                onDismiss: { showFixSheet = false }
            )
        }
    }
    
    // MARK: - Perform Fix with AI
    private func performFix() {
        guard !fixDescription.isEmpty else { return }
        guard let result = analyzingManager.result else { return }
        
        isFixing = true
        fixProgress = 0
        
        Task {
            do {
                // Get the image from the result or captured image
                let imageToAnalyze = result.image ?? analyzingManager.capturedImage
                
                // Compress image for API
                var imageData: Data? = nil
                if let image = imageToAnalyze {
                    imageData = image.jpegData(compressionQuality: 0.7)
                }
                
                // Animate progress
                for i in 1...8 {
                    try await Task.sleep(nanoseconds: 200_000_000)
                    await MainActor.run {
                        fixProgress = Double(i * 10)
                    }
                }
                
                // Call GPT for re-analysis with correction
                let fixedResult = try await reanalyzeWithAI(
                    originalName: result.foodName,
                    originalCalories: result.calories,
                    originalProtein: result.protein,
                    originalCarbs: result.carbs,
                    originalFat: result.fat,
                    originalIngredients: result.ingredients,
                    correction: fixDescription,
                    imageData: imageData
                )
                
                await MainActor.run {
                    fixProgress = 100
                    
                    // Update the result with fixed values
                    var updatedResult = result
                    updatedResult.foodName = fixedResult.name
                    updatedResult.calories = fixedResult.calories
                    updatedResult.protein = fixedResult.protein
                    updatedResult.carbs = fixedResult.carbs
                    updatedResult.fat = fixedResult.fat
                    updatedResult.ingredients = fixedResult.ingredients
                    
                    analyzingManager.result = updatedResult
                    ingredients = fixedResult.ingredients
                    
                    isFixing = false
                    showFixSheet = false
                    fixDescription = ""
                }
            } catch {
                print("❌ Fix error: \(error)")
                await MainActor.run {
                    isFixing = false
                }
            }
        }
    }
    
    private struct FixedResult {
        let name: String
        let calories: Int
        let protein: Int
        let carbs: Int
        let fat: Int
        let ingredients: [AnalyzingFoodManager.AnalyzedIngredient]
    }
    
    private func reanalyzeWithAI(
        originalName: String,
        originalCalories: Int,
        originalProtein: Int,
        originalCarbs: Int,
        originalFat: Int,
        originalIngredients: [AnalyzingFoodManager.AnalyzedIngredient],
        correction: String,
        imageData: Data?
    ) async throws -> FixedResult {
        guard let apiKey = EnvManager.shared.value(for: "OPENAI_API_KEY"), !apiKey.isEmpty else {
            throw NSError(domain: "APIKeyError", code: -1)
        }
        
        guard let url = URL(string: "https://api.openai.com/v1/chat/completions") else {
            throw NSError(domain: "URLError", code: -1)
        }
        
        let ingredientsText = originalIngredients.map { "\($0.name): \($0.calories) kcal, \($0.protein)g protein, \($0.carbs)g kolhydrater, \($0.fat)g fett (\($0.amount))" }.joined(separator: "\n")
        
        let prompt = """
        Du har tidigare analyserat en maträtt och fått följande resultat:
        - Namn: \(originalName)
        - Kalorier: \(originalCalories) kcal
        - Protein: \(originalProtein)g
        - Kolhydrater: \(originalCarbs)g
        - Fett: \(originalFat)g
        
        Ingredienser:
        \(ingredientsText.isEmpty ? "Inga ingredienser listade" : ingredientsText)
        
        Användaren har gett följande rättelse/korrigering:
        "\(correction)"
        
        Baserat på denna information OCH bilden (om tillgänglig), ge nya korrigerade näringsvärden och en uppdaterad ingredienslista.
        Använd svenska mått (gram, dl, msk, tsk, st).
        
        Svara ENDAST med JSON i detta format:
        {
            "name": "Korrigerat namn på svenska",
            "calories": 0,
            "protein": 0,
            "carbs": 0,
            "fat": 0,
            "ingredients": [
                {
                    "name": "Ingrediensnamn på svenska",
                    "calories": 0,
                    "protein": 0,
                    "carbs": 0,
                    "fat": 0,
                    "amount": "mängd med svenska mått"
                }
            ]
        }
        """
        
        var messages: [[String: Any]] = []
        
        // Build message content
        var contentArray: [[String: Any]] = [
            ["type": "text", "text": prompt]
        ]
        
        // Add image if available
        if let imageData = imageData {
            let base64Image = imageData.base64EncodedString()
            contentArray.append([
                "type": "image_url",
                "image_url": [
                    "url": "data:image/jpeg;base64,\(base64Image)",
                    "detail": "low"
                ]
            ])
        }
        
        messages.append([
            "role": "user",
            "content": contentArray
        ])
        
        let requestBody: [String: Any] = [
            "model": "gpt-4o-mini",
            "messages": messages,
            "max_tokens": 1500
        ]
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        let (data, _) = try await URLSession.shared.data(for: request)
        
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let firstChoice = choices.first,
              let message = firstChoice["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw NSError(domain: "ParseError", code: -1)
        }
        
        // Parse the JSON response
        let cleanedContent = content
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard let responseData = cleanedContent.data(using: .utf8),
              let resultJson = try JSONSerialization.jsonObject(with: responseData) as? [String: Any] else {
            throw NSError(domain: "JSONParseError", code: -1)
        }
        
        let name = resultJson["name"] as? String ?? originalName
        let calories = resultJson["calories"] as? Int ?? originalCalories
        let protein = resultJson["protein"] as? Int ?? originalProtein
        let carbs = resultJson["carbs"] as? Int ?? originalCarbs
        let fat = resultJson["fat"] as? Int ?? originalFat
        
        var parsedIngredients: [AnalyzingFoodManager.AnalyzedIngredient] = []
        if let ingredientsArray = resultJson["ingredients"] as? [[String: Any]] {
            for ing in ingredientsArray {
                let ingredient = AnalyzingFoodManager.AnalyzedIngredient(
                    name: ing["name"] as? String ?? "Okänd",
                    calories: ing["calories"] as? Int ?? 0,
                    protein: ing["protein"] as? Int ?? 0,
                    carbs: ing["carbs"] as? Int ?? 0,
                    fat: ing["fat"] as? Int ?? 0,
                    amount: ing["amount"] as? String ?? "1 portion"
                )
                parsedIngredients.append(ingredient)
            }
        }
        
        return FixedResult(
            name: name,
            calories: calories,
            protein: protein,
            carbs: carbs,
            fat: fat,
            ingredients: parsedIngredients.isEmpty ? originalIngredients : parsedIngredients
        )
    }
    
    // MARK: - Actions
    private func addNewIngredient() {
        let newIngredient = AnalyzingFoodManager.AnalyzedIngredient(
            name: "Ny ingrediens",
            calories: 0,
            protein: 0,
            carbs: 0,
            fat: 0,
            amount: "1 portion"
        )
        ingredients.append(newIngredient)
        selectedIngredient = newIngredient
        showEditSheet = true
    }
    
    private func saveAndDismiss() {
        // Update the result with modified ingredients
        if var result = analyzingManager.result {
            result.ingredients = ingredients
            result.recalculateTotals()
            analyzingManager.result = result
        }
        
        // Add to food log
        analyzingManager.addResultToLog()
        
        dismiss()
    }
}

// MARK: - Fix Nutrition Sheet
struct FixNutritionSheet: View {
    @Binding var fixDescription: String
    @Binding var isFixing: Bool
    @Binding var fixProgress: Double
    let onFix: () -> Void
    let onDismiss: () -> Void
    
    @FocusState private var isTextFieldFocused: Bool
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 40))
                        .foregroundColor(.black)
                    
                    Text("Rätta till")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.black)
                }
                .padding(.top, 8)
                
                // Text field
                TextField("Beskriv vad som ska rättas", text: $fixDescription, axis: .vertical)
                    .font(.system(size: 16))
                    .padding(16)
                    .background(Color.gray.opacity(0.08))
                    .cornerRadius(16)
                    .lineLimit(4...8)
                    .focused($isTextFieldFocused)
                
                // Example
                VStack(alignment: .leading, spacing: 8) {
                    Text("Exempel:")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.black)
                    
                    Text("\"Det var bara 100g kyckling, inte 200g\" eller \"Du missade att ta med såsen\"")
                        .font(.system(size: 15))
                        .foregroundColor(.gray)
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.gray.opacity(0.06))
                .cornerRadius(16)
                
                Spacer()
                
                // Update button
                if isFixing {
                    VStack(spacing: 12) {
                        ProgressView(value: fixProgress, total: 100)
                            .progressViewStyle(LinearProgressViewStyle(tint: .black))
                            .scaleEffect(y: 2)
                        
                        Text("Analyserar med AI...")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.gray)
                    }
                    .padding(.bottom, 20)
                } else {
                    Button {
                        onFix()
                    } label: {
                        Text("Uppdatera")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(fixDescription.isEmpty ? Color.gray : Color.black)
                            .cornerRadius(14)
                    }
                    .disabled(fixDescription.isEmpty)
                    .padding(.bottom, 20)
                }
            }
            .padding(.horizontal, 20)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        onDismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.black)
                            .frame(width: 36, height: 36)
                            .background(Color.gray.opacity(0.12))
                            .clipShape(Circle())
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .onAppear {
            isTextFieldFocused = true
        }
    }
}

// MARK: - Macro Summary Card
struct MacroSummaryCard: View {
    let emoji: String
    let label: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Text(emoji)
                .font(.system(size: 24))
            
            Text(label)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
            
            Text(value)
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.primary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(color)
        .cornerRadius(16)
    }
}

// MARK: - Ingredient Row
struct IngredientRow: View {
    let ingredient: AnalyzingFoodManager.AnalyzedIngredient
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(ingredient.name)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.primary)
                    
                    Text("• \(ingredient.calories) kcal")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            Text(ingredient.amount)
                .font(.system(size: 14))
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .contentShape(Rectangle())
    }
}

// MARK: - Edit Ingredient Sheet
struct EditIngredientSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var ingredient: AnalyzingFoodManager.AnalyzedIngredient
    let onDelete: () -> Void
    
    @State private var name: String = ""
    @State private var calories: String = ""
    @State private var protein: String = ""
    @State private var carbs: String = ""
    @State private var fat: String = ""
    @State private var amount: String = ""
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Ingrediens") {
                    TextField("Namn", text: $name)
                    TextField("Mängd (t.ex. 100g, 1 portion)", text: $amount)
                }
                
                Section("Näringsvärden") {
                    HStack {
                        Text("Kalorier")
                        Spacer()
                        TextField("0", text: $calories)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                        Text("kcal")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Protein")
                        Spacer()
                        TextField("0", text: $protein)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                        Text("g")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Kolhydrater")
                        Spacer()
                        TextField("0", text: $carbs)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                        Text("g")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Fett")
                        Spacer()
                        TextField("0", text: $fat)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                        Text("g")
                            .foregroundColor(.secondary)
                    }
                }
                
                Section {
                    Button(role: .destructive) {
                        onDelete()
                    } label: {
                        HStack {
                            Spacer()
                            Text("Ta bort ingrediens")
                            Spacer()
                        }
                    }
                }
            }
            .navigationTitle("Redigera ingrediens")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Avbryt") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Spara") {
                        saveChanges()
                        dismiss()
                    }
                    .font(.system(size: 16, weight: .semibold))
                }
            }
        }
        .onAppear {
            name = ingredient.name
            calories = "\(ingredient.calories)"
            protein = "\(ingredient.protein)"
            carbs = "\(ingredient.carbs)"
            fat = "\(ingredient.fat)"
            amount = ingredient.amount
        }
    }
    
    private func saveChanges() {
        ingredient.name = name
        ingredient.calories = Int(calories) ?? 0
        ingredient.protein = Int(protein) ?? 0
        ingredient.carbs = Int(carbs) ?? 0
        ingredient.fat = Int(fat) ?? 0
        ingredient.amount = amount
    }
}

#Preview {
    FoodNutritionDetailView()
}
