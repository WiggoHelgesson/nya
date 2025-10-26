import SwiftUI
import RevenueCat
import RevenueCatUI

struct PaywallAfterSignupView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    
    var body: some View {
        PaywallView()
    }
}


#Preview {
    PaywallAfterSignupView()
        .environmentObject(AuthViewModel())
}

