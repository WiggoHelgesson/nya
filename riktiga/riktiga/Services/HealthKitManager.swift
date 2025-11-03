import Foundation
import HealthKit

class HealthKitManager {
    static let shared = HealthKitManager()
    
    private let healthStore = HKHealthStore()
    private let stepsType = HKQuantityType.quantityType(forIdentifier: .stepCount)!
    private let flightsType = HKQuantityType.quantityType(forIdentifier: .flightsClimbed)!
    
    private init() {
        // Request authorization for step count
        let typesToRead: Set<HKObjectType> = [stepsType, flightsType]
        
        guard HKHealthStore.isHealthDataAvailable() else {
            print("ℹ️ Health data is not available on this device")
            return
        }
        
        healthStore.requestAuthorization(toShare: nil, read: typesToRead) { success, error in
            if success {
                print("✅ HealthKit authorization granted")
            } else {
                print("❌ HealthKit authorization denied: \(error?.localizedDescription ?? "unknown error")")
            }
        }
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

