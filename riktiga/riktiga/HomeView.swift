import SwiftUI
import Combine
import UIKit
import Supabase
import HealthKit
import PhotosUI

// MARK: - Food Log Ingredient Model
struct FoodLogIngredient: Codable, Identifiable {
    var id: String { name + String(calories) }
    let name: String
    let calories: Int
    let protein: Int
    let carbs: Int
    let fat: Int
    let amount: String
}

// MARK: - Food Log Entry Model
struct FoodLogEntry: Identifiable, Codable {
    let id: String
    let userId: String
    let name: String
    let calories: Int
    let protein: Int
    let carbs: Int
    let fat: Int
    let mealType: String // "breakfast", "lunch", "dinner", "snack"
    let loggedAt: Date
    let imageUrl: String?
    let nutriScore: String?
    let ingredients: [FoodLogIngredient]?
    
    enum CodingKeys: String, CodingKey {
        case id, name, calories, protein, carbs, fat, ingredients
        case userId = "user_id"
        case mealType = "meal_type"
        case loggedAt = "logged_at"
        case imageUrl = "image_url"
        case nutriScore = "nutri_score"
    }
    
    // Nutri-Score color helper
    var nutriScoreColor: Color {
        switch nutriScore?.uppercased() {
        case "A": return Color(red: 0.0, green: 0.5, blue: 0.2)
        case "B": return Color(red: 0.5, green: 0.7, blue: 0.2)
        case "C": return Color(red: 0.9, green: 0.7, blue: 0.1)
        case "D": return Color(red: 0.9, green: 0.5, blue: 0.1)
        case "E": return Color(red: 0.8, green: 0.2, blue: 0.1)
        default: return Color.gray
        }
    }
}

// MARK: - Activity Log Entry Model
struct ActivityLogEntry: Identifiable, Codable {
    let id: String
    let userId: String
    let activityType: String
    let caloriesBurned: Int
    let duration: Int // minutes
    let intensity: String
    let loggedAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id, duration, intensity
        case userId = "user_id"
        case activityType = "activity_type"
        case caloriesBurned = "calories_burned"
        case loggedAt = "logged_at"
    }
}

// MARK: - Water Log Entry Model
struct WaterLogEntry: Identifiable, Codable {
    let id: String
    let userId: String
    let amount: Int // ml
    let loggedAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id, amount
        case userId = "user_id"
        case loggedAt = "logged_at"
    }
}

// MARK: - Test Food Log Insert (for debugging)
// MARK: - Daily Summary Model
struct DailySummary {
    var date: Date
    var steps: Int
    var stepsGoal: Int
    var caloriesBurned: Int
    var caloriesConsumed: Int
    var caloriesGoal: Int
    var waterMl: Int
    var waterGoalMl: Int
    var protein: Int
    var carbs: Int
    var fat: Int
    var foodLogs: [FoodLogEntry]
    var activityLogs: [ActivityLogEntry]
    
    var waterCups: Int { waterMl / 240 } // 240ml per cup
    var waterGoalCups: Int { waterGoalMl / 240 }
    
    static var empty: DailySummary {
        DailySummary(
            date: Date(),
            steps: 0,
            stepsGoal: 10000,
            caloriesBurned: 0,
            caloriesConsumed: 0,
            caloriesGoal: 2000,
            waterMl: 0,
            waterGoalMl: 2400,
            protein: 0,
            carbs: 0,
            fat: 0,
            foodLogs: [],
            activityLogs: []
        )
    }
}

