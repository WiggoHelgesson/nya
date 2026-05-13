import Foundation
import Combine

/// Persisterar användarens senaste söktermer för marknadsplatsen.
/// Backas av `UserDefaults` och publicerar ändringar till SwiftUI via
/// `@Published`. Dedupar case-insensitivt med nyaste först, cap `maxCount`.
final class RecentMarketSearchesStore: ObservableObject {
    static let shared = RecentMarketSearchesStore()

    @Published private(set) var items: [String] = []

    private let defaults = UserDefaults.standard
    private let key = "market.recent_searches"
    private let maxCount = 10

    private init() { load() }

    // MARK: - Public API

    func add(_ term: String) {
        let trimmed = term.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        var next = items.filter { $0.caseInsensitiveCompare(trimmed) != .orderedSame }
        next.insert(trimmed, at: 0)
        if next.count > maxCount { next = Array(next.prefix(maxCount)) }
        items = next
        save()
    }

    func remove(_ term: String) {
        items.removeAll { $0.caseInsensitiveCompare(term) == .orderedSame }
        save()
    }

    func clearAll() {
        items = []
        save()
    }

    // MARK: - Persistence

    private func load() {
        items = (defaults.array(forKey: key) as? [String]) ?? []
    }

    private func save() {
        defaults.set(items, forKey: key)
    }
}
