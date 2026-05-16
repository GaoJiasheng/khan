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
    /// Top-level "task done" state. Each Note IS a TODO item — the
    /// list view shows a checkbox per row; tick it to mark this whole
    /// note complete. Independent of any in-body checklist items
    /// (those live in `bodyMarkdown` as `- [x]` markers).
    public var done: Bool = false
    /// Timestamp when `done` flipped from false → true. Cleared back to
    /// `nil` when `done` flips back to false. Used by the future
    /// "archive yesterday's completed tasks" automation.
    public var completedAt: Date?
    /// Timestamp when `archived` flipped from false → true. Cleared
    /// back to `nil` on un-archive. Lets the archived view sort by
    /// "most recently archived first" (more useful than `updatedAt`
    /// for digging through old tasks).
    public var archivedAt: Date?
    /// Soft-delete flag — `true` means the row is in the trash view,
    /// recoverable. The user requested this so the regular delete
    /// button doesn't need a confirmation dialog (mistakes can be
    /// undone from Trash). Hard-delete (truly removing the row) only
    /// happens from inside the trash view.
    public var deleted: Bool = false
    /// Timestamp when `deleted` flipped from false → true. Cleared on
    /// restore. Used to sort the Trash view newest-first.
    public var deletedAt: Date?
    /// Manual sort key for drag-and-drop reordering. Lower value =
    /// higher in the list within the same pinned/done group. Default 0
    /// for legacy rows (they fall back to `createdAt` ordering via the
    /// secondary sort). Stored as Double so we can sandwich a new
    /// note between two existing rows by averaging their orders
    /// without renumbering everything.
    public var order: Double = 0
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
