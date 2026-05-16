import SwiftUI
import DorisCore
import DorisUI

/// Top-level tab bar. Order: Today / Events / Notes — Today is the cyber-girl
/// hero scene + weather + voice button (iOS counterpart of the Mac
/// expanded panel), Events/Notes pull from the shared SwiftData store.
struct RootTabView: View {
    @ObservedObject private var lang = LanguageSettings.shared
    @State private var selection: Tab = .today

    enum Tab: Hashable { case today, events, notes }

    var body: some View {
        TabView(selection: $selection) {
            TodayScreen()
                .tabItem {
                    Label(L("Today", "今日"), systemImage: "sun.max.fill")
                }
                .tag(Tab.today)

            EventsScreen()
                .tabItem {
                    Label(L("Events", "事件"), systemImage: "tray.fill")
                }
                .tag(Tab.events)

            NotesScreen()
                .tabItem {
                    Label(L("Notes", "笔记"), systemImage: "note.text")
                }
                .tag(Tab.notes)
        }
        .tint(CyberPalette.neonCyan)
    }
}
