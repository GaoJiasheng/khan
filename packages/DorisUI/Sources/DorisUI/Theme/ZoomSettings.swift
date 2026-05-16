import Foundation
import Combine
import SwiftUI

/// Global UI zoom level. Browser-style — `scale = 1.0` means "normal,"
/// `> 1.0` enlarges everything (text, icons, paddings) proportionally
/// the way Cmd-+ does in Safari, `< 1.0` shrinks. Applied as a
/// `scaleEffect` (with a compensating logical frame) at the root of
/// each scaled scene so layout is computed at the logical size and
/// then rendered at the visual size.
///
/// Single global value across the whole app: main window + dropdown
/// panel share one zoom so the two surfaces stay visually consistent.
/// Persisted to `UserDefaults` so restarts preserve the setting.
@MainActor
public final class ZoomSettings: ObservableObject {
    public static let shared = ZoomSettings()

    /// Discrete steps the UI snaps to. Picked to match browser
    /// conventions roughly (70%, 80%, 90%, 100%, 110%, 125%, 150%).
    /// Cmd-+ / Cmd-− move one step in either direction.
    public static let steps: [Double] = [0.70, 0.80, 0.90, 1.00, 1.10, 1.25, 1.50]
    public static let defaultScale: Double = 1.00

    @Published public var scale: Double {
        didSet {
            // Clamp to the steps. If something tries to set an
            // off-grid value (e.g. UserDefaults from a future version
            // with different steps), snap to the nearest step.
            let snapped = Self.snap(scale)
            if snapped != scale {
                scale = snapped
                return
            }
            UserDefaults.standard.set(scale, forKey: Self.key)
        }
    }

    private static let key = "doris.ui.zoom"

    private init() {
        let raw = UserDefaults.standard.double(forKey: Self.key)
        self.scale = raw > 0 ? Self.snap(raw) : Self.defaultScale
    }

    /// Bump to the next step up, no-op at the top.
    public func zoomIn() {
        if let idx = Self.steps.firstIndex(of: scale), idx + 1 < Self.steps.count {
            scale = Self.steps[idx + 1]
        }
    }

    /// Bump to the next step down, no-op at the bottom.
    public func zoomOut() {
        if let idx = Self.steps.firstIndex(of: scale), idx > 0 {
            scale = Self.steps[idx - 1]
        }
    }

    /// Cmd-0 — snap back to 100%.
    public func reset() {
        scale = Self.defaultScale
    }

    /// Snap an arbitrary value to the nearest discrete step. Used
    /// when reading the persisted value back from `UserDefaults` and
    /// whenever someone assigns `scale` directly.
    private static func snap(_ value: Double) -> Double {
        var best = steps.first ?? defaultScale
        var bestDelta = abs(value - best)
        for s in steps.dropFirst() {
            let delta = abs(value - s)
            if delta < bestDelta {
                best = s
                bestDelta = delta
            }
        }
        return best
    }
}

// MARK: - View modifier

public extension View {
    /// Apply Doris's global zoom level to this view. Renders the
    /// content at its logical size inside a `GeometryReader`-driven
    /// frame, then scales the rendered output by the active zoom.
    /// The outer frame is sized to the scaled output so the parent
    /// reserves the right amount of space.
    ///
    /// Effective behaviour:
    ///   - Container grows when zoom > 1, shrinks when zoom < 1
    ///   - Inner content lays out at `containerSize / zoom`, then is
    ///     rendered at `containerSize` — i.e. fonts / icons / spacings
    ///     all visually scale together
    ///
    /// Use this on the root of any scene that should participate in
    /// the global zoom (e.g. `MainWindowView`, `AnchorView`).
    @MainActor
    func dorisZoom() -> some View {
        modifier(DorisZoomModifier())
    }
}

@MainActor
private struct DorisZoomModifier: ViewModifier {
    @ObservedObject private var zoom = ZoomSettings.shared

    /// At zoom 1.0 (the default), bypass GeometryReader + scaleEffect
    /// entirely. Both are no-ops *visually* at scale 1.0 — but the
    /// GeometryReader still creates a new coordinate space and
    /// changes how hit-test events propagate to child buttons,
    /// causing controls inside the zoomed view to feel "sticky" or
    /// require multiple clicks. Only wrap in the scaling chrome
    /// when the user has actually zoomed off 100%.
    @ViewBuilder
    func body(content: Content) -> some View {
        if zoom.scale == 1.0 {
            content
        } else {
            GeometryReader { proxy in
                let s = zoom.scale
                content
                    .frame(
                        width: max(1, proxy.size.width / s),
                        height: max(1, proxy.size.height / s)
                    )
                    .scaleEffect(s, anchor: .topLeading)
            }
        }
    }
}
