import SwiftUI
import SwiftData
import DorisCore

public struct EventsListView: View {
    @Query(sort: [SortDescriptor(\Message.receivedAt, order: .reverse)])
    private var messages: [Message]
    @Environment(\.modelContext) private var modelContext
    @State private var filter: SourceKind?

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 6) {
                FilterChip(label: L("All", "全部"), isOn: filter == nil) { filter = nil }
                ForEach(SourceKind.allCases, id: \.self) { kind in
                    FilterChip(label: kind.displayName, isOn: filter == kind) { filter = kind }
                }
                Spacer()
            }
            .padding(8)
            Divider()
            List {
                ForEach(filtered) { message in
                    EventsRowView(message: message)
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                message.state = .dismissed
                            } label: { Label(L("Dismiss", "忽略"), systemImage: "xmark") }
                            Button {
                                message.state = .actioned
                            } label: { Label(L("Done", "完成"), systemImage: "checkmark") }
                            .tint(.green)
                        }
                }
            }
            .listStyle(.inset)
        }
        .navigationTitle(L("Events", "事件"))
    }

    private var filtered: [Message] {
        guard let f = filter else { return messages.filter { $0.state == .active } }
        return messages.filter { $0.state == .active && $0.source == f }
    }
}

private struct FilterChip: View {
    let label: String
    let isOn: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.caption)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(isOn ? Color.accentColor.opacity(0.2) : Color.secondary.opacity(0.1))
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}
