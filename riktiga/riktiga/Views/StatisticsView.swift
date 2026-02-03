import SwiftUI
import Supabase

// MARK: - Sport Type Filter
enum SportType: String, CaseIterable, Identifiable {
    case gym = "Gym"
    case running = "Löpning"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .gym: return "dumbbell.fill"
        case .running: return "figure.run"
        }
    }
    
    var activityTypes: [String] {
        switch self {
        case .gym: return ["gym", "weight_training", "strength"]
        case .running: return ["run", "running", "trail_run"]
        }
    }
}

struct StatisticsView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    
    @State private var selectedSport: SportType = .gym
    @State private var allPosts: [WorkoutPost] = []
    @State private var isLoading = true
    @State private var progressStats: ProgressStats = ProgressStats()
    @State private var weeklyData: [WeekData] = []
    @State private var workoutDays: Set<Int> = []
    @State private var exerciseHistories: [StatExerciseHistory] = []
    @State private var aiPredictions: [OneRepMaxPredictionService.AIPrediction] = []
    @State private var isLoadingPredictions = false
    @State private var predictionError: String? = nil
    
    // Animation states
    @State private var showFilter = false
    @State private var showWeekStats = false
    @State private var showChart = false
    @State private var showMonthly = false
    @State private var showCalendar = false
    @State private var showBMI = false
    @State private var showProgressive = false
    @State private var show1RMPredictions = false
    @State private var showMuscleBalance = false
    @State private var showTopExercises = false
    @State private var showSkeleton = true
    @State private var showProgressPhotos = false

    // BMI state
    @State private var userHeightCm: Int? = nil
    @State private var userWeightKg: Double? = nil
    @State private var showBMIInfo = false
    
    // Chart animation states
    @State private var chartLineTrim: CGFloat = 0
    @State private var chartAreaOpacity: Double = 0
    @State private var chartPointsOpacity: Double = 0
    @State private var statValuesAnimated: Bool = false
    
    // Muscle distribution filter
    @State private var muscleTimePeriod: MuscleTimePeriod = .last30Days
    
    private let calendar = Calendar.current
    
    private var filteredPosts: [WorkoutPost] {
        allPosts.filter { post in
            let type = post.activityType.lowercased()
            return selectedSport.activityTypes.contains { type.contains($0) }
        }
    }
    
    var body: some View {
        ZStack {
            // Skeleton loading view - shows immediately
            if showSkeleton {
                StatisticsSkeletonView()
                    .transition(.opacity)
            }
            
            ScrollView {
                VStack(spacing: 0) {
                    // MARK: - Monthly Recap Preview (first section)
                    monthlyRecapSection
                        .padding(.top, 16)
                        .opacity(showMonthly ? 1 : 0)
                        .offset(y: showMonthly ? 0 : 25)
                        .scaleEffect(showMonthly ? 1 : 0.95, anchor: .top)
                    
                    // MARK: - BMI Section
                    Divider()
                        .padding(.vertical, 24)
                        .opacity(showBMI ? 1 : 0)
                    
                    Group {
                        if userHeightCm != nil && userWeightKg != nil {
                            bmiSection
                        } else if !isLoading {
                            bmiMissingDataSection
                        }
                    }
                    .opacity(showBMI ? 1 : 0)
                    .offset(y: showBMI ? 0 : 25)
                    .scaleEffect(showBMI ? 1 : 0.95, anchor: .top)
                    
                    // MARK: - Sport Type Filter
                    sportTypeFilter
                        .padding(.top, 16)
                        .opacity(showFilter ? 1 : 0)
                    .offset(y: showFilter ? 0 : 10)
                
                // MARK: - This Week Stats
                thisWeekSection
                    .padding(.top, 24)
                    .opacity(showWeekStats ? 1 : 0)
                    .offset(y: showWeekStats ? 0 : 20)
                    .scaleEffect(showWeekStats ? 1 : 0.95, anchor: .top)
                
                // MARK: - Past 12 Weeks Chart
                past12WeeksChart
                    .padding(.top, 8)
                    .opacity(showChart ? 1 : 0)
                    .offset(y: showChart ? 0 : 25)
                    .scaleEffect(showChart ? 1 : 0.95, anchor: .top)
                
                // MARK: - Calendar Section
                Divider()
                    .padding(.vertical, 24)
                    .opacity(showCalendar ? 1 : 0)
                
                calendarSection
                    .opacity(showCalendar ? 1 : 0)
                    .offset(y: showCalendar ? 0 : 25)
                    .scaleEffect(showCalendar ? 1 : 0.95, anchor: .top)
                
                // MARK: - Progress Photos Section
                Divider()
                    .padding(.vertical, 24)
                    .opacity(showProgressPhotos ? 1 : 0)
                
                ProgressPhotosSectionView()
                    .environmentObject(authViewModel)
                    .opacity(showProgressPhotos ? 1 : 0)
                    .offset(y: showProgressPhotos ? 0 : 25)
                    .scaleEffect(showProgressPhotos ? 1 : 0.95, anchor: .top)
                
                // MARK: - Progressive Overload Section
                Divider()
                    .padding(.vertical, 24)
                    .opacity(showProgressive ? 1 : 0)
                
                progressiveOverloadSection
                    .opacity(showProgressive ? 1 : 0)
                    .offset(y: showProgressive ? 0 : 25)
                    .scaleEffect(showProgressive ? 1 : 0.95, anchor: .top)
                
                Divider()
                    .padding(.vertical, 24)
                    .opacity(show1RMPredictions ? 1 : 0)
                
                // MARK: - 1RM Predictions Section
                oneRepMaxPredictionsSection
                    .opacity(show1RMPredictions ? 1 : 0)
                    .offset(y: show1RMPredictions ? 0 : 15)
                
                // MARK: - Muscle Distribution Section
                muscleDistributionSection
                    .opacity(showMuscleBalance ? 1 : 0)
                    .offset(y: showMuscleBalance ? 0 : 15)
                    .padding(.top, 24)
                
                // MARK: - Top Exercises Section
                topExercisesSection
                    .opacity(showTopExercises ? 1 : 0)
                    .offset(y: showTopExercises ? 0 : 15)
                    .padding(.top, 24)
                
                Spacer(minLength: 100)
            }
        }
        .opacity(showSkeleton ? 0 : 1)
        }
        .background(Color(.systemBackground))
        .navigationTitle("Statistik")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadData()
        }
        .onAppear {
            animateContent()
        }
        .enableSwipeBack()
    }
    
    private func animateContent() {
        // Show everything instantly for fast navigation
        // Data loading happens in the background via .task
        showSkeleton = false
        showFilter = true
        showWeekStats = true
        showChart = true
        showCalendar = true
        showBMI = true
        showProgressPhotos = true
        showProgressive = true
        showMonthly = true
        show1RMPredictions = true
        showMuscleBalance = true
        showTopExercises = true
        chartLineTrim = 1.0
        chartAreaOpacity = 1.0
        chartPointsOpacity = 1.0
        statValuesAnimated = true
    }
    
    // MARK: - Sport Type Filter
    private var sportTypeFilter: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(SportType.allCases) { sport in
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            selectedSport = sport
                            updateStats()
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: sport.icon)
                                .font(.system(size: 14, weight: .medium))
                            Text(sport.rawValue)
                                .font(.system(size: 14, weight: .medium))
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(selectedSport == sport ? Color.primary : Color.gray.opacity(0.3), lineWidth: selectedSport == sport ? 2 : 1)
                        )
                        .foregroundColor(selectedSport == sport ? .primary : .gray)
                    }
                }
            }
            .padding(.horizontal, 20)
        }
    }
    
    // MARK: - This Week Section
    private var thisWeekSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Denna vecka")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.primary)
            
            HStack(spacing: 0) {
                if selectedSport == .gym {
                    StatColumn(label: "Volym", value: "\(Int(progressStats.distance)) kg", isAnimated: true, delay: 0.1)
                    StatColumn(label: "Set", value: "\(Int(progressStats.elevation))", isAnimated: true, delay: 0.2)
                    StatColumn(label: "Tid", value: formatDuration(progressStats.duration), isAnimated: true, delay: 0.3)
                } else {
                    StatColumn(label: "Distans", value: String(format: "%.2f km", progressStats.distance), isAnimated: true, delay: 0.1)
                    StatColumn(label: "Höjdmeter", value: "\(Int(progressStats.elevation)) m", isAnimated: true, delay: 0.2)
                    StatColumn(label: "Tid", value: formatDuration(progressStats.duration), isAnimated: true, delay: 0.3)
                }
            }
        }
        .padding(.horizontal, 20)
    }
    
    // MARK: - Past 12 Weeks Chart
    private var past12WeeksChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Senaste 12 veckorna")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.gray)
            
            GeometryReader { geometry in
                let maxValue = weeklyData.map { $0.value }.max() ?? 1
                let chartWidth = geometry.size.width
                let chartHeight: CGFloat = 120
                let pointSpacing = chartWidth / CGFloat(max(weeklyData.count - 1, 1))
                
                ZStack(alignment: .bottomLeading) {
                    // Grid lines
                    VStack(spacing: 0) {
                        ForEach(0..<3) { i in
                            Divider()
                                .background(Color.gray.opacity(0.2))
                            if i < 2 {
                                Spacer()
                            }
                        }
                    }
                    .frame(height: chartHeight)
                    
                    // Y-axis labels
                    VStack {
                        let unit = selectedSport == .gym ? "kg" : "km"
                        Text("\(Int(maxValue)) \(unit)")
                            .font(.system(size: 10))
                            .foregroundColor(.gray)
                        Spacer()
                        Text("\(Int(maxValue / 2)) \(unit)")
                            .font(.system(size: 10))
                            .foregroundColor(.gray)
                        Spacer()
                        Text("0 \(unit)")
                            .font(.system(size: 10))
                            .foregroundColor(.gray)
                    }
                    .frame(height: chartHeight)
                    .offset(x: chartWidth + 8)
                    
                    // Line chart with area fill
                    if weeklyData.count > 1 {
                        // Area fill - animated opacity
                        Path { path in
                            path.move(to: CGPoint(x: 0, y: chartHeight))
                            for (index, data) in weeklyData.enumerated() {
                                let x = CGFloat(index) * pointSpacing
                                let y = chartHeight - (data.value / maxValue) * chartHeight
                                path.addLine(to: CGPoint(x: x, y: y))
                            }
                            path.addLine(to: CGPoint(x: CGFloat(weeklyData.count - 1) * pointSpacing, y: chartHeight))
                            path.closeSubpath()
                        }
                        .fill(Color.primary.opacity(0.1 * chartAreaOpacity))
                        
                        // Line - animated with trim
                        Path { path in
                            for (index, data) in weeklyData.enumerated() {
                                let x = CGFloat(index) * pointSpacing
                                let y = chartHeight - (data.value / maxValue) * chartHeight
                                if index == 0 {
                                    path.move(to: CGPoint(x: x, y: y))
                                } else {
                                    path.addLine(to: CGPoint(x: x, y: y))
                                }
                            }
                        }
                        .trim(from: 0, to: chartLineTrim)
                        .stroke(Color.primary, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                        
                        // Data points - animated with scale and opacity
                        ForEach(weeklyData.indices, id: \.self) { index in
                            let x = CGFloat(index) * pointSpacing
                            let y = chartHeight - (weeklyData[index].value / maxValue) * chartHeight
                            
                            Circle()
                                .fill(index == weeklyData.count - 1 ? Color.primary : Color(.systemBackground))
                                .frame(width: index == weeklyData.count - 1 ? 12 : 8, height: index == weeklyData.count - 1 ? 12 : 8)
                                .overlay(
                                    Circle()
                                        .stroke(Color.primary, lineWidth: 2)
                                )
                                .scaleEffect(chartPointsOpacity)
                                .opacity(chartPointsOpacity)
                                .position(x: x, y: y)
                        }
                    }
                    
                    // X-axis labels
                    HStack {
                        let currentMonth = calendar.component(.month, from: Date())
                        let months = (0..<3).reversed().map { offset -> String in
                            let month = (currentMonth - offset + 11) % 12 + 1
                            return monthAbbreviation(month).uppercased()
                        }
                        
                        ForEach(months, id: \.self) { month in
                            Text(month)
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(.gray)
                            if month != months.last {
                                Spacer()
                            }
                        }
                    }
                    .offset(y: chartHeight + 16)
                }
                .frame(height: chartHeight + 30)
            }
            .frame(height: 150)
            .padding(.trailing, 50)
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
    }
    
    // MARK: - Monthly Recap Section
    private var monthlyRecapSection: some View {
        let previousMonth = calendar.date(byAdding: .month, value: -1, to: Date()) ?? Date()
        let monthFormatter = DateFormatter()
        monthFormatter.dateFormat = "MMMM"
        monthFormatter.locale = Locale(identifier: "sv_SE")
        let monthName = monthFormatter.string(from: previousMonth).capitalized
        
        let yearFormatter = DateFormatter()
        yearFormatter.dateFormat = "yyyy"
        let year = yearFormatter.string(from: previousMonth)
        
        return VStack(alignment: .leading, spacing: 16) {
            NavigationLink(destination: MonthlyReportView()) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(monthName)
                            .font(.system(size: 48, weight: .light))
                            .foregroundColor(.primary)
                        Text(year)
                            .font(.system(size: 48, weight: .light))
                            .foregroundColor(.gray)
                    }
                    
                    Spacer()
                    
                    // Mini bar chart preview
                    HStack(alignment: .bottom, spacing: 3) {
                        ForEach(0..<12, id: \.self) { i in
                            let heights: [CGFloat] = [20, 35, 25, 15, 30, 20, 40, 35, 45, 50, 30, 8]
                            RoundedRectangle(cornerRadius: 1)
                                .fill(i == 11 ? Color.primary : Color.gray.opacity(0.4))
                                .frame(width: 4, height: heights[i])
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
            .buttonStyle(.plain)
            
            // View recap button
            NavigationLink(destination: MonthlyReportView()) {
                Text("Se din månadsrapport")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.primary)
                    .cornerRadius(30)
            }
            .padding(.horizontal, 20)
        }
    }
    
    // MARK: - Calendar Section
    private var calendarSection: some View {
        let currentMonth = Date()
        let monthFormatter = DateFormatter()
        monthFormatter.dateFormat = "MMMM yyyy"
        monthFormatter.locale = Locale(identifier: "sv_SE")
        
        return VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(monthFormatter.string(from: currentMonth).capitalized)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.primary)
                
                Spacer()
            }
            
            // Calendar grid
            calendarGrid
        }
        .padding(.horizontal, 20)
    }
    
    // MARK: - Calendar Grid
    private var calendarGrid: some View {
        let weekdaySymbols = ["M", "T", "W", "T", "F", "S", "S"]
        let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: Date()))!
        let daysInMonth = calendar.range(of: .day, in: .month, for: startOfMonth)?.count ?? 30
        let rawWeekday = calendar.component(.weekday, from: startOfMonth)
        let leadingDays = rawWeekday == 1 ? 6 : rawWeekday - 2
        let today = calendar.component(.day, from: Date())
        
        return VStack(spacing: 12) {
            // Weekday headers
            HStack {
                ForEach(weekdaySymbols, id: \.self) { symbol in
                    Text(symbol)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.gray)
                        .frame(maxWidth: .infinity)
                }
            }
            
            // Calendar rows
            let totalCells = leadingDays + daysInMonth
            let rows = (totalCells + 6) / 7
            
            ForEach(0..<rows, id: \.self) { row in
                HStack(spacing: 0) {
                    ForEach(0..<7, id: \.self) { col in
                        let index = row * 7 + col
                        let day = index - leadingDays + 1
                        
                        if day > 0 && day <= daysInMonth {
                            ZStack {
                                if workoutDays.contains(day) {
                                    Circle()
                                        .fill(Color.primary)
                                        .frame(width: 32, height: 32)
                                    
                                    Image(systemName: selectedSport.icon)
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(.white)
                                } else if day == today {
                                    Circle()
                                        .stroke(Color.primary, lineWidth: 2)
                                        .frame(width: 32, height: 32)
                                    
                                    Text("\(day)")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(.primary)
                                } else {
                                    Text("\(day)")
                                        .font(.system(size: 14))
                                        .foregroundColor(day > today ? .gray.opacity(0.5) : .primary)
                                }
                            }
                            .frame(maxWidth: .infinity)
                        } else {
                            Text("")
                                .frame(maxWidth: .infinity)
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - BMI Section
    private var bmiSection: some View {
        let heightM = Double(userHeightCm ?? 170) / 100.0
        let weight = userWeightKg ?? 70.0
        let bmi = weight / (heightM * heightM)
        
        // Determine BMI category
        let category: (name: String, color: Color) = {
            if bmi < 18.5 {
                return ("Underviktig", Color(red: 0.4, green: 0.6, blue: 0.9))
            } else if bmi < 25.0 {
                return ("Hälsosam", Color(red: 0.3, green: 0.7, blue: 0.5))
            } else if bmi < 30.0 {
                return ("Överviktig", Color(red: 0.85, green: 0.7, blue: 0.3))
            } else {
                return ("Fetma", Color(red: 0.9, green: 0.4, blue: 0.4))
            }
        }()
        
        // Calculate indicator position (BMI range 15-35 mapped to 0-1)
        let indicatorPosition: CGFloat = {
            let clampedBMI = min(max(bmi, 15.0), 35.0)
            return CGFloat((clampedBMI - 15.0) / 20.0)
        }()
        
        return VStack(alignment: .leading, spacing: 20) {
            // Header
            HStack {
                Text("Ditt BMI")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.primary)
                
                Spacer()
                
                Button {
                    showBMIInfo = true
                } label: {
                    Image(systemName: "questionmark.circle")
                        .font(.system(size: 20))
                        .foregroundColor(.gray)
                }
            }
            
            // BMI Value and Category
            HStack(alignment: .center, spacing: 16) {
                Text(String(format: "%.1f", bmi))
                    .font(.system(size: 48, weight: .bold))
                    .foregroundColor(.primary)
                
                HStack(spacing: 8) {
                    Text("Din vikt är")
                        .font(.system(size: 15))
                        .foregroundColor(.secondary)
                    
                    Text(category.name)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(category.color)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(category.color, lineWidth: 1.5)
                        )
                }
            }
            
            // BMI Bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background bar with segments
                    HStack(spacing: 0) {
                        // Underweight (blue) - 0 to 18.5
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color(red: 0.4, green: 0.6, blue: 0.9))
                            .frame(width: geometry.size.width * 0.175)
                        
                        // Healthy (green) - 18.5 to 25
                        Rectangle()
                            .fill(Color(red: 0.3, green: 0.7, blue: 0.5))
                            .frame(width: geometry.size.width * 0.325)
                        
                        // Overweight (yellow) - 25 to 30
                        Rectangle()
                            .fill(Color(red: 0.85, green: 0.7, blue: 0.3))
                            .frame(width: geometry.size.width * 0.25)
                        
                        // Obese (red) - 30+
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color(red: 0.9, green: 0.4, blue: 0.4))
                            .frame(width: geometry.size.width * 0.25)
                    }
                    .frame(height: 24)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    
                    // Indicator
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.primary)
                        .frame(width: 4, height: 32)
                        .offset(x: geometry.size.width * indicatorPosition - 2)
                }
            }
            .frame(height: 32)
            
            // Legend
            HStack(spacing: 0) {
                BMILegendItem(color: Color(red: 0.4, green: 0.6, blue: 0.9), label: "Underviktig", range: "<18.5")
                Spacer()
                BMILegendItem(color: Color(red: 0.3, green: 0.7, blue: 0.5), label: "Hälsosam", range: "18.5–24.9")
                Spacer()
                BMILegendItem(color: Color(red: 0.85, green: 0.7, blue: 0.3), label: "Överviktig", range: "25.0–29.9")
                Spacer()
                BMILegendItem(color: Color(red: 0.9, green: 0.4, blue: 0.4), label: "Fetma", range: ">30.0")
            }
        }
        .padding(20)
        .background(Color(.systemBackground))
        .cornerRadius(20)
        .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 4)
        .padding(.horizontal, 20)
        .alert("Vad är BMI?", isPresented: $showBMIInfo) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("BMI (Body Mass Index) är ett mått som relaterar din vikt till din längd. Det används för att ge en indikation på om din vikt är hälsosam, men tar inte hänsyn till muskelmassa, benstomme eller kroppssammansättning.")
        }
    }
    
    // MARK: - BMI Missing Data Section
    private var bmiMissingDataSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Header
            HStack {
                Text("Ditt BMI")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.primary)
                
                Spacer()
                
                Button {
                    showBMIInfo = true
                } label: {
                    Image(systemName: "questionmark.circle")
                        .font(.system(size: 20))
                        .foregroundColor(.gray)
                }
            }
            
            // Missing data prompt
            VStack(spacing: 16) {
                Image(systemName: "scalemass.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.gray.opacity(0.5))
                
                Text("Lägg till din längd och vikt")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)
                
                Text("Gå till din profil och fyll i din längd och vikt för att se ditt BMI.")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                
                NavigationLink {
                    SettingsView()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 16, weight: .medium))
                        Text("Gå till inställningar")
                            .font(.system(size: 15, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.black)
                    .cornerRadius(12)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
        }
        .padding(20)
        .background(Color(.systemBackground))
        .cornerRadius(20)
        .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 4)
        .padding(.horizontal, 20)
        .alert("Vad är BMI?", isPresented: $showBMIInfo) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("BMI (Body Mass Index) är ett mått som relaterar din vikt till din längd. Det används för att ge en indikation på om din vikt är hälsosam, men tar inte hänsyn till muskelmassa, benstomme eller kroppssammansättning.")
        }
    }
    
    // MARK: - Progressive Overload Section
    private var progressiveOverloadSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Header
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("UTVECKLING")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.secondary)
                        .tracking(1.5)
                    
                    Text("Progressive Overload")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.primary)
                    
                    Text("Följ din styrkeutveckling")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if !exerciseHistories.isEmpty {
                    NavigationLink {
                        AllExercisesListView(exerciseHistories: exerciseHistories)
                    } label: {
                        HStack(spacing: 4) {
                            Text("Se alla")
                                .font(.system(size: 14, weight: .semibold))
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12, weight: .semibold))
                        }
                        .foregroundColor(.primary)
                    }
                }
            }
            
            // Exercise cards or empty state
            if exerciseHistories.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "dumbbell.fill")
                        .font(.system(size: 32))
                        .foregroundColor(.gray.opacity(0.4))
                    
                    Text("Inga gympass ännu")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.secondary)
                    
                    Text("Kör ditt första gympass för att se din utveckling")
                        .font(.system(size: 13))
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
                .background(Color(.secondarySystemBackground))
                .cornerRadius(20)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.primary.opacity(0.06), lineWidth: 1)
                )
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(exerciseHistories.prefix(5).enumerated()), id: \.element.id) { index, history in
                        NavigationLink {
                            StatExerciseDetailView(history: history)
                        } label: {
                            StatExerciseRow(history: history, isLast: index == min(4, exerciseHistories.count - 1))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .background(Color(.secondarySystemBackground))
                .cornerRadius(20)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.primary.opacity(0.06), lineWidth: 1)
                )
                
                // See all button
                if exerciseHistories.count > 5 {
                    NavigationLink {
                        AllExercisesListView(exerciseHistories: exerciseHistories)
                    } label: {
                        HStack {
                            Text("Se alla \(exerciseHistories.count) övningar")
                                .font(.system(size: 15, weight: .semibold))
                            
                            Image(systemName: "arrow.right")
                                .font(.system(size: 13, weight: .semibold))
                        }
                        .foregroundColor(Color(.systemBackground))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(Color.primary)
                        )
                    }
                }
            }
        }
        .padding(.horizontal, 20)
    }
    
    // MARK: - 1RM Predictions Section
    private var oneRepMaxPredictionsSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Header
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 6) {
                    Image("64")
                        .resizable()
                        .scaledToFit()
                        .frame(height: 56)
                    
                    Text("1 Rep Max")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.primary)
                    
                    Text("AI-analyserad maxstyrka per övning")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if !exerciseHistories.isEmpty && !aiPredictions.isEmpty {
                    NavigationLink {
                        All1RMPredictionsView(exerciseHistories: exerciseHistories, aiPredictions: aiPredictions)
                    } label: {
                        HStack(spacing: 4) {
                            Text("Se alla")
                                .font(.system(size: 14, weight: .semibold))
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12, weight: .semibold))
                        }
                        .foregroundColor(.primary)
                    }
                }
            }
            
            // Exercise cards or empty state
            if exerciseHistories.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.system(size: 32))
                        .foregroundColor(.gray.opacity(0.4))
                    
                    Text("Inga gympass ännu")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.secondary)
                    
                    Text("Kör ditt första gympass för att se dina 1RM prediktioner")
                        .font(.system(size: 13))
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
                .background(Color(.secondarySystemBackground))
                .cornerRadius(20)
            } else if isLoadingPredictions {
                // Loading state
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.2)
                    
                    Text("AI analyserar din träningsdata...")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 50)
                .background(Color(.secondarySystemBackground))
                .cornerRadius(20)
            } else if let error = predictionError {
                // Error state
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 32))
                        .foregroundColor(.gray)
                    
                    Text(error)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    
                    Button {
                        Task {
                            await loadAIPredictions()
                        }
                    } label: {
                        Text("Försök igen")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.green)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
                .background(Color(.secondarySystemBackground))
                .cornerRadius(20)
            } else {
                // Show top 3 exercises with AI predictions
                VStack(spacing: 0) {
                    ForEach(Array(exerciseHistories.prefix(3).enumerated()), id: \.element.id) { index, history in
                        let aiPrediction = aiPredictions.first { $0.exerciseName.lowercased() == history.name.lowercased() }
                        NavigationLink {
                            OneRepMaxDetailView(history: history, aiPrediction: aiPrediction)
                        } label: {
                            OneRMPredictionRow(
                                history: history, 
                                aiPrediction: aiPrediction,
                                isLast: index == min(2, exerciseHistories.count - 1)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .background(Color(.secondarySystemBackground))
                .cornerRadius(20)
                
                // See all button
                if exerciseHistories.count > 3 {
                    NavigationLink {
                        All1RMPredictionsView(exerciseHistories: exerciseHistories, aiPredictions: aiPredictions)
                    } label: {
                        HStack {
                            Text("Se alla \(exerciseHistories.count) övningar")
                                .font(.system(size: 15, weight: .semibold))
                            
                            Image(systemName: "arrow.right")
                                .font(.system(size: 13, weight: .semibold))
                        }
                        .foregroundColor(Color(.systemBackground))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(Color.primary)
                        )
                    }
                }
            }
        }
        .padding(.horizontal, 20)
    }
    
    private func loadAIPredictions(retryCount: Int = 0) async {
        guard !exerciseHistories.isEmpty else { return }
        
        await MainActor.run {
            isLoadingPredictions = true
            predictionError = nil
        }
        
        do {
            let predictions = try await OneRepMaxPredictionService.shared.getPredictions(for: exerciseHistories)
            await MainActor.run {
                aiPredictions = predictions
                isLoadingPredictions = false
            }
        } catch {
            // Auto-retry once after cache is cleared (which happens automatically on error)
            if retryCount < 1 {
                print("🔄 Auto-retrying AI predictions after error...")
                try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 second delay
                await loadAIPredictions(retryCount: retryCount + 1)
            } else {
                await MainActor.run {
                    predictionError = error.localizedDescription
                    isLoadingPredictions = false
                }
            }
        }
    }
    
    // MARK: - Muscle Distribution Section
    private var muscleDistributionSection: some View {
        let muscleData = computeMuscleDistribution(for: muscleTimePeriod)
        
        return VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Text("Muskeldistribution")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)
                
                Image(systemName: "chevron.up")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white.opacity(0.6))
                
                Spacer()
                
                Menu {
                    Button {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            muscleTimePeriod = .last30Days
                        }
                    } label: {
                        HStack {
                            Text("Senaste 30 dagarna")
                            if muscleTimePeriod == .last30Days {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                    
                    Button {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            muscleTimePeriod = .last90Days
                        }
                    } label: {
                        HStack {
                            Text("Senaste 90 dagarna")
                            if muscleTimePeriod == .last90Days {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                    
                    Button {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            muscleTimePeriod = .total
                        }
                    } label: {
                        HStack {
                            Text("Totalt")
                            if muscleTimePeriod == .total {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(muscleTimePeriod.displayName)
                            .font(.system(size: 13, weight: .medium))
                        Image(systemName: "chevron.down")
                            .font(.system(size: 10, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.white.opacity(0.15))
                    .cornerRadius(8)
                }
            }
            
            // Radar chart
            MuscleRadarChart(muscleData: muscleData)
                .frame(height: 280)
            
            // Legend - top muscle group
            if let topMuscle = muscleData.max(by: { $0.value < $1.value }), topMuscle.value > 0 {
                HStack(spacing: 8) {
                    Circle()
                        .fill(Color.white)
                        .frame(width: 10, height: 10)
                    
                    Text(topMuscle.key)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Text("\(topMuscle.value) sets")
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.6))
                    
                    Text("100%")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                }
                
                // Progress bar
                GeometryReader { geometry in
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.white)
                        .frame(width: geometry.size.width, height: 6)
                }
                .frame(height: 6)
            }
        }
        .padding(20)
        .background(Color.black)
        .cornerRadius(20)
        .padding(.horizontal, 20)
    }
    
    // MARK: - Top Exercises Section
    private var topExercisesSection: some View {
        let topExercises = computeTopExercises()
        
        return VStack(alignment: .leading, spacing: 20) {
            // Header (same style as Progressive Overload)
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("RANKING")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.secondary)
                        .tracking(1.5)
                    
                    Text("Top Övningar")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.primary)
                    
                    Text("Dina mest tränade övningar")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if topExercises.count > 3 {
                    NavigationLink {
                        AllTopExercisesView(exercises: topExercises, exerciseHistories: exerciseHistories)
                    } label: {
                        HStack(spacing: 4) {
                            Text("Se alla")
                                .font(.system(size: 14, weight: .semibold))
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12, weight: .semibold))
                        }
                        .foregroundColor(.primary)
                    }
                }
            }
            
            // Exercise list (same style as Progressive Overload)
            if topExercises.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "list.number")
                        .font(.system(size: 32))
                        .foregroundColor(.gray.opacity(0.4))
                    
                    Text("Inga övningar ännu")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.secondary)
                    
                    Text("Kör ditt första gympass för att se din ranking")
                        .font(.system(size: 13))
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
                .background(Color(.secondarySystemBackground))
                .cornerRadius(20)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(topExercises.prefix(3).enumerated()), id: \.element.name) { index, exercise in
                        TopExerciseRow(
                            rank: index + 1,
                            exercise: exercise,
                            exerciseId: getExerciseId(for: exercise.name),
                            isLast: index == min(2, topExercises.count - 1)
                        )
                    }
                }
                .background(Color(.secondarySystemBackground))
                .cornerRadius(20)
                
                // See all button
                if topExercises.count > 3 {
                    NavigationLink {
                        AllTopExercisesView(exercises: topExercises, exerciseHistories: exerciseHistories)
                    } label: {
                        HStack {
                            Text("Se alla \(topExercises.count) övningar")
                                .font(.system(size: 15, weight: .semibold))
                            
                            Image(systemName: "arrow.right")
                                .font(.system(size: 13, weight: .semibold))
                        }
                        .foregroundColor(Color(.systemBackground))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(Color.primary)
                        )
                    }
                }
            }
        }
        .padding(.horizontal, 20)
    }
    
    private func getExerciseId(for exerciseName: String) -> String? {
        exerciseHistories.first { $0.name == exerciseName }?.exerciseId
    }
    
    // MARK: - Compute Muscle Distribution
    private func computeMuscleDistribution(for timePeriod: MuscleTimePeriod) -> [String: Int] {
        var muscleSetCounts: [String: Int] = [
            "Chest": 0,
            "Shoulders": 0,
            "Back": 0,
            "Biceps": 0,
            "Triceps": 0,
            "Quads": 0,
            "Hams": 0,
            "Glutes": 0
        ]
        
        let cutoffDate: Date? = {
            switch timePeriod {
            case .last30Days:
                return Calendar.current.date(byAdding: .day, value: -30, to: Date())
            case .last90Days:
                return Calendar.current.date(byAdding: .day, value: -90, to: Date())
            case .total:
                return nil
            }
        }()
        
        for post in allPosts {
            let type = post.activityType.lowercased()
            guard type.contains("gym") else { continue }
            guard let exercises = post.exercises else { continue }
            
            // Filter by date if cutoff is set
            if let cutoff = cutoffDate, let postDate = parseDate(post.createdAt) {
                guard postDate >= cutoff else { continue }
            }
            
            for exercise in exercises {
                let category = (exercise.category ?? "").lowercased()
                let setCount = exercise.kg.count
                
                // Map categories to muscle groups
                if category.contains("chest") || category.contains("bröst") {
                    muscleSetCounts["Chest", default: 0] += setCount
                } else if category.contains("shoulder") || category.contains("axlar") || category.contains("delt") {
                    muscleSetCounts["Shoulders", default: 0] += setCount
                } else if category.contains("back") || category.contains("rygg") || category.contains("lat") {
                    muscleSetCounts["Back", default: 0] += setCount
                } else if category.contains("bicep") {
                    muscleSetCounts["Biceps", default: 0] += setCount
                } else if category.contains("tricep") {
                    muscleSetCounts["Triceps", default: 0] += setCount
                } else if category.contains("quad") || category.contains("leg") || category.contains("ben") {
                    muscleSetCounts["Quads", default: 0] += setCount
                } else if category.contains("ham") || category.contains("hamstring") {
                    muscleSetCounts["Hams", default: 0] += setCount
                } else if category.contains("glute") || category.contains("rumpa") {
                    muscleSetCounts["Glutes", default: 0] += setCount
                }
            }
        }
        
        return muscleSetCounts
    }
    
    // MARK: - Compute Top Exercises
    private func computeTopExercises() -> [TopExerciseData] {
        var exerciseMap: [String: TopExerciseData] = [:]
        
        for post in allPosts {
            let type = post.activityType.lowercased()
            guard type.contains("gym") else { continue }
            guard let exercises = post.exercises else { continue }
            guard let date = parseDate(post.createdAt) else { continue }
            
            for exercise in exercises {
                let name = exercise.name
                let setCount = exercise.kg.count
                let maxWeight = exercise.kg.max() ?? 0
                
                if var existing = exerciseMap[name] {
                    existing.totalSets += setCount
                    existing.sessionCount += 1
                    if date > existing.lastDate {
                        existing.lastDate = date
                    }
                    if maxWeight > existing.bestWeight {
                        existing.bestWeight = maxWeight
                    }
                    exerciseMap[name] = existing
                } else {
                    exerciseMap[name] = TopExerciseData(
                        name: name,
                        totalSets: setCount,
                        sessionCount: 1,
                        lastDate: date,
                        bestWeight: maxWeight
                    )
                }
            }
        }
        
        return exerciseMap.values.sorted { $0.totalSets > $1.totalSets }
    }
    
    // MARK: - Helper Functions
    private func loadData() async {
        guard let userId = authViewModel.currentUser?.id else { return }
        
        do {
            // Load workout posts
            let posts = try await WorkoutService.shared.getUserWorkoutPosts(userId: userId, forceRefresh: true)
            
            // Load BMI data (height and weight) from profiles
            await loadBMIData(userId: userId)
            
            await MainActor.run {
                withAnimation(.easeInOut(duration: 0.3)) {
                    self.allPosts = posts
                    updateStats()
                    calculateCalendarData()
                    computeExerciseHistories()
                    isLoading = false
                }
            }
            
            // Load AI predictions after exercise histories are computed
            await loadAIPredictions()
        } catch {
            print("Error loading stats: \(error)")
            await MainActor.run {
                isLoading = false
            }
        }
    }
    
    private func loadBMIData(userId: String) async {
        do {
            struct ProfileBMI: Decodable {
                let height_cm: Int?
                let weight_kg: Double?
            }
            
            let profiles: [ProfileBMI] = try await SupabaseConfig.supabase
                .from("profiles")
                .select("height_cm, weight_kg")
                .eq("id", value: userId)
                .execute()
                .value
            
            if let profile = profiles.first {
                await MainActor.run {
                    self.userHeightCm = profile.height_cm
                    self.userWeightKg = profile.weight_kg
                    print("📊 BMI data loaded: height=\(profile.height_cm ?? 0)cm, weight=\(profile.weight_kg ?? 0)kg")
                }
            }
        } catch {
            print("⚠️ Error loading BMI data: \(error)")
        }
    }
    
    private func computeExerciseHistories() {
        var map: [String: (exerciseId: String?, snapshots: [StatExerciseSnapshot])] = [:]
        
        for post in allPosts {
            let type = post.activityType.lowercased()
            guard type.contains("gym") else { continue }
            guard let exercises = post.exercises, !exercises.isEmpty else { continue }
            guard let date = parseDate(post.createdAt) else { continue }
            
            for exercise in exercises {
                let sets = zip(exercise.kg, exercise.reps)
                    .map { StatSetSnapshot(weight: $0.0, reps: $0.1) }
                    .filter { $0.reps > 0 }
                guard !sets.isEmpty else { continue }
                
                // Best set based on estimated 1RM
                let bestSet = sets.max(by: { $0.estimated1RM < $1.estimated1RM }) ?? sets[0]
                
                let snapshot = StatExerciseSnapshot(
                    date: date,
                    bestSet: bestSet,
                    sets: sets,
                    category: exercise.category
                )
                
                // Store exercise ID if available
                if map[exercise.name] == nil {
                    map[exercise.name] = (exerciseId: exercise.id, snapshots: [snapshot])
                } else {
                    map[exercise.name]?.snapshots.append(snapshot)
                    // Update exerciseId if we have a newer one
                    if let id = exercise.id, map[exercise.name]?.exerciseId == nil {
                        map[exercise.name]?.exerciseId = id
                    }
                }
            }
        }
        
        let histories = map.map { name, data -> StatExerciseHistory in
            let sorted = data.snapshots.sorted { $0.date < $1.date }
            return StatExerciseHistory(
                name: name,
                category: sorted.last?.category,
                exerciseId: data.exerciseId,
                history: sorted
            )
        }
        
        // Sort by latest activity
        exerciseHistories = histories.sorted { (lhs, rhs) -> Bool in
            let leftDate = lhs.latestSnapshot?.date ?? .distantPast
            let rightDate = rhs.latestSnapshot?.date ?? .distantPast
            return leftDate > rightDate
        }
    }
    
    private func updateStats() {
        withAnimation(.easeInOut(duration: 0.3)) {
            let posts = filteredPosts
            let now = Date()
            let startOfWeek = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)) ?? now
            
            let thisWeekPosts = posts.filter { post in
                guard let date = parseDate(post.createdAt) else { return false }
                return date >= startOfWeek
            }
        
        if selectedSport == .gym {
            // Calculate volume and sets for gym
            let volume = thisWeekPosts.reduce(0.0) { total, post in
                let postVolume = post.exercises?.reduce(0.0) { exerciseTotal, exercise in
                    let exerciseVolume = zip(exercise.reps, exercise.kg).reduce(0.0) { setTotal, pair in
                        setTotal + Double(pair.0) * pair.1
                    }
                    return exerciseTotal + exerciseVolume
                } ?? 0.0
                return total + postVolume
            }
            
            let sets = thisWeekPosts.reduce(0) { total, post in
                let postSets = post.exercises?.reduce(0) { $0 + $1.sets } ?? 0
                return total + postSets
            }
            
            progressStats = ProgressStats(
                distance: volume, // Using distance field for volume
                elevation: Double(sets), // Using elevation field for sets
                duration: thisWeekPosts.reduce(0) { $0 + Double($1.duration ?? 0) }
            )
        } else {
            // Calculate distance and elevation for cardio
            progressStats = ProgressStats(
                distance: thisWeekPosts.reduce(0) { $0 + (($1.distance ?? 0) / 1000) },
                elevation: thisWeekPosts.reduce(0) { $0 + ($1.elevationGain ?? 0) },
                duration: thisWeekPosts.reduce(0) { $0 + Double($1.duration ?? 0) }
            )
        }
        
        // Calculate weekly data for chart
        var data: [WeekData] = []
        for weekOffset in (0..<12).reversed() {
            guard let weekStart = calendar.date(byAdding: .weekOfYear, value: -weekOffset, to: startOfWeek) else { continue }
            guard let weekEnd = calendar.date(byAdding: .day, value: 7, to: weekStart) else { continue }
            
            let weekPosts = posts.filter { post in
                guard let date = parseDate(post.createdAt) else { return false }
                return date >= weekStart && date < weekEnd
            }
            
            let value: Double
            if selectedSport == .gym {
                value = weekPosts.reduce(0.0) { total, post in
                    let postVolume = post.exercises?.reduce(0.0) { exerciseTotal, exercise in
                        let exerciseVolume = zip(exercise.reps, exercise.kg).reduce(0.0) { setTotal, pair in
                            setTotal + Double(pair.0) * pair.1
                        }
                        return exerciseTotal + exerciseVolume
                    } ?? 0.0
                    return total + postVolume
                }
            } else {
                value = weekPosts.reduce(0.0) { $0 + (($1.distance ?? 0) / 1000) }
            }
            
            data.append(WeekData(weekStart: weekStart, value: value))
        }
        weeklyData = data
    }
}
    
    private func calculateCalendarData() {
        withAnimation(.easeInOut(duration: 0.3)) {
            let posts = filteredPosts
            let thisMonth = calendar.dateComponents([.year, .month], from: Date())
            
            var days: Set<Int> = []
            for post in posts {
                if let date = parseDate(post.createdAt) {
                    let postComponents = calendar.dateComponents([.year, .month, .day], from: date)
                    if postComponents.year == thisMonth.year && postComponents.month == thisMonth.month {
                        if let day = postComponents.day {
                            days.insert(day)
                        }
                    }
                }
            }
            workoutDays = days
        }
    }
    
    private func parseDate(_ dateString: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: dateString) {
            return date
        }
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: dateString)
    }
    
    private func formatDuration(_ seconds: Double) -> String {
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }
    
    private func monthAbbreviation(_ month: Int) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "sv_SE")
        return formatter.shortMonthSymbols[month - 1].replacingOccurrences(of: ".", with: "")
    }
}

