import Foundation
import DorisIPC
import SwiftData

/// Periodically calls `ModelContext.save()` to flush pending writes and let
/// SwiftData's CloudKit mirror push them upstream. The "poke" model is
/// deliberately conservative — saves are cheap when there's nothing dirty
/// and SwiftData handles the actual CloudKit round-trip behind the scenes.
///
/// Reads `SyncSettings.shared.autoSyncEnabled` at start; if the user has
/// auto-sync turned off, `start()` is a no-op until they call `pokeNow()`
/// manually (the toolbar button) or restart the app with auto-sync back on.
///
/// On every successful poke, updates `SyncSettings.shared.lastSyncedAt`
/// so UI can render a "Last synced 30 s ago" label without polling.
public actor SyncTimer {
    private let container: ModelContainer
    private let interval: TimeInterval
    private var task: Task<Void, Never>?

    public init(container: ModelContainer, interval: TimeInterval = 60) {
        self.container = container
        self.interval = interval
    }

    public func start() async {
        guard task == nil else { return }
        let auto = await MainActor.run { SyncSettings.shared.autoSyncEnabled }
        guard auto else {
            DorisLog.sync.debug("auto-sync disabled by user; timer not started")
            return
        }
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

    /// Explicit user-driven sync. Always runs regardless of the auto-sync
    /// setting; this is the path the "Sync Now" button takes.
    public func pokeNow() async {
        await poke(container: container)
    }

    private func poke(container: ModelContainer) async {
        await MainActor.run {
            let context = ModelContext(container)
            do {
                try context.save()
                SyncSettings.shared.markSyncedNow()
                DorisLog.sync.debug("sync poke fired")
            } catch {
                DorisLog.sync.error("sync poke save failed: \(String(describing: error), privacy: .public)")
            }
        }
    }
}
