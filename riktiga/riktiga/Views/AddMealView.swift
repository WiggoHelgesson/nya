import SwiftUI
import Combine
import Supabase

// MARK: - Unified Food Item Model
struct FoodItem: Identifiable {
    let id: String
    let name: String
    let brand: String?
    let category: String?
    let calories: Double?
    let protein: Double?
    let carbs: Double?
    let fat: Double?
    let barcode: String?
    let source: FoodSource
    let imageUrl: String?
    let servingSize: String?
    let servingQuantity: Double?
    let nutriScore: String? // A, B, C, D, E
    let novaGroup: Int? // 1-4
    
    enum FoodSource {
        case livsmedelsverket
        case openFoodFacts
        case fatSecret
    }
    
    // Nutri-Score color
    var nutriScoreColor: Color {
        switch nutriScore?.uppercased() {
        case "A": return Color(red: 0.0, green: 0.5, blue: 0.2) // Dark green
        case "B": return Color(red: 0.5, green: 0.7, blue: 0.2) // Light green
        case "C": return Color(red: 0.9, green: 0.7, blue: 0.1) // Yellow
        case "D": return Color(red: 0.9, green: 0.5, blue: 0.1) // Orange
        case "E": return Color(red: 0.8, green: 0.2, blue: 0.1) // Red
        default: return Color.gray
        }
    }
}

// MARK: - Livsmedelsverket API Models
struct LivsmedelsverketFood: Codable, Identifiable {
    let nummer: Int
    let namn: String
    let huvudgrupp: String?
    let energiKcal: Double?
    let kolhydrater: Double?
    let protein: Double?
    let fett: Double?
    
    var id: Int { nummer }
    
    enum CodingKeys: String, CodingKey {
        case nummer
        case namn
        case huvudgrupp
        case energiKcal = "energi_kcal"
        case kolhydrater
        case protein
        case fett
    }
    
    func toFoodItem() -> FoodItem {
        FoodItem(
            id: "lv_\(nummer)",
            name: namn,
            brand: nil,
            category: huvudgrupp,
            calories: energiKcal,
            protein: protein,
            carbs: kolhydrater,
            fat: fett,
            barcode: nil,
            source: .livsmedelsverket,
            imageUrl: nil,
            servingSize: "100g",
            servingQuantity: 100,
            nutriScore: nil,
            novaGroup: nil
        )
    }
}

struct LivsmedelsverketResponse: Codable {
    let livsmedel: [LivsmedelsverketFoodItem]?
}

struct LivsmedelsverketListResponse: Codable {
    let livsmedel: [LivsmedelsverketFoodItem]
}

struct LivsmedelsverketFoodItem: Codable, Identifiable {
    let nummer: Int
    let namn: String
    let huvudgrupp: String?
    
    var id: Int { nummer }
    
    func toFoodItem() -> FoodItem {
        FoodItem(
            id: "lv_\(nummer)",
            name: namn,
            brand: nil,
            category: huvudgrupp,
            calories: nil,
            protein: nil,
            carbs: nil,
            fat: nil,
            barcode: nil,
            source: .livsmedelsverket,
            imageUrl: nil,
            servingSize: "100g",
            servingQuantity: 100,
            nutriScore: nil,
            novaGroup: nil
        )
    }
}

// MARK: - Open Food Facts API Models
struct OpenFoodFactsSearchResponse: Codable {
    let count: Int?
    let page: Int?
    let pageSize: Int?
    let products: [OpenFoodFactsProduct]?
    
    enum CodingKeys: String, CodingKey {
        case count, page, products
        case pageSize = "page_size"
    }
}

struct OpenFoodFactsProduct: Codable, Identifiable {
    let code: String?
    let productName: String?
    let brands: String?
    let categoriesTags: [String]?
    let nutriments: OpenFoodFactsNutriments?
    let imageUrl: String?
    let imageFrontUrl: String?
    let imageFrontSmallUrl: String?
    let servingSize: String?
    let servingQuantity: Double?
    let nutriscoreGrade: String?
    let novaGroup: Int?
    
    var id: String { code ?? UUID().uuidString }
    
    enum CodingKeys: String, CodingKey {
        case code, brands, nutriments
        case productName = "product_name"
        case categoriesTags = "categories_tags"
        case imageUrl = "image_url"
        case imageFrontUrl = "image_front_url"
        case imageFrontSmallUrl = "image_front_small_url"
        case servingSize = "serving_size"
        case servingQuantity = "serving_quantity"
        case nutriscoreGrade = "nutriscore_grade"
        case novaGroup = "nova_group"
    }
    
    func toFoodItem() -> FoodItem? {
        guard let name = productName, !name.isEmpty else { return nil }
        
        // Get best available calorie value
        let kcal100g = nutriments?.bestEnergyKcal
        
        // Calculate calories per serving if we have serving info
        var caloriesPerServing: Double? = nil
        if let kcal = kcal100g {
            if let servingQty = servingQuantity, servingQty > 0 {
                caloriesPerServing = (kcal * servingQty) / 100
            } else {
                caloriesPerServing = kcal
            }
        }
        
        return FoodItem(
            id: "off_\(code ?? UUID().uuidString)",
            name: name,
            brand: brands,
            category: categoriesTags?.first?.replacingOccurrences(of: "en:", with: "").replacingOccurrences(of: "-", with: " ").capitalized,
            calories: caloriesPerServing ?? kcal100g,
            protein: nutriments?.bestProteins,
            carbs: nutriments?.bestCarbs,
            fat: nutriments?.bestFat,
            barcode: code,
            source: .openFoodFacts,
            imageUrl: imageFrontSmallUrl ?? imageFrontUrl ?? imageUrl,
            servingSize: servingSize ?? "100g",
            servingQuantity: servingQuantity ?? 100,
            nutriScore: nutriscoreGrade,
            novaGroup: novaGroup
        )
    }
}

