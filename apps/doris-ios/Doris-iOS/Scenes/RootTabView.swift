import SwiftUI
import DorisCore
import DorisUI

/// Top-level tab bar. Order: Today / Notes / Events / Settings.
/// Today is the agenda hero (weather + pinned + calendar preview).
/// Notes is the primary writing surface. Events is the cross-device
/// notifications inbox. Settings was lifted from a Notes-toolbar sheet
/// into its own tab so the Notes top bar can stay focused on quick
/// actions (calendar timeline + new note).
struct RootTabView: View {
    @ObservedObject private var lang = LanguageSettings.shared
    @State private var selection: Tab = .today

    enum Tab: Hashable { case today, notes, events, settings }

    var body: some View {
        TabView(selection: $selection) {
            TodayScreen()
                .tabItem {
                    Label(L("Today", "今日"), systemImage: "sun.max.fill")
                }
                .tag(Tab.today)

            NotesScreen()
                .tabItem {
                    Label(L("Notes", "笔记"), systemImage: "note.text")
                }
                .tag(Tab.notes)

            EventsScreen()
                .tabItem {
                    Label(L("Events", "事件"), systemImage: "tray.fill")
                }
                .tag(Tab.events)

            SettingsScreen()
                .tabItem {
                    Label(L("Settings", "设置"), systemImage: "gearshape.fill")
                }
                .tag(Tab.settings)
        }
        .tint(CyberPalette.neonCyan)
    }
}
