import AppKit
import Combine
import SwiftUI
import SwiftData
import DorisCore
import DorisUI

/// Manually-managed main window. Replaces the SwiftUI `Window("Doris",
/// id: "main")` scene because that scene was auto-instantiating its
/// window on app launch / activation despite our four
/// `applicationShouldOpenUntitledFile` / `NSQuitAlwaysKeepsWindows` /
/// `applicationShouldHandleReopen` / `applicationSupportsSecureRestorableState`
/// suppressors. SwiftUI's `Window` scene type maintains its own
/// activation reflexes that those overrides don't fully reach.
///
/// With this controller:
///   - Nothing happens at launch — the window object isn't even created.
///   - First call to `show()` lazily builds the `NSWindow` +
///     `NSHostingController(MainWindowView)` and orders it front.
///   - Subsequent calls to `show()` reuse the same instance (single-window
///     semantics, like the previous `Window` scene gave us).
///   - Closing the window doesn't quit the app — the controller keeps
///     the (hidden) window around so the next `show()` is instant and
///     state-preserving.
@MainActor
final class MainWindowController: NSObject, NSWindowDelegate {
    static let shared = MainWindowController()

    private var window: NSWindow?
    /// Last zoom level we sized the window for. When `ZoomSettings.scale`
    /// changes we resize by the *ratio* (new / last) so the user's
    /// manual resize choices are preserved — we're scaling, not snapping
    /// back to a fixed baseline.
    ///
    /// Starts at `1.0` (not the persisted zoom) because the window is
    /// created with the baseline 900×600 `contentRect`. On first show,
    /// if the user had a saved zoom of e.g. 1.25, we need ratio
    /// `1.25 / 1.0 = 1.25` to grow the window to 1125×750. If we
    /// initialised `lastAppliedZoom` to the saved 1.25 instead, the
    /// ratio would be 1.0 and the window would stay at the baseline
    /// — with the persisted zoom applied to layout that's a
    /// "shrunk content" look that the user reads as proportionally
    /// off.
    private var lastAppliedZoom: Double = 1.0
    private var zoomObserver: AnyCancellable?
    /// `NSEvent` local monitor for Cmd-+ / Cmd-− / Cmd-0. Lives at
    /// the AppKit level (not as SwiftUI `keyboardShortcut` modifiers
    /// hung in the view tree) because the SwiftUI approach forced
    /// hidden Button elements into the responder chain and broke
    /// hit-testing for every visible Button at the top of the
    /// NavigationSplitView's detail header.
    private var zoomKeyMonitor: Any?

    private override init() { super.init() }

