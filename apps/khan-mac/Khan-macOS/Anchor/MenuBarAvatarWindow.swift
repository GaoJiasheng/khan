import AppKit
import SwiftUI
import KhanCore
import KhanIPC
import KhanMacChrome
import KhanUI

/// Borderless NSWindow that hosts the avatar at one of four screen edges.
/// On the TOP edge of a notched display it extends the camera notch to the right.
/// On any other edge / on non-notched displays' top, it draws as a small tab whose
/// flat side hugs the screen edge.
/// Drag to move; on release it snaps to the nearest edge of whichever screen the
/// cursor ended on.
@MainActor
final class MenuBarAvatarWindow {
    private let window: NSWindow
    private let model = MenuBarModel()
    private let onClick: () -> Void
    /// Cursor position relative to the window's bottom-left when drag started, in global
    /// screen coords. Using global cursor + this offset avoids the feedback loop you get
    /// when a SwiftUI DragGesture's view-local translation shifts as the window moves.
    private var dragCursorOffset: CGPoint?

    var screenFrame: NSRect { window.frame }
    var screen: NSScreen? { window.screen ?? bestScreen() }
    var edge: AnchorEdge { model.edge }

    init(onClick: @escaping () -> Void) {
        self.onClick = onClick

        let win = NSWindow(
            contentRect: NSRect(origin: .zero, size: NSSize(width: 40, height: 32)),
            styleMask: [.borderless],
            backing: .buffered,
            defer: true
        )
        win.isReleasedWhenClosed = false
        win.level = .statusBar
        win.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        win.backgroundColor = .clear
        win.isOpaque = false
        win.hasShadow = false
        win.ignoresMouseEvents = false
        win.isMovable = false
        win.hidesOnDeactivate = false
        self.window = win

        let m = self.model
        let host = NSHostingController(rootView: MenuBarAvatarContent(
            model: m,
            onClick: onClick,
            onDragChanged: { [weak self] t in self?.dragChanged(t) },
            onDragEnded:   { [weak self] _ in self?.dragEnded() }
        ))
        win.contentViewController = host

        relayout()
        win.orderFrontRegardless()
    }

    func hide() { window.orderOut(nil) }

    /// Recompute frame + visual style from the saved screen + edge.
    func relayout() {
        guard let s = bestScreen() else { return }
        let edge = AnchorScreenStore.savedEdge()
        model.edge = edge
        let layout = layoutFor(edge: edge, screen: s)
        model.shape = layout.shape
        window.setFrame(layout.frame, display: true)
    }

    // MARK: - Drag

    private func dragChanged(_ translation: CGSize) {
        // Ignore the SwiftUI translation; sample the global cursor instead. The first
        // call records the cursor's offset within the window so subsequent moves are
        // an absolute repositioning rather than a relative one.
        let mouse = NSEvent.mouseLocation
        if dragCursorOffset == nil {
            dragCursorOffset = CGPoint(
                x: mouse.x - window.frame.origin.x,
                y: mouse.y - window.frame.origin.y
            )
        }
        guard let offset = dragCursorOffset else { return }
        let newOrigin = CGPoint(x: mouse.x - offset.x, y: mouse.y - offset.y)
        window.setFrameOrigin(newOrigin)
    }

    private func dragEnded() {
        dragCursorOffset = nil
        let center = NSPoint(x: window.frame.midX, y: window.frame.midY)
        let target = NSScreen.screens.first { $0.frame.contains(center) }
            ?? window.screen
            ?? NSScreen.main
            ?? NSScreen.screens.first!
        let dTop    = abs(target.frame.maxY - center.y)
        let dBottom = abs(center.y - target.frame.minY)
        let dRight  = abs(target.frame.maxX - center.x)
        let dLeft   = abs(center.x - target.frame.minX)
        let nearest: AnchorEdge = [
            (AnchorEdge.top, dTop),
            (.bottom, dBottom),
            (.right, dRight),
            (.left, dLeft)
        ].min(by: { $0.1 < $1.1 })!.0

        AnchorScreenStore.save(screen: target)
        AnchorScreenStore.save(edge: nearest)
        relayoutAnimated()
    }

