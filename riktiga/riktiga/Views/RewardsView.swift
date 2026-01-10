import SwiftUI
import UIKit

struct RewardCatalog {
    static let all: [RewardCard] = [
        // MARK: - Golf
        RewardCard(
            id: 1,
            brandName: "PLIKTGOLF",
            discount: "10% rabatt",
            points: "200 poäng",
            imageName: "56",
            category: "Golf",
            isBookmarked: false
        ),
        RewardCard(
            id: 2,
            brandName: "PEGMATE",
            discount: "5% rabatt",
            points: "200 poäng",
            imageName: "49",
            category: "Golf",
            isBookmarked: false
        ),
        RewardCard(
            id: 3,
            brandName: "LONEGOLF",
            discount: "10% rabatt",
            points: "200 poäng",
            imageName: "50",
            category: "Golf",
            isBookmarked: false
        ),
        RewardCard(
            id: 4,
            brandName: "WINWIZE",
            discount: "20% rabatt",
            points: "200 poäng",
            imageName: "51",
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
            id: 7,
            brandName: "HAPPYALBA",
            discount: "10% rabatt",
            points: "200 poäng",
            imageName: "57",
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
        
        // MARK: - Energidryck (ny kategori)
        RewardCard(
            id: 31,
            brandName: "FUSE ENERGY",
            discount: "10% rabatt",
            points: "200 poäng",
            imageName: "48",
            category: "Energidryck",
            isBookmarked: false
        ),
        RewardCard(
            id: 32,
            brandName: "ZEN ENERGY",
            discount: "15% rabatt",
            points: "200 poäng",
            imageName: "52",
            category: "Energidryck",
            isBookmarked: false
        ),
        RewardCard(
            id: 33,
            brandName: "CLYRO",
            discount: "20% rabatt",
            points: "200 poäng",
            imageName: "53",
            category: "Energidryck",
            isBookmarked: false
        ),
        
        // MARK: - Gym (endast PUMPLABS, CLYRO, Powerwell)
        RewardCard(
            id: 9,
            brandName: "PUMPLABS",
            discount: "15% rabatt",
            points: "200 poäng",
            imageName: "54",
            category: "Gym",
            isBookmarked: false
        ),
        RewardCard(
            id: 24,
            brandName: "CLYRO",
            discount: "20% rabatt",
            points: "200 poäng",
            imageName: "53",
            category: "Gym",
            isBookmarked: false
        ),
        RewardCard(
            id: 27,
            brandName: "Powerwell",
            discount: "15% rabatt",
            points: "200 poäng",
            imageName: "55",
            category: "Gym",
            isBookmarked: false
        ),
        
        // MARK: - Löpning
        RewardCard(
            id: 11,
            brandName: "ZEN ENERGY",
            discount: "15% rabatt",
            points: "200 poäng",
            imageName: "52",
            category: "Löpning",
            isBookmarked: false
        ),
        RewardCard(
            id: 21,
            brandName: "FUSE ENERGY",
            discount: "10% rabatt",
            points: "200 poäng",
            imageName: "48",
            category: "Löpning",
            isBookmarked: false
        ),
        RewardCard(
            id: 25,
            brandName: "CLYRO",
            discount: "20% rabatt",
            points: "200 poäng",
            imageName: "53",
            category: "Löpning",
            isBookmarked: false
        ),
        RewardCard(
            id: 28,
            brandName: "XEEIL",
            discount: "15% rabatt",
            points: "200 poäng",
            imageName: "44",
            category: "Löpning",
            isBookmarked: false
        ),
        
        // MARK: - Skidåkning (utan FUSE ENERGY)
        RewardCard(
            id: 19,
            brandName: "CAPSTONE",
            discount: "10% rabatt",
            points: "200 poäng",
            imageName: "34",
            category: "Skidåkning",
            isBookmarked: false
        ),
        RewardCard(
            id: 26,
            brandName: "Fjällsyn UF",
            discount: "15% rabatt",
            points: "200 poäng",
            imageName: "38",
            category: "Skidåkning",
            isBookmarked: false
        ),
        RewardCard(
            id: 30,
            brandName: "XEEIL",
            discount: "15% rabatt",
            points: "200 poäng",
            imageName: "44",
            category: "Skidåkning",
            isBookmarked: false
        )
    ]
}

struct HeroBannerAsset: Identifiable {
    let id = UUID()
    let imageName: String
    let url: String
}

struct RewardsView: View {
    @State private var selectedCategory = "Energidryck"
    @State private var currentHeroIndex = 0
    @State private var searchText = ""
    @State private var showSearchView = false
    @State private var showFavorites = false
    @State private var showMyPurchases = false
    @State private var favoritedRewards: Set<Int> = []
    @State private var navigationPath = NavigationPath()
    @EnvironmentObject var authViewModel: AuthViewModel
    @Environment(\.colorScheme) var colorScheme
    
