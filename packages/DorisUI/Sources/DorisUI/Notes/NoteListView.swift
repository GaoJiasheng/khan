import SwiftUI
import SwiftData
import DorisCore

public struct NoteListView: View {
    @Query(sort: [SortDescriptor(\Note.updatedAt, order: .reverse)])
    private var notes: [Note]
    @Environment(\.modelContext) private var modelContext
    @State private var selectedID: UUID?
    public var folderFilter: Folder?

    public init(folderFilter: Folder? = nil) {
        self.folderFilter = folderFilter
        if let folder = folderFilter {
            let id = folder.id
            _notes = Query(
                filter: #Predicate { $0.folder?.id == id },
                sort: [SortDescriptor(\Note.updatedAt, order: .reverse)]
            )
        }
    }

    public var body: some View {
        NavigationSplitView {
            List(selection: $selectedID) {
                ForEach(notes) { note in
                    NavigationLink(value: note.id) {
                        VStack(alignment: .leading, spacing: 2) {
                            HStack {
                                if note.pinned { Image(systemName: "pin.fill").foregroundStyle(.orange) }
                                Text(note.title.isEmpty ? "Untitled" : note.title)
                                    .lineLimit(1)
                            }
                            Text(note.updatedAt, style: .relative)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .onDelete { indexSet in
                    for index in indexSet { modelContext.delete(notes[index]) }
                }
            }
            .listStyle(.sidebar)
            .toolbar {
                Button {
                    let new = Note(title: "New note")
                    modelContext.insert(new)
                    selectedID = new.id
                } label: { Image(systemName: "plus") }
            }
            .navigationTitle(folderFilter?.name ?? "Notes")
        } detail: {
            if let id = selectedID, let note = notes.first(where: { $0.id == id }) {
                NoteEditorView(note: note)
            } else {
                ContentUnavailableView("No note selected", systemImage: "note.text")
            }
        }
    }
}
