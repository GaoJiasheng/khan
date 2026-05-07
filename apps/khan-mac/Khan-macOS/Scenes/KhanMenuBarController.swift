import AppKit

@MainActor
final class KhanMenuBarController: NSObject {
    private let item: NSStatusItem
    private let onOpenInbox: () -> Void
    private let onSyncNow: () -> Void
    private let onQuit: () -> Void

    init(onOpenInbox: @escaping () -> Void, onSyncNow: @escaping () -> Void, onQuit: @escaping () -> Void) {
        self.onOpenInbox = onOpenInbox
        self.onSyncNow = onSyncNow
        self.onQuit = onQuit
        self.item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()
        configure()
    }

    private func configure() {
        if let button = item.button {
            button.image = NSImage(systemSymbolName: "bell.badge", accessibilityDescription: "Khan")
        }
        let menu = NSMenu()
        menu.addItem(.init(title: "Open Inbox", action: #selector(openInboxAction), keyEquivalent: "i"))
        menu.addItem(.init(title: "Sync Now", action: #selector(syncAction), keyEquivalent: "r"))
        menu.addItem(.separator())
        menu.addItem(.init(title: "Quit Khan", action: #selector(quitAction), keyEquivalent: "q"))
        for menuItem in menu.items { menuItem.target = self }
        item.menu = menu
    }

    @objc private func openInboxAction() { onOpenInbox() }
    @objc private func syncAction() { onSyncNow() }
    @objc private func quitAction() { onQuit() }
}