// MARK: - Supporting Types
private struct ProgressStats {
    var distance: Double = 0
    var elevation: Double = 0
    var duration: Double = 0
}

private struct WeekData: Identifiable {
    let id = UUID()
    let weekStart: Date
    let value: Double
}

private struct StatColumn: View {
    let label: String
    let value: String
    var isAnimated: Bool = false
    var delay: Double = 0
    
    @State private var showValue = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 12))
                .foregroundColor(.gray)
                .opacity(showValue ? 1 : 0)
                .offset(y: showValue ? 0 : 10)
            
            Text(value)
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.primary)
                .opacity(showValue ? 1 : 0)
                .scaleEffect(showValue ? 1 : 0.5, anchor: .leading)
                .offset(y: showValue ? 0 : 15)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .onAppear {
            if isAnimated {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.7).delay(delay)) {
                    showValue = true
                }
            } else {
                showValue = true
            }
        }
    }
}

private struct SectionHeader: View {
    let title: String
    let icon: String
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.secondary)
            
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.secondary)
                .textCase(.uppercase)
        }
    }
}

private enum CalendarMode: String, CaseIterable, Identifiable {
    case month = "Månad"
    case year = "År"
    case multiYear = "Flera år"
    
    var id: String { rawValue }
}

private struct CalendarOverviewView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var workoutDates: [Date] = []
    @State private var workoutSet: Set<Date> = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var mode: CalendarMode = .month
    @State private var referenceDate = Date()
    @State private var earliestDate: Date?
    
    private var calendar: Calendar {
        var cal = Calendar(identifier: .iso8601)
        cal.locale = Locale(identifier: "sv_SE")
        cal.firstWeekday = 2
        return cal
    }
    
    private let isoFormatterWithMs: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
    
    private let isoFormatterNoMs: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header card
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "calendar")
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundColor(.primary)
                        
                        Text("Träningskalender")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.primary)
                        
                        Spacer()
                    }
                    
                    Text("Visualisera dina träningsdagar och håll koll på din kontinuitet.")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                    
                    // Stats row
                    HStack(spacing: 12) {
                        CalendarStatItem(value: "\(workoutDates.count)", label: "Pass", color: .primary)
                        CalendarStatItem(value: "\(workoutSet.count)", label: "Dagar", color: .secondary)
                    }
                    .padding(.top, 8)
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.systemBackground))
                .cornerRadius(16)
                .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 4)
                
                // Mode picker card
                VStack(spacing: 16) {
                    modePicker
                }
                .padding(16)
                .background(Color(.systemBackground))
                .cornerRadius(16)
                .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 4)
                
                // Calendar card
                VStack {
                    switch mode {
                    case .month:
                        MonthCalendarView(referenceDate: $referenceDate,
                                          workoutSet: workoutSet,
                                          calendar: calendar)
                    case .year:
                        YearCalendarView(referenceDate: $referenceDate,
                                         workoutSet: workoutSet,
                                         calendar: calendar)
                    case .multiYear:
                        MultiYearCalendarView(referenceDate: referenceDate,
                                              earliestDate: earliestDate,
                                              workoutSet: workoutSet,
                                              calendar: calendar)
                    }
                }
                .padding(16)
                .background(Color(.systemBackground))
                .cornerRadius(16)
                .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 4)
            }
            .padding(16)
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .navigationTitle("Kalender")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: reload) {
                    Image(systemName: "arrow.clockwise")
                }
                .disabled(isLoading)
            }
        }
        .overlay(alignment: .center) {
            if isLoading {
                ProgressView("Hämtar träningsdagar…")
                    .padding(.horizontal, 24)
                    .padding(.vertical, 16)
                    .background(Color(.systemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .shadow(color: Color.black.opacity(0.15), radius: 10, x: 0, y: 6)
            } else if let errorMessage {
                VStack(spacing: 12) {
                    Text(errorMessage)
                        .font(.callout)
                        .multilineTextAlignment(.center)
                    Button("Försök igen") {
                        reload()
                    }
                    .font(.system(size: 14, weight: .semibold))
                    .padding(.horizontal, 18)
                    .padding(.vertical, 8)
                    .background(Color.primary)
                    .foregroundColor(Color(.systemBackground))
                    .clipShape(Capsule())
                }
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(18)
                .shadow(color: Color.black.opacity(0.15), radius: 10, x: 0, y: 6)
            }
        }
        .task {
            await loadWorkoutDates()
        }
        .refreshable {
            await loadWorkoutDates(force: true)
        }
    }
    
    private var currentStreak: Int {
        guard !workoutSet.isEmpty else { return 0 }
        
        var streak = 0
        var currentDate = calendar.startOfDay(for: Date())
        
        // Check if today or yesterday was a workout day to start the streak
        if !workoutSet.contains(currentDate) {
            if let yesterday = calendar.date(byAdding: .day, value: -1, to: currentDate) {
                currentDate = yesterday
            }
        }
        
        // Count consecutive days backwards
        while workoutSet.contains(currentDate) {
            streak += 1
            if let previousDay = calendar.date(byAdding: .day, value: -1, to: currentDate) {
                currentDate = previousDay
            } else {
                break
            }
        }
        
        return streak
    }
    
    private var modePicker: some View {
        VStack(spacing: 12) {
            Picker("Vy", selection: $mode) {
                ForEach(CalendarMode.allCases) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            
            switch mode {
            case .month:
                MonthNavigationControls(referenceDate: $referenceDate, calendar: calendar)
            case .year:
                YearNavigationControls(referenceDate: $referenceDate, calendar: calendar)
            case .multiYear:
                EmptyView()
            }
        }
    }
    
    private func reload() {
        Task {
            await loadWorkoutDates(force: true)
        }
    }
    
    private func loadWorkoutDates(force: Bool = false) async {
        guard let userId = authViewModel.currentUser?.id else {
            await MainActor.run {
                self.errorMessage = "Logga in för att se kalendern."
                self.isLoading = false
            }
            return
        }
        
        await MainActor.run {
            if force || workoutDates.isEmpty {
                isLoading = true
            }
            errorMessage = nil
        }
        
        do {
            let posts = try await WorkoutService.shared.getUserWorkoutPosts(userId: userId, forceRefresh: force)
            let fetchedDates: [Date] = posts.compactMap { post in
                if let date = isoFormatterWithMs.date(from: post.createdAt) {
                    return date
                }
                return isoFormatterNoMs.date(from: post.createdAt)
            }
            let daySet = Set(fetchedDates.map { calendar.startOfDay(for: $0) })
            let earliest = fetchedDates.min()
            
            await MainActor.run {
                withAnimation {
                    self.workoutDates = fetchedDates
                    self.workoutSet = daySet
                    self.earliestDate = earliest
                    self.isLoading = false
                }
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "Kunde inte hämta kalenderdata just nu."
                self.isLoading = false
            }
        }
    }
}

private struct CalendarStatItem: View {
    let value: String
    let label: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 8) {
            Text(value)
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(color)
            
            Text(label)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(color.opacity(0.1))
        .cornerRadius(12)
    }
}

