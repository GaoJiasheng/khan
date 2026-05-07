import SwiftUI
import SwiftData
import KhanCore
import KhanIPC
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
            sidebarTab
                .tabItem { Label("Sidebar", systemImage: "sidebar.right") }
            shortcutTab
                .tabItem { Label("Shortcuts", systemImage: "keyboard") }
            cliTab
                .tabItem { Label("CLI", systemImage: "terminal") }
        }
        .frame(width: 460, height: 360)
        .padding()
    }

    private var generalTab: some View {
        Form {
            Picker("Theme", selection: theme) {
                ForEach(KhanTheme.allCases, id: \.self) { Text($0.rawValue.capitalized).tag($0) }
            }
            Toggle("Show hex color preview", isOn: showHexColorPreview)
            Toggle("Auto-backup daily", isOn: autoBackupEnabled)
            HStack {
                Text("Sync poke interval")
                Spacer()
                Stepper("\(settings.syncPokeIntervalSec) s", value: syncPokeInterval, in: 30...600, step: 30)
            }
        }
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
    private var syncPokeInterval: Binding<Int> {
        Binding(get: { settings.syncPokeIntervalSec }, set: { settings.syncPokeIntervalSec = $0 })
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
