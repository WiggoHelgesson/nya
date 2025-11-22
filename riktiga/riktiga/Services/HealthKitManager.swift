import Foundation
import HealthKit
import UIKit

class HealthKitManager {
    static let shared = HealthKitManager()
    
    private let healthStore = HKHealthStore()
    private let stepsType = HKQuantityType.quantityType(forIdentifier: .stepCount)!
    private let flightsType = HKQuantityType.quantityType(forIdentifier: .flightsClimbed)!
    
    private init() {}
    
    func requestAuthorization(completion: ((Bool) -> Void)? = nil) {
        let typesToRead: Set<HKObjectType> = [stepsType, flightsType]
        
        guard HKHealthStore.isHealthDataAvailable() else {
            print("ℹ️ Health data is not available on this device")
            completion?(false)
            return
        }
        
        healthStore.requestAuthorization(toShare: nil, read: typesToRead) { _, error in
            // Defer status check slightly to allow HealthKit to update
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                let authorized = self.isHealthDataAuthorized()
                
                if authorized {
                    print("✅ HealthKit authorization granted for required types")
                } else if let error = error {
                    print("❌ HealthKit authorization failed: \(error.localizedDescription)")
                } else {
                    let stepsStatus = self.healthStore.authorizationStatus(for: self.stepsType)
                    let flightsStatus = self.healthStore.authorizationStatus(for: self.flightsType)
                    print("⚠️ HealthKit authorization incomplete – steps status: \(stepsStatus.rawValue), flights status: \(flightsStatus.rawValue)")
                }
                
                completion?(authorized)
            }
        }
    }
    
    func handleManageAuthorizationButton() {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        let status = healthStore.authorizationStatus(for: stepsType)
        
        switch status {
        case .notDetermined:
            DispatchQueue.main.async {
                self.requestAuthorization()
            }
        case .sharingAuthorized, .sharingDenied:
            DispatchQueue.main.async {
                guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                UIApplication.shared.open(url)
            }
        @unknown default:
            DispatchQueue.main.async {
                guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                UIApplication.shared.open(url)
            }
        }
    }
    
    func isHealthDataAuthorized() -> Bool {
        guard HKHealthStore.isHealthDataAvailable() else { return false }
        let stepsStatus = healthStore.authorizationStatus(for: stepsType)
        return stepsStatus == .sharingAuthorized
    }
    
    func getWeeklySteps(completion: @escaping ([DailySteps]) -> Void) {
        let calendar = Calendar.current
        let now = Date()
        
        // Get start of week (Monday)
        let startOfWeek = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now))!
        
        // Get end of week (Sunday)
        let endOfWeek = calendar.date(byAdding: .day, value: 6, to: startOfWeek)!
        
        let predicate = HKQuery.predicateForSamples(
            withStart: startOfWeek,
            end: endOfWeek,
            options: .strictStartDate
        )
        
        let query = HKStatisticsCollectionQuery(
            quantityType: stepsType,
            quantitySamplePredicate: predicate,
            options: .cumulativeSum,
            anchorDate: startOfWeek,
            intervalComponents: DateComponents(day: 1)
        )
        
        query.initialResultsHandler = { query, results, error in
            guard let results = results else {
                print("❌ Error fetching steps: \(error?.localizedDescription ?? "unknown error")")
                DispatchQueue.main.async {
                    completion([])
                }
                return
            }
            
            var dailySteps: [DailySteps] = []
            
            results.enumerateStatistics(from: startOfWeek, to: endOfWeek) { statistics, _ in
                let date = statistics.startDate
                let steps = statistics.sumQuantity()?.doubleValue(for: HKUnit.count()) ?? 0
                
                dailySteps.append(DailySteps(date: date, steps: Int(steps)))
            }
            
            DispatchQueue.main.async {
                completion(dailySteps)
            }
        }
        
        healthStore.execute(query)
    }
    
    func getStepsForDate(_ date: Date, completion: @escaping (Int) -> Void) {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: endOfDay, options: .strictStartDate)
        
        let query = HKStatisticsQuery(
            quantityType: stepsType,
            quantitySamplePredicate: predicate,
            options: .cumulativeSum
        ) { _, result, error in
            guard let result = result, let sum = result.sumQuantity() else {
                DispatchQueue.main.async {
                    completion(0)
                }
                return
            }
            
            let steps = Int(sum.doubleValue(for: HKUnit.count()))
            DispatchQueue.main.async {
                completion(steps)
            }
        }
        
        healthStore.execute(query)
    }

    // MARK: - Monthly steps total for current month
    func getCurrentMonthStepsTotal(completion: @escaping (Int) -> Void) {
        let calendar = Calendar.current
        let now = Date()
        let comps = calendar.dateComponents([.year, .month], from: now)
        guard let startOfMonth = calendar.date(from: comps),
              let endOfMonth = calendar.date(byAdding: DateComponents(month: 1), to: startOfMonth) else {
            completion(0)
            return
        }
        let predicate = HKQuery.predicateForSamples(withStart: startOfMonth, end: endOfMonth, options: .strictStartDate)
        let query = HKStatisticsQuery(quantityType: stepsType, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, result, _ in
            let steps = Int(result?.sumQuantity()?.doubleValue(for: HKUnit.count()) ?? 0)
            DispatchQueue.main.async { completion(steps) }
        }
        healthStore.execute(query)
    }
    
    func getWeeklyFlightsClimbed(completion: @escaping ([DailyFlights]) -> Void) {
        let calendar = Calendar.current
        let now = Date()
        guard let startOfWeek = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)) else {
            completion([])
            return
        }
        guard let endOfWeek = calendar.date(byAdding: .day, value: 7, to: startOfWeek) else {
            completion([])
            return
        }
        let predicate = HKQuery.predicateForSamples(
            withStart: startOfWeek,
            end: endOfWeek,
            options: .strictStartDate
        )
        let query = HKStatisticsCollectionQuery(
            quantityType: flightsType,
            quantitySamplePredicate: predicate,
            options: .cumulativeSum,
            anchorDate: startOfWeek,
            intervalComponents: DateComponents(day: 1)
        )
        query.initialResultsHandler = { _, results, error in
            guard let results = results else {
                print("❌ Error fetching flights climbed: \(error?.localizedDescription ?? "unknown error")")
                DispatchQueue.main.async { completion([]) }
                return
            }
            var dailyFlights: [DailyFlights] = []
            results.enumerateStatistics(from: startOfWeek, to: endOfWeek) { statistics, _ in
                let date = statistics.startDate
                let flights = Int(statistics.sumQuantity()?.doubleValue(for: HKUnit.count()) ?? 0)
                let entry = DailyFlights(date: date, count: flights, isToday: calendar.isDateInToday(date))
                dailyFlights.append(entry)
            }
            DispatchQueue.main.async { completion(dailyFlights) }
        }
        healthStore.execute(query)
    }
}

struct DailySteps: Identifiable {
    let id = UUID()
    let date: Date
    let steps: Int
    
    var dayName: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter.string(from: date)
    }
    
    var shortDayName: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "E"
        return formatter.string(from: date)
    }
}

struct DailyFlights: Identifiable {
    let id = UUID()
    let date: Date
    let count: Int
    let isToday: Bool
    
    var dayName: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "sv_SE")
        formatter.dateFormat = "EEE"
        return formatter.string(from: date)
    }
}

