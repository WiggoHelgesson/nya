import SwiftUI
import Combine
import UIKit
import Supabase
import HealthKit

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
    
    enum CodingKeys: String, CodingKey {
        case id, name, calories, protein, carbs, fat
        case userId = "user_id"
        case mealType = "meal_type"
        case loggedAt = "logged_at"
        case imageUrl = "image_url"
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
    @State private var showFoodLogDetail = false
    
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [
                    Color(red: 0.92, green: 0.92, blue: 0.93),
                    Color(red: 0.96, green: 0.96, blue: 0.97),
                    Color.white
                ],
                startPoint: .top,
                endPoint: .center
            )
            .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 16) {
                    // MARK: - Header
                    headerView
                        .padding(.horizontal, 20)
                        .padding(.top, 10)
                    
                    // MARK: - Week Calendar
                    weekCalendarView
                        .opacity(showCalendar ? 1 : 0)
                        .offset(y: showCalendar ? 0 : 10)
                    
                    // MARK: - Calorie Card
                    calorieTrackerCard
                        .padding(.horizontal, 16)
                        .opacity(showCards ? 1 : 0)
                        .offset(y: showCards ? 0 : 15)
                        .animation(.easeInOut(duration: 0.3), value: viewModel.selectedDate)
                    
                    // MARK: - Macro Cards
                    macroCardsRow
                        .padding(.horizontal, 16)
                        .opacity(showCards ? 1 : 0)
                        .offset(y: showCards ? 0 : 15)
                        .animation(.easeInOut(duration: 0.3), value: viewModel.selectedDate)
                    
                    // MARK: - Page Indicator Dots
                    HStack(spacing: 6) {
                        Circle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: 8, height: 8)
                        Circle()
                            .fill(Color.black)
                            .frame(width: 8, height: 8)
                    }
                    .opacity(showWater ? 1 : 0)
                    
                    // MARK: - AI Analyzing Section
                    if analyzingManager.isAnalyzing || analyzingManager.result != nil || analyzingManager.noFoodDetected {
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
                        .opacity(showRecent ? 1 : 0)
                        .offset(y: showRecent ? 0 : 15)
                        .animation(.easeInOut(duration: 0.3), value: viewModel.selectedDate)
                    
                    Spacer(minLength: 120)
                }
                .padding(.top, 8)
            }
        }
        .onAppear {
            animateContent()
            viewModel.setUserId(authViewModel.currentUser?.id)
            viewModel.loadData()
        }
        .onChange(of: authViewModel.currentUser?.id) { _, newId in
            viewModel.setUserId(newId)
            viewModel.loadData()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("RefreshFoodLogs"))) { _ in
            viewModel.loadData()
        }
        .fullScreenCover(isPresented: $showFoodScanner) {
            FoodScannerView(initialMode: .ai)
        }
        .fullScreenCover(isPresented: $showFoodLogDetail) {
            if let foodLog = selectedFoodLog {
                FoodLogDetailView(entry: foodLog)
            }
        }
    }
    
    // MARK: - Header
    private var headerView: some View {
        HStack {
            Image("23")
                .resizable()
                .scaledToFit()
                .frame(width: 44, height: 44)
                .cornerRadius(10)
            
            Spacer()
        }
    }
    
    // MARK: - Week Calendar View
    private var weekCalendarView: some View {
        TabView(selection: $viewModel.currentWeekIndex) {
            ForEach(Array(viewModel.weeks.enumerated()), id: \.element.id) { index, week in
                weekView(week: week)
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
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(dayInfo.isSelected ? .black : Color.gray.opacity(0.6))
                        
                        ZStack {
                            if dayInfo.isSelected {
                                // Selected state: solid circle with number
                                Circle()
                                    .stroke(Color.black, lineWidth: 2.5)
                                    .frame(width: 40, height: 40)
                            } else if dayInfo.isToday {
                                // Today but not selected: subtle gray ring
                                Circle()
                                    .stroke(Color.gray.opacity(0.25), lineWidth: 1.5)
                                    .frame(width: 40, height: 40)
                            } else {
                                // Default: dotted border
                                Circle()
                                    .stroke(style: StrokeStyle(lineWidth: 1.5, lineCap: .round, dash: [2, 4]))
                                    .foregroundColor(Color.gray.opacity(0.25))
                                    .frame(width: 40, height: 40)
                            }
                            
                            Text("\(dayInfo.dayNumber)")
                                .font(.system(size: 15, weight: dayInfo.isSelected ? .bold : .medium))
                                .foregroundColor(dayInfo.isSelected ? .black : Color.black.opacity(0.7))
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
    
    // MARK: - Calorie Tracker Card
    private var calorieTrackerCard: some View {
        HStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 4) {
                Text("\(max(0, viewModel.currentSummary.caloriesGoal - viewModel.currentSummary.caloriesConsumed))")
                    .font(.system(size: 48, weight: .bold))
                    .foregroundColor(.black)
                
                Text("Calories left")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.12), lineWidth: 10)
                    .frame(width: 100, height: 100)
                
                Circle()
                    .trim(from: 0, to: CGFloat(min(Double(viewModel.currentSummary.caloriesConsumed) / Double(viewModel.currentSummary.caloriesGoal), 1.0)))
                    .stroke(Color.black, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                    .frame(width: 100, height: 100)
                    .rotationEffect(.degrees(-90))
                
                Image(systemName: "flame.fill")
                    .font(.system(size: 24))
                    .foregroundColor(.black)
            }
        }
        .padding(24)
        .background(Color.white)
        .cornerRadius(24)
        .shadow(color: Color.black.opacity(0.06), radius: 10, x: 0, y: 4)
    }
    
    // MARK: - Macro Cards Row
    private var macroCardsRow: some View {
        HStack(spacing: 12) {
            macroVerticalCard(
                amount: "\(viewModel.currentSummary.protein)g",
                label: "Protein over",
                emoji: "🥩",
                color: Color(red: 0.95, green: 0.45, blue: 0.45)
            )
            
            macroVerticalCard(
                amount: "\(viewModel.currentSummary.carbs)g",
                label: "Carbs over",
                emoji: "🌾",
                color: Color(red: 0.9, green: 0.65, blue: 0.45)
            )
            
            macroVerticalCard(
                amount: "\(viewModel.currentSummary.fat)g",
                label: "Fat over",
                emoji: "🫒",
                color: Color(red: 0.45, green: 0.6, blue: 0.85)
            )
        }
    }
    
    private func macroVerticalCard(amount: String, label: String, emoji: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(amount)
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(.black)
            
            Text(label)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.gray)
            
            Spacer()
            
            HStack {
                Spacer()
                ZStack {
                    Circle()
                        .stroke(color.opacity(0.3), lineWidth: 4)
                        .frame(width: 55, height: 55)
                    
                    Text(emoji)
                        .font(.system(size: 22))
                }
                Spacer()
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .frame(height: 160)
        .background(Color.white)
        .cornerRadius(20)
        .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 2)
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
            } else {
                ForEach(viewModel.recentLogs) { log in
                    switch log {
                    case .food(let entry):
                        FoodLogCardView(entry: entry)
                            .onTapGesture {
                                selectedFoodLog = entry
                                showFoodLogDetail = true
                            }
                    case .activity(let entry):
                        ActivityLogCardView(entry: entry)
                    }
                }
            }
        }
    }
    
    // MARK: - Animation
    private func animateContent() {
        // Reset states if needed
        showCalendar = false
        showCards = false
        showWater = false
        showRecent = false
        
        let duration = 0.45
        let delay = 0.08
        
        withAnimation(.easeOut(duration: duration)) {
            showCalendar = true
        }
        withAnimation(.easeOut(duration: duration).delay(delay * 1)) {
            showCards = true
        }
        withAnimation(.easeOut(duration: duration).delay(delay * 2)) {
            showWater = true
        }
        withAnimation(.easeOut(duration: duration).delay(delay * 3)) {
            showRecent = true
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
                        // Header with name and time
                        HStack {
                            Text(result.foodName)
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.black)
                                .lineLimit(1)
                            
                            Spacer()
                            
                            Text(currentTimeString())
                                .font(.system(size: 12))
                                .foregroundColor(.gray)
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
                                Text("\(result.carbs)g")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.black)
                            }
                            HStack(spacing: 3) {
                                Text("🫒")
                                    .font(.system(size: 11))
                                Text("\(result.fat)g")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.black)
                            }
                        }
                        
                        // Action buttons
                        HStack(spacing: 10) {
                            Button {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    analyzingManager.addResultToLog()
                                }
                            } label: {
                                Text("Lägg till")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .background(Color.black)
                                    .cornerRadius(10)
                            }
                            
                            Button {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    analyzingManager.dismissResult()
                                }
                            } label: {
                                Text("Avbryt")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(.black)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .background(Color.gray.opacity(0.12))
                                    .cornerRadius(10)
                            }
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
    
    struct DayInfo: Identifiable {
        let id = UUID()
        let date: Date
        let dayLetter: String
        let dayNumber: Int
        var isSelected: Bool
        var isToday: Bool
        var hasActivity: Bool
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
                
                days.append(DayInfo(
                    date: date,
                    dayLetter: dayLetters[dayOffset],
                    dayNumber: dayNumber,
                    isSelected: isSelected,
                    isToday: isToday,
                    hasActivity: false
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
    
    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            // Image if available
            if let imageUrl = entry.imageUrl, let url = URL(string: imageUrl) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(width: 90, height: 90)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    case .failure(_):
                        foodPlaceholder
                    case .empty:
                        ProgressView()
                            .frame(width: 90, height: 90)
                    @unknown default:
                        foodPlaceholder
                    }
                }
            }
            
            VStack(alignment: .leading, spacing: 8) {
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
                        .foregroundColor(.gray.opacity(0.8))
                }
                
                // Calories row
                HStack(spacing: 5) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 13))
                        .foregroundColor(.black)
                    Text("\(entry.calories) kalorier")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.black)
                }
                
                // Macros row with colored indicators
                HStack(spacing: 12) {
                    macroItem(icon: "🥩", value: "\(entry.protein)g", color: .red)
                    macroItem(icon: "🌾", value: "\(entry.carbs)g", color: .orange)
                    macroItem(icon: "🫒", value: "\(entry.fat)g", color: .blue)
                }
            }
        }
        .padding(14)
        .background(
            LinearGradient(
                colors: [Color.white, Color(red: 0.98, green: 0.98, blue: 0.99)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 2)
    }
    
    private func macroItem(icon: String, value: String, color: Color) -> some View {
        HStack(spacing: 4) {
            Text(icon)
                .font(.system(size: 12))
            Text(value)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.black.opacity(0.7))
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

// MARK: - Food Log Detail View
struct FoodLogDetailView: View {
    @Environment(\.dismiss) var dismiss
    let entry: FoodLogEntry
    @State private var quantity: Int = 1
    @State private var isSaved = false
    
    private var displayTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: entry.loggedAt)
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background gradient matching HomeView
                LinearGradient(
                    colors: [
                        Color(red: 0.94, green: 0.94, blue: 0.95),
                        Color(red: 0.97, green: 0.97, blue: 0.98),
                        Color.white
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Image section (if available)
                    if let imageUrl = entry.imageUrl, let url = URL(string: imageUrl) {
                        ZStack(alignment: .bottom) {
                            AsyncImage(url: url) { phase in
                                switch phase {
                                case .success(let image):
                                    image
                                        .resizable()
                                        .scaledToFill()
                                        .frame(height: 320)
                                        .clipped()
                                case .failure(_), .empty:
                                    Color.gray.opacity(0.1)
                                        .frame(height: 120)
                                @unknown default:
                                    Color.gray.opacity(0.1)
                                        .frame(height: 120)
                                }
                            }
                            
                            // Info card overlay
                            infoCard
                                .offset(y: 80)
                        }
                        .padding(.bottom, 80)
                    } else {
                        // No image - just show info card
                        infoCard
                            .padding(.top, 20)
                    }
                    
                    ScrollView {
                        VStack(spacing: 16) {
                            // Ingredients section
                            ingredientsSection
                                .padding(.horizontal, 16)
                        }
                        .padding(.top, entry.imageUrl != nil ? 16 : 16)
                        .padding(.bottom, 100)
                    }
                    
                    // Bottom buttons
                    bottomButtons
                }
            }
            .navigationTitle("Näringsvärden")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "arrow.left")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(entry.imageUrl != nil ? .white : .black)
                            .frame(width: 40, height: 40)
                            .background(entry.imageUrl != nil ? Color.black.opacity(0.4) : Color.gray.opacity(0.15))
                            .clipShape(Circle())
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 8) {
                        Button {
                            // Share
                        } label: {
                            Image(systemName: "square.and.arrow.up")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(entry.imageUrl != nil ? .white : .black)
                                .frame(width: 40, height: 40)
                                .background(entry.imageUrl != nil ? Color.black.opacity(0.4) : Color.gray.opacity(0.15))
                                .clipShape(Circle())
                        }
                        
                        Button {
                            // More options
                        } label: {
                            Image(systemName: "ellipsis")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(entry.imageUrl != nil ? .white : .black)
                                .frame(width: 40, height: 40)
                                .background(entry.imageUrl != nil ? Color.black.opacity(0.4) : Color.gray.opacity(0.15))
                                .clipShape(Circle())
                        }
                    }
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
        }
    }
    
    // MARK: - Info Card
    private var infoCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header row
            HStack {
                Button {
                    isSaved.toggle()
                } label: {
                    Image(systemName: isSaved ? "bookmark.fill" : "bookmark")
                        .font(.system(size: 20))
                        .foregroundColor(.black)
                }
                
                Text(displayTime)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.black.opacity(0.6))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(20)
                
                Spacer()
            }
            
            // Title and quantity
            HStack(alignment: .top) {
                Text(entry.name)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.black)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                
                Spacer()
                
                // Quantity selector
                HStack(spacing: 8) {
                    Text("\(quantity)")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.black)
                    
                    Image(systemName: "pencil")
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color.white)
                .cornerRadius(25)
                .overlay(
                    RoundedRectangle(cornerRadius: 25)
                        .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                )
            }
            
            // Nutrition info
            VStack(spacing: 12) {
                // Calories card
                HStack(spacing: 12) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 22))
                        .foregroundColor(.black)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Kalorier")
                            .font(.system(size: 13))
                            .foregroundColor(.gray)
                        Text("\(entry.calories * quantity)")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(.black)
                    }
                    
                    Spacer()
                }
                .padding(14)
                .background(Color.white)
                .cornerRadius(14)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.gray.opacity(0.12), lineWidth: 1)
                )
                
                // Macros row
                HStack(spacing: 10) {
                    macroCard(emoji: "🥩", label: "Protein", value: "\(entry.protein * quantity)g")
                    macroCard(emoji: "🌾", label: "Kolhydrater", value: "\(entry.carbs * quantity)g")
                    macroCard(emoji: "🫒", label: "Fett", value: "\(entry.fat * quantity)g")
                }
            }
            
            // Page indicator
            HStack {
                Spacer()
                HStack(spacing: 6) {
                    Circle()
                        .fill(Color.black)
                        .frame(width: 8, height: 8)
                    Circle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 8, height: 8)
                }
                Spacer()
            }
            .padding(.top, 8)
        }
        .padding(20)
        .background(Color.white)
        .cornerRadius(24)
        .shadow(color: Color.black.opacity(0.08), radius: 12, x: 0, y: 4)
        .padding(.horizontal, 16)
    }
    
    private func macroCard(emoji: String, label: String, value: String) -> some View {
        VStack(spacing: 6) {
            Text(emoji)
                .font(.system(size: 22))
            
            Text(label)
                .font(.system(size: 11))
                .foregroundColor(.gray)
            
            Text(value)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.black)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color.white)
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.gray.opacity(0.12), lineWidth: 1)
        )
    }
    
    // MARK: - Ingredients Section
    private var ingredientsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Ingredienser")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.black)
                
                Spacer()
                
                Button {
                    // Add ingredients
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                            .font(.system(size: 14, weight: .medium))
                        Text("Lägg till")
                            .font(.system(size: 14, weight: .medium))
                    }
                    .foregroundColor(.gray)
                }
            }
            
            // Hidden ingredients notice
            HStack(spacing: 8) {
                Image(systemName: "eye.slash")
                    .font(.system(size: 16))
                    .foregroundColor(.gray)
                
                Text("Ingredienser dolda")
                    .font(.system(size: 14))
                    .foregroundColor(.gray)
                
                Button {
                    // Learn why
                } label: {
                    Text("Läs mer")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.black)
                        .underline()
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
        }
    }
    
    // MARK: - Bottom Buttons
    private var bottomButtons: some View {
        HStack(spacing: 12) {
            Button {
                // Fix issue / Edit
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 14))
                    Text("Fixa problem")
                        .font(.system(size: 16, weight: .semibold))
                }
                .foregroundColor(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color.white)
                .cornerRadius(30)
                .overlay(
                    RoundedRectangle(cornerRadius: 30)
                        .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                )
            }
            
            Button {
                dismiss()
            } label: {
                Text("Klar")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.black)
                    .cornerRadius(30)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.white.opacity(0.001)) // Transparent background
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
        Button(action: action) {
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


#Preview {
    HomeView()
        .environmentObject(AuthViewModel())
}
