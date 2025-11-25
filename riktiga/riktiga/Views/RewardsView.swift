import SwiftUI

struct HeroBannerAsset: Identifiable {
    let id = UUID()
    let imageName: String
    let url: String
}

struct RewardsView: View {
    @State private var selectedCategory = "Golf"
    @State private var currentHeroIndex = 0
    @State private var currentRewardIndex = 0
    @State private var selectedReward: RewardCard?
    @State private var searchText = ""
    @State private var showSearchView = false
    @State private var showFavorites = false
    @State private var showMyPurchases = false
    @State private var favoritedRewards: Set<Int> = []
    @EnvironmentObject var authViewModel: AuthViewModel
    
    let categories = ["Golf", "Löpning", "Gym", "Skidåkning"]
    
    private let sectionBackgroundColor = Color(red: 247/255, green: 248/255, blue: 255/255)
    private let sectionShadowColor = Color.black.opacity(0.05)
    
    let heroBanners: [HeroBannerAsset] = [
        HeroBannerAsset(imageName: "2", url: "https://pliktgolf.se"),
        HeroBannerAsset(imageName: "32", url: "https://peaksummit.se"),
        HeroBannerAsset(imageName: "3", url: "https://lonegolf.se")
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
            discount: "20% rabatt",
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
            discount: "15% rabatt",
            points: "200 poäng",
            imageName: "12",
            category: "Gym",
            isBookmarked: false
        ),
        RewardCard(
            id: 10,
            brandName: "ZEN ENERGY",
            discount: "15% rabatt",
            points: "200 poäng",
            imageName: "13",
            category: "Gym",
            isBookmarked: false
        ),
        RewardCard(
            id: 11,
            brandName: "ZEN ENERGY",
            discount: "15% rabatt",
            points: "200 poäng",
            imageName: "13",
            category: "Löpning",
            isBookmarked: false
        ),
        RewardCard(
            id: 12,
            brandName: "PEAK",
            discount: "15% rabatt med koden Summit",
            points: "200 poäng",
            imageName: "33",
            category: "Golf",
            isBookmarked: false
        ),
        RewardCard(
            id: 13,
            brandName: "PEAK",
            discount: "15% rabatt med koden Summit",
            points: "200 poäng",
            imageName: "33",
            category: "Löpning",
            isBookmarked: false
        ),
        RewardCard(
            id: 14,
            brandName: "PEAK",
            discount: "15% rabatt med koden Summit",
            points: "200 poäng",
            imageName: "33",
            category: "Gym",
            isBookmarked: false
        ),
        RewardCard(
            id: 15,
            brandName: "PEAK",
            discount: "15% rabatt med koden Summit",
            points: "200 poäng",
            imageName: "33",
            category: "Skidåkning",
            isBookmarked: false
        ),
        RewardCard(
            id: 16,
            brandName: "CAPSTONE",
            discount: "10% rabatt med koden CAPSTONE10",
            points: "200 poäng",
            imageName: "34",
            category: "Golf",
            isBookmarked: false
        ),
        RewardCard(
            id: 17,
            brandName: "CAPSTONE",
            discount: "10% rabatt med koden CAPSTONE10",
            points: "200 poäng",
            imageName: "34",
            category: "Löpning",
            isBookmarked: false
        ),
        RewardCard(
            id: 18,
            brandName: "CAPSTONE",
            discount: "10% rabatt med koden CAPSTONE10",
            points: "200 poäng",
            imageName: "34",
            category: "Gym",
            isBookmarked: false
        ),
        RewardCard(
            id: 19,
            brandName: "CAPSTONE",
            discount: "10% rabatt med koden CAPSTONE10",
            points: "200 poäng",
            imageName: "34",
            category: "Skidåkning",
            isBookmarked: false
        )
    ]
    
    var filteredRewards: [RewardCard] {
        return allRewards.filter { $0.category == selectedCategory }
    }
    
    var sortedAllRewards: [RewardCard] {
        // Remove duplicates by brand name
        let uniqueRewards = Dictionary(grouping: allRewards, by: { $0.brandName })
            .compactMapValues { $0.first }
            .values
        
        return Array(uniqueRewards).sorted { first, second in
            // PUMPLABS first
            if first.brandName == "PUMPLABS" && second.brandName != "PUMPLABS" {
                return true
            }
            if second.brandName == "PUMPLABS" && first.brandName != "PUMPLABS" {
                return false
            }
            
            // ZEN ENERGY second
            if first.brandName == "ZEN ENERGY" && second.brandName != "ZEN ENERGY" && second.brandName != "PUMPLABS" {
                return true
            }
            if second.brandName == "ZEN ENERGY" && first.brandName != "ZEN ENERGY" && first.brandName != "PUMPLABS" {
                return false
            }
            
            // Rest in alphabetical order
            return first.brandName < second.brandName
        }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.white
                
                VStack(spacing: 0) {
                    // MARK: - Header with Search, Favorites, and Points
                    VStack(spacing: 16) {
                        // Top row with points and icons
                        HStack {
                // Points display
                HStack(spacing: 8) {
                    Image(systemName: "gift.fill")
                        .foregroundColor(.white)
                        .font(.system(size: 16))
                    
                    Text("\(authViewModel.currentUser?.currentXP ?? 0)")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.black)
                .cornerRadius(20)
                .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
                            
                            Spacer()
                            
                            // Right side icons
                            HStack(spacing: 16) {
                                Button(action: {
                                    // Navigate to My Purchases
                                    showMyPurchases = true
                                }) {
                                    Image(systemName: "bag.fill")
                                        .foregroundColor(.black)
                                        .font(.system(size: 20))
                                }
                                
                                Button(action: {
                                    // Navigate to favorited discounts
                                    showFavorites = true
                                }) {
                                    Image(systemName: "bookmark.fill")
                                        .foregroundColor(.black)
                                        .font(.system(size: 20))
                                }
                            }
            }
            .padding(.horizontal, 8)
            .padding(.top, 8)
                        
                        // Search bar
                        Button(action: {
                            showSearchView = true
                        }) {
                            HStack {
                                Image(systemName: "magnifyingglass")
                                    .foregroundColor(.gray)
                                    .font(.system(size: 16))
                                
                                Text("Sök")
                                    .font(.system(size: 16))
                                    .foregroundColor(.gray)
                                
                                Spacer()
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(Color.white)
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                            )
                        }
                        .padding(.horizontal, 16)
                    }
                    .padding(.bottom, 16)
                    .background(Color(.systemBackground))
                    
                    ScrollView {
                    VStack(spacing: 24) {
                        // MARK: - Hero Banner Slider
                        ScrollViewReader { proxy in
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    ForEach(heroBanners.indices, id: \.self) { index in
                                        let banner = heroBanners[index]
                                        HeroBannerCard(imageName: banner.imageName)
                                            .frame(width: UIScreen.main.bounds.width - 32)
                                            .contentShape(Rectangle())
                                            .onTapGesture {
                                                openHeroBannerURL(banner.url)
                                            }
                                            .id(index)
                                    }
                                }
                                .padding(.horizontal, 16)
                                .scrollTargetLayout()
                            }
                            .scrollTargetBehavior(.viewAligned)
                            .onAppear {
                                proxy.scrollTo(currentHeroIndex, anchor: .leading)
                            }
                        }
                        .frame(height: 200)
                        
                        // MARK: - Categories Section
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Kategorier")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(.black)
                                .padding(.horizontal, 16)
                            
                            HStack(spacing: 16) {
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
                            .frame(maxWidth: .infinity)
                            .padding(.horizontal, 16)
                        }
                        
                        // MARK: - Rewards Section
                        ZStack {
                            RoundedRectangle(cornerRadius: 26, style: .continuous)
                                .fill(sectionBackgroundColor)
                                .shadow(color: sectionShadowColor, radius: 16, x: 0, y: 10)
                            
                            VStack(alignment: .leading, spacing: 20) {
                                Text("Belöningar")
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundColor(.black)
                                    .padding(.horizontal, 4)
                                
                                ScrollViewReader { proxy in
                                    ScrollView(.horizontal, showsIndicators: false) {
                                        HStack(spacing: 20) {
                                            ForEach(Array(filteredRewards.enumerated()), id: \.element.id) { index, reward in
                                                NavigationLink(destination: RewardDetailView(reward: reward)) {
                                                    FullScreenRewardCard(reward: reward, favoritedRewards: $favoritedRewards)
                                                }
                                                .buttonStyle(PlainButtonStyle())
                                                .id(index)
                                            }
                                        }
                                        .padding(.vertical, 8)
                                        .padding(.horizontal, 4)
                                        .scrollTargetLayout()
                                    }
                                    .scrollTargetBehavior(.viewAligned)
                                    .onAppear {
                                        proxy.scrollTo(currentRewardIndex, anchor: .center)
                                    }
                                }
                            }
                            .padding(.vertical, 28)
                            .padding(.horizontal, 22)
                        }
                        .padding(.horizontal, 16)
                        
                        // MARK: - Alla belöningar Section
                        ZStack {
                            RoundedRectangle(cornerRadius: 26, style: .continuous)
                                .fill(sectionBackgroundColor)
                                .shadow(color: sectionShadowColor, radius: 16, x: 0, y: 10)
                            
                            VStack(alignment: .leading, spacing: 20) {
                                Text("Alla belöningar")
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundColor(.black)
                                    .padding(.horizontal, 4)
                                
                                ScrollViewReader { proxy in
                                    ScrollView(.horizontal, showsIndicators: false) {
                                        HStack(spacing: 20) {
                                            ForEach(Array(sortedAllRewards.enumerated()), id: \.element.id) { index, reward in
                                                NavigationLink(destination: RewardDetailView(reward: reward)) {
                                                    FullScreenRewardCard(reward: reward, favoritedRewards: $favoritedRewards)
                                                }
                                                .buttonStyle(PlainButtonStyle())
                                                .id(index)
                                            }
                                        }
                                        .padding(.vertical, 8)
                                        .padding(.horizontal, 4)
                                        .scrollTargetLayout()
                                    }
                                    .scrollTargetBehavior(.viewAligned)
                                    .onAppear {
                                        proxy.scrollTo(0, anchor: .center)
                                    }
                                }
                            }
                            .padding(.vertical, 28)
                            .padding(.horizontal, 22)
                        }
                        .padding(.horizontal, 16)
                        
                        Spacer(minLength: 100)
                    }
                    .padding(.top, 8)
                    }
                }
            }
            .navigationTitle("Belöningar")
            .navigationBarTitleDisplayMode(.inline)
            .enableSwipeBack()
            .sheet(isPresented: $showSearchView) {
                SearchRewardsView(allRewards: allRewards)
            }
            .sheet(isPresented: $showFavorites) {
                FavoritesView(favoritedRewards: $favoritedRewards, allRewards: allRewards)
            }
            .sheet(isPresented: $showMyPurchases) {
                MyPurchasesView()
            }
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
            VStack(spacing: 6) {
                Image(systemName: getCategoryIcon(category))
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(isSelected ? .white : .gray)
                
                Text(category)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(isSelected ? .white : .gray)
            }
            .frame(width: 80, height: 80)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? .black : Color(.systemGray5))
            )
        }
        .scaleEffect(isSelected ? 1.05 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isSelected)
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
    @Binding var favoritedRewards: Set<Int>
    
    static let cardHeight: CGFloat = 360
    
    private let cornerRadius: CGFloat = 24
    private let cardBackground = Color.white
    private let infoBackground = Color(red: 247/255, green: 247/255, blue: 255/255)
    private let accentColor = Color(red: 78/255, green: 77/255, blue: 255/255)
    
    private var isBookmarked: Bool {
        favoritedRewards.contains(reward.id)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .topTrailing) {
                Image(reward.imageName)
                    .resizable()
                    .scaledToFill()
                    .frame(height: 210)
                    .frame(maxWidth: .infinity)
                    .clipped()
                
                HStack(spacing: 6) {
                    Image(systemName: "gift.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.black)
                    
                    Text(reward.points)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.black)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.white)
                .clipShape(Capsule())
                .shadow(color: Color.black.opacity(0.12), radius: 6, x: 0, y: 4)
                .padding(18)
            }
            
            HStack(spacing: 16) {
                Image(getBrandLogo(for: reward.imageName))
                    .resizable()
                    .scaledToFit()
                    .frame(width: 48, height: 48)
                    .clipShape(Circle())
                    .shadow(color: Color.black.opacity(0.08), radius: 5, x: 0, y: 3)
                
                VStack(alignment: .leading, spacing: 6) {
                    Text(reward.discount)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.black)
                    
                    Text(reward.brandName)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(Color.gray)
                }
                
                Spacer()
                
                Button(action: {
                    if isBookmarked {
                        favoritedRewards.remove(reward.id)
                    } else {
                        favoritedRewards.insert(reward.id)
                    }
                }) {
                    Image(systemName: isBookmarked ? "bookmark.fill" : "bookmark")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(isBookmarked ? accentColor : .gray)
                }
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 24)
            .background(infoBackground)
        }
        .frame(width: UIScreen.main.bounds.width - 64)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .shadow(color: Color.black.opacity(0.08), radius: 14, x: 0, y: 9)
    }
    
    private func getBrandLogo(for imageName: String) -> String {
        switch imageName {
        case "4": return "15" // PLIKTGOLF
        case "5": return "5"  // PEGMATE
        case "6": return "14" // LONEGOLF
        case "7": return "17" // WINWIZE
        case "8": return "18" // SCANDIGOLF
        case "9": return "19" // Exotic Golf
        case "10": return "16" // HAPPYALBA (Alba)
        case "11": return "20" // RETROGOLF
        case "12": return "21" // PUMPLABS
        case "13": return "22" // ZEN ENERGY
        default: return "5" // Default to PEGMATE
        }
    }
}