    /// Open the main window if it doesn't exist yet, or bring it to
    /// front if it does. Always activates the app so the window comes
    /// into focus (needed because Doris is `LSUIElement: true` — it's
    /// not normally activatable by clicking the menu-bar avatar).
    ///
    /// `preferredScreen` is the display the user just interacted with
    /// (typically the screen where the menu-bar dropdown was open).
    /// On first show we center the window on that screen; on
    /// re-show, we move the existing window over if it isn't already
    /// on the right display, so users with multi-monitor setups don't
    /// get the main window left behind on whatever screen it was last
    /// closed on.
    func show(preferredScreen: NSScreen? = nil) {
        NSApp.activate(ignoringOtherApps: true)
        if let window {
            if window.isMiniaturized { window.deminiaturize(nil) }
            if let screen = preferredScreen, window.screen != screen {
                centerWindow(window, on: screen)
            }
            window.makeKeyAndOrderFront(nil)
            scheduleGreetOnNextRunloop()
            // Catch any zoom changes that happened while the window
            // was closed — the observer is set up after first show
            // so before that we'd have missed them.
            applyZoom(ZoomSettings.shared.scale, toWindow: window, animated: false)
            observeZoom()
            installZoomKeyMonitor()
            return
        }

        let container = DorisRuntime.shared.container
        // `MainWindowView` observes `ThemeSettings` itself and applies
        // `.preferredColorScheme` reactively — don't apply it here too
        // (a static modifier at construction time wins, freezing the
        // window to whatever theme was active when first opened).
        let root = MainWindowView()
            .modelContainer(container)
        let host = NSHostingController(rootView: root)

        let win = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 900, height: 600),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: true
        )
        win.title = "Doris"
        // Hide the title text and make the title bar transparent so the
        // content view extends edge-to-edge under it. Combined with
        // `.fullSizeContentView`, this lets the DORIS / tabs / sync /
        // theme nav strip sit at the very top of the window with only
        // the traffic lights floating over the dark sidebar.
        win.titleVisibility = .hidden
        win.titlebarAppearsTransparent = true
        win.contentViewController = host
        win.identifier = NSUserInterfaceItemIdentifier("doris-main")
        // Match the previous SwiftUI Window's full-screen behavior — the
        // green title-bar button enters full-screen instead of zoom.
        win.collectionBehavior.remove(.fullScreenNone)
        win.collectionBehavior.remove(.fullScreenAuxiliary)
        win.collectionBehavior.insert(.fullScreenPrimary)
        win.isReleasedWhenClosed = false
        win.delegate = self
        if let screen = preferredScreen {
            centerWindow(win, on: screen)
        } else {
            win.center()
        }

        self.window = win
        win.makeKeyAndOrderFront(nil)
        scheduleGreetOnNextRunloop()
        // Apply current zoom to the freshly-built window once, then
        // observe ZoomSettings for subsequent Cmd-+/Cmd-− events.
        applyZoom(ZoomSettings.shared.scale, toWindow: win, animated: false)
        observeZoom()
        installZoomKeyMonitor()
    }

    /// Listen for Cmd-+ / Cmd-− / Cmd-0 at the AppKit event level and
    /// route them to `ZoomSettings`. Local monitors fire while *any*
    /// of our app's windows are key; we explicitly gate on
    /// `self.window?.isKeyWindow` so a focused dropdown panel doesn't
    /// accidentally consume the shortcut (the dropdown follows zoom
    /// passively — it shouldn't issue zoom commands itself).
    ///
    /// Matched by physical `keyCode` rather than `charactersIgnoringModifiers`
    /// because the latter goes through the active keyboard layout +
    /// input source — under a Chinese IME or a remapping utility
    /// (Karabiner, Hammerspoon) it can return a substituted or
    /// reversed character, which is what produced the "Cmd-= shrinks,
    /// Cmd-− grows" complaint. Physical keyCodes ignore those layers.
    ///
    /// Returning `nil` swallows the event; returning it passes it on.
    private func installZoomKeyMonitor() {
        guard zoomKeyMonitor == nil else { return }
        zoomKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self,
                  let window = self.window,
                  window.isKeyWindow,
                  event.modifierFlags.contains(.command)
            else { return event }
            // US ANSI Mac keyCodes for the affected keys:
            //   24 = `=` / `+` (top row, right of `0`)
            //   27 = `-` / `_` (top row)
            //   29 = `0` (top row)
            //   69 = numeric keypad `+`
            //   78 = numeric keypad `-`
            //   82 = numeric keypad `0`
            switch event.keyCode {
            case 24, 69:
                ZoomSettings.shared.zoomIn()
                return nil
            case 27, 78:
                ZoomSettings.shared.zoomOut()
                return nil
            case 29, 82:
                ZoomSettings.shared.reset()
                return nil
            default:
                return event
            }
        }
    }

    /// Resize the main window to reflect a zoom value. Uses the
    /// *ratio* between the new zoom and the last-applied zoom so the
    /// user's manual resize choices are preserved — if they dragged
    /// the window to 1100×700 at zoom 1.0 and then bump zoom to 1.25,
    /// the window becomes 1375×875 (not snapped to a fixed baseline
    /// × 1.25). Re-centers around the window's current center.
    ///
    /// The zoom value MUST be passed in explicitly: reading from
    /// `ZoomSettings.shared.scale` inside an `@Published` sink callback
    /// returns the *old* value (`@Published` emits during `willSet`,
    /// before the wrappedValue is updated). That's what produced the
    /// reversed-direction bug — the first Cmd-+ press read scale=1.0
    /// while it was already on its way to 1.10, mis-computed a 1.0
    /// ratio, etc. Always take the value from the publisher.
    private func applyZoom(_ newZoom: Double, toWindow win: NSWindow, animated: Bool = false) {
        let ratio = newZoom / lastAppliedZoom
        guard abs(ratio - 1.0) > 0.001 else {
            lastAppliedZoom = newZoom
            return
        }
        let oldFrame = win.frame
        let newWidth = oldFrame.width * ratio
        let newHeight = oldFrame.height * ratio
        let centerX = oldFrame.midX
        let centerY = oldFrame.midY
        let newFrame = NSRect(
            x: centerX - newWidth / 2,
            y: centerY - newHeight / 2,
            width: newWidth,
            height: newHeight
        )
        win.setFrame(newFrame, display: true, animate: animated)
        lastAppliedZoom = newZoom
    }

    /// Subscribe to `ZoomSettings.shared.$scale`. Idempotent — multiple
    /// `show()` calls reuse the same subscription. The published value
    /// is forwarded into `applyZoom` directly so we don't accidentally
    /// read the stale `wrappedValue` mid-willSet.
    private func observeZoom() {
        guard zoomObserver == nil else { return }
        zoomObserver = ZoomSettings.shared.$scale
            .dropFirst() // skip current value; we applied it inline
            .sink { [weak self] newScale in
                guard let self, let window = self.window else { return }
                self.applyZoom(newScale, toWindow: window, animated: true)
            }
    }

    /// Fire a hero greeting one tick after the window is shown.
    ///
    /// The two-step delay matters: we have to wait for AppKit to finish
    /// `makeKeyAndOrderFront` AND for SwiftUI to mount the hosting view
    /// tree (so `AvatarHero`'s `.onChange(of: heroEvents.lastGreeting)`
    /// observer is attached) before bumping the bus. If we bumped it
    /// synchronously, the change would happen before the observer was
    /// in place and the greeting would be silently missed.
    ///
    /// 200 ms is the same hand-tuned delay the dropdown panel uses for
    /// the same reason; both surfaces share the singleton `HeroEvents`
    /// bus + the same `AvatarHero` listener pattern.
    private func scheduleGreetOnNextRunloop() {
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 200_000_000)
            HeroEvents.shared.greet()
        }
    }

    private func centerWindow(_ win: NSWindow, on screen: NSScreen) {
        let visible = screen.visibleFrame
        let size = win.frame.size
        let origin = NSPoint(
            x: visible.midX - size.width / 2,
            y: visible.midY - size.height / 2
        )
        win.setFrameOrigin(origin)
    }

    // MARK: - NSWindowDelegate

    /// Closing the window just hides it — keep the instance around for
    /// fast re-open. Returning `false` would block the close; we want
    /// the window to actually disappear, so return `true` and let
    /// AppKit hide it (with `isReleasedWhenClosed = false` the NSWindow
    /// object survives the close and can be ordered-front again).
    func windowShouldClose(_ sender: NSWindow) -> Bool { true }
}
