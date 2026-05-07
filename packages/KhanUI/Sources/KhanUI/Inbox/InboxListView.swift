import SwiftUI
import SwiftData
import KhanCore

public struct InboxListView: View {
    @Query(sort: [SortDescriptor(\Message.receivedAt, order: .reverse)])
    private var messages: [Message]
    @Environment(\.modelContext) private var modelContext
    @State private var filter: SourceKind?

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 6) {
                FilterChip(label: "All", isOn: filter == nil) { filter = nil }
                ForEach(SourceKind.allCases, id: \.self) { kind in
                    FilterChip(label: kind.displayName, isOn: filter == kind) { filter = kind }
                }
                Spacer()
            }
            .padding(8)
            Divider()
            List {
                ForEach(filtered) { message in
                    InboxRowView(message: message)
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                message.state = .dismissed
                            } label: { Label("Dismiss", systemImage: "xmark") }
                            Button {
                                message.state = .actioned
                            } label: { Label("Done", systemImage: "checkmark") }
                            .tint(.green)
                        }
                }
            }
            .listStyle(.inset)
        }
        .navigationTitle("Inbox")
    }

    private var filtered: [Message] {
        guard let f = filter else { return messages.filter { $0.state == .inbox } }
        return messages.filter { $0.state == .inbox && $0.source == f }
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
