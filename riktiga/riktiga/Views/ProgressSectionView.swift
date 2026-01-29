import SwiftUI

// MARK: - Progress Section View (For Statistics Tab)
struct ProgressSectionView: View {
    @ObservedObject private var achievementManager = AchievementManager.shared
    @State private var streakInfo: StreakInfo = StreakInfo(currentStreak: 0, longestStreak: 0, lastActivityDate: nil, completedToday: false, completedDaysThisWeek: [])
    @State private var showMilestones = false
    
    // Animation states
    @State private var showStreakCard = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Streak Card - centered and full width
            Button {
                showMilestones = true
            } label: {
                StreakCardView(
                    streak: streakInfo.currentStreak,
                    completedToday: streakInfo.completedToday,
                    completedDaysThisWeek: streakInfo.completedDaysThisWeek
                )
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(ScaleButtonStyle())
            .opacity(showStreakCard ? 1 : 0)
            .offset(y: showStreakCard ? 0 : 20)
            .scaleEffect(showStreakCard ? 1 : 0.9)
            .padding(.horizontal, 20)
        }
        .padding(.vertical, 16)
        .onAppear {
            loadStreak()
            animateCards()
        }
        .onReceive(NotificationCenter.default.publisher(for: .streakUpdated)) { _ in
            loadStreak()
        }
        .fullScreenCover(isPresented: $showMilestones) {
            MilestonesView()
        }
    }
    
    private func loadStreak() {
        streakInfo = StreakManager.shared.getCurrentStreak()
    }
    
    private func animateCards() {
        showStreakCard = false
        
        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
            showStreakCard = true
        }
    }
}

// MARK: - Scale Button Style
struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

// MARK: - Streak Card View
struct StreakCardView: View {
    let streak: Int
    var completedToday: Bool = false
    var completedDaysThisWeek: [Int] = [] // Weekday indices (1=Sunday, 2=Monday, etc.)
    
    // Weekday labels (Monday first, Swedish style)
    private let weekdays = ["M", "T", "O", "T", "F", "L", "S"]
    // Map to Calendar weekday (2=Monday, 3=Tuesday, ... 7=Saturday, 1=Sunday)
    private let weekdayIndices = [2, 3, 4, 5, 6, 7, 1]
    
    private var flameColor: Color {
        streak > 0 ? .orange : .gray
    }
    
    private var innerFlameColor: Color {
        streak > 0 ? .yellow : .gray.opacity(0.6)
    }
    
    private var currentWeekday: Int {
        Calendar.current.component(.weekday, from: Date())
    }
    
    var body: some View {
        VStack(spacing: 12) {
            // Flame with sparkles
            ZStack {
                // Sparkles (only show if completed today)
                if completedToday {
                    Image(systemName: "sparkle")
                        .font(.system(size: 12))
                        .foregroundColor(.orange.opacity(0.6))
                        .offset(x: -35, y: -20)
                    
                    Image(systemName: "sparkle")
                        .font(.system(size: 10))
                        .foregroundColor(.yellow.opacity(0.7))
                        .offset(x: 35, y: -25)
                    
                    Image(systemName: "sparkle")
                        .font(.system(size: 8))
                        .foregroundColor(.orange.opacity(0.5))
                        .offset(x: 40, y: 5)
                }
                
                // Main flame
                ZStack {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 60))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [flameColor, flameColor.opacity(0.7)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                    
                    // Inner lighter flame
                    Image(systemName: "flame.fill")
                        .font(.system(size: 35))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [innerFlameColor.opacity(0.9), flameColor.opacity(0.6)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .offset(y: 8)
                    
                    // Streak number
                    Text("\(streak)")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(.white.opacity(0.9))
                        .offset(y: 15)
                }
            }
            
            Text("Streak")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.secondary)
            
            // Weekday indicators
            HStack(spacing: 8) {
                ForEach(0..<7, id: \.self) { index in
                    let weekdayIndex = weekdayIndices[index]
                    let isCompleted = completedDaysThisWeek.contains(weekdayIndex)
                    let isToday = weekdayIndex == currentWeekday
                    
                    VStack(spacing: 4) {
                        Text(weekdays[index])
                            .font(.system(size: 12, weight: isToday ? .bold : .medium))
                            .foregroundColor(isToday ? .orange : .secondary)
                        
                        ZStack {
                            Circle()
                                .fill(isCompleted ? Color.orange : Color(.systemGray5))
                                .frame(width: 22, height: 22)
                            
                            if isCompleted {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(.white)
                            }
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.06), radius: 12, x: 0, y: 4)
        )
    }
}

// MARK: - Badges Card View
struct BadgesCardView: View {
    let badgeCount: Int
    let recentBadges: [Achievement]
    
    var body: some View {
        VStack(spacing: 12) {
            // Badge shape
            ZStack {
                // Octagon badge shape
                OctagonShape()
                    .fill(
                        LinearGradient(
                            colors: [Color(hex: "4A4A5A"), Color(hex: "2A2A3A")],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 70, height: 70)
                
                // Gold border
                OctagonShape()
                    .stroke(
                        LinearGradient(
                            colors: [Color(hex: "D4AF37"), Color(hex: "B8960C")],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 2
                    )
                    .frame(width: 70, height: 70)
                
                // Badge count
                Text("\(badgeCount)")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
            }
            
            Text("Utmärkelser")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.secondary)
            
            // Recent badges row
            if !recentBadges.isEmpty {
                HStack(spacing: 4) {
                    ForEach(recentBadges.prefix(4)) { badge in
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: badge.gradientColors,
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 28, height: 28)
                            .overlay(
                                Image(systemName: badge.icon)
                                    .font(.system(size: 12))
                                    .foregroundColor(.white)
                            )
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.06), radius: 12, x: 0, y: 4)
        )
    }
}

// MARK: - Octagon Shape
struct OctagonShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let width = rect.width
        let height = rect.height
        let cornerSize = width * 0.25
        
        path.move(to: CGPoint(x: cornerSize, y: 0))
        path.addLine(to: CGPoint(x: width - cornerSize, y: 0))
        path.addLine(to: CGPoint(x: width, y: cornerSize))
        path.addLine(to: CGPoint(x: width, y: height - cornerSize))
        path.addLine(to: CGPoint(x: width - cornerSize, y: height))
        path.addLine(to: CGPoint(x: cornerSize, y: height))
        path.addLine(to: CGPoint(x: 0, y: height - cornerSize))
        path.addLine(to: CGPoint(x: 0, y: cornerSize))
        path.closeSubpath()
        
        return path
    }
}

// MARK: - Preview
#Preview {
    ProgressSectionView()
        .background(Color(.systemGroupedBackground))
}

