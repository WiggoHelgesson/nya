import SwiftUI

// MARK: - Milestones View
struct MilestonesView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var achievementManager = AchievementManager.shared
    @State private var streakInfo: StreakInfo = StreakInfo(currentStreak: 0, longestStreak: 0, lastActivityDate: nil, completedToday: false, completedDaysThisWeek: [])
    @State private var selectedAchievement: Achievement? = nil
    
    private var totalBadges: Int {
        Achievement.allAchievements.count
    }
    
    private var unlockedCount: Int {
        achievementManager.unlockedAchievements.count
    }
    
    private var progress: Double {
        guard totalBadges > 0 else { return 0 }
        return Double(unlockedCount) / Double(totalBadges)
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header stats
                    headerStats
                    
                    // Sub-stats
                    subStats
                    
                    // Achievements by category
                    achievementsByCategory
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Milstolpar")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "arrow.left")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.primary)
                            .frame(width: 40, height: 40)
                            .background(Color(.systemBackground))
                            .clipShape(Circle())
                    }
                }
                
            }
        }
        .onAppear {
            loadStreakData()
        }
        .fullScreenCover(item: $selectedAchievement) { achievement in
            AchievementPopupView(
                achievement: achievement,
                onDismiss: {
                    selectedAchievement = nil
                }
            )
        }
    }
    
    // MARK: - Header Stats
    private var headerStats: some View {
        HStack(spacing: 20) {
            // Day Streak
            VStack(spacing: 8) {
                ZStack {
                    // Sparkles
                    Image(systemName: "sparkle")
                        .font(.system(size: 10))
                        .foregroundColor(.orange.opacity(0.6))
                        .offset(x: -30, y: -15)
                    
                    Image(systemName: "sparkle")
                        .font(.system(size: 8))
                        .foregroundColor(.yellow.opacity(0.7))
                        .offset(x: 28, y: -18)
                    
                    // Main flame
                    ZStack {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 50))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [Color.orange, Color.orange.opacity(0.7)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                        
                        Image(systemName: "flame.fill")
                            .font(.system(size: 28))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [Color.yellow.opacity(0.9), Color.orange.opacity(0.6)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .offset(y: 6)
                        
                        Text("\(streakInfo.currentStreak)")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundColor(.white.opacity(0.9))
                            .offset(y: 12)
                    }
                }
                
                Text("Streak")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.primary)
            }
            .frame(maxWidth: .infinity)
            
            // Badges Earned
            VStack(spacing: 8) {
                ZStack {
                    OctagonShape()
                        .fill(
                            LinearGradient(
                                colors: [Color(hex: "4A4A5A"), Color(hex: "2A2A3A")],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 60, height: 60)
                    
                    OctagonShape()
                        .stroke(
                            LinearGradient(
                                colors: [Color(hex: "D4AF37"), Color(hex: "B8960C")],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 2
                        )
                        .frame(width: 60, height: 60)
                    
                    Text("\(unlockedCount)")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                }
                
                Text("Utmärkelser")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.primary)
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.top, 20)
    }
    
    // MARK: - Sub Stats
    private var subStats: some View {
        HStack(spacing: 12) {
            // Longest streak
            HStack(spacing: 8) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.orange)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(streakInfo.longestStreak) dagar")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.primary)
                    Text("längsta svit")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemBackground))
            )
            
            // Badge progress
            HStack(spacing: 8) {
                OctagonShape()
                    .fill(Color(hex: "4A4A5A"))
                    .frame(width: 24, height: 24)
                    .overlay(
                        OctagonShape()
                            .stroke(Color(hex: "D4AF37"), lineWidth: 1)
                    )
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(unlockedCount)/\(totalBadges) utmärkelser")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    // Progress bar
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color.gray.opacity(0.3))
                                .frame(height: 4)
                            
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color.primary)
                                .frame(width: geo.size.width * progress, height: 4)
                        }
                    }
                    .frame(height: 4)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemBackground))
            )
        }
    }
    
    // MARK: - Achievements by Category
    private var achievementsByCategory: some View {
        VStack(spacing: 24) {
            // Streaks category
            achievementSection(
                title: "Dagssvitar",
                achievements: Achievement.allAchievements.filter { $0.category == .streaks }
            )
            
            // Meals category
            achievementSection(
                title: "Matloggning",
                achievements: Achievement.allAchievements.filter { $0.category == .meals }
            )
            
            // Workouts category
            achievementSection(
                title: "Träning",
                achievements: Achievement.allAchievements.filter { $0.category == .workouts }
            )
            
            // Social category
            achievementSection(
                title: "Socialt",
                achievements: Achievement.allAchievements.filter { $0.category == .social }
            )
        }
    }
    
    // MARK: - Achievement Section
    private func achievementSection(title: String, achievements: [Achievement]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Section header removed - achievements are self-explanatory
            
            // 3-column grid
            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 12),
                GridItem(.flexible(), spacing: 12),
                GridItem(.flexible(), spacing: 12)
            ], spacing: 16) {
                ForEach(achievements) { achievement in
                    AchievementBadgeView(
                        achievement: achievement,
                        isUnlocked: achievementManager.isUnlocked(achievement.id)
                    )
                    .onTapGesture {
                        // For testing - show animation for any achievement
                        var testAchievement = achievement
                        testAchievement.unlockedAt = Date()
                        selectedAchievement = testAchievement
                        
                        // Trigger haptic feedback
                        triggerHaptic()
                    }
                }
            }
        }
    }
    
    // MARK: - Load Data
    private func loadStreakData() {
        streakInfo = StreakManager.shared.getCurrentStreak()
    }
    
    // MARK: - Haptic Feedback
    private func triggerHaptic() {
        let heavy = UIImpactFeedbackGenerator(style: .heavy)
        let notification = UINotificationFeedbackGenerator()
        
        heavy.prepare()
        notification.prepare()
        
        // 3 hårda slag
        heavy.impactOccurred(intensity: 1.0)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            heavy.impactOccurred(intensity: 1.0)
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            heavy.impactOccurred(intensity: 1.0)
            notification.notificationOccurred(.success)
        }
    }
}

