import AppKit
import SwiftUI
import KhanIPC

public final class KhanAnchorPanel: NSPanel {
    public override var canBecomeKey: Bool { false }
    public override var canBecomeMain: Bool { false }
}

public enum AnchorPanelLayout {
    public static let circleIdleSize: CGFloat = 28
    public static let pillIdleWidth: CGFloat = 96
    public static let pillIdleHeight: CGFloat = 26

    public static let bannerWidth: CGFloat = 320
    public static let bannerHeight: CGFloat = 72
    public static let fixWidth: CGFloat = 360
    public static let fixHeight: CGFloat = 96

    public static func rendersAsFakeNotch(position: AnchorPosition, screen: NSScreen? = nil) -> Bool {
        let s = screen ?? NSScreen.main ?? NSScreen.screens.first!
        switch position {
        case .notchAdjacent:
            return !s.hasNotch
        case .topCenter:
            return true
        default:
            return false
        }
    }

    public static func make<Content: View>(
        position: AnchorPosition,
        screen: NSScreen,
        @ViewBuilder content: () -> Content
    ) -> KhanAnchorPanel {
        let frame = idleFrame(position: position, screen: screen)
        let panel = KhanAnchorPanel(
            contentRect: frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: true
        )
        panel.isReleasedWhenClosed = false
        panel.level = .screenSaver
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary]
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.isFloatingPanel = false
        panel.becomesKeyOnlyIfNeeded = true
        panel.hidesOnDeactivate = false
        panel.ignoresMouseEvents = false
        panel.isMovable = true
        panel.contentViewController = NSHostingController(rootView: AnyView(content()))
        return panel
    }

    /// Drop-down surface anchored to a status-item button. Doesn't try to draw inside
    /// the menu-bar exclusion zone — the status item handles the in-bar avatar.
    public static func makeFloating<Content: View>(
        initialSize: NSSize,
        @ViewBuilder content: () -> Content
    ) -> KhanAnchorPanel {
        let panel = KhanAnchorPanel(
            contentRect: NSRect(origin: .zero, size: initialSize),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: true
        )
        panel.isReleasedWhenClosed = false
        panel.level = .popUpMenu
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.isFloatingPanel = true
        panel.becomesKeyOnlyIfNeeded = true
        panel.hidesOnDeactivate = false
        panel.contentViewController = NSHostingController(rootView: AnyView(content()))
        return panel
    }

    public static func idleFrame(position: AnchorPosition, screen: NSScreen? = nil) -> NSRect {
        let s = screen ?? NSScreen.main ?? NSScreen.screens.first!
        let v = s.visibleFrame
        let f = s.frame
        let pad: CGFloat = 6

        switch position {
        case .notchAdjacent:
            if s.hasNotch {
                // Real notch: place the avatar circle just right of the notch, vertically
                // anchored so its TOP aligns with the screen edge (= top of menu bar).
                // Centering inside safeAreaInsets.top makes the visible logo hang below
                // the status icons because the inset is taller than the icons themselves.
                let size = circleIdleSize
                let yInBar = f.maxY - size + 2 // 2pt overshoot keeps it visually pinned to top
                let xRightOfNotch: CGFloat
                if #available(macOS 12.0, *), let rightArea = s.auxiliaryTopRightArea {
                    xRightOfNotch = rightArea.minX + 6
                } else {
                    xRightOfNotch = f.midX + 100 + 6
                }
                return NSRect(
                    x: xRightOfNotch,
                    y: yInBar,
                    width: size,
                    height: size
                )
            } else {
                return NSRect(
                    x: f.midX - pillIdleWidth / 2,
                    y: f.maxY - pillIdleHeight,
                    width: pillIdleWidth,
                    height: pillIdleHeight
                )
            }

        case .topCenter:
            return NSRect(
                x: f.midX - pillIdleWidth / 2,
                y: f.maxY - pillIdleHeight,
                width: pillIdleWidth,
                height: pillIdleHeight
            )

        case .rightCenter:
            let size = circleIdleSize
            return NSRect(x: v.maxX - size - pad, y: v.midY - size / 2, width: size, height: size)
        case .rightTop:
            let size = circleIdleSize
            return NSRect(x: v.maxX - size - pad, y: v.maxY - size - pad, width: size, height: size)
        case .rightBottom:
            let size = circleIdleSize
            return NSRect(x: v.maxX - size - pad, y: v.minY + pad, width: size, height: size)
        case .leftCenter:
            let size = circleIdleSize
            return NSRect(x: v.minX + pad, y: v.midY - size / 2, width: size, height: size)
        case .notchRight:
            let size = circleIdleSize
            return NSRect(x: f.midX + 100, y: f.maxY - size - 2, width: size, height: size)
        case .notchLeft:
            let size = circleIdleSize
            return NSRect(x: f.midX - 100 - size, y: f.maxY - size - 2, width: size, height: size)
        }
    }

    public static func expandedFrame(
        position: AnchorPosition,
        width: CGFloat,
        height: CGFloat,
        screen: NSScreen? = nil
    ) -> NSRect {
        let s = screen ?? NSScreen.main ?? NSScreen.screens.first!
        let v = s.visibleFrame
        let f = s.frame
        let pad: CGFloat = 6

        switch position {
        case .notchAdjacent:
            if s.hasNotch {
                // Drop down anchored to the avatar's idle x (just right of the notch).
                let xRightOfNotch: CGFloat
                if #available(macOS 12.0, *), let rightArea = s.auxiliaryTopRightArea {
                    xRightOfNotch = rightArea.minX + 6
                } else {
                    xRightOfNotch = f.midX + 100 + 6
                }
                // Clamp so the panel doesn't run off the right edge.
                let maxX = f.maxX - width - 6
                let xClamped = min(xRightOfNotch, maxX)
                return NSRect(
                    x: xClamped,
                    y: f.maxY - height,
                    width: width,
                    height: height
                )
            } else {
                return NSRect(x: f.midX - width / 2, y: f.maxY - height, width: width, height: height)
            }
        case .topCenter:
            return NSRect(x: f.midX - width / 2, y: f.maxY - height, width: width, height: height)
        case .notchRight, .notchLeft:
            return NSRect(x: f.midX - width / 2, y: f.maxY - height, width: width, height: height)
        case .rightCenter:
            return NSRect(x: v.maxX - width - pad, y: v.midY - height / 2, width: width, height: height)
        case .rightTop:
            return NSRect(x: v.maxX - width - pad, y: v.maxY - height - pad, width: width, height: height)
        case .rightBottom:
            return NSRect(x: v.maxX - width - pad, y: v.minY + pad, width: width, height: height)
        case .leftCenter:
            return NSRect(x: v.minX + pad, y: v.midY - height / 2, width: width, height: height)
        }
    }
}

// MARK: - Screen persistence

public enum AnchorScreenStore {
    private static let screenKey = "khan.anchorScreenDisplayID"
    private static let edgeKey = "khan.anchorEdge"

    public static func savedScreen() -> NSScreen? {
        let raw = UserDefaults.standard.integer(forKey: screenKey)
        guard raw != 0 else { return nil }
        let target = CGDirectDisplayID(raw)
        return NSScreen.screens.first { screen in
            (screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID) == target
        }
    }

    public static func save(screen: NSScreen) {
        guard let id = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID else { return }
        UserDefaults.standard.set(Int(id), forKey: screenKey)
    }

    public static func savedEdge() -> AnchorEdge {
        let raw = UserDefaults.standard.string(forKey: edgeKey) ?? AnchorEdge.top.rawValue
        return AnchorEdge(rawValue: raw) ?? .top
    }

    public static func save(edge: AnchorEdge) {
        UserDefaults.standard.set(edge.rawValue, forKey: edgeKey)
    }
}