    // Adaptive colors
    private var pageBackgroundColor: Color {
        colorScheme == .dark ? Color.black : Color.white
    }
    private var sectionBackgroundColor: Color {
        colorScheme == .dark ? Color.black : Color.white
    }
    private var cardBackground: Color {
        colorScheme == .dark ? Color(red: 0.12, green: 0.12, blue: 0.12) : Color.white
    }
    private var primaryTextColor: Color {
        colorScheme == .dark ? Color.white : Color.black
    }
    private var secondaryTextColor: Color {
        Color.gray
    }
    
    let heroBanners: [HeroBannerAsset] = [
        HeroBannerAsset(imageName: "2", url: "https://pliktgolf.se"),
        HeroBannerAsset(imageName: "3", url: "https://lonegolf.se")
    ]
    
    let categories = ["Energidryck", "Gym", "Löpning", "Golf", "Skidåkning"]
    
    let allRewards = RewardCatalog.all
    
    // Pre-sorted rewards cache - computed once
    private var energyDrinkRewards: [RewardCard] { sortedRewards(for: "Energidryck") }
    private var gymRewards: [RewardCard] { sortedRewards(for: "Gym") }
    private var runningRewards: [RewardCard] { sortedRewards(for: "Löpning") }
    private var golfRewards: [RewardCard] { sortedRewards(for: "Golf") }
    private var skiRewards: [RewardCard] { sortedRewards(for: "Skidåkning") }
    
    private func sortedRewards(for category: String) -> [RewardCard] {
        let rewards = allRewards.filter { $0.category == category }
        
        if category == "Golf" {
            let priority: [String: Int] = [
                "J.LINDEBERG": 0,
                "LONEGOLF": 0,
                "PLIKTGOLF": 1
            ]
            
            return rewards.sorted { lhs, rhs in
                let leftPriority = priority[lhs.brandName] ?? Int.max
                let rightPriority = priority[rhs.brandName] ?? Int.max
                
                if leftPriority != rightPriority {
                    return leftPriority < rightPriority
                }
                
                return featuredSort(lhs, rhs)
            }
        }
        
        if category == "Skidåkning" {
            let priority: [String: Int] = [
                "J.LINDEBERG": 0
            ]
            
            return rewards.sorted { lhs, rhs in
                let leftPriority = priority[lhs.brandName] ?? Int.max
                let rightPriority = priority[rhs.brandName] ?? Int.max
                
                if leftPriority != rightPriority {
                    return leftPriority < rightPriority
                }
                
                return featuredSort(lhs, rhs)
            }
        }
        
        if category == "Löpning" {
            let priority: [String: Int] = [
                "FUSE ENERGY": 0
            ]
            
            return rewards.sorted { lhs, rhs in
                let leftPriority = priority[lhs.brandName] ?? Int.max
                let rightPriority = priority[rhs.brandName] ?? Int.max
                
                if leftPriority != rightPriority {
                    return leftPriority < rightPriority
                }
                
                return featuredSort(lhs, rhs)
            }
        }
        
        return rewards.sorted(by: featuredSort(_:_:))
    }
    