// MARK: - Achievement Badge View
struct AchievementBadgeView: View {
    let achievement: Achievement
    let isUnlocked: Bool
    
    var body: some View {
        VStack(spacing: 8) {
            // Badge
            ZStack {
                // Hexagon/badge shape
                HexagonShape()
                    .fill(
                        isUnlocked
                            ? LinearGradient(
                                colors: achievement.gradientColors,
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                              )
                            : LinearGradient(
                                colors: [Color.gray.opacity(0.3), Color.gray.opacity(0.2)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                              )
                    )
                    .frame(width: 70, height: 80)
                
                // Border
                HexagonShape()
                    .stroke(
                        isUnlocked
                            ? Color.white.opacity(0.3)
                            : Color.gray.opacity(0.2),
                        lineWidth: 2
                    )
                    .frame(width: 70, height: 80)
                
                // Sparkles for unlocked
                if isUnlocked {
                    Image(systemName: "sparkle")
                        .font(.system(size: 8))
                        .foregroundColor(.white.opacity(0.7))
                        .offset(x: -25, y: -25)
                    
                    Image(systemName: "sparkle")
                        .font(.system(size: 6))
                        .foregroundColor(.white.opacity(0.5))
                        .offset(x: 28, y: -20)
                }
                
                // Icon and number
                VStack(spacing: 4) {
                    Image(systemName: achievement.icon)
                        .font(.system(size: 24))
                        .foregroundColor(isUnlocked ? .white : .gray.opacity(0.4))
                    
                    Text("\(achievement.requirement)")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(isUnlocked ? .white.opacity(0.9) : .gray.opacity(0.4))
                }
            }
            
            // Name
            Text(achievement.name)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(isUnlocked ? .primary : .secondary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
            
            // Description
            Text(achievement.description)
                .font(.system(size: 10))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .opacity(isUnlocked ? 1 : 0.6)
    }
}

// MARK: - Preview
#Preview {
    MilestonesView()
}

