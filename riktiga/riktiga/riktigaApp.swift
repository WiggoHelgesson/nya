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
import GoogleSignIn

@main
struct UpAndDownApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject var authViewModel = AuthViewModel()
    @StateObject var versionService = AppVersionService.shared
    @StateObject var deepLinkHandler = DeepLinkHandler.shared
    @State private var showSplash = true
    @State private var showOptionalUpdate = false
    @State private var showAdPopup = false
    @ObservedObject private var adService = AdService.shared
    
    init() {
        // Configure Stripe
        StripeConfig.configure()
        
        // Configure Google Sign-In
        GIDSignIn.sharedInstance.configuration = GIDConfiguration(
            clientID: "748390418907-05k79f4af3tcdftfeasfds1rq0behvoi.apps.googleusercontent.com"
        )
        
        // Cancel any existing daily steps reminders (feature removed)
        NotificationManager.shared.cancelDailyStepsReminder()
    }
    
    var body: some Scene {
        WindowGroup {
            ZStack {
                if showSplash {
                    SplashScreenView()
                        .onAppear {
                            Task {
                                await versionService.checkVersion()
                                await adService.fetchPopupAd()
                            }
                            
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                                withAnimation {
                                    showSplash = false
                                }
                                if adService.popupAd != nil {
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                        showAdPopup = true
                                    }
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
            // Handle deep links (password reset, Insert Affiliate, Strava, Google Sign-In, etc.)
            .onOpenURL { url in
                print("📱 Received deep link: \(url)")
                
                // Handle Google Sign-In callback
                if GIDSignIn.sharedInstance.handle(url) {
                    print("✅ Google Sign-In URL handled")
                    return
                }
                
                // Check if this is an Insert Affiliate deep link
                let urlString = url.absoluteString
                
                // Handle Strava OAuth callback (upanddown://upanddown?code=...)
                if url.scheme == "upanddown" && url.host == "upanddown" {
                    Task {
                        let success = await StravaService.shared.handleOAuthCallback(url: url)
                        print(success ? "✅ Strava connected successfully" : "❌ Strava connection failed")
                    }
                    return
                }
                
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
            .fullScreenCover(isPresented: $showAdPopup) {
                if let ad = adService.popupAd {
                    PopupAdView(ad: ad) {
                        adService.markPopupShown()
                        showAdPopup = false
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    private var mainAppView: some View {
        if authViewModel.isLoggedIn {
            MainTabView()
                .environmentObject(authViewModel)
                .tint(.black)
                .onAppear {
                    PushNotificationService.shared.requestPermissionAndRegister()
                    NotificationManager.shared.cancelMealReminders()
                    NotificationManager.shared.scheduleMonthlyReportNotifications(avatarUrl: authViewModel.currentUser?.avatarUrl)
                    WidgetSyncService.shared.syncStreakData()
                }
        } else {
            AuthenticationView()
                .environmentObject(authViewModel)
        }
    }
}

// MARK: - Fullscreen Popup Ad
struct PopupAdView: View {
    let ad: AdCampaign
    let onDismiss: () -> Void
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            if let imageURL = ad.imageURL {
                AsyncImage(url: imageURL) { image in
                    image.resizable().aspectRatio(contentMode: .fill)
                } placeholder: {
                    Color.black
                }
                .ignoresSafeArea()
            }
            
            LinearGradient(
                colors: [.black.opacity(0.7), .clear, .black.opacity(0.6)],
                startPoint: .bottom,
                endPoint: .top
            )
            .ignoresSafeArea()
            
            VStack {
                HStack {
                    Spacer()
                    Button(action: onDismiss) {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 36, height: 36)
                            .background(Color.black.opacity(0.5))
                            .clipShape(Circle())
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 60)
                
                Spacer()
                
                VStack(spacing: 12) {
                    Text(ad.title)
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                    
                    if let desc = ad.description, !desc.isEmpty {
                        Text(desc)
                            .font(.system(size: 16))
                            .foregroundColor(.white.opacity(0.85))
                            .multilineTextAlignment(.center)
                            .lineLimit(3)
                    }
                    
                    Button {
                        AdService.shared.trackClick(campaignId: ad.id)
                        if let url = ad.ctaURL {
                            UIApplication.shared.open(url)
                        }
                        onDismiss()
                    } label: {
                        Text(ad.ctaLabel)
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.white)
                            .cornerRadius(14)
                    }
                    .padding(.top, 8)
                    
                    Text("Annons")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.5))
                }
                .padding(.horizontal, 30)
                .padding(.bottom, 60)
            }
        }
    }
}