private struct MonthNavigationControls: View {
    @Binding var referenceDate: Date
    let calendar: Calendar
    
    var body: some View {
        HStack {
            Button(action: { changeMonth(-1) }) {
                Image(systemName: "chevron.left")
                    .font(.headline)
                    .padding(8)
                    .background(Color(.systemGray5))
                    .clipShape(Circle())
            }
            Spacer()
            Text(monthFormatter.string(from: referenceDate).capitalized)
                .font(.system(size: 18, weight: .bold))
            Spacer()
            Button(action: { changeMonth(1) }) {
                Image(systemName: "chevron.right")
                    .font(.headline)
                    .padding(8)
                    .background(Color(.systemGray5))
                    .clipShape(Circle())
            }
        }
    }
    
    private var monthFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "LLLL yyyy"
        formatter.locale = Locale(identifier: "sv_SE")
        return formatter
    }
    
    private func changeMonth(_ offset: Int) {
        if let newDate = calendar.date(byAdding: .month, value: offset, to: referenceDate) {
            referenceDate = newDate
        }
    }
}

private struct YearNavigationControls: View {
    @Binding var referenceDate: Date
    let calendar: Calendar
    
    var body: some View {
        HStack {
            Button(action: { shiftYear(-1) }) {
                Image(systemName: "chevron.left")
                    .font(.headline)
                    .padding(8)
                    .background(Color(.systemGray5))
                    .clipShape(Circle())
            }
            Spacer()
            Text(yearFormatter.string(from: referenceDate))
                .font(.system(size: 18, weight: .bold))
            Spacer()
            Button(action: { shiftYear(1) }) {
                Image(systemName: "chevron.right")
                    .font(.headline)
                    .padding(8)
                    .background(Color(.systemGray5))
                    .clipShape(Circle())
            }
        }
    }
    
    private var yearFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy"
        formatter.locale = Locale(identifier: "sv_SE")
        return formatter
    }
    
    private func shiftYear(_ offset: Int) {
        if let newDate = calendar.date(byAdding: .year, value: offset, to: referenceDate) {
            referenceDate = newDate
        }
    }
}

private struct MonthCalendarView: View {
    @Binding var referenceDate: Date
    let workoutSet: Set<Date>
    let calendar: Calendar
    