    private func featuredSort(_ first: RewardCard, _ second: RewardCard) -> Bool {
        if first.brandName == "PUMPLABS" && second.brandName != "PUMPLABS" {
            return true
        }
        if second.brandName == "PUMPLABS" && first.brandName != "PUMPLABS" {
            return false
        }
        
        if first.brandName == "ZEN ENERGY" && second.brandName != "ZEN ENERGY" && second.brandName != "PUMPLABS" {
            return true
        }
        if second.brandName == "ZEN ENERGY" && first.brandName != "ZEN ENERGY" && first.brandName != "PUMPLABS" {
            return false
        }
        
        return first.brandName < second.brandName
    }
    
    private var heroBannerSection: some View {
        TabView(selection: $currentHeroIndex) {
            ForEach(heroBanners.indices, id: \.self) { index in
                let banner = heroBanners[index]
                HeroBannerCard(imageName: banner.imageName)
                    .contentShape(Rectangle())
                    .tag(index)
                    .onTapGesture {
                        if let url = URL(string: banner.url) {
                            UIApplication.shared.open(url)
                        }
                    }
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .automatic))
        .frame(height: 200)
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
    }
    
    private var categoriesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Kategorier")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(primaryTextColor)
                .padding(.horizontal, 16)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(categories, id: \.self) { category in
                        NavigationLink {
                            CategoryRewardsListView(
                                category: category,
                                rewards: sortedRewards(for: category),
                                favoritedRewards: $favoritedRewards
                            )
                        } label: {
                            CategoryButton(
                                category: category,
                                isSelected: selectedCategory == category
                            )
                        }
                        .buttonStyle(.plain)
                        .simultaneousGesture(
                            TapGesture().onEnded {
                                selectedCategory = category
                            }
                        )
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }
    
    @ViewBuilder
    private func sliderSection(title: String, category: String) -> some View {
        let rewards = sortedRewards(for: category)
        sliderSectionOptimized(title: title, rewards: rewards)
    }
    
    @ViewBuilder
    private func sliderSectionOptimized(title: String, rewards: [RewardCard]) -> some View {
        if rewards.isEmpty {
            EmptyView()
        } else {
            VStack(alignment: .leading, spacing: 0) {
                // Section header with "Se alla"
                HStack {
                    Text(title)
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(primaryTextColor)
                    
                    Spacer()
                    
                    NavigationLink {
                        CategoryRewardsListView(
                            category: title,
                            rewards: rewards,
                            favoritedRewards: $favoritedRewards
                        )
                    } label: {
                        HStack(spacing: 4) {
                            Text("Se alla")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(.gray)
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.gray)
                        }
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 16)
                .padding(.top, 20)
                .padding(.bottom, 16)
                
                // Horizontal scroll of reward cards with snapping
                SnappingRewardScrollView(rewards: rewards, favoritedRewards: $favoritedRewards)
            }
            .background(sectionBackgroundColor)
            .clipped()
        }
    }
    
