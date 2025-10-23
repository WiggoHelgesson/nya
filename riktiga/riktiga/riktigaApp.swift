//
//  riktigaApp.swift
//  riktiga
//
//  Created by Wiggo Helgesson on 2025-10-23.
//

import SwiftUI

@main
struct riktigaApp: App {
    @StateObject var authViewModel = AuthViewModel()
    
    var body: some Scene {
        WindowGroup {
            if authViewModel.isLoggedIn {
                MainTabView()
                    .environmentObject(authViewModel)
            } else {
                AuthenticationView()
                    .environmentObject(authViewModel)
            }
        }
    }
}
