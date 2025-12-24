import SwiftUI

struct RewardsSection: View {
    let title: String
    let rewards: [RewardCard]
    @Binding var favoritedRewards: Set<Int>
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title)
                .font(.system(size: 20, weight: .black, design: .rounded))
                .foregroundColor(.primary)
                .padding(.horizontal, 20)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(rewards) { reward in
                        NavigationLink(destination: RewardDetailView(reward: reward)) {
                            FullScreenRewardCard(reward: reward, favoritedRewards: $favoritedRewards)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.horizontal, 20)
            }
            .frame(height: FullScreenRewardCard.cardHeight)
        }
    }
}