// MARK: - Calorie Tracker Home View (Cal AI Style)
struct HomeView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @Environment(\.colorScheme) var colorScheme
    @StateObject private var viewModel = CalorieTrackerViewModel()
    @ObservedObject private var analyzingManager = AnalyzingFoodManager.shared
    
    // Animation states
    @State private var showCalendar = false
    @State private var showCards = false
    @State private var showWater = false
    @State private var showRecent = false
    @State private var showFoodScanner = false
    @State private var selectedFoodLog: FoodLogEntry?
    @State private var showNutritionDetail = false
    
    // Data transition animation
    @State private var isTransitioning = false
    @State private var displayedCaloriesLeft: Int = 0
    @State private var displayedCaloriesConsumed: Int = 0
    @State private var displayedCaloriesGoal: Int = 2000
    @State private var displayedProtein: Int = 0
    @State private var displayedCarbs: Int = 0
    @State private var displayedFat: Int = 0
    
    // Macro goals (loaded from UserDefaults, set by nutrition onboarding)
    @State private var proteinGoal: Int = 150
    @State private var carbsGoal: Int = 250
    @State private var fatGoal: Int = 70
    @State private var caloriesGoal: Int = 2000
    
    // Toggle between "kvar" (left) and "ätit" (eaten) mode
    @State private var showEatenMode = false
    @State private var isModeTransitioning = false
    
    // Nutrition onboarding for existing users
    @State private var showNutritionOnboarding = false
    
    // AI text food search
    @State private var aiTextInput: String = ""
    @State private var isAISearching: Bool = false
    @State private var aiSearchResult: FoodScannerService.AIFoodAnalysis? = nil
    @State private var aiSearchError: Bool = false
    @State private var aiSearchSaved: Bool = false
    @State private var aiDebounceTask: Task<Void, Never>? = nil
    @State private var showManualFoodEntry: Bool = false
    @State private var aiTextUsageCount: Int = 0
    
    // Achievement manager
    @ObservedObject private var achievementManager = AchievementManager.shared
    
    // Streak count
    @State private var streakCount: Int = 0
    
    // Pro banner always visible
    
    // Check if nutrition onboarding has been completed (user-specific)
    private var hasCompletedNutritionOnboarding: Bool {
        guard let userId = authViewModel.currentUser?.id else { return false }
        return NutritionGoalsManager.shared.hasCompletedOnboarding(userId: userId)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // MARK: - Standard App Header
            SimpleAppHeader()
                .environmentObject(authViewModel)
                .zIndex(2)
            
            // MARK: - Pro Banner (Sticky)
            // Only show for non-Pro members
            if !(authViewModel.currentUser?.isProMember ?? false) {
                ProBannerView(onTap: {
                    SuperwallService.shared.showPaywall()
                })
                .zIndex(1)
            }
            
            ZStack {
                // Background gradient - light blue
                LinearGradient(
                    colors: [
                        Color(red: 0.95, green: 0.97, blue: 1.0),
                        Color(red: 0.98, green: 0.95, blue: 0.97),
                        Color(.systemGroupedBackground)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 16) {
                        // Scroll offset detector
                        GeometryReader { geometry in
                            Color.clear.preference(
                                key: ScrollOffsetPreferenceKey.self,
                                value: geometry.frame(in: .named("scroll")).minY
                            )
                        }
                        .frame(height: 0)
                        
                        // MARK: - App Logo & Streak
                        HStack {
                            Image("23")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 44, height: 44)
                                .cornerRadius(10)
                            
                            Spacer()
                            
                            // Streak badge
                            HStack(spacing: 4) {
                                Image(systemName: "flame.fill")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.orange)
                                Text("\(streakCount)")
                                    .font(.system(size: 16, weight: .bold, design: .rounded))
                                    .foregroundColor(.primary)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(
                                Capsule()
                                    .fill(Color(.systemBackground))
                                    .shadow(color: .black.opacity(0.08), radius: 4, x: 0, y: 2)
                            )
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 8)
                        .pageEntrance()
                        
                        // MARK: - Week Calendar
                        weekCalendarView
                        .opacity(showCalendar ? 1 : 0)
                        .offset(y: showCalendar ? 0 : 10)
                        .pageEntrance(delay: 0.05)
                    
                    // MARK: - Calorie Card
                    calorieTrackerCard
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                        .opacity(showCards ? (isTransitioning ? 0.7 : 1) : 0)
                        .scaleEffect(isTransitioning ? 0.98 : 1)
                        .offset(y: showCards ? 0 : 15)
                        .pageEntrance(delay: 0.08)
                    
                    // MARK: - Macro Cards
                    macroCardsRow
                        .padding(.horizontal, 16)
                        .padding(.top, 14)
                        .opacity(showCards ? (isTransitioning ? 0.7 : 1) : 0)
                        .scaleEffect(isTransitioning ? 0.98 : 1)
                        .offset(y: showCards ? 0 : 15)
                        .pageEntrance(delay: 0.12)
                    
                    // MARK: - AI Text Food Input
                    aiTextInputSection
                        .padding(.horizontal, 16)
                        .padding(.top, 10)
                    
                    // Limit reached message
                    if !canUseAITextForFree {
                        Button {
                            SuperwallService.shared.showPaywall()
                        } label: {
                            Text("Din maxgräns är nådd. Uppgradera till Pro för full tillgång till kaloritracking med AI")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 20)
                                .padding(.top, 6)
                        }
                    }
                    
                    // Manual food entry button
                    Button {
                        showManualFoodEntry = true
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "square.and.pencil")
                                .font(.system(size: 14, weight: .medium))
                            Text("Registrera måltid manuellt")
                                .font(.system(size: 14, weight: .medium))
                        }
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(Color.white)
                                .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 3)
                        )
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    
                    // MARK: - AI Analyzing Section
                    if analyzingManager.isAnalyzing || analyzingManager.result != nil || analyzingManager.noFoodDetected || analyzingManager.limitReached {
                        aiAnalyzingSection
                            .padding(.horizontal, 16)
                            .transition(.asymmetric(
                                insertion: .opacity.combined(with: .scale(scale: 0.95)),
                                removal: .opacity
                            ))
                    }
                    
                    // MARK: - Recently Logged Section
                    recentlyLoggedSection
                        .padding(.horizontal, 16)
                        .opacity(showRecent ? (isTransitioning ? 0.6 : 1) : 0)
                        .offset(y: showRecent ? (isTransitioning ? 5 : 0) : 15)
                    
                    Spacer(minLength: 120)
                }
                .padding(.top, 8)
            }
            .coordinateSpace(name: "scroll")
            .refreshable {
                await refreshAllData()
            }
        } // ZStack
        } // VStack
        .onAppear {
            loadAITextUsage()
            animateContent()
            loadNutritionGoals()
            loadStreakCount()
            viewModel.setUserId(authViewModel.currentUser?.id)
            viewModel.loadData()
            updateDisplayedValues(animated: false)
        }
        .onChange(of: authViewModel.currentUser?.id) { _, newId in
            viewModel.setUserId(newId)
            viewModel.loadData()
            loadNutritionGoals()
            updateDisplayedValues(animated: false)
        }
        .onChange(of: viewModel.currentSummary.caloriesConsumed) { _, _ in
            updateDisplayedValues(animated: true)
        }
        .onChange(of: viewModel.currentSummary.caloriesGoal) { _, _ in
            updateDisplayedValues(animated: true)
        }
        .onChange(of: viewModel.currentSummary.protein) { _, _ in
            updateDisplayedValues(animated: true)
        }
        .onChange(of: viewModel.currentSummary.carbs) { _, _ in
            updateDisplayedValues(animated: true)
        }
        .onChange(of: viewModel.currentSummary.fat) { _, _ in
            updateDisplayedValues(animated: true)
        }
        .onChange(of: viewModel.selectedDate) { _, _ in
            // Trigger transition animation when date changes
            withAnimation(.easeOut(duration: 0.15)) {
                isTransitioning = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    isTransitioning = false
                }
            }
        }
        .onChange(of: showEatenMode) { _, _ in
            // Update displayed values when mode changes
            updateDisplayedValues(animated: true)
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("RefreshFoodLogs"))) { _ in
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                viewModel.loadData()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("NutritionGoalsUpdated"))) { _ in
            loadNutritionGoals()
            updateDisplayedValues(animated: true)
        }
        .onReceive(NotificationCenter.default.publisher(for: .streakUpdated)) { _ in
            loadStreakCount()
        }
        .fullScreenCover(isPresented: $showFoodScanner) {
            FoodScannerView(initialMode: .ai)
        }
        .fullScreenCover(isPresented: $showNutritionDetail) {
            FoodNutritionDetailView()
        }
        .fullScreenCover(item: $selectedFoodLog) { foodLog in
            FoodLogDetailView(entry: foodLog)
        }
        .fullScreenCover(isPresented: $showManualFoodEntry) {
            ManualFoodEntryView()
                .environmentObject(authViewModel)
        }
        .fullScreenCover(isPresented: $showNutritionOnboarding) {
            ExistingUserNutritionOnboardingView()
                .environmentObject(authViewModel)
        }
        .onChange(of: analyzingManager.showPaywallForLimit) { _, newValue in
            if newValue {
                SuperwallService.shared.showPaywall()
                analyzingManager.showPaywallForLimit = false
            }
        }
        .fullScreenCover(isPresented: $achievementManager.showAchievementPopup) {
            if let achievement = achievementManager.currentlyShowingAchievement {
                AchievementPopupView(
                    achievement: achievement,
                    onDismiss: {
                        achievementManager.dismissAchievement()
                    }
                )
                .background(Color.clear)
            }
        }
        .onAppear {
            // Set user for achievement manager
            if let userId = authViewModel.currentUser?.id {
                achievementManager.setUser(userId)
            }
        }
    }
    
    // MARK: - Week Calendar View
    private var weekCalendarView: some View {
        let weeksCount = viewModel.weeks.count
        return TabView(selection: $viewModel.currentWeekIndex) {
            ForEach(0..<weeksCount, id: \.self) { index in
                weekView(week: viewModel.weeks[index])
                    .tag(index)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .frame(height: 100)
    }
    
    private func weekView(week: CalorieTrackerViewModel.WeekInfo) -> some View {
        HStack(spacing: 0) {
            ForEach(week.days) { dayInfo in
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        viewModel.selectDate(dayInfo.date)
                    }
                } label: {
                    VStack(spacing: 8) {
                        Text(dayInfo.dayLetter)
                            .font(.system(size: 13, weight: dayInfo.isSelected || dayInfo.isToday ? .semibold : .medium))
                            .foregroundColor(dayInfo.isSelected ? .black : (dayInfo.isToday ? Color.black.opacity(0.7) : Color.gray.opacity(0.6)))
                        
                        ZStack {
                            // Ring based on calorie status
                            dayRing(for: dayInfo)
                            
                            Text("\(dayInfo.dayNumber)")
                                .font(.system(size: 15, weight: dayInfo.isSelected || dayInfo.isToday ? .bold : .medium))
                                .foregroundColor(dayInfo.isSelected ? .black : (dayInfo.isToday ? Color.black.opacity(0.85) : Color.black.opacity(0.7)))
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        dayInfo.isSelected ?
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.white)
                            .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 2)
                        : nil
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 8)
    }
    
    /// Returns the appropriate ring view based on calorie status
    @ViewBuilder
    private func dayRing(for dayInfo: CalorieTrackerViewModel.DayInfo) -> some View {
        let ringColor = ringColor(for: dayInfo.calorieStatus)
        
        if dayInfo.isSelected {
            // Selected state: solid ring (color based on status, or black if no meals)
            Circle()
                .stroke(ringColor, lineWidth: 2.5)
                .frame(width: 40, height: 40)
        } else {
            switch dayInfo.calorieStatus {
            case .onTarget:
                // Green solid ring
                Circle()
                    .stroke(Color.green, lineWidth: 2)
                    .frame(width: 40, height: 40)
            case .slightlyOver:
                // Yellow solid ring
                Circle()
                    .stroke(Color.yellow, lineWidth: 2)
                    .frame(width: 40, height: 40)
            case .overTarget:
                // Red solid ring
                Circle()
                    .stroke(Color.red, lineWidth: 2)
                    .frame(width: 40, height: 40)
            case .noMeals, .future:
                // Dotted gray ring
                Circle()
                    .stroke(style: StrokeStyle(lineWidth: 1.5, lineCap: .round, dash: [2, 4]))
                    .foregroundColor(dayInfo.isToday ? Color.gray.opacity(0.4) : Color.gray.opacity(0.25))
                    .frame(width: 40, height: 40)
            }
        }
    }
    
    /// Returns the color for the ring based on calorie status
    private func ringColor(for status: CalorieTrackerViewModel.CalorieStatus) -> Color {
        switch status {
        case .onTarget: return .green
        case .slightlyOver: return .yellow
        case .overTarget: return .red
        case .noMeals, .future: return .black
        }
    }
    
    // MARK: - Calorie Tracker Card
    private var calorieTrackerCard: some View {
        Button {
            handleNutritionCardTap()
        } label: {
            HStack(spacing: 24) {
                VStack(alignment: .leading, spacing: 6) {
                    if hasCompletedNutritionOnboarding {
                        // Show either calories left or calories consumed
                        let displayValue = showEatenMode ? displayedCaloriesConsumed : displayedCaloriesLeft
                        
                        Text("\(displayValue)")
                            .font(.system(size: 56, weight: .bold))
                            .foregroundColor(.black)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                            .fixedSize(horizontal: true, vertical: false)
                            .contentTransition(.numericText(value: Double(displayValue)))
                            .animation(.spring(response: 0.5, dampingFraction: 0.8), value: displayValue)
                            .opacity(isModeTransitioning ? 0 : 1)
                            .scaleEffect(isModeTransitioning ? 0.8 : 1)
                        
                        Text(showEatenMode ? "Kalorier ätit" : "Kalorier kvar")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.gray)
                            .contentTransition(.opacity)
                            .animation(.easeInOut(duration: 0.2), value: showEatenMode)
                    } else {
                        // Show "?" for users who haven't completed nutrition onboarding
                        Text("?")
                            .font(.system(size: 56, weight: .bold))
                            .foregroundColor(.black)
                        
                        Text("Tryck för att ställa in")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.gray)
                    }
                }
                
                Spacer()
                
                ZStack {
                    Circle()
                        .stroke(Color.gray.opacity(0.12), lineWidth: 12)
                        .frame(width: 108, height: 108)
                    
                    if hasCompletedNutritionOnboarding {
                        Circle()
                            .trim(from: 0, to: CGFloat(min(Double(displayedCaloriesConsumed) / Double(max(displayedCaloriesGoal, 1)), 1.0)))
                            .stroke(Color.black, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                            .frame(width: 108, height: 108)
                            .rotationEffect(.degrees(-90))
                            .animation(.spring(response: 0.6, dampingFraction: 0.75), value: displayedCaloriesConsumed)
                    }
                    
                    Image(systemName: hasCompletedNutritionOnboarding ? "flame.fill" : "questionmark")
                        .font(.system(size: 28))
                        .foregroundColor(.black)
                }
            }
            .padding(30)
            .background(Color.white)
            .cornerRadius(26)
            .shadow(color: Color.black.opacity(0.07), radius: 14, x: 0, y: 6)
        }
        .buttonStyle(.plain)
    }
    
    // Handle tap on nutrition cards
    private func handleNutritionCardTap() {
        if hasCompletedNutritionOnboarding {
            toggleEatenMode()
        } else {
            // Open nutrition onboarding for users who haven't set up their goals
            showNutritionOnboarding = true
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.impactOccurred()
        }
    }
    
    // Toggle between "kvar" and "ätit" mode with animation
    private func toggleEatenMode() {
        // Start transition animation
        withAnimation(.easeOut(duration: 0.15)) {
            isModeTransitioning = true
        }
        
        // Toggle mode after brief delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                showEatenMode.toggle()
                isModeTransitioning = false
            }
        }
        
        // Haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
    }
    
    // MARK: - Macro Cards Row
    private var macroCardsRow: some View {
        Button {
            handleNutritionCardTap()
        } label: {
            let proteinEaten = viewModel.currentSummary.protein
            let carbsEaten = viewModel.currentSummary.carbs
            let fatEaten = viewModel.currentSummary.fat
            
            HStack(spacing: 10) {
                animatedMacroCard(
                    value: hasCompletedNutritionOnboarding ? displayedProtein : nil,
                    name: "Protein",
                    emoji: "🍗",
                    color: .black,
                    progress: Double(proteinEaten) / Double(max(proteinGoal, 1))
                )
                
                animatedMacroCard(
                    value: hasCompletedNutritionOnboarding ? displayedCarbs : nil,
                    name: "Kolhydrater",
                    emoji: "🌾",
                    color: .black,
                    progress: Double(carbsEaten) / Double(max(carbsGoal, 1))
                )
                
                animatedMacroCard(
                    value: hasCompletedNutritionOnboarding ? displayedFat : nil,
                    name: "Fett",
                    emoji: "🥑",
                    color: .black,
                    progress: Double(fatEaten) / Double(max(fatGoal, 1))
                )
            }
        }
        .buttonStyle(.plain)
    }
    
    private func animatedMacroCard(value: Int?, name: String, emoji: String, color: Color, progress: Double) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            if let value = value {
                Text("\(value)g")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.black)
                    .contentTransition(.numericText(value: Double(value)))
                    .animation(.spring(response: 0.5, dampingFraction: 0.8), value: value)
                    .opacity(isModeTransitioning ? 0 : 1)
                    .scaleEffect(isModeTransitioning ? 0.8 : 1)
                
                Text(name)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.gray)
                    .lineLimit(1)
            } else {
                Text("?")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.black)
                
                Text(name)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.gray)
                    .lineLimit(1)
            }
            
            Spacer()
            
            HStack {
                Spacer()
                ZStack {
                    Circle()
                        .stroke(Color.gray.opacity(0.12), lineWidth: 6)
                        .frame(width: 56, height: 56)
                    
                    if hasCompletedNutritionOnboarding {
                        Circle()
                            .trim(from: 0, to: CGFloat(min(max(progress, 0), 1)))
                            .stroke(color, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                            .frame(width: 56, height: 56)
                            .rotationEffect(.degrees(-90))
                            .animation(.spring(response: 0.6, dampingFraction: 0.8), value: progress)
                    }
                    
                    Text(emoji)
                        .font(.system(size: 22))
                        .grayscale(1)
                }
                Spacer()
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .frame(height: 130)
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 3)
    }
    
    // MARK: - AI Text Food Input Section
    
    private var confidenceScore: Int {
        guard let result = aiSearchResult else { return 0 }
        switch result.confidence {
        case "high": return 9
        case "medium": return 6
        case "low": return 3
        default: return 5
        }
    }
    
    private var aiTextInputSection: some View {
        VStack(spacing: 0) {
            // Main input row
            Button {
                if let result = aiSearchResult, !aiSearchSaved {
                    saveAISearchResult(result)
                }
            } label: {
                HStack(spacing: 12) {
                    // Text field
                    TextField("Skriv vad du åt, AI räknar kalorier...", text: $aiTextInput)
                        .font(.system(size: 14, weight: .regular))
                        .foregroundColor(.primary)
                        .submitLabel(.send)
                        .onSubmit {
                            if canUseAITextForFree {
                                analyzeFromText()
                            } else {
                                SuperwallService.shared.showPaywall()
                            }
                        }
                        .onChange(of: aiTextInput) { _, newValue in
                            // Reset previous result when typing new text
                            if aiSearchResult != nil && !isAISearching {
                                withAnimation {
                                    aiSearchResult = nil
                                    aiSearchSaved = false
                                    aiSearchError = false
                                }
                            }
                            
                            // Auto-search with debounce: start shimmer immediately, search after 1.2s pause
                            aiDebounceTask?.cancel()
                            let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                            if trimmed.count >= 3 {
                                // Check if user can use AI text for free
                                if !canUseAITextForFree {
                                    // Show paywall immediately
                                    SuperwallService.shared.showPaywall()
                                } else {
                                    // Show shimmer immediately while user types
                                    if !isAISearching {
                                        withAnimation {
                                            isAISearching = true
                                            aiSearchError = false
                                        }
                                    }
                                    // Debounce: wait for user to stop typing before actually calling API
                                    aiDebounceTask = Task {
                                        try? await Task.sleep(nanoseconds: 1_200_000_000) // 1.2 seconds
                                        guard !Task.isCancelled else { return }
                                        await MainActor.run {
                                            analyzeFromText()
                                        }
                                    }
                                }
                            } else {
                                // Clear searching state if text is too short
                                if isAISearching {
                                    withAnimation {
                                        isAISearching = false
                                    }
                                }
                            }
                        }
                    
                    // Right side: status indicator
                    if isAISearching {
                        // Shimmer "Söker" text
                        Text("Söker")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.gray)
                            .modifier(ShimmerEffect())
                    } else if let result = aiSearchResult, !aiSearchSaved {
                        // Result: sparkle + calories
                        HStack(spacing: 4) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 12, weight: .semibold))
                            Text("\(result.calories) cal")
                                .font(.system(size: 14, weight: .bold))
                        }
                        .foregroundColor(.black)
                    } else if aiSearchSaved {
                        // Saved checkmark
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 18))
                            .foregroundColor(.black)
                    } else if aiSearchError {
                        Text("Försök igen")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.red)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color.white)
                        .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 3)
                )
            }
            .buttonStyle(.plain)
            
            // Sources + confidence scale + log button (always visible when result exists)
            if let _ = aiSearchResult, !aiSearchSaved {
                VStack(spacing: 10) {
                    // Confidence scale 1-10
                    HStack(spacing: 3) {
                        Text("Träffsäkerhet")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.secondary)
                        
                        // Visual scale bars 1-10
                        HStack(spacing: 2) {
                            ForEach(1...10, id: \.self) { i in
                                RoundedRectangle(cornerRadius: 1.5)
                                    .fill(i <= confidenceScore ? Color.black : Color.black.opacity(0.12))
                                    .frame(width: 8, height: 12)
                            }
                        }
                        
                        Text("\(confidenceScore)/10")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundColor(.black)
                        
                        Spacer()
                        
                        // Log button
                        Button {
                            if let result = aiSearchResult {
                                saveAISearchResult(result)
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 12))
                                Text("Logga")
                                    .font(.system(size: 13, weight: .semibold))
                            }
                            .foregroundColor(.black)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                Capsule()
                                    .fill(Color.black.opacity(0.08))
                            )
                        }
                    }
                    
                    // Sources
                    HStack(spacing: 4) {
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 9))
                        Text("Källa: GPT-4o nutritionsdata")
                            .font(.system(size: 11, weight: .medium))
                        Spacer()
                    }
                    .foregroundColor(.secondary.opacity(0.7))
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: isAISearching)
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: aiSearchResult != nil)
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: aiSearchSaved)
    }
    
    // MARK: - AI Text Search Functions
    
    private var isProUser: Bool {
        authViewModel.currentUser?.isProMember ?? false
    }
    
    private var aiTextFreeLimit: Int { 2 }
    
    private var canUseAITextForFree: Bool {
        isProUser || aiTextUsageCount < aiTextFreeLimit
    }
    
    private var aiTextUsageKey: String {
        let userId = authViewModel.currentUser?.id ?? "unknown"
        return "ai_text_search_usage_\(userId)"
    }
    
    private func loadAITextUsage() {
        aiTextUsageCount = UserDefaults.standard.integer(forKey: aiTextUsageKey)
    }
    
    private func incrementAITextUsage() {
        aiTextUsageCount += 1
        UserDefaults.standard.set(aiTextUsageCount, forKey: aiTextUsageKey)
    }
    
    private func analyzeFromText() {
        let text = aiTextInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        
        // Check limit for non-pro users
        if !isProUser && aiTextUsageCount >= aiTextFreeLimit {
            withAnimation {
                isAISearching = false
            }
            SuperwallService.shared.showPaywall()
            return
        }
        
        if !isAISearching {
            withAnimation {
                isAISearching = true
            }
        }
        aiSearchResult = nil
        aiSearchError = false
        aiSearchSaved = false
        
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        
        Task {
            do {
                let result = try await FoodScannerService.shared.analyzeFoodFromDescription(text)
                
                // Count usage on successful result
                await MainActor.run {
                    incrementAITextUsage()
                }
                
                await MainActor.run {
                    withAnimation {
                        aiSearchResult = result
                        isAISearching = false
                    }
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                }
            } catch {
                await MainActor.run {
                    withAnimation {
                        isAISearching = false
                        aiSearchError = true
                    }
                    UINotificationFeedbackGenerator().notificationOccurred(.error)
                }
                print("❌ AI text analysis failed: \(error)")
                
                // Clear error after 3 seconds
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    withAnimation {
                        aiSearchError = false
                    }
                }
            }
        }
    }
    
    private func saveAISearchResult(_ result: FoodScannerService.AIFoodAnalysis) {
        guard let userId = authViewModel.currentUser?.id else { return }
        
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        
        withAnimation {
            aiSearchSaved = true
        }
        
        Task {
            do {
                let entry = ManualFoodLogInsert(
                    id: UUID().uuidString,
                    userId: userId,
                    name: result.name,
                    calories: result.calories,
                    protein: result.protein,
                    carbs: result.carbs,
                    fat: result.fat,
                    mealType: "snack",
                    loggedAt: ISO8601DateFormatter().string(from: Date()),
                    imageUrl: nil
                )
                
                try await SupabaseConfig.supabase
                    .from("food_logs")
                    .insert(entry)
                    .execute()
                
                print("✅ AI text food saved: \(result.name) - \(result.calories) cal")
                
                await MainActor.run {
                    NotificationCenter.default.post(name: NSNotification.Name("RefreshFoodLogs"), object: nil)
                    viewModel.loadData()
                    updateDisplayedValues(animated: true)
                }
                
                // Reset after a short delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    withAnimation {
                        aiTextInput = ""
                        aiSearchResult = nil
                        aiSearchSaved = false
                    }
                }
            } catch {
                print("❌ Failed to save AI food: \(error)")
                await MainActor.run {
                    withAnimation {
                        aiSearchSaved = false
                    }
                }
            }
        }
    }
    
    // MARK: - Recently Logged Section
    private var recentlyLoggedSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Nyligen uppladdat")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.black)
            
            if viewModel.recentLogs.isEmpty {
                // Empty state
                VStack(spacing: 12) {
                    Image(systemName: "fork.knife.circle")
                        .font(.system(size: 40))
                        .foregroundColor(.gray.opacity(0.5))
                    
                    Text("Inga loggade måltider")
                        .font(.system(size: 15))
                        .foregroundColor(.gray)
                    
                    Text("Tryck på + för att logga din första måltid")
                        .font(.system(size: 13))
                        .foregroundColor(.gray.opacity(0.7))
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 30)
                .background(Color.white)
                .cornerRadius(18)
                .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 3)
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .scale(scale: 0.95)).combined(with: .offset(y: 10)),
                    removal: .opacity.combined(with: .scale(scale: 0.95))
                ))
            } else {
                ForEach(Array(viewModel.recentLogs.enumerated()), id: \.element.id) { index, log in
                    switch log {
                    case .food(let entry):
                        FoodLogCardView(entry: entry)
                            .onTapGesture {
                                selectedFoodLog = entry
                            }
                            .transition(.asymmetric(
                                insertion: .opacity.combined(with: .offset(y: 15)).animation(.spring(response: 0.4, dampingFraction: 0.8).delay(Double(index) * 0.05)),
                                removal: .opacity.combined(with: .scale(scale: 0.95))
                            ))
                    case .activity(let entry):
                        ActivityLogCardView(entry: entry)
                            .transition(.asymmetric(
                                insertion: .opacity.combined(with: .offset(y: 15)).animation(.spring(response: 0.4, dampingFraction: 0.8).delay(Double(index) * 0.05)),
                                removal: .opacity.combined(with: .scale(scale: 0.95))
                            ))
                    }
                }
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: viewModel.recentLogs.map { $0.id })
    }
    
    // MARK: - Animation
    private func animateContent() {
        // Show everything instantly for fast navigation
        showCalendar = true
        showCards = true
        showWater = true
        showRecent = true
    }
    
    // MARK: - Load Streak Count
    private func loadStreakCount() {
        streakCount = StreakManager.shared.getCurrentStreak().currentStreak
    }
    
    // MARK: - Pull to Refresh
    private func refreshAllData() async {
        // Reload user profile from server
        await authViewModel.loadUserProfile()
        
        // Reload all local data
        await MainActor.run {
            loadNutritionGoals()
            loadStreakCount()
            loadAITextUsage()
            viewModel.loadData()
            updateDisplayedValues(animated: true)
        }
    }
    
    // MARK: - Load Nutrition Goals (User-Specific)
    private func loadNutritionGoals() {
        guard let userId = authViewModel.currentUser?.id else { 
            print("⚠️ loadNutritionGoals: No user ID available")
            return 
        }
        
        print("🔍 Loading nutrition goals for user: \(userId)")
        
        // First try to load from UserDefaults (fast)
        if let goals = NutritionGoalsManager.shared.loadGoals(userId: userId), goals.calories > 0 {
            print("✅ Loaded goals from UserDefaults: \(goals.calories) kcal")
            caloriesGoal = goals.calories
            proteinGoal = goals.protein > 0 ? goals.protein : 150
            carbsGoal = goals.carbs > 0 ? goals.carbs : 250
            fatGoal = goals.fat > 0 ? goals.fat : 70
            viewModel.currentSummary.caloriesGoal = caloriesGoal
            
            // Sync goals to widgets
            WidgetSyncService.shared.syncNutritionGoals(
                caloriesGoal: caloriesGoal,
                proteinGoal: proteinGoal,
                carbsGoal: carbsGoal,
                fatGoal: fatGoal
            )
            return
        }
        
        // Fallback: Load from Supabase profile
        print("📡 UserDefaults empty, fetching from Supabase...")
        Task {
            do {
                let response = try await SupabaseConfig.supabase
                    .from("profiles")
                    .select("daily_calories_goal, daily_protein_goal, daily_carbs_goal, daily_fat_goal")
                    .eq("id", value: userId)
                    .single()
                    .execute()
                
                if let json = try? JSONSerialization.jsonObject(with: response.data) as? [String: Any] {
                    let fetchedCalories = json["daily_calories_goal"] as? Int ?? 0
                    let fetchedProtein = json["daily_protein_goal"] as? Int ?? 0
                    let fetchedCarbs = json["daily_carbs_goal"] as? Int ?? 0
                    let fetchedFat = json["daily_fat_goal"] as? Int ?? 0
                    
                    if fetchedCalories > 0 {
                        print("✅ Loaded goals from Supabase: \(fetchedCalories) kcal")
                        
                        // Save to UserDefaults for future use
                        NutritionGoalsManager.shared.saveGoals(
                            calories: fetchedCalories,
                            protein: fetchedProtein,
                            carbs: fetchedCarbs,
                            fat: fetchedFat,
                            userId: userId
                        )
                        
                        await MainActor.run {
                            caloriesGoal = fetchedCalories
                            proteinGoal = fetchedProtein > 0 ? fetchedProtein : 150
                            carbsGoal = fetchedCarbs > 0 ? fetchedCarbs : 250
                            fatGoal = fetchedFat > 0 ? fetchedFat : 70
                            viewModel.currentSummary.caloriesGoal = caloriesGoal
                            updateDisplayedValues(animated: true)
                            
                            // Sync goals to widgets
                            WidgetSyncService.shared.syncNutritionGoals(
                                caloriesGoal: caloriesGoal,
                                proteinGoal: proteinGoal,
                                carbsGoal: carbsGoal,
                                fatGoal: fatGoal
                            )
                        }
                    } else {
                        print("⚠️ No goals found in Supabase either")
                    }
                }
            } catch {
                print("❌ Failed to fetch goals from Supabase: \(error)")
            }
        }
    }
    
    // MARK: - Update Displayed Values with Animation
    private func updateDisplayedValues(animated: Bool) {
        let newCaloriesLeft = max(0, caloriesGoal - viewModel.currentSummary.caloriesConsumed)
        let newCaloriesConsumed = viewModel.currentSummary.caloriesConsumed
        let newCaloriesGoal = caloriesGoal
        
        // Calculate macro values based on mode
        let proteinEaten = viewModel.currentSummary.protein
        let carbsEaten = viewModel.currentSummary.carbs
        let fatEaten = viewModel.currentSummary.fat
        
        // If showEatenMode is true, show eaten values; otherwise show "kvar" (left)
        let newProtein = showEatenMode ? proteinEaten : max(0, proteinGoal - proteinEaten)
        let newCarbs = showEatenMode ? carbsEaten : max(0, carbsGoal - carbsEaten)
        let newFat = showEatenMode ? fatEaten : max(0, fatGoal - fatEaten)
        
        if animated {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                displayedCaloriesLeft = newCaloriesLeft
                displayedCaloriesConsumed = newCaloriesConsumed
                displayedCaloriesGoal = newCaloriesGoal
                displayedProtein = newProtein
                displayedCarbs = newCarbs
                displayedFat = newFat
            }
        } else {
            displayedCaloriesLeft = newCaloriesLeft
            displayedCaloriesConsumed = newCaloriesConsumed
            displayedCaloriesGoal = newCaloriesGoal
            displayedProtein = newProtein
            displayedCarbs = newCarbs
            displayedFat = newFat
        }
    }
    
    // MARK: - AI Analyzing Section
    private var aiAnalyzingSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Notify Banner (dismissible)
            if analyzingManager.isAnalyzing && analyzingManager.showNotifyBanner {
                HStack(spacing: 10) {
                    Image(systemName: "bell")
                        .font(.system(size: 16))
                        .foregroundColor(.gray.opacity(0.7))
                    
                    Text("Få notis när analysen är klar. Du behöver inte vänta.")
                        .font(.system(size: 13))
                        .foregroundColor(.black.opacity(0.75))
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                    
                    Spacer(minLength: 8)
                    
                    Button {
                        analyzingManager.requestNotificationPermission()
                        withAnimation(.easeOut(duration: 0.2)) {
                            analyzingManager.dismissNotifyBanner()
                        }
                    } label: {
                        Text(analyzingManager.notificationsEnabled ? "Notiser på ✓" : "Notifiera mig")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(analyzingManager.notificationsEnabled ? .green : .black)
                            .underline(!analyzingManager.notificationsEnabled)
                    }
                    .disabled(analyzingManager.notificationsEnabled)
                    
                    Button {
                        withAnimation(.easeOut(duration: 0.2)) {
                            analyzingManager.dismissNotifyBanner()
                        }
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.gray.opacity(0.6))
                    }
                }
                .padding(12)
                .background(Color.white)
                .cornerRadius(12)
                .shadow(color: Color.black.opacity(0.04), radius: 5, x: 0, y: 2)
            }
            
            // Analyzing Card or Result Card
            if analyzingManager.isAnalyzing {
                // Analyzing in progress card
                HStack(spacing: 14) {
                    // Image with progress overlay
                    ZStack {
                        if let image = analyzingManager.capturedImage {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 100, height: 100)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14)
                                        .fill(Color.black.opacity(0.15))
                                )
                        } else {
                            RoundedRectangle(cornerRadius: 14)
                                .fill(Color.gray.opacity(0.15))
                                .frame(width: 100, height: 100)
                        }
                        
                        // Progress circle overlay
                        Circle()
                            .stroke(Color.white.opacity(0.3), lineWidth: 3)
                            .frame(width: 46, height: 46)
                        
                        Circle()
                            .trim(from: 0, to: CGFloat(analyzingManager.progress / 100))
                            .stroke(Color.white, lineWidth: 3)
                            .frame(width: 46, height: 46)
                            .rotationEffect(.degrees(-90))
                            .animation(.easeOut(duration: 0.15), value: analyzingManager.progress)
                        
                        Text("\(Int(analyzingManager.progress))%")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.white)
                    }
                    
                    // Analysis status
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Analyserar mat...")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.black)
                        
                        // Progress bars - mimicking the design
                        HStack(spacing: 6) {
                            ForEach(0..<4, id: \.self) { index in
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(progressBarColor(for: index))
                                    .frame(height: 8)
                                    .animation(.easeOut(duration: 0.3), value: analyzingManager.progress)
                            }
                        }
                        
                        Text("Vi meddelar dig när det är klart!")
                            .font(.system(size: 12))
                            .foregroundColor(.gray.opacity(0.8))
                    }
                    
                    Spacer()
                }
                .padding(14)
                .background(Color.white)
                .cornerRadius(16)
                .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 3)
                
            } else if analyzingManager.noFoodDetected {
                // No food detected card
                HStack(alignment: .top, spacing: 14) {
                    // Image
                    if let image = analyzingManager.capturedImage {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 100, height: 100)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Ingen mat hittades")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.red)
                            
                            Spacer()
                            
                            Button {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    analyzingManager.dismissNoFoodError()
                                }
                            } label: {
                                Image(systemName: "xmark")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.gray.opacity(0.6))
                                    .frame(width: 28, height: 28)
                                    .background(Color.gray.opacity(0.1))
                                    .clipShape(Circle())
                            }
                        }
                        
                        Text("Prova en annan vinkel")
                            .font(.system(size: 13))
                            .foregroundColor(.gray)
                        
                        Button {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                analyzingManager.dismissNoFoodError()
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                showFoodScanner = true
                            }
                        } label: {
                            Text("Ta ny bild")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.black)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 10)
                                .background(Color.gray.opacity(0.12))
                                .cornerRadius(20)
                        }
                        .padding(.top, 4)
                    }
                }
                .padding(14)
                .background(Color.white)
                .cornerRadius(16)
                .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 3)
                
            } else if analyzingManager.limitReached {
                // Limit reached card - shows lock icon
                limitReachedCard
                
            } else if let result = analyzingManager.result {
                // Result card - shows analyzed food with add/cancel buttons
                HStack(alignment: .top, spacing: 14) {
                    // Image
                    if let image = result.image {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 100, height: 100)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        // Header with name, time and close button
                        HStack {
                            Text(result.foodName)
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.black)
                                .lineLimit(1)
                            
                            Spacer()
                            
                            Text(currentTimeString())
                                .font(.system(size: 12))
                                .foregroundColor(.gray)
                            
                            // Close/dismiss button
                            Button {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                    analyzingManager.clearResult()
                                }
                            } label: {
                                Image(systemName: "xmark")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(.black)
                                    .frame(width: 24, height: 24)
                                    .background(Color.gray.opacity(0.15))
                                    .clipShape(Circle())
                            }
                        }
                        
                        // Calories
                        HStack(spacing: 5) {
                            Image(systemName: "flame.fill")
                                .font(.system(size: 13))
                                .foregroundColor(.black)
                            Text("\(result.calories) kalorier")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundColor(.black)
                        }
                        
                        // Macros
                        HStack(spacing: 12) {
                            HStack(spacing: 3) {
                                Text("🥩")
                                    .font(.system(size: 11))
                                Text("\(result.protein)g")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.black)
                            }
                            HStack(spacing: 3) {
                                Text("🌾")
                                    .font(.system(size: 11))
                                    .grayscale(1)
                                Text("\(result.carbs)g")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.black)
                            }
                            HStack(spacing: 3) {
                                Text("🥑")
                                    .font(.system(size: 11))
                                    .grayscale(1)
                                Text("\(result.fat)g")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.black)
                            }
                        }
                        
                        // Ingredients count (if available)
                        if !result.ingredients.isEmpty {
                            Button {
                                showNutritionDetail = true
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: "list.bullet")
                                        .font(.system(size: 12))
                                    Text("\(result.ingredients.count) ingredienser")
                                        .font(.system(size: 12, weight: .medium))
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 10, weight: .semibold))
                                }
                                .foregroundColor(.gray)
                            }
                        }
                        
                        // Action buttons
                        HStack(spacing: 10) {
                            // Se detaljer button (opens ingredient view)
                            Button {
                                showNutritionDetail = true
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: "fork.knife")
                                        .font(.system(size: 13))
                                    Text("Se detaljer")
                                        .font(.system(size: 13, weight: .semibold))
                                }
                                .foregroundColor(.black)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(Color.gray.opacity(0.12))
                                .cornerRadius(10)
                            }
                            .disabled(analyzingManager.isSaving || analyzingManager.saveSuccess)
                            
                            Button {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    analyzingManager.addResultToLog()
                                }
                            } label: {
                                HStack(spacing: 6) {
                                    if analyzingManager.isSaving {
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                            .scaleEffect(0.8)
                                        Text("Sparar...")
                                            .font(.system(size: 13, weight: .semibold))
                                    } else if analyzingManager.saveSuccess {
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.system(size: 16))
                                        Text("Tillagd!")
                                            .font(.system(size: 13, weight: .semibold))
                                    } else {
                                        Text("Lägg till")
                                            .font(.system(size: 13, weight: .semibold))
                                    }
                                }
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(analyzingManager.saveSuccess ? Color.green : Color.black)
                                .cornerRadius(10)
                            }
                            .disabled(analyzingManager.isSaving || analyzingManager.saveSuccess)
                        }
                        .padding(.top, 2)
                    }
                }
                .padding(14)
                .background(Color.white)
                .cornerRadius(16)
                .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 3)
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: analyzingManager.isAnalyzing)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: analyzingManager.result != nil)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: analyzingManager.noFoodDetected)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: analyzingManager.limitReached)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: analyzingManager.isSaving)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: analyzingManager.saveSuccess)
    }
    
    // MARK: - Limit Reached Card
    private var limitReachedCard: some View {
        HStack(alignment: .center, spacing: 14) {
            // Image with lock overlay
            ZStack {
                if let image = analyzingManager.capturedImage {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 100, height: 100)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(Color.black.opacity(0.5))
                        )
                } else {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color.gray.opacity(0.15))
                        .frame(width: 100, height: 100)
                }
                
                // Lock icon
                Image(systemName: "lock.fill")
                    .font(.system(size: 32, weight: .medium))
                    .foregroundColor(.white)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Veckolimit nådd")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(.black)
                
                Text("Du har använt dina 3 gratis AI-skanningar denna vecka.")
                    .font(.system(size: 13))
                    .foregroundColor(.gray)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                
                HStack(spacing: 10) {
                    Button {
                        analyzingManager.showPaywallForLimit = true
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "crown.fill")
                                .font(.system(size: 12))
                            Text("Bli Pro")
                                .font(.system(size: 13, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            LinearGradient(
                                colors: [Color.purple, Color.blue],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(10)
                    }
                    
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            analyzingManager.dismissLimitReached()
                        }
                    } label: {
                        Text("Stäng")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(Color.gray.opacity(0.12))
                            .cornerRadius(10)
                    }
                }
                .padding(.top, 4)
            }
        }
        .padding(14)
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 3)
    }
    
    private func progressBarColor(for index: Int) -> Color {
        let progress = analyzingManager.progress
        let threshold = Double(index + 1) * 25
        
        if progress >= threshold {
            return Color.gray.opacity(0.7)
        } else if progress >= threshold - 25 {
            // Partial fill for current segment
            return Color.gray.opacity(0.35)
        } else {
            return Color.gray.opacity(0.12)
        }
    }
    
    private func currentTimeString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: Date())
    }
}

