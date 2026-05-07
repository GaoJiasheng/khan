import SwiftUI
import SwiftData
import KhanCore
import KhanIPC

@main
struct KhanApp: App {
    @NSApplicationDelegateAdaptor(KhanAppDelegate.self) var appDelegate
    @State private var modelContainer: ModelContainer? = makeContainer()

    var body: some Scene {
        WindowGroup("Khan", id: "main") {
            if let modelContainer {
                MainWindowView()
                    .modelContainer(modelContainer)
            } else {
                Text("Khan failed to initialize its data store. Check that iCloud is signed in and the App Group is configured.")
                    .padding()
            }
        }
        .windowResizability(.contentMinSize)
        .commands {
            KhanCommands()
        }

        Settings {
            if let modelContainer {
                SettingsView()
                    .modelContainer(modelContainer)
            }
        }
    }
}

private func makeContainer() -> ModelContainer? {
    // On macOS 26+, ModelConfiguration with cloudKitDatabase: .none still triggers
    // NSCloudKitMirroringDelegate setup, which crashes on unsigned binaries that
    // don't have iCloud entitlements. Default to in-memory so the dev build runs.
    // Production builds opt into CloudKit-backed persistence with KHAN_USE_CLOUDKIT=1.
    let optInCloudKit = ProcessInfo.processInfo.environment["KHAN_USE_CLOUDKIT"] == "1"
    if optInCloudKit {
        if let c = try? ModelContainerFactory.make(useCloudKit: true) { return c }
    }
    return try? ModelContainerFactory.make(inMemory: true)
}
