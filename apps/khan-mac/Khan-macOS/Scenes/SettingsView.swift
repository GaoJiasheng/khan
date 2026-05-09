import SwiftUI
import SwiftData
import KhanCore
import KhanIPC
import KhanUI
import KeyboardShortcuts

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var settingsQuery: [UserSettings]

    private var settings: UserSettings {
        if let existing = settingsQuery.first { return existing }
        let new = UserSettings()
        modelContext.insert(new)
        return new
    }

    var body: some View {
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
        .frame(width: 480, height: 420)
        .padding()
    }

    private var generalTab: some View {
        Form {
            Picker("Theme", selection: theme) {
                ForEach(KhanTheme.allCases, id: \.self) { Text($0.rawValue.capitalized).tag($0) }
            }
            Toggle("Show hex color preview", isOn: showHexColorPreview)
            Toggle("Auto-backup daily", isOn: autoBackupEnabled)
        }
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
    }

    private var shortcutTab: some View {
        Form {
            KeyboardShortcuts.Recorder("Toggle sidebar", name: .toggleSidebar)
            KeyboardShortcuts.Recorder("Toggle notch", name: .toggleNotch)
            KeyboardShortcuts.Recorder("Open inbox", name: .openInbox)
        }
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
    }

    // Bindings backing onto the persisted UserSettings row.
    private var theme: Binding<KhanTheme> {
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
                    .help("Mirrors notes and inbox messages through your iCloud account so other devices stay in sync.")
                if sync.cloudKitEnabled {
                    Text("Restart Khan after toggling iCloud for the change to take effect.")
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
                    .help("When on, Khan periodically flushes pending writes so iCloud has the latest state. Turn off if you only want manual sync.")
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