// MARK: - Calorie Tracker ViewModel
class CalorieTrackerViewModel: ObservableObject {
    @Published var selectedDate: Date = Date()
    @Published var currentSummary: DailySummary = .empty
    @Published var weeks: [WeekInfo] = []
    @Published var recentLogs: [LogEntry] = []
    @Published var currentWeekIndex: Int = 0
    
    private var userId: String?
    private let healthStore = HKHealthStore()
    private var cancellables = Set<AnyCancellable>()
    
    // Calorie status for ring color
    enum CalorieStatus {
        case noMeals       // Dotted gray ring - no meals logged
        case onTarget      // Green ring - at or below target, or up to 100 over
        case slightlyOver  // Yellow ring - 100-200 calories over target
        case overTarget    // Red ring - more than 200 calories over target
        case future        // Gray dotted - future date, no data yet
    }
    
    struct DayInfo: Identifiable {
        let id = UUID()
        let date: Date
        let dayLetter: String
        let dayNumber: Int
        var isSelected: Bool
        var isToday: Bool
        var hasActivity: Bool
        var calorieStatus: CalorieStatus = .noMeals
    }
    
    struct WeekInfo: Identifiable {
        let id = UUID()
        let days: [DayInfo]
        let weekNumber: Int
        var containsSelectedDate: Bool
        var containsToday: Bool
    }
    
