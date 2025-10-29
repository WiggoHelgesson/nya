import SwiftUI

struct StatisticsView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var authViewModel: AuthViewModel
    @ObservedObject private var statisticsService = StatisticsService.shared
    @State private var monthlyStats: MonthlyStats?
    @State private var isLoadingMonthlyStats = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGray6)
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        // MARK: - Header Stats
                        VStack(spacing: 16) {
                            Text("STATISTIK")
                                .font(.system(size: 24, weight: .black))
                                .foregroundColor(.black)
                            
                            HStack(spacing: 20) {
                                StatCard(
                                    title: "Denna vecka",
                                    value: String(format: "%.1f", statisticsService.weeklyStats?.totalDistance ?? 0.0),
                                    unit: "km",
                                    color: AppColors.brandBlue
                                )
                                
                                StatCard(
                                    title: "Denna månad",
                                    value: String(format: "%.1f", monthlyStats?.totalDistance ?? 0.0),
                                    unit: "km",
                                    color: AppColors.brandGreen
                                )
                            }
                        }
                        .padding(.top, 20)
                        .onAppear {
                            loadMonthlyStats()
                        }
                        
                        // MARK: - Weekly Chart
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Veckans aktivitet")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.black)
                            
                            if statisticsService.isLoading {
                                ProgressView()
                                    .frame(maxWidth: .infinity)
                            } else {
                                VStack(spacing: 8) {
                                    let dailyStats = statisticsService.weeklyStats?.dailyStats ?? []
                                    if dailyStats.isEmpty {
                                        Text("Ingen aktivitet denna vecka")
                                            .font(.system(size: 14))
                                            .foregroundColor(.gray)
                                            .frame(maxWidth: .infinity, alignment: .center)
                                            .padding(.vertical, 20)
                                    } else {
                                        ForEach(dailyStats, id: \.day) { dailyStat in
                                            HStack {
                                                Text(dailyStat.day)
                                                    .font(.system(size: 14, weight: .medium))
                                                    .foregroundColor(.gray)
                                                    .frame(width: 30, alignment: .leading)
                                                
                                                ZStack(alignment: .leading) {
                                                    RoundedRectangle(cornerRadius: 4)
                                                        .fill(Color(.systemGray5))
                                                        .frame(height: 20)
                                                    
                                                    RoundedRectangle(cornerRadius: 4)
                                                        .fill(AppColors.brandBlue)
                                                        .frame(width: CGFloat(dailyStat.distance * 10), height: 20)
                                                }
                                                
                                                Text(String(format: "%.1f km", dailyStat.distance))
                                                    .font(.system(size: 12, weight: .medium))
                                                    .foregroundColor(.black)
                                                    .frame(width: 50, alignment: .trailing)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        .padding(16)
                        .background(Color.white)
                        .cornerRadius(12)
                        
                        // MARK: - Monthly Progress
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Månadsöversikt")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.black)
                            
                            if isLoadingMonthlyStats {
                                ProgressView()
                                    .frame(maxWidth: .infinity)
                            } else {
                                VStack(spacing: 8) {
                                    let weeklyStats = monthlyStats?.weeklyStats ?? []
                                    if weeklyStats.isEmpty {
                                        Text("Ingen aktivitet denna månad")
                                            .font(.system(size: 14))
                                            .foregroundColor(.gray)
                                            .frame(maxWidth: .infinity, alignment: .center)
                                            .padding(.vertical, 20)
                                    } else {
                                        ForEach(weeklyStats, id: \.week) { weeklyStat in
                                            HStack {
                                                Text(weeklyStat.week)
                                                    .font(.system(size: 14, weight: .medium))
                                                    .foregroundColor(.gray)
                                                    .frame(width: 60, alignment: .leading)
                                                
                                                ZStack(alignment: .leading) {
                                                    RoundedRectangle(cornerRadius: 4)
                                                        .fill(Color(.systemGray5))
                                                        .frame(height: 20)
                                                    
                                                    RoundedRectangle(cornerRadius: 4)
                                                        .fill(AppColors.brandGreen)
                                                        .frame(width: CGFloat(weeklyStat.distance * 2), height: 20)
                                                }
                                                
                                                Text(String(format: "%.1f km", weeklyStat.distance))
                                                    .font(.system(size: 12, weight: .medium))
                                                    .foregroundColor(.black)
                                                    .frame(width: 50, alignment: .trailing)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        .padding(16)
                        .background(Color.white)
                        .cornerRadius(12)
                        
                        // MARK: - Achievement Stats
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Prestationer")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.black)
                            
                            VStack(spacing: 12) {
                                AchievementRow(
                                    icon: "flame.fill",
                                    title: "Veckans längsta löpning",
                                    value: String(format: "%.1f km", statisticsService.weeklyStats?.dailyStats.max(by: { $0.distance < $1.distance })?.distance ?? 0.0),
                                    color: AppColors.brandBlue
                                )
                                
                                AchievementRow(
                                    icon: "trophy.fill",
                                    title: "Total poäng",
                                    value: "\(formatNumber(authViewModel.currentUser?.currentXP ?? 0))",
                                    color: AppColors.pastelPink
                                )
                            }
                        }
                        .padding(16)
                        .background(Color.white)
                        .cornerRadius(12)
                        
                        Spacer(minLength: 20)
                    }
                    .padding(16)
                }
            }
            .navigationTitle("Statistik")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Klar") {
                        dismiss()
                    }
                    .foregroundColor(.black)
                }
            }
        }
    }
    
    func loadMonthlyStats() {
        guard let userId = authViewModel.currentUser?.id else { return }
        
        isLoadingMonthlyStats = true
        
        Task {
            await StatisticsService.shared.fetchMonthlyStats(userId: userId) { stats in
                DispatchQueue.main.async {
                    self.monthlyStats = stats
                    self.isLoadingMonthlyStats = false
                }
            }
        }
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let unit: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.gray)
            
            HStack(alignment: .bottom, spacing: 2) {
                Text(value)
                    .font(.system(size: 24, weight: .black))
                    .foregroundColor(color)
                
                Text(unit)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.gray)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(16)
        .background(Color.white)
        .cornerRadius(12)
    }
}

struct AchievementRow: View {
    let icon: String
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(color)
                .frame(width: 30)
            
            Text(title)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.black)
            
            Spacer()
            
            Text(value)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.black)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    StatisticsView()
        .environmentObject(AuthViewModel())
}
