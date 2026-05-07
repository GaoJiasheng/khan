import SwiftUI
import KhanCore
import KhanUI

/// Top-level tab bar. Order: Today / Inbox / Notes — Today is the cyber-girl
/// hero scene + weather + voice button (iOS counterpart of the Mac
/// expanded panel), Inbox/Notes pull from the shared SwiftData store.
struct RootTabView: View {
    @ObservedObject private var lang = LanguageSettings.shared
    @State private var selection: Tab = .today

    enum Tab: Hashable { case today, inbox, notes }

    var body: some View {
        TabView(selection: $selection) {
            TodayScreen()
                .tabItem {
                    Label(L("Today", "今日"), systemImage: "sun.max.fill")
                }
                .tag(Tab.today)

            InboxScreen()
                .tabItem {
                    Label(L("Inbox", "收件箱"), systemImage: "tray.fill")
                }
                .tag(Tab.inbox)

            NotesScreen()
                .tabItem {
                    Label(L("Notes", "笔记"), systemImage: "note.text")
                }
                .tag(Tab.notes)
        }
        .tint(CyberPalette.neonCyan)
    }
}
