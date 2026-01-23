import SwiftUI
import Supabase

// MARK: - Nutrition Onboarding Data Model
struct NutritionOnboardingData: Codable {
    var gender: String = ""
    var workoutsPerWeek: String = ""
    var heightCm: Int = 170
    var weightKg: Double = 70.0
    var birthDate: Date = Calendar.current.date(byAdding: .year, value: -25, to: Date()) ?? Date()
    var goal: String = ""
    var targetWeightKg: Double = 65.0
    
    // Calculated results
    var dailyCalories: Int = 0
    var dailyProtein: Int = 0
    var dailyCarbs: Int = 0
    var dailyFat: Int = 0
    
    var age: Int {
        Calendar.current.dateComponents([.year], from: birthDate, to: Date()).year ?? 25
    }
}

// MARK: - Nutrition Onboarding View
struct NutritionOnboardingView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var authViewModel: AuthViewModel
    
    @State private var currentStep = 0
    @State private var onboardingData = NutritionOnboardingData()
    @State private var isCalculating = false
    @State private var calculationProgress: Double = 0
    @State private var calculationStep: String = ""
    @State private var showResults = false
    
    // Animation states
    @State private var contentOpacity: Double = 0
    @State private var contentOffset: CGFloat = 20
    
    private let totalSteps = 6
    
    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()
            
            if isCalculating {
                calculatingView
            } else if showResults {
                resultsView
            } else {
                VStack(spacing: 0) {
                    // Header with back button and progress bar
                    headerView
                    
                    // Content
                    ScrollView {
                        VStack(alignment: .leading, spacing: 24) {
                            stepContent
                                .opacity(contentOpacity)
                                .offset(y: contentOffset)
                        }
                        .padding(.horizontal, 24)
                        .padding(.top, 24)
                    }
                    
                    // Continue button
                    continueButton
                }
            }
        }
        .onAppear {
            animateContentIn()
        }
        .onChange(of: currentStep) { _, _ in
            animateContentIn()
        }
    }
    
    // MARK: - Header View
    private var headerView: some View {
        HStack(spacing: 16) {
            // Back button
            Button {
                if currentStep > 0 {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        currentStep -= 1
                    }
                } else {
                    dismiss()
                }
            } label: {
                Image(systemName: "arrow.left")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.black)
                    .frame(width: 40, height: 40)
                    .background(Color(.systemGray6))
                    .clipShape(Circle())
            }
            
            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color(.systemGray5))
                        .frame(height: 4)
                        .cornerRadius(2)
                    
                    Rectangle()
                        .fill(Color.black)
                        .frame(width: geometry.size.width * CGFloat(currentStep + 1) / CGFloat(totalSteps), height: 4)
                        .cornerRadius(2)
                        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: currentStep)
                }
            }
            .frame(height: 4)
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 24)
    }
    
    // MARK: - Step Content
    @ViewBuilder
    private var stepContent: some View {
        switch currentStep {
        case 0:
            genderStepView
        case 1:
            workoutsStepView
        case 2:
            heightWeightStepView
        case 3:
            birthdayStepView
        case 4:
            goalStepView
        case 5:
            targetWeightStepView
        default:
            EmptyView()
        }
    }
    
    // MARK: - Step 1: Gender Selection
    private var genderStepView: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Välj ditt kön")
                .font(.system(size: 32, weight: .bold))
                .foregroundColor(.black)
            
            Text("Detta används för att kalibrera din personliga plan.")
                .font(.system(size: 16))
                .foregroundColor(.gray)
            
            Spacer().frame(height: 60)
            
            VStack(spacing: 12) {
                genderOptionButton(title: "Man", value: "male")
                genderOptionButton(title: "Kvinna", value: "female")
                genderOptionButton(title: "Annat", value: "other")
            }
        }
    }
    
    private func genderOptionButton(title: String, value: String) -> some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                onboardingData.gender = value
            }
            hapticFeedback()
        } label: {
            Text(title)
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(onboardingData.gender == value ? Color.black : Color(.systemGray6))
                )
                .foregroundColor(onboardingData.gender == value ? .white : .black)
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Step 2: Workouts Per Week
    private var workoutsStepView: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Hur många pass tränar du per vecka?")
                .font(.system(size: 32, weight: .bold))
                .foregroundColor(.black)
            
            Text("Detta används för att kalibrera din personliga plan.")
                .font(.system(size: 16))
                .foregroundColor(.gray)
            
            Spacer().frame(height: 40)
            
            VStack(spacing: 12) {
                workoutOptionButton(
                    range: "0-2",
                    description: "Tränar då och då",
                    icon: "circle.fill",
                    value: "0-2"
                )
                workoutOptionButton(
                    range: "3-5",
                    description: "Några pass i veckan",
                    icon: "circle.grid.2x1.fill",
                    value: "3-5"
                )
                workoutOptionButton(
                    range: "6+",
                    description: "Dedikerad atlet",
                    icon: "circle.grid.3x3.fill",
                    value: "6+"
                )
            }
        }
    }
    
    private func workoutOptionButton(range: String, description: String, icon: String, value: String) -> some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                onboardingData.workoutsPerWeek = value
            }
            hapticFeedback()
        } label: {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(.black)
                    .frame(width: 40)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(range)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.black)
                    
                    Text(description)
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                }
                
                Spacer()
            }
            .padding(18)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(onboardingData.workoutsPerWeek == value ? Color(.systemGray5) : Color(.systemGray6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(onboardingData.workoutsPerWeek == value ? Color.black : Color.clear, lineWidth: 2)
                    )
            )
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Step 3: Height & Weight
    private var heightWeightStepView: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Längd & vikt")
                .font(.system(size: 32, weight: .bold))
                .foregroundColor(.black)
            
            Text("Detta används för att kalibrera din personliga plan.")
                .font(.system(size: 16))
                .foregroundColor(.gray)
            
            Spacer().frame(height: 40)
            
            // Pickers - metric only
            HStack(spacing: 20) {
                // Height picker
                VStack(spacing: 8) {
                    Text("Längd")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.black)
                    
                    Picker("Längd", selection: $onboardingData.heightCm) {
                        ForEach(140...220, id: \.self) { cm in
                            Text("\(cm) cm")
                                .tag(cm)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(height: 150)
                }
                .frame(maxWidth: .infinity)
                
                // Weight picker
                VStack(spacing: 8) {
                    Text("Vikt")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.black)
                    
                    Picker("Vikt", selection: Binding(
                        get: { Int(onboardingData.weightKg) },
                        set: { onboardingData.weightKg = Double($0) }
                    )) {
                        ForEach(40...200, id: \.self) { kg in
                            Text("\(kg) kg").tag(kg)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(height: 150)
                }
                .frame(maxWidth: .infinity)
            }
        }
    }
    
    // MARK: - Step 4: Birthday
    private var birthdayStepView: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("När är du född?")
                .font(.system(size: 32, weight: .bold))
                .foregroundColor(.black)
            
            Text("Detta används för att kalibrera din personliga plan.")
                .font(.system(size: 16))
                .foregroundColor(.gray)
            
            Spacer().frame(height: 80)
            
            DatePicker(
                "",
                selection: $onboardingData.birthDate,
                in: ...Date(),
                displayedComponents: .date
            )
            .datePickerStyle(.wheel)
            .labelsHidden()
            .environment(\.locale, Locale(identifier: "sv_SE"))
        }
    }
    
    // MARK: - Step 5: Goal Selection
    private var goalStepView: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Vad är ditt mål?")
                .font(.system(size: 32, weight: .bold))
                .foregroundColor(.black)
            
            Text("Detta hjälper oss skapa en plan för ditt kaloriintag.")
                .font(.system(size: 16))
                .foregroundColor(.gray)
            
            Spacer().frame(height: 60)
            
            VStack(spacing: 12) {
                goalOptionButton(title: "Gå ner i vikt", value: "lose")
                goalOptionButton(title: "Behålla vikt", value: "maintain")
                goalOptionButton(title: "Gå upp i vikt", value: "gain")
            }
        }
    }
    
    private func goalOptionButton(title: String, value: String) -> some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                onboardingData.goal = value
            }
            hapticFeedback()
        } label: {
            Text(title)
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(onboardingData.goal == value ? .white : .black)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.vertical, 20)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(onboardingData.goal == value ? Color.black : Color(.systemGray6))
                )
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Step 6: Target Weight
    private var targetWeightStepView: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Vad är din målvikt?")
                .font(.system(size: 32, weight: .bold))
                .foregroundColor(.black)
            
            Text("Välj den vikt du vill uppnå.")
                .font(.system(size: 16))
                .foregroundColor(.gray)
            
            Spacer().frame(height: 40)
            
            VStack(spacing: 24) {
                // Goal label
                Text(onboardingData.goal == "lose" ? "Gå ner i vikt" : onboardingData.goal == "gain" ? "Gå upp i vikt" : "Behåll vikt")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.gray)
                
                // Current weight info
                HStack {
                    Text("Nuvarande vikt:")
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                    Text("\(Int(onboardingData.weightKg)) kg")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.black)
                }
                
                // Target weight picker - simple and easy to use
                Picker("Målvikt", selection: Binding(
                    get: { Int(onboardingData.targetWeightKg) },
                    set: { onboardingData.targetWeightKg = Double($0) }
                )) {
                    ForEach(40...150, id: \.self) { kg in
                        Text("\(kg) kg").tag(kg)
                    }
                }
                .pickerStyle(.wheel)
                .frame(height: 150)
                
                // Weight difference indicator
                let diff = Int(onboardingData.targetWeightKg) - Int(onboardingData.weightKg)
                if diff != 0 {
                    HStack(spacing: 8) {
                        Image(systemName: diff < 0 ? "arrow.down.circle.fill" : "arrow.up.circle.fill")
                            .foregroundColor(diff < 0 ? .green : .orange)
                        
                        Text("\(abs(diff)) kg \(diff < 0 ? "att gå ner" : "att gå upp")")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.black)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                }
            }
        }
    }
    
    // MARK: - Continue Button
    private var continueButton: some View {
        VStack(spacing: 0) {
            Button {
                if currentStep < totalSteps - 1 {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        currentStep += 1
                    }
                } else {
                    startCalculation()
                }
                hapticFeedback()
            } label: {
                Text("Fortsätt")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(canContinue ? .white : .gray)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(canContinue ? Color.black : Color(.systemGray5))
                    .clipShape(Capsule())
            }
            .disabled(!canContinue)
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
        }
        .background(Color.white)
    }
    
    private var canContinue: Bool {
        switch currentStep {
        case 0: return !onboardingData.gender.isEmpty
        case 1: return !onboardingData.workoutsPerWeek.isEmpty
        case 2: return true
        case 3: return true
        case 4: return !onboardingData.goal.isEmpty
        case 5: return true
        default: return true
        }
    }
    
    // MARK: - Calculating View
    private var calculatingView: some View {
        VStack(spacing: 24) {
            Spacer()
            
            Text("\(Int(calculationProgress))%")
                .font(.system(size: 64, weight: .bold))
                .foregroundColor(.black)
                .contentTransition(.numericText())
                .animation(.easeOut(duration: 0.1), value: calculationProgress)
            
            Text("Vi skapar allt\nåt dig")
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(.black)
                .multilineTextAlignment(.center)
            
            // Progress bar with gradient
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color(.systemGray5))
                        .frame(height: 8)
                        .cornerRadius(4)
                    
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [Color.red, Color.blue],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geometry.size.width * CGFloat(calculationProgress / 100), height: 8)
                        .cornerRadius(4)
                        .animation(.easeOut(duration: 0.2), value: calculationProgress)
                }
            }
            .frame(height: 8)
            .padding(.horizontal, 40)
            
            Text(calculationStep)
                .font(.system(size: 16))
                .foregroundColor(.gray)
                .animation(.easeInOut, value: calculationStep)
            
            Spacer()
            
            // Recommendation checklist
            VStack(alignment: .leading, spacing: 12) {
                Text("Daglig rekommendation för")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.black)
                
                checklistItem(text: "Kalorier", isChecked: calculationProgress >= 20)
                checklistItem(text: "Kolhydrater", isChecked: calculationProgress >= 40)
                checklistItem(text: "Protein", isChecked: calculationProgress >= 60)
                checklistItem(text: "Fett", isChecked: calculationProgress >= 80)
                checklistItem(text: "Hälsopoäng", isChecked: calculationProgress >= 100)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 60)
        }
    }
    
    @ViewBuilder
    private func checklistItem(text: String, isChecked: Bool) -> some View {
        HStack(spacing: 12) {
            Text("•")
                .foregroundColor(.black)
            
            Text(text)
                .font(.system(size: 15))
                .foregroundColor(.black)
            
            Spacer()
            
            if isChecked {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.black)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isChecked)
    }
    
    // MARK: - Results View
    private var resultsView: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 16) {
                    // Back button
                    HStack {
                        Button {
                            withAnimation {
                                showResults = false
                                isCalculating = false
                                currentStep = totalSteps - 1
                            }
                        } label: {
                            Image(systemName: "arrow.left")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.black)
                                .frame(width: 40, height: 40)
                                .background(Color(.systemGray6))
                                .clipShape(Circle())
                        }
                        
                        // Full progress bar
                        GeometryReader { geometry in
                            Rectangle()
                                .fill(Color.black)
                                .frame(height: 4)
                                .cornerRadius(2)
                        }
                        .frame(height: 4)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    
                    // Checkmark and title
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 50))
                        .foregroundColor(.black)
                    
                    Text("Grattis")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.black)
                    
                    Text("din personliga plan är klar!")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.black)
                }
                
                // Goal prediction
                VStack(spacing: 12) {
                    Text("Du bör:")
                        .font(.system(size: 16))
                        .foregroundColor(.gray)
                    
                    Text(goalPredictionText)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.black)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(Color(.systemGray6))
                        .cornerRadius(20)
                }
                
                // Daily recommendation section
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Daglig rekommendation")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.black)
                        
                        Text("Du kan ändra detta när som helst")
                            .font(.system(size: 14))
                            .foregroundColor(.gray)
                    }
                    .padding(.horizontal, 24)
                    
                    // Macro cards grid
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                        MacroResultCard(
                            emoji: "🔥",
                            title: "Kalorier",
                            value: $onboardingData.dailyCalories,
                            unit: "",
                            progress: 0.75
                        )
                        
                        MacroResultCard(
                            emoji: "🌾",
                            title: "Kolhydrater",
                            value: $onboardingData.dailyCarbs,
                            unit: "g",
                            progress: 0.65
                        )
                        
                        MacroResultCard(
                            emoji: "🍗",
                            title: "Protein",
                            value: $onboardingData.dailyProtein,
                            unit: "g",
                            progress: 0.70
                        )
                        
                        MacroResultCard(
                            emoji: "🥑",
                            title: "Fett",
                            value: $onboardingData.dailyFat,
                            unit: "g",
                            progress: 0.55
                        )
                    }
                    .padding(.horizontal, 24)
                }
                
                Spacer().frame(height: 20)
                
                // Get started button
                Button {
                    saveAndComplete()
                } label: {
                    Text("Nu kör vi!")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(Color.black)
                        .clipShape(Capsule())
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            }
        }
    }
    
    // MARK: - Computed Properties
    private var goalPredictionText: String {
        let weightDiff = abs(onboardingData.targetWeightKg - onboardingData.weightKg)
        let weeks = Int(weightDiff / 0.5) // ~0.5kg per week
        let targetDate = Calendar.current.date(byAdding: .weekOfYear, value: max(weeks, 1), to: Date()) ?? Date()
        
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "sv_SE")
        dateFormatter.dateFormat = "d MMMM"
        
        let action = onboardingData.goal == "lose" ? "Gå ner" : onboardingData.goal == "gain" ? "Gå upp" : "Behåll"
        return "\(action) \(Int(weightDiff)) kg till \(dateFormatter.string(from: targetDate))"
    }
    
    // MARK: - Helper Functions
    private func animateContentIn() {
        contentOpacity = 0
        contentOffset = 20
        
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.1)) {
            contentOpacity = 1
            contentOffset = 0
        }
    }
    
    private func hapticFeedback() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
    }
    
    private func startCalculation() {
        withAnimation {
            isCalculating = true
        }
        
        // Simulate calculation steps
        let steps = [
            "Beräknar BMR...",
            "Tillämpar aktivitetsnivå...",
            "Optimerar makrofördelning...",
            "Anpassar efter mål...",
            "Färdigställer plan..."
        ]
        
        var currentStepIndex = 0
        calculationStep = steps[0]
        
        // Animate progress
        Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { timer in
            if calculationProgress < 100 {
                calculationProgress += 1
                
                // Update step text
                let newIndex = min(Int(calculationProgress / 20), steps.count - 1)
                if newIndex != currentStepIndex {
                    currentStepIndex = newIndex
                    withAnimation {
                        calculationStep = steps[newIndex]
                    }
                }
            } else {
                timer.invalidate()
                calculateNutritionPlan()
            }
        }
    }
    
    private func calculateNutritionPlan() {
        // Calculate using Mifflin-St Jeor equation
        let bmr: Double
        let weight = onboardingData.weightKg
        let height = Double(onboardingData.heightCm)
        let age = Double(onboardingData.age)
        
        if onboardingData.gender == "male" {
            bmr = 10 * weight + 6.25 * height - 5 * age + 5
        } else {
            bmr = 10 * weight + 6.25 * height - 5 * age - 161
        }
        
        // Activity multiplier
        let activityMultiplier: Double
        switch onboardingData.workoutsPerWeek {
        case "0-2": activityMultiplier = 1.375
        case "3-5": activityMultiplier = 1.55
        case "6+": activityMultiplier = 1.725
        default: activityMultiplier = 1.375
        }
        
        var tdee = bmr * activityMultiplier
        
        // Adjust for goal
        switch onboardingData.goal {
        case "lose": tdee -= 500 // Calorie deficit
        case "gain": tdee += 300 // Calorie surplus
        default: break
        }
        
        // Calculate macros
        let calories = Int(tdee)
        let protein = Int(weight * 2.0) // 2g per kg body weight
        let fat = Int(tdee * 0.25 / 9) // 25% of calories from fat
        let carbs = Int((tdee - Double(protein * 4) - Double(fat * 9)) / 4)
        
        onboardingData.dailyCalories = calories
        onboardingData.dailyProtein = protein
        onboardingData.dailyCarbs = max(carbs, 50)
        onboardingData.dailyFat = fat
        
        // Show results
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                isCalculating = false
                showResults = true
            }
        }
    }
    
    private func saveAndComplete() {
        // Save nutrition data to UserDefaults and/or Supabase
        Task {
            if let userId = authViewModel.currentUser?.id {
                // Save to Supabase using encodable struct
                do {
                    let updateData = NutritionProfileUpdate(
                        daily_calories_goal: onboardingData.dailyCalories,
                        daily_protein_goal: onboardingData.dailyProtein,
                        daily_carbs_goal: onboardingData.dailyCarbs,
                        daily_fat_goal: onboardingData.dailyFat,
                        target_weight: onboardingData.targetWeightKg,
                        height_cm: onboardingData.heightCm,
                        weight_kg: onboardingData.weightKg,
                        gender: onboardingData.gender,
                        fitness_goal: onboardingData.goal,
                        workouts_per_week: onboardingData.workoutsPerWeek
                    )
                    
                    try await SupabaseConfig.supabase
                        .from("profiles")
                        .update(updateData)
                        .eq("id", value: userId)
                        .execute()
                    
                    print("✅ Nutrition onboarding data saved")
                } catch {
                    print("❌ Failed to save nutrition data: \(error)")
                }
            }
            
            // Save locally (user-specific)
            if let userId = authViewModel.currentUser?.id {
                NutritionGoalsManager.shared.saveGoals(
                    calories: onboardingData.dailyCalories,
                    protein: onboardingData.dailyProtein,
                    carbs: onboardingData.dailyCarbs,
                    fat: onboardingData.dailyFat,
                    userId: userId
                )
            }
            
            // Post notification to refresh home view
            NotificationCenter.default.post(name: NSNotification.Name("NutritionGoalsUpdated"), object: nil)
            
            await MainActor.run {
                dismiss()
            }
        }
    }
}

// MARK: - Encodable struct for Supabase update
struct NutritionProfileUpdate: Encodable {
    let daily_calories_goal: Int
    let daily_protein_goal: Int
    let daily_carbs_goal: Int
    let daily_fat_goal: Int
    let target_weight: Double?
    let height_cm: Int?
    let weight_kg: Double?
    let gender: String?
    let fitness_goal: String?
    let workouts_per_week: String?
}

// Note: MacroResultCard is now defined in AuthenticationView.swift

#Preview {
    NutritionOnboardingView()
        .environmentObject(AuthViewModel())
}

