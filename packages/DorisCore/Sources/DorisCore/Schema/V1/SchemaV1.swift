import Foundation
import DorisIPC
import SwiftData

public enum SchemaV1 {
    public static let models: [any PersistentModel.Type] = [
        Folder.self,
        Note.self,
        ChecklistItem.self,
        Tag.self,
        Attachment.self,
        Message.self,
        Device.self,
        UserSettings.self
    ]

    public static let schema = Schema(models)
}