struct OpenFoodFactsNutriments: Codable {
    // Energy can come in different formats
    let energyKcal100g: Double?
    let energyKcal: Double?
    let energy100g: Double?
    
    // Protein
    let proteins100g: Double?
    let proteins: Double?
    
    // Carbs
    let carbohydrates100g: Double?
    let carbohydrates: Double?
    
    // Fat
    let fat100g: Double?
    let fat: Double?
    
    // Sugar
    let sugars100g: Double?
    let sugars: Double?
    
    // Fiber
    let fiber100g: Double?
    let fiber: Double?
    
    // Salt
    let salt100g: Double?
    let salt: Double?
    
    enum CodingKeys: String, CodingKey {
        case energyKcal100g = "energy-kcal_100g"
        case energyKcal = "energy-kcal"
        case energy100g = "energy_100g"
        case proteins100g = "proteins_100g"
        case proteins
        case carbohydrates100g = "carbohydrates_100g"
        case carbohydrates
        case fat100g = "fat_100g"
        case fat
        case sugars100g = "sugars_100g"
        case sugars
        case fiber100g = "fiber_100g"
        case fiber
        case salt100g = "salt_100g"
        case salt
    }
    
    // Helper to get best available value
    var bestEnergyKcal: Double? {
        energyKcal100g ?? energyKcal ?? energy100g
    }
    
    var bestProteins: Double? {
        proteins100g ?? proteins
    }
    
    var bestCarbs: Double? {
        carbohydrates100g ?? carbohydrates
    }
    
    var bestFat: Double? {
        fat100g ?? fat
    }
}

struct OpenFoodFactsProductResponse: Codable {
    let code: String?
    let product: OpenFoodFactsProduct?
    let status: Int?
    let statusVerbose: String?
    
    enum CodingKeys: String, CodingKey {
        case code, product, status
        case statusVerbose = "status_verbose"
    }
}

struct LivsmedelsverketNutrition: Codable {
    let nummer: Int
    let namn: String
    let naringsvarden: NutritionValues?
    
    struct NutritionValues: Codable {
        let energiKcal: Double?
        let kolhydrater: Double?
        let protein: Double?
        let fett: Double?
        let fiber: Double?
        let socker: Double?
        
        enum CodingKeys: String, CodingKey {
            case energiKcal = "energi_kcal"
            case kolhydrater
            case protein
            case fett
            case fiber
            case socker
        }
    }
}

