import SwiftUI
import AppKit
import DynamicNotchKit
import DorisIPC

/// Wraps DynamicNotchKit so the rest of the app can swap implementations later.
@MainActor
public final class DynamicNotchAdapter {
    private var info: DynamicNotchInfo?
    private var fixedNotch: DynamicNotch<AnyView, EmptyView, EmptyView>?

    public init() {}

    /// Briefly display an info-style notch banner that auto-dismisses.
    public func showBanner(title: String, body: String?, sfSymbol: String?, autoHideAfter: TimeInterval = 4) {
        Task { @MainActor in
            await dismissAll()
            let icon: DynamicNotchInfo.Label? = sfSymbol.map { .init(systemName: $0, color: nil) }
            let info = DynamicNotchInfo(
                icon: icon,
                title: LocalizedStringKey(title),
                description: body.map(LocalizedStringKey.init(_:))
            )
            self.info = info
            await info.expand()
            try? await Task.sleep(nanoseconds: UInt64(autoHideAfter * 1_000_000_000))
            if self.info === info {
                await info.hide()
                self.info = nil
            }
        }
    }

    /// Show a persistent expanded notch with custom content. Stays until `hide()` is called.
    public func showFix<Content: View>(@ViewBuilder content: @escaping () -> Content) {
        let view = AnyView(content())
        Task { @MainActor in
            await dismissAll()
            let notch = DynamicNotch<AnyView, EmptyView, EmptyView>(
                hoverBehavior: .all,
                style: .auto,
                expanded: { view },
                compactLeading: { EmptyView() },
                compactTrailing: { EmptyView() }
            )
            self.fixedNotch = notch
            await notch.expand()
        }
    }

    public func hide() {
        Task { @MainActor in
            await dismissAll()
        }
    }

    private func dismissAll() async {
        if let info {
            await info.hide()
            self.info = nil
        }
        if let fixedNotch {
            await fixedNotch.hide()
            self.fixedNotch = nil
        }
    }
}
