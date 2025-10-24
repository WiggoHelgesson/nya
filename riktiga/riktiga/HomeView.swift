import SwiftUI

struct HomeView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var weeklyDistance: Double = 12.5 // km
    @State private var showStartSession = false
    @State private var showRewards = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Bakgrund
                AppColors.white
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        // MARK: - Top Section: Månadens Pris
                        VStack(spacing: 0) {
                            Button(action: {
                                // Navigate to monthly prize
                            }) {
                                HStack {
                                    Image(systemName: "trophy.fill")
                                        .font(.system(size: 20, weight: .bold))
                                        .foregroundColor(.white)
                                    
                                    Text("MÅNADENS PRIS")
                                        .font(.system(size: 16, weight: .black))
                                        .foregroundColor(.white)
                                    
                                    Spacer()
                                    
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundColor(.white)
                                }
                                .padding(.horizontal, 20)
                                .padding(.vertical, 16)
                                .background(
                                    LinearGradient(
                                        gradient: Gradient(colors: [AppColors.brandBlue, AppColors.brandBlue.opacity(0.8)]),
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .cornerRadius(12)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 20)
                        
                        // MARK: - Welcome Section
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Välkommen")
                                .font(.system(size: 24, weight: .black))
                                .foregroundColor(.white)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 12)
                                .background(AppColors.brandBlue)
                                .cornerRadius(12)
                                .rotationEffect(.degrees(-1))
                            
                            Text((authViewModel.currentUser?.name ?? "ANVÄNDARE").uppercased())
                                .font(.system(size: 32, weight: .black))
                                .foregroundColor(.black)
                                .padding(.horizontal, 20)
                                .padding(.top, 8)
                        }
                        
                        // MARK: - Weekly Distance Section
                        VStack(spacing: 16) {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Denna vecka")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(.gray)
                                    
                                    Text(String(format: "%.1f km", weeklyDistance))
                                        .font(.system(size: 36, weight: .black))
                                        .foregroundColor(.black)
                                }
                                
                                Spacer()
                                
                                VStack(alignment: .trailing, spacing: 4) {
                                    Text("Mål: 20 km")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(.gray)
                                    
                                    Text("\(Int((weeklyDistance / 20.0) * 100))%")
                                        .font(.system(size: 20, weight: .bold))
                                        .foregroundColor(AppColors.brandGreen)
                                }
                            }
                            
                            // Progress bar
                            GeometryReader { geometry in
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color(.systemGray6))
                                        .frame(height: 12)
                                    
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(
                                            LinearGradient(
                                                gradient: Gradient(colors: [AppColors.brandGreen, AppColors.brandBlue]),
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            )
                                        )
                                        .frame(width: geometry.size.width * (weeklyDistance / 20.0), height: 12)
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
                                        .font(.system(size: 20, weight: .bold))
                                    
                                    Text("STARTA PASS")
                                        .font(.system(size: 18, weight: .black))
                                    
                                    Spacer()
                                    
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 16, weight: .semibold))
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(16)
                                .background(AppColors.brandGreen)
                                .foregroundColor(.white)
                                .cornerRadius(14)
                                .rotationEffect(.degrees(-2))
                            }
                            
                            // Se Varumärken Button
                            Button(action: {
                                showRewards = true
                            }) {
                                HStack(spacing: 12) {
                                    Image(systemName: "shippingbox.fill")
                                        .font(.system(size: 20, weight: .bold))
                                    
                                    Text("SE VARUMÄRKEN")
                                        .font(.system(size: 18, weight: .black))
                                    
                                    Spacer()
                                    
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 16, weight: .semibold))
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(16)
                                .background(AppColors.brandBlue)
                                .foregroundColor(.white)
                                .cornerRadius(14)
                                .rotationEffect(.degrees(2))
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
                                // Day 1 - Monday
                                WeeklyStatRow(day: "Mån", distance: 2.1, isToday: false)
                                WeeklyStatRow(day: "Tis", distance: 1.8, isToday: false)
                                WeeklyStatRow(day: "Ons", distance: 3.2, isToday: false)
                                WeeklyStatRow(day: "Tor", distance: 2.5, isToday: false)
                                WeeklyStatRow(day: "Fre", distance: 1.9, isToday: true)
                                WeeklyStatRow(day: "Lör", distance: 0.0, isToday: false)
                                WeeklyStatRow(day: "Sön", distance: 0.0, isToday: false)
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
                .foregroundColor(isToday ? AppColors.brandBlue : .gray)
                .frame(width: 30, alignment: .leading)
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(.systemGray6))
                        .frame(height: 8)
                    
                    RoundedRectangle(cornerRadius: 4)
                        .fill(isToday ? AppColors.brandBlue : AppColors.brandGreen)
                        .frame(width: distance > 0 ? geometry.size.width * (distance / 5.0) : 0, height: 8)
                }
            }
            .frame(height: 8)
            
            Text(String(format: "%.1f km", distance))
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(isToday ? AppColors.brandBlue : .gray)
                .frame(width: 50, alignment: .trailing)
        }
    }
}

#Preview {
    HomeView()
        .environmentObject(AuthViewModel())
}
