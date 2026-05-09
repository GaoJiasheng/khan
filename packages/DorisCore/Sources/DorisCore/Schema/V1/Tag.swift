import Foundation
import DorisIPC
import SwiftData

@Model
public final class Tag {
    public var id: UUID = UUID()
    public var name: String = ""
    public var colorHex: String?
    public var createdAt: Date = Date()

    @Relationship(inverse: \Note.tags)
    public var notes: [Note]? = []

    @Relationship(inverse: \Message.tags)
    public var messages: [Message]? = []

    public init(id: UUID = UUID(), name: String, colorHex: String? = nil) {
        self.id = id
        self.name = name
        self.colorHex = colorHex
        self.createdAt = Date()
    }
}