    private var monthLabel: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "LLLL yyyy"
        formatter.locale = Locale(identifier: "sv_SE")
        return formatter.string(from: referenceDate).capitalized
    }
    
    private var daysInMonth: [Int] {
        guard let range = calendar.range(of: .day, in: .month, for: referenceDate) else { return [] }
        return Array(range)
    }
    
    private var firstWeekdayOffset: Int {
        let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: referenceDate)) ?? referenceDate
        let weekday = calendar.component(.weekday, from: monthStart)
        let normalized = (weekday - calendar.firstWeekday + 7) % 7
        return normalized
    }
    
    private var workoutCountThisMonth: Int {
        daysInMonth.filter { day in
            guard let date = dayDate(day: day) else { return false }
            return workoutSet.contains(calendar.startOfDay(for: date))
        }.count
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Month header with stats
            HStack {
                Text(monthLabel)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.primary)
                
                Spacer()
                
                HStack(spacing: 4) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.green)
                    Text("\(workoutCountThisMonth) pass")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.green)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.green.opacity(0.12))
                .cornerRadius(10)
            }
            
            // Weekday headers
            let weekdaySymbols = calendar.shortWeekdaySymbols
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 7), spacing: 12) {
                ForEach(weekdaySymbols, id: \.self) { symbol in
                    Text(symbol.capitalized)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity)
                }
                
                // Empty cells for offset
                ForEach(0..<firstWeekdayOffset, id: \.self) { _ in
                    Text("")
                        .frame(height: 36)
                }
                
                // Day cells
                ForEach(daysInMonth, id: \.self) { day in
                    let date = dayDate(day: day)
                    let isWorkoutDay = date.map { workoutSet.contains(calendar.startOfDay(for: $0)) } ?? false
                    let isToday = date.map { calendar.isDateInToday($0) } ?? false
                    
                    Text("\(day)")
                        .font(.system(size: 15, weight: isWorkoutDay || isToday ? .bold : .medium))
                        .frame(width: 38, height: 38)
                        .background(
                            ZStack {
                                if isWorkoutDay {
                                    Circle()
                                        .fill(Color.green)
                                } else if isToday {
                                    Circle()
                                        .stroke(Color.primary, lineWidth: 2)
                                } else {
                                    Circle()
                                        .fill(Color(.systemGray6))
                                }
                            }
                        )
                        .foregroundColor(isWorkoutDay ? .white : .primary)
                }
            }
        }
    }
    
    private func dayDate(day: Int) -> Date? {
        var comps = calendar.dateComponents([.year, .month], from: referenceDate)
        comps.day = day
        return calendar.date(from: comps)
    }
}

private struct YearCalendarView: View {
    @Binding var referenceDate: Date
    let workoutSet: Set<Date>
    let calendar: Calendar
    
    private var months: [Date] {
        guard let yearStart = calendar.date(from: calendar.dateComponents([.year], from: referenceDate)) else { return [] }
        return (0..<12).compactMap { calendar.date(byAdding: .month, value: $0, to: yearStart) }
    }
    
    private var totalWorkoutsThisYear: Int {
        months.reduce(0) { total, monthStart in
            let days = calendar.range(of: .day, in: .month, for: monthStart) ?? 1..<32
            return total + days.filter { day in
                var comps = calendar.dateComponents([.year, .month], from: monthStart)
                comps.day = day
                guard let date = calendar.date(from: comps) else { return false }
                return workoutSet.contains(calendar.startOfDay(for: date))
            }.count
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Year header with total stats
            HStack {
                Text(yearFormatter.string(from: referenceDate))
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.primary)
                
                Spacer()
                
                HStack(spacing: 4) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.green)
                    Text("\(totalWorkoutsThisYear) pass totalt")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.green)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.green.opacity(0.12))
                .cornerRadius(10)
            }
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 2), spacing: 12) {
                ForEach(months, id: \.self) { monthStart in
                    MiniMonthCard(monthStart: monthStart, workoutSet: workoutSet, calendar: calendar)
                }
            }
        }
    }
    
    private var yearFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy"
        formatter.locale = Locale(identifier: "sv_SE")
        return formatter
    }
}

private struct MiniMonthCard: View {
    let monthStart: Date
    let workoutSet: Set<Date>
    let calendar: Calendar
    
    private var monthLabel: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM"
        formatter.locale = Locale(identifier: "sv_SE")
        return formatter.string(from: monthStart).capitalized
    }
    
    private var workoutCount: Int {
        let days = calendar.range(of: .day, in: .month, for: monthStart) ?? 1..<32
        return days.filter { day in
            guard let date = makeDate(day: day) else { return false }
            return workoutSet.contains(calendar.startOfDay(for: date))
        }.count
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(monthLabel)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.primary)
                
                Spacer()
                
                if workoutCount > 0 {
                    Text("\(workoutCount)")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color.green)
                        .cornerRadius(8)
                }
            }
            
            let days = calendar.range(of: .day, in: .month, for: monthStart) ?? 1..<32
            let columns = Array(repeating: GridItem(.flexible(), spacing: 3), count: 7)
            LazyVGrid(columns: columns, spacing: 3) {
                ForEach(days, id: \.self) { day in
                    let date = makeDate(day: day)
                    let hasWorkout = date.map { workoutSet.contains(calendar.startOfDay(for: $0)) } ?? false
                    RoundedRectangle(cornerRadius: 2)
                        .fill(hasWorkout ? Color.green : Color(.systemGray5))
                        .frame(width: 12, height: 12)
                }
            }
        }
        .padding(14)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
    
    private func makeDate(day: Int) -> Date? {
        var comps = calendar.dateComponents([.year, .month], from: monthStart)
        comps.day = day
        return calendar.date(from: comps)
    }
}

private struct MultiYearCalendarView: View {
    let referenceDate: Date
    let earliestDate: Date?
    let workoutSet: Set<Date>
    let calendar: Calendar
    
    private var years: [Int] {
        let refYear = calendar.component(.year, from: referenceDate)
        guard let earliest = earliestDate else { return [refYear] }
        let earliestYear = calendar.component(.year, from: earliest)
        return Array(earliestYear...refYear).reversed()
    }
    
    private var totalWorkouts: Int {
        workoutSet.count
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Header
            HStack {
                Text("Historik")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.primary)
                
                Spacer()
                
                HStack(spacing: 4) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.green)
                    Text("\(totalWorkouts) pass totalt")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.green)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.green.opacity(0.12))
                .cornerRadius(10)
            }
            
            if years.isEmpty {
                HStack(spacing: 12) {
                    Image(systemName: "calendar.badge.exclamationmark")
                        .font(.system(size: 24))
                        .foregroundColor(.secondary)
                    
                    Text("Inga registrerade pass ännu.")
                        .font(.system(size: 15))
                        .foregroundColor(.secondary)
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.systemGray6))
                .cornerRadius(12)
            } else {
                ForEach(years, id: \.self) { year in
                    YearHeatRow(year: year, workoutSet: workoutSet, calendar: calendar)
                }
            }
        }
    }
}

private struct YearHeatRow: View {
    let year: Int
    let workoutSet: Set<Date>
    let calendar: Calendar
    
    private var workoutsThisYear: Int {
        let months = (0..<12).compactMap { offset -> Date? in
            var comps = DateComponents()
            comps.year = year
            comps.month = offset + 1
            comps.day = 1
            return calendar.date(from: comps)
        }
        return months.reduce(0) { total, monthStart in
            let range = calendar.range(of: .day, in: .month, for: monthStart) ?? 1..<32
            return total + range.filter { day in
                var comps = calendar.dateComponents([.year, .month], from: monthStart)
                comps.day = day
                guard let date = calendar.date(from: comps) else { return false }
                return workoutSet.contains(calendar.startOfDay(for: date))
            }.count
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("\(year)")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.primary)
                
                Spacer()
                
                Text("\(workoutsThisYear) pass")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.secondary)
            }
            
            let months = (0..<12).compactMap { offset -> Date? in
                var comps = DateComponents()
                comps.year = year
                comps.month = offset + 1
                comps.day = 1
                return calendar.date(from: comps)
            }
            
            // Month labels
            HStack(spacing: 4) {
                ForEach(["J", "F", "M", "A", "M", "J", "J", "A", "S", "O", "N", "D"], id: \.self) { label in
                    Text(label)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }
            
            // Activity dots
            HStack(spacing: 4) {
                ForEach(months, id: \.self) { monthStart in
                    MiniMonthDot(monthStart: monthStart, workoutSet: workoutSet, calendar: calendar)
                }
            }
        }
        .padding(16)
        .background(Color(.systemGray6))
        .cornerRadius(14)
    }
}

private struct MiniMonthDot: View {
    let monthStart: Date
    let workoutSet: Set<Date>
    let calendar: Calendar
    
    private var workoutCountInMonth: Int {
        let range = calendar.range(of: .day, in: .month, for: monthStart) ?? 1..<32
        return range.filter { day in
            var comps = calendar.dateComponents([.year, .month], from: monthStart)
            comps.day = day
            guard let date = calendar.date(from: comps) else { return false }
            return workoutSet.contains(calendar.startOfDay(for: date))
        }.count
    }
    
    private var intensity: Double {
        let count = workoutCountInMonth
        if count == 0 { return 0 }
        if count <= 3 { return 0.3 }
        if count <= 7 { return 0.5 }
        if count <= 12 { return 0.75 }
        return 1.0
    }
    
    var body: some View {
        RoundedRectangle(cornerRadius: 4, style: .continuous)
            .fill(workoutCountInMonth > 0 ? Color.green.opacity(intensity) : Color(.systemGray5))
            .frame(maxWidth: .infinity, minHeight: 20)
    }
}

private struct StatisticsMenuRow: View {
    let icon: String
    let assetName: String?
    let title: String
    let subtitle: String
    var iconColor: Color
    var showDivider: Bool
    
    init(icon: String, assetName: String? = nil, title: String, subtitle: String, iconColor: Color = .primary, showDivider: Bool = false) {
        self.icon = icon
        self.assetName = assetName
        self.title = title
        self.subtitle = subtitle
        self.iconColor = iconColor
        self.showDivider = showDivider
    }
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(iconColor.opacity(0.12))
                        .frame(width: 44, height: 44)
                    if let assetName {
                        Image(assetName)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 38, height: 38)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    } else {
                        Image(systemName: icon)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(iconColor)
                    }
                }
                
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary)
                    Text(subtitle)
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.secondary.opacity(0.5))
            }
            .padding(.vertical, 12)
            
            if showDivider {
                Divider()
                    .padding(.leading, 58)
            }
        }
    }
}

private struct UppyMenuRow: View {
    let title: String
    let subtitle: String
    
    private var prefixText: String {
        guard let range = title.range(of: "UPPY", options: .caseInsensitive) else {
            return title
        }
        return title[..<range.lowerBound].trimmingCharacters(in: .whitespaces)
    }
    
    private var uppyText: String? {
        guard let range = title.range(of: "UPPY", options: .caseInsensitive) else {
            return nil
        }
        return String(title[range])
    }
    
    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color(.systemGray6))
                    .frame(width: 48, height: 48)
                Image("23")
                    .resizable()
                    .scaledToFill()
                    .frame(width: 42, height: 42)
                    .clipShape(Circle())
            }
            
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(prefixText.isEmpty ? title : prefixText.replacingOccurrences(of: " ", with: ""))
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    if let uppyText {
                        LinearGradient(
                            colors: [Color.primary, Color.gray.opacity(0.75), Color.gray.opacity(0.55)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        .mask(
                            Text(uppyText.uppercased())
                                .font(.system(size: 16, weight: .heavy))
                        )
                        .accessibilityLabel("UPPY")
                        
                        Image(systemName: "sparkle.fill")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.primary)
                            .accessibilityHidden(true)
                    }
                }
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundColor(.gray)
            }
        }
        .padding(.vertical, 4)
    }
}

private struct StepStatisticsSectionView: View {
    @State private var todaySteps: Int?
    @State private var lastWeekSteps: Int?
    @State private var lastMonthSteps: Int?
    @State private var isAuthorized = HealthKitManager.shared.isHealthDataAuthorized()
    @State private var isLoading = false
    @State private var hasInitialized = false
    @State private var pendingRequests = 0
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Din aktivitet")
                        .font(.system(size: 17, weight: .semibold))
                    Text("Synkas från Apple Hälsa")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
                Spacer()
                if isAuthorized {
                    Button {
                        loadStepData()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 16, weight: .semibold))
                            .padding(8)
                            .background(Color(.systemGray6))
                            .clipShape(Circle())
                    }
                    .disabled(isLoading)
                    .accessibilityLabel("Uppdatera stegstatistik")
                }
            }
            
            if !isAuthorized {
                VStack(alignment: .leading, spacing: 12) {
                    Text("För att se din stegstatistik behöver du ge appen tillgång till stegdata i Apple Hälsa.")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                    HStack {
                        Button(action: requestAuthorization) {
                            Text("Tillåt stegdata")
                                .font(.system(size: 14, weight: .semibold))
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(Color.primary)
                                .foregroundColor(Color(.systemBackground))
                                .clipShape(Capsule())
                        }
                        Button(action: HealthKitManager.shared.handleManageAuthorizationButton) {
                            Text("Öppna inställningar")
                                .font(.system(size: 14, weight: .medium))
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(Color(.systemGray5))
                                .clipShape(Capsule())
                        }
                    }
                }
            } else if isLoading {
                HStack(spacing: 12) {
                    ProgressView()
                    Text("Hämtar stegdata…")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                VStack(spacing: 12) {
                    StepStatRow(title: "Idag", steps: todaySteps)
                    Divider()
                    StepStatRow(title: "Förra veckan", steps: lastWeekSteps, subtitle: "Mån–Sön föregående vecka")
                    Divider()
                    StepStatRow(title: "Förra månaden", steps: lastMonthSteps)
                }
            }
        }
        .padding(16)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .drawingGroup() // GPU-accelerated rendering
        .onAppear {
            guard !hasInitialized else { return }
            hasInitialized = true
            if isAuthorized {
                loadStepData()
            } else {
                requestAuthorizationIfPossible()
            }
        }
    }
    
    private func requestAuthorization() {
        requestAuthorizationIfPossible()
    }
    
    private func requestAuthorizationIfPossible() {
        HealthKitManager.shared.requestAuthorization { granted in
            DispatchQueue.main.async {
                self.isAuthorized = granted
                if granted {
                    self.loadStepData()
                }
            }
        }
    }
    
    private func loadStepData() {
        guard isAuthorized else { return }
        isLoading = true
        pendingRequests = 3
        
        let calendar = Calendar(identifier: .iso8601)
        let now = Date()
        
        HealthKitManager.shared.getStepsForDate(now) { steps in
            self.todaySteps = steps
            self.markRequestComplete()
        }
        
        if let startOfCurrentWeek = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)),
           let startOfLastWeek = calendar.date(byAdding: .weekOfYear, value: -1, to: startOfCurrentWeek) {
            HealthKitManager.shared.getStepsTotal(from: startOfLastWeek, to: startOfCurrentWeek) { steps in
                self.lastWeekSteps = steps
                self.markRequestComplete()
            }
        } else {
            self.lastWeekSteps = 0
            markRequestComplete()
        }
        
        if let startOfCurrentMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: now)),
           let startOfLastMonth = calendar.date(byAdding: .month, value: -1, to: startOfCurrentMonth) {
            HealthKitManager.shared.getStepsTotal(from: startOfLastMonth, to: startOfCurrentMonth) { steps in
                self.lastMonthSteps = steps
                self.markRequestComplete()
            }
        } else {
            self.lastMonthSteps = 0
            markRequestComplete()
        }
    }
    
    private func markRequestComplete() {
        pendingRequests -= 1
        if pendingRequests <= 0 {
            isLoading = false
        }
    }
}

private struct StepStatRow: View {
    let title: String
    let steps: Int?
    var subtitle: String?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                Spacer()
                Text(formattedSteps)
                    .font(.system(size: 20, weight: .bold))
            }
            if let subtitle {
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            Text(kilometerText)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
        }
    }
    
    private var formattedSteps: String {
        guard let steps = steps else { return "--" }
        return NumberFormatter.stepsFormatter.string(from: NSNumber(value: steps)) ?? "\(steps)"
    }
    
    private var kilometerText: String {
        guard let steps = steps, steps > 0 else { return "Ingen data" }
        let kilometers = StepSyncService.convertStepsToKilometers(steps)
        return String(format: "≈ %.1f km", kilometers)
    }
}

private extension NumberFormatter {
    static let stepsFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        return formatter
    }()
}

private struct MonthlySummary {
    let totalSessions: Int
    let totalDurationSeconds: Int
    let totalVolumeKg: Double
    let highlightedDays: Set<Int>
    let monthStartDate: Date
}

