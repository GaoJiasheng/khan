import Foundation
import KhanIPC
import SwiftData

@Model
public final class Note {
    public var id: UUID = UUID()
    public var title: String = ""
    public var bodyMarkdown: String = ""
    public var isChecklist: Bool = false
    public var pinned: Bool = false
    public var archived: Bool = false
    public var colorHex: String?
    public var createdAt: Date = Date()
    public var updatedAt: Date = Date()

    public var folder: Folder?
    public var tags: [Tag]? = []
    public var promotedFrom: Message?

    @Relationship(deleteRule: .cascade, inverse: \ChecklistItem.note)
    public var checklistItems: [ChecklistItem]? = []

    @Relationship(deleteRule: .cascade, inverse: \Attachment.note)
    public var attachments: [Attachment]? = []

    public init(
        id: UUID = UUID(),
        title: String = "",
        bodyMarkdown: String = "",
        isChecklist: Bool = false,
        pinned: Bool = false,
        archived: Bool = false,
        colorHex: String? = nil,
        folder: Folder? = nil
    ) {
        self.id = id
        self.title = title
        self.bodyMarkdown = bodyMarkdown
        self.isChecklist = isChecklist
        self.pinned = pinned
        self.archived = archived
        self.colorHex = colorHex
        self.folder = folder
        let now = Date()
        self.createdAt = now
        self.updatedAt = now
    }
}
