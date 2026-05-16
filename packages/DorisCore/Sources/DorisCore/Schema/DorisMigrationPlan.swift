import Foundation
import SwiftData

/// Registered migration plan for the Doris SwiftData store.
///
/// Currently contains one stage: V1 → V2 (lightweight — adds the
/// optional `dueDate: Date?` field to `Note`). SwiftData performs
/// the column addition automatically; no custom migration closure is
/// needed because `dueDate` is optional and existing rows default to nil.
///
/// Both iOS and macOS load the container via `ModelContainerFactory`
/// which passes `migrationPlan: DorisMigrationPlan.self`, so both
/// platforms migrate in lockstep when the binary is updated.
public enum DorisMigrationPlan: SchemaMigrationPlan {
    public static var schemas: [any VersionedSchema.Type] = [
        SchemaV1.self,
        SchemaV2.self
    ]

    public static var stages: [MigrationStage] = [
        .lightweight(fromVersion: SchemaV1.self, toVersion: SchemaV2.self)
    ]
}