    enum LogEntry: Identifiable {
        case food(FoodLogEntry)
        case activity(ActivityLogEntry)
        
        var id: String {
            switch self {
            case .food(let entry): return entry.id
            case .activity(let entry): return entry.id
            }
        }
        
        var loggedAt: Date {
            switch self {
            case .food(let entry): return entry.loggedAt
            case .activity(let entry): return entry.loggedAt
            }
        }
    }
    
    var caloriesFromSteps: Int {
        // Approximately 0.04 calories per step
        Int(Double(currentSummary.steps) * 0.04)
    }
    
    var caloriesFromWorkouts: Int {
        currentSummary.caloriesBurned - caloriesFromSteps
    }
    
    init() {
        generateWeekDates()
    }
    
    func setUserId(_ id: String?) {
        self.userId = id
    }
    
    func loadData() {
        withAnimation(.easeInOut(duration: 0.3)) {
            generateWeekDates()
            loadDailySummary(for: selectedDate)
            loadRecentLogs()
            fetchStepsFromHealthKit()
        }
    }
    
    func selectDate(_ date: Date) {
        withAnimation(.easeInOut(duration: 0.3)) {
            selectedDate = date
            generateWeekDates()
            loadDailySummary(for: date)
            loadRecentLogs()
            fetchStepsFromHealthKit()
        }
    }
    
