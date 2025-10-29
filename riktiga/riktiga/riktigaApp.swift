//
//  UpAndDownApp.swift
//  Up&Down
//
//  Created by Wiggo Helgesson on 2025-10-23.
//

import SwiftUI

@main
struct UpAndDownApp: App {
    @StateObject var authViewModel = AuthViewModel()
    @State private var showSplash = true
    
    var body: some Scene {
        WindowGroup {
            if showSplash {
                SplashScreenView()
                    .onAppear {
                        // Ask for notifications early
                        NotificationManager.shared.requestAuthorization { _ in
                            // After asking, evaluate today's steps and schedule if needed
                            HealthKitManager.shared.getStepsForDate(Date()) { steps in
                                if steps < 10_000 {
                                    NotificationManager.shared.scheduleDailyStepsReminder(atHour: 19, minute: 0)
                                } else {
                                    NotificationManager.shared.cancelDailyStepsReminder()
                                }
                            }
                        }
                        
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
