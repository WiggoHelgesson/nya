import SwiftUI
import UIKit

struct MonthlyPrizeView: View {
    @EnvironmentObject private var authViewModel: AuthViewModel
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @State private var topUsers: [MonthlyUser] = []
    @State private var isLoading = false
    @State private var countdownText: String = ""
    @State private var countdownTimer: Timer?
    @State private var autoRefreshTask: Task<Void, Never>?
    @State private var showPaywall = false
    private let leaderboardRefreshInterval: UInt64 = 45 * 1_000_000_000
    
    private var isPremium: Bool {
        authViewModel.currentUser?.isProMember ?? false
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemBackground)
                    .ignoresSafeArea()
                
                // Always show the content (will be blurred if not Pro)
                ScrollView {
                    VStack(spacing: 20) {
                        // Pro member notice
                        Text("Enbart PRO medlemmar kan delta")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.gray)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 20)
                            .padding(.top, 16)
                        
                        // Countdown
                        VStack(spacing: 8) {
                            Text("Tid kvar av månaden")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.primary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Text(countdownText)
                                .font(.system(size: 22, weight: .bold))
                                .foregroundColor(.primary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(20)
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                        )
                        .padding(.horizontal, 20)

                        HealthDataDisclosureView(
                            title: "Topplistan bygger på Apple Health",
                            description: "Stegen som visas på Månadens pris hämtas automatiskt från Apple Health. Se till att dela stegdata med Up&Down för att kvala in och håll koll på dina behörigheter i Hälsa-appen.",
                            showsManageButton: true,
                            manageAction: openHealthSettings
                        )
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                        )
                        .padding(.horizontal, 20)
                        
                        // Current month leaderboard
                        VStack(spacing: 0) {
                            Text("Topplista denna månad")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.primary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(20)
                            
                            if isLoading {
                                VStack(spacing: 16) {
                                    ProgressView()
                                        .scaleEffect(1.2)
                                    Text("Laddar topplistan...")
                                        .font(.system(size: 16))
                                        .foregroundColor(.gray)
                                }
                                .padding(.vertical, 40)
                            } else if topUsers.isEmpty {
                                // Empty state
                                VStack(spacing: 16) {
                                    Image(systemName: "trophy")
                                        .font(.system(size: 60))
                                        .foregroundColor(.gray)
                                    Text("Inga Pro-medlemmar på topplistan ännu")
                                        .font(.system(size: 18, weight: .semibold))
                                        .foregroundColor(.primary)
                                    Text("Endast Pro-medlemmar syns på topplistan")
                                        .font(.system(size: 14))
                                        .foregroundColor(.gray)
                                        .multilineTextAlignment(.center)
                                }
                                .padding(.vertical, 40)
                            } else {
                                VStack(spacing: 0) {
                                    ForEach(Array(topUsers.enumerated()), id: \.element.id) { index, user in
                                        NavigationLink {
                                            UserProfileView(userId: user.id)
                                                .environmentObject(authViewModel)
                                        } label: {
                                            MonthlyUserRow(
                                                rank: index + 1,
                                                user: user
                                            )
                                        }
                                        .buttonStyle(PlainButtonStyle())
                                        if index < topUsers.count - 1 {
                                            Divider()
                                                .padding(.leading, 60)
                                        }
                                    }
                                }
                            }
                        }
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                        )
                        .padding(.horizontal, 20)
                        
                        Spacer(minLength: 50)
                    }
                }
                .blur(radius: isPremium ? 0 : 10)
                
                // Pro guard overlay for non-Pro users
                if !isPremium {
                    VStack(spacing: 24) {
                        Spacer()
                        
                        Image(systemName: "trophy.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)
                        
                        Text("Enbart för Pro medlemmar")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(.primary)
                            .multilineTextAlignment(.center)
                        
                        Text("Uppgradera till Pro för att delta i månadens tävling, synas på topplistan och vinna häftiga priser!")
                            .font(.system(size: 16))
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                        
                        Button {
                            showPaywall = true
                        } label: {
                            Text("Bli Pro medlem")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(colorScheme == .dark ? .black : .white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(Color.primary)
                                .cornerRadius(12)
                        }
                        .padding(.horizontal, 40)
                        .padding(.top, 8)
                        
                        Spacer()
                    }
                    .background(Color(.systemBackground).opacity(0.3))
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
                            .foregroundColor(.primary)
                    }
                }
            }
            .sheet(isPresented: $showPaywall) {
                PresentPaywallView()
            }
            .onAppear {
                loadMonthlyStats()
                startCountdown()
                startAutoRefresh()
            }
            .onDisappear {
                countdownTimer?.invalidate()
                countdownTimer = nil
                stopAutoRefresh()
            }
        }
    }
    
    private func loadMonthlyStats() {
        let monthKey = MonthlyStatsService.currentMonthKey()
        if let cached = AppCacheManager.shared.getCachedMonthlyLeaderboard(monthKey: monthKey) {
            self.topUsers = cached
            self.isLoading = cached.isEmpty
            prefetchAvatarImages(for: cached)
        } else {
            self.isLoading = true
        }
        Task {
            await refreshLeaderboard(showLoadingState: topUsers.isEmpty)
        }
    }

    private func refreshLeaderboard(showLoadingState: Bool = false) async {
        if showLoadingState {
            await MainActor.run {
                self.isLoading = true
            }
        }
        do {
            await MonthlyStatsService.shared.syncCurrentUserMonthlySteps()
            let latest = try await MonthlyStatsService.shared.fetchTopMonthlyUsers(limit: 20, forceRemote: true)
            await MainActor.run {
                self.topUsers = latest
                self.isLoading = false
                prefetchAvatarImages(for: latest)
            }
        } catch {
            print("❌ Error loading monthly stats: \(error)")
            await MainActor.run {
                if self.topUsers.isEmpty,
                   let fallback = AppCacheManager.shared.getCachedMonthlyLeaderboard(monthKey: MonthlyStatsService.currentMonthKey()) {
                    self.topUsers = fallback
                    prefetchAvatarImages(for: fallback)
                }
                self.isLoading = false
            }
        }
    }

    private func startAutoRefresh() {
        autoRefreshTask?.cancel()
        autoRefreshTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: leaderboardRefreshInterval)
                await refreshLeaderboard()
            }
        }
    }

    private func stopAutoRefresh() {
        autoRefreshTask?.cancel()
        autoRefreshTask = nil
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
        HealthKitManager.shared.handleManageAuthorizationButton()
    }
    
    private func prefetchAvatarImages(for users: [MonthlyUser]) {
        let urls = users.compactMap { $0.avatarUrl }.filter { !$0.isEmpty }
        guard !urls.isEmpty else { return }
        ImageCacheManager.shared.prefetch(urls: urls)
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
                .foregroundColor(rank == 1 ? Color(red: 0.95, green: 0.75, blue: 0.18) : .primary)
                .frame(width: 30)
            
            // Profile picture
            ProfileImage(url: user.avatarUrl, size: 40)
            
            // Username with PRO badge if applicable
            HStack(spacing: 6) {
                Text(user.username)
                    .font(.system(size: 14))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                
                if user.isPro {
                    Image("41")
                        .resizable()
                        .renderingMode(.original)
                        .scaledToFit()
                        .frame(height: 14)
                }
            }
            
            Spacer()
            
            // Steps
            Text("\(user.steps) steg")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
                .fixedSize()
                .multilineTextAlignment(.trailing)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

#Preview {
    MonthlyPrizeView()
        .environmentObject(AuthViewModel())
}

