import SwiftUI
import DorisCore
import DorisUI

struct NotchExpandedView: View {
    @State private var tab: Tab = .inbox

    enum Tab { case inbox, notes, today }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Doris")
                    .font(.headline)
                Spacer()
                Button {
                    NSWorkspace.shared.open(URL(string: "doris://main")!)
                } label: { Image(systemName: "macwindow") }
                    .buttonStyle(.borderless)
            }
            .padding(8)
            Divider()
            switch tab {
            case .inbox: InboxListView()
            case .notes: NoteListView()
            case .today: DorisEmptyStateView(title: "Today", systemImage: "sun.max", subtitle: nil)
            }
        }
        .frame(width: 480, height: 400)
        .background(.regularMaterial)
    }
}
