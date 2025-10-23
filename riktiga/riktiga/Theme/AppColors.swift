import SwiftUI

struct AppColors {
    // Primary Colors - WANTZEN Branding
    static let brandGreen = Color(red: 0.72, green: 0.85, blue: 0.38)      // #B8D962
    static let brandBlue = Color(red: 0.36, green: 0.44, blue: 0.85)       // #5B6FD9
    static let brandDark = Color(red: 0.1, green: 0.1, blue: 0.1)          // #1A1A1A
    
    // Secondary Colors
    static let white = Color.white
    static let lightGray = Color(red: 0.96, green: 0.96, blue: 0.96)       // #F5F5F5
    static let mediumGray = Color(red: 0.85, green: 0.85, blue: 0.85)      // #D9D9D9
    
    // Functional Colors
    static let success = Color(red: 0.2, green: 0.8, blue: 0.4)
    static let warning = Color(red: 1.0, green: 0.8, blue: 0.0)
    static let error = Color(red: 1.0, green: 0.3, blue: 0.3)
}

// MARK: - Theme Extension
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