    var body: some View {
        NavigationStack(path: $navigationPath) {
            ZStack {
                pageBackgroundColor
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // MARK: - Fixed Strava-Style Navigation Header
                    StravaStyleHeaderView()
                        .environmentObject(authViewModel)
                        .zIndex(1)
                    
                    ScrollView {
                        VStack(spacing: 0) {
                        // MARK: - Header with Search, Favorites, and Points
                        VStack(spacing: 16) {
                            // Top row with points and icons
                            HStack {
                                // Points display
                                HStack(spacing: 8) {
                                    Image(systemName: "gift.fill")
                                        .foregroundColor(colorScheme == .dark ? .black : .white)
                                        .font(.system(size: 16))
                                    
                                    Text("\(authViewModel.currentUser?.currentXP ?? 0)")
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(colorScheme == .dark ? .black : .white)
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(primaryTextColor)
                                .cornerRadius(20)
                                
                                Spacer()
                                
                                // Right side icons
                                HStack(spacing: 16) {
                                    Button(action: {
                                        showMyPurchases = true
                                    }) {
                                        Image(systemName: "bag.fill")
                                            .foregroundColor(primaryTextColor)
                                            .font(.system(size: 20))
                                    }
                                    
                                    Button(action: {
                                        showFavorites = true
                                    }) {
                                        Image(systemName: "bookmark.fill")
                                            .foregroundColor(primaryTextColor)
                                            .font(.system(size: 20))
                                    }
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.top, 8)
                            
                            // Search bar
                            Button(action: {
                                showSearchView = true
                            }) {
                                HStack {
                                    Image(systemName: "magnifyingglass")
                                        .foregroundColor(secondaryTextColor)
                                        .font(.system(size: 16))
                                    
                                    Text("Sök")
                                        .font(.system(size: 16))
                                        .foregroundColor(secondaryTextColor)
                                    
                                    Spacer()
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                                .background(cardBackground)
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                                )
                            }
                            .padding(.horizontal, 16)
                        }
                        .padding(.bottom, 16)
                        .background(sectionBackgroundColor)
                        
                        LazyVStack(spacing: 12) {
                            heroBannerSection
                                .background(sectionBackgroundColor)
                            
                            categoriesSection
                                .padding(.vertical, 16)
                                .background(sectionBackgroundColor)
                            
                            sliderSectionOptimized(title: "Energidryck", rewards: energyDrinkRewards)
                            
                            sliderSectionOptimized(title: "Gym", rewards: gymRewards)
                            
                            sliderSectionOptimized(title: "Löpning", rewards: runningRewards)
                            
                            sliderSectionOptimized(title: "Golf", rewards: golfRewards)
                            
                            sliderSectionOptimized(title: "Skidåkning", rewards: skiRewards)
                            
                            Spacer(minLength: 100)
                        }
                        }
                    }
                }
            }
            .navigationBarHidden(true)
            .enableSwipeBack()
            .tint(primaryTextColor) // Adaptive back buttons
            .sheet(isPresented: $showSearchView) {
                SearchRewardsView(allRewards: allRewards)
            }
            .sheet(isPresented: $showFavorites) {
                FavoritesView(favoritedRewards: $favoritedRewards, allRewards: allRewards)
            }
            .sheet(isPresented: $showMyPurchases) {
                MyPurchasesView()
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("PopToRootBeloningar"))) { _ in
                navigationPath = NavigationPath()
            }
        }
        .tint(primaryTextColor) // Adaptive back buttons for all navigation
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
            .drawingGroup() // Rasterize for smoother transitions
    }
}

struct CategoryButton: View {
    let category: String
    let isSelected: Bool
    @Environment(\.colorScheme) var colorScheme
    
    private var cardBackground: Color {
        colorScheme == .dark ? Color(red: 0.12, green: 0.12, blue: 0.12) : Color.white
    }
    
    private var primaryTextColor: Color {
        colorScheme == .dark ? Color.white : Color.black
    }
    
    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: iconName)
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(isSelected ? (colorScheme == .dark ? .black : .white) : .gray)
            
            Text(category)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(isSelected ? (colorScheme == .dark ? .black : .white) : .gray)
        }
        .frame(width: 80, height: 80)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isSelected ? primaryTextColor : cardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isSelected ? Color.clear : Color.gray.opacity(0.2), lineWidth: 1)
        )
    }
    
    private var iconName: String {
        switch category {
        case "Energidryck":
            return "bolt.fill"
        case "Golf":
            return "flag.fill"
        case "Löpning":
            return "figure.run"
        case "Gym":
            return "dumbbell.fill"
        case "Skidåkning":
            return "figure.skiing.downhill"
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

// Snapping scroll view for reward cards
struct SnappingRewardScrollView: View {
    let rewards: [RewardCard]
    @Binding var favoritedRewards: Set<Int>
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: 16) {
                ForEach(rewards) { reward in
                    NavigationLink {
                        RewardDetailView(reward: reward)
                    } label: {
                        ModernRewardCard(reward: reward, favoritedRewards: $favoritedRewards)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .id(reward.id)
                }
            }
            .scrollTargetLayout()
            .padding(.horizontal, 24)
            .padding(.bottom, 20)
        }
        .scrollTargetBehavior(.viewAligned)
        .contentMargins(.horizontal, 0, for: .scrollContent)
    }
}

