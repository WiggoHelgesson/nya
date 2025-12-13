import SwiftUI

struct WeeklyActivityChart: View {
    let weeklyData: [WeeklyActivityData]
    @State private var selectedActivity: ActivityType = .gym
    @State private var selectedWeekIndex: Int? = nil
    @State private var showStatistics = false
    @State private var showPaywall = false
    @State private var isPremium = RevenueCatManager.shared.isPremium
    
    enum ActivityType: String, CaseIterable {
        case run = "Löpning"
        case golf = "Golf"
        case climbing = "Berg"
        case skiing = "Skidor"
        case gym = "Gym"
        
        var icon: String {
            switch self {
            case .run: return "figure.run"
            case .golf: return "figure.golf"
            case .climbing: return "figure.climbing"
            case .skiing: return "figure.skiing.downhill"
            case .gym: return "dumbbell"
            }
        }
        
        var displayName: String {
            return self.rawValue
        }
    }
    
    var body: some View {
        VStack(spacing: 16) {
            // Activity Type Selector
            HStack(spacing: 6) {
                ForEach([ActivityType.gym, ActivityType.run], id: \.self) { type in
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            selectedActivity = type
                        }
                    }) {
                        HStack(spacing: 3) {
                            Image(systemName: type.icon)
                                .font(.system(size: 11, weight: .medium))
                            Text(type.rawValue)
                                .font(.system(size: 11, weight: .medium))
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                        .frame(maxWidth: .infinity)
                        .background(
                            selectedActivity == type ? Color.black : Color(.systemGray6)
                        )
                        .foregroundColor(selectedActivity == type ? .white : .black)
                        .cornerRadius(14)
                    }
                }
            }
            
            // Stats Summary
            let displayData = selectedWeekIndex != nil ? [weeklyData[selectedWeekIndex!]] : weeklyData
            let filteredData = displayData.filter { getPrimaryMetric(for: $0, activity: selectedActivity) > 0 || getTime(for: $0, activity: selectedActivity) > 0 }
            let totalPrimary = filteredData.reduce(0.0) { $0 + getPrimaryMetric(for: $1, activity: selectedActivity) }
            let totalTime = filteredData.reduce(0.0) { $0 + getTime(for: $1, activity: selectedActivity) }
            let totalElevation = filteredData.reduce(0.0) { $0 + getElevation(for: $1, activity: selectedActivity) }
            
            // Period label
            if let weekIndex = selectedWeekIndex {
                Text(periodLabel(for: weeklyData[weekIndex]))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.gray)
            } else {
                Text("Denna vecka")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.gray)
            }
            
            if selectedActivity == .gym {
                HStack(spacing: 20) {
                    StatView(title: "Tid", value: formatTime(totalTime))
                    StatView(title: "Volym", value: formatVolume(totalPrimary))
                }
            } else {
                HStack(spacing: 20) {
                    StatView(title: "Distans", value: String(format: "%.2f km", totalPrimary))
                    StatView(title: "Tid", value: formatTime(totalTime))
                    StatView(title: "Höjd", value: String(format: "%.0f m", totalElevation))
                }
            }
            
            // Chart
            ChartView(
                data: weeklyData, 
                activity: selectedActivity,
                selectedIndex: $selectedWeekIndex
            )
            .frame(height: 200)
            
            // Statistics Button
            Button(action: {
                if isPremium {
                    showStatistics = true
                } else {
                    showPaywall = true
                }
            }) {
                HStack {
                    Image(systemName: "chart.xyaxis.line")
                        .font(.system(size: 16, weight: .semibold))
                    Text("Se mer av din statistik")
                        .font(.system(size: 16, weight: .semibold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.black)
                .cornerRadius(12)
            }
        }
        .padding(16)
        .background(Color.white)
        .cornerRadius(16)
        .sheet(isPresented: $showStatistics) {
            StatisticsView()
        }
        .sheet(isPresented: $showPaywall) {
            PresentPaywallView()
        }
        .onReceive(RevenueCatManager.shared.$isPremium) { newValue in
            isPremium = newValue
        }
    }
    
    private func getDistance(for data: WeeklyActivityData, activity: ActivityType) -> Double {
        switch activity {
        case .run: return data.runDistance
        case .golf: return data.golfDistance
        case .climbing: return data.climbingDistance
        case .skiing: return data.skiingDistance
        case .gym: return 0
        }
    }
    
    private func getTime(for data: WeeklyActivityData, activity: ActivityType) -> Double {
        switch activity {
        case .run: return data.runTime
        case .golf: return data.golfTime
        case .climbing: return data.climbingTime
        case .skiing: return data.skiingTime
        case .gym: return data.gymTime
        }
    }
    
    private func getElevation(for data: WeeklyActivityData, activity: ActivityType) -> Double {
        switch activity {
        case .run: return data.runElevation
        case .golf: return data.golfElevation
        case .climbing: return data.climbingElevation
        case .skiing: return data.skiingElevation
        case .gym: return 0
        }
    }
    
    private func getPrimaryMetric(for data: WeeklyActivityData, activity: ActivityType) -> Double {
        switch activity {
        case .run: return data.runDistance
        case .golf: return data.golfDistance
        case .climbing: return data.climbingDistance
        case .skiing: return data.skiingDistance
        case .gym: return data.gymVolume
        }
    }
    
    private func formatTime(_ seconds: Double) -> String {
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }
    
    private func formatVolume(_ volume: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        let text = formatter.string(from: NSNumber(value: Int(round(volume)))) ?? "0"
        return "\(text) kg"
    }
    
    private func periodLabel(for weekData: WeeklyActivityData) -> String {
        let calendar = Calendar.current
        let weekOfYear = calendar.component(.weekOfYear, from: weekData.startDate)
        
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "sv_SE")
        dateFormatter.dateFormat = "MMMM"
        let monthName = dateFormatter.string(from: weekData.startDate)
        
        // Capitalize first letter
        let capitalizedMonth = monthName.prefix(1).uppercased() + monthName.dropFirst()
        
        return "\(capitalizedMonth) Vecka \(weekOfYear)"
    }
}