    private func relayoutAnimated() {
        guard let s = bestScreen() else { return }
        let edge = AnchorScreenStore.savedEdge()
        model.edge = edge
        let layout = layoutFor(edge: edge, screen: s)
        model.shape = layout.shape
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.22
            ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
            ctx.allowsImplicitAnimation = true
            window.animator().setFrame(layout.frame, display: true)
        })
    }

    // MARK: - Edge → frame + shape

    private struct Layout { let frame: NSRect; let shape: MenuBarModel.Shape }

    private func layoutFor(edge: AnchorEdge, screen s: NSScreen) -> Layout {
        let f = s.frame
        switch edge {
        case .top:
            if #available(macOS 12.0, *), let rightArea = s.auxiliaryTopRightArea, s.safeAreaInsets.top > 0 {
                let height = rightArea.height
                let visibleWidth: CGFloat = max(36, height + 4)
                let overshoot: CGFloat = 14
                let width = visibleWidth + overshoot
                let xLeft = rightArea.minX - overshoot
                let yTop = f.maxY
                return Layout(
                    frame: NSRect(x: xLeft, y: yTop - height, width: width, height: height),
                    shape: .notchExtension
                )
            } else {
                let width: CGFloat = 96
                let height: CGFloat = 26
                return Layout(
                    frame: NSRect(x: f.midX - width / 2, y: f.maxY - height, width: width, height: height),
                    shape: .fakeNotch
                )
            }
        case .right:
            // Mirror the top/bottom fake-notch proportions (96 along edge × 26 perpendicular)
            // but elongated VERTICALLY so the tab feels as substantial as the horizontal ones.
            let perpendicular: CGFloat = 44
            let alongEdge: CGFloat = 96
            let overshoot: CGFloat = 10
            return Layout(
                frame: NSRect(
                    x: f.maxX - perpendicular + overshoot,
                    y: f.midY - alongEdge / 2,
                    width: perpendicular,
                    height: alongEdge
                ),
                shape: .edgeRight
            )
        case .left:
            let perpendicular: CGFloat = 44
            let alongEdge: CGFloat = 96
            let overshoot: CGFloat = 10
            return Layout(
                frame: NSRect(
                    x: f.minX - overshoot,
                    y: f.midY - alongEdge / 2,
                    width: perpendicular,
                    height: alongEdge
                ),
                shape: .edgeLeft
            )
        case .bottom:
            let height: CGFloat = 26
            let width: CGFloat = 96
            return Layout(
                frame: NSRect(x: f.midX - width / 2, y: f.minY, width: width, height: height),
                shape: .edgeBottom
            )
        }
    }

    private func bestScreen() -> NSScreen? {
        if let saved = AnchorScreenStore.savedScreen() { return saved }
        if let primary = NSScreen.screens.first(where: { $0.frame.origin == .zero }) {
            return primary
        }
        return NSScreen.main ?? NSScreen.screens.first
    }
}

// MARK: - SwiftUI

@MainActor
final class MenuBarModel: ObservableObject {
    enum Shape { case notchExtension, fakeNotch, edgeRight, edgeLeft, edgeBottom }
    @Published var shape: Shape = .notchExtension
    @Published var edge: AnchorEdge = .top
}

private struct MenuBarAvatarContent: View {
    @ObservedObject var model: MenuBarModel
    @ObservedObject var settings = AppearanceSettings.shared
    @ObservedObject private var lang = LanguageSettings.shared
    let onClick: () -> Void
    let onDragChanged: (CGSize) -> Void
    let onDragEnded: (CGSize) -> Void
    @State private var hovered = false

    var body: some View {
        Button(action: onClick) {
            ZStack {
                background
                AvatarPortrait()
                    .clipShape(Circle())
                    .frame(width: 26, height: 26)
                    .modifier(AvatarOffsetModifier(shape: model.shape))
            }
            .scaleEffect(hovered ? 1.04 : 1.0)
            .animation(.easeInOut(duration: 0.12), value: hovered)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovered = $0 }
        .help(L(
            "Khan — drag to a different screen edge · right-click for settings",
            "Khan — 拖动可切换屏幕边缘 · 右键打开设置"
        ))
        .contextMenu {
            Button(L("Open Main Window", "打开主窗口")) {
                AppCommands.openMainWindow()
            }
            Divider()
            Button(L("Sync Now", "立即同步")) {
                AppCommands.syncNow()
            }
            Button(L("Settings…", "设置…")) {
                SettingsWindowController.shared.show()
            }
            Divider()
            Button(L("Quit Khan", "退出 Khan")) {
                NSApp.terminate(nil)
            }
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 6)
                .onChanged { v in onDragChanged(v.translation) }
                .onEnded   { v in onDragEnded(v.translation) }
        )
    }

    /// Notch-extension always solid black (so it fuses with the real notch).
    /// Every other shape honors the user-set background opacity.
    private var backgroundOpacity: Double {
        model.shape == .notchExtension ? 1.0 : settings.backgroundOpacity
    }

    @ViewBuilder
    private var background: some View {
        let fill = Color.black.opacity(backgroundOpacity)
        switch model.shape {
        case .notchExtension: NotchExtensionShape(cornerRadius: 10).fill(fill)
        case .fakeNotch:      FakeNotchSymmetric(cornerRadius: 10).fill(fill)
        case .edgeRight:      EdgeAttachShape(corner: .right, cornerRadius: 10).fill(fill)
        case .edgeLeft:       EdgeAttachShape(corner: .left, cornerRadius: 10).fill(fill)
        case .edgeBottom:     EdgeAttachShape(corner: .bottom, cornerRadius: 10).fill(fill)
        }
    }
}