// Modern card design matching the inspiration
struct ModernRewardCard: View {
    let reward: RewardCard
    @Binding var favoritedRewards: Set<Int>
    @Environment(\.colorScheme) var colorScheme
    
    private let cardWidth: CGFloat = UIScreen.main.bounds.width - 64
    private let imageHeight: CGFloat = 260
    
    private var isBookmarked: Bool {
        favoritedRewards.contains(reward.id)
    }
    
    private var cardBackground: Color {
        colorScheme == .dark ? Color(red: 0.12, green: 0.12, blue: 0.12) : Color.white
    }
    
    private var primaryTextColor: Color {
        colorScheme == .dark ? Color.white : Color.black
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Image section with badge
            ZStack(alignment: .topTrailing) {
                Image(reward.imageName)
                    .resizable()
                    .scaledToFill()
                    .frame(width: cardWidth, height: imageHeight)
                    .clipped()
                
                // Points badge
                HStack(spacing: 4) {
                    Image(systemName: "gift.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(primaryTextColor)
                    
                    Text("200")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(primaryTextColor)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(cardBackground)
                .clipShape(Capsule())
                .shadow(color: .black.opacity(colorScheme == .dark ? 0.3 : 0.1), radius: 4, x: 0, y: 2)
                .padding(16)
            }
            
            // Info section
            HStack(spacing: 14) {
                // Brand logo
                Image(getBrandLogo(for: reward.imageName))
                    .resizable()
                    .scaledToFit()
                    .frame(width: 52, height: 52)
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(Color.gray.opacity(0.15), lineWidth: 1)
                    )
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(reward.discount)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(primaryTextColor)
                        .lineLimit(2)
                    
                    Text(reward.brandName)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.gray)
                        .textCase(.uppercase)
                }
                
                Spacer()
                
                // Bookmark button
                Button(action: {
                    if isBookmarked {
                        favoritedRewards.remove(reward.id)
                    } else {
                        favoritedRewards.insert(reward.id)
                    }
                }) {
                    Image(systemName: isBookmarked ? "bookmark.fill" : "bookmark")
                        .font(.system(size: 20))
                        .foregroundColor(isBookmarked ? primaryTextColor : .gray)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 18)
            .background(cardBackground.opacity(0.5))
        }
        .frame(width: cardWidth)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(colorScheme == .dark ? 0.3 : 0.06), radius: 8, x: 0, y: 4)
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
        case "34": return "34" // CAPSTONE
        case "35": return "46" // FUSE ENERGY (old)
        case "48": return "46" // FUSE ENERGY (new cover)
        case "38": return "38" // Fjällsyn UF
        case "39": return "39" // CLYRO (old)
        case "53": return "39" // CLYRO (new cover)
        case "40": return "40" // Powerwell (old)
        case "55": return "40" // Powerwell (new cover)
        case "44": return "45" // XEEIL
        default: return imageName // Use the image itself as logo if no mapping
        }
    }
}

struct FullScreenRewardCard: View {
    let reward: RewardCard
    @Binding var favoritedRewards: Set<Int>
    
    static let cardHeight: CGFloat = 360
    
    private let cornerRadius: CGFloat = 24
    private let cardBackground = Color(.secondarySystemBackground)
    private let infoBackground = Color(red: 247/255, green: 247/255, blue: 255/255)
    private let accentColor = Color(red: 78/255, green: 77/255, blue: 255/255)
    
    private var isBookmarked: Bool {
        favoritedRewards.contains(reward.id)
    }
    
