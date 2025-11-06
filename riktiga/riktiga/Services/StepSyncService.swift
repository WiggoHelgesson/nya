import Foundation
import Supabase
import PostgREST

final class StepSyncService {
    static let shared = StepSyncService()
    private let supabase = SupabaseConfig.supabase
    private let calendar = Calendar(identifier: .iso8601)
    private let stepsCache = NSCache<NSString, NSNumber>()
    private init() { }
    
    private func currentWeekKey() -> String {
        let components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date())
        let year = components.yearForWeekOfYear ?? calendar.component(.year, from: Date())
        let week = components.weekOfYear ?? calendar.component(.weekOfYear, from: Date())
        return String(format: "%d-W%02d", year, week)
    }
    
    func syncCurrentUserWeeklySteps() async {
        await withCheckedContinuation { continuation in
            HealthKitManager.shared.getWeeklySteps { dailySteps in
                let totalSteps = dailySteps.reduce(0) { $0 + $1.steps }
                Task {
                    defer { continuation.resume() }
                    do {
                        let session = try await self.supabase.auth.session
                        let userId = session.user.id.uuidString
                        let weekKey = self.currentWeekKey()
                        struct Payload: Encodable { let user_id: String; let week_key: String; let steps: Int }
                        try await self.supabase
                            .from("weekly_steps")
                            .upsert(Payload(user_id: userId, week_key: weekKey, steps: totalSteps), onConflict: "user_id,week_key")
                            .execute()
                        print("✅ Synced weekly steps: \(totalSteps) for \(userId) week=\(weekKey)")
                        self.stepsCache.setObject(NSNumber(value: totalSteps), forKey: "\(userId)_\(weekKey)" as NSString)
                    } catch {
                        print("❌ Failed to sync weekly steps: \(error)")
                    }
                }
            }
        }
    }

    func fetchWeeklySteps(for userId: String) async -> Int {
        let weekKey = currentWeekKey()
        let cacheKey = "\(userId)_\(weekKey)" as NSString
        if let cached = stepsCache.object(forKey: cacheKey) {
            return cached.intValue
        }
        
        struct Row: Decodable { let steps: Int }
        do {
            let rows: [Row] = try await supabase
                .from("weekly_steps")
                .select("steps")
                .eq("user_id", value: userId)
                .eq("week_key", value: weekKey)
                .limit(1)
                .execute()
                .value
            let steps = rows.first?.steps ?? 0
            stepsCache.setObject(NSNumber(value: steps), forKey: cacheKey)
            return steps
        } catch {
            if let postgrestError = error as? PostgrestError, postgrestError.code == "42P01" {
                print("⚠️ weekly_steps table not found on Supabase")
                return 0
            }
            print("❌ Error fetching weekly steps for \(userId): \(error)")
            return 0
        }
    }
    
    static func convertStepsToKilometers(_ steps: Int) -> Double {
        Double(steps) / 1312.0
    }
}