struct StatView: View {
    let title: String
    let value: String
    
    var body: some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.system(size: 12))
                .foregroundColor(.gray)
            Text(value)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.black)
        }
        .frame(maxWidth: .infinity)
    }
}

struct ChartView: View {
    let data: [WeeklyActivityData]
    let activity: WeeklyActivityChart.ActivityType
    @Binding var selectedIndex: Int?
    
    var body: some View {
        GeometryReader { geometry in
            let maxValue = data.map { getValue(for: $0) }.max() ?? 1.0
            let chartWidth = geometry.size.width
            let chartHeight = geometry.size.height - 40
            let barWidth = (chartWidth - CGFloat(data.count - 1) * 8) / CGFloat(data.count)
            
            VStack(spacing: 0) {
                ZStack(alignment: .bottom) {
                    // Background fill area
                    Path { path in
                        for (index, weekData) in data.enumerated() {
                            let value = getValue(for: weekData)
                            let heightRatio = maxValue > 0 ? CGFloat(value / maxValue) : 0
                            let barHeight = chartHeight * heightRatio
                            let xPos = CGFloat(index) * (barWidth + 8) + barWidth / 2
                            let yPos = chartHeight - barHeight
                            
                            if index == 0 {
                                path.move(to: CGPoint(x: xPos, y: chartHeight))
                                path.addLine(to: CGPoint(x: xPos, y: yPos))
                            } else {
                                path.addLine(to: CGPoint(x: xPos, y: yPos))
                            }
                        }
                        
                        // Close the path at the bottom
                        if let lastIndex = data.indices.last {
                            let xPos = CGFloat(lastIndex) * (barWidth + 8) + barWidth / 2
                            path.addLine(to: CGPoint(x: xPos, y: chartHeight))
                        }
                        path.closeSubpath()
                    }
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [Color.black.opacity(0.2), Color.black.opacity(0.05)]),
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    
                    // Line connecting points
                    Path { path in
                        for (index, weekData) in data.enumerated() {
                            let value = getValue(for: weekData)
                            let heightRatio = maxValue > 0 ? CGFloat(value / maxValue) : 0
                            let barHeight = chartHeight * heightRatio
                            let xPos = CGFloat(index) * (barWidth + 8) + barWidth / 2
                            let yPos = chartHeight - barHeight
                            
                            if index == 0 {
                                path.move(to: CGPoint(x: xPos, y: yPos))
                            } else {
                                path.addLine(to: CGPoint(x: xPos, y: yPos))
                            }
                        }
                    }
                    .stroke(Color.black, lineWidth: 3)
                    
                    // Points and labels
                    HStack(alignment: .bottom, spacing: 8) {
                        ForEach(Array(data.enumerated()), id: \.offset) { index, weekData in
                            VStack(spacing: 0) {
                                let value = getValue(for: weekData)
                                let heightRatio = maxValue > 0 ? CGFloat(value / maxValue) : 0
                                let barHeight = chartHeight * heightRatio
                                let isSelected = selectedIndex == index
                                
                                Spacer(minLength: 0)
                                
                                // Point - positioned at top of bar
                                Button(action: {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        if selectedIndex == index {
                                            selectedIndex = nil
                                        } else {
                                            selectedIndex = index
                                        }
                                    }
                                }) {
                                    ZStack {
                                        Circle()
                                            .fill(Color.white)
                                            .frame(width: isSelected ? 18 : 14, height: isSelected ? 18 : 14)
                                            .shadow(color: Color.black.opacity(0.1), radius: 2)
                                        
                                        Circle()
                                            .stroke(Color.black, lineWidth: 3)
                                            .frame(width: isSelected ? 18 : 14, height: isSelected ? 18 : 14)
                                        
                                        if isSelected {
                                            Circle()
                                                .fill(Color.black)
                                                .frame(width: 8, height: 8)
                                        }
                                    }
                                }
                                .frame(width: isSelected ? 18 : 14, height: isSelected ? 18 : 14)
                                .padding(.bottom, barHeight)
                                
                                // Week label
                                Text(weekData.weekLabel)
                                    .font(.system(size: 10))
                                    .foregroundColor(isSelected ? .black : .gray)
                                    .fontWeight(isSelected ? .semibold : .regular)
                                    .frame(height: 20)
                            }
                            .frame(width: barWidth, height: chartHeight + 20)
                        }
                    }
                }
                .frame(height: chartHeight + 20)
                
                // Value label
                Text(valueSummary())
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
    }
    
