import AppKit
import SwiftUI
import SwiftData
import DorisCore
import DorisIPC
import DorisMacChrome
import DorisUI

@MainActor
final class AnchorController: NotificationPresenter {
    private let model = AnchorModel()
    private var panel: DorisAnchorPanel?
    private var avatarWindow: MenuBarAvatarWindow?
    private var screenObserver: NSObjectProtocol?
    private var bannerDismissTask: Task<Void, Never>?
    private let modelContainer: ModelContainer

    /// Expanded panel size when user clicks the anchor (no notification active).
    /// Wider than v0.1 to give the cyber-girl scene a proper hero column on the left.
    static let expandedWidth: CGFloat = 560
    static let expandedHeight: CGFloat = 380

    init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
    }

    func show() {
        if avatarWindow == nil {
            avatarWindow = MenuBarAvatarWindow { [weak self] in
                self?.toggleExpanded()
            }
        }
        if screenObserver == nil {
            screenObserver = NotificationCenter.default.addObserver(
                forName: NSApplication.didChangeScreenParametersNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                self?.avatarWindow?.relayout()
            }
        }
        if panel == nil {
            buildPanel()
        }
    }

    func hide() {
        panel?.orderOut(nil)
    }

    /// Public entry for the launch path — open the dropdown panel at app
    /// start so the user immediately sees their inbox / notes / today
    /// instead of staring at an empty menu bar. Idempotent: a second call
    /// while already expanded does nothing (vs. `toggleExpanded` which
    /// would collapse it).
    func expand() {
        guard model.state != .expanded else { return }
        model.state = .expanded
        showPanel()
        HeroEvents.shared.greet()
    }

    // Auto-collapse used to fire 8 seconds after expand to keep idle CPU
    // down. With inline note editing in the dropdown that became
    // user-hostile — the panel would disappear out from under whatever
    // they were typing. We've since moved to "panel stays open until the
    // user clicks the avatar (or 'X') to close", and rely on the full
    // panel teardown on close (`tearDownPanelContent`) to flush all
    // SwiftUI animators when they're done.

    private func buildPanel() {
        let model = self.model
        let container = self.modelContainer
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
        // Drag is no longer used (the status item lives where macOS puts it). We pass
        // no-op handlers to satisfy AnchorView's API.
        let noopDrag: (CGSize) -> Void = { _ in }
        let rootView = AnyView(
            AnchorView(
                model: model,
                position: .notchAdjacent,
                screenHasNotch: true,
                onTapIdle: { /* status item handles this */ },
                onTapMessage: onTapMessage,
                onDismissMessage: onDismissMessage,
                onCloseExpanded: onClose,
                onDragChanged: noopDrag,
                onDragEnded: noopDrag
            )
            .modelContainer(container)
        )

        if let existing = panel {
            // Reuse the existing NSPanel chrome and just remount the
            // SwiftUI host. We tear `contentViewController` down on hide
            // (so animations stop) and put a fresh one back here on next
            // show.
            existing.contentViewController = NSHostingController(rootView: rootView)
        } else {
            panel = AnchorPanelLayout.makeFloating(initialSize: NSSize(width: 1, height: 1)) {
                rootView
            }
        }
    }

    // MARK: - Expand / collapse

    private func toggleExpanded() {
        if case .expanded = model.state {
            model.state = .idle
            hidePanel()
        } else {
            model.state = .expanded
            showPanel()
            HeroEvents.shared.greet()
        }
    }

    private func dismissActiveMessage() {
        bannerDismissTask?.cancel()
        bannerDismissTask = nil
        model.state = .idle
        hidePanel()
    }

    private func showPanel() {
        // (Re)build the SwiftUI host so the AvatarHero / AnchorView tree
        // is freshly mounted. We tear it down on hide to stop animations,
        // so on show we have to put it back.
        if panel == nil || panel?.contentViewController == nil {
            buildPanel()
        }
        guard let panel else { return }
        let target = computeRect()
        let start = collapsedRect()

        // 1. Snap to a tiny frame at the logo's bottom center, transparent.
        panel.setFrame(start, display: false)
        panel.alphaValue = 0
        panel.orderFrontRegardless()

        // 2. Snap to fully open with a quick ease-out — feels like the logo bursts open.
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.18
            ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
            ctx.allowsImplicitAnimation = true
            panel.animator().setFrame(target, display: true)
            panel.animator().alphaValue = 1
        }
    }

    private func hidePanel() {
        guard let panel, panel.isVisible else {
            panel?.orderOut(nil)
            tearDownPanelContent()
            return
        }
        let end = collapsedRect()
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.14
            ctx.timingFunction = CAMediaTimingFunction(name: .easeIn)
            ctx.allowsImplicitAnimation = true
            panel.animator().setFrame(end, display: true)
            panel.animator().alphaValue = 0
        }, completionHandler: { [weak self, weak panel] in
            panel?.orderOut(nil)
            // Critical for CPU: drop the SwiftUI host once the close
            // animation finishes. NSPanel.orderOut on its own only hides
            // the window — the SwiftUI view tree (AvatarHero with its
            // TimelineView, particle Canvas, animated player) keeps
            // running in the background and burning CPU at the display
            // refresh rate. Setting `contentViewController = nil`
            // releases the hosting controller and SwiftUI tears down
            // every animator inside it. Next `showPanel()` rebuilds.
            self?.tearDownPanelContent()
        })
    }

    private func tearDownPanelContent() {
        // Setting `contentViewController = nil` alone doesn't fully tear
        // down SwiftUI's hosting tree — the GraphHost / animator state
        // can outlive the controller, keeping CPU spinning even after
        // the window is `orderOut`'d. Releasing the entire NSPanel is
        // the only reliable way to flush every animator. `buildPanel()`
        // recreates a fresh one on the next `showPanel()` call.
        panel?.close()
        panel?.contentViewController = nil
        panel = nil
    }

    /// A 2-point rect at the bottom-center of the avatar — the panel scales out from
    /// here on show, and back into here on hide.
    private func collapsedRect() -> NSRect {
        if let avatar = avatarWindow {
            let f = avatar.screenFrame
            return NSRect(x: f.midX - 1, y: f.minY - 1, width: 2, height: 2)
        }
        // Avoid `NSScreen.screens.first!` — the force-unwrap embeds the
        // source file path into the runtime trap message, leaking the
        // build-tree path into the .dylib's `__cstring` section. The
        // `guard let` form has the same behavior in practice (we only
        // reach this branch when there's no avatar window, which itself
        // requires a screen) but doesn't bake any path metadata.
        guard let s = NSScreen.screens.first(where: { $0.frame.origin == .zero })
                    ?? NSScreen.main
                    ?? NSScreen.screens.first else {
            return .zero
        }
        return NSRect(x: s.frame.maxX - 16, y: s.frame.maxY - 16, width: 2, height: 2)
    }

    // MARK: - Frame placement

    private func applyFrame(animated: Bool) {
        guard let panel = panel else { return }
        let rect = computeRect()
        if animated {
            NSAnimationContext.runAnimationGroup({ ctx in
                ctx.duration = 0.28
                ctx.timingFunction = CAMediaTimingFunction(controlPoints: 0.16, 0.92, 0.34, 1.04)
                ctx.allowsImplicitAnimation = true
                panel.animator().setFrame(rect, display: true)
            })
        } else {
            panel.setFrame(rect, display: true)
        }
    }

    /// Compute the panel rect anchored to the avatar window. The panel grows AWAY from
    /// the screen edge: down for top, up for bottom, left for right edge, right for left.
    private func computeRect() -> NSRect {
        let (width, height): (CGFloat, CGFloat)
        switch model.state {
        case .idle:
            return .zero
        case .banner:
            width = AnchorPanelLayout.bannerWidth
            height = AnchorPanelLayout.bannerHeight
        case .fix:
            width = AnchorPanelLayout.fixWidth
            height = AnchorPanelLayout.fixHeight
        case .expanded:
            width = Self.expandedWidth
            height = Self.expandedHeight
        }

        if let avatar = avatarWindow, let screen = avatar.screen {
            let aFrame = avatar.screenFrame
            let s = screen.frame
            let gap: CGFloat = 6

            // The panel anchors to the screen edge the avatar lives on, but it CENTERS
            // along the perpendicular axis on the screen (not on the avatar). This way
            // the panel always feels balanced relative to the display, even when the
            // logo is tucked in a corner or beside the notch.
            switch avatar.edge {
            case .top:
                // Drop down from the screen's top edge, horizontally centered on screen.
                let x = s.midX - width / 2
                let y = aFrame.minY - gap - height
                return NSRect(x: x, y: y, width: width, height: height)
            case .bottom:
                // Grow upward from the screen's bottom edge, horizontally centered.
                let x = s.midX - width / 2
                let y = aFrame.maxY + gap
                return NSRect(x: x, y: y, width: width, height: height)
            case .right:
                // Grow leftward from the right edge, vertically centered.
                let x = aFrame.minX - gap - width
                let y = s.midY - height / 2
                return NSRect(x: x, y: y, width: width, height: height)
            case .left:
                // Grow rightward from the left edge, vertically centered.
                let x = aFrame.maxX + gap
                let y = s.midY - height / 2
                return NSRect(x: x, y: y, width: width, height: height)
            }
        }

        // Fallback: top-right of the primary screen. (See `collapsedRect`
        // for why we don't `force-unwrap NSScreen.screens.first` here —
        // the trap message would leak the source path.)
        guard let s = NSScreen.screens.first(where: { $0.frame.origin == .zero })
                    ?? NSScreen.main
                    ?? NSScreen.screens.first else {
            return .zero
        }
        let pad: CGFloat = 6
        return NSRect(
            x: s.frame.maxX - width - pad,
            y: s.frame.maxY - height - 32,
            width: width,
            height: height
        )
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
            HeroEvents.shared.alert()
            self.model.state = .banner(message: m)
            self.showPanel()
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
            HeroEvents.shared.alert()
            self.model.state = .fix(message: m)
            self.showPanel()
        }
    }

    nonisolated func dismiss(messageID: UUID) {
        Task { @MainActor [weak self] in
            self?.dismissActiveMessage()
        }
    }
}