// MARK: - Add Meal View
struct AddMealView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var viewModel = AddMealViewModel()
    @State private var selectedTab: MealTab = .all
    @State private var selectedFood: FoodItem?
    @State private var showFoodDetail = false
    @State private var showCreateMeal = false
    
    enum MealTab: String, CaseIterable {
        case all = "Alla"
        case myMeals = "Måltider"
        case saved = "Sparade"
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                Color(red: 0.96, green: 0.96, blue: 0.94)
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Tab bar
                    tabBar
                        .padding(.top, 4)
                    
                    // Search bar
                    searchBarSection
                        .padding(.horizontal, 16)
                        .padding(.top, 16)
                    
                    // Content
                    if viewModel.isSearching {
                        searchResultsView
                    } else {
                        // Daily intake card when not searching
                        dailyIntakeCard
                            .padding(.horizontal, 16)
                            .padding(.top, 16)
                        
                        contentView
                    }
                    
                    Spacer()
                }
            }
            .navigationTitle("Logga mat")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "arrow.left")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.black)
                            .frame(width: 40, height: 40)
                            .background(Color.gray.opacity(0.15))
                            .clipShape(Circle())
                    }
                }
            }
            .sheet(isPresented: $showFoodDetail) {
                if let food = selectedFood {
                    FoodDetailView(food: food) {
                        showFoodDetail = false
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showCreateMeal) {
                CreateMealView()
            }
        }
    }
    
    // MARK: - Tab Bar
    private var tabBar: some View {
        HStack(spacing: 0) {
            ForEach(MealTab.allCases, id: \.self) { tab in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedTab = tab
                    }
                } label: {
                    VStack(spacing: 6) {
                        Text(tab.rawValue)
                            .font(.system(size: 15, weight: selectedTab == tab ? .semibold : .regular))
                            .foregroundColor(selectedTab == tab ? .black : .gray)
                        
                        // Underline for selected tab
                        Rectangle()
                            .fill(selectedTab == tab ? Color.black : Color.clear)
                            .frame(height: 2)
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 16)
    }
    
    // MARK: - Search Bar Section
    private var searchBarSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Beskriv vad du åt")
                .font(.system(size: 13))
                .foregroundColor(.gray)
            
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 16))
                    .foregroundColor(.gray)
                
                TextField("Sök matvara...", text: $viewModel.searchText)
                    .font(.system(size: 17))
                    .foregroundColor(.black)
                    .autocorrectionDisabled()
                    .onChange(of: viewModel.searchText) { _, newValue in
                        viewModel.search(query: newValue)
                    }
                
                if !viewModel.searchText.isEmpty {
                    Button {
                        viewModel.searchText = ""
                        viewModel.searchResults = []
                        viewModel.isSearching = false
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 18))
                            .foregroundColor(.gray)
                    }
                }
            }
        }
        .padding(16)
        .background(Color.white)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
        )
    }
    
    // MARK: - Daily Intake Card
    private var dailyIntakeCard: some View {
        VStack(spacing: 16) {
            // Header with calories
            HStack {
                Text("Dagligt intag")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.black)
                
                Spacer()
                
                Text("\(viewModel.consumedCalories) / \(viewModel.calorieGoal) kcal")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.black)
            }
            
            // Calorie progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 6)
                    
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.green)
                        .frame(width: geometry.size.width * min(CGFloat(viewModel.consumedCalories) / CGFloat(viewModel.calorieGoal), 1.0), height: 6)
                }
            }
            .frame(height: 6)
            
            // Macros
            HStack(spacing: 0) {
                macroColumn(title: "KH", current: viewModel.consumedCarbs, goal: viewModel.carbsGoal, color: Color(red: 0.85, green: 0.7, blue: 0.7))
                
                macroColumn(title: "Protein", current: viewModel.consumedProtein, goal: viewModel.proteinGoal, color: Color(red: 0.85, green: 0.75, blue: 0.7))
                
                macroColumn(title: "Fett", current: viewModel.consumedFat, goal: viewModel.fatGoal, color: Color(red: 0.7, green: 0.75, blue: 0.85))
            }
        }
        .padding(16)
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
    }
    
    private func macroColumn(title: String, current: Int, goal: Int, color: Color) -> some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.black)
            
            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 4)
                    
                    RoundedRectangle(cornerRadius: 2)
                        .fill(color)
                        .frame(width: geometry.size.width * min(CGFloat(current) / CGFloat(goal), 1.0), height: 4)
                }
            }
            .frame(height: 4)
            .padding(.horizontal, 16)
            
            Text("\(current) / \(goal) g")
                .font(.system(size: 13))
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - Content View (Tab Content)
    @ViewBuilder
    private var contentView: some View {
        switch selectedTab {
        case .all:
            allTabContent
        case .myMeals:
            myMealsTabContent
        case .saved:
            savedTabContent
        }
    }
    
    // MARK: - All Tab Content
    private var allTabContent: some View {
        VStack(spacing: 20) {
            Spacer()
            
            Image(systemName: "leaf.fill")
                .font(.system(size: 100))
                .foregroundColor(.green.opacity(0.6))
                .padding(.bottom, 20)
            
            Text("Sök efter mat ovan för att logga din måltid")
                .font(.system(size: 15))
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            Spacer()
        }
    }
    
    // MARK: - My Meals Tab Content
    private var myMealsTabContent: some View {
        VStack(spacing: 16) {
            Spacer()
            
            // Food emoji
            Text("🍲🧃")
                .font(.system(size: 80))
            
            Text("Mina måltider")
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(.black)
            
            Text("Logga snabbt dina favoritmåltider.")
                .font(.system(size: 15))
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
            
            Button {
                // Coming soon - disabled
            } label: {
                Text("Lanseras inom kort")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white.opacity(0.7))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.black.opacity(0.4))
                    .cornerRadius(30)
            }
            .disabled(true)
            .padding(.horizontal, 40)
            .padding(.top, 8)
            
            Spacer()
        }
    }
    
    // MARK: - Saved Tab Content
    private var savedTabContent: some View {
        VStack(spacing: 16) {
            Spacer()
            
            // Screenshot illustration placeholder
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.gray.opacity(0.08))
                .frame(width: 280, height: 180)
                .overlay(
                    VStack(spacing: 12) {
                        Image(systemName: "bookmark")
                            .font(.system(size: 40))
                            .foregroundColor(.gray.opacity(0.4))
                        
                        Text("Sparade matvaror")
                            .font(.system(size: 14))
                            .foregroundColor(.gray.opacity(0.6))
                    }
                )
            
            Text("Inga sparade matvaror ännu")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.black)
            
            HStack(spacing: 4) {
                Text("Tryck på")
                    .font(.system(size: 14))
                    .foregroundColor(.gray)
                Image(systemName: "bookmark")
                    .font(.system(size: 14))
                    .foregroundColor(.gray)
                Text("på en matvara för att spara.")
                    .font(.system(size: 14))
                    .foregroundColor(.gray)
            }
            
            Spacer()
        }
    }
    
    // MARK: - Search Results View
    private var searchResultsView: some View {
        VStack(spacing: 0) {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 8) {
                    if viewModel.isLoading {
                        HStack {
                            Spacer()
                            ProgressView()
                            Spacer()
                        }
                        .padding(.top, 40)
                    } else if viewModel.searchResults.isEmpty && !viewModel.searchText.isEmpty {
                        HStack {
                            Spacer()
                            VStack(spacing: 12) {
                                Image(systemName: "magnifyingglass")
                                    .font(.system(size: 40))
                                    .foregroundColor(.gray.opacity(0.5))
                                Text("Inga resultat hittades")
                                    .font(.system(size: 15))
                                    .foregroundColor(.gray)
                            }
                            Spacer()
                        }
                        .padding(.top, 40)
                    } else {
                        // Header
                        Text("Välj från databas")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.black)
                            .padding(.top, 8)
                            .padding(.bottom, 12)
                        
                        // Results list
                        ForEach(viewModel.searchResults) { food in
                            FoodSearchResultRow(
                                food: food,
                                onTap: {
                                    selectedFood = food
                                    showFoodDetail = true
                                },
                                onAdd: {
                                    viewModel.quickAddFood(food) {
                                        // Dismiss after adding
                                        dismiss()
                                    }
                                }
                            )
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 100) // Space for bottom button
            }
            
            // Generate with AI button at bottom
            if !viewModel.searchResults.isEmpty || (!viewModel.searchText.isEmpty && !viewModel.isLoading) {
                VStack(spacing: 0) {
                    Divider()
                    
                    Button {
                        // Generate with AI action
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 16))
                            Text("Generera resultat med AI")
                                .font(.system(size: 16, weight: .medium))
                        }
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.white)
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                        )
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color(red: 0.96, green: 0.95, blue: 0.92))
                }
            }
        }
    }
}

// MARK: - Food Search Result Row
struct FoodSearchResultRow: View {
    let food: FoodItem
    let onTap: () -> Void
    let onAdd: () -> Void
    
