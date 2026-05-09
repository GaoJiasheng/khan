import SwiftUI
import SwiftData
import DorisCore
import DorisIPC
import DorisUI

@main
struct DorisApp: App {
    @NSApplicationDelegateAdaptor(DorisAppDelegate.self) var appDelegate
    /// Single shared container — owned by `DorisRuntime` so the menu-bar
    /// dropdown (constructed in AppDelegate) and the main window scene
    /// (this struct's `WindowGroup`) point at the **same** SwiftData
    /// store. Earlier versions had two independent `ModelContainer`s in
    /// the same process; edits never crossed.
    private let modelContainer: ModelContainer = DorisRuntime.shared.container
    @ObservedObject private var theme = ThemeSettings.shared

    var body: some Scene {
        // Doris is an `LSUIElement` agent — this scene does NOT auto-create
        // its window at launch. The window opens only on demand (avatar's
        // right-click → "Open Main Window", which calls
        // `AppCommands.openMainWindow` → SwiftUI's `openWindow(id:)`,
        // captured into that hook by `MenuBarAvatarContent.onAppear`).
        //
        // Use `Window` (singular) NOT `WindowGroup`: WindowGroup spawns
        // a new window every time `openWindow(id:)` is called, so
        // clicking notes in the dropdown was popping a fresh main window
        // each time. `Window` is a single-instance scene — repeated
        // calls just bring the existing instance forward.
        Window("Doris", id: "main") {
            MainWindowView()
                .modelContainer(modelContainer)
                .background(WindowConfigurator())
                .preferredColorScheme(theme.mode.colorScheme)
        }
        .windowResizability(.contentMinSize)
        .commands {
            DorisCommands()
        }

        Settings {
            SettingsView()
                .modelContainer(modelContainer)
                .preferredColorScheme(theme.mode.colorScheme)
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