struct RewardDetailView: View {
    let reward: RewardCard
    @State private var showCheckout = false
    @State private var showConfirmation = false
    @EnvironmentObject var authViewModel: AuthViewModel
    
    private var hasEnoughPoints: Bool {
        return (authViewModel.currentUser?.currentXP ?? 0) >= 200
    }
    
    var body: some View {
        ZStack {
            // White background for the entire page
            Color.white
                .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 0) {
                    // 1. Cover image
                    Image(reward.imageName)
                        .resizable()
                        .scaledToFill()
                        .frame(height: 250)
                        .clipped()
                    
                    VStack(spacing: 24) {
                        // 2. Discount text and title
                        VStack(spacing: 8) {
                            Text(reward.discount)
                                .font(.system(size: 28, weight: .bold))
                                .foregroundColor(.black)
                            
                            Text("för \(reward.brandName)")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundColor(.gray)
                        }
                        .padding(.top, 20)
                        .padding(.horizontal, 20)
                        
                        // 3. Company description card - gray background
                        VStack(spacing: 20) {
                            // Company logo at the top
                            VStack(spacing: 12) {
                                // Real company logo
                                Image(getCompanyLogo(for: reward.brandName))
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 80, height: 80)
                                    .background(Color.white)
                                    .clipShape(Circle())
                                    .overlay(
                                        Circle()
                                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                                    )
                                
                                // Company name
                                Text(reward.brandName)
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(.black)
                            }
                            .padding(.top, 24)
                            
                            // Company description
                            Text(getCompanyDescription(for: reward.brandName))
                                .font(.system(size: 14))
                                .foregroundColor(.black)
                                .multilineTextAlignment(.leading)
                                .lineLimit(nil)
                                .padding(.horizontal, 20)
                            
                            // Add extra vertical spacing
                            Spacer()
                                .frame(height: 20)
                        }
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(16)
                        .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
                        .padding(.horizontal, 20)
                        
                        // 4. Action buttons - shorter width
                        VStack(spacing: 12) {
                            // Visit website button
                            Button(action: {
                                openCompanyWebsite(for: reward.brandName)
                            }) {
                                Text("BESÖK HEMSIDA")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(.black)
                                    .frame(width: 280) // Shorter width
                                    .padding(.vertical, 16)
                                    .background(Color.white)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                                    )
                                    .cornerRadius(12)
                            }
                            
                            // Claim reward button
                            Button(action: {
                                if hasEnoughPoints {
                                    showCheckout = true
                                }
                            }) {
                                Text(hasEnoughPoints ? "HÄMTA BELÖNING" : "INTE TILLRÄCKLIGT MED POÄNG")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(.white)
                                    .frame(width: 280) // Shorter width
                                    .padding(.vertical, 16)
                                    .background(hasEnoughPoints ? Color.black : Color.gray)
                                    .cornerRadius(12)
                            }
                            .disabled(!hasEnoughPoints)
                        }
                        .padding(.bottom, 30)
                    }
                }
            }
        }
        .navigationTitle(reward.brandName)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showCheckout) {
            CheckoutView(reward: reward, showConfirmation: $showConfirmation)
        }
        .sheet(isPresented: $showConfirmation) {
            ConfirmationView(reward: reward)
        }
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
        case "PEAK":
            return "PEAK Summit ger dig funktionella outdoor- och träningskläder som klarar både berg, löpning och gym. Använd koden SUMMIT för 15% rabatt."
        case "CAPSTONE":
            return "CAPSTONE erbjuder premium tränings- och friluftskläder för allt från gym till bergstoppar. Använd koden CAPSTONE10 för 10% rabatt."
        default:
            return "Ett företag som erbjuder högkvalitativa produkter för din aktivitet."
        }
    }
    
    private func getCompanyLogo(for brandName: String) -> String {
        switch brandName {
        case "PLIKTGOLF":
            return "15" // Pliktgolf logo
        case "PEGMATE":
            return "5" // Pegmate logo
        case "LONEGOLF":
            return "14" // Lonegolf logo
        case "WINWIZE":
            return "17" // WinWize logo
        case "SCANDIGOLF":
            return "18" // Scandigolf logo
        case "Exotic Golf":
            return "19" // Exotic Golf logo
        case "HAPPYALBA":
            return "16" // Alba logo
        case "RETROGOLF":
            return "20" // Retro golf logo
        case "PUMPLABS":
            return "21" // Pumplabs logo
        case "ZEN ENERGY":
            return "22" // Zen energy logo
        case "PEAK":
            return "33"
        case "CAPSTONE":
            return "34"
        default:
            return "5" // Default to Pegmate logo
        }
    }
    
    private func openCompanyWebsite(for brandName: String) {
        let urlString: String
        
        switch brandName {
        case "PUMPLABS":
            urlString = "https://pumplab.se/"
        case "Exotic Golf":
            urlString = "https://exoticagolf.se/"
        case "ZEN ENERGY":
            urlString = "https://zenenergydrinks.com/?srsltid=AfmBOoo0XewnkvbPLeH1CbuslALX3C-hEOOaf_jJuHh3XMGlHm-rB2Pb"
        case "HAPPYALBA":
            urlString = "https://www.happyalba.com/"
        case "LONEGOLF":
            urlString = "https://lonegolf.se"
        case "PEGMATE":
            urlString = "https://pegmate.se/en/"
        case "PLIKTGOLF":
            urlString = "https://pliktgolf.se"
        case "PEAK":
            urlString = "https://peaksummit.se"
        case "CAPSTONE":
            urlString = "https://capstone.nu/"
        case "RETROGOLF":
            urlString = "https://retrogolfacademy.se/"
        case "SCANDIGOLF":
            urlString = "https://www.scandigolf.se/"
        case "WINWIZE":
            urlString = "https://winwize.com/?srsltid=AfmBOootwFRqBXLHIeZW7SD8Em9h3_XydIfKOpTSt_uB01nndveoqM0J"
        default:
            urlString = "https://google.com" // Fallback
        }
        
        if let url = URL(string: urlString) {
            UIApplication.shared.open(url)
        }
    }
    
    private func openHeroBannerURL(_ urlString: String) {
        guard let url = URL(string: urlString) else { return }
        UIApplication.shared.open(url)
    }
}

