import Foundation

struct RewardCelebration: Codable, Identifiable, Equatable {
    let id: UUID
    let points: Int
    let reason: String
    let date: Date
}

final class RewardCelebrationManager {
    static let shared = RewardCelebrationManager()
    
    private let storageKey = "rewardCelebrationQueue"
    private let queue = DispatchQueue(label: "RewardCelebrationManagerQueue", qos: .userInitiated)
    private var cachedCelebrations: [RewardCelebration] = []
    
    private init() {
        cachedCelebrations = loadFromDisk()
    }
    
    func enqueueReward(points: Int, reason: String) {
        queue.sync {
            let celebration = RewardCelebration(id: UUID(), points: points, reason: reason, date: Date())
            cachedCelebrations.append(celebration)
            saveToDisk()
        }
        
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .rewardCelebrationQueued, object: nil)
        }
    }
    
    func consumeNextReward() -> RewardCelebration? {
        var celebration: RewardCelebration?
        queue.sync {
            guard !cachedCelebrations.isEmpty else { return }
            celebration = cachedCelebrations.removeFirst()
            saveToDisk()
        }
        return celebration
    }
    
    private func saveToDisk() {
        guard let data = try? JSONEncoder().encode(cachedCelebrations) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }
    
    private func loadFromDisk() -> [RewardCelebration] {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let celebrations = try? JSONDecoder().decode([RewardCelebration].self, from: data) else {
            return []
        }
        return celebrations
    }
}

extension Notification.Name {
    static let rewardCelebrationQueued = Notification.Name("RewardCelebrationQueued")
}

