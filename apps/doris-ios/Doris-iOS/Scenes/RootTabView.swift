import SwiftUI
import DorisCore
import DorisUI

/// Top-level tab bar. Order: Today / Notes / Events.
/// Today is the agenda hero (weather + pinned + calendar). Notes is the
/// primary writing surface, kept adjacent to Today since users move
/// between them most often. Events is the inbox of cross-device pings.
struct RootTabView: View {
    @ObservedObject private var lang = LanguageSettings.shared
    @State private var selection: Tab = .today

    enum Tab: Hashable { case today, notes, events }

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
        }
        .tint(CyberPalette.neonCyan)
    }
}