    // Format the display name with brand
    private var displayTitle: String {
        if let brand = food.brand, !brand.isEmpty {
            return "\(food.name) · \(brand)"
        } else if let category = food.category, !category.isEmpty {
            return "\(food.name) · \(category)"
        }
        return food.name
    }
    
    // Format serving size for display
    private var servingSizeDisplay: String {
        if let servingSize = food.servingSize, !servingSize.isEmpty {
            return servingSize
        }
        return "100g"
    }
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Optional image - only show if food has an image
                if let imageUrl = food.imageUrl, let url = URL(string: imageUrl) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFill()
                                .frame(width: 50, height: 50)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        case .failure(_):
                            foodPlaceholder
                        case .empty:
                            ProgressView()
                                .frame(width: 50, height: 50)
                        @unknown default:
                            foodPlaceholder
                        }
                    }
                } else {
                    foodPlaceholder
                }
                
                VStack(alignment: .leading, spacing: 6) {
                    // Title: Name · Brand
                    Text(displayTitle)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.black)
                        .lineLimit(1)
                    
                    // Calories and serving size
                    HStack(spacing: 6) {
                        // Fire icon
                        Image(systemName: "flame.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.gray)
                        
                        // Calories
                        if let calories = food.calories {
                            Text("\(Int(calories)) kcal")
                                .font(.system(size: 14))
                                .foregroundColor(.gray)
                        } else {
                            Text("- kcal")
                                .font(.system(size: 14))
                                .foregroundColor(.gray)
                        }
                        
                        // Separator
                        Text("·")
                            .font(.system(size: 14))
                            .foregroundColor(.gray)
                        
                        // Serving size
                        Text(servingSizeDisplay)
                            .font(.system(size: 14))
                            .foregroundColor(.gray)
                    }
                }
                
                Spacer()
                
                // Plus button - white circle
                Button(action: onAdd) {
                    ZStack {
                        Circle()
                            .fill(Color.white)
                            .frame(width: 36, height: 36)
                            .shadow(color: Color.black.opacity(0.08), radius: 4, x: 0, y: 2)
                        
                        Image(systemName: "plus")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.black)
                    }
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(Color.white)
            .cornerRadius(16)
            .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 2)
        }
        .buttonStyle(.plain)
    }
    
    private var foodPlaceholder: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.gray.opacity(0.1))
                .frame(width: 50, height: 50)
            
            Image(systemName: "fork.knife")
                .font(.system(size: 20))
                .foregroundColor(.gray.opacity(0.4))
        }
    }
}

// MARK: - Add Meal ViewModel
class AddMealViewModel: ObservableObject {
    @Published var searchText = ""
    @Published var searchResults: [FoodItem] = []
    @Published var isSearching = false
    @Published var isLoading = false
    
    // Daily goals (can be customized per user)
    let calorieGoal = 1862
    let carbsGoal = 233
    let proteinGoal = 93
    let fatGoal = 62
    
    // Consumed today (will be fetched from database)
    @Published var consumedCalories = 0
    @Published var consumedCarbs = 0
    @Published var consumedProtein = 0
    @Published var consumedFat = 0
    
    private var searchTask: Task<Void, Never>?
    
    func search(query: String) {
        searchTask?.cancel()
        
        guard !query.isEmpty else {
            isSearching = false
            searchResults = []
            return
        }
        
        isSearching = true
        isLoading = true
        
        let currentQuery = query // Capture the query
        
        searchTask = Task { @MainActor in
            // Short debounce - just 200ms for snappy search
            try? await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
            
            // Check if this search is still relevant
            guard !Task.isCancelled, self.searchText == currentQuery else {
                print("⏭️ Search cancelled - user still typing")
                return
            }
            
            await searchOpenFoodFactsFallback(query: currentQuery)
        }
    }
    
    @MainActor
    private func searchWithFatSecret(query: String) async {
        print("\n🔎 === FatSecret search for '\(query)' ===")
        
        do {
            let fatSecretResults = try await FatSecretService.shared.searchFoods(query: query, maxResults: 30)
            
            // Convert FatSecret results to FoodItem
            let results = fatSecretResults.map { food -> FoodItem in
                FoodItem(
                    id: food.foodId,
                    name: food.displayName,
                    brand: food.brandName,
                    category: nil,
                    calories: Double(food.calories),
                    protein: food.protein,
                    carbs: food.carbs,
                    fat: food.fat,
                    barcode: nil,
                    source: .fatSecret,
                    imageUrl: nil, // FatSecret doesn't provide images in search results
                    servingSize: food.servingSize,
                    servingQuantity: nil,
                    nutriScore: nil,
                    novaGroup: nil
                )
            }
            
            // Sort by relevance
            let lowercasedQuery = query.lowercased()
            let sortedResults = results.sorted { item1, item2 in
                let name1 = item1.name.lowercased()
                let name2 = item2.name.lowercased()
                
                let exact1 = name1 == lowercasedQuery
                let exact2 = name2 == lowercasedQuery
                let starts1 = name1.hasPrefix(lowercasedQuery)
                let starts2 = name2.hasPrefix(lowercasedQuery)
                
                if exact1 != exact2 { return exact1 }
                if starts1 != starts2 { return starts1 }
                return name1 < name2
            }
            
            searchResults = Array(sortedResults.prefix(50))
            isLoading = false
            print("✅ FatSecret showing \(searchResults.count) results to user\n")
            
        } catch {
            print("❌ FatSecret search error: \(error)")
            // Fallback to Open Food Facts if FatSecret fails
            print("⚠️ Falling back to Open Food Facts...")
            await searchOpenFoodFactsFallback(query: query)
        }
    }
    
