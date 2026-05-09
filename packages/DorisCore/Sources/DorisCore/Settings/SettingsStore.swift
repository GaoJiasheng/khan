import Foundation
import DorisIPC
import SwiftData

@MainActor
public final class SettingsStore {
    private let container: ModelContainer

    public init(container: ModelContainer) {
        self.container = container
    }

    public func load() -> UserSettings {
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<UserSettings>()
        if let existing = try? context.fetch(descriptor).first { return existing }
        let new = UserSettings()
        context.insert(new)
        try? context.save()
        return new
    }

    public func save(_ settings: UserSettings) {
        let context = ModelContext(container)
        if let existing = try? context.fetch(FetchDescriptor<UserSettings>()).first {
            existing.sidebarEdgeRaw = settings.sidebarEdgeRaw
            existing.sidebarWidth = settings.sidebarWidth
            existing.hotSideEnabled = settings.hotSideEnabled
            existing.hotSideDwellMs = settings.hotSideDwellMs
            existing.openBarVisible = settings.openBarVisible
            existing.notchBehaviorRaw = settings.notchBehaviorRaw
            existing.globalShortcutKey = settings.globalShortcutKey
            existing.syncPokeIntervalSec = settings.syncPokeIntervalSec
            existing.cloudKitEnabled = settings.cloudKitEnabled
            existing.defaultNoteFolderID = settings.defaultNoteFolderID
            existing.muteRulesData = settings.muteRulesData
            existing.cliSourceAllowlist = settings.cliSourceAllowlist
            existing.themeRaw = settings.themeRaw
            existing.showHexColorPreview = settings.showHexColorPreview
            existing.autoBackupEnabled = settings.autoBackupEnabled
            existing.pinnedAcrossSpaces = settings.pinnedAcrossSpaces
            existing.firstLaunchCompleted = settings.firstLaunchCompleted
            existing.cliInstalledAt = settings.cliInstalledAt
            existing.deviceName = settings.deviceName
        } else {
            context.insert(settings)
        }
        try? context.save()
    }
}
