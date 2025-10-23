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
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 16) {
                                    ForEach(rewards) { reward in
                                        FullScreenRewardCard(reward: reward)
                                    }
                                }
                                .padding(.horizontal, 16)
                            }
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
            // Image Section - Takes up most of the screen
            ZStack {
                // Real brand image as background
                Image(reward.imageName)
                    .resizable()
                    .scaledToFill()
                    .frame(height: 400)
                    .clipped()
                
                // Dark overlay for better text readability
                Rectangle()
                    .fill(Color.black.opacity(0.3))
                    .frame(height: 400)
                
                // Brand Logo in center
                VStack(spacing: 8) {
                    Circle()
                        .fill(Color.white.opacity(0.9))
                        .frame(width: 80, height: 80)
                        .overlay(
                            VStack(spacing: 4) {
                                Text(getBrandLogoText(reward.brandName))
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(.black)
                                    .multilineTextAlignment(.center)
                                Image(systemName: "flag.fill")
                                    .font(.system(size: 10))
                                    .foregroundColor(.black)
                            }
                        )
                    
                    Text(reward.brandName)
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.top, 8)
                }
                
                // Points badge
                VStack {
                    HStack {
                        Spacer()
                        Text(reward.points)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.black.opacity(0.8))
                            .cornerRadius(16)
                    }
                    Spacer()
                }
                .padding(16)
            }
            
            // Info Section - Compact at bottom
            HStack {
                // Small brand logo
                Circle()
                    .fill(Color.white.opacity(0.9))
                    .frame(width: 40, height: 40)
                    .overlay(
                        VStack(spacing: 2) {
                            Text(getBrandLogoText(reward.brandName))
                                .font(.system(size: 6, weight: .bold))
                                .foregroundColor(.black)
                                .multilineTextAlignment(.center)
                            Image(systemName: "flag.fill")
                                .font(.system(size: 4))
                                .foregroundColor(.black)
                        }
                    )
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(reward.discount)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.black)
                    
                    Text(reward.brandName)
                        .font(.system(size: 14, weight: .medium))
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
        .frame(width: 280) // Fixed width for horizontal scroll
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
    }
    
    private func getBrandLogoText(_ brandName: String) -> String {
        switch brandName {
        case "PLIKTGOLF":
            return "PLIKT\nGOLF"
        case "PEGMATE":
            return "PEG\nMATE"
        case "LONEGOLF":
            return "LONE\nGOLF"
        case "WINWIZE":
            return "WIN\nWIZE"
        case "SCANDIGOLF":
            return "SCANDI\nGOLF"
        case "Exotic Golf":
            return "EXOTIC\nGOLF"
        case "HAPPYALBA":
            return "HAPPY\nALBA"
        case "RETROGOLF":
            return "RETRO\nGOLF"
        case "PUMPLABS":
            return "PUMP\nLABS"
        default:
            return brandName
        }
    }
}

#Preview {
    RewardsView()
}
