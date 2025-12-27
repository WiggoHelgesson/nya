//
//  UpAndDownApp.swift
//  Up&Down
//
//  Created by Wiggo Helgesson on 2025-10-23.
//

import SwiftUI
import StripePaymentSheet
import InsertAffiliateSwift
import RevenueCat

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
        
        // Cancel any existing daily steps reminders (feature removed)
        NotificationManager.shared.cancelDailyStepsReminder()
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
            // Handle deep links (password reset, Insert Affiliate, etc.)
            .onOpenURL { url in
                print("📱 Received deep link: \(url)")
                
                // Check if this is an Insert Affiliate deep link
                let urlString = url.absoluteString
                
                // Handle Insert Affiliate URL scheme (ia-companycode://affiliatecode)
                if urlString.hasPrefix("ia-") {
                    if let affiliateCode = url.host {
                        Task {
                            _ = await InsertAffiliateSwift.setShortCode(shortCode: affiliateCode)
                            print("✅ Insert Affiliate code processed: \(affiliateCode)")
                            // Set RevenueCat attribute if identifier exists
                            if let identifier = InsertAffiliateSwift.returnInsertAffiliateIdentifier() {
                                Purchases.shared.attribution.setAttributes(["insert_affiliate": identifier])
                                print("✅ RevenueCat attribute set: \(identifier)")
                            }
                        }
                    }
                }
                // Handle Insert Affiliate universal link (https://api.insertaffiliate.com/V1/companycode/affiliatecode)
                else if urlString.contains("insertaffiliate.com") {
                    let pathComponents = url.pathComponents
                    if let affiliateCode = pathComponents.last, affiliateCode.count > 2 {
                        Task {
                            _ = await InsertAffiliateSwift.setShortCode(shortCode: affiliateCode)
                            print("✅ Insert Affiliate code processed: \(affiliateCode)")
                            // Set RevenueCat attribute if identifier exists
                            if let identifier = InsertAffiliateSwift.returnInsertAffiliateIdentifier() {
                                Purchases.shared.attribution.setAttributes(["insert_affiliate": identifier])
                                print("✅ RevenueCat attribute set: \(identifier)")
                            }
                        }
                    }
                }
                
                // Handle other deep links (password reset, etc.)
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
                .tint(.black) // Global black tint for all navigation
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