struct MonthlyReportView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var allPosts: [WorkoutPost] = []
    @State private var last12MonthsData: [(month: Int, year: Int, hours: Double)] = [] // Last 12 months data
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var hasLoaded = false
    
    // Animation states
    @State private var showHeader = false
    @State private var showYearChart = false
    @State private var showTotals = false
    @State private var showCalendar = false
    @State private var showSports = false
    @State private var showLongest = false
    @State private var showKudos = false
    
    private let calendar = Calendar.current
    
    private let isoFormatterWithFraction: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }()
    
    private let isoFormatterWithoutFraction: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }()
    
    // Get last month's date
    private var lastMonthDate: Date {
        calendar.date(byAdding: .month, value: -1, to: Date()) ?? Date()
    }
    
    private var currentMonth: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "LLLL"
        formatter.locale = Locale(identifier: "sv_SE")
        return formatter.string(from: lastMonthDate).capitalized
    }
    
    private var currentYear: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy"
        return formatter.string(from: lastMonthDate)
    }
    
    private var monthPosts: [WorkoutPost] {
        // Get last month's start and end
        guard let startOfLastMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: lastMonthDate)),
              let startOfCurrentMonth = calendar.date(byAdding: .month, value: 1, to: startOfLastMonth) else {
            return []
        }
        return allPosts.filter { post in
            guard let date = parseDate(post.createdAt) else { return false }
            return date >= startOfLastMonth && date < startOfCurrentMonth
        }
    }
    
    private var totalDays: Int {
        Set(monthPosts.compactMap { post -> Int? in
            guard let date = parseDate(post.createdAt) else { return nil }
            return calendar.component(.day, from: date)
        }).count
    }
    
    private var totalHours: Double {
        Double(monthPosts.reduce(0) { $0 + ($1.duration ?? 0) }) / 3600.0
    }
    
    private var totalDistance: Double {
        monthPosts.reduce(0) { $0 + ($1.distance ?? 0) } / 1000.0
    }
    
    private var totalElevation: Double {
        monthPosts.reduce(0) { $0 + ($1.elevationGain ?? 0) }
    }
    
    // Total kg lifted from gym sessions
    private var totalKgLifted: Double {
        monthPosts.reduce(0.0) { total, post in
            guard let exercises = post.exercises else { return total }
            let postKg = exercises.reduce(0.0) { exerciseTotal, exercise in
                // Sum all kg × reps for each set
                let exerciseVolume = zip(exercise.kg, exercise.reps).reduce(0.0) { setTotal, pair in
                    setTotal + (pair.0 * Double(pair.1))
                }
                return exerciseTotal + exerciseVolume
            }
            return total + postKg
        }
    }
    
    private var longestActivity: WorkoutPost? {
        monthPosts.max(by: { ($0.distance ?? 0) < ($1.distance ?? 0) })
    }
    
    private var highlightedDays: Set<Int> {
        Set(monthPosts.compactMap { post -> Int? in
            guard let date = parseDate(post.createdAt) else { return nil }
            return calendar.component(.day, from: date)
        })
    }
    
    private var sportBreakdown: [(type: String, count: Int, percentage: Double, color: Color)] {
        var counts: [String: Int] = [:]
        for post in monthPosts {
            let type = post.activityType
            counts[type, default: 0] += 1
        }
        let total = counts.values.reduce(0, +)
        guard total > 0 else { return [] }
        
        let colors: [Color] = [.primary, Color(.systemGray2), Color(.systemGray4), Color(.systemGray5)]
        return counts.sorted { $0.value > $1.value }.enumerated().map { index, item in
            (type: item.key, count: item.value, percentage: Double(item.value) / Double(total) * 100, color: colors[index % colors.count])
        }
    }
    
    private var topSport: String {
        sportBreakdown.first?.type ?? "Träning"
    }
    
    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: 0) {
                    if isLoading {
                        loadingView
                            .frame(width: geometry.size.width, height: geometry.size.height)
                    } else if let errorMessage {
                        errorView(errorMessage)
                            .frame(width: geometry.size.width, height: geometry.size.height)
                    } else {
                        // Black header section - elegant fade and scale
                        headerSection(geometry: geometry)
                            .opacity(showHeader ? 1 : 0)
                            .scaleEffect(showHeader ? 1 : 0.97)
                        
                        // Year chart - slide up with fade
                        yearChartSection(geometry: geometry)
                            .opacity(showYearChart ? 1 : 0)
                            .offset(y: showYearChart ? 0 : 25)
                            .scaleEffect(showYearChart ? 1 : 0.98)
                        
                        // Month totals - elegant reveal
                        monthTotalsSection(geometry: geometry)
                            .opacity(showTotals ? 1 : 0)
                            .offset(y: showTotals ? 0 : 25)
                            .scaleEffect(showTotals ? 1 : 0.98)
                        
                        // Calendar - smooth appearance
                        calendarSection(geometry: geometry)
                            .opacity(showCalendar ? 1 : 0)
                            .offset(y: showCalendar ? 0 : 25)
                            .scaleEffect(showCalendar ? 1 : 0.98)
                        
                        // Top Sports - refined animation
                        topSportsSection(geometry: geometry)
                            .opacity(showSports ? 1 : 0)
                            .offset(y: showSports ? 0 : 25)
                            .scaleEffect(showSports ? 1 : 0.98)
                        
                        // Longest Activity - gentle reveal
                        longestActivitySection(geometry: geometry)
                            .opacity(showLongest ? 1 : 0)
                            .offset(y: showLongest ? 0 : 25)
                            .scaleEffect(showLongest ? 1 : 0.98)
                        
                        // Kudos section - final elegant touch
                        kudosSection(geometry: geometry)
                            .opacity(showKudos ? 1 : 0)
                            .offset(y: showKudos ? 0 : 25)
                            .scaleEffect(showKudos ? 1 : 0.98)
                    }
                }
            }
        }
        .background(Color(.systemBackground))
        .navigationTitle("Månadsrecap")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if !hasLoaded {
                hasLoaded = true
                await loadData()
                animateMonthlyContent()
            }
        }
        .onAppear {
            if hasLoaded {
                animateMonthlyContent()
            }
        }
    }
    
    private func animateMonthlyContent() {
        // Reset states first
        showHeader = false
        showYearChart = false
        showTotals = false
        showCalendar = false
        showSports = false
        showLongest = false
        showKudos = false
        
        // Elegant staggered animations with smooth spring curves
        withAnimation(.spring(response: 0.6, dampingFraction: 0.85)) {
            showHeader = true
        }
        
        withAnimation(.spring(response: 0.6, dampingFraction: 0.85).delay(0.12)) {
            showYearChart = true
        }
        
        withAnimation(.spring(response: 0.6, dampingFraction: 0.85).delay(0.22)) {
            showTotals = true
        }
        
        withAnimation(.spring(response: 0.6, dampingFraction: 0.85).delay(0.32)) {
            showCalendar = true
        }
        
        withAnimation(.spring(response: 0.6, dampingFraction: 0.85).delay(0.42)) {
            showSports = true
        }
        
        withAnimation(.spring(response: 0.6, dampingFraction: 0.85).delay(0.52)) {
            showLongest = true
        }
        
        withAnimation(.spring(response: 0.6, dampingFraction: 0.85).delay(0.62)) {
            showKudos = true
        }
    }
    
    // MARK: - Header Section
    private func headerSection(geometry: GeometryProxy) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(authViewModel.currentUser?.name.uppercased() ?? "DIN RECAP")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.white)
                .tracking(2)
            
            Spacer()
            
            VStack(alignment: .leading, spacing: -10) {
                Text(currentMonth)
                    .font(.system(size: min(geometry.size.width * 0.16, 60), weight: .light))
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                Text(currentYear)
                    .font(.system(size: min(geometry.size.width * 0.16, 60), weight: .light))
                    .foregroundColor(.gray.opacity(0.6))
                    .lineLimit(1)
            }
            
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 40)
        .frame(maxWidth: .infinity, minHeight: geometry.size.height * 0.7, alignment: .leading)
        .background(Color.black)
    }
    
    // MARK: - Year Chart Section
    private func yearChartSection(geometry: GeometryProxy) -> some View {
        let screenWidth = geometry.size.width
        let barWidth = max(8, (screenWidth - 60) / 14)
        let maxHours = max(last12MonthsData.map { $0.hours }.max() ?? 1, 1)
        let lastMonthComponent = calendar.component(.month, from: lastMonthDate)
        let lastYearComponent = calendar.component(.year, from: lastMonthDate)
        
        return VStack(spacing: 0) {
            Spacer()
            HStack(alignment: .bottom, spacing: 2) {
                ForEach(Array(last12MonthsData.enumerated()), id: \.offset) { index, data in
                    let isCurrentMonth = data.month == lastMonthComponent && data.year == lastYearComponent
                    let barHeight: CGFloat = 120
                    let height = maxHours > 0 ? (data.hours / maxHours) * barHeight : 0
                    
                    VStack(spacing: 6) {
                        // Show hours label for current month or if hours > 0 and is highlighted
                        if isCurrentMonth && data.hours > 0 {
                            HStack(spacing: 2) {
                                Circle()
                                    .fill(Color.orange)
                                    .frame(width: 6, height: 6)
                                Text("\(Int(data.hours)) HRS")
                                    .font(.system(size: 8, weight: .bold))
                                    .foregroundColor(.white)
                            }
                            .fixedSize()
                        }
                        
                        RoundedRectangle(cornerRadius: 2)
                            .fill(isCurrentMonth ? Color.white : Color.white.opacity(0.3))
                            .frame(width: barWidth, height: max(4, height))
                        
                        Text(monthAbbreviation(data.month))
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(isCurrentMonth ? .orange : .white.opacity(0.5))
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, 16)
            Spacer()
        }
        .frame(maxWidth: .infinity, minHeight: 220)
        .background(Color.black)
    }
    
    // MARK: - Month Totals Section
    private func monthTotalsSection(geometry: GeometryProxy) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("SAMMANFATTNING")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.primary)
                .tracking(1)
            
            HStack(alignment: .top, spacing: 12) {
                // Large Days on the left
                VStack(alignment: .leading, spacing: 0) {
                    Rectangle()
                        .fill(Color.primary)
                        .frame(height: 2)
                        .padding(.bottom, 6)
                    
                    HStack {
                        Spacer()
                        Text("DAGAR")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.gray)
                    }
                    
                    Text("\(totalDays)")
                        .font(.system(size: min(geometry.size.width * 0.22, 90), weight: .thin))
                        .foregroundColor(.primary)
                        .minimumScaleFactor(0.5)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity)
                
                // Other stats on the right
                VStack(alignment: .leading, spacing: 0) {
                    // Hours
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(height: 1)
                    HStack {
                        Image(systemName: "clock")
                            .font(.system(size: 14))
                            .foregroundColor(.primary)
                        Text(String(format: "%.0f", totalHours))
                            .font(.system(size: 24, weight: .regular))
                            .foregroundColor(.primary)
                        Spacer()
                        Text("TIM")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.gray)
                    }
                    .padding(.vertical, 12)
                    
                    // Distance
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(height: 1)
                    HStack {
                        Image(systemName: "location.north.fill")
                            .font(.system(size: 14))
                            .foregroundColor(.primary)
                            .rotationEffect(.degrees(45))
                        Text(String(format: "%.1f", totalDistance))
                            .font(.system(size: 24, weight: .regular))
                            .foregroundColor(.primary)
                        Spacer()
                        Text("KM")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.gray)
                    }
                    .padding(.vertical, 12)
                    
                    // Total KG lifted
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(height: 1)
                    HStack {
                        Image(systemName: "dumbbell.fill")
                            .font(.system(size: 14))
                            .foregroundColor(.primary)
                        Text(formatKg(totalKgLifted))
                            .font(.system(size: 24, weight: .regular))
                            .foregroundColor(.primary)
                        Spacer()
                        Text("KG")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.gray)
                    }
                    .padding(.vertical, 12)
                    
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(height: 1)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 30)
        .frame(maxWidth: .infinity)
        .background(Color(.systemBackground))
    }
    
    // Helper to format large KG numbers
    private func formatKg(_ kg: Double) -> String {
        if kg >= 1000 {
            return String(format: "%.1fk", kg / 1000)
        } else {
            return String(format: "%.0f", kg)
        }
    }
    
    // MARK: - Calendar Section
    private func calendarSection(geometry: GeometryProxy) -> some View {
        let weekdaySymbols = ["M", "T", "W", "T", "F", "S", "S"]
        let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: lastMonthDate))!
        let daysInMonth = calendar.range(of: .day, in: .month, for: startOfMonth)?.count ?? 30
        let rawWeekday = calendar.component(.weekday, from: startOfMonth)
        let leadingDays = rawWeekday == 1 ? 6 : rawWeekday - 2
        let cellSize: CGFloat = min((geometry.size.width - 80) / 7, 36)
        
        return VStack(alignment: .leading, spacing: 20) {
            HStack {
                ForEach(weekdaySymbols, id: \.self) { symbol in
                    Text(symbol)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.gray)
                        .frame(maxWidth: .infinity)
                }
            }
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7), spacing: 16) {
                ForEach(0..<leadingDays, id: \.self) { _ in
                    Circle()
                        .fill(Color.clear)
                        .frame(width: 4, height: 4)
                }
                
                ForEach(1...daysInMonth, id: \.self) { day in
                    if highlightedDays.contains(day) {
                        ZStack {
                            Circle()
                                .fill(Color.primary)
                                .frame(width: cellSize, height: cellSize)
                            Text("\(day)")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(Color(.systemBackground))
                        }
                    } else {
                        Circle()
                            .fill(Color(.systemGray4))
                            .frame(width: 5, height: 5)
                    }
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 30)
        .frame(maxWidth: .infinity)
        .background(Color(.systemBackground))
    }
    
    // MARK: - Top Sports Section
    private func topSportsSection(geometry: GeometryProxy) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("DINA SPORTER")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.primary)
                .tracking(1)
            
            Text(topSport)
                .font(.system(size: min(geometry.size.width * 0.18, 70), weight: .thin))
                .foregroundColor(.primary)
                .minimumScaleFactor(0.5)
                .lineLimit(1)
            
            if !sportBreakdown.isEmpty {
                // Legend - wrapped
                FlowLayout(spacing: 12) {
                    ForEach(sportBreakdown, id: \.type) { sport in
                        HStack(spacing: 6) {
                            Circle()
                                .fill(sport.color)
                                .frame(width: 8, height: 8)
                            Image(systemName: sportIcon(for: sport.type))
                                .font(.system(size: 12))
                                .foregroundColor(.primary)
                            Text("\(Int(sport.percentage))%")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.gray)
                        }
                    }
                }
                .padding(.vertical, 8)
                
                // Stacked bar
                GeometryReader { barGeometry in
                    HStack(spacing: 0) {
                        ForEach(sportBreakdown, id: \.type) { sport in
                            Rectangle()
                                .fill(sport.color)
                                .frame(width: barGeometry.size.width * (sport.percentage / 100))
                        }
                    }
                    .cornerRadius(4)
                }
                .frame(height: 80)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 40)
        .frame(maxWidth: .infinity)
        .background(Color(.systemGroupedBackground))
    }
    
    // MARK: - Longest Activity Section
    @ViewBuilder
    private func longestActivitySection(geometry: GeometryProxy) -> some View {
        if let post = longestActivity {
            VStack(alignment: .leading, spacing: 16) {
                Text("LÄNGSTA AKTIVITET")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.primary)
                    .tracking(1)
                    .padding(.horizontal, 20)
                
                ZStack(alignment: .bottomLeading) {
                    if let imageUrl = post.imageUrl, let url = URL(string: imageUrl) {
                        AsyncImage(url: url) { image in
                            image
                                .resizable()
                                .scaledToFill()
                        } placeholder: {
                            Rectangle()
                                .fill(Color.gray.opacity(0.1))
                        }
                        .frame(width: geometry.size.width, height: 350)
                        .clipped()
                    } else {
                        Rectangle()
                            .fill(Color.gray.opacity(0.2))
                            .frame(width: geometry.size.width, height: 350)
                            .overlay(
                                Image(systemName: "map.fill")
                                    .font(.system(size: 50))
                                    .foregroundColor(.gray)
                            )
                    }
                    
                    // Overlay info
                    VStack(alignment: .leading, spacing: 6) {
                        Text(post.title)
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.white)
                            .lineLimit(1)
                        
                        HStack(spacing: 12) {
                            Image(systemName: "calendar")
                                .font(.system(size: 12))
                            Text(formatActivityDate(post.createdAt))
                                .font(.system(size: 13, weight: .medium))
                        }
                        .foregroundColor(.white.opacity(0.9))
                        
                        HStack(spacing: 12) {
                            Image(systemName: "location")
                                .font(.system(size: 12))
                            if let distance = post.distance {
                                Text("\(String(format: "%.1f", distance / 1000)) km")
                                    .font(.system(size: 13, weight: .medium))
                            }
                            if let elevation = post.elevationGain {
                                Text("\(String(format: "%.0f", elevation)) m")
                                    .font(.system(size: 13, weight: .medium))
                            }
                        }
                        .foregroundColor(.white.opacity(0.9))
                    }
                    .padding(20)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        LinearGradient(colors: [.black.opacity(0.85), .clear], startPoint: .bottom, endPoint: .top)
                    )
                }
            }
            .padding(.top, 20)
            .frame(maxWidth: .infinity)
            .background(Color(.systemBackground))
        }
    }
    
    // MARK: - Kudos Section
    private func kudosSection(geometry: GeometryProxy) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            Spacer()
            
            Text("Bra jobbat, \(authViewModel.currentUser?.name ?? "du")!")
                .font(.system(size: min(geometry.size.width * 0.11, 44), weight: .light))
                .foregroundColor(.primary)
                .minimumScaleFactor(0.6)
                .lineLimit(2)
            
            Text("Du har tränat \(totalDays) \(totalDays == 1 ? "dag" : "dagar") denna \(currentMonth.lowercased()).")
                .font(.system(size: 17))
                .foregroundColor(.gray)
            
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 60)
        .frame(maxWidth: .infinity, minHeight: 300)
        .background(Color(.systemBackground))
    }
    
    // Simple flow layout for wrapping
    private struct FlowLayout: Layout {
        var spacing: CGFloat = 8
        
        func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
            let result = layout(subviews: subviews, proposal: proposal)
            return result.size
        }
        
        func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
            let result = layout(subviews: subviews, proposal: proposal)
            for (index, frame) in result.frames.enumerated() {
                subviews[index].place(at: CGPoint(x: bounds.minX + frame.minX, y: bounds.minY + frame.minY), proposal: .unspecified)
            }
        }
        
        private func layout(subviews: Subviews, proposal: ProposedViewSize) -> (size: CGSize, frames: [CGRect]) {
            var frames: [CGRect] = []
            var x: CGFloat = 0
            var y: CGFloat = 0
            var lineHeight: CGFloat = 0
            let maxWidth = proposal.width ?? .infinity
            
            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)
                if x + size.width > maxWidth && x > 0 {
                    x = 0
                    y += lineHeight + spacing
                    lineHeight = 0
                }
                frames.append(CGRect(origin: CGPoint(x: x, y: y), size: size))
                lineHeight = max(lineHeight, size.height)
                x += size.width + spacing
            }
            
            return (CGSize(width: maxWidth, height: y + lineHeight), frames)
        }
    }
    
    // MARK: - Loading & Error Views
    private var loadingView: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text("Hämtar din månadsrecap…")
                .font(.callout)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 400)
    }
    
    private func errorView(_ message: String) -> some View {
        VStack(spacing: 12) {
            Text(message)
                .font(.callout)
                .foregroundColor(.primary)
                .multilineTextAlignment(.center)
            Button(action: {
                Task { await loadData() }
            }) {
                Text("Försök igen")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 10)
                    .background(Color.primary)
                    .clipShape(Capsule())
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
    }
    
    // MARK: - Helper Functions
    private func loadData() async {
        guard let userId = authViewModel.currentUser?.id else {
            await MainActor.run {
                self.errorMessage = "Kunde inte hämta användaruppgifter."
                self.isLoading = false
            }
            return
        }
        
        await MainActor.run {
            self.isLoading = true
            self.errorMessage = nil
        }
        
        do {
            let posts = try await WorkoutService.shared.getUserWorkoutPosts(userId: userId, forceRefresh: true)
            
            // Calculate last 12 months data
            var monthlyHours: [String: Double] = [:] // "YYYY-MM" -> hours
            
            // Get the last 12 months
            var last12Months: [(month: Int, year: Int, hours: Double)] = []
            let now = Date()
            
            for i in 0..<12 {
                if let date = calendar.date(byAdding: .month, value: -i, to: now) {
                    let month = calendar.component(.month, from: date)
                    let year = calendar.component(.year, from: date)
                    let key = "\(year)-\(month)"
                    monthlyHours[key] = 0
                }
            }
            
            // Sum hours for each month
            for post in posts {
                guard let date = parseDate(post.createdAt) else { continue }
                let month = calendar.component(.month, from: date)
                let year = calendar.component(.year, from: date)
                let key = "\(year)-\(month)"
                
                if monthlyHours[key] != nil {
                    let hours = Double(post.duration ?? 0) / 3600.0
                    monthlyHours[key, default: 0] += hours
                }
            }
            
            // Build the array in chronological order (oldest first)
            for i in (0..<12).reversed() {
                if let date = calendar.date(byAdding: .month, value: -i, to: now) {
                    let month = calendar.component(.month, from: date)
                    let year = calendar.component(.year, from: date)
                    let key = "\(year)-\(month)"
                    let hours = monthlyHours[key] ?? 0
                    last12Months.append((month: month, year: year, hours: hours))
                }
            }
            
            await MainActor.run {
                self.allPosts = posts
                self.last12MonthsData = last12Months
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "Kunde inte hämta statistik just nu."
                self.isLoading = false
            }
        }
    }
    
    private func parseDate(_ isoString: String) -> Date? {
        if let date = isoFormatterWithFraction.date(from: isoString) {
            return date
        }
        return isoFormatterWithoutFraction.date(from: isoString)
    }
    
    private func formatActivityDate(_ isoString: String) -> String {
        let date = parseDate(isoString) ?? Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM d, yyyy"
        formatter.locale = Locale(identifier: "sv_SE")
        return formatter.string(from: date)
    }
    
    private func volumeFromExercises(_ exercises: [GymExercisePost]?) -> Double {
        guard let exercises else { return 0 }
        return exercises.reduce(0) { runningTotal, exercise in
            let setVolume = zip(exercise.kg, exercise.reps).reduce(0.0) { $0 + $1.0 * Double($1.1) }
            return runningTotal + setVolume
        }
    }
    
    private func monthAbbreviation(_ month: Int) -> String {
        let abbreviations = ["", "JAN", "FEB", "MAR", "APR", "MAY", "JUN", "JUL", "AUG", "SEP", "OCT", "NOV", "DEC"]
        return abbreviations[month]
    }
    
    private func sportIcon(for type: String) -> String {
        switch type.lowercased() {
        case "run", "löpning", "running": return "figure.run"
        case "swim", "simning", "swimming": return "figure.pool.swim"
        case "cycle", "cykling", "cycling": return "figure.outdoor.cycle"
        case "gym", "gympass", "strength": return "dumbbell.fill"
        case "golf": return "figure.golf"
        default: return "figure.walk"
        }
    }
}

