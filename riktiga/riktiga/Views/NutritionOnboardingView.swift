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
            Text(L.t(sv: "Välj ditt kön", nb: "Velg ditt kjønn"))
                .font(.system(size: 32, weight: .bold))
                .foregroundColor(.black)
            
            Text(L.t(sv: "Detta används för att kalibrera din personliga plan.", nb: "Dette brukes for å kalibrere din personlige plan."))
                .font(.system(size: 16))
                .foregroundColor(.gray)
            
            Spacer().frame(height: 60)
            
            VStack(spacing: 12) {
                genderOptionButton(title: L.t(sv: "Man", nb: "Mann"), value: "male")
                genderOptionButton(title: L.t(sv: "Kvinna", nb: "Kvinne"), value: "female")
                genderOptionButton(title: L.t(sv: "Annat", nb: "Annet"), value: "other")
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
            Text(L.t(sv: "Hur många pass tränar du per vecka?", nb: "Hvor mange økter trener du per uke?"))
                .font(.system(size: 32, weight: .bold))
                .foregroundColor(.black)
            
            Text(L.t(sv: "Detta används för att kalibrera din personliga plan.", nb: "Dette brukes for å kalibrere din personlige plan."))
                .font(.system(size: 16))
                .foregroundColor(.gray)
            
            Spacer().frame(height: 40)
            
            VStack(spacing: 12) {
                workoutOptionButton(
                    range: "0-2",
                    description: L.t(sv: "Tränar då och då", nb: "Trener nå og da"),
                    icon: "circle.fill",
                    value: "0-2"
                )
                workoutOptionButton(
                    range: "3-5",
                    description: L.t(sv: "Några pass i veckan", nb: "Noen økter i uken"),
                    icon: "circle.grid.2x1.fill",
                    value: "3-5"
                )
                workoutOptionButton(
                    range: "6+",
                    description: L.t(sv: "Dedikerad atlet", nb: "Dedikert utøver"),
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
            Text(L.t(sv: "Längd & vikt", nb: "Høyde & vekt"))
                .font(.system(size: 32, weight: .bold))
                .foregroundColor(.black)
            
            Text(L.t(sv: "Detta används för att kalibrera din personliga plan.", nb: "Dette brukes for å kalibrere din personlige plan."))
                .font(.system(size: 16))
                .foregroundColor(.gray)
            
            Spacer().frame(height: 40)
            
            // Pickers - metric only
            HStack(spacing: 20) {
                // Height picker
                VStack(spacing: 8) {
                    Text(L.t(sv: "Längd", nb: "Høyde"))
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.black)
                    
                    Picker(L.t(sv: "Längd", nb: "Høyde"), selection: $onboardingData.heightCm) {
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
                    Text(L.t(sv: "Vikt", nb: "Vekt"))
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.black)
                    
                    Picker(L.t(sv: "Vikt", nb: "Vekt"), selection: Binding(
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
            Text(L.t(sv: "När är du född?", nb: "Når er du født?"))
                .font(.system(size: 32, weight: .bold))
                .foregroundColor(.black)
            
            Text(L.t(sv: "Detta används för att kalibrera din personliga plan.", nb: "Dette brukes for å kalibrere din personlige plan."))
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
            Text(L.t(sv: "Vad är ditt mål?", nb: "Hva er målet ditt?"))
                .font(.system(size: 32, weight: .bold))
                .foregroundColor(.black)
            
            Text(L.t(sv: "Detta hjälper oss skapa en plan för ditt kaloriintag.", nb: "Dette hjelper oss å lage en plan for kaloriinntaket ditt."))
                .font(.system(size: 16))
                .foregroundColor(.gray)
            
            Spacer().frame(height: 60)
            
            VStack(spacing: 12) {
                goalOptionButton(title: L.t(sv: "Gå ner i vikt", nb: "Gå ned i vekt"), value: "lose")
                goalOptionButton(title: L.t(sv: "Behålla vikt", nb: "Beholde vekt"), value: "maintain")
                goalOptionButton(title: L.t(sv: "Gå upp i vikt", nb: "Gå opp i vekt"), value: "gain")
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
            Text(L.t(sv: "Vad är din målvikt?", nb: "Hva er målvekten din?"))
                .font(.system(size: 32, weight: .bold))
                .foregroundColor(.black)
            
            Text(L.t(sv: "Välj den vikt du vill uppnå.", nb: "Velg vekten du vil oppnå."))
                .font(.system(size: 16))
                .foregroundColor(.gray)
            
            Spacer().frame(height: 40)
            
            VStack(spacing: 24) {
                // Goal label
                Text(onboardingData.goal == "lose" ? L.t(sv: "Gå ner i vikt", nb: "Gå ned i vekt") : onboardingData.goal == "gain" ? L.t(sv: "Gå upp i vikt", nb: "Gå opp i vekt") : L.t(sv: "Behåll vikt", nb: "Behold vekt"))
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.gray)
                
                // Current weight info
                HStack {
                    Text(L.t(sv: "Nuvarande vikt:", nb: "Nåværende vekt:"))
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                    Text("\(Int(onboardingData.weightKg)) kg")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.black)
                }
                
                // Target weight picker - simple and easy to use
                Picker(L.t(sv: "Målvikt", nb: "Målvekt"), selection: Binding(
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
                        
                        Text(L.t(sv: "\(abs(diff)) kg \(diff < 0 ? "att gå ner" : "att gå upp")", nb: "\(abs(diff)) kg \(diff < 0 ? "å gå ned" : "å gå opp")"))
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
                Text(L.t(sv: "Fortsätt", nb: "Fortsett"))
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
            
            Text(L.t(sv: "Vi skapar allt\nåt dig", nb: "Vi lager alt\nfor deg"))
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
                Text(L.t(sv: "Daglig rekommendation för", nb: "Daglig anbefaling for"))
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.black)
                
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
                    
                    Text(L.t(sv: "Grattis", nb: "Gratulerer"))
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.black)
                    
                    Text(L.t(sv: "din personliga plan är klar!", nb: "din personlige plan er klar!"))
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.black)
                }
                
                // Goal prediction
                VStack(spacing: 12) {
                    Text(L.t(sv: "Du bör:", nb: "Du bør:"))
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
                        Text(L.t(sv: "Daglig rekommendation", nb: "Daglig anbefaling"))
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.black)
                        
                        Text(L.t(sv: "Du kan ändra detta när som helst", nb: "Du kan endre dette når som helst"))
                            .font(.system(size: 14))
                            .foregroundColor(.gray)
                    }
                    .padding(.horizontal, 24)
                    
                    // Macro cards grid
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                        MacroResultCard(
                            emoji: "🔥",
                            title: L.t(sv: "Kalorier", nb: "Kalorier"),
                            value: $onboardingData.dailyCalories,
                            unit: "",
                            progress: 0.75
                        )
                        
                        MacroResultCard(
                            emoji: "🌾",
                            title: L.t(sv: "Kolhydrater", nb: "Karbohydrater"),
                            value: $onboardingData.dailyCarbs,
                            unit: "g",
                            progress: 0.65
                        )
                        
                        MacroResultCard(
                            emoji: "🍗",
                            title: L.t(sv: "Protein", nb: "Protein"),
                            value: $onboardingData.dailyProtein,
                            unit: "g",
                            progress: 0.70
                        )
                        
                        MacroResultCard(
                            emoji: "🥑",
                            title: L.t(sv: "Fett", nb: "Fett"),
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
                    Text(L.t(sv: "Nu kör vi!", nb: "Nå kjører vi!"))
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
        
        let action = onboardingData.goal == "lose" ? L.t(sv: "Gå ner", nb: "Gå ned") : onboardingData.goal == "gain" ? L.t(sv: "Gå upp", nb: "Gå opp") : L.t(sv: "Behåll", nb: "Behold")
        return L.t(sv: "\(action) \(Int(weightDiff)) kg till \(dateFormatter.string(from: targetDate))", nb: "\(action) \(Int(weightDiff)) kg til \(dateFormatter.string(from: targetDate))")
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
            L.t(sv: "Beräknar BMR...", nb: "Beregner BMR..."),
            L.t(sv: "Tillämpar aktivitetsnivå...", nb: "Bruker aktivitetsnivå..."),
            L.t(sv: "Optimerar makrofördelning...", nb: "Optimerer makrofordeling..."),
            L.t(sv: "Anpassar efter mål...", nb: "Tilpasser etter mål..."),
            L.t(sv: "Färdigställer plan...", nb: "Ferdigstiller plan...")
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
                    let dateFormatter = DateFormatter()
                    dateFormatter.dateFormat = "yyyy-MM-dd"
                    let birthDateString = dateFormatter.string(from: onboardingData.birthDate)
                    
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
                        workouts_per_week: onboardingData.workoutsPerWeek,
                        birth_date: birthDateString
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
    let birth_date: String?
}

struct MacroResultCard: View {
    let emoji: String
    let title: String
    @Binding var value: Int
    let unit: String
    let progress: Double
    
    @Environment(\.colorScheme) private var colorScheme
    @State private var isEditing = false
    @State private var editValue: String = ""
    
    private var isDarkMode: Bool { colorScheme == .dark }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(emoji).font(.system(size: 14)).grayscale(1)
                Text(title).font(.system(size: 14)).foregroundColor(.gray)
                Spacer()
            }
            
            HStack(alignment: .bottom, spacing: 0) {
                ZStack {
                    Circle().stroke(Color(.systemGray5), lineWidth: 6).frame(width: 60, height: 60)
                    Circle().trim(from: 0, to: progress).stroke(Color.black, style: StrokeStyle(lineWidth: 6, lineCap: .round)).frame(width: 60, height: 60).rotationEffect(.degrees(-90))
                    VStack(spacing: 0) {
                        Text("\(value)").font(.system(size: 18, weight: .bold)).foregroundColor(isDarkMode ? .white : .black)
                        if !unit.isEmpty { Text(unit).font(.system(size: 10)).foregroundColor(.gray) }
                    }
                }
                Spacer()
                Button {
                    editValue = "\(value)"
                    isEditing = true
                } label: {
                    Image(systemName: "pencil").font(.system(size: 14)).foregroundColor(.gray)
                }
            }
        }
        .padding(16)
        .background(isDarkMode ? Color(.systemGray6) : Color.white)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(isDarkMode ? 0 : 0.06), radius: 8, x: 0, y: 2)
        .alert(L.t(sv: "Ändra \(title.lowercased())", nb: "Endre \(title.lowercased())"), isPresented: $isEditing) {
            TextField(L.t(sv: "Värde", nb: "Verdi"), text: $editValue)
                .keyboardType(.numberPad)
            Button(L.t(sv: "Avbryt", nb: "Avbryt"), role: .cancel) { }
            Button(L.t(sv: "Spara", nb: "Lagre")) {
                if let newValue = Int(editValue), newValue > 0 {
                    value = newValue
                    let generator = UIImpactFeedbackGenerator(style: .light)
                    generator.impactOccurred()
                }
            }
        } message: {
            Text(L.t(sv: "Ange nytt värde för \(title.lowercased())\(unit.isEmpty ? "" : " (\(unit))")", nb: "Skriv inn ny verdi for \(title.lowercased())\(unit.isEmpty ? "" : " (\(unit))")"))
        }
    }
}

#Preview {
    NutritionOnboardingView()
        .environmentObject(AuthViewModel())
}

