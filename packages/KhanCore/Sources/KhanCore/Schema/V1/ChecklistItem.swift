import Foundation
import KhanIPC
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
}
