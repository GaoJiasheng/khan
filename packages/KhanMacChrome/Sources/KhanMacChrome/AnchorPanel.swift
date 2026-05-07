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
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: true
        )
        panel.isReleasedWhenClosed = false
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.isFloatingPanel = true
        panel.becomesKeyOnlyIfNeeded = true
        panel.hidesOnDeactivate = false
        panel.ignoresMouseEvents = false
        panel.isMovable = true
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
            if let notch = s.notchFrame {
                let size = circleIdleSize
                let menuBarTop = f.maxY
                let menuBarHeight = notch.height
                return NSRect(
                    x: notch.maxX + 4,
                    y: menuBarTop - menuBarHeight + (menuBarHeight - size) / 2,
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
            if let notch = s.notchFrame {
                return NSRect(x: notch.maxX - 4, y: f.maxY - height, width: width, height: height)
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
    private static let key = "khan.anchorScreenDisplayID"

    public static func savedScreen() -> NSScreen? {
        let raw = UserDefaults.standard.integer(forKey: key)
        guard raw != 0 else { return nil }
        let target = CGDirectDisplayID(raw)
        return NSScreen.screens.first { screen in
            (screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID) == target
        }
    }

    public static func save(screen: NSScreen) {
        guard let id = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID else { return }
        UserDefaults.standard.set(Int(id), forKey: key)
    }
}
