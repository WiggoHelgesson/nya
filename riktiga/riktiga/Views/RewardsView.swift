import SwiftUI

struct RewardsView: View {
    @State private var selectedCategory = "Golf"
    @State private var currentHeroIndex = 0
    @State private var currentRewardIndex = 0
    @State private var selectedReward: RewardCard?
    
    let categories = ["Golf", "Löpning", "Gym", "Skidåkning"]
    
    let heroImages = [
        "2",
        "3"
    ]
    
    let allRewards = [
        RewardCard(
            id: 1,
            brandName: "PLIKTGOLF",
            discount: "10% rabatt",
            points: "200 poäng",
            imageName: "4",
            category: "Golf",
            isBookmarked: false
        ),
        RewardCard(
            id: 2,
            brandName: "PEGMATE",
            discount: "5% rabatt",
            points: "200 poäng",
            imageName: "5",
            category: "Golf",
            isBookmarked: false
        ),
        RewardCard(
            id: 3,
            brandName: "LONEGOLF",
            discount: "10% rabatt",
            points: "200 poäng",
            imageName: "6",
            category: "Golf",
            isBookmarked: false
        ),
        RewardCard(
            id: 4,
            brandName: "WINWIZE",
            discount: "25% rabatt",
            points: "200 poäng",
            imageName: "7",
            category: "Golf",
            isBookmarked: false
        ),
        RewardCard(
            id: 5,
            brandName: "SCANDIGOLF",
            discount: "15% rabatt",
            points: "200 poäng",
            imageName: "8",
            category: "Golf",
            isBookmarked: false
        ),
        RewardCard(
            id: 6,
            brandName: "Exotic Golf",
            discount: "10% rabatt",
            points: "200 poäng",
            imageName: "9",
            category: "Golf",
            isBookmarked: false
        ),
        RewardCard(
            id: 7,
            brandName: "HAPPYALBA",
            discount: "10% rabatt",
            points: "200 poäng",
            imageName: "10",
            category: "Golf",
            isBookmarked: false
        ),
        RewardCard(
            id: 8,
            brandName: "RETROGOLF",
            discount: "10% rabatt",
            points: "200 poäng",
            imageName: "11",
            category: "Golf",
            isBookmarked: false
        ),
        RewardCard(
            id: 9,
            brandName: "PUMPLABS",
            discount: "10% rabatt",
            points: "200 poäng",
            imageName: "12",
            category: "Gym",
            isBookmarked: false
        ),
        RewardCard(
            id: 10,
            brandName: "ZEN ENERGY",
            discount: "10% rabatt",
            points: "200 poäng",
            imageName: "13",
            category: "Gym",
            isBookmarked: false
        ),
        RewardCard(
            id: 11,
            brandName: "ZEN ENERGY",
            discount: "10% rabatt",
            points: "200 poäng",
            imageName: "13",
            category: "Löpning",
            isBookmarked: false
        )
    ]
    
    var filteredRewards: [RewardCard] {
        return allRewards.filter { $0.category == selectedCategory }
    }
    
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
                            
                            ScrollViewReader { proxy in
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 16) {
                                        ForEach(Array(filteredRewards.enumerated()), id: \.element.id) { index, reward in
                                            NavigationLink(destination: RewardDetailView(reward: reward)) {
                                                FullScreenRewardCard(reward: reward)
                                            }
                                            .buttonStyle(PlainButtonStyle())
                                            .id(index)
                                        }
                                    }
                                    .padding(.horizontal, 16)
                                    .scrollTargetLayout()
                                }
                                .scrollTargetBehavior(.viewAligned)
                                .onAppear {
                                    proxy.scrollTo(currentRewardIndex, anchor: .center)
                                }
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
    let category: String
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
                .frame(height: 250) // Smaller height to match image proportions
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
        .frame(width: UIScreen.main.bounds.width - 20) // Almost full screen width with small margin
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
    }
}

struct RewardDetailView: View {
    let reward: RewardCard
    
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Same image as on the card
                Image(reward.imageName)
                    .resizable()
                    .scaledToFill()
                    .frame(height: 250)
                    .clipped()
                
                VStack(spacing: 20) {
                    // Discount and brand name
                    VStack(spacing: 8) {
                        Text(reward.discount)
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.black)
                        
                        Text(reward.brandName)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.gray)
                    }
                    .padding(.top, 16)
                    .padding(.horizontal, 40)
                    
                    // Company description
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Företaget")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.black)
                        
                        Text(getCompanyDescription(for: reward.brandName))
                            .font(.system(size: 12))
                            .foregroundColor(.gray)
                            .lineLimit(nil)
                    }
                    .padding(.horizontal, 40)
                    
                    // Get discount button
                    Button(action: {
                        // Handle get discount action
                        print("Getting discount for \(reward.brandName)")
                    }) {
                        Text("Hämta rabatt")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(12)
                            .background(Color.black)
                            .cornerRadius(8)
                    }
                    .padding(.horizontal, 40)
                    .padding(.top, 20)
                    .padding(.bottom, 30)
                }
            }
        }
        .navigationTitle(reward.brandName)
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func getCompanyDescription(for brandName: String) -> String {
        switch brandName {
        case "PLIKTGOLF":
            return "PLIKTGOLF är Sveriges ledande golfbutik med över 30 års erfarenhet. Vi erbjuder det senaste inom golfutrustning, kläder och accessoarer från världens bästa märken."
        case "PEGMATE":
            return "PEGMATE specialiserar sig på högkvalitativ golfutrustning och är känt för sina innovativa produkter som hjälper golfare att förbättra sitt spel."
        case "LONEGOLF":
            return "LONEGOLF fokuserar på premium golfutrustning och personlig service. Vi hjälper dig att hitta rätt utrustning för ditt spel."
        case "WINWIZE":
            return "WINWIZE är en innovativ golfbutik som kombinerar traditionell kvalitet med moderna lösningar för att ge dig det bästa golfupplevelsen."
        case "SCANDIGOLF":
            return "SCANDIGOLF är en nordisk golfbutik som erbjuder högkvalitativ utrustning från Skandinaviens bästa märken."
        case "Exotic Golf":
            return "Exotic Golf specialiserar sig på unika och exklusiva golfprodukter från världens alla hörn."
        case "HAPPYALBA":
            return "HAPPYALBA fokuserar på golfkläder och accessoarer som kombinerar stil med funktionalitet för den moderna golfaren."
        case "RETROGOLF":
            return "RETROGOLF erbjuder klassisk golfutrustning med en modern twist, perfekt för golfare som uppskattar både tradition och innovation."
        case "PUMPLABS":
            return "PUMPLABS är en modern gymkedja som fokuserar på funktionell träning och personlig utveckling. Vi hjälper dig att nå dina fitnessmål."
        case "ZEN ENERGY":
            return "ZEN ENERGY erbjuder energidrycker och supplement som ger dig den extra energin du behöver för din träning och vardag."
        default:
            return "Ett företag som erbjuder högkvalitativa produkter för din aktivitet."
        }
    }
}

#Preview {
    RewardsView()
}
