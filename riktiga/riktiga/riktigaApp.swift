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
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject var authViewModel = AuthViewModel()
    @StateObject var versionService = AppVersionService.shared
    @StateObject var deepLinkHandler = DeepLinkHandler.shared
    @State private var showSplash = true
    @State private var showOptionalUpdate = false
    
    init() {
        // Configure Stripe
        StripeConfig.configure()
    }
    
    var body: some Scene {
        WindowGroup {
            ZStack {
                if showSplash {
                    SplashScreenView()
                        .onAppear {
                            // Check version during splash
                            Task {
                                await versionService.checkVersion()
                            }
                            
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                                withAnimation {
                                    showSplash = false
                                }
                            }
                        }
                } else {
                    // Check version result
                    switch versionService.checkResult {
                    case .forceUpdateRequired(let message, let url):
                        // Block app completely
                        ForceUpdateView(
                            message: message,
                            appStoreUrl: url,
                            isForced: true
                        )
                        
                    case .updateAvailable(let message, let url):
                        // Show main app but with optional update sheet
                        mainAppView
                            .sheet(isPresented: $showOptionalUpdate) {
                                ForceUpdateView(
                                    message: message,
                                    appStoreUrl: url,
                                    isForced: false,
                                    onDismiss: { showOptionalUpdate = false }
                                )
                                .presentationDetents([.medium])
                            }
                            .onAppear {
                                // Show optional update once per session
                                if !showOptionalUpdate {
                                    showOptionalUpdate = true
                                }
                            }
                        
                    case .upToDate, .error:
                        mainAppView
                    }
                }
            }
            // Handle deep links (password reset, etc.)
            .onOpenURL { url in
                _ = deepLinkHandler.handle(url: url)
            }
            // Show reset password sheet when triggered by deep link
            .sheet(isPresented: $deepLinkHandler.showResetPassword) {
                ResetPasswordView()
            }
        }
    }
    
    @ViewBuilder
    private var mainAppView: some View {
        if authViewModel.isLoggedIn {
            MainTabView()
                .environmentObject(authViewModel)
                .onAppear {
                    // Request push notification permission when logged in
                    PushNotificationService.shared.requestPermissionAndRegister()
                }
        } else {
            AuthenticationView()
                .environmentObject(authViewModel)
        }
    }
}
