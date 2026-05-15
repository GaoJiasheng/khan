import Foundation
import DorisIPC
import SwiftData

/// Version 1 of the Doris schema — original set of 8 models with no
/// `dueDate` on Note. Used as the migration source in `DorisMigrationPlan`.
public enum SchemaV1: VersionedSchema {
    public static let versionIdentifier = Schema.Version(1, 0, 0)

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
