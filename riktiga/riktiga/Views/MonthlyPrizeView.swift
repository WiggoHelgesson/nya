import SwiftUI
import UIKit

struct MonthlyPrizeView: View {
    @Environment(\.dismiss) var dismiss
    @State private var topUsers: [MonthlyUser] = []
    @State private var isLoading = false
    @State private var countdownText: String = ""
    @State private var countdownTimer: Timer?
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGray6)
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        // Countdown
                        VStack(spacing: 8) {
                            Text("Tid kvar av månaden")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.black)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 20)
                            Text(countdownText)
                                .font(.system(size: 22, weight: .bold))
                                .foregroundColor(.black)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 20)
                        }
                        .padding(.top, 16)
                        .padding(.horizontal, 20)

                        HealthDataDisclosureView(
                            title: "Topplistan bygger på Apple Health",
                            description: "Stegen som visas på Månadens pris hämtas automatiskt från Apple Health. Se till att dela stegdata med Up&Down för att kvala in och håll koll på dina behörigheter i Hälsa-appen.",
                            showsManageButton: true,
                            manageAction: openHealthSettings
                        )
                        .padding(.horizontal, 20)
                        
                        // Current month leaderboard
                        Text("Topplista denna månad")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 20)
                        
                        if isLoading {
                            VStack(spacing: 16) {
                                ProgressView()
                                    .scaleEffect(1.2)
                                Text("Laddar topplistan...")
                                    .font(.system(size: 16))
                                    .foregroundColor(.gray)
                            }
                            .padding(.vertical, 60)
                        } else if topUsers.isEmpty {
                            // Empty state
                            VStack(spacing: 16) {
                                Image(systemName: "trophy")
                                    .font(.system(size: 60))
                                    .foregroundColor(.gray)
                                Text("Inga träningspass hittades den här månaden")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(.black)
                                Text("Starta ditt första pass för att hamna på topplistan!")
                                    .font(.system(size: 14))
                                    .foregroundColor(.gray)
                                    .multilineTextAlignment(.center)
                            }
                            .padding(.vertical, 60)
                        } else {
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
                        }
                        
                        Spacer(minLength: 50)
                    }
                }
            }
            .navigationTitle("Månadens pris")
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
                startCountdown()
            }
            .onDisappear {
                countdownTimer?.invalidate()
                countdownTimer = nil
            }
        }
    }
    
    private func loadMonthlyStats() {
        isLoading = true
        if let cached = AppCacheManager.shared.getCachedMonthlyLeaderboard(monthKey: MonthlyStatsService.currentMonthKey()) {
            self.topUsers = cached
            self.isLoading = false
        }
        Task {
            do {
                await MonthlyStatsService.shared.syncCurrentUserMonthlySteps()
                topUsers = try await MonthlyStatsService.shared.fetchTopMonthlyUsers(limit: 20)
                isLoading = false
            } catch {
                print("❌ Error loading monthly stats: \(error)")
                if topUsers.isEmpty,
                   let fallback = AppCacheManager.shared.getCachedMonthlyLeaderboard(monthKey: MonthlyStatsService.currentMonthKey()) {
                    topUsers = fallback
                }
                isLoading = false
            }
        }
    }

    private func startCountdown() {
        func computeText() -> String {
            let cal = Calendar.current
            let now = Date()
            let comps = cal.dateComponents([.year, .month], from: now)
            guard let startOfNextMonth = cal.date(byAdding: DateComponents(month: 1), to: cal.date(from: comps) ?? now),
                  let endDate = cal.date(from: cal.dateComponents([.year, .month, .day], from: startOfNextMonth)) else {
                return ""
            }
            let remaining = max(0, Int(endDate.timeIntervalSinceNow))
            let days = remaining / 86400
            let hours = (remaining % 86400) / 3600
            let minutes = (remaining % 3600) / 60
            let seconds = remaining % 60
            if days > 0 {
                return "\(days)d \(hours)h \(minutes)m \(seconds)s"
            } else {
                return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
            }
        }
        countdownText = computeText()
        countdownTimer?.invalidate()
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            countdownText = computeText()
        }
    }

    private func openHealthSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}

struct MonthlyUser: Identifiable, Codable {
    let id: String
    let username: String
    let avatarUrl: String?
    let steps: Int
    let isPro: Bool
    
    init(id: String, username: String, avatarUrl: String?, steps: Int, isPro: Bool = false) {
        self.id = id
        self.username = username
        self.avatarUrl = avatarUrl
        self.steps = steps
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
                    .font(.system(size: 14))
                    .foregroundColor(.black)
                    .lineLimit(1)
                    .truncationMode(.tail)
                
                if user.isPro {
                    Text("PRO")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.black)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1.5)
                        .background(Color.yellow)
                        .cornerRadius(3)
                }
            }
            
            Spacer()
            
            // Steps
            Text("\(user.steps) steg")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.black)
                .frame(width: 100, alignment: .trailing)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

#Preview {
    MonthlyPrizeView()
}

