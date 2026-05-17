import SwiftUI
import DorisCore

/// Compact sync-status pill used in the macOS main window's detail header.
/// Shows the *current* sync state at a glance — no need to hover for the
/// tooltip — and acts as the manual "Sync Now" trigger when tapped.
///
/// States (left → right inside the pill):
///   · Idle, cloud OK, recent sync : `↻ 2 min ago` (cyan)
///   · Idle, cloud OK, never synced: `↻ Never synced` (cyan)
///   · Idle, cloud OFF             : `☁︎ Local only` (muted)
///   · Active error                : `⚠ <truncated reason>` (red)
///   · Tap pending                 : spinner + `Syncing…` (cyan)
///
/// Tooltip echoes the full state — exact error message, last-synced
/// timestamp — for users who want details.
public struct SyncNowToolbarButton: View {
    @ObservedObject private var sync = SyncSettings.shared
    @ObservedObject private var lang = LanguageSettings.shared
    @State private var spinning: Bool = false
    @State private var nowTick: Date = Date()
    private let tickTimer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    public init() {}

    public var body: some View {
        Button { tap() } label: {
            HStack(spacing: 5) {
                leadingIcon
                Text(statusLabel)
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(textColor)
                    .lineLimit(1)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Capsule().fill(.primary.opacity(0.05)))
            .overlay(Capsule().stroke(strokeColor, lineWidth: 0.6))
            .help(helpText)
        }
        .buttonStyle(.plain)
        .disabled(spinning)
        .onReceive(tickTimer) { nowTick = $0 }
    }

    // MARK: - Visual state

    @ViewBuilder
    private var leadingIcon: some View {
        if spinning {
            ProgressView()
                .controlSize(.mini)
                .scaleEffect(0.75)
                .tint(accentColor)
        } else {
            Image(systemName: iconName)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(accentColor)
        }
    }

    private var hasError: Bool { sync.lastSyncError != nil }

    private var iconName: String {
        if hasError { return "exclamationmark.icloud.fill" }
        if !sync.cloudKitEnabled { return "icloud.slash" }
        return "arrow.triangle.2.circlepath"
    }

    private var accentColor: Color {
        if hasError { return .red }
        if !sync.cloudKitEnabled { return Color.primary.opacity(0.45) }
        return CyberPalette.neonCyan
    }

    private var strokeColor: Color {
        if hasError { return Color.red.opacity(0.55) }
        if !sync.cloudKitEnabled { return Color.primary.opacity(0.12) }
        return CyberPalette.neonCyan.opacity(0.35)
    }

    private var textColor: Color {
        if hasError { return .red }
        return .primary.opacity(0.65)
    }

    /// Compact status text. Errors get truncated to keep the toolbar
    /// from blowing out at high zoom levels — the full message lives
    /// in the tooltip and in Settings → Sync.
    private var statusLabel: String {
        if spinning {
            return L("Syncing…", "同步中…")
        }
        if let err = sync.lastSyncError {
            return truncate(err, max: 16)
        }
        if !sync.cloudKitEnabled {
            return L("Local only", "仅本地")
        }
        guard let last = sync.lastSyncedAt else {
            return L("Never synced", "尚未同步")
        }
        _ = nowTick  // 1-Hz refresh dependency
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .short
        return f.localizedString(for: last, relativeTo: Date())
    }

    private var helpText: String {
        if let err = sync.lastSyncError {
            return L("Sync error: \(err)\nTap to retry.",
                     "同步错误:\(err)\n点击重试。")
        }
        var label = L("Sync Now", "立即同步")
        if !sync.cloudKitEnabled {
            label += L(" (iCloud off — local save only)",
                       "（未启用 iCloud,仅本地保存）")
        }
        if let last = sync.lastSyncedAt {
            let f = RelativeDateTimeFormatter()
            f.unitsStyle = .short
            label += "\n" + L("Last synced ", "上次同步 ")
                + f.localizedString(for: last, relativeTo: Date())
        }
        return label
    }

    private func truncate(_ s: String, max: Int) -> String {
        s.count <= max ? s : String(s.prefix(max)) + "…"
    }

    // MARK: - Action

    /// Fire the manual sync hook. The actor-backed `SyncTimer.pokeNow()`
    /// runs the local save + CloudKit reachability probe; once it lands
    /// it updates `sync.lastSyncedAt` / `sync.lastSyncError`, and the
    /// `@ObservedObject` here picks that up automatically. The 1.2s
    /// timer is just so the spinner doesn't flicker for instant
    /// completions on cached `accountStatus()` calls.
    private func tap() {
        spinning = true
        AppCommands.syncNow()
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            spinning = false
        }
    }
}