struct CheckoutView: View {
    let reward: RewardCard
    @Binding var showConfirmation: Bool
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var authViewModel: AuthViewModel
    @ObservedObject private var purchaseService = PurchaseService.shared
    
    @State private var firstName = ""
    @State private var lastName = ""
    @State private var email = ""
    @State private var city = ""
    @State private var showSubscriptionView = false
    @State private var isProcessingPurchase = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header with reward info
                    VStack(spacing: 12) {
                        Text(reward.discount)
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(.black)
                        
                        Text(reward.brandName)
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.gray)
                    }
                    .padding(.top, 20)
                    
                    // Form fields
                    VStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Förnamn")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.black)
                            
                            TextField("Ange ditt förnamn", text: $firstName)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Efternamn")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.black)
                            
                            TextField("Ange ditt efternamn", text: $lastName)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("E-post")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.black)
                            
                            TextField("Ange din e-post", text: $email)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .keyboardType(.emailAddress)
                                .autocapitalization(.none)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(email.isEmpty || (email.contains("@") && email.contains(".")) ? Color.gray.opacity(0.3) : Color.red, lineWidth: 1)
                                )
                            
                            if !email.isEmpty && (!email.contains("@") || !email.contains(".")) {
                                Text("Ange en giltig e-postadress")
                                    .font(.system(size: 12))
                                    .foregroundColor(.red)
                            }
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Stad")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.black)
                            
                            TextField("Ange din stad", text: $city)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                        }
                    }
                    .padding(.horizontal, 20)
                    
                    Spacer(minLength: 40)
                    
                    // Confirm purchase button
                    Button(action: {
                        Task {
                            await processPurchase()
                        }
                    }) {
                        HStack {
                            if isProcessingPurchase {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.8)
                            }
                            Text(isProcessingPurchase ? "Bearbetar..." : "Bekräfta köp")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.white)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(16)
                        .background(Color.black)
                        .cornerRadius(10)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                    .disabled(firstName.isEmpty || lastName.isEmpty || email.isEmpty || city.isEmpty || isProcessingPurchase || !email.contains("@") || !email.contains("."))
                }
            }
            .navigationTitle("Checkout")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Avbryt") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showSubscriptionView) {
                SubscriptionView()
            }
        }
    }
    
    private func processPurchase() async {
        print("🔄 Starting purchase process...")
        
        guard let userId = authViewModel.currentUser?.id else {
            print("❌ No user ID available")
            return
        }
        
        print("✅ User ID: \(userId)")
        
        // Validate email format
        guard email.contains("@") && email.contains(".") else {
            print("❌ Invalid email format: \(email)")
            return
        }
        
        print("✅ Email format valid: \(email)")
        
        // Check if user has enough points
        guard let user = authViewModel.currentUser, user.currentXP >= 200 else {
            print("❌ Not enough points. Current XP: \(authViewModel.currentUser?.currentXP ?? 0)")
            return
        }
        
        print("✅ User has enough points: \(user.currentXP)")
        
        isProcessingPurchase = true
        
        do {
            print("🔄 Calling purchaseService.purchaseReward...")
            let success = try await purchaseService.purchaseReward(reward, userId: userId)
            print("✅ Purchase service returned: \(success)")
            
            if success {
                print("🔄 Deducting 200 points from user account...")
                // Deduct 200 points from user's account
                try await ProfileService.shared.updateUserPoints(userId: userId, pointsToAdd: -200)
                print("✅ Points deducted successfully")
                
                print("🔄 Refreshing user profile...")
                // Refresh user profile to update points
                await authViewModel.loadUserProfile()
                print("✅ User profile refreshed")
                
                print("🔄 Closing checkout and showing confirmation...")
                // Close checkout view and show confirmation
                DispatchQueue.main.async {
                    showConfirmation = true
                }
                
                // Close checkout view after a short delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    dismiss()
                }
                print("✅ Checkout closed and confirmation shown")
            } else {
                print("❌ Purchase service returned false")
                // User doesn't have premium subscription
                showSubscriptionView = true
            }
        } catch {
            print("❌ Error processing purchase: \(error)")
            // Handle error - could show an alert
        }
        
        isProcessingPurchase = false
        print("🔄 Purchase process completed")
    }
}

