import KeyboardShortcuts
import AppKit

extension KeyboardShortcuts.Name {
    public static let toggleSidebar = Self("toggleSidebar", default: .init(.k, modifiers: [.command, .option]))
    public static let toggleNotch = Self("toggleNotch")
    public static let openInbox = Self("openInbox")
}

@MainActor
public enum GlobalShortcuts {
    public static func bind(toggleSidebar: @escaping () -> Void) {
        KeyboardShortcuts.onKeyDown(for: .toggleSidebar) { toggleSidebar() }
    }

    public static func bind(toggleNotch: @escaping () -> Void) {
        KeyboardShortcuts.onKeyDown(for: .toggleNotch) { toggleNotch() }
    }

    public static func bind(openInbox: @escaping () -> Void) {
        KeyboardShortcuts.onKeyDown(for: .openInbox) { openInbox() }
    }
}