    @MainActor
    private func searchOpenFoodFactsFallback(query: String) async {
        print("\n🔎 === Fallback Open Food Facts search for '\(query)' ===")
        
        let results = await searchOpenFoodFacts(query: query)
        
        // Sort by relevance (exact matches first, then by name)
        let lowercasedQuery = query.lowercased()
        let sortedResults = results.sorted { item1, item2 in
            let name1 = item1.name.lowercased()
            let name2 = item2.name.lowercased()
            
            let exact1 = name1 == lowercasedQuery
            let exact2 = name2 == lowercasedQuery
            let starts1 = name1.hasPrefix(lowercasedQuery)
            let starts2 = name2.hasPrefix(lowercasedQuery)
            
            if exact1 != exact2 { return exact1 }
            if starts1 != starts2 { return starts1 }
            return name1 < name2
        }
        
        searchResults = Array(sortedResults.prefix(50))
        isLoading = false
        print("✅ Showing \(searchResults.count) results to user\n")
    }
    
    private func searchOpenFoodFacts(query: String) async -> [FoodItem] {
        // Open Food Facts Search API - Fast and simple
        
        guard let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            print("❌ Failed to encode query: \(query)")
            return []
        }
        
        // Use simple text search - fastest and most reliable
        let urlString = "https://world.openfoodfacts.org/cgi/search.pl?search_terms=\(encodedQuery)&search_simple=1&action=process&json=1&page_size=30&fields=code,product_name,brands,nutriments,image_front_small_url,serving_size,serving_quantity,nutriscore_grade,nova_group"
        
        print("📡 Searching Open Food Facts for: '\(query)'")
        
        if let results = await performOpenFoodFactsSearch(urlString: urlString), !results.isEmpty {
            return results
        }
        
        return []
    }
    
    private func performOpenFoodFactsSearch(urlString: String) async -> [FoodItem]? {
        guard let url = URL(string: urlString) else {
            print("❌ Invalid Open Food Facts URL")
            return nil
        }
        
        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("UpAndDown/1.0 iOS", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 10
        request.cachePolicy = .returnCacheDataElseLoad
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                print("❌ Open Food Facts API error")
                return nil
            }
            
            print("✅ Open Food Facts response received")
            return parseOpenFoodFactsResponse(data: data)
            
        } catch {
            print("❌ Open Food Facts error: \(error.localizedDescription)")
            return nil
        }
    }
    
    private func parseOpenFoodFactsResponse(data: Data) -> [FoodItem] {
        let decoder = JSONDecoder()
        
        // First try standard decoding
        if let searchResponse = try? decoder.decode(OpenFoodFactsSearchResponse.self, from: data) {
            let products = searchResponse.products ?? []
            let foodItems = products.compactMap { $0.toFoodItem() }
            print("🌍 Found \(foodItems.count) products from Open Food Facts")
            return foodItems
        }
        
        // Fallback: Manual JSON parsing
        print("⚠️ Standard decode failed, trying manual parsing...")
        
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let productsArray = json["products"] as? [[String: Any]] else {
            print("❌ Could not parse Open Food Facts response")
            return []
        }
        
        var foodItems: [FoodItem] = []
        
        for product in productsArray {
            guard let name = product["product_name"] as? String, !name.isEmpty else { continue }
            
            let code = product["code"] as? String
            let brands = product["brands"] as? String
            let imageUrl = product["image_front_small_url"] as? String 
                ?? product["image_front_url"] as? String 
                ?? product["image_url"] as? String
            let servingSize = product["serving_size"] as? String
            let servingQty = product["serving_quantity"] as? Double
            
            // Parse nutriments
            var calories: Double? = nil
            var protein: Double? = nil
            var carbs: Double? = nil
            var fat: Double? = nil
            
            if let nutriments = product["nutriments"] as? [String: Any] {
                calories = nutriments["energy-kcal_100g"] as? Double
                    ?? nutriments["energy-kcal"] as? Double
                    ?? (nutriments["energy_100g"] as? Double).map { $0 / 4.184 }
                protein = nutriments["proteins_100g"] as? Double ?? nutriments["proteins"] as? Double
                carbs = nutriments["carbohydrates_100g"] as? Double ?? nutriments["carbohydrates"] as? Double
                fat = nutriments["fat_100g"] as? Double ?? nutriments["fat"] as? Double
            }
            
            let nutriScore = product["nutriscore_grade"] as? String
            let novaGroup = product["nova_group"] as? Int
            
            let foodItem = FoodItem(
                id: "off_\(code ?? UUID().uuidString)",
                name: name,
                brand: brands,
                category: nil,
                calories: calories,
                protein: protein,
                carbs: carbs,
                fat: fat,
                barcode: code,
                source: .openFoodFacts,
                imageUrl: imageUrl,
                servingSize: servingSize ?? "100g",
                servingQuantity: servingQty ?? 100,
                nutriScore: nutriScore,
                novaGroup: novaGroup
            )
            foodItems.append(foodItem)
        }
        
        print("🌍 Parsed \(foodItems.count) products from Open Food Facts")
        return foodItems
    }
    
    // Search by barcode using Open Food Facts
    func searchByBarcode(_ barcode: String) async -> FoodItem? {
        // Reference: https://openfoodfacts.github.io/openfoodfacts-server/api/tutorial-off-api/
        guard let url = URL(string: "https://world.openfoodfacts.org/api/v2/product/\(barcode)?fields=code,product_name,brands,categories_tags,nutriments,image_front_url,serving_size,serving_quantity,nutriscore_grade,nova_group") else {
            return nil
        }
        
        do {
            var request = URLRequest(url: url)
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            request.setValue("UpAndDown iOS App", forHTTPHeaderField: "User-Agent")
            request.timeoutInterval = 10
            
            print("📡 Looking up barcode: \(barcode)")
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                return nil
            }
            
            let decoder = JSONDecoder()
            if let productResponse = try? decoder.decode(OpenFoodFactsProductResponse.self, from: data),
               let product = productResponse.product,
               productResponse.status == 1 {
                print("✅ Found product: \(product.productName ?? "Unknown")")
                return product.toFoodItem()
            }
        } catch {
            print("❌ Barcode lookup error: \(error)")
        }
        
        return nil
    }
    
    func selectFood(_ food: FoodItem) {
        print("Selected food: \(food.name) from \(food.source)")
    }
    
    func quickAddFood(_ food: FoodItem, completion: @escaping () -> Void) {
        Task {
            do {
                guard let userId = try? await SupabaseConfig.supabase.auth.session.user.id.uuidString else {
                    print("❌ No user logged in")
                    return
                }
                
                let entry = FoodLogInsertModel(
                    id: UUID().uuidString,
                    userId: userId,
                    name: food.name,
                    calories: Int(food.calories ?? 0),
                    protein: Int(food.protein ?? 0),
                    carbs: Int(food.carbs ?? 0),
                    fat: Int(food.fat ?? 0),
                    mealType: "snack",
                    loggedAt: ISO8601DateFormatter().string(from: Date()),
                    servingSize: food.servingSize ?? "100g",
                    servingQuantity: 1.0,
                    nutriScore: food.nutriScore,
                    imageUrl: food.imageUrl
                )
                
                try await SupabaseConfig.supabase
                    .from("food_logs")
                    .insert(entry)
                    .execute()
                
                print("✅ Quick added: \(food.name) - \(food.calories ?? 0) kcal (image: \(food.imageUrl != nil))")
                
                await MainActor.run {
                    NotificationCenter.default.post(name: NSNotification.Name("RefreshFoodLogs"), object: nil)
                    completion()
                }
            } catch {
                print("❌ Error saving food: \(error)")
            }
        }
    }
}