    private func getValue(for data: WeeklyActivityData) -> Double {
        switch activity {
        case .run: return data.runDistance
        case .golf: return data.golfDistance
        case .climbing: return data.climbingDistance
        case .skiing: return data.skiingDistance
        case .gym: return data.gymVolume
        }
    }
    
    private func valueSummary() -> String {
        guard let last = data.last else { return "" }
        let value = getValue(for: last)
        switch activity {
        case .gym:
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            formatter.maximumFractionDigits = 0
            let text = formatter.string(from: NSNumber(value: Int(round(value)))) ?? "0"
            return "\(text) kg"
        default:
            return String(format: "%.0f km", value)
        }
    }
}

struct WeeklyActivityData {
    let weekLabel: String
    let runDistance: Double
    let runTime: Double
    let runElevation: Double
    let golfDistance: Double
    let golfTime: Double
    let golfElevation: Double
    let climbingDistance: Double
    let climbingTime: Double
    let climbingElevation: Double
    let skiingDistance: Double
    let skiingTime: Double
    let skiingElevation: Double
    let gymVolume: Double
    let gymTime: Double
    let startDate: Date
    let endDate: Date
}

#Preview {
    WeeklyActivityChart(weeklyData: [
        WeeklyActivityData(weekLabel: "Sep 1", runDistance: 10, runTime: 3600, runElevation: 100, golfDistance: 2, golfTime: 1800, golfElevation: 0, climbingDistance: 5, climbingTime: 2400, climbingElevation: 50, skiingDistance: 0, skiingTime: 0, skiingElevation: 0, gymVolume: 3200, gymTime: 5400, startDate: Date(), endDate: Date()),
        WeeklyActivityData(weekLabel: "Sep 8", runDistance: 25, runTime: 7200, runElevation: 200, golfDistance: 3, golfTime: 2400, golfElevation: 0, climbingDistance: 8, climbingTime: 3600, climbingElevation: 80, skiingDistance: 0, skiingTime: 0, skiingElevation: 0, gymVolume: 4800, gymTime: 7200, startDate: Date(), endDate: Date()),
        WeeklyActivityData(weekLabel: "Sep 15", runDistance: 60, runTime: 14400, runElevation: 400, golfDistance: 5, golfTime: 3600, golfElevation: 0, climbingDistance: 12, climbingTime: 5400, climbingElevation: 120, skiingDistance: 0, skiingTime: 0, skiingElevation: 0, gymVolume: 2000, gymTime: 3600, startDate: Date(), endDate: Date())
    ])
    .padding()
}

