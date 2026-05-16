import KeyboardShortcuts
import AppKit

extension KeyboardShortcuts.Name {
    public static let toggleSidebar = Self("toggleSidebar", default: .init(.k, modifiers: [.command, .option]))
    public static let toggleNotch = Self("toggleNotch")
    public static let openEvents = Self("openEvents")
}

@MainActor
public enum GlobalShortcuts {
    public static func bind(toggleSidebar: @escaping () -> Void) {
        KeyboardShortcuts.onKeyDown(for: .toggleSidebar) { toggleSidebar() }
    }

    public static func bind(toggleNotch: @escaping () -> Void) {
        KeyboardShortcuts.onKeyDown(for: .toggleNotch) { toggleNotch() }
    }

    public static func bind(openEvents: @escaping () -> Void) {
        KeyboardShortcuts.onKeyDown(for: .openEvents) { openEvents() }
    }
}
