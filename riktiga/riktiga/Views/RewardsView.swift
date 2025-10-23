import SwiftUI

struct RewardsView: View {
    @State private var selectedCategory = "Golf"
    @State private var currentHeroIndex = 0
    
    let categories = ["Golf", "Löpning", "Gym", "Skidåkning"]
    
    let heroImages = [
        "2",
        "3"
    ]
    
    let rewards = [
        RewardCard(
            id: 1,
            brandName: "PLIKTGOLF",
            discount: "10% rabatt",
            points: "200 poäng",
            imageName: "4", // Using image 4 for PLIKTGOLF
            isBookmarked: false
        ),
        RewardCard(
            id: 2,
            brandName: "PEGMATE",
            discount: "5% rabatt",
            points: "200 poäng",
            imageName: "5", // Using image 5 for PEGMATE
            isBookmarked: false
        ),
        RewardCard(
            id: 3,
            brandName: "LONEGOLF",
            discount: "10% rabatt",
            points: "200 poäng",
            imageName: "6", // Using image 6 for LONEGOLF
            isBookmarked: false
        ),
        RewardCard(
            id: 4,
            brandName: "WINWIZE",
            discount: "25% rabatt",
            points: "200 poäng",
            imageName: "7", // Using image 7 for WINWIZE
            isBookmarked: false
        ),
        RewardCard(
            id: 5,
            brandName: "SCANDIGOLF",
            discount: "15% rabatt",
            points: "200 poäng",
            imageName: "8", // Using image 8 for SCANDIGOLF
            isBookmarked: false
        ),
        RewardCard(
            id: 6,
            brandName: "Exotic Golf",
            discount: "10% rabatt",
            points: "200 poäng",
            imageName: "9", // Using image 9 for Exotic Golf
            isBookmarked: false
        ),
        RewardCard(
            id: 7,
            brandName: "HAPPYALBA",
            discount: "10% rabatt",
            points: "200 poäng",
            imageName: "10", // Using image 10 for HAPPYALBA
            isBookmarked: false
        ),
        RewardCard(
            id: 8,
            brandName: "RETROGOLF",
            discount: "10% rabatt",
            points: "200 poäng",
            imageName: "11", // Using image 11 for RETROGOLF
            isBookmarked: false
        ),
        RewardCard(
            id: 9,
            brandName: "PUMPLABS",
            discount: "10% rabatt",
            points: "200 poäng",
            imageName: "12", // Using image 12 for PUMPLABS
            isBookmarked: false
        )
    ]
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemBackground)
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // MARK: - Hero Banner Slider
                        TabView(selection: $currentHeroIndex) {
                            ForEach(0..<heroImages.count, id: \.self) { index in
                                HeroBannerCard(
                                    imageName: heroImages[index]
                                )
                                .tag(index)
                            }
                        }
                        .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                        .frame(height: 200)
                        .cornerRadius(12)
                        .padding(.horizontal, 16)
                        
                        // MARK: - Categories Section
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Kategorier")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(.black)
                                .padding(.horizontal, 16)
                            
                            HStack(spacing: 12) {
                                ForEach(categories, id: \.self) { category in
                                    CategoryButton(
                                        category: category,
                                        isSelected: selectedCategory == category,
                                        action: {
                                            selectedCategory = category
                                        }
                                    )
                                }
                            }
                            .padding(.horizontal, 16)
                        }
                        
                        // MARK: - Rewards Section
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Belöningar")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(.black)
                                .padding(.horizontal, 16)
                            
                            TabView {
                                ForEach(rewards) { reward in
                                    FullScreenRewardCard(reward: reward)
                                        .padding(.horizontal, 16)
                                }
                            }
                            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                            .frame(height: 400)
                        }
                        
                        Spacer(minLength: 100)
                    }
                    .padding(.top, 8)
                }
            }
            .navigationTitle("Belöningar")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

struct HeroBannerCard: View {
    let imageName: String
    
    var body: some View {
        Image(imageName)
            .resizable()
            .scaledToFill()
            .frame(height: 200)
            .clipped()
            .cornerRadius(12)
    }
}

struct CategoryButton: View {
    let category: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: getCategoryIcon(category))
                    .font(.system(size: 24))
                    .foregroundColor(isSelected ? .white : .gray)
                
                Text(category)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(isSelected ? .white : .gray)
            }
            .frame(width: 70, height: 70)
            .background(isSelected ? .black : Color(.systemGray6))
            .cornerRadius(12)
        }
    }
    
    func getCategoryIcon(_ category: String) -> String {
        switch category {
        case "Golf":
            return "flag.fill"
        case "Löpning":
            return "figure.run"
        case "Gym":
            return "dumbbell.fill"
        case "Skidåkning":
            return "mountain.2.fill"
        default:
            return "star.fill"
        }
    }
}

struct RewardCard: Identifiable {
    let id: Int
    let brandName: String
    let discount: String
    let points: String
    let imageName: String
    let isBookmarked: Bool
}

struct FullScreenRewardCard: View {
    let reward: RewardCard
    @State private var isBookmarked: Bool
    
    init(reward: RewardCard) {
        self.reward = reward
        self._isBookmarked = State(initialValue: reward.isBookmarked)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Image Section - Clean brand image only
            Image(reward.imageName)
                .resizable()
                .scaledToFill()
                .frame(height: 300) // Smaller height like in the image
                .clipped()
            
            // Info Section - Clean like in the image
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(reward.discount)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.black)
                    
                    Text(reward.brandName)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                Button(action: {
                    isBookmarked.toggle()
                }) {
                    Image(systemName: isBookmarked ? "bookmark.fill" : "bookmark")
                        .font(.system(size: 20))
                        .foregroundColor(.gray)
                }
            }
            .padding(20)
            .background(Color.white)
        }
        .frame(maxWidth: .infinity) // Let TabView handle the sizing
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
    }
}

#Preview {
    RewardsView()
}
