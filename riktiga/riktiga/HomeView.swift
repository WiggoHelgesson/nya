import SwiftUI
import Combine

struct HomeView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @StateObject private var statisticsService = StatisticsService.shared
    private let healthKitManager = HealthKitManager.shared
    @State private var showStartSession = false
    @State private var showRewards = false
    @State private var weeklySteps: [DailySteps] = []
    @State private var isLoadingSteps = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Bakgrund
                AppColors.white
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        // MARK: - Welcome Section
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 16) {
                                // Profile Picture Circle
                                AsyncImage(url: URL(string: authViewModel.currentUser?.avatarUrl ?? "")) { image in
                                    image
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                } placeholder: {
                                    Image(systemName: "person.circle.fill")
                                        .font(.system(size: 40))
                                        .foregroundColor(.white)
                                }
                                .frame(width: 50, height: 50)
                                .clipShape(Circle())
                                .overlay(
                                    Circle()
                                        .stroke(Color.white, lineWidth: 2)
                                )
                                
                                Text("VÄLKOMMEN")
                                    .font(.system(size: 32, weight: .black))
                                    .foregroundColor(.white)
                                
                                Spacer()
                            }
                            .padding(.horizontal, 24)
                            .padding(.vertical, 16)
                            .background(Color.black)
                            .cornerRadius(16)
                            .rotationEffect(.degrees(-2))
                            .shadow(color: Color.black.opacity(0.3), radius: 8, x: 0, y: 4)
                            
                            Text((authViewModel.currentUser?.name ?? "ANVÄNDARE").uppercased())
                                .font(.system(size: 36, weight: .bold))
                                .foregroundColor(.black)
                                .padding(.horizontal, 20)
                                .padding(.top, 12)
                                .rotationEffect(.degrees(-2))
                                .shadow(color: Color.black.opacity(0.2), radius: 4, x: 0, y: 2)
                        }
                        .padding(.top, 20)
                        
                        // MARK: - Weekly Distance Section
                        VStack(spacing: 16) {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Denna vecka")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(.gray)
                                    
                                    if statisticsService.isLoading {
                                        Text("Laddar...")
                                            .font(.system(size: 36, weight: .black))
                                            .foregroundColor(.gray)
                                    } else {
                                        Text(String(format: "%.1f km", statisticsService.weeklyStats?.totalDistance ?? 0.0))
                                            .font(.system(size: 36, weight: .black))
                                            .foregroundColor(.black)
                                    }
                                }
                                
                                Spacer()
                                
                                VStack(alignment: .trailing, spacing: 4) {
                                    Text("Mål: 20 km")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(.gray)
                                    
                                    if statisticsService.isLoading {
                                        Text("0%")
                                            .font(.system(size: 20, weight: .bold))
                                            .foregroundColor(.gray)
                                    } else {
                                        Text("\(Int((statisticsService.weeklyStats?.goalProgress ?? 0.0) * 100))%")
                                            .font(.system(size: 20, weight: .bold))
                                            .foregroundColor(.black)
                                    }
                                }
                            }
                            
                            // Progress bar
                            GeometryReader { geometry in
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color(.systemGray6))
                                        .frame(height: 12)
                                    
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color.black)
                                        .frame(width: geometry.size.width * (statisticsService.weeklyStats?.goalProgress ?? 0.0), height: 12)
                                }
                            }
                            .frame(height: 12)
                        }
                        .padding(20)
                        .background(Color.white)
                        .cornerRadius(16)
                        .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 2)
                        .padding(.horizontal, 20)
                        
                        // MARK: - Action Buttons
                        VStack(spacing: 12) {
                            // Starta Pass Button
                            Button(action: {
                                showStartSession = true
                            }) {
                                HStack(spacing: 12) {
                                    Image(systemName: "play.fill")
                                        .font(.system(size: 18, weight: .medium))
                                    
                                    Text("STARTA PASS")
                                        .font(.system(size: 16, weight: .semibold))
                                    
                                    Spacer()
                                    
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 14, weight: .medium))
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(16)
                                .background(Color(.systemGray5))
                                .foregroundColor(.primary)
                                .cornerRadius(12)
                            }
                            
                            // Se Varumärken Button
                            Button(action: {
                                showRewards = true
                            }) {
                                HStack(spacing: 12) {
                                    Image(systemName: "shippingbox.fill")
                                        .font(.system(size: 18, weight: .medium))
                                    
                                    Text("SE VARUMÄRKEN")
                                        .font(.system(size: 16, weight: .semibold))
                                    
                                    Spacer()
                                    
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 14, weight: .medium))
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(16)
                                .background(Color(.systemGray5))
                                .foregroundColor(.primary)
                                .cornerRadius(12)
                            }
                        }
                        .padding(.horizontal, 20)
                        
                        // MARK: - Weekly Statistics Section
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Veckoöversikt")
                                .font(.system(size: 20, weight: .black))
                                .foregroundColor(.black)
                                .padding(.horizontal, 20)
                            
                            VStack(spacing: 12) {
                                if statisticsService.isLoading {
                                    ForEach(0..<7) { _ in
                                        WeeklyStatRow(day: "---", distance: 0.0, isToday: false)
                                    }
                                } else {
                                    ForEach(statisticsService.weeklyStats?.dailyStats ?? [], id: \.day) { dailyStat in
                                        WeeklyStatRow(day: dailyStat.day, distance: dailyStat.distance, isToday: dailyStat.isToday)
                                    }
                                }
                            }
                            .padding(20)
                            .background(Color.white)
                            .cornerRadius(16)
                            .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 2)
                        }
                        .padding(.horizontal, 20)
                        
                        // MARK: - Weekly Steps Section
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Steg denna vecka")
                                .font(.system(size: 20, weight: .black))
                                .foregroundColor(.black)
                                .padding(.horizontal, 20)
                            
                            VStack(spacing: 12) {
                                if isLoadingSteps {
                                    ForEach(0..<7) { _ in
                                        WeeklyStatRow(day: "---", distance: 0.0, isToday: false)
                                    }
                                } else if weeklySteps.isEmpty {
                                    Text("Ingen stegdata tillgänglig")
                                        .font(.system(size: 14))
                                        .foregroundColor(.gray)
                                        .padding()
                                } else {
                                    ForEach(weeklySteps) { dailySteps in
                                        WeeklyStepsRow(date: dailySteps.date, steps: dailySteps.steps)
                                    }
                                }
                            }
                            .padding(20)
                            .background(Color.white)
                            .cornerRadius(16)
                            .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 2)
                        }
                        .padding(.horizontal, 20)
                        
                        Spacer(minLength: 50)
                    }
                    .padding(.vertical, 12)
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
        }
        .sheet(isPresented: $showStartSession) {
            StartSessionView()
        }
        .sheet(isPresented: $showRewards) {
            RewardsView()
        }
        .onAppear {
            if let userId = authViewModel.currentUser?.id {
                Task {
                    await statisticsService.fetchWeeklyStats(userId: userId)
                }
            }
            
            // Hämta stegdata från Apple Health
            isLoadingSteps = true
            healthKitManager.getWeeklySteps { steps in
                weeklySteps = steps
                isLoadingSteps = false
            }
            
            // Lyssna på profilbild uppdateringar
            NotificationCenter.default.addObserver(
                forName: .profileImageUpdated,
                object: nil,
                queue: .main
            ) { notification in
                if let newImageUrl = notification.object as? String {
                    print("🔄 Profile image updated in HomeView: \(newImageUrl)")
                    authViewModel.objectWillChange.send()
                }
            }
        }
        .onDisappear {
            NotificationCenter.default.removeObserver(self, name: .profileImageUpdated, object: nil)
        }
    }
}

struct WeeklyStatRow: View {
    let day: String
    let distance: Double
    let isToday: Bool
    
    var body: some View {
        HStack {
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
                        .frame(width: distance > 0 ? geometry.size.width * (distance / 5.0) : 0, height: 8)
                }
            }
            .frame(height: 8)
            
            Text(String(format: "%.1f km", distance))
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(isToday ? .black : .gray)
                .frame(width: 50, alignment: .trailing)
        }
    }
}

struct WeeklyStepsRow: View {
    let date: Date
    let steps: Int
    
    private var isToday: Bool {
        Calendar.current.isDateInToday(date)
    }
    
    private var dayName: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter.string(from: date)
    }
    
    var body: some View {
        HStack {
            Text(dayName)
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
                        .frame(width: steps > 0 ? geometry.size.width * (CGFloat(steps) / 10000.0) : 0, height: 8)
                }
            }
            .frame(height: 8)
            
            Text("\(steps)")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(isToday ? .black : .gray)
                .frame(width: 50, alignment: .trailing)
        }
    }
}

#Preview {
    HomeView()
        .environmentObject(AuthViewModel())
}
