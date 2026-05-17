import SwiftUI
import SwiftData
import AppKit
import DorisCore
import DorisIPC
import DorisUI
import KeyboardShortcuts

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @ObservedObject private var theme = ThemeSettings.shared
    @Query private var settingsQuery: [UserSettings]

    private var settings: UserSettings {
        if let existing = settingsQuery.first { return existing }
        let new = UserSettings()
        modelContext.insert(new)
        return new
    }

    var body: some View {
        ZStack {
            CyberPalette.backdrop
                .ignoresSafeArea()
            TabView {
                generalTab
                    .tabItem { Label("General", systemImage: "gear") }
                syncTab
                    .tabItem { Label("Sync", systemImage: "icloud.fill") }
                recentlyDeletedTab
                    .tabItem { Label("Recently Deleted", systemImage: "trash") }
                sidebarTab
                    .tabItem { Label("Sidebar", systemImage: "sidebar.right") }
                shortcutTab
                    .tabItem { Label("Shortcuts", systemImage: "keyboard") }
                cliTab
                    .tabItem { Label("CLI", systemImage: "terminal") }
            }
            .scrollContentBackground(.hidden)
            .padding()
        }
        .frame(width: 480, height: 460)
        .preferredColorScheme(theme.mode.colorScheme)
        .background(SettingsWindowOpacityFix())
    }

    private var generalTab: some View {
        Form {
            Picker("Theme", selection: themeBinding) {
                ForEach(DorisTheme.allCases, id: \.self) { Text($0.rawValue.capitalized).tag($0) }
            }
            Toggle("Show hex color preview", isOn: showHexColorPreview)
            Toggle("Auto-backup daily", isOn: autoBackupEnabled)
        }
        .scrollContentBackground(.hidden)
    }

    /// Sync tab — controls iCloud-backed CloudKit mirroring + manual
    /// sync. The CloudKit toggle is sticky (next launch) and shows a
    /// "restart required" hint because SwiftData binds the configuration
    /// at container init time.
    private var syncTab: some View {
        SyncSettingsTab()
    }

    /// Recently Deleted tab — shows archived notes so the user can
    /// restore or permanently delete them.
    private var recentlyDeletedTab: some View {
        MacRecentlyDeletedTab()
    }

    private var sidebarTab: some View {
        Form {
            Picker("Edge", selection: sidebarEdge) {
                Text("Left").tag(SidebarEdge.left)
                Text("Right").tag(SidebarEdge.right)
            }
            HStack {
                Text("Width")
                Slider(value: sidebarWidth, in: 240...520, step: 10)
                Text("\(Int(settings.sidebarWidth)) px")
            }
            Toggle("Hot Side enabled", isOn: hotSideEnabled)
            Toggle("Open Bar visible", isOn: openBarVisible)
            Toggle("Pinned across spaces", isOn: pinnedAcrossSpaces)
            Picker("Notch behavior", selection: notchBehavior) {
                ForEach(NotchBehavior.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }
        }
        .scrollContentBackground(.hidden)
    }

    private var shortcutTab: some View {
        Form {
            KeyboardShortcuts.Recorder("Toggle sidebar", name: .toggleSidebar)
            KeyboardShortcuts.Recorder("Toggle notch", name: .toggleNotch)
            KeyboardShortcuts.Recorder("Open events", name: .openEvents)
        }
        .scrollContentBackground(.hidden)
    }

    private var cliTab: some View {
        Form {
            HStack {
                Text("CLI installed at")
                Spacer()
                Text(settings.cliInstalledAt ?? "(not installed)")
                    .foregroundStyle(.secondary)
            }
            Text("Allowed source app IDs")
                .font(.headline)
            Text(settings.cliSourceAllowlist.joined(separator: ", "))
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
        }
        .scrollContentBackground(.hidden)
    }

    // Bindings backing onto the persisted UserSettings row.
    // Renamed from `theme` to `themeBinding` so it doesn't collide with the
    // top-level `@ObservedObject private var theme = ThemeSettings.shared`
    // we observe to react to live theme switches.
    private var themeBinding: Binding<DorisTheme> {
        Binding(get: { settings.theme }, set: { settings.theme = $0 })
    }
    private var sidebarEdge: Binding<SidebarEdge> {
        Binding(get: { settings.sidebarEdge }, set: { settings.sidebarEdge = $0 })
    }
    private var notchBehavior: Binding<NotchBehavior> {
        Binding(get: { settings.notchBehavior }, set: { settings.notchBehavior = $0 })
    }
    private var sidebarWidth: Binding<Double> {
        Binding(get: { settings.sidebarWidth }, set: { settings.sidebarWidth = $0 })
    }
    private var hotSideEnabled: Binding<Bool> {
        Binding(get: { settings.hotSideEnabled }, set: { settings.hotSideEnabled = $0 })
    }
    private var openBarVisible: Binding<Bool> {
        Binding(get: { settings.openBarVisible }, set: { settings.openBarVisible = $0 })
    }
    private var pinnedAcrossSpaces: Binding<Bool> {
        Binding(get: { settings.pinnedAcrossSpaces }, set: { settings.pinnedAcrossSpaces = $0 })
    }
    private var showHexColorPreview: Binding<Bool> {
        Binding(get: { settings.showHexColorPreview }, set: { settings.showHexColorPreview = $0 })
    }
    private var autoBackupEnabled: Binding<Bool> {
        Binding(get: { settings.autoBackupEnabled }, set: { settings.autoBackupEnabled = $0 })
    }
}

