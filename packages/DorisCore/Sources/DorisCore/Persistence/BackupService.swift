import Foundation
import DorisIPC

public enum BackupService {
    public static func snapshot() throws -> URL {
        let backups = try IPCDirectory.backupsDir()
        let dateString = Self.dateFormatter.string(from: Date())
        let target = backups.appendingPathComponent(dateString, isDirectory: true)
        try FileManager.default.createDirectory(at: target, withIntermediateDirectories: true)

        let storeURL = try ModelContainerFactory.storeURL(inMemory: false)
        let dir = storeURL.deletingLastPathComponent()
        let fm = FileManager.default
        for file in (try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)) ?? [] {
            let dest = target.appendingPathComponent(file.lastPathComponent)
            try? fm.removeItem(at: dest)
            try fm.copyItem(at: file, to: dest)
        }
        return target
    }

    public static func listBackups() throws -> [URL] {
        let backups = try IPCDirectory.backupsDir()
        let fm = FileManager.default
        let items = (try? fm.contentsOfDirectory(at: backups, includingPropertiesForKeys: nil)) ?? []
        return items.sorted { $0.lastPathComponent > $1.lastPathComponent }
    }

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyyMMdd-HHmmss"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()
}