// MARK: - Food Log Insert Model
struct FoodLogInsertModel: Codable {
    let id: String
    let userId: String
    let name: String
    let calories: Int
    let protein: Int
    let carbs: Int
    let fat: Int
    let mealType: String
    let loggedAt: String
    let servingSize: String
    let servingQuantity: Double
    let nutriScore: String?
    let imageUrl: String?
    
    enum CodingKeys: String, CodingKey {
        case id, name, calories, protein, carbs, fat
        case userId = "user_id"
        case mealType = "meal_type"
        case loggedAt = "logged_at"
        case servingSize = "serving_size"
        case servingQuantity = "serving_quantity"
        case nutriScore = "nutri_score"
        case imageUrl = "image_url"
    }
}

// MARK: - Food Detail View
struct FoodDetailView: View {
    @Environment(\.dismiss) var dismiss
    let food: FoodItem
    let onLog: () -> Void
    
    @State private var selectedMeasurement: MeasurementType = .gram
    @State private var numberOfServings: Double = 1.0
    @State private var isSaved = false
    @State private var isLogging = false
    
    enum MeasurementType: String, CaseIterable {
        case tablespoon = "Msk"
        case gram = "G"
        case serving = "Portion"
    }
    
    // Calculate nutrients based on servings
    private var displayCalories: Int {
        Int((food.calories ?? 0) * numberOfServings)
    }
    
    private var displayProtein: Int {
        Int((food.protein ?? 0) * numberOfServings)
    }
    
    private var displayCarbs: Int {
        Int((food.carbs ?? 0) * numberOfServings)
    }
    