    func addWater() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            currentSummary.waterMl += 240 // One glass
        }
        saveWaterLog(amount: 240)
    }
    
    func removeWater() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            currentSummary.waterMl = max(0, currentSummary.waterMl - 240)
        }
    }
    
    private func generateWeekDates() {
        var calendar = Calendar.current
        calendar.firstWeekday = 2 // Monday = 2
        let today = calendar.startOfDay(for: Date())
        
        // Find Monday of the week containing today
        let weekday = calendar.component(.weekday, from: today)
        let daysFromMonday = (weekday + 5) % 7 // Convert to Monday = 0
        guard let mondayOfCurrentWeek = calendar.date(byAdding: .day, value: -daysFromMonday, to: today) else { return }
        
        // Generate 8 weeks (4 before current week, current week, 3 after)
        var allWeeks: [WeekInfo] = []
        let dayLetters = ["Mån", "Tis", "Ons", "Tor", "Fre", "Lör", "Sön"]
        
        for weekOffset in -4...3 {
            guard let weekStart = calendar.date(byAdding: .weekOfYear, value: weekOffset, to: mondayOfCurrentWeek) else { continue }
            
            var days: [DayInfo] = []
            var containsSelected = false
            var containsToday = false
            
            for dayOffset in 0..<7 {
                guard let date = calendar.date(byAdding: .day, value: dayOffset, to: weekStart) else { continue }
                
                let dayNumber = calendar.component(.day, from: date)
                let isSelected = calendar.isDate(date, inSameDayAs: selectedDate)
                let isToday = calendar.isDate(date, inSameDayAs: today)
                
                if isSelected { containsSelected = true }
                if isToday { containsToday = true }
                
                // Determine initial calorie status
                let isFutureDate = date > today
                let initialStatus: CalorieStatus = isFutureDate ? .future : .noMeals
                
                days.append(DayInfo(
                    date: date,
                    dayLetter: dayLetters[dayOffset],
                    dayNumber: dayNumber,
                    isSelected: isSelected,
                    isToday: isToday,
                    hasActivity: false,
                    calorieStatus: initialStatus
                ))
            }
            
            let weekNumber = calendar.component(.weekOfYear, from: weekStart)
            allWeeks.append(WeekInfo(
                days: days,
                weekNumber: weekNumber,
                containsSelectedDate: containsSelected,
                containsToday: containsToday
            ))
        }
        
        self.weeks = allWeeks
        
        // Set current week index to the week containing selected date
        if let index = allWeeks.firstIndex(where: { $0.containsSelectedDate }) {
            self.currentWeekIndex = index
        }
        
        // Load calorie data for all visible days
        Task {
            await loadCalorieStatusForWeeks()
        }
    }
    
    /// Fetch calorie data for all days in the weeks and update their status
    private func loadCalorieStatusForWeeks() async {
        guard let userId = userId else { return }
        
        let calendar = Calendar.current
        let today = Date()
        
        // Get all dates from all weeks
        var allDates: [Date] = []
        for week in weeks {
            for day in week.days {
                // Only load past and today dates
                if day.date <= today {
                    allDates.append(day.date)
                }
            }
        }
        
        guard !allDates.isEmpty else { return }
        
        // Get date range
        guard let minDate = allDates.min(),
              let maxDate = allDates.max() else { return }
        
        let startOfMinDate = calendar.startOfDay(for: minDate)
        let endOfMaxDate = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: maxDate))!
        
        do {
            // Fetch all food logs for the date range
            let foodLogs: [FoodLogEntry] = try await SupabaseConfig.supabase
                .from("food_logs")
                .select()
                .eq("user_id", value: userId)
                .gte("logged_at", value: ISO8601DateFormatter().string(from: startOfMinDate))
                .lt("logged_at", value: ISO8601DateFormatter().string(from: endOfMaxDate))
                .execute()
                .value
            
            // Group food logs by date
            var caloriesByDate: [Date: Int] = [:]
            var hasMealsByDate: [Date: Bool] = [:]
            
            for log in foodLogs {
                let dayStart = calendar.startOfDay(for: log.loggedAt)
                caloriesByDate[dayStart, default: 0] += log.calories
                hasMealsByDate[dayStart] = true
            }
            
            // Get the user's calorie goal
            let calorieGoal = NutritionGoalsManager.shared.getCaloriesGoal(userId: userId)
            
            // Update weeks with calorie status
            await MainActor.run {
                var updatedWeeks = self.weeks
                
                for weekIndex in 0..<updatedWeeks.count {
                    var updatedDays = updatedWeeks[weekIndex].days
                    
                    for dayIndex in 0..<updatedDays.count {
                        let dayStart = calendar.startOfDay(for: updatedDays[dayIndex].date)
                        
                        // Skip future dates
                        if updatedDays[dayIndex].date > today {
                            updatedDays[dayIndex].calorieStatus = .future
                            continue
                        }
                        
                        // Check if any meals were logged
                        guard hasMealsByDate[dayStart] == true else {
                            updatedDays[dayIndex].calorieStatus = .noMeals
                            continue
                        }
                        
                        let totalCalories = caloriesByDate[dayStart] ?? 0
                        let caloriesOver = totalCalories - calorieGoal
                        
                        // Determine status based on how much over goal
                        if caloriesOver <= 100 {
                            updatedDays[dayIndex].calorieStatus = .onTarget  // Green
                        } else if caloriesOver <= 200 {
                            updatedDays[dayIndex].calorieStatus = .slightlyOver  // Yellow
                        } else {
                            updatedDays[dayIndex].calorieStatus = .overTarget  // Red
                        }
                    }
                    
                    updatedWeeks[weekIndex] = WeekInfo(
                        days: updatedDays,
                        weekNumber: updatedWeeks[weekIndex].weekNumber,
                        containsSelectedDate: updatedWeeks[weekIndex].containsSelectedDate,
                        containsToday: updatedWeeks[weekIndex].containsToday
                    )
                }
                
                self.weeks = updatedWeeks
            }
        } catch {
            print("❌ Error loading calorie status: \(error)")
        }
    }
    
    private func loadDailySummary(for date: Date) {
        guard let userId = userId else { return }
        
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        
        Task {
            do {
                // Fetch food logs for the day
                let foodLogs: [FoodLogEntry] = try await SupabaseConfig.supabase
                    .from("food_logs")
                    .select()
                    .eq("user_id", value: userId)
                    .gte("logged_at", value: ISO8601DateFormatter().string(from: startOfDay))
                    .lt("logged_at", value: ISO8601DateFormatter().string(from: endOfDay))
                    .execute()
                    .value
                
                // Fetch activity logs for the day
                let activityLogs: [ActivityLogEntry] = try await SupabaseConfig.supabase
                    .from("activity_logs")
                    .select()
                    .eq("user_id", value: userId)
                    .gte("logged_at", value: ISO8601DateFormatter().string(from: startOfDay))
                    .lt("logged_at", value: ISO8601DateFormatter().string(from: endOfDay))
                    .execute()
                    .value
                
                // Fetch water logs for the day
                let waterLogs: [WaterLogEntry] = try await SupabaseConfig.supabase
                    .from("water_logs")
                    .select()
                    .eq("user_id", value: userId)
                    .gte("logged_at", value: ISO8601DateFormatter().string(from: startOfDay))
                    .lt("logged_at", value: ISO8601DateFormatter().string(from: endOfDay))
                    .execute()
                    .value
                
                let totalWater = waterLogs.reduce(0) { $0 + $1.amount }
                let totalCaloriesConsumed = foodLogs.reduce(0) { $0 + $1.calories }
                let totalProtein = foodLogs.reduce(0) { $0 + $1.protein }
                let totalCarbs = foodLogs.reduce(0) { $0 + $1.carbs }
                let totalFat = foodLogs.reduce(0) { $0 + $1.fat }
                let totalCaloriesBurnedFromActivities = activityLogs.reduce(0) { $0 + $1.caloriesBurned }
                
                // Debug: Log food logs and their images
                print("📷 Daily summary - Food logs loaded: \(foodLogs.count)")
                for log in foodLogs {
                    print("   - \(log.name): imageUrl = \(log.imageUrl ?? "nil")")
                }
                
                // Preload food images for faster display
                let imageUrls = foodLogs.compactMap { $0.imageUrl }.filter { !$0.isEmpty }
                print("📷 Found \(imageUrls.count) images to preload")
                ImageCacheManager.shared.prefetch(urls: imageUrls)
                
                await MainActor.run {
                    self.currentSummary = DailySummary(
                        date: date,
                        steps: self.currentSummary.steps,
                        stepsGoal: 10000,
                        caloriesBurned: self.caloriesFromSteps + totalCaloriesBurnedFromActivities,
                        caloriesConsumed: totalCaloriesConsumed,
                        caloriesGoal: 2000,
                        waterMl: totalWater,
                        waterGoalMl: 2400,
                        protein: totalProtein,
                        carbs: totalCarbs,
                        fat: totalFat,
                        foodLogs: foodLogs,
                        activityLogs: activityLogs
                    )
                    
                    // Sync nutrition data to widgets (only for today)
                    if Calendar.current.isDateInToday(date) {
                        WidgetSyncService.shared.syncNutritionConsumed(
                            caloriesConsumed: totalCaloriesConsumed,
                            proteinConsumed: totalProtein,
                            carbsConsumed: totalCarbs,
                            fatConsumed: totalFat
                        )
                    }
                }
            } catch {
                print("❌ Error loading daily summary: \(error)")
            }
        }
    }
    
    private func loadRecentLogs() {
        guard let userId = userId else { return }
        
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: selectedDate)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        
        Task {
            do {
                let foodLogs: [FoodLogEntry] = try await SupabaseConfig.supabase
                    .from("food_logs")
                    .select()
                    .eq("user_id", value: userId)
                    .gte("logged_at", value: ISO8601DateFormatter().string(from: startOfDay))
                    .lt("logged_at", value: ISO8601DateFormatter().string(from: endOfDay))
                    .order("logged_at", ascending: false)
                    .limit(10)
                    .execute()
                    .value
                
                let activityLogs: [ActivityLogEntry] = try await SupabaseConfig.supabase
                    .from("activity_logs")
                    .select()
                    .eq("user_id", value: userId)
                    .gte("logged_at", value: ISO8601DateFormatter().string(from: startOfDay))
                    .lt("logged_at", value: ISO8601DateFormatter().string(from: endOfDay))
                    .order("logged_at", ascending: false)
                    .limit(10)
                    .execute()
                    .value
                
                var allLogs: [LogEntry] = []
                allLogs.append(contentsOf: foodLogs.map { .food($0) })
                allLogs.append(contentsOf: activityLogs.map { .activity($0) })
                allLogs.sort { $0.loggedAt > $1.loggedAt }
                
                // Preload food images for faster display
                let imageUrls = foodLogs.compactMap { $0.imageUrl }.filter { !$0.isEmpty }
                ImageCacheManager.shared.prefetch(urls: imageUrls)
                
                await MainActor.run {
                    self.recentLogs = Array(allLogs.prefix(5))
                }
            } catch {
                print("❌ Error loading recent logs: \(error)")
            }
        }
    }
    
    private func fetchStepsFromHealthKit() {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        
        let stepType = HKQuantityType(.stepCount)
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: selectedDate)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: endOfDay)
        let query = HKStatisticsQuery(quantityType: stepType, quantitySamplePredicate: predicate, options: .cumulativeSum) { [weak self] _, result, error in
            guard let self = self, error == nil, let sum = result?.sumQuantity() else { return }
            
            let steps = Int(sum.doubleValue(for: .count()))
            
            DispatchQueue.main.async {
                self.currentSummary.steps = steps
                self.currentSummary.caloriesBurned = self.caloriesFromSteps + self.currentSummary.activityLogs.reduce(0) { $0 + $1.caloriesBurned }
            }
        }
        
        healthStore.execute(query)
    }
    
    private func saveWaterLog(amount: Int) {
        guard let userId = userId else { return }
        
        Task {
            do {
                struct WaterLogInsert: Encodable {
                    let id: String
                    let user_id: String
                    let amount: Int
                    let logged_at: String
                }
                
                let log = WaterLogInsert(
                    id: UUID().uuidString,
                    user_id: userId,
                    amount: amount,
                    logged_at: ISO8601DateFormatter().string(from: Date())
                )
                
                try await SupabaseConfig.supabase
                    .from("water_logs")
                    .insert(log)
                    .execute()
            } catch {
                print("❌ Error saving water log: \(error)")
            }
        }
    }
}

