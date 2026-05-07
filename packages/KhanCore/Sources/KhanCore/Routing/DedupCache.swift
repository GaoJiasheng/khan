import Foundation
import KhanIPC

public actor DedupCache {
    private var seen: [UUID: Date] = [:]
    private let capacity: Int
    private let ttl: TimeInterval

    public init(capacity: Int = 1024, ttl: TimeInterval = 600) {
        self.capacity = capacity
        self.ttl = ttl
    }

    public func record(_ id: UUID) -> Bool {
        evict()
        if seen[id] != nil { return false }
        seen[id] = Date()
        return true
    }

    public func contains(_ id: UUID) -> Bool {
        seen[id] != nil
    }

    private func evict() {
        let cutoff = Date().addingTimeInterval(-ttl)
        seen = seen.filter { $0.value > cutoff }
        if seen.count > capacity {
            let sorted = seen.sorted { $0.value < $1.value }
            let drop = sorted.prefix(seen.count - capacity).map(\.key)
            for k in drop { seen.removeValue(forKey: k) }
        }
    }
}
