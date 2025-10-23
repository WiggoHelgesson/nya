import SwiftUI

struct HomeView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var weekProgress = 65
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Hej, \(authViewModel.currentUser?.name ?? "User")!")
                            .font(.title)
                            .fontWeight(.bold)
                        Text("Fortsätt träna och nå dina mål")
                            .foregroundColor(.gray)
                    }
                    .padding(.horizontal)
                    
                    // Veckoöversikt
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Din veckoöversikt")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        VStack(spacing: 16) {
                            HStack(spacing: 12) {
                                VStack(alignment: .leading) {
                                    Text("Mål denna vecka")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                    Text("650 kcal")
                                        .font(.title2)
                                        .fontWeight(.bold)
                                }
                                
                                Spacer()
                                
                                ZStack {
                                    Circle()
                                        .stroke(Color.gray.opacity(0.2), lineWidth: 8)
                                    
                                    Circle()
                                        .trim(from: 0, to: CGFloat(weekProgress) / 100)
                                        .stroke(
                                            LinearGradient(
                                                gradient: Gradient(colors: [
                                                    Color(red: 0.1, green: 0.6, blue: 0.8),
                                                    Color(red: 0.2, green: 0.4, blue: 0.9)
                                                ]),
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            ),
                                            style: StrokeStyle(lineWidth: 8, lineCap: .round)
                                        )
                                        .rotationEffect(.degrees(-90))
                                    
                                    Text("\(weekProgress)%")
                                        .font(.headline)
                                        .fontWeight(.bold)
                                }
                                .frame(width: 80, height: 80)
                            }
                            .padding(20)
                            .background(Color(.systemGray6))
                            .cornerRadius(12)
                        }
                        .padding(.horizontal)
                    }
                    
                    // Dagens aktiviteter
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Idag")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        VStack(spacing: 10) {
                            ActivityCard(
                                icon: "figure.walk",
                                title: "Promenad",
                                duration: "30 min",
                                calories: 150
                            )
                            
                            ActivityCard(
                                icon: "figure.stairs",
                                title: "Löpning",
                                duration: "20 min",
                                calories: 250
                            )
                        }
                        .padding(.horizontal)
                    }
                    
                    // Tips
                    VStack(alignment: .leading, spacing: 8) {
                        Text("💡 Tips för idag")
                            .font(.headline)
                        Text("Drick mer vatten! Du behöver minst 2 liter per dag för att hålla dig hydratiserad.")
                            .font(.body)
                            .foregroundColor(.gray)
                    }
                    .padding(16)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(12)
                    .padding(.horizontal)
                    
                    Spacer(minLength: 50)
                }
                .padding(.vertical)
            }
            .navigationTitle("Hem")
        }
    }
}

struct ActivityCard: View {
    let icon: String
    let title: String
    let duration: String
    let calories: Int
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.white)
                .frame(width: 40, height: 40)
                .background(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color(red: 0.1, green: 0.6, blue: 0.8),
                            Color(red: 0.2, green: 0.4, blue: 0.9)
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .cornerRadius(8)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(duration)
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text("\(calories)")
                    .font(.headline)
                Text("kcal")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
        .padding(12)
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }
}

#Preview {
    HomeView()
        .environmentObject(AuthViewModel())
}