// MARK: - Food Log Card View
struct FoodLogCardView: View {
    let entry: FoodLogEntry
    
    private var displayTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm" // Swedish 24h format
        return formatter.string(from: entry.loggedAt)
    }
    
    private var hasImage: Bool {
        if let url = entry.imageUrl, !url.isEmpty {
            return true
        }
        return false
    }
    
    var body: some View {
        HStack(alignment: .center, spacing: 0) {
            // Image on left side if available - using optimized cached image
            if let imageUrl = entry.imageUrl, !imageUrl.isEmpty {
                OptimizedAsyncImage(url: imageUrl, width: 110, height: 110, cornerRadius: 0)
                    .clipShape(
                        UnevenRoundedRectangle(
                            topLeadingRadius: 16,
                            bottomLeadingRadius: 16,
                            bottomTrailingRadius: 0,
                            topTrailingRadius: 0
                        )
                    )
            }
            
            // Content section
            VStack(alignment: .leading, spacing: 10) {
                // Header row with name and time
                HStack(alignment: .top) {
                    Text(entry.name)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.black)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    
                    Spacer()
                    
                    Text(displayTime)
                        .font(.system(size: 13))
                        .foregroundColor(.gray)
                }
                
                // Calories row
                HStack(spacing: 6) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.orange)
                    Text("\(entry.calories) Kalorier")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(.black)
                }
                
                // Macros row
                HStack(spacing: 14) {
                    macroItem(emoji: "🍗", value: "\(entry.protein)g")
                    macroItem(emoji: "🌾", value: "\(entry.carbs)g")
                    macroItem(emoji: "🥑", value: "\(entry.fat)g")
                }
            }
            .padding(.horizontal, hasImage ? 14 : 18)
            .padding(.vertical, 16)
        }
        .frame(minHeight: hasImage ? 110 : nil)
        .background(
            ZStack {
                // Base color
                Color.white
                
                // Subtle gradient overlay
                LinearGradient(
                    colors: [
                        Color(red: 0.98, green: 0.98, blue: 0.99),
                        Color(red: 0.96, green: 0.96, blue: 0.97)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
        )
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.06), radius: 6, x: 0, y: 2)
    }
    
    private var imagePlaceholder: some View {
        Rectangle()
            .fill(Color.gray.opacity(0.1))
            .frame(width: 110, height: 110)
            .overlay(
                Image(systemName: "photo")
                    .font(.system(size: 24))
                    .foregroundColor(.gray.opacity(0.4))
            )
    }
    
    private func macroItem(emoji: String, value: String) -> some View {
        HStack(spacing: 6) {
            Text(emoji)
                .font(.system(size: 14))
                .grayscale(1)
            Text(value)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.black)
        }
    }
    
    private var foodPlaceholder: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(Color.gray.opacity(0.15))
            .frame(width: 90, height: 90)
            .overlay(
                Image(systemName: "fork.knife")
                    .font(.system(size: 24))
                    .foregroundColor(.gray.opacity(0.5))
            )
    }
}

// MARK: - Food Log Detail View (matches FoodNutritionDetailView design)
struct FoodLogDetailView: View {
    @Environment(\.dismiss) var dismiss
    let entry: FoodLogEntry
    
    @State private var showDeleteConfirmation = false
    @State private var isDeleting = false
    @State private var showFixSheet = false
    @State private var fixDescription = ""
    @State private var isFixing = false
    @State private var fixProgress: Double = 0
    
