import SwiftUI

struct ProductHealthResultView: View {
    let analysis: ProductHealthAnalysis
    let onScanAnother: (() -> Void)?
    let onDismiss: (() -> Void)?
    
    @State private var showIngredients = false
    @State private var expandedMicroplastic = false
    @State private var expandedHeavyMetal = false
    
    init(analysis: ProductHealthAnalysis, onScanAnother: (() -> Void)? = nil, onDismiss: (() -> Void)? = nil) {
        self.analysis = analysis
        self.onScanAnother = onScanAnother
        self.onDismiss = onDismiss
    }
    
    // MARK: - Colors
    private let goodGreen = Color(red: 34/255, green: 197/255, blue: 94/255)  // #22C55E
    private let badRed = Color(red: 239/255, green: 68/255, blue: 68/255)     // #EF4444
    private let warningOrange = Color(red: 249/255, green: 115/255, blue: 22/255)
    private let warningYellow = Color(red: 234/255, green: 179/255, blue: 8/255)
    private let cardBackground = Color(UIColor.systemGray6)
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Product header
                    productHeader
                    
                    // Health Grade circle
                    healthGradeSection
                    
                    // Quick Overview
                    quickOverviewSection
                    
                    // Natural vs Processed
                    naturalVsProcessedSection
                    
                    // Brand Trust
                    brandTrustSection
                    
                    // Additives Breakdown
                    if !analysis.additives.isEmpty {
                        additivesSection
                    }
                    
                    // Microplastic Risk
                    microplasticSection
                    
                    // Heavy Metal Risk
                    heavyMetalSection
                    
                    // Action buttons
                    actionButtons
                    
