//
//  UpAndDownApp.swift
//  Up&Down
//
//  Created by Wiggo Helgesson on 2025-10-23.
//

import SwiftUI
import StripePaymentSheet

@main
struct UpAndDownApp: App {
    @StateObject var authViewModel = AuthViewModel()
    @State private var showSplash = true
    
    init() {
        // Configure Stripe
        StripeConfig.configure()
    }
    
    var body: some Scene {
        WindowGroup {
            if showSplash {
                SplashScreenView()
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                            withAnimation {
                                showSplash = false
                            }
                        }
                    }
            } else if authViewModel.isLoggedIn {
                MainTabView()
                    .environmentObject(authViewModel)
            } else {
                AuthenticationView()
                    .environmentObject(authViewModel)
            }
        }
    }
}
