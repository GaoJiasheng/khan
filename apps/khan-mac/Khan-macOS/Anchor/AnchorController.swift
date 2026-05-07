import AppKit
import SwiftUI
import SwiftData
import KhanCore
import KhanIPC
import KhanMacChrome

@MainActor
final class AnchorController: NotificationPresenter {
    private let model = AnchorModel()
    private var panel: KhanAnchorPanel?
    private var position: AnchorPosition
    private var bannerDismissTask: Task<Void, Never>?
    private let modelContainer: ModelContainer
    private var dragStartOrigin: CGPoint?

    /// Expanded panel size when user clicks the anchor (no notification active).
    static let expandedWidth: CGFloat = 420
    static let expandedHeight: CGFloat = 320

    init(position: AnchorPosition, modelContainer: ModelContainer) {
        self.position = position
        self.modelContainer = modelContainer
    }

    func show() {
        if panel == nil {
            buildPanel()
        }
        panel?.orderFrontRegardless()
        applyFrame(animated: false)
    }

    func hide() {
        panel?.orderOut(nil)
    }

    func setPosition(_ position: AnchorPosition) {
        self.position = position
        applyFrame()
    }

    private var currentScreen: NSScreen {
        AnchorScreenStore.savedScreen()
            ?? panel?.screen
            ?? NSScreen.main
            ?? NSScreen.screens.first!
    }

    private func buildPanel() {
        let model = self.model
        let container = self.modelContainer
        let onIdleTap: () -> Void = { [weak self] in
            self?.toggleExpanded()
        }
        let onTapMessage: (AnchorMessage) -> Void = { [weak self] _ in
            self?.dismissActiveMessage()
            self?.toggleExpanded()
        }
        let onDismissMessage: (AnchorMessage) -> Void = { [weak self] _ in
            self?.dismissActiveMessage()
        }
        let onClose: () -> Void = { [weak self] in
            self?.dismissActiveMessage()
        }
        let onDragChanged: (CGSize) -> Void = { [weak self] t in
            self?.dragChanged(t)
        }
        let onDragEnded: (CGSize) -> Void = { [weak self] t in
            self?.dragEnded(t)
        }
        let pos = position
        panel = AnchorPanelLayout.make(position: position, screen: currentScreen) {
            AnchorView(
                model: model,
                position: pos,
                onTapIdle: onIdleTap,
                onTapMessage: onTapMessage,
                onDismissMessage: onDismissMessage,
                onCloseExpanded: onClose,
                onDragChanged: onDragChanged,
                onDragEnded: onDragEnded
            )
            .modelContainer(container)
        }
    }

    // MARK: - Expand / collapse

    private func toggleExpanded() {
        if case .expanded = model.state {
            model.state = .idle
        } else {
            model.state = .expanded
        }
        applyFrame()
    }

    private func dismissActiveMessage() {
        bannerDismissTask?.cancel()
        bannerDismissTask = nil
        model.state = .idle
        applyFrame()
    }

    // MARK: - Drag

    private func dragChanged(_ translation: CGSize) {
        guard let panel else { return }
        if dragStartOrigin == nil {
            dragStartOrigin = panel.frame.origin
            // Force idle state during drag so we don't try to resize while moving
            if case .idle = model.state {} else {
                model.state = .idle
            }
        }
        guard let start = dragStartOrigin else { return }
        // SwiftUI translation: y grows downward; AppKit panel origin: y grows upward
        let newOrigin = CGPoint(
            x: start.x + translation.width,
            y: start.y - translation.height
        )
        panel.setFrameOrigin(newOrigin)
    }

    private func dragEnded(_ translation: CGSize) {
        dragStartOrigin = nil
        guard let panel else { return }
        // Determine which screen we ended on (by panel center)
        let center = NSPoint(x: panel.frame.midX, y: panel.frame.midY)
        let newScreen = NSScreen.screens.first { $0.frame.contains(center) }
            ?? panel.screen
            ?? NSScreen.main
            ?? NSScreen.screens.first!
        AnchorScreenStore.save(screen: newScreen)
        // Snap to the canonical idle slot on that screen
        applyFrame(animated: true)
    }

    // MARK: - Frame application with smooth animation

    private func applyFrame(animated: Bool = true) {
        guard let panel else { return }
        let screen = currentScreen
        let rect: NSRect
        switch model.state {
        case .idle:
            rect = AnchorPanelLayout.idleFrame(position: position, screen: screen)
        case .banner:
            rect = AnchorPanelLayout.expandedFrame(
                position: position,
                width: AnchorPanelLayout.bannerWidth,
                height: AnchorPanelLayout.bannerHeight,
                screen: screen
            )
        case .fix:
            rect = AnchorPanelLayout.expandedFrame(
                position: position,
                width: AnchorPanelLayout.fixWidth,
                height: AnchorPanelLayout.fixHeight,
                screen: screen
            )
        case .expanded:
            rect = AnchorPanelLayout.expandedFrame(
                position: position,
                width: Self.expandedWidth,
                height: Self.expandedHeight,
                screen: screen
            )
        }

        if animated {
            NSAnimationContext.runAnimationGroup({ ctx in
                ctx.duration = 0.32
                // Match SwiftUI .spring(response: 0.32, dampingFraction: 0.82): an ease-out with a touch of overshoot.
                ctx.timingFunction = CAMediaTimingFunction(controlPoints: 0.16, 0.92, 0.34, 1.04)
                ctx.allowsImplicitAnimation = true
                panel.animator().setFrame(rect, display: true)
            })
        } else {
            panel.setFrame(rect, display: true)
        }
    }

    // MARK: - NotificationPresenter

    nonisolated func presentBanner(_ message: PresentableMessage) {
        let m = AnchorMessage(
            id: message.id,
            title: message.title,
            body: message.body,
            iconName: message.iconName ?? message.source.sfSymbol,
            displayMode: .banner,
            receivedAt: message.receivedAt
        )
        Task { @MainActor [weak self] in
            guard let self else { return }
            self.model.flashNotifyReaction()
            self.model.state = .banner(message: m)
            self.applyFrame()
            self.bannerDismissTask?.cancel()
            self.bannerDismissTask = Task { @MainActor [weak self] in
                try? await Task.sleep(nanoseconds: 4_000_000_000)
                guard !Task.isCancelled else { return }
                if case .banner(let current) = self?.model.state, current.id == m.id {
                    self?.dismissActiveMessage()
                }
            }
        }
    }

    nonisolated func presentFix(_ message: PresentableMessage) {
        let m = AnchorMessage(
            id: message.id,
            title: message.title,
            body: message.body,
            iconName: message.iconName ?? message.source.sfSymbol,
            displayMode: .fix,
            receivedAt: message.receivedAt
        )
        Task { @MainActor [weak self] in
            guard let self else { return }
            self.bannerDismissTask?.cancel()
            self.bannerDismissTask = nil
            self.model.flashNotifyReaction()
            self.model.state = .fix(message: m)
            self.applyFrame()
        }
    }

    nonisolated func dismiss(messageID: UUID) {
        Task { @MainActor [weak self] in
            self?.dismissActiveMessage()
        }
    }
}