                    Spacer(minLength: 20)
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
            }
            .background(Color(UIColor.systemBackground))
            .navigationTitle("Resultat")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Klar") {
                        onDismiss?()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
    
    // MARK: - Product Header
    
    private var productHeader: some View {
        VStack(spacing: 8) {
            // Product image (if available)
            if let imageUrl = analysis.imageUrl, let url = URL(string: imageUrl) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(height: 120)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                    default:
                        EmptyView()
                    }
                }
            }
            
            Text(analysis.productName)
                .font(.system(size: 22, weight: .bold))
                .multilineTextAlignment(.center)
            
            if let brand = analysis.brand {
                Text(brand)
                    .font(.system(size: 15))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(cardBackground)
                    .clipShape(Capsule())
            }
        }
        .padding(.top, 4)
    }
    
    // MARK: - Health Grade
    
    private var healthGradeSection: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .stroke(scoreColor.opacity(0.2), lineWidth: 12)
                    .frame(width: 140, height: 140)
                
                Circle()
                    .trim(from: 0, to: CGFloat(analysis.healthScore) / 100)
                    .stroke(scoreColor, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                    .frame(width: 140, height: 140)
                    .rotationEffect(.degrees(-90))
                
                VStack(spacing: 2) {
                    Text("\(analysis.healthScore)")
                        .font(.system(size: 46, weight: .bold, design: .rounded))
                        .foregroundColor(scoreColor)
                    
                    Text("av 100")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
            }
            
            Text(analysis.healthGrade)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(scoreColor)
                .padding(.horizontal, 24)
                .padding(.vertical, 8)
                .background(scoreColor.opacity(0.12))
                .clipShape(Capsule())
        }
        .padding(.vertical, 8)
    }
    
    // MARK: - Quick Overview
    
    private var quickOverviewSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionTitle("Snabb översikt")
            
            VStack(spacing: 0) {
                overviewRow(
                    icon: "exclamationmark.triangle.fill",
                    label: "Skadliga tillsatser",
                    value: "\(analysis.harmfulAdditives)",
                    valueColor: analysis.harmfulAdditives > 0 ? badRed : goodGreen
                )
                Divider().padding(.horizontal, 16)
                
                overviewRow(
                    icon: "drop.fill",
                    label: "Fröolja",
                    value: analysis.hasSeedOil ? "Ja" : "Nej",
                    valueColor: analysis.hasSeedOil ? badRed : goodGreen
                )
                Divider().padding(.horizontal, 16)
                
                overviewRow(
                    icon: "list.bullet",
                    label: "Antal ingredienser",
                    value: "\(analysis.totalIngredients)",
                    valueColor: .primary
                )
                Divider().padding(.horizontal, 16)
                
                overviewRow(
                    icon: "gearshape.2.fill",
                    label: "Ultraprocessad",
                    value: analysis.isUltraProcessed ? "Ja" : "Nej",
                    valueColor: analysis.isUltraProcessed ? badRed : goodGreen
                )
                
                if let nova = analysis.novaGroup {
                    Divider().padding(.horizontal, 16)
                    overviewRow(
                        icon: "number",
                        label: "NOVA-grupp",
                        value: "\(nova)",
                        valueColor: nova >= 4 ? badRed : (nova >= 3 ? warningOrange : goodGreen)
                    )
                }
            }
            .background(cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }
    
    private func overviewRow(icon: String, label: String, value: String, valueColor: Color) -> some View {
        HStack {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(.secondary)
                .frame(width: 30)
            
            Text(label)
                .font(.system(size: 15))
                .foregroundColor(.primary)
            
            Spacer()
            
            Text(value)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(valueColor)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }
    
    // MARK: - Natural vs Processed
    
    private var naturalVsProcessedSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("Naturligt vs Bearbetat")
            
            VStack(spacing: 16) {
                // Percentage bar
                VStack(spacing: 8) {
                    HStack {
                        Text("Naturligt")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(goodGreen)
                        Spacer()
                        Text("\(analysis.naturalPercentage)%")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(goodGreen)
                    }
                    
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color(UIColor.systemGray5))
                                .frame(height: 12)
                            
                            RoundedRectangle(cornerRadius: 6)
                                .fill(goodGreen)
                                .frame(width: geometry.size.width * CGFloat(analysis.naturalPercentage) / 100, height: 12)
                        }
                    }
                    .frame(height: 12)
                }
                
                VStack(spacing: 8) {
                    HStack {
                        Text("Bearbetat")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(badRed)
                        Spacer()
                        Text("\(analysis.processedPercentage)%")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(badRed)
                    }
                    
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color(UIColor.systemGray5))
                                .frame(height: 12)
                            
                            RoundedRectangle(cornerRadius: 6)
                                .fill(badRed)
                                .frame(width: geometry.size.width * CGFloat(analysis.processedPercentage) / 100, height: 12)
                        }
                    }
                    .frame(height: 12)
                }
                
                // Show ingredients button
                if !analysis.ingredientClassifications.isEmpty {
                    Button {
                        withAnimation { showIngredients.toggle() }
                    } label: {
                        HStack {
                            Text(showIngredients ? "Dölj ingredienser" : "Visa ingredienser")
                                .font(.system(size: 14, weight: .semibold))
                            Image(systemName: showIngredients ? "chevron.up" : "chevron.down")
                                .font(.system(size: 12))
                        }
                        .foregroundColor(.primary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color(UIColor.systemGray5))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    
                    if showIngredients {
                        VStack(spacing: 6) {
                            ForEach(analysis.ingredientClassifications) { ingredient in
                                HStack(spacing: 10) {
                                    Circle()
                                        .fill(ingredient.isNatural ? goodGreen : badRed)
                                        .frame(width: 8, height: 8)
                                    
                                    Text(ingredient.name)
                                        .font(.system(size: 14))
                                        .foregroundColor(.primary)
                                    
                                    Spacer()
                                    
                                    if let note = ingredient.note {
                                        Text(note)
                                            .font(.system(size: 12))
                                            .foregroundColor(.secondary)
                                            .lineLimit(1)
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                        }
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
            }
            .padding(16)
            .background(cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }
    
    // MARK: - Brand Trust
    
    private var brandTrustSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("Varumärkesförtroende")
            
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(brandColor.opacity(0.15))
                        .frame(width: 50, height: 50)
                    
                    Image(systemName: brandIcon)
                        .font(.system(size: 22))
                        .foregroundColor(brandColor)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(brandLabel)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(brandColor)
                    
                    Text(analysis.brandTrustNote)
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }
    
    // MARK: - Additives Breakdown
    
    private var additivesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("Tillsatser")
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(analysis.additives) { additive in
                        additiveCard(additive)
                    }
                }
                .padding(.horizontal, 2)
            }
        }
    }
    
    private func additiveCard(_ additive: AdditiveInfo) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // Risk badge
            Text(localizedRiskLevel(additive.riskLevel))
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(riskColor(additive.riskLevel))
                .clipShape(Capsule())
            
            Text(additive.name)
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(.primary)
                .lineLimit(1)
            
            Text(additive.code)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.secondary)
            
            Text(additive.description)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
            
            Spacer(minLength: 0)
            
            Text(additive.function)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.secondary)
                .lineLimit(1)
        }
        .padding(14)
        .frame(width: 180, alignment: .leading)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    // MARK: - Microplastic Risk
    
    private var microplasticSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("Mikroplastrisk")
            
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    riskBadge(text: localizedMicroplasticRisk, color: microplasticColor)
                    Spacer()
                    Button {
                        withAnimation { expandedMicroplastic.toggle() }
                    } label: {
                        Image(systemName: expandedMicroplastic ? "chevron.up" : "chevron.down")
                            .foregroundColor(.secondary)
                    }
                }
                
                if expandedMicroplastic {
                    Text(analysis.microplasticNote)
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .padding(16)
            .background(cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }
    
    // MARK: - Heavy Metal Risk
    
    private var heavyMetalSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("Tungmetallrisk")
            
            VStack(alignment: .leading, spacing: 16) {
                // Risk score
                HStack {
                    Text("Riskpoäng")
                        .font(.system(size: 15, weight: .medium))
                    Spacer()
                    Text("\(analysis.heavyMetalRiskScore)/100")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(heavyMetalColor)
                }
                
                // Progress bar
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color(UIColor.systemGray5))
                            .frame(height: 10)
                        
                        RoundedRectangle(cornerRadius: 6)
                            .fill(heavyMetalColor)
                            .frame(width: geometry.size.width * CGFloat(analysis.heavyMetalRiskScore) / 100, height: 10)
                    }
                }
                .frame(height: 10)
                
                Button {
                    withAnimation { expandedHeavyMetal.toggle() }
                } label: {
                    HStack {
                        Text(expandedHeavyMetal ? "Dölj detaljer" : "Visa detaljer")
                            .font(.system(size: 14, weight: .semibold))
                        Image(systemName: expandedHeavyMetal ? "chevron.up" : "chevron.down")
                            .font(.system(size: 12))
                    }
                    .foregroundColor(.primary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color(UIColor.systemGray5))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                
                if expandedHeavyMetal {
                    VStack(spacing: 12) {
                        metalRow(name: "Bly (Pb)", level: analysis.metalBreakdown.lead)
                        metalRow(name: "Kadmium (Cd)", level: analysis.metalBreakdown.cadmium)
                        metalRow(name: "Arsenik (As)", level: analysis.metalBreakdown.arsenic)
                        metalRow(name: "Kvicksilver (Hg)", level: analysis.metalBreakdown.mercury)
                        
                        Divider()
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Källor: \(analysis.metalBreakdown.primarySources)")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                            
                            Text("Datatäckning: \(analysis.metalBreakdown.dataCoverage)%")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                    }
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
                
                Text(analysis.heavyMetalNote)
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(16)
            .background(cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }
    
    private func metalRow(name: String, level: String) -> some View {
        HStack {
            Text(name)
                .font(.system(size: 14))
                .foregroundColor(.primary)
            Spacer()
            riskBadge(text: localizedMetalLevel(level), color: metalLevelColor(level))
        }
    }
    
    // MARK: - Action Buttons
    
    private var actionButtons: some View {
        VStack(spacing: 12) {
            if let onScanAnother = onScanAnother {
                Button {
                    onScanAnother()
                } label: {
                    HStack {
                        Image(systemName: "barcode.viewfinder")
                        Text("Scanna en till produkt")
                    }
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(goodGreen)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }
            }
        }
        .padding(.top, 8)
    }
    
    // MARK: - Helpers
    
    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 18, weight: .bold))
            .padding(.leading, 4)
    }
    
    private func riskBadge(text: String, color: Color) -> some View {
        Text(text)
            .font(.system(size: 13, weight: .bold))
            .foregroundColor(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .background(color)
            .clipShape(Capsule())
    }
    
    private var scoreColor: Color {
        switch analysis.healthScore {
        case 0..<25: return badRed
        case 25..<50: return warningOrange
        case 50..<75: return warningYellow
        default: return goodGreen
        }
    }
    
    private var brandColor: Color {
        switch analysis.brandTrustScore.lowercased() {
        case "clear": return goodGreen
        case "warning": return warningOrange
        case "danger": return badRed
        default: return .gray
        }
    }
    
    private var brandIcon: String {
        switch analysis.brandTrustScore.lowercased() {
        case "clear": return "checkmark.shield.fill"
        case "warning": return "exclamationmark.shield.fill"
        case "danger": return "xmark.shield.fill"
        default: return "shield.fill"
        }
    }
    
    private var brandLabel: String {
        switch analysis.brandTrustScore.lowercased() {
        case "clear": return "Pålitligt"
        case "warning": return "Varning"
        case "danger": return "Fara"
        default: return "Okänt"
        }
    }
    
    private var microplasticColor: Color {
        switch analysis.microplasticRisk.lowercased() {
        case "ingen", "none": return goodGreen
        case "låg", "low": return goodGreen
        case "måttlig", "moderate": return warningOrange
        case "hög", "high": return badRed
        default: return .gray
        }
    }
    
    private var localizedMicroplasticRisk: String {
        switch analysis.microplasticRisk.lowercased() {
        case "ingen", "none": return "Ingen risk"
        case "låg", "low": return "Låg risk"
        case "måttlig", "moderate": return "Måttlig risk"
        case "hög", "high": return "Hög risk"
        default: return analysis.microplasticRisk
        }
    }
    
    private var heavyMetalColor: Color {
        switch analysis.heavyMetalRiskScore {
        case 0..<20: return goodGreen
        case 20..<50: return warningOrange
        default: return badRed
        }
    }
    
    private func riskColor(_ riskLevel: String) -> Color {
        switch riskLevel.lowercased() {
        case "low risk": return goodGreen
        case "moderate risk": return warningOrange
        case "high risk": return badRed
        default: return .gray
        }
    }
    
    private func localizedRiskLevel(_ riskLevel: String) -> String {
        switch riskLevel.lowercased() {
        case "low risk": return "Låg risk"
        case "moderate risk": return "Måttlig risk"
        case "high risk": return "Hög risk"
        default: return riskLevel
        }
    }
    
    private func metalLevelColor(_ level: String) -> Color {
        switch level.lowercased() {
        case "undetected", "low": return goodGreen
        case "moderate": return warningOrange
        case "high": return badRed
        default: return .gray
        }
    }
    
    private func localizedMetalLevel(_ level: String) -> String {
        switch level.lowercased() {
        case "undetected": return "Ej påvisad"
        case "low": return "Låg"
        case "moderate": return "Måttlig"
        case "high": return "Hög"
        default: return level
        }
    }
    
    // MARK: - Placeholder (used when data is loading)
    static let placeholder = ProductHealthAnalysis(
        productName: "Laddar...",
        brand: nil,
        barcode: nil,
        imageUrl: nil,
        healthScore: 0,
        healthGrade: "",
        harmfulAdditives: 0,
        hasSeedOil: false,
        totalIngredients: 0,
        novaGroup: nil,
        isUltraProcessed: false,
        naturalPercentage: 0,
        processedPercentage: 0,
        ingredientClassifications: [],
        brandTrustScore: "Clear",
        brandTrustNote: "",
        additives: [],
        microplasticRisk: "Ingen",
        microplasticNote: "",
        heavyMetalRiskScore: 0,
        heavyMetalNote: "",
        metalBreakdown: MetalBreakdown(lead: "Undetected", cadmium: "Undetected", arsenic: "Undetected", mercury: "Undetected", primarySources: "", dataCoverage: 0),
        calories: 0,
        protein: 0,
        carbs: 0,
        fat: 0
    )
}
