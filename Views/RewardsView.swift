import SwiftUI

struct RewardsView: View {
    @State private var selectedTab = 0
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Points display
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Dina poäng")
                            .font(.caption)
                            .foregroundColor(.gray)
                        
                        HStack(alignment: .center) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("3,240")
                                    .font(.system(size: 48, weight: .bold))
                                Text("poäng totalt")
                                    .font(.body)
                                    .foregroundColor(.gray)
                            }
                            
                            Spacer()
                            
                            Image(systemName: "star.fill")
                                .font(.system(size: 80))
                                .foregroundColor(Color(red: 1, green: 0.85, blue: 0))
                        }
                    }
                    .padding(20)
                    .background(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color(red: 0.1, green: 0.6, blue: 0.8).opacity(0.1),
                                Color(red: 0.2, green: 0.4, blue: 0.9).opacity(0.1)
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .cornerRadius(12)
                    .padding(.horizontal)
                    
                    // Tabs
                    Picker("", selection: $selectedTab) {
                        Text("Olåst").tag(0)
                        Text("Låst").tag(1)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                    
                    if selectedTab == 0 {
                        // Unlocked rewards
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Dina belöningar")
                                .font(.headline)
                                .padding(.horizontal)
                            
                            VStack(spacing: 12) {
                                RewardCard(
                                    icon: "🏅",
                                    title: "Bronze Athlete",
                                    description: "Slutför 5 träningspass",
                                    points: 100,
                                    isUnlocked: true
                                )
                                
                                RewardCard(
                                    icon: "🥈",
                                    title: "Silver Runner",
                                    description: "Sluta 50 km",
                                    points: 500,
                                    isUnlocked: true
                                )
                                
                                RewardCard(
                                    icon: "🔥",
                                    title: "Calorie Crusher",
                                    description: "Bränn 10,000 kcal",
                                    points: 750,
                                    isUnlocked: true
                                )
                            }
                            .padding(.horizontal)
                        }
                    } else {
                        // Locked rewards
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Nästa belöning")
                                .font(.headline)
                                .padding(.horizontal)
                            
                            VStack(spacing: 12) {
                                RewardCard(
                                    icon: "🥇",
                                    title: "Gold Champion",
                                    description: "Sluta 200 km",
                                    points: 2000,
                                    isUnlocked: false,
                                    pointsRemaining: 1240
                                )
                                
                                RewardCard(
                                    icon: "💎",
                                    title: "Platinum Elite",
                                    description: "50 gånger träning",
                                    points: 5000,
                                    isUnlocked: false,
                                    pointsRemaining: 1760
                                )
                                
                                RewardCard(
                                    icon: "👑",
                                    title: "Legend Status",
                                    description: "1 år aktivt träning",
                                    points: 10000,
                                    isUnlocked: false,
                                    pointsRemaining: 6760
                                )
                            }
                            .padding(.horizontal)
                        }
                    }
                    
                    Spacer(minLength: 50)
                }
                .padding(.vertical)
            }
            .navigationTitle("Belöningar")
        }
    }
}

struct RewardCard: View {
    let icon: String
    let title: String
    let description: String
    let points: Int
    let isUnlocked: Bool
    var pointsRemaining: Int = 0
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                Text(icon)
                    .font(.system(size: 36))
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                if isUnlocked {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.title3)
                } else {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("\(points)")
                            .font(.caption2)
                            .foregroundColor(.gray)
                        Text("pts")
                            .font(.caption2)
                            .foregroundColor(.gray)
                    }
                }
            }
            
            if !isUnlocked && pointsRemaining > 0 {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text("\(pointsRemaining) poäng kvar")
                            .font(.caption)
                            .foregroundColor(.gray)
                        Spacer()
                        Text("\((100 * (points - pointsRemaining)) / points)%")
                            .font(.caption)
                            .fontWeight(.bold)
                    }
                    
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.gray.opacity(0.2))
                            
                            RoundedRectangle(cornerRadius: 4)
                                .fill(
                                    LinearGradient(
                                        gradient: Gradient(colors: [
                                            Color(red: 0.1, green: 0.6, blue: 0.8),
                                            Color(red: 0.2, green: 0.4, blue: 0.9)
                                        ]),
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: geometry.size.width * CGFloat(points - pointsRemaining) / CGFloat(points))
                        }
                    }
                    .frame(height: 6)
                }
            }
        }
        .padding(12)
        .background(isUnlocked ? Color(.systemGray6) : Color(.systemGray6).opacity(0.5))
        .cornerRadius(10)
        .opacity(isUnlocked ? 1 : 0.8)
    }
}

#Preview {
    RewardsView()
}
