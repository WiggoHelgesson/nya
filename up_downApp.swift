import SwiftUI

@main
struct up_downApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject var authViewModel = AuthViewModel()
    @Environment(\.scenePhase) private var scenePhase
    
    var body: some Scene {
        WindowGroup {
            if authViewModel.isLoggedIn {
                MainTabView()
                    .environmentObject(authViewModel)
                    .task {
                        await StepSyncService.shared.syncCurrentUserWeeklySteps()
                    }
            } else {
                AuthenticationView()
                    .environmentObject(authViewModel)
            }
        }
        .onChange(of: scenePhase) { phase in
            switch phase {
            case .active:
                Task {
                    await StepSyncService.shared.syncCurrentUserWeeklySteps()
                }
            case .background:
                BackgroundRefreshManager.shared.scheduleAppRefresh()
            default:
                break
            }
        }
    }
}
