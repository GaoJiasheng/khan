import Foundation
import DorisIPC
import SwiftData

@Model
public final class Folder {
    public var id: UUID = UUID()
    public var name: String = ""
    public var colorHex: String?
    public var position: Int = 0
    public var isPinned: Bool = false
    public var createdAt: Date = Date()
    public var updatedAt: Date = Date()

    public var parent: Folder?

    @Relationship(deleteRule: .cascade, inverse: \Folder.parent)
    public var children: [Folder]? = []

    @Relationship(deleteRule: .nullify, inverse: \Note.folder)
    public var notes: [Note]? = []

    public init(
        id: UUID = UUID(),
        name: String,
        colorHex: String? = nil,
        position: Int = 0,
        isPinned: Bool = false,
        parent: Folder? = nil
    ) {
        self.id = id
        self.name = name
        self.colorHex = colorHex
        self.position = position
        self.isPinned = isPinned
        self.parent = parent
        let now = Date()
        self.createdAt = now
        self.updatedAt = now
    }
}
