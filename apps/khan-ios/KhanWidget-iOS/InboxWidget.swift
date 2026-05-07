import WidgetKit
import SwiftUI
import SwiftData
import KhanCore
import KhanUI

struct InboxWidget: Widget {
    let kind: String = "com.gavin.khan.widget.inbox"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: InboxProvider()) { entry in
            InboxWidgetView(entry: entry)
        }
        .configurationDisplayName("Khan Inbox")
        .description("Recent unread messages.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge, .accessoryRectangular])
    }
}

struct InboxEntry: TimelineEntry {
    let date: Date
    let messages: [InboxSnapshot]
}

struct InboxSnapshot: Identifiable {
    let id: UUID
    let title: String
    let source: String
    let receivedAt: Date
}

struct InboxProvider: TimelineProvider {
    func placeholder(in context: Context) -> InboxEntry {
        InboxEntry(date: .now, messages: [])
    }

    func getSnapshot(in context: Context, completion: @escaping (InboxEntry) -> Void) {
        completion(load())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<InboxEntry>) -> Void) {
        let next = Date().addingTimeInterval(15 * 60)
        completion(Timeline(entries: [load()], policy: .after(next)))
    }

    private func load() -> InboxEntry {
        guard let container = try? ModelContainerFactory.make(useCloudKit: true) else {
            return InboxEntry(date: .now, messages: [])
        }
        let context = ModelContext(container)
        var descriptor = FetchDescriptor<Message>(
            sortBy: [SortDescriptor(\.receivedAt, order: .reverse)]
        )
        descriptor.fetchLimit = 5
        let messages = (try? context.fetch(descriptor)) ?? []
        return InboxEntry(
            date: .now,
            messages: messages.map {
                InboxSnapshot(id: $0.id, title: $0.title, source: $0.source.displayName, receivedAt: $0.receivedAt)
            }
        )
    }
}

struct InboxWidgetView: View {
    let entry: InboxEntry

    var body: some View {
        if entry.messages.isEmpty {
            VStack {
                Image(systemName: "tray")
                Text("Inbox empty")
                    .font(.caption)
            }
        } else {
            VStack(alignment: .leading, spacing: 4) {
                ForEach(entry.messages.prefix(4)) { m in
                    HStack {
                        Text(m.title)
                            .font(.caption)
                            .lineLimit(1)
                        Spacer()
                        Text(m.receivedAt, style: .relative)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(8)
        }
    }
}
