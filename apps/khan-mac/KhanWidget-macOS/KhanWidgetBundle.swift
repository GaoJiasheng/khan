import WidgetKit
import SwiftUI

@main
struct KhanWidgetBundleMac: WidgetBundle {
    var body: some Widget {
        InboxWidgetMac()
    }
}

struct InboxWidgetMac: Widget {
    let kind = "com.gavin.khan.widget.inbox.mac"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: PlaceholderProvider()) { _ in
            VStack { Image(systemName: "tray"); Text("Khan Inbox").font(.caption) }
        }
        .configurationDisplayName("Khan Inbox")
        .description("Recent inbox items.")
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
