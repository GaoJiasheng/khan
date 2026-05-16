import SwiftUI
import DorisCore
import DorisUI

struct SidebarRootView: View {
    @State private var tab: Tab = .events

    enum Tab: Hashable { case events, notes, today }

    var body: some View {
        VStack(spacing: 0) {
            tabBar
            Divider()
            switch tab {
            case .events: EventsListView()
            case .notes:  NoteListView()
            case .today:  TodayView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.regularMaterial)
    }

    private var tabBar: some View {
        HStack {
            Button("Events") { tab = .events }
                .fontWeight(tab == .events ? .bold : .regular)
            Button("Notes") { tab = .notes }
                .fontWeight(tab == .notes ? .bold : .regular)
            Button("Today") { tab = .today }
                .fontWeight(tab == .today ? .bold : .regular)
            Spacer()
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
}

private struct TodayView: View {
    var body: some View {
        DorisEmptyStateView(title: "Today", systemImage: "sun.max", subtitle: "Quick captures and recent items will appear here.")
    }
}
