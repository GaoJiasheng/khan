import Foundation
import DorisIPC
import SwiftData

/// Periodically calls `ModelContext.save()` to flush pending writes and let
/// SwiftData's CloudKit mirror push them upstream. The "poke" model is
/// deliberately conservative — saves are cheap when there's nothing dirty
/// and SwiftData handles the actual CloudKit round-trip behind the scenes.
///
/// On every successful poke, updates `SyncSettings.shared.lastSyncedAt`
/// so UI can render a "Last synced 30 s ago" label. On failure, updates
/// `SyncSettings.shared.lastSyncError` so both iOS and Mac can surface
/// a red alert without the user digging into logs.
///
/// Also runs a 30-day tombstone purge on each poke: notes that have been
/// soft-deleted (`archived = true`) for 30+ days are hard-deleted so they
/// don't accumulate indefinitely in iCloud.
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
                SyncSettings.shared.lastSyncError = nil
                DorisLog.sync.debug("sync poke fired")
            } catch {
                let msg = error.localizedDescription
                SyncSettings.shared.lastSyncError = msg
                DorisLog.sync.error("sync poke save failed: \(msg, privacy: .public)")
            }
            // 30-day tombstone purge — runs on every poke so it's
            // ambient and doesn't require a separate scheduled task.
            Self.purgeTombstones(context: context)
        }
    }

    /// Hard-deletes notes that have been soft-deleted (`archived = true`)
    /// for more than 30 days. Must be called on the main actor (since
    /// `ModelContext` operations are main-actor bound).
    @MainActor
    private static func purgeTombstones(context: ModelContext) {
        let cutoff = Date().addingTimeInterval(-30 * 24 * 60 * 60)
        let descriptor = FetchDescriptor<Note>(
            predicate: #Predicate<Note> { $0.archived && $0.updatedAt < cutoff }
        )
        guard let stale = try? context.fetch(descriptor), !stale.isEmpty else { return }
        for note in stale {
            context.delete(note)
        }
        try? context.save()
        DorisLog.sync.debug("purged \(stale.count) tombstoned note(s)")
    }
}