/// macOS Sync settings tab — the user-facing surface for CloudKit + auto
/// sync controls. Lives in its own struct so `SyncSettings.shared` can be
/// observed without ballooning the parent's body.
private struct SyncSettingsTab: View {
    @ObservedObject private var sync = SyncSettings.shared
    @ObservedObject private var lang = LanguageSettings.shared
    @State private var isSyncing: Bool = false
    @State private var lastTickTimer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    @State private var nowTick: Date = Date()

    var body: some View {
        Form {
            // ── Status banner — always visible, mirrors the iOS sync pill ──
            Section {
                statusBanner
                    .listRowInsets(EdgeInsets())
            }

            Section {
                Toggle(L("Use iCloud sync", "使用 iCloud 同步"),
                       isOn: $sync.cloudKitEnabled)
                    .help(L("Mirrors notes and events through your iCloud account so other devices stay in sync.",
                            "通过 iCloud 镜像笔记和事件,让其他设备保持同步。"))
                if sync.cloudKitEnabled {
                    Text(L("Restart Doris after toggling iCloud for the change to take effect.",
                           "切换 iCloud 后需重启 Doris 才会生效。"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text(L("Local only. Notes stay on this Mac.",
                           "仅本地存储,笔记不会离开本机。"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("iCloud")
            }

            Section {
                Toggle(L("Auto-sync every 60 seconds", "每 60 秒自动同步"),
                       isOn: $sync.autoSyncEnabled)
                    .help(L("When on, Doris periodically flushes pending writes so iCloud has the latest state. Turn off if you only want manual sync.",
                            "开启后,Doris 会定期刷写改动到 iCloud。关闭则只在手动同步时触发。"))
            } header: {
                Text(L("Auto-sync", "自动同步"))
            }

            Section {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Button {
                            runManualSync()
                        } label: {
                            HStack(spacing: 6) {
                                if isSyncing {
                                    ProgressView().controlSize(.small)
                                } else {
                                    Image(systemName: "arrow.triangle.2.circlepath")
                                }
                                Text(isSyncing
                                     ? L("Syncing…", "同步中…")
                                     : L("Sync Now", "立即同步"))
                            }
                        }
                        .disabled(isSyncing)
                        Spacer()
                        Text(lastSyncedLabel)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                }
            } header: {
                Text(L("Manual sync", "手动同步"))
            } footer: {
                Text(L("Sync Now performs a local save plus a CloudKit reachability check (account status + user record fetch). Last-synced only updates when both succeed.",
                       "立即同步会先本地保存,然后真实验证 iCloud 可达性(账号状态 + 拉取用户 record)。两步都成功才会刷新「上次同步」时间。"))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .scrollContentBackground(.hidden)
        .onReceive(lastTickTimer) { nowTick = $0 }
    }

    // MARK: - Status banner

    /// Always-visible state strip at the top of the Sync tab. Reads from
    /// the same `SyncSettings.shared` the toolbar pill uses, so the two
    /// surfaces always agree on whether iCloud is green / red / local.
    private var statusBanner: some View {
        let hasError = sync.lastSyncError != nil
        let accent: Color =
            hasError ? .red :
            !sync.cloudKitEnabled ? Color.primary.opacity(0.45) :
            CyberPalette.neonCyan

        return HStack(spacing: 10) {
            Image(systemName: bannerIcon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(accent)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(bannerTitle)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(hasError ? .red : .primary)
                Text(bannerSubtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(accent.opacity(0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(accent.opacity(hasError ? 0.45 : 0.18), lineWidth: 0.7)
        )
        .padding(.vertical, 4)
    }

    private var bannerIcon: String {
        if sync.lastSyncError != nil { return "exclamationmark.icloud.fill" }
        if !sync.cloudKitEnabled     { return "icloud.slash" }
        if sync.lastSyncedAt == nil  { return "icloud" }
        return "checkmark.icloud.fill"
    }

    private var bannerTitle: String {
        if sync.lastSyncError != nil {
            return L("Sync error", "同步失败")
        }
        if !sync.cloudKitEnabled {
            return L("iCloud sync disabled", "未启用 iCloud 同步")
        }
        if sync.lastSyncedAt == nil {
            return L("Not synced yet", "尚未同步")
        }
        return L("In sync with iCloud", "已与 iCloud 同步")
    }

    private var bannerSubtitle: String {
        if let err = sync.lastSyncError {
            return err
        }
        if !sync.cloudKitEnabled {
            return L("Notes stay on this Mac. Toggle iCloud on below to mirror to other devices.",
                     "笔记仅保存在本机。下方开启 iCloud 即可与其他设备同步。")
        }
        if sync.lastSyncedAt == nil {
            return L("Tap Sync Now below to start a sync.",
                     "点击下方「立即同步」开始第一次同步。")
        }
        return lastSyncedLabel
    }

    /// Friendly "Last synced 30s ago" / "Last synced 2 min ago" label.
    /// Recomputes via `nowTick` once a second so the value stays fresh.
    private var lastSyncedLabel: String {
        guard let last = sync.lastSyncedAt else {
            return L("Never synced yet", "尚未同步")
        }
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .short
        _ = nowTick
        return L("Last synced ", "上次同步 ")
            + f.localizedString(for: last, relativeTo: Date())
    }

    private func runManualSync() {
        isSyncing = true
        AppCommands.syncNow()
        // SyncTimer.pokeNow does its own CloudKit roundtrip; result
        // lands in SyncSettings.shared as either lastSyncedAt update
        // or lastSyncError. The spinner is just visual buffering.
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            isSyncing = false
        }
    }
}

// MARK: - Recently Deleted tab

@MainActor
private struct MacRecentlyDeletedTab: View {
    @Environment(\.modelContext) private var ctx

    @Query(
        filter: #Predicate<Note> { note in note.archived },
        sort: [SortDescriptor(\Note.updatedAt, order: .reverse)]
    )
    private var archived: [Note]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if archived.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "trash")
                        .font(.system(size: 32))
                        .foregroundStyle(.secondary)
                    Text("No recently deleted notes.")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    Text("Notes archived on this device or synced from iOS appear here.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                HStack {
                    Text("\(archived.count) archived note(s)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Delete All", role: .destructive) {
                        for n in archived { ctx.delete(n) }
                        try? ctx.save()
                    }
                    .foregroundStyle(.red)
                }
                List {
                    ForEach(archived) { note in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(note.title.isEmpty ? "Untitled" : note.title)
                                    .font(.body)
                                    .lineLimit(1)
                                Text(note.updatedAt, style: .relative)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button("Restore") {
                                note.archived = false
                                note.touch()
                                try? ctx.save()
                            }
                            .controlSize(.small)
                            .foregroundStyle(Color.accentColor)
                            Button("Delete Forever") {
                                ctx.delete(note)
                                try? ctx.save()
                            }
                            .controlSize(.small)
                            .foregroundStyle(.red)
                            .buttonStyle(.plain)
                        }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        }
        .padding(8)
    }
}

// MARK: - SettingsWindowOpacityFix

/// SwiftUI's `Settings` scene hosts content in an NSWindow with
/// `NSVisualEffectView`-backed vibrancy. That's why the previous Settings
/// surface looked semi-transparent regardless of theme — the desktop
/// wallpaper bled through. This NSViewRepresentable reaches up the view
/// hierarchy on first attach, finds the host NSWindow, and:
///
///   · `isOpaque = true`           — stop drawing the window with alpha
///   · `backgroundColor = .clear`  — but let SwiftUI's own backdrop paint
///   · removes any vibrancy view   — kills the blur material so the
///                                   adaptive cyber gradient behind us
///                                   shows through cleanly
///
/// Same TrackingView trick we use for the main window's
/// `WindowConfigurator` to handle the case where SwiftUI calls
/// `makeNSView` before the view is attached to its window.
private struct SettingsWindowOpacityFix: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let v = TrackingView()
        v.onMoveToWindow = { configure($0) }
        DispatchQueue.main.async { configure(v.window) }
        return v
    }
    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async { configure(nsView.window) }
    }

    private func configure(_ window: NSWindow?) {
        guard let window else { return }
        window.isOpaque = true
        window.backgroundColor = .clear
        window.titlebarAppearsTransparent = false

        // Remove any NSVisualEffectView SwiftUI inserted as the window's
        // backing material — the cyber backdrop in `SettingsView.body`
        // already covers the whole content area, so the vibrancy is
        // both invisible and the source of the wash-out.
        if let contentView = window.contentView {
            stripVisualEffects(from: contentView)
        }
    }

    private func stripVisualEffects(from view: NSView) {
        for sub in view.subviews {
            if let vfx = sub as? NSVisualEffectView {
                vfx.isHidden = true
            } else {
                stripVisualEffects(from: sub)
            }
        }
    }

    private final class TrackingView: NSView {
        var onMoveToWindow: ((NSWindow?) -> Void)?
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            onMoveToWindow?(window)
        }
    }
}
