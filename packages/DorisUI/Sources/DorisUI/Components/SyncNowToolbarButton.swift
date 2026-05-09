import SwiftUI
import DorisCore

/// Cyber-themed "Sync Now" toolbar button — taps to fire `AppCommands.syncNow`
/// (which the AppDelegate has wired to `SyncTimer.pokeNow()`), shows a
/// spinning ProgressView while the work is in flight, and otherwise
/// renders a small badge with the relative "last synced" timestamp on
/// hover. Reused by both macOS and iOS.
///
/// Why the spinner is time-boxed: the manual sync hook is a fire-and-forget
/// closure (no completion callback), so we show the spinner for ~600ms
/// regardless. The actual `lastSyncedAt` value updates inside the same
/// turn of the runloop, so the user sees both the spinner and the fresh
/// timestamp animate together — feels responsive enough.
public struct SyncNowToolbarButton: View {
    @ObservedObject private var sync = SyncSettings.shared
    @State private var spinning: Bool = false
    @State private var rotation: Double = 0

    public init() {}

    public var body: some View {
        Button {
            tap()
        } label: {
            ZStack {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.system(size: 13, weight: .semibold))
                    .rotationEffect(.degrees(spinning ? rotation : 0))
                    .foregroundStyle(
                        sync.cloudKitEnabled
                            ? AnyShapeStyle(CyberPalette.neonCyan)
                            : AnyShapeStyle(Color.primary.opacity(0.55))
                    )
            }
            .frame(width: 22, height: 22)
            .help(helpText)
        }
        .buttonStyle(.plain)
        .disabled(spinning)
        .animation(.linear(duration: 0.6).repeatCount(spinning ? 2 : 0, autoreverses: false), value: rotation)
    }

    private var helpText: String {
        var label = "Sync Now"
        if !sync.cloudKitEnabled {
            label += " (iCloud disabled — local flush only)"
        }
        if let last = sync.lastSyncedAt {
            let f = RelativeDateTimeFormatter()
            f.unitsStyle = .short
            label += "\nLast synced " + f.localizedString(for: last, relativeTo: Date())
        }
        return label
    }

    private func tap() {
        spinning = true
        rotation = 360
        AppCommands.syncNow()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            spinning = false
            rotation = 0
        }
    }
}
