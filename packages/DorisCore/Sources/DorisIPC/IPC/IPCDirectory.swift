import Foundation

public enum IPCDirectory {
    public enum DirectoryError: Error {
        case appGroupUnavailable
    }

    /// Returns the App Group container URL, or a development fallback when the binary
    /// is not signed/entitled. The fallback honors `$DORIS_IPC_ROOT` for explicit override.
    public static func containerURL() throws -> URL {
        if let override = ProcessInfo.processInfo.environment["DORIS_IPC_ROOT"], !override.isEmpty {
            return URL(fileURLWithPath: override, isDirectory: true)
        }
        if let url = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: DorisIdentifiers.appGroup
        ) {
            return url
        }
        // Fallback for unsigned dev builds (Mac only — on iOS, the App Group
        // is always entitled when running on device or simulator, so this
        // path doesn't apply, and `homeDirectoryForCurrentUser` is iOS-banned).
        #if os(macOS)
        let home = FileManager.default.homeDirectoryForCurrentUser
        return home
            .appendingPathComponent("Library/Application Support", isDirectory: true)
            .appendingPathComponent("doris-dev", isDirectory: true)
        #else
        // On iOS, fall back to the app's caches dir if the App Group is
        // genuinely missing — better to persist somewhere than crash.
        let caches = try FileManager.default.url(
            for: .cachesDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        return caches.appendingPathComponent("doris-fallback", isDirectory: true)
        #endif
    }

    public static func ipcRoot() throws -> URL {
        try containerURL().appendingPathComponent("IPC", isDirectory: true)
    }

    public static func inboxDir() throws -> URL {
        try ipcRoot().appendingPathComponent("inbox", isDirectory: true)
    }

    public static func outboxDir() throws -> URL {
        try ipcRoot().appendingPathComponent("outbox", isDirectory: true)
    }

    public static func processedDir() throws -> URL {
        try ipcRoot().appendingPathComponent("processed", isDirectory: true)
    }

    public static func attachmentsDir() throws -> URL {
        try containerURL().appendingPathComponent("Attachments", isDirectory: true)
    }

    public static func backupsDir() throws -> URL {
        try containerURL().appendingPathComponent("Backups", isDirectory: true)
    }

    public static func logsDir() throws -> URL {
        try containerURL().appendingPathComponent("Logs", isDirectory: true)
    }

    @discardableResult
    public static func ensureDirectories() throws -> URL {
        let fm = FileManager.default
        let root = try containerURL()
        try fm.createDirectory(at: root, withIntermediateDirectories: true)
        for sub in ["IPC/inbox", "IPC/outbox", "IPC/processed", "Attachments", "Backups", "Logs"] {
            let url = root.appendingPathComponent(sub, isDirectory: true)
            try fm.createDirectory(at: url, withIntermediateDirectories: true)
        }
        return root
    }

    public static func newRequestFilename(for id: UUID) -> String {
        let ms = Int64(Date().timeIntervalSince1970 * 1000)
        return "\(ms)-\(id.uuidString).json"
    }
}
