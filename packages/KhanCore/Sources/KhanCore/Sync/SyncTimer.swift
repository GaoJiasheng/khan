import Foundation
import KhanIPC
import SwiftData

public actor SyncTimer {
    private let container: ModelContainer
    private let interval: TimeInterval
    private var task: Task<Void, Never>?

    public init(container: ModelContainer, interval: TimeInterval = 60) {
        self.container = container
        self.interval = interval
    }

    public func start() {
        guard task == nil else { return }
        let interval = self.interval
        let containerRef = container
        task = Task.detached { [weak self] in
            while let self, !Task.isCancelled {
                await self.poke(container: containerRef)
                try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
            }
        }
    }

    public func stop() {
        task?.cancel()
        task = nil
    }

    public func pokeNow() async {
        await poke(container: container)
    }

    private func poke(container: ModelContainer) async {
        await MainActor.run {
            let context = ModelContext(container)
            do {
                try context.save()
                KhanLog.sync.debug("sync poke fired")
            } catch {
                KhanLog.sync.error("sync poke save failed: \(String(describing: error), privacy: .public)")
            }
        }
    }
}
