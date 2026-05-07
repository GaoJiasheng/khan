import AppKit
import KhanIPC

@MainActor
public final class HotSideEngine {
    public typealias Trigger = () -> Void

    private let trigger: Trigger
    private var monitor: Any?
    private var dwellTimer: Timer?
    private var isAtEdge = false
    public var edge: SidebarEdge
    public var dwellMs: Int
    public var enabled: Bool {
        didSet { enabled ? start() : stop() }
    }

    public init(edge: SidebarEdge = .right, dwellMs: Int = 150, enabled: Bool = true, trigger: @escaping Trigger) {
        self.edge = edge
        self.dwellMs = dwellMs
        self.enabled = enabled
        self.trigger = trigger
        if enabled { start() }
    }

    deinit {
        if let monitor {
            NSEvent.removeMonitor(monitor)
        }
        dwellTimer?.invalidate()
    }

    private func start() {
        if monitor != nil { return }
        monitor = NSEvent.addGlobalMonitorForEvents(matching: .mouseMoved) { [weak self] event in
            self?.handleMouse(event: event)
        }
    }

    private func stop() {
        if let monitor {
            NSEvent.removeMonitor(monitor)
            self.monitor = nil
        }
        dwellTimer?.invalidate()
        dwellTimer = nil
        isAtEdge = false
    }

    private func handleMouse(event: NSEvent) {
        let location = NSEvent.mouseLocation
        guard let screen = NSScreen.screens.first(where: { $0.frame.contains(location) }) else { return }
        let frame = screen.frame
        let proximity: CGFloat = 2
        let nearEdge: Bool
        switch edge {
        case .left:  nearEdge = location.x <= frame.minX + proximity
        case .right: nearEdge = location.x >= frame.maxX - proximity
        }
        if nearEdge {
            if !isAtEdge {
                isAtEdge = true
                dwellTimer?.invalidate()
                dwellTimer = Timer.scheduledTimer(withTimeInterval: TimeInterval(dwellMs) / 1000, repeats: false) { [weak self] _ in
                    Task { @MainActor in self?.fire() }
                }
            }
        } else {
            isAtEdge = false
            dwellTimer?.invalidate()
            dwellTimer = nil
        }
    }

    private func fire() {
        // Skip if frontmost app is full-screen game-class (best-effort).
        if let frontmost = NSWorkspace.shared.frontmostApplication,
           let bundleID = frontmost.bundleIdentifier,
           Self.fullScreenSilencedBundleIDs.contains(bundleID) {
            return
        }
        trigger()
    }

    public static let fullScreenSilencedBundleIDs: Set<String> = []
}
