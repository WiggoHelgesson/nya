import UIKit
import BackgroundTasks

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        BackgroundRefreshManager.shared.register()
        BackgroundRefreshManager.shared.scheduleAppRefresh()
        return true
    }
    
    func applicationDidEnterBackground(_ application: UIApplication) {
        BackgroundRefreshManager.shared.scheduleAppRefresh()
    }
}
