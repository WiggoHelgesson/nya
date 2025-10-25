import SwiftUI

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
                Color(.systemBackground)
                
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
                                    ForEach(0..<heroImages.count, id: \.self) { index in
                                        HeroBannerCard(
                                            imageName: heroImages[index]
                                        )
                                        .frame(width: UIScreen.main.bounds.width - 32)
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
                                                FullScreenRewardCard(reward: reward, favoritedRewards: $favoritedRewards)
                                            }
                                            .buttonStyle(PlainButtonStyle())
                                            .id(index)
                                        }
                                    }
                                    .padding(.horizontal, 24)
                                    .scrollTargetLayout()
                                }
                                .scrollTargetBehavior(.viewAligned)
                                .onAppear {
                                    proxy.scrollTo(currentRewardIndex, anchor: .center)
                                }
                            }
                        }
                        
                        // MARK: - Alla belöningar Section
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Alla belöningar")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(.black)
                                .padding(.horizontal, 16)
                            
                            ScrollViewReader { proxy in
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 16) {
                                        ForEach(Array(sortedAllRewards.enumerated()), id: \.element.id) { index, reward in
                                            NavigationLink(destination: RewardDetailView(reward: reward)) {
                                                FullScreenRewardCard(reward: reward, favoritedRewards: $favoritedRewards)
                                            }
                                            .buttonStyle(PlainButtonStyle())
                                            .id(index)
                                        }
                                    }
                                    .padding(.horizontal, 24)
                                    .scrollTargetLayout()
                                }
                                .scrollTargetBehavior(.viewAligned)
                                .onAppear {
                                    proxy.scrollTo(0, anchor: .center)
                                }
                            }
                        }
                        
                        Spacer(minLength: 100)
                    }
                    .padding(.top, 8)
                    }
                }
            }
            .navigationTitle("Belöningar")
            .navigationBarTitleDisplayMode(.inline)
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
    
    private var isBookmarked: Bool {
        favoritedRewards.contains(reward.id)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Image Section - Clean brand image only
            ZStack {
                Image(reward.imageName)
                    .resizable()
                    .scaledToFill()
                    .frame(height: 240) // Increased height for longer cards
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
            
            // Info Section - Clean like in the image
            HStack(spacing: 12) {
                // Brand logo based on imageName
                Image(getBrandLogo(for: reward.imageName))
                    .resizable()
                    .scaledToFit()
                    .frame(width: 40, height: 40)
                    .clipShape(Circle())
                
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
                    if isBookmarked {
                        favoritedRewards.remove(reward.id)
                    } else {
                        favoritedRewards.insert(reward.id)
                    }
                }) {
                    Image(systemName: isBookmarked ? "bookmark.fill" : "bookmark")
                        .font(.system(size: 18))
                        .foregroundColor(isBookmarked ? .black : .gray)
                }
            }
            .padding(20)
            .background(Color.white)
        }
        .frame(width: UIScreen.main.bounds.width * 0.8, height: 320)
        .cornerRadius(16)
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
    
    var body: some View {
        ZStack {
            // Gray background like in the image
            Color.gray.opacity(0.1)
                .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 24) {
                    // Company description card - like the white card in the image
                    VStack(spacing: 16) {
                        // Company logo at the top
                        VStack(spacing: 12) {
                            // Logo placeholder - circular white badge
                            ZStack {
                                Circle()
                                    .fill(Color.white)
                                    .frame(width: 80, height: 80)
                                    .overlay(
                                        Circle()
                                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                                    )
                                
                                // Company logo or initial
                                Text(String(reward.brandName.prefix(2)))
                                    .font(.system(size: 24, weight: .bold))
                                    .foregroundColor(.black)
                            }
                            
                            // Company name
                            Text(reward.brandName)
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.black)
                        }
                        .padding(.top, 20)
                        
                        // Company description
                        Text(getCompanyDescription(for: reward.brandName))
                            .font(.system(size: 14))
                            .foregroundColor(.black)
                            .multilineTextAlignment(.leading)
                            .lineLimit(nil)
                            .padding(.horizontal, 20)
                        
                        // Visit website button (like in the image)
                        Button(action: {
                            // Open company website
                        }) {
                            Text("BESÖK HEMSIDA")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.black)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Color.white)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                                )
                                .cornerRadius(8)
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 20)
                    }
                    .background(Color.white)
                    .cornerRadius(16)
                    .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    
                    // Discount info
                    VStack(spacing: 8) {
                        Text(reward.discount)
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.black)
                        
                        Text("för \(reward.brandName)")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.gray)
                    }
                    .padding(.horizontal, 20)
                    
                    // Claim reward button (like the purple button in the image)
                    Button(action: {
                        showCheckout = true
                    }) {
                        Text("HÄMTA BELÖNING")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.black)
                            .cornerRadius(12)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 30)
                }
            }
        }
        .navigationTitle(reward.brandName)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showCheckout) {
            CheckoutView(reward: reward)
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
        default:
            return "Ett företag som erbjuder högkvalitativa produkter för din aktivitet."
        }
    }
}

struct CheckoutView: View {
    let reward: RewardCard
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var authViewModel: AuthViewModel
    @StateObject private var purchaseService = PurchaseService.shared
    
    @State private var firstName = ""
    @State private var lastName = ""
    @State private var email = ""
    @State private var city = ""
    @State private var showConfirmation = false
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
                    .disabled(firstName.isEmpty || lastName.isEmpty || email.isEmpty || city.isEmpty || isProcessingPurchase)
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
            .sheet(isPresented: $showConfirmation) {
                ConfirmationView(reward: reward)
            }
            .sheet(isPresented: $showSubscriptionView) {
                SubscriptionView()
            }
        }
    }
    
    private func processPurchase() async {
        guard let userId = authViewModel.currentUser?.id else {
            print("❌ No user ID available")
            return
        }
        
        isProcessingPurchase = true
        
        do {
            let success = try await purchaseService.purchaseReward(reward, userId: userId)
            
            if success {
                showConfirmation = true
            } else {
                // User doesn't have premium subscription
                showSubscriptionView = true
            }
        } catch {
            print("❌ Error processing purchase: \(error)")
            // Handle error - could show an alert
        }
        
        isProcessingPurchase = false
    }
}

struct ConfirmationView: View {
    let reward: RewardCard
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var authViewModel: AuthViewModel
    @StateObject private var purchaseService = PurchaseService.shared
    
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
                            // Visit website action
                            print("Visiting website for \(reward.brandName)")
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
            .navigationTitle("FRAMGÅNGSAKADEMIN")
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
            return "PLIKT2025"
        case "PEGMATE":
            return "PEGMATE2025"
        case "LONEGOLF":
            return "LONE2025"
        case "WINWIZE":
            return "WINWIZE2025"
        case "SCANDIGOLF":
            return "SCANDI2025"
        case "Exotic Golf":
            return "EXOTIC2025"
        case "HAPPYALBA":
            return "HAPPY2025"
        case "RETROGOLF":
            return "RETRO2025"
        case "PUMPLABS":
            return "PUMP2025"
        case "ZEN ENERGY":
            return "ZEN2025"
        default:
            return "CODE2025"
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
