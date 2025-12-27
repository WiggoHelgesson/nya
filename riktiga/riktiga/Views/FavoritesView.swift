import SwiftUI

struct FavoritesView: View {
    @Binding var favoritedRewards: Set<Int>
    let allRewards: [RewardCard]
    @Environment(\.dismiss) private var dismiss
    
    var favoriteRewards: [RewardCard] {
        allRewards.filter { favoritedRewards.contains($0.id) }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if favoriteRewards.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "bookmark")
                            .font(.system(size: 48))
                            .foregroundColor(.gray)
                        
                        Text("Inga favoriter än")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.gray)
                        
                        Text("Markera belöningar som favoriter för att se dem här")
                            .font(.system(size: 14))
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            ForEach(favoriteRewards, id: \.id) { reward in
                                NavigationLink(destination: RewardDetailView(reward: reward)) {
                                    FavoriteRewardCard(reward: reward, favoritedRewards: $favoritedRewards)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 16)
                    }
                }
            }
            .navigationTitle("Favoriter")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Stäng") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct FavoriteRewardCard: View {
    let reward: RewardCard
    @Binding var favoritedRewards: Set<Int>
    
    private var isBookmarked: Bool {
        favoritedRewards.contains(reward.id)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Image Section
            ZStack {
                Image(reward.imageName)
                    .resizable()
                    .scaledToFill()
                    .frame(height: 200)
                    .clipped()
                
                // Points overlay
                VStack {
                    HStack {
                        Spacer()
                        Text("200 poäng")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.black)
                            .cornerRadius(8)
                            .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
                            .padding(.trailing, 96)
                    }
                    Spacer()
                }
                .padding(.top, 8)
                .padding(.leading, 8)
            }
            
            // Info Section
            HStack(spacing: 12) {
                // Brand logo
                Image(getBrandLogo(for: reward.imageName))
                    .resizable()
                    .scaledToFit()
                    .frame(width: 40, height: 40)
                    .clipShape(Circle())
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(reward.discount)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.primary)
                    
                    Text(reward.brandName)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                Button(action: {
                    favoritedRewards.remove(reward.id)
                }) {
                    Image(systemName: "bookmark.fill")
                        .font(.system(size: 18))
                        .foregroundColor(.primary)
                }
            }
            .padding(20)
            .background(Color(.secondarySystemBackground))
        }
        .frame(width: UIScreen.main.bounds.width - 32, height: 280)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
    
    private func getBrandLogo(for imageName: String) -> String {
        switch imageName {
        case "4": return "15" // PLIKTGOLF (old)
        case "56": return "15" // PLIKTGOLF (new cover)
        case "5": return "5"  // PEGMATE (old)
        case "49": return "5"  // PEGMATE (new cover)
        case "6": return "14" // LONEGOLF (old)
        case "50": return "14" // LONEGOLF (new cover)
        case "7": return "17" // WINWIZE (old)
        case "51": return "17" // WINWIZE (new cover)
        case "8": return "18" // SCANDIGOLF
        case "9": return "19" // Exotic Golf
        case "10": return "16" // HAPPYALBA (old)
        case "57": return "16" // HAPPYALBA (new cover)
        case "11": return "20" // RETROGOLF
        case "12": return "21" // PUMPLABS (old)
        case "54": return "21" // PUMPLABS (new cover)
        case "13": return "22" // ZEN ENERGY (old)
        case "52": return "22" // ZEN ENERGY (new cover)
        default: return "5" // Default to PEGMATE
        }
    }
}

#Preview {
    FavoritesView(favoritedRewards: .constant([1, 2]), allRewards: [])
}
