import SwiftUI
import KhanCore
import KhanUI

struct RootTabView: View {
    var body: some View {
        TabView {
            NavigationStack {
                InboxListView()
                    .navigationTitle("Inbox")
            }
            .tabItem { Label("Inbox", systemImage: "tray") }

            NavigationStack {
                NoteListView()
            }
            .tabItem { Label("Notes", systemImage: "note.text") }

            NavigationStack {
                IOSDevicesView()
            }
            .tabItem { Label("Devices", systemImage: "iphone") }
        }
    }
}

private struct IOSDevicesView: View {
    var body: some View {
        KhanEmptyStateView(title: "Devices", systemImage: "iphone", subtitle: "Devices on your iCloud account will appear here once they sync.")
            .navigationTitle("Devices")
    }
}
