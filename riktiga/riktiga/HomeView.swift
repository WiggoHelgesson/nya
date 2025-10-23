import SwiftUI

struct HomeView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var stepProgress = 0.65 // 5426 / 8000 steps = ~65%
    @State private var showStartSession = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Bakgrund
                AppColors.white
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        // MARK: - Header
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
                        
                        // MARK: - Steps/Activity Circle Card
                        VStack(spacing: 0) {
                            ZStack {
                                // Background circle
                                Circle()
                                    .fill(Color(.systemGray6))
                                
                                // Progress circle
                                Circle()
                                    .trim(from: 0, to: stepProgress)
                                    .stroke(
                                        Color.black,
                                        style: StrokeStyle(lineWidth: 16, lineCap: .round)
                                    )
                                    .rotationEffect(.degrees(-90))
                                
                                // Center content
                                VStack(spacing: 8) {
                                    Text("5 426")
                                        .font(.system(size: 48, weight: .black))
                                        .foregroundColor(.black)
                                    
                                    Text("STEG")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(.gray)
                                    
                                    HStack(spacing: 4) {
                                        Image(systemName: "flame.fill")
                                            .foregroundColor(.gray)
                                        Text("1")
                                            .font(.system(size: 14, weight: .bold))
                                            .foregroundColor(.black)
                                    }
                                    .padding(.top, 4)
                                }
                            }
                            .frame(height: 280)
                            .padding(20)
                        }
                        .background(Color.white)
                        .cornerRadius(20)
                        .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 2)
                        .padding(.horizontal, 20)
                        
                        // MARK: - Action Buttons
                        VStack(spacing: 12) {
                            // Starta Pass Button
                            NavigationLink(destination: StartSessionView()) {
                                HStack(spacing: 12) {
                                    Image(systemName: "play.fill")
                                        .font(.system(size: 20, weight: .bold))
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("STARTA PASS")
                                            .font(.system(size: 18, weight: .black))
                                        Text("Börja ett träningspass")
                                            .font(.system(size: 13, weight: .semibold))
                                            .opacity(0.9)
                                    }
                                    
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
                            NavigationLink(destination: RewardsView()) {
                                HStack(spacing: 12) {
                                    Image(systemName: "star.fill")
                                        .font(.system(size: 20, weight: .bold))
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("SE VARUMÄRKEN")
                                            .font(.system(size: 18, weight: .black))
                                        Text("Tjäna och använd poäng")
                                            .font(.system(size: 13, weight: .semibold))
                                            .opacity(0.9)
                                    }
                                    
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
                        
                        // MARK: - Daily Challenges/Tips Section
                        VStack(alignment: .leading, spacing: 12) {
                            Text("💡 TIPS FÖR IDAG")
                                .font(.system(size: 18, weight: .black))
                                .foregroundColor(.white)
                            
                            Text("Drick mer vatten! Du behöver minst 2 liter per dag för att hålla dig hydratiserad och energisk.")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(.white)
                                .lineLimit(4)
                        }
                        .padding(20)
                        .background(AppColors.brandYellow)
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

#Preview {
    HomeView()
        .environmentObject(AuthViewModel())
}
