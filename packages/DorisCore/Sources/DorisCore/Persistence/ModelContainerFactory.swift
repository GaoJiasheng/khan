import Foundation
import DorisIPC
import SwiftData

public enum ModelContainerFactory {
    public enum FactoryError: Error {
        case appGroupUnavailable
    }

    /// Creates the shared Doris `ModelContainer`.
    ///
    /// Both iOS and macOS call this via `DorisRuntime.shared.container`
    /// so they always use the **same** schema version, migration plan,
    /// and CloudKit container — the single source of truth for cross-
    /// device data consistency.
    ///
    /// Migration: `DorisMigrationPlan` is always registered. On first
    /// launch after an app update that bumps the schema version, SwiftData
    /// runs the appropriate lightweight stage before the container opens.
    public static func make(useCloudKit: Bool = true, inMemory: Bool = false) throws -> ModelContainer {
        let url = try storeURL(inMemory: inMemory)
        let schema = SchemaV2.schema

        let config: ModelConfiguration
        if inMemory {
            config = ModelConfiguration(
                "Doris-InMemory",
                schema: schema,
                isStoredInMemoryOnly: true
            )
        } else if useCloudKit {
            config = ModelConfiguration(
                "Doris",
                schema: schema,
                url: url,
                cloudKitDatabase: .private(DorisIdentifiers.cloudKitContainer)
            )
        } else {
            config = ModelConfiguration(
                "Doris",
                schema: schema,
                url: url,
                cloudKitDatabase: .none
            )
        }

        return try ModelContainer(
            for: schema,
            migrationPlan: DorisMigrationPlan.self,
            configurations: [config]
        )
    }

    public static func storeURL(inMemory: Bool) throws -> URL {
        if inMemory {
            return URL(fileURLWithPath: "/dev/null")
        }
        // Single source of truth: IPCDirectory.containerURL() honors DORIS_IPC_ROOT
        // for dev builds and falls back through the App Group container otherwise.
        let group = try IPCDirectory.containerURL()
        let storeDir = group.appendingPathComponent("Store", isDirectory: true)
        try FileManager.default.createDirectory(at: storeDir, withIntermediateDirectories: true)
        return storeDir.appendingPathComponent("Doris.sqlite")
    }
}
