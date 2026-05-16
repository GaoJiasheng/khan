import WidgetKit
import SwiftUI
import SwiftData
import DorisCore
import DorisUI

struct EventsWidget: Widget {
    let kind: String = "com.gavin.doris.widget.events"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: EventsProvider()) { entry in
            EventsWidgetView(entry: entry)
        }
        .configurationDisplayName("Doris Events")
        .description("Recent events.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge, .accessoryRectangular])
    }
}

struct EventsEntry: TimelineEntry {
    let date: Date
    let messages: [EventsSnapshot]
}

struct EventsSnapshot: Identifiable {
    let id: UUID
    let title: String
    let source: String
    let receivedAt: Date
}

struct EventsProvider: TimelineProvider {
    func placeholder(in context: Context) -> EventsEntry {
        EventsEntry(date: .now, messages: [])
    }

    func getSnapshot(in context: Context, completion: @escaping (EventsEntry) -> Void) {
        completion(load())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<EventsEntry>) -> Void) {
        let next = Date().addingTimeInterval(15 * 60)
        completion(Timeline(entries: [load()], policy: .after(next)))
    }

    private func load() -> EventsEntry {
        guard let container = try? ModelContainerFactory.make(useCloudKit: true) else {
            return EventsEntry(date: .now, messages: [])
        }
        let context = ModelContext(container)
        var descriptor = FetchDescriptor<Message>(
            sortBy: [SortDescriptor(\.receivedAt, order: .reverse)]
        )
        descriptor.fetchLimit = 5
        let messages = (try? context.fetch(descriptor)) ?? []
        return EventsEntry(
            date: .now,
            messages: messages.map {
                EventsSnapshot(id: $0.id, title: $0.title, source: $0.source.displayName, receivedAt: $0.receivedAt)
            }
        )
    }
}

struct EventsWidgetView: View {
    let entry: EventsEntry

    var body: some View {
        if entry.messages.isEmpty {
            VStack {
                Image(systemName: "bell.slash")
                Text("No events")
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
