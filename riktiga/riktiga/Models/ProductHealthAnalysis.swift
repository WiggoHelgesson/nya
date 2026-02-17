import Foundation

// MARK: - Product Health Analysis (GPT result)

struct ProductHealthAnalysis: Codable, Identifiable {
    var id: String { barcode ?? UUID().uuidString }
    
    let productName: String
    let brand: String?
    let barcode: String?
    let imageUrl: String?
    
    // Health Score
    let healthScore: Int // 1-100
    let healthGrade: String // "Dåligt", "Medel", "Bra", "Utmärkt"
    
    // Quick Overview
    let harmfulAdditives: Int
    let hasSeedOil: Bool
    let totalIngredients: Int
    let novaGroup: Int? // 1-4
    let isUltraProcessed: Bool
    
    // Natural vs Processed
    let naturalPercentage: Int
    let processedPercentage: Int
    let ingredientClassifications: [IngredientClassification]
    
    // Brand Trust
    let brandTrustScore: String // "Clear", "Warning", "Danger"
    let brandTrustNote: String
    
    // Additives
    let additives: [AdditiveInfo]
    
    // Risks
    let microplasticRisk: String // "Ingen", "Låg", "Måttlig", "Hög"
    let microplasticNote: String
    let heavyMetalRiskScore: Int // 0-100
    let heavyMetalNote: String
    let metalBreakdown: MetalBreakdown
    
    // Nutrition (from Open Food Facts)
    let calories: Int
    let protein: Int
    let carbs: Int
    let fat: Int
    
    enum CodingKeys: String, CodingKey {
        case productName = "product_name"
        case brand
        case barcode
        case imageUrl = "image_url"
        case healthScore = "health_score"
        case healthGrade = "health_grade"
        case harmfulAdditives = "harmful_additives"
        case hasSeedOil = "has_seed_oil"
        case totalIngredients = "total_ingredients"
        case novaGroup = "nova_group"
        case isUltraProcessed = "is_ultra_processed"
        case naturalPercentage = "natural_percentage"
        case processedPercentage = "processed_percentage"
        case ingredientClassifications = "ingredient_classifications"
        case brandTrustScore = "brand_trust_score"
        case brandTrustNote = "brand_trust_note"
        case additives
        case microplasticRisk = "microplastic_risk"
        case microplasticNote = "microplastic_note"
        case heavyMetalRiskScore = "heavy_metal_risk_score"
        case heavyMetalNote = "heavy_metal_note"
        case metalBreakdown = "metal_breakdown"
        case calories, protein, carbs, fat
    }
}

// MARK: - Sub-models

struct IngredientClassification: Codable, Identifiable {
    var id: String { name }
    let name: String
    let isNatural: Bool
    let note: String?
    
    enum CodingKeys: String, CodingKey {
        case name
        case isNatural = "is_natural"
        case note
    }
}

struct AdditiveInfo: Codable, Identifiable {
    var id: String { code }
    let name: String
    let code: String // E-number e.g. "E338"
    let riskLevel: String // "Low risk", "Moderate risk", "High risk"
    let description: String
    let function: String // e.g. "ANTIOXIDANT/REGULATOR"
    
    enum CodingKeys: String, CodingKey {
        case name, code
        case riskLevel = "risk_level"
        case description
        case function
    }
}

struct MetalBreakdown: Codable {
    let lead: String // "Low", "Moderate", "High", "Undetected"
    let cadmium: String
    let arsenic: String
    let mercury: String
    let primarySources: String
    let dataCoverage: Int // percentage
    
    enum CodingKeys: String, CodingKey {
        case lead, cadmium, arsenic, mercury
        case primarySources = "primary_sources"
        case dataCoverage = "data_coverage"
    }
}

// MARK: - Health Grade Helpers

extension ProductHealthAnalysis {
    var healthScoreColor: String {
        switch healthScore {
        case 0..<25: return "red"
        case 25..<50: return "orange"
        case 50..<75: return "yellow"
        default: return "green"
        }
    }
    
    var microplasticRiskColor: String {
        switch microplasticRisk.lowercased() {
        case "ingen", "none": return "green"
        case "låg", "low": return "green"
        case "måttlig", "moderate": return "orange"
        case "hög", "high": return "red"
        default: return "gray"
        }
    }
    
    var brandTrustColor: String {
        switch brandTrustScore.lowercased() {
        case "clear": return "green"
        case "warning": return "orange"
        case "danger": return "red"
        default: return "gray"
        }
    }
}
