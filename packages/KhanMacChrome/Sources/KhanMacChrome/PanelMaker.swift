import AppKit
import SwiftUI
import KhanIPC

@MainActor
public enum PanelMaker {
    /// Create the SideNotes-style sidebar panel. Hosts an arbitrary SwiftUI view.
    public static func sidebar<Content: View>(
        edge: SidebarEdge,
        width: CGFloat,
        fixed: Bool,
        @ViewBuilder content: () -> Content
    ) -> KhanSidebarPanel {
        let panel = KhanSidebarPanel(
            contentRect: defaultRect(edge: edge, width: width),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: true
        )
        panel.isReleasedWhenClosed = false
        panel.becomesKeyOnlyIfNeeded = true
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = !fixed
        panel.hasShadow = true
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.level = fixed ? .statusBar - 1 : .floating
        panel.collectionBehavior = fixed
            ? [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
            : [.moveToActiveSpace, .fullScreenAuxiliary]

        let host = NSHostingController(rootView: AnyView(content()))
        panel.contentViewController = host
        panel.title = "Khan Sidebar"
        return panel
    }

    /// Create the always-visible Open Bar trigger.
    public static func openBar(edge: SidebarEdge, height: CGFloat) -> KhanOpenBarPanel {
        let panel = KhanOpenBarPanel(
            contentRect: openBarRect(edge: edge, height: height),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: true
        )
        panel.isReleasedWhenClosed = false
        panel.level = .statusBar - 2
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.backgroundColor = NSColor.windowBackgroundColor.withAlphaComponent(0.001)
        panel.isOpaque = false
        return panel
    }

    private static func defaultRect(edge: SidebarEdge, width: CGFloat) -> NSRect {
        guard let screen = NSScreen.main else {
            return NSRect(x: 0, y: 0, width: width, height: 600)
        }
        let visible = screen.visibleFrame
        let h = visible.height
        let x: CGFloat = edge == .left ? visible.minX : visible.maxX - width
        let y = visible.minY
        return NSRect(x: x, y: y, width: width, height: h)
    }

    private static func openBarRect(edge: SidebarEdge, height: CGFloat) -> NSRect {
        guard let screen = NSScreen.main else {
            return NSRect(x: 0, y: 0, width: 6, height: height)
        }
        let visible = screen.visibleFrame
        let x: CGFloat = edge == .left ? visible.minX : visible.maxX - 6
        return NSRect(x: x, y: visible.minY, width: 6, height: visible.height)
    }
}

public final class KhanSidebarPanel: NSPanel {
    public override var canBecomeKey: Bool { true }
    public override var canBecomeMain: Bool { false }
}

public final class KhanOpenBarPanel: NSPanel {
    public override var canBecomeKey: Bool { false }
    public override var canBecomeMain: Bool { false }
}