    var body: some View {
        cardContent
            .drawingGroup() // Rasterize for smoother scrolling
    }
    
    private var cardContent: some View {
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
                        .foregroundColor(.primary)
                    
                    Text(reward.points)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.primary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.white)
                .clipShape(Capsule())
                .padding(18)
            }
            
            HStack(spacing: 16) {
                Image(getBrandLogo(for: reward.imageName))
                    .resizable()
                    .scaledToFit()
                    .frame(width: 48, height: 48)
                    .clipShape(Circle())
                
                VStack(alignment: .leading, spacing: 6) {
                    Text(reward.discount)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.primary)
                    
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
        .shadow(color: Color.black.opacity(0.05), radius: 6, x: 0, y: 3) // Lighter shadow for performance
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
        case "34": return "34" // CAPSTONE
        case "35": return "46" // FUSE ENERGY (old)
        case "48": return "46" // FUSE ENERGY (new cover)
        case "38": return "38" // Fjällsyn UF
        case "39": return "39" // CLYRO (old)
        case "53": return "39" // CLYRO (new cover)
        case "40": return "40" // Powerwell (old)
        case "55": return "40" // Powerwell (new cover)
        case "44": return "45" // XEEIL
        default: return imageName // Use the image itself as logo if no mapping
        }
    }
}

struct CategoryRewardsListView: View {
    let category: String
    let rewards: [RewardCard]
    @Binding var favoritedRewards: Set<Int>
    @Environment(\.colorScheme) var colorScheme
    
    private var pageBackgroundColor: Color {
        colorScheme == .dark ? Color.black : Color.white
    }
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                ForEach(rewards, id: \.id) { reward in
                    NavigationLink {
                        RewardDetailView(reward: reward)
                    } label: {
                        ModernRewardCard(reward: reward, favoritedRewards: $favoritedRewards)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .id(reward.id)
                }
            }
            .padding(.vertical, 20)
            .padding(.horizontal, 16)
        }
        .background(pageBackgroundColor.ignoresSafeArea())
        .navigationTitle(category)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { NavigationDepthTracker.shared.setAtRoot(false) }
        .onDisappear { NavigationDepthTracker.shared.setAtRoot(true) }
    }
}

struct RewardDetailView: View {
    let reward: RewardCard
    @State private var showCheckout = false
    @State private var showConfirmation = false
    @State private var isImageLoaded = false
    @EnvironmentObject var authViewModel: AuthViewModel
    
    private var hasEnoughPoints: Bool {
        return (authViewModel.currentUser?.currentXP ?? 0) >= 200
    }
    
