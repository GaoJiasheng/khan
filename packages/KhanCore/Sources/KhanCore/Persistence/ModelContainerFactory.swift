import Foundation
import KhanIPC
import SwiftData

public enum ModelContainerFactory {
    public enum FactoryError: Error {
        case appGroupUnavailable
    }

    public static func make(useCloudKit: Bool = true, inMemory: Bool = false) throws -> ModelContainer {
        let url = try storeURL(inMemory: inMemory)
        let schema = SchemaV1.schema

        let config: ModelConfiguration
        if inMemory {
            config = ModelConfiguration(
                "Khan-InMemory",
                schema: schema,
                isStoredInMemoryOnly: true
            )
        } else if useCloudKit {
            config = ModelConfiguration(
                "Khan",
                schema: schema,
                url: url,
                cloudKitDatabase: .private(KhanIdentifiers.cloudKitContainer)
            )
        } else {
            config = ModelConfiguration(
                "Khan",
                schema: schema,
                url: url,
                cloudKitDatabase: .none
            )
        }

        return try ModelContainer(for: schema, configurations: [config])
    }

    public static func storeURL(inMemory: Bool) throws -> URL {
        if inMemory {
            return URL(fileURLWithPath: "/dev/null")
        }
        // Single source of truth: IPCDirectory.containerURL() honors KHAN_IPC_ROOT
        // for dev builds and falls back through the App Group container otherwise.
        let group = try IPCDirectory.containerURL()
        let storeDir = group.appendingPathComponent("Store", isDirectory: true)
        try FileManager.default.createDirectory(at: storeDir, withIntermediateDirectories: true)
        return storeDir.appendingPathComponent("Khan.sqlite")
    }
}