    private var displayFat: Int {
        Int((food.fat ?? 0) * numberOfServings)
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.96, green: 0.96, blue: 0.94)
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 24) {
                            // Food name and save button - FIRST
                            HStack {
                                Text(food.name)
                                    .font(.system(size: 26, weight: .bold))
                                    .foregroundColor(.black)
                                
                                Spacer()
                                
                                Button {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                                        isSaved.toggle()
                                    }
                                } label: {
                                    Image(systemName: isSaved ? "bookmark.fill" : "bookmark")
                                        .font(.system(size: 22))
                                        .foregroundColor(.black)
                                }
                            }
                            .padding(.top, 8)
                            
                            // Nutri-Score Badge - After title
                            if let nutriScore = food.nutriScore, !nutriScore.isEmpty {
                                NutriScoreBadge(grade: nutriScore)
                            }
                            
                            // Measurement selector
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Mått")
                                    .font(.system(size: 15))
                                    .foregroundColor(.gray)
                                
                                HStack(spacing: 10) {
                                    ForEach(MeasurementType.allCases, id: \.self) { type in
                                        Button {
                                            withAnimation(.easeInOut(duration: 0.2)) {
                                                selectedMeasurement = type
                                            }
                                        } label: {
                                            Text(type.rawValue)
                                                .font(.system(size: 15, weight: .medium))
                                                .foregroundColor(selectedMeasurement == type ? .white : .black)
                                                .padding(.horizontal, 20)
                                                .padding(.vertical, 12)
                                                .background(selectedMeasurement == type ? Color.black : Color.gray.opacity(0.1))
                                                .cornerRadius(20)
                                        }
                                    }
                                }
                            }
                            
                            // Number of servings
                            HStack {
                                Text("Antal portioner")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.black)
                                
                                Spacer()
                                
                                HStack(spacing: 8) {
                                    Text(String(format: "%.1f", numberOfServings))
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(.black)
                                    
                                    Image(systemName: "pencil")
                                        .font(.system(size: 14))
                                        .foregroundColor(.gray)
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(20)
                            }
                            
                            // Stepper for servings
                            HStack {
                                Spacer()
                                Stepper("", value: $numberOfServings, in: 0.5...10, step: 0.5)
                                    .labelsHidden()
                            }
                            
                            // Nutrition cards - swipeable
                            TabView {
                                nutritionMainCard
                                nutritionDetailCard
                            }
                            .tabViewStyle(.page(indexDisplayMode: .always))
                            .frame(height: 200)
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 100)
                    }
                    
                    // Bottom log button
                    VStack(spacing: 0) {
                        Divider()
                        
                        Button {
                            logFood()
                        } label: {
                            if isLogging {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            } else {
                                Text("Logga")
                                    .font(.system(size: 17, weight: .semibold))
                            }
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.black)
                        .cornerRadius(30)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 16)
                        .disabled(isLogging)
                    }
                    .background(Color(red: 0.96, green: 0.96, blue: 0.94))
                }
            }
            .navigationTitle("Vald matvara")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "arrow.left")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.black)
                            .frame(width: 40, height: 40)
                            .background(Color.gray.opacity(0.15))
                            .clipShape(Circle())
                    }
                }
            }
        }
    }
    
    // MARK: - Nutrition Main Card
    private var nutritionMainCard: some View {
        VStack(spacing: 16) {
            // Calories row
            HStack(spacing: 12) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 24))
                    .foregroundColor(.black)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Kalorier")
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                    Text("\(displayCalories)")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(.black)
                }
                
                Spacer()
            }
            .padding(16)
            .background(Color.white)
            .cornerRadius(16)
            
            // Macros row
            HStack(spacing: 12) {
                macroCard(emoji: "🥩", label: "Protein", value: "\(displayProtein)g")
                macroCard(emoji: "🌾", label: "Kolhydrater", value: "\(displayCarbs)g")
                macroCard(emoji: "🫒", label: "Fett", value: "\(displayFat)g")
            }
        }
        .padding(.horizontal, 4)
    }
    
    // MARK: - Nutrition Detail Card
    private var nutritionDetailCard: some View {
        VStack(spacing: 12) {
            nutritionRow(label: "Fiber", value: "- g")
            nutritionRow(label: "Socker", value: "- g")
            nutritionRow(label: "Salt", value: "- g")
            nutritionRow(label: "Mättat fett", value: "- g")
        }
        .padding(16)
        .background(Color.white)
        .cornerRadius(16)
        .padding(.horizontal, 4)
    }
    
    private func macroCard(emoji: String, label: String, value: String) -> some View {
        VStack(spacing: 8) {
            Text(emoji)
                .font(.system(size: 28))
            
            Text(label)
                .font(.system(size: 13))
                .foregroundColor(.gray)
            
            Text(value)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.black)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(Color.white)
        .cornerRadius(12)
    }
    
    private func nutritionRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 15))
                .foregroundColor(.black)
            Spacer()
            Text(value)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.gray)
        }
    }
    
    private func logFood() {
        isLogging = true
        
        Task {
            do {
                guard let userId = try? await SupabaseConfig.supabase.auth.session.user.id.uuidString else {
                    print("❌ No user logged in")
                    isLogging = false
                    return
                }
                
                let entry = FoodLogInsertModel(
                    id: UUID().uuidString,
                    userId: userId,
                    name: food.name,
                    calories: displayCalories,
                    protein: displayProtein,
                    carbs: displayCarbs,
                    fat: displayFat,
                    mealType: "snack",
                    loggedAt: ISO8601DateFormatter().string(from: Date()),
                    servingSize: food.servingSize ?? "100g",
                    servingQuantity: numberOfServings,
                    nutriScore: food.nutriScore,
                    imageUrl: food.imageUrl
                )
                
                try await SupabaseConfig.supabase
                    .from("food_logs")
                    .insert(entry)
                    .execute()
                
                print("✅ Logged: \(food.name) - \(displayCalories) kcal (image: \(food.imageUrl != nil))")
                
                await MainActor.run {
                    NotificationCenter.default.post(name: NSNotification.Name("RefreshFoodLogs"), object: nil)
                    isLogging = false
                    onLog()
                }
            } catch {
                print("❌ Error logging food: \(error)")
                await MainActor.run {
                    isLogging = false
                }
            }
        }
    }
}

// MARK: - Create Meal View
struct CreateMealView: View {
    @Environment(\.dismiss) var dismiss
    @State private var mealName = ""
    @State private var mealItems: [MealItem] = []
    @State private var showAddItems = false
    
    struct MealItem: Identifiable {
        let id = UUID()
        let name: String
        let calories: Int
        let protein: Int
        let carbs: Int
        let fat: Int
    }
    
    private var totalCalories: Int {
        mealItems.reduce(0) { $0 + $1.calories }
    }
    
    private var totalProtein: Int {
        mealItems.reduce(0) { $0 + $1.protein }
    }
    
    private var totalCarbs: Int {
        mealItems.reduce(0) { $0 + $1.carbs }
    }
    
