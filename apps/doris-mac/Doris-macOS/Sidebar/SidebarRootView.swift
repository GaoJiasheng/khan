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
            Button(L("Events", "事件")) { tab = .events }
                .fontWeight(tab == .events ? .bold : .regular)
            Button(L("Notes", "笔记")) { tab = .notes }
                .fontWeight(tab == .notes ? .bold : .regular)
            Button(L("Today", "今日")) { tab = .today }
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
        DorisEmptyStateView(
            title: L("Today", "今日"),
            systemImage: "sun.max",
            subtitle: L("Quick captures and recent items will appear here.",
                        "快速记录的内容和最近的项目会出现在这里。")
        )
    }
}
