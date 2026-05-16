import Foundation
import DorisIPC
import SwiftData

/// Version 2 of the Doris schema — adds the optional `dueDate: Date?`
/// field to `Note`. All other models are unchanged.
///
/// Migration V1 → V2 is a SwiftData lightweight stage: the new column
/// is added to the SQLite store with NULL for all existing rows.
/// See `DorisMigrationPlan` for the registered migration path.
public enum SchemaV2: VersionedSchema {
    public static let versionIdentifier = Schema.Version(2, 0, 0)

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