private struct AvatarOffsetModifier: ViewModifier {
    let shape: MenuBarModel.Shape
    func body(content: Content) -> some View {
        switch shape {
        case .notchExtension: content.padding(.leading, 14)
        case .fakeNotch:      content.padding(.bottom, 2)
        case .edgeRight:      content.padding(.trailing, 10) // shift toward the visible (left) part
        case .edgeLeft:       content.padding(.leading, 10)
        case .edgeBottom:     content.padding(.top, 2)
        }
    }
}

struct NotchExtensionShape: Shape {
    var cornerRadius: CGFloat = 10
    func path(in rect: CGRect) -> Path {
        let r = min(cornerRadius, min(rect.width, rect.height) / 2)
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - r))
        p.addQuadCurve(to: CGPoint(x: rect.maxX - r, y: rect.maxY), control: CGPoint(x: rect.maxX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}

struct FakeNotchSymmetric: Shape {
    var cornerRadius: CGFloat = 10
    func path(in rect: CGRect) -> Path {
        let r = min(cornerRadius, min(rect.width, rect.height) / 2)
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - r))
        p.addQuadCurve(to: CGPoint(x: rect.maxX - r, y: rect.maxY), control: CGPoint(x: rect.maxX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX + r, y: rect.maxY))
        p.addQuadCurve(to: CGPoint(x: rect.minX, y: rect.maxY - r), control: CGPoint(x: rect.minX, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}

struct EdgeAttachShape: Shape {
    enum Corner { case right, left, bottom }
    var corner: Corner
    var cornerRadius: CGFloat = 10

    func path(in rect: CGRect) -> Path {
        let r = min(cornerRadius, min(rect.width, rect.height) / 2)
        var p = Path()
        switch corner {
        case .right:
            // Tab attached to the RIGHT edge of the screen: flat right, rounded left corners.
            p.move(to: CGPoint(x: rect.maxX, y: rect.minY))
            p.addLine(to: CGPoint(x: rect.minX + r, y: rect.minY))
            p.addQuadCurve(to: CGPoint(x: rect.minX, y: rect.minY + r), control: CGPoint(x: rect.minX, y: rect.minY))
            p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - r))
            p.addQuadCurve(to: CGPoint(x: rect.minX + r, y: rect.maxY), control: CGPoint(x: rect.minX, y: rect.maxY))
            p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            p.closeSubpath()
        case .left:
            // Flat left, rounded right corners.
            p.move(to: CGPoint(x: rect.minX, y: rect.minY))
            p.addLine(to: CGPoint(x: rect.maxX - r, y: rect.minY))
            p.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.minY + r), control: CGPoint(x: rect.maxX, y: rect.minY))
            p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - r))
            p.addQuadCurve(to: CGPoint(x: rect.maxX - r, y: rect.maxY), control: CGPoint(x: rect.maxX, y: rect.maxY))
            p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
            p.closeSubpath()
        case .bottom:
            // Flat bottom, rounded top corners.
            p.move(to: CGPoint(x: rect.minX, y: rect.maxY))
            p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + r))
            p.addQuadCurve(to: CGPoint(x: rect.maxX - r, y: rect.minY), control: CGPoint(x: rect.maxX, y: rect.minY))
            p.addLine(to: CGPoint(x: rect.minX + r, y: rect.minY))
            p.addQuadCurve(to: CGPoint(x: rect.minX, y: rect.minY + r), control: CGPoint(x: rect.minX, y: rect.minY))
            p.closeSubpath()
        }
        return p
    }
}

private struct AvatarPortrait: View {
    static let bundled: NSImage? = {
        let candidates = ["khan-avatar", "khan-avatar-idle"]
        for name in candidates {
            if let url = Bundle.main.url(forResource: name, withExtension: "png", subdirectory: "Avatar"),
               let img = NSImage(contentsOf: url) { return img }
            if let url = Bundle.main.url(forResource: name, withExtension: "png"),
               let img = NSImage(contentsOf: url) { return img }
        }
        return nil
    }()

    var body: some View {
        if let img = Self.bundled {
            Image(nsImage: img)
                .resizable()
                .interpolation(.high)
                .scaledToFill()
        } else {
            Text("K")
                .font(.system(size: 12, weight: .heavy, design: .rounded))
                .foregroundStyle(.cyan)
        }
    }
}
