import AppKit

public extension NSScreen {
    /// True when the screen has a built-in camera notch (MacBook Pro / Air 2021+).
    var hasNotch: Bool {
        safeAreaInsets.top > 0
    }

    /// Approximate frame of the physical notch in screen coordinates, or nil if none.
    /// We can't query the exact shape, but the notch is centered horizontally and
    /// occupies the safeAreaInsets.top region.
    var notchFrame: NSRect? {
        guard hasNotch else { return nil }
        let inset = safeAreaInsets.top
        // Real notch widths are typically 200pt on 14"/16" MacBooks. We treat it as 200pt
        // and centre it on the screen — that's what AppKit's safe-area system uses.
        let width: CGFloat = 200
        let f = frame
        return NSRect(
            x: f.midX - width / 2,
            y: f.maxY - inset,
            width: width,
            height: inset
        )
    }
}