    private var totalFat: Int {
        mealItems.reduce(0) { $0 + $1.fat }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.96, green: 0.96, blue: 0.94)
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    ScrollView {
                        VStack(spacing: 16) {
                            // Name input
                            nameInputCard
                                .padding(.horizontal, 16)
                                .padding(.top, 16)
                            
                            // Nutrition summary
                            nutritionSummaryCard
                                .padding(.horizontal, 16)
                            
                            // Page indicator
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(Color.black)
                                    .frame(width: 8, height: 8)
                                Circle()
                                    .fill(Color.gray.opacity(0.3))
                                    .frame(width: 8, height: 8)
                            }
                            .padding(.top, 8)
                            
                            // Meal items section
                            mealItemsSection
                                .padding(.horizontal, 16)
                                .padding(.top, 24)
                        }
                        .padding(.bottom, 100)
                    }
                    
                    // Create button
                    VStack {
                        Button {
                            // TODO: Save meal
                            dismiss()
                        } label: {
                            Text("Skapa måltid")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundColor(mealItems.isEmpty ? .gray : .white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(mealItems.isEmpty ? Color.gray.opacity(0.3) : Color.black)
                                .cornerRadius(30)
                        }
                        .disabled(mealItems.isEmpty)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 16)
                    }
                    .background(Color(red: 0.96, green: 0.96, blue: 0.94))
                }
            }
            .navigationTitle("Skapa måltid")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "arrow.left")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.black)
                            .frame(width: 40, height: 40)
                            .background(Color.gray.opacity(0.15))
                            .clipShape(Circle())
                    }
                }
            }
        }
    }
    
    // MARK: - Name Input Card
    private var nameInputCard: some View {
        HStack {
            if mealName.isEmpty {
                Text("Tryck för att namnge")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.gray.opacity(0.5))
            }
            
            TextField("", text: $mealName)
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(.black)
            
            Image(systemName: "pencil")
                .font(.system(size: 18))
                .foregroundColor(.gray)
        }
        .padding(18)
        .background(Color.white)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.gray.opacity(0.15), lineWidth: 1)
        )
    }
    
    // MARK: - Nutrition Summary Card
    private var nutritionSummaryCard: some View {
        VStack(spacing: 12) {
            // Calories
            HStack(spacing: 12) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 22))
                    .foregroundColor(.black)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Kalorier")
                        .font(.system(size: 13))
                        .foregroundColor(.gray)
                    Text("\(totalCalories)")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.black)
                }
                
                Spacer()
            }
            .padding(14)
            .background(Color.white)
            .cornerRadius(14)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color.gray.opacity(0.15), lineWidth: 1)
            )
            
            // Macros
            HStack(spacing: 10) {
                macroMiniCard(emoji: "🥩", label: "Protein", value: "\(totalProtein)g")
                macroMiniCard(emoji: "🌾", label: "Kolhydrater", value: "\(totalCarbs)g")
                macroMiniCard(emoji: "🫒", label: "Fett", value: "\(totalFat)g")
            }
        }
    }
    
    private func macroMiniCard(emoji: String, label: String, value: String) -> some View {
        VStack(spacing: 6) {
            Text(emoji)
                .font(.system(size: 24))
            
            Text(label)
                .font(.system(size: 11))
                .foregroundColor(.gray)
            
            Text(value)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.black)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color.white)
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.gray.opacity(0.15), lineWidth: 1)
        )
    }
    
    // MARK: - Meal Items Section
    private var mealItemsSection: some View {
        VStack(spacing: 12) {
            // Header
            HStack {
                Image(systemName: "fork.knife")
                    .font(.system(size: 18))
                    .foregroundColor(.gray)
                
                Text("Ingredienser")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.black)
            }
            
            // Add items button
            Button {
                showAddItems = true
            } label: {
                HStack {
                    Image(systemName: "plus")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.black)
                    
                    Text("Lägg till ingredienser")
                        .font(.system(size: 16))
                        .foregroundColor(.black)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color.white)
                .cornerRadius(14)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                )
            }
            .sheet(isPresented: $showAddItems) {
                AddMealView()
            }
            
            // List of added items
            ForEach(mealItems) { item in
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.name)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.black)
                        
                        Text("\(item.calories) kcal")
                            .font(.system(size: 13))
                            .foregroundColor(.gray)
                    }
                    
                    Spacer()
                    
                    Button {
                        if let index = mealItems.firstIndex(where: { $0.id == item.id }) {
                            mealItems.remove(at: index)
                        }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.gray.opacity(0.5))
                    }
                }
                .padding(14)
                .background(Color.white)
                .cornerRadius(12)
            }
        }
    }
}

// MARK: - Nutri-Score Badge
struct NutriScoreBadge: View {
    let grade: String
    
    private let grades = ["A", "B", "C", "D", "E"]
    
    private func colorFor(_ g: String) -> Color {
        switch g {
        case "A": return Color(red: 0.0, green: 0.52, blue: 0.26) // Dark green
        case "B": return Color(red: 0.52, green: 0.73, blue: 0.18) // Light green
        case "C": return Color(red: 0.96, green: 0.78, blue: 0.15) // Yellow
        case "D": return Color(red: 0.93, green: 0.55, blue: 0.14) // Orange
        case "E": return Color(red: 0.88, green: 0.27, blue: 0.14) // Red
        default: return Color.gray
        }
    }
    
    private var gradeDescription: String {
        switch grade.uppercased() {
        case "A": return "Utmärkt näringsvärde"
        case "B": return "Bra näringsvärde"
        case "C": return "Genomsnittligt näringsvärde"
        case "D": return "Lågt näringsvärde"
        case "E": return "Dåligt näringsvärde"
        default: return "Näringsvärde"
        }
    }
    
    var body: some View {
        HStack(spacing: 16) {
            // Official Nutri-Score badge design
            VStack(spacing: 0) {
                // NUTRI-SCORE header
                Text("NUTRI-SCORE")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(Color(red: 0.4, green: 0.4, blue: 0.4))
                    .padding(.bottom, 4)
                
                // Grade bar
                HStack(spacing: 0) {
                    ForEach(grades, id: \.self) { g in
                        let isSelected = g == grade.uppercased()
                        
                        ZStack {
                            // Background color bar
                            Rectangle()
                                .fill(colorFor(g))
                            
                            // Letter
                            Text(g)
                                .font(.system(size: isSelected ? 24 : 14, weight: .black))
                                .foregroundColor(isSelected ? colorFor(g) : .white.opacity(0.7))
                                .background(
                                    Group {
                                        if isSelected {
                                            Circle()
                                                .fill(Color.white)
                                                .frame(width: 38, height: 38)
                                        }
                                    }
                                )
                        }
                        .frame(width: isSelected ? 48 : 32, height: 48)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                )
            }
            
            // Description
            VStack(alignment: .leading, spacing: 4) {
                Text("Nutri-Score")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.black)
                
                Text(gradeDescription)
                    .font(.system(size: 13))
                    .foregroundColor(.gray)
            }
            
            Spacer()
        }
        .padding(16)
        .background(Color.white)
        .cornerRadius(16)
    }
}

#Preview {
    AddMealView()
}

