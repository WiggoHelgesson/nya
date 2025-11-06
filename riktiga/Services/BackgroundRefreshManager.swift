import Foundation
import BackgroundTasks

final class BackgroundRefreshManager {
    static let shared = BackgroundRefreshManager()
    private let refreshIdentifier = "se.updown.steps.refresh"
    private init() {}
    
    func register() {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: refreshIdentifier, using: nil) { task in
            guard let refreshTask = task as? BGAppRefreshTask else { return }
            self.handleAppRefresh(task: refreshTask)
        }
    }
    
    func scheduleAppRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: refreshIdentifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 24 * 60 * 60)
        do {
            try BGTaskScheduler.shared.submit(request)
            print("✅ Scheduled background step sync refresh")
        } catch {
            print("❌ Could not schedule background refresh: \(error)")
        }
    }
    
    private func handleAppRefresh(task: BGAppRefreshTask) {
        scheduleAppRefresh()
        let queue = OperationQueue()
        queue.maxConcurrentOperationCount = 1
        task.expirationHandler = {
            queue.cancelAllOperations()
        }
        queue.addOperation {
            let semaphore = DispatchSemaphore(value: 0)
            Task {
                await StepSyncService.shared.syncCurrentUserWeeklySteps()
                semaphore.signal()
            }
            semaphore.wait()
            task.setTaskCompleted(success: true)
        }
    }
}