private struct MonthlyStatCard: View {
    let title: String
    let value: String
    let subtitle: String
    var icon: String = "chart.bar.fill"
    var color: Color = .primary
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(color)
            
            Text(value)
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 8)
        .frame(maxWidth: .infinity)
        .background(Color(.systemBackground))
        .cornerRadius(14)
        .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 4)
    }
}

private struct MonthlyCalendarView: View {
    let monthStart: Date
    let highlightedDays: Set<Int>
    
    private let calendar = Calendar.current
    private let weekdaySymbols = ["Mån", "Tis", "Ons", "Tor", "Fre", "Lör", "Sön"]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Weekday headers
            HStack {
                ForEach(weekdaySymbols, id: \.self) { symbol in
                    Text(symbol)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 7), spacing: 10) {
                ForEach(0..<leadingEmptyDays, id: \.self) { _ in
                    Rectangle()
                        .foregroundColor(.clear)
                        .frame(height: 36)
                }
                
                ForEach(1...daysInMonth, id: \.self) { day in
                    dayCell(for: day)
                }
            }
        }
    }
    
    private var daysInMonth: Int {
        calendar.range(of: .day, in: .month, for: monthStart)?.count ?? 30
    }
    
    private var leadingEmptyDays: Int {
        let weekday = calendar.component(.weekday, from: monthStart)
        return (weekday + 5) % 7
    }
    
    private func dayCell(for day: Int) -> some View {
        let date = calendar.date(byAdding: .day, value: day - 1, to: monthStart) ?? monthStart
        let today = Date()
        let isFuture = date > today
        let isHighlighted = highlightedDays.contains(day)
        let isToday = calendar.isDateInToday(date)
        
        return Text("\(day)")
            .font(.system(size: 15, weight: isHighlighted || isToday ? .bold : .medium))
            .frame(width: 36, height: 36)
            .background(
                ZStack {
                    if isHighlighted {
                        Circle()
                            .fill(Color.green)
                    } else if isToday {
                        Circle()
                            .stroke(Color.primary, lineWidth: 2)
                    } else if !isFuture {
                        Circle()
                            .fill(Color(.systemGray6))
                    }
                }
            )
            .foregroundColor(isHighlighted ? .white : (isFuture ? .secondary.opacity(0.4) : .primary))
    }
}

// MARK: - Progressive Overload Supporting Types

struct StatSetSnapshot: Identifiable {
    let id = UUID()
    let weight: Double
    let reps: Int
    
    var estimated1RM: Double {
        guard reps > 0 else { return weight }
        if reps == 1 { return weight }
        return weight * (1 + Double(reps) / 30.0)
    }
}

struct StatExerciseSnapshot: Identifiable {
    let id = UUID()
    let date: Date
    let bestSet: StatSetSnapshot
    let sets: [StatSetSnapshot]
    let category: String?
    
    var estimated1RM: Double {
        bestSet.estimated1RM
    }
}

struct StatExerciseHistory: Identifiable {
    let id = UUID()
    let name: String
    let category: String?
    let exerciseId: String?
    let history: [StatExerciseSnapshot]
    
    var latestSnapshot: StatExerciseSnapshot? { history.last }
    
    var personalBestWeight: Double? {
        history.flatMap { $0.sets }.map { $0.weight }.max()
    }
    
    var trendPercentage: Double {
        guard history.count >= 2 else { return 0 }
        let firstWeight = history.first?.bestSet.weight ?? 0
        let lastWeight = history.last?.bestSet.weight ?? 0
        return firstWeight > 0 ? ((lastWeight - firstWeight) / firstWeight) * 100 : 0
    }
    
    var trendMessage: String {
        let change = trendPercentage
        if change > 5 {
            return "+\(String(format: "%.0f", change))%"
        } else if change > 0 {
            return "+\(String(format: "%.1f", change))%"
        } else if change < -5 {
            return "\(String(format: "%.0f", change))%"
        } else if change < 0 {
            return "\(String(format: "%.1f", change))%"
        } else {
            return "Platå"
        }
    }
    
    var trendColor: Color {
        let change = trendPercentage
        if change > 0 { return .green }
        if change < 0 { return .secondary }
        return .gray
    }
    
    var trendIcon: String {
        let change = trendPercentage
        if change > 5 { return "flame.fill" }
        if change > 0 { return "arrow.up.right" }
        if change < 0 { return "arrow.down.right" }
        return "pause.fill"
    }
    
    // MARK: - 1RM Predictions
    
    /// Current 1RM = the HEAVIEST weight the user has actually lifted
    var current1RM: Double {
        // Find the heaviest weight lifted across all history
        let allWeights = history.flatMap { $0.sets }.map { $0.weight }
        return allWeights.max() ?? 0
    }
    
    /// Latest 1RM = heaviest weight from most recent workout
    var latest1RM: Double {
        latestSnapshot?.bestSet.weight ?? 0
    }
    
    /// Max weight from 30 days ago (or earliest if less than 30 days of data)
    var thirtyDaysAgo1RM: Double? {
        let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        // Find snapshot closest to 30 days ago
        let oldSnapshots = history.filter { $0.date <= thirtyDaysAgo }
        return oldSnapshots.last?.bestSet.weight ?? history.first?.bestSet.weight
    }
    
    /// Change in max weight over last 30 days (in kg)
    var thirtyDayChange: Double {
        guard let old1RM = thirtyDaysAgo1RM, old1RM > 0 else { return 0 }
        return latest1RM - old1RM
    }
    
    /// Monthly progression rate (kg per month) based on historical data
    var monthlyProgressionRate: Double {
        guard history.count >= 2,
              let firstDate = history.first?.date,
              let lastDate = history.last?.date else { return 0 }
        
        let firstWeight = history.first?.bestSet.weight ?? 0
        let lastWeight = history.last?.bestSet.weight ?? 0
        
        let daysDiff = Calendar.current.dateComponents([.day], from: firstDate, to: lastDate).day ?? 0
        guard daysDiff > 7 else { return 0 } // Need at least a week of data
        
        let monthsDiff = Double(daysDiff) / 30.0
        return (lastWeight - firstWeight) / max(monthsDiff, 0.5)
    }
    
    /// Predicted 1RM in 3 months
    var prediction3Months: Double {
        let rate = monthlyProgressionRate
        // Cap progression rate to realistic values (max ~2.5kg/month for most exercises)
        let cappedRate = min(max(rate, 0), 5.0)
        return latest1RM + (cappedRate * 3)
    }
    
    /// Predicted 1RM in 6 months
    var prediction6Months: Double {
        let rate = monthlyProgressionRate
        let cappedRate = min(max(rate, 0), 5.0)
        return latest1RM + (cappedRate * 6)
    }
    
    /// Predicted 1RM in 1 year
    var prediction1Year: Double {
        let rate = monthlyProgressionRate
        // Diminishing returns over longer periods - reduce rate by 20% for year prediction
        let cappedRate = min(max(rate * 0.8, 0), 4.0)
        return latest1RM + (cappedRate * 12)
    }
    
    /// Whether we have enough data to make predictions
    var canPredict: Bool {
        history.count >= 2 && monthlyProgressionRate > 0
    }
}

// MARK: - Exercise Row for Statistics
struct StatExerciseRow: View {
    let history: StatExerciseHistory
    var isLast: Bool = false
    var showTrend: Bool = true  // Option to hide trend badge
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 14) {
                // Exercise image from API
                if let exerciseId = history.exerciseId {
                    ExerciseGIFView(exerciseId: exerciseId, gifUrl: nil)
                        .frame(width: 56, height: 56)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                } else {
                    // Fallback gradient icon
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(
                                LinearGradient(
                                    colors: [Color.green.opacity(0.2), Color.green.opacity(0.1)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 56, height: 56)
                        
                        Image(systemName: "dumbbell.fill")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundColor(.green)
                    }
                }
                
                // Exercise info
                VStack(alignment: .leading, spacing: 4) {
                    Text(history.name)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    HStack(spacing: 6) {
                        if let category = history.category {
                            Text(category)
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                        }
                        
                        Text("•")
                            .font(.system(size: 8))
                            .foregroundColor(.secondary.opacity(0.4))
                        
                        Text("\(history.history.count) pass")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                // Weight only (clean look)
                if let bestWeight = history.personalBestWeight {
                    HStack(spacing: 2) {
                        Text("\(String(format: "%.0f", bestWeight))")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(.primary)
                        Text("kg")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                }
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.secondary.opacity(0.4))
            }
            .padding(.vertical, 14)
            .padding(.horizontal, 16)
            
            if !isLast {
                Divider()
                    .padding(.leading, 86)
            }
        }
    }
}

// MARK: - All Exercises List View
struct AllExercisesListView: View {
    @EnvironmentObject private var authViewModel: AuthViewModel
    private let providedHistories: [StatExerciseHistory]?
    @State private var loadedHistories: [StatExerciseHistory] = []
    @State private var isLoading = false
    @State private var searchText = ""
    @State private var showStats = false
    @State private var showSearch = false
    @State private var showList = false
    
    // Initialize with provided histories (from StatisticsView)
    init(exerciseHistories: [StatExerciseHistory]) {
        self.providedHistories = exerciseHistories
    }
    
    // Initialize without histories (will load its own - from SocialView)
    init() {
        self.providedHistories = nil
    }
    
    private var exerciseHistories: [StatExerciseHistory] {
        providedHistories ?? loadedHistories
    }
    
    private var filteredExercises: [StatExerciseHistory] {
        if searchText.isEmpty {
            return exerciseHistories
        }
        return exerciseHistories.filter { 
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            ($0.category?.localizedCaseInsensitiveContains(searchText) ?? false)
        }
    }
    
    var body: some View {
        ZStack {
            if isLoading && exerciseHistories.isEmpty {
                VStack(spacing: 16) {
                    ProgressView()
                    Text("Laddar övningar...")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
            } else {
                ScrollView {
                    VStack(spacing: 16) {
                        // Search bar
                        HStack(spacing: 10) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 16))
                                .foregroundColor(.secondary)
                            
                            TextField("Sök övning...", text: $searchText)
                                .font(.system(size: 16))
                                .foregroundColor(.primary)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                        )
                        .padding(.horizontal, 16)
                        .opacity(showSearch ? 1 : 0)
                        .offset(y: showSearch ? 0 : 10)
                        
                        // Exercise list
                        VStack(spacing: 0) {
                            ForEach(Array(filteredExercises.enumerated()), id: \.element.id) { index, history in
                                NavigationLink {
                                    StatExerciseDetailView(history: history)
                                } label: {
                                    CleanExerciseRow(history: history, isLast: index == filteredExercises.count - 1)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(16)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                        )
                        .padding(.horizontal, 16)
                        .padding(.bottom, 20)
                        .opacity(showList ? 1 : 0)
                        .offset(y: showList ? 0 : 15)
                    }
                    .padding(.top, 16)
                }
            }
        }
        .background(Color(.systemBackground))
        .navigationTitle("Alla övningar")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            // Only load if no histories were provided
            if providedHistories == nil {
                await loadExerciseHistories()
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.4)) {
                showStats = true
            }
            withAnimation(.easeOut(duration: 0.4).delay(0.1)) {
                showSearch = true
            }
            withAnimation(.easeOut(duration: 0.4).delay(0.2)) {
                showList = true
            }
        }
    }
    
    private func loadExerciseHistories() async {
        guard let userId = authViewModel.currentUser?.id else { return }
        
        await MainActor.run { isLoading = true }
        
        do {
            let posts = try await WorkoutService.shared.fetchUserWorkoutPosts(userId: userId)
            let gymPosts = posts.filter { $0.activityType.lowercased().contains("gym") }
            
            // Group by exercise name
            var exerciseDict: [String: (name: String, exerciseId: String?, snapshots: [StatExerciseSnapshot])] = [:]
            
            for post in gymPosts {
                guard let exercises = post.exercises else { continue }
                
                for exercise in exercises {
                    let normalizedName = exercise.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                    
                    // Build sets for this session
                    var sets: [StatSetSnapshot] = []
                    var bestSet: StatSetSnapshot?
                    
                    for i in 0..<min(exercise.reps.count, exercise.kg.count) {
                        let setSnapshot = StatSetSnapshot(weight: exercise.kg[i], reps: exercise.reps[i])
                        sets.append(setSnapshot)
                        
                        if bestSet == nil || exercise.kg[i] > bestSet!.weight || 
                           (exercise.kg[i] == bestSet!.weight && exercise.reps[i] > bestSet!.reps) {
                            bestSet = setSnapshot
                        }
                    }
                    
                    guard let best = bestSet else { continue }
                    
                    let sessionDate = ISO8601DateFormatter().date(from: post.createdAt) ?? Date()
                    
                    let snapshot = StatExerciseSnapshot(
                        date: sessionDate,
                        bestSet: best,
                        sets: sets,
                        category: nil
                    )
                    
                    if var existing = exerciseDict[normalizedName] {
                        existing.snapshots.append(snapshot)
                        existing.snapshots.sort { $0.date < $1.date }
                        exerciseDict[normalizedName] = existing
                    } else {
                        exerciseDict[normalizedName] = (
                            name: exercise.name,
                            exerciseId: exercise.id,
                            snapshots: [snapshot]
                        )
                    }
                }
            }
            
            // Convert to StatExerciseHistory array
            let histories: [StatExerciseHistory] = exerciseDict.values.map { item in
                StatExerciseHistory(
                    name: item.name,
                    category: nil,
                    exerciseId: item.exerciseId,
                    history: item.snapshots
                )
            }.sorted { $0.history.count > $1.history.count }
            
            await MainActor.run {
                loadedHistories = histories
                isLoading = false
            }
        } catch {
            print("❌ Error loading exercise histories: \(error)")
            await MainActor.run {
                isLoading = false
            }
        }
    }
}

