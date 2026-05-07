import Foundation

public enum KhanIdentifiers {
    public static let appGroup = "group.com.gavin.khan.shared"
    public static let cloudKitContainer = "iCloud.com.gavin.khan"
    public static let urlScheme = "khan"
    public static let darwinKickName = "com.gavin.khan.ipc.kick"
    public static let keychainService = "com.gavin.khan.hmac-secret"
    public static let keychainAccount = "khan-cli"
    public static let bgRefreshTaskID = "com.gavin.khan.refresh"
}

public enum KhanZones {
    public static let notes = "NotesZone"
    public static let messages = "MessagesZone"
    public static let outbox = "OutboxZone"
    public static let devices = "DevicesZone"
}