    private var displayTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: entry.loggedAt)
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Header with name and time
                    headerSection
                    
                    // MARK: - Macro Summary Cards
                    macroSummarySection
                    
                    // MARK: - Ingredients Section
                    if let ingredients = entry.ingredients, !ingredients.isEmpty {
                        ingredientsSection(ingredients: ingredients)
                    } else {
                        noIngredientsSection
                    }
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
            }
            .safeAreaInset(edge: .bottom) {
                bottomButtons
            }
        }
        .sheet(isPresented: $showFixSheet) {
            FoodLogFixSheet(
                entry: entry,
                fixDescription: $fixDescription,
                isFixing: $isFixing,
                fixProgress: $fixProgress,
                onFix: { performFix() },
                onDismiss: { showFixSheet = false }
            )
        }
        .alert("Radera måltid?", isPresented: $showDeleteConfirmation) {
            Button("Avbryt", role: .cancel) { }
            Button("Radera", role: .destructive) {
                deleteEntry()
            }
        } message: {
            Text("Är du säker på att du vill radera \"\(entry.name)\"? Detta kan inte ångras.")
        }
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Time badge
            Text(displayTime)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.secondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color(.secondarySystemBackground))
                .cornerRadius(20)
            
            // Food name
            Text(entry.name)
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.primary)
            
            // Calories
            HStack(spacing: 4) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 14))
                    .foregroundColor(.orange)
                Text("\(entry.calories) kcal")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color(.systemBackground))
        .cornerRadius(16)
    }
    
    // MARK: - Macro Summary Section
    private var macroSummarySection: some View {
        HStack(spacing: 12) {
            FoodLogMacroCard(
                emoji: "🥩",
                label: "Protein",
                value: "\(entry.protein)g",
                color: Color(red: 0.95, green: 0.9, blue: 0.9)
            )
            
            FoodLogMacroCard(
                emoji: "🌾",
                label: "Kolhydrater",
                value: "\(entry.carbs)g",
                color: Color(red: 0.95, green: 0.93, blue: 0.88)
            )
            
            FoodLogMacroCard(
                emoji: "🥑",
                label: "Fett",
                value: "\(entry.fat)g",
                color: Color(red: 0.9, green: 0.93, blue: 0.98)
            )
        }
    }
    
    // MARK: - Ingredients Section
    private func ingredientsSection(ingredients: [FoodLogIngredient]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Ingredienser")
                .font(.system(size: 18, weight: .bold))
            
            VStack(spacing: 0) {
                ForEach(ingredients) { ingredient in
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
    
    // MARK: - No Ingredients Section
    private var noIngredientsSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "list.bullet.rectangle")
                .font(.system(size: 40))
                .foregroundColor(.gray.opacity(0.5))
            
            Text("Inga ingredienser sparade")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.secondary)
            
            Text("Använd \"Rätta till\" för att lägga till ingredienser med AI")
                .font(.system(size: 14))
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 30)
        .background(Color(.systemBackground))
        .cornerRadius(16)
    }
    
    // MARK: - Bottom Buttons
    private var bottomButtons: some View {
        HStack(spacing: 12) {
            // Delete button
            Button {
                showDeleteConfirmation = true
            } label: {
                HStack(spacing: 6) {
                    if isDeleting {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .red))
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "trash")
                            .font(.system(size: 14))
                    }
                    Text("Radera")
                        .font(.system(size: 16, weight: .medium))
                }
                .foregroundColor(.red)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color(.systemBackground))
                .cornerRadius(28)
                .overlay(
                    RoundedRectangle(cornerRadius: 28)
                        .stroke(Color.red.opacity(0.3), lineWidth: 1)
                )
            }
            .disabled(isDeleting)
            
            // Fix result button (AI)
            Button {
                showFixSheet = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 14))
                    Text("Rätta till")
                        .font(.system(size: 16, weight: .semibold))
                }
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
    }
    
    // MARK: - Delete Entry
    private func deleteEntry() {
        isDeleting = true
        
        Task {
            do {
                try await SupabaseConfig.supabase
                    .from("food_logs")
                    .delete()
                    .eq("id", value: entry.id)
                    .execute()
                
                print("✅ Deleted food log: \(entry.name)")
                
                await MainActor.run {
                    NotificationCenter.default.post(name: NSNotification.Name("RefreshFoodLogs"), object: nil)
                    isDeleting = false
                    dismiss()
                }
            } catch {
                print("❌ Error deleting food log: \(error)")
                await MainActor.run {
                    isDeleting = false
                }
            }
        }
    }
    
    // MARK: - Perform Fix with AI
    private func performFix() {
        guard !fixDescription.isEmpty else { return }
        
        isFixing = true
        fixProgress = 0
        
        Task {
            do {
                // Animate progress
                for i in 1...8 {
                    try await Task.sleep(nanoseconds: 200_000_000)
                    await MainActor.run {
                        fixProgress = Double(i * 10)
                    }
                }
                
                // Call GPT for re-analysis
                let fixedResult = try await reanalyzeWithGPT(
                    originalName: entry.name,
                    originalCalories: entry.calories,
                    originalProtein: entry.protein,
                    originalCarbs: entry.carbs,
                    originalFat: entry.fat,
                    correction: fixDescription
                )
                
                await MainActor.run {
                    fixProgress = 100
                }
                
                // Update database with corrected values
                struct FoodLogFixUpdate: Encodable {
                    let name: String
                    let calories: Int
                    let protein: Int
                    let carbs: Int
                    let fat: Int
                }
                
                let updateData = FoodLogFixUpdate(
                    name: fixedResult.name,
                    calories: fixedResult.calories,
                    protein: fixedResult.protein,
                    carbs: fixedResult.carbs,
                    fat: fixedResult.fat
                )
                
                try await SupabaseConfig.supabase
                    .from("food_logs")
                    .update(updateData)
                    .eq("id", value: entry.id)
                    .execute()
                
                print("✅ Updated food log with corrected values")
                
                await MainActor.run {
                    isFixing = false
                    showFixSheet = false
                    fixDescription = ""
                    
                    NotificationCenter.default.post(name: NSNotification.Name("RefreshFoodLogs"), object: nil)
                    dismiss()
                }
            } catch {
                print("❌ Fix error: \(error)")
                await MainActor.run {
                    isFixing = false
                }
            }
        }
    }
    
    private struct FixedFoodResult {
        let name: String
        let calories: Int
        let protein: Int
        let carbs: Int
        let fat: Int
    }
    
    private func reanalyzeWithGPT(
        originalName: String,
        originalCalories: Int,
        originalProtein: Int,
        originalCarbs: Int,
        originalFat: Int,
        correction: String
    ) async throws -> FixedFoodResult {
        guard let apiKey = EnvManager.shared.value(for: "OPENAI_API_KEY"), !apiKey.isEmpty else {
            throw NSError(domain: "APIKeyError", code: -1)
        }
        
        guard let url = URL(string: "https://api.openai.com/v1/chat/completions") else {
            throw NSError(domain: "URLError", code: -1)
        }
        
        let prompt = """
        Du har tidigare analyserat en maträtt och fått följande resultat:
        - Namn: \(originalName)
        - Kalorier: \(originalCalories) kcal
        - Protein: \(originalProtein)g
        - Kolhydrater: \(originalCarbs)g
        - Fett: \(originalFat)g
        
        Användaren har gett följande rättelse/korrigering:
        "\(correction)"
        
        Baserat på denna information, ge nya korrigerade näringsvärden.
        
        Svara ENDAST med JSON i detta format:
        {
            "name": "Korrigerat namn på svenska",
            "calories": 0,
            "protein": 0,
            "carbs": 0,
            "fat": 0
        }
        """
        
        let requestBody: [String: Any] = [
            "model": "gpt-4o-mini",
            "messages": [
                ["role": "user", "content": prompt]
            ],
            "max_tokens": 500
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
        
        let cleanedContent = content
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard let responseData = cleanedContent.data(using: .utf8),
              let resultJson = try JSONSerialization.jsonObject(with: responseData) as? [String: Any] else {
            throw NSError(domain: "JSONParseError", code: -1)
        }
        
        return FixedFoodResult(
            name: resultJson["name"] as? String ?? originalName,
            calories: resultJson["calories"] as? Int ?? originalCalories,
            protein: resultJson["protein"] as? Int ?? originalProtein,
            carbs: resultJson["carbs"] as? Int ?? originalCarbs,
            fat: resultJson["fat"] as? Int ?? originalFat
        )
    }
}

// MARK: - Food Log Macro Card
struct FoodLogMacroCard: View {
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

// MARK: - Food Log Fix Sheet
struct FoodLogFixSheet: View {
    let entry: FoodLogEntry
    @Binding var fixDescription: String
    @Binding var isFixing: Bool
    @Binding var fixProgress: Double
    let onFix: () -> Void
    let onDismiss: () -> Void
    
    @FocusState private var isTextFieldFocused: Bool
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                VStack(spacing: 8) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 40))
                        .foregroundColor(.black)
                    
                    Text("Rätta till")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.black)
                }
                .padding(.top, 8)
                
                TextField("Beskriv vad som ska rättas", text: $fixDescription, axis: .vertical)
                    .font(.system(size: 16))
                    .padding(16)
                    .background(Color.gray.opacity(0.08))
                    .cornerRadius(16)
                    .lineLimit(4...8)
                    .focused($isTextFieldFocused)
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Exempel:")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.black)
                    
                    Text("\"Det var bara 100g kyckling\" eller \"Lägg till ris och sås\"")
                        .font(.system(size: 15))
                        .foregroundColor(.gray)
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.gray.opacity(0.06))
                .cornerRadius(16)
                
                Spacer()
                
                if isFixing {
                    VStack(spacing: 12) {
                        ProgressView(value: fixProgress, total: 100)
                            .progressViewStyle(LinearProgressViewStyle(tint: .black))
                            .scaleEffect(y: 2)
                        
                        Text("Analyserar...")
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

// MARK: - Fix Result View (Sheet)
struct FixResultView: View {
    let entry: FoodLogEntry
    @Binding var fixDescription: String
    @Binding var isFixing: Bool
    @Binding var fixProgress: Double
    let onFix: () -> Void
    let onDismiss: () -> Void
    
    @FocusState private var isTextFieldFocused: Bool
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(UIColor.systemBackground)
                    .ignoresSafeArea()
                
                VStack(alignment: .leading, spacing: 24) {
                    // Header
                    HStack(spacing: 10) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 24, weight: .medium))
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
                        
                        Text("Nötfärsen var 5% fett och du missade att ta med såsen.")
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
                            
                            Text("Analyserar...")
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
                                .padding(.vertical, 18)
                                .background(fixDescription.isEmpty ? Color.gray : Color.black)
                                .cornerRadius(30)
                        }
                        .disabled(fixDescription.isEmpty)
                        .padding(.bottom, 20)
                    }
                }
                .padding(.horizontal, 20)
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        onDismiss()
                    } label: {
                        Image(systemName: "arrow.left")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.black)
                            .frame(width: 40, height: 40)
                            .background(Color.gray.opacity(0.12))
                            .clipShape(Circle())
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                isTextFieldFocused = true
            }
        }
    }
}

// MARK: - Activity Log Card View
struct ActivityLogCardView: View {
    let entry: ActivityLogEntry
    
    private var timeFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter
    }
    
    private var activityTypeSwedish: String {
        switch entry.activityType {
        case "weight_lifting", "gym": return "Styrketräning"
        case "running": return "Löpning"
        case "cycling": return "Cykling"
        case "swimming": return "Simning"
        case "yoga": return "Yoga"
        case "walking": return "Promenad"
        default: return "Träning"
        }
    }
    
    private var intensitySwedish: String {
        switch entry.intensity.lowercased() {
        case "low": return "Låg"
        case "medium": return "Medel"
        case "high": return "Hög"
        default: return entry.intensity
        }
    }
    
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.gray.opacity(0.08))
                    .frame(width: 56, height: 56)
                
                Image(systemName: "dumbbell.fill")
                    .font(.system(size: 22))
                    .foregroundColor(.black)
            }
            
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(activityTypeSwedish)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.black)
                    
                    Spacer()
                    
                    Text(timeFormatter.string(from: entry.loggedAt))
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(8)
                }
                
                HStack(spacing: 4) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 13))
                        .foregroundColor(.black)
                    Text("\(entry.caloriesBurned) kalorier")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.black)
                }
                
                HStack(spacing: 12) {
                    HStack(spacing: 4) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 11))
                            .foregroundColor(.gray)
                        Text("Intensitet: \(intensitySwedish)")
                            .font(.system(size: 12))
                            .foregroundColor(.gray)
                    }
                    
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.system(size: 11))
                            .foregroundColor(.gray)
                        Text("\(entry.duration) min")
                            .font(.system(size: 12))
                            .foregroundColor(.gray)
                    }
                }
            }
        }
        .padding(12)
        .background(Color.white)
        .cornerRadius(18)
        .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 3)
    }
}

// MARK: - Brand Logo Item (used by other views)
struct BrandLogoItem: Identifiable {
    let id = UUID()
    let name: String
    let imageName: String
    
    static let all: [BrandLogoItem] = [
        BrandLogoItem(name: "J.LINDEBERG", imageName: "37"),
        BrandLogoItem(name: "PLIKTGOLF", imageName: "15"),
        BrandLogoItem(name: "PEGMATE", imageName: "5"),
        BrandLogoItem(name: "LONEGOLF", imageName: "14"),
        BrandLogoItem(name: "WINWIZE", imageName: "17"),
        BrandLogoItem(name: "SCANDIGOLF", imageName: "18"),
        BrandLogoItem(name: "HAPPYALBA", imageName: "16"),
        BrandLogoItem(name: "RETROGOLF", imageName: "20"),
        BrandLogoItem(name: "PUMPLABS", imageName: "21"),
        BrandLogoItem(name: "ZEN ENERGY", imageName: "22"),
        BrandLogoItem(name: "PEAK", imageName: "33"),
        BrandLogoItem(name: "CAPSTONE", imageName: "34"),
        BrandLogoItem(name: "FUSE ENERGY", imageName: "46")
    ]
}

// MARK: - Popular Store Item
struct PopularStoreItem: Identifiable {
    let id = UUID()
    let name: String
    let imageName: String
    let reward: RewardCard?
    
