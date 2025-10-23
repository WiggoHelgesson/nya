import SwiftUI

struct StatisticsView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var authViewModel: AuthViewModel
    
    // Sample data for charts
    let weeklyData = [
        ("Mån", 2.5),
        ("Tis", 3.2),
        ("Ons", 1.8),
        ("Tor", 4.1),
        ("Fre", 2.9),
        ("Lör", 5.2),
        ("Sön", 3.7)
    ]
    
    let monthlyData = [
        ("Vecka 1", 18.5),
        ("Vecka 2", 22.3),
        ("Vecka 3", 19.8),
        ("Vecka 4", 25.1)
    ]
    
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
                                    value: "23.2",
                                    unit: "km",
                                    color: AppColors.brandBlue
                                )
                                
                                StatCard(
                                    title: "Denna månad",
                                    value: "89.7",
                                    unit: "km",
                                    color: AppColors.brandGreen
                                )
                            }
                        }
                        .padding(.top, 20)
                        
                        // MARK: - Weekly Chart
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Veckans aktivitet")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.black)
                            
                            VStack(spacing: 8) {
                                ForEach(weeklyData, id: \.0) { day, distance in
                                    HStack {
                                        Text(day)
                                            .font(.system(size: 14, weight: .medium))
                                            .foregroundColor(.gray)
                                            .frame(width: 30, alignment: .leading)
                                        
                                        ZStack(alignment: .leading) {
                                            RoundedRectangle(cornerRadius: 4)
                                                .fill(Color(.systemGray5))
                                                .frame(height: 20)
                                            
                                            RoundedRectangle(cornerRadius: 4)
                                                .fill(AppColors.brandBlue)
                                                .frame(width: CGFloat(distance * 10), height: 20)
                                        }
                                        
                                        Text(String(format: "%.1f km", distance))
                                            .font(.system(size: 12, weight: .medium))
                                            .foregroundColor(.black)
                                            .frame(width: 50, alignment: .trailing)
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
                            
                            VStack(spacing: 8) {
                                ForEach(monthlyData, id: \.0) { week, distance in
                                    HStack {
                                        Text(week)
                                            .font(.system(size: 14, weight: .medium))
                                            .foregroundColor(.gray)
                                            .frame(width: 60, alignment: .leading)
                                        
                                        ZStack(alignment: .leading) {
                                            RoundedRectangle(cornerRadius: 4)
                                                .fill(Color(.systemGray5))
                                                .frame(height: 20)
                                            
                                            RoundedRectangle(cornerRadius: 4)
                                                .fill(AppColors.brandGreen)
                                                .frame(width: CGFloat(distance * 2), height: 20)
                                        }
                                        
                                        Text(String(format: "%.1f km", distance))
                                            .font(.system(size: 12, weight: .medium))
                                            .foregroundColor(.black)
                                            .frame(width: 50, alignment: .trailing)
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
                                    value: "5.2 km",
                                    color: AppColors.brandBlue
                                )
                                
                                AchievementRow(
                                    icon: "clock.fill",
                                    title: "Snabbaste tempo",
                                    value: "4:32/km",
                                    color: AppColors.brandGreen
                                )
                                
                                AchievementRow(
                                    icon: "calendar",
                                    title: "Aktiva dagar denna månad",
                                    value: "18 dagar",
                                    color: AppColors.brandYellow
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
