import Foundation
import DorisIPC
import SwiftData

@Model
public final class Device {
    public var id: UUID = UUID()
    public var name: String = ""
    public var platform: String = ""
    public var lastSeenAt: Date = Date()

    public init(id: UUID, name: String, platform: String, lastSeenAt: Date = Date()) {
        self.id = id
        self.name = name
        self.platform = platform
        self.lastSeenAt = lastSeenAt
    }
}
