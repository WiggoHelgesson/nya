import SwiftUI

struct RewardCategorySheet: View {
    let category: String
    let rewards: [RewardCard]
    @Binding var favoritedRewards: Set<Int>
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    ForEach(rewards) { reward in
                        NavigationLink(destination: RewardDetailView(reward: reward)) {
                            FullScreenRewardCard(reward: reward, favoritedRewards: $favoritedRewards)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.vertical, 24)
                .padding(.bottom, 12)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(category)
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.large])
    }
}






