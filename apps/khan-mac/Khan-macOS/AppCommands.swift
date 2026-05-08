import Foundation

/// Global hooks the menu-bar avatar's right-click menu can call. AppDelegate
/// wires these up at launch (e.g. `syncNow` -> `syncTimer.pokeNow()`); the
/// avatar UI calls them blind. Keeps the SwiftUI layer free of stored
/// references to AppDelegate-owned actors.
@MainActor
enum AppCommands {
    static var syncNow: () -> Void = {}
    static var openMainWindow: () -> Void = {}
}
