import Foundation
import DorisIPC
import SwiftData

@Model
public final class ChecklistItem {
    public var id: UUID = UUID()
    public var text: String = ""
    public var done: Bool = false
    public var position: Int = 0
    public var note: Note?

    public init(
        id: UUID = UUID(),
        text: String,
        done: Bool = false,
        position: Int = 0,
        note: Note? = nil
    ) {
        self.id = id
        self.text = text
        self.done = done
        self.position = position
        self.note = note
    }

    /// Bubbles a "something changed" signal to the parent note so
    /// updatedAt stays in sync when checklist items are toggled or edited.
    /// This is the cross-device sync safety hook: without it, toggling
    /// `done` on one device doesn't bump the note's updatedAt, so the
    /// CloudKit mirror may not propagate the change.
    public func touch() {
        note?.touch()
    }
}
