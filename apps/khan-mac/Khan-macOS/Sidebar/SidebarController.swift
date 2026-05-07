import AppKit
import SwiftUI
import SwiftData
import KhanCore
import KhanIPC
import KhanMacChrome

@MainActor
final class SidebarController {
    private let modelContainer: ModelContainer
    private let settings: UserSettings
    private var panel: KhanSidebarPanel?
    private var isVisible = false

    init(modelContainer: ModelContainer, settings: UserSettings) {
        self.modelContainer = modelContainer
        self.settings = settings
    }

    func show() {
        if panel == nil { rebuild() }
        guard let panel else { return }
        panel.orderFrontRegardless()
        isVisible = true
    }

    func hide() {
        panel?.orderOut(nil)
        isVisible = false
    }

    func toggle() {
        if isVisible { hide() } else { show() }
    }

    private func rebuild() {
        let container = modelContainer
        let edge = settings.sidebarEdge
        let width = CGFloat(settings.sidebarWidth)
        let fixed = settings.pinnedAcrossSpaces

        panel = PanelMaker.sidebar(
            edge: edge,
            width: width,
            fixed: fixed
        ) {
            SidebarRootView()
                .modelContainer(container)
        }
    }
}
