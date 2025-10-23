import SwiftUI

struct RewardsView: View {
    @State private var selectedCategory = "Golf"
    @State private var currentHeroIndex = 0
    
    let categories = ["Golf", "Löpning", "Gym", "Skidåkning"]
    
    let heroImages = [
        "golf_course_hero",
        "golf_autumn_hero"
    ]
    
    let rewards = [
        RewardCard(
            id: 1,
            brandName: "PLIKT GOLF",
            discount: "10% rabatt",
            points: "LD 200",
            imageName: "golf_reward_1",
            isBookmarked: false
        ),
        RewardCard(
            id: 2,
            brandName: "GOLF SHOP",
            discount: "15% rabatt",
            points: "LD 300",
            imageName: "golf_reward_2",
            isBookmarked: true
        ),
        RewardCard(
            id: 3,
            brandName: "GOLF PRO",
            discount: "20% rabatt",
            points: "LD 500",
            imageName: "golf_reward_3",
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
                                    title: "ALLT FÖR HÖSTGOLFEN PÅ ETT STÄLLE",
                                    brandName: "PLIKT GOLF",
                                    website: "Pliktgolf.se",
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
                                        RewardCardView(reward: reward)
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
    let title: String
    let brandName: String
    let website: String
    let imageName: String
    
    var body: some View {
        ZStack {
            // Background Image (placeholder)
            RoundedRectangle(cornerRadius: 12)
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color.green.opacity(0.8),
                            Color.blue.opacity(0.6)
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            
            VStack(spacing: 12) {
                // Brand Logo
                VStack(spacing: 4) {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 60, height: 60)
                        .overlay(
                            VStack(spacing: 2) {
                                Text("PLIKT")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(.white)
                                Text("GOLF")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(.white)
                                Image(systemName: "flag.fill")
                                    .font(.system(size: 8))
                                    .foregroundColor(.white)
                            }
                        )
                }
                
                // Title
                Text(title)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                
                // Website
                Text(website)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.9))
            }
            .padding(20)
        }
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

struct RewardCardView: View {
    let reward: RewardCard
    @State private var isBookmarked: Bool
    
    init(reward: RewardCard) {
        self.reward = reward
        self._isBookmarked = State(initialValue: reward.isBookmarked)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Image Section
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color.green.opacity(0.7),
                                Color.blue.opacity(0.5)
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(height: 120)
                
                // Brand Logo in center
                Circle()
                    .fill(Color.green)
                    .frame(width: 50, height: 50)
                    .overlay(
                        VStack(spacing: 2) {
                            Text("PLIKT")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundColor(.white)
                            Text("GOLF")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundColor(.white)
                            Image(systemName: "flag.fill")
                                .font(.system(size: 6))
                                .foregroundColor(.white)
                        }
                    )
                
                // Points badge
                VStack {
                    HStack {
                        Spacer()
                        Text(reward.points)
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.black)
                            .cornerRadius(12)
                    }
                    Spacer()
                }
                .padding(8)
            }
            
            // Info Section
            HStack {
                // Small brand logo
                Circle()
                    .fill(Color.green)
                    .frame(width: 24, height: 24)
                    .overlay(
                        VStack(spacing: 1) {
                            Text("PLIKT")
                                .font(.system(size: 4, weight: .bold))
                                .foregroundColor(.white)
                            Text("GOLF")
                                .font(.system(size: 4, weight: .bold))
                                .foregroundColor(.white)
                            Image(systemName: "flag.fill")
                                .font(.system(size: 3))
                                .foregroundColor(.white)
                        }
                    )
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(reward.discount)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.black)
                    
                    Text(reward.brandName)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                Button(action: {
                    isBookmarked.toggle()
                }) {
                    Image(systemName: isBookmarked ? "bookmark.fill" : "bookmark")
                        .font(.system(size: 16))
                        .foregroundColor(.gray)
                }
            }
            .padding(12)
            .background(Color.white)
        }
        .frame(width: 160)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
}

#Preview {
    RewardsView()
}
