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
        // Wrap the whole thing in a ZStack with the adaptive cyber backdrop
        // behind it. macOS gives Settings windows a vibrancy-blurred chrome
        // by default — `.preferredColorScheme(...)` flips the foreground but
        // not the vibrancy, which is why the user saw a half-transparent
        // window regardless of theme. Painting an opaque adaptive backdrop
        // on top of the vibrancy fixes that, and the
        // `SettingsWindowOpacityFix` NSViewRepresentable below also tells
        // the host NSWindow to render opaquely so light-mode pixels don't
        // bleed in from the desktop wallpaper.
        ZStack {
            CyberPalette.backdrop
                .ignoresSafeArea()
            TabView {
                generalTab
                    .tabItem { Label("General", systemImage: "gear") }
                syncTab
                    .tabItem { Label("Sync", systemImage: "icloud.fill") }
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
        .frame(width: 480, height: 420)
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
    @State private var isSyncing: Bool = false
    @State private var lastTickTimer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    @State private var nowTick: Date = Date()

    var body: some View {
        Form {
            Section {
                Toggle("Use iCloud (CloudKit) sync", isOn: $sync.cloudKitEnabled)
                    .help("Mirrors notes and events through your iCloud account so other devices stay in sync.")
                if sync.cloudKitEnabled {
                    Text("Restart Doris after toggling iCloud for the change to take effect.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("Local only. Notes stay on this Mac.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("iCloud")
            }

            Section {
                Toggle("Auto-sync every 60 seconds", isOn: $sync.autoSyncEnabled)
                    .help("When on, Doris periodically flushes pending writes so iCloud has the latest state. Turn off if you only want manual sync.")
            } header: {
                Text("Auto-sync")
            }

            Section {
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
                            Text(isSyncing ? "Syncing…" : "Sync Now")
                        }
                    }
                    .disabled(isSyncing)
                    Spacer()
                    Text(lastSyncedLabel)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
            } header: {
                Text("Manual sync")
            } footer: {
                Text("Sync Now flushes pending writes to disk and lets iCloud pick them up. Independent of the auto-sync toggle.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .scrollContentBackground(.hidden)
        .onReceive(lastTickTimer) { nowTick = $0 }
    }

    /// Friendly "Last synced 30s ago" / "Last synced 2 min ago" label.
    /// Recomputes via `nowTick` once a second so the value stays fresh
    /// without us hammering the formatter.
    private var lastSyncedLabel: String {
        guard let last = sync.lastSyncedAt else { return "Never synced yet" }
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .short
        _ = nowTick // dependency
        return "Last synced " + f.localizedString(for: last, relativeTo: Date())
    }

    private func runManualSync() {
        isSyncing = true
        AppCommands.syncNow()
        // The hook fires off-thread; we just give the UI a beat to show
        // the spinner before flipping back. The "Last synced" label
        // updates from SyncSettings.shared.lastSyncedAt the moment the
        // poke succeeds.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            isSyncing = false
        }
    }
}

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