// MARK: - Clean Exercise Row (White/Black/Green only)
private struct CleanExerciseRow: View {
    let history: StatExerciseHistory
    var isLast: Bool = false
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 14) {
                // Exercise image from API
                if let exerciseId = history.exerciseId {
                    ExerciseGIFView(exerciseId: exerciseId, gifUrl: nil)
                        .frame(width: 56, height: 56)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                } else {
                    // Fallback icon
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.primary.opacity(0.05))
                            .frame(width: 56, height: 56)
                        
                        Image(systemName: "dumbbell.fill")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundColor(.primary)
                    }
                }
                
                // Exercise info
                VStack(alignment: .leading, spacing: 4) {
                    Text(history.name)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    HStack(spacing: 6) {
                        if let category = history.category {
                            Text(category)
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                        }
                        
                        Text("•")
                            .font(.system(size: 8))
                            .foregroundColor(.secondary.opacity(0.5))
                        
                        Text("\(history.history.count) pass")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                // Weight only (clean look)
                if let bestWeight = history.personalBestWeight {
                    HStack(spacing: 2) {
                        Text("\(String(format: "%.0f", bestWeight))")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(.primary)
                        Text("kg")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                }
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.secondary.opacity(0.5))
            }
            .padding(.vertical, 14)
            .padding(.horizontal, 16)
            
            if !isLast {
                Rectangle()
                    .fill(Color.primary.opacity(0.08))
                    .frame(height: 1)
                    .padding(.leading, 86)
            }
        }
    }
}


// MARK: - Exercise Detail View with Chart
struct StatExerciseDetailView: View {
    let history: StatExerciseHistory
    
    @State private var showHero = false
    @State private var showStats = false
    @State private var showChart = false
    @State private var showHistory = false
    
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "sv_SE")
        formatter.dateFormat = "d MMM yyyy"
        return formatter
    }()
    
    private let shortDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "sv_SE")
        formatter.dateFormat = "d MMM"
        return formatter
    }()
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Hero card with image
                heroCard
                    .opacity(showHero ? 1 : 0)
                    .scaleEffect(showHero ? 1 : 0.95)
                
                // Stats grid
                statsGrid
                    .opacity(showStats ? 1 : 0)
                    .offset(y: showStats ? 0 : 15)
                
                // Chart
                if history.history.count >= 2 {
                    chartCard
                        .opacity(showChart ? 1 : 0)
                        .offset(y: showChart ? 0 : 15)
                }
                
                // History list
                historyCard
                    .opacity(showHistory ? 1 : 0)
                    .offset(y: showHistory ? 0 : 15)
            }
            .padding(16)
        }
        .background(Color(.systemBackground))
        .navigationTitle(history.name)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            withAnimation(.easeOut(duration: 0.4)) {
                showHero = true
            }
            withAnimation(.easeOut(duration: 0.4).delay(0.1)) {
                showStats = true
            }
            withAnimation(.easeOut(duration: 0.4).delay(0.2)) {
                showChart = true
            }
            withAnimation(.easeOut(duration: 0.4).delay(0.3)) {
                showHistory = true
            }
        }
    }
    
    private var heroCard: some View {
        VStack(spacing: 16) {
            // Exercise image
            if let exerciseId = history.exerciseId {
                ExerciseGIFView(exerciseId: exerciseId, gifUrl: nil)
                    .frame(width: 120, height: 120)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color.primary.opacity(0.05))
                        .frame(width: 120, height: 120)
                    
                    Image(systemName: "dumbbell.fill")
                        .font(.system(size: 44, weight: .medium))
                        .foregroundColor(.primary)
                }
            }
            
            VStack(spacing: 6) {
                Text(history.name)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
                
                if let category = history.category {
                    Text(category)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background(Color.primary.opacity(0.05))
                        .cornerRadius(8)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        )
    }
    
    private var statsGrid: some View {
        HStack(spacing: 12) {
            CleanStatCard(
                value: "\(String(format: "%.0f", history.latestSnapshot?.bestSet.weight ?? 0))",
                unit: "kg",
                label: "Senaste"
            )
            
            CleanStatCard(
                value: "\(String(format: "%.0f", history.personalBestWeight ?? 0))",
                unit: "kg",
                label: "Personbästa",
                isHighlighted: true
            )
            
            CleanStatCard(
                value: "\(history.history.count)",
                unit: "",
                label: "Pass"
            )
        }
    }
    
    private var chartCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Utvecklingskurva")
                .font(.system(size: 17, weight: .bold))
                .foregroundColor(.primary)
            
            // Simple line chart
            GeometryReader { geometry in
                let data = history.history
                let maxWeight = data.map { $0.bestSet.weight }.max() ?? 1
                let minWeight = data.map { $0.bestSet.weight }.min() ?? 0
                let range = maxWeight - minWeight > 0 ? maxWeight - minWeight : 1
                let chartWidth = geometry.size.width - 50
                let chartHeight: CGFloat = 180
                let pointSpacing = chartWidth / CGFloat(max(data.count - 1, 1))
                
                ZStack(alignment: .bottomLeading) {
                    // Grid lines
                    VStack(spacing: 0) {
                        ForEach(0..<4) { i in
                            Rectangle()
                                .fill(Color.primary.opacity(0.08))
                                .frame(height: 1)
                            if i < 3 { Spacer() }
                        }
                    }
                    .frame(height: chartHeight)
                    .padding(.trailing, 50)
                    
                    // Area fill with gradient
                    if data.count > 1 {
                        Path { path in
                            path.move(to: CGPoint(x: 0, y: chartHeight))
                            for (index, snapshot) in data.enumerated() {
                                let x = CGFloat(index) * pointSpacing
                                let normalizedY = (snapshot.bestSet.weight - minWeight) / range
                                let y = chartHeight - normalizedY * chartHeight
                                path.addLine(to: CGPoint(x: x, y: y))
                            }
                            path.addLine(to: CGPoint(x: CGFloat(data.count - 1) * pointSpacing, y: chartHeight))
                            path.closeSubpath()
                        }
                        .fill(
                            LinearGradient(
                                colors: [Color.green.opacity(0.3), Color.green.opacity(0.05)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        
                        // Line
                        Path { path in
                            for (index, snapshot) in data.enumerated() {
                                let x = CGFloat(index) * pointSpacing
                                let normalizedY = (snapshot.bestSet.weight - minWeight) / range
                                let y = chartHeight - normalizedY * chartHeight
                                if index == 0 {
                                    path.move(to: CGPoint(x: x, y: y))
                                } else {
                                    path.addLine(to: CGPoint(x: x, y: y))
                                }
                            }
                        }
                        .stroke(Color.green, style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                        
                        // Points
                        ForEach(data.indices, id: \.self) { index in
                            let x = CGFloat(index) * pointSpacing
                            let normalizedY = (data[index].bestSet.weight - minWeight) / range
                            let y = chartHeight - normalizedY * chartHeight
                            
                            Circle()
                                .fill(Color(.systemBackground))
                                .frame(width: 12, height: 12)
                                .overlay(
                                    Circle()
                                        .fill(Color.green)
                                        .frame(width: 8, height: 8)
                                )
                                .position(x: x, y: y)
                        }
                    }
                    
                    // Y-axis labels
                    VStack {
                        Text("\(Int(maxWeight)) kg")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("\(Int((maxWeight + minWeight) / 2)) kg")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("\(Int(minWeight)) kg")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                    .frame(height: chartHeight)
                    .offset(x: chartWidth + 10)
                }
                .frame(height: chartHeight)
            }
            .frame(height: 180)
        }
        .padding(20)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        )
    }
    
    private var historyCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Historik")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(.primary)
                
                Spacer()
                
                Text("\(history.history.count) pass")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.secondary)
            }
            
            ForEach(Array(history.history.enumerated().reversed()), id: \.element.id) { index, snapshot in
                let previousSnapshot: StatExerciseSnapshot? = index > 0 ? history.history[index - 1] : nil
                let isLatest = index == history.history.count - 1
                
                VStack(spacing: 0) {
                    HStack(spacing: 12) {
                        // Timeline indicator
                        Circle()
                            .fill(isLatest ? Color.green : Color.primary.opacity(0.2))
                            .frame(width: 10, height: 10)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(dateFormatter.string(from: snapshot.date))
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(isLatest ? .primary : .secondary)
                            
                            Text("\(String(format: "%.1f", snapshot.bestSet.weight)) kg × \(snapshot.bestSet.reps) reps")
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing, spacing: 4) {
                            HStack(spacing: 2) {
                                Text("\(String(format: "%.0f", snapshot.bestSet.weight))")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(isLatest ? .primary : .secondary)
                                Text("kg")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.secondary)
                            }
                            
                            if let prev = previousSnapshot {
                                let delta = snapshot.bestSet.weight - prev.bestSet.weight
                                let sign = delta >= 0 ? "+" : ""
                                Text("\(sign)\(String(format: "%.1f", delta)) kg")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(delta >= 0 ? .green : .secondary)
                            }
                        }
                    }
                    .padding(.vertical, 12)
                    
                    if index > 0 {
                        Rectangle()
                            .fill(Color.primary.opacity(0.08))
                            .frame(height: 1)
                            .padding(.leading, 22)
                    }
                }
            }
        }
        .padding(20)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        )
    }
}

// MARK: - Clean Stat Card (Adaptive colors)
private struct CleanStatCard: View {
    let value: String
    let unit: String
    let label: String
    var isHighlighted: Bool = false
    
    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 2) {
                Text(value)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(isHighlighted ? .green : .primary)
                if !unit.isEmpty {
                    Text(unit)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                }
            }
            
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        )
    }
}

// MARK: - 1RM Prediction Row (Strava-style)
struct OneRMPredictionRow: View {
    let history: StatExerciseHistory
    var aiPrediction: OneRepMaxPredictionService.AIPrediction? = nil
    var isLast: Bool = false
    
    // Show 1-year prediction as the main value
    private var prediction1Year: Double {
        aiPrediction?.prediction1Year ?? history.prediction1Year
    }
    
    private var current1RM: Double {
        aiPrediction?.current1RM ?? history.latest1RM
    }
    
    private var increase: Double {
        prediction1Year - current1RM
    }
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 14) {
                // Exercise GIF with clean rounded corners
                if let exerciseId = history.exerciseId {
                    ExerciseGIFView(exerciseId: exerciseId, gifUrl: nil)
                        .frame(width: 52, height: 52)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                } else {
                    // Fallback icon
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.gray.opacity(0.1))
                            .frame(width: 52, height: 52)
                        Image(systemName: "dumbbell.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.gray)
                    }
                }
                
                // Exercise name and current
                VStack(alignment: .leading, spacing: 3) {
                    Text(history.name)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    Text("Nu: \(String(format: "%.0f", current1RM)) kg")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // 1-year prediction as main value
                VStack(alignment: .trailing, spacing: 3) {
                    HStack(spacing: 2) {
                        Text("\(String(format: "%.0f", prediction1Year))")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.primary)
                        Text("kg")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                    
                    HStack(spacing: 3) {
                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 10, weight: .semibold))
                        Text("+\(String(format: "%.0f", increase)) kg")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundColor(.green)
                }
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.secondary.opacity(0.3))
            }
            .padding(.vertical, 14)
            .padding(.horizontal, 16)
            
            if !isLast {
                Divider()
                    .padding(.leading, 86)
            }
        }
    }
}

// Wavy circle shape (like Strava's distance badges)
struct WavyCircleShape: Shape {
    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2
        let waveCount = 12
        let waveDepth: CGFloat = 3
        
        var path = Path()
        
        for i in 0..<360 {
            let angle = Double(i) * .pi / 180
            let wave = sin(Double(i * waveCount) * .pi / 180) * waveDepth
            let r = radius + wave
            let x = center.x + r * cos(angle)
            let y = center.y + r * sin(angle)
            
            if i == 0 {
                path.move(to: CGPoint(x: x, y: y))
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }
        path.closeSubpath()
        
        return path
    }
}

// MARK: - All 1RM Predictions View
struct All1RMPredictionsView: View {
    let exerciseHistories: [StatExerciseHistory]
    var aiPredictions: [OneRepMaxPredictionService.AIPrediction] = []
    @State private var searchText = ""
    @State private var showContent = false
    
    private var filteredExercises: [StatExerciseHistory] {
        if searchText.isEmpty {
            return exerciseHistories
        }
        return exerciseHistories.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            ($0.category?.localizedCaseInsensitiveContains(searchText) ?? false)
        }
    }
    
    private func getPrediction(for exerciseName: String) -> OneRepMaxPredictionService.AIPrediction? {
        aiPredictions.first { $0.exerciseName.lowercased() == exerciseName.lowercased() }
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Search bar
                HStack(spacing: 12) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.secondary)
                    
                    TextField("Sök övning...", text: $searchText)
                        .font(.system(size: 16))
                        .foregroundColor(.primary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color(.secondarySystemBackground))
                .cornerRadius(12)
                .padding(.horizontal, 16)
                
                // Exercise list
                VStack(spacing: 0) {
                    ForEach(Array(filteredExercises.enumerated()), id: \.element.id) { index, history in
                        let aiPrediction = getPrediction(for: history.name)
                        NavigationLink {
                            OneRepMaxDetailView(history: history, aiPrediction: aiPrediction)
                        } label: {
                            OneRMPredictionRow(
                                history: history, 
                                aiPrediction: aiPrediction,
                                isLast: index == filteredExercises.count - 1
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .background(Color(.secondarySystemBackground))
                .cornerRadius(20)
                .padding(.horizontal, 16)
            }
            .padding(.top, 16)
            .opacity(showContent ? 1 : 0)
            .offset(y: showContent ? 0 : 15)
        }
        .background(Color(.systemBackground))
        .navigationTitle("1RM Prediktioner")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            withAnimation(.easeOut(duration: 0.4)) {
                showContent = true
            }
        }
    }
}

// MARK: - 1RM Detail View with Future Predictions
struct OneRepMaxDetailView: View {
    let history: StatExerciseHistory
    var aiPrediction: OneRepMaxPredictionService.AIPrediction? = nil
    
