import SwiftUI
import SwiftData
import KhanCore
import KhanIPC
import KhanUI

@main
struct KhanApp: App {
    @NSApplicationDelegateAdaptor(KhanAppDelegate.self) var appDelegate
    @State private var modelContainer: ModelContainer? = makeContainer()
    @ObservedObject private var theme = ThemeSettings.shared

    var body: some Scene {
        WindowGroup("Khan", id: "main") {
            Group {
                if let modelContainer {
                    MainWindowView()
                        .modelContainer(modelContainer)
                        .background(WindowOpenerCapture())
                } else {
                    Text("Khan failed to initialize its data store. Check that iCloud is signed in and the App Group is configured.")
                        .padding()
                }
            }
            .preferredColorScheme(theme.mode.colorScheme)
        }
        .windowResizability(.contentMinSize)
        .commands {
            KhanCommands()
        }

        Settings {
            if let modelContainer {
                SettingsView()
                    .modelContainer(modelContainer)
                    .preferredColorScheme(theme.mode.colorScheme)
            }
        }
    }
}

/// Hidden view that captures `@Environment(\.openWindow)` and writes a
/// closure into `AppCommands.openMainWindow` so the avatar's right-click
/// menu (which lives in AppKit-land, no SwiftUI environment) can call it.
private struct WindowOpenerCapture: View {
    @Environment(\.openWindow) private var openWindow
    var body: some View {
        Color.clear
            .frame(width: 0, height: 0)
            .onAppear {
                AppCommands.openMainWindow = {
                    openWindow(id: "main")
                    NSApp.activate(ignoringOtherApps: true)
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
