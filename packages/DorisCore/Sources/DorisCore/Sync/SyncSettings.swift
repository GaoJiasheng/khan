import Foundation
import Combine

/// User-facing iCloud sync controls. Owns the persisted "should we use
/// CloudKit?", "should we auto-poke?", and the most recent successful
/// sync timestamp. UI binds to it; the runtime reads it to decide which
/// `ModelContainer` to construct, and whether to start the periodic timer.
///
/// Persisted in the **App Group** UserDefaults (`group.com.gavin.doris.shared`)
/// so the CLI, the share extension, and the main app see the same flags.
/// Falls back to `UserDefaults.standard` if the App Group isn't available
/// (unsigned dev builds — same fallback as IPCDirectory).
@MainActor
public final class SyncSettings: ObservableObject {
    public static let shared = SyncSettings()

    private static let cloudKitEnabledKey = "doris.sync.cloudkit.enabled"
    private static let autoSyncEnabledKey = "doris.sync.auto.enabled"
    private static let lastSyncedAtKey    = "doris.sync.lastSyncedAt"

    /// Cross-process defaults. Returns the App-Group-scoped suite when
    /// available, otherwise falls back to standard. Same fallback shape
    /// IPCDirectory uses for unsigned dev builds.
    private static let store: UserDefaults = {
        UserDefaults(suiteName: DorisIdentifiers.appGroup) ?? .standard
    }()

    /// True = ModelContainer is constructed with `cloudKitDatabase: .private(...)`.
    /// Flipping this requires an app restart for the change to take effect
    /// (SwiftData picks the configuration at container init time).
    @Published public var cloudKitEnabled: Bool {
        didSet { Self.store.set(cloudKitEnabled, forKey: Self.cloudKitEnabledKey) }
    }

    /// True = `SyncTimer` runs the periodic context.save() poke. Off = only
    /// manual `Sync Now` button + remote pushes update state.
    @Published public var autoSyncEnabled: Bool {
        didSet { Self.store.set(autoSyncEnabled, forKey: Self.autoSyncEnabledKey) }
    }

    /// Last time `SyncTimer.poke` saved without error. Drives the "Last
    /// synced 30 s ago" label in Settings + the toolbar Sync Now button.
    @Published public var lastSyncedAt: Date? {
        didSet {
            if let d = lastSyncedAt {
                Self.store.set(d.timeIntervalSince1970, forKey: Self.lastSyncedAtKey)
            } else {
                Self.store.removeObject(forKey: Self.lastSyncedAtKey)
            }
        }
    }

    private init() {
        let store = Self.store
        // CloudKit defaults to OFF — matches the previous env-var-gated behavior
        // so dev builds still come up clean. Users opt-in via Settings.
        let ck = store.object(forKey: Self.cloudKitEnabledKey) as? Bool ?? false
        let auto = store.object(forKey: Self.autoSyncEnabledKey) as? Bool ?? true
        let last = store.object(forKey: Self.lastSyncedAtKey) as? TimeInterval

        self.cloudKitEnabled = ck
        self.autoSyncEnabled = auto
        self.lastSyncedAt = last.map { Date(timeIntervalSince1970: $0) }

        // Honor the legacy env-var override on first launch — if the user has
        // DORIS_USE_CLOUDKIT=1 in their shell, treat it as opt-in. We only do
        // this when the persisted value hasn't been explicitly set yet.
        if store.object(forKey: Self.cloudKitEnabledKey) == nil {
            if ProcessInfo.processInfo.environment["DORIS_USE_CLOUDKIT"] == "1" {
                self.cloudKitEnabled = true
            }
        }
    }

    /// Called by SyncTimer after a successful poke. Wraps in a MainActor
    /// hop to make Combine publishing safe.
    public func markSyncedNow() {
        lastSyncedAt = Date()
    }
}