    @State private var showHero = false
    @State private var showCurrent = false
    @State private var showPredictions = false
    @State private var showChart = false
    @State private var showTips = false
    
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "sv_SE")
        formatter.dateFormat = "d MMM yyyy"
        return formatter
    }()
    
    // Use AI predictions if available, fallback to formula-based
    private var current1RM: Double {
        aiPrediction?.current1RM ?? history.latest1RM
    }
    
    private var prediction3M: Double {
        aiPrediction?.prediction3Months ?? history.prediction3Months
    }
    
    private var prediction6M: Double {
        aiPrediction?.prediction6Months ?? history.prediction6Months
    }
    
    private var prediction1Y: Double {
        aiPrediction?.prediction1Year ?? history.prediction1Year
    }
    
    private var monthlyRate: Double {
        aiPrediction?.monthlyProgressRate ?? history.monthlyProgressionRate
    }
    
    private var hasAIPrediction: Bool {
        aiPrediction != nil
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Hero card with exercise image
                heroCard
                    .opacity(showHero ? 1 : 0)
                    .scaleEffect(showHero ? 1 : 0.95)
                
                // Current 1RM card
                current1RMCard
                    .opacity(showCurrent ? 1 : 0)
                    .offset(y: showCurrent ? 0 : 15)
                
                // AI Tips card (if available)
                if let tips = aiPrediction?.tips, !tips.isEmpty {
                    aiTipsCard(tips: tips)
                        .opacity(showTips ? 1 : 0)
                        .offset(y: showTips ? 0 : 15)
                }
                
                // Future predictions
                if hasAIPrediction || history.canPredict {
                    futurePredictionsCard
                        .opacity(showPredictions ? 1 : 0)
                        .offset(y: showPredictions ? 0 : 15)
                }
                
                // 1RM progression chart
                if history.history.count >= 2 {
                    oneRMChartCard
                        .opacity(showChart ? 1 : 0)
                        .offset(y: showChart ? 0 : 15)
                }
            }
            .padding(16)
        }
        .background(Color(.systemBackground))
        .navigationTitle(history.name)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            withAnimation(.easeOut(duration: 0.4)) {
                showHero = true
            }
            withAnimation(.easeOut(duration: 0.4).delay(0.1)) {
                showCurrent = true
            }
            withAnimation(.easeOut(duration: 0.4).delay(0.15)) {
                showTips = true
            }
            withAnimation(.easeOut(duration: 0.4).delay(0.2)) {
                showPredictions = true
            }
            withAnimation(.easeOut(duration: 0.4).delay(0.3)) {
                showChart = true
            }
        }
    }
    
    private var heroCard: some View {
        VStack(spacing: 16) {
            // Exercise GIF with clean rounded corners
            if let exerciseId = history.exerciseId {
                ExerciseGIFView(exerciseId: exerciseId, gifUrl: nil)
                    .frame(width: 100, height: 100)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color.gray.opacity(0.1))
                        .frame(width: 100, height: 100)
                    Image(systemName: "dumbbell.fill")
                        .font(.system(size: 40, weight: .medium))
                        .foregroundColor(.gray)
                }
            }
            
            VStack(spacing: 6) {
                Text(history.name)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
                
                if let category = history.category {
                    Text(category)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(20)
    }
    
    private var current1RMCard: some View {
        VStack(spacing: 20) {
            // Current max weight
            VStack(spacing: 4) {
                Text("Nuvarande Max")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)
                    .tracking(0.5)
                
                HStack(alignment: .lastTextBaseline, spacing: 4) {
                    Text("\(String(format: "%.0f", current1RM))")
                        .font(.system(size: 52, weight: .bold))
                        .foregroundColor(.primary)
                    Text("kg")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.secondary)
                }
            }
            
            // Progression badge
            HStack(spacing: 6) {
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 12, weight: .semibold))
                Text("+\(String(format: "%.1f", max(monthlyRate, 0))) kg/månad")
                    .font(.system(size: 14, weight: .semibold))
            }
            .foregroundColor(.green)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Color.green.opacity(0.1))
            .cornerRadius(20)
            
            // Info
            Text("Baserat på \(history.history.count) träningspass")
                .font(.system(size: 13))
                .foregroundColor(.secondary)
        }
        .padding(20)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(20)
    }
    
    private func aiTipsCard(tips: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "lightbulb.fill")
                    .font(.system(size: 14))
                    .foregroundColor(.gray)
                Text("Tips")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.primary)
            }
            
            Text(tips)
                .font(.system(size: 14))
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.yellow.opacity(0.3), lineWidth: 1)
        )
    }
    
    private var futurePredictionsCard: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Prediktioner")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.primary)
                Spacer()
            }
            
            // Prediction timeline with cleaner Apple style
            VStack(spacing: 12) {
                PredictionTimelineRow(
                    timeLabel: "3 månader",
                    prediction: prediction3M,
                    current: current1RM,
                    color: .green.opacity(0.6),
                    isLast: false
                )
                
                PredictionTimelineRow(
                    timeLabel: "6 månader",
                    prediction: prediction6M,
                    current: current1RM,
                    color: .green.opacity(0.8),
                    isLast: false
                )
                
                PredictionTimelineRow(
                    timeLabel: "1 år",
                    prediction: prediction1Y,
                    current: current1RM,
                    color: .green,
                    isLast: true
                )
            }
        }
        .padding(20)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(20)
    }
    
    private var oneRMChartCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("1RM utveckling")
                .font(.system(size: 17, weight: .bold))
                .foregroundColor(.primary)
            
            // Chart showing estimated 1RM over time
            GeometryReader { geometry in
                let data = history.history
                let oneRMs = data.map { $0.estimated1RM }
                let maxRM = oneRMs.max() ?? 1
                let minRM = oneRMs.min() ?? 0
                let range = maxRM - minRM > 0 ? maxRM - minRM : 1
                let chartWidth = geometry.size.width - 50
                let chartHeight: CGFloat = 180
                let pointSpacing = chartWidth / CGFloat(max(data.count - 1, 1))
                
                ZStack(alignment: .bottomLeading) {
                    // Grid lines
                    VStack(spacing: 0) {
                        ForEach(0..<4) { i in
                            Rectangle()
                                .fill(Color.primary.opacity(0.08))
                                .frame(height: 1)
                            if i < 3 { Spacer() }
                        }
                    }
                    .frame(height: chartHeight)
                    .padding(.trailing, 50)
                    
                    // Area fill with gradient
                    if data.count > 1 {
                        Path { path in
                            path.move(to: CGPoint(x: 0, y: chartHeight))
                            for (index, snapshot) in data.enumerated() {
                                let x = CGFloat(index) * pointSpacing
                                let normalizedY = (snapshot.estimated1RM - minRM) / range
                                let y = chartHeight - normalizedY * chartHeight
                                path.addLine(to: CGPoint(x: x, y: y))
                            }
                            path.addLine(to: CGPoint(x: CGFloat(data.count - 1) * pointSpacing, y: chartHeight))
                            path.closeSubpath()
                        }
                        .fill(
                            LinearGradient(
                                colors: [Color.green.opacity(0.3), Color.green.opacity(0.05)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        
                        // Line
                        Path { path in
                            for (index, snapshot) in data.enumerated() {
                                let x = CGFloat(index) * pointSpacing
                                let normalizedY = (snapshot.estimated1RM - minRM) / range
                                let y = chartHeight - normalizedY * chartHeight
                                if index == 0 {
                                    path.move(to: CGPoint(x: x, y: y))
                                } else {
                                    path.addLine(to: CGPoint(x: x, y: y))
                                }
                            }
                        }
                        .stroke(Color.green, style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                        
                        // Points
                        ForEach(data.indices, id: \.self) { index in
                            let x = CGFloat(index) * pointSpacing
                            let normalizedY = (data[index].estimated1RM - minRM) / range
                            let y = chartHeight - normalizedY * chartHeight
                            
                            Circle()
                                .fill(Color(.systemBackground))
                                .frame(width: 12, height: 12)
                                .overlay(
                                    Circle()
                                        .fill(Color.green)
                                        .frame(width: 8, height: 8)
                                )
                                .position(x: x, y: y)
                        }
                    }
                    
                    // Y-axis labels
                    VStack {
                        Text("\(Int(maxRM)) kg")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("\(Int((maxRM + minRM) / 2)) kg")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("\(Int(minRM)) kg")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                    .frame(height: chartHeight)
                    .offset(x: chartWidth + 10)
                }
                .frame(height: chartHeight)
            }
            .frame(height: 180)
        }
        .padding(20)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(20)
    }
}

// MARK: - Prediction Timeline Row
private struct PredictionTimelineRow: View {
    let timeLabel: String
    let prediction: Double
    let current: Double
    let color: Color
    let isLast: Bool
    
    private var increase: Double {
        prediction - current
    }
    
    var body: some View {
        HStack(spacing: 0) {
            // Time label
            Text(timeLabel)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.secondary)
                .frame(width: 80, alignment: .leading)
            
            Spacer()
            
            // Prediction value
            HStack(spacing: 4) {
                Text("\(String(format: "%.0f", prediction))")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.primary)
                Text("kg")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Increase badge
            HStack(spacing: 3) {
                Image(systemName: "arrow.up")
                    .font(.system(size: 10, weight: .semibold))
                Text("+\(String(format: "%.0f", increase))")
                    .font(.system(size: 13, weight: .semibold))
            }
            .foregroundColor(color)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(color.opacity(0.15))
            .cornerRadius(8)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 4)
        .background(Color(.tertiarySystemBackground))
        .cornerRadius(12)
    }
}

// MARK: - Top Exercise Data Model
struct TopExerciseData {
    let name: String
    var totalSets: Int
    var sessionCount: Int
    var lastDate: Date
    var bestWeight: Double
}

// MARK: - Muscle Radar Chart
// MARK: - Muscle Time Period
enum MuscleTimePeriod: String, CaseIterable {
    case last30Days = "30"
    case last90Days = "90"
    case total = "total"
    
    var displayName: String {
        switch self {
        case .last30Days: return "Senaste 30 dagarna"
        case .last90Days: return "Senaste 90 dagarna"
        case .total: return "Totalt"
        }
    }
}

struct MuscleRadarChart: View {
    let muscleData: [String: Int]
    
    private let muscles = ["Chest", "Shoulders", "Back", "Biceps", "Triceps", "Quads", "Hams", "Glutes"]
    
    private var maxValue: Int {
        max(muscleData.values.max() ?? 1, 1)
    }
    
    var body: some View {
        GeometryReader { geometry in
            let center = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)
            let radius = min(geometry.size.width, geometry.size.height) / 2 - 40
            
            ZStack {
                // Grid circles
                ForEach(1...4, id: \.self) { level in
                    Circle()
                        .stroke(Color.white.opacity(0.15), lineWidth: 1)
                        .frame(width: radius * 2 * CGFloat(level) / 4, height: radius * 2 * CGFloat(level) / 4)
                }
                
                // Grid lines from center
                ForEach(0..<muscles.count, id: \.self) { index in
                    let angle = angleFor(index: index)
                    Path { path in
                        path.move(to: center)
                        path.addLine(to: pointFor(angle: angle, radius: radius, center: center))
                    }
                    .stroke(Color.white.opacity(0.15), lineWidth: 1)
                }
                
                // Data polygon fill
                Path { path in
                    for (index, muscle) in muscles.enumerated() {
                        let value = muscleData[muscle] ?? 0
                        let normalizedValue = maxValue > 0 ? CGFloat(value) / CGFloat(maxValue) : 0
                        let angle = angleFor(index: index)
                        let point = pointFor(angle: angle, radius: radius * normalizedValue, center: center)
                        
                        if index == 0 {
                            path.move(to: point)
                        } else {
                            path.addLine(to: point)
                        }
                    }
                    path.closeSubpath()
                }
                .fill(Color.white.opacity(0.2))
                
                // Data polygon stroke
                Path { path in
                    for (index, muscle) in muscles.enumerated() {
                        let value = muscleData[muscle] ?? 0
                        let normalizedValue = maxValue > 0 ? CGFloat(value) / CGFloat(maxValue) : 0
                        let angle = angleFor(index: index)
                        let point = pointFor(angle: angle, radius: radius * normalizedValue, center: center)
                        
                        if index == 0 {
                            path.move(to: point)
                        } else {
                            path.addLine(to: point)
                        }
                    }
                    path.closeSubpath()
                }
                .stroke(Color.white, lineWidth: 2)
                
                // Data points
                ForEach(0..<muscles.count, id: \.self) { index in
                    let muscle = muscles[index]
                    let value = muscleData[muscle] ?? 0
                    let normalizedValue = maxValue > 0 ? CGFloat(value) / CGFloat(maxValue) : 0
                    let angle = angleFor(index: index)
                    let point = pointFor(angle: angle, radius: radius * normalizedValue, center: center)
                    
                    Circle()
                        .fill(Color.white)
                        .frame(width: 8, height: 8)
                        .position(point)
                }
                
                // Labels
                ForEach(0..<muscles.count, id: \.self) { index in
                    let muscle = muscles[index]
                    let angle = angleFor(index: index)
                    let labelRadius = radius + 25
                    let point = pointFor(angle: angle, radius: labelRadius, center: center)
                    
                    Text(muscle)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.8))
                        .position(point)
                }
            }
        }
    }
    
    private func angleFor(index: Int) -> Double {
        let sliceAngle = 360.0 / Double(muscles.count)
        return (sliceAngle * Double(index) - 90) * .pi / 180
    }
    
    private func pointFor(angle: Double, radius: CGFloat, center: CGPoint) -> CGPoint {
        CGPoint(
            x: center.x + radius * CGFloat(cos(angle)),
            y: center.y + radius * CGFloat(sin(angle))
        )
    }
}

// MARK: - Top Exercise Row
struct TopExerciseRow: View {
    let rank: Int
    let exercise: TopExerciseData
    let exerciseId: String?
    var isLast: Bool = false
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "sv_SE")
        formatter.dateFormat = "d MMM"
        return formatter
    }
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 14) {
                // Exercise GIF or fallback with rank badge
                ZStack(alignment: .bottomTrailing) {
                    if let exerciseId = exerciseId {
                        ExerciseGIFView(exerciseId: exerciseId, gifUrl: nil)
                            .frame(width: 56, height: 56)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    } else {
                        // Fallback icon
                        ZStack {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.primary.opacity(0.05))
                                .frame(width: 56, height: 56)
                            
                            Image(systemName: "dumbbell.fill")
                                .font(.system(size: 22, weight: .semibold))
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    // Rank badge
                    Text("#\(rank)")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Color.primary)
                        .cornerRadius(4)
                        .offset(x: 4, y: 4)
                }
                
                // Exercise info
                VStack(alignment: .leading, spacing: 4) {
                    Text(exercise.name)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    HStack(spacing: 6) {
                        Text("\(exercise.totalSets) sets")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                        
                        Text("•")
                            .font(.system(size: 8))
                            .foregroundColor(.secondary.opacity(0.4))
                        
                        Text("\(exercise.sessionCount) pass")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                // Best weight
                HStack(spacing: 2) {
                    Text("\(String(format: "%.0f", exercise.bestWeight))")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(.primary)
                    Text("kg")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)
                }
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.secondary.opacity(0.4))
            }
            .padding(.vertical, 14)
            .padding(.horizontal, 16)
            
            if !isLast {
                Divider()
                    .padding(.leading, 86)
            }
        }
    }
}

// MARK: - All Top Exercises View
struct AllTopExercisesView: View {
    let exercises: [TopExerciseData]
    let exerciseHistories: [StatExerciseHistory]
    @State private var showContent = false
    
    private func getExerciseId(for exerciseName: String) -> String? {
        exerciseHistories.first { $0.name == exerciseName }?.exerciseId
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                ForEach(Array(exercises.enumerated()), id: \.element.name) { index, exercise in
                    TopExerciseRow(
                        rank: index + 1,
                        exercise: exercise,
                        exerciseId: getExerciseId(for: exercise.name),
                        isLast: index == exercises.count - 1
                    )
                }
            }
            .background(Color(.secondarySystemBackground))
            .cornerRadius(20)
            .padding(16)
            .opacity(showContent ? 1 : 0)
            .offset(y: showContent ? 0 : 15)
        }
        .background(Color(.systemBackground))
        .navigationTitle("Top Övningar")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            withAnimation(.easeOut(duration: 0.4)) {
                showContent = true
            }
        }
    }
}

// MARK: - Statistics Skeleton View
private struct StatisticsSkeletonView: View {
    @State private var isAnimating = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Progress section skeleton
                VStack(spacing: 12) {
                    HStack(spacing: 16) {
                        StatSkeletonBox(width: 80, height: 80, cornerRadius: 12)
                        VStack(alignment: .leading, spacing: 8) {
                            StatSkeletonBox(width: 120, height: 20, cornerRadius: 4)
                            StatSkeletonBox(width: 180, height: 14, cornerRadius: 4)
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                }
                .padding(.top, 8)
                
                // Filter skeleton
                HStack(spacing: 12) {
                    StatSkeletonPill(width: 80, height: 36)
                    StatSkeletonPill(width: 80, height: 36)
                }
                .padding(.top, 8)
                
                // Week stats skeleton
                VStack(spacing: 12) {
                    StatSkeletonBox(width: UIScreen.main.bounds.width - 32, height: 120, cornerRadius: 16)
                }
                .padding(.horizontal, 16)
                
                // Chart skeleton
                VStack(alignment: .leading, spacing: 12) {
                    StatSkeletonBox(width: 100, height: 20, cornerRadius: 4)
                        .padding(.horizontal, 16)
                    StatSkeletonBox(width: UIScreen.main.bounds.width - 32, height: 200, cornerRadius: 16)
                        .padding(.horizontal, 16)
                }
                
                // Monthly recap skeleton
                VStack(alignment: .leading, spacing: 12) {
                    StatSkeletonBox(width: 140, height: 20, cornerRadius: 4)
                        .padding(.horizontal, 16)
                    StatSkeletonBox(width: UIScreen.main.bounds.width - 32, height: 100, cornerRadius: 16)
                        .padding(.horizontal, 16)
                }
                
                Spacer(minLength: 100)
            }
        }
        .background(Color(.systemBackground))
    }
}

private struct StatSkeletonBox: View {
    let width: CGFloat
    let height: CGFloat
    var cornerRadius: CGFloat = 8
    @State private var isAnimating = false
    
    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(
                LinearGradient(
                    colors: [Color(.systemGray5), Color(.systemGray4), Color(.systemGray5)],
                    startPoint: isAnimating ? .leading : .trailing,
                    endPoint: isAnimating ? .trailing : .leading
                )
            )
            .frame(width: width, height: height)
            .onAppear {
                withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                    isAnimating = true
                }
            }
    }
}

private struct StatSkeletonPill: View {
    let width: CGFloat
    let height: CGFloat
    @State private var isAnimating = false
    
    var body: some View {
        Capsule()
            .fill(
                LinearGradient(
                    colors: [Color(.systemGray5), Color(.systemGray4), Color(.systemGray5)],
                    startPoint: isAnimating ? .leading : .trailing,
                    endPoint: isAnimating ? .trailing : .leading
                )
            )
            .frame(width: width, height: height)
            .onAppear {
                withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                    isAnimating = true
                }
            }
    }
}

// MARK: - BMI Legend Item
private struct BMILegendItem: View {
    let color: Color
    let label: String
    let range: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Circle()
                    .fill(color)
                    .frame(width: 8, height: 8)
                
                Text(label)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.primary)
            }
            
            Text(range)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
        }
    }
}


#Preview {
    NavigationStack {
        StatisticsView()
            .environmentObject(AuthViewModel())
    }
}

#Preview("Monthly report") {
    NavigationStack {
        MonthlyReportView()
            .environmentObject(AuthViewModel())
    }
}
