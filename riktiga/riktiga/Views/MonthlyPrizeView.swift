import SwiftUI

struct MonthlyPrizeView: View {
    @Environment(\.dismiss) var dismiss
    @State private var topUsers: [MonthlyUser] = []
    @State private var lastMonthWinner: MonthlyUser?
    @State private var isLoading = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGray6)
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        // MARK: - Header
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Vinnaren får månadens pris")
                                .font(.system(size: 28, weight: .bold))
                                .foregroundColor(.black)
                            
                            Text("Se vilka som gått längst den här månaden")
                                .font(.system(size: 16))
                                .foregroundColor(.gray)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 20)
                        .padding(.top, 20)
                        
                        // MARK: - Last Month's Winner
                        if let winner = lastMonthWinner {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Förra månadens vinnare")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.gray)
                                    .padding(.horizontal, 16)
                                    .padding(.top, 16)
                                
                                HStack(spacing: 12) {
                                    AsyncImage(url: URL(string: winner.avatarUrl ?? "")) { image in
                                        image
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                    } placeholder: {
                                        Image(systemName: "person.circle.fill")
                                            .font(.system(size: 50))
                                            .foregroundColor(.gray)
                                    }
                                    .frame(width: 50, height: 50)
                                    .clipShape(Circle())
                                    
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(winner.username)
                                            .font(.system(size: 16, weight: .semibold))
                                            .foregroundColor(.black)
                                        
                                        Text(String(format: "%.1f km", winner.distance))
                                            .font(.system(size: 14))
                                            .foregroundColor(.gray)
                                    }
                                    
                                    Spacer()
                                }
                                .padding(.horizontal, 16)
                                .padding(.bottom, 16)
                            }
                            .background(Color(.systemGray5))
                            .cornerRadius(12)
                            .padding(.horizontal, 20)
                        }
                        
                        // MARK: - Current Month Ranking
                        VStack(spacing: 0) {
                            ForEach(Array(topUsers.enumerated()), id: \.element.id) { index, user in
                                MonthlyUserRow(
                                    rank: index + 1,
                                    user: user
                                )
                                
                                if index < topUsers.count - 1 {
                                    Divider()
                                        .padding(.leading, 60)
                                }
                            }
                        }
                        .background(Color.white)
                        .cornerRadius(12)
                        .padding(.horizontal, 20)
                        
                        Spacer(minLength: 50)
                    }
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        dismiss()
                    }) {
                        Image(systemName: "xmark")
                            .foregroundColor(.black)
                    }
                }
            }
            .onAppear {
                loadMonthlyStats()
            }
        }
    }
    
    private func loadMonthlyStats() {
        isLoading = true
        
        Task {
            do {
                // Fetch top 20 users for current month
                topUsers = try await MonthlyStatsService.shared.fetchTopMonthlyUsers(limit: 20)
                
                // Fetch last month's winner
                lastMonthWinner = try await MonthlyStatsService.shared.fetchLastMonthWinner()
                
                isLoading = false
            } catch {
                print("❌ Error loading monthly stats: \(error)")
                isLoading = false
            }
        }
    }
}

struct MonthlyUser: Identifiable {
    let id: String
    let username: String
    let avatarUrl: String?
    let distance: Double
    let isPro: Bool
    
    init(id: String, username: String, avatarUrl: String?, distance: Double, isPro: Bool = false) {
        self.id = id
        self.username = username
        self.avatarUrl = avatarUrl
        self.distance = distance
        self.isPro = isPro
    }
}

struct MonthlyUserRow: View {
    let rank: Int
    let user: MonthlyUser
    
    var body: some View {
        HStack(spacing: 12) {
            // Rank number
            Text("\(rank)")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.black)
                .frame(width: 30)
            
            // Profile picture
            AsyncImage(url: URL(string: user.avatarUrl ?? "")) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Image(systemName: "person.circle.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.gray)
            }
            .frame(width: 40, height: 40)
            .clipShape(Circle())
            
            // Username with PRO badge if applicable
            HStack(spacing: 6) {
                Text(user.username)
                    .font(.system(size: 16))
                    .foregroundColor(.black)
                
                if user.isPro {
                    Text("PRO")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.black)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.yellow)
                        .cornerRadius(4)
                }
            }
            
            Spacer()
            
            // Distance
            Text(String(format: "%.1f km", user.distance))
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.black)
                .frame(width: 60, alignment: .trailing)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

#Preview {
    MonthlyPrizeView()
}

