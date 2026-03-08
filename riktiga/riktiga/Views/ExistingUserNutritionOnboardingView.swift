import SwiftUI
import Supabase

// MARK: - Nutrition Onboarding for Existing Users
// This view is shown to users who already have an account but haven't completed the nutrition onboarding

struct ExistingUserNutritionOnboardingView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) private var colorScheme
    
    // Onboarding data
    @State private var gender: String = ""
    @State private var workoutsPerWeek: String = ""
    @State private var heightCm: Int = 170
    @State private var weightKg: Double = 70.0
    @State private var birthDate: Date = Calendar.current.date(byAdding: .year, value: -25, to: Date()) ?? Date()
    @State private var goal: String = ""
    @State private var targetWeightKg: Double = 65.0
    
    // Results
    @State private var dailyCalories: Int = 0
    @State private var dailyProtein: Int = 0
    @State private var dailyCarbs: Int = 0
    @State private var dailyFat: Int = 0
    
    // UI States
    @State private var currentStep: Int = 0
    @State private var isCalculating = false
    @State private var calculationProgress: Double = 0
    @State private var calculationStep: String = ""
    @State private var showResults = false
    @State private var contentOpacity: Double = 1
    @State private var contentOffset: CGFloat = 0
    
    private let totalSteps = 6
    
    private var age: Int {
        Calendar.current.dateComponents([.year], from: birthDate, to: Date()).year ?? 25
    }
    
    // MARK: - Dark Mode Colors
    private var isDarkMode: Bool { colorScheme == .dark }
    private var backgroundColor: Color { isDarkMode ? .black : .white }
    private var primaryTextColor: Color { isDarkMode ? .white : .black }
    private var secondaryTextColor: Color { isDarkMode ? .white.opacity(0.7) : .black.opacity(0.6) }
    private var buttonBackgroundColor: Color { isDarkMode ? .white : .black }
    private var buttonTextColor: Color { isDarkMode ? .black : .white }
    private var cardBackgroundColor: Color { isDarkMode ? Color(.systemGray6) : Color(.systemGray6) }
    private var selectedCardBackgroundColor: Color { isDarkMode ? .white : .black }
    private var selectedCardTextColor: Color { isDarkMode ? .black : .white }
    private var unselectedCardTextColor: Color { isDarkMode ? .white : .black }
    
    var body: some View {
        ZStack {
            backgroundColor.ignoresSafeArea()
            
            if showResults {
                resultsView
            } else if isCalculating {
                calculatingView
            } else {
                onboardingView
            }
        }
    }
    
    // MARK: - Onboarding View
    private var onboardingView: some View {
        VStack(spacing: 0) {
            // Header with back/close button and progress
            HStack(spacing: 16) {
                Button {
                    if currentStep > 0 {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            currentStep -= 1
                        }
                    } else {
                        dismiss()
                    }
                } label: {
                    Image(systemName: currentStep > 0 ? "arrow.left" : "xmark")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(primaryTextColor)
                        .frame(width: 40, height: 40)
                        .background(Color(.systemGray6))
                        .clipShape(Circle())
                }
                
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Rectangle()
                            .fill(Color(.systemGray5))
                            .frame(height: 4)
                            .cornerRadius(2)
                        
                        let progress = CGFloat(currentStep + 1) / CGFloat(totalSteps)
                        Rectangle()
                            .fill(buttonBackgroundColor)
                            .frame(width: geometry.size.width * progress, height: 4)
                            .cornerRadius(2)
                            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: currentStep)
                    }
                }
                .frame(height: 4)
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 24)
            
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(stepTitle)
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(primaryTextColor)
                    
                    Text(stepSubtitle)
                        .font(.system(size: 16))
                        .foregroundColor(.gray)
                        .padding(.bottom, 8)
                    
                    stepContent
                }
                .padding(.horizontal, 24)
                .opacity(contentOpacity)
                .offset(y: contentOffset)
            }
            
            // Continue button
            VStack(spacing: 0) {
                Button {
                    continueToNextStep()
                } label: {
                    Text(L.t(sv: "Fortsätt", nb: "Fortsett"))
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(canContinue ? buttonTextColor : .gray)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(canContinue ? buttonBackgroundColor : Color(.systemGray5))
                        .clipShape(Capsule())
                }
                .disabled(!canContinue)
                .padding(.horizontal, 24)
                .padding(.vertical, 16)
            }
            .background(backgroundColor)
        }
        .onChange(of: currentStep) { _, _ in
            animateContentIn()
        }
    }
    
    private var stepTitle: String {
        switch currentStep {
        case 0: return L.t(sv: "Välj ditt kön", nb: "Velg ditt kjønn")
        case 1: return L.t(sv: "Hur ofta tränar du?", nb: "Hvor ofte trener du?")
        case 2: return L.t(sv: "Längd & vikt", nb: "Høyde & vekt")
        case 3: return L.t(sv: "När är du född?", nb: "Når er du født?")
        case 4: return L.t(sv: "Vad är ditt mål?", nb: "Hva er målet ditt?")
        case 5: return L.t(sv: "Vad är din målvikt?", nb: "Hva er målvekten din?")
        default: return ""
        }
    }
    
    private var stepSubtitle: String {
        switch currentStep {
        case 0: return L.t(sv: "Detta används för att kalibrera din personliga plan.", nb: "Dette brukes for å kalibrere din personlige plan.")
        case 1: return L.t(sv: "Detta används för att kalibrera din personliga plan.", nb: "Dette brukes for å kalibrere din personlige plan.")
        case 2: return L.t(sv: "Detta används för att kalibrera din personliga plan.", nb: "Dette brukes for å kalibrere din personlige plan.")
        case 3: return L.t(sv: "Detta används för att kalibrera din personliga plan.", nb: "Dette brukes for å kalibrere din personlige plan.")
        case 4: return L.t(sv: "Detta hjälper oss skapa en plan för ditt kaloriintag.", nb: "Dette hjelper oss å lage en plan for kaloriinntaket ditt.")
        case 5: return L.t(sv: "Välj den vikt du vill uppnå.", nb: "Velg vekten du vil oppnå.")
        default: return ""
        }
    }
    
    @ViewBuilder
    private var stepContent: some View {
        switch currentStep {
        case 0: genderStepContent
        case 1: workoutsStepContent
        case 2: heightWeightStepContent
        case 3: birthdayStepContent
        case 4: goalStepContent
        case 5: targetWeightStepContent
        default: EmptyView()
        }
    }
    
    private var canContinue: Bool {
        switch currentStep {
        case 0: return !gender.isEmpty
        case 1: return !workoutsPerWeek.isEmpty
        case 2: return true
        case 3: return true
        case 4: return !goal.isEmpty
        case 5: return true
        default: return false
        }
    }
    
    // MARK: - Step Contents
    private var genderStepContent: some View {
        VStack(spacing: 12) {
            Spacer().frame(height: 40)
            genderButton(title: L.t(sv: "Man", nb: "Mann"), value: "male")
            genderButton(title: L.t(sv: "Kvinna", nb: "Kvinne"), value: "female")
            genderButton(title: L.t(sv: "Annat", nb: "Annet"), value: "other")
        }
    }
    
    private func genderButton(title: String, value: String) -> some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                gender = value
            }
            hapticFeedback()
        } label: {
            Text(title)
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(gender == value ? selectedCardTextColor : unselectedCardTextColor)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
                .background(RoundedRectangle(cornerRadius: 16).fill(gender == value ? selectedCardBackgroundColor : cardBackgroundColor))
        }
    }
    
    private var workoutsStepContent: some View {
        VStack(spacing: 12) {
            Spacer().frame(height: 20)
            workoutButton(range: "0-2", description: L.t(sv: "Tränar då och då", nb: "Trener av og til"), icon: "circle.fill", value: "0-2")
            workoutButton(range: "3-5", description: L.t(sv: "Några pass i veckan", nb: "Noen økter i uken"), icon: "circle.grid.2x1.fill", value: "3-5")
            workoutButton(range: "6+", description: L.t(sv: "Dedikerad atlet", nb: "Dedikert atlet"), icon: "circle.grid.3x3.fill", value: "6+")
        }
    }
    
    private func workoutButton(range: String, description: String, icon: String, value: String) -> some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                workoutsPerWeek = value
            }
            hapticFeedback()
        } label: {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(primaryTextColor)
                    .frame(width: 40)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(range).font(.system(size: 18, weight: .semibold)).foregroundColor(primaryTextColor)
                    Text(description).font(.system(size: 14)).foregroundColor(.gray)
                }
                Spacer()
            }
            .padding(18)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(workoutsPerWeek == value ? Color(.systemGray5) : cardBackgroundColor)
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(workoutsPerWeek == value ? buttonBackgroundColor : Color.clear, lineWidth: 2))
            )
        }
    }
    
    private var heightWeightStepContent: some View {
        VStack(spacing: 20) {
            Spacer().frame(height: 20)
            
            HStack(spacing: 20) {
                VStack(spacing: 8) {
                    Text(L.t(sv: "Längd", nb: "Høyde")).font(.system(size: 16, weight: .semibold)).foregroundColor(primaryTextColor)
                    Picker(L.t(sv: "Längd", nb: "Høyde"), selection: $heightCm) {
                        ForEach(140...220, id: \.self) { cm in
                            Text("\(cm) cm").tag(cm)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(height: 150)
                }
                .frame(maxWidth: .infinity)
                
                VStack(spacing: 8) {
                    Text(L.t(sv: "Vikt", nb: "Vekt")).font(.system(size: 16, weight: .semibold)).foregroundColor(primaryTextColor)
                    Picker(L.t(sv: "Vikt", nb: "Vekt"), selection: Binding(
                        get: { Int(weightKg) },
                        set: { weightKg = Double($0) }
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
    
    private var birthdayStepContent: some View {
        VStack {
            Spacer().frame(height: 60)
            DatePicker("", selection: $birthDate, in: ...Date(), displayedComponents: .date)
                .datePickerStyle(.wheel)
                .labelsHidden()
                .environment(\.locale, Locale(identifier: "sv_SE"))
        }
    }
    
    private var goalStepContent: some View {
        VStack(spacing: 12) {
            Spacer().frame(height: 40)
            goalButton(title: L.t(sv: "Gå ner i vikt", nb: "Gå ned i vekt"), value: "lose")
            goalButton(title: L.t(sv: "Behålla vikt", nb: "Beholde vekt"), value: "maintain")
            goalButton(title: L.t(sv: "Gå upp i vikt", nb: "Gå opp i vekt"), value: "gain")
        }
    }
    
    private func goalButton(title: String, value: String) -> some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                goal = value
            }
            hapticFeedback()
        } label: {
            Text(title)
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(goal == value ? selectedCardTextColor : unselectedCardTextColor)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.vertical, 20)
                .background(RoundedRectangle(cornerRadius: 16).fill(goal == value ? selectedCardBackgroundColor : cardBackgroundColor))
        }
    }
    
    private var targetWeightStepContent: some View {
        VStack(spacing: 24) {
            Spacer().frame(height: 20)
            
            Text(goal == "lose" ? L.t(sv: "Gå ner i vikt", nb: "Gå ned i vekt") : goal == "gain" ? L.t(sv: "Gå upp i vikt", nb: "Gå opp i vekt") : L.t(sv: "Behåll vikt", nb: "Behold vekt"))
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.gray)
            
            HStack {
                Text(L.t(sv: "Nuvarande vikt:", nb: "Nåværende vekt:")).font(.system(size: 14)).foregroundColor(.gray)
                Text("\(Int(weightKg)) kg").font(.system(size: 14, weight: .semibold)).foregroundColor(primaryTextColor)
            }
            
            Picker(L.t(sv: "Målvikt", nb: "Målvekt"), selection: Binding(
                get: { Int(targetWeightKg) },
                set: { targetWeightKg = Double($0) }
            )) {
                ForEach(40...150, id: \.self) { kg in
                    Text("\(kg) kg").tag(kg)
                }
            }
            .pickerStyle(.wheel)
            .frame(height: 150)
            
            let diff = Int(targetWeightKg) - Int(weightKg)
            if diff != 0 {
                HStack(spacing: 8) {
                    Image(systemName: diff < 0 ? "arrow.down.circle.fill" : "arrow.up.circle.fill")
                        .foregroundColor(diff < 0 ? .green : .orange)
                    Text("\(abs(diff)) kg \(diff < 0 ? L.t(sv: "att gå ner", nb: "å gå ned") : L.t(sv: "att gå upp", nb: "å gå opp"))")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(primaryTextColor)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(cardBackgroundColor)
                .cornerRadius(12)
            }
        }
    }
    
    // MARK: - Calculating View
    private var calculatingView: some View {
        VStack(spacing: 24) {
            Spacer()
            
            Text("\(Int(calculationProgress))%")
                .font(.system(size: 64, weight: .bold))
                .foregroundColor(primaryTextColor)
                .contentTransition(.numericText())
                .animation(.easeOut(duration: 0.1), value: calculationProgress)
            
            Text(L.t(sv: "Vi skapar allt\nåt dig", nb: "Vi lager alt\nfor deg"))
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(primaryTextColor)
                .multilineTextAlignment(.center)
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle().fill(Color(.systemGray5)).frame(height: 8).cornerRadius(4)
                    Rectangle()
                        .fill(LinearGradient(colors: [Color.red, Color.blue], startPoint: .leading, endPoint: .trailing))
                        .frame(width: geometry.size.width * CGFloat(calculationProgress / 100), height: 8)
                        .cornerRadius(4)
                }
            }
            .frame(height: 8)
            .padding(.horizontal, 40)
            
            Text(calculationStep)
                .font(.system(size: 16))
                .foregroundColor(.gray)
            
            Spacer()
            
            VStack(alignment: .leading, spacing: 12) {
                Text(L.t(sv: "Daglig rekommendation för", nb: "Daglig anbefaling for"))
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(primaryTextColor)
                
                checklistItem(text: L.t(sv: "Kalorier", nb: "Kalorier"), isChecked: calculationProgress >= 20)
                checklistItem(text: L.t(sv: "Kolhydrater", nb: "Karbohydrater"), isChecked: calculationProgress >= 40)
                checklistItem(text: L.t(sv: "Protein", nb: "Protein"), isChecked: calculationProgress >= 60)
                checklistItem(text: L.t(sv: "Fett", nb: "Fett"), isChecked: calculationProgress >= 80)
                checklistItem(text: L.t(sv: "Hälsopoäng", nb: "Helsepoeng"), isChecked: calculationProgress >= 100)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 60)
        }
    }
    
    @ViewBuilder
    private func checklistItem(text: String, isChecked: Bool) -> some View {
        HStack(spacing: 12) {
            Text("•").foregroundColor(primaryTextColor)
            Text(text).font(.system(size: 15)).foregroundColor(primaryTextColor)
            Spacer()
            if isChecked {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(primaryTextColor)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isChecked)
    }
    
    // MARK: - Results View
    private var resultsView: some View {
        ScrollView {
            VStack(spacing: 24) {
                VStack(spacing: 16) {
                    HStack {
                        Spacer()
                        GeometryReader { geometry in
                            Rectangle().fill(buttonBackgroundColor).frame(height: 4).cornerRadius(2)
                        }
                        .frame(height: 4)
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 50))
                        .foregroundColor(primaryTextColor)
                    
                    Text(L.t(sv: "Grattis", nb: "Gratulerer"))
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(primaryTextColor)
                    
                    Text(L.t(sv: "din personliga plan är klar!", nb: "din personlige plan er klar!"))
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(primaryTextColor)
                }
                
                VStack(spacing: 12) {
                    Text(L.t(sv: "Du bör:", nb: "Du bør:"))
                        .font(.system(size: 16))
                        .foregroundColor(.gray)
                    
                    Text(goalPredictionText)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(primaryTextColor)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(cardBackgroundColor)
                        .cornerRadius(20)
                }
                
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(L.t(sv: "Daglig rekommendation", nb: "Daglig anbefaling"))
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(primaryTextColor)
                        Text(L.t(sv: "Du kan ändra detta när som helst", nb: "Du kan endre dette når som helst"))
                            .font(.system(size: 14))
                            .foregroundColor(.gray)
                    }
                    .padding(.horizontal, 24)
                    
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                        MacroResultCard(emoji: "🔥", title: L.t(sv: "Kalorier", nb: "Kalorier"), value: $dailyCalories, unit: "", progress: 0.75)
                        MacroResultCard(emoji: "🌾", title: L.t(sv: "Kolhydrater", nb: "Karbohydrater"), value: $dailyCarbs, unit: "g", progress: 0.65)
                        MacroResultCard(emoji: "🍗", title: L.t(sv: "Protein", nb: "Protein"), value: $dailyProtein, unit: "g", progress: 0.70)
                        MacroResultCard(emoji: "🥑", title: L.t(sv: "Fett", nb: "Fett"), value: $dailyFat, unit: "g", progress: 0.55)
                    }
                    .padding(.horizontal, 24)
                }
                
                Spacer().frame(height: 20)
                
                Button {
                    saveAndComplete()
                } label: {
                    Text(L.t(sv: "Kom igång!", nb: "Kom i gang!"))
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(buttonTextColor)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(buttonBackgroundColor)
                        .clipShape(Capsule())
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            }
        }
    }
    
    private var goalPredictionText: String {
        let weightDiff = abs(targetWeightKg - weightKg)
        let weeks = Int(weightDiff / 0.5)
        let targetDate = Calendar.current.date(byAdding: .weekOfYear, value: max(weeks, 1), to: Date()) ?? Date()
        
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "sv_SE")
        dateFormatter.dateFormat = "d MMMM"
        
        let action = goal == "lose" ? L.t(sv: "Gå ner", nb: "Gå ned") : goal == "gain" ? L.t(sv: "Gå upp", nb: "Gå opp") : L.t(sv: "Behåll", nb: "Behold")
        return "\(action) \(Int(weightDiff)) kg \(L.t(sv: "till", nb: "til")) \(dateFormatter.string(from: targetDate))"
    }
    
    // MARK: - Helper Functions
    private func continueToNextStep() {
        hapticFeedback()
        
        if currentStep < totalSteps - 1 {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                currentStep += 1
            }
        } else {
            startCalculation()
        }
    }
    
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
        
        let steps = [
            L.t(sv: "Beräknar BMR...", nb: "Beregner BMR..."),
            L.t(sv: "Tillämpar aktivitetsnivå...", nb: "Bruker aktivitetsnivå..."),
            L.t(sv: "Optimerar makrofördelning...", nb: "Optimerer makrofordeling..."),
            L.t(sv: "Anpassar efter mål...", nb: "Tilpasser etter mål..."),
            L.t(sv: "Färdigställer plan...", nb: "Ferdigstiller plan...")
        ]
        
        var currentStepIndex = 0
        calculationStep = steps[0]
        
        Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { timer in
            if calculationProgress < 100 {
                calculationProgress += 1
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
        let bmr: Double
        let weight = weightKg
        let height = Double(heightCm)
        let ageDouble = Double(age)
        
        if gender == "male" {
            bmr = 10 * weight + 6.25 * height - 5 * ageDouble + 5
        } else {
            bmr = 10 * weight + 6.25 * height - 5 * ageDouble - 161
        }
        
        let activityMultiplier: Double
        switch workoutsPerWeek {
        case "0-2": activityMultiplier = 1.375
        case "3-5": activityMultiplier = 1.55
        case "6+": activityMultiplier = 1.725
        default: activityMultiplier = 1.375
        }
        
        var tdee = bmr * activityMultiplier
        
        switch goal {
        case "lose": tdee -= 500
        case "gain": tdee += 300
        default: break
        }
        
        let calories = Int(tdee)
        let protein = Int(weight * 2.0)
        let fat = Int(tdee * 0.25 / 9)
        let carbs = Int((tdee - Double(protein * 4) - Double(fat * 9)) / 4)
        
        dailyCalories = calories
        dailyProtein = protein
        dailyCarbs = max(carbs, 50)
        dailyFat = fat
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                isCalculating = false
                showResults = true
            }
        }
    }
    
    private func saveAndComplete() {
        Task {
            if let userId = authViewModel.currentUser?.id {
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "yyyy-MM-dd"
                let birthDateString = dateFormatter.string(from: birthDate)
                
                let updateData = NutritionProfileUpdate(
                    daily_calories_goal: dailyCalories,
                    daily_protein_goal: dailyProtein,
                    daily_carbs_goal: dailyCarbs,
                    daily_fat_goal: dailyFat,
                    target_weight: targetWeightKg,
                    height_cm: heightCm,
                    weight_kg: weightKg,
                    gender: gender,
                    fitness_goal: goal,
                    workouts_per_week: workoutsPerWeek,
                    birth_date: birthDateString
                )
                
                do {
                    try await SupabaseConfig.supabase
                        .from("profiles")
                        .update(updateData)
                        .eq("id", value: userId)
                        .execute()
                    print("✅ Nutrition goals saved to Supabase")
                } catch {
                    print("⚠️ Failed to save to Supabase: \(error)")
                }
            }
            
            // Save locally (user-specific)
            if let userId = authViewModel.currentUser?.id {
                NutritionGoalsManager.shared.saveGoals(
                    calories: dailyCalories,
                    protein: dailyProtein,
                    carbs: dailyCarbs,
                    fat: dailyFat,
                    userId: userId
                )
            }
            
            await MainActor.run {
                NotificationCenter.default.post(name: NSNotification.Name("NutritionGoalsUpdated"), object: nil)
                dismiss()
            }
        }
    }
}

#Preview {
    ExistingUserNutritionOnboardingView()
        .environmentObject(AuthViewModel())
}

