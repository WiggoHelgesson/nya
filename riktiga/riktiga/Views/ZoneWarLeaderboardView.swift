import SwiftUI

struct ZoneWarLeaderboardView: View {
    let areaName: String
    let leaders: [TerritoryLeader]
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerSection
            
            // Leaderboard list
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(Array(leaders.enumerated()), id: \.element.id) { index, leader in
                        LeaderboardRow(rank: index + 1, leader: leader)
                    }
                }
            }
            .background(Color(red: 0.1, green: 0.15, blue: 0.25))
        }
        .background(Color(red: 0.1, green: 0.15, blue: 0.25))
        .onAppear {
            // Prefetch all avatar images
            let urls = leaders.compactMap { $0.avatarUrl }
            ImageCacheManager.shared.prefetch(urls: urls)
        }
    }
    
    private var headerSection: some View {
        VStack(spacing: 8) {
            // Crown and title
            HStack(spacing: 8) {
                Text("👑")
                    .font(.title2)
                Text("KING OF THE AREA")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
                Text("👑")
                    .font(.title2)
            }
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity)
            .background(Color(red: 0.45, green: 0.4, blue: 0.25)) // Olive/gold color
        }
    }
}

struct LeaderboardRow: View {
    let rank: Int
    let leader: TerritoryLeader
    @State private var showUserProfile = false
    
    var body: some View {
        Button {
            showUserProfile = true
        } label: {
            HStack(spacing: 12) {
                // Rank
                Text("\(rank)")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(rankColor)
                    .frame(width: 32, alignment: .leading)
                
                // Flag (Swedish flag emoji)
                Text("🇸🇪")
                    .font(.title2)
                
                // Profile image
                ProfileImage(url: leader.avatarUrl, size: 50)
                
                // Name
                HStack(spacing: 4) {
                    Text(leader.name)
                        .font(.system(size: 17, weight: .medium))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    
                    if leader.isPro {
                        Image("41")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 18, height: 18)
                    }
                }
                
                Spacer()
                
                // Area
                Text(formatArea(leader.totalArea))
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(rowBackgroundColor)
        }
        .buttonStyle(.plain)
        .background(
            NavigationLink(
                destination: UserProfileView(userId: leader.id),
                isActive: $showUserProfile
            ) {
                EmptyView()
            }
            .hidden()
        )
    }
    
    private var rankColor: Color {
        switch rank {
        case 1: return Color(red: 1, green: 0.84, blue: 0) // Gold
        case 2: return Color(white: 0.78) // Silver
        case 3: return Color(red: 0.8, green: 0.5, blue: 0.2) // Bronze
        default: return .white
        }
    }
    
    private var rowBackgroundColor: Color {
        switch rank {
        case 1: return Color(red: 0.15, green: 0.22, blue: 0.38) // Dark blue
        case 2: return Color(red: 0.18, green: 0.25, blue: 0.42)
        case 3: return Color(red: 0.2, green: 0.28, blue: 0.45)
        case 4: return Color(red: 0.35, green: 0.22, blue: 0.28) // Burgundy/purple
        default:
            // Alternate between dark blue shades
            return rank % 2 == 0 
                ? Color(red: 0.12, green: 0.18, blue: 0.32)
                : Color(red: 0.15, green: 0.22, blue: 0.38)
        }
    }
    
    private func formatArea(_ area: Double) -> String {
        let km2 = area / 1_000_000
        if km2 >= 10 {
            return String(format: "%.1fKM²", km2)
        } else if km2 >= 1 {
            return String(format: "%.2fKM²", km2)
        } else if area >= 1000 {
            return String(format: "%.2fKM²", km2)
        } else {
            return String(format: "%.0fM²", area)
        }
    }
}

// Model for leaderboard
struct TerritoryLeader: Identifiable {
    let id: String
    let name: String
    let avatarUrl: String?
    let totalArea: Double // in m²
    let isPro: Bool
}

