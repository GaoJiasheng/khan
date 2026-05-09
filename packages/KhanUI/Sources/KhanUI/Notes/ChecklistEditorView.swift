import SwiftUI
import SwiftData
import KhanCore

public struct ChecklistEditorView: View {
    @Bindable public var note: Note
    @Environment(\.modelContext) private var modelContext
    @State private var newItem: String = ""

    public init(note: Note) {
        self.note = note
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(sortedItems) { item in
                HStack(alignment: .center, spacing: 8) {
                    Toggle("", isOn: Bindable(wrappedValue: item).done)
                        // `.toggleStyle(.checkbox)` is macOS-only. On iOS
                        // SwiftUI doesn't ship a built-in checkbox style,
                        // so fall back to `.switch` (the platform default).
                        #if os(macOS)
                        .toggleStyle(.checkbox)
                        #else
                        .toggleStyle(.switch)
                        #endif
                        .labelsHidden()
                    TextField("", text: Bindable(wrappedValue: item).text)
                        .textFieldStyle(.plain)
                        .strikethrough(item.done, color: .secondary)
                    Spacer()
                    Button(role: .destructive) {
                        modelContext.delete(item)
                    } label: {
                        Image(systemName: "minus.circle")
                    }
                    .buttonStyle(.borderless)
                }
            }
            HStack {
                Image(systemName: "plus.circle")
                TextField("Add item", text: $newItem)
                    .onSubmit { addItem() }
                    .textFieldStyle(.plain)
            }
        }
    }

    private var sortedItems: [ChecklistItem] {
        (note.checklistItems ?? []).sorted { $0.position < $1.position }
    }

    private func addItem() {
        let trimmed = newItem.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let existing = note.checklistItems ?? []
        let nextPosition = (existing.map(\.position).max() ?? 0) + 1
        let item = ChecklistItem(text: trimmed, done: false, position: nextPosition, note: note)
        modelContext.insert(item)
        var updated = existing
        updated.append(item)
        note.checklistItems = updated
        note.updatedAt = Date()
        newItem = ""
    }
}
