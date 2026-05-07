import SwiftUI
import KhanCore
import KhanUI

struct MainWindowView: View {
    @State private var tab: Tab = .inbox

    enum Tab: Hashable { case inbox, notes, devices }

    var body: some View {
        NavigationSplitView {
            List(selection: $tab) {
                Label("Inbox", systemImage: "tray.full").tag(Tab.inbox)
                Label("Notes", systemImage: "note.text").tag(Tab.notes)
                Label("Devices", systemImage: "laptopcomputer.and.iphone").tag(Tab.devices)
            }
            .listStyle(.sidebar)
            .navigationTitle("Khan")
        } detail: {
            switch tab {
            case .inbox: InboxListView()
            case .notes: NoteListView()
            case .devices: DevicesListView()
            }
        }
        .frame(minWidth: 720, minHeight: 480)
    }
}

struct DevicesListView: View {
    var body: some View {
        KhanEmptyStateView(title: "Devices", systemImage: "laptopcomputer.and.iphone", subtitle: "Devices on your iCloud account will appear here once they sync.")
    }
}
