import Foundation
import DorisIPC
import SwiftData

@Model
public final class Attachment {
    public var id: UUID = UUID()
    public var filename: String = ""
    public var mimeType: String = ""
    public var byteCount: Int = 0
    public var relativePath: String = ""
    public var createdAt: Date = Date()

    public var note: Note?
    public var message: Message?

    public init(
        id: UUID = UUID(),
        filename: String,
        mimeType: String,
        byteCount: Int,
        relativePath: String,
        note: Note? = nil,
        message: Message? = nil
    ) {
        self.id = id
        self.filename = filename
        self.mimeType = mimeType
        self.byteCount = byteCount
        self.relativePath = relativePath
        self.note = note
        self.message = message
        self.createdAt = Date()
    }
}
