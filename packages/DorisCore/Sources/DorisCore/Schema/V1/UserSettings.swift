import Foundation
import DorisIPC
import SwiftData

@Model
public final class UserSettings {
    public var id: UUID = UUID()
    public var sidebarEdgeRaw: String = "right"
    public var sidebarWidth: Double = 320
    public var hotSideEnabled: Bool = true
    public var hotSideDwellMs: Int = 150
    public var openBarVisible: Bool = true
    public var notchBehaviorRaw: String = "idlePillVisible"
    public var globalShortcutKey: String?
    public var syncPokeIntervalSec: Int = 60
    public var cloudKitEnabled: Bool = true
    public var defaultNoteFolderID: UUID?
    public var muteRulesData: Data = Data()
    public var cliSourceAllowlist: [String] = ["claude-code", "*"]
    public var themeRaw: String = "system"
    public var showHexColorPreview: Bool = true
    public var autoBackupEnabled: Bool = true
    public var pinnedAcrossSpaces: Bool = true
    public var firstLaunchCompleted: Bool = false
    public var cliInstalledAt: String?
    public var deviceName: String = ""
    public var anchorPositionRaw: String = AnchorPosition.rightCenter.rawValue
    public var anchorVisible: Bool = true

    public init(id: UUID = UUID()) {
        self.id = id
        self.muteRulesData = (try? JSONEncoder().encode([MuteRule]())) ?? Data()
        self.deviceName = DeviceIdentity.currentName()
    }

    public var sidebarEdge: SidebarEdge {
        get { SidebarEdge(rawValue: sidebarEdgeRaw) ?? .right }
        set { sidebarEdgeRaw = newValue.rawValue }
    }

    public var notchBehavior: NotchBehavior {
        get { NotchBehavior(rawValue: notchBehaviorRaw) ?? .idlePillVisible }
        set { notchBehaviorRaw = newValue.rawValue }
    }

    public var theme: DorisTheme {
        get { DorisTheme(rawValue: themeRaw) ?? .system }
        set { themeRaw = newValue.rawValue }
    }

    public var muteRules: [MuteRule] {
        get { (try? JSONDecoder().decode([MuteRule].self, from: muteRulesData)) ?? [] }
        set { muteRulesData = (try? JSONEncoder().encode(newValue)) ?? Data() }
    }

    public var anchorPosition: AnchorPosition {
        get { AnchorPosition(rawValue: anchorPositionRaw) ?? .rightCenter }
        set { anchorPositionRaw = newValue.rawValue }
    }
}
