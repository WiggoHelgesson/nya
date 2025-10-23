import SwiftUI

struct HomeView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var weekProgress = 65
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Bakgrund
                AppColors.white
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 28) {
                        // MARK: - Header med stor, tjock text
                        VStack(alignment: .leading, spacing: 2) {
                            Text("HEJ,")
                                .font(.system(size: 56, weight: .black))
                                .foregroundColor(.black)
                                .lineLimit(1)
                            
                            Text((authViewModel.currentUser?.name ?? "ANVÄNDARE").uppercased())
                                .font(.system(size: 56, weight: .black))
                                .foregroundColor(AppColors.brandBlue)
                                .lineLimit(1)
                            
                            Text("Fortsätt träna och nå dina mål")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.black)
                                .padding(.top, 8)
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 20)
                        
                        // MARK: - Veckoöversikt Card
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("DIN VECKA")
                                        .font(.system(size: 13, weight: .bold))
                                        .foregroundColor(AppColors.white)
                                    
                                    Text("650 KM")
                                        .font(.system(size: 32, weight: .black))
                                        .foregroundColor(AppColors.white)
                                }
                                
                                Spacer()
                                
                                ZStack {
                                    Circle()
                                        .stroke(AppColors.white.opacity(0.3), lineWidth: 8)
                                    
                                    Circle()
                                        .trim(from: 0, to: CGFloat(weekProgress) / 100)
                                        .stroke(
                                            AppColors.white,
                                            style: StrokeStyle(lineWidth: 8, lineCap: .round)
                                        )
                                        .rotationEffect(.degrees(-90))
                                    
                                    Text("\(weekProgress)%")
                                        .font(.system(size: 20, weight: .black))
                                        .foregroundColor(AppColors.white)
                                }
                                .frame(width: 90, height: 90)
                            }
                            .padding(24)
                            .background(AppColors.brandBlue)
                            .cornerRadius(16)
                            .rotationEffect(.degrees(-3), anchor: .center)
                        }
                        .padding(.horizontal, 20)
                        
                        // MARK: - Feature Cards
                        VStack(spacing: 16) {
                            // Kort 1 - Grön
                            BrandedCard(
                                title: "STARTA TRÄNING",
                                subtitle: "Börja ett nytt pass",
                                icon: "play.fill",
                                backgroundColor: AppColors.brandGreen,
                                angle: -4
                            )
                            
                            // Kort 2 - Gul
                            BrandedCard(
                                title: "DAGENS UTMANING",
                                subtitle: "Du är 450 kcal från målet",
                                icon: "target",
                                backgroundColor: AppColors.brandYellow,
                                angle: 3
                            )
                            
                            // Kort 3 - Rosa
                            BrandedCard(
                                title: "DIN STATISTIK",
                                subtitle: "Se din framgång",
                                icon: "chart.bar.fill",
                                backgroundColor: AppColors.pastelPink,
                                angle: -3
                            )
                        }
                        .padding(.horizontal, 20)
                        
                        // MARK: - Tips Section
                        VStack(alignment: .leading, spacing: 12) {
                            Text("💡 TIPS FÖR IDAG")
                                .font(.system(size: 18, weight: .black))
                                .foregroundColor(.black)
                            
                            Text("Drick mer vatten! Du behöver minst 2 liter per dag för att hålla dig hydratiserad och energisk.")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(.black)
                                .lineLimit(4)
                        }
                        .padding(20)
                        .background(AppColors.brandYellow.opacity(0.6))
                        .cornerRadius(12)
                        .rotationEffect(.degrees(2), anchor: .center)
                        .padding(.horizontal, 20)
                        
                        Spacer(minLength: 50)
                    }
                    .padding(.vertical, 12)
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

// MARK: - Branded Card Component
struct BrandedCard: View {
    let title: String
    let subtitle: String
    let icon: String
    let backgroundColor: Color
    let angle: Double
    
    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.system(size: 20, weight: .black))
                    .foregroundColor(.black)
                    .lineLimit(2)
                
                Text(subtitle)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.black.opacity(0.7))
                    .lineLimit(2)
            }
            
            Spacer()
            
            Image(systemName: icon)
                .font(.system(size: 28, weight: .semibold))
                .foregroundColor(.black)
        }
        .padding(20)
        .background(backgroundColor)
        .cornerRadius(14)
        .rotationEffect(.degrees(angle), anchor: .center)
    }
}

#Preview {
    HomeView()
        .environmentObject(AuthViewModel())
}