struct ConfirmationView: View {
    let reward: RewardCard
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var authViewModel: AuthViewModel
    @ObservedObject private var purchaseService = PurchaseService.shared
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Main content card
                VStack(spacing: 24) {
                    // Confirmation message
                    VStack(spacing: 16) {
                        Text("Tack för din beställning!")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.black)
                            .multilineTextAlignment(.center)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("För att ta del av erbjudandet:")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.black)
                            
                            Text("1. Kopiera koden nedan")
                                .font(.system(size: 14))
                                .foregroundColor(.gray)
                            
                            Text("2. Använd den på erbjudandets hemsida")
                                .font(.system(size: 14))
                                .foregroundColor(.gray)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.top, 40)
                    
                    // Code section
                    VStack(spacing: 12) {
                        HStack {
                            Text(getDiscountCode(for: reward.brandName))
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.black)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                                .background(Color.white)
                                .cornerRadius(8)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                                )
                            
                            Button(action: {
                                // Copy code to clipboard
                                UIPasteboard.general.string = getDiscountCode(for: reward.brandName)
                            }) {
                                Image(systemName: "doc.on.doc")
                                    .font(.system(size: 16))
                                    .foregroundColor(.white)
                                    .frame(width: 40, height: 40)
                                    .background(Color.black)
                                    .cornerRadius(8)
                            }
                        }
                    }
                    
                    // Additional information
                    Text("Du hittar information om din beställning i 'Mina köp'")
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                    
                    Spacer()
                    
                    // Action buttons
                    VStack(spacing: 12) {
                        Button(action: {
                            openCompanyWebsite(for: reward.brandName)
                        }) {
                            Text("BESÖK HEMSIDA")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(16)
                                .background(Color.black)
                                .cornerRadius(10)
                        }
                        
                        Button(action: {
                            dismiss()
                        }) {
                            Text("INTE NU")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.black)
                                .frame(maxWidth: .infinity)
                                .padding(16)
                                .background(Color.white)
                                .cornerRadius(10)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(Color.black, lineWidth: 1)
                                )
                        }
                    }
                    .padding(.bottom, 20)
                }
                .padding(.horizontal, 20)
                .background(Color.white)
                .cornerRadius(16)
                .padding(.horizontal, 16)
                .padding(.vertical, 20)
            }
            .background(Color(.systemGray6))
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        dismiss()
                    }) {
                        Image(systemName: "chevron.left")
                            .foregroundColor(.black)
                            .frame(width: 32, height: 32)
                            .background(Color(.systemGray5))
                            .cornerRadius(16)
                    }
                }
            }
            .onAppear {
                // Save purchase when confirmation view appears
                if let userId = authViewModel.currentUser?.id {
                    purchaseService.addMockPurchase(brandName: reward.brandName, discount: reward.discount, userId: userId)
                }
            }
        }
    }
    
    private func getDiscountCode(for brandName: String) -> String {
        switch brandName {
        case "PLIKTGOLF":
            return "T59W1DH7B81J"
        case "PEGMATE":
            return "Pegmate2026"
        case "LONEGOLF":
            return "UP&DOWN_10"
        case "WINWIZE":
            return "9AEWBGBZV5HR"
        case "SCANDIGOLF":
            return "A0Z8JNnsE"
        case "Exotic Golf":
            return "upanddown15"
        case "HAPPYALBA":
            return "HAPPY2025"
        case "RETROGOLF":
            return "Upanddown20"
        case "PUMPLABS":
            return "UPNDOWN15"
        case "ZEN ENERGY":
            return "UPDOWN15"
        default:
            return "CODE2025"
        }
    }
    
    private func openCompanyWebsite(for brandName: String) {
        let urlString: String
        
        switch brandName {
        case "PUMPLABS":
            urlString = "https://pumplab.se/"
        case "Exotic Golf":
            urlString = "https://exoticagolf.se/"
        case "ZEN ENERGY":
            urlString = "https://zenenergydrinks.com/?srsltid=AfmBOoo0XewnkvbPLeH1CbuslALX3C-hEOOaf_jJuHh3XMGlHm-rB2Pb"
        case "HAPPYALBA":
            urlString = "https://www.happyalba.com/"
        case "LONEGOLF":
            urlString = "https://lonegolf.se"
        case "PEGMATE":
            urlString = "https://pegmate.se/en/"
        case "PLIKTGOLF":
            urlString = "https://pliktgolf.se"
        case "RETROGOLF":
            urlString = "https://retrogolfacademy.se/"
        case "SCANDIGOLF":
            urlString = "https://www.scandigolf.se/"
        case "WINWIZE":
            urlString = "https://winwize.com/?srsltid=AfmBOootwFRqBXLHIeZW7SD8Em9h3_XydIfKOpTSt_uB01nndveoqM0J"
        default:
            urlString = "https://google.com" // Fallback
        }
        
        if let url = URL(string: urlString) {
            UIApplication.shared.open(url)
        }
    }
}

struct AllRewardsCard: View {
    let reward: RewardCard
    
    var body: some View {
        VStack(spacing: 8) {
            // Brand logo
            Image(getBrandLogo(for: reward.imageName))
                .resizable()
                .scaledToFit()
                .frame(width: 30, height: 30)
                .clipShape(Circle())
            
            VStack(spacing: 2) {
                Text(reward.discount)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.black)
                    .multilineTextAlignment(.center)
                
                Text(reward.brandName)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
        }
        .frame(width: 80, height: 80)
        .padding(8)
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
    
    private func getBrandLogo(for imageName: String) -> String {
        switch imageName {
        case "4": return "15" // PLIKTGOLF
        case "5": return "5"  // PEGMATE
        case "6": return "14" // LONEGOLF
        case "7": return "17" // WINWIZE
        case "8": return "18" // SCANDIGOLF
        case "9": return "19" // Exotic Golf
        case "10": return "16" // HAPPYALBA (Alba)
        case "11": return "20" // RETROGOLF
        case "12": return "21" // PUMPLABS
        case "13": return "22" // ZEN ENERGY
        default: return "5" // Default to PEGMATE
        }
    }
}

#Preview {
    RewardsView()
        .environmentObject(AuthViewModel())
}
