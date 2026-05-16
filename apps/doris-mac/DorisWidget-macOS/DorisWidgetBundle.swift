import WidgetKit
import SwiftUI

@main
struct DorisWidgetBundleMac: WidgetBundle {
    var body: some Widget {
        EventsWidgetMac()
    }
}

struct EventsWidgetMac: Widget {
    let kind = "com.gavin.doris.widget.events.mac"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: PlaceholderProvider()) { _ in
            VStack { Image(systemName: "tray"); Text("Doris Events").font(.caption) }
        }
        .configurationDisplayName("Doris Events")
        .description("Recent events.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct PlaceholderEntry: TimelineEntry { let date: Date }
struct PlaceholderProvider: TimelineProvider {
    func placeholder(in context: Context) -> PlaceholderEntry { .init(date: .now) }
    func getSnapshot(in context: Context, completion: @escaping (PlaceholderEntry) -> Void) {
        completion(.init(date: .now))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<PlaceholderEntry>) -> Void) {
        completion(Timeline(entries: [.init(date: .now)], policy: .atEnd))
    }
}
