import SwiftUI

struct AppColors {
    // Primary Colors - WANTZEN Branding (Pastell)
    static let brandGreen = Color(red: 0.78, green: 0.89, blue: 0.52)       // Pastell Grönt
    static let brandBlue = Color(red: 0.52, green: 0.64, blue: 0.92)        // Pastell Blått
    static let brandYellow = Color(red: 0.95, green: 0.88, blue: 0.40)      // Pastell Gult
    static let brandDark = Color(red: 0.1, green: 0.1, blue: 0.1)           // #1A1A1A
    
    // Pastell Accent Colors
    static let pastelPink = Color(red: 0.95, green: 0.70, blue: 0.75)
    static let pastelOrange = Color(red: 0.95, green: 0.80, blue: 0.55)
    static let pastelPurple = Color(red: 0.80, green: 0.70, blue: 0.92)
    
    // Secondary Colors
    static let white = Color.white
    static let lightGray = Color(red: 0.96, green: 0.96, blue: 0.96)        // #F5F5F5
    static let mediumGray = Color(red: 0.85, green: 0.85, blue: 0.85)       // #D9D9D9
    
    // Functional Colors
    static let success = Color(red: 0.2, green: 0.8, blue: 0.4)
    static let warning = Color(red: 1.0, green: 0.8, blue: 0.0)
    static let error = Color(red: 1.0, green: 0.3, blue: 0.3)
}

// MARK: - Theme Extensions
extension View {
    func themePrimaryButton() -> some View {
        self
            .padding(12)
            .background(AppColors.brandBlue)
            .foregroundColor(.white)
            .cornerRadius(25)
            .font(.headline)
    }
    
    func themeSecondaryButton() -> some View {
        self
            .padding(12)
            .background(AppColors.brandGreen)
            .foregroundColor(AppColors.brandDark)
            .cornerRadius(25)
            .font(.headline)
    }
}

// MARK: - Skewed Background View
struct SkewedBackground: View {
    let color: Color
    let angle: Double = -8
    
    var body: some View {
        color
            .rotationEffect(.degrees(angle), anchor: .center)
            .ignoresSafeArea()
    }
}