    var body: some View {
        ZStack {
            // Background white
            Color.white
                .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 0) {
                    // 1. Cover image - optimized
                    Image(reward.imageName)
                        .resizable()
                        .scaledToFill()
                        .frame(height: 250)
                        .clipped()
                        .drawingGroup() // Rasterize for better performance
                    
                    VStack(spacing: 24) {
                        // 2. Discount text and title
                        VStack(spacing: 8) {
                            Text(reward.discount)
                                .font(.system(size: 28, weight: .bold))
                                .foregroundColor(.primary)
                            
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
                                    .foregroundColor(.primary)
                            }
                            .padding(.top, 24)
                            
                            // Company description
                            Text(getCompanyDescription(for: reward.brandName))
                                .font(.system(size: 14))
                                .foregroundColor(.primary)
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
                                    .foregroundColor(.primary)
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
                        .padding(.bottom, 100) // Extra bottom padding for safe scrolling
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
        .onAppear { NavigationDepthTracker.shared.setAtRoot(false) }
        .onDisappear { NavigationDepthTracker.shared.setAtRoot(true) }
    }
    
    private func getCompanyDescription(for brandName: String) -> String {
        switch brandName {
        case "PLIKTGOLF":
            return "Pliktgolf startade hösten 2023 med målet att göra golf mer tillgängligt och hållbart genom att sälja återvunna premiumbollar till ett lägre pris. Tillsammans med golfklubbar samlar de in bortslagna bollar från vatten och natur, rengör och sorterar dem, och erbjuder sedan golfare ett cirkulärt alternativ kompletterat med träningstillbehör och teknik."
        case "PEGMATE":
            return "Pegmate är en svensk uppfinning från Karlshamn/Mörrum i Blekinge. En extra peg-hållare med elastiskt fäste som sitter kvar i marken och gör att peggen inte flyger iväg vid utslag eller på rangen. Produkten är lokalproducerad, giftfri och fungerar lika bra på gräs som konstgräs."
        case "LONEGOLF":
            return "Lone Golf är ett svenskt startup-varumärke som designar och säljer egna golfklubbor med ambitionen att ge premiumkänsla till ett mer tillgängligt pris. Fokus ligger på egen design, teknik och en rak dialog med golfare."
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
            return "PumpLab tar fram högkvalitativa kosttillskott utvecklade och producerade i Sverige. Fokus ligger på rena ingredienser, tydliga doser och produkter som faktiskt levererar resultat – bättre prestation, snabbare återhämtning och god smak för dig som vill ta träningen till nästa nivå."
        case "ZEN ENERGY":
            return "Zen Energy är energidrycken för dig som vill ta både kroppen och hjärnan till nästa nivå. Varje burk innehåller 10 g veganskt protein, 165 mg naturligt koffein och 300 mg ekologiskt Lion’s Mane för skärpa och fokus – plus ett komplett vitaminkomplex utan artificiella tillsatser."
        case "CAPSTONE":
            return "Capstone fokuserar på skidglasögon och tillbehör med magnetiska linser som enkelt anpassas efter ljusförhållanden. Målet är att kombinera stil, komfort och funktion för skidåkare som vill ha premiumkänsla utan att kompromissa."
        case "FUSE ENERGY":
            return "Fuse Energy ger dig smart energi på ett nytt sätt. Istället för burkar får du en brustablett – med koffein, L-teanin och vitaminer – som du löser i vatten. Resultatet är ren, effektiv energi och skärpt fokus utan socker, krascher eller onödigt släp. Perfekt för träning, studier eller dagar när du behöver ett extra lyft."
        case "J.LINDEBERG":
            return "J.Lindeberg kombinerar skandinaviskt mode med högpresterande sportplagg. Kollektionerna är designade för golfbanan och backen med tekniska material, skarpa snitt och premiumdetaljer – så att du kan prestera på topp och samtidigt se ut som ett proffs."
        case "CLYRO":
            return "Clyro tillverkar energidrycker med 20 gram protein och hög kvalitet så att du kan kombinera boost och återhämtning i samma burk. Perfekt före eller efter gymmet – utan att kompromissa på smak eller innehåll."
        case "Fjällsyn UF":
            return "Fjällsyn tillverkar moderna och stilrena skidglasögon till schyssta priser – designade i svensk fjällmiljö för att du ska få bästa sikt på berget."
        case "Powerwell":
            return "Powerwell tillverkar PWO och kosttillskott av hög kvalitet för dig som vill prestera varje pass. Svenska recept, rena ingredienser och brutalt fokus på effekt utan onödiga tillsatser."
        case "XEEIL":
            return "XEEIL är ett innovativt doftstift utvecklat utifrån aromaterapeutiska principer. Vi kombinerar uppfriskande mentol med noggrant utvalda naturliga eteriska oljor för att skapa en balanserad och effektiv doftupplevelse."
        default:
            return "Ett företag som erbjuder högkvalitativa produkter för din aktivitet."
        }
    }
    
    private func getCompanyLogo(for brandName: String) -> String {
        switch brandName {
        case "J.LINDEBERG":
            return "37"
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
        case "CAPSTONE":
            return "34"
        case "FUSE ENERGY":
            return "46"
        case "CLYRO":
            return "39"
        case "Fjällsyn UF":
            return "38"
        case "Powerwell":
            return "40"
        case "XEEIL":
            return "45"
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
        case "CAPSTONE":
            urlString = "https://capstone.nu/"
        case "FUSE ENERGY":
            urlString = "https://fuseenergy.se"
        case "RETROGOLF":
            urlString = "https://retrogolfacademy.se/"
        case "SCANDIGOLF":
            urlString = "https://www.scandigolf.se/"
        case "WINWIZE":
            urlString = "https://winwize.com/?srsltid=AfmBOootwFRqBXLHIeZW7SD8Em9h3_XydIfKOpTSt_uB01nndveoqM0J"
        case "J.LINDEBERG":
            urlString = "https://jlindeberg.com/"
        case "CLYRO":
            urlString = "https://clyro.se/"
        case "Fjällsyn UF":
            urlString = "https://fjallsynuf.se/"
        case "Powerwell":
            urlString = "https://powerwell.se/"
        case "XEEIL":
            urlString = "https://xeeil.se"
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
    private let purchaseService = PurchaseService.shared
    
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
                            .foregroundColor(.primary)
                        
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
                                .foregroundColor(.primary)
                            
                            TextField("Ange ditt förnamn", text: $firstName)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Efternamn")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.primary)
                            
                            TextField("Ange ditt efternamn", text: $lastName)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("E-post")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.primary)
                            
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
                                .foregroundColor(.primary)
                            
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
    private let purchaseService = PurchaseService.shared
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Main content card
                VStack(spacing: 24) {
                    // Confirmation message
                    VStack(spacing: 16) {
                        Text("Tack för din beställning!")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.primary)
                            .multilineTextAlignment(.center)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("För att ta del av erbjudandet:")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.primary)
                            
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
                                .foregroundColor(.primary)
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
                                .foregroundColor(.primary)
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
            .background(Color.white)
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        dismiss()
                    }) {
                        Image(systemName: "chevron.left")
                            .foregroundColor(.primary)
                            .frame(width: 32, height: 32)
                            .background(Color.white)
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
        case "CAPSTONE":
            return "CAPSTONE10"
        case "FUSE ENERGY":
            return "Wiggo"
        case "CLYRO":
            return "Up&Down20"
        case "Fjällsyn UF":
            return "FJÄLLSYN15PÅALLT"
        case "Powerwell":
            return "1EFN34345G1J"
        case "XEEIL":
            return "SNOWSTORM15"
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
        case "CAPSTONE":
            urlString = "https://capstone.nu/"
        case "FUSE ENERGY":
            urlString = "https://fuseenergy.se"
        case "RETROGOLF":
            urlString = "https://retrogolfacademy.se/"
        case "SCANDIGOLF":
            urlString = "https://www.scandigolf.se/"
        case "WINWIZE":
            urlString = "https://winwize.com/?srsltid=AfmBOootwFRqBXLHIeZW7SD8Em9h3_XydIfKOpTSt_uB01nndveoqM0J"
        case "CLYRO":
            urlString = "https://clyro.se/"
        case "Fjällsyn UF":
            urlString = "https://fjallsynuf.se/"
        case "Powerwell":
            urlString = "https://powerwell.se/"
        case "XEEIL":
            urlString = "https://xeeil.se"
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
                    .foregroundColor(.primary)
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
        .drawingGroup() // Rasterize for better scroll performance
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
        case "34": return "34" // CAPSTONE
        case "35": return "46" // FUSE ENERGY (old)
        case "48": return "46" // FUSE ENERGY (new cover)
        case "38": return "38" // Fjällsyn
        case "39": return "39" // CLYRO (old)
        case "53": return "39" // CLYRO (new cover)
        case "40": return "40" // Powerwell (old)
        case "55": return "40" // Powerwell (new cover)
        case "44": return "45" // XEEIL
        default: return imageName // Use the image itself as logo if no mapping
        }
    }
}

#Preview {
    RewardsView()
        .environmentObject(AuthViewModel())
}
