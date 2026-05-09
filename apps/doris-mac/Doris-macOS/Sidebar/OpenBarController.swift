import AppKit
import SwiftUI
import DorisIPC
import DorisMacChrome

@MainActor
final class OpenBarController {
    private var panel: DorisOpenBarPanel?
    private let edge: SidebarEdge
    private let onTap: () -> Void

    init(edge: SidebarEdge, onTap: @escaping () -> Void) {
        self.edge = edge
        self.onTap = onTap
    }

    func show() {
        if panel == nil { rebuild() }
        panel?.orderFrontRegardless()
    }

    func hide() {
        panel?.orderOut(nil)
    }

    private func rebuild() {
        guard let screen = NSScreen.main else { return }
        let new = PanelMaker.openBar(edge: edge, height: screen.visibleFrame.height)
        let view = OpenBarView(onTap: onTap)
        new.contentViewController = NSHostingController(rootView: view)
        panel = new
    }
}

struct OpenBarView: View {
    let onTap: () -> Void
    @State private var hovered = false

    var body: some View {
        Rectangle()
            .fill(hovered ? Color.accentColor.opacity(0.5) : Color.accentColor.opacity(0.001))
            .frame(width: 6)
            .onHover { hovered = $0 }
            .contentShape(Rectangle())
            .onTapGesture { onTap() }
    }
}
