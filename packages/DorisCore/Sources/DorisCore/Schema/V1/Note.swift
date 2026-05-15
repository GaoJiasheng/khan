import Foundation
import DorisIPC
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
    /// Due date for calendar/Today view. nil = no due date.
    /// Added in SchemaV2; existing notes get nil via lightweight migration.
    public var dueDate: Date?
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
        dueDate: Date? = nil,
        folder: Folder? = nil
    ) {
        self.id = id
        self.title = title
        self.bodyMarkdown = bodyMarkdown
        self.isChecklist = isChecklist
        self.pinned = pinned
        self.archived = archived
        self.colorHex = colorHex
        self.dueDate = dueDate
        self.folder = folder
        let now = Date()
        self.createdAt = now
        self.updatedAt = now
    }

    // MARK: - Helpers

    /// Stamps `updatedAt` to now. Use this instead of setting `updatedAt`
    /// directly — single chokepoint for all "note was modified" signals,
    /// important for CloudKit merge-conflict disambiguation.
    public func touch() {
        updatedAt = Date()
    }

    /// Soft-delete: marks the note archived and stamps updatedAt. Use this
    /// instead of `modelContext.delete(note)` so CloudKit propagates the
    /// archived flag to other devices. SyncTimer auto-purges records that
    /// have been archived for 30+ days via a hard delete.
    public func archive() {
        archived = true
        touch()
    }
}