    static let all: [PopularStoreItem] = [
        PopularStoreItem(name: "Pumplab", imageName: "21", reward: RewardCatalog.all.first { $0.brandName == "PUMPLABS" }),
        PopularStoreItem(name: "Lonegolf", imageName: "14", reward: RewardCatalog.all.first { $0.brandName == "LONEGOLF" }),
        PopularStoreItem(name: "Zen Energy", imageName: "22", reward: RewardCatalog.all.first { $0.brandName == "ZEN ENERGY" }),
        PopularStoreItem(name: "Fuse Energy", imageName: "46", reward: RewardCatalog.all.first { $0.brandName == "FUSE ENERGY" }),
        PopularStoreItem(name: "Pliktgolf", imageName: "15", reward: RewardCatalog.all.first { $0.brandName == "PLIKTGOLF" }),
        PopularStoreItem(name: "Clyro", imageName: "39", reward: RewardCatalog.all.first { $0.brandName == "CLYRO" }),
        PopularStoreItem(name: "Happyalba", imageName: "16", reward: RewardCatalog.all.first { $0.brandName == "HAPPYALBA" }),
        PopularStoreItem(name: "Winwize", imageName: "17", reward: RewardCatalog.all.first { $0.brandName == "WINWIZE" }),
        PopularStoreItem(name: "Capstone", imageName: "34", reward: RewardCatalog.all.first { $0.brandName == "CAPSTONE" })
    ]
}

// MARK: - Welcome Task Card
struct WelcomeTaskCard: View {
    let icon: String
    let title: String
    let subtitle: String
    let isCompleted: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .stroke(isCompleted ? Color.black : Color(.systemGray3), lineWidth: 1.5)
                        .frame(width: 22, height: 22)
                    
                    if isCompleted {
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.black)
                    }
                }
                
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.systemGray5))
                        .frame(width: 48, height: 48)
                    
                    Image(systemName: icon)
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(.black)
                }
                
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.black)
                    
                    Text(subtitle)
                        .font(.system(size: 13))
                        .foregroundColor(.gray)
                        .lineLimit(2)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Color(.systemGray3))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 14)
            .background(Color(.systemGray6))
            .cornerRadius(16)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Featured User Model
struct FeaturedUser: Identifiable {
    let id: String
    let username: String
    let avatarUrl: String?
}

// MARK: - Featured User Card
struct FeaturedUserCard: View {
    let user: FeaturedUser
    let isFollowing: Bool
    let onFollowToggle: () -> Void
    @State private var isProcessing = false
    
    var body: some View {
        VStack(spacing: 12) {
            NavigationLink(destination: UserProfileView(userId: user.id)) {
                ProfileAvatarView(path: user.avatarUrl ?? "", size: 60)
            }
            
            Text(user.username)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.primary)
                .lineLimit(1)
            
            Button(action: {
                guard !isProcessing else { return }
                isProcessing = true
                onFollowToggle()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    isProcessing = false
                }
            }) {
                Text(isFollowing ? "Följer" : "Följ")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(isFollowing ? .gray : .white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
                    .background(isFollowing ? Color(.systemGray5) : Color.black)
                    .cornerRadius(8)
            }
            .disabled(isProcessing)
        }
        .frame(width: 100)
        .padding(12)
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.08), radius: 4, x: 0, y: 2)
    }
}

// MARK: - Recommended Friend Card
struct RecommendedFriendCard: View {
    let user: UserSearchResult
    let isFollowing: Bool
    let onFollowToggle: () -> Void
    @State private var isProcessing = false
    
    var body: some View {
        VStack(spacing: 12) {
            NavigationLink(destination: UserProfileView(userId: user.id)) {
                ProfileImage(url: user.avatarUrl, size: 60)
            }
            
            Text(user.name)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.primary)
                .lineLimit(1)
            
            Button(action: {
                guard !isProcessing else { return }
                isProcessing = true
                onFollowToggle()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    isProcessing = false
                }
            }) {
                Text(isFollowing ? "Följer" : "Följ")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(isFollowing ? .gray : .white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
                    .background(isFollowing ? Color(.systemGray5) : Color.black)
                    .cornerRadius(8)
            }
            .disabled(isProcessing)
        }
        .frame(width: 100)
        .padding(12)
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.08), radius: 4, x: 0, y: 2)
    }
}

// MARK: - Weekly Stat Row
struct WeeklyStatRow: View {
    let day: String
    let distance: Double
    let isToday: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            Text(day)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(isToday ? .black : .gray)
                .frame(width: 30, alignment: .leading)
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(.systemGray6))
                        .frame(height: 8)
                    
                    RoundedRectangle(cornerRadius: 4)
                        .fill(isToday ? .black : Color.gray)
                        .frame(width: min(geometry.size.width * (distance / 10.0), geometry.size.width), height: 8)
                }
            }
            .frame(height: 8)
            
            Text(String(format: "%.1f km", distance))
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(isToday ? .black : .gray)
                .frame(width: 55, alignment: .trailing)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Add Meal Sheet
struct AddMealSheet: View {
    @Environment(\.dismiss) var dismiss
    @State private var showAddMealView = false
    
    var body: some View {
        ZStack {
            // Semi-transparent background
            Color.black.opacity(0.001)
                .ignoresSafeArea()
                .onTapGesture {
                    dismiss()
                }
            
            VStack {
                Spacer()
                
                // 4 square options grid
                VStack(spacing: 12) {
                    HStack(spacing: 12) {
                        // Starta pass
                        AddOptionSquare(
                            icon: "dumbbell.fill",
                            title: "Starta pass"
                        ) {
                            dismiss()
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                NotificationCenter.default.post(
                                    name: NSNotification.Name("SwitchActivity"),
                                    object: nil,
                                    userInfo: ["activity": "running"]
                                )
                            }
                        }
                        
                        // Sparade måltider
                        AddOptionSquare(
                            icon: "bookmark.fill",
                            title: "Sparade måltider"
                        ) {
                            // Saved foods action
                        }
                    }
                    
                    HStack(spacing: 12) {
                        // Måltid (Sök mat)
                        AddOptionSquare(
                            icon: "fork.knife",
                            title: "Måltid"
                        ) {
                            showAddMealView = true
                        }
                        
                        // Scanna streckkod
                        AddOptionSquare(
                            icon: "barcode.viewfinder",
                            title: "Scanna streckkod"
                        ) {
                            // Scan food action
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 100)
            }
        }
        .background(Color.clear)
        .presentationBackground(.clear)
        .presentationDetents([.large])
        .presentationDragIndicator(.hidden)
        .fullScreenCover(isPresented: $showAddMealView) {
            AddMealView()
        }
    }
}

// MARK: - Add Option Square
struct AddOptionSquare: View {
    let icon: String
    let title: String
    let action: () -> Void
    
    var body: some View {
        Button(action: {
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.impactOccurred()
            action()
        }) {
            VStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 26, weight: .medium))
                    .foregroundColor(.black)
                
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.black)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 110)
            .background(Color.white)
            .cornerRadius(16)
            .shadow(color: Color.black.opacity(0.08), radius: 12, x: 0, y: 4)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Nutri-Score Badge for Food Log
struct FoodLogNutriScoreBadge: View {
    let grade: String
    
    private let grades = ["A", "B", "C", "D", "E"]
    
    private func colorFor(_ g: String) -> Color {
        switch g {
        case "A": return Color(red: 0.0, green: 0.52, blue: 0.26) // Dark green
        case "B": return Color(red: 0.52, green: 0.73, blue: 0.18) // Light green
        case "C": return Color(red: 0.96, green: 0.78, blue: 0.15) // Yellow
        case "D": return Color(red: 0.93, green: 0.55, blue: 0.14) // Orange
        case "E": return Color(red: 0.88, green: 0.27, blue: 0.14) // Red
        default: return Color.gray
        }
    }
    
    private var gradeDescription: String {
        switch grade.uppercased() {
        case "A": return "Utmärkt näringsvärde"
        case "B": return "Bra näringsvärde"
        case "C": return "Genomsnittligt näringsvärde"
        case "D": return "Lågt näringsvärde"
        case "E": return "Dåligt näringsvärde"
        default: return "Näringsvärde"
        }
    }
    
    var body: some View {
        HStack(spacing: 16) {
            // Official Nutri-Score badge design
            VStack(spacing: 0) {
                // NUTRI-SCORE header
                Text("NUTRI-SCORE")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(Color(red: 0.4, green: 0.4, blue: 0.4))
                    .padding(.bottom, 4)
                
                // Grade bar
                HStack(spacing: 0) {
                    ForEach(grades, id: \.self) { g in
                        let isSelected = g == grade.uppercased()
                        
                        ZStack {
                            // Background color bar
                            Rectangle()
                                .fill(colorFor(g))
                            
                            // Letter
                            Text(g)
                                .font(.system(size: isSelected ? 24 : 14, weight: .black))
                                .foregroundColor(isSelected ? colorFor(g) : .white.opacity(0.7))
                                .background(
                                    Group {
                                        if isSelected {
                                            Circle()
                                                .fill(Color.white)
                                                .frame(width: 38, height: 38)
                                        }
                                    }
                                )
                        }
                        .frame(width: isSelected ? 48 : 32, height: 48)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                )
            }
            
            // Description
            VStack(alignment: .leading, spacing: 4) {
                Text("Nutri-Score")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.black)
                
                Text(gradeDescription)
                    .font(.system(size: 13))
                    .foregroundColor(.gray)
            }
            
            Spacer()
        }
        .padding(16)
        .background(Color.white)
        .cornerRadius(16)
    }
}

// MARK: - Scroll Offset Preference Key
struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

// MARK: - Pro Banner View
private struct ProBannerView: View {
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            ZStack {
                // Background gradient (Black to Silver)
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color(red: 0.1, green: 0.1, blue: 0.1),
                        Color(red: 0.3, green: 0.3, blue: 0.3),
                        Color(red: 0.5, green: 0.5, blue: 0.5),
                        Color(red: 0.3, green: 0.3, blue: 0.3),
                        Color(red: 0.1, green: 0.1, blue: 0.1)
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                
                // Content
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Skaffa Up&Down Pro och lås upp alla förmåner")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                        
                        // CTA Button (White)
                        HStack(spacing: 4) {
                            Text("Prenumerera nu")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.black)
                            
                            Image(systemName: "arrow.right")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.black)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 6)
                        .background(Color.white)
                        .cornerRadius(20)
                    }
                    
                    Spacer()
                    
                    // App Logo
                    Image("23")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 50, height: 50)
                        .cornerRadius(10)
                        .shadow(color: .black.opacity(0.3), radius: 5, x: 0, y: 2)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .frame(height: 70)
            .overlay(
                RoundedRectangle(cornerRadius: 0)
                    .stroke(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color.white.opacity(0.2),
                                Color.white.opacity(0.1)
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.5
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    HomeView()
        .environmentObject(AuthViewModel())
}

// MARK: - Shimmer Effect (ChatGPT-style)
struct ShimmerEffect: ViewModifier {
    @State private var phase: CGFloat = 0
    
    func body(content: Content) -> some View {
        content
            .overlay(
                GeometryReader { geometry in
                    LinearGradient(
                        colors: [
                            .clear,
                            .white.opacity(0.6),
                            .clear
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: geometry.size.width * 0.6)
                    .offset(x: -geometry.size.width * 0.3 + phase * geometry.size.width * 1.6)
                    .blendMode(.sourceAtop)
                }
            )
            .onAppear {
                withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                    phase = 1
                }
            }
    }
}
