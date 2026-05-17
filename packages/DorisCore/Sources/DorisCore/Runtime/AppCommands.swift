import Foundation

/// Global hooks the avatar's right-click menu, toolbar buttons, App
/// Intents, and AppleScript handlers can call. AppDelegate (Mac & iOS)
/// wires these at launch — e.g. `syncNow` → `DorisRuntime.shared.syncNow()`,
/// `openMainWindow` → SwiftUI's `openWindow(id: "main")`. UI calls them
/// blind and is decoupled from the actual hook owner.
///
/// `openMainWindow` is a no-op on iOS (no separate window) but kept in
/// the cross-platform surface so the same UI code paths compile on
/// both platforms.
@MainActor
public enum AppCommands {
    public static var syncNow: () -> Void = {}
    public static var openMainWindow: () -> Void = {}
    /// Open the app's settings UI. On Mac this brings up the standalone
    /// `SettingsWindowController` panel (the same one the menu-bar
    /// avatar's right-click → "Settings…" opens). No-op on iOS where
    /// Settings is reached via the tab bar.
    public static var openSettings: () -> Void = {}
}
