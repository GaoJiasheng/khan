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
                        .background(WindowConfigurator())
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
/// Also reaches into the hosting `NSWindow` to make the green title-bar
/// button enter native full-screen instead of regular zoom.
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

/// Bridges into AppKit to mark the host window as full-screen primary so
/// the green title-bar button switches from "zoom" (+) to "enter full
/// screen" (diagonal arrows). Setting `.fullScreenPrimary` is enough —
/// the system handles toggling into and out of full-screen itself.
///
/// Retries a few times because `view.window` is nil during the first few
/// runloop ticks (NSView gets attached to its window after the first
/// layout pass), and SwiftUI sometimes asks `makeNSView` before that
/// pass completes.
private struct WindowConfigurator: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = TrackingView()
        view.onMoveToWindow = { configure($0) }
        DispatchQueue.main.async { configure(view.window) }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async { configure(nsView.window) }
    }

    private func configure(_ window: NSWindow?) {
        guard let window else { return }
        window.collectionBehavior.remove(.fullScreenNone)
        window.collectionBehavior.remove(.fullScreenAuxiliary)
        window.collectionBehavior.insert(.fullScreenPrimary)
    }
}

/// NSView that fires a callback whenever it gets attached to a window.
/// Lets the configurator catch the window even when SwiftUI's first
/// `makeNSView` pass runs before the view is in the hierarchy.
private final class TrackingView: NSView {
    var onMoveToWindow: ((NSWindow?) -> Void)?
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        onMoveToWindow?(window)
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
