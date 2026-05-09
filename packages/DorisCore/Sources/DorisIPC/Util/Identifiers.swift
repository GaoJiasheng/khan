import Foundation

public enum DorisIdentifiers {
    public static let appGroup = "group.com.gavin.doris.shared"
    public static let cloudKitContainer = "iCloud.com.gavin.doris"
    public static let urlScheme = "doris"
    public static let darwinKickName = "com.gavin.doris.ipc.kick"
    public static let keychainService = "com.gavin.doris.hmac-secret"
    public static let keychainAccount = "doris-cli"
    public static let bgRefreshTaskID = "com.gavin.doris.refresh"
}

public enum DorisZones {
    public static let notes = "NotesZone"
    public static let messages = "MessagesZone"
    public static let outbox = "OutboxZone"
    public static let devices = "DevicesZone"
}
